import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_models.dart';
import '../models/marketplace_models.dart';
import '../utils/ids.dart';

/// O banco recusou a mensagem porque o serviço foi concluído/cancelado
/// (trigger `CHAT_ARCHIVED`): a conversa virou somente leitura.
class ChatArchivedException implements Exception {
  const ChatArchivedException();

  static const userMessage = 'Este serviço foi encerrado. A conversa está arquivada e não aceita novas mensagens.';

  @override
  String toString() => userMessage;
}

/// Chat por demanda, notificações, avaliações e suporte.
class SocialService {
  SocialService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// IDs de notificações marcadas como lidas na sessão atual (atualização otimista < 16ms
  /// compartilhada entre `NotificationsScreen` e `UnreadBell` tanto para Cliente quanto Profissional).
  static final Set<String> _optimisticallyReadIds = <String>{};
  static DateTime? _markedAllReadAt;
  static final StreamController<void> _notificationsChangedController =
      StreamController<void>.broadcast();

  /// Stream disparado sempre que qualquer notificação é marcada como lida/vista.
  static Stream<void> get onNotificationsChanged =>
      _notificationsChangedController.stream;

  /// Verifica se a notificação já foi vista (no banco ou otimisticamente na sessão).
  static bool isOptimisticallyRead(AppNotification n) {
    if (!n.unread) return true;
    if (_optimisticallyReadIds.contains(n.id)) return true;
    if (_markedAllReadAt != null && !n.createdAt.isAfter(_markedAllReadAt!)) {
      return true;
    }
    return false;
  }

  /// Aplica o estado otimista de leitura sobre uma notificação.
  static AppNotification applyOptimisticRead(AppNotification n) {
    if (!n.unread) return n;
    if (isOptimisticallyRead(n)) {
      return n.copyWith(readAt: DateTime.now());
    }
    return n;
  }

  /// Marca instantaneamente em memória uma notificação como vista e notifica a UI.
  static void markOptimisticallyRead(String id) {
    _optimisticallyReadIds.add(id);
    if (!_notificationsChangedController.isClosed) {
      _notificationsChangedController.add(null);
    }
  }

  /// Marca instantaneamente todas as notificações atuais como vistas em memória e notifica a UI.
  static void markAllOptimisticallyRead([Iterable<String> ids = const []]) {
    _optimisticallyReadIds.addAll(ids);
    _markedAllReadAt = DateTime.now().add(const Duration(seconds: 2));
    if (!_notificationsChangedController.isClosed) {
      _notificationsChangedController.add(null);
    }
  }

  @visibleForTesting
  static void resetOptimisticReadState() {
    _optimisticallyReadIds.clear();
    _markedAllReadAt = null;
  }

  String get uid {
    final u = _client.auth.currentUser;
    if (u == null) throw const AuthException('Sessão expirada.');
    return u.id;
  }

  // ----------------------------------------------------------------- chat

  /// Mensagens da conversa em ordem CRONOLÓGICA (antiga → nova).
  ///
  /// O default do `supabase_flutter` é `ascending: false`; por isso a ordem é
  /// explícita aqui E reforçada no Dart (created_at, desempate por id): o stream
  /// só aceita uma coluna de ordenação. Nunca misturar DESC com lista não reversa.
  Stream<List<ChatMessage>> streamMessages(String jobId, String providerId) => _client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('job_id', jobId)
      .order('created_at', ascending: true)
      .map((rows) {
        final list = rows.map(ChatMessage.fromMap).where((m) => m.providerId == providerId).toList();
        list.sort((a, b) {
          final c = a.createdAt.compareTo(b.createdAt);
          return c != 0 ? c : a.id.compareTo(b.id);
        });
        return list;
      });

  /// Envia uma mensagem de forma idempotente.
  ///
  /// [clientMessageId] (UUID v4) é SEMPRE enviado; o banco tem
  /// `UNIQUE (job_id, sender_id, client_message_id)`, então um retry/duplo envio
  /// falha com `23505`, que aqui é tratado como SUCESSO (a mensagem já está lá).
  /// Serviço encerrado (`CHAT_ARCHIVED`) vira [ChatArchivedException].
  Future<void> sendMessage({
    required String jobId,
    required String providerId,
    required String body,
    String kind = 'text',
    Map<String, dynamic>? meta,
    String? clientMessageId,
  }) async {
    try {
      await _client.from('messages').insert({
        'job_id': jobId,
        'provider_id': providerId,
        'body': body,
        'kind': kind,
        'meta': meta,
        'client_message_id': clientMessageId ?? uuidV4(),
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') return;
      if (e.message.contains('CHAT_ARCHIVED')) throw const ChatArchivedException();
      rethrow;
    }
  }

  /// Interlocutor da conversa (nome já sanitizado, foto e especialidade) via RPC
  /// `chat_counterpart`. Null se o banco não devolver nada.
  Future<ChatCounterpart?> chatCounterpart(String jobId, String providerId) async {
    final r = await _client.rpc('chat_counterpart', params: {'p_job': jobId, 'p_provider': providerId});
    if (r is Map) return ChatCounterpart.fromMap(Map<String, dynamic>.from(r));
    return null;
  }

  // -------------------------------------------------------- notificações

  Future<List<AppNotification>> fetchNotifications() async {
    final rows = await _client
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return rows.map(AppNotification.fromMap).map(applyOptimisticRead).toList();
  }

  Stream<List<AppNotification>> streamNotifications() {
    late StreamController<List<AppNotification>> controller;
    StreamSubscription<List<AppNotification>>? realtimeSub;
    StreamSubscription<void>? localSub;
    List<AppNotification>? latestRaw;

    void emitCurrent() {
      if (controller.isClosed || latestRaw == null) return;
      controller.add(latestRaw!.map(applyOptimisticRead).toList());
    }

    controller = StreamController<List<AppNotification>>.broadcast(
      onListen: () {
        realtimeSub = _client
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .map((rows) => rows.map(AppNotification.fromMap).toList())
            .listen(
              (items) {
                latestRaw = items;
                emitCurrent();
              },
              onError: (Object err, StackTrace st) {
                if (!controller.isClosed) controller.addError(err, st);
              },
            );
        localSub = onNotificationsChanged.listen((_) {
          emitCurrent();
        });
      },
      onCancel: () async {
        await realtimeSub?.cancel();
        await localSub?.cancel();
      },
    );
    return controller.stream;
  }

  Future<void> markRead(String id) async {
    markOptimisticallyRead(id);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    try {
      await _client
          .from('notifications')
          .update({'read_at': nowIso})
          .eq('id', id);
    } catch (_) {
      try {
        await _client.rpc('mark_notification_read', params: {'p_notification_id': id});
      } catch (_) {}
    }
  }

  Future<void> markAllRead() async {
    markAllOptimisticallyRead();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    try {
      await _client
          .from('notifications')
          .update({'read_at': nowIso})
          .eq('user_id', uid)
          .isFilter('read_at', null);
    } catch (_) {
      try {
        await _client.rpc('mark_notification_read');
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------ avaliações

  Future<void> submitReview({
    required String jobId,
    required int rating,
    String? comment,
    List<String> tags = const [],
    double tip = 0,
    Map<String, int>? criteria,
    List<String> photoPaths = const [],
  }) =>
      _client.rpc('submit_review', params: {
        'p_job_id': jobId,
        'p_rating': rating,
        'p_comment': comment,
        'p_tags': tags,
        'p_tip': tip,
        'p_criteria': criteria,
        'p_photo_paths': photoPaths,
      });

  /// Estado da avaliação do serviço para o usuário: `none`, `waiting` (enviada,
  /// aguardando a outra parte ou 48 h) ou `revealed`.
  Future<String> reviewStatus(String jobId) async {
    final r = await _client.rpc('review_status', params: {'p_job': jobId});
    return (r as String?) ?? 'none';
  }

  Future<bool> alreadyReviewed(String jobId) async {
    final row = await _client
        .from('reviews')
        .select('id')
        .eq('job_id', jobId)
        .eq('reviewer_id', uid)
        .maybeSingle();
    return row != null;
  }

  // --------------------------------------------------------------- suporte

  Future<String> createTicket({
    String? jobId,
    required String reason,
    String? description,
    List<String> evidencePaths = const [],
  }) async {
    final r = await _client.rpc('create_support_ticket', params: {
      'p_job_id': jobId,
      'p_reason': reason,
      'p_description': description,
      'p_evidence': evidencePaths,
    });
    return r as String;
  }

  Future<List<Map<String, dynamic>>> myTickets() async {
    final rows = await _client.from('support_tickets').select().eq('user_id', uid).order('created_at', ascending: false);
    return rows.cast<Map<String, dynamic>>();
  }
}

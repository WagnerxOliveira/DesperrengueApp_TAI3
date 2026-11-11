import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client_dossier_models.dart';
import '../models/marketplace_models.dart';
import '../utils/order_utils.dart';
import '../utils/tag_normalizer.dart';
import 'media_service.dart';

/// Ciclo de vida do serviço: demanda -> convites/orçamentos -> aceite ->
/// checkout MOCK -> execução -> PIN -> conclusão. Toda transição de estado
/// passa por RPC no banco; o app nunca escreve `status`/`payment_status`.
class JobService {
  JobService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static final StreamController<void> _jobsChangedController =
      StreamController<void>.broadcast();

  /// Barramento reativo local disparado sempre que um pedido é criado, alterado
  /// ou quando o usuário navega para a aba "Meus Pedidos", garantindo atualização
  /// instantânea (< 16ms) sem precisar fechar e reabrir o aplicativo.
  static Stream<void> get onJobsChanged => _jobsChangedController.stream;

  /// Notifica todos os ouvintes ativos (`ClientOrdersTab`, painéis) para
  /// sincronizar imediatamente a lista de pedidos.
  static void notifyJobsChanged() {
    if (!_jobsChangedController.isClosed) {
      _jobsChangedController.add(null);
    }
  }

  String get uid {
    final u = _client.auth.currentUser;
    if (u == null) throw const AuthException('Sessão expirada.');
    return u.id;
  }

  Stream<List<Job>> _reactiveJobStream({
    required Stream<List<Job>> Function() realtimeFactory,
    required Future<List<Job>> Function() fetchFallback,
  }) {
    late StreamController<List<Job>> controller;
    StreamSubscription<List<Job>>? realtimeSub;
    StreamSubscription<void>? localBusSub;

    Future<void> refreshFromDb() async {
      try {
        final fresh = await fetchFallback();
        if (!controller.isClosed) {
          controller.add(fresh);
        }
      } catch (_) {
        // Falha transitória no re-fetch secundário não interrompe o stream principal.
      }
    }

    controller = StreamController<List<Job>>.broadcast(
      onListen: () {
        realtimeSub = realtimeFactory().listen(
          (rows) {
            if (!controller.isClosed) controller.add(rows);
          },
          onError: (Object err, StackTrace st) {
            if (!controller.isClosed) controller.addError(err, st);
          },
        );
        localBusSub = onJobsChanged.listen((_) => refreshFromDb());
      },
      onCancel: () async {
        await realtimeSub?.cancel();
        await localBusSub?.cancel();
      },
    );
    return controller.stream;
  }

  // ---------------------------------------------------------------- cliente

  Future<String> createJob({
    required String title,
    required String description,
    required String category,
    required bool emergency,
    required bool direct,
    required String addressSummary,
    required String addressLine,
    String? complement,
    String? reference,
    DateTime? scheduledFor,
    double? latitude,
    double? longitude,
    List<String> photoPaths = const [],
    List<Map<String, dynamic>> photoAnnotations = const [],
  }) async {
    final basePayload = <String, dynamic>{
      'client_id': uid,
      'title': title,
      'description': description,
      'category': category,
      'urgency': emergency ? 'emergency' : 'scheduled',
      'visibility': direct ? 'direct' : 'open',
      'address_summary': addressSummary,
      'scheduled_for': scheduledFor?.toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'photo_paths': photoPaths,
    };

    Map<String, dynamic> row;
    if (photoAnnotations.isNotEmpty) {
      try {
        row = await _client
            .from('jobs')
            .insert({
              ...basePayload,
              'photo_annotations': photoAnnotations,
            })
            .select('id')
            .single();
      } on PostgrestException catch (e) {
        if (e.message.contains('photo_annotations')) {
          row = await _client.from('jobs').insert(basePayload).select('id').single();
        } else {
          rethrow;
        }
      }
    } else {
      row = await _client.from('jobs').insert(basePayload).select('id').single();
    }

    final id = row['id'] as String;

    await _client.from('job_addresses').insert({
      'job_id': id,
      'address_line': addressLine,
      'complement': complement,
      'reference': reference,
    });
    notifyJobsChanged();
    return id;
  }

  Future<int> invite(String jobId, List<String> providerIds) async {
    final r = await _client.rpc('invite_providers', params: {
      'p_job_id': jobId,
      'p_provider_ids': providerIds,
    });
    notifyJobsChanged();
    return (r as num?)?.toInt() ?? 0;
  }

  Future<Job?> fetchJob(String id) async {
    final row = await _client.from('jobs').select().eq('id', id).maybeSingle();
    return row == null ? null : Job.fromMap(row);
  }

  /// Dossiê do serviço para o cliente dono (RPC `client_job_dossier`); null se não for o dono.
  Future<ClientDossier?> clientJobDossier(String jobId) async {
    final r = await _client.rpc('client_job_dossier', params: {'p_job': jobId});
    if (r is Map) return ClientDossier.fromMap(Map<String, dynamic>.from(r));
    return null;
  }

  /// Serviços concluídos, sob proteção pós-serviço, em mediação ou cancelados do cliente logado,
  /// mais recentes primeiro (conclusão/aprovação > criação). Alimenta o "Histórico de serviços".
  Future<List<Job>> fetchMyFinishedJobs() async {
    final rows = await _client
        .from('jobs')
        .select()
        .eq('client_id', uid)
        .inFilter('status', ['completed', 'disputed', 'canceled'])
        .order('created_at', ascending: false);
    final jobs = rows.map(Job.fromMap).toList();
    DateTime when(Job j) => j.approvedAt ?? j.finishedAt ?? j.createdAt;
    jobs.sort((a, b) => when(b).compareTo(when(a)));
    return jobs;
  }

  Stream<Job?> streamJob(String id) => _client
      .from('jobs')
      .stream(primaryKey: ['id'])
      .eq('id', id)
      .map((rows) => rows.isEmpty ? null : Job.fromMap(rows.first));

  Future<List<Job>> fetchMyJobs() async {
    final rows = await _client
        .from('jobs')
        .select()
        .eq('client_id', uid)
        .order('created_at', ascending: false);
    return rows.map(Job.fromMap).toList();
  }

  Stream<List<Job>> streamMyJobs() => _reactiveJobStream(
        realtimeFactory: () => _client
            .from('jobs')
            .stream(primaryKey: ['id'])
            .eq('client_id', uid)
            .order('created_at', ascending: false)
            .map((rows) => rows.map(Job.fromMap).toList()),
        fetchFallback: fetchMyJobs,
      );

  /// Serviços em mediação em que o usuário participa (como cliente OU como profissional).
  /// Alimenta a seção "Mediações" de Perfil > Ajuda e suporte: só existe quando há uma aberta.
  Future<List<Job>> fetchMyDisputes() async {
    final me = uid;
    final rows = await _client
        .from('jobs')
        .select()
        .eq('status', 'disputed')
        .or('client_id.eq.$me,provider_id.eq.$me')
        .order('created_at', ascending: false);
    return rows.map(Job.fromMap).toList();
  }

  /// Quantos pedidos do cliente estão em aberto aguardando orçamentos agora.
  /// Alimenta o contador "1º, 2º, 3º" da revisão do pedido.
  Future<int> countMyOpenRequests() async => countOpenRequests(await fetchMyJobs());

  /// `job_id` dos serviços que o cliente JÁ avaliou (conquista "Voz da Comunidade").
  Future<Set<String>> myGivenReviewJobIds() async {
    final rows = await _client.from('reviews').select('job_id').eq('reviewer_id', uid);
    return {for (final r in rows) r['job_id'] as String};
  }

  /// `job_id` dos serviços em que o próprio usuário abriu contestação/suporte.
  Future<Set<String>> myContestedJobIds() async {
    final rows = await _client.from('support_tickets').select('job_id').eq('user_id', uid).not('job_id', 'is', null);
    return {for (final r in rows) r['job_id'] as String};
  }

  Future<List<Quote>> fetchQuotes(String jobId) async {
    final rows = await _client
        .from('quotes')
        .select()
        .eq('job_id', jobId)
        .neq('status', 'withdrawn')
        .order('created_at');
    return rows.map(Quote.fromMap).toList();
  }

  Stream<List<Quote>> streamQuotes(String jobId) => _client
      .from('quotes')
      .stream(primaryKey: ['id'])
      .eq('job_id', jobId)
      .map((rows) => rows.map(Quote.fromMap).where((q) => q.status != 'withdrawn').toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));

  Future<List<JobInvite>> invitesForJob(String jobId) async {
    final rows = await _client.from('job_invites').select().eq('job_id', jobId).order('created_at');
    return rows.map(JobInvite.fromMap).toList();
  }

  Stream<List<JobInvite>> streamInvites(String jobId) => _client
      .from('job_invites')
      .stream(primaryKey: ['job_id', 'provider_id'])
      .eq('job_id', jobId)
      .map((rows) => rows.map(JobInvite.fromMap).toList());

  Future<void> acceptQuote(String quoteId) async {
    await _client.rpc('accept_quote', params: {'p_quote_id': quoteId});
    notifyJobsChanged();
  }

  Future<void> rejectQuote(String quoteId) async {
    await _client.rpc('reject_quote', params: {'p_quote_id': quoteId});
    notifyJobsChanged();
  }

  Future<void> cancelJob(String jobId) async {
    await _client.rpc('cancel_job', params: {'p_job_id': jobId});
    notifyJobsChanged();
  }

  /// Checkout MOCK: só o método escolhido trafega (nunca dados de cartão).
  Future<void> payJob(String jobId, String method, {DateTime? scheduledFor}) async {
    await _client.rpc('pay_job_mock', params: {
      'p_job_id': jobId,
      'p_method': method,
      'p_scheduled_for': scheduledFor?.toUtc().toIso8601String(),
    });
    notifyJobsChanged();
  }

  Future<void> requestEmergency(String jobId, String method) async {
    await _client.rpc('request_emergency_mock', params: {'p_job_id': jobId, 'p_method': method});
    notifyJobsChanged();
  }

  /// PIN de 4 dígitos que o CLIENTE mostra ao profissional (RLS: só o dono lê).
  Future<String?> jobPin(String jobId) async {
    final row = await _client.from('job_secrets').select('pin').eq('job_id', jobId).maybeSingle();
    return row?['pin'] as String?;
  }

  /// Endereço completo (RLS: dono e profissional contratado).
  Future<Map<String, dynamic>?> jobAddress(String jobId) =>
      _client.from('job_addresses').select().eq('job_id', jobId).maybeSingle();

  Future<Payment?> fetchPayment(String jobId) async {
    final row = await _client.from('payments').select().eq('job_id', jobId).maybeSingle();
    return row == null ? null : Payment.fromMap(row);
  }

  Future<Map<String, dynamic>?> clientCard(String jobId) =>
      _client.from('job_client_cards').select().eq('job_id', jobId).maybeSingle();

  // ----------------------------------------------------------- profissional

  Future<void> sendQuote({
    required String jobId,
    required double price,
    String? message,
    double? estimatedHours,
  }) async {
    await _client.from('quotes').insert({
      'job_id': jobId,
      'provider_id': uid,
      'price': price,
      'message': (message == null || message.trim().isEmpty) ? null : message.trim(),
      'estimated_hours': estimatedHours,
    });
    notifyJobsChanged();
  }

  Future<void> withdrawQuote(String jobId) async {
    await _client.rpc('withdraw_quote', params: {'p_job_id': jobId});
    notifyJobsChanged();
  }

  Future<void> declineInvite(String jobId) async {
    await _client.rpc('decline_invite', params: {'p_job_id': jobId});
    notifyJobsChanged();
  }

  Future<void> acceptEmergency(String jobId) async {
    await _client.rpc('accept_emergency', params: {'p_job_id': jobId});
    notifyJobsChanged();
  }

  /// Valida o PIN no servidor. O banco devolve 'ok', 'invalid:N' (N = tentativas
  /// restantes) ou 'locked' (e persiste a tentativa); aqui vira exceção legível.
  Future<void> completeWithPin(String jobId, String pin) async {
    final r = await _client.rpc('complete_job_with_pin', params: {'p_job_id': jobId, 'p_pin': pin});
    final s = (r as String?) ?? '';
    if (s == 'ok') {
      notifyJobsChanged();
      return;
    }
    if (s == 'locked') throw 'PIN_LOCKED';
    if (s.startsWith('invalid:')) throw 'PIN_INVALID:${s.substring(8)}';
    throw 'Não foi possível concluir o serviço.';
  }

  Future<Quote?> myQuoteFor(String jobId) async {
    final row = await _client
        .from('quotes')
        .select()
        .eq('job_id', jobId)
        .eq('provider_id', uid)
        .maybeSingle();
    return row == null ? null : Quote.fromMap(row);
  }

  /// Convites ainda vivos para o profissional, com a demanda correspondente.
  Future<List<({JobInvite invite, Job job})>> myLiveInvites() async {
    final rows = await _client
        .from('job_invites')
        .select()
        .eq('provider_id', uid)
        .eq('status', 'pending')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('expires_at');
    final invites = rows.map(JobInvite.fromMap).toList();
    if (invites.isEmpty) return [];
    final jobs = await _client
        .from('jobs')
        .select()
        .inFilter('id', invites.map((i) => i.jobId).toList());
    final byId = {for (final j in jobs.map(Job.fromMap)) j.id: j};
    return [
      for (final i in invites)
        if (byId[i.jobId] != null && byId[i.jobId]!.status == JobStatus.open) (invite: i, job: byId[i.jobId]!),
    ];
  }

  /// Demandas abertas ao público (feed), exceto as que já orcei.
  ///
  /// **Isolamento por categoria**: só aparece o pedido cuja categoria o profissional atende
  /// (match canônico por `Set` — "Encanador" ↔ `hidraulica`). Sem especialidades o feed fica
  /// vazio (o servidor aplica a mesma regra via RLS; aqui é só a UX coerente).
  Future<List<Job>> openFeed({List<String> specialties = const []}) async {
    if (specialties.isEmpty) return const [];
    final mine = canonicalTagSet(specialties);
    final rows = await _client
        .from('jobs')
        .select()
        .eq('status', 'open')
        .eq('visibility', 'open')
        .neq('client_id', uid)
        .order('created_at', ascending: false)
        .limit(50);
    final jobs = rows.map(Job.fromMap).where((j) => slugSetMatchesCategory(mine, j.category)).toList();
    final quoted = await _client.from('quotes').select('job_id').eq('provider_id', uid);
    final quotedIds = {for (final q in quoted) q['job_id'] as String};
    return jobs.where((j) => !quotedIds.contains(j.id) && j.quoteCount < 3).toList();
  }

  /// Serviços em que o profissional é o contratado.
  Future<List<Job>> providerJobs() async {
    final rows = await _client
        .from('jobs')
        .select()
        .eq('provider_id', uid)
        .order('created_at', ascending: false);
    return rows.map(Job.fromMap).toList();
  }

  Stream<List<Job>> streamProviderJobs() => _reactiveJobStream(
        realtimeFactory: () => _client
            .from('jobs')
            .stream(primaryKey: ['id'])
            .eq('provider_id', uid)
            .order('created_at', ascending: false)
            .map((rows) => rows.map(Job.fromMap).toList()),
        fetchFallback: providerJobs,
      );

  /// Orçamentos que o profissional enviou e ainda aguardam resposta.
  Future<List<({Quote quote, Job? job})>> myPendingQuotes() async {
    final rows = await _client
        .from('quotes')
        .select()
        .eq('provider_id', uid)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    final quotes = rows.map(Quote.fromMap).toList();
    if (quotes.isEmpty) return [];
    final jobs = await _client.from('jobs').select().inFilter('id', quotes.map((q) => q.jobId).toList());
    final byId = {for (final j in jobs.map(Job.fromMap)) j.id: j};
    return [for (final q in quotes) (quote: q, job: byId[q.jobId])];
  }

  // -------------------------------------------------------------- evidências

  Future<List<Map<String, dynamic>>> evidence(String jobId) async {
    final rows = await _client.from('job_evidence').select().eq('job_id', jobId);
    return rows.cast<Map<String, dynamic>>();
  }

  Future<void> addEvidence({
    required String jobId,
    required String slot,
    required Uint8List bytes,
    required String ext,
  }) async {
    final media = MediaService(_client);
    final path = await media.uploadPrivate(bytes, ext, prefix: 'ev_$slot');
    // Sem UPDATE liberado na tabela: substitui removendo a anterior do mesmo slot.
    await _client.from('job_evidence').delete().eq('job_id', jobId).eq('slot', slot);
    await _client.from('job_evidence').insert(
      {'job_id': jobId, 'provider_id': uid, 'slot': slot, 'path': path},
    );
  }

  /// Relatório técnico já salvo do pedido (null se ainda não existe).
  Future<String?> jobReport(String jobId) async {
    final row = await _client.from('jobs').select('provider_report').eq('id', jobId).maybeSingle();
    return row?['provider_report'] as String?;
  }

  Future<void> removeEvidence(String id) => _client.from('job_evidence').delete().eq('id', id);
}

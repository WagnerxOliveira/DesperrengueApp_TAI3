import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/marketplace_models.dart';
import '../utils/order_utils.dart';

/// Máquina de estados reativa O(1) para controle de leitura e badges das abas de `Meus Pedidos`
/// (`Em Andamento`, `Concluídos`, `Cancelados` e `Em Mediação`).
///
/// Garante decremento síncrono imediato (`0 ms`) na UI no exato frame do toque do usuário,
/// persistência durável por `userId` em `SharedPreferences`, e re-notificação automática caso
/// o pedido mude de estado, profissional ou valor acordado.
class UnreadOrdersBadgeController extends ChangeNotifier {
  UnreadOrdersBadgeController({
    this.currentUserIdResolver,
  });

  static final UnreadOrdersBadgeController instance = UnreadOrdersBadgeController();

  final String Function()? currentUserIdResolver;

  static const String _kPrefsPrefix = 'carbon_viewed_orders_v1_';
  static const int _kMaxStoredSignaturesPerUser = 1000;

  final Map<String, Set<String>> _viewedByUser = <String, Set<String>>{};
  final Set<String> _loadedUsers = <String>{};
  final Map<String, Future<void>> _loadingByUser = <String, Future<void>>{};

  /// Mapeamento determinístico de [JobStatus] para a aba correspondente em `Meus Pedidos`.
  static OrderTab tabForStatus(JobStatus status) => switch (status) {
        JobStatus.completed => OrderTab.completed,
        JobStatus.canceled => OrderTab.canceled,
        JobStatus.disputed => OrderTab.mediation,
        JobStatus.open ||
        JobStatus.awaitingPayment ||
        JobStatus.scheduled ||
        JobStatus.inProgress ||
        JobStatus.awaitingApproval =>
          OrderTab.inProgress,
      };

  static String _formatPricePart(double? price) {
    if (price == null || price <= 0) return '';
    return price.toStringAsFixed(2);
  }

  static String _buildSignature({
    required String jobId,
    required OrderTab tab,
    required String statusName,
    required String? providerId,
    required double? price,
  }) {
    final cleanProvider = (providerId ?? '').trim();
    final pricePart = _formatPricePart(price);
    return '$jobId|${tab.name}|$statusName|$cleanProvider|$pricePart';
  }

  /// Calcula a assinatura determinística do estado atual de [job].
  ///
  /// Se o pedido mudar de status, aba, profissional atribuído ou preço acordado,
  /// uma nova assinatura é produzida e o pedido volta a aparecer como não lido;
  /// enquanto permanecer no mesmo estado, uma vez aberto fica marcado como lido.
  static String computeStateSignature(Job job, {OrderTab? tab}) {
    final effectiveTab = tab ?? tabForStatus(job.status);
    return _buildSignature(
      jobId: job.id,
      tab: effectiveTab,
      statusName: job.status.name,
      providerId: job.providerId,
      price: job.agreedPrice,
    );
  }

  String _resolveUserId(String? userId) {
    final explicit = userId?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    if (currentUserIdResolver != null) {
      final resolved = currentUserIdResolver!().trim();
      if (resolved.isNotEmpty) return resolved;
    }
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null && uid.trim().isNotEmpty) return uid.trim();
    } catch (_) {
      // Supabase não inicializado em testes de widget/unitários: usa escopo padrão 'current'.
    }
    return 'current';
  }

  static String _prefsKey(String uid) => '$_kPrefsPrefix$uid';

  /// Hidrata do `SharedPreferences` uma única vez por [userId], fazendo união (`addAll`)
  /// sem jamais sobrescrever leituras já marcadas sincronamente em memória.
  Future<void> ensureLoaded({String? userId}) {
    final uid = _resolveUserId(userId);
    if (_loadedUsers.contains(uid)) return Future<void>.value();
    return _loadingByUser[uid] ??= _doLoadUser(uid);
  }

  Future<void> _doLoadUser(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_prefsKey(uid)) ?? const <String>[];
      final memSet = _viewedByUser.putIfAbsent(uid, () => <String>{});
      final beforeLen = memSet.length;
      memSet.addAll(stored);
      _loadedUsers.add(uid);
      if (memSet.length != beforeLen) {
        notifyListeners();
      }
    } catch (_) {
      _loadedUsers.add(uid);
    } finally {
      _loadingByUser.remove(uid);
    }
  }

  /// Consulta em `O(1)` se [job] ainda não foi aberto/visualizado em seu estado atual.
  bool isUnread(Job job, {String? userId, OrderTab? tab}) {
    final uid = _resolveUserId(userId);
    final set = _viewedByUser[uid];
    if (set == null || set.isEmpty) return true;
    final effectiveTab = tab ?? tabForStatus(job.status);
    final sig = computeStateSignature(job, tab: effectiveTab);
    if (set.contains(sig)) return false;
    final terminalFallback = 'status_only:${job.id}|${effectiveTab.name}|${job.status.name}';
    if (set.contains(terminalFallback)) return false;
    return true;
  }

  /// Conta estritamente quantos pedidos de [jobs] na aba [tab] ainda NÃO foram visualizados.
  int countUnread(OrderTab tab, Iterable<Job> jobs, {String? userId}) {
    final uid = _resolveUserId(userId);
    final set = _viewedByUser[uid];
    var unread = 0;
    for (final job in jobs) {
      if (set == null || set.isEmpty) {
        unread++;
        continue;
      }
      final sig = computeStateSignature(job, tab: tab);
      if (set.contains(sig)) continue;
      final terminalFallback = 'status_only:${job.id}|${tab.name}|${job.status.name}';
      if (set.contains(terminalFallback)) continue;
      unread++;
    }
    return unread;
  }

  /// Marca [job] como visualizado:
  /// Atualiza o `Set<String>` em memória na **primeira linha síncrona** e dispara
  /// `notifyListeners()` imediatamente (`0 ms`) ANTES da persistência assíncrona no `SharedPreferences`.
  Future<void> markViewed(Job job, {String? userId, OrderTab? tab}) {
    final uid = _resolveUserId(userId);
    final sig = computeStateSignature(job, tab: tab);
    final set = _viewedByUser.putIfAbsent(uid, () => <String>{});
    final changed = set.add(sig);
    if (changed) {
      notifyListeners();
    }
    return _persistUserSet(uid);
  }

  /// Marca um pedido como visualizado quando `DetalheServicoClienteScreen` é aberto diretamente via `jobId`.
  /// Também executa atualização em memória e `notifyListeners()` de forma 100% síncrona (`0 ms`).
  Future<void> markViewedByIdAndStatus({
    required String jobId,
    required JobStatus status,
    String? userId,
    String? providerId,
    double? price,
  }) {
    final uid = _resolveUserId(userId);
    final effectiveTab = tabForStatus(status);
    final sig = _buildSignature(
      jobId: jobId,
      tab: effectiveTab,
      statusName: status.name,
      providerId: providerId,
      price: price,
    );
    final set = _viewedByUser.putIfAbsent(uid, () => <String>{});
    var changed = set.add(sig);
    if (providerId == null &&
        price == null &&
        (status == JobStatus.completed ||
            status == JobStatus.canceled ||
            status == JobStatus.disputed)) {
      changed = set.add('status_only:$jobId|${effectiveTab.name}|${status.name}') || changed;
    }
    if (changed) {
      notifyListeners();
    }
    return _persistUserSet(uid);
  }

  /// Escritas em andamento por usuário: `markViewed` em sequência (ex.: abrir 30
  /// pedidos) coalesce em NO MÁXIMO uma escrita ativa + uma pendente, em vez de
  /// 30 gravações de até 1000 assinaturas.
  final Map<String, Future<void>> _persistInFlight = <String, Future<void>>{};
  final Set<String> _persistDirty = <String>{};

  Future<void> _persistUserSet(String uid) {
    final running = _persistInFlight[uid];
    if (running != null) {
      _persistDirty.add(uid); // o loop abaixo regrava com o estado mais novo
      return running;
    }
    // ATENÇÃO: o callback NÃO pode retornar o valor de `remove` (é o próprio Future;
    // `whenComplete` aguardaria a si mesmo = deadlock).
    final f = _persistLoop(uid).whenComplete(() {
      _persistInFlight.remove(uid);
    });
    _persistInFlight[uid] = f;
    return f;
  }

  Future<void> _persistLoop(String uid) async {
    do {
      _persistDirty.remove(uid);
      await _persistOnce(uid);
    } while (_persistDirty.contains(uid));
  }

  Future<void> _persistOnce(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _prefsKey(uid);
      final set = _viewedByUser.putIfAbsent(uid, () => <String>{});
      if (!_loadedUsers.contains(uid)) {
        final existing = prefs.getStringList(key) ?? const <String>[];
        set.addAll(existing);
        _loadedUsers.add(uid);
      }
      // Limita também a memória (antes só o disco era limitado): descarta as
      // assinaturas mais antigas (ordem de inserção do LinkedHashSet).
      if (set.length > _kMaxStoredSignaturesPerUser) {
        final drop = set.length - _kMaxStoredSignaturesPerUser;
        for (final old in set.take(drop).toList()) {
          set.remove(old);
        }
      }
      await prefs.setStringList(key, set.toList());
    } catch (_) {
      // Falha de armazenamento local nunca interrompe a UI.
    }
  }
  @visibleForTesting
  void resetForTesting() {
    _viewedByUser.clear();
    _loadedUsers.clear();
    _loadingByUser.clear();
    _persistDirty.clear();
    _persistInFlight.clear();
    notifyListeners();
  }
}

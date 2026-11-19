import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../storage/local_prefs.dart';

/// Rastreador de estado da apresentação cinematográfica pós-cadastro
/// (`DesperrengueWelcomeCinemaScreen`).
///
/// Garante que todo novo cadastro (via E-mail + OTP ou 1º acesso OAuth)
/// assista à apresentação ininterrupta exatamente uma vez antes da
/// `RoleSelectionScreen`, sem bloquear contas antigas nem suítes de teste
/// legadas que instanciam `PostAuthRouter` diretamente.
class WelcomeCinemaTracker {
  WelcomeCinemaTracker._();

  static const String keyPrefixSeen = 'welcome_cinema_v3_seen_';
  static const String keyPendingUid = 'welcome_cinema_v3_pending_uid';

  static final Set<String> _completedInMemory = <String>{};
  static String? _armedUidInMemory;

  /// Chamado logo após a criação de cadastro (ex: verificação OTP de signup).
  static Future<void> armForFreshRegistration([String? userId]) async {
    final normalized =
        (userId != null && userId.trim().isNotEmpty) ? userId.trim() : '*';
    _armedUidInMemory = normalized;
    if (normalized != '*') {
      _completedInMemory.remove(normalized);
    }
    await LocalPrefs.write(keyPendingUid, normalized);
  }

  /// Chamado quando a animação ininterrupta conclui 100%.
  static Future<void> markCompleted(String userId) async {
    final cleanId = userId.trim();
    if (cleanId.isEmpty) return;
    _completedInMemory.add(cleanId);
    if (_armedUidInMemory == cleanId || _armedUidInMemory == '*') {
      _armedUidInMemory = null;
    }
    await LocalPrefs.write('$keyPrefixSeen$cleanId', '1');
    final pending = await LocalPrefs.read(keyPendingUid);
    if (pending == cleanId || pending == '*') {
      await LocalPrefs.remove(keyPendingUid);
    }
  }

  /// Verifica se a animação deve tocar agora antes da RoleSelectionScreen:
  /// Retorna `true` quando:
  ///   1) `!forceSelection` E `!profile.isClient` E `!profile.isProvider` E `!profile.isAdmin`
  ///   2) E o usuário ainda NÃO viu (`seen != '1'`)
  ///   3) E (`pendingUid == profile.id` OU `pendingUid == '*'` OU `(authCreatedAt != null && referenceNow.difference(authCreatedAt.toUtc()).inMinutes <= 30)`).
  /// Isso garante que:
  ///   - Todo novo cadastro (seja por E-mail+OTP ou 1º acesso Google OAuth) vê a animação ininterrupta!
  ///   - Testes unitários/widget legados sem `armForFreshRegistration` e sem `authCreatedAt` recente NÃO são bloqueados acidentalmente!
  static Future<bool> shouldShowBeforeRoleSelection({
    required UserProfile profile,
    DateTime? authCreatedAt,
    bool forceSelection = false,
    DateTime? referenceNow,
  }) async {
    if (forceSelection ||
        profile.isClient ||
        profile.isProvider ||
        profile.isAdmin) {
      return false;
    }

    final cleanId = profile.id.trim();
    if (cleanId.isEmpty) return false;

    if (_completedInMemory.contains(cleanId)) {
      return false;
    }

    final seen = await LocalPrefs.read('$keyPrefixSeen$cleanId');
    if (seen == '1') {
      _completedInMemory.add(cleanId);
      return false;
    }

    final pendingFromPrefs = await LocalPrefs.read(keyPendingUid);
    final pendingUid = _armedUidInMemory ?? pendingFromPrefs;
    final isArmedForUser = pendingUid == cleanId || pendingUid == '*';

    var isRecentAuth = false;
    if (authCreatedAt != null) {
      final nowUtc = (referenceNow ?? DateTime.now()).toUtc();
      final diffMinutes = nowUtc.difference(authCreatedAt.toUtc()).inMinutes;
      isRecentAuth = diffMinutes >= -5 && diffMinutes <= 30;
    }

    return isArmedForUser || isRecentAuth;
  }

  /// Verificação síncrona em memória para evitar flash claro durante o
  /// carregamento inicial do `PostAuthRouter` logo após signup OTP ou OAuth.
  static bool isLikelyFreshAuthInMemory({
    String? userId,
    DateTime? authCreatedAt,
    DateTime? referenceNow,
  }) {
    final cleanUid = userId?.trim();
    if (cleanUid != null &&
        cleanUid.isNotEmpty &&
        _completedInMemory.contains(cleanUid)) {
      return false;
    }
    final armed = _armedUidInMemory;
    if (armed != null && !_completedInMemory.contains(armed)) {
      return true;
    }
    if (cleanUid == null && _completedInMemory.isNotEmpty) {
      return false;
    }
    if (authCreatedAt != null) {
      final nowUtc = (referenceNow ?? DateTime.now()).toUtc();
      final diffMinutes = nowUtc.difference(authCreatedAt.toUtc()).inMinutes;
      return diffMinutes >= -5 && diffMinutes <= 30;
    }
    return false;
  }

  @visibleForTesting
  static void resetMemoryStateForTesting() {
    _completedInMemory.clear();
    _armedUidInMemory = null;
  }
}

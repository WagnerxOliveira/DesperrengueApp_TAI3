/// Camada de Dados, Criptografia Cliente (`PBKDF2-HMAC-SHA256` 210.000 rodadas),
/// Ponte `FLAG_SECURE`, Autoridade Isolada `ceo-vault-authority` e Coordenador
/// WebSocket em Tempo Real (`WSS TLS 1.3`) do `Desperrengue CEO`.
///
/// Regras arquiteturais inegociáveis:
/// - **Zero Cross-App Redirect**: proibido `signInWithOAuth` / `OAuthProvider` / navegador
///   externo. Toda sessão JWT do titular único é emitida no servidor (`ceo-vault-authority`)
///   e hidratada in-app via `setSession`.
/// - **Zero dados falsos (`Zero-Fake Policy`)**: zero valores pré-preenchidos e zero mocks.
/// - **Exclusividade Monocrática**: único titular aceito é `wagneroliveira2395@gmail.com`.
/// - **Custódia Dividida + AES-256**: `PBKDF2-HMAC-SHA256` (`210.000` rodadas) fora da UI
///   thread + zeroização de RAM -> `CEO_VAULT_EDGE_PEPPER` -> `HMAC-SHA512 x 25.000` + `AES-256`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/analytics/founder_dashboard_models.dart';
import '../../../core/utils/off_thread.dart';
import '../domain/ceo_smart_otp_formatter.dart';
import '../domain/ceo_strong_password_policy.dart';

/// Sessão autenticada de Step-Up Zero-Trust do Cofre Monocrático CEO.
class FounderStepUpSession {
  const FounderStepUpSession({
    required this.stepUpCredentialHex,
    required this.userId,
    required this.accountEmail,
    required this.deviceHashHex,
    required this.expiresAtUtc,
    this.passwordVersion = 1,
  });

  final String stepUpCredentialHex;
  final String userId;
  final String accountEmail;
  final String deviceHashHex;
  final DateTime expiresAtUtc;
  final int passwordVersion;

  bool isExpiredAt(DateTime nowUtc) => !expiresAtUtc.isAfter(nowUtc.toUtc());
}

/// Estado pré-autenticação retornado por `inspect_gate` (sem disparar e-mail).
class CeoGateInspectionResult {
  const CeoGateInspectionResult({
    required this.ownerEmail,
    required this.passwordConfigured,
    required this.passwordVersion,
    this.passwordUpdatedAtUtc,
    this.lockedUntilUtc,
  });

  final String ownerEmail;
  final bool passwordConfigured;
  final int passwordVersion;
  final DateTime? passwordUpdatedAtUtc;
  final DateTime? lockedUntilUtc;

  bool isLockedAt(DateTime nowUtc) =>
      lockedUntilUtc != null && lockedUntilUtc!.isAfter(nowUtc.toUtc());
}

/// Telemetria criptográfica exibida no Perfil Soberano do CEO.
class CeoProfileSecurityStatus {
  const CeoProfileSecurityStatus({
    required this.ownerEmail,
    required this.passwordConfigured,
    required this.passwordVersion,
    required this.kdfSpec,
    required this.activeSessionsCount,
    required this.protectedHistoryDepth,
    required this.deviceHashPrefix,
    this.passwordUpdatedAtUtc,
    this.lastLoginAtUtc,
  });

  final String ownerEmail;
  final bool passwordConfigured;
  final int passwordVersion;
  final String kdfSpec;
  final int activeSessionsCount;
  final int protectedHistoryDepth;
  final String deviceHashPrefix;
  final DateTime? passwordUpdatedAtUtc;
  final DateTime? lastLoginAtUtc;

  factory CeoProfileSecurityStatus.fromJson(Map<String, dynamic> json) {
    return CeoProfileSecurityStatus(
      ownerEmail: (json['owner_email'] ?? kMonocraticCeoEmail).toString(),
      passwordConfigured: json['password_configured'] != false,
      passwordVersion: (json['password_version'] is num)
          ? (json['password_version'] as num).round()
          : 1,
      kdfSpec: (json['kdf_spec'] ??
              'edge:pbkdf2-sha256:210000+hmac-sha256|db:hmac-sha512:25000+pgp-aes256')
          .toString(),
      activeSessionsCount: (json['active_sessions_count'] is num)
          ? (json['active_sessions_count'] as num).round()
          : 1,
      protectedHistoryDepth: (json['protected_history_depth'] is num)
          ? (json['protected_history_depth'] as num).round()
          : 1,
      deviceHashPrefix: (json['device_hash_prefix'] ?? '').toString(),
      passwordUpdatedAtUtc: DateTime.tryParse(
        (json['password_updated_at'] ?? '').toString(),
      )?.toUtc(),
      lastLoginAtUtc: DateTime.tryParse(
        (json['last_login_at'] ?? '').toString(),
      )?.toUtc(),
    );
  }
}

/// Resposta da solicitação do código exclusivo de 6 dígitos enviado a `wagneroliveira2395@gmail.com`.
class CeoOtpChallengeTicket {
  CeoOtpChallengeTicket({
    required this.challengeId,
    required this.maskedDestination,
    required this.expiresAtUtc,
    required this.nextCooldownSeconds,
    required this.purpose,
    String? challengeRef,
    DateTime? issuedAtUtc,
  })  : challengeRef = (challengeRef != null && challengeRef.trim().isNotEmpty)
            ? challengeRef.trim().toUpperCase()
            : deriveRefFromChallengeId(challengeId),
        issuedAtUtc = (issuedAtUtc ?? DateTime.now().toUtc()).toUtc();

  final String challengeId;
  final String challengeRef;
  final DateTime issuedAtUtc;
  final String maskedDestination;
  final DateTime expiresAtUtc;
  final int nextCooldownSeconds;
  final String purpose;

  bool isExpiredAt(DateTime nowUtc) => !expiresAtUtc.isAfter(nowUtc.toUtc());

  static String deriveRefFromChallengeId(String rawId) {
    final hex = rawId.replaceAll('-', '').trim().toUpperCase();
    return hex.length >= 4 ? hex.substring(0, 4) : '0000';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'challenge_id': challengeId,
        'challenge_ref': challengeRef,
        'issued_at': issuedAtUtc.toIso8601String(),
        'masked_destination': maskedDestination,
        'expires_at': expiresAtUtc.toIso8601String(),
        'next_cooldown_seconds': nextCooldownSeconds,
        'purpose': purpose,
      };

  factory CeoOtpChallengeTicket.fromJson(Map<String, dynamic> json) {
    final cid = (json['challenge_id'] ?? '').toString().trim();
    return CeoOtpChallengeTicket(
      challengeId: cid,
      challengeRef: (json['challenge_ref'] ?? '').toString(),
      issuedAtUtc:
          DateTime.tryParse((json['issued_at'] ?? '').toString())?.toUtc(),
      maskedDestination:
          (json['masked_destination'] ?? kMonocraticCeoEmail).toString(),
      expiresAtUtc:
          DateTime.tryParse((json['expires_at'] ?? '').toString())?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      nextCooldownSeconds: (json['next_cooldown_seconds'] is num)
          ? (json['next_cooldown_seconds'] as num).round()
          : 30,
      purpose: (json['purpose'] ?? '').toString(),
    );
  }
}

/// Exceção tipada e estruturada do Cofre Monocrático CEO.
class CeoVaultSecurityException implements Exception {
  const CeoVaultSecurityException({
    required this.errorCode,
    required this.userMessagePt,
    this.remainingAttempts,
    this.failedAttempts,
    this.lockedUntilUtc,
    this.retryAfterSeconds,
    this.latestChallengeRef,
    this.failedPolicyRules = const <String>[],
  });

  final String errorCode;
  final String userMessagePt;
  final int? remainingAttempts;
  final int? failedAttempts;
  final DateTime? lockedUntilUtc;
  final int? retryAfterSeconds;
  final String? latestChallengeRef;
  final List<String> failedPolicyRules;

  @override
  String toString() => '$errorCode: $userMessagePt';
}

/// Estado nativo da blindagem óptica Android (`FLAG_SECURE`).
class CeoScreenProtectionState {
  const CeoScreenProtectionState({
    required this.flagSecureActive,
    required this.temporaryCaptureAllowed,
    required this.remainingCaptureSeconds,
  });

  final bool flagSecureActive;
  final bool temporaryCaptureAllowed;
  final int remainingCaptureSeconds;

  static const CeoScreenProtectionState lockedDefault =
      CeoScreenProtectionState(
    flagSecureActive: true,
    temporaryCaptureAllowed: false,
    remainingCaptureSeconds: 0,
  );

  factory CeoScreenProtectionState.fromMap(Map<dynamic, dynamic> map) {
    final active = map['flagSecureActive'] != false;
    final tempAllowed = map['temporaryCaptureAllowed'] == true;
    final remMs = (map['remainingCaptureMs'] is num)
        ? (map['remainingCaptureMs'] as num).round()
        : 0;
    return CeoScreenProtectionState(
      flagSecureActive: active,
      temporaryCaptureAllowed: tempAllowed,
      remainingCaptureSeconds: ((remMs + 999) ~/ 1000).clamp(0, 300),
    );
  }
}

/// Ponte nativa `MethodChannel` para controle de `FLAG_SECURE` no APK `founder`.
class CeoScreenSecurityBridge {
  const CeoScreenSecurityBridge();

  static const MethodChannel _channel = MethodChannel(
    'br.com.desperrengue.app.founder/security',
  );

  Future<CeoScreenProtectionState> getProtectionStatus() async {
    if (kIsWeb) return CeoScreenProtectionState.lockedDefault;
    try {
      final raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getScreenProtectionStatus');
      if (raw != null) {
        return CeoScreenProtectionState.fromMap(raw);
      }
    } catch (_) {}
    return CeoScreenProtectionState.lockedDefault;
  }

  Future<CeoScreenProtectionState> setTemporaryCaptureAllowed({
    required bool allow,
    int durationSeconds = 300,
  }) async {
    if (kIsWeb) return CeoScreenProtectionState.lockedDefault;
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'setTemporaryCaptureAllowed',
        <String, dynamic>{
          'allow': allow,
          'durationSeconds': durationSeconds.clamp(30, 300),
        },
      );
      if (raw != null) {
        return CeoScreenProtectionState.fromMap(raw);
      }
    } catch (_) {}
    return CeoScreenProtectionState.lockedDefault;
  }
}

/// Motor Criptográfico Cliente (`PBKDF2-HMAC-SHA256` RFC 8018 §5.2 — 210.000 rodadas)
/// compatível bit a bit com `WebCrypto.subtle.deriveBits('PBKDF2')` na Edge Function.
class CeoMasterPasswordCryptoEngine {
  const CeoMasterPasswordCryptoEngine._();

  static const int defaultIterations = 210000;
  static const String domainSalt =
      'DESPERRENGUE_CEO_MASTER_PW_V2:$kMonocraticCeoEmail';

  static String _bytesToLowerHex(Uint8List bytes) {
    final sb = StringBuffer();
    for (var i = 0; i < bytes.length; i++) {
      sb.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  /// Deriva `CK` (`CHAR(64)` hexadecimal, 256 bits) via `PBKDF2-HMAC-SHA256`
  /// e sobrescreve todos os buffers temporários de RAM com zeros antes de retornar.
  static String deriveClientKeySync(
    String rawPassword, {
    int iterations = defaultIterations,
  }) {
    final rounds = iterations.clamp(1000, 600000);
    final pwBytes = Uint8List.fromList(utf8.encode(rawPassword));
    final saltBytes = Uint8List.fromList(utf8.encode(domainSalt));
    final block1Input = Uint8List(saltBytes.length + 4);
    block1Input.setRange(0, saltBytes.length, saltBytes);
    block1Input[saltBytes.length] = 0;
    block1Input[saltBytes.length + 1] = 0;
    block1Input[saltBytes.length + 2] = 0;
    block1Input[saltBytes.length + 3] = 1;

    final t = Uint8List(32);
    var u = Uint8List(32);

    try {
      final hmac = Hmac(sha256, pwBytes);
      final first = hmac.convert(block1Input).bytes;
      for (var j = 0; j < 32; j++) {
        u[j] = first[j];
        t[j] = first[j];
      }

      for (var i = 1; i < rounds; i++) {
        final next = hmac.convert(u).bytes;
        for (var j = 0; j < 32; j++) {
          u[j] = next[j];
          t[j] ^= next[j];
        }
      }

      return _bytesToLowerHex(t);
    } finally {
      pwBytes.fillRange(0, pwBytes.length, 0);
      saltBytes.fillRange(0, saltBytes.length, 0);
      block1Input.fillRange(0, block1Input.length, 0);
      t.fillRange(0, t.length, 0);
      u.fillRange(0, u.length, 0);
    }
  }

  /// Executa `PBKDF2-HMAC-SHA256` fora da UI thread para preservar animações a 120 FPS.
  static Future<String> deriveClientKeyOffThread(
    String rawPassword, {
    int iterations = defaultIterations,
  }) {
    return runOffMainThread(
      () => deriveClientKeySync(rawPassword, iterations: iterations),
    );
  }
}

/// Estado de conexão da ponte em tempo real (`WSS TLS 1.3`).
enum CeoRealtimeConnectionStatus {
  disconnected,
  connecting,
  liveConnected,
  reconnecting,
}

/// Contrato de transporte injetável para produção (`SupabaseCeoBackendGateway`) e suítes Red-Team.
abstract class CeoBackendGateway {
  String? get currentUserEmail;
  String? get currentUserId;
  Stream<String?> get authEmailChanges;

  /// Hidrata in-app a sessão JWT emitida por `ceo-vault-authority` sem abrir navegador externo.
  Future<void> hydrateSovereignSession({
    required String accessToken,
    required String refreshToken,
  });

  Future<void> signOut();

  Future<void> reportIntrusionCanary({
    required String canaryCode,
    required Map<String, dynamic> meta,
  });

  Future<Map<String, dynamic>> invokeVaultAuthority(Map<String, dynamic> body);

  Future<Map<String, dynamic>> callRpc(
    String functionName,
    Map<String, dynamic> params,
  );

  Future<void Function()> subscribeWarRoomLive({
    required void Function(CeoLiveEventItem event) onLiveEvent,
    required void Function(CeoRealtimeConnectionStatus status) onStatusChanged,
  });
}

/// Implementação oficial de Produção conectada 100% ao Supabase (`eisfkemgooqbgqljvwvs`).
class SupabaseCeoBackendGateway implements CeoBackendGateway {
  SupabaseCeoBackendGateway({SupabaseClient? client}) : _explicitClient = client;

  final SupabaseClient? _explicitClient;

  SupabaseClient get _client => _explicitClient ?? Supabase.instance.client;

  @override
  String? get currentUserEmail {
    try {
      return _client.auth.currentUser?.email?.trim().toLowerCase();
    } catch (_) {
      return null;
    }
  }

  @override
  String? get currentUserId {
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<String?> get authEmailChanges {
    try {
      return _client.auth.onAuthStateChange.map(
        (state) => state.session?.user.email?.trim().toLowerCase(),
      );
    } catch (_) {
      return const Stream<String?>.empty();
    }
  }

  @override
  Future<void> hydrateSovereignSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _client.auth.setSession(
      refreshToken,
      accessToken: accessToken,
    );
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }

  @override
  Future<void> reportIntrusionCanary({
    required String canaryCode,
    required Map<String, dynamic> meta,
  }) async {
    try {
      await _client.rpc<dynamic>(
        'founder_report_security_canary',
        params: <String, dynamic>{
          'p_canary_code': canaryCode,
          'p_meta': meta,
        },
      );
    } catch (_) {}
  }

  static Map<String, dynamic>? _tryDecodeMapPayload(dynamic payload) {
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    if (payload is List<int> && payload.isNotEmpty) {
      try {
        final str = utf8.decode(payload, allowMalformed: true).trim();
        if (str.isNotEmpty) {
          final decoded = jsonDecode(str);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    if (payload is String && payload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> invokeVaultAuthority(
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _client.functions.invoke(
        'ceo-vault-authority',
        body: body,
      );
      final parsed = _tryDecodeMapPayload(res.data);
      if (parsed != null) return parsed;
      return const <String, dynamic>{
        'ok': false,
        'error_code': 'ERR_OTP_VERIFICATION_FAILED',
      };
    } on FunctionException catch (e) {
      final parsedDetails = _tryDecodeMapPayload(e.details);
      if (parsedDetails != null) return parsedDetails;
      return <String, dynamic>{
        'ok': false,
        'error_code': 'ERR_EDGE_HTTP_${e.status}',
      };
    }
  }

  @override
  Future<Map<String, dynamic>> callRpc(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    try {
      final raw = await _client.rpc<dynamic>(functionName, params: params);
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return const <String, dynamic>{};
    } on PostgrestException catch (e) {
      throw CeoVaultSecurityException(
        errorCode: e.code ?? 'ERR_PG_DENIED',
        userMessagePt: _translateSecurityError(e.message),
      );
    }
  }

  @override
  Future<void Function()> subscribeWarRoomLive({
    required void Function(CeoLiveEventItem event) onLiveEvent,
    required void Function(CeoRealtimeConnectionStatus status) onStatusChanged,
  }) async {
    onStatusChanged(CeoRealtimeConnectionStatus.connecting);
    final channel = _client.channel(
      'ceo:war-room:live',
      opts: const RealtimeChannelConfig(private: true),
    );

    channel
        .onBroadcast(
          event: 'ceo_live_event',
          callback: (payload) {
            final inner = payload['payload'];
            final eventMap = inner is Map
                ? Map<String, dynamic>.from(inner)
                : Map<String, dynamic>.from(payload);
            if (eventMap.containsKey('event_seq') ||
                eventMap.containsKey('event_type')) {
              onLiveEvent(CeoLiveEventItem.fromJson(eventMap));
            }
          },
        )
        .subscribe((status, [error]) {
          switch (status) {
            case RealtimeSubscribeStatus.subscribed:
              onStatusChanged(CeoRealtimeConnectionStatus.liveConnected);
            case RealtimeSubscribeStatus.timedOut:
            case RealtimeSubscribeStatus.channelError:
              onStatusChanged(CeoRealtimeConnectionStatus.reconnecting);
            case RealtimeSubscribeStatus.closed:
              onStatusChanged(CeoRealtimeConnectionStatus.disconnected);
          }
        });

    return () async {
      onStatusChanged(CeoRealtimeConnectionStatus.disconnected);
      try {
        await _client.removeChannel(channel);
      } catch (_) {}
    };
  }
}

String _translateSecurityError(
  String rawCodeOrMessage, {
  String? latestChallengeRef,
}) {
  final msg = rawCodeOrMessage.trim();
  final cleanRef = (latestChallengeRef ?? '').trim().toUpperCase();

  if (msg.contains('ERR_MONOCRATIC_OWNER_ONLY')) {
    return 'Acesso bloqueado: o aplicativo Desperrengue CEO é restrito exclusivamente ao titular soberano ($kMonocraticCeoEmail).';
  }
  if (msg.contains('ERR_UNAUTHENTICATED') ||
      msg.contains('ERR_MISSING_BEARER_TOKEN') ||
      msg.contains('ERR_INVALID_OR_EXPIRED_JWT')) {
    return 'Sua sessão soberana expirou. Valide sua Senha Mestra e o código de 6 dígitos para entrar.';
  }
  if (msg.contains('ERR_STEPUP_SESSION_EXPIRED_OR_REVOKED') ||
      msg.contains('ERR_STEPUP_SESSION_EXPIRED_OR_INVALID')) {
    return 'Sessão do Cofre encerrada ou rotacionada. Faça login com sua Senha Mestra e código de 6 dígitos.';
  }
  if (msg.contains('ERR_MASTER_PASSWORD_NOT_CONFIGURED')) {
    return 'Sua Senha Mestra ainda não foi criada. Conclua a cerimônia de primeiro acesso.';
  }
  if (msg.contains('ERR_VAULT_ALREADY_SEALED')) {
    return 'Sua Senha Mestra já está ativa no Cofre Soberano. Utilize a tela de entrada com senha.';
  }
  if (msg.contains('ERR_INVALID_MASTER_PASSWORD')) {
    return 'Senha Mestra incorreta. Verifique maiúsculas, minúsculas, números e símbolos informados.';
  }
  if (msg.contains('ERR_VAULT_LOCKED_BACKOFF')) {
    return 'Cofre temporariamente bloqueado após tentativas consecutivas incorretas. Aguarde o temporizador de segurança.';
  }
  if (msg.contains('ERR_WEAK_PASSWORD_POLICY')) {
    return 'A senha precisa ter entre 12 e 64 caracteres, incluindo letra maiúscula, minúscula, número, símbolo especial e alta entropia.';
  }
  if (msg.contains('ERR_PASSWORD_REUSE_FORBIDDEN')) {
    return 'Por segurança extrema, escolha uma Senha Mestra inédita (diferente da senha atual e das últimas 5 senhas).';
  }
  if (msg.contains('ERR_OTP_COOLDOWN_ACTIVE')) {
    return 'Aguarde o intervalo de proteção antes de solicitar um novo código de 6 dígitos.';
  }
  if (msg.contains('ERR_OTP_SUPERSEDED_BY_NEWER_EMAIL')) {
    final refSuffix = cleanRef.isNotEmpty ? ' (Protocolo #$cleanRef)' : '';
    return 'Você informou o código de um e-mail anterior já substituído. Abra o e-mail mais recente$refSuffix enviado para $kMonocraticCeoEmail.';
  }
  if (msg.contains('ERR_OTP_CODE_INCORRECT')) {
    final refSuffix = cleanRef.isNotEmpty ? ' (Protocolo #$cleanRef)' : '';
    return 'Código de 6 dígitos incorreto. Confira o código do e-mail$refSuffix enviado para $kMonocraticCeoEmail.';
  }
  if (msg.contains('ERR_OTP_DEVICE_MISMATCH')) {
    return 'Este código foi solicitado em outra sessão ou instância. Toque em "Reenviar código" para gerar um novo neste aparelho.';
  }
  if (msg.contains('ERR_OTP_MAX_ATTEMPTS_EXCEEDED')) {
    return 'Limite de 5 tentativas atingido para este código. Toque em "Reenviar código" para receber um novo.';
  }
  if (msg.contains('ERR_OTP_EXPIRED')) {
    return 'Este código de 6 dígitos expirou (validade de 10 minutos). Toque em "Reenviar código" para receber um novo.';
  }
  if (msg.contains('ERR_OTP_ALREADY_USED')) {
    return 'Este código de 6 dígitos já foi utilizado ou substituído. Solicite um novo código seguro.';
  }
  if (msg.contains('ERR_OTP_CHALLENGE_NOT_FOUND')) {
    return 'Desafio de verificação expirado ou não localizado. Toque em "Reenviar código" para receber um novo código.';
  }
  if (msg.contains('ERR_OTP_VERIFICATION_FAILED') ||
      msg.contains('ERR_EDGE_HTTP_')) {
    return 'Falha momentânea de comunicação ao validar os 6 dígitos. Confira sua conexão e tente novamente.';
  }
  if (msg.contains('ERR_ENROLLMENT_TICKET_INVALID_OR_EXPIRED')) {
    return 'A autorização temporária expirou (10 min). Solicite um novo código de 6 dígitos.';
  }
  if (msg.contains('ERR_RESET_LINK_DEVICE_MISMATCH')) {
    return 'Link bloqueado: a redefinição só pode ser concluída no mesmo aparelho onde você solicitou a troca no Perfil CEO.';
  }
  if (msg.contains('ERR_RESET_LINK_EXPIRED_OR_USED') ||
      msg.contains('ERR_RESET_LINK_INVALID')) {
    return 'Este link único de redefinição expirou (10 min) ou já foi utilizado. Solicite um novo código em Perfil CEO.';
  }
  if (msg.contains('ERR_EMAIL_DELIVERY_FAILED')) {
    return 'Falha momentânea ao entregar o e-mail de segurança. Tente novamente em instantes.';
  }
  return msg.isEmpty ? 'Operação negada pelo Cofre Soberano.' : msg;
}

/// Repositório Monocrático & Coordenador em Tempo Real do `Desperrengue CEO`.
class FounderCockpitRepository {
  FounderCockpitRepository({
    CeoBackendGateway? gateway,
    FlutterSecureStorage? secureStorage,
    this.pbkdf2Iterations = CeoMasterPasswordCryptoEngine.defaultIterations,
    this.deviceLabelOverride,
  })  : _gateway = gateway ?? SupabaseCeoBackendGateway(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _deviceSeedStorageKey =
      'dsp_ceo_sovereign_device_seed_v1';
  static const String _deviceSeedMirrorPrefsKey =
      'dsp_ceo_sovereign_device_seed_mirror_v1';
  static const String _pendingOtpTicketPrefsKey =
      'dsp_ceo_pending_otp_ticket_v1';

  final CeoBackendGateway _gateway;
  final FlutterSecureStorage _secureStorage;
  final int pbkdf2Iterations;
  final String? deviceLabelOverride;

  String? _cachedDeviceHashHex;
  FounderStepUpSession? _activeStepUpSession;
  FounderDashboardSnapshot _snapshot = FounderDashboardSnapshot.emptyZero();

  void Function()? _unsubscribeRealtime;
  Timer? _snapshotDebounceTimer;
  Timer? _heartbeatTimer;

  final ValueNotifier<CeoRealtimeConnectionStatus> realtimeStatusNotifier =
      ValueNotifier<CeoRealtimeConnectionStatus>(
    CeoRealtimeConnectionStatus.disconnected,
  );

  final StreamController<FounderDashboardSnapshot> _snapshotStreamController =
      StreamController<FounderDashboardSnapshot>.broadcast();

  final StreamController<CeoLiveEventItem> _liveEventStreamController =
      StreamController<CeoLiveEventItem>.broadcast();

  FounderDashboardSnapshot get currentSnapshot => _snapshot;

  FounderStepUpSession? get activeStepUpSession => _activeStepUpSession;

  Stream<FounderDashboardSnapshot> get snapshotChanges =>
      _snapshotStreamController.stream;

  Stream<CeoLiveEventItem> get liveEventArrivals =>
      _liveEventStreamController.stream;

  Stream<String?> get authEmailChanges => _gateway.authEmailChanges;

  String? get authenticatedEmail => _gateway.currentUserEmail;

  bool get isAuthenticatedMonocraticOwner =>
      _gateway.currentUserEmail == kMonocraticCeoEmail;

  String get defaultDeviceLabel {
    if (deviceLabelOverride != null && deviceLabelOverride!.trim().isNotEmpty) {
      return deviceLabelOverride!.trim();
    }
    if (kIsWeb) return 'Desperrengue CEO · Console Web TLS';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Desperrengue CEO · Android Blindado';
      case TargetPlatform.iOS:
        return 'Desperrengue CEO · iOS Blindado';
      case TargetPlatform.windows:
        return 'Desperrengue CEO · Workstation Windows';
      case TargetPlatform.macOS:
        return 'Desperrengue CEO · Workstation macOS';
      case TargetPlatform.linux:
        return 'Desperrengue CEO · Workstation Linux';
      case TargetPlatform.fuchsia:
        return 'Desperrengue CEO · Terminal';
    }
  }

  /// Gera e persiste uma semente CSPRNG de 256 bits no Keystore/Keychain seguro do aparelho,
  /// com espelho resiliente local para impedir mutação de fingerprint durante troca de apps
  /// (ex.: alternância rápida entre Desperrengue CEO e Gmail no Android One UI).
  Future<String> getOrCreateDeviceHashHex() async {
    if (_cachedDeviceHashHex != null) return _cachedDeviceHashHex!;

    String? seed;
    try {
      seed = await _secureStorage.read(key: _deviceSeedStorageKey);
    } catch (_) {}

    if (seed == null || seed.length < 32) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final mirrored = prefs.getString(_deviceSeedMirrorPrefsKey);
        if (mirrored != null && mirrored.length >= 32) {
          seed = mirrored;
          try {
            await _secureStorage.write(key: _deviceSeedStorageKey, value: seed);
          } catch (_) {}
        }
      } catch (_) {}
    }

    if (seed == null || seed.length < 32) {
      final rng = math.Random.secure();
      final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
      seed = base64UrlEncode(bytes);
      try {
        await _secureStorage.write(key: _deviceSeedStorageKey, value: seed);
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_deviceSeedMirrorPrefsKey) != seed) {
        await prefs.setString(_deviceSeedMirrorPrefsKey, seed);
      }
    } catch (_) {}

    _cachedDeviceHashHex = sha256
        .convert(utf8.encode('DSP_CEO_DEVICE_FP_V1:$seed'))
        .toString()
        .toLowerCase();
    return _cachedDeviceHashHex!;
  }

  /// Persiste temporariamente o ticket de OTP pendente (apenas metadados públicos,
  /// zero segredo) para sobreviver à recriação de Activity do Android ao abrir o Gmail.
  Future<void> savePendingOtpTicket(CeoOtpChallengeTicket ticket) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingOtpTicketPrefsKey,
        jsonEncode(ticket.toJson()),
      );
    } catch (_) {}
  }

  /// Restaura o ticket de OTP pendente se pertencer à finalidade esperada e ainda
  /// estiver dentro da janela de validade de 10 minutos.
  Future<CeoOtpChallengeTicket?> loadValidPendingOtpTicket({
    required String expectedPurpose,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingOtpTicketPrefsKey);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final ticket = CeoOtpChallengeTicket.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (ticket.challengeId.length < 32 ||
          ticket.purpose != expectedPurpose ||
          ticket.isExpiredAt(DateTime.now().toUtc())) {
        await prefs.remove(_pendingOtpTicketPrefsKey);
        return null;
      }
      return ticket;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPendingOtpTicket() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingOtpTicketPrefsKey);
    } catch (_) {}
  }

  /// Verifica se um e-mail informado pertence exclusivamente ao único dono.
  Future<void> enforceMonocraticEmailOrReject(String attemptedEmail) async {
    final normalized = attemptedEmail.trim().toLowerCase();
    if (normalized == kMonocraticCeoEmail) return;

    await _gateway.reportIntrusionCanary(
      canaryCode: 'NON_OWNER_LOGIN_ATTEMPT_BLOCKED',
      meta: <String, dynamic>{
        'email_domain': normalized.contains('@')
            ? normalized.split('@').last
            : 'invalid',
      },
    );
    await signOutAndLock();
    throw const CeoVaultSecurityException(
      errorCode: 'ERR_MONOCRATIC_OWNER_ONLY_42501',
      userMessagePt:
          'Acesso negado e auditado: somente o e-mail soberano wagneroliveira2395@gmail.com possui acesso ao Desperrengue CEO.',
    );
  }

  CeoVaultSecurityException _exceptionFromEdgeMap(
    Map<String, dynamic> res, {
    String fallbackCode = 'ERR_VAULT_OPERATION_DENIED',
  }) {
    final code = (res['error_code'] ?? fallbackCode).toString();
    final latestRefRaw = (res['latest_challenge_ref'] ?? '').toString().trim();
    final latestRef =
        latestRefRaw.isNotEmpty ? latestRefRaw.toUpperCase() : null;
    final msg = (res['message'] is String &&
            (res['message'] as String).trim().isNotEmpty)
        ? (res['message'] as String).trim()
        : _translateSecurityError(code, latestChallengeRef: latestRef);
    final remAttempts = (res['remaining_attempts'] is num)
        ? (res['remaining_attempts'] as num).round()
        : null;
    final failedAttempts = (res['failed_attempts'] is num)
        ? (res['failed_attempts'] as num).round()
        : null;
    final retrySec = (res['retry_after_seconds'] is num)
        ? (res['retry_after_seconds'] as num).round()
        : null;
    final lockedUntil = DateTime.tryParse(
      (res['locked_until'] ?? '').toString(),
    )?.toUtc();
    final rawRules = res['failed_rules'];
    final failedRules = rawRules is List
        ? List<String>.unmodifiable(rawRules.map((e) => e.toString()))
        : const <String>[];

    return CeoVaultSecurityException(
      errorCode: code,
      userMessagePt: msg,
      remainingAttempts: remAttempts,
      failedAttempts: failedAttempts,
      lockedUntilUtc: lockedUntil,
      retryAfterSeconds: retrySec,
      latestChallengeRef: latestRef,
      failedPolicyRules: failedRules,
    );
  }

  // ---------------------------------------------------------------------------
  // 1. INSPEÇÃO SOBERANA & CERIMÔNIA DE PRIMEIRO ACESSO (CRIAÇÃO DE SENHA MESTRA)
  // ---------------------------------------------------------------------------

  Future<CeoGateInspectionResult> inspectSovereignGate({
    String email = kMonocraticCeoEmail,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final devHash = await getOrCreateDeviceHashHex();
    final res = await _gateway.invokeVaultAuthority(<String, dynamic>{
      'action': 'inspect_gate',
      'email': cleanEmail,
      'device_hash': devHash,
      'device_label': defaultDeviceLabel,
    });

    if (res['ok'] != true) {
      throw _exceptionFromEdgeMap(
        res,
        fallbackCode: 'ERR_MONOCRATIC_OWNER_ONLY_42501',
      );
    }

    return CeoGateInspectionResult(
      ownerEmail: (res['owner_email'] ?? kMonocraticCeoEmail).toString(),
      passwordConfigured: res['password_configured'] == true,
      passwordVersion: (res['password_version'] is num)
          ? (res['password_version'] as num).round()
          : 0,
      passwordUpdatedAtUtc: DateTime.tryParse(
        (res['password_updated_at'] ?? '').toString(),
      )?.toUtc(),
      lockedUntilUtc: DateTime.tryParse(
        (res['locked_until'] ?? '').toString(),
      )?.toUtc(),
    );
  }

  Future<CeoOtpChallengeTicket> requestInitialBootstrapOtp({
    required String email,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail != kMonocraticCeoEmail) {
      await enforceMonocraticEmailOrReject(cleanEmail);
    }

    final devHash = await getOrCreateDeviceHashHex();
    final res = await _gateway.invokeVaultAuthority(<String, dynamic>{
      'action': 'request_initial_bootstrap_otp',
      'email': cleanEmail,
      'device_hash': devHash,
      'device_label': defaultDeviceLabel,
    });

    if (res['ok'] != true) {
      throw _exceptionFromEdgeMap(res, fallbackCode: 'ERR_OTP_REQUEST_DENIED');
    }

    final ticket = _parseOtpTicket(res, purpose: 'INITIAL_PASSWORD_SETUP');
    await savePendingOtpTicket(ticket);
    return ticket;
  }

  Future<String> verifyInitialBootstrapOtp({
    required String challengeId,
    required String sixDigitCode,
  }) async {
    final cleanDigits = CeoSmartOtpExtractor.extractBestSixDigits(sixDigitCode);
    if (cleanDigits.length != 6) {
      throw const CeoVaultSecurityException(
        errorCode: 'ERR_INVALID_OTP_INPUT',
        userMessagePt:
            'Digite exatamente os 6 dígitos enviados para wagneroliveira2395@gmail.com.',
      );
    }

    final devHash = await getOrCreateDeviceHashHex();
    final res = await _gateway.invokeVaultAuthority(<String, dynamic>{
      'action': 'verify_initial_bootstrap_otp',
      'challenge_id': challengeId.trim(),
      'otp_code': cleanDigits,
      'device_hash': devHash,
      'device_label': defaultDeviceLabel,
    });

    if (res['ok'] != true) {
      throw _exceptionFromEdgeMap(
        res,
        fallbackCode: 'ERR_OTP_VERIFICATION_FAILED',
      );
    }

    final ticket = (res['enrollment_ticket'] ?? '').toString().trim();
    if (ticket.length != 64) {
      throw const CeoVaultSecurityException(
        errorCode: 'ERR_ENROLLMENT_TICKET_INVALID_OR_EXPIRED',
        userMessagePt: 'Ticket criptográfico inválido. Solicite um novo código.',
      );
    }
    await clearPendingOtpTicket();
    return ticket;
  }

  Future<FounderStepUpSession> createInitialMasterPassword({
    required String enrollmentTicketHex,
    required String masterPassword,
  }) async {
    final evaluation = CeoStrongPasswordPolicy.evaluate(masterPassword);
    if (!evaluation.isApproved) {
      throw CeoVaultSecurityException(
        errorCode: 'ERR_WEAK_PASSWORD_POLICY',
        userMessagePt: evaluation.primaryRejectionMessagePt ??
            'A Senha Mestra não atende aos requisitos de segurança.',
        failedPolicyRules: evaluation.failedRuleCodes,
      );
    }

    final devHash = await getOrCreateDeviceHashHex();
    final clientKeyHex =
        await CeoMasterPasswordCryptoEngine.deriveClientKeyOffThread(
      masterPassword,
      iterations: pbkdf2Iterations,
    );

    final res = await _gateway.invokeVaultAuthority(<String, dynamic>{
      'action': 'set_initial_password',
      'enrollment_ticket': enrollmentTicketHex.trim().toLowerCase(),
      'password': masterPassword,
      if (pbkdf2Iterations == CeoMasterPasswordCryptoEngine.defaultIterations)
        'client_key_hex': clientKeyHex,
      'device_hash': devHash,
      'device_label': defaultDeviceLabel,
    });

    if (res['ok'] != true) {
      throw _exceptionFromEdgeMap(
        res,
        fallbackCode: 'ERR_VAULT_SEAL_FAILED',
      );
    }

    return _hydrateSessionFromAuthorityResponse(res, devHash);
  }

  // ---------------------------------------------------------------------------
  // 2. LOGIN DIÁRIO 2FA (SENHA MESTRA FORTE + CÓDIGO DE 6 DÍGITOS NO E-MAIL)
  // ---------------------------------------------------------------------------

  Future<CeoOtpChallengeTicket> verifyMasterPasswordAndRequestLoginOtp({
    required String email,
    required String masterPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || masterPassword.isEmpty) {
      throw const CeoVaultSecurityException(
        errorCode: 'ERR_EMPTY_CREDENTIALS',
        userMessagePt:
            'Informe seu e-mail soberano e sua Senha Mestra de Administrador CEO.',
      );
    }
    if (cleanEmail != kMonocraticCeoEmail) {
      await enforceMonocraticEmailOrReject(cleanEmail);
    }
    if (masterPassword.runes.length > CeoStrongPasswordPolicy.maxLength) {
      throw const CeoVaultSecurityException(
        errorCode: 'ERR_INVALID_MASTER_PASSWORD',
        userMessagePt: 'A Senha Mestra respeita o limite máximo de 64 caracteres.',
      );
    }

    final devHash = await getOrCreateDeviceHashHex();
    final clientKeyHex =
        await CeoMasterPasswordCryptoEngine.deriveClientKeyOffThread(
      masterPassword,
      iterations: pbkdf2Iterations,
    );

    final res = await _gateway.invokeVaultAuthority(<String, dynamic>{
      'action': 'verify_password_and_send_login_otp',
      'email': cleanEmail,
      'client_key_hex': clientKeyHex,
      'device_hash': devHash,
      'device_label': defaultDeviceLabel,
    });

    if (res['ok'] != true) {
      throw _exceptionFromEdgeMap(
        res,
        fallbackCode: 'ERR_INVALID_MASTER_PASSWORD',
      );
    }

    final ticket = _parseOtpTicket(res, purpose: 'LOGIN_2FA');
    await savePendingOtpTicket(ticket);
    return ticket;
  }

  Future<CeoOtpChallengeTicket> resendLoginTwoFactorOtp({
    required String previousChallengeId,
  }) async {
    final devHash = await getOrCreateDeviceHashHex();
    final res = await _gateway.invokeVaultAuthority(<String, dynamic>{
      'action': 'resend_login_otp',
      'previous_challenge_id': previousChallengeId.trim(),
      'device_hash': devHash,
      'device_label': defaultDeviceLabel,
    });

    if (res['ok'] != true) {
      throw _exceptionFromEdgeMap(res, fallbackCode: 'ERR_OTP_REQUEST_DENIED');
    }

    final ticket = _parseOtpTicket(res, purpose: 'LOGIN_2FA');
    await savePendingOtpTicket(ticket);
    return ticket;
  }

  Future<FounderStepUpSession> completeLoginTwoFactor({
    required String challengeId,
    required String sixDigitCode,
  }) async {
    final cleanDigits = CeoSmartOtpExtractor.extractBestSixDigits(sixDigitCode);
    if (cleanDigits.length != 6) {
      throw const CeoVaultSecurityException(
        errorCode: 'ERR_INVALID_OTP_INPUT',
        userMessagePt:
            'Digite exatamente os 6 dígitos enviados para wagneroliveira2395@gmail.com.',
      );
    }

    final devHash = await getOrCreateDeviceHashHex();
    final res = await _gateway.invokeVaultAuthority(<String, dynamic>{
      'action': 'complete_login_2fa',
      'challenge_id': challengeId.trim(),
      'otp_code': cleanDigits,
      'device_hash': devHash,
      'device_label': defaultDeviceLabel,
    });

    if (res['ok'] != true) {
      throw _exceptionFromEdgeMap(
        res,
        fallbackCode: 'ERR_OTP_VERIFICATION_FAILED',
      );
    }

    await clearPendingOtpTicket();
    return _hydrateSessionFromAuthorityResponse(res, devHash);
  }

  // ---------------------------------------------------------------------------
  // 3. PERFIL SOBERANO CEO & ROTAÇÃO EM 2 E-MAILS + DEEP-LINK EFÊMERO
  // ---------------------------------------------------------------------------

  Future<CeoProfileSecurityStatus> fetchProfileSecurityStatus() async {
    final session = _requireActiveSession();
    final res = await _gateway.invokeVaultAuthority(<String, dynamic>{
      'action': 'get_ceo_profile_security_status',
      'stepup_token': session.stepUpCredentialHex,
      'device_hash': session.deviceHashHex,
      'device_label': defaultDeviceLabel,
    });

    if (res['ok'] != true) {
      throw _exceptionFromEdgeMap(
        res,
        fallbackCode: 'ERR_STEPUP_SESSION_EXPIRED_OR_REVOKED',
      );
    }

    return CeoProfileSecurityStatus.fromJson(res);
  }

  /// Dispara o E-mail #1 com o código de 6 dígitos para `wagneroliveira2395@gmail.com`.
  Future<CeoOtpChallengeTicket> requestProfilePasswordChangeOtp() async {
    final session = _requireActiveSession();
    final res = await _gateway.invokeVaultAuthority(<String, dynamic>{
      'action': 'request_password_change_otp',
      'stepup_token': session.stepUpCredentialHex,
      'device_hash': session.deviceHashHex,
      'device_label': defaultDeviceLabel,
    });

    if (res['ok'] != true) {
      throw _exceptionFromEdgeMap(res, fallbackCode: 'ERR_OTP_REQUEST_DENIED');
    }

    return _parseOtpTicket(res, purpose: 'PROFILE_PASSWORD_CHANGE_AUTH');
  }

  /// Valida os 6 dígitos do E-mail #1 e dispara imediatamente o E-mail #2 com o
  /// botão clicável de abertura direta no `Desperrengue CEO`.
  Future<DateTime> verifyProfileOtpAndDispatchResetLink({
    required String challengeId,
    required String sixDigitCode,
  }) async {
    final session = _requireActiveSession();
    final cleanDigits = CeoSmartOtpExtractor.extractBestSixDigits(sixDigitCode);
    if (cleanDigits.length != 6) {
      throw const CeoVaultSecurityException(
        errorCode: 'ERR_INVALID_OTP_INPUT',
        userMessagePt:
            'Digite exatamente os 6 dígitos enviados para wagneroliveira2395@gmail.com.',
      );
    }

    final res = await _gateway.invokeVaultAuthority(<String, dynamic>{
      'action': 'verify_password_change_otp_and_dispatch_link',
      'stepup_token': session.stepUpCredentialHex,
      'device_hash': session.deviceHashHex,
      'device_label': defaultDeviceLabel,
      'challenge_id': challengeId.trim(),
      'otp_code': cleanDigits,
    });

    if (res['ok'] != true) {
      throw _exceptionFromEdgeMap(
        res,
        fallbackCode: 'ERR_OTP_VERIFICATION_FAILED',
      );
    }

    return DateTime.tryParse((res['expires_at'] ?? '').toString())?.toUtc() ??
        DateTime.now().toUtc().add(const Duration(minutes: 10));
  }

  /// Conclui a redefinição da Senha Mestra aberta via Deep-Link do E-mail #2,
  /// recifra no Cofre AES-256 e encerra 100% das sessões para exigir novo login completo.
  Future<void> commitPasswordResetFromDeepLink({
    required String linkId,
    required String grantTokenHex,
    required String newMasterPassword,
  }) async {
    final evaluation = CeoStrongPasswordPolicy.evaluate(newMasterPassword);
    if (!evaluation.isApproved) {
      throw CeoVaultSecurityException(
        errorCode: 'ERR_WEAK_PASSWORD_POLICY',
        userMessagePt: evaluation.primaryRejectionMessagePt ??
            'A nova Senha Mestra não atende aos requisitos de segurança.',
        failedPolicyRules: evaluation.failedRuleCodes,
      );
    }

    final devHash = await getOrCreateDeviceHashHex();
    final clientKeyHex =
        await CeoMasterPasswordCryptoEngine.deriveClientKeyOffThread(
      newMasterPassword,
      iterations: pbkdf2Iterations,
    );

    final res = await _gateway.invokeVaultAuthority(<String, dynamic>{
      'action': 'commit_password_reset_from_link',
      'link_id': linkId.trim().toLowerCase(),
      'grant_token': grantTokenHex.trim().toLowerCase(),
      'password': newMasterPassword,
      if (pbkdf2Iterations == CeoMasterPasswordCryptoEngine.defaultIterations)
        'client_key_hex': clientKeyHex,
      'device_hash': devHash,
      'device_label': defaultDeviceLabel,
    });

    if (res['ok'] != true) {
      throw _exceptionFromEdgeMap(
        res,
        fallbackCode: 'ERR_PASSWORD_ROTATION_DENIED',
      );
    }

    await signOutAndLock();
  }

  CeoOtpChallengeTicket _parseOtpTicket(
    Map<String, dynamic> res, {
    required String purpose,
  }) {
    final cid = (res['challenge_id'] ?? '').toString().trim();
    return CeoOtpChallengeTicket(
      challengeId: cid,
      challengeRef: (res['challenge_ref'] ?? '').toString(),
      issuedAtUtc: DateTime.tryParse(
            (res['issued_at'] ?? '').toString(),
          )?.toUtc() ??
          DateTime.now().toUtc(),
      maskedDestination:
          (res['masked_destination'] ?? kMonocraticCeoEmail).toString(),
      expiresAtUtc: DateTime.tryParse(
            (res['expires_at'] ?? '').toString(),
          )?.toUtc() ??
          DateTime.now().toUtc().add(const Duration(minutes: 10)),
      nextCooldownSeconds: (res['next_cooldown_seconds'] is num)
          ? (res['next_cooldown_seconds'] as num).round()
          : 30,
      purpose: purpose,
    );
  }

  Future<FounderStepUpSession> _hydrateSessionFromAuthorityResponse(
    Map<String, dynamic> res,
    String devHash,
  ) async {
    final accessToken = (res['access_token'] ?? '').toString().trim();
    final refreshToken = (res['refresh_token'] ?? '').toString().trim();
    if (accessToken.isNotEmpty && refreshToken.isNotEmpty) {
      await _gateway.hydrateSovereignSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    }

    final activeEmail = _gateway.currentUserEmail ?? kMonocraticCeoEmail;
    await enforceMonocraticEmailOrReject(activeEmail);

    final stepupToken = (res['stepup_token'] ?? '').toString().trim();
    final expiresAt = DateTime.tryParse(
          (res['stepup_expires_at'] ?? res['expires_at'] ?? '').toString(),
        )?.toUtc() ??
        DateTime.now().toUtc().add(const Duration(minutes: 15));
    final pwVersion = (res['password_version'] is num)
        ? (res['password_version'] as num).round()
        : 1;

    final session = FounderStepUpSession(
      stepUpCredentialHex: stepupToken,
      userId: _gateway.currentUserId ?? '',
      accountEmail: kMonocraticCeoEmail,
      deviceHashHex: devHash,
      expiresAtUtc: expiresAt,
      passwordVersion: pwVersion,
    );
    _activeStepUpSession = session;
    await _startRealtimeBridgeAndHeartbeat();
    return session;
  }

  // ---------------------------------------------------------------------------
  // 4. SNAPSHOT 100% REAL + STREAM DE TEMPO REAL (`ceo:war-room:live`) + FORENSE
  // ---------------------------------------------------------------------------

  Future<FounderDashboardSnapshot> fetchLiveSnapshot({
    String? windowKey,
  }) async {
    final session = _activeStepUpSession;
    if (session == null) {
      throw const CeoVaultSecurityException(
        errorCode: 'ERR_VAULT_LOCKED',
        userMessagePt:
            'Valide sua Senha Mestra e o código de 6 dígitos para abrir o Cofre Soberano.',
      );
    }

    final effectiveWindow = (windowKey ?? _snapshot.windowKey).trim();
    final res = await _gateway.callRpc(
      'ceo_get_live_cockpit_snapshot',
      <String, dynamic>{
        'p_stepup_token': session.stepUpCredentialHex,
        'p_device_hash': session.deviceHashHex,
        'p_window_key': effectiveWindow.isEmpty ? '30d' : effectiveWindow,
      },
    );

    _snapshot = FounderDashboardSnapshot.fromJson(res);
    if (!_snapshotStreamController.isClosed) {
      _snapshotStreamController.add(_snapshot);
    }
    return _snapshot;
  }

  Future<List<CeoLiveEventItem>> catchUpMissedLiveEvents() async {
    final session = _activeStepUpSession;
    if (session == null) return const <CeoLiveEventItem>[];

    try {
      final res = await _gateway.callRpc(
        'ceo_fetch_live_events_since',
        <String, dynamic>{
          'p_stepup_token': session.stepUpCredentialHex,
          'p_device_hash': session.deviceHashHex,
          'p_after_seq': _snapshot.latestEventSeq,
          'p_limit': 100,
        },
      );
      final list = res['events'];
      if (list is! List || list.isEmpty) return const <CeoLiveEventItem>[];
      final parsed = <CeoLiveEventItem>[
        for (final item in list)
          if (item is Map)
            CeoLiveEventItem.fromJson(Map<String, dynamic>.from(item)),
      ];
      if (parsed.isNotEmpty) {
        _snapshot = _snapshot.prependLiveEvents(parsed);
        if (!_snapshotStreamController.isClosed) {
          _snapshotStreamController.add(_snapshot);
        }
        _scheduleDebouncedSnapshotRefresh();
      }
      return parsed;
    } catch (_) {
      return const <CeoLiveEventItem>[];
    }
  }

  Future<CeoOrderForensicsDossier> inspectOrderForensics(String jobId) async {
    final session = _requireActiveSession();
    final res = await _gateway.callRpc(
      'ceo_inspect_order_forensics',
      <String, dynamic>{
        'p_stepup_token': session.stepUpCredentialHex,
        'p_device_hash': session.deviceHashHex,
        'p_job_id': jobId.trim(),
      },
    );
    return CeoOrderForensicsDossier.fromJson(res);
  }

  Future<List<CeoRealUserDirectoryRow>> listRealUsersDirectory({
    String search = '',
    String roleFilter = 'all',
    int limit = 60,
  }) async {
    final session = _requireActiveSession();
    final res = await _gateway.callRpc(
      'ceo_list_real_users_directory',
      <String, dynamic>{
        'p_stepup_token': session.stepUpCredentialHex,
        'p_device_hash': session.deviceHashHex,
        'p_search': search.trim(),
        'p_role_filter': roleFilter.trim(),
        'p_limit': limit.clamp(1, 200),
      },
    );
    final rawUsers = res['users'];
    if (rawUsers is! List) return const <CeoRealUserDirectoryRow>[];
    return List<CeoRealUserDirectoryRow>.unmodifiable(<CeoRealUserDirectoryRow>[
      for (final u in rawUsers)
        if (u is Map)
          CeoRealUserDirectoryRow.fromJson(Map<String, dynamic>.from(u)),
    ]);
  }

  Future<void> recordRealExpense({
    required DateTime competenceDate,
    required String expenseKind,
    required String category,
    required String description,
    required int amountCents,
    String? paymentStatus,
  }) async {
    final session = _requireActiveSession();
    final dateIso =
        '${competenceDate.year.toString().padLeft(4, '0')}-${competenceDate.month.toString().padLeft(2, '0')}-${competenceDate.day.toString().padLeft(2, '0')}';
    await _gateway.callRpc(
      'ceo_record_real_expense',
      <String, dynamic>{
        'p_stepup_token': session.stepUpCredentialHex,
        'p_device_hash': session.deviceHashHex,
        'p_competence_date': dateIso,
        'p_expense_kind': expenseKind,
        'p_category': category.trim(),
        'p_description': description.trim(),
        'p_amount_cents': amountCents,
        if (paymentStatus != null && paymentStatus.trim().isNotEmpty)
          'p_payment_status': paymentStatus.trim().toUpperCase(),
      },
    );
    await fetchLiveSnapshot();
  }

  Future<void> toggleExpensePaidStatus({
    required String expenseId,
    required bool paid,
  }) async {
    final session = _requireActiveSession();
    await _gateway.callRpc(
      'ceo_toggle_expense_paid_status',
      <String, dynamic>{
        'p_stepup_token': session.stepUpCredentialHex,
        'p_device_hash': session.deviceHashHex,
        'p_expense_id': expenseId.trim(),
        'p_paid': paid,
      },
    );
    await fetchLiveSnapshot();
  }

  Future<void> deleteRealExpense(String expenseId) async {
    final session = _requireActiveSession();
    await _gateway.callRpc(
      'ceo_delete_real_expense',
      <String, dynamic>{
        'p_stepup_token': session.stepUpCredentialHex,
        'p_device_hash': session.deviceHashHex,
        'p_expense_id': expenseId.trim(),
      },
    );
    await fetchLiveSnapshot();
  }

  Future<void> revokeTrustedDevice(String targetDeviceId) async {
    final session = _requireActiveSession();
    await _gateway.callRpc(
      'ceo_revoke_trusted_device',
      <String, dynamic>{
        'p_stepup_token': session.stepUpCredentialHex,
        'p_device_hash': session.deviceHashHex,
        'p_target_device_id': targetDeviceId.trim(),
      },
    );
    await fetchLiveSnapshot();
  }

  Future<void> refreshHeartbeat() async {
    final session = _activeStepUpSession;
    if (session == null) return;
    try {
      final res = await _gateway.callRpc(
        'ceo_refresh_stepup_heartbeat',
        <String, dynamic>{
          'p_stepup_token': session.stepUpCredentialHex,
          'p_device_hash': session.deviceHashHex,
        },
      );
      if (res['ok'] == true) {
        final nextExp = DateTime.tryParse(
          (res['expires_at'] ?? '').toString(),
        )?.toUtc();
        if (nextExp != null) {
          _activeStepUpSession = FounderStepUpSession(
            stepUpCredentialHex: session.stepUpCredentialHex,
            userId: session.userId,
            accountEmail: session.accountEmail,
            deviceHashHex: session.deviceHashHex,
            expiresAtUtc: nextExp,
            passwordVersion: session.passwordVersion,
          );
        }
      }
    } catch (_) {}
  }

  /// Tranca o Cofre Soberano (revoga o `stepup_token` no PostgreSQL, desliga o WebSocket
  /// privado e limpa a sessão em memória para exigir Senha Mestra + 6 dígitos ao reentrar).
  Future<void> lockVault() async {
    final prev = _activeStepUpSession;
    _activeStepUpSession = null;
    _stopRealtimeBridgeAndTimers();
    if (prev != null) {
      try {
        await _gateway.callRpc(
          'ceo_lock_sovereign_vault',
          <String, dynamic>{'p_stepup_token': prev.stepUpCredentialHex},
        );
      } catch (_) {}
    }
  }

  /// Tranca o Cofre e encerra completamente qualquer token local.
  Future<void> signOutAndLock() async {
    await lockVault();
    await clearPendingOtpTicket();
    _snapshot = FounderDashboardSnapshot.emptyZero();
    await _gateway.signOut();
  }

  FounderStepUpSession _requireActiveSession() {
    final s = _activeStepUpSession;
    if (s == null) {
      throw const CeoVaultSecurityException(
        errorCode: 'ERR_VAULT_LOCKED',
        userMessagePt:
            'Cofre trancado. Valide sua Senha Mestra e o código de 6 dígitos para continuar.',
      );
    }
    return s;
  }

  Future<void> _startRealtimeBridgeAndHeartbeat() async {
    _stopRealtimeBridgeAndTimers();

    _unsubscribeRealtime = await _gateway.subscribeWarRoomLive(
      onLiveEvent: (event) {
        _snapshot = _snapshot.prependLiveEvents(<CeoLiveEventItem>[event]);
        if (!_snapshotStreamController.isClosed) {
          _snapshotStreamController.add(_snapshot);
        }
        if (!_liveEventStreamController.isClosed) {
          _liveEventStreamController.add(event);
        }
        HapticFeedback.selectionClick();
        _scheduleDebouncedSnapshotRefresh();
      },
      onStatusChanged: (status) {
        final prev = realtimeStatusNotifier.value;
        realtimeStatusNotifier.value = status;
        if (status == CeoRealtimeConnectionStatus.liveConnected &&
            prev == CeoRealtimeConnectionStatus.reconnecting) {
          catchUpMissedLiveEvents();
        }
      },
    );

    _heartbeatTimer = Timer.periodic(
      const Duration(minutes: 4),
      (_) => refreshHeartbeat(),
    );
  }

  void _scheduleDebouncedSnapshotRefresh() {
    _snapshotDebounceTimer?.cancel();
    _snapshotDebounceTimer = Timer(const Duration(milliseconds: 350), () async {
      if (_activeStepUpSession == null) return;
      try {
        await fetchLiveSnapshot();
      } catch (_) {}
    });
  }

  void _stopRealtimeBridgeAndTimers() {
    _snapshotDebounceTimer?.cancel();
    _snapshotDebounceTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    final unsub = _unsubscribeRealtime;
    _unsubscribeRealtime = null;
    unsub?.call();
    realtimeStatusNotifier.value = CeoRealtimeConnectionStatus.disconnected;
  }

  void dispose() {
    _stopRealtimeBridgeAndTimers();
    realtimeStatusNotifier.dispose();
    _snapshotStreamController.close();
    _liveEventStreamController.close();
  }
}

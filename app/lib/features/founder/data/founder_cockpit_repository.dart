/// Camada de Dados, Criptografia Cliente (`PBKDF2-HMAC-SHA256`), Ponte `FLAG_SECURE`
/// e Coordenador WebSocket em Tempo Real (`WSS TLS 1.3`) do `Desperrengue CEO`.
///
/// Regras arquiteturais inegociáveis:
/// - Zero dados falsos (`Zero-Fake Policy`): sem `deterministicDemo`, sem PIN pré-preenchido,
///   sem e-mail pré-preenchido e sem fallback silencioso para dados fictícios.
/// - Exclusividade Monocrática: único titular aceito é `wagneroliveira2395@gmail.com`.
///   Qualquer outra sessão dispara `INTRUSION_CANARY` na cadeia WORM `SHA-256` e faz
///   `signOut()` imediato.
/// - Prova Criptográfica de PIN: `PBKDF2-HMAC-SHA256` com `120.000` iterações em worker
///   assíncrono via [runOffMainThread], seguida de `10.000` rodadas `HMAC-SHA256` com
///   pepper de 512 bits + salt CSPRNG de 256 bits no PostgreSQL (`CHAR(64)` `SHA-256`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/analytics/founder_dashboard_models.dart';
import '../../../core/utils/off_thread.dart';

/// Sessão autenticada de Step-Up Zero-Trust do Cofre Monocrático CEO.
class FounderStepUpSession {
  const FounderStepUpSession({
    required this.stepUpCredentialHex,
    required this.userId,
    required this.accountEmail,
    required this.deviceHashHex,
    required this.expiresAtUtc,
  });

  final String stepUpCredentialHex;
  final String userId;
  final String accountEmail;
  final String deviceHashHex;
  final DateTime expiresAtUtc;

  bool isExpiredAt(DateTime nowUtc) => !expiresAtUtc.isAfter(nowUtc.toUtc());
}

/// Resposta da solicitação do código de 6 dígitos enviado a `wagneroliveira2395@gmail.com`.
class CeoOtpChallengeTicket {
  const CeoOtpChallengeTicket({
    required this.challengeId,
    required this.maskedDestination,
    required this.expiresAtUtc,
    required this.nextCooldownSeconds,
    required this.purpose,
  });

  final String challengeId;
  final String maskedDestination;
  final DateTime expiresAtUtc;
  final int nextCooldownSeconds;
  final String purpose;
}

/// Resultado da verificação em tempo constante do código de 6 dígitos.
class CeoOtpVerificationResult {
  const CeoOtpVerificationResult({
    required this.purpose,
    required this.pinAlreadyConfigured,
    required this.enrollmentTicketHex,
    required this.ticketExpiresAtUtc,
  });

  final String purpose;
  final bool pinAlreadyConfigured;
  final String enrollmentTicketHex;
  final DateTime ticketExpiresAtUtc;
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
  });

  final String errorCode;
  final String userMessagePt;
  final int? remainingAttempts;
  final int? failedAttempts;
  final DateTime? lockedUntilUtc;
  final int? retryAfterSeconds;

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

/// Motor Criptográfico Cliente (`PBKDF2-HMAC-SHA256` RFC 8018 + Validador de Entropia).
class CeoPinCryptoEngine {
  const CeoPinCryptoEngine._();

  static const int defaultIterations = 120000;
  static const String _domainSalt =
      'DESPERRENGUE_CEO_PIN_V1:$kMonocraticCeoEmail';

  /// Valida a força do PIN pessoal do CEO (6 a 8 dígitos numéricos, bloqueando sequências
  /// ascendentes/descendentes, todos os dígitos repetidos e padrões triviais).
  /// Retorna `null` quando aprovado ou a mensagem de rejeição em `pt-BR`.
  static String? validatePinStrength(String candidate) {
    final clean = candidate.trim();
    if (!RegExp(r'^\d{6,8}$').hasMatch(clean)) {
      return 'Seu PIN pessoal deve conter de 6 a 8 dígitos numéricos.';
    }

    // Bloqueia todos os dígitos iguais (000000, 111111, ..., 999999)
    final uniqueDigits = clean.split('').toSet();
    if (uniqueDigits.length <= 2) {
      return 'Por segurança extrema, escolha um PIN com pelo menos 3 algarismos distintos.';
    }

    // Bloqueia sequências aritméticas contínuas (123456, 654321, 234567, 012345...)
    var allAsc = true;
    var allDesc = true;
    for (var i = 1; i < clean.length; i++) {
      final diff = clean.codeUnitAt(i) - clean.codeUnitAt(i - 1);
      if (diff != 1) allAsc = false;
      if (diff != -1) allDesc = false;
    }
    if (allAsc || allDesc) {
      return 'Sequências numéricas consecutivas (ex.: 123456 ou 654321) são bloqueadas.';
    }

    // Bloqueia repetição de bloco (ex.: 123123, 121212)
    if (clean.length == 6) {
      if (clean.substring(0, 3) == clean.substring(3, 6) ||
          (clean.substring(0, 2) == clean.substring(2, 4) &&
              clean.substring(2, 4) == clean.substring(4, 6))) {
        return 'Evite blocos repetidos previsíveis ao criar seu PIN soberano.';
      }
    }

    return null;
  }

  /// Deriva em memória um bloco de 32 bytes (`CHAR(64)` hexadecimal `SHA-256`) via
  /// `PBKDF2-HMAC-SHA256` (`dkLen = 32`, `blockIndex = 1`) e zera buffers temporários.
  static String deriveClientPinProofSync(
    String rawPin, {
    int iterations = defaultIterations,
  }) {
    final rounds = iterations.clamp(1000, 500000);
    final keyBytes = Uint8List.fromList(utf8.encode(rawPin.trim()));
    final saltBytes = utf8.encode(_domainSalt);
    final block1Input = Uint8List(saltBytes.length + 4);
    block1Input.setRange(0, saltBytes.length, saltBytes);
    block1Input[saltBytes.length] = 0;
    block1Input[saltBytes.length + 1] = 0;
    block1Input[saltBytes.length + 2] = 0;
    block1Input[saltBytes.length + 3] = 1;

    try {
      final hmac = Hmac(sha256, keyBytes);
      var u = Uint8List.fromList(hmac.convert(block1Input).bytes);
      final t = Uint8List.fromList(u);

      for (var i = 1; i < rounds; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < 32; j++) {
          t[j] ^= u[j];
        }
      }

      // Digest final SHA-256 canônico em lowercase hex (64 caracteres)
      final finalDigest = sha256.convert(t).toString().toLowerCase();
      t.fillRange(0, t.length, 0);
      u.fillRange(0, u.length, 0);
      return finalDigest;
    } finally {
      keyBytes.fillRange(0, keyBytes.length, 0);
      block1Input.fillRange(0, block1Input.length, 0);
    }
  }

  /// Executa a derivação `PBKDF2-HMAC-SHA256` fora da UI thread para manter 120 FPS.
  static Future<String> deriveClientPinProofOffThread(
    String rawPin, {
    int iterations = defaultIterations,
  }) {
    final clean = rawPin.trim();
    return runOffMainThread(
      () => deriveClientPinProofSync(clean, iterations: iterations),
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

/// Contrato de transporte injetável para produção (Supabase Real) e testes determinísticos.
abstract class CeoBackendGateway {
  String? get currentUserEmail;
  String? get currentUserId;
  Stream<String?> get authEmailChanges;

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  });

  Future<void> signInWithGoogleOAuth();

  Future<void> sendPrimaryEmailSignInOtp({required String email});

  Future<void> verifyPrimaryEmailSignInOtp({
    required String email,
    required String token,
  });

  Future<void> signOut();

  Future<void> reportIntrusionCanary({
    required String canaryCode,
    required Map<String, dynamic> meta,
  });

  Future<Map<String, dynamic>> invokeEdgeAuth(Map<String, dynamic> body);

  Future<Map<String, dynamic>> callRpc(
    String functionName,
    Map<String, dynamic> params,
  );

  /// Conecta ao canal privado `ceo:war-room:live` (`private: true`) e invoca
  /// [onLiveEvent] a cada evento `ceo_live_event` transmitido pelo PostgreSQL.
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
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  @override
  Future<void> signInWithGoogleOAuth() async {
    final launched = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      authScreenLaunchMode: LaunchMode.platformDefault,
      redirectTo: 'br.com.desperrengue.app.founder://login-callback',
      queryParams: const <String, String>{
        'prompt': 'select_account',
        'login_hint': kMonocraticCeoEmail,
      },
    );
    if (!launched) {
      throw const CeoVaultSecurityException(
        errorCode: 'ERR_OAUTH_LAUNCH_FAILED',
        userMessagePt:
            'Não foi possível abrir o autenticador seguro do Google neste dispositivo.',
      );
    }
  }

  @override
  Future<void> sendPrimaryEmailSignInOtp({required String email}) async {
    await _client.auth.signInWithOtp(
      email: email.trim().toLowerCase(),
      shouldCreateUser: false,
    );
  }

  @override
  Future<void> verifyPrimaryEmailSignInOtp({
    required String email,
    required String token,
  }) async {
    await _client.auth.verifyOTP(
      type: OtpType.email,
      email: email.trim().toLowerCase(),
      token: token.trim(),
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

  @override
  Future<Map<String, dynamic>> invokeEdgeAuth(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke(
        'ceo-sovereign-auth',
        body: body,
      );
      final data = res.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      if (data is String && data.trim().isNotEmpty) {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
      return const <String, dynamic>{'ok': false};
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map) {
        return Map<String, dynamic>.from(details);
      }
      if (details is String && details.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(details);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
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
            // Supabase Realtime broadcast pode aninhar em `payload['payload']` ou entregar direto
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

String _translateSecurityError(String rawCodeOrMessage) {
  final msg = rawCodeOrMessage.trim();
  if (msg.contains('ERR_MONOCRATIC_OWNER_ONLY')) {
    return 'Acesso bloqueado: este aplicativo é de titularidade exclusiva do CEO ($kMonocraticCeoEmail).';
  }
  if (msg.contains('ERR_UNAUTHENTICATED')) {
    return 'Sua sessão primária expirou. Autentique novamente sua conta soberana.';
  }
  if (msg.contains('ERR_STEPUP_SESSION_EXPIRED_OR_INVALID')) {
    return 'Sessão de alta segurança expirada por inatividade. Digite seu PIN pessoal para continuar.';
  }
  if (msg.contains('ERR_PIN_NOT_CONFIGURED')) {
    return 'Seu PIN pessoal ainda não foi configurado. Valide o código de 6 dígitos enviado ao seu e-mail.';
  }
  if (msg.contains('ERR_UNTRUSTED_DEVICE_OTP_REQUIRED')) {
    return 'Novo dispositivo detectado. Valide o código de 6 dígitos enviado ao seu e-mail para vinculá-lo.';
  }
  if (msg.contains('ERR_VAULT_LOCKED_BACKOFF')) {
    return 'Cofre temporariamente bloqueado após tentativas incorretas de PIN. Aguarde o temporizador.';
  }
  if (msg.contains('ERR_INVALID_PERSONAL_PIN')) {
    return 'PIN pessoal incorreto. Verifique os dígitos informados.';
  }
  if (msg.contains('ERR_OTP_COOLDOWN_ACTIVE')) {
    return 'Aguarde o intervalo de segurança antes de solicitar um novo código de 6 dígitos.';
  }
  if (msg.contains('ERR_OTP_CODE_INCORRECT')) {
    return 'Código de 6 dígitos incorreto. Confira o último e-mail enviado para $kMonocraticCeoEmail.';
  }
  if (msg.contains('ERR_OTP_MAX_ATTEMPTS_EXCEEDED') ||
      msg.contains('ERR_OTP_CHALLENGE_EXPIRED')) {
    return 'Este código de 6 dígitos expirou. Solicite o envio de um novo código seguro.';
  }
  if (msg.contains('ERR_ENROLLMENT_TICKET_INVALID_OR_EXPIRED')) {
    return 'O ticket criptográfico de criação de PIN expirou (5 min). Solicite um novo código de 6 dígitos.';
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
    this.pbkdf2Iterations = CeoPinCryptoEngine.defaultIterations,
    this.deviceLabelOverride,
  })  : _gateway = gateway ?? SupabaseCeoBackendGateway(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _deviceSeedStorageKey =
      'dsp_ceo_sovereign_device_seed_v1';

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
  /// retornando apenas seu digest `SHA-256` (`CHAR(64)` hexadecimal).
  Future<String> getOrCreateDeviceHashHex() async {
    if (_cachedDeviceHashHex != null) return _cachedDeviceHashHex!;
    try {
      var seed = await _secureStorage.read(key: _deviceSeedStorageKey);
      if (seed == null || seed.length < 32) {
        final rng = math.Random.secure();
        final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
        seed = base64UrlEncode(bytes);
        await _secureStorage.write(key: _deviceSeedStorageKey, value: seed);
      }
      _cachedDeviceHashHex = sha256
          .convert(utf8.encode('DSP_CEO_DEVICE_FP_V1:$seed'))
          .toString()
          .toLowerCase();
      return _cachedDeviceHashHex!;
    } catch (_) {
      // Ambiente headless de teste sem plugin nativo registrado
      final rng = math.Random.secure();
      final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
      _cachedDeviceHashHex = sha256.convert(bytes).toString().toLowerCase();
      return _cachedDeviceHashHex!;
    }
  }

  // ---------------------------------------------------------------------------
  // CAMADA 1: AUTENTICAÇÃO PRIMÁRIA ESTRITA (`wagneroliveira2395@gmail.com`)
  // ---------------------------------------------------------------------------

  /// Verifica se um e-mail digitado ou retornado por OAuth pertence ao único dono.
  /// Se não pertencer, registra canário WORM e encerra imediatamente qualquer sessão!
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
          'Acesso negado e auditado: o aplicativo Desperrengue CEO é restrito exclusivamente ao titular soberano.',
    );
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw const CeoVaultSecurityException(
        errorCode: 'ERR_EMPTY_CREDENTIALS',
        userMessagePt: 'Informe seu e-mail soberano e sua senha de acesso.',
      );
    }
    if (cleanEmail != kMonocraticCeoEmail) {
      await enforceMonocraticEmailOrReject(cleanEmail);
    }
    try {
      await _gateway.signInWithEmailPassword(
        email: cleanEmail,
        password: password,
      );
    } on AuthException catch (e) {
      throw CeoVaultSecurityException(
        errorCode: 'ERR_SUPABASE_AUTH',
        userMessagePt: e.message,
      );
    }
    final activeEmail = _gateway.currentUserEmail ?? '';
    await enforceMonocraticEmailOrReject(activeEmail);
  }

  Future<void> signInWithGoogleOAuth() async {
    await _gateway.signInWithGoogleOAuth();
  }

  Future<void> sendPrimaryEmailSignInOtp({required String email}) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail != kMonocraticCeoEmail) {
      await enforceMonocraticEmailOrReject(cleanEmail);
    }
    try {
      await _gateway.sendPrimaryEmailSignInOtp(email: cleanEmail);
    } on AuthException catch (e) {
      throw CeoVaultSecurityException(
        errorCode: 'ERR_SUPABASE_AUTH_OTP',
        userMessagePt: e.message,
      );
    }
  }

  Future<void> verifyPrimaryEmailSignInOtp({
    required String email,
    required String code,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail != kMonocraticCeoEmail) {
      await enforceMonocraticEmailOrReject(cleanEmail);
    }
    try {
      await _gateway.verifyPrimaryEmailSignInOtp(
        email: cleanEmail,
        token: code.trim(),
      );
    } on AuthException catch (e) {
      throw CeoVaultSecurityException(
        errorCode: 'ERR_SUPABASE_AUTH_OTP_INVALID',
        userMessagePt: e.message,
      );
    }
    final activeEmail = _gateway.currentUserEmail ?? '';
    await enforceMonocraticEmailOrReject(activeEmail);
  }

  /// Consulta no PostgreSQL se o PIN `SHA-256` já foi criado por Wagner e se este
  /// aparelho já está vinculado criptograficamente (`ceo_vault_status`).
  Future<CeoVaultStatus> fetchVaultStatus() async {
    final activeEmail = _gateway.currentUserEmail;
    if (activeEmail == null || activeEmail.isEmpty) {
      throw const CeoVaultSecurityException(
        errorCode: 'ERR_UNAUTHENTICATED_28000',
        userMessagePt: 'Autentique sua conta soberana para acessar o Cofre CEO.',
      );
    }
    await enforceMonocraticEmailOrReject(activeEmail);

    final devHash = await getOrCreateDeviceHashHex();
    final json = await _gateway.callRpc(
      'ceo_vault_status',
      <String, dynamic>{'p_device_hash': devHash},
    );
    final status = CeoVaultStatus.fromJson(json);
    if (!status.ok) {
      final code = status.errorCode ?? 'ERR_MONOCRATIC_OWNER_ONLY_42501';
      if (code.contains('MONOCRATIC_OWNER')) {
        await signOutAndLock();
      }
      throw CeoVaultSecurityException(
        errorCode: code,
        userMessagePt: _translateSecurityError(code),
      );
    }
    return status;
  }

  // ---------------------------------------------------------------------------
  // CAMADA 2: CÓDIGO DE 6 DÍGITOS EXCLUSIVO NO E-MAIL `wagneroliveira2395@gmail.com`
  // ---------------------------------------------------------------------------

  Future<CeoOtpChallengeTicket> requestEmailSecurityOtp({
    required String purpose,
  }) async {
    final activeEmail = _gateway.currentUserEmail ?? '';
    await enforceMonocraticEmailOrReject(activeEmail);

    final devHash = await getOrCreateDeviceHashHex();
    final res = await _gateway.invokeEdgeAuth(<String, dynamic>{
      'action': 'request_otp',
      'purpose': purpose,
      'device_hash': devHash,
      'device_label': defaultDeviceLabel,
    });

    if (res['ok'] != true) {
      final code = (res['error_code'] ?? 'ERR_OTP_REQUEST_DENIED').toString();
      final retrySec = (res['retry_after_seconds'] is num)
          ? (res['retry_after_seconds'] as num).round()
          : null;
      throw CeoVaultSecurityException(
        errorCode: code,
        userMessagePt: (res['message'] is String &&
                (res['message'] as String).trim().isNotEmpty)
            ? (res['message'] as String).trim()
            : _translateSecurityError(code),
        retryAfterSeconds: retrySec,
      );
    }

    return CeoOtpChallengeTicket(
      challengeId: (res['challenge_id'] ?? '').toString(),
      maskedDestination:
          (res['masked_destination'] ?? kMaskedMonocraticCeoEmail).toString(),
      expiresAtUtc: DateTime.tryParse(
            (res['expires_at'] ?? '').toString(),
          )?.toUtc() ??
          DateTime.now().toUtc().add(const Duration(minutes: 5)),
      nextCooldownSeconds: (res['next_cooldown_seconds'] is num)
          ? (res['next_cooldown_seconds'] as num).round()
          : 30,
      purpose: purpose,
    );
  }

  Future<CeoOtpVerificationResult> verifyEmailSecurityOtp({
    required String challengeId,
    required String sixDigitCode,
  }) async {
    final cleanDigits = sixDigitCode.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.length != 6) {
      throw const CeoVaultSecurityException(
        errorCode: 'ERR_INVALID_OTP_INPUT',
        userMessagePt:
            'Digite exatamente os 6 dígitos enviados para o seu e-mail.',
      );
    }

    final devHash = await getOrCreateDeviceHashHex();
    final res = await _gateway.invokeEdgeAuth(<String, dynamic>{
      'action': 'verify_otp',
      'challenge_id': challengeId,
      'otp_code': cleanDigits,
      'device_hash': devHash,
      'device_label': defaultDeviceLabel,
    });

    if (res['ok'] != true) {
      final code = (res['error_code'] ?? 'ERR_OTP_CODE_INCORRECT').toString();
      final rem = (res['remaining_attempts'] is num)
          ? (res['remaining_attempts'] as num).round()
          : null;
      throw CeoVaultSecurityException(
        errorCode: code,
        userMessagePt: _translateSecurityError(code),
        remainingAttempts: rem,
      );
    }

    return CeoOtpVerificationResult(
      purpose: (res['purpose'] ?? 'INITIAL_PIN_SETUP').toString(),
      pinAlreadyConfigured: res['pin_configured'] == true,
      enrollmentTicketHex: (res['enrollment_ticket'] ?? '').toString(),
      ticketExpiresAtUtc: DateTime.tryParse(
            (res['ticket_expires_at'] ?? '').toString(),
          )?.toUtc() ??
          DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );
  }

  // ---------------------------------------------------------------------------
  // CAMADA 3: CRIAÇÃO E DESBLOQUEIO DO PIN PESSOAL (`SHA-256`)
  // ---------------------------------------------------------------------------

  /// Cria ou redefine o PIN pessoal escolhido por Wagner após validação do código de 6 dígitos.
  Future<FounderStepUpSession> registerPersonalPin({
    required String enrollmentTicketHex,
    required String personalPin,
  }) async {
    final weakness = CeoPinCryptoEngine.validatePinStrength(personalPin);
    if (weakness != null) {
      throw CeoVaultSecurityException(
        errorCode: 'ERR_WEAK_PERSONAL_PIN',
        userMessagePt: weakness,
      );
    }

    final devHash = await getOrCreateDeviceHashHex();
    final proofHex = await CeoPinCryptoEngine.deriveClientPinProofOffThread(
      personalPin,
      iterations: pbkdf2Iterations,
    );

    final res = await _gateway.callRpc(
      'ceo_register_personal_pin',
      <String, dynamic>{
        'p_enrollment_ticket': enrollmentTicketHex.trim().toLowerCase(),
        'p_client_pin_proof': proofHex,
        'p_device_hash': devHash,
        'p_device_label': defaultDeviceLabel,
      },
    );

    if (res['ok'] != true) {
      final code =
          (res['error_code'] ?? 'ERR_ENROLLMENT_TICKET_INVALID_OR_EXPIRED')
              .toString();
      throw CeoVaultSecurityException(
        errorCode: code,
        userMessagePt: _translateSecurityError(code),
      );
    }

    return _activateStepUpSessionFromRpc(res, devHash);
  }

  /// Desbloqueia o Cofre Soberano validando o PIN pessoal de Wagner em tempo constante `SHA-256`.
  Future<FounderStepUpSession> unlockWithPersonalPin({
    required String personalPin,
  }) async {
    final clean = personalPin.trim();
    if (!RegExp(r'^\d{6,8}$').hasMatch(clean)) {
      throw const CeoVaultSecurityException(
        errorCode: 'ERR_INVALID_PERSONAL_PIN',
        userMessagePt: 'Digite os 6 dígitos do seu PIN pessoal.',
      );
    }

    final devHash = await getOrCreateDeviceHashHex();
    final proofHex = await CeoPinCryptoEngine.deriveClientPinProofOffThread(
      clean,
      iterations: pbkdf2Iterations,
    );

    final res = await _gateway.callRpc(
      'ceo_unlock_sovereign_vault',
      <String, dynamic>{
        'p_client_pin_proof': proofHex,
        'p_device_hash': devHash,
        'p_device_label': defaultDeviceLabel,
      },
    );

    if (res['ok'] != true) {
      final code = (res['error_code'] ?? 'ERR_INVALID_PERSONAL_PIN').toString();
      final failed = (res['failed_attempts'] is num)
          ? (res['failed_attempts'] as num).round()
          : null;
      final lockedUntil = DateTime.tryParse(
        (res['locked_until'] ?? '').toString(),
      )?.toUtc();
      throw CeoVaultSecurityException(
        errorCode: code,
        userMessagePt: _translateSecurityError(code),
        failedAttempts: failed,
        lockedUntilUtc: lockedUntil,
      );
    }

    return _activateStepUpSessionFromRpc(res, devHash);
  }

  Future<FounderStepUpSession> _activateStepUpSessionFromRpc(
    Map<String, dynamic> rpcRes,
    String devHash,
  ) async {
    final token = (rpcRes['stepup_token'] ?? '').toString().trim();
    final expiresAt = DateTime.tryParse(
          (rpcRes['expires_at'] ?? '').toString(),
        )?.toUtc() ??
        DateTime.now().toUtc().add(const Duration(minutes: 15));

    final session = FounderStepUpSession(
      stepUpCredentialHex: token,
      userId: _gateway.currentUserId ?? '',
      accountEmail: kMonocraticCeoEmail,
      deviceHashHex: devHash,
      expiresAtUtc: expiresAt,
    );
    _activeStepUpSession = session;
    await _startRealtimeBridgeAndHeartbeat();
    return session;
  }

  // ---------------------------------------------------------------------------
  // SNAPSHOT 100% REAL + STREAM DE TEMPO REAL (`ceo:war-room:live`) + FORENSE
  // ---------------------------------------------------------------------------

  Future<FounderDashboardSnapshot> fetchLiveSnapshot({
    String? windowKey,
  }) async {
    final session = _activeStepUpSession;
    if (session == null) {
      throw const CeoVaultSecurityException(
        errorCode: 'ERR_VAULT_LOCKED',
        userMessagePt: 'Desbloqueie seu Cofre Soberano com seu PIN pessoal.',
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

  /// Recupera qualquer evento emitido enquanto o celular esteve sem rede (`event_seq > afterSeq`).
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
          );
        }
      }
    } catch (_) {}
  }

  /// Tranca o Cofre Soberano (revoga o `stepup_token` no PostgreSQL, desliga o WebSocket
  /// privado e limpa a sessão em memória, mantendo o login primário do dono para rápido PIN).
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

  /// Tranca o Cofre e encerra completamente a sessão primária OAuth/Auth no aparelho.
  Future<void> signOutAndLock() async {
    await lockVault();
    _snapshot = FounderDashboardSnapshot.emptyZero();
    await _gateway.signOut();
  }

  FounderStepUpSession _requireActiveSession() {
    final s = _activeStepUpSession;
    if (s == null) {
      throw const CeoVaultSecurityException(
        errorCode: 'ERR_VAULT_LOCKED',
        userMessagePt: 'Cofre trancado. Digite seu PIN pessoal para continuar.',
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

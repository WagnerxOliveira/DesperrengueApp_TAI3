import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:desperrengue_app/core/analytics/founder_accountant_pack_service.dart';
import 'package:desperrengue_app/core/analytics/founder_dashboard_models.dart';
import 'package:desperrengue_app/core/analytics/founder_dp_optimization_engine.dart';
import 'package:desperrengue_app/core/boot/app_initialization_service.dart';
import 'package:desperrengue_app/core/state/theme_controller.dart';
import 'package:desperrengue_app/features/founder/data/founder_cockpit_repository.dart';
import 'package:desperrengue_app/features/founder/domain/ceo_strong_password_policy.dart';
import 'package:desperrengue_app/features/founder/presentation/founder_animations_and_shaders.dart';
import 'package:desperrengue_app/features/founder/presentation/founder_cockpit_screen.dart';
import 'package:desperrengue_app/features/founder/presentation/founder_deep_link_coordinator.dart';
import 'package:desperrengue_app/features/founder/presentation/founder_update_gate.dart';
import 'package:desperrengue_app/main_founder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gateway em memória 100% determinístico que simula fielmente os contratos
/// criptográficos do PostgreSQL 17 (`20261115000000`) + Edge Function
/// `ceo-vault-authority` + WebSocket privado `ceo:war-room:live`.
class FakeCeoBackendGateway implements CeoBackendGateway {
  FakeCeoBackendGateway({
    this.authenticatedEmailInitial,
    this.pbkdf2Iterations = 1200,
    FounderDashboardSnapshot? initialSnapshot,
  })  : _currentEmail = authenticatedEmailInitial,
        snapshotToReturn =
            initialSnapshot ?? FounderDashboardSnapshot.emptyZero();

  final String? authenticatedEmailInitial;
  final int pbkdf2Iterations;

  String? _currentEmail;
  final String _currentUserId = '00000000-0000-4000-8000-00000000ce01';

  final StreamController<String?> _authChanges =
      StreamController<String?>.broadcast();

  FounderDashboardSnapshot snapshotToReturn;
  final List<String> recordedCanaryCodes = <String>[];
  final List<String> dispatchedEmailKinds = <String>[];
  final List<CeoLiveEventItem> missedEventsQueue = <CeoLiveEventItem>[];
  int signOutCallCount = 0;
  int hydratedSessionCount = 0;

  String? _storedEdgeKeyVerifierHex;
  final List<String> _passwordHistoryVerifiers = <String>[];
  int _passwordVersion = 0;
  DateTime? _passwordUpdatedAtUtc;
  DateTime? _lastLoginAtUtc;

  final Set<String> _trustedDeviceHashes = <String>{};
  String _lastIssuedOtpCode = '482917';
  String _lastChallengeId = '11111111-2222-4333-8444-555555555555';
  String _lastChallengePurpose = '';
  String _lastChallengeDeviceHash = '';
  String? _validEnrollmentTicketHex;
  String? _activeStepUpTokenHex;

  String? _lastResetLinkId;
  String? _lastResetGrantTokenHex;
  String? _lastResetDeviceHash;
  bool _resetLinkConsumed = false;

  int _failedPasswordAttempts = 0;
  DateTime? _lockedUntilUtc;

  void Function(CeoLiveEventItem event)? _liveEventCallback;
  void Function(CeoRealtimeConnectionStatus status)? _statusCallback;

  String get lastIssuedOtpCode => _lastIssuedOtpCode;
  int get passwordVersion => _passwordVersion;

  Uri? get lastDispatchedResetDeepLinkUri {
    if (_lastResetLinkId == null || _lastResetGrantTokenHex == null) {
      return null;
    }
    return Uri.parse(
      'desperrengue-founder://vault/reset-password?lid=$_lastResetLinkId&gt=$_lastResetGrantTokenHex',
    );
  }

  /// Pré-sela uma Senha Mestra em memória para testes que já partem da Sala de Guerra.
  Future<FounderStepUpSession> preSealAndUnlockForTest({
    required FounderCockpitRepository repo,
    String masterPassword = 'K9#vM2\$pQ7!xR4&zL8',
  }) async {
    final otp = await repo.requestInitialBootstrapOtp(
      email: kMonocraticCeoEmail,
    );
    final ticketHex = await repo.verifyInitialBootstrapOtp(
      challengeId: otp.challengeId,
      sixDigitCode: _lastIssuedOtpCode,
    );
    return repo.createInitialMasterPassword(
      enrollmentTicketHex: ticketHex,
      masterPassword: masterPassword,
    );
  }

  void emitLiveRealtimeEvent(CeoLiveEventItem event) {
    _liveEventCallback?.call(event);
  }

  void emitRealtimeStatus(CeoRealtimeConnectionStatus status) {
    _statusCallback?.call(status);
  }

  String _computeServerVerifierFromClientKey(String clientKeyHex) {
    return sha256
        .convert(
          utf8.encode(
            'EDGE_PEPPER_V2:DB_PEPPER_512_AES256:${clientKeyHex.toLowerCase()}',
          ),
        )
        .toString()
        .toLowerCase();
  }

  String _extractOrDeriveClientKey(Map<String, dynamic> body) {
    final explicit = body['client_key_hex']?.toString().trim().toLowerCase();
    if (explicit != null && explicit.length == 64) {
      return explicit;
    }
    final rawPw = body['password']?.toString() ?? '';
    return CeoMasterPasswordCryptoEngine.deriveClientKeySync(
      rawPw,
      iterations: pbkdf2Iterations,
    );
  }

  @override
  String? get currentUserEmail => _currentEmail;

  @override
  String? get currentUserId => _currentEmail == null ? null : _currentUserId;

  @override
  Stream<String?> get authEmailChanges => _authChanges.stream;

  @override
  Future<void> hydrateSovereignSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    hydratedSessionCount++;
    _currentEmail = kMonocraticCeoEmail;
    _authChanges.add(_currentEmail);
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    _currentEmail = null;
    _activeStepUpTokenHex = null;
    _authChanges.add(null);
  }

  @override
  Future<void> reportIntrusionCanary({
    required String canaryCode,
    required Map<String, dynamic> meta,
  }) async {
    recordedCanaryCodes.add(canaryCode);
  }

  @override
  Future<Map<String, dynamic>> invokeVaultAuthority(
    Map<String, dynamic> body,
  ) async {
    final action = body['action']?.toString() ?? '';

    if (action == 'inspect_gate') {
      final email =
          (body['email'] ?? kMonocraticCeoEmail).toString().trim().toLowerCase();
      if (email != kMonocraticCeoEmail) {
        recordedCanaryCodes.add('EDGE_INSPECT_GATE_NON_OWNER');
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_MONOCRATIC_OWNER_ONLY_42501',
        };
      }
      return <String, dynamic>{
        'ok': true,
        'owner_email': kMonocraticCeoEmail,
        'password_configured': _storedEdgeKeyVerifierHex != null,
        'password_version': _passwordVersion,
        'password_updated_at': _passwordUpdatedAtUtc?.toIso8601String(),
        'locked_until': _lockedUntilUtc?.toIso8601String(),
      };
    }

    if (action == 'request_initial_bootstrap_otp') {
      final email = (body['email'] ?? '').toString().trim().toLowerCase();
      if (email != kMonocraticCeoEmail) {
        recordedCanaryCodes.add('EDGE_BOOTSTRAP_NON_OWNER');
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_MONOCRATIC_OWNER_ONLY_42501',
        };
      }
      if (_storedEdgeKeyVerifierHex != null) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_VAULT_ALREADY_SEALED',
        };
      }
      _lastIssuedOtpCode = '739204';
      _lastChallengeId = 'aaaaaaaa-bbbb-4ccc-8ddd-111111111111';
      _lastChallengePurpose = 'INITIAL_PASSWORD_SETUP';
      _lastChallengeDeviceHash = (body['device_hash'] ?? '').toString();
      dispatchedEmailKinds.add('INITIAL_PASSWORD_SETUP');
      return <String, dynamic>{
        'ok': true,
        'challenge_id': _lastChallengeId,
        'masked_destination': kMaskedMonocraticCeoEmail,
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
        'next_cooldown_seconds': 30,
      };
    }

    if (action == 'verify_initial_bootstrap_otp') {
      final cid = (body['challenge_id'] ?? '').toString();
      final code = (body['otp_code'] ?? '').toString();
      final devHash = (body['device_hash'] ?? '').toString();
      if (cid != _lastChallengeId ||
          _lastChallengePurpose != 'INITIAL_PASSWORD_SETUP' ||
          devHash != _lastChallengeDeviceHash ||
          code != _lastIssuedOtpCode) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_OTP_CODE_INCORRECT',
          'remaining_attempts': 4,
        };
      }
      _validEnrollmentTicketHex = List<String>.filled(64, 'e').join();
      return <String, dynamic>{
        'ok': true,
        'enrollment_ticket': _validEnrollmentTicketHex,
      };
    }

    if (action == 'set_initial_password') {
      final ticket = (body['enrollment_ticket'] ?? '').toString();
      final rawPw = (body['password'] ?? '').toString();
      final devHash = (body['device_hash'] ?? '').toString();
      if (_validEnrollmentTicketHex == null ||
          ticket != _validEnrollmentTicketHex) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_ENROLLMENT_TICKET_INVALID_OR_EXPIRED',
        };
      }
      final ev = CeoStrongPasswordPolicy.evaluate(rawPw);
      if (!ev.isApproved) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_WEAK_PASSWORD_POLICY',
          'failed_rules': ev.failedRuleCodes,
        };
      }
      final ck = _extractOrDeriveClientKey(body);
      final verifier = _computeServerVerifierFromClientKey(ck);
      _validEnrollmentTicketHex = null;
      _storedEdgeKeyVerifierHex = verifier;
      _passwordHistoryVerifiers.insert(0, verifier);
      _passwordVersion = 1;
      _passwordUpdatedAtUtc = DateTime.now().toUtc();
      _lastLoginAtUtc = _passwordUpdatedAtUtc;
      _trustedDeviceHashes.add(devHash);
      _failedPasswordAttempts = 0;
      _lockedUntilUtc = null;
      _activeStepUpTokenHex = List<String>.filled(64, 'a').join();
      return <String, dynamic>{
        'ok': true,
        'stepup_token': _activeStepUpTokenHex,
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 15))
            .toIso8601String(),
        'password_version': _passwordVersion,
        'access_token': 'jwt-access-v1',
        'refresh_token': 'jwt-refresh-v1',
      };
    }

    if (action == 'verify_password_and_send_login_otp') {
      final email = (body['email'] ?? '').toString().trim().toLowerCase();
      if (email != kMonocraticCeoEmail) {
        recordedCanaryCodes.add('EDGE_LOGIN_NON_OWNER');
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_MONOCRATIC_OWNER_ONLY_42501',
        };
      }
      if (_storedEdgeKeyVerifierHex == null) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_MASTER_PASSWORD_NOT_CONFIGURED',
        };
      }
      if (_lockedUntilUtc != null &&
          _lockedUntilUtc!.isAfter(DateTime.now().toUtc())) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_VAULT_LOCKED_BACKOFF',
          'failed_attempts': _failedPasswordAttempts,
          'locked_until': _lockedUntilUtc!.toIso8601String(),
        };
      }
      final ck = _extractOrDeriveClientKey(body);
      final candidateVerifier = _computeServerVerifierFromClientKey(ck);
      if (candidateVerifier != _storedEdgeKeyVerifierHex) {
        _failedPasswordAttempts++;
        if (_failedPasswordAttempts >= 4) {
          _lockedUntilUtc =
              DateTime.now().toUtc().add(const Duration(seconds: 60));
          if (_failedPasswordAttempts == 5) {
            dispatchedEmailKinds.add('SECURITY_INTRUSION_ALERT');
          }
          return <String, dynamic>{
            'ok': false,
            'error_code': 'ERR_VAULT_LOCKED_BACKOFF',
            'failed_attempts': _failedPasswordAttempts,
            'locked_until': _lockedUntilUtc!.toIso8601String(),
          };
        }
        // Zero envio de OTP quando a Senha Mestra está incorreta!
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_INVALID_MASTER_PASSWORD',
          'failed_attempts': _failedPasswordAttempts,
        };
      }

      _failedPasswordAttempts = 0;
      _lockedUntilUtc = null;
      _lastIssuedOtpCode = '618492';
      _lastChallengeId = 'bbbbbbbb-cccc-4ddd-8eee-222222222222';
      _lastChallengePurpose = 'LOGIN_2FA';
      _lastChallengeDeviceHash = (body['device_hash'] ?? '').toString();
      dispatchedEmailKinds.add('LOGIN_2FA');
      return <String, dynamic>{
        'ok': true,
        'challenge_id': _lastChallengeId,
        'masked_destination': kMaskedMonocraticCeoEmail,
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
        'next_cooldown_seconds': 30,
      };
    }

    if (action == 'resend_login_otp') {
      final prev = (body['previous_challenge_id'] ?? '').toString();
      final devHash = (body['device_hash'] ?? '').toString();
      if (prev != _lastChallengeId ||
          _lastChallengePurpose != 'LOGIN_2FA' ||
          devHash != _lastChallengeDeviceHash) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_OTP_CHALLENGE_EXPIRED',
        };
      }
      _lastIssuedOtpCode = '905317';
      _lastChallengeId = 'cccccccc-dddd-4eee-8fff-333333333333';
      dispatchedEmailKinds.add('LOGIN_2FA_RESEND');
      return <String, dynamic>{
        'ok': true,
        'challenge_id': _lastChallengeId,
        'masked_destination': kMaskedMonocraticCeoEmail,
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
        'next_cooldown_seconds': 45,
      };
    }

    if (action == 'complete_login_2fa') {
      final cid = (body['challenge_id'] ?? '').toString();
      final code = (body['otp_code'] ?? '').toString();
      final devHash = (body['device_hash'] ?? '').toString();
      if (cid != _lastChallengeId ||
          _lastChallengePurpose != 'LOGIN_2FA' ||
          devHash != _lastChallengeDeviceHash ||
          code != _lastIssuedOtpCode) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_OTP_CODE_INCORRECT',
          'remaining_attempts': 4,
        };
      }
      _trustedDeviceHashes.add(devHash);
      _lastLoginAtUtc = DateTime.now().toUtc();
      _activeStepUpTokenHex = List<String>.filled(64, 'b').join();
      return <String, dynamic>{
        'ok': true,
        'stepup_token': _activeStepUpTokenHex,
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 15))
            .toIso8601String(),
        'password_version': _passwordVersion,
        'access_token': 'jwt-access-login-2fa',
        'refresh_token': 'jwt-refresh-login-2fa',
      };
    }

    if (action == 'get_ceo_profile_security_status') {
      final token = (body['stepup_token'] ?? '').toString();
      if (_activeStepUpTokenHex == null || token != _activeStepUpTokenHex) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_STEPUP_SESSION_EXPIRED_OR_REVOKED',
        };
      }
      final devHash = (body['device_hash'] ?? '').toString();
      return <String, dynamic>{
        'ok': true,
        'owner_email': kMonocraticCeoEmail,
        'password_configured': _storedEdgeKeyVerifierHex != null,
        'password_version': _passwordVersion,
        'kdf_spec':
            'edge:pbkdf2-sha256:210000+hmac-sha256|db:hmac-sha512:25000+pgp-aes256',
        'active_sessions_count': 1,
        'protected_history_depth': _passwordHistoryVerifiers.length,
        'device_hash_prefix':
            devHash.length >= 12 ? devHash.substring(0, 12) : devHash,
        'password_updated_at': _passwordUpdatedAtUtc?.toIso8601String(),
        'last_login_at': _lastLoginAtUtc?.toIso8601String(),
      };
    }

    if (action == 'request_password_change_otp') {
      final token = (body['stepup_token'] ?? '').toString();
      if (_activeStepUpTokenHex == null || token != _activeStepUpTokenHex) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_STEPUP_SESSION_EXPIRED_OR_REVOKED',
        };
      }
      _lastIssuedOtpCode = '842159';
      _lastChallengeId = 'dddddddd-eeee-4fff-8aaa-444444444444';
      _lastChallengePurpose = 'PROFILE_PASSWORD_CHANGE_AUTH';
      _lastChallengeDeviceHash = (body['device_hash'] ?? '').toString();
      dispatchedEmailKinds.add('PROFILE_PASSWORD_CHANGE_AUTH_EMAIL_1');
      return <String, dynamic>{
        'ok': true,
        'challenge_id': _lastChallengeId,
        'masked_destination': kMaskedMonocraticCeoEmail,
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
        'next_cooldown_seconds': 30,
      };
    }

    if (action == 'verify_password_change_otp_and_dispatch_link') {
      final token = (body['stepup_token'] ?? '').toString();
      final cid = (body['challenge_id'] ?? '').toString();
      final code = (body['otp_code'] ?? '').toString();
      final devHash = (body['device_hash'] ?? '').toString();
      if (_activeStepUpTokenHex == null || token != _activeStepUpTokenHex) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_STEPUP_SESSION_EXPIRED_OR_REVOKED',
        };
      }
      if (cid != _lastChallengeId ||
          _lastChallengePurpose != 'PROFILE_PASSWORD_CHANGE_AUTH' ||
          devHash != _lastChallengeDeviceHash ||
          code != _lastIssuedOtpCode) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_OTP_CODE_INCORRECT',
          'remaining_attempts': 4,
        };
      }
      _lastResetLinkId = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';
      _lastResetGrantTokenHex =
          'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
      _lastResetDeviceHash = devHash;
      _resetLinkConsumed = false;
      dispatchedEmailKinds.add('PASSWORD_CHANGE_LINK_UNLOCKED_EMAIL_2');
      return <String, dynamic>{
        'ok': true,
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
      };
    }

    if (action == 'commit_password_reset_from_link') {
      final lid = (body['link_id'] ?? '').toString().toLowerCase();
      final gt = (body['grant_token'] ?? '').toString().toLowerCase();
      final devHash = (body['device_hash'] ?? '').toString();
      final rawPw = (body['password'] ?? '').toString();

      if (_resetLinkConsumed ||
          _lastResetLinkId == null ||
          lid != _lastResetLinkId ||
          gt != _lastResetGrantTokenHex) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_RESET_LINK_INVALID_OR_EXPIRED',
        };
      }
      if (_lastResetDeviceHash != null && devHash != _lastResetDeviceHash) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_RESET_LINK_DEVICE_MISMATCH',
        };
      }

      final ev = CeoStrongPasswordPolicy.evaluate(rawPw);
      if (!ev.isApproved) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_WEAK_PASSWORD_POLICY',
          'failed_rules': ev.failedRuleCodes,
        };
      }

      final ck = _extractOrDeriveClientKey(body);
      final newVerifier = _computeServerVerifierFromClientKey(ck);
      if (_passwordHistoryVerifiers.take(5).contains(newVerifier)) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_PASSWORD_RECENTLY_USED',
        };
      }

      _resetLinkConsumed = true;
      _storedEdgeKeyVerifierHex = newVerifier;
      _passwordHistoryVerifiers.insert(0, newVerifier);
      _passwordVersion++;
      _passwordUpdatedAtUtc = DateTime.now().toUtc();
      _activeStepUpTokenHex = null; // revoga 100% das sessões anteriores!
      dispatchedEmailKinds.add('PASSWORD_CHANGED_AUDIT_RECEIPT');
      return <String, dynamic>{
        'ok': true,
        'password_version': _passwordVersion,
      };
    }

    return <String, dynamic>{'ok': false, 'error_code': 'ERR_UNKNOWN_ACTION'};
  }

  @override
  Future<Map<String, dynamic>> callRpc(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    if (functionName == 'ceo_vault_status') {
      if (_currentEmail != kMonocraticCeoEmail) {
        recordedCanaryCodes.add('RPC_NON_OWNER_BLOCKED');
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_MONOCRATIC_OWNER_ONLY_42501',
        };
      }
      final devHash = params['p_device_hash']?.toString() ?? '';
      return <String, dynamic>{
        'ok': true,
        'owner_email': kMonocraticCeoEmail,
        'pin_configured': _storedEdgeKeyVerifierHex != null,
        'password_configured': _storedEdgeKeyVerifierHex != null,
        'password_version': _passwordVersion,
        'device_trusted': _trustedDeviceHashes.contains(devHash),
        'pin_algo_version':
            'CLIENT_PBKDF2_210K_EDGE_PEPPER_PG_HMAC512_25K_PGP_AES256_V2',
        'failed_pin_attempts': _failedPasswordAttempts,
        'locked_until': _lockedUntilUtc?.toIso8601String(),
      };
    }

    if (functionName == 'ceo_get_live_cockpit_snapshot') {
      final win = params['p_window_key']?.toString() ?? '30d';
      final json = snapshotToReturn.toJson();
      json['window_key'] = win;
      return json;
    }

    if (functionName == 'ceo_fetch_live_events_since') {
      final afterSeq = (params['p_after_seq'] as num?)?.toInt() ?? 0;
      final fresh = missedEventsQueue
          .where((e) => e.eventSeq > afterSeq)
          .map((e) => e.toJson())
          .toList();
      return <String, dynamic>{'events': fresh};
    }

    if (functionName == 'ceo_inspect_order_forensics') {
      final jobId = params['p_job_id']?.toString() ?? '';
      return <String, dynamic>{
        'job': <String, dynamic>{
          'job_id': jobId,
          'order_code': '#DESP-REAL1',
          'title': 'Reparo Hidráulico Residencial',
          'description': 'Troca de registro com verificação GPS real',
          'category': 'Encanador',
          'status': 'in_progress',
          'payment_status': 'paid_escrow',
          'escrow_status': 'HELD',
          'agreed_price_cents': 25000,
          'labor_cents': 20000,
          'materials_cents': 5000,
          'checkin_distance_m': 14,
        },
        'client': <String, dynamic>{
          'full_name': 'Marina Real',
          'city': 'São Paulo',
          'client_kyc_status': 'APPROVED',
        },
        'provider': <String, dynamic>{
          'full_name': 'Carlos Mestre',
          'city': 'São Paulo',
          'verification_status': 'ACTIVE',
          'jobs_done': 8,
        },
        'location': <String, dynamic>{
          'neighborhood': 'Pinheiros',
          'city': 'São Paulo',
          'uf': 'SP',
          'address_line': 'Rua dos Pinheiros, 500',
        },
        'quotes': <Map<String, dynamic>>[
          <String, dynamic>{
            'provider_name': 'Carlos Mestre',
            'status': 'accepted',
            'amount_cents': 25000,
          },
        ],
        'invites': const <Map<String, dynamic>>[],
        'payments': const <Map<String, dynamic>>[],
        'ledger_txns': <Map<String, dynamic>>[
          <String, dynamic>{
            'entry_kind': 'ESCROW_HOLD',
            'bucket': 'CLIENT_ESCROW',
            'amount_cents': 25000,
          },
        ],
        'maturation_entries': const <Map<String, dynamic>>[],
        'fiscal_documents': const <Map<String, dynamic>>[],
        'mediations': const <Map<String, dynamic>>[],
        'reviews': const <Map<String, dynamic>>[],
      };
    }

    if (functionName == 'ceo_list_real_users_directory') {
      return <String, dynamic>{
        'users': <Map<String, dynamic>>[
          <String, dynamic>{
            'user_id': 'u-real-1',
            'full_name': 'Marina Real',
            'city': 'São Paulo',
            'is_client': true,
            'is_provider': false,
            'client_kyc_status': 'APPROVED',
            'biometric_verified': true,
            'specialties': const <String>[],
            'rating_avg': 5.0,
            'rating_count': 2,
            'jobs_done': 0,
            'client_jobs_count': 2,
            'accepting_jobs': false,
            'client_wallet_available_cents': 5000,
            'client_wallet_escrow_cents': 25000,
            'provider_wallet_cents': 0,
            'created_at': DateTime.utc(2026, 11, 14).toIso8601String(),
          },
        ],
      };
    }

    if (functionName == 'ceo_record_real_expense') {
      final newEntry = CeoRealExpenseEntry(
        id: 'exp-${snapshotToReturn.realExpenses.length + 1}',
        competenceDateIso:
            params['p_competence_date']?.toString() ?? '2026-11-14',
        expenseKind: params['p_expense_kind']?.toString() ?? 'FIXED_OPEX',
        category: params['p_category']?.toString() ?? 'Cloud',
        description: params['p_description']?.toString() ?? '',
        amountCents: (params['p_amount_cents'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.now().toUtc(),
      );
      final updatedExpenses = <CeoRealExpenseEntry>[
        newEntry,
        ...snapshotToReturn.realExpenses,
      ];
      final fixedSum = updatedExpenses
          .where((e) => e.expenseKind == 'FIXED_OPEX')
          .fold<int>(0, (acc, e) => acc + e.amountCents);
      final newDre = FounderDreCents.computeFromComponents(
        laborGrossCents: snapshotToReturn.dreCents.laborGrossCents,
        materialsExemptCents: snapshotToReturn.dreCents.materialsExemptCents,
        sosFeeRevenueCents: snapshotToReturn.dreCents.sosFeeRevenueCents,
        completedOrdersCount: snapshotToReturn.dreCents.completedOrdersCount,
        fixedOpexCents: fixedSum,
      );
      snapshotToReturn = snapshotToReturn.copyWith(
        dreCents: newDre,
        realExpenses: updatedExpenses,
      );
      return <String, dynamic>{'ok': true};
    }

    if (functionName == 'ceo_lock_sovereign_vault') {
      _activeStepUpTokenHex = null;
      return <String, dynamic>{'ok': true};
    }

    return <String, dynamic>{'ok': true};
  }

  @override
  Future<void Function()> subscribeWarRoomLive({
    required void Function(CeoLiveEventItem event) onLiveEvent,
    required void Function(CeoRealtimeConnectionStatus status) onStatusChanged,
  }) async {
    _liveEventCallback = onLiveEvent;
    _statusCallback = onStatusChanged;
    onStatusChanged(CeoRealtimeConnectionStatus.liveConnected);
    return () {
      _liveEventCallback = null;
      onStatusChanged(CeoRealtimeConnectionStatus.disconnected);
    };
  }
}

FounderDashboardSnapshot _buildSampleRealSnapshot() {
  final dre = FounderDreCents.computeFromComponents(
    laborGrossCents: 100000,
    materialsExemptCents: 25000,
    sosFeeRevenueCents: 2000,
    completedOrdersCount: 4,
    fixedOpexCents: 3000,
  );
  final recon = FounderThreeWayReconciliation.compute(
    pixTopupsConfirmedCents: 127000,
    ledgerNetSumCents: 127000,
    walletsAndEscrowTotalCents: 127000,
  );
  const demo = FounderDemographicsSummary(
    onlyClientsCount: 5,
    onlyProvidersCount: 3,
    dualModeBothCount: 2,
    onboardingIncompleteCount: 1,
    totalUsersCount: 11,
    newUsersInWindowCount: 4,
    kycVerifiedCount: 8,
    kycPendingCount: 2,
    kycRejectedCount: 0,
    kycNotSubmittedCount: 1,
    biometricVerifiedCount: 8,
    ocrVerifiedCount: 8,
    lgpdDeletedClientCount: 0,
    lgpdDeletedProviderCount: 0,
    lgpdDeletedAllCount: 0,
  );
  return FounderDashboardSnapshot.emptyZero(
    generatedAt: DateTime.utc(2026, 11, 14, 15, 0),
  ).copyWith(
    latestEventSeq: 10,
    demographics: demo,
    dreCents: dre,
    reconciliation: recon,
    livePulse: const CeoLiveOperationsPulse(
      openJobsCount: 1,
      awaitingPaymentCount: 0,
      scheduledJobsCount: 1,
      inProgressJobsCount: 1,
      awaitingApprovalCount: 0,
      completedAllTimeCount: 4,
      canceledInWindowCount: 0,
      disputedJobsCount: 0,
      quotesInWindowCount: 5,
      quotesPendingCount: 2,
      quotesAcceptedInWindowCount: 3,
      invitesPendingCount: 1,
      pixPendingCount: 0,
      reviewsTotalCount: 4,
      reviewsAvgBps: 4950,
    ),
    treasury: const FounderTreasurySummary(
      availableWalletsCents: 82000,
      activeExecutionEscrowCents: 25000,
      maturationD0D2Cents: 10000,
      maturationD5Cents: 10000,
      maturationD7Cents: 0,
      availableForPixPayoutCents: 0,
      frozenMediationCents: 0,
      frozenUnderDuressCents: 0,
      estimatedMonthlyCdiFloatCents: 1100,
    ),
    actuarialPool: const FounderActuarialPoolSummary(
      runningBalanceCents: 15000,
      activeExposureCents: 8000,
      icaRatioBps: 18750,
      fcrLayer1Bps: 10000,
      clawbackRecoveredCents: 0,
      claimsPaidCents: 0,
    ),
    liveMapPoints: <CeoLiveMapPoint>[
      CeoLiveMapPoint(
        jobId: 'job-real-1',
        orderCode: '#DESP-REAL1',
        title: 'Reparo Hidráulico Residencial',
        categoryName: 'Encanador',
        status: 'in_progress',
        escrowStatus: 'HELD',
        urgency: 'immediate',
        lat: -23.5614,
        lng: -46.6559,
        isExactPin: true,
        amountCents: 25000,
        neighborhood: 'Pinheiros',
        city: 'São Paulo',
        uf: 'SP',
        clientName: 'Marina Real',
        providerName: 'Carlos Mestre',
        createdAt: DateTime.utc(2026, 11, 14, 14, 30),
      ),
    ],
    recentOrdersMicroPnl: <OrderMicroPnlRecord>[
      OrderMicroPnlRecord(
        orderCode: '#DESP-REAL1',
        jobId: 'job-real-1',
        title: 'Reparo Hidráulico Residencial',
        categoryName: 'Encanador',
        neighborhood: 'Pinheiros',
        createdAt: DateTime.utc(2026, 11, 14, 14, 30),
        status: 'in_progress',
        clientName: 'Marina Real',
        providerName: 'Carlos Mestre',
        gmvCents: 25000,
        laborCents: 20000,
        materialsExemptCents: 5000,
        nfeVerified: true,
        providerNetCents: 17000,
        platformFeeCents: 2700,
        poolCarveoutCents: 300,
        taxDasCents: 162,
        pixCloudCostCents: 0,
        netMarginCents: 2538,
        escrowStatus: 'HELD',
      ),
    ],
    liveEvents: <CeoLiveEventItem>[
      CeoLiveEventItem(
        eventSeq: 10,
        eventType: 'JOB_IN_PROGRESS',
        severity: 'FINANCE',
        title: 'Execução iniciada #DESP-REAL1',
        subtitle: 'Encanador · Pinheiros, São Paulo',
        entityTable: 'jobs',
        entityId: 'job-real-1',
        amountCents: 25000,
        metadata: const <String, dynamic>{'job_id': 'job-real-1'},
        occurredAt: DateTime.utc(2026, 11, 14, 14, 45),
      ),
    ],
    dailySeries: <FounderDailyMetricPoint>[
      const FounderDailyMetricPoint(
        dayIso: '2026-11-13',
        ordersCount: 2,
        gmvCents: 60000,
        laborCents: 50000,
        materialsExemptCents: 10000,
        platformRevenueCents: 6750,
        poolCarveoutCents: 750,
        taxDasCents: 405,
        variableCostCents: 0,
        netProfitCents: 6345,
        warrantyClaimsCents: 0,
      ),
      const FounderDailyMetricPoint(
        dayIso: '2026-11-14',
        ordersCount: 2,
        gmvCents: 65000,
        laborCents: 50000,
        materialsExemptCents: 15000,
        platformRevenueCents: 8750,
        poolCarveoutCents: 750,
        taxDasCents: 525,
        variableCostCents: 0,
        netProfitCents: 5225,
        warrantyClaimsCents: 0,
      ),
    ],
    trustedDevices: <CeoTrustedDeviceItem>[
      CeoTrustedDeviceItem(
        deviceId: 'dev-1',
        deviceLabel: 'Desperrengue CEO · Android Blindado',
        fingerprintPrefix: 'f1f1f1f1f1f1',
        isCurrentDevice: true,
        boundAt: DateTime.utc(2026, 11, 14, 12, 0),
        lastSeenAt: DateTime.utc(2026, 11, 14, 15, 0),
      ),
    ],
  );
}

Widget _wrapFounderTestApp({
  required Widget child,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final theme = FounderSovereignTokens.buildTheme();
  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const <Locale>[Locale('pt', 'BR')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      builder: (context, inner) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: textScaler),
          child: inner ?? const SizedBox.shrink(),
        );
      },
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  const strongMasterPasswordV1 = 'K9#vM2\$pQ7!xR4&zL8';
  const strongMasterPasswordV2 = 'Z8@qW3!mN7#pL5\$vR2';

  // ===========================================================================
  // PILAR 1: IDENTIDADE MONOCRÁTICA (`wagneroliveira2395@gmail.com`), SENHA MESTRA AES-256 & 2FA 6D
  // ===========================================================================
  group('Pillar 1 — Monocratic Single-Owner Vault, AES-256 Master Password & 2FA', () {
    test('Blocks every non-owner email, logs INTRUSION_CANARY, and dispatches zero emails', () async {
      final gw = FakeCeoBackendGateway(pbkdf2Iterations: 1200);
      final repo = FounderCockpitRepository(
        gateway: gw,
        pbkdf2Iterations: 1200,
      );
      addTearDown(repo.dispose);

      for (final intruder in const <String>[
        'intruder@attacker.org',
        'wagner.ceo@desperrengue.com.br',
        'wagneroliveira2395@evil.com',
      ]) {
        await expectLater(
          () => repo.requestInitialBootstrapOtp(email: intruder),
          throwsA(
            isA<CeoVaultSecurityException>().having(
              (e) => e.errorCode,
              'errorCode',
              equals('ERR_MONOCRATIC_OWNER_ONLY_42501'),
            ),
          ),
        );
        await expectLater(
          () => repo.verifyMasterPasswordAndRequestLoginOtp(
            email: intruder,
            masterPassword: strongMasterPasswordV1,
          ),
          throwsA(
            isA<CeoVaultSecurityException>().having(
              (e) => e.errorCode,
              'errorCode',
              equals('ERR_MONOCRATIC_OWNER_ONLY_42501'),
            ),
          ),
        );
      }

      expect(gw.recordedCanaryCodes.length, equals(6));
      expect(gw.dispatchedEmailKinds, isEmpty);
      expect(repo.authenticatedEmail, isNull);
    });

    test('Completes First-Access Bootstrap -> Daily 2FA Login -> Anti-Inbox-Bombing Lockout -> 2-Email + Deep-Link Rotation', () async {
      final gw = FakeCeoBackendGateway(
        pbkdf2Iterations: 1200,
        initialSnapshot: _buildSampleRealSnapshot(),
      );
      final repo = FounderCockpitRepository(
        gateway: gw,
        pbkdf2Iterations: 1200,
      );
      addTearDown(repo.dispose);

      // 1. Inspeção inicial: cofre ainda sem senha criada (passwordConfigured == false)
      final initialGate = await repo.inspectSovereignGate();
      expect(initialGate.passwordConfigured, isFalse);
      expect(initialGate.passwordVersion, equals(0));

      // 2. Primeiro acesso: código de 6 dígitos enviado exclusivamente para wagneroliveira2395@gmail.com
      final bootstrapOtp = await repo.requestInitialBootstrapOtp(
        email: kMonocraticCeoEmail,
      );
      expect(bootstrapOtp.maskedDestination, equals(kMaskedMonocraticCeoEmail));

      await expectLater(
        () => repo.verifyInitialBootstrapOtp(
          challengeId: bootstrapOtp.challengeId,
          sixDigitCode: '000000',
        ),
        throwsA(
          isA<CeoVaultSecurityException>().having(
            (e) => e.errorCode,
            'errorCode',
            equals('ERR_OTP_CODE_INCORRECT'),
          ),
        ),
      );

      final enrollmentTicket = await repo.verifyInitialBootstrapOtp(
        challengeId: bootstrapOtp.challengeId,
        sixDigitCode: gw.lastIssuedOtpCode,
      );
      expect(enrollmentTicket.length, equals(64));

      // 3. Rejeita senha fraca e aceita Senha Mestra Forte em AES-256 (hidratando sessão in-app sem navegador!)
      await expectLater(
        () => repo.createInitialMasterPassword(
          enrollmentTicketHex: enrollmentTicket,
          masterPassword: 'Wagner2395!',
        ),
        throwsA(
          isA<CeoVaultSecurityException>().having(
            (e) => e.errorCode,
            'errorCode',
            equals('ERR_WEAK_PASSWORD_POLICY'),
          ),
        ),
      );

      final sessionV1 = await repo.createInitialMasterPassword(
        enrollmentTicketHex: enrollmentTicket,
        masterPassword: strongMasterPasswordV1,
      );
      expect(sessionV1.accountEmail, equals(kMonocraticCeoEmail));
      expect(sessionV1.passwordVersion, equals(1));
      expect(gw.hydratedSessionCount, equals(1));

      // 4. Tranca o cofre e testa Login Diário 2FA + Anti-Inbox-Bombing (senha errada envia ZERO e-mails OTP!)
      await repo.lockVault();
      final emailCountBeforeWrongPw = gw.dispatchedEmailKinds.length;

      await expectLater(
        () => repo.verifyMasterPasswordAndRequestLoginOtp(
          email: kMonocraticCeoEmail,
          masterPassword: 'Wrong#92\$Kp7!xR4&zL',
        ),
        throwsA(
          isA<CeoVaultSecurityException>().having(
            (e) => e.errorCode,
            'errorCode',
            equals('ERR_INVALID_MASTER_PASSWORD'),
          ),
        ),
      );
      expect(
        gw.dispatchedEmailKinds.length,
        equals(emailCountBeforeWrongPw),
        reason: 'Senha incorreta jamais pode disparar código OTP no e-mail do CEO',
      );

      final loginOtp = await repo.verifyMasterPasswordAndRequestLoginOtp(
        email: kMonocraticCeoEmail,
        masterPassword: strongMasterPasswordV1,
      );
      expect(gw.dispatchedEmailKinds.last, equals('LOGIN_2FA'));

      final unlockedLogin = await repo.completeLoginTwoFactor(
        challengeId: loginOtp.challengeId,
        sixDigitCode: gw.lastIssuedOtpCode,
      );
      expect(unlockedLogin.stepUpCredentialHex, isNotEmpty);

      // 5. Perfil do CEO: Cerimônia em 2 E-mails + Deep-Link Efêmero
      final profileOtp = await repo.requestProfilePasswordChangeOtp();
      expect(
        gw.dispatchedEmailKinds.last,
        equals('PROFILE_PASSWORD_CHANGE_AUTH_EMAIL_1'),
      );

      await repo.verifyProfileOtpAndDispatchResetLink(
        challengeId: profileOtp.challengeId,
        sixDigitCode: gw.lastIssuedOtpCode,
      );
      expect(
        gw.dispatchedEmailKinds.last,
        equals('PASSWORD_CHANGE_LINK_UNLOCKED_EMAIL_2'),
      );

      final resetUri = gw.lastDispatchedResetDeepLinkUri!;
      final linkId = resetUri.queryParameters['lid']!;
      final grantToken = resetUri.queryParameters['gt']!;

      // Bloqueia reutilização da senha anterior (histórico protegido de 5 senhas)
      await expectLater(
        () => repo.commitPasswordResetFromDeepLink(
          linkId: linkId,
          grantTokenHex: grantToken,
          newMasterPassword: strongMasterPasswordV1,
        ),
        throwsA(
          isA<CeoVaultSecurityException>().having(
            (e) => e.errorCode,
            'errorCode',
            equals('ERR_PASSWORD_RECENTLY_USED'),
          ),
        ),
      );

      // Salva nova Senha Mestra Forte -> incrementa passwordVersion para 2 e encerra todas as sessões!
      await repo.commitPasswordResetFromDeepLink(
        linkId: linkId,
        grantTokenHex: grantToken,
        newMasterPassword: strongMasterPasswordV2,
      );
      expect(repo.activeStepUpSession, isNull);
      expect(gw.passwordVersion, equals(2));

      // Replay do mesmo link é bloqueado imediatamente
      await expectLater(
        () => repo.commitPasswordResetFromDeepLink(
          linkId: linkId,
          grantTokenHex: grantToken,
          newMasterPassword: 'M7#pL5\$vR2!qW8@zX4',
        ),
        throwsA(
          isA<CeoVaultSecurityException>().having(
            (e) => e.errorCode,
            'errorCode',
            equals('ERR_RESET_LINK_INVALID_OR_EXPIRED'),
          ),
        ),
      );

      // Senha antiga não entra mais; nova senha + novo código de 6 dígitos abrem a Sala de Guerra!
      await expectLater(
        () => repo.verifyMasterPasswordAndRequestLoginOtp(
          email: kMonocraticCeoEmail,
          masterPassword: strongMasterPasswordV1,
        ),
        throwsA(isA<CeoVaultSecurityException>()),
      );

      final loginV2Otp = await repo.verifyMasterPasswordAndRequestLoginOtp(
        email: kMonocraticCeoEmail,
        masterPassword: strongMasterPasswordV2,
      );
      final sessionV2 = await repo.completeLoginTwoFactor(
        challengeId: loginV2Otp.challengeId,
        sixDigitCode: gw.lastIssuedOtpCode,
      );
      expect(sessionV2.passwordVersion, equals(2));
    });
  });

  // ===========================================================================
  // PILAR 2: ZERO-FAKE POLICY, STREAM EM TEMPO REAL (`WSS`) & RECONEXÃO SEM PERDA
  // ===========================================================================
  group('Pillar 2 — Zero-Fake Empty State & Encrypted Real-Time Bridge', () {
    test('emptyZero snapshot contains 100% zeros and zero synthetic artifacts', () {
      final zero = FounderDashboardSnapshot.emptyZero();
      expect(zero.dreCents.gmvTotalCents, equals(0));
      expect(zero.dreCents.platformGrossRevenueCents, equals(0));
      expect(zero.dreCents.fixedOpexCents, equals(0));
      expect(zero.demographics.totalUsersCount, equals(0));
      expect(zero.livePulse.activeOrdersTotalCount, equals(0));
      expect(zero.liveMapPoints, isEmpty);
      expect(zero.recentOrdersMicroPnl, isEmpty);
      expect(zero.securityWatch.duressIncidents, isEmpty);
      expect(zero.reconciliation.threeWayReconciliationOk, isTrue);
      expect(zero.categoryLiquidity.length, equals(33));
      expect(zero.categoryLiquidity.every((c) => c.demandCount == 0), isTrue);
    });

    test('Receives instant WebSocket live events and recovers missed events on reconnect', () async {
      final gw = FakeCeoBackendGateway(
        pbkdf2Iterations: 1200,
        initialSnapshot: _buildSampleRealSnapshot(),
      );
      final repo = FounderCockpitRepository(
        gateway: gw,
        pbkdf2Iterations: 1200,
      );
      addTearDown(repo.dispose);

      await gw.preSealAndUnlockForTest(repo: repo);
      await repo.fetchLiveSnapshot();
      expect(repo.currentSnapshot.latestEventSeq, equals(10));

      final liveArrivals = <CeoLiveEventItem>[];
      final sub = repo.liveEventArrivals.listen(liveArrivals.add);
      addTearDown(sub.cancel);

      gw.emitLiveRealtimeEvent(
        CeoLiveEventItem(
          eventSeq: 11,
          eventType: 'PIX_CONFIRMED',
          severity: 'FINANCE',
          title: 'PIX confirmado R\$ 180,00',
          subtitle: 'Recarga de carteira liquidada',
          entityTable: 'pix_topups',
          entityId: 'pix-11',
          amountCents: 18000,
          metadata: const <String, dynamic>{},
          occurredAt: DateTime.utc(2026, 11, 14, 15, 5),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(liveArrivals.length, equals(1));
      expect(repo.currentSnapshot.latestEventSeq, equals(11));
      expect(repo.currentSnapshot.liveEvents.first.eventSeq, equals(11));

      gw.missedEventsQueue.add(
        CeoLiveEventItem(
          eventSeq: 12,
          eventType: 'NEW_USER_PROFILE',
          severity: 'INFO',
          title: 'Novo cadastro no Desperrengue',
          subtitle: 'Prestador em São Paulo',
          entityTable: 'profiles',
          entityId: 'u-12',
          amountCents: 0,
          metadata: const <String, dynamic>{},
          occurredAt: DateTime.utc(2026, 11, 14, 15, 6),
        ),
      );
      gw.emitRealtimeStatus(CeoRealtimeConnectionStatus.reconnecting);
      gw.emitRealtimeStatus(CeoRealtimeConnectionStatus.liveConnected);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(repo.currentSnapshot.latestEventSeq, equals(12));
    });
  });

  // ===========================================================================
  // PILAR 3: MATEMÁTICA CONTÁBIL CPC 47, MOTORES DP, PDF SHA-256 & OTA CEO
  // ===========================================================================
  group('Pillar 3 — Accounting Invariants, DP Engines, PDF Seal & CEO OTA', () {
    test('CPC 47 integer split, 1-centavo 3-way reconciliation & %PDF-1.4 SHA-256 pack', () {
      final snap = _buildSampleRealSnapshot();
      expect(snap.dreCents.allAccountingInvariantsOk, isTrue);
      expect(snap.reconciliation.threeWayReconciliationOk, isTrue);

      final brokenRecon = FounderThreeWayReconciliation.compute(
        pixTopupsConfirmedCents: 127000,
        ledgerNetSumCents: 127000,
        walletsAndEscrowTotalCents: 126999,
      );
      expect(brokenRecon.threeWayReconciliationOk, isFalse);
      expect(brokenRecon.discrepancyCents.abs(), equals(1));

      const packSvc = FounderAccountantPackService();
      final pack = packSvc.generateMonthlyPackSync(snap);
      expect(pack.pdfBytes.length, greaterThan(500));
      expect(utf8.decode(pack.pdfBytes.take(8).toList()), startsWith('%PDF-1.4'));
      expect(pack.verifyIntegrity(), isTrue);

      final timeline = PrefixSumFinancialTimeline(snap.dailySeries);
      expect(timeline.queryLastDays(7).gmvCents, equals(125000));

      const detector = AntiBypassAndLeakageDetector();
      final bypass = detector.evaluateRisk(
        chatSnippet: 'm3 ch4m4 n0 z4p 11 99887 6655',
        cancelledWithinMinutesAfterChat: 8,
        laborCents: 3000,
        materialsExemptCents: 25000,
        hasVerified44DigitNfe: false,
      );
      expect(bypass.compositeRiskBps, greaterThanOrEqualTo(5000));
    });

    test('FounderUpdateService selects strictly desperrengue-founder-ceo.apk, parses SHA-256 + size, and caches ETag 304', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const expectedCeoSha =
          'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
      const releaseJson = '''
      {
        "body": "build: 202611150\\nversion: 2.14.0\\n## Novidades\\nfeat(ceo): cofre soberano de senha mestra AES-256\\n\\n---\\n- SHA-256 (`desperrengue.apk`): `ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff`\\n- SHA-256 (`desperrengue-founder-ceo.apk`): `$expectedCeoSha`",
        "assets": [
          {
            "name": "desperrengue.apk",
            "size": 54000000,
            "browser_download_url": "https://github.com/org/repo/releases/download/beta-latest/desperrengue.apk"
          },
          {
            "name": "desperrengue-founder-ceo.apk",
            "size": 57671680,
            "browser_download_url": "https://github.com/org/repo/releases/download/beta-latest/desperrengue-founder-ceo.apk"
          }
        ]
      }
      ''';
      final info = FounderUpdateService.parseFounderRelease(
        releaseJson,
        currentBuild: 202611140,
        repo: 'org/repo',
      );
      expect(info, isNotNull);
      expect(info!.apkUrl, endsWith('/desperrengue-founder-ceo.apk'));
      expect(info.version, equals('2.14.0'));
      expect(info.sizeBytes, equals(57671680));
      expect(info.sizeLabel, equals('55 MB'));
      expect(info.sha256, equals(expectedCeoSha));

      var seenIfNoneMatch = '';
      var callCount = 0;
      final mockHttp = MockClient((req) async {
        callCount++;
        seenIfNoneMatch = req.headers['If-None-Match'] ?? '';
        if (callCount == 1) {
          return http.Response(
            releaseJson,
            200,
            headers: <String, String>{'etag': 'W/"ceo-etag-150"'},
          );
        }
        return http.Response('', 304);
      });

      final svc = FounderUpdateService(
        client: mockHttp,
        buildNumber: () async => 202611140,
        repo: 'org/repo',
      );
      final first = await svc.check();
      expect(first, isNotNull);
      expect(first!.build, equals(202611150));

      final second = await svc.check();
      expect(seenIfNoneMatch, equals('W/"ceo-etag-150"'));
      expect(second, isNotNull);
      expect(second!.sha256, equals(expectedCeoSha));
    });
  });

  // ===========================================================================
  // PILAR 4: E2E WIDGET CEREMONIES (ZERO OAUTH, 64-CHAR CAP, PERFIL 2-EMAILS + DEEP-LINK & VIEWPORTS)
  // ===========================================================================
  group('Pillar 4 — Sovereign Auth UI, 64-Char Cap, Profile 2-Email Deep-Link & Multi-Viewport', () {
    testWidgets('E2E Ceremony: Blank Gate, Zero Google OAuth Button, 64-Char Physical Cap, Bootstrap & 2-Email Deep-Link Password Rotation', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final gw = FakeCeoBackendGateway(
        pbkdf2Iterations: 1200,
        initialSnapshot: _buildSampleRealSnapshot(),
      );
      final repo = FounderCockpitRepository(
        gateway: gw,
        pbkdf2Iterations: 1200,
      );
      addTearDown(repo.dispose);

      final linkStream = StreamController<Uri>.broadcast();
      addTearDown(linkStream.close);
      final deepLinkCoordinator = FounderDeepLinkCoordinator(
        getInitialLinkOverride: () async => null,
        uriStreamOverride: linkStream.stream,
      );
      addTearDown(deepLinkCoordinator.dispose);

      await tester.pumpWidget(
        _wrapFounderTestApp(
          child: FounderCockpitScreen(
            repository: repo,
            deepLinkCoordinator: deepLinkCoordinator,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      // 1. Confirma remoção física de qualquer botão OAuth Google cross-app e campos 100% vazios!
      expect(find.textContaining('Autenticar Conta Google Soberana'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('founder-sovereign-auth-gate-scaffold')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('ceo-bootstrap-email-input')),
        findsOneWidget,
      );
      for (final ed in tester.widgetList<EditableText>(find.byType(EditableText))) {
        expect(ed.controller.text, isEmpty);
      }

      // 2. Primeiro acesso: digita e-mail soberano e solicita código de 6 dígitos
      await tester.enterText(
        find.byKey(const ValueKey<String>('ceo-bootstrap-email-input')),
        kMonocraticCeoEmail,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('ceo-bootstrap-send-otp-btn')));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const ValueKey<String>('ceo-otp-code-input')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey<String>('ceo-otp-code-input')),
        gw.lastIssuedOtpCode,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('ceo-bootstrap-verify-otp-btn')));
      await tester.pump(const Duration(milliseconds: 200));

      // 3. Testa teto físico de 64 caracteres (colar 96 caracteres trunca exatamente em 64!)
      expect(
        find.byKey(const ValueKey<String>('ceo-create-password-input')),
        findsOneWidget,
      );
      final ninetySixChars = 'K9#vM2\$pQ7!xR4&z' * 6; // 96 chars
      await tester.enterText(
        find.byKey(const ValueKey<String>('ceo-create-password-input')),
        ninetySixChars,
      );
      await tester.pump();
      expect(find.text('64 / 64'), findsOneWidget);

      // 4. Cria Senha Mestra Forte V1 e entra na Sala de Guerra
      await tester.enterText(
        find.byKey(const ValueKey<String>('ceo-create-password-input')),
        strongMasterPasswordV1,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('ceo-confirm-password-input')),
        strongMasterPasswordV1,
      );
      await tester.pump();

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('ceo-save-initial-password-btn')),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final btn = tester.widget<FilledButton>(
          find.byKey(const ValueKey<String>('ceo-save-initial-password-btn')),
        );
        btn.onPressed!();
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.byKey(const ValueKey<String>('founder-cockpit-unlocked-scaffold')),
        findsOneWidget,
      );

      // 5. Abre Perfil Soberano pelo botão no topo (ceo-header-profile-btn) e dispara E-mail #1 + E-mail #2
      await tester.tap(find.byKey(const ValueKey<String>('ceo-header-profile-btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('ceo-profile-change-password-btn')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('ceo-profile-change-password-btn')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const ValueKey<String>('ceo-profile-otp-input')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('ceo-profile-otp-input')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey<String>('ceo-profile-otp-input')),
        gw.lastIssuedOtpCode,
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('ceo-profile-otp-verify-btn')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('ceo-profile-otp-verify-btn')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const ValueKey<String>('ceo-profile-link-dispatched-card')),
        findsOneWidget,
      );

      // 6. Toca no link do E-mail #2 -> Deep-link abre imediatamente a tela segura de Nova Senha Mestra!
      final resetUri = gw.lastDispatchedResetDeepLinkUri!;
      final accepted = deepLinkCoordinator.handleUriForTesting(resetUri);
      expect(accepted, isTrue);
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.byKey(const ValueKey<String>('ceo-reset-new-password-input')),
        findsOneWidget,
      );

      // Grava Senha Mestra Forte V2 -> encerra todas as sessões e leva à tela limpa de Login!
      await tester.enterText(
        find.byKey(const ValueKey<String>('ceo-reset-new-password-input')),
        strongMasterPasswordV2,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('ceo-reset-confirm-password-input')),
        strongMasterPasswordV2,
      );
      await tester.pump();

      await tester.runAsync(() async {
        final commitBtn = tester.widget<FilledButton>(
          find.byKey(const ValueKey<String>('ceo-reset-commit-password-btn')),
        );
        commitBtn.onPressed!();
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey<String>('ceo-login-email-input')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('ceo-login-password-input')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('DesperrengueFounderApp animated splash transitions cleanly into Sovereign Auth Gate', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fastBoot = AppInitializationService(
        warmUp: () async {},
        initBackend: () async {},
        readTheme: () async => AppThemeMode.dark,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: DesperrengueFounderApp(
            bootService: fastBoot,
            splashDuration: const Duration(milliseconds: 300),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('founder-animated-splash-screen')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const ValueKey<String>('founder-boot-ready')),
        findsOneWidget,
      );
    });

    testWidgets('Unlocked 5-Tab War Room, Privacy Blur, Forensic Sheet & Multi-Viewport 0-Overflow', (tester) async {
      final gw = FakeCeoBackendGateway(
        pbkdf2Iterations: 1200,
        initialSnapshot: _buildSampleRealSnapshot(),
      );
      final repo = FounderCockpitRepository(
        gateway: gw,
        pbkdf2Iterations: 1200,
      );
      addTearDown(repo.dispose);

      await tester.runAsync(() async {
        await gw.preSealAndUnlockForTest(repo: repo);
      });

      final noopLinks = FounderDeepLinkCoordinator(
        getInitialLinkOverride: () async => null,
        uriStreamOverride: const Stream<Uri>.empty(),
      );
      addTearDown(noopLinks.dispose);

      // 1. Tortura 320x640 @ textScale 1.35x (Mobile estreito)
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapFounderTestApp(
          textScaler: const TextScaler.linear(1.35),
          child: FounderCockpitScreen(
            repository: repo,
            deepLinkCoordinator: noopLinks,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('founder-cockpit-unlocked-scaffold')),
        findsOneWidget,
      );

      for (var tab = 0; tab < 5; tab++) {
        await tester.tap(find.byKey(ValueKey<String>('ceo-nav-tab-$tab')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          tester.takeException(),
          isNull,
          reason: 'Zero overflow na aba $tab em 320x640 @ 1.35x',
        );
      }

      // 2. Desktop Panorâmico 1440x900 + Privacy Blur + Dossiê Forense
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(
        _wrapFounderTestApp(
          child: FounderCockpitScreen(
            repository: repo,
            deepLinkCoordinator: noopLinks,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey<String>('ceo-nav-tab-0')));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.textContaining('•••••'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 150));

      await tester.tap(find.byKey(const ValueKey<String>('ceo-nav-tab-2')));
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.byKey(const ValueKey<String>('ceo-live-geo-radar-card')),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Dossiê Forense').first);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Dossiê Forense').first);
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.byKey(const ValueKey<String>('ceo-order-forensic-sheet')),
        findsOneWidget,
      );
      expect(find.textContaining('Marina Real'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FounderUpdateGate delivers automatic floating in-app direct update with live progress & SHA-256 verification', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const shaHex =
          '99887766554433221100ffeeddccbbaa99887766554433221100ffeeddccbbaa';
      const releasePayload = '''
      {
        "body": "build: 202611200\\nversion: 2.14.0\\n## Novidades\\nAtualização direta sem navegador\\n---\\n- SHA-256 (`desperrengue-founder-ceo.apk`): `$shaHex`",
        "assets": [
          {
            "name": "desperrengue-founder-ceo.apk",
            "size": 52428800,
            "browser_download_url": "https://github.com/org/repo/releases/download/beta-latest/desperrengue-founder-ceo.apk"
          }
        ]
      }
      ''';

      final mockClient = MockClient(
        (_) async => http.Response(releasePayload, 200),
      );
      final updateSvc = FounderUpdateService(
        client: mockClient,
        buildNumber: () async => 202611140,
        repo: 'org/repo',
      );

      final finishDownload = Completer<void>();
      FounderUpdateInfo? installedInfo;
      final fakeInstaller = FounderNativeOtaInstaller(
        customRunner: (info, onProgress) async {
          installedInfo = info;
          onProgress(
            const FounderOtaProgress(
              phase: FounderOtaInstallPhase.downloading,
              receivedBytes: 26214400,
              totalBytes: 52428800,
              progress: 0.50,
            ),
          );
          await finishDownload.future;
          onProgress(
            const FounderOtaProgress(
              phase: FounderOtaInstallPhase.installerLaunched,
              receivedBytes: 52428800,
              totalBytes: 52428800,
              progress: 1.0,
              verifiedSha256: shaHex,
            ),
          );
        },
      );
      addTearDown(fakeInstaller.dispose);

      final gw = FakeCeoBackendGateway(pbkdf2Iterations: 1200);
      final repo = FounderCockpitRepository(
        gateway: gw,
        pbkdf2Iterations: 1200,
      );
      addTearDown(repo.dispose);

      final noopLinks = FounderDeepLinkCoordinator(
        getInitialLinkOverride: () async => null,
        uriStreamOverride: const Stream<Uri>.empty(),
      );
      addTearDown(noopLinks.dispose);

      await tester.pumpWidget(
        _wrapFounderTestApp(
          child: FounderUpdateGate(
            service: updateSvc,
            installer: fakeInstaller,
            initialDelay: const Duration(milliseconds: 100),
            interval: const Duration(minutes: 5),
            child: FounderCockpitScreen(
              repository: repo,
              deepLinkCoordinator: noopLinks,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const ValueKey<String>('founder-floating-ota-card')),
        findsOneWidget,
      );
      expect(find.textContaining('Versão 2.14.0'), findsOneWidget);
      expect(find.textContaining('50 MB'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('founder-ota-install-btn')),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('founder-ota-progress-bar')),
        findsOneWidget,
      );
      expect(find.textContaining('50%'), findsOneWidget);
      expect(installedInfo?.sha256, equals(shaHex));

      finishDownload.complete();
      await tester.pump();

      expect(
        find.textContaining('Toque em "Atualizar" no Android'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

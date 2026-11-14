import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:desperrengue_app/core/analytics/founder_accountant_pack_service.dart';
import 'package:desperrengue_app/core/analytics/founder_dashboard_models.dart';
import 'package:desperrengue_app/core/analytics/founder_dp_optimization_engine.dart';
import 'package:desperrengue_app/core/boot/app_initialization_service.dart';
import 'package:desperrengue_app/core/state/theme_controller.dart';
import 'package:desperrengue_app/features/founder/data/founder_cockpit_repository.dart';
import 'package:desperrengue_app/features/founder/presentation/founder_animations_and_shaders.dart';
import 'package:desperrengue_app/features/founder/presentation/founder_cockpit_screen.dart';
import 'package:desperrengue_app/features/founder/presentation/founder_update_gate.dart';
import 'package:desperrengue_app/main_founder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gateway em memória 100% determinístico que simula fielmente os contratos
/// criptográficos do PostgreSQL 17 (`20261114180000`) + Edge Function `ceo-sovereign-auth`
/// + WebSocket privado `ceo:war-room:live`.
class FakeCeoBackendGateway implements CeoBackendGateway {
  FakeCeoBackendGateway({
    this.authenticatedEmailInitial,
    FounderDashboardSnapshot? initialSnapshot,
  })  : _currentEmail = authenticatedEmailInitial,
        snapshotToReturn =
            initialSnapshot ?? FounderDashboardSnapshot.emptyZero();

  final String? authenticatedEmailInitial;
  String? _currentEmail;
  final String _currentUserId = '00000000-0000-4000-8000-00000000ce01';

  final StreamController<String?> _authChanges =
      StreamController<String?>.broadcast();

  FounderDashboardSnapshot snapshotToReturn;
  final List<String> recordedCanaryCodes = <String>[];
  final List<CeoLiveEventItem> missedEventsQueue = <CeoLiveEventItem>[];
  int signOutCallCount = 0;

  String? _storedServerPinHashHex;
  final Set<String> _trustedDeviceHashes = <String>{};
  String _lastIssuedOtpCode = '482917';
  String _lastChallengeId = '11111111-2222-4333-8444-555555555555';
  String? _validEnrollmentTicketHex;
  String? _activeStepUpTokenHex;
  int _failedPinAttempts = 0;
  DateTime? _lockedUntilUtc;

  void Function(CeoLiveEventItem event)? _liveEventCallback;
  void Function(CeoRealtimeConnectionStatus status)? _statusCallback;

  String get lastIssuedOtpCode => _lastIssuedOtpCode;

  void emitLiveRealtimeEvent(CeoLiveEventItem event) {
    _liveEventCallback?.call(event);
  }

  void emitRealtimeStatus(CeoRealtimeConnectionStatus status) {
    _statusCallback?.call(status);
  }

  String _serverHashProof(String clientProofHex) {
    return sha256
        .convert(utf8.encode('SERVER_PEPPER_V1:$clientProofHex'))
        .toString()
        .toLowerCase();
  }

  @override
  String? get currentUserEmail => _currentEmail;

  @override
  String? get currentUserId => _currentEmail == null ? null : _currentUserId;

  @override
  Stream<String?> get authEmailChanges => _authChanges.stream;

  @override
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    _currentEmail = email.trim().toLowerCase();
    _authChanges.add(_currentEmail);
  }

  @override
  Future<void> signInWithGoogleOAuth() async {
    _currentEmail = kMonocraticCeoEmail;
    _authChanges.add(_currentEmail);
  }

  @override
  Future<void> sendPrimaryEmailSignInOtp({required String email}) async {}

  @override
  Future<void> verifyPrimaryEmailSignInOtp({
    required String email,
    required String token,
  }) async {
    _currentEmail = email.trim().toLowerCase();
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
  Future<Map<String, dynamic>> invokeEdgeAuth(Map<String, dynamic> body) async {
    if (_currentEmail != kMonocraticCeoEmail) {
      recordedCanaryCodes.add('EDGE_NON_OWNER_BLOCKED');
      return <String, dynamic>{
        'ok': false,
        'error_code': 'ERR_MONOCRATIC_OWNER_ONLY_42501',
      };
    }

    final action = body['action']?.toString() ?? '';
    if (action == 'request_otp') {
      _lastIssuedOtpCode = '739204';
      _lastChallengeId = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
      return <String, dynamic>{
        'ok': true,
        'challenge_id': _lastChallengeId,
        'masked_destination': kMaskedMonocraticCeoEmail,
        'expires_at':
            DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
        'next_cooldown_seconds': 30,
      };
    }

    if (action == 'verify_otp') {
      final code = body['otp_code']?.toString() ?? '';
      final devHash = body['device_hash']?.toString() ?? '';
      if (code != _lastIssuedOtpCode) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_OTP_CODE_INCORRECT',
          'remaining_attempts': 4,
        };
      }
      _trustedDeviceHashes.add(devHash);
      _validEnrollmentTicketHex = List<String>.filled(64, 'e').join();
      return <String, dynamic>{
        'ok': true,
        'purpose': 'INITIAL_PIN_SETUP',
        'pin_configured': _storedServerPinHashHex != null,
        'enrollment_ticket': _validEnrollmentTicketHex,
        'ticket_expires_at':
            DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
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
        'pin_configured': _storedServerPinHashHex != null,
        'device_trusted': _trustedDeviceHashes.contains(devHash),
        'pin_algo_version': 'CLIENT_PBKDF2_120K_SERVER_HMAC10K_SHA256_V1',
        'failed_pin_attempts': _failedPinAttempts,
        'locked_until': _lockedUntilUtc?.toIso8601String(),
      };
    }

    if (functionName == 'ceo_register_personal_pin') {
      final ticket = params['p_enrollment_ticket']?.toString() ?? '';
      final proof = params['p_client_pin_proof']?.toString() ?? '';
      final devHash = params['p_device_hash']?.toString() ?? '';
      if (_validEnrollmentTicketHex == null ||
          ticket != _validEnrollmentTicketHex) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_ENROLLMENT_TICKET_INVALID_OR_EXPIRED',
        };
      }
      _validEnrollmentTicketHex = null; // single-use!
      _storedServerPinHashHex = _serverHashProof(proof);
      _trustedDeviceHashes.add(devHash);
      _failedPinAttempts = 0;
      _activeStepUpTokenHex = List<String>.filled(64, 'c').join();
      return <String, dynamic>{
        'ok': true,
        'stepup_token': _activeStepUpTokenHex,
        'expires_at':
            DateTime.now().toUtc().add(const Duration(minutes: 15)).toIso8601String(),
      };
    }

    if (functionName == 'ceo_unlock_sovereign_vault') {
      final proof = params['p_client_pin_proof']?.toString() ?? '';
      final devHash = params['p_device_hash']?.toString() ?? '';
      if (_lockedUntilUtc != null &&
          _lockedUntilUtc!.isAfter(DateTime.now().toUtc())) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_VAULT_LOCKED_BACKOFF',
          'failed_attempts': _failedPinAttempts,
          'locked_until': _lockedUntilUtc!.toIso8601String(),
        };
      }
      if (!_trustedDeviceHashes.contains(devHash)) {
        return <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_UNTRUSTED_DEVICE_OTP_REQUIRED',
        };
      }
      if (_storedServerPinHashHex == null ||
          _serverHashProof(proof) != _storedServerPinHashHex) {
        _failedPinAttempts++;
        if (_failedPinAttempts >= 5) {
          _lockedUntilUtc =
              DateTime.now().toUtc().add(const Duration(seconds: 60));
        }
        return <String, dynamic>{
          'ok': false,
          'error_code': _failedPinAttempts >= 5
              ? 'ERR_VAULT_LOCKED_BACKOFF'
              : 'ERR_INVALID_PERSONAL_PIN',
          'failed_attempts': _failedPinAttempts,
          'locked_until': _lockedUntilUtc?.toIso8601String(),
        };
      }
      _failedPinAttempts = 0;
      _activeStepUpTokenHex = List<String>.filled(64, 'd').join();
      return <String, dynamic>{
        'ok': true,
        'stepup_token': _activeStepUpTokenHex,
        'expires_at':
            DateTime.now().toUtc().add(const Duration(minutes: 15)).toIso8601String(),
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
        competenceDateIso: params['p_competence_date']?.toString() ?? '2026-11-14',
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
  final demo = const FounderDemographicsSummary(
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
  // ===========================================================================
  // PILAR 1: COFRE MONOCRÁTICO (`wagneroliveira2395@gmail.com`), OTP 6 DÍGITOS & PIN SHA-256
  // ===========================================================================
  group('Pillar 1 — Monocratic Single-Owner Vault & 3-Layer SHA-256 Auth', () {
    test('Blocks every non-owner email, logs INTRUSION_CANARY, and forces signOut', () async {
      final gw = FakeCeoBackendGateway();
      final repo = FounderCockpitRepository(
        gateway: gw,
        pbkdf2Iterations: 1500,
      );
      addTearDown(repo.dispose);

      for (final intruder in const <String>[
        'intruder@attacker.org',
        'wagner.ceo@desperrengue.com.br',
        'wagneroliveira2395@evil.com',
      ]) {
        await expectLater(
          () => repo.signInWithEmailPassword(
            email: intruder,
            password: 'any-password',
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

      expect(gw.recordedCanaryCodes.length, equals(3));
      expect(gw.signOutCallCount, greaterThanOrEqualTo(3));
      expect(repo.authenticatedEmail, isNull);
    });

    test('Validates PIN entropy, completes 6-digit email OTP -> personal PIN SHA-256 creation -> unlock & lockout backoff', () async {
      expect(CeoPinCryptoEngine.validatePinStrength('000000'), isNotNull);
      expect(CeoPinCryptoEngine.validatePinStrength('123456'), isNotNull);
      expect(CeoPinCryptoEngine.validatePinStrength('654321'), isNotNull);
      expect(CeoPinCryptoEngine.validatePinStrength('123123'), isNotNull);
      expect(CeoPinCryptoEngine.validatePinStrength('904817'), isNull);

      final proof1 = CeoPinCryptoEngine.deriveClientPinProofSync(
        '904817',
        iterations: 1500,
      );
      final proof2 = CeoPinCryptoEngine.deriveClientPinProofSync(
        '904817',
        iterations: 1500,
      );
      expect(proof1.length, equals(64));
      expect(proof1, equals(proof2));

      final gw = FakeCeoBackendGateway(
        initialSnapshot: _buildSampleRealSnapshot(),
      );
      final repo = FounderCockpitRepository(
        gateway: gw,
        pbkdf2Iterations: 1500,
      );
      addTearDown(repo.dispose);

      // Camada 1: Login do único dono
      await repo.signInWithEmailPassword(
        email: kMonocraticCeoEmail,
        password: 'sovereign-strong-pass',
      );
      final initialStatus = await repo.fetchVaultStatus();
      expect(initialStatus.pinConfigured, isFalse);
      expect(initialStatus.requiresEmailOtp, isTrue);

      // Camada 2: Solicita e verifica código de 6 dígitos enviado para wagneroliveira2395@gmail.com
      final otpTicket = await repo.requestEmailSecurityOtp(
        purpose: 'INITIAL_PIN_SETUP',
      );
      expect(otpTicket.maskedDestination, equals(kMaskedMonocraticCeoEmail));

      await expectLater(
        () => repo.verifyEmailSecurityOtp(
          challengeId: otpTicket.challengeId,
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

      final otpVerified = await repo.verifyEmailSecurityOtp(
        challengeId: otpTicket.challengeId,
        sixDigitCode: gw.lastIssuedOtpCode,
      );
      expect(otpVerified.enrollmentTicketHex.length, equals(64));

      // Camada 3: Wagner cria seu PIN pessoal (rejeita PIN fraco, aceita PIN forte)
      await expectLater(
        () => repo.registerPersonalPin(
          enrollmentTicketHex: otpVerified.enrollmentTicketHex,
          personalPin: '123456',
        ),
        throwsA(isA<CeoVaultSecurityException>()),
      );

      final session = await repo.registerPersonalPin(
        enrollmentTicketHex: otpVerified.enrollmentTicketHex,
        personalPin: '904817',
      );
      expect(session.accountEmail, equals(kMonocraticCeoEmail));
      expect(repo.activeStepUpSession, isNotNull);

      // Tranca o cofre e testa desbloqueio diário por PIN + bloqueio progressivo após 5 erros
      await repo.lockVault();
      expect(repo.activeStepUpSession, isNull);

      final unlockedAgain = await repo.unlockWithPersonalPin(
        personalPin: '904817',
      );
      expect(unlockedAgain.stepUpCredentialHex, isNotEmpty);

      await repo.lockVault();
      for (var i = 0; i < 5; i++) {
        await expectLater(
          () => repo.unlockWithPersonalPin(personalPin: '817294'),
          throwsA(isA<CeoVaultSecurityException>()),
        );
      }
      await expectLater(
        () => repo.unlockWithPersonalPin(personalPin: '904817'),
        throwsA(
          isA<CeoVaultSecurityException>().having(
            (e) => e.errorCode,
            'errorCode',
            equals('ERR_VAULT_LOCKED_BACKOFF'),
          ),
        ),
      );
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
        authenticatedEmailInitial: kMonocraticCeoEmail,
        initialSnapshot: _buildSampleRealSnapshot(),
      );
      final repo = FounderCockpitRepository(
        gateway: gw,
        pbkdf2Iterations: 1500,
      );
      addTearDown(repo.dispose);

      final ticket =
          await repo.requestEmailSecurityOtp(purpose: 'INITIAL_PIN_SETUP');
      final verified = await repo.verifyEmailSecurityOtp(
        challengeId: ticket.challengeId,
        sixDigitCode: gw.lastIssuedOtpCode,
      );
      await repo.registerPersonalPin(
        enrollmentTicketHex: verified.enrollmentTicketHex,
        personalPin: '904817',
      );
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

      // Simula queda de rede e reconexão recuperando evento #12 perdido
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
        walletsAndEscrowTotalCents: 126999, // 1 centavo de desvio!
      );
      expect(brokenRecon.threeWayReconciliationOk, isFalse);
      expect(brokenRecon.discrepancyCents.abs(), equals(1));

      const packSvc = FounderAccountantPackService();
      final pack = packSvc.generateMonthlyPackSync(snap);
      expect(pack.pdfBytes.length, greaterThan(500));
      expect(utf8.decode(pack.pdfBytes.take(8).toList()), startsWith('%PDF-1.4'));
      expect(pack.verifyIntegrity(), isTrue);

      // Motores DP continuam 100% operacionais sobre dados reais
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
        "body": "build: 202611150\\nversion: 2.13.1\\n## Novidades\\nfeat(ceo): atualizacao automatica direta no celular\\n\\n---\\n- SHA-256 (`desperrengue.apk`): `ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff`\\n- SHA-256 (`desperrengue-founder-ceo.apk`): `$expectedCeoSha`",
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
      expect(info.version, equals('2.13.1'));
      expect(info.sizeBytes, equals(57671680));
      expect(info.sizeLabel, equals('55 MB'));
      expect(info.sha256, equals(expectedCeoSha));
      expect(
        info.headlineNotes,
        contains('atualizacao automatica direta no celular'),
      );

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
  // PILAR 4: ZERO PRÉ-PREENCHIMENTO, SPLASH 120 FPS & TORTURA MULTI-VIEWPORT
  // ===========================================================================
  group('Pillar 4 — Blank Vault Gate, Animated Boot & 5-Tab UI Torture', () {
    testWidgets('Vault Gate starts with 100% blank inputs (zero pre-filled PIN or email)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final gw = FakeCeoBackendGateway();
      final repo = FounderCockpitRepository(
        gateway: gw,
        pbkdf2Iterations: 1200,
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        _wrapFounderTestApp(
          child: FounderCockpitScreen(repository: repo),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const ValueKey<String>('founder-stepup-vault-gate')),
        findsOneWidget,
      );

      final editables = tester.widgetList<EditableText>(find.byType(EditableText));
      for (final ed in editables) {
        expect(
          ed.controller.text,
          isEmpty,
          reason: 'Nenhum campo de credencial ou PIN pode iniciar pré-preenchido',
        );
      }
    });

    testWidgets('DesperrengueFounderApp animated splash transitions cleanly into Vault Gate', (tester) async {
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
        authenticatedEmailInitial: kMonocraticCeoEmail,
        initialSnapshot: _buildSampleRealSnapshot(),
      );
      final repo = FounderCockpitRepository(
        gateway: gw,
        pbkdf2Iterations: 1200,
      );
      addTearDown(repo.dispose);

      await tester.runAsync(() async {
        final otp =
            await repo.requestEmailSecurityOtp(purpose: 'INITIAL_PIN_SETUP');
        final ver = await repo.verifyEmailSecurityOtp(
          challengeId: otp.challengeId,
          sixDigitCode: gw.lastIssuedOtpCode,
        );
        await repo.registerPersonalPin(
          enrollmentTicketHex: ver.enrollmentTicketHex,
          personalPin: '904817',
        );
      });

      // 1. Tortura 320x640 @ textScale 1.35x (Mobile estreito)
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapFounderTestApp(
          textScaler: const TextScaler.linear(1.35),
          child: FounderCockpitScreen(repository: repo),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('founder-cockpit-unlocked-scaffold')),
        findsOneWidget,
      );

      // Navega pelas 5 abas sem qualquer overflow
      for (var tab = 0; tab < 5; tab++) {
        await tester.tap(find.byKey(ValueKey<String>('ceo-nav-tab-$tab')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: 'Zero overflow na aba $tab em 320x640');
      }

      // 2. Desktop Panorâmico 1440x900 + Privacy Blur + Dossiê Forense
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(
        _wrapFounderTestApp(
          child: FounderCockpitScreen(repository: repo),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);

      // Volta para Aba 0 (Ao Vivo) e testa atalho de Privacidade (tecla Espaço)
      await tester.tap(find.byKey(const ValueKey<String>('ceo-nav-tab-0')));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.textContaining('•••••'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 150));

      // Abre Aba 2 (Operações) e inspeciona Dossiê Forense Real
      await tester.tap(find.byKey(const ValueKey<String>('ceo-nav-tab-2')));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byKey(const ValueKey<String>('ceo-live-geo-radar-card')), findsOneWidget);

      await tester.ensureVisible(find.text('Dossiê Forense').first);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Dossiê Forense').first);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byKey(const ValueKey<String>('ceo-order-forensic-sheet')), findsOneWidget);
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
        "body": "build: 202611200\\nversion: 2.13.1\\n## Novidades\\nAtualização direta sem navegador\\n---\\n- SHA-256 (`desperrengue-founder-ceo.apk`): `$shaHex`",
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

      final gw = FakeCeoBackendGateway();
      final repo = FounderCockpitRepository(
        gateway: gw,
        pbkdf2Iterations: 1200,
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        _wrapFounderTestApp(
          child: FounderUpdateGate(
            service: updateSvc,
            installer: fakeInstaller,
            initialDelay: const Duration(milliseconds: 100),
            interval: const Duration(minutes: 5),
            child: FounderCockpitScreen(repository: repo),
          ),
        ),
      );

      // Após o delay inicial de 100ms, o cartão flutuante aparece automaticamente sobre a tela do Cofre!
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const ValueKey<String>('founder-floating-ota-card')),
        findsOneWidget,
      );
      expect(find.textContaining('Versão 2.13.1'), findsOneWidget);
      expect(find.textContaining('50 MB'), findsOneWidget);

      // Toca em "Atualizar" -> faz streaming direto dentro do app com barra de progresso (sem abrir navegador!)
      await tester.tap(find.byKey(const ValueKey<String>('founder-ota-install-btn')));
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

/// Modelos canônicos imutáveis do aplicativo exclusivo `Desperrengue CEO`
/// (`br.com.desperrengue.app.founder` — Cofre Monocrático & Sala de Guerra em Tempo Real).
///
/// Regras arquiteturais inegociáveis (`Zero-Fake Policy`):
/// - 100% aritmética inteira em centavos ([int] + [Money]): zero `double` para moeda.
/// - Zero dados falsos, sintéticos ou demonstrativos (`deterministicDemo` erradicado):
///   qualquer métrica ausente ou zerada no banco é representada fielmente como `0` / `const []`.
/// - Exclusividade Monocrática: único titular autorizado `wagneroliveira2395@gmail.com`
///   (zero vagas de delegados).
/// - Zero `dart:io` e zero dependências de widgets Flutter (100% seguro para envio
///   entre worker threads via `runOffMainThread` e compatível com Web/Wasm/VM).
library;

import 'dart:math' as math;

import '../models/marketplace_models.dart' show kCategories;
import '../utils/money.dart';

/// E-mail canônico e imutável do único titular soberano do `Desperrengue CEO`.
const String kMonocraticCeoEmail = 'wagneroliveira2395@gmail.com';

/// Máscara executiva para exibição em telas intermediárias de verificação OTP.
const String kMaskedMonocraticCeoEmail = 'wa***95@gmail.com';

int _asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return fallback;
    final parsedInt = int.tryParse(trimmed);
    if (parsedInt != null) return parsedInt;
    final parsedDouble = double.tryParse(trimmed);
    if (parsedDouble != null && parsedDouble.isFinite) {
      return parsedDouble.round();
    }
  }
  return fallback;
}

double _asDouble(dynamic value, [double fallback = 0.0]) {
  if (value is double) return value.isFinite ? value : fallback;
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null && parsed.isFinite) return parsed;
  }
  return fallback;
}

bool _asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.trim().toLowerCase();
    if (lower == 'true' || lower == 't' || lower == '1') return true;
    if (lower == 'false' || lower == 'f' || lower == '0') return false;
  }
  return fallback;
}

String _asString(dynamic value, [String fallback = '']) {
  if (value is String) return value;
  if (value == null) return fallback;
  return value.toString();
}

String? _asNullableString(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

List<String> _asStringList(dynamic value) {
  if (value is! List) return const <String>[];
  return List<String>.unmodifiable(
    value
        .map((e) => e?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty),
  );
}

DateTime _asDateTimeUtc(dynamic value, [DateTime? fallback]) {
  if (value is DateTime) return value.toUtc();
  if (value is String && value.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed != null) return parsed.toUtc();
  }
  return (fallback ?? DateTime.now().toUtc()).toUtc();
}

DateTime? _asNullableDateTimeUtc(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim())?.toUtc();
  }
  return null;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return <Map<String, dynamic>>[
    for (final item in value)
      if (item is Map) _asMap(item),
  ];
}

String _slugifyCategory(String name) {
  const diacritics = <String, String>{
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'é': 'e',
    'ê': 'e',
    'í': 'i',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  final lower = name.toLowerCase();
  final sb = StringBuffer();
  for (var i = 0; i < lower.length; i++) {
    final ch = lower[i];
    if (diacritics.containsKey(ch)) {
      sb.write(diacritics[ch]);
    } else if ((ch.codeUnitAt(0) >= 97 && ch.codeUnitAt(0) <= 122) ||
        (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57)) {
      sb.write(ch);
    } else {
      sb.write('_');
    }
  }
  return sb
      .toString()
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

/// As 33 categorias canônicas oficiais do Desperrengue (espelho exato de [kCategories]).
List<String> get kCanonicalServiceCategoryNames =>
    List<String>.unmodifiable(kCategories.map((c) => c.name));

// ============================================================================
// 1. METADADOS CRIPTOGRÁFICOS DO COFRE MONOCRÁTICO CEO (`SHA-256`)
// ============================================================================

/// Estado retornado por `public.ceo_vault_status(p_device_hash)`.
class CeoVaultStatus {
  const CeoVaultStatus({
    required this.ok,
    this.errorCode,
    required this.ownerEmail,
    required this.pinConfigured,
    required this.deviceTrusted,
    required this.pinAlgoVersion,
    this.pinConfiguredAt,
    this.pinRotatedAt,
    required this.failedPinAttempts,
    this.lockedUntil,
  });

  final bool ok;
  final String? errorCode;
  final String ownerEmail;
  final bool pinConfigured;
  final bool deviceTrusted;
  final String pinAlgoVersion;
  final DateTime? pinConfiguredAt;
  final DateTime? pinRotatedAt;
  final int failedPinAttempts;
  final DateTime? lockedUntil;

  bool isLockedAt(DateTime nowUtc) =>
      lockedUntil != null && lockedUntil!.isAfter(nowUtc.toUtc());

  bool get requiresEmailOtp => !pinConfigured || !deviceTrusted;

  String get requiredOtpPurpose =>
      !pinConfigured ? 'INITIAL_PIN_SETUP' : 'NEW_DEVICE_BIND';

  factory CeoVaultStatus.fromJson(Map<String, dynamic> json) {
    return CeoVaultStatus(
      ok: _asBool(json['ok']),
      errorCode: _asNullableString(json['error_code']),
      ownerEmail: _asString(json['owner_email'], kMonocraticCeoEmail),
      pinConfigured: _asBool(json['pin_configured']),
      deviceTrusted: _asBool(json['device_trusted']),
      pinAlgoVersion: _asString(
        json['pin_algo_version'],
        'CLIENT_PBKDF2_120K_SERVER_HMAC10K_SHA256_V1',
      ),
      pinConfiguredAt: _asNullableDateTimeUtc(json['pin_configured_at']),
      pinRotatedAt: _asNullableDateTimeUtc(json['pin_rotated_at']),
      failedPinAttempts: _asInt(json['failed_pin_attempts']),
      lockedUntil: _asNullableDateTimeUtc(json['locked_until']),
    );
  }
}

/// Metadados do Cofre Soberano embutidos no snapshot ao vivo (`vault_metadata`).
class CeoVaultMetadata {
  const CeoVaultMetadata({
    required this.ownerEmail,
    required this.pinAlgoVersion,
    this.pinConfiguredAt,
    this.pinRotatedAt,
    this.failedPinAttempts = 0,
  });

  final String ownerEmail;
  final String pinAlgoVersion;
  final DateTime? pinConfiguredAt;
  final DateTime? pinRotatedAt;
  final int failedPinAttempts;

  factory CeoVaultMetadata.empty() => const CeoVaultMetadata(
        ownerEmail: kMonocraticCeoEmail,
        pinAlgoVersion: 'CLIENT_PBKDF2_120K_SERVER_HMAC10K_SHA256_V1',
      );

  factory CeoVaultMetadata.fromJson(Map<String, dynamic> json) {
    return CeoVaultMetadata(
      ownerEmail: _asString(json['owner_email'], kMonocraticCeoEmail),
      pinAlgoVersion: _asString(
        json['pin_algo_version'],
        'CLIENT_PBKDF2_120K_SERVER_HMAC10K_SHA256_V1',
      ),
      pinConfiguredAt: _asNullableDateTimeUtc(json['pin_configured_at']),
      pinRotatedAt: _asNullableDateTimeUtc(json['pin_rotated_at']),
      failedPinAttempts: _asInt(json['failed_pin_attempts']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'owner_email': ownerEmail,
        'pin_algo_version': pinAlgoVersion,
        'pin_configured_at': pinConfiguredAt?.toUtc().toIso8601String(),
        'pin_rotated_at': pinRotatedAt?.toUtc().toIso8601String(),
        'failed_pin_attempts': failedPinAttempts,
      };
}

// ============================================================================
// 2. DEMOGRAFIA REAL DE 5 ESTADOS & PULSO OPERACIONAL AO VIVO
// ============================================================================

/// Partição demográfica 100% real de `public.profiles` + offboarding LGPD.
class FounderDemographicsSummary {
  const FounderDemographicsSummary({
    required this.onlyClientsCount,
    required this.onlyProvidersCount,
    required this.dualModeBothCount,
    this.onboardingIncompleteCount = 0,
    required this.totalUsersCount,
    this.newUsersInWindowCount = 0,
    required this.kycVerifiedCount,
    required this.kycPendingCount,
    required this.kycRejectedCount,
    this.kycNotSubmittedCount = 0,
    this.biometricVerifiedCount = 0,
    this.ocrVerifiedCount = 0,
    required this.lgpdDeletedClientCount,
    required this.lgpdDeletedProviderCount,
    required this.lgpdDeletedAllCount,
  });

  final int onlyClientsCount;
  final int onlyProvidersCount;
  final int dualModeBothCount;
  final int onboardingIncompleteCount;
  final int totalUsersCount;
  final int newUsersInWindowCount;
  final int kycVerifiedCount;
  final int kycPendingCount;
  final int kycRejectedCount;
  final int kycNotSubmittedCount;
  final int biometricVerifiedCount;
  final int ocrVerifiedCount;
  final int lgpdDeletedClientCount;
  final int lgpdDeletedProviderCount;
  final int lgpdDeletedAllCount;

  /// Verifica a partição exata de `public.profiles` nos 4 subconjuntos disjuntos + total.
  bool get partitionInvariantOk =>
      onlyClientsCount +
          onlyProvidersCount +
          dualModeBothCount +
          onboardingIncompleteCount ==
      totalUsersCount;

  int get totalActiveClients => onlyClientsCount + dualModeBothCount;

  int get totalActiveProviders => onlyProvidersCount + dualModeBothCount;

  /// Participação da Interseção Dourada Dual-Mode em basis points (`100 bp = 1%`).
  int get dualModeShareBps => totalUsersCount <= 0
      ? 0
      : ((dualModeBothCount * 10000) + (totalUsersCount ~/ 2)) ~/
          totalUsersCount;

  int get totalLgpdOffboardings =>
      lgpdDeletedClientCount + lgpdDeletedProviderCount + lgpdDeletedAllCount;

  factory FounderDemographicsSummary.emptyZero() =>
      const FounderDemographicsSummary(
        onlyClientsCount: 0,
        onlyProvidersCount: 0,
        dualModeBothCount: 0,
        onboardingIncompleteCount: 0,
        totalUsersCount: 0,
        newUsersInWindowCount: 0,
        kycVerifiedCount: 0,
        kycPendingCount: 0,
        kycRejectedCount: 0,
        kycNotSubmittedCount: 0,
        biometricVerifiedCount: 0,
        ocrVerifiedCount: 0,
        lgpdDeletedClientCount: 0,
        lgpdDeletedProviderCount: 0,
        lgpdDeletedAllCount: 0,
      );

  factory FounderDemographicsSummary.fromJson(Map<String, dynamic> json) {
    final onlyClients = _asInt(json['only_clients_count']);
    final onlyProviders = _asInt(json['only_providers_count']);
    final dualBoth = _asInt(json['dual_mode_both_count']);
    final onboarding = _asInt(json['onboarding_incomplete_count']);
    final fallbackTotal = onlyClients + onlyProviders + dualBoth + onboarding;
    final total = _asInt(json['total_users_count'], fallbackTotal);
    final kycOk = _asInt(json['kyc_verified_count']);
    final kycPend = _asInt(json['kyc_pending_count']);
    final kycRej = _asInt(json['kyc_rejected_count']);
    final kycNotSub = _asInt(
      json['kyc_not_submitted_count'],
      math.max(0, total - kycOk - kycPend - kycRej),
    );

    return FounderDemographicsSummary(
      onlyClientsCount: onlyClients,
      onlyProvidersCount: onlyProviders,
      dualModeBothCount: dualBoth,
      onboardingIncompleteCount: onboarding,
      totalUsersCount: total,
      newUsersInWindowCount: _asInt(json['new_users_in_window_count']),
      kycVerifiedCount: kycOk,
      kycPendingCount: kycPend,
      kycRejectedCount: kycRej,
      kycNotSubmittedCount: kycNotSub,
      biometricVerifiedCount: _asInt(json['biometric_verified_count']),
      ocrVerifiedCount: _asInt(json['ocr_verified_count']),
      lgpdDeletedClientCount: _asInt(json['lgpd_deleted_client_count']),
      lgpdDeletedProviderCount: _asInt(json['lgpd_deleted_provider_count']),
      lgpdDeletedAllCount: _asInt(json['lgpd_deleted_all_count']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'only_clients_count': onlyClientsCount,
        'only_providers_count': onlyProvidersCount,
        'dual_mode_both_count': dualModeBothCount,
        'onboarding_incomplete_count': onboardingIncompleteCount,
        'total_users_count': totalUsersCount,
        'new_users_in_window_count': newUsersInWindowCount,
        'kyc_verified_count': kycVerifiedCount,
        'kyc_pending_count': kycPendingCount,
        'kyc_rejected_count': kycRejectedCount,
        'kyc_not_submitted_count': kycNotSubmittedCount,
        'biometric_verified_count': biometricVerifiedCount,
        'ocr_verified_count': ocrVerifiedCount,
        'lgpd_deleted_client_count': lgpdDeletedClientCount,
        'lgpd_deleted_provider_count': lgpdDeletedProviderCount,
        'lgpd_deleted_all_count': lgpdDeletedAllCount,
      };
}

/// Contadores operacionais em tempo real do marketplace (`live_operations_pulse`).
class CeoLiveOperationsPulse {
  const CeoLiveOperationsPulse({
    required this.openJobsCount,
    required this.awaitingPaymentCount,
    required this.scheduledJobsCount,
    required this.inProgressJobsCount,
    required this.awaitingApprovalCount,
    required this.completedAllTimeCount,
    required this.canceledInWindowCount,
    required this.disputedJobsCount,
    required this.quotesInWindowCount,
    required this.quotesPendingCount,
    required this.quotesAcceptedInWindowCount,
    required this.invitesPendingCount,
    required this.pixPendingCount,
    required this.reviewsTotalCount,
    required this.reviewsAvgBps,
  });

  final int openJobsCount;
  final int awaitingPaymentCount;
  final int scheduledJobsCount;
  final int inProgressJobsCount;
  final int awaitingApprovalCount;
  final int completedAllTimeCount;
  final int canceledInWindowCount;
  final int disputedJobsCount;
  final int quotesInWindowCount;
  final int quotesPendingCount;
  final int quotesAcceptedInWindowCount;
  final int invitesPendingCount;
  final int pixPendingCount;
  final int reviewsTotalCount;

  /// Média de avaliações em milésimos (`5000 == 5.00★`).
  final int reviewsAvgBps;

  double get reviewsAvgStars => reviewsAvgBps / 1000.0;

  int get awaitingQuoteOrPaymentCount => openJobsCount + awaitingPaymentCount;

  int get inExecutionPipelineCount =>
      scheduledJobsCount + inProgressJobsCount + awaitingApprovalCount;

  int get activeOrdersTotalCount =>
      openJobsCount +
      awaitingPaymentCount +
      scheduledJobsCount +
      inProgressJobsCount +
      awaitingApprovalCount +
      disputedJobsCount;

  factory CeoLiveOperationsPulse.emptyZero() => const CeoLiveOperationsPulse(
        openJobsCount: 0,
        awaitingPaymentCount: 0,
        scheduledJobsCount: 0,
        inProgressJobsCount: 0,
        awaitingApprovalCount: 0,
        completedAllTimeCount: 0,
        canceledInWindowCount: 0,
        disputedJobsCount: 0,
        quotesInWindowCount: 0,
        quotesPendingCount: 0,
        quotesAcceptedInWindowCount: 0,
        invitesPendingCount: 0,
        pixPendingCount: 0,
        reviewsTotalCount: 0,
        reviewsAvgBps: 0,
      );

  factory CeoLiveOperationsPulse.fromJson(Map<String, dynamic> json) {
    return CeoLiveOperationsPulse(
      openJobsCount: _asInt(json['open_jobs_count']),
      awaitingPaymentCount: _asInt(json['awaiting_payment_count']),
      scheduledJobsCount: _asInt(json['scheduled_jobs_count']),
      inProgressJobsCount: _asInt(json['in_progress_jobs_count']),
      awaitingApprovalCount: _asInt(json['awaiting_approval_count']),
      completedAllTimeCount: _asInt(json['completed_all_time_count']),
      canceledInWindowCount: _asInt(json['canceled_in_window_count']),
      disputedJobsCount: _asInt(json['disputed_jobs_count']),
      quotesInWindowCount: _asInt(json['quotes_in_window_count']),
      quotesPendingCount: _asInt(json['quotes_pending_count']),
      quotesAcceptedInWindowCount:
          _asInt(json['quotes_accepted_in_window_count']),
      invitesPendingCount: _asInt(json['invites_pending_count']),
      pixPendingCount: _asInt(json['pix_pending_count']),
      reviewsTotalCount: _asInt(json['reviews_total_count']),
      reviewsAvgBps: _asInt(json['reviews_avg_bps']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'open_jobs_count': openJobsCount,
        'awaiting_payment_count': awaitingPaymentCount,
        'scheduled_jobs_count': scheduledJobsCount,
        'in_progress_jobs_count': inProgressJobsCount,
        'awaiting_approval_count': awaitingApprovalCount,
        'completed_all_time_count': completedAllTimeCount,
        'canceled_in_window_count': canceledInWindowCount,
        'disputed_jobs_count': disputedJobsCount,
        'quotes_in_window_count': quotesInWindowCount,
        'quotes_pending_count': quotesPendingCount,
        'quotes_accepted_in_window_count': quotesAcceptedInWindowCount,
        'invites_pending_count': invitesPendingCount,
        'pix_pending_count': pixPendingCount,
        'reviews_total_count': reviewsTotalCount,
        'reviews_avg_bps': reviewsAvgBps,
      };
}

// ============================================================================
// 3. DRE CPC 47 / IFRS 15, RECONCILIAÇÃO TRIPLA, TESOURARIA E POOL ATUARIAL
// ============================================================================

/// Demonstração do Resultado do Exercício (DRE) em centavos inteiros (BIGINT)
/// segundo segregação Principal vs. Agente (CPC 47 / IFRS 15 / Simples Anexo III).
class FounderDreCents {
  const FounderDreCents({
    required this.gmvTotalCents,
    required this.laborGrossCents,
    required this.materialsExemptCents,
    required this.providerNetLaborCents,
    required this.platformGrossRevenueCents,
    required this.sosFeeRevenueCents,
    required this.warrantyPoolCarveoutCents,
    required this.simplesNacionalTaxCents,
    required this.grossGmvHypotheticalTaxCents,
    required this.taxSavingsBps,
    required this.variablePspAndCloudCents,
    required this.tier0KycSavingsCents,
    required this.contributionMarginCents,
    required this.fixedOpexCents,
    required this.completedOrdersCount,
    required this.stageGate40Reached,
    required this.stageGate100Reached,
    required this.netProfitEbitdaCents,
  });

  final int gmvTotalCents;
  final int laborGrossCents;
  final int materialsExemptCents;
  final int providerNetLaborCents;
  final int platformGrossRevenueCents;
  final int sosFeeRevenueCents;
  final int warrantyPoolCarveoutCents;
  final int simplesNacionalTaxCents;
  final int grossGmvHypotheticalTaxCents;
  final int taxSavingsBps;
  final int variablePspAndCloudCents;
  final int tier0KycSavingsCents;
  final int contributionMarginCents;
  final int fixedOpexCents;
  final int completedOrdersCount;
  final bool stageGate40Reached;
  final bool stageGate100Reached;
  final int netProfitEbitdaCents;

  int get baseLaborFee135Cents => platformGrossRevenueCents - sosFeeRevenueCents;

  int get thirdPartyPassThroughCents =>
      providerNetLaborCents + materialsExemptCents;

  int get legalTaxSavingsCents => math.max(
        0,
        grossGmvHypotheticalTaxCents - simplesNacionalTaxCents,
      );

  double get taxSavingsPct => taxSavingsBps / 100.0;

  double get effectiveTakeRatePct => gmvTotalCents <= 0
      ? 0.0
      : (platformGrossRevenueCents * 100.0) / gmvTotalCents;

  bool get gmvSplitInvariantOk =>
      gmvTotalCents == laborGrossCents + materialsExemptCents;

  bool get laborAllocationInvariantOk =>
      laborGrossCents ==
      providerNetLaborCents + baseLaborFee135Cents + warrantyPoolCarveoutCents;

  bool get contributionMarginInvariantOk =>
      contributionMarginCents ==
      platformGrossRevenueCents -
          simplesNacionalTaxCents -
          variablePspAndCloudCents;

  bool get ebitdaInvariantOk =>
      netProfitEbitdaCents == contributionMarginCents - fixedOpexCents;

  bool get allAccountingInvariantsOk =>
      gmvSplitInvariantOk &&
      laborAllocationInvariantOk &&
      contributionMarginInvariantOk &&
      ebitdaInvariantOk;

  factory FounderDreCents.emptyZero() => const FounderDreCents(
        gmvTotalCents: 0,
        laborGrossCents: 0,
        materialsExemptCents: 0,
        providerNetLaborCents: 0,
        platformGrossRevenueCents: 0,
        sosFeeRevenueCents: 0,
        warrantyPoolCarveoutCents: 0,
        simplesNacionalTaxCents: 0,
        grossGmvHypotheticalTaxCents: 0,
        taxSavingsBps: 0,
        variablePspAndCloudCents: 0,
        tier0KycSavingsCents: 0,
        contributionMarginCents: 0,
        fixedOpexCents: 0,
        completedOrdersCount: 0,
        stageGate40Reached: false,
        stageGate100Reached: false,
        netProfitEbitdaCents: 0,
      );

  /// Construtor contábil exato em centavos a partir dos componentes primários.
  factory FounderDreCents.computeFromComponents({
    required int laborGrossCents,
    required int materialsExemptCents,
    required int sosFeeRevenueCents,
    required int completedOrdersCount,
    required int fixedOpexCents,
    int variablePspAndCloudCents = 0,
    int tier0KycSavingsCents = 0,
  }) {
    final gmvTotal = laborGrossCents + materialsExemptCents;
    final laborSplit =
        Money.allocate(laborGrossCents, const <int>[8500, 1350, 150]);
    final providerNetLabor = laborSplit[0];
    final platformBase135 = laborSplit[1];
    final poolCarveout15 = laborSplit[2];

    final platformGrossRev = platformBase135 + sosFeeRevenueCents;
    final simplesDas6 = Money.percentOfCents(platformGrossRev, 600);
    final hypotheticalGrossTax = ((gmvTotal * 1133) + 5000) ~/ 10000;
    final savingsCents = hypotheticalGrossTax > simplesDas6
        ? hypotheticalGrossTax - simplesDas6
        : 0;
    final savingsBps = hypotheticalGrossTax <= 0
        ? 0
        : ((savingsCents * 10000) + (hypotheticalGrossTax ~/ 2)) ~/
            hypotheticalGrossTax;

    final contribution =
        platformGrossRev - simplesDas6 - variablePspAndCloudCents;
    final netEbitda = contribution - fixedOpexCents;

    return FounderDreCents(
      gmvTotalCents: gmvTotal,
      laborGrossCents: laborGrossCents,
      materialsExemptCents: materialsExemptCents,
      providerNetLaborCents: providerNetLabor,
      platformGrossRevenueCents: platformGrossRev,
      sosFeeRevenueCents: sosFeeRevenueCents,
      warrantyPoolCarveoutCents: poolCarveout15,
      simplesNacionalTaxCents: simplesDas6,
      grossGmvHypotheticalTaxCents: hypotheticalGrossTax,
      taxSavingsBps: savingsBps,
      variablePspAndCloudCents: variablePspAndCloudCents,
      tier0KycSavingsCents: tier0KycSavingsCents,
      contributionMarginCents: contribution,
      fixedOpexCents: fixedOpexCents,
      completedOrdersCount: completedOrdersCount,
      stageGate40Reached: completedOrdersCount >= 40,
      stageGate100Reached: completedOrdersCount >= 100,
      netProfitEbitdaCents: netEbitda,
    );
  }

  factory FounderDreCents.fromJson(Map<String, dynamic> json) {
    return FounderDreCents(
      gmvTotalCents: _asInt(json['gmv_total_cents']),
      laborGrossCents: _asInt(json['labor_gross_cents']),
      materialsExemptCents: _asInt(json['materials_exempt_cents']),
      providerNetLaborCents: _asInt(json['provider_net_labor_cents']),
      platformGrossRevenueCents: _asInt(json['platform_gross_revenue_cents']),
      sosFeeRevenueCents: _asInt(json['sos_fee_revenue_cents']),
      warrantyPoolCarveoutCents: _asInt(json['warranty_pool_carveout_cents']),
      simplesNacionalTaxCents: _asInt(json['simples_nacional_tax_cents']),
      grossGmvHypotheticalTaxCents:
          _asInt(json['gross_gmv_hypothetical_tax_cents']),
      taxSavingsBps: _asInt(json['tax_savings_bps']),
      variablePspAndCloudCents: _asInt(json['variable_psp_and_cloud_cents']),
      tier0KycSavingsCents: _asInt(json['tier0_kyc_savings_cents']),
      contributionMarginCents: _asInt(json['contribution_margin_cents']),
      fixedOpexCents: _asInt(json['fixed_opex_cents']),
      completedOrdersCount: _asInt(json['completed_orders_count']),
      stageGate40Reached: _asBool(json['stage_gate_40_reached']),
      stageGate100Reached: _asBool(json['stage_gate_100_reached']),
      netProfitEbitdaCents: _asInt(json['net_profit_ebitda_cents']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'gmv_total_cents': gmvTotalCents,
        'labor_gross_cents': laborGrossCents,
        'materials_exempt_cents': materialsExemptCents,
        'provider_net_labor_cents': providerNetLaborCents,
        'platform_gross_revenue_cents': platformGrossRevenueCents,
        'sos_fee_revenue_cents': sosFeeRevenueCents,
        'warranty_pool_carveout_cents': warrantyPoolCarveoutCents,
        'simples_nacional_tax_cents': simplesNacionalTaxCents,
        'gross_gmv_hypothetical_tax_cents': grossGmvHypotheticalTaxCents,
        'tax_savings_bps': taxSavingsBps,
        'variable_psp_and_cloud_cents': variablePspAndCloudCents,
        'tier0_kyc_savings_cents': tier0KycSavingsCents,
        'contribution_margin_cents': contributionMarginCents,
        'fixed_opex_cents': fixedOpexCents,
        'completed_orders_count': completedOrdersCount,
        'stage_gate_40_reached': stageGate40Reached,
        'stage_gate_100_reached': stageGate100Reached,
        'net_profit_ebitda_cents': netProfitEbitdaCents,
      };
}

/// Conciliação Tripla de Custódia (`PIX Topups` <-> `Razão Contábil` <-> `Carteiras + Escrow`).
/// Qualquer divergência de 1 único centavo aciona `threeWayReconciliationOk == false`.
class FounderThreeWayReconciliation {
  const FounderThreeWayReconciliation({
    required this.pixTopupsConfirmedCents,
    required this.ledgerNetSumCents,
    required this.walletsAndEscrowTotalCents,
    required this.discrepancyCents,
    required this.threeWayReconciliationOk,
    this.cumulativePlatformSettledOutCents = 0,
    this.clientSeedHomologationCents = 0,
  });

  final int pixTopupsConfirmedCents;
  final int ledgerNetSumCents;
  final int walletsAndEscrowTotalCents;
  final int cumulativePlatformSettledOutCents;
  final int clientSeedHomologationCents;
  final int discrepancyCents;
  final bool threeWayReconciliationOk;

  factory FounderThreeWayReconciliation.emptyZero() =>
      const FounderThreeWayReconciliation(
        pixTopupsConfirmedCents: 0,
        ledgerNetSumCents: 0,
        walletsAndEscrowTotalCents: 0,
        discrepancyCents: 0,
        threeWayReconciliationOk: true,
      );

  factory FounderThreeWayReconciliation.compute({
    required int pixTopupsConfirmedCents,
    required int ledgerNetSumCents,
    required int walletsAndEscrowTotalCents,
    int cumulativePlatformSettledOutCents = 0,
    int clientSeedHomologationCents = 0,
  }) {
    final expectedNetCustody = pixTopupsConfirmedCents +
        clientSeedHomologationCents -
        cumulativePlatformSettledOutCents;
    final dExpectedVsLedger = expectedNetCustody - ledgerNetSumCents;
    final dExpectedVsWallets = expectedNetCustody - walletsAndEscrowTotalCents;
    final dLedgerVsWallets = ledgerNetSumCents - walletsAndEscrowTotalCents;

    var maxSignedDiscrepancy = dExpectedVsWallets;
    if (dExpectedVsLedger.abs() > maxSignedDiscrepancy.abs()) {
      maxSignedDiscrepancy = dExpectedVsLedger;
    }
    if (dLedgerVsWallets.abs() > maxSignedDiscrepancy.abs()) {
      maxSignedDiscrepancy = dLedgerVsWallets;
    }
    final isExact = dExpectedVsLedger == 0 &&
        dExpectedVsWallets == 0 &&
        dLedgerVsWallets == 0;

    return FounderThreeWayReconciliation(
      pixTopupsConfirmedCents: pixTopupsConfirmedCents,
      ledgerNetSumCents: ledgerNetSumCents,
      walletsAndEscrowTotalCents: walletsAndEscrowTotalCents,
      cumulativePlatformSettledOutCents: cumulativePlatformSettledOutCents,
      clientSeedHomologationCents: clientSeedHomologationCents,
      discrepancyCents: maxSignedDiscrepancy,
      threeWayReconciliationOk: isExact,
    );
  }

  factory FounderThreeWayReconciliation.fromJson(Map<String, dynamic> json) {
    final pix = _asInt(json['pix_topups_confirmed_cents']);
    final ledger = _asInt(json['ledger_net_sum_cents']);
    final wallets = _asInt(json['wallets_and_escrow_total_cents']);
    final settledOut = _asInt(json['cumulative_platform_settled_out_cents']);
    final seedCred = _asInt(json['client_seed_homologation_cents']);
    if (json.containsKey('discrepancy_cents') &&
        json.containsKey('three_way_reconciliation_ok')) {
      return FounderThreeWayReconciliation(
        pixTopupsConfirmedCents: pix,
        ledgerNetSumCents: ledger,
        walletsAndEscrowTotalCents: wallets,
        cumulativePlatformSettledOutCents: settledOut,
        clientSeedHomologationCents: seedCred,
        discrepancyCents: _asInt(json['discrepancy_cents']),
        threeWayReconciliationOk: _asBool(json['three_way_reconciliation_ok']),
      );
    }
    return FounderThreeWayReconciliation.compute(
      pixTopupsConfirmedCents: pix,
      ledgerNetSumCents: ledger,
      walletsAndEscrowTotalCents: wallets,
      cumulativePlatformSettledOutCents: settledOut,
      clientSeedHomologationCents: seedCred,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'pix_topups_confirmed_cents': pixTopupsConfirmedCents,
        'ledger_net_sum_cents': ledgerNetSumCents,
        'wallets_and_escrow_total_cents': walletsAndEscrowTotalCents,
        'cumulative_platform_settled_out_cents':
            cumulativePlatformSettledOutCents,
        'client_seed_homologation_cents': clientSeedHomologationCents,
        'discrepancy_cents': discrepancyCents,
        'three_way_reconciliation_ok': threeWayReconciliationOk,
      };
}

/// Tesouraria, Liquidez em Carteiras e Histograma Real de Maturação Escrow (`D+0..D+7`).
class FounderTreasurySummary {
  const FounderTreasurySummary({
    required this.availableWalletsCents,
    required this.activeExecutionEscrowCents,
    required this.maturationD0D2Cents,
    required this.maturationD5Cents,
    required this.maturationD7Cents,
    this.availableForPixPayoutCents = 0,
    required this.frozenMediationCents,
    required this.frozenUnderDuressCents,
    required this.estimatedMonthlyCdiFloatCents,
  });

  final int availableWalletsCents;
  final int activeExecutionEscrowCents;
  final int maturationD0D2Cents;
  final int maturationD5Cents;
  final int maturationD7Cents;
  final int availableForPixPayoutCents;
  final int frozenMediationCents;
  final int frozenUnderDuressCents;
  final int estimatedMonthlyCdiFloatCents;

  int get totalMaturationCents =>
      maturationD0D2Cents + maturationD5Cents + maturationD7Cents;

  int get totalFrozenCents => frozenMediationCents + frozenUnderDuressCents;

  int get totalCustodyCents =>
      availableWalletsCents +
      activeExecutionEscrowCents +
      totalMaturationCents +
      availableForPixPayoutCents +
      totalFrozenCents;

  factory FounderTreasurySummary.emptyZero() => const FounderTreasurySummary(
        availableWalletsCents: 0,
        activeExecutionEscrowCents: 0,
        maturationD0D2Cents: 0,
        maturationD5Cents: 0,
        maturationD7Cents: 0,
        availableForPixPayoutCents: 0,
        frozenMediationCents: 0,
        frozenUnderDuressCents: 0,
        estimatedMonthlyCdiFloatCents: 0,
      );

  factory FounderTreasurySummary.fromJson(Map<String, dynamic> json) {
    return FounderTreasurySummary(
      availableWalletsCents: _asInt(json['available_wallets_cents']),
      activeExecutionEscrowCents: _asInt(json['active_execution_escrow_cents']),
      maturationD0D2Cents: _asInt(json['maturation_d0_d2_cents']),
      maturationD5Cents: _asInt(json['maturation_d5_cents']),
      maturationD7Cents: _asInt(json['maturation_d7_cents']),
      availableForPixPayoutCents:
          _asInt(json['available_for_pix_payout_cents']),
      frozenMediationCents: _asInt(json['frozen_mediation_cents']),
      frozenUnderDuressCents: _asInt(json['frozen_under_duress_cents']),
      estimatedMonthlyCdiFloatCents:
          _asInt(json['estimated_monthly_cdi_float_cents']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'available_wallets_cents': availableWalletsCents,
        'active_execution_escrow_cents': activeExecutionEscrowCents,
        'maturation_d0_d2_cents': maturationD0D2Cents,
        'maturation_d5_cents': maturationD5Cents,
        'maturation_d7_cents': maturationD7Cents,
        'available_for_pix_payout_cents': availableForPixPayoutCents,
        'frozen_mediation_cents': frozenMediationCents,
        'frozen_under_duress_cents': frozenUnderDuressCents,
        'estimated_monthly_cdi_float_cents': estimatedMonthlyCdiFloatCents,
      };
}

/// Solvência Atuarial do Fundo Garantidor (`warranty_pool_ledger` — meta `ICA >= 1,50x`).
class FounderActuarialPoolSummary {
  const FounderActuarialPoolSummary({
    required this.runningBalanceCents,
    required this.activeExposureCents,
    required this.icaRatioBps,
    required this.fcrLayer1Bps,
    required this.clawbackRecoveredCents,
    required this.claimsPaidCents,
  });

  final int runningBalanceCents;
  final int activeExposureCents;
  final int icaRatioBps;
  final int fcrLayer1Bps;
  final int clawbackRecoveredCents;
  final int claimsPaidCents;

  double get icaRatioMultiple => icaRatioBps / 10000.0;

  bool get isSolventAboveTarget =>
      activeExposureCents == 0 || icaRatioBps >= 15000;

  double get fcrLayer1Pct => fcrLayer1Bps / 100.0;

  factory FounderActuarialPoolSummary.emptyZero() =>
      const FounderActuarialPoolSummary(
        runningBalanceCents: 0,
        activeExposureCents: 0,
        icaRatioBps: 0,
        fcrLayer1Bps: 10000,
        clawbackRecoveredCents: 0,
        claimsPaidCents: 0,
      );

  factory FounderActuarialPoolSummary.fromJson(Map<String, dynamic> json) {
    return FounderActuarialPoolSummary(
      runningBalanceCents: _asInt(json['running_balance_cents']),
      activeExposureCents: _asInt(json['active_exposure_cents']),
      icaRatioBps: _asInt(json['ica_ratio_bps']),
      fcrLayer1Bps: _asInt(json['fcr_layer1_bps'], 10000),
      clawbackRecoveredCents: _asInt(json['clawback_recovered_cents']),
      claimsPaidCents: _asInt(json['claims_paid_cents']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'running_balance_cents': runningBalanceCents,
        'active_exposure_cents': activeExposureCents,
        'ica_ratio_bps': icaRatioBps,
        'fcr_layer1_bps': fcrLayer1Bps,
        'clawback_recovered_cents': clawbackRecoveredCents,
        'claims_paid_cents': claimsPaidCents,
      };
}

// ============================================================================
// 4. OPERAÇÕES REAIS: 33 CATEGORIAS, MAPA CARTOGRÁFICO AO VIVO & LIQUIDEZ LOCAL
// ============================================================================

/// Ponto da matriz real das 33 categorias canônicas (Demanda × Oferta × Ticket Real).
class CategoryLiquidityPoint {
  const CategoryLiquidityPoint({
    required this.categoryId,
    required this.categoryName,
    required this.demandCount,
    required this.activeProvidersCount,
    required this.avgTicketCents,
    required this.conversionBps,
  });

  final String categoryId;
  final String categoryName;
  final int demandCount;
  final int activeProvidersCount;
  final int avgTicketCents;
  final int conversionBps;

  double get conversionPct => conversionBps / 100.0;

  double get demandPerProvider => activeProvidersCount <= 0
      ? demandCount.toDouble()
      : demandCount / activeProvidersCount;

  bool get isSupplyBottleneck => demandCount >= 3 && activeProvidersCount == 0;

  int get estimatedGmvCents =>
      (demandCount * avgTicketCents * conversionBps) ~/ 10000;

  factory CategoryLiquidityPoint.fromJson(Map<String, dynamic> json) {
    final name = _asString(json['category_name'], 'Outros');
    return CategoryLiquidityPoint(
      categoryId: _asString(json['category_id'], _slugifyCategory(name)),
      categoryName: name,
      demandCount: _asInt(json['demand_count']),
      activeProvidersCount: _asInt(json['active_providers_count']),
      avgTicketCents: _asInt(json['avg_ticket_cents']),
      conversionBps: _asInt(json['conversion_bps']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'category_id': categoryId,
        'category_name': categoryName,
        'demand_count': demandCount,
        'active_providers_count': activeProvidersCount,
        'avg_ticket_cents': avgTicketCents,
        'conversion_bps': conversionBps,
      };
}

/// Linha real de liquidez por bairro/cidade (`neighborhood_liquidity`).
class CeoRealNeighborhoodRow {
  const CeoRealNeighborhoodRow({
    required this.neighborhoodName,
    required this.cityName,
    required this.demandCount,
    required this.activeSupplyCount,
    required this.avgTicketCents,
  });

  final String neighborhoodName;
  final String cityName;
  final int demandCount;
  final int activeSupplyCount;
  final int avgTicketCents;

  factory CeoRealNeighborhoodRow.fromJson(Map<String, dynamic> json) {
    return CeoRealNeighborhoodRow(
      neighborhoodName: _asString(json['neighborhood_name'], 'Região Geral'),
      cityName: _asString(json['city_name'], 'Não informada'),
      demandCount: _asInt(json['demand_count']),
      activeSupplyCount: _asInt(json['active_supply_count']),
      avgTicketCents: _asInt(json['avg_ticket_cents']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'neighborhood_name': neighborhoodName,
        'city_name': cityName,
        'demand_count': demandCount,
        'active_supply_count': activeSupplyCount,
        'avg_ticket_cents': avgTicketCents,
      };
}

/// Célula bivariada Oferta × Demanda derivada estritamente de pedidos reais.
class NeighborhoodLiquidityCell {
  const NeighborhoodLiquidityCell({
    required this.neighborhood,
    required this.demandScore,
    required this.supplyScore,
    required this.unmetOrdersCount,
    required this.activeProvidersCount,
    required this.suggestedBoosterCents,
    required this.expectedIncrementalNetCents,
  });

  final String neighborhood;
  final int demandScore;
  final int supplyScore;
  final int unmetOrdersCount;
  final int activeProvidersCount;
  final int suggestedBoosterCents;
  final int expectedIncrementalNetCents;

  double get demandNormalized => (demandScore / 100.0).clamp(0.0, 1.0);
  double get supplyNormalized => (supplyScore / 100.0).clamp(0.0, 1.0);

  bool get needsSupplyBooster => demandScore >= 65 && supplyScore <= 50;

  String get quadrantLabelPt {
    if (demandScore >= 65 && supplyScore <= 50) {
      return 'Escassez Crítica (Disparar Booster)';
    }
    if (demandScore >= 65 && supplyScore > 50) {
      return 'Alta Liquidez Equilibrada';
    }
    if (demandScore < 65 && supplyScore > 55) {
      return 'Reserva de Oferta Disponível';
    }
    return 'Expansão Orgânica Inicial';
  }

  factory NeighborhoodLiquidityCell.fromRealRow(
    CeoRealNeighborhoodRow row, {
    required int maxDemand,
    required int maxSupply,
  }) {
    final dScore = maxDemand <= 0
        ? 0
        : ((row.demandCount * 100) ~/ maxDemand).clamp(0, 100);
    final sScore = maxSupply <= 0
        ? 0
        : ((row.activeSupplyCount * 100) ~/ maxSupply).clamp(0, 100);
    final unmet = math.max(0, row.demandCount - row.activeSupplyCount);
    final label = row.cityName.isNotEmpty && row.cityName != 'Não informada'
        ? '${row.neighborhoodName} · ${row.cityName}'
        : row.neighborhoodName;
    final avgNetPerJob = (row.avgTicketCents * 1269) ~/ 10000;
    return NeighborhoodLiquidityCell(
      neighborhood: label,
      demandScore: dScore,
      supplyScore: sScore,
      unmetOrdersCount: unmet,
      activeProvidersCount: row.activeSupplyCount,
      suggestedBoosterCents: unmet * 1500,
      expectedIncrementalNetCents: unmet * avgNetPerJob,
    );
  }

  factory NeighborhoodLiquidityCell.fromJson(Map<String, dynamic> json) {
    return NeighborhoodLiquidityCell(
      neighborhood: _asString(
        json['neighborhood'] ?? json['neighborhood_name'],
        'Região Geral',
      ),
      demandScore: _asDouble(json['demand_score'], 0).round().clamp(0, 100),
      supplyScore: _asDouble(json['supply_score'], 0).round().clamp(0, 100),
      unmetOrdersCount: _asInt(json['unmet_orders_count']),
      activeProvidersCount: _asInt(
        json['active_providers_count'] ?? json['active_supply_count'],
      ),
      suggestedBoosterCents: _asInt(json['suggested_booster_cents']),
      expectedIncrementalNetCents:
          _asInt(json['expected_incremental_net_cents']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'neighborhood': neighborhood,
        'demand_score': demandScore,
        'supply_score': supplyScore,
        'unmet_orders_count': unmetOrdersCount,
        'active_providers_count': activeProvidersCount,
        'suggested_booster_cents': suggestedBoosterCents,
        'expected_incremental_net_cents': expectedIncrementalNetCents,
      };
}

/// Pino cartográfico real extraído de `public.job_geo` + `public.jobs` (`live_map_points`).
class CeoLiveMapPoint {
  const CeoLiveMapPoint({
    required this.jobId,
    required this.orderCode,
    required this.title,
    required this.categoryName,
    required this.status,
    required this.escrowStatus,
    required this.urgency,
    required this.lat,
    required this.lng,
    required this.isExactPin,
    required this.amountCents,
    required this.neighborhood,
    required this.city,
    required this.uf,
    required this.clientName,
    this.providerName,
    this.scheduledFor,
    this.startedAt,
    required this.createdAt,
  });

  final String jobId;
  final String orderCode;
  final String title;
  final String categoryName;
  final String status;
  final String escrowStatus;
  final String urgency;
  final double lat;
  final double lng;
  final bool isExactPin;
  final int amountCents;
  final String neighborhood;
  final String city;
  final String uf;
  final String clientName;
  final String? providerName;
  final DateTime? scheduledFor;
  final DateTime? startedAt;
  final DateTime createdAt;

  bool get isActiveJob =>
      status == 'open' ||
      status == 'awaiting_payment' ||
      status == 'scheduled' ||
      status == 'in_progress' ||
      status == 'awaiting_approval' ||
      status == 'disputed';

  factory CeoLiveMapPoint.fromJson(Map<String, dynamic> json) {
    return CeoLiveMapPoint(
      jobId: _asString(json['job_id']),
      orderCode: _asString(json['order_code'], '#DESP'),
      title: _asString(json['title'], 'Serviço'),
      categoryName: _asString(json['category_name'], 'Outros'),
      status: _asString(json['status'], 'open'),
      escrowStatus: _asString(json['escrow_status'], 'NONE'),
      urgency: _asString(json['urgency'], 'scheduled'),
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
      isExactPin: _asBool(json['is_exact_pin']),
      amountCents: _asInt(json['amount_cents']),
      neighborhood: _asString(json['neighborhood']).trim(),
      city: _asString(json['city'], 'Não informada').trim(),
      uf: _asString(json['uf']).trim(),
      clientName: _asString(json['client_name'], 'Cliente'),
      providerName: _asNullableString(json['provider_name']),
      scheduledFor: _asNullableDateTimeUtc(json['scheduled_for']),
      startedAt: _asNullableDateTimeUtc(json['started_at']),
      createdAt: _asDateTimeUtc(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'job_id': jobId,
        'order_code': orderCode,
        'title': title,
        'category_name': categoryName,
        'status': status,
        'escrow_status': escrowStatus,
        'urgency': urgency,
        'lat': lat,
        'lng': lng,
        'is_exact_pin': isExactPin,
        'amount_cents': amountCents,
        'neighborhood': neighborhood,
        'city': city,
        'uf': uf,
        'client_name': clientName,
        'provider_name': providerName,
        'scheduled_for': scheduledFor?.toUtc().toIso8601String(),
        'started_at': startedAt?.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}

// ============================================================================
// 5. SÉRIE DIÁRIA DENSA (`America/Sao_Paulo`) & ORDENS REAIS MICRO-P&L
// ============================================================================

/// Ponto diário da série temporal financeira (base para Prefix Sums $O(1)$ e Kadane/CUSUM).
class FounderDailyMetricPoint {
  const FounderDailyMetricPoint({
    required this.dayIso,
    required this.ordersCount,
    required this.gmvCents,
    required this.laborCents,
    required this.materialsExemptCents,
    required this.platformRevenueCents,
    required this.poolCarveoutCents,
    required this.taxDasCents,
    required this.variableCostCents,
    required this.netProfitCents,
    required this.warrantyClaimsCents,
  });

  final String dayIso;
  final int ordersCount;
  final int gmvCents;
  final int laborCents;
  final int materialsExemptCents;
  final int platformRevenueCents;
  final int poolCarveoutCents;
  final int taxDasCents;
  final int variableCostCents;
  final int netProfitCents;
  final int warrantyClaimsCents;

  factory FounderDailyMetricPoint.fromJson(Map<String, dynamic> json) {
    return FounderDailyMetricPoint(
      dayIso: _asString(json['day_iso']),
      ordersCount: _asInt(json['orders_count']),
      gmvCents: _asInt(json['gmv_cents']),
      laborCents: _asInt(json['labor_cents']),
      materialsExemptCents: _asInt(json['materials_exempt_cents']),
      platformRevenueCents: _asInt(json['platform_revenue_cents']),
      poolCarveoutCents: _asInt(json['pool_carveout_cents']),
      taxDasCents: _asInt(json['tax_das_cents']),
      variableCostCents: _asInt(json['variable_cost_cents']),
      netProfitCents: _asInt(json['net_profit_cents']),
      warrantyClaimsCents: _asInt(json['warranty_claims_cents']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'day_iso': dayIso,
        'orders_count': ordersCount,
        'gmv_cents': gmvCents,
        'labor_cents': laborCents,
        'materials_exempt_cents': materialsExemptCents,
        'platform_revenue_cents': platformRevenueCents,
        'pool_carveout_cents': poolCarveoutCents,
        'tax_das_cents': taxDasCents,
        'variable_cost_cents': variableCostCents,
        'net_profit_cents': netProfitCents,
        'warranty_claims_cents': warrantyClaimsCents,
      };
}

/// Registro real unitário de Ordem de Serviço + Micro-P&L (`#DESP-XXXXX`).
class OrderMicroPnlRecord {
  const OrderMicroPnlRecord({
    required this.orderCode,
    required this.jobId,
    this.title = 'Serviço',
    required this.categoryName,
    required this.neighborhood,
    required this.createdAt,
    this.scheduledFor,
    this.status = 'open',
    this.urgency = 'scheduled',
    this.clientName = 'Cliente',
    this.providerName,
    this.quotesCount = 0,
    required this.gmvCents,
    required this.laborCents,
    required this.materialsExemptCents,
    required this.nfeVerified,
    required this.providerNetCents,
    required this.platformFeeCents,
    required this.poolCarveoutCents,
    required this.taxDasCents,
    required this.pixCloudCostCents,
    required this.netMarginCents,
    required this.escrowStatus,
    this.nfeAccessKey,
    this.providerAvatarUrl,
    this.evidencePhotoUrl,
  });

  final String orderCode;
  final String jobId;
  final String title;
  final String categoryName;
  final String neighborhood;
  final DateTime createdAt;
  final DateTime? scheduledFor;
  final String status;
  final String urgency;
  final String clientName;
  final String? providerName;
  final int quotesCount;
  final int gmvCents;
  final int laborCents;
  final int materialsExemptCents;
  final String? nfeAccessKey;
  final bool nfeVerified;
  final int providerNetCents;
  final int platformFeeCents;
  final int poolCarveoutCents;
  final int taxDasCents;
  final int pixCloudCostCents;
  final int netMarginCents;
  final String escrowStatus;
  final String? providerAvatarUrl;
  final String? evidencePhotoUrl;

  int get providerTotalPayoutCents => providerNetCents + materialsExemptCents;

  bool get hasValid44DigitNfeKey =>
      nfeAccessKey != null && RegExp(r'^\d{44}$').hasMatch(nfeAccessKey!);

  bool get splitConservationOk =>
      gmvCents == laborCents + materialsExemptCents &&
      laborCents == providerNetCents + platformFeeCents + poolCarveoutCents &&
      netMarginCents == platformFeeCents - taxDasCents - pixCloudCostCents;

  factory OrderMicroPnlRecord.fromJson(Map<String, dynamic> json) {
    return OrderMicroPnlRecord(
      orderCode: _asString(json['order_code'], '#DESP'),
      jobId: _asString(json['job_id']),
      title: _asString(json['title'], 'Serviço'),
      categoryName: _asString(json['category_name'], 'Outros'),
      neighborhood: _asString(json['neighborhood'], 'Não informado'),
      createdAt: _asDateTimeUtc(json['created_at']),
      scheduledFor: _asNullableDateTimeUtc(json['scheduled_for']),
      status: _asString(json['status'], 'open'),
      urgency: _asString(json['urgency'], 'scheduled'),
      clientName: _asString(json['client_name'], 'Cliente'),
      providerName: _asNullableString(json['provider_name']),
      quotesCount: _asInt(json['quotes_count']),
      gmvCents: _asInt(json['gmv_cents']),
      laborCents: _asInt(json['labor_cents']),
      materialsExemptCents: _asInt(json['materials_exempt_cents']),
      nfeAccessKey: _asNullableString(json['nfe_access_key']),
      nfeVerified: _asBool(json['nfe_verified']),
      providerNetCents: _asInt(json['provider_net_cents']),
      platformFeeCents: _asInt(json['platform_fee_cents']),
      poolCarveoutCents: _asInt(json['pool_carveout_cents']),
      taxDasCents: _asInt(json['tax_das_cents']),
      pixCloudCostCents: _asInt(json['pix_cloud_cost_cents']),
      netMarginCents: _asInt(json['net_margin_cents']),
      escrowStatus: _asString(json['escrow_status'], 'NONE'),
      providerAvatarUrl: _asNullableString(json['provider_avatar_url']),
      evidencePhotoUrl: _asNullableString(json['evidence_photo_url']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'order_code': orderCode,
        'job_id': jobId,
        'title': title,
        'category_name': categoryName,
        'neighborhood': neighborhood,
        'created_at': createdAt.toUtc().toIso8601String(),
        'scheduled_for': scheduledFor?.toUtc().toIso8601String(),
        'status': status,
        'urgency': urgency,
        'client_name': clientName,
        'provider_name': providerName,
        'quotes_count': quotesCount,
        'gmv_cents': gmvCents,
        'labor_cents': laborCents,
        'materials_exempt_cents': materialsExemptCents,
        'nfe_access_key': nfeAccessKey,
        'nfe_verified': nfeVerified,
        'provider_net_cents': providerNetCents,
        'platform_fee_cents': platformFeeCents,
        'pool_carveout_cents': poolCarveoutCents,
        'tax_das_cents': taxDasCents,
        'pix_cloud_cost_cents': pixCloudCostCents,
        'net_margin_cents': netMarginCents,
        'escrow_status': escrowStatus,
        'provider_avatar_url': providerAvatarUrl,
        'evidence_photo_url': evidencePhotoUrl,
      };
}

// ============================================================================
// 6. SEGURANÇA, SEFAZ, SILENT DURESS, DISPOSITIVOS, AUDITORIA WORM & DESPESAS
// ============================================================================

/// Incidente real sob custódia forense `FROZEN_UNDER_DURESS` (vazio se não houver incidente real).
class DuressIncidentRecord {
  const DuressIncidentRecord({
    required this.incidentId,
    required this.orderCode,
    required this.jobId,
    required this.triggeredAt,
    required this.frozenAmountCents,
    required this.custodyStatus,
    required this.maskedVictimRole,
    required this.maskedAccountRef,
    required this.coarseNeighborhood,
    required this.deviceIntegrityHash,
    required this.ledgerFreezeTxId,
    required this.evidenceChainHashes,
    this.decoyUiDisplayed = true,
  });

  final String incidentId;
  final String orderCode;
  final String jobId;
  final DateTime triggeredAt;
  final int frozenAmountCents;
  final String custodyStatus;
  final String maskedVictimRole;
  final String maskedAccountRef;
  final String coarseNeighborhood;
  final String deviceIntegrityHash;
  final String ledgerFreezeTxId;
  final List<String> evidenceChainHashes;
  final bool decoyUiDisplayed;

  factory DuressIncidentRecord.fromJson(Map<String, dynamic> json) {
    final hashesRaw = json['evidence_chain_hashes'];
    final hashes = hashesRaw is List
        ? hashesRaw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    return DuressIncidentRecord(
      incidentId: _asString(json['incident_id'] ?? json['id']),
      orderCode: _asString(json['order_code'] ?? json['code']),
      jobId: _asString(json['job_id']),
      triggeredAt: _asDateTimeUtc(
        json['triggered_at'] ?? json['created_at'] ?? json['frozen_at'],
      ),
      frozenAmountCents: _asInt(
        json['frozen_amount_cents'] ?? json['amount_cents'],
      ),
      custodyStatus: _asString(
        json['custody_status'] ?? json['status'],
        'FROZEN_UNDER_DURESS',
      ),
      maskedVictimRole: _asString(
        json['masked_victim_role'] ?? json['victim_role'],
        'PRESTADOR_CREDENCIADO',
      ),
      maskedAccountRef: _asString(
        json['masked_account_ref'] ?? json['user_ref'],
      ),
      coarseNeighborhood: _asString(
        json['coarse_neighborhood'] ?? json['neighborhood'],
      ),
      deviceIntegrityHash: _asString(
        json['device_integrity_hash'] ?? json['integrity_hash'],
      ),
      ledgerFreezeTxId: _asString(
        json['ledger_freeze_tx_id'] ?? json['tx_id'],
      ),
      evidenceChainHashes: List<String>.unmodifiable(hashes),
      decoyUiDisplayed: _asBool(json['decoy_ui_displayed'], true),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'incident_id': incidentId,
        'order_code': orderCode,
        'job_id': jobId,
        'triggered_at': triggeredAt.toUtc().toIso8601String(),
        'frozen_amount_cents': frozenAmountCents,
        'custody_status': custodyStatus,
        'masked_victim_role': maskedVictimRole,
        'masked_account_ref': maskedAccountRef,
        'coarse_neighborhood': coarseNeighborhood,
        'device_integrity_hash': deviceIntegrityHash,
        'ledger_freeze_tx_id': ledgerFreezeTxId,
        'evidence_chain_hashes': evidenceChainHashes,
        'decoy_ui_displayed': decoyUiDisplayed,
      };
}

/// Vigilância de Segurança Zero-Trust, SEFAZ, Geo-Privacidade (`0.00%`) e Cadeia WORM.
class FounderSecurityAndSefazWatch {
  const FounderSecurityAndSefazWatch({
    this.pendingSefazTotalCount = 0,
    required this.pendingSefazOver26hCount,
    this.verifiedSefazCount = 0,
    required this.canceledClawbackCount,
    required this.frozenUnderDuressCount,
    required this.geoPrivacyLeakBps,
    required this.intrusionCanariesCount,
    required this.auditChainIntact,
    required this.duressIncidents,
  });

  final int pendingSefazTotalCount;
  final int pendingSefazOver26hCount;
  final int verifiedSefazCount;
  final int canceledClawbackCount;
  final int frozenUnderDuressCount;
  final int geoPrivacyLeakBps;
  final int intrusionCanariesCount;
  final bool auditChainIntact;
  final List<DuressIncidentRecord> duressIncidents;

  bool get zeroGeoPrivacyLeaks => geoPrivacyLeakBps == 0;

  factory FounderSecurityAndSefazWatch.emptyZero() =>
      const FounderSecurityAndSefazWatch(
        pendingSefazTotalCount: 0,
        pendingSefazOver26hCount: 0,
        verifiedSefazCount: 0,
        canceledClawbackCount: 0,
        frozenUnderDuressCount: 0,
        geoPrivacyLeakBps: 0,
        intrusionCanariesCount: 0,
        auditChainIntact: true,
        duressIncidents: <DuressIncidentRecord>[],
      );

  factory FounderSecurityAndSefazWatch.fromJson(Map<String, dynamic> json) {
    final incidentsRaw = _asMapList(json['duress_incidents']);
    return FounderSecurityAndSefazWatch(
      pendingSefazTotalCount: _asInt(json['pending_sefaz_total_count']),
      pendingSefazOver26hCount: _asInt(json['pending_sefaz_over_26h_count']),
      verifiedSefazCount: _asInt(json['verified_sefaz_count']),
      canceledClawbackCount: _asInt(json['canceled_clawback_count']),
      frozenUnderDuressCount: _asInt(json['frozen_under_duress_count']),
      geoPrivacyLeakBps: _asInt(json['geo_privacy_leak_bps']),
      intrusionCanariesCount: _asInt(json['intrusion_canaries_count']),
      auditChainIntact: _asBool(json['audit_chain_intact'], true),
      duressIncidents: List<DuressIncidentRecord>.unmodifiable(
        incidentsRaw.map(DuressIncidentRecord.fromJson),
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'pending_sefaz_total_count': pendingSefazTotalCount,
        'pending_sefaz_over_26h_count': pendingSefazOver26hCount,
        'verified_sefaz_count': verifiedSefazCount,
        'canceled_clawback_count': canceledClawbackCount,
        'frozen_under_duress_count': frozenUnderDuressCount,
        'geo_privacy_leak_bps': geoPrivacyLeakBps,
        'intrusion_canaries_count': intrusionCanariesCount,
        'audit_chain_intact': auditChainIntact,
        'duress_incidents': duressIncidents.map((d) => d.toJson()).toList(),
      };
}

/// Dispositivo vinculado por código de 6 dígitos no e-mail do CEO (`trusted_devices`).
class CeoTrustedDeviceItem {
  const CeoTrustedDeviceItem({
    required this.deviceId,
    required this.deviceLabel,
    required this.fingerprintPrefix,
    required this.isCurrentDevice,
    required this.boundAt,
    required this.lastSeenAt,
  });

  final String deviceId;
  final String deviceLabel;
  final String fingerprintPrefix;
  final bool isCurrentDevice;
  final DateTime boundAt;
  final DateTime lastSeenAt;

  factory CeoTrustedDeviceItem.fromJson(Map<String, dynamic> json) {
    return CeoTrustedDeviceItem(
      deviceId: _asString(json['device_id']),
      deviceLabel: _asString(json['device_label'], 'Dispositivo Soberano CEO'),
      fingerprintPrefix: _asString(json['fingerprint_prefix']),
      isCurrentDevice: _asBool(json['is_current_device']),
      boundAt: _asDateTimeUtc(json['bound_at']),
      lastSeenAt: _asDateTimeUtc(json['last_seen_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'device_id': deviceId,
        'device_label': deviceLabel,
        'fingerprint_prefix': fingerprintPrefix,
        'is_current_device': isCurrentDevice,
        'bound_at': boundAt.toUtc().toIso8601String(),
        'last_seen_at': lastSeenAt.toUtc().toIso8601String(),
      };
}

/// Registro real na cadeia WORM `SHA-256` (`private.founder_audit_log`).
class CeoWormAuditItem {
  const CeoWormAuditItem({
    required this.id,
    required this.eventCode,
    required this.severity,
    required this.isIntrusionCanary,
    required this.prevHash,
    required this.rowHash,
    required this.createdAt,
  });

  final int id;
  final String eventCode;
  final String severity;
  final bool isIntrusionCanary;
  final String prevHash;
  final String rowHash;
  final DateTime createdAt;

  factory CeoWormAuditItem.fromJson(Map<String, dynamic> json) {
    return CeoWormAuditItem(
      id: _asInt(json['id']),
      eventCode: _asString(json['event_code']),
      severity: _asString(json['severity'], 'INFO'),
      isIntrusionCanary: _asBool(json['is_intrusion_canary']),
      prevHash: _asString(json['prev_hash']),
      rowHash: _asString(json['row_hash']),
      createdAt: _asDateTimeUtc(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'event_code': eventCode,
        'severity': severity,
        'is_intrusion_canary': isIntrusionCanary,
        'prev_hash': prevHash,
        'row_hash': rowHash,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}

/// Despesa operacional real registrada pelo CEO em `private.ceo_expense_entries`.
class CeoRealExpenseEntry {
  const CeoRealExpenseEntry({
    required this.id,
    required this.competenceDateIso,
    required this.expenseKind,
    required this.category,
    required this.description,
    required this.amountCents,
    required this.createdAt,
  });

  final String id;
  final String competenceDateIso;
  final String expenseKind;
  final String category;
  final String description;
  final int amountCents;
  final DateTime createdAt;

  String get kindLabelPt {
    switch (expenseKind) {
      case 'VARIABLE_PSP_CLOUD':
        return 'Variável (PSP / Cloud)';
      case 'TAX_EXTRA':
        return 'Tributo / Taxa Extra';
      default:
        return 'OPEX Fixo';
    }
  }

  factory CeoRealExpenseEntry.fromJson(Map<String, dynamic> json) {
    return CeoRealExpenseEntry(
      id: _asString(json['id']),
      competenceDateIso: _asString(json['competence_date']),
      expenseKind: _asString(json['expense_kind'], 'FIXED_OPEX'),
      category: _asString(json['category'], 'Infraestrutura'),
      description: _asString(json['description']),
      amountCents: _asInt(json['amount_cents']),
      createdAt: _asDateTimeUtc(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'competence_date': competenceDateIso,
        'expense_kind': expenseKind,
        'category': category,
        'description': description,
        'amount_cents': amountCents,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}

// ============================================================================
// 7. EVENTO EM TEMPO REAL (`private.ceo_live_events` + WSS `ceo:war-room:live`)
// ============================================================================

/// Evento monotônico da ponte criptografada em tempo real (`Desperrengue` -> `Desperrengue CEO`).
class CeoLiveEventItem {
  const CeoLiveEventItem({
    required this.eventSeq,
    required this.eventType,
    required this.severity,
    required this.title,
    required this.subtitle,
    required this.entityTable,
    required this.entityId,
    required this.amountCents,
    required this.metadata,
    required this.occurredAt,
  });

  final int eventSeq;
  final String eventType;
  final String severity;
  final String title;
  final String subtitle;
  final String entityTable;
  final String entityId;
  final int amountCents;
  final Map<String, dynamic> metadata;
  final DateTime occurredAt;

  String? get linkedJobId {
    if (entityTable == 'jobs' && entityId.isNotEmpty) return entityId;
    final fromMeta = metadata['job_id']?.toString().trim();
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
    return null;
  }

  factory CeoLiveEventItem.fromJson(Map<String, dynamic> json) {
    return CeoLiveEventItem(
      eventSeq: _asInt(json['event_seq']),
      eventType: _asString(json['event_type'], 'LIVE_EVENT'),
      severity: _asString(json['severity'], 'INFO'),
      title: _asString(json['title'], 'Movimentação em Tempo Real'),
      subtitle: _asString(json['subtitle']),
      entityTable: _asString(json['entity_table']),
      entityId: _asString(json['entity_id']),
      amountCents: _asInt(json['amount_cents']),
      metadata: Map<String, dynamic>.unmodifiable(_asMap(json['metadata'])),
      occurredAt: _asDateTimeUtc(json['occurred_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'event_seq': eventSeq,
        'event_type': eventType,
        'severity': severity,
        'title': title,
        'subtitle': subtitle,
        'entity_table': entityTable,
        'entity_id': entityId,
        'amount_cents': amountCents,
        'metadata': metadata,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
      };
}

// ============================================================================
// 8. FUNIL REAL DE CONVERSÃO, COORTES MENSAIS REAIS, AVALIAÇÕES & DIRETÓRIO CRM
// ============================================================================

/// Etapa real do funil de conversão (`real_conversion_funnel`).
class CeoConversionFunnelStage {
  const CeoConversionFunnelStage({
    required this.stageId,
    required this.label,
    required this.usersCount,
  });

  final String stageId;
  final String label;
  final int usersCount;

  factory CeoConversionFunnelStage.fromJson(Map<String, dynamic> json) {
    return CeoConversionFunnelStage(
      stageId: _asString(json['stage_id']),
      label: _asString(json['label']),
      usersCount: _asInt(json['users_count']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'stage_id': stageId,
        'label': label,
        'users_count': usersCount,
      };
}

/// Coorte mensal real de atividade (`real_monthly_cohorts`).
class CeoMonthlyCohortRow {
  const CeoMonthlyCohortRow({
    required this.cohortLabel,
    required this.cohortSize,
    required this.m0Bps,
    required this.m1Bps,
    required this.m2Bps,
    required this.m3Bps,
  });

  final String cohortLabel;
  final int cohortSize;
  final int m0Bps;
  final int m1Bps;
  final int m2Bps;
  final int m3Bps;

  List<int> get retentionBpsList =>
      List<int>.unmodifiable(<int>[m0Bps, m1Bps, m2Bps, m3Bps]);

  factory CeoMonthlyCohortRow.fromJson(Map<String, dynamic> json) {
    return CeoMonthlyCohortRow(
      cohortLabel: _asString(json['cohort_label']),
      cohortSize: _asInt(json['cohort_size']),
      m0Bps: _asInt(json['m0_bps']),
      m1Bps: _asInt(json['m1_bps']),
      m2Bps: _asInt(json['m2_bps']),
      m3Bps: _asInt(json['m3_bps']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cohort_label': cohortLabel,
        'cohort_size': cohortSize,
        'm0_bps': m0Bps,
        'm1_bps': m1Bps,
        'm2_bps': m2Bps,
        'm3_bps': m3Bps,
      };
}

/// Avaliação real revelada no marketplace (`recent_reviews`).
class CeoReviewItem {
  const CeoReviewItem({
    required this.reviewId,
    required this.jobId,
    required this.rating,
    required this.comment,
    required this.tags,
    this.reply,
    required this.reviewerName,
    required this.revieweeName,
    required this.categoryName,
    required this.createdAt,
  });

  final String reviewId;
  final String jobId;
  final int rating;
  final String comment;
  final List<String> tags;
  final String? reply;
  final String reviewerName;
  final String revieweeName;
  final String categoryName;
  final DateTime createdAt;

  factory CeoReviewItem.fromJson(Map<String, dynamic> json) {
    return CeoReviewItem(
      reviewId: _asString(json['review_id']),
      jobId: _asString(json['job_id']),
      rating: _asInt(json['rating'], 5).clamp(1, 5),
      comment: _asString(json['comment']),
      tags: _asStringList(json['tags']),
      reply: _asNullableString(json['reply']),
      reviewerName: _asString(json['reviewer_name'], 'Avaliador'),
      revieweeName: _asString(json['reviewee_name'], 'Avaliado'),
      categoryName: _asString(json['category_name'], 'Serviço'),
      createdAt: _asDateTimeUtc(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'review_id': reviewId,
        'job_id': jobId,
        'rating': rating,
        'comment': comment,
        'tags': tags,
        'reply': reply,
        'reviewer_name': reviewerName,
        'reviewee_name': revieweeName,
        'category_name': categoryName,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}

/// Linha do diretório pesquisável de usuários reais (`ceo_list_real_users_directory`).
class CeoRealUserDirectoryRow {
  const CeoRealUserDirectoryRow({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    required this.city,
    required this.isClient,
    required this.isProvider,
    this.verificationStatus,
    required this.clientKycStatus,
    required this.biometricVerified,
    required this.specialties,
    required this.ratingAvg,
    required this.ratingCount,
    required this.jobsDone,
    required this.clientJobsCount,
    required this.acceptingJobs,
    required this.clientWalletAvailableCents,
    required this.clientWalletEscrowCents,
    required this.providerWalletCents,
    required this.createdAt,
    this.updatedAt,
  });

  final String userId;
  final String fullName;
  final String? avatarUrl;
  final String city;
  final bool isClient;
  final bool isProvider;
  final String? verificationStatus;
  final String clientKycStatus;
  final bool biometricVerified;
  final List<String> specialties;
  final double ratingAvg;
  final int ratingCount;
  final int jobsDone;
  final int clientJobsCount;
  final bool acceptingJobs;
  final int clientWalletAvailableCents;
  final int clientWalletEscrowCents;
  final int providerWalletCents;
  final DateTime createdAt;
  final DateTime? updatedAt;

  String get roleLabelPt {
    if (isClient && isProvider) return 'Modo Híbrido (Cliente + Prestador)';
    if (isProvider) return 'Prestador';
    if (isClient) return 'Cliente';
    return 'Em Onboarding';
  }

  bool get isKycApproved =>
      verificationStatus == 'ACTIVE' ||
      clientKycStatus == 'APPROVED' ||
      biometricVerified;

  int get totalCustodyCents =>
      clientWalletAvailableCents +
      clientWalletEscrowCents +
      providerWalletCents;

  factory CeoRealUserDirectoryRow.fromJson(Map<String, dynamic> json) {
    return CeoRealUserDirectoryRow(
      userId: _asString(json['user_id']),
      fullName: _asString(json['full_name'], 'Usuário'),
      avatarUrl: _asNullableString(json['avatar_url']),
      city: _asString(json['city']),
      isClient: _asBool(json['is_client']),
      isProvider: _asBool(json['is_provider']),
      verificationStatus: _asNullableString(json['verification_status']),
      clientKycStatus: _asString(json['client_kyc_status'], 'NOT_SUBMITTED'),
      biometricVerified: _asBool(json['biometric_verified']),
      specialties: _asStringList(json['specialties']),
      ratingAvg: _asDouble(json['rating_avg']),
      ratingCount: _asInt(json['rating_count']),
      jobsDone: _asInt(json['jobs_done']),
      clientJobsCount: _asInt(json['client_jobs_count']),
      acceptingJobs: _asBool(json['accepting_jobs']),
      clientWalletAvailableCents: _asInt(json['client_wallet_available_cents']),
      clientWalletEscrowCents: _asInt(json['client_wallet_escrow_cents']),
      providerWalletCents: _asInt(json['provider_wallet_cents']),
      createdAt: _asDateTimeUtc(json['created_at']),
      updatedAt: _asNullableDateTimeUtc(json['updated_at']),
    );
  }
}

/// Dossiê Forense completo retornado por `public.ceo_inspect_order_forensics`.
class CeoOrderForensicsDossier {
  const CeoOrderForensicsDossier({
    required this.job,
    required this.client,
    this.provider,
    required this.location,
    required this.quotes,
    required this.invites,
    required this.payments,
    required this.ledgerTxns,
    required this.maturationEntries,
    required this.fiscalDocuments,
    required this.mediations,
    required this.reviews,
  });

  final Map<String, dynamic> job;
  final Map<String, dynamic> client;
  final Map<String, dynamic>? provider;
  final Map<String, dynamic> location;
  final List<Map<String, dynamic>> quotes;
  final List<Map<String, dynamic>> invites;
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> ledgerTxns;
  final List<Map<String, dynamic>> maturationEntries;
  final List<Map<String, dynamic>> fiscalDocuments;
  final List<Map<String, dynamic>> mediations;
  final List<Map<String, dynamic>> reviews;

  String get jobId => _asString(job['job_id']);
  String get orderCode => _asString(job['order_code'], '#DESP');
  String get title => _asString(job['title'], 'Serviço');
  String get description => _asString(job['description']);
  String get category => _asString(job['category'], 'Outros');
  String get status => _asString(job['status'], 'open');
  String get paymentStatus => _asString(job['payment_status'], 'pending');
  String get escrowStatus => _asString(job['escrow_status'], 'NONE');
  int get agreedPriceCents => _asInt(job['agreed_price_cents']);
  int get laborCents => _asInt(job['labor_cents']);
  int get materialsCents => _asInt(job['materials_cents']);

  factory CeoOrderForensicsDossier.fromJson(Map<String, dynamic> json) {
    final provRaw = json['provider'];
    return CeoOrderForensicsDossier(
      job: Map<String, dynamic>.unmodifiable(_asMap(json['job'])),
      client: Map<String, dynamic>.unmodifiable(_asMap(json['client'])),
      provider: provRaw is Map
          ? Map<String, dynamic>.unmodifiable(_asMap(provRaw))
          : null,
      location: Map<String, dynamic>.unmodifiable(_asMap(json['location'])),
      quotes: List<Map<String, dynamic>>.unmodifiable(
        _asMapList(json['quotes']),
      ),
      invites: List<Map<String, dynamic>>.unmodifiable(
        _asMapList(json['invites']),
      ),
      payments: List<Map<String, dynamic>>.unmodifiable(
        _asMapList(json['payments']),
      ),
      ledgerTxns: List<Map<String, dynamic>>.unmodifiable(
        _asMapList(json['ledger_txns']),
      ),
      maturationEntries: List<Map<String, dynamic>>.unmodifiable(
        _asMapList(json['maturation_entries']),
      ),
      fiscalDocuments: List<Map<String, dynamic>>.unmodifiable(
        _asMapList(json['fiscal_documents']),
      ),
      mediations: List<Map<String, dynamic>>.unmodifiable(
        _asMapList(json['mediations']),
      ),
      reviews: List<Map<String, dynamic>>.unmodifiable(
        _asMapList(json['reviews']),
      ),
    );
  }
}

// ============================================================================
// 9. ESTRUTURAS COMPATÍVEIS COM OS MOTORES DP / GRÁFICOS (100% ZERO-FAKE)
// ============================================================================

/// Etapa individual do Funil de Conversão.
class AarrrStageMetric {
  const AarrrStageMetric({
    required this.stageCode,
    required this.stageLabelPt,
    required this.usersCount,
    required this.stepConversionBps,
  });

  final String stageCode;
  final String stageLabelPt;
  final int usersCount;
  final int stepConversionBps;

  double get stepConversionPct => stepConversionBps / 100.0;
}

/// Resumo do Funil Real (derivado de contagens 100% reais, zero constantes sintéticas).
class FounderAarrrFunnelSummary {
  const FounderAarrrFunnelSummary({
    required this.acquisitionCount,
    required this.activationCount,
    required this.retentionCount,
    required this.revenueCount,
    required this.referralCount,
    this.cacCents = 0,
    this.ltvCents = 0,
    this.ltvToCacRatioBps = 0,
  });

  final int acquisitionCount;
  final int activationCount;
  final int retentionCount;
  final int revenueCount;
  final int referralCount;
  final int cacCents;
  final int ltvCents;
  final int ltvToCacRatioBps;

  double get ltvToCacMultiple => ltvToCacRatioBps / 10000.0;

  List<AarrrStageMetric> get stages {
    int bps(int numVal, int denVal) =>
        denVal <= 0 ? 0 : ((numVal * 10000) + (denVal ~/ 2)) ~/ denVal;
    return <AarrrStageMetric>[
      AarrrStageMetric(
        stageCode: 'ACQUISITION',
        stageLabelPt: 'Cadastros Reais',
        usersCount: acquisitionCount,
        stepConversionBps: acquisitionCount > 0 ? 10000 : 0,
      ),
      AarrrStageMetric(
        stageCode: 'ACTIVATION',
        stageLabelPt: 'KYC / Identidade Aprovada',
        usersCount: activationCount,
        stepConversionBps: bps(activationCount, acquisitionCount),
      ),
      AarrrStageMetric(
        stageCode: 'RETENTION',
        stageLabelPt: 'Pedido ou Orçamento Enviado',
        usersCount: retentionCount,
        stepConversionBps: bps(retentionCount, activationCount),
      ),
      AarrrStageMetric(
        stageCode: 'REVENUE',
        stageLabelPt: 'Custódia / Serviço Concluído',
        usersCount: revenueCount,
        stepConversionBps: bps(revenueCount, retentionCount),
      ),
      AarrrStageMetric(
        stageCode: 'REFERRAL',
        stageLabelPt: 'Recorrência (2+ Serviços) / Dual-Mode',
        usersCount: referralCount,
        stepConversionBps: bps(referralCount, revenueCount),
      ),
    ];
  }

  factory FounderAarrrFunnelSummary.emptyZero() =>
      const FounderAarrrFunnelSummary(
        acquisitionCount: 0,
        activationCount: 0,
        retentionCount: 0,
        revenueCount: 0,
        referralCount: 0,
      );

  factory FounderAarrrFunnelSummary.fromRealStages(
    List<CeoConversionFunnelStage> realStages,
    FounderDemographicsSummary demographics,
  ) {
    int stageVal(String id) {
      for (final s in realStages) {
        if (s.stageId == id) return s.usersCount;
      }
      return 0;
    }

    return FounderAarrrFunnelSummary(
      acquisitionCount: stageVal('signups'),
      activationCount: stageVal('kyc_ok'),
      retentionCount: stageVal('engaged'),
      revenueCount: math.max(stageVal('completed'), stageVal('escrow')),
      referralCount:
          math.max(stageVal('recurring'), demographics.dualModeBothCount),
    );
  }

  factory FounderAarrrFunnelSummary.fromJson(Map<String, dynamic> json) {
    return FounderAarrrFunnelSummary(
      acquisitionCount: _asInt(json['acquisition_count']),
      activationCount: _asInt(json['activation_count']),
      retentionCount: _asInt(json['retention_count']),
      revenueCount: _asInt(json['revenue_count']),
      referralCount: _asInt(json['referral_count']),
      cacCents: _asInt(json['cac_cents']),
      ltvCents: _asInt(json['ltv_cents']),
      ltvToCacRatioBps: _asInt(json['ltv_to_cac_ratio_bps']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'acquisition_count': acquisitionCount,
        'activation_count': activationCount,
        'retention_count': retentionCount,
        'revenue_count': revenueCount,
        'referral_count': referralCount,
        'cac_cents': cacCents,
        'ltv_cents': ltvCents,
        'ltv_to_cac_ratio_bps': ltvToCacRatioBps,
      };
}

/// Linha mensal da matriz de retenção por safra (Cohort Retention).
class CohortRetentionRow {
  const CohortRetentionRow({
    required this.cohortMonthIso,
    required this.initialUsers,
    required this.retentionByMonthBps,
    required this.netRevenuePerUserCents,
  });

  final String cohortMonthIso;
  final int initialUsers;
  final List<int> retentionByMonthBps;
  final int netRevenuePerUserCents;

  factory CohortRetentionRow.fromRealCohort(CeoMonthlyCohortRow real) {
    return CohortRetentionRow(
      cohortMonthIso: real.cohortLabel,
      initialUsers: real.cohortSize,
      retentionByMonthBps: real.retentionBpsList,
      netRevenuePerUserCents: 0,
    );
  }

  factory CohortRetentionRow.fromJson(Map<String, dynamic> json) {
    final rawList = json['retention_by_month_bps'];
    final parsed = rawList is List
        ? rawList.map(_asInt).toList(growable: false)
        : const <int>[];
    return CohortRetentionRow(
      cohortMonthIso: _asString(json['cohort_month_iso']),
      initialUsers: _asInt(json['initial_users']),
      retentionByMonthBps: List<int>.unmodifiable(parsed),
      netRevenuePerUserCents: _asInt(json['net_revenue_per_user_cents']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cohort_month_iso': cohortMonthIso,
        'initial_users': initialUsers,
        'retention_by_month_bps': retentionByMonthBps,
        'net_revenue_per_user_cents': netRevenuePerUserCents,
      };
}

/// Resumo FinOps KYC real (sem constantes sintéticas).
class FounderKycFinOpsSummary {
  const FounderKycFinOpsSummary({
    required this.tier0LocalCount,
    required this.argonCloudCount,
    required this.carbonSerproCount,
    required this.cloudSavingsCents,
    this.actualCloudSpendCents = 0,
    this.hypotheticalNaiveCloudSpendCents = 0,
  });

  final int tier0LocalCount;
  final int argonCloudCount;
  final int carbonSerproCount;
  final int cloudSavingsCents;
  final int actualCloudSpendCents;
  final int hypotheticalNaiveCloudSpendCents;

  int get totalEvaluations =>
      tier0LocalCount + argonCloudCount + carbonSerproCount;

  int get tier0DeflectionBps => totalEvaluations <= 0
      ? 0
      : ((tier0LocalCount * 10000) + (totalEvaluations ~/ 2)) ~/
          totalEvaluations;

  factory FounderKycFinOpsSummary.fromRealDemographics(
    FounderDemographicsSummary d,
  ) {
    return FounderKycFinOpsSummary(
      tier0LocalCount: d.ocrVerifiedCount,
      argonCloudCount: d.biometricVerifiedCount,
      carbonSerproCount: 0,
      cloudSavingsCents: 0,
    );
  }

  factory FounderKycFinOpsSummary.fromJson(Map<String, dynamic> json) {
    return FounderKycFinOpsSummary(
      tier0LocalCount: _asInt(json['tier0_local_count']),
      argonCloudCount: _asInt(json['argon_cloud_count']),
      carbonSerproCount: _asInt(json['carbon_serpro_count']),
      cloudSavingsCents: _asInt(json['cloud_savings_cents']),
      actualCloudSpendCents: _asInt(json['actual_cloud_spend_cents']),
      hypotheticalNaiveCloudSpendCents:
          _asInt(json['hypothetical_naive_cloud_spend_cents']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'tier0_local_count': tier0LocalCount,
        'argon_cloud_count': argonCloudCount,
        'carbon_serpro_count': carbonSerproCount,
        'cloud_savings_cents': cloudSavingsCents,
        'actual_cloud_spend_cents': actualCloudSpendCents,
        'hypothetical_naive_cloud_spend_cents':
            hypotheticalNaiveCloudSpendCents,
      };
}

/// Degrau da Cascata Tarifária Meritocrática de 5 Níveis.
class TieredWaterfallStep {
  const TieredWaterfallStep({
    required this.stepIndex,
    required this.tierName,
    required this.takeRateBps,
    required this.eligibleProvidersCount,
    required this.gmvShareBps,
    required this.descriptionPt,
  });

  final int stepIndex;
  final String tierName;
  final int takeRateBps;
  final int eligibleProvidersCount;
  final int gmvShareBps;
  final String descriptionPt;

  double get takeRatePct => takeRateBps / 100.0;

  factory TieredWaterfallStep.fromJson(Map<String, dynamic> json) {
    return TieredWaterfallStep(
      stepIndex: _asInt(json['step_index'], 1),
      tierName: _asString(json['tier_name'], 'Degrau 1 · Credenciado Base'),
      takeRateBps: _asInt(json['take_rate_bps'], 1500),
      eligibleProvidersCount: _asInt(json['eligible_providers_count']),
      gmvShareBps: _asInt(json['gmv_share_bps']),
      descriptionPt: _asString(json['description_pt']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'step_index': stepIndex,
        'tier_name': tierName,
        'take_rate_bps': takeRateBps,
        'eligible_providers_count': eligibleProvidersCount,
        'gmv_share_bps': gmvShareBps,
        'description_pt': descriptionPt,
      };
}

/// Cascata Tarifária de 5 Degraus + Catálogo Canônico de `112` Medalhas (`90` + `22`).
class FounderTieredWaterfallSummary {
  const FounderTieredWaterfallSummary({
    required this.steps,
    this.providerMedalsTotal = 90,
    this.clientMedalsTotal = 22,
    this.totalMedals = 112,
    this.unlockedProviderMedalsCount = 0,
    this.unlockedClientMedalsCount = 0,
  });

  final List<TieredWaterfallStep> steps;
  final int providerMedalsTotal;
  final int clientMedalsTotal;
  final int totalMedals;
  final int unlockedProviderMedalsCount;
  final int unlockedClientMedalsCount;

  bool get medalsCatalogInvariantOk =>
      providerMedalsTotal == 90 &&
      clientMedalsTotal == 22 &&
      totalMedals == 112 &&
      steps.length == 5;

  /// Constrói a tabela institucional de 5 degraus usando APENAS `totalProviders` real (`0` se `0`).
  static List<TieredWaterfallStep> canonicalFiveSteps({
    int totalProviders = 0,
  }) {
    final p = math.max(0, totalProviders);
    return <TieredWaterfallStep>[
      TieredWaterfallStep(
        stepIndex: 1,
        tierName: 'Degrau 1 · Credenciado Base',
        takeRateBps: 1500,
        eligibleProvidersCount: p,
        gmvShareBps: p > 0 ? 10000 : 0,
        descriptionPt: '13,5% Plataforma + 1,5% Pool Garantia (0% s/ Peças)',
      ),
      const TieredWaterfallStep(
        stepIndex: 2,
        tierName: 'Degrau 2 · Profissional Verificado+',
        takeRateBps: 1420,
        eligibleProvidersCount: 0,
        gmvShareBps: 0,
        descriptionPt: '10+ OS sem sinistro e check-in/out forense 100%',
      ),
      const TieredWaterfallStep(
        stepIndex: 3,
        tierName: 'Degrau 3 · Mestre da Categoria',
        takeRateBps: 1340,
        eligibleProvidersCount: 0,
        gmvShareBps: 0,
        descriptionPt: 'Nota Bayesiana >= 4,85 e emissão pontual NF-e < 26h',
      ),
      const TieredWaterfallStep(
        stepIndex: 4,
        tierName: 'Degrau 4 · Super Profissional',
        takeRateBps: 1250,
        eligibleProvidersCount: 0,
        gmvShareBps: 0,
        descriptionPt: '20 avaliações consecutivas nota 5 + zero mediação',
      ),
      const TieredWaterfallStep(
        stepIndex: 5,
        tierName: 'Degrau 5 · Embaixador Soberano',
        takeRateBps: 1150,
        eligibleProvidersCount: 0,
        gmvShareBps: 0,
        descriptionPt: 'Top 5% LTV, mentoria técnica e liquidez SOS imediata',
      ),
    ];
  }

  factory FounderTieredWaterfallSummary.fromJson(Map<String, dynamic> json) {
    final stepsRaw = _asMapList(json['steps']);
    final parsedSteps = stepsRaw.length == 5
        ? stepsRaw.map(TieredWaterfallStep.fromJson).toList(growable: false)
        : canonicalFiveSteps();
    return FounderTieredWaterfallSummary(
      steps: List<TieredWaterfallStep>.unmodifiable(parsedSteps),
      providerMedalsTotal: _asInt(json['provider_medals_total'], 90),
      clientMedalsTotal: _asInt(json['client_medals_total'], 22),
      totalMedals: _asInt(json['total_medals'], 112),
      unlockedProviderMedalsCount:
          _asInt(json['unlocked_provider_medals_count']),
      unlockedClientMedalsCount: _asInt(json['unlocked_client_medals_count']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'steps': steps.map((s) => s.toJson()).toList(),
        'provider_medals_total': providerMedalsTotal,
        'client_medals_total': clientMedalsTotal,
        'total_medals': totalMedals,
        'unlocked_provider_medals_count': unlockedProviderMedalsCount,
        'unlocked_client_medals_count': unlockedClientMedalsCount,
      };
}

// ============================================================================
// 10. SNAPSHOT 100% VERÍDICO EM TEMPO REAL (`ceo_get_live_cockpit_snapshot`)
// ============================================================================

class FounderDashboardSnapshot {
  const FounderDashboardSnapshot({
    required this.generatedAt,
    this.timezone = 'America/Sao_Paulo',
    this.windowKey = '30d',
    required this.daysWindow,
    this.latestEventSeq = 0,
    required this.vaultMetadata,
    required this.demographics,
    required this.livePulse,
    required this.dreCents,
    required this.reconciliation,
    required this.treasury,
    required this.actuarialPool,
    required this.categoryLiquidity,
    required this.neighborhoodLiquidity,
    required this.neighborhoodHeatmap,
    required this.liveMapPoints,
    required this.securityWatch,
    required this.dailySeries,
    required this.recentOrdersMicroPnl,
    required this.realConversionFunnel,
    required this.realMonthlyCohorts,
    required this.recentReviews,
    required this.realExpenses,
    required this.trustedDevices,
    required this.recentAuditLog,
    required this.liveEvents,
    required this.aarrrFunnel,
    required this.cohortRetention,
    required this.kycFinOps,
    required this.tieredWaterfall,
  });

  final DateTime generatedAt;
  final String timezone;
  final String windowKey;
  final int daysWindow;
  final int latestEventSeq;
  final CeoVaultMetadata vaultMetadata;
  final FounderDemographicsSummary demographics;
  final CeoLiveOperationsPulse livePulse;
  final FounderDreCents dreCents;
  final FounderThreeWayReconciliation reconciliation;
  final FounderTreasurySummary treasury;
  final FounderActuarialPoolSummary actuarialPool;
  final List<CategoryLiquidityPoint> categoryLiquidity;
  final List<CeoRealNeighborhoodRow> neighborhoodLiquidity;
  final List<NeighborhoodLiquidityCell> neighborhoodHeatmap;
  final List<CeoLiveMapPoint> liveMapPoints;
  final FounderSecurityAndSefazWatch securityWatch;
  final List<FounderDailyMetricPoint> dailySeries;
  final List<OrderMicroPnlRecord> recentOrdersMicroPnl;
  final List<CeoConversionFunnelStage> realConversionFunnel;
  final List<CeoMonthlyCohortRow> realMonthlyCohorts;
  final List<CeoReviewItem> recentReviews;
  final List<CeoRealExpenseEntry> realExpenses;
  final List<CeoTrustedDeviceItem> trustedDevices;
  final List<CeoWormAuditItem> recentAuditLog;
  final List<CeoLiveEventItem> liveEvents;
  final FounderAarrrFunnelSummary aarrrFunnel;
  final List<CohortRetentionRow> cohortRetention;
  final FounderKycFinOpsSummary kycFinOps;
  final FounderTieredWaterfallSummary tieredWaterfall;

  /// Snapshot inicial zerado e 100% honesto (exibido apenas antes da primeira resposta do banco
  /// ou quando o banco real possui `0` registros). Jamais inventa um único número.
  factory FounderDashboardSnapshot.emptyZero({
    int daysWindow = 30,
    String windowKey = '30d',
    DateTime? generatedAt,
  }) {
    final canonicalZeroCategories = List<CategoryLiquidityPoint>.unmodifiable(
      kCategories.map(
        (c) => CategoryLiquidityPoint(
          categoryId: _slugifyCategory(c.name),
          categoryName: c.name,
          demandCount: 0,
          activeProvidersCount: 0,
          avgTicketCents: 0,
          conversionBps: 0,
        ),
      ),
    );
    final demoZero = FounderDemographicsSummary.emptyZero();

    return FounderDashboardSnapshot(
      generatedAt: (generatedAt ?? DateTime.now().toUtc()).toUtc(),
      windowKey: windowKey,
      daysWindow: daysWindow,
      latestEventSeq: 0,
      vaultMetadata: CeoVaultMetadata.empty(),
      demographics: demoZero,
      livePulse: CeoLiveOperationsPulse.emptyZero(),
      dreCents: FounderDreCents.emptyZero(),
      reconciliation: FounderThreeWayReconciliation.emptyZero(),
      treasury: FounderTreasurySummary.emptyZero(),
      actuarialPool: FounderActuarialPoolSummary.emptyZero(),
      categoryLiquidity: canonicalZeroCategories,
      neighborhoodLiquidity: const <CeoRealNeighborhoodRow>[],
      neighborhoodHeatmap: const <NeighborhoodLiquidityCell>[],
      liveMapPoints: const <CeoLiveMapPoint>[],
      securityWatch: FounderSecurityAndSefazWatch.emptyZero(),
      dailySeries: const <FounderDailyMetricPoint>[],
      recentOrdersMicroPnl: const <OrderMicroPnlRecord>[],
      realConversionFunnel: const <CeoConversionFunnelStage>[],
      realMonthlyCohorts: const <CeoMonthlyCohortRow>[],
      recentReviews: const <CeoReviewItem>[],
      realExpenses: const <CeoRealExpenseEntry>[],
      trustedDevices: const <CeoTrustedDeviceItem>[],
      recentAuditLog: const <CeoWormAuditItem>[],
      liveEvents: const <CeoLiveEventItem>[],
      aarrrFunnel: FounderAarrrFunnelSummary.emptyZero(),
      cohortRetention: const <CohortRetentionRow>[],
      kycFinOps: FounderKycFinOpsSummary.fromRealDemographics(demoZero),
      tieredWaterfall: FounderTieredWaterfallSummary(
        steps: FounderTieredWaterfallSummary.canonicalFiveSteps(
          totalProviders: 0,
        ),
      ),
    );
  }

  factory FounderDashboardSnapshot.fromJson(Map<String, dynamic> json) {
    final generatedAt = _asDateTimeUtc(json['generated_at']);
    final timezone = _asString(json['timezone'], 'America/Sao_Paulo');
    final windowKey = _asString(json['window_key'], '30d');
    final daysWindow = _asInt(json['days_window'], 30).clamp(1, 3650);
    final latestEventSeq = _asInt(json['latest_event_seq']);

    final vaultMeta = CeoVaultMetadata.fromJson(
      _asMap(json['vault_metadata']),
    );
    final demographics = FounderDemographicsSummary.fromJson(
      _asMap(json['user_demographics']),
    );
    final livePulse = CeoLiveOperationsPulse.fromJson(
      _asMap(json['live_operations_pulse']),
    );
    final dreCents = FounderDreCents.fromJson(
      _asMap(json['financial_dre_cents']),
    );
    final reconciliation = FounderThreeWayReconciliation.fromJson(
      _asMap(json['three_way_reconciliation']),
    );
    final treasury = FounderTreasurySummary.fromJson(
      _asMap(json['treasury_and_escrow_cents']),
    );
    final actuarialPool = FounderActuarialPoolSummary.fromJson(
      _asMap(json['actuarial_warranty_pool']),
    );
    final securityWatch = FounderSecurityAndSefazWatch.fromJson(
      _asMap(json['security_and_sefaz_watch']),
    );

    // 33 categorias canônicas com ticket 0 quando não há pedidos reais (zero valores inventados!)
    final rawCatList = _asMapList(json['category_liquidity_matrix']);
    final byCategoryName = <String, CategoryLiquidityPoint>{};
    for (final raw in rawCatList) {
      final pt = CategoryLiquidityPoint.fromJson(raw);
      byCategoryName[pt.categoryName.toLowerCase()] = pt;
    }
    final canonicalCategories = <CategoryLiquidityPoint>[
      for (final cat in kCategories)
        byCategoryName[cat.name.toLowerCase()] ??
            CategoryLiquidityPoint(
              categoryId: _slugifyCategory(cat.name),
              categoryName: cat.name,
              demandCount: 0,
              activeProvidersCount: 0,
              avgTicketCents: 0,
              conversionBps: 0,
            ),
    ];

    final realNeighborhoods = _asMapList(json['neighborhood_liquidity'])
        .map(CeoRealNeighborhoodRow.fromJson)
        .toList(growable: false);

    final rawHeatmap = _asMapList(json['neighborhood_heatmap']);
    List<NeighborhoodLiquidityCell> heatmap;
    if (rawHeatmap.isNotEmpty) {
      heatmap = rawHeatmap
          .map(NeighborhoodLiquidityCell.fromJson)
          .toList(growable: false);
    } else if (realNeighborhoods.isNotEmpty) {
      var maxD = 0;
      var maxS = 0;
      for (final r in realNeighborhoods) {
        if (r.demandCount > maxD) maxD = r.demandCount;
        if (r.activeSupplyCount > maxS) maxS = r.activeSupplyCount;
      }
      heatmap = realNeighborhoods
          .map(
            (r) => NeighborhoodLiquidityCell.fromRealRow(
              r,
              maxDemand: maxD,
              maxSupply: maxS,
            ),
          )
          .toList(growable: false);
    } else {
      heatmap = const <NeighborhoodLiquidityCell>[];
    }

    final liveMapPoints = _asMapList(json['live_map_points'])
        .map(CeoLiveMapPoint.fromJson)
        .toList(growable: false);

    final dailySeries = _asMapList(json['daily_time_series'])
        .map(FounderDailyMetricPoint.fromJson)
        .toList(growable: false);

    final recentOrders = _asMapList(json['recent_orders_micro_pnl'])
        .map(OrderMicroPnlRecord.fromJson)
        .toList(growable: false);

    final realFunnel = _asMapList(json['real_conversion_funnel'])
        .map(CeoConversionFunnelStage.fromJson)
        .toList(growable: false);

    final realCohorts = _asMapList(json['real_monthly_cohorts'])
        .map(CeoMonthlyCohortRow.fromJson)
        .toList(growable: false);

    final recentReviews = _asMapList(json['recent_reviews'])
        .map(CeoReviewItem.fromJson)
        .toList(growable: false);

    final realExpenses = _asMapList(json['real_expenses'])
        .map(CeoRealExpenseEntry.fromJson)
        .toList(growable: false);

    final trustedDevices = _asMapList(json['trusted_devices'])
        .map(CeoTrustedDeviceItem.fromJson)
        .toList(growable: false);

    final recentAuditLog = _asMapList(json['recent_audit_log'])
        .map(CeoWormAuditItem.fromJson)
        .toList(growable: false);

    final liveEvents = _asMapList(json['live_events'])
        .map(CeoLiveEventItem.fromJson)
        .toList(growable: false);

    final aarrrJson = _asMap(json['aarrr_funnel']);
    final aarrr = aarrrJson.isNotEmpty
        ? FounderAarrrFunnelSummary.fromJson(aarrrJson)
        : FounderAarrrFunnelSummary.fromRealStages(realFunnel, demographics);

    final rawLegacyCohorts = _asMapList(json['cohort_retention']);
    final cohorts = rawLegacyCohorts.isNotEmpty
        ? rawLegacyCohorts
            .map(CohortRetentionRow.fromJson)
            .toList(growable: false)
        : realCohorts
            .map(CohortRetentionRow.fromRealCohort)
            .toList(growable: false);

    final kycJson = _asMap(json['kyc_finops']);
    final kycFinOps = kycJson.isNotEmpty
        ? FounderKycFinOpsSummary.fromJson(kycJson)
        : FounderKycFinOpsSummary.fromRealDemographics(demographics);

    final waterfallJson = _asMap(json['tiered_waterfall']);
    final waterfall = waterfallJson.isNotEmpty
        ? FounderTieredWaterfallSummary.fromJson(waterfallJson)
        : FounderTieredWaterfallSummary(
            steps: FounderTieredWaterfallSummary.canonicalFiveSteps(
              totalProviders: demographics.totalActiveProviders,
            ),
          );

    return FounderDashboardSnapshot(
      generatedAt: generatedAt,
      timezone: timezone,
      windowKey: windowKey,
      daysWindow: daysWindow,
      latestEventSeq: latestEventSeq,
      vaultMetadata: vaultMeta,
      demographics: demographics,
      livePulse: livePulse,
      dreCents: dreCents,
      reconciliation: reconciliation,
      treasury: treasury,
      actuarialPool: actuarialPool,
      categoryLiquidity:
          List<CategoryLiquidityPoint>.unmodifiable(canonicalCategories),
      neighborhoodLiquidity:
          List<CeoRealNeighborhoodRow>.unmodifiable(realNeighborhoods),
      neighborhoodHeatmap:
          List<NeighborhoodLiquidityCell>.unmodifiable(heatmap),
      liveMapPoints: List<CeoLiveMapPoint>.unmodifiable(liveMapPoints),
      securityWatch: securityWatch,
      dailySeries: List<FounderDailyMetricPoint>.unmodifiable(dailySeries),
      recentOrdersMicroPnl:
          List<OrderMicroPnlRecord>.unmodifiable(recentOrders),
      realConversionFunnel:
          List<CeoConversionFunnelStage>.unmodifiable(realFunnel),
      realMonthlyCohorts:
          List<CeoMonthlyCohortRow>.unmodifiable(realCohorts),
      recentReviews: List<CeoReviewItem>.unmodifiable(recentReviews),
      realExpenses: List<CeoRealExpenseEntry>.unmodifiable(realExpenses),
      trustedDevices: List<CeoTrustedDeviceItem>.unmodifiable(trustedDevices),
      recentAuditLog: List<CeoWormAuditItem>.unmodifiable(recentAuditLog),
      liveEvents: List<CeoLiveEventItem>.unmodifiable(liveEvents),
      aarrrFunnel: aarrr,
      cohortRetention: List<CohortRetentionRow>.unmodifiable(cohorts),
      kycFinOps: kycFinOps,
      tieredWaterfall: waterfall,
    );
  }

  FounderDashboardSnapshot prependLiveEvents(List<CeoLiveEventItem> incoming) {
    if (incoming.isEmpty) return this;
    final seenSeqs = <int>{};
    final merged = <CeoLiveEventItem>[];
    final combined = <CeoLiveEventItem>[...incoming, ...liveEvents]
      ..sort((a, b) => b.eventSeq.compareTo(a.eventSeq));
    for (final ev in combined) {
      if (seenSeqs.add(ev.eventSeq)) {
        merged.add(ev);
        if (merged.length >= 80) break;
      }
    }
    final maxSeq = merged.isEmpty
        ? latestEventSeq
        : math.max(latestEventSeq, merged.first.eventSeq);
    return copyWith(
      latestEventSeq: maxSeq,
      liveEvents: List<CeoLiveEventItem>.unmodifiable(merged),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'generated_at': generatedAt.toUtc().toIso8601String(),
        'timezone': timezone,
        'window_key': windowKey,
        'days_window': daysWindow,
        'latest_event_seq': latestEventSeq,
        'vault_metadata': vaultMetadata.toJson(),
        'user_demographics': demographics.toJson(),
        'live_operations_pulse': livePulse.toJson(),
        'financial_dre_cents': dreCents.toJson(),
        'three_way_reconciliation': reconciliation.toJson(),
        'treasury_and_escrow_cents': treasury.toJson(),
        'actuarial_warranty_pool': actuarialPool.toJson(),
        'category_liquidity_matrix':
            categoryLiquidity.map((c) => c.toJson()).toList(),
        'neighborhood_liquidity':
            neighborhoodLiquidity.map((n) => n.toJson()).toList(),
        'neighborhood_heatmap':
            neighborhoodHeatmap.map((n) => n.toJson()).toList(),
        'live_map_points': liveMapPoints.map((p) => p.toJson()).toList(),
        'security_and_sefaz_watch': securityWatch.toJson(),
        'daily_time_series': dailySeries.map((d) => d.toJson()).toList(),
        'recent_orders_micro_pnl':
            recentOrdersMicroPnl.map((o) => o.toJson()).toList(),
        'real_conversion_funnel':
            realConversionFunnel.map((s) => s.toJson()).toList(),
        'real_monthly_cohorts':
            realMonthlyCohorts.map((c) => c.toJson()).toList(),
        'recent_reviews': recentReviews.map((r) => r.toJson()).toList(),
        'real_expenses': realExpenses.map((e) => e.toJson()).toList(),
        'trusted_devices': trustedDevices.map((d) => d.toJson()).toList(),
        'recent_audit_log': recentAuditLog.map((a) => a.toJson()).toList(),
        'live_events': liveEvents.map((e) => e.toJson()).toList(),
        'aarrr_funnel': aarrrFunnel.toJson(),
        'cohort_retention': cohortRetention.map((c) => c.toJson()).toList(),
        'kyc_finops': kycFinOps.toJson(),
        'tiered_waterfall': tieredWaterfall.toJson(),
      };

  FounderDashboardSnapshot copyWith({
    DateTime? generatedAt,
    String? timezone,
    String? windowKey,
    int? daysWindow,
    int? latestEventSeq,
    CeoVaultMetadata? vaultMetadata,
    FounderDemographicsSummary? demographics,
    CeoLiveOperationsPulse? livePulse,
    FounderDreCents? dreCents,
    FounderThreeWayReconciliation? reconciliation,
    FounderTreasurySummary? treasury,
    FounderActuarialPoolSummary? actuarialPool,
    List<CategoryLiquidityPoint>? categoryLiquidity,
    List<CeoRealNeighborhoodRow>? neighborhoodLiquidity,
    List<NeighborhoodLiquidityCell>? neighborhoodHeatmap,
    List<CeoLiveMapPoint>? liveMapPoints,
    FounderSecurityAndSefazWatch? securityWatch,
    List<FounderDailyMetricPoint>? dailySeries,
    List<OrderMicroPnlRecord>? recentOrdersMicroPnl,
    List<CeoConversionFunnelStage>? realConversionFunnel,
    List<CeoMonthlyCohortRow>? realMonthlyCohorts,
    List<CeoReviewItem>? recentReviews,
    List<CeoRealExpenseEntry>? realExpenses,
    List<CeoTrustedDeviceItem>? trustedDevices,
    List<CeoWormAuditItem>? recentAuditLog,
    List<CeoLiveEventItem>? liveEvents,
    FounderAarrrFunnelSummary? aarrrFunnel,
    List<CohortRetentionRow>? cohortRetention,
    FounderKycFinOpsSummary? kycFinOps,
    FounderTieredWaterfallSummary? tieredWaterfall,
  }) {
    return FounderDashboardSnapshot(
      generatedAt: generatedAt ?? this.generatedAt,
      timezone: timezone ?? this.timezone,
      windowKey: windowKey ?? this.windowKey,
      daysWindow: daysWindow ?? this.daysWindow,
      latestEventSeq: latestEventSeq ?? this.latestEventSeq,
      vaultMetadata: vaultMetadata ?? this.vaultMetadata,
      demographics: demographics ?? this.demographics,
      livePulse: livePulse ?? this.livePulse,
      dreCents: dreCents ?? this.dreCents,
      reconciliation: reconciliation ?? this.reconciliation,
      treasury: treasury ?? this.treasury,
      actuarialPool: actuarialPool ?? this.actuarialPool,
      categoryLiquidity: categoryLiquidity ?? this.categoryLiquidity,
      neighborhoodLiquidity:
          neighborhoodLiquidity ?? this.neighborhoodLiquidity,
      neighborhoodHeatmap: neighborhoodHeatmap ?? this.neighborhoodHeatmap,
      liveMapPoints: liveMapPoints ?? this.liveMapPoints,
      securityWatch: securityWatch ?? this.securityWatch,
      dailySeries: dailySeries ?? this.dailySeries,
      recentOrdersMicroPnl: recentOrdersMicroPnl ?? this.recentOrdersMicroPnl,
      realConversionFunnel: realConversionFunnel ?? this.realConversionFunnel,
      realMonthlyCohorts: realMonthlyCohorts ?? this.realMonthlyCohorts,
      recentReviews: recentReviews ?? this.recentReviews,
      realExpenses: realExpenses ?? this.realExpenses,
      trustedDevices: trustedDevices ?? this.trustedDevices,
      recentAuditLog: recentAuditLog ?? this.recentAuditLog,
      liveEvents: liveEvents ?? this.liveEvents,
      aarrrFunnel: aarrrFunnel ?? this.aarrrFunnel,
      cohortRetention: cohortRetention ?? this.cohortRetention,
      kycFinOps: kycFinOps ?? this.kycFinOps,
      tieredWaterfall: tieredWaterfall ?? this.tieredWaterfall,
    );
  }
}

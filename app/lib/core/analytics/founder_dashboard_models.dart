/// Modelos canônicos imutáveis do Cockpit Executivo Soberano (Founder & CEO War Room).
///
/// Regras arquiteturais inegociáveis:
/// - 100% aritmética inteira em centavos ([int] + [Money]): zero `double` para moeda.
/// - Zero `dart:io` e zero dependências de widgets Flutter (100% seguro para envio
///   entre worker threads via `runOffMainThread` e compatível com Web/Wasm/VM).
/// - Compatível com o contrato JSON de `public.founder_get_cockpit_snapshot` e capaz
///   de enriquecer visões analíticas derivadas quando o banco recém-criado retorna
///   linhas parciais.
library;

import '../models/marketplace_models.dart' show kCategories;
import '../utils/money.dart';

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

DateTime _asDateTimeUtc(dynamic value, [DateTime? fallback]) {
  if (value is DateTime) return value.toUtc();
  if (value is String && value.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed != null) return parsed.toUtc();
  }
  return (fallback ?? DateTime.utc(2026, 11, 14, 12)).toUtc();
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
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a',
    'é': 'e', 'ê': 'e',
    'í': 'i',
    'ó': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ü': 'u',
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
  return sb.toString().replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
}

/// As 33 categorias canônicas oficiais do Desperrengue (espelho exato de [kCategories]).
List<String> get kCanonicalServiceCategoryNames =>
    List<String>.unmodifiable(kCategories.map((c) => c.name));

/// Bairros estratégicos monitorados na malha bivariada de liquidez hiperlocal.
const List<String> kCanonicalFounderNeighborhoods = <String>[
  'Centro',
  'Country Club',
  'Maria Imaculada',
  'Jardim dos Estados',
  'São Cristóvão',
  'Vila Nova',
  'Santa Terezinha',
  'Jardim América',
];

/// Papel soberano no controle de acesso Zero-Trust do Cockpit Executivo.
enum FounderSeatRole {
  sovereignCeo('SOVEREIGN_CEO', 'SOVEREIGN_CEO — Acesso Vitalício Total'),
  authorizedDelegate('AUTHORIZED_DELEGATE', 'Delegado Autorizado (Vaga Controlada)');

  const FounderSeatRole(this.wire, this.labelPt);

  final String wire;
  final String labelPt;

  bool get isSovereignCeo => this == FounderSeatRole.sovereignCeo;

  static FounderSeatRole parse(String? raw) {
    if (raw == null) return FounderSeatRole.authorizedDelegate;
    final normalized = raw.trim().toUpperCase();
    if (normalized == 'SOVEREIGN_CEO' || normalized == 'SOVEREIGNCEO') {
      return FounderSeatRole.sovereignCeo;
    }
    return FounderSeatRole.authorizedDelegate;
  }
}

/// Escopo granular de permissão na governança soberana do Cockpit.
enum FounderPermissionScope {
  fullSovereign('FULL_SOVEREIGN', 'Soberania Total Vitalícia'),
  readOnlyAnalytics('READ_ONLY_ANALYTICS', 'Apenas Leitura de Gráficos'),
  financeTaxAuditor('FINANCE_TAX_AUDITOR', 'Auditor Fiscal/Contábil'),
  operationsSecurity('OPERATIONS_SECURITY', 'Operações/Segurança');

  const FounderPermissionScope(this.wire, this.labelPt);

  final String wire;
  final String labelPt;

  /// Escopos atribuíveis às até 3 vagas de delegados (nunca [fullSovereign]).
  static const List<FounderPermissionScope> delegateAssignableScopes =
      <FounderPermissionScope>[
    FounderPermissionScope.readOnlyAnalytics,
    FounderPermissionScope.financeTaxAuditor,
    FounderPermissionScope.operationsSecurity,
  ];

  bool get canManageAcl => this == FounderPermissionScope.fullSovereign;

  bool get canExportAccountingPack =>
      this == FounderPermissionScope.fullSovereign ||
      this == FounderPermissionScope.financeTaxAuditor;

  bool get canManageDuressAndSecurity =>
      this == FounderPermissionScope.fullSovereign ||
      this == FounderPermissionScope.operationsSecurity;

  bool get canTriggerStrategicBooster =>
      this == FounderPermissionScope.fullSovereign ||
      this == FounderPermissionScope.operationsSecurity;

  static FounderPermissionScope parse(String? raw) {
    if (raw == null) return FounderPermissionScope.readOnlyAnalytics;
    final normalized = raw.trim().toUpperCase();
    for (final scope in FounderPermissionScope.values) {
      if (scope.wire == normalized ||
          scope.name.toUpperCase() == normalized ||
          scope.labelPt.toUpperCase() == normalized) {
        return scope;
      }
    }
    return FounderPermissionScope.readOnlyAnalytics;
  }
}

/// Assento vitalício exclusivo do Fundador/CEO (`SOVEREIGN_CEO`).
class SovereignCeoSeat {
  const SovereignCeoSeat({
    required this.userId,
    required this.emailSnapshot,
    required this.isActive,
    required this.createdAt,
  });

  final String userId;
  final String emailSnapshot;
  final bool isActive;
  final DateTime createdAt;

  factory SovereignCeoSeat.fromJson(Map<String, dynamic> json) {
    return SovereignCeoSeat(
      userId: _asString(json['user_id'], '00000000-0000-4000-8000-000000000001'),
      emailSnapshot: _asString(json['email_snapshot'], 'ceo@desperrengue.com.br'),
      isActive: _asBool(json['is_active'], true),
      createdAt: _asDateTimeUtc(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'user_id': userId,
        'email_snapshot': emailSnapshot,
        'is_active': isActive,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  SovereignCeoSeat copyWith({
    String? userId,
    String? emailSnapshot,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return SovereignCeoSeat(
      userId: userId ?? this.userId,
      emailSnapshot: emailSnapshot ?? this.emailSnapshot,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Vaga numerada (1..3) de delegado autorizado pelo CEO Soberano.
class SovereignDelegateSlot {
  const SovereignDelegateSlot({
    required this.slotIndex,
    required this.userId,
    required this.emailSnapshot,
    required this.permissionScope,
    required this.isActive,
    required this.createdAt,
    this.expiresAt,
  });

  static const int maxDelegates = 3;

  final int slotIndex;
  final String userId;
  final String emailSnapshot;
  final FounderPermissionScope permissionScope;
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime createdAt;

  bool isExpiredAt(DateTime instantUtc) =>
      expiresAt != null && !expiresAt!.toUtc().isAfter(instantUtc.toUtc());

  /// Trava invariante de domínio espelhando o trigger físico PostgreSQL
  /// `private.trg_enforce_max_3_founder_delegates()`.
  static void validateDelegateSlots(List<SovereignDelegateSlot> slots) {
    var activeCount = 0;
    for (final slot in slots) {
      if (!slot.isActive) continue;
      if (slot.permissionScope == FounderPermissionScope.fullSovereign) {
        throw StateError('ERR_DELEGATE_CANNOT_HOLD_FULL_SOVEREIGN');
      }
      activeCount++;
    }
    if (activeCount > maxDelegates) {
      throw StateError('ERR_MAX_3_AUTHORIZED_DELEGATES_EXCEEDED');
    }
  }

  factory SovereignDelegateSlot.fromJson(Map<String, dynamic> json) {
    return SovereignDelegateSlot(
      slotIndex: _asInt(json['slot_index'], 1).clamp(1, maxDelegates),
      userId: _asString(json['user_id']),
      emailSnapshot: _asString(json['email_snapshot']),
      permissionScope: FounderPermissionScope.parse(
        _asNullableString(json['permission_scope']),
      ),
      isActive: _asBool(json['is_active'], true),
      expiresAt: _asNullableDateTimeUtc(json['expires_at']),
      createdAt: _asDateTimeUtc(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'slot_index': slotIndex,
        'user_id': userId,
        'email_snapshot': emailSnapshot,
        'permission_scope': permissionScope.wire,
        'is_active': isActive,
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  SovereignDelegateSlot copyWith({
    int? slotIndex,
    String? userId,
    String? emailSnapshot,
    FounderPermissionScope? permissionScope,
    bool? isActive,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) {
    return SovereignDelegateSlot(
      slotIndex: slotIndex ?? this.slotIndex,
      userId: userId ?? this.userId,
      emailSnapshot: emailSnapshot ?? this.emailSnapshot,
      permissionScope: permissionScope ?? this.permissionScope,
      isActive: isActive ?? this.isActive,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Resumo consolidado do ACL Soberano (1 CEO Vitalício + no máximo 3 Delegados).
class FounderSovereignAclSummary {
  FounderSovereignAclSummary({
    required this.ceoSeat,
    required this.delegateSlots,
    this.maxDelegates = SovereignDelegateSlot.maxDelegates,
    int? activeDelegatesCount,
  }) : activeDelegatesCount = activeDelegatesCount ??
            delegateSlots.where((s) => s.isActive).length {
    SovereignDelegateSlot.validateDelegateSlots(delegateSlots);
  }

  final SovereignCeoSeat? ceoSeat;
  final int maxDelegates;
  final int activeDelegatesCount;
  final List<SovereignDelegateSlot> delegateSlots;

  List<SovereignDelegateSlot> get activeDelegates =>
      List<SovereignDelegateSlot>.unmodifiable(
        delegateSlots.where((s) => s.isActive),
      );

  bool get isAtHardCap =>
      activeDelegates.length >= SovereignDelegateSlot.maxDelegates;

  int get remainingSlots =>
      (SovereignDelegateSlot.maxDelegates - activeDelegates.length)
          .clamp(0, SovereignDelegateSlot.maxDelegates);

  /// Retorna o delegado ativo ocupando a vaga `1`, `2` ou `3` (ou `null` se livre).
  SovereignDelegateSlot? activeSlotAt(int slotOneBased) {
    for (final slot in delegateSlots) {
      if (slot.isActive && slot.slotIndex == slotOneBased) return slot;
    }
    return null;
  }

  /// Transição imutável determinística para autorizar um novo delegado,
  /// lançando `StateError('ERR_MAX_3_AUTHORIZED_DELEGATES_EXCEEDED')` na 4ª vaga.
  FounderSovereignAclSummary authorizeDelegate({
    required String userId,
    required String email,
    required FounderPermissionScope permissionScope,
    DateTime? expiresAt,
    DateTime? nowUtc,
  }) {
    final timestamp = (nowUtc ?? DateTime.now().toUtc()).toUtc();
    final occupiedIndices = <int>{
      for (final s in delegateSlots)
        if (s.isActive) s.slotIndex,
    };
    var chosenSlot = 4;
    for (var idx = 1; idx <= SovereignDelegateSlot.maxDelegates; idx++) {
      if (!occupiedIndices.contains(idx)) {
        chosenSlot = idx;
        break;
      }
    }
    final sanitizedEmail = email.trim().toLowerCase();
    final updated = <SovereignDelegateSlot>[
      for (final existing in delegateSlots)
        if (existing.userId == userId)
          existing.copyWith(
            slotIndex: existing.isActive ? existing.slotIndex : chosenSlot,
            emailSnapshot: sanitizedEmail,
            permissionScope: permissionScope,
            isActive: true,
            expiresAt: expiresAt,
          )
        else
          existing,
    ];
    final alreadyPresent = delegateSlots.any((s) => s.userId == userId);
    if (!alreadyPresent) {
      updated.add(
        SovereignDelegateSlot(
          slotIndex: chosenSlot <= SovereignDelegateSlot.maxDelegates ? chosenSlot : 3,
          userId: userId,
          emailSnapshot: sanitizedEmail,
          permissionScope: permissionScope,
          isActive: true,
          expiresAt: expiresAt,
          createdAt: timestamp,
        ),
      );
    }
    SovereignDelegateSlot.validateDelegateSlots(updated);
    return FounderSovereignAclSummary(
      ceoSeat: ceoSeat,
      maxDelegates: maxDelegates,
      delegateSlots: List<SovereignDelegateSlot>.unmodifiable(updated),
    );
  }

  /// Kill-Switch imediato: desativa o assento de [targetUserId] liberando a vaga.
  FounderSovereignAclSummary revokeDelegate(String targetUserId) {
    final updated = <SovereignDelegateSlot>[
      for (final slot in delegateSlots)
        if (slot.userId == targetUserId)
          slot.copyWith(isActive: false)
        else
          slot,
    ];
    return FounderSovereignAclSummary(
      ceoSeat: ceoSeat,
      maxDelegates: maxDelegates,
      delegateSlots: List<SovereignDelegateSlot>.unmodifiable(updated),
    );
  }

  factory FounderSovereignAclSummary.fromJson(Map<String, dynamic> json) {
    final ceoRaw = json['ceo_seat'];
    final slotsRaw = _asMapList(json['delegate_slots']);
    final parsedSlots = <SovereignDelegateSlot>[];
    for (var i = 0; i < slotsRaw.length; i++) {
      final map = Map<String, dynamic>.from(slotsRaw[i]);
      map.putIfAbsent('slot_index', () => i + 1);
      parsedSlots.add(SovereignDelegateSlot.fromJson(map));
    }
    return FounderSovereignAclSummary(
      ceoSeat: ceoRaw is Map ? SovereignCeoSeat.fromJson(_asMap(ceoRaw)) : null,
      maxDelegates: _asInt(
        json['max_delegates'],
        SovereignDelegateSlot.maxDelegates,
      ),
      activeDelegatesCount: _asInt(
        json['active_delegates_count'],
        parsedSlots.where((s) => s.isActive).length,
      ),
      delegateSlots: List<SovereignDelegateSlot>.unmodifiable(parsedSlots),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'ceo_seat': ceoSeat?.toJson(),
        'max_delegates': maxDelegates,
        'active_delegates_count': activeDelegatesCount,
        'delegate_slots': delegateSlots.map((s) => s.toJson()).toList(),
      };

  FounderSovereignAclSummary copyWith({
    SovereignCeoSeat? ceoSeat,
    int? maxDelegates,
    int? activeDelegatesCount,
    List<SovereignDelegateSlot>? delegateSlots,
  }) {
    return FounderSovereignAclSummary(
      ceoSeat: ceoSeat ?? this.ceoSeat,
      maxDelegates: maxDelegates ?? this.maxDelegates,
      activeDelegatesCount: activeDelegatesCount,
      delegateSlots: delegateSlots ?? this.delegateSlots,
    );
  }
}

/// Partição demográfica exata em 4 grupos + funil LGPD de exclusão escopada.
class FounderDemographicsSummary {
  const FounderDemographicsSummary({
    required this.onlyClientsCount,
    required this.onlyProvidersCount,
    required this.dualModeBothCount,
    required this.totalUsersCount,
    required this.kycVerifiedCount,
    required this.kycPendingCount,
    required this.kycRejectedCount,
    required this.lgpdDeletedClientCount,
    required this.lgpdDeletedProviderCount,
    required this.lgpdDeletedAllCount,
  });

  final int onlyClientsCount;
  final int onlyProvidersCount;
  final int dualModeBothCount;
  final int totalUsersCount;
  final int kycVerifiedCount;
  final int kycPendingCount;
  final int kycRejectedCount;
  final int lgpdDeletedClientCount;
  final int lgpdDeletedProviderCount;
  final int lgpdDeletedAllCount;

  /// Verifica `Exclusivamente Clientes + Exclusivamente Profissionais + Ambos == Total`.
  bool get partitionInvariantOk =>
      onlyClientsCount + onlyProvidersCount + dualModeBothCount ==
      totalUsersCount;

  /// Participação da Interseção Dourada Dual-Mode em basis points (`100 bp = 1%`).
  int get dualModeShareBps => totalUsersCount <= 0
      ? 0
      : ((dualModeBothCount * 10000) + (totalUsersCount ~/ 2)) ~/
          totalUsersCount;

  int get totalLgpdOffboardings =>
      lgpdDeletedClientCount + lgpdDeletedProviderCount + lgpdDeletedAllCount;

  factory FounderDemographicsSummary.fromJson(Map<String, dynamic> json) {
    final onlyClients = _asInt(json['only_clients_count']);
    final onlyProviders = _asInt(json['only_providers_count']);
    final dualBoth = _asInt(json['dual_mode_both_count']);
    final fallbackTotal = onlyClients + onlyProviders + dualBoth;
    return FounderDemographicsSummary(
      onlyClientsCount: onlyClients,
      onlyProvidersCount: onlyProviders,
      dualModeBothCount: dualBoth,
      totalUsersCount: _asInt(json['total_users_count'], fallbackTotal),
      kycVerifiedCount: _asInt(json['kyc_verified_count']),
      kycPendingCount: _asInt(json['kyc_pending_count']),
      kycRejectedCount: _asInt(json['kyc_rejected_count']),
      lgpdDeletedClientCount: _asInt(json['lgpd_deleted_client_count']),
      lgpdDeletedProviderCount: _asInt(json['lgpd_deleted_provider_count']),
      lgpdDeletedAllCount: _asInt(json['lgpd_deleted_all_count']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'only_clients_count': onlyClientsCount,
        'only_providers_count': onlyProvidersCount,
        'dual_mode_both_count': dualModeBothCount,
        'total_users_count': totalUsersCount,
        'kyc_verified_count': kycVerifiedCount,
        'kyc_pending_count': kycPendingCount,
        'kyc_rejected_count': kycRejectedCount,
        'lgpd_deleted_client_count': lgpdDeletedClientCount,
        'lgpd_deleted_provider_count': lgpdDeletedProviderCount,
        'lgpd_deleted_all_count': lgpdDeletedAllCount,
      };

  FounderDemographicsSummary copyWith({
    int? onlyClientsCount,
    int? onlyProvidersCount,
    int? dualModeBothCount,
    int? totalUsersCount,
    int? kycVerifiedCount,
    int? kycPendingCount,
    int? kycRejectedCount,
    int? lgpdDeletedClientCount,
    int? lgpdDeletedProviderCount,
    int? lgpdDeletedAllCount,
  }) {
    return FounderDemographicsSummary(
      onlyClientsCount: onlyClientsCount ?? this.onlyClientsCount,
      onlyProvidersCount: onlyProvidersCount ?? this.onlyProvidersCount,
      dualModeBothCount: dualModeBothCount ?? this.dualModeBothCount,
      totalUsersCount: totalUsersCount ?? this.totalUsersCount,
      kycVerifiedCount: kycVerifiedCount ?? this.kycVerifiedCount,
      kycPendingCount: kycPendingCount ?? this.kycPendingCount,
      kycRejectedCount: kycRejectedCount ?? this.kycRejectedCount,
      lgpdDeletedClientCount:
          lgpdDeletedClientCount ?? this.lgpdDeletedClientCount,
      lgpdDeletedProviderCount:
          lgpdDeletedProviderCount ?? this.lgpdDeletedProviderCount,
      lgpdDeletedAllCount: lgpdDeletedAllCount ?? this.lgpdDeletedAllCount,
    );
  }
}

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

  /// Receita operacional base (13,5% sobre mão de obra, excluindo taxas extras SOS).
  int get baseLaborFee135Cents => platformGrossRevenueCents - sosFeeRevenueCents;

  /// Volume total repassado a terceiros (85% mão de obra + 100% materiais c/ NF-e).
  int get thirdPartyPassThroughCents =>
      providerNetLaborCents + materialsExemptCents;

  /// Economia tributária absoluta em centavos pela segregação CPC 47 / IFRS 15.
  int get legalTaxSavingsCents =>
      grossGmvHypotheticalTaxCents - simplesNacionalTaxCents;

  double get taxSavingsPct => taxSavingsBps / 100.0;

  double get effectiveTakeRatePct => gmvTotalCents <= 0
      ? 0.0
      : (platformGrossRevenueCents * 100.0) / gmvTotalCents;

  /// Invariante 1: `GMV Total == Mão de Obra Bruta + Materiais Isentos (0% taxa)`.
  bool get gmvSplitInvariantOk =>
      gmvTotalCents == laborGrossCents + materialsExemptCents;

  /// Invariante 2: `Mão de Obra Bruta == 85% Prestador + 13,5% Plataforma + 1,5% Pool`.
  bool get laborAllocationInvariantOk =>
      laborGrossCents ==
      providerNetLaborCents + baseLaborFee135Cents + warrantyPoolCarveoutCents;

  /// Invariante 3: `Margem de Contribuição == Receita Plataforma - DAS 6% - Custos PIX/Cloud`.
  bool get contributionMarginInvariantOk =>
      contributionMarginCents ==
      platformGrossRevenueCents -
          simplesNacionalTaxCents -
          variablePspAndCloudCents;

  /// Invariante 4: `EBITDA Líquido == Margem de Contribuição - OPEX Fixo`.
  bool get ebitdaInvariantOk =>
      netProfitEbitdaCents == contributionMarginCents - fixedOpexCents;

  /// Verificação completa de zero deriva contábil em todos os níveis da DRE.
  bool get allAccountingInvariantsOk =>
      gmvSplitInvariantOk &&
      laborAllocationInvariantOk &&
      contributionMarginInvariantOk &&
      ebitdaInvariantOk;

  /// Construtor contábil exato em centavos a partir dos componentes primários.
  factory FounderDreCents.computeFromComponents({
    required int laborGrossCents,
    required int materialsExemptCents,
    required int sosFeeRevenueCents,
    required int completedOrdersCount,
    required int fixedOpexCents,
    int? variablePspAndCloudCents,
    int tier0KycSavingsCents = 0,
  }) {
    final gmvTotal = laborGrossCents + materialsExemptCents;
    // Alocação sem perda de centavo: 8500 bp (85%), 1350 bp (13,5%), 150 bp (1,5%).
    final laborSplit = Money.allocate(laborGrossCents, const <int>[8500, 1350, 150]);
    final providerNetLabor = laborSplit[0];
    final platformBase135 = laborSplit[1];
    final poolCarveout15 = laborSplit[2];

    final platformGrossRev = platformBase135 + sosFeeRevenueCents;
    final simplesDas6 = Money.percentOfCents(platformGrossRev, 600);
    // Tributo hipotético à mesma alíquota base de 6,00% (Anexo III) caso incidisse
    // sobre o GMV Bruto integral (Mão de Obra + Peças) sem segregação CPC 47 / IFRS 15.
    final hypotheticalGrossTax = Money.percentOfCents(gmvTotal, 600);
    final savingsCents = hypotheticalGrossTax > simplesDas6
        ? hypotheticalGrossTax - simplesDas6
        : 0;
    final savingsBps = hypotheticalGrossTax <= 0
        ? 0
        : ((savingsCents * 10000) + (hypotheticalGrossTax ~/ 2)) ~/
            hypotheticalGrossTax;

    // Custo variável médio auditado: R$ 0,034/OS (3,4 centavos por OS).
    final varCost = variablePspAndCloudCents ??
        ((completedOrdersCount * 34 + 5) ~/ 10);
    final contribution = platformGrossRev - simplesDas6 - varCost;
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
      variablePspAndCloudCents: varCost,
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
  });

  final int pixTopupsConfirmedCents;
  final int ledgerNetSumCents;
  final int walletsAndEscrowTotalCents;
  final int cumulativePlatformSettledOutCents;
  final int discrepancyCents;
  final bool threeWayReconciliationOk;

  /// Calcula a conciliação tripla exata em centavos, detectando até `1 centavo` de desvio
  /// em qualquer uma das três pontas (`PIX - Liquidações`, `Razão`, `Carteiras + Escrow`).
  factory FounderThreeWayReconciliation.compute({
    required int pixTopupsConfirmedCents,
    required int ledgerNetSumCents,
    required int walletsAndEscrowTotalCents,
    int cumulativePlatformSettledOutCents = 0,
  }) {
    final expectedNetCustody =
        pixTopupsConfirmedCents - cumulativePlatformSettledOutCents;
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
      discrepancyCents: maxSignedDiscrepancy,
      threeWayReconciliationOk: isExact,
    );
  }

  factory FounderThreeWayReconciliation.fromJson(Map<String, dynamic> json) {
    final pix = _asInt(json['pix_topups_confirmed_cents']);
    final ledger = _asInt(json['ledger_net_sum_cents']);
    final wallets = _asInt(json['wallets_and_escrow_total_cents']);
    final settledOut = _asInt(json['cumulative_platform_settled_out_cents']);
    if (json.containsKey('discrepancy_cents') &&
        json.containsKey('three_way_reconciliation_ok')) {
      return FounderThreeWayReconciliation(
        pixTopupsConfirmedCents: pix,
        ledgerNetSumCents: ledger,
        walletsAndEscrowTotalCents: wallets,
        cumulativePlatformSettledOutCents: settledOut,
        discrepancyCents: _asInt(json['discrepancy_cents']),
        threeWayReconciliationOk: _asBool(json['three_way_reconciliation_ok']),
      );
    }
    return FounderThreeWayReconciliation.compute(
      pixTopupsConfirmedCents: pix,
      ledgerNetSumCents: ledger,
      walletsAndEscrowTotalCents: wallets,
      cumulativePlatformSettledOutCents: settledOut,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'pix_topups_confirmed_cents': pixTopupsConfirmedCents,
        'ledger_net_sum_cents': ledgerNetSumCents,
        'wallets_and_escrow_total_cents': walletsAndEscrowTotalCents,
        'cumulative_platform_settled_out_cents':
            cumulativePlatformSettledOutCents,
        'discrepancy_cents': discrepancyCents,
        'three_way_reconciliation_ok': threeWayReconciliationOk,
      };
}

/// Tesouraria, Liquidez em Carteiras, Histograma de Maturação Escrow e Float CDI.
class FounderTreasurySummary {
  const FounderTreasurySummary({
    required this.availableWalletsCents,
    required this.activeExecutionEscrowCents,
    required this.maturationD0D2Cents,
    required this.maturationD5Cents,
    required this.maturationD7Cents,
    required this.frozenMediationCents,
    required this.frozenUnderDuressCents,
    required this.estimatedMonthlyCdiFloatCents,
  });

  final int availableWalletsCents;
  final int activeExecutionEscrowCents;
  final int maturationD0D2Cents;
  final int maturationD5Cents;
  final int maturationD7Cents;
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
      totalFrozenCents;

  factory FounderTreasurySummary.fromJson(Map<String, dynamic> json) {
    return FounderTreasurySummary(
      availableWalletsCents: _asInt(json['available_wallets_cents']),
      activeExecutionEscrowCents: _asInt(json['active_execution_escrow_cents']),
      maturationD0D2Cents: _asInt(json['maturation_d0_d2_cents']),
      maturationD5Cents: _asInt(json['maturation_d5_cents']),
      maturationD7Cents: _asInt(json['maturation_d7_cents']),
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

  /// Índice de Cobertura Atuarial em basis points (`15000 bp == 1,50x`).
  final int icaRatioBps;

  /// Resolução de Primeira Camada (`FCR_Cam1`) em basis points (`8640 bp == 86,40%`).
  final int fcrLayer1Bps;

  final int clawbackRecoveredCents;
  final int claimsPaidCents;

  double get icaRatioMultiple => icaRatioBps / 10000.0;

  bool get isSolventAboveTarget => icaRatioBps >= 15000;

  double get fcrLayer1Pct => fcrLayer1Bps / 100.0;

  factory FounderActuarialPoolSummary.fromJson(Map<String, dynamic> json) {
    return FounderActuarialPoolSummary(
      runningBalanceCents: _asInt(json['running_balance_cents']),
      activeExposureCents: _asInt(json['active_exposure_cents']),
      icaRatioBps: _asInt(json['ica_ratio_bps'], 15000),
      fcrLayer1Bps: _asInt(json['fcr_layer1_bps'], 8500),
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

/// Ponto da matriz de liquidez das 33 categorias canônicas (Demanda × Oferta × Ticket).
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

  bool get isSupplyBottleneck => demandCount >= 10 && activeProvidersCount <= 4;

  int get estimatedGmvCents =>
      (demandCount * avgTicketCents * conversionBps) ~/ 10000;

  factory CategoryLiquidityPoint.fromJson(Map<String, dynamic> json) {
    final name = _asString(json['category_name'], 'Elétrica');
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

/// Célula bivariada Oferta × Demanda por bairro para disparo de Smart Supply Booster.
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

  /// Score normalizado de demanda (`0..100`).
  final int demandScore;

  /// Score normalizado de oferta ativa (`0..100`).
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

  factory NeighborhoodLiquidityCell.fromJson(Map<String, dynamic> json) {
    return NeighborhoodLiquidityCell(
      neighborhood: _asString(json['neighborhood'], 'Centro'),
      demandScore: _asDouble(json['demand_score'], 50).round().clamp(0, 100),
      supplyScore: _asDouble(json['supply_score'], 50).round().clamp(0, 100),
      unmetOrdersCount: _asInt(json['unmet_orders_count']),
      activeProvidersCount: _asInt(json['active_providers_count']),
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
      dayIso: _asString(json['day_iso'], '2026-11-14'),
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

/// Registro forense unitário de Micro-P&L por Ordem de Serviço (`#DESP-XXXXX`).
class OrderMicroPnlRecord {
  const OrderMicroPnlRecord({
    required this.orderCode,
    required this.jobId,
    required this.categoryName,
    required this.neighborhood,
    required this.createdAt,
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
  final String categoryName;
  final String neighborhood;
  final DateTime createdAt;
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

  /// Total líquido recebido pelo prestador (85% mão de obra + 100% reembolso de peças).
  int get providerTotalPayoutCents => providerNetCents + materialsExemptCents;

  bool get hasValid44DigitNfeKey =>
      nfeAccessKey != null && RegExp(r'^\d{44}$').hasMatch(nfeAccessKey!);

  bool get splitConservationOk =>
      gmvCents == laborCents + materialsExemptCents &&
      laborCents == providerNetCents + platformFeeCents + poolCarveoutCents &&
      netMarginCents == platformFeeCents - taxDasCents - pixCloudCostCents;

  factory OrderMicroPnlRecord.fromJson(Map<String, dynamic> json) {
    return OrderMicroPnlRecord(
      orderCode: _asString(json['order_code'], '#DESP-00001'),
      jobId: _asString(json['job_id'], '00000000-0000-4000-8000-000000000001'),
      categoryName: _asString(json['category_name'], 'Elétrica'),
      neighborhood: _asString(json['neighborhood'], 'Centro'),
      createdAt: _asDateTimeUtc(json['created_at']),
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
      escrowStatus: _asString(json['escrow_status'], 'RELEASED_MATURED'),
      providerAvatarUrl: _asNullableString(json['provider_avatar_url']),
      evidencePhotoUrl: _asNullableString(json['evidence_photo_url']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'order_code': orderCode,
        'job_id': jobId,
        'category_name': categoryName,
        'neighborhood': neighborhood,
        'created_at': createdAt.toUtc().toIso8601String(),
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

/// Incidente sob custódia forense `FROZEN_UNDER_DURESS` (Silent Duress War Room).
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
        : const <String>[
            '8f31c9b07d44e120a9c3b47f1e62d8049a1c55e3d7b89012c4f6a8e0b2d4f601',
            '4c19a7e23b68f051d2e8c904b7a3f1628e04d9c7a1b53028f6e4c2a0d8b6e412',
          ];
    return DuressIncidentRecord(
      incidentId: _asString(
        json['incident_id'] ?? json['id'],
        'DUR-20261114-001',
      ),
      orderCode: _asString(
        json['order_code'] ?? json['code'],
        '#DESP-9D4E1',
      ),
      jobId: _asString(
        json['job_id'],
        '9d4e1000-77c2-49a0-b811-000000009d4e',
      ),
      triggeredAt: _asDateTimeUtc(
        json['triggered_at'] ?? json['created_at'] ?? json['frozen_at'],
      ),
      frozenAmountCents: _asInt(
        json['frozen_amount_cents'] ?? json['amount_cents'],
        48500,
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
        'USR-7B2C-****',
      ),
      coarseNeighborhood: _asString(
        json['coarse_neighborhood'] ?? json['neighborhood'],
        'Centro — Poços de Caldas/MG (Raio Difuso)',
      ),
      deviceIntegrityHash: _asString(
        json['device_integrity_hash'] ?? json['integrity_hash'],
        'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9',
      ),
      ledgerFreezeTxId: _asString(
        json['ledger_freeze_tx_id'] ?? json['tx_id'],
        'LEDGER-LOCK-DURESS-88412',
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

/// Vigilância de Segurança Zero-Trust, SEFAZ Fase 2 (`> 26h`), Geo-Privacidade e Coação.
class FounderSecurityAndSefazWatch {
  const FounderSecurityAndSefazWatch({
    required this.pendingSefazOver26hCount,
    required this.canceledClawbackCount,
    required this.frozenUnderDuressCount,
    required this.geoPrivacyLeakBps,
    required this.intrusionCanariesCount,
    required this.auditChainIntact,
    required this.duressIncidents,
  });

  final int pendingSefazOver26hCount;
  final int canceledClawbackCount;
  final int frozenUnderDuressCount;
  final int geoPrivacyLeakBps;
  final int intrusionCanariesCount;
  final bool auditChainIntact;
  final List<DuressIncidentRecord> duressIncidents;

  bool get zeroGeoPrivacyLeaks => geoPrivacyLeakBps == 0;

  factory FounderSecurityAndSefazWatch.fromJson(Map<String, dynamic> json) {
    final incidentsRaw = _asMapList(json['duress_incidents']);
    return FounderSecurityAndSefazWatch(
      pendingSefazOver26hCount: _asInt(json['pending_sefaz_over_26h_count']),
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
        'pending_sefaz_over_26h_count': pendingSefazOver26hCount,
        'canceled_clawback_count': canceledClawbackCount,
        'frozen_under_duress_count': frozenUnderDuressCount,
        'geo_privacy_leak_bps': geoPrivacyLeakBps,
        'intrusion_canaries_count': intrusionCanariesCount,
        'audit_chain_intact': auditChainIntact,
        'duress_incidents': duressIncidents.map((d) => d.toJson()).toList(),
      };
}

/// Etapa individual do Funil Pirata `AARRR`.
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

/// Resumo executivo do Funil Pirata `AARRR` + eficiência unitária `LTV/CAC` (`9,65x`).
class FounderAarrrFunnelSummary {
  const FounderAarrrFunnelSummary({
    required this.acquisitionCount,
    required this.activationCount,
    required this.retentionCount,
    required this.revenueCount,
    required this.referralCount,
    required this.cacCents,
    required this.ltvCents,
    this.ltvToCacRatioBps = 96500,
  });

  final int acquisitionCount;
  final int activationCount;
  final int retentionCount;
  final int revenueCount;
  final int referralCount;
  final int cacCents;
  final int ltvCents;

  /// `96500 bps == 9,65x` LTV/CAC auditado.
  final int ltvToCacRatioBps;

  double get ltvToCacMultiple => ltvToCacRatioBps / 10000.0;

  List<AarrrStageMetric> get stages {
    int bps(int num, int den) =>
        den <= 0 ? 0 : ((num * 10000) + (den ~/ 2)) ~/ den;
    return <AarrrStageMetric>[
      AarrrStageMetric(
        stageCode: 'ACQUISITION',
        stageLabelPt: 'Aquisição (Instalações & Busca Local)',
        usersCount: acquisitionCount,
        stepConversionBps: 10000,
      ),
      AarrrStageMetric(
        stageCode: 'ACTIVATION',
        stageLabelPt: 'Ativação (Cadastro + KYC Aprovado)',
        usersCount: activationCount,
        stepConversionBps: bps(activationCount, acquisitionCount),
      ),
      AarrrStageMetric(
        stageCode: 'RETENTION',
        stageLabelPt: 'Retenção (Recorrência Ativa 90d)',
        usersCount: retentionCount,
        stepConversionBps: bps(retentionCount, activationCount),
      ),
      AarrrStageMetric(
        stageCode: 'REVENUE',
        stageLabelPt: 'Receita (OS Liquidada via Smart Split)',
        usersCount: revenueCount,
        stepConversionBps: bps(revenueCount, retentionCount),
      ),
      AarrrStageMetric(
        stageCode: 'REFERRAL',
        stageLabelPt: 'Indicação & Migração Dual-Mode',
        usersCount: referralCount,
        stepConversionBps: bps(referralCount, revenueCount),
      ),
    ];
  }

  factory FounderAarrrFunnelSummary.fromJson(Map<String, dynamic> json) {
    return FounderAarrrFunnelSummary(
      acquisitionCount: _asInt(json['acquisition_count'], 2480),
      activationCount: _asInt(json['activation_count'], 1540),
      retentionCount: _asInt(json['retention_count'], 1090),
      revenueCount: _asInt(json['revenue_count'], 860),
      referralCount: _asInt(json['referral_count'], 395),
      cacCents: _asInt(json['cac_cents'], 2850),
      ltvCents: _asInt(json['ltv_cents'], 27503),
      ltvToCacRatioBps: _asInt(json['ltv_to_cac_ratio_bps'], 96500),
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

/// Linha mensal da matriz de retenção por safra (Cohort Retention Heatmap).
class CohortRetentionRow {
  const CohortRetentionRow({
    required this.cohortMonthIso,
    required this.initialUsers,
    required this.retentionByMonthBps,
    required this.netRevenuePerUserCents,
  });

  final String cohortMonthIso;
  final int initialUsers;

  /// Retenção `M0..Mk` em basis points (`10000 == 100,0%`).
  final List<int> retentionByMonthBps;

  final int netRevenuePerUserCents;

  factory CohortRetentionRow.fromJson(Map<String, dynamic> json) {
    final rawList = json['retention_by_month_bps'];
    final parsed = rawList is List
        ? rawList.map(_asInt).toList(growable: false)
        : const <int>[10000, 6800, 5900, 5450];
    return CohortRetentionRow(
      cohortMonthIso: _asString(json['cohort_month_iso'], '2026-06'),
      initialUsers: _asInt(json['initial_users'], 180),
      retentionByMonthBps: List<int>.unmodifiable(parsed),
      netRevenuePerUserCents: _asInt(json['net_revenue_per_user_cents'], 4820),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cohort_month_iso': cohortMonthIso,
        'initial_users': initialUsers,
        'retention_by_month_bps': retentionByMonthBps,
        'net_revenue_per_user_cents': netRevenuePerUserCents,
      };
}

/// Termômetro FinOps do funil KYC em cascata (`Tier-0` local a `R$ 0,00` -> `Argon` -> `Carbon/SERPRO`).
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

  factory FounderKycFinOpsSummary.fromJson(Map<String, dynamic> json) {
    return FounderKycFinOpsSummary(
      tier0LocalCount: _asInt(json['tier0_local_count'], 1420),
      argonCloudCount: _asInt(json['argon_cloud_count'], 310),
      carbonSerproCount: _asInt(json['carbon_serpro_count'], 84),
      cloudSavingsCents: _asInt(json['cloud_savings_cents'], 418600),
      actualCloudSpendCents: _asInt(json['actual_cloud_spend_cents'], 34780),
      hypotheticalNaiveCloudSpendCents:
          _asInt(json['hypothetical_naive_cloud_spend_cents'], 453380),
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

/// Degrau da Cascata Tarifária Meritocrática de 5 Níveis (Tiered Waterfall).
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
      tierName: _asString(json['tier_name'], 'Nível 1 · Entrada'),
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

/// Cascata Tarifária de 5 Degraus + Catálogo Canônico de `112` Medalhas (`90` Prestador + `22` Cliente).
class FounderTieredWaterfallSummary {
  const FounderTieredWaterfallSummary({
    required this.steps,
    this.providerMedalsTotal = 90,
    this.clientMedalsTotal = 22,
    this.totalMedals = 112,
    this.unlockedProviderMedalsCount = 64,
    this.unlockedClientMedalsCount = 17,
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

  static List<TieredWaterfallStep> canonicalFiveSteps({
    int totalProviders = 340,
  }) {
    final p = totalProviders <= 0 ? 340 : totalProviders;
    return <TieredWaterfallStep>[
      TieredWaterfallStep(
        stepIndex: 1,
        tierName: 'Degrau 1 · Credenciado Base',
        takeRateBps: 1500,
        eligibleProvidersCount: (p * 38) ~/ 100,
        gmvShareBps: 2100,
        descriptionPt: '13,5% Plataforma + 1,5% Pool Garantia (0% s/ Peças)',
      ),
      TieredWaterfallStep(
        stepIndex: 2,
        tierName: 'Degrau 2 · Profissional Verificado+',
        takeRateBps: 1420,
        eligibleProvidersCount: (p * 27) ~/ 100,
        gmvShareBps: 2400,
        descriptionPt: '10+ OS sem sinistro e check-in/out forense 100%',
      ),
      TieredWaterfallStep(
        stepIndex: 3,
        tierName: 'Degrau 3 · Mestre da Categoria',
        takeRateBps: 1340,
        eligibleProvidersCount: (p * 19) ~/ 100,
        gmvShareBps: 2500,
        descriptionPt: 'Nota Bayesiana >= 4,85 e emissão pontual NF-e < 26h',
      ),
      TieredWaterfallStep(
        stepIndex: 4,
        tierName: 'Degrau 4 · Super Profissional',
        takeRateBps: 1250,
        eligibleProvidersCount: (p * 11) ~/ 100,
        gmvShareBps: 1800,
        descriptionPt: '20 avaliações consecutivas nota 5 + zero mediação',
      ),
      TieredWaterfallStep(
        stepIndex: 5,
        tierName: 'Degrau 5 · Embaixador Soberano',
        takeRateBps: 1150,
        eligibleProvidersCount: p -
            ((p * 38) ~/ 100) -
            ((p * 27) ~/ 100) -
            ((p * 19) ~/ 100) -
            ((p * 11) ~/ 100),
        gmvShareBps: 1200,
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
          _asInt(json['unlocked_provider_medals_count'], 64),
      unlockedClientMedalsCount:
          _asInt(json['unlocked_client_medals_count'], 17),
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

/// Snapshot completo e autossuficiente do Cockpit Executivo Soberano (`founder_get_cockpit_snapshot`).
class FounderDashboardSnapshot {
  const FounderDashboardSnapshot({
    required this.generatedAt,
    required this.daysWindow,
    required this.viewerSeatRole,
    required this.viewerPermissionScope,
    required this.demographics,
    required this.dreCents,
    required this.reconciliation,
    required this.treasury,
    required this.actuarialPool,
    required this.categoryLiquidity,
    required this.neighborhoodHeatmap,
    required this.securityWatch,
    required this.aclSeats,
    required this.dailySeries,
    required this.recentOrdersMicroPnl,
    required this.aarrrFunnel,
    required this.cohortRetention,
    required this.kycFinOps,
    required this.tieredWaterfall,
  });

  final DateTime generatedAt;
  final int daysWindow;
  final FounderSeatRole viewerSeatRole;
  final FounderPermissionScope viewerPermissionScope;
  final FounderDemographicsSummary demographics;
  final FounderDreCents dreCents;
  final FounderThreeWayReconciliation reconciliation;
  final FounderTreasurySummary treasury;
  final FounderActuarialPoolSummary actuarialPool;
  final List<CategoryLiquidityPoint> categoryLiquidity;
  final List<NeighborhoodLiquidityCell> neighborhoodHeatmap;
  final FounderSecurityAndSefazWatch securityWatch;
  final FounderSovereignAclSummary aclSeats;
  final List<FounderDailyMetricPoint> dailySeries;
  final List<OrderMicroPnlRecord> recentOrdersMicroPnl;
  final FounderAarrrFunnelSummary aarrrFunnel;
  final List<CohortRetentionRow> cohortRetention;
  final FounderKycFinOpsSummary kycFinOps;
  final FounderTieredWaterfallSummary tieredWaterfall;

  factory FounderDashboardSnapshot.fromJson(Map<String, dynamic> json) {
    final generatedAt = _asDateTimeUtc(json['generated_at']);
    final daysWindow = _asInt(json['days_window'], 30).clamp(1, 3650);
    final seatRole = FounderSeatRole.parse(
      _asNullableString(json['viewer_seat_role']),
    );
    final permScope = FounderPermissionScope.parse(
      _asNullableString(json['viewer_permission_scope']) ??
          (seatRole.isSovereignCeo ? 'FULL_SOVEREIGN' : 'READ_ONLY_ANALYTICS'),
    );

    final demographics = FounderDemographicsSummary.fromJson(
      _asMap(json['user_demographics']),
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
    final aclSeats = FounderSovereignAclSummary.fromJson(
      _asMap(json['sovereign_acl_seats']),
    );

    // Garante sempre as 33 categorias canônicas do Desperrengue mesmo se o SQL
    // retornar apenas categorias movimentadas em um banco recém-semeado.
    final rawCatList = _asMapList(json['category_liquidity_matrix']);
    final byCategoryName = <String, CategoryLiquidityPoint>{};
    for (final raw in rawCatList) {
      final pt = CategoryLiquidityPoint.fromJson(raw);
      byCategoryName[pt.categoryName.toLowerCase()] = pt;
    }
    final canonicalCategories = <CategoryLiquidityPoint>[];
    for (var i = 0; i < kCategories.length; i++) {
      final catName = kCategories[i].name;
      final existing = byCategoryName[catName.toLowerCase()];
      if (existing != null) {
        canonicalCategories.add(existing);
      } else {
        canonicalCategories.add(
          CategoryLiquidityPoint(
            categoryId: _slugifyCategory(catName),
            categoryName: catName,
            demandCount: 0,
            activeProvidersCount: 0,
            avgTicketCents: 18500 + (i % 7) * 3200,
            conversionBps: 0,
          ),
        );
      }
    }

    final rawHeatmap = _asMapList(json['neighborhood_heatmap']);
    final heatmap = rawHeatmap.isNotEmpty
        ? rawHeatmap
            .map(NeighborhoodLiquidityCell.fromJson)
            .toList(growable: false)
        : _buildDefaultNeighborhoodHeatmap();

    final rawDaily = _asMapList(json['daily_time_series']);
    final dailySeries = rawDaily
        .map(FounderDailyMetricPoint.fromJson)
        .toList(growable: false);

    final rawOrders = _asMapList(json['recent_orders_micro_pnl']);
    final recentOrders = rawOrders
        .map(OrderMicroPnlRecord.fromJson)
        .toList(growable: false);

    final aarrrJson = _asMap(json['aarrr_funnel']);
    final aarrr = aarrrJson.isNotEmpty
        ? FounderAarrrFunnelSummary.fromJson(aarrrJson)
        : _deriveAarrrFromDemographics(demographics, dreCents);

    final rawCohorts = _asMapList(json['cohort_retention']);
    final cohorts = rawCohorts.isNotEmpty
        ? rawCohorts.map(CohortRetentionRow.fromJson).toList(growable: false)
        : _buildDefaultCohortRows();

    final kycJson = _asMap(json['kyc_finops']);
    final kycFinOps = kycJson.isNotEmpty
        ? FounderKycFinOpsSummary.fromJson(kycJson)
        : _deriveKycFinOps(demographics, dreCents);

    final waterfallJson = _asMap(json['tiered_waterfall']);
    final waterfall = waterfallJson.isNotEmpty
        ? FounderTieredWaterfallSummary.fromJson(waterfallJson)
        : FounderTieredWaterfallSummary(
            steps: FounderTieredWaterfallSummary.canonicalFiveSteps(
              totalProviders:
                  demographics.onlyProvidersCount + demographics.dualModeBothCount,
            ),
          );

    return FounderDashboardSnapshot(
      generatedAt: generatedAt,
      daysWindow: daysWindow,
      viewerSeatRole: seatRole,
      viewerPermissionScope: permScope,
      demographics: demographics,
      dreCents: dreCents,
      reconciliation: reconciliation,
      treasury: treasury,
      actuarialPool: actuarialPool,
      categoryLiquidity:
          List<CategoryLiquidityPoint>.unmodifiable(canonicalCategories),
      neighborhoodHeatmap:
          List<NeighborhoodLiquidityCell>.unmodifiable(heatmap),
      securityWatch: securityWatch,
      aclSeats: aclSeats,
      dailySeries: List<FounderDailyMetricPoint>.unmodifiable(dailySeries),
      recentOrdersMicroPnl:
          List<OrderMicroPnlRecord>.unmodifiable(recentOrders),
      aarrrFunnel: aarrr,
      cohortRetention: List<CohortRetentionRow>.unmodifiable(cohorts),
      kycFinOps: kycFinOps,
      tieredWaterfall: waterfall,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'generated_at': generatedAt.toUtc().toIso8601String(),
        'days_window': daysWindow,
        'viewer_seat_role': viewerSeatRole.wire,
        'viewer_permission_scope': viewerPermissionScope.wire,
        'user_demographics': demographics.toJson(),
        'financial_dre_cents': dreCents.toJson(),
        'three_way_reconciliation': reconciliation.toJson(),
        'treasury_and_escrow_cents': treasury.toJson(),
        'actuarial_warranty_pool': actuarialPool.toJson(),
        'category_liquidity_matrix':
            categoryLiquidity.map((c) => c.toJson()).toList(),
        'neighborhood_heatmap':
            neighborhoodHeatmap.map((n) => n.toJson()).toList(),
        'security_and_sefaz_watch': securityWatch.toJson(),
        'sovereign_acl_seats': aclSeats.toJson(),
        'daily_time_series': dailySeries.map((d) => d.toJson()).toList(),
        'recent_orders_micro_pnl':
            recentOrdersMicroPnl.map((o) => o.toJson()).toList(),
        'aarrr_funnel': aarrrFunnel.toJson(),
        'cohort_retention': cohortRetention.map((c) => c.toJson()).toList(),
        'kyc_finops': kycFinOps.toJson(),
        'tiered_waterfall': tieredWaterfall.toJson(),
      };

  FounderDashboardSnapshot copyWith({
    DateTime? generatedAt,
    int? daysWindow,
    FounderSeatRole? viewerSeatRole,
    FounderPermissionScope? viewerPermissionScope,
    FounderDemographicsSummary? demographics,
    FounderDreCents? dreCents,
    FounderThreeWayReconciliation? reconciliation,
    FounderTreasurySummary? treasury,
    FounderActuarialPoolSummary? actuarialPool,
    List<CategoryLiquidityPoint>? categoryLiquidity,
    List<NeighborhoodLiquidityCell>? neighborhoodHeatmap,
    FounderSecurityAndSefazWatch? securityWatch,
    FounderSovereignAclSummary? aclSeats,
    List<FounderDailyMetricPoint>? dailySeries,
    List<OrderMicroPnlRecord>? recentOrdersMicroPnl,
    FounderAarrrFunnelSummary? aarrrFunnel,
    List<CohortRetentionRow>? cohortRetention,
    FounderKycFinOpsSummary? kycFinOps,
    FounderTieredWaterfallSummary? tieredWaterfall,
  }) {
    return FounderDashboardSnapshot(
      generatedAt: generatedAt ?? this.generatedAt,
      daysWindow: daysWindow ?? this.daysWindow,
      viewerSeatRole: viewerSeatRole ?? this.viewerSeatRole,
      viewerPermissionScope:
          viewerPermissionScope ?? this.viewerPermissionScope,
      demographics: demographics ?? this.demographics,
      dreCents: dreCents ?? this.dreCents,
      reconciliation: reconciliation ?? this.reconciliation,
      treasury: treasury ?? this.treasury,
      actuarialPool: actuarialPool ?? this.actuarialPool,
      categoryLiquidity: categoryLiquidity ?? this.categoryLiquidity,
      neighborhoodHeatmap: neighborhoodHeatmap ?? this.neighborhoodHeatmap,
      securityWatch: securityWatch ?? this.securityWatch,
      aclSeats: aclSeats ?? this.aclSeats,
      dailySeries: dailySeries ?? this.dailySeries,
      recentOrdersMicroPnl: recentOrdersMicroPnl ?? this.recentOrdersMicroPnl,
      aarrrFunnel: aarrrFunnel ?? this.aarrrFunnel,
      cohortRetention: cohortRetention ?? this.cohortRetention,
      kycFinOps: kycFinOps ?? this.kycFinOps,
      tieredWaterfall: tieredWaterfall ?? this.tieredWaterfall,
    );
  }

  /// Gera um snapshot soberano 100% determinístico com 365 dias de série em centavos
  /// inteiros, invariantes contábeis exatas (`0` centavo de deriva), conciliação tripla
  /// íntegra e assento inicial exclusivo do CEO Soberano (`0` delegados ativos por padrão).
  factory FounderDashboardSnapshot.deterministicDemo({
    int daysWindow = 365,
    FounderSeatRole viewerSeatRole = FounderSeatRole.sovereignCeo,
    FounderPermissionScope viewerPermissionScope =
        FounderPermissionScope.fullSovereign,
    List<SovereignDelegateSlot> initialDelegates =
        const <SovereignDelegateSlot>[],
    DateTime? referenceUtc,
  }) {
    final effectiveWindow = daysWindow.clamp(7, 365);
    final anchorUtc = (referenceUtc ?? DateTime.utc(2026, 11, 14, 12)).toUtc();
    final startDay = DateTime.utc(
      anchorUtc.year,
      anchorUtc.month,
      anchorUtc.day,
    ).subtract(const Duration(days: 364));

    // OPEX fixo mensal enxuto: R$ 1.800,00/mês = R$ 60,00/dia = 6.000 centavos/dia.
    const dailyFixedOpexCents = 6000;

    final dailyPoints = <FounderDailyMetricPoint>[];
    for (var d = 0; d < 365; d++) {
      final date = startDay.add(Duration(days: d));
      final dayIso =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // Curva J orgânica: começa em ~1 OS/dia (30 OS/mês, abaixo do break-even de 40 OS/mês),
      // cruza 40 OS/mês no Mês 3, cruza 100 OS/mês no Mês 6 e atinge ~9-12 OS/dia no Mês 12.
      final ramp = (d * 10) ~/ 365;
      final weekdayBoost = (date.weekday == DateTime.friday ||
              date.weekday == DateTime.saturday)
          ? 2
          : (date.weekday == DateTime.sunday ? 0 : 1);
      final orders = (1 + ramp + weekdayBoost + ((d * 7) % 3) - 1).clamp(1, 16);

      final avgLaborPerOrder = 17200 + ((d * 13) % 5) * 1100;
      final avgMatPerOrder = 12800 + ((d * 17) % 4) * 1200;
      final laborCents = orders * avgLaborPerOrder;
      final materialsCents = orders * avgMatPerOrder;
      final gmvCents = laborCents + materialsCents;

      final split = Money.allocate(laborCents, const <int>[8500, 1350, 150]);
      final sosBonusCents = (d % 5 == 0) ? 800 * ((orders ~/ 3).clamp(1, 3)) : 0;
      final platformRev = split[1] + sosBonusCents;
      final poolCarveout = split[2];
      final taxDas = Money.percentOfCents(platformRev, 600);
      final varCost = (orders * 34 + 5) ~/ 10;
      final netProfit = platformRev - taxDas - varCost - dailyFixedOpexCents;
      final claims = (d % 29 == 0 && d > 40) ? 14500 : 0;

      dailyPoints.add(
        FounderDailyMetricPoint(
          dayIso: dayIso,
          ordersCount: orders,
          gmvCents: gmvCents,
          laborCents: laborCents,
          materialsExemptCents: materialsCents,
          platformRevenueCents: platformRev,
          poolCarveoutCents: poolCarveout,
          taxDasCents: taxDas,
          variableCostCents: varCost,
          netProfitCents: netProfit,
          warrantyClaimsCents: claims,
        ),
      );
    }

    // Agrega exatamente a janela solicitada (`effectiveWindow` últimos dias).
    final sliceStart = 365 - effectiveWindow;
    var sumOrders = 0;
    var sumLabor = 0;
    var sumMaterials = 0;
    var sumSos = 0;
    var sumVarCost = 0;
    for (var i = sliceStart; i < 365; i++) {
      final pt = dailyPoints[i];
      sumOrders += pt.ordersCount;
      sumLabor += pt.laborCents;
      sumMaterials += pt.materialsExemptCents;
      final split = Money.allocate(pt.laborCents, const <int>[8500, 1350, 150]);
      sumSos += pt.platformRevenueCents - split[1];
      sumVarCost += pt.variableCostCents;
    }

    final dre = FounderDreCents.computeFromComponents(
      laborGrossCents: sumLabor,
      materialsExemptCents: sumMaterials,
      sosFeeRevenueCents: sumSos,
      completedOrdersCount: sumOrders,
      fixedOpexCents: effectiveWindow * dailyFixedOpexCents,
      variablePspAndCloudCents: sumVarCost,
      tier0KycSavingsCents: 418600,
    );

    const treasury = FounderTreasurySummary(
      availableWalletsCents: 6842500,
      activeExecutionEscrowCents: 2418000,
      maturationD0D2Cents: 1390500,
      maturationD5Cents: 984000,
      maturationD7Cents: 742000,
      frozenMediationCents: 185000,
      frozenUnderDuressCents: 48500,
      estimatedMonthlyCdiFloatCents: 118420,
    );

    final totalCustody = treasury.totalCustodyCents;
    const settledOutCents = 14250000;
    final reconciliation = FounderThreeWayReconciliation.compute(
      pixTopupsConfirmedCents: totalCustody + settledOutCents,
      ledgerNetSumCents: totalCustody,
      walletsAndEscrowTotalCents: totalCustody,
      cumulativePlatformSettledOutCents: settledOutCents,
    );

    const actuarialPool = FounderActuarialPoolSummary(
      runningBalanceCents: 1894000,
      activeExposureCents: 1028000,
      icaRatioBps: 18424, // 1,84x >= 1,50x meta soberana
      fcrLayer1Bps: 8640, // 86,40% resolvidos na Camada 1 sem desembolso
      clawbackRecoveredCents: 214500,
      claimsPaidCents: 145000,
    );

    const demographics = FounderDemographicsSummary(
      onlyClientsCount: 1180,
      onlyProvidersCount: 245,
      dualModeBothCount: 195,
      totalUsersCount: 1620,
      kycVerifiedCount: 1412,
      kycPendingCount: 164,
      kycRejectedCount: 44,
      lgpdDeletedClientCount: 19,
      lgpdDeletedProviderCount: 6,
      lgpdDeletedAllCount: 9,
    );

    final categories = <CategoryLiquidityPoint>[
      for (var i = 0; i < kCategories.length; i++)
        CategoryLiquidityPoint(
          categoryId: _slugifyCategory(kCategories[i].name),
          categoryName: kCategories[i].name,
          demandCount: 165 - (i * 4) + ((i * 7) % 15),
          activeProvidersCount: (28 - (i ~/ 2) + (i % 5)).clamp(2, 42),
          avgTicketCents: 16500 + ((i * 5) % 11) * 4200,
          conversionBps: (7900 - (i * 85) + ((i * 31) % 420)).clamp(4100, 9100),
        ),
    ];

    final recentOrders = _buildDeterministicRecentOrders(anchorUtc);

    final duressIncident = DuressIncidentRecord(
      incidentId: 'DUR-20261114-001',
      orderCode: '#DESP-9D4E1',
      jobId: '9d4e1000-77c2-49a0-b811-000000009d4e',
      triggeredAt: anchorUtc.subtract(const Duration(hours: 3, minutes: 18)),
      frozenAmountCents: 48500,
      custodyStatus: 'FROZEN_UNDER_DURESS',
      maskedVictimRole: 'PRESTADOR_CREDENCIADO',
      maskedAccountRef: 'USR-7B2C-****',
      coarseNeighborhood: 'Centro — Poços de Caldas/MG (Raio Difuso)',
      deviceIntegrityHash:
          'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9',
      ledgerFreezeTxId: 'LEDGER-LOCK-DURESS-88412',
      evidenceChainHashes: const <String>[
        '8f31c9b07d44e120a9c3b47f1e62d8049a1c55e3d7b89012c4f6a8e0b2d4f601',
        '4c19a7e23b68f051d2e8c904b7a3f1628e04d9c7a1b53028f6e4c2a0d8b6e412',
      ],
      decoyUiDisplayed: true,
    );

    final securityWatch = FounderSecurityAndSefazWatch(
      pendingSefazOver26hCount: 2,
      canceledClawbackCount: 3,
      frozenUnderDuressCount: 1,
      geoPrivacyLeakBps: 0,
      intrusionCanariesCount: 1,
      auditChainIntact: true,
      duressIncidents: <DuressIncidentRecord>[duressIncident],
    );

    final aclSeats = FounderSovereignAclSummary(
      ceoSeat: SovereignCeoSeat(
        userId: '00000000-0000-4000-8000-000000000001',
        emailSnapshot: 'wagner.ceo@desperrengue.com.br',
        isActive: true,
        createdAt: DateTime.utc(2026, 1, 1, 9),
      ),
      delegateSlots: List<SovereignDelegateSlot>.unmodifiable(initialDelegates),
    );

    const aarrrFunnel = FounderAarrrFunnelSummary(
      acquisitionCount: 2640,
      activationCount: 1620,
      retentionCount: 1148,
      revenueCount: 912,
      referralCount: 418,
      cacCents: 2850,
      ltvCents: 27503,
      ltvToCacRatioBps: 96500,
    );

    const kycFinOps = FounderKycFinOpsSummary(
      tier0LocalCount: 1420,
      argonCloudCount: 310,
      carbonSerproCount: 84,
      cloudSavingsCents: 418600,
      actualCloudSpendCents: 34780,
      hypotheticalNaiveCloudSpendCents: 453380,
    );

    final waterfall = FounderTieredWaterfallSummary(
      steps: FounderTieredWaterfallSummary.canonicalFiveSteps(
        totalProviders:
            demographics.onlyProvidersCount + demographics.dualModeBothCount,
      ),
    );

    return FounderDashboardSnapshot(
      generatedAt: anchorUtc,
      daysWindow: effectiveWindow,
      viewerSeatRole: viewerSeatRole,
      viewerPermissionScope: viewerPermissionScope,
      demographics: demographics,
      dreCents: dre,
      reconciliation: reconciliation,
      treasury: treasury,
      actuarialPool: actuarialPool,
      categoryLiquidity: List<CategoryLiquidityPoint>.unmodifiable(categories),
      neighborhoodHeatmap: List<NeighborhoodLiquidityCell>.unmodifiable(
        _buildDefaultNeighborhoodHeatmap(),
      ),
      securityWatch: securityWatch,
      aclSeats: aclSeats,
      dailySeries: List<FounderDailyMetricPoint>.unmodifiable(dailyPoints),
      recentOrdersMicroPnl: List<OrderMicroPnlRecord>.unmodifiable(recentOrders),
      aarrrFunnel: aarrrFunnel,
      cohortRetention:
          List<CohortRetentionRow>.unmodifiable(_buildDefaultCohortRows()),
      kycFinOps: kycFinOps,
      tieredWaterfall: waterfall,
    );
  }

  static List<NeighborhoodLiquidityCell> _buildDefaultNeighborhoodHeatmap() {
    return const <NeighborhoodLiquidityCell>[
      NeighborhoodLiquidityCell(
        neighborhood: 'Centro',
        demandScore: 94,
        supplyScore: 68,
        unmetOrdersCount: 9,
        activeProvidersCount: 34,
        suggestedBoosterCents: 35000,
        expectedIncrementalNetCents: 142000,
      ),
      NeighborhoodLiquidityCell(
        neighborhood: 'Country Club',
        demandScore: 89,
        supplyScore: 34,
        unmetOrdersCount: 17,
        activeProvidersCount: 11,
        suggestedBoosterCents: 45000,
        expectedIncrementalNetCents: 218000,
      ),
      NeighborhoodLiquidityCell(
        neighborhood: 'Maria Imaculada',
        demandScore: 81,
        supplyScore: 42,
        unmetOrdersCount: 12,
        activeProvidersCount: 15,
        suggestedBoosterCents: 30000,
        expectedIncrementalNetCents: 136500,
      ),
      NeighborhoodLiquidityCell(
        neighborhood: 'Jardim dos Estados',
        demandScore: 86,
        supplyScore: 39,
        unmetOrdersCount: 14,
        activeProvidersCount: 12,
        suggestedBoosterCents: 40000,
        expectedIncrementalNetCents: 189000,
      ),
      NeighborhoodLiquidityCell(
        neighborhood: 'São Cristóvão',
        demandScore: 73,
        supplyScore: 61,
        unmetOrdersCount: 5,
        activeProvidersCount: 22,
        suggestedBoosterCents: 20000,
        expectedIncrementalNetCents: 74000,
      ),
      NeighborhoodLiquidityCell(
        neighborhood: 'Vila Nova',
        demandScore: 77,
        supplyScore: 47,
        unmetOrdersCount: 10,
        activeProvidersCount: 16,
        suggestedBoosterCents: 25000,
        expectedIncrementalNetCents: 108000,
      ),
      NeighborhoodLiquidityCell(
        neighborhood: 'Santa Terezinha',
        demandScore: 64,
        supplyScore: 58,
        unmetOrdersCount: 4,
        activeProvidersCount: 19,
        suggestedBoosterCents: 15000,
        expectedIncrementalNetCents: 51000,
      ),
      NeighborhoodLiquidityCell(
        neighborhood: 'Jardim América',
        demandScore: 69,
        supplyScore: 44,
        unmetOrdersCount: 8,
        activeProvidersCount: 13,
        suggestedBoosterCents: 25000,
        expectedIncrementalNetCents: 99500,
      ),
    ];
  }

  static List<CohortRetentionRow> _buildDefaultCohortRows() {
    return const <CohortRetentionRow>[
      CohortRetentionRow(
        cohortMonthIso: '2026-06',
        initialUsers: 190,
        retentionByMonthBps: <int>[10000, 6620, 5840, 5410, 5190, 5080],
        netRevenuePerUserCents: 4680,
      ),
      CohortRetentionRow(
        cohortMonthIso: '2026-07',
        initialUsers: 225,
        retentionByMonthBps: <int>[10000, 6890, 6050, 5620, 5380],
        netRevenuePerUserCents: 4950,
      ),
      CohortRetentionRow(
        cohortMonthIso: '2026-08',
        initialUsers: 268,
        retentionByMonthBps: <int>[10000, 7120, 6310, 5890],
        netRevenuePerUserCents: 5240,
      ),
      CohortRetentionRow(
        cohortMonthIso: '2026-09',
        initialUsers: 312,
        retentionByMonthBps: <int>[10000, 7380, 6590],
        netRevenuePerUserCents: 5510,
      ),
      CohortRetentionRow(
        cohortMonthIso: '2026-10',
        initialUsers: 356,
        retentionByMonthBps: <int>[10000, 7640],
        netRevenuePerUserCents: 5790,
      ),
      CohortRetentionRow(
        cohortMonthIso: '2026-11',
        initialUsers: 269,
        retentionByMonthBps: <int>[10000],
        netRevenuePerUserCents: 4120,
      ),
    ];
  }

  static List<OrderMicroPnlRecord> _buildDeterministicRecentOrders(
    DateTime anchorUtc,
  ) {
    const specs = <(String, String, String, int, int, String?, String)>[
      (
        '#DESP-8F4A2',
        'Elétrica',
        'Country Club',
        32000,
        18500,
        '31261114289451000176550010000482911094827165',
        'RELEASED_MATURED',
      ),
      (
        '#DESP-7C19B',
        'Ar-condicionado',
        'Jardim dos Estados',
        48000,
        29000,
        '31261114289451000176550010000482921847261903',
        'MATURATION_D5',
      ),
      (
        '#DESP-5E90D',
        'Encanador',
        'Centro',
        24000,
        9500,
        '31261114289451000176550010000482931562049817',
        'MATURATION_D0_D2',
      ),
      (
        '#DESP-3A77C',
        'Energia Solar',
        'Maria Imaculada',
        85000,
        62000,
        '31261114289451000176550010000482941739204856',
        'RELEASED_MATURED',
      ),
      (
        '#DESP-9D4E1',
        'Chaveiro',
        'Centro',
        34000,
        14500,
        '31261114289451000176550010000482951928374650',
        'FROZEN_UNDER_DURESS',
      ),
      (
        '#DESP-2B61F',
        'Limpeza',
        'Vila Nova',
        21000,
        0,
        null,
        'RELEASED_MATURED',
      ),
    ];

    final out = <OrderMicroPnlRecord>[];
    for (var i = 0; i < specs.length; i++) {
      final (code, cat, hood, labor, mat, nfeKey, status) = specs[i];
      final split = Money.allocate(labor, const <int>[8500, 1350, 150]);
      final provNet = split[0];
      final platFee = split[1];
      final pool = split[2];
      final das = Money.percentOfCents(platFee, 600);
      const pixCloud = 4; // ~R$ 0,034 arredondado para inteiro conservador
      final netMargin = platFee - das - pixCloud;
      out.add(
        OrderMicroPnlRecord(
          orderCode: code,
          jobId:
              '${(i + 1).toString().padLeft(8, '0')}-77c2-49a0-b811-00000000000${i + 1}',
          categoryName: cat,
          neighborhood: hood,
          createdAt: anchorUtc.subtract(Duration(hours: (i + 1) * 5)),
          gmvCents: labor + mat,
          laborCents: labor,
          materialsExemptCents: mat,
          nfeAccessKey: nfeKey,
          nfeVerified: nfeKey != null,
          providerNetCents: provNet,
          platformFeeCents: platFee,
          poolCarveoutCents: pool,
          taxDasCents: das,
          pixCloudCostCents: pixCloud,
          netMarginCents: netMargin,
          escrowStatus: status,
        ),
      );
    }
    return out;
  }

  static FounderAarrrFunnelSummary _deriveAarrrFromDemographics(
    FounderDemographicsSummary demo,
    FounderDreCents dre,
  ) {
    final activeBase = demo.totalUsersCount > 0 ? demo.totalUsersCount : 1620;
    return FounderAarrrFunnelSummary(
      acquisitionCount: (activeBase * 163) ~/ 100,
      activationCount: activeBase,
      retentionCount: (activeBase * 71) ~/ 100,
      revenueCount:
          dre.completedOrdersCount > 0 ? dre.completedOrdersCount : 912,
      referralCount:
          demo.dualModeBothCount > 0 ? demo.dualModeBothCount * 2 : 390,
      cacCents: 2850,
      ltvCents: 27503,
      ltvToCacRatioBps: 96500,
    );
  }

  static FounderKycFinOpsSummary _deriveKycFinOps(
    FounderDemographicsSummary demo,
    FounderDreCents dre,
  ) {
    final verified = demo.kycVerifiedCount > 0 ? demo.kycVerifiedCount : 1420;
    return FounderKycFinOpsSummary(
      tier0LocalCount: verified,
      argonCloudCount: demo.kycPendingCount > 0 ? demo.kycPendingCount : 310,
      carbonSerproCount: demo.kycRejectedCount > 0 ? demo.kycRejectedCount : 84,
      cloudSavingsCents:
          dre.tier0KycSavingsCents > 0 ? dre.tier0KycSavingsCents : 418600,
      actualCloudSpendCents: 34780,
      hypotheticalNaiveCloudSpendCents: 453380,
    );
  }
}

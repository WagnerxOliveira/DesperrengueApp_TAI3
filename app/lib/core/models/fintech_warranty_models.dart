import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../utils/money.dart';

/// Camada de Segurança da Informação (AppSec), Sanitização e Conformidade LGPD.
class SecurityAndLgpdGuard {
  const SecurityAndLgpdGuard._();

  /// Arredondamento financeiro seguro de 2 casas decimais (half-to-even / centavos exatos).
  static double roundCurrency(double value) {
    if (value.isNaN || value.isInfinite) {
      throw ArgumentError('Valor financeiro inválido (NaN ou Infinito).');
    }
    return Money.fromCents(Money.toCents(value));
  }

  /// Valida um valor monetário impedindo negativos, NaN ou Infinity.
  static double validateAmount(double amount, {String fieldName = 'amount'}) {
    if (amount.isNaN || amount.isInfinite) {
      throw ArgumentError('Campo $fieldName contém valor não numérico (NaN/Infinity).');
    }
    if (amount < 0) {
      throw ArgumentError('Campo $fieldName não pode ser negativo: $amount.');
    }
    return roundCurrency(amount);
  }

  /// Valida as alíquotas do Split Inteligente contra adulteração (Anti-Tampering).
  static void validateSplitRates({
    required double totalPlatformTakeRate,
    required double operationalTakeRate,
    required double warrantyReserveTakeRate,
  }) {
    if (totalPlatformTakeRate.isNaN ||
        operationalTakeRate.isNaN ||
        warrantyReserveTakeRate.isNaN ||
        totalPlatformTakeRate.isInfinite ||
        operationalTakeRate.isInfinite ||
        warrantyReserveTakeRate.isInfinite) {
      throw ArgumentError('Alíquotas de split inválidas (NaN/Infinity).');
    }
    if (totalPlatformTakeRate < 0.0 ||
        totalPlatformTakeRate > 0.30 ||
        operationalTakeRate < 0.0 ||
        warrantyReserveTakeRate < 0.0) {
      throw ArgumentError('Alíquotas de split fora dos limites de segurança permitidos.');
    }
    final sum = operationalTakeRate + warrantyReserveTakeRate;
    if ((totalPlatformTakeRate - sum).abs() > 1e-6) {
      throw ArgumentError(
        'Inconsistência nas alíquotas de split: total ($totalPlatformTakeRate) != operacional ($operationalTakeRate) + reserva ($warrantyReserveTakeRate).',
      );
    }
  }

  /// Mascara CPF (`***.456.789-**`) ou CNPJ (`**.345.678/0001-**`) conforme LGPD.
  static String maskCpfOrCnpj(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11) {
      return '***.${digits.substring(3, 6)}.${digits.substring(6, 9)}-**';
    }
    if (digits.length == 14) {
      return '**.${digits.substring(2, 5)}.${digits.substring(5, 8)}/${digits.substring(8, 12)}-**';
    }
    if (digits.length >= 4) {
      return '***.${digits.substring(digits.length - 4)}-**';
    }
    return '***.***.***-**';
  }

  /// Mascara telefone (`(**) *****-1234`) conforme LGPD.
  static String maskPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 4) {
      final last4 = digits.substring(digits.length - 4);
      return '(**) *****-$last4';
    }
    return '(**) *****-****';
  }

  /// Minimiza o nome do titular/cliente para certificados e logs (ex: `"Wagner Oliveira"` -> `"Wagner O."`).
  static String maskClientName(String fullName) {
    final clean = sanitizeInput(fullName);
    if (clean.isEmpty) return 'Titular Protegido (LGPD)';
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first;
    final first = parts.first;
    final lastInitial = parts.last.substring(0, 1).toUpperCase();
    return '$first $lastInitial.';
  }

  /// Limpa caracteres de controle, tags HTML/scripts e payloads maliciosos.
  static String sanitizeInput(String raw, {int maxLength = 500}) {
    var s = raw;
    // Remove blocos <script>...</script>
    s = s.replaceAll(RegExp(r'<\s*script[^>]*>[\s\S]*?<\s*/\s*script\s*>', caseSensitive: false), '');
    // Remove tags HTML genéricas
    s = s.replaceAll(RegExp(r'<[^>]*>'), '');
    // Remove vetores inline de JS/SQL comuns
    s = s.replaceAll(RegExp(r'(javascript\s*:|onerror\s*=|onload\s*=|onclick\s*=)', caseSensitive: false), '');
    // Remove caracteres de controle ASCII exceto espaço comum
    s = s.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), ' ');
    // Remove colchetes angulares remanescentes
    s = s.replaceAll('<', '').replaceAll('>', '');
    // Normaliza espaços múltiplos
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.length > maxLength) {
      s = s.substring(0, maxLength).trim();
    }
    return s;
  }

  /// Gera uma assinatura de integridade forense determinística para impedir adulteração
  /// de fotos de Check-in/Check-out, geolocalização e recibos fiscais.
  static String generateForensicHash({
    required String orderId,
    required String stage,
    required String timestampIso8601,
    double? latitude,
    double? longitude,
    double amount = 0.0,
  }) {
    final latFixed = latitude != null ? latitude.toStringAsFixed(6) : 'no_lat';
    final lngFixed = longitude != null ? longitude.toStringAsFixed(6) : 'no_lng';
    final amtFixed = roundCurrency(amount.isNaN || amount.isInfinite || amount < 0 ? 0.0 : amount)
        .toStringAsFixed(2);
    final canonical = 'DSP|v1|${orderId.trim()}|${stage.trim()}|${timestampIso8601.trim()}|$latFixed|$lngFixed|$amtFixed';
    final bytes = utf8.encode(canonical);

    // 4 lanes de 32-bit FNV-1a compatíveis com VM 64-bit e JavaScript (dart2js / Web 53-bit safe).
    var h1 = 0x811C9DC5;
    var h2 = 0x1B873593;
    var h3 = 0x85EBCA6B;
    var h4 = 0xC2B2AE35;
    for (var i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      h1 = ((h1 ^ b) * 0x01000193) & 0x7FFFFFFF;
      h2 = ((h2 ^ ((b + i * 17) & 0xFF)) * 0x01000193) & 0x7FFFFFFF;
      h3 = ((h3 ^ ((b + i * 31) & 0xFF)) * 0x01000193) & 0x7FFFFFFF;
      h4 = ((h4 ^ ((b + i * 47) & 0xFF)) * 0x01000193) & 0x7FFFFFFF;
    }
    final hex1 = h1.toRadixString(16).padLeft(8, '0').toUpperCase();
    final hex2 = h2.toRadixString(16).padLeft(8, '0').toUpperCase();
    final hex3 = h3.toRadixString(16).padLeft(8, '0').toUpperCase();
    final hex4 = h4.toRadixString(16).padLeft(8, '0').toUpperCase();
    return 'DSP-FSH-$hex1$hex2$hex3$hex4';
  }
}

/// Etapa da evidência fotográfica forense.
enum ForensicStage {
  beforeCheckIn,
  afterCheckOut,
  materialFiscalReceipt,
}

extension ForensicStageX on ForensicStage {
  String get code => switch (this) {
        ForensicStage.beforeCheckIn => 'before_check_in',
        ForensicStage.afterCheckOut => 'after_check_out',
        ForensicStage.materialFiscalReceipt => 'material_fiscal_receipt',
      };

  String get label => switch (this) {
        ForensicStage.beforeCheckIn => 'Check-in (Antes)',
        ForensicStage.afterCheckOut => 'Check-out (Depois)',
        ForensicStage.materialFiscalReceipt => 'Cupom Fiscal (Peças)',
      };

  static ForensicStage fromCode(String? raw) => switch (raw) {
        'before_check_in' || 'beforeCheckIn' => ForensicStage.beforeCheckIn,
        'after_check_out' || 'afterCheckOut' => ForensicStage.afterCheckOut,
        'material_fiscal_receipt' || 'materialFiscalReceipt' => ForensicStage.materialFiscalReceipt,
        _ => ForensicStage.beforeCheckIn,
      };
}

/// Evidência Visual Forense com carimbo de tempo, GPS e hash de integridade.
@immutable
class ForensicPhotoEvidence {
  const ForensicPhotoEvidence({
    required this.id,
    required this.imagePathOrUrl,
    required this.stage,
    required this.capturedAt,
    this.latitude,
    this.longitude,
    required this.isGpsVerifiedAtAddress,
    required this.captionOrTechnicalNote,
    required this.integrityHash,
  });

  factory ForensicPhotoEvidence.verified({
    required String id,
    required String orderId,
    required String imagePathOrUrl,
    required ForensicStage stage,
    required DateTime capturedAt,
    double? latitude,
    double? longitude,
    bool isGpsVerifiedAtAddress = true,
    String captionOrTechnicalNote = '',
    double amount = 0.0,
  }) {
    final sanitizedNote = SecurityAndLgpdGuard.sanitizeInput(captionOrTechnicalNote);
    final hash = SecurityAndLgpdGuard.generateForensicHash(
      orderId: orderId,
      stage: stage.code,
      timestampIso8601: capturedAt.toUtc().toIso8601String(),
      latitude: latitude,
      longitude: longitude,
      amount: amount,
    );
    return ForensicPhotoEvidence(
      id: id,
      imagePathOrUrl: imagePathOrUrl.trim(),
      stage: stage,
      capturedAt: capturedAt,
      latitude: latitude,
      longitude: longitude,
      isGpsVerifiedAtAddress: isGpsVerifiedAtAddress,
      captionOrTechnicalNote: sanitizedNote,
      integrityHash: hash,
    );
  }

  final String id;
  final String imagePathOrUrl;
  final ForensicStage stage;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
  final bool isGpsVerifiedAtAddress;
  final String captionOrTechnicalNote;
  final String integrityHash;

  ForensicPhotoEvidence copyWith({
    String? id,
    String? imagePathOrUrl,
    ForensicStage? stage,
    DateTime? capturedAt,
    double? latitude,
    double? longitude,
    bool? isGpsVerifiedAtAddress,
    String? captionOrTechnicalNote,
    String? integrityHash,
  }) {
    return ForensicPhotoEvidence(
      id: id ?? this.id,
      imagePathOrUrl: imagePathOrUrl ?? this.imagePathOrUrl,
      stage: stage ?? this.stage,
      capturedAt: capturedAt ?? this.capturedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isGpsVerifiedAtAddress: isGpsVerifiedAtAddress ?? this.isGpsVerifiedAtAddress,
      captionOrTechnicalNote: captionOrTechnicalNote != null
          ? SecurityAndLgpdGuard.sanitizeInput(captionOrTechnicalNote)
          : this.captionOrTechnicalNote,
      integrityHash: integrityHash ?? this.integrityHash,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'imagePathOrUrl': imagePathOrUrl,
        'stage': stage.code,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'isGpsVerifiedAtAddress': isGpsVerifiedAtAddress,
        'captionOrTechnicalNote': captionOrTechnicalNote,
        'integrityHash': integrityHash,
      };

  factory ForensicPhotoEvidence.fromMap(Map<String, dynamic> map) {
    return ForensicPhotoEvidence(
      id: (map['id'] as String?) ?? '',
      imagePathOrUrl: (map['imagePathOrUrl'] as String?) ?? '',
      stage: ForensicStageX.fromCode(map['stage'] as String?),
      capturedAt: DateTime.tryParse((map['capturedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      isGpsVerifiedAtAddress: (map['isGpsVerifiedAtAddress'] as bool?) ?? false,
      captionOrTechnicalNote: SecurityAndLgpdGuard.sanitizeInput(
        (map['captionOrTechnicalNote'] as String?) ?? '',
      ),
      integrityHash: (map['integrityHash'] as String?) ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ForensicPhotoEvidence.fromJson(String source) =>
      ForensicPhotoEvidence.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForensicPhotoEvidence &&
          other.id == id &&
          other.imagePathOrUrl == imagePathOrUrl &&
          other.stage == stage &&
          other.capturedAt.millisecondsSinceEpoch == capturedAt.millisecondsSinceEpoch &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.isGpsVerifiedAtAddress == isGpsVerifiedAtAddress &&
          other.captionOrTechnicalNote == captionOrTechnicalNote &&
          other.integrityHash == integrityHash;

  @override
  int get hashCode => Object.hash(
        id,
        imagePathOrUrl,
        stage,
        capturedAt.millisecondsSinceEpoch,
        latitude,
        longitude,
        isGpsVerifiedAtAddress,
        captionOrTechnicalNote,
        integrityHash,
      );
}

/// Item de Reembolso de Material com Cupom Fiscal (Carteira B — 0% de taxa da plataforma).
@immutable
class MaterialReimbursementTicket {
  const MaterialReimbursementTicket({
    required this.id,
    required this.materialDescription,
    required this.storeName,
    required this.fiscalReceiptNumber,
    required this.receiptTotalAmount,
    this.receiptPhoto,
    this.isApprovedByClient = false,
  }) : assert(receiptTotalAmount >= 0, 'receiptTotalAmount deve ser >= 0');

  factory MaterialReimbursementTicket.validated({
    required String id,
    required String materialDescription,
    required String storeName,
    required String fiscalReceiptNumber,
    required double receiptTotalAmount,
    ForensicPhotoEvidence? receiptPhoto,
    bool isApprovedByClient = false,
  }) {
    final safeAmount = SecurityAndLgpdGuard.validateAmount(
      receiptTotalAmount,
      fieldName: 'receiptTotalAmount',
    );
    return MaterialReimbursementTicket(
      id: id.trim(),
      materialDescription: SecurityAndLgpdGuard.sanitizeInput(materialDescription),
      storeName: SecurityAndLgpdGuard.sanitizeInput(storeName),
      fiscalReceiptNumber: SecurityAndLgpdGuard.sanitizeInput(fiscalReceiptNumber),
      receiptTotalAmount: safeAmount,
      receiptPhoto: receiptPhoto,
      isApprovedByClient: isApprovedByClient,
    );
  }

  final String id;
  final String materialDescription;
  final String storeName;
  final String fiscalReceiptNumber;
  final double receiptTotalAmount;
  final ForensicPhotoEvidence? receiptPhoto;
  final bool isApprovedByClient;

  MaterialReimbursementTicket copyWith({
    String? id,
    String? materialDescription,
    String? storeName,
    String? fiscalReceiptNumber,
    double? receiptTotalAmount,
    ForensicPhotoEvidence? receiptPhoto,
    bool? isApprovedByClient,
  }) {
    return MaterialReimbursementTicket.validated(
      id: id ?? this.id,
      materialDescription: materialDescription ?? this.materialDescription,
      storeName: storeName ?? this.storeName,
      fiscalReceiptNumber: fiscalReceiptNumber ?? this.fiscalReceiptNumber,
      receiptTotalAmount: receiptTotalAmount ?? this.receiptTotalAmount,
      receiptPhoto: receiptPhoto ?? this.receiptPhoto,
      isApprovedByClient: isApprovedByClient ?? this.isApprovedByClient,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'materialDescription': materialDescription,
        'storeName': storeName,
        'fiscalReceiptNumber': fiscalReceiptNumber,
        'receiptTotalAmount': receiptTotalAmount,
        'receiptPhoto': receiptPhoto?.toMap(),
        'isApprovedByClient': isApprovedByClient,
      };

  factory MaterialReimbursementTicket.fromMap(Map<String, dynamic> map) {
    return MaterialReimbursementTicket.validated(
      id: (map['id'] as String?) ?? '',
      materialDescription: (map['materialDescription'] as String?) ?? '',
      storeName: (map['storeName'] as String?) ?? '',
      fiscalReceiptNumber: (map['fiscalReceiptNumber'] as String?) ?? '',
      receiptTotalAmount: (map['receiptTotalAmount'] as num?)?.toDouble() ?? 0.0,
      receiptPhoto: map['receiptPhoto'] is Map<String, dynamic>
          ? ForensicPhotoEvidence.fromMap(map['receiptPhoto'] as Map<String, dynamic>)
          : null,
      isApprovedByClient: (map['isApprovedByClient'] as bool?) ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MaterialReimbursementTicket.fromJson(String source) =>
      MaterialReimbursementTicket.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialReimbursementTicket &&
          other.id == id &&
          other.materialDescription == materialDescription &&
          other.storeName == storeName &&
          other.fiscalReceiptNumber == fiscalReceiptNumber &&
          other.receiptTotalAmount == receiptTotalAmount &&
          other.receiptPhoto == receiptPhoto &&
          other.isApprovedByClient == isApprovedByClient;

  @override
  int get hashCode => Object.hash(
        id,
        materialDescription,
        storeName,
        fiscalReceiptNumber,
        receiptTotalAmount,
        receiptPhoto,
        isApprovedByClient,
      );
}

/// Motor Matemático de Split Inteligente (Carteira A: Mão de Obra vs Carteira B: Peças 0%).
@immutable
class SmartSplitBreakdown {
  const SmartSplitBreakdown({
    required this.serviceLaborAmount,
    required this.materialReimbursementAmount,
    this.totalPlatformTakeRate = 0.15,
    this.operationalTakeRate = 0.135,
    this.warrantyReserveTakeRate = 0.015,
  })  : assert(serviceLaborAmount >= 0, 'serviceLaborAmount deve ser >= 0'),
        assert(materialReimbursementAmount >= 0, 'materialReimbursementAmount deve ser >= 0');

  factory SmartSplitBreakdown.validated({
    required double serviceLaborAmount,
    required double materialReimbursementAmount,
    double totalPlatformTakeRate = 0.15,
    double operationalTakeRate = 0.135,
    double warrantyReserveTakeRate = 0.015,
  }) {
    final safeLabor = SecurityAndLgpdGuard.validateAmount(
      serviceLaborAmount,
      fieldName: 'serviceLaborAmount',
    );
    final safeMaterial = SecurityAndLgpdGuard.validateAmount(
      materialReimbursementAmount,
      fieldName: 'materialReimbursementAmount',
    );
    SecurityAndLgpdGuard.validateSplitRates(
      totalPlatformTakeRate: totalPlatformTakeRate,
      operationalTakeRate: operationalTakeRate,
      warrantyReserveTakeRate: warrantyReserveTakeRate,
    );
    return SmartSplitBreakdown(
      serviceLaborAmount: safeLabor,
      materialReimbursementAmount: safeMaterial,
      totalPlatformTakeRate: totalPlatformTakeRate,
      operationalTakeRate: operationalTakeRate,
      warrantyReserveTakeRate: warrantyReserveTakeRate,
    );
  }

  /// Carteira A — Mão de Obra do Técnico.
  final double serviceLaborAmount;

  /// Carteira B — Reembolso de Peças com 0% de taxa.
  final double materialReimbursementAmount;

  /// Alíquota total sobre mão de obra (padrão: 15% = 0.15).
  final double totalPlatformTakeRate;

  /// Caixa Livre Operacional da Plataforma (padrão: 13,5% = 0.135).
  final double operationalTakeRate;

  /// Fundo de Reserva de Garantia (padrão: 1,5% = 0.015).
  final double warrantyReserveTakeRate;

  // ---------------------------------------------------------------------------
  // Aritmética em CENTAVOS INTEIROS (core/utils/money.dart): nenhum `double` entra
  // em soma/percentual. Invariantes garantidos para QUALQUER valor/centavo ímpar:
  //   totalPlatformFee + providerNetLaborPayout == serviceLaborAmount
  //   providerTotalNetPayout + totalPlatformFee == grossTransactionAmount
  //   platformOperationalRevenue + warrantyReserveContribution == totalPlatformFee
  // Os getters em `double` existem só por compatibilidade de API/serialização.
  // ---------------------------------------------------------------------------

  int get _laborCents => Money.toCents(serviceLaborAmount);
  int get _materialCents => Money.toCents(materialReimbursementAmount);
  int get _opRevenueCents => Money.rateOfCents(_laborCents, operationalTakeRate);
  int get _reserveCents => Money.rateOfCents(_laborCents, warrantyReserveTakeRate);
  int get _totalFeeCents => _opRevenueCents + _reserveCents;

  /// Centavos inteiros da taxa total (fonte da verdade para quem precisa gravar/ratear).
  int get totalPlatformFeeCents => _totalFeeCents;

  /// Centavos inteiros do repasse líquido da mão de obra.
  int get providerNetLaborPayoutCents => _laborCents - _totalFeeCents;

  /// Valor bruto total da transação (M + P).
  double get grossTransactionAmount => Money.fromCents(_laborCents + _materialCents);

  /// Receita operacional da plataforma (M * 0.135).
  double get platformOperationalRevenue => Money.fromCents(_opRevenueCents);

  /// Aporte no Fundo de Reserva de Garantia (M * 0.015).
  double get warrantyReserveContribution => Money.fromCents(_reserveCents);

  /// Taxa total da plataforma (soma exata da receita operacional + aporte de garantia).
  double get totalPlatformFee => Money.fromCents(_totalFeeCents);

  /// Repasse líquido da mão de obra para o prestador (M - totalPlatformFee).
  double get providerNetLaborPayout => Money.fromCents(providerNetLaborPayoutCents);

  /// Repasse líquido total do prestador (providerNetLaborPayout + P).
  double get providerTotalNetPayout =>
      Money.fromCents(providerNetLaborPayoutCents + _materialCents);

  /// Alíquota efetiva percentual sobre o valor bruto total (0 a 100%), 2 casas.
  double get effectiveFeePercentageOnGross {
    final grossCents = _laborCents + _materialCents;
    if (grossCents <= 0) return 0.0;
    // (fee / gross) * 100 com 2 casas, meio para cima, em inteiros.
    final centi = (_totalFeeCents * 10000 + grossCents ~/ 2) ~/ grossCents;
    return centi / 100.0;
  }

  /// Economia real do prestador por não pagar taxa sobre peças (P * totalPlatformTakeRate).
  double get providerSavedFeeBySmartSplit =>
      Money.fromCents(Money.rateOfCents(_materialCents, totalPlatformTakeRate));

  /// Teto máximo de cobertura do Fundo de Garantia = 100% da mão de obra original (M).
  double get maxWarrantyCoverageCap => Money.fromCents(_laborCents);
  SmartSplitBreakdown copyWith({
    double? serviceLaborAmount,
    double? materialReimbursementAmount,
    double? totalPlatformTakeRate,
    double? operationalTakeRate,
    double? warrantyReserveTakeRate,
  }) {
    return SmartSplitBreakdown.validated(
      serviceLaborAmount: serviceLaborAmount ?? this.serviceLaborAmount,
      materialReimbursementAmount:
          materialReimbursementAmount ?? this.materialReimbursementAmount,
      totalPlatformTakeRate: totalPlatformTakeRate ?? this.totalPlatformTakeRate,
      operationalTakeRate: operationalTakeRate ?? this.operationalTakeRate,
      warrantyReserveTakeRate: warrantyReserveTakeRate ?? this.warrantyReserveTakeRate,
    );
  }

  Map<String, dynamic> toMap() => {
        'serviceLaborAmount': serviceLaborAmount,
        'materialReimbursementAmount': materialReimbursementAmount,
        'totalPlatformTakeRate': totalPlatformTakeRate,
        'operationalTakeRate': operationalTakeRate,
        'warrantyReserveTakeRate': warrantyReserveTakeRate,
      };

  factory SmartSplitBreakdown.fromMap(Map<String, dynamic> map) {
    return SmartSplitBreakdown.validated(
      serviceLaborAmount: (map['serviceLaborAmount'] as num?)?.toDouble() ?? 0.0,
      materialReimbursementAmount:
          (map['materialReimbursementAmount'] as num?)?.toDouble() ?? 0.0,
      totalPlatformTakeRate: (map['totalPlatformTakeRate'] as num?)?.toDouble() ?? 0.15,
      operationalTakeRate: (map['operationalTakeRate'] as num?)?.toDouble() ?? 0.135,
      warrantyReserveTakeRate: (map['warrantyReserveTakeRate'] as num?)?.toDouble() ?? 0.015,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SmartSplitBreakdown.fromJson(String source) =>
      SmartSplitBreakdown.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmartSplitBreakdown &&
          other.serviceLaborAmount == serviceLaborAmount &&
          other.materialReimbursementAmount == materialReimbursementAmount &&
          other.totalPlatformTakeRate == totalPlatformTakeRate &&
          other.operationalTakeRate == operationalTakeRate &&
          other.warrantyReserveTakeRate == warrantyReserveTakeRate;

  @override
  int get hashCode => Object.hash(
        serviceLaborAmount,
        materialReimbursementAmount,
        totalPlatformTakeRate,
        operationalTakeRate,
        warrantyReserveTakeRate,
      );
}

/// Certificado Digital de Garantia e Conformidade com Cadeia Forense e 3 Regras de Ouro.
@immutable
class WarrantyCertificate {
  const WarrantyCertificate({
    required this.certificateCode,
    required this.securityVerificationHash,
    required this.orderId,
    required this.serviceCategoryName,
    required this.serviceTitle,
    required this.clientName,
    required this.providerName,
    required this.propertyAddress,
    required this.issuedAt,
    required this.warrantyDurationDays,
    required this.expiresAt,
    required this.checkInBeforePhotos,
    required this.checkOutAfterPhotos,
    required this.reimbursedMaterials,
    required this.financialBreakdown,
    this.goldenLegalClauses = defaultGoldenClauses,
  });

  static const List<String> defaultGoldenClauses = [
    '1. ESCOPO ESTRITO ÀS FOTOS FORENSES: A garantia cobre exclusivamente o ponto de intervenção registrado nas fotos verificadas de Check-in (Antes) e Check-out (Depois).',
    '2. INVIOLABILIDADE DO LOCAL: A cobertura é automaticamente extinta caso haja violação de lacre, mau uso ou intervenção posterior de terceiros não credenciados.',
    '3. TETO FINANCEIRO (CAP 100% MÃO DE OBRA) E PEÇAS: A cobertura do Fundo de Reserva limita-se a 100% da mão de obra original (Carteira A). Defeitos de fabricação das peças contam com garantia legal do fabricante via Cupom Fiscal anexado na Carteira B.',
  ];

  final String certificateCode;
  final String securityVerificationHash;
  final String orderId;
  final String serviceCategoryName;
  final String serviceTitle;
  final String clientName;
  final String providerName;
  final String propertyAddress;
  final DateTime issuedAt;
  final int warrantyDurationDays;
  final DateTime expiresAt;
  final List<ForensicPhotoEvidence> checkInBeforePhotos;
  final List<ForensicPhotoEvidence> checkOutAfterPhotos;
  final List<MaterialReimbursementTicket> reimbursedMaterials;
  final SmartSplitBreakdown financialBreakdown;
  final List<String> goldenLegalClauses;

  /// Nome do cliente protegido conforme minimização de dados da LGPD.
  String get maskedClientName => SecurityAndLgpdGuard.maskClientName(clientName);

  /// Valida se a cadeia forense possui mínimo de 2 fotos de Check-in e 2 fotos de Check-out com hashes íntegros.
  bool get hasCompleteForensicChain =>
      checkInBeforePhotos.length >= 2 &&
      checkOutAfterPhotos.length >= 2 &&
      checkInBeforePhotos.every((p) => p.integrityHash.isNotEmpty) &&
      checkOutAfterPhotos.every((p) => p.integrityHash.isNotEmpty);

  /// Verifica se o certificado é válido, possui cadeia forense completa e está dentro da vigência.
  bool get isValidAndActive =>
      hasCompleteForensicChain && DateTime.now().isBefore(expiresAt);

  /// Dias restantes de cobertura de garantia.
  int get remainingDays {
    final diff = expiresAt.difference(DateTime.now()).inDays;
    if (diff < 0) return 0;
    if (diff > warrantyDurationDays) return warrantyDurationDays;
    return diff;
  }

  WarrantyCertificate copyWith({
    String? certificateCode,
    String? securityVerificationHash,
    String? orderId,
    String? serviceCategoryName,
    String? serviceTitle,
    String? clientName,
    String? providerName,
    String? propertyAddress,
    DateTime? issuedAt,
    int? warrantyDurationDays,
    DateTime? expiresAt,
    List<ForensicPhotoEvidence>? checkInBeforePhotos,
    List<ForensicPhotoEvidence>? checkOutAfterPhotos,
    List<MaterialReimbursementTicket>? reimbursedMaterials,
    SmartSplitBreakdown? financialBreakdown,
    List<String>? goldenLegalClauses,
  }) {
    return WarrantyCertificate(
      certificateCode: certificateCode ?? this.certificateCode,
      securityVerificationHash: securityVerificationHash ?? this.securityVerificationHash,
      orderId: orderId ?? this.orderId,
      serviceCategoryName: serviceCategoryName ?? this.serviceCategoryName,
      serviceTitle: serviceTitle ?? this.serviceTitle,
      clientName: clientName ?? this.clientName,
      providerName: providerName ?? this.providerName,
      propertyAddress: propertyAddress ?? this.propertyAddress,
      issuedAt: issuedAt ?? this.issuedAt,
      warrantyDurationDays: warrantyDurationDays ?? this.warrantyDurationDays,
      expiresAt: expiresAt ?? this.expiresAt,
      checkInBeforePhotos: checkInBeforePhotos ?? this.checkInBeforePhotos,
      checkOutAfterPhotos: checkOutAfterPhotos ?? this.checkOutAfterPhotos,
      reimbursedMaterials: reimbursedMaterials ?? this.reimbursedMaterials,
      financialBreakdown: financialBreakdown ?? this.financialBreakdown,
      goldenLegalClauses: goldenLegalClauses ?? this.goldenLegalClauses,
    );
  }

  Map<String, dynamic> toMap() => {
        'certificateCode': certificateCode,
        'securityVerificationHash': securityVerificationHash,
        'orderId': orderId,
        'serviceCategoryName': serviceCategoryName,
        'serviceTitle': serviceTitle,
        'clientName': clientName,
        'providerName': providerName,
        'propertyAddress': propertyAddress,
        'issuedAt': issuedAt.toUtc().toIso8601String(),
        'warrantyDurationDays': warrantyDurationDays,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'checkInBeforePhotos': checkInBeforePhotos.map((x) => x.toMap()).toList(),
        'checkOutAfterPhotos': checkOutAfterPhotos.map((x) => x.toMap()).toList(),
        'reimbursedMaterials': reimbursedMaterials.map((x) => x.toMap()).toList(),
        'financialBreakdown': financialBreakdown.toMap(),
        'goldenLegalClauses': goldenLegalClauses,
      };

  factory WarrantyCertificate.fromMap(Map<String, dynamic> map) {
    return WarrantyCertificate(
      certificateCode: (map['certificateCode'] as String?) ?? '',
      securityVerificationHash: (map['securityVerificationHash'] as String?) ?? '',
      orderId: (map['orderId'] as String?) ?? '',
      serviceCategoryName: (map['serviceCategoryName'] as String?) ?? '',
      serviceTitle: (map['serviceTitle'] as String?) ?? '',
      clientName: (map['clientName'] as String?) ?? '',
      providerName: (map['providerName'] as String?) ?? '',
      propertyAddress: (map['propertyAddress'] as String?) ?? '',
      issuedAt: DateTime.tryParse((map['issuedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      warrantyDurationDays: (map['warrantyDurationDays'] as num?)?.toInt() ?? 90,
      expiresAt: DateTime.tryParse((map['expiresAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      checkInBeforePhotos: ((map['checkInBeforePhotos'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ForensicPhotoEvidence.fromMap)
          .toList(),
      checkOutAfterPhotos: ((map['checkOutAfterPhotos'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ForensicPhotoEvidence.fromMap)
          .toList(),
      reimbursedMaterials: ((map['reimbursedMaterials'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MaterialReimbursementTicket.fromMap)
          .toList(),
      financialBreakdown: map['financialBreakdown'] is Map<String, dynamic>
          ? SmartSplitBreakdown.fromMap(map['financialBreakdown'] as Map<String, dynamic>)
          : const SmartSplitBreakdown(
              serviceLaborAmount: 0,
              materialReimbursementAmount: 0,
            ),
      goldenLegalClauses: ((map['goldenLegalClauses'] as List?) ?? defaultGoldenClauses)
          .map((e) => '$e')
          .toList(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory WarrantyCertificate.fromJson(String source) =>
      WarrantyCertificate.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WarrantyCertificate &&
          other.certificateCode == certificateCode &&
          other.securityVerificationHash == securityVerificationHash &&
          other.orderId == orderId &&
          other.serviceCategoryName == serviceCategoryName &&
          other.serviceTitle == serviceTitle &&
          other.clientName == clientName &&
          other.providerName == providerName &&
          other.propertyAddress == propertyAddress &&
          other.issuedAt.millisecondsSinceEpoch == issuedAt.millisecondsSinceEpoch &&
          other.warrantyDurationDays == warrantyDurationDays &&
          other.expiresAt.millisecondsSinceEpoch == expiresAt.millisecondsSinceEpoch &&
          listEquals(other.checkInBeforePhotos, checkInBeforePhotos) &&
          listEquals(other.checkOutAfterPhotos, checkOutAfterPhotos) &&
          listEquals(other.reimbursedMaterials, reimbursedMaterials) &&
          other.financialBreakdown == financialBreakdown &&
          listEquals(other.goldenLegalClauses, goldenLegalClauses);

  @override
  int get hashCode => Object.hash(
        certificateCode,
        securityVerificationHash,
        orderId,
        serviceCategoryName,
        serviceTitle,
        clientName,
        providerName,
        propertyAddress,
        issuedAt.millisecondsSinceEpoch,
        warrantyDurationDays,
        expiresAt.millisecondsSinceEpoch,
        Object.hashAll(checkInBeforePhotos),
        Object.hashAll(checkOutAfterPhotos),
        Object.hashAll(reimbursedMaterials),
        financialBreakdown,
        Object.hashAll(goldenLegalClauses),
      );
}

/// As 3 Camadas de Resolução de Garantia Desperrengue.
enum WarrantyResolutionLayer {
  /// Camada 1 (85-90% dos casos): Retorno gratuito obrigatório do próprio prestador (Art. 20 CDC).
  layer1ProviderFreeReturn,

  /// Camada 2 (8-10% dos casos): Defeito precoce em <48h com retenção preventiva da Carteira A no Escrow.
  layer2EscrowHoldRetention,

  /// Camada 3 (<2% dos casos): Prestador original inadimplente; Prestador Socorrista pago pelo Fundo de Reserva (1,5%) + Clawback.
  layer3ReserveFundRescue,
}

extension WarrantyResolutionLayerX on WarrantyResolutionLayer {
  String get code => switch (this) {
        WarrantyResolutionLayer.layer1ProviderFreeReturn => 'layer1_provider_free_return',
        WarrantyResolutionLayer.layer2EscrowHoldRetention => 'layer2_escrow_hold_retention',
        WarrantyResolutionLayer.layer3ReserveFundRescue => 'layer3_reserve_fund_rescue',
      };

  String get shortBadge => switch (this) {
        WarrantyResolutionLayer.layer1ProviderFreeReturn => 'Camada 1 • 85–90% dos casos',
        WarrantyResolutionLayer.layer2EscrowHoldRetention => 'Camada 2 • 8–10% dos casos',
        WarrantyResolutionLayer.layer3ReserveFundRescue => 'Camada 3 • < 2% dos casos',
      };

  String get title => switch (this) {
        WarrantyResolutionLayer.layer1ProviderFreeReturn =>
          'Camada 1: Retorno Gratuito Obrigatório (Art. 20 CDC)',
        WarrantyResolutionLayer.layer2EscrowHoldRetention =>
          'Camada 2: Retenção Preventiva Escrow (< 48h)',
        WarrantyResolutionLayer.layer3ReserveFundRescue =>
          'Camada 3: Prestador Socorrista via Fundo de Reserva (1,5%) + Clawback',
      };

  String get description => switch (this) {
        WarrantyResolutionLayer.layer1ProviderFreeReturn =>
          'O prestador original realiza o retorno técnico sem custo adicional. Sua agenda de novos chamados e ranking ficam travados até a confirmação do reparo.',
        WarrantyResolutionLayer.layer2EscrowHoldRetention =>
          'Para defeitos reportados em menos de 48h, o repasse da Carteira A (Mão de Obra) permanece congelado no Escrow até a solução definitiva.',
        WarrantyResolutionLayer.layer3ReserveFundRescue =>
          'Se o prestador original recusar ou abandonar o retorno, o Fundo de Reserva de 1,5% remunera um Prestador Socorrista (até o teto de 100% da mão de obra) e lança Clawback automático no saldo futuro do infrator.',
      };

  static WarrantyResolutionLayer fromCode(String? raw) => switch (raw) {
        'layer1_provider_free_return' || 'layer1ProviderFreeReturn' =>
          WarrantyResolutionLayer.layer1ProviderFreeReturn,
        'layer2_escrow_hold_retention' || 'layer2EscrowHoldRetention' =>
          WarrantyResolutionLayer.layer2EscrowHoldRetention,
        'layer3_reserve_fund_rescue' || 'layer3ReserveFundRescue' =>
          WarrantyResolutionLayer.layer3ReserveFundRescue,
        _ => WarrantyResolutionLayer.layer1ProviderFreeReturn,
      };
}

enum WarrantyClaimStatus {
  open,
  providerAssignedForReturn,
  escrowRetained,
  rescueProviderDispatched,
  resolved,
}

extension WarrantyClaimStatusX on WarrantyClaimStatus {
  String get code => switch (this) {
        WarrantyClaimStatus.open => 'open',
        WarrantyClaimStatus.providerAssignedForReturn => 'provider_assigned_for_return',
        WarrantyClaimStatus.escrowRetained => 'escrow_retained',
        WarrantyClaimStatus.rescueProviderDispatched => 'rescue_provider_dispatched',
        WarrantyClaimStatus.resolved => 'resolved',
      };

  String get label => switch (this) {
        WarrantyClaimStatus.open => 'Aberto',
        WarrantyClaimStatus.providerAssignedForReturn => 'Retorno CDC Agendado (Agenda Travada)',
        WarrantyClaimStatus.escrowRetained => 'Carteira A Retida no Escrow (<48h)',
        WarrantyClaimStatus.rescueProviderDispatched => 'Prestador Socorrista Acionado (Fundo 1,5%)',
        WarrantyClaimStatus.resolved => 'Garantia Concluída',
      };

  static WarrantyClaimStatus fromCode(String? raw) => switch (raw) {
        'provider_assigned_for_return' || 'providerAssignedForReturn' =>
          WarrantyClaimStatus.providerAssignedForReturn,
        'escrow_retained' || 'escrowRetained' => WarrantyClaimStatus.escrowRetained,
        'rescue_provider_dispatched' || 'rescueProviderDispatched' =>
          WarrantyClaimStatus.rescueProviderDispatched,
        'resolved' => WarrantyClaimStatus.resolved,
        _ => WarrantyClaimStatus.open,
      };
}

/// Ticket de Acionamento da Garantia em 3 Camadas com Teto Cap e Registro de Clawback.
@immutable
class WarrantyClaimTicket {
  const WarrantyClaimTicket({
    required this.id,
    required this.certificateCode,
    required this.orderId,
    required this.originalProviderId,
    this.rescueProviderId,
    required this.currentLayer,
    required this.status,
    required this.claimReason,
    required this.reportedAt,
    required this.hoursSinceServiceCompletion,
    required this.isOriginalProviderScheduleLocked,
    required this.isEscrowWalletARetained,
    required this.reserveFundAllocatedAmount,
    required this.maxWarrantyCoverageCap,
    required this.clawbackDebitedFromOffender,
    required this.auditTrailNote,
  }) : assert(
          reserveFundAllocatedAmount <= maxWarrantyCoverageCap,
          'A alocação do Fundo de Reserva nunca pode ultrapassar o maxWarrantyCoverageCap (100% da mão de obra).',
        );

  final String id;
  final String certificateCode;
  final String orderId;
  final String originalProviderId;
  final String? rescueProviderId;
  final WarrantyResolutionLayer currentLayer;
  final WarrantyClaimStatus status;
  final String claimReason;
  final DateTime reportedAt;
  final double hoursSinceServiceCompletion;
  final bool isOriginalProviderScheduleLocked;
  final bool isEscrowWalletARetained;
  final double reserveFundAllocatedAmount;
  final double maxWarrantyCoverageCap;
  final double clawbackDebitedFromOffender;
  final String auditTrailNote;

  WarrantyClaimTicket copyWith({
    String? id,
    String? certificateCode,
    String? orderId,
    String? originalProviderId,
    String? rescueProviderId,
    WarrantyResolutionLayer? currentLayer,
    WarrantyClaimStatus? status,
    String? claimReason,
    DateTime? reportedAt,
    double? hoursSinceServiceCompletion,
    bool? isOriginalProviderScheduleLocked,
    bool? isEscrowWalletARetained,
    double? reserveFundAllocatedAmount,
    double? maxWarrantyCoverageCap,
    double? clawbackDebitedFromOffender,
    String? auditTrailNote,
  }) {
    final cap = SecurityAndLgpdGuard.validateAmount(
      maxWarrantyCoverageCap ?? this.maxWarrantyCoverageCap,
      fieldName: 'maxWarrantyCoverageCap',
    );
    final rawAllocated = SecurityAndLgpdGuard.validateAmount(
      reserveFundAllocatedAmount ?? this.reserveFundAllocatedAmount,
      fieldName: 'reserveFundAllocatedAmount',
    );
    final cappedAllocated = rawAllocated > cap ? cap : rawAllocated;
    return WarrantyClaimTicket(
      id: id ?? this.id,
      certificateCode: certificateCode ?? this.certificateCode,
      orderId: orderId ?? this.orderId,
      originalProviderId: originalProviderId ?? this.originalProviderId,
      rescueProviderId: rescueProviderId ?? this.rescueProviderId,
      currentLayer: currentLayer ?? this.currentLayer,
      status: status ?? this.status,
      claimReason: claimReason != null
          ? SecurityAndLgpdGuard.sanitizeInput(claimReason)
          : this.claimReason,
      reportedAt: reportedAt ?? this.reportedAt,
      hoursSinceServiceCompletion:
          hoursSinceServiceCompletion ?? this.hoursSinceServiceCompletion,
      isOriginalProviderScheduleLocked:
          isOriginalProviderScheduleLocked ?? this.isOriginalProviderScheduleLocked,
      isEscrowWalletARetained: isEscrowWalletARetained ?? this.isEscrowWalletARetained,
      reserveFundAllocatedAmount: cappedAllocated,
      maxWarrantyCoverageCap: cap,
      clawbackDebitedFromOffender: SecurityAndLgpdGuard.validateAmount(
        clawbackDebitedFromOffender ?? this.clawbackDebitedFromOffender,
        fieldName: 'clawbackDebitedFromOffender',
      ),
      auditTrailNote: auditTrailNote != null
          ? SecurityAndLgpdGuard.sanitizeInput(auditTrailNote)
          : this.auditTrailNote,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'certificateCode': certificateCode,
        'orderId': orderId,
        'originalProviderId': originalProviderId,
        'rescueProviderId': rescueProviderId,
        'currentLayer': currentLayer.code,
        'status': status.code,
        'claimReason': claimReason,
        'reportedAt': reportedAt.toUtc().toIso8601String(),
        'hoursSinceServiceCompletion': hoursSinceServiceCompletion,
        'isOriginalProviderScheduleLocked': isOriginalProviderScheduleLocked,
        'isEscrowWalletARetained': isEscrowWalletARetained,
        'reserveFundAllocatedAmount': reserveFundAllocatedAmount,
        'maxWarrantyCoverageCap': maxWarrantyCoverageCap,
        'clawbackDebitedFromOffender': clawbackDebitedFromOffender,
        'auditTrailNote': auditTrailNote,
      };

  factory WarrantyClaimTicket.fromMap(Map<String, dynamic> map) {
    final cap = SecurityAndLgpdGuard.validateAmount(
      (map['maxWarrantyCoverageCap'] as num?)?.toDouble() ?? 0.0,
    );
    final rawAllocated = SecurityAndLgpdGuard.validateAmount(
      (map['reserveFundAllocatedAmount'] as num?)?.toDouble() ?? 0.0,
    );
    return WarrantyClaimTicket(
      id: (map['id'] as String?) ?? '',
      certificateCode: (map['certificateCode'] as String?) ?? '',
      orderId: (map['orderId'] as String?) ?? '',
      originalProviderId: (map['originalProviderId'] as String?) ?? '',
      rescueProviderId: map['rescueProviderId'] as String?,
      currentLayer: WarrantyResolutionLayerX.fromCode(map['currentLayer'] as String?),
      status: WarrantyClaimStatusX.fromCode(map['status'] as String?),
      claimReason: SecurityAndLgpdGuard.sanitizeInput((map['claimReason'] as String?) ?? ''),
      reportedAt: DateTime.tryParse((map['reportedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      hoursSinceServiceCompletion:
          (map['hoursSinceServiceCompletion'] as num?)?.toDouble() ?? 0.0,
      isOriginalProviderScheduleLocked:
          (map['isOriginalProviderScheduleLocked'] as bool?) ?? false,
      isEscrowWalletARetained: (map['isEscrowWalletARetained'] as bool?) ?? false,
      reserveFundAllocatedAmount: rawAllocated > cap ? cap : rawAllocated,
      maxWarrantyCoverageCap: cap,
      clawbackDebitedFromOffender: SecurityAndLgpdGuard.validateAmount(
        (map['clawbackDebitedFromOffender'] as num?)?.toDouble() ?? 0.0,
      ),
      auditTrailNote: SecurityAndLgpdGuard.sanitizeInput(
        (map['auditTrailNote'] as String?) ?? '',
      ),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory WarrantyClaimTicket.fromJson(String source) =>
      WarrantyClaimTicket.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WarrantyClaimTicket &&
          other.id == id &&
          other.certificateCode == certificateCode &&
          other.orderId == orderId &&
          other.originalProviderId == originalProviderId &&
          other.rescueProviderId == rescueProviderId &&
          other.currentLayer == currentLayer &&
          other.status == status &&
          other.claimReason == claimReason &&
          other.reportedAt.millisecondsSinceEpoch == reportedAt.millisecondsSinceEpoch &&
          other.hoursSinceServiceCompletion == hoursSinceServiceCompletion &&
          other.isOriginalProviderScheduleLocked == isOriginalProviderScheduleLocked &&
          other.isEscrowWalletARetained == isEscrowWalletARetained &&
          other.reserveFundAllocatedAmount == reserveFundAllocatedAmount &&
          other.maxWarrantyCoverageCap == maxWarrantyCoverageCap &&
          other.clawbackDebitedFromOffender == clawbackDebitedFromOffender &&
          other.auditTrailNote == auditTrailNote;

  @override
  int get hashCode => Object.hash(
        id,
        certificateCode,
        orderId,
        originalProviderId,
        rescueProviderId,
        currentLayer,
        status,
        claimReason,
        reportedAt.millisecondsSinceEpoch,
        hoursSinceServiceCompletion,
        isOriginalProviderScheduleLocked,
        isEscrowWalletARetained,
        reserveFundAllocatedAmount,
        maxWarrantyCoverageCap,
        clawbackDebitedFromOffender,
        auditTrailNote,
      );
}

/// Registro individual auditado no Passaporte de Manutenção do Imóvel ("Prontuário da Casa").
@immutable
class PropertyMaintenanceEntry {
  const PropertyMaintenanceEntry({
    required this.id,
    required this.orderId,
    required this.certificateCode,
    required this.serviceCategoryName,
    required this.serviceTitle,
    required this.providerName,
    required this.completedAt,
    required this.warrantyExpiresAt,
    required this.laborAmount,
    required this.materialAmount,
    required this.forensicHash,
  });

  final String id;
  final String orderId;
  final String certificateCode;
  final String serviceCategoryName;
  final String serviceTitle;
  final String providerName;
  final DateTime completedAt;
  final DateTime warrantyExpiresAt;
  final double laborAmount;
  final double materialAmount;
  final String forensicHash;

  double get totalInvested =>
      Money.fromCents(Money.toCents(laborAmount) + Money.toCents(materialAmount));

  bool get isWarrantyActive => DateTime.now().isBefore(warrantyExpiresAt);

  PropertyMaintenanceEntry copyWith({
    String? id,
    String? orderId,
    String? certificateCode,
    String? serviceCategoryName,
    String? serviceTitle,
    String? providerName,
    DateTime? completedAt,
    DateTime? warrantyExpiresAt,
    double? laborAmount,
    double? materialAmount,
    String? forensicHash,
  }) {
    return PropertyMaintenanceEntry(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      certificateCode: certificateCode ?? this.certificateCode,
      serviceCategoryName: serviceCategoryName ?? this.serviceCategoryName,
      serviceTitle: serviceTitle ?? this.serviceTitle,
      providerName: providerName ?? this.providerName,
      completedAt: completedAt ?? this.completedAt,
      warrantyExpiresAt: warrantyExpiresAt ?? this.warrantyExpiresAt,
      laborAmount: laborAmount ?? this.laborAmount,
      materialAmount: materialAmount ?? this.materialAmount,
      forensicHash: forensicHash ?? this.forensicHash,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'orderId': orderId,
        'certificateCode': certificateCode,
        'serviceCategoryName': serviceCategoryName,
        'serviceTitle': serviceTitle,
        'providerName': providerName,
        'completedAt': completedAt.toUtc().toIso8601String(),
        'warrantyExpiresAt': warrantyExpiresAt.toUtc().toIso8601String(),
        'laborAmount': laborAmount,
        'materialAmount': materialAmount,
        'forensicHash': forensicHash,
      };

  factory PropertyMaintenanceEntry.fromMap(Map<String, dynamic> map) {
    return PropertyMaintenanceEntry(
      id: (map['id'] as String?) ?? '',
      orderId: (map['orderId'] as String?) ?? '',
      certificateCode: (map['certificateCode'] as String?) ?? '',
      serviceCategoryName: (map['serviceCategoryName'] as String?) ?? '',
      serviceTitle: (map['serviceTitle'] as String?) ?? '',
      providerName: (map['providerName'] as String?) ?? '',
      completedAt: DateTime.tryParse((map['completedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      warrantyExpiresAt:
          DateTime.tryParse((map['warrantyExpiresAt'] as String?) ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      laborAmount: (map['laborAmount'] as num?)?.toDouble() ?? 0.0,
      materialAmount: (map['materialAmount'] as num?)?.toDouble() ?? 0.0,
      forensicHash: (map['forensicHash'] as String?) ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PropertyMaintenanceEntry.fromJson(String source) =>
      PropertyMaintenanceEntry.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PropertyMaintenanceEntry &&
          other.id == id &&
          other.orderId == orderId &&
          other.certificateCode == certificateCode &&
          other.serviceCategoryName == serviceCategoryName &&
          other.serviceTitle == serviceTitle &&
          other.providerName == providerName &&
          other.completedAt.millisecondsSinceEpoch == completedAt.millisecondsSinceEpoch &&
          other.warrantyExpiresAt.millisecondsSinceEpoch ==
              warrantyExpiresAt.millisecondsSinceEpoch &&
          other.laborAmount == laborAmount &&
          other.materialAmount == materialAmount &&
          other.forensicHash == forensicHash;

  @override
  int get hashCode => Object.hash(
        id,
        orderId,
        certificateCode,
        serviceCategoryName,
        serviceTitle,
        providerName,
        completedAt.millisecondsSinceEpoch,
        warrantyExpiresAt.millisecondsSinceEpoch,
        laborAmount,
        materialAmount,
        forensicHash,
      );
}

/// Passaporte de Manutenção do Imóvel — "Prontuário da Casa" para vistoria de imobiliária/seguradora.
///
/// Complexidade Algorítmica:
/// - Agregação financeira (`totalLaborInvested`, `totalMaterialsInvested`, `totalInvestedAmount`): $O(N)$ sobre `entries`.
/// - Cálculo de prontidão ABNT NBR 5674 (`inspectionReadinessScore`): $O(N)$ no pior caso e $O(1)$ no melhor caso (quando vazio).
@immutable
class PropertyMaintenancePassport {
  const PropertyMaintenancePassport({
    required this.passportId,
    required this.propertyAddress,
    required this.ownerName,
    required this.updatedAt,
    required this.entries,
    this.propertyNickname = '',
    this.propertyType = 'Casa Residencial',
    this.passportPurpose = 'Vistoria de Imobiliária / Entrega de Chaves',
    this.inspectedSystems = const <String>[],
    this.isConfiguredByClient = false,
  });

  final String passportId;
  final String propertyAddress;
  final String ownerName;
  final DateTime updatedAt;
  final List<PropertyMaintenanceEntry> entries;
  final String propertyNickname;
  final String propertyType;
  final String passportPurpose;
  final List<String> inspectedSystems;
  final bool isConfiguredByClient;

  String get maskedOwnerName => SecurityAndLgpdGuard.maskClientName(ownerName);

  int get _laborInvestedCents => entries.fold<int>(0, (s, e) => s + Money.toCents(e.laborAmount));
  int get _materialsInvestedCents => entries.fold<int>(0, (s, e) => s + Money.toCents(e.materialAmount));

  double get totalLaborInvested => Money.fromCents(_laborInvestedCents);

  double get totalMaterialsInvested => Money.fromCents(_materialsInvestedCents);

  double get totalInvestedAmount =>
      Money.fromCents(_laborInvestedCents + _materialsInvestedCents);

  int get activeWarrantiesCount => entries.where((e) => e.isWarrantyActive).length;

  /// Score de prontidão para vistoria de imobiliária/seguradora (0 a 100) segundo ABNT NBR 5674.
  /// Sem dados falsos: inicia em 0/100 até que o cliente configure o imóvel ou registre serviços reais.
  int get inspectionReadinessScore {
    if (entries.isEmpty && !isConfiguredByClient) return 0;
    final configBase = (isConfiguredByClient || propertyAddress.trim().isNotEmpty) ? 35 : 20;
    final systemsBonus = (inspectedSystems.length * 5).clamp(0, 25);
    final entriesBonus = (entries.length * 15).clamp(0, 30);
    final warrantyBonus = activeWarrantiesCount > 0 ? 10 : 0;
    return (configBase + systemsBonus + entriesBonus + warrantyBonus).clamp(0, 100);
  }

  String get inspectionReadinessLabel {
    final s = inspectionReadinessScore;
    if (s == 0) {
      return 'Não iniciado (0/100) — Configure seu imóvel e registre manutenções reais';
    }
    if (s >= 85) {
      return 'Excelente ($s/100) — Imóvel Auditado (Apto para Vistoria/Seguradora)';
    }
    if (s >= 60) {
      return 'Muito Bom ($s/100) — Manutenção Preventiva Comprovada';
    }
    return 'Em estruturação ($s/100) — Registre manutenções reais para elevar o score';
  }

  PropertyMaintenancePassport copyWith({
    String? passportId,
    String? propertyAddress,
    String? ownerName,
    DateTime? updatedAt,
    List<PropertyMaintenanceEntry>? entries,
    String? propertyNickname,
    String? propertyType,
    String? passportPurpose,
    List<String>? inspectedSystems,
    bool? isConfiguredByClient,
  }) {
    return PropertyMaintenancePassport(
      passportId: passportId ?? this.passportId,
      propertyAddress: propertyAddress ?? this.propertyAddress,
      ownerName: ownerName ?? this.ownerName,
      updatedAt: updatedAt ?? this.updatedAt,
      entries: entries ?? this.entries,
      propertyNickname: propertyNickname ?? this.propertyNickname,
      propertyType: propertyType ?? this.propertyType,
      passportPurpose: passportPurpose ?? this.passportPurpose,
      inspectedSystems: inspectedSystems ?? this.inspectedSystems,
      isConfiguredByClient: isConfiguredByClient ?? this.isConfiguredByClient,
    );
  }

  Map<String, dynamic> toMap() => {
        'passportId': passportId,
        'propertyAddress': propertyAddress,
        'ownerName': ownerName,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'entries': entries.map((x) => x.toMap()).toList(),
        'propertyNickname': propertyNickname,
        'propertyType': propertyType,
        'passportPurpose': passportPurpose,
        'inspectedSystems': inspectedSystems,
        'isConfiguredByClient': isConfiguredByClient,
      };

  factory PropertyMaintenancePassport.fromMap(Map<String, dynamic> map) {
    return PropertyMaintenancePassport(
      passportId: (map['passportId'] as String?) ?? '',
      propertyAddress: (map['propertyAddress'] as String?) ?? '',
      ownerName: (map['ownerName'] as String?) ?? '',
      updatedAt: DateTime.tryParse((map['updatedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      entries: ((map['entries'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PropertyMaintenanceEntry.fromMap)
          .toList(),
      propertyNickname: (map['propertyNickname'] as String?) ?? '',
      propertyType: (map['propertyType'] as String?) ?? 'Casa Residencial',
      passportPurpose:
          (map['passportPurpose'] as String?) ?? 'Vistoria de Imobiliária / Entrega de Chaves',
      inspectedSystems: ((map['inspectedSystems'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      isConfiguredByClient: (map['isConfiguredByClient'] as bool?) ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PropertyMaintenancePassport.fromJson(String source) =>
      PropertyMaintenancePassport.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PropertyMaintenancePassport &&
          other.passportId == passportId &&
          other.propertyAddress == propertyAddress &&
          other.ownerName == ownerName &&
          other.updatedAt.millisecondsSinceEpoch == updatedAt.millisecondsSinceEpoch &&
          other.propertyNickname == propertyNickname &&
          other.propertyType == propertyType &&
          other.passportPurpose == passportPurpose &&
          other.isConfiguredByClient == isConfiguredByClient &&
          listEquals(other.inspectedSystems, inspectedSystems) &&
          listEquals(other.entries, entries);

  @override
  int get hashCode => Object.hash(
        passportId,
        propertyAddress,
        ownerName,
        updatedAt.millisecondsSinceEpoch,
        propertyNickname,
        propertyType,
        passportPurpose,
        isConfiguredByClient,
        Object.hashAll(inspectedSystems),
        Object.hashAll(entries),
      );
}

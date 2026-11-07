import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Nível de urgência diagnosticado pela Triagem Inteligente Multimodal.
enum UrgencyLevel {
  low('low'),
  medium('medium'),
  high('high'),
  criticalEmergency('critical_emergency');

  const UrgencyLevel(this.wire);
  final String wire;

  static UrgencyLevel parse(String? raw) {
    if (raw == null) return UrgencyLevel.medium;
    for (final v in UrgencyLevel.values) {
      if (v.wire == raw || v.name == raw) return v;
    }
    return UrgencyLevel.medium;
  }
}

extension UrgencyLevelX on UrgencyLevel {
  String get label => switch (this) {
        UrgencyLevel.low => 'Baixa',
        UrgencyLevel.medium => 'Moderada',
        UrgencyLevel.high => 'Alta Prioridade',
        UrgencyLevel.criticalEmergency => 'Emergência Crítica',
      };

  String get slaTargetText => switch (this) {
        UrgencyLevel.low => 'Atendimento padrão',
        UrgencyLevel.medium => 'Agendamento prioritário',
        UrgencyLevel.high => 'Prioridade na fila',
        UrgencyLevel.criticalEmergency => 'Acionamento imediato',
      };

  IconData get icon => switch (this) {
        UrgencyLevel.low => Icons.check_circle_outline_rounded,
        UrgencyLevel.medium => Icons.schedule_rounded,
        UrgencyLevel.high => Icons.priority_high_rounded,
        UrgencyLevel.criticalEmergency => Icons.warning_amber_rounded,
      };

  Color resolveColor(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return switch (this) {
      UrgencyLevel.low => dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      UrgencyLevel.medium => dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
      UrgencyLevel.high => dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
      UrgencyLevel.criticalEmergency => dark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
    };
  }

  Color resolveContainerColor(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return switch (this) {
      UrgencyLevel.low => dark ? const Color(0xFF132A1E) : const Color(0xFFDCFCE7),
      UrgencyLevel.medium => dark ? const Color(0xFF16243B) : const Color(0xFFDBEAFE),
      UrgencyLevel.high => dark ? const Color(0xFF2E2212) : const Color(0xFFFEF3C7),
      UrgencyLevel.criticalEmergency => dark ? const Color(0xFF311518) : const Color(0xFFFEE2E2),
    };
  }
}

/// Peça ou insumo provável identificado pela triagem para evitar visita perdida.
@immutable
class ProbableMaterialItem {
  const ProbableMaterialItem({
    required this.id,
    required this.name,
    required this.technicalSpec,
    required this.estimatedQuantity,
    this.isOptional = false,
    this.clientAlreadyHasIt = false,
  });

  final String id;
  final String name;
  final String technicalSpec;
  final String estimatedQuantity;
  final bool isOptional;
  final bool clientAlreadyHasIt;

  ProbableMaterialItem copyWith({
    String? id,
    String? name,
    String? technicalSpec,
    String? estimatedQuantity,
    bool? isOptional,
    bool? clientAlreadyHasIt,
  }) =>
      ProbableMaterialItem(
        id: id ?? this.id,
        name: name ?? this.name,
        technicalSpec: technicalSpec ?? this.technicalSpec,
        estimatedQuantity: estimatedQuantity ?? this.estimatedQuantity,
        isOptional: isOptional ?? this.isOptional,
        clientAlreadyHasIt: clientAlreadyHasIt ?? this.clientAlreadyHasIt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'technicalSpec': technicalSpec,
        'estimatedQuantity': estimatedQuantity,
        'isOptional': isOptional,
        'clientAlreadyHasIt': clientAlreadyHasIt,
      };

  factory ProbableMaterialItem.fromMap(Map<String, dynamic> map) => ProbableMaterialItem(
        id: (map['id'] as String?) ?? '',
        name: (map['name'] as String?) ?? '',
        technicalSpec: (map['technicalSpec'] as String?) ?? '',
        estimatedQuantity: (map['estimatedQuantity'] as String?) ?? '1 un',
        isOptional: (map['isOptional'] as bool?) ?? false,
        clientAlreadyHasIt: (map['clientAlreadyHasIt'] as bool?) ?? false,
      );

  String toJson() => jsonEncode(toMap());

  factory ProbableMaterialItem.fromJson(String source) =>
      ProbableMaterialItem.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProbableMaterialItem &&
          other.id == id &&
          other.name == name &&
          other.technicalSpec == technicalSpec &&
          other.estimatedQuantity == estimatedQuantity &&
          other.isOptional == isOptional &&
          other.clientAlreadyHasIt == clientAlreadyHasIt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        technicalSpec,
        estimatedQuantity,
        isOptional,
        clientAlreadyHasIt,
      );
}

/// Passo prático de Primeiros Socorros do Imóvel (Contenção de Emergência em 60s).
@immutable
class ContainmentStep {
  const ContainmentStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.iconKey,
    this.isCriticalSafetyWarning = false,
    this.safetyWarningBadgeText,
    this.isCompleted = false,
  });

  final int stepNumber;
  final String title;
  final String description;
  final String iconKey;
  final bool isCriticalSafetyWarning;
  final String? safetyWarningBadgeText;
  final bool isCompleted;

  /// Mapeia [iconKey] para um [IconData] constante do Material Icons.
  IconData get iconData => switch (iconKey) {
        'water_drop_off' || 'valve' => Icons.plumbing_rounded,
        'faucet' => Icons.water_drop_outlined,
        'power_off' || 'breaker' => Icons.power_off_rounded,
        'bolt_off' => Icons.electrical_services_rounded,
        'gas_meter' => Icons.propane_tank_outlined,
        'window' || 'air' => Icons.air_rounded,
        'no_flash' => Icons.flash_off_rounded,
        'evacuate' || 'exit' => Icons.directions_run_rounded,
        'lock' || 'key' => Icons.vpn_key_off_rounded,
        'roof' || 'bucket' => Icons.roofing_rounded,
        'ac_unit' => Icons.ac_unit_rounded,
        'support' || 'handyman' => Icons.handyman_rounded,
        'shield' => Icons.shield_outlined,
        'warning' => Icons.warning_amber_rounded,
        _ => Icons.health_and_safety_outlined,
      };

  ContainmentStep copyWith({
    int? stepNumber,
    String? title,
    String? description,
    String? iconKey,
    bool? isCriticalSafetyWarning,
    String? safetyWarningBadgeText,
    bool? isCompleted,
  }) =>
      ContainmentStep(
        stepNumber: stepNumber ?? this.stepNumber,
        title: title ?? this.title,
        description: description ?? this.description,
        iconKey: iconKey ?? this.iconKey,
        isCriticalSafetyWarning: isCriticalSafetyWarning ?? this.isCriticalSafetyWarning,
        safetyWarningBadgeText: safetyWarningBadgeText ?? this.safetyWarningBadgeText,
        isCompleted: isCompleted ?? this.isCompleted,
      );

  Map<String, dynamic> toMap() => {
        'stepNumber': stepNumber,
        'title': title,
        'description': description,
        'iconKey': iconKey,
        'isCriticalSafetyWarning': isCriticalSafetyWarning,
        'safetyWarningBadgeText': safetyWarningBadgeText,
        'isCompleted': isCompleted,
      };

  factory ContainmentStep.fromMap(Map<String, dynamic> map) => ContainmentStep(
        stepNumber: (map['stepNumber'] as num?)?.toInt() ?? 1,
        title: (map['title'] as String?) ?? '',
        description: (map['description'] as String?) ?? '',
        iconKey: (map['iconKey'] as String?) ?? 'shield',
        isCriticalSafetyWarning: (map['isCriticalSafetyWarning'] as bool?) ?? false,
        safetyWarningBadgeText: map['safetyWarningBadgeText'] as String?,
        isCompleted: (map['isCompleted'] as bool?) ?? false,
      );

  String toJson() => jsonEncode(toMap());

  factory ContainmentStep.fromJson(String source) =>
      ContainmentStep.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContainmentStep &&
          other.stepNumber == stepNumber &&
          other.title == title &&
          other.description == description &&
          other.iconKey == iconKey &&
          other.isCriticalSafetyWarning == isCriticalSafetyWarning &&
          other.safetyWarningBadgeText == safetyWarningBadgeText &&
          other.isCompleted == isCompleted;

  @override
  int get hashCode => Object.hash(
        stepNumber,
        title,
        description,
        iconKey,
        isCriticalSafetyWarning,
        safetyWarningBadgeText,
        isCompleted,
      );
}

/// Guia interativo de contenção de emergência (Primeiros Socorros do Imóvel).
@immutable
class EmergencyContainmentGuide {
  const EmergencyContainmentGuide({
    required this.id,
    required this.emergencyTypeTitle,
    required this.steps,
    this.targetActionSeconds = 60,
    this.criticalProhibitions = const [],
    this.emergencyPublicPhone,
    this.emergencyPublicLabel,
  });

  final String id;
  final String emergencyTypeTitle;
  final int targetActionSeconds;
  final List<String> criticalProhibitions;
  final List<ContainmentStep> steps;
  final String? emergencyPublicPhone;
  final String? emergencyPublicLabel;

  int get completedStepsCount => steps.where((s) => s.isCompleted).length;

  double get completionProgress =>
      steps.isEmpty ? 1.0 : (completedStepsCount / steps.length).clamp(0.0, 1.0);

  bool get isFullyContained => steps.isNotEmpty && completedStepsCount == steps.length;

  EmergencyContainmentGuide copyWith({
    String? id,
    String? emergencyTypeTitle,
    int? targetActionSeconds,
    List<String>? criticalProhibitions,
    List<ContainmentStep>? steps,
    String? emergencyPublicPhone,
    String? emergencyPublicLabel,
  }) =>
      EmergencyContainmentGuide(
        id: id ?? this.id,
        emergencyTypeTitle: emergencyTypeTitle ?? this.emergencyTypeTitle,
        targetActionSeconds: targetActionSeconds ?? this.targetActionSeconds,
        criticalProhibitions: criticalProhibitions ?? this.criticalProhibitions,
        steps: steps ?? this.steps,
        emergencyPublicPhone: emergencyPublicPhone ?? this.emergencyPublicPhone,
        emergencyPublicLabel: emergencyPublicLabel ?? this.emergencyPublicLabel,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'emergencyTypeTitle': emergencyTypeTitle,
        'targetActionSeconds': targetActionSeconds,
        'criticalProhibitions': criticalProhibitions,
        'steps': steps.map((s) => s.toMap()).toList(),
        'emergencyPublicPhone': emergencyPublicPhone,
        'emergencyPublicLabel': emergencyPublicLabel,
      };

  factory EmergencyContainmentGuide.fromMap(Map<String, dynamic> map) =>
      EmergencyContainmentGuide(
        id: (map['id'] as String?) ?? '',
        emergencyTypeTitle: (map['emergencyTypeTitle'] as String?) ?? '',
        targetActionSeconds: (map['targetActionSeconds'] as num?)?.toInt() ?? 60,
        criticalProhibitions:
            ((map['criticalProhibitions'] as List?) ?? const []).cast<String>(),
        steps: ((map['steps'] as List?) ?? const [])
            .map((e) => ContainmentStep.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        emergencyPublicPhone: map['emergencyPublicPhone'] as String?,
        emergencyPublicLabel: map['emergencyPublicLabel'] as String?,
      );

  String toJson() => jsonEncode(toMap());

  factory EmergencyContainmentGuide.fromJson(String source) =>
      EmergencyContainmentGuide.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmergencyContainmentGuide &&
          other.id == id &&
          other.emergencyTypeTitle == emergencyTypeTitle &&
          other.targetActionSeconds == targetActionSeconds &&
          listEquals(other.criticalProhibitions, criticalProhibitions) &&
          listEquals(other.steps, steps) &&
          other.emergencyPublicPhone == emergencyPublicPhone &&
          other.emergencyPublicLabel == emergencyPublicLabel;

  @override
  int get hashCode => Object.hash(
        id,
        emergencyTypeTitle,
        targetActionSeconds,
        Object.hashAll(criticalProhibitions),
        Object.hashAll(steps),
        emergencyPublicPhone,
        emergencyPublicLabel,
      );
}

/// Resultado consolidado da Triagem Inteligente Multimodal.
@immutable
class SmartTriageResult {
  const SmartTriageResult({
    required this.id,
    required this.analyzedAt,
    required this.suggestedCategoryId,
    required this.suggestedCategoryName,
    required this.urgencyLevel,
    required this.diagnosticSummary,
    required this.probableRootCause,
    required this.estimatedDurationRange,
    required this.confidenceScore,
    required this.probableMaterials,
    required this.recommendedProviderTools,
    this.containmentGuide,
  });

  final String id;
  final DateTime analyzedAt;
  final String suggestedCategoryId;
  final String suggestedCategoryName;
  final UrgencyLevel urgencyLevel;
  final String diagnosticSummary;
  final String probableRootCause;
  final String estimatedDurationRange;
  final double confidenceScore;
  final List<ProbableMaterialItem> probableMaterials;
  final List<String> recommendedProviderTools;
  final EmergencyContainmentGuide? containmentGuide;

  List<ProbableMaterialItem> get materialsProviderMustBring =>
      probableMaterials.where((m) => !m.clientAlreadyHasIt).toList(growable: false);

  List<ProbableMaterialItem> get materialsClientProvides =>
      probableMaterials.where((m) => m.clientAlreadyHasIt).toList(growable: false);

  bool get hasEmergencyContainment => containmentGuide != null;

  SmartTriageResult toggleMaterial(String materialId) => copyWith(
        probableMaterials: [
          for (final item in probableMaterials)
            if (item.id == materialId)
              item.copyWith(clientAlreadyHasIt: !item.clientAlreadyHasIt)
            else
              item,
        ],
      );

  SmartTriageResult toggleContainmentStep(int stepNumber) {
    final guide = containmentGuide;
    if (guide == null) return this;
    return copyWith(
      containmentGuide: guide.copyWith(
        steps: [
          for (final step in guide.steps)
            if (step.stepNumber == stepNumber)
              step.copyWith(isCompleted: !step.isCompleted)
            else
              step,
        ],
      ),
    );
  }

  SmartTriageResult copyWith({
    String? id,
    DateTime? analyzedAt,
    String? suggestedCategoryId,
    String? suggestedCategoryName,
    UrgencyLevel? urgencyLevel,
    String? diagnosticSummary,
    String? probableRootCause,
    String? estimatedDurationRange,
    double? confidenceScore,
    List<ProbableMaterialItem>? probableMaterials,
    List<String>? recommendedProviderTools,
    EmergencyContainmentGuide? containmentGuide,
    bool clearContainmentGuide = false,
  }) =>
      SmartTriageResult(
        id: id ?? this.id,
        analyzedAt: analyzedAt ?? this.analyzedAt,
        suggestedCategoryId: suggestedCategoryId ?? this.suggestedCategoryId,
        suggestedCategoryName: suggestedCategoryName ?? this.suggestedCategoryName,
        urgencyLevel: urgencyLevel ?? this.urgencyLevel,
        diagnosticSummary: diagnosticSummary ?? this.diagnosticSummary,
        probableRootCause: probableRootCause ?? this.probableRootCause,
        estimatedDurationRange: estimatedDurationRange ?? this.estimatedDurationRange,
        confidenceScore: confidenceScore ?? this.confidenceScore,
        probableMaterials: probableMaterials ?? this.probableMaterials,
        recommendedProviderTools: recommendedProviderTools ?? this.recommendedProviderTools,
        containmentGuide:
            clearContainmentGuide ? null : (containmentGuide ?? this.containmentGuide),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'analyzedAt': analyzedAt.toUtc().toIso8601String(),
        'suggestedCategoryId': suggestedCategoryId,
        'suggestedCategoryName': suggestedCategoryName,
        'urgencyLevel': urgencyLevel.wire,
        'diagnosticSummary': diagnosticSummary,
        'probableRootCause': probableRootCause,
        'estimatedDurationRange': estimatedDurationRange,
        'confidenceScore': confidenceScore,
        'probableMaterials': probableMaterials.map((m) => m.toMap()).toList(),
        'recommendedProviderTools': recommendedProviderTools,
        'containmentGuide': containmentGuide?.toMap(),
      };

  factory SmartTriageResult.fromMap(Map<String, dynamic> map) => SmartTriageResult(
        id: (map['id'] as String?) ?? 'triage',
        analyzedAt: map['analyzedAt'] is String
            ? (DateTime.tryParse(map['analyzedAt'] as String)?.toLocal() ??
                DateTime.fromMillisecondsSinceEpoch(0))
            : DateTime.fromMillisecondsSinceEpoch(0),
        suggestedCategoryId: (map['suggestedCategoryId'] as String?) ?? 'pequenos reparos',
        suggestedCategoryName:
            (map['suggestedCategoryName'] as String?) ?? 'Pequenos Reparos',
        urgencyLevel: UrgencyLevel.parse(map['urgencyLevel'] as String?),
        diagnosticSummary: (map['diagnosticSummary'] as String?) ?? '',
        probableRootCause: (map['probableRootCause'] as String?) ?? '',
        estimatedDurationRange: (map['estimatedDurationRange'] as String?) ?? '45 a 90 min',
        confidenceScore: ((map['confidenceScore'] as num?)?.toDouble() ?? 0.85).clamp(0.0, 1.0),
        probableMaterials: ((map['probableMaterials'] as List?) ?? const [])
            .map((e) => ProbableMaterialItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        recommendedProviderTools:
            ((map['recommendedProviderTools'] as List?) ?? const []).cast<String>(),
        containmentGuide: map['containmentGuide'] is Map
            ? EmergencyContainmentGuide.fromMap(
                Map<String, dynamic>.from(map['containmentGuide'] as Map))
            : null,
      );

  String toJson() => jsonEncode(toMap());

  factory SmartTriageResult.fromJson(String source) =>
      SmartTriageResult.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmartTriageResult &&
          other.id == id &&
          other.analyzedAt.millisecondsSinceEpoch ==
              analyzedAt.millisecondsSinceEpoch &&
          other.suggestedCategoryId == suggestedCategoryId &&
          other.suggestedCategoryName == suggestedCategoryName &&
          other.urgencyLevel == urgencyLevel &&
          other.diagnosticSummary == diagnosticSummary &&
          other.probableRootCause == probableRootCause &&
          other.estimatedDurationRange == estimatedDurationRange &&
          other.confidenceScore == confidenceScore &&
          listEquals(other.probableMaterials, probableMaterials) &&
          listEquals(other.recommendedProviderTools, recommendedProviderTools) &&
          other.containmentGuide == containmentGuide;

  @override
  int get hashCode => Object.hash(
        id,
        analyzedAt.millisecondsSinceEpoch,
        suggestedCategoryId,
        suggestedCategoryName,
        urgencyLevel,
        diagnosticSummary,
        probableRootCause,
        estimatedDurationRange,
        confidenceScore,
        Object.hashAll(probableMaterials),
        Object.hashAll(recommendedProviderTools),
        containmentGuide,
      );
}

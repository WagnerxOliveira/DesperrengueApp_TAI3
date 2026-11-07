import 'package:flutter/foundation.dart';

/// Registro imutável de um serviço concluído e validado via PIN do Cliente.
///
/// Regra arquitetural:
/// - Todo serviço validado pelo PIN do cliente entra permanentemente no
///   **Histórico de Serviços Prestados** ([ProviderPortfolioState.fullHistory]).
/// - Nenhum item de [fullHistory] pode jamais ser apagado.
/// - Quando o cliente avalia o serviço posteriormente, os campos de avaliação
///   ([isReviewedByClient], [clientRating], [clientReviewComment], [clientPraiseTags],
///   [clientReviewedAt]) são sincronizados reativamente tanto no Histórico quanto
///   no Meu Portfólio.
@immutable
class CompletedServiceRecord {
  const CompletedServiceRecord({
    required this.id,
    required this.orderId,
    required this.title,
    required this.categoryName,
    required this.detailedExecutionReport,
    required this.cityAndState,
    required this.completedAt,
    required this.validatedClientPin,
    required this.serviceValue,
    required this.executionDurationText,
    this.toolsAndMaterialsUsed = const <String>[],
    this.beforeAfterPhotoCaptionsOrUrls = const <String>[],
    required this.warrantyCertificateCode,
    this.isReviewedByClient = false,
    this.clientRating,
    this.clientReviewComment,
    this.clientPraiseTags = const <String>[],
    this.clientReviewedAt,
    this.clientDisplayName,
  });

  final String id;
  final String orderId;
  final String title;
  final String categoryName;
  final String detailedExecutionReport;
  final String cityAndState;
  final DateTime completedAt;
  final String validatedClientPin;
  final double serviceValue;
  final String executionDurationText;
  final List<String> toolsAndMaterialsUsed;
  final List<String> beforeAfterPhotoCaptionsOrUrls;
  final String warrantyCertificateCode;

  // Sincronização Reativa da Avaliação do Cliente (pode chegar minutos ou dias após o PIN)
  final bool isReviewedByClient;
  final double? clientRating;
  final String? clientReviewComment;
  final List<String> clientPraiseTags;
  final DateTime? clientReviewedAt;
  final String? clientDisplayName;

  CompletedServiceRecord copyWith({
    String? id,
    String? orderId,
    String? title,
    String? categoryName,
    String? detailedExecutionReport,
    String? cityAndState,
    DateTime? completedAt,
    String? validatedClientPin,
    double? serviceValue,
    String? executionDurationText,
    List<String>? toolsAndMaterialsUsed,
    List<String>? beforeAfterPhotoCaptionsOrUrls,
    String? warrantyCertificateCode,
    bool? isReviewedByClient,
    double? clientRating,
    String? clientReviewComment,
    List<String>? clientPraiseTags,
    DateTime? clientReviewedAt,
    String? clientDisplayName,
  }) {
    return CompletedServiceRecord(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      title: title ?? this.title,
      categoryName: categoryName ?? this.categoryName,
      detailedExecutionReport:
          detailedExecutionReport ?? this.detailedExecutionReport,
      cityAndState: cityAndState ?? this.cityAndState,
      completedAt: completedAt ?? this.completedAt,
      validatedClientPin: validatedClientPin ?? this.validatedClientPin,
      serviceValue: serviceValue ?? this.serviceValue,
      executionDurationText:
          executionDurationText ?? this.executionDurationText,
      toolsAndMaterialsUsed:
          toolsAndMaterialsUsed ?? this.toolsAndMaterialsUsed,
      beforeAfterPhotoCaptionsOrUrls:
          beforeAfterPhotoCaptionsOrUrls ?? this.beforeAfterPhotoCaptionsOrUrls,
      warrantyCertificateCode:
          warrantyCertificateCode ?? this.warrantyCertificateCode,
      isReviewedByClient: isReviewedByClient ?? this.isReviewedByClient,
      clientRating: clientRating ?? this.clientRating,
      clientReviewComment: clientReviewComment ?? this.clientReviewComment,
      clientPraiseTags: clientPraiseTags ?? this.clientPraiseTags,
      clientReviewedAt: clientReviewedAt ?? this.clientReviewedAt,
      clientDisplayName: clientDisplayName ?? this.clientDisplayName,
    );
  }
}

/// Estado completo do sistema **"Meu Portfólio" Inteligente + "Histórico de Serviços Prestados"**.
@immutable
class ProviderPortfolioState {
  const ProviderPortfolioState({
    this.fullHistory = const <CompletedServiceRecord>[],
    this.curatedPortfolioIds = const <String>[],
  });

  /// Lista completa e permanente de todos os serviços já validados via PIN do cliente,
  /// ordenada do mais recente para o mais antigo (`b.completedAt.compareTo(a.completedAt)`).
  /// REGRA IMUTÁVEL: Nenhum serviço em [fullHistory] pode jamais ser excluído.
  final List<CompletedServiceRecord> fullHistory;

  /// IDs (máximo de 3) escolhidos manualmente pelo profissional a partir de [eligibleHistoryPool].
  final List<String> curatedPortfolioIds;

  /// Os 3 últimos serviços realizados e validados via PIN (`fullHistory.take(3).toList()`).
  List<CompletedServiceRecord> get automaticTopThree =>
      fullHistory.take(3).toList(growable: false);

  /// Serviços do histórico que já saíram dos 3 mais recentes (`fullHistory.skip(3).toList()`).
  /// O profissional só pode escolher destaques a partir deste pool.
  List<CompletedServiceRecord> get eligibleHistoryPool =>
      fullHistory.length > 3
          ? fullHistory.skip(3).toList(growable: false)
          : const <CompletedServiceRecord>[];

  /// Serviços efetivamente exibidos na seção "Destaques Escolhidos do Meu Histórico (Até 3 serviços)".
  /// Garante que apenas serviços pertencentes ao [eligibleHistoryPool] apareçam aqui e no máximo 3.
  List<CompletedServiceRecord> get curatedPortfolioServices {
    if (eligibleHistoryPool.isEmpty || curatedPortfolioIds.isEmpty) {
      return const <CompletedServiceRecord>[];
    }
    final byId = <String, CompletedServiceRecord>{
      for (final s in eligibleHistoryPool) s.id: s,
    };
    final result = <CompletedServiceRecord>[];
    for (final id in curatedPortfolioIds) {
      final item = byId[id];
      if (item != null && result.length < 3) {
        result.add(item);
      }
    }
    return result;
  }

  /// Serviços elegíveis do histórico que ainda não estão fixados na vitrine de destaques.
  List<CompletedServiceRecord> get availableToCurate {
    final activeIds = curatedPortfolioServices.map((s) => s.id).toSet();
    return eligibleHistoryPool
        .where((s) => !activeIds.contains(s.id))
        .toList(growable: false);
  }

  /// Total de serviços concluídos e validados via PIN.
  int get totalCompletedCount => fullHistory.length;

  /// A opção de adicionar serviços do histórico ao portfólio só é desbloqueada a partir do 4º serviço concluído.
  /// Para 0, 1, 2 ou 3 serviços concluídos, retorna `false`.
  bool get isAddFromHistoryUnlocked => totalCompletedCount >= 4;

  /// Verdadeiro quando o botão de adicionar (+1 por vez) está desbloqueado, há vagas (< 3) e existem itens disponíveis no histórico elegível.
  bool get canAddMoreCuratedServices =>
      isAddFromHistoryUnlocked &&
      curatedPortfolioServices.length < 3 &&
      availableToCurate.isNotEmpty;

  /// Verifica se um serviço está atualmente no Top 3 automático.
  bool isInAutomaticTopThree(String serviceId) =>
      automaticTopThree.any((s) => s.id == serviceId);

  /// Verifica se um serviço está atualmente nos Destaques Escolhidos.
  bool isInCuratedPortfolio(String serviceId) =>
      curatedPortfolioServices.any((s) => s.id == serviceId);

  ProviderPortfolioState copyWith({
    List<CompletedServiceRecord>? fullHistory,
    List<String>? curatedPortfolioIds,
  }) {
    final sorted = List<CompletedServiceRecord>.from(
      fullHistory ?? this.fullHistory,
    )..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    final top3Ids = sorted.take(3).map((s) => s.id).toSet();
    final eligibleIds = sorted.skip(3).map((s) => s.id).toSet();
    final nextCurated = <String>[];
    for (final id in (curatedPortfolioIds ?? this.curatedPortfolioIds)) {
      if (!top3Ids.contains(id) &&
          eligibleIds.contains(id) &&
          !nextCurated.contains(id) &&
          nextCurated.length < 3) {
        nextCurated.add(id);
      }
    }
    return ProviderPortfolioState(
      fullHistory: List<CompletedServiceRecord>.unmodifiable(sorted),
      curatedPortfolioIds: List<String>.unmodifiable(nextCurated),
    );
  }
}

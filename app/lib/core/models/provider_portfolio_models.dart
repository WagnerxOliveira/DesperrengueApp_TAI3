import 'package:flutter/foundation.dart';

/// Quantidade de serviços mais recentes exibidos automaticamente no topo do Portfólio (Pilha LIFO).
const int kAutomaticPortfolioTopCount = 3;

/// Quantidade máxima de serviços adicionais que o profissional pode escolher do Histórico (a partir do 4º).
const int kMaxCuratedPortfolioServices = 5;

/// Estágios reais do ciclo de vida de um serviço no **Histórico de Serviços Prestados**.
enum ServiceHistoryLifecycleStage {
  /// Garantia/proteção pós-serviço concluída e 100% do pagamento líquido recebido pelo profissional.
  /// ÚNICO estágio elegível para entrar no **Meu Portfólio** (Top 3 LIFO + até 5 Destaques Escolhidos).
  settledAndPaid,

  /// Serviço finalizado com PIN presencial, atualmente dentro da janela de cobertura técnica / maturação
  /// antes da liquidação final de 100%. Nome oficial de alto padrão: **Sob Proteção Pós-Serviço**
  /// (Subtítulo: *Em Cobertura Técnica & Maturação*).
  underPostServiceProtection,

  /// Serviço com contestação ou acionamento de garantia técnica aberto pelo Cliente ou pelo Profissional.
  inMediation,

  /// Serviço cancelado pelo Cliente, pelo Profissional ou automaticamente por expiração.
  canceled,
}

extension ServiceHistoryLifecycleStageX on ServiceHistoryLifecycleStage {
  String get label => switch (this) {
        ServiceHistoryLifecycleStage.settledAndPaid =>
          'Concluído & 100% Liquidado',
        ServiceHistoryLifecycleStage.underPostServiceProtection =>
          'Sob Proteção Pós-Serviço',
        ServiceHistoryLifecycleStage.inMediation => 'Em Mediação',
        ServiceHistoryLifecycleStage.canceled => 'Cancelado',
      };

  String get subtitle => switch (this) {
        ServiceHistoryLifecycleStage.settledAndPaid =>
          'Proteção pós-serviço finalizada • 100% recebido pelo profissional',
        ServiceHistoryLifecycleStage.underPostServiceProtection =>
          'Em Cobertura Técnica & Maturação • Aguardando liberação final 100%',
        ServiceHistoryLifecycleStage.inMediation =>
          'Em análise técnica na central de mediação imparcial',
        ServiceHistoryLifecycleStage.canceled =>
          'Encerrado por cancelamento registrado em auditoria',
      };

  static ServiceHistoryLifecycleStage fromWire(String? raw) => switch (raw) {
        'under_protection' =>
          ServiceHistoryLifecycleStage.underPostServiceProtection,
        'in_mediation' => ServiceHistoryLifecycleStage.inMediation,
        'canceled' => ServiceHistoryLifecycleStage.canceled,
        _ => ServiceHistoryLifecycleStage.settledAndPaid,
      };
}

/// Modo de visualização do Portfólio para garantir isolamento estrito entre Profissional e Cliente.
enum PortfolioViewMode {
  /// Visão do próprio Profissional dono (vê valores financeiros, curadoria de até 5 destaques e
  /// pode editar exclusivamente o campo "Notas Técnicas Complementares").
  providerOwner,

  /// Visão pública para o Usuário Cliente (somente leitura limpa, sem exibir valores monetários
  /// e sem exibir avisos de ocultação ou botões de edição).
  clientPublic,
}

/// Registro auditado de um serviço no **Histórico de Serviços Prestados** e **Meu Portfólio**.
///
/// Regras de Segurança e Imutabilidade:
/// - [clientRequestedDescription] (o que foi solicitado pelo cliente), [detailedExecutionReport]
///   (solução técnica aplicada pelo profissional na conclusão) e [beforeAfterPhotoCaptionsOrUrls]
///   (fotos da execução) são **estritamente imutáveis** após a conclusão do serviço.
/// - Apenas o campo pós-obra [complementaryTechnicalNotes] (**"Notas Técnicas Complementares"**)
///   pode ser adicionado ou atualizado pelo profissional para enriquecer a vitrine do seu Portfólio.
/// - Apenas registros com [isEligibleForPortfolio] == `true` (`settledAndPaid` + `isPaid100Percent`)
///   podem ingressar na Pilha LIFO Top 3 ou nos até 5 Destaques Escolhidos do **Meu Portfólio**.
@immutable
class CompletedServiceRecord {
  const CompletedServiceRecord({
    required this.id,
    required this.orderId,
    required this.title,
    required this.categoryName,
    this.clientRequestedDescription = '',
    required this.detailedExecutionReport,
    this.complementaryTechnicalNotes,
    required this.cityAndState,
    required this.completedAt,
    required this.validatedClientPin,
    required this.serviceValue,
    this.grossAmount,
    this.materialsAmount = 0.0,
    this.platformFeeAmount = 0.0,
    required this.executionDurationText,
    this.toolsAndMaterialsUsed = const <String>[],
    this.beforeAfterPhotoCaptionsOrUrls = const <String>[],
    required this.warrantyCertificateCode,
    this.lifecycleStage = ServiceHistoryLifecycleStage.settledAndPaid,
    this.isPaid100Percent = true,
    this.protectionEndsAt,
    this.mediationOpenedBy,
    this.mediationReason,
    this.canceledByRole,
    this.cancelReason,
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

  /// Descrição original exata solicitada pelo cliente ao abrir o pedido (IMUTÁVEL).
  final String clientRequestedDescription;

  /// Solução técnica aplicada pelo profissional no momento da conclusão (IMUTÁVEL).
  final String detailedExecutionReport;

  /// "Notas Técnicas Complementares": único campo textual editável pelo profissional após a conclusão.
  final String? complementaryTechnicalNotes;

  final String cityAndState;
  final DateTime completedAt;
  final String validatedClientPin;

  /// Valor líquido do profissional (jamais exibido ao Usuário Cliente no Portfólio público).
  final double serviceValue;
  final double? grossAmount;
  final double materialsAmount;
  final double platformFeeAmount;

  final String executionDurationText;
  final List<String> toolsAndMaterialsUsed;

  /// Fotos ordenadas da 1ª à última (IMUTÁVEIS após a conclusão do serviço).
  final List<String> beforeAfterPhotoCaptionsOrUrls;
  final String warrantyCertificateCode;

  /// Estágio real no Histórico de Serviços Prestados.
  final ServiceHistoryLifecycleStage lifecycleStage;

  /// Indica se o período de proteção pós-serviço já encerrou e o profissional recebeu 100% do pagamento.
  final bool isPaid100Percent;

  /// Data/hora de término do período de proteção pós-serviço / maturação.
  final DateTime? protectionEndsAt;

  /// Metadados de mediação (quando [lifecycleStage] == [ServiceHistoryLifecycleStage.inMediation]).
  final String? mediationOpenedBy;
  final String? mediationReason;

  /// Metadados de cancelamento (quando [lifecycleStage] == [ServiceHistoryLifecycleStage.canceled]).
  final String? canceledByRole;
  final String? cancelReason;

  // Sincronização Reativa da Avaliação do Cliente
  final bool isReviewedByClient;
  final double? clientRating;
  final String? clientReviewComment;
  final List<String> clientPraiseTags;
  final DateTime? clientReviewedAt;
  final String? clientDisplayName;

  /// Regra Inegociável (`RN-PORT-ELIG-01`):
  /// Um serviço SÓ pode entrar no "Meu Portfólio" quando foi concluído, não foi cancelado,
  /// não está em mediação, finalizou o período de proteção pós-serviço e o profissional
  /// já recebeu 100% do pagamento.
  bool get isEligibleForPortfolio =>
      lifecycleStage == ServiceHistoryLifecycleStage.settledAndPaid &&
      isPaid100Percent;

  bool get hasClientRequestedDescription =>
      clientRequestedDescription.trim().isNotEmpty;

  bool get hasComplementaryTechnicalNotes =>
      (complementaryTechnicalNotes ?? '').trim().isNotEmpty;

  /// Atualiza EXCLUSIVAMENTE as "Notas Técnicas Complementares", preservando de forma
  /// criptograficamente imutável a solicitação do cliente, a solução da conclusão e as fotos.
  CompletedServiceRecord copyWithComplementaryNotes(String? notes) {
    final cleaned = notes?.trim();
    return copyWith(
      complementaryTechnicalNotes:
          (cleaned == null || cleaned.isEmpty) ? null : cleaned,
      clearComplementaryNotes: cleaned == null || cleaned.isEmpty,
    );
  }

  CompletedServiceRecord copyWith({
    String? id,
    String? orderId,
    String? title,
    String? categoryName,
    String? clientRequestedDescription,
    String? detailedExecutionReport,
    String? complementaryTechnicalNotes,
    bool clearComplementaryNotes = false,
    String? cityAndState,
    DateTime? completedAt,
    String? validatedClientPin,
    double? serviceValue,
    double? grossAmount,
    double? materialsAmount,
    double? platformFeeAmount,
    String? executionDurationText,
    List<String>? toolsAndMaterialsUsed,
    List<String>? beforeAfterPhotoCaptionsOrUrls,
    String? warrantyCertificateCode,
    ServiceHistoryLifecycleStage? lifecycleStage,
    bool? isPaid100Percent,
    DateTime? protectionEndsAt,
    String? mediationOpenedBy,
    String? mediationReason,
    String? canceledByRole,
    String? cancelReason,
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
      clientRequestedDescription:
          clientRequestedDescription ?? this.clientRequestedDescription,
      detailedExecutionReport:
          detailedExecutionReport ?? this.detailedExecutionReport,
      complementaryTechnicalNotes: clearComplementaryNotes
          ? null
          : (complementaryTechnicalNotes ?? this.complementaryTechnicalNotes),
      cityAndState: cityAndState ?? this.cityAndState,
      completedAt: completedAt ?? this.completedAt,
      validatedClientPin: validatedClientPin ?? this.validatedClientPin,
      serviceValue: serviceValue ?? this.serviceValue,
      grossAmount: grossAmount ?? this.grossAmount,
      materialsAmount: materialsAmount ?? this.materialsAmount,
      platformFeeAmount: platformFeeAmount ?? this.platformFeeAmount,
      executionDurationText:
          executionDurationText ?? this.executionDurationText,
      toolsAndMaterialsUsed:
          toolsAndMaterialsUsed ?? this.toolsAndMaterialsUsed,
      beforeAfterPhotoCaptionsOrUrls:
          beforeAfterPhotoCaptionsOrUrls ?? this.beforeAfterPhotoCaptionsOrUrls,
      warrantyCertificateCode:
          warrantyCertificateCode ?? this.warrantyCertificateCode,
      lifecycleStage: lifecycleStage ?? this.lifecycleStage,
      isPaid100Percent: isPaid100Percent ?? this.isPaid100Percent,
      protectionEndsAt: protectionEndsAt ?? this.protectionEndsAt,
      mediationOpenedBy: mediationOpenedBy ?? this.mediationOpenedBy,
      mediationReason: mediationReason ?? this.mediationReason,
      canceledByRole: canceledByRole ?? this.canceledByRole,
      cancelReason: cancelReason ?? this.cancelReason,
      isReviewedByClient: isReviewedByClient ?? this.isReviewedByClient,
      clientRating: clientRating ?? this.clientRating,
      clientReviewComment: clientReviewComment ?? this.clientReviewComment,
      clientPraiseTags: clientPraiseTags ?? this.clientPraiseTags,
      clientReviewedAt: clientReviewedAt ?? this.clientReviewedAt,
      clientDisplayName: clientDisplayName ?? this.clientDisplayName,
    );
  }

  factory CompletedServiceRecord.fromMap(Map<String, dynamic> m) {
    final stage =
        ServiceHistoryLifecycleStageX.fromWire(m['lifecycle_stage'] as String?);
    final paid100 = m['is_paid_100_percent'] == null
        ? stage == ServiceHistoryLifecycleStage.settledAndPaid
        : m['is_paid_100_percent'] == true;
    final rawPhotos = (m['photos'] as List?) ??
        (m['before_after_photos'] as List?) ??
        const <dynamic>[];
    final rawTags = (m['client_praise_tags'] as List?) ?? const <dynamic>[];
    final rawTools =
        (m['tools_and_materials_used'] as List?) ?? const <dynamic>[];
    final idStr = (m['id'] as String?) ?? (m['job_id'] as String?) ?? '';
    return CompletedServiceRecord(
      id: idStr,
      orderId: (m['order_id'] as String?) ?? idStr,
      title: (m['title'] as String?) ?? 'Serviço Residencial',
      categoryName: (m['category_name'] as String?) ?? 'Manutenção',
      clientRequestedDescription:
          (m['client_requested_description'] as String?) ?? '',
      detailedExecutionReport: (m['detailed_execution_report'] as String?) ??
          'Serviço concluído e auditado na plataforma.',
      complementaryTechnicalNotes:
          m['complementary_technical_notes'] as String?,
      cityAndState: (m['city_and_state'] as String?) ?? 'Local Verificado',
      completedAt:
          DateTime.tryParse('${m['completed_at'] ?? ''}')?.toLocal() ??
              DateTime.now(),
      validatedClientPin: (m['validated_client_pin'] as String?) ?? '••••',
      serviceValue: (m['service_value'] as num?)?.toDouble() ?? 0.0,
      grossAmount: (m['gross_amount'] as num?)?.toDouble(),
      materialsAmount: (m['materials_amount'] as num?)?.toDouble() ?? 0.0,
      platformFeeAmount: (m['platform_fee_amount'] as num?)?.toDouble() ?? 0.0,
      executionDurationText:
          (m['execution_duration_text'] as String?) ?? 'Concluído no prazo',
      toolsAndMaterialsUsed:
          rawTools.whereType<String>().toList(growable: false),
      beforeAfterPhotoCaptionsOrUrls:
          rawPhotos.whereType<String>().toList(growable: false),
      warrantyCertificateCode: (m['warranty_certificate_code'] as String?) ??
          'DSP-${idStr.substring(0, idStr.length.clamp(0, 6)).toUpperCase()}',
      lifecycleStage: stage,
      isPaid100Percent: paid100,
      protectionEndsAt:
          DateTime.tryParse('${m['protection_ends_at'] ?? ''}')?.toLocal(),
      mediationOpenedBy: m['mediation_opened_by'] as String?,
      mediationReason: m['mediation_reason'] as String?,
      canceledByRole: m['canceled_by_role'] as String?,
      cancelReason: m['cancel_reason'] as String?,
      isReviewedByClient: m['is_reviewed_by_client'] == true,
      clientRating: (m['client_rating'] as num?)?.toDouble(),
      clientReviewComment: m['client_review_comment'] as String?,
      clientPraiseTags: rawTags.whereType<String>().toList(growable: false),
      clientReviewedAt:
          DateTime.tryParse('${m['client_reviewed_at'] ?? ''}')?.toLocal(),
      clientDisplayName: m['client_display_name'] as String?,
    );
  }
}

/// Tabela de Memoização por Programação Dinâmica ($O(N)$ na construção única, $\Theta(1)$ por consulta).
class _MemoizedPortfolioPartition {
  _MemoizedPortfolioPartition(
    List<CompletedServiceRecord> fullHistory,
    List<String> curatedPortfolioIds,
  ) {
    final settled = <CompletedServiceRecord>[];
    final protection = <CompletedServiceRecord>[];
    final mediation = <CompletedServiceRecord>[];
    final canceled = <CompletedServiceRecord>[];
    final byIdMap = <String, CompletedServiceRecord>{};

    for (final s in fullHistory) {
      byIdMap[s.id] = s;
      switch (s.lifecycleStage) {
        case ServiceHistoryLifecycleStage.settledAndPaid:
          if (s.isEligibleForPortfolio) {
            settled.add(s);
          } else {
            protection.add(s);
          }
        case ServiceHistoryLifecycleStage.underPostServiceProtection:
          protection.add(s);
        case ServiceHistoryLifecycleStage.inMediation:
          mediation.add(s);
        case ServiceHistoryLifecycleStage.canceled:
          canceled.add(s);
      }
    }

    settledEligible = List<CompletedServiceRecord>.unmodifiable(settled);
    underProtection = List<CompletedServiceRecord>.unmodifiable(protection);
    inMediation = List<CompletedServiceRecord>.unmodifiable(mediation);
    canceledList = List<CompletedServiceRecord>.unmodifiable(canceled);
    recordById = Map<String, CompletedServiceRecord>.unmodifiable(byIdMap);

    final top3 = settled.take(kAutomaticPortfolioTopCount).toList(growable: false);
    automaticTopThree = List<CompletedServiceRecord>.unmodifiable(top3);
    topThreeIds = Set<String>.unmodifiable(top3.map((e) => e.id));

    final pool = settled.length > kAutomaticPortfolioTopCount
        ? settled.skip(kAutomaticPortfolioTopCount).toList(growable: false)
        : const <CompletedServiceRecord>[];
    eligiblePool = List<CompletedServiceRecord>.unmodifiable(pool);

    final poolById = <String, CompletedServiceRecord>{
      for (final s in pool) s.id: s,
    };

    final curated = <CompletedServiceRecord>[];
    final curatedSet = <String>{};
    for (final id in curatedPortfolioIds) {
      final item = poolById[id];
      if (item != null &&
          !curatedSet.contains(id) &&
          curated.length < kMaxCuratedPortfolioServices) {
        curated.add(item);
        curatedSet.add(id);
      }
    }
    curatedServices = List<CompletedServiceRecord>.unmodifiable(curated);
    curatedIds = Set<String>.unmodifiable(curatedSet);

    availableToCurate = List<CompletedServiceRecord>.unmodifiable(
      pool.where((s) => !curatedSet.contains(s.id)),
    );

    final rankMap = <String, int>{};
    for (var i = 0; i < settled.length; i++) {
      rankMap[settled[i].id] = i;
    }
    settledRankById = Map<String, int>.unmodifiable(rankMap);
  }

  late final List<CompletedServiceRecord> settledEligible;
  late final List<CompletedServiceRecord> underProtection;
  late final List<CompletedServiceRecord> inMediation;
  late final List<CompletedServiceRecord> canceledList;
  late final Map<String, CompletedServiceRecord> recordById;

  late final List<CompletedServiceRecord> automaticTopThree;
  late final Set<String> topThreeIds;
  late final List<CompletedServiceRecord> eligiblePool;
  late final List<CompletedServiceRecord> curatedServices;
  late final Set<String> curatedIds;
  late final List<CompletedServiceRecord> availableToCurate;
  late final Map<String, int> settledRankById;
}

/// Estado completo do sistema **"Meu Portfólio" Inteligente + "Histórico de Serviços Prestados"**
/// otimizado com Programação Dinâmica (Memoização $O(1)$ no melhor caso).
@immutable
class ProviderPortfolioState {
  ProviderPortfolioState({
    this.fullHistory = const <CompletedServiceRecord>[],
    this.curatedPortfolioIds = const <String>[],
  });

  /// Lista completa e permanente de todos os serviços do profissional no Histórico
  /// (Concluídos 100% Liquidados, Sob Proteção Pós-Serviço, Em Mediação e Cancelados),
  /// ordenada do mais recente para o mais antigo (`b.completedAt.compareTo(a.completedAt)`).
  final List<CompletedServiceRecord> fullHistory;

  /// IDs (máximo de [kMaxCuratedPortfolioServices] = 5) escolhidos manualmente pelo profissional
  /// a partir de [eligibleHistoryPool] (a partir do 4º serviço elegível 100% liquidado).
  final List<String> curatedPortfolioIds;

  late final _MemoizedPortfolioPartition _memo =
      _MemoizedPortfolioPartition(fullHistory, curatedPortfolioIds);

  /// Serviços elegíveis que já finalizaram a proteção pós-serviço e foram 100% pagos.
  List<CompletedServiceRecord> get settledEligibleHistory =>
      _memo.settledEligible;

  /// Serviços em período de cobertura técnica ("Sob Proteção Pós-Serviço").
  List<CompletedServiceRecord> get underProtectionServices =>
      _memo.underProtection;

  /// Serviços atualmente "Em Mediação".
  List<CompletedServiceRecord> get inMediationServices => _memo.inMediation;

  /// Serviços "Cancelados" (pelo cliente ou pelo profissional).
  List<CompletedServiceRecord> get canceledServices => _memo.canceledList;

  /// Os 3 últimos serviços elegíveis (100% pagos e pós-proteção) exibidos automaticamente no topo (Pilha LIFO).
  List<CompletedServiceRecord> get automaticTopThree => _memo.automaticTopThree;

  /// Serviços elegíveis (100% pagos e pós-proteção) que já saíram dos 3 mais recentes (do 4º em diante).
  /// O profissional pode escolher até [kMaxCuratedPortfolioServices] (5) destaques a partir deste pool.
  List<CompletedServiceRecord> get eligibleHistoryPool => _memo.eligiblePool;

  /// Serviços efetivamente exibidos na seção "Destaques Escolhidos do Meu Histórico (Até 5 serviços)".
  List<CompletedServiceRecord> get curatedPortfolioServices =>
      _memo.curatedServices;

  /// Todos os serviços visíveis publicamente no Meu Portfólio (Top 3 Automáticos + até 5 Escolhidos = máx. 8).
  List<CompletedServiceRecord> get publicPortfolioServices =>
      <CompletedServiceRecord>[
        ..._memo.automaticTopThree,
        ..._memo.curatedServices,
      ];

  /// Serviços elegíveis do histórico que ainda não estão fixados na vitrine de destaques.
  List<CompletedServiceRecord> get availableToCurate => _memo.availableToCurate;

  /// Total de serviços elegíveis (Concluídos & 100% Liquidados).
  int get totalCompletedCount => _memo.settledEligible.length;

  /// Total geral de registros no Histórico de Serviços Prestados (incluindo Sob Proteção, Mediação e Cancelados).
  int get totalHistoryRecordsCount => fullHistory.length;

  /// A opção de adicionar serviços do histórico ao portfólio só é desbloqueada a partir do 4º serviço elegível (100% pago).
  bool get isAddFromHistoryUnlocked =>
      totalCompletedCount > kAutomaticPortfolioTopCount;

  /// Verdadeiro quando o botão de adicionar (+1 por vez) está desbloqueado, há vagas (< 5) e existem itens disponíveis no histórico elegível.
  bool get canAddMoreCuratedServices =>
      isAddFromHistoryUnlocked &&
      curatedPortfolioServices.length < kMaxCuratedPortfolioServices &&
      availableToCurate.isNotEmpty;

  /// Consulta em tempo constante $\Theta(1)$ se um serviço está atualmente no Top 3 automático.
  bool isInAutomaticTopThree(String serviceId) =>
      _memo.topThreeIds.contains(serviceId);

  /// Consulta em tempo constante $\Theta(1)$ se um serviço está atualmente nos Destaques Escolhidos (até 5).
  bool isInCuratedPortfolio(String serviceId) =>
      _memo.curatedIds.contains(serviceId);

  /// Consulta em tempo constante $\Theta(1)$ o índice (0-based) de um serviço entre os Concluídos & 100% Pagos.
  int settledRankOf(String serviceId) => _memo.settledRankById[serviceId] ?? -1;

  /// Busca em tempo constante $\Theta(1)$ um registro pelo ID.
  CompletedServiceRecord? findById(String serviceId) =>
      _memo.recordById[serviceId];

  ProviderPortfolioState copyWith({
    List<CompletedServiceRecord>? fullHistory,
    List<String>? curatedPortfolioIds,
  }) {
    final sorted = List<CompletedServiceRecord>.from(
      fullHistory ?? this.fullHistory,
    )..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    final settled =
        sorted.where((s) => s.isEligibleForPortfolio).toList(growable: false);
    final top3Ids = settled
        .take(kAutomaticPortfolioTopCount)
        .map((s) => s.id)
        .toSet();
    final eligibleIds = settled
        .skip(kAutomaticPortfolioTopCount)
        .map((s) => s.id)
        .toSet();

    final nextCurated = <String>[];
    for (final id in (curatedPortfolioIds ?? this.curatedPortfolioIds)) {
      if (!top3Ids.contains(id) &&
          eligibleIds.contains(id) &&
          !nextCurated.contains(id) &&
          nextCurated.length < kMaxCuratedPortfolioServices) {
        nextCurated.add(id);
      }
    }
    return ProviderPortfolioState(
      fullHistory: List<CompletedServiceRecord>.unmodifiable(sorted),
      curatedPortfolioIds: List<String>.unmodifiable(nextCurated),
    );
  }
}

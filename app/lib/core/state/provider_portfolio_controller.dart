import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/marketplace_models.dart';
import '../models/provider_portfolio_models.dart';

/// Catálogo de serviços realistas para simulação e demonstração do fluxo
/// de conclusão via PIN do Cliente (1º, 2º, 3º, 4º, 5º+ serviços).
final List<CompletedServiceRecord> kSamplePinCompletedServices = <CompletedServiceRecord>[
  CompletedServiceRecord(
    id: 'srv-pin-001',
    orderId: 'job-pin-001',
    title: 'Substituição de Disjuntor Termomagnético DIN 40A e Reaperto do QDC',
    categoryName: 'Elétrica',
    detailedExecutionReport:
        'Realizado diagnóstico termográfico no Quadro de Distribuição de Circuitos (QDC), '
        'identificando aquecimento no barramento neutro e fadiga térmica no disjuntor bipolar 40A do circuito do chuveiro. '
        'Efetuada substituição por disjuntor DIN 40A Curva C certificado INMETRO, crimpagem de terminais tubulares ilhós 6mm² '
        'e teste de carga sob tensão nominal 220V sem queda de tensão.',
    cityAndState: 'Poços de Caldas - MG',
    completedAt: DateTime(2026, 10, 10, 14, 30),
    validatedClientPin: '4829',
    serviceValue: 240.00,
    executionDurationText: '1h 25min',
    toolsAndMaterialsUsed: <String>[
      'Disjuntor Bipolar DIN 40A Curva C',
      'Terminais Tubulares Ilhós 6mm²',
      'Alicate Amperímetro True RMS',
      'Torquímetro Isolado 1000V (NBR 5410)',
    ],
    beforeAfterPhotoCaptionsOrUrls: <String>[
      'ANTES: Disjuntor antigo com sinais de carbonização no borne superior',
      'DEPOIS: QDC reorganizado com disjuntor novo e terminais prensados',
    ],
    warrantyCertificateCode: 'GAR-DSP-001-2026',
    isReviewedByClient: true,
    clientRating: 5.0,
    clientReviewComment:
        'Profissional extremamente técnico! Explicou o motivo do desarme, trocou a peça com segurança e deixou o quadro impecável.',
    clientPraiseTags: <String>['Super pontual', 'Serviço impecável', 'Explicou tudo'],
    clientReviewedAt: DateTime(2026, 10, 10, 16, 10),
    clientDisplayName: 'Marina A.',
  ),
  CompletedServiceRecord(
    id: 'srv-pin-002',
    orderId: 'job-pin-002',
    title: 'Reparo de Vazamento Oculto em Registro de Pressão 3/4" e Vedação',
    categoryName: 'Hidráulica',
    detailedExecutionReport:
        'Estancamento imediato de infiltração na parede do box do banheiro social. '
        'Substituição do castelo e vedante do registro de pressão 3/4" padrão Deca, '
        'aplicação de fita veda-rosca de alta densidade e recomposição localizada do rejunte acrílico impermeável. '
        'Teste hidrostático de estanqueidade aprovado por 30 minutos.',
    cityAndState: 'Poços de Caldas - MG',
    completedAt: DateTime(2026, 10, 18, 11, 15),
    validatedClientPin: '7391',
    serviceValue: 195.00,
    executionDurationText: '1h 10min',
    toolsAndMaterialsUsed: <String>[
      'Reparo Completo Registro de Pressão 3/4"',
      'Fita Veda-Rosca PTFE Alta Densidade',
      'Rejunte Acrílico Impermeável Cinza Platina',
      'Chave Sextavada para Castelo Hidráulico',
    ],
    beforeAfterPhotoCaptionsOrUrls: <String>[
      'ANTES: Gotejamento contínuo pela canopla e umidade no rejunte',
      'DEPOIS: Registro estanque, pressão normalizada e acabamento limpo',
    ],
    warrantyCertificateCode: 'GAR-DSP-002-2026',
    isReviewedByClient: true,
    clientRating: 5.0,
    clientReviewComment:
        'Resolveu o vazamento sem quebrar pisos desnecessários. Muito cuidadoso com a limpeza.',
    clientPraiseTags: <String>['Cuidadoso', 'Limpeza nota 10', 'Preço justo'],
    clientReviewedAt: DateTime(2026, 10, 18, 18, 45),
    clientDisplayName: 'Roberto S.',
  ),
  CompletedServiceRecord(
    id: 'srv-pin-003',
    orderId: 'job-pin-003',
    title: 'Tratamento de Umidade Ascendente e Pintura Acrílica Premium Fosca',
    categoryName: 'Pintura',
    detailedExecutionReport:
        'Raspagem integral do reboco desplacado na sala de estar (14 m²), aplicação de fundo preparador de paredes '
        'aglutinante de partículas, nivelamento em duas demãos de massa corrida PVA com lixamento orbital grão 220 '
        'e acabamento em 3 demãos cruzadas de tinta acrílica premium fosca.',
    cityAndState: 'Poços de Caldas - MG',
    completedAt: DateTime(2026, 10, 26, 17, 20),
    validatedClientPin: '1604',
    serviceValue: 480.00,
    executionDurationText: '4h 15min',
    toolsAndMaterialsUsed: <String>[
      'Fundo Preparador de Paredes Base Água',
      'Massa Corrida PVA e Lixas Grão 150/220',
      'Tinta Acrílica Premium Fosca Branco Neve',
      'Lona Plástica e Fita Crepe Automotiva de Proteção',
    ],
    beforeAfterPhotoCaptionsOrUrls: <String>[
      'ANTES: Parede com bolhas de umidade e descascamento próximo ao rodapé',
      'DEPOIS: Superfície nivelada, selada e com pintura uniforme sem respingos',
    ],
    warrantyCertificateCode: 'GAR-DSP-003-2026',
    isReviewedByClient: false,
    clientDisplayName: 'Fernanda L.',
  ),
  CompletedServiceRecord(
    id: 'srv-pin-004',
    orderId: 'job-pin-004',
    title: 'Higienização Bactericida e Recarga Técnica de Split Inverter 12.000 BTUs',
    categoryName: 'Ar-condicionado',
    detailedExecutionReport:
        'Desmontagem da carenagem e turbina da evaporadora, lavagem pressurizada com bolsa coletora '
        'e sanitizante bactericida biodegradável. Desobstrução do dreno por pressão positiva, aferição de superaquecimento '
        'com manifold digital e complemento de fluido refrigerante R-410A. Delta T de saída estabilizado em 13,8 °C.',
    cityAndState: 'Poços de Caldas - MG',
    completedAt: DateTime(2026, 11, 2, 15, 45),
    validatedClientPin: '9258',
    serviceValue: 310.00,
    executionDurationText: '1h 50min',
    toolsAndMaterialsUsed: <String>[
      'Bolsa Coletora Impermeável para Split',
      'Bactericida Neutro para Serpentina de Alumínio',
      'Manifold Digital e Balança de Precisão R-410A',
      'Termômetro Infravermelho Calibrado',
    ],
    beforeAfterPhotoCaptionsOrUrls: <String>[
      'ANTES: Turbina obstruída por biofilme e vazão de ar reduzida em 60%',
      'DEPOIS: Evaporadora higienizada e temperatura de insuflamento em 8,4 °C',
    ],
    warrantyCertificateCode: 'GAR-DSP-004-2026',
    isReviewedByClient: true,
    clientRating: 4.9,
    clientReviewComment:
        'O ar-condicionado voltou a gelar como novo e parou de pingar na parede. Recomendo demais!',
    clientPraiseTags: <String>['Equipamento profissional', 'Resolveu de primeira'],
    clientReviewedAt: DateTime(2026, 11, 2, 19, 00),
    clientDisplayName: 'Lucas M.',
  ),
  CompletedServiceRecord(
    id: 'srv-pin-005',
    orderId: 'job-pin-005',
    title: 'Instalação de Fechadura Digital Biométrica e Alinhamento de Batente',
    categoryName: 'Chaveiro',
    detailedExecutionReport:
        'Furação com gabarito técnico em porta maciça de madeira (espessura 42 mm), embutimento da máquina mortise, '
        'passagem do chicote blindado, ajuste milimétrico da contra-testa no batente para fechamento suave '
        'e cadastro das biometrias e senhas de administrador junto ao cliente.',
    cityAndState: 'Poços de Caldas - MG',
    completedAt: DateTime(2026, 11, 6, 16, 40),
    validatedClientPin: '3187',
    serviceValue: 280.00,
    executionDurationText: '1h 35min',
    toolsAndMaterialsUsed: <String>[
      'Serra Copo Bimetal 32mm e 54mm',
      'Formão Profissional para Rebaixo de Testa',
      'Fechadura Digital Biométrica Sobrepor/Embutir',
      'Pilhas Alcalinas AA de Longa Duração',
    ],
    beforeAfterPhotoCaptionsOrUrls: <String>[
      'ANTES: Fechadura mecânica antiga com lingueta travando no batente',
      'DEPOIS: Fechadura digital alinhada com travamento automático perfeito',
    ],
    warrantyCertificateCode: 'GAR-DSP-005-2026',
    isReviewedByClient: false,
    clientDisplayName: 'Patrícia V.',
  ),
];

/// Store singleton reativo para sincronizar o estado entre telas Riverpod e telas StatefulWidget/StatelessWidget.
class ProviderPortfolioStore extends ChangeNotifier {
  ProviderPortfolioStore._()
      : _state = ProviderPortfolioState(
          // Inicia com os 4 primeiros serviços concluídos via PIN para demonstrar
          // tanto o Top 3 automático quanto o 4º serviço elegível no Histórico,
          // mantendo total suporte a testar 0, 1, 2, 3, 4, 5+ serviços.
          fullHistory: kSamplePinCompletedServices.take(4).toList(),
          curatedPortfolioIds: <String>[kSamplePinCompletedServices.first.id],
        );

  static final ProviderPortfolioStore instance = ProviderPortfolioStore._();

  ProviderPortfolioState _state;
  int _simulationCounter = 5;

  ProviderPortfolioState get state => _state;

  void _update(ProviderPortfolioState next) {
    _state = next;
    notifyListeners();
  }

  /// Operação A — Conclusão de Serviço via PIN do Cliente (Rotação FIFO Automática):
  /// - Registra o serviço no topo de `fullHistory` (`#1 Mais Recente`).
  /// - Empurra o antigo `#1` para `#2`, o `#2` para `#3`, e o antigo `#3` sai de
  ///   `automaticTopThree` mas **PERMANECE INTACTO** em `fullHistory` e passa a integrar
  ///   automaticamente `eligibleHistoryPool`.
  CompletedServiceRecord completeAndValidateServiceWithPin(
    CompletedServiceRecord newCompletedService,
  ) {
    final withoutDuplicate = _state.fullHistory
        .where((s) => s.id != newCompletedService.id && s.orderId != newCompletedService.orderId)
        .toList();
    final updatedHistory = <CompletedServiceRecord>[
      newCompletedService,
      ...withoutDuplicate,
    ]..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    _update(
      _state.copyWith(
        fullHistory: updatedHistory,
      ),
    );
    return newCompletedService;
  }

  /// Integração direta com o fluxo real de conclusão do pedido (`ReleasePaymentScreen`)
  /// quando o profissional insere o PIN de 4 dígitos do cliente.
  CompletedServiceRecord completeJobWithPin({
    required Job job,
    required String validatedClientPin,
    String? detailedExecutionReport,
    String? executionDurationText,
    List<String>? toolsAndMaterialsUsed,
    List<String>? beforeAfterPhotoCaptionsOrUrls,
    String? clientDisplayName,
  }) {
    final now = DateTime.now();
    final cityState = _extractCityAndState(job.addressSummary);
    final record = CompletedServiceRecord(
      id: 'srv-${job.id}',
      orderId: job.id,
      title: job.title.trim().isNotEmpty ? job.title.trim() : 'Atendimento Técnico (${job.category})',
      categoryName: job.category,
      detailedExecutionReport: (detailedExecutionReport ?? '').trim().isNotEmpty
          ? detailedExecutionReport!.trim()
          : (job.description.trim().isNotEmpty
              ? 'Execução técnica concluída conforme escopo solicitado: ${job.description.trim()}. '
                  'Testes funcionais e conferência presencial aprovados mediante validação do PIN do cliente.'
              : 'Serviço executado dentro das normas técnicas da categoria ${job.category}, '
                  'com check-in/check-out auditado e validação presencial pelo PIN do cliente.'),
      cityAndState: cityState,
      completedAt: now,
      validatedClientPin: validatedClientPin.trim().isEmpty ? '0000' : validatedClientPin.trim(),
      serviceValue: job.agreedPrice ?? 180.0,
      executionDurationText: executionDurationText ?? '1h 30min',
      toolsAndMaterialsUsed: toolsAndMaterialsUsed ??
          <String>[
            'Kit de Ferramentas Homologado (${job.category})',
            'EPIs e Insumos de Acabamento Certificado',
          ],
      beforeAfterPhotoCaptionsOrUrls: beforeAfterPhotoCaptionsOrUrls ??
          <String>[
            'ANTES: Registro fotográfico de diagnóstico inicial no local',
            'DEPOIS: Registro final homologado após conclusão e limpeza',
          ],
      warrantyCertificateCode: 'GAR-${job.code.replaceAll('#', '')}-${now.year}',
      isReviewedByClient: false,
      clientDisplayName: clientDisplayName ?? 'Cliente Verificado',
    );
    return completeAndValidateServiceWithPin(record);
  }

  static String _extractCityAndState(String? summary) {
    final raw = (summary ?? '').trim();
    if (raw.isEmpty) return 'Poços de Caldas - MG';
    if (raw.contains(',')) {
      return raw.split(',').last.trim();
    }
    return raw;
  }

  /// Operação B — Adicionar Serviço do Histórico ao Portfólio (1 por vez, até 3, a partir do 4º serviço):
  /// - Valida se `isAddFromHistoryUnlocked == true` (`totalCompletedCount >= 4`).
  /// - Valida se `curatedPortfolioServices.length < 3`.
  /// - Valida se `serviceId` pertence ao `eligibleHistoryPool` (não é um dos 3 últimos)
  ///   e ainda não está em `curatedPortfolioIds`.
  /// - Adiciona exatamente 1 serviço por chamada.
  bool addServiceFromHistoryToPortfolio(String serviceId) {
    if (!_state.isAddFromHistoryUnlocked) return false;
    if (_state.curatedPortfolioServices.length >= 3) return false;
    final inEligiblePool = _state.eligibleHistoryPool.any((s) => s.id == serviceId);
    if (!inEligiblePool) return false;
    if (_state.curatedPortfolioIds.contains(serviceId)) return false;

    final nextCurated = <String>[
      ..._state.curatedPortfolioIds,
      serviceId,
    ];
    _update(_state.copyWith(curatedPortfolioIds: nextCurated));
    return true;
  }

  /// Substitui um destaque escolhido por outro item elegível do histórico (1 por vez).
  bool swapCuratedServiceInPortfolio({
    required String oldServiceId,
    required String newServiceId,
  }) {
    if (!_state.isAddFromHistoryUnlocked) return false;
    final inEligiblePool = _state.eligibleHistoryPool.any((s) => s.id == newServiceId);
    if (!inEligiblePool) return false;
    if (_state.curatedPortfolioIds.contains(newServiceId)) return false;

    final nextCurated = _state.curatedPortfolioIds
        .map((id) => id == oldServiceId ? newServiceId : id)
        .toList();
    _update(_state.copyWith(curatedPortfolioIds: nextCurated));
    return true;
  }

  /// Operação C — Remover ou Trocar Serviço Escolhido do Portfólio (Sem Excluir do Histórico):
  /// - Remove `serviceId` apenas de `curatedPortfolioIds`.
  /// - `fullHistory` permanece 100% intacto (nenhum serviço realizado jamais é excluído do Histórico).
  bool removeCuratedServiceFromPortfolio(String serviceId) {
    if (!_state.curatedPortfolioIds.contains(serviceId)) return false;
    final nextCurated = _state.curatedPortfolioIds
        .where((id) => id != serviceId)
        .toList();
    _update(_state.copyWith(curatedPortfolioIds: nextCurated));
    return true;
  }

  /// Operação D — Sincronização Reativa da Avaliação do Cliente:
  /// - Quando o cliente avalia um serviço concluído (seja imediatamente após o PIN ou dias depois),
  ///   localiza o `CompletedServiceRecord` em `fullHistory` (por `serviceId` ou `orderId`) e
  ///   atualiza `isReviewedByClient = true`, `clientRating`, `clientReviewComment`,
  ///   `clientPraiseTags` e `clientReviewedAt`.
  /// - Como `automaticTopThree` e `curatedPortfolioServices` derivam diretamente de `fullHistory`,
  ///   a avaliação passa a ser exibida imediatamente tanto no Meu Portfólio quanto no Histórico.
  bool syncClientEvaluationToHistoryAndPortfolio({
    String? serviceId,
    String? orderId,
    required double rating,
    required String comment,
    List<String> praiseTags = const <String>[],
    String? clientDisplayName,
    DateTime? reviewedAt,
  }) {
    var found = false;
    final updatedHistory = _state.fullHistory.map((record) {
      final matchById = serviceId != null && record.id == serviceId;
      final matchByOrder = orderId != null && record.orderId == orderId;
      if (!matchById && !matchByOrder) return record;
      found = true;
      return record.copyWith(
        isReviewedByClient: true,
        clientRating: rating,
        clientReviewComment: comment.trim().isEmpty
            ? 'Excelente atendimento técnico! Serviço concluído e aprovado.'
            : comment.trim(),
        clientPraiseTags: praiseTags.isEmpty
            ? const <String>['Serviço aprovado', 'Profissional verificado']
            : praiseTags,
        clientReviewedAt: reviewedAt ?? DateTime.now(),
        clientDisplayName: clientDisplayName ?? record.clientDisplayName,
      );
    }).toList();

    if (!found && orderId != null) {
      // Se o pedido avaliado ainda não estava em fullHistory, registra e já sincroniza a avaliação.
      final now = reviewedAt ?? DateTime.now();
      updatedHistory.insert(
        0,
        CompletedServiceRecord(
          id: serviceId ?? 'srv-$orderId',
          orderId: orderId,
          title: 'Atendimento Técnico Verificado (#${orderId.substring(0, orderId.length.clamp(1, 6))})',
          categoryName: 'Manutenção Residencial',
          detailedExecutionReport:
              'Serviço concluído com validação presencial de PIN do cliente e avaliado na plataforma.',
          cityAndState: 'Poços de Caldas - MG',
          completedAt: now.subtract(const Duration(minutes: 25)),
          validatedClientPin: '8412',
          serviceValue: 220.0,
          executionDurationText: '1h 20min',
          toolsAndMaterialsUsed: const <String>[
            'Ferramental Técnico Certificado',
            'Insumos Homologados',
          ],
          beforeAfterPhotoCaptionsOrUrls: const <String>[
            'ANTES: Diagnóstico inicial registrado',
            'DEPOIS: Serviço concluído e validado pelo cliente',
          ],
          warrantyCertificateCode: 'GAR-${now.millisecondsSinceEpoch.toString().substring(7)}',
          isReviewedByClient: true,
          clientRating: rating,
          clientReviewComment: comment.trim().isEmpty
              ? 'Excelente atendimento técnico! Serviço concluído e aprovado.'
              : comment.trim(),
          clientPraiseTags: praiseTags.isEmpty
              ? const <String>['Serviço aprovado', 'Profissional verificado']
              : praiseTags,
          clientReviewedAt: now,
          clientDisplayName: clientDisplayName ?? 'Cliente Verificado',
        ),
      );
      found = true;
    }

    if (found) {
      _update(_state.copyWith(fullHistory: updatedHistory));
    }
    return found;
  }

  /// Simula a conclusão de um novo serviço validado via PIN do cliente para testar em tempo real
  /// a rotação automática dos 3 mais recentes e o desbloqueio da escolha no Histórico a partir do 4º serviço.
  CompletedServiceRecord simulateNextPinCompletedService() {
    final currentCount = _state.totalCompletedCount;
    final nextNumber = currentCount + 1;
    final now = DateTime.now().add(Duration(seconds: _simulationCounter++));

    if (currentCount < kSamplePinCompletedServices.length) {
      // Usa o próximo serviço da lista de amostras com timestamp mais recente para entrar em #1
      final template = kSamplePinCompletedServices[currentCount];
      final record = template.copyWith(
        completedAt: now,
      );
      return completeAndValidateServiceWithPin(record);
    }

    final categories = <String>['Elétrica', 'Hidráulica', 'Pintura', 'Marcenaria', 'Alvenaria'];
    final category = categories[nextNumber % categories.length];
    final pin = (1000 + (nextNumber * 733) % 8999).toString().padLeft(4, '0');
    final record = CompletedServiceRecord(
      id: 'srv-pin-${nextNumber.toString().padLeft(3, '0')}',
      orderId: 'job-pin-${nextNumber.toString().padLeft(3, '0')}',
      title: '$nextNumberº Serviço Concluído via PIN • Manutenção Especializada ($category)',
      categoryName: category,
      detailedExecutionReport:
          'Execução completa do $nextNumberº atendimento técnico em $category, incluindo diagnóstico instrumental, '
          'substituição preventiva de componentes desgastados, limpeza técnica da área de intervenção '
          'e validação final presencial com o código PIN de 4 dígitos fornecido pelo cliente.',
      cityAndState: 'Poços de Caldas - MG',
      completedAt: now,
      validatedClientPin: pin,
      serviceValue: 180.0 + (nextNumber * 25.0),
      executionDurationText: '1h ${(15 + (nextNumber * 7) % 40).toString().padLeft(2, '0')}min',
      toolsAndMaterialsUsed: <String>[
        'Kit Profissional de $category',
        'Insumos de Vedação e Fixação Certificados',
        'Instrumento Digital de Aferição',
      ],
      beforeAfterPhotoCaptionsOrUrls: <String>[
        'ANTES: Inspeção inicial e isolamento seguro do ponto de $category',
        'DEPOIS: $nextNumberº serviço finalizado, testado e aprovado com PIN $pin',
      ],
      warrantyCertificateCode: 'GAR-DSP-${nextNumber.toString().padLeft(3, '0')}-2026',
      isReviewedByClient: false,
      clientDisplayName: 'Cliente #${nextNumber.toString().padLeft(2, '0')}',
    );
    return completeAndValidateServiceWithPin(record);
  }

  /// Simula a chegada de uma avaliação futura do cliente para um serviço já concluído via PIN.
  bool simulateFutureClientReviewForService(String serviceId) {
    return syncClientEvaluationToHistoryAndPortfolio(
      serviceId: serviceId,
      rating: 5.0,
      comment:
          'Avaliação enviada pelo cliente após uso do serviço: trabalho impecável, super pontual, '
          'explicou cada etapa técnica e deixou tudo funcionando perfeitamente!',
      praiseTags: const <String>[
        'Super pontual',
        'Qualidade impecável',
        'Recomendo 100%',
      ],
      reviewedAt: DateTime.now(),
    );
  }

  /// Permite ajustar rapidamente a quantidade de serviços concluídos (ex.: 0, 1, 2, 3, 4, 5)
  /// para validar o comportamento antes e depois do 4º serviço.
  void resetToCount(int count, {List<String> curatedIds = const <String>[]}) {
    final clamped = count.clamp(0, kSamplePinCompletedServices.length);
    // Ordena do mais antigo para o mais recente ao fatiar os primeiros `clamped` serviços
    final chronological = List<CompletedServiceRecord>.from(kSamplePinCompletedServices)
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    final subset = chronological.take(clamped).toList();
    _update(
      ProviderPortfolioState(fullHistory: subset).copyWith(
        curatedPortfolioIds: curatedIds,
      ),
    );
  }
}

/// Controller Riverpod (`Notifier<ProviderPortfolioState>`) sincronizado com [ProviderPortfolioStore.instance].
class ProviderPortfolioAndHistoryController extends Notifier<ProviderPortfolioState> {
  @override
  ProviderPortfolioState build() {
    final store = ProviderPortfolioStore.instance;
    void listener() {
      state = store.state;
    }

    store.addListener(listener);
    ref.onDispose(() => store.removeListener(listener));
    return store.state;
  }

  CompletedServiceRecord completeAndValidateServiceWithPin(
    CompletedServiceRecord newCompletedService,
  ) {
    return ProviderPortfolioStore.instance.completeAndValidateServiceWithPin(
      newCompletedService,
    );
  }

  bool addServiceFromHistoryToPortfolio(String serviceId) {
    return ProviderPortfolioStore.instance.addServiceFromHistoryToPortfolio(
      serviceId,
    );
  }

  bool swapCuratedServiceInPortfolio({
    required String oldServiceId,
    required String newServiceId,
  }) {
    return ProviderPortfolioStore.instance.swapCuratedServiceInPortfolio(
      oldServiceId: oldServiceId,
      newServiceId: newServiceId,
    );
  }

  bool removeCuratedServiceFromPortfolio(String serviceId) {
    return ProviderPortfolioStore.instance.removeCuratedServiceFromPortfolio(
      serviceId,
    );
  }

  bool syncClientEvaluationToHistoryAndPortfolio({
    String? serviceId,
    String? orderId,
    required double rating,
    required String comment,
    List<String> praiseTags = const <String>[],
    String? clientDisplayName,
    DateTime? reviewedAt,
  }) {
    return ProviderPortfolioStore.instance
        .syncClientEvaluationToHistoryAndPortfolio(
      serviceId: serviceId,
      orderId: orderId,
      rating: rating,
      comment: comment,
      praiseTags: praiseTags,
      clientDisplayName: clientDisplayName,
      reviewedAt: reviewedAt,
    );
  }

  CompletedServiceRecord simulateNextPinCompletedService() {
    return ProviderPortfolioStore.instance.simulateNextPinCompletedService();
  }

  bool simulateFutureClientReviewForService(String serviceId) {
    return ProviderPortfolioStore.instance.simulateFutureClientReviewForService(
      serviceId,
    );
  }

  void resetToCount(int count, {List<String> curatedIds = const <String>[]}) {
    ProviderPortfolioStore.instance.resetToCount(count, curatedIds: curatedIds);
  }
}

final providerPortfolioControllerProvider =
    NotifierProvider<ProviderPortfolioAndHistoryController, ProviderPortfolioState>(
  ProviderPortfolioAndHistoryController.new,
);

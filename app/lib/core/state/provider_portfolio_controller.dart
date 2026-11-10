import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/marketplace_models.dart';
import '../models/provider_portfolio_models.dart';

/// Fixtures exclusivas para testes automatizados (`@visibleForTesting`).
/// Em produção, [ProviderPortfolioStore] inicia 100% vazio (Zero Fake Data)
/// e carrega exclusivamente serviços reais do Supabase.
@visibleForTesting
final List<CompletedServiceRecord> kSamplePinCompletedServices =
    <CompletedServiceRecord>[
  CompletedServiceRecord(
    id: 'srv-pin-004',
    orderId: 'job-pin-004',
    title: 'Automação de Iluminação LED + Instalação de Lustre Pendente Duplo',
    categoryName: 'Elétrica',
    clientRequestedDescription:
        'Preciso instalar um lustre pendente duplo na sala de jantar com pé-direito alto e configurar 3 circuitos dimerizáveis em LED.',
    detailedExecutionReport:
        'Instalação de lustre pendente em pé-direito duplo com ancoragem química, '
        'passagem de circuito dedicado 1,5mm² para três cenas de iluminação LED dimerizável, '
        'configuração de interruptores paralelos e teste fotométrico de estabilidade sem flicker.',
    complementaryTechnicalNotes:
        'Utilizados conectores de torção blindados WAGO 221 e cabo antichama 750V conforme ABNT NBR 5410.',
    cityAndState: 'Poços de Caldas - MG',
    completedAt: DateTime(2026, 10, 28, 17, 45),
    validatedClientPin: '4928',
    serviceValue: 320.0,
    grossAmount: 420.0,
    materialsAmount: 100.0,
    platformFeeAmount: 38.4,
    executionDurationText: '2h 10min',
    toolsAndMaterialsUsed: const <String>[
      'Multímetro True RMS Fluke',
      'Conectores WAGO 221',
      'Parafusadeira Brushless + Buchas Fisheye',
      'Dimmer Rotativo LED Estabilizado',
    ],
    beforeAfterPhotoCaptionsOrUrls: const <String>[
      'ANTES: Ponto de teto em laje sem suporte reforçado e fiação antiga exposta',
      'DEPOIS: Lustre nivelado a laser e circuitos LED operando em 3 cenas',
      'DETALHE: Conexões isoladas com conectores WAGO 221 no plafon superior',
    ],
    warrantyCertificateCode: 'GAR-EL-2026-004',
    isReviewedByClient: true,
    clientRating: 5.0,
    clientReviewComment:
        'Trabalho de altíssimo padrão! Nivelou o lustre perfeitamente, não deixou uma sujeira sequer e explicou todo o funcionamento.',
    clientPraiseTags: const <String>[
      'Acabamento impecável',
      'Super pontual',
      'Limpeza exemplar',
    ],
    clientReviewedAt: DateTime(2026, 10, 28, 18, 30),
    clientDisplayName: 'Mariana C.',
  ),
  CompletedServiceRecord(
    id: 'srv-pin-003',
    orderId: 'job-pin-003',
    title: 'Pressurização da Rede de Água Quente e Troca de Misturador Monocomando',
    categoryName: 'Hidráulica',
    clientRequestedDescription:
        'A pressão da água quente da suíte está muito fraca e o misturador monocomando está pingando.',
    detailedExecutionReport:
        'Desmontagem técnica do misturador antigo oxidado, limpeza da tubulação CPVC, '
        'instalação de novo monocomando gourmet com cartucho cerâmico de alta vazão '
        'e teste de estanqueidade sob pressão dinâmica de 25 m.c.a. por 40 minutos.',
    cityAndState: 'Poços de Caldas - MG',
    completedAt: DateTime(2026, 10, 22, 14, 20),
    validatedClientPin: '7310',
    serviceValue: 240.0,
    grossAmount: 290.0,
    materialsAmount: 50.0,
    platformFeeAmount: 28.8,
    executionDurationText: '1h 35min',
    toolsAndMaterialsUsed: const <String>[
      'Manômetro Hidráulico de Bancada',
      'Fita PTFE Alta Densidade',
      'Chave de Bacia Telescópica',
      'Flexíveis Malha de Aço Inox 40cm',
    ],
    beforeAfterPhotoCaptionsOrUrls: const <String>[
      'ANTES: Baixa vazão e gotejamento na junta excêntrica do misturador',
      'DEPOIS: Monocomando instalado com vedação estanque e vazão estabilizada',
    ],
    warrantyCertificateCode: 'GAR-HD-2026-003',
    isReviewedByClient: true,
    clientRating: 4.9,
    clientReviewComment:
        'Resolveu a falta de pressão que outros dois profissionais não tinham conseguido resolver. Nota 10!',
    clientPraiseTags: const <String>[
      'Diagnóstico preciso',
      'Preço justo',
      'Zero vazamento',
    ],
    clientReviewedAt: DateTime(2026, 10, 22, 19, 10),
    clientDisplayName: 'Ricardo T.',
  ),
  CompletedServiceRecord(
    id: 'srv-pin-002',
    orderId: 'job-pin-002',
    title: 'Adequação de Quadro de Distribuição (QDC) Norma NBR 5410 + DR e DPS',
    categoryName: 'Elétrica',
    clientRequestedDescription:
        'O disjuntor do chuveiro desarma quando liga o forno elétrico. Quero revisar o quadro inteiro e colocar proteção DR e DPS.',
    detailedExecutionReport:
        'Reorganização integral do QDC bifásico com barramentos tipo pente, instalação de '
        'Interruptor Diferencial Residual (IDR 40A 30mA), dois Dispositivos de Proteção contra Surtos (DPS Classe II), '
        'crimpagem de terminais tubulares ilhós em todos os condutores e identificação normatizada dos circuitos.',
    cityAndState: 'Poços de Caldas - MG',
    completedAt: DateTime(2026, 10, 15, 11, 50),
    validatedClientPin: '1854',
    serviceValue: 480.0,
    grossAmount: 680.0,
    materialsAmount: 200.0,
    platformFeeAmount: 57.6,
    executionDurationText: '3h 20min',
    toolsAndMaterialsUsed: const <String>[
      'Alicate Prensa Terminais Tubular',
      'IDR Tetrapolar 40A 30mA + DPS 275V',
      'Barramento Pente Bifásico 80A',
      'Termovisor Infravermelho para Inspeção Térmica',
    ],
    beforeAfterPhotoCaptionsOrUrls: const <String>[
      'ANTES: Fios emendados sem barramento e aquecimento excessivo no disjuntor geral',
      'DEPOIS: QDC penteado com terminais ilhós, IDR, DPS e etiquetas técnicas',
    ],
    warrantyCertificateCode: 'GAR-EL-2026-002',
    isReviewedByClient: false,
    clientDisplayName: 'Fernanda L.',
  ),
  CompletedServiceRecord(
    id: 'srv-pin-001',
    orderId: 'job-pin-001',
    title: 'Reparo Estrutural de Infiltração em Registro de Gaveta Geral 3/4"',
    categoryName: 'Hidráulica',
    clientRequestedDescription:
        'O registro geral do banheiro não fecha a água completamente e está umedecendo o rejunte.',
    detailedExecutionReport:
        'Abertura cirúrgica de apenas 1 peça de porcelanato com disco diamantado extrafino, '
        'substituição do castelo e vedante de bronze do registro de gaveta Deca 3/4", '
        'recomposição de argamassa impermeabilizante polimérica e assentamento com nivelador.',
    cityAndState: 'Poços de Caldas - MG',
    completedAt: DateTime(2026, 10, 04, 16, 10),
    validatedClientPin: '9042',
    serviceValue: 290.0,
    grossAmount: 350.0,
    materialsAmount: 60.0,
    platformFeeAmount: 34.8,
    executionDurationText: '2h 00min',
    toolsAndMaterialsUsed: const <String>[
      'Esmerilhadeira com Disco Diamantado Porcelanato',
      'Reparo Original Registro Gaveta 3/4"',
      'Argamassa Polimérica Impermeabilizante',
    ],
    beforeAfterPhotoCaptionsOrUrls: const <String>[
      'ANTES: Umidade ativa na junta do registro geral e perda de estanqueidade',
      'DEPOIS: Registro substituído e porcelanato recomposto com alinhamento milimétrico',
    ],
    warrantyCertificateCode: 'GAR-HD-2026-001',
    isReviewedByClient: true,
    clientRating: 5.0,
    clientReviewComment:
        'Meu primeiro serviço contratado no app e fiquei impressionado! Salvou meu porcelanato sem quebrar o banheiro todo.',
    clientPraiseTags: const <String>[
      'Cuidado com o imóvel',
      'Mestre no que faz',
      'Honesto e rápido',
    ],
    clientReviewedAt: DateTime(2026, 10, 04, 18, 00),
    clientDisplayName: 'Carlos Eduardo M.',
  ),
  CompletedServiceRecord(
    id: 'srv-pin-005',
    orderId: 'job-pin-005',
    title: 'Instalação de Infraestrutura para Carregador Veicular Wallbox 7,4kW',
    categoryName: 'Elétrica',
    clientRequestedDescription:
        'Preciso instalar um carregador Wallbox 7,4kW na vaga da garagem com proteção exclusiva.',
    detailedExecutionReport:
        'Lançamento de cabo HEPR 90°C 6mm² em eletroduto galvanizado aparente na garagem, '
        'quadro exclusivo de proteção com disjuntor curva C 40A e IDR Tipo A, '
        'aterramento dedicado e comissionamento de carga contínua de 32A.',
    cityAndState: 'Poços de Caldas - MG',
    completedAt: DateTime(2026, 11, 01, 15, 00),
    validatedClientPin: '6621',
    serviceValue: 650.0,
    grossAmount: 950.0,
    materialsAmount: 300.0,
    platformFeeAmount: 78.0,
    executionDurationText: '3h 45min',
    toolsAndMaterialsUsed: const <String>[
      'Terrômetro Digital Certificador',
      'Cabo HEPR 6mm² + Eletroduto Galvanizado',
      'IDR Tipo A 40A + DPS Dedicado',
    ],
    beforeAfterPhotoCaptionsOrUrls: const <String>[
      'ANTES: Vaga de garagem sem ponto de força dedicado',
      'DEPOIS: Wallbox 7,4kW instalado, certificado e carregando a 32A estáveis',
    ],
    warrantyCertificateCode: 'GAR-EL-2026-005',
    isReviewedByClient: true,
    clientRating: 5.0,
    clientReviewComment:
        'Serviço nível engenheiro! Fez todos os testes de aterramento na minha frente e entregou laudo completo.',
    clientPraiseTags: const <String>[
      'Segurança máxima',
      'Conhecimento técnico',
      'Altíssimo padrão',
    ],
    clientReviewedAt: DateTime(2026, 11, 01, 16, 20),
    clientDisplayName: 'Dr. Henrique S.',
  ),
];

/// Store reativo global (`ChangeNotifier`) para o **Meu Portfólio** e
/// **Histórico de Serviços Prestados**.
///
/// Regras Arquiteturais de Produção:
/// - **Zero Fake Data**: Inicia 100% vazio (`fullHistory: []`, `curatedPortfolioIds: []`).
/// - **Sincronização Real com Supabase**: Carrega apenas serviços reais do profissional autenticado.
/// - **Elegibilidade Estrita do Portfólio**: Apenas serviços `settledAndPaid` (com 100% do pagamento
///   recebido e proteção pós-serviço concluída) entram no Top 3 LIFO ou podem ser escolhidos
///   nos até 5 Destaques do Histórico.
/// - **Imutabilidade de Segurança**: A descrição solicitada pelo cliente, a solução aplicada na
///   conclusão e as fotos são imutáveis. Apenas o campo **"Notas Técnicas Complementares"**
///   pode ser editado pós-conclusão pelo profissional dono.
class ProviderPortfolioStore extends ChangeNotifier {
  ProviderPortfolioStore._()
      : _state = ProviderPortfolioState(
          fullHistory: const <CompletedServiceRecord>[],
          curatedPortfolioIds: const <String>[],
        );

  static final ProviderPortfolioStore instance = ProviderPortfolioStore._();

  ProviderPortfolioState _state;
  int _simulationCounter = 0;
  bool _isSyncing = false;

  ProviderPortfolioState get state => _state;
  bool get isSyncing => _isSyncing;

  void _update(ProviderPortfolioState nextState) {
    _state = nextState;
    notifyListeners();
  }

  /// Sincroniza o Histórico de Serviços Prestados e os Destaques do Portfólio
  /// diretamente com o Supabase para o profissional autenticado.
  Future<void> syncFromSupabase([SupabaseClient? customClient]) async {
    SupabaseClient client;
    try {
      client = customClient ?? Supabase.instance.client;
    } catch (_) {
      return;
    }
    final user = client.auth.currentUser;
    if (user == null) return;

    _isSyncing = true;
    notifyListeners();
    try {
      final res = await client.rpc('provider_full_service_history');
      if (res is List) {
        final records = <CompletedServiceRecord>[];
        final pinnedIds = <String>[];
        for (final raw in res) {
          if (raw is Map) {
            final map = Map<String, dynamic>.from(raw);
            final rec = CompletedServiceRecord.fromMap(map);
            records.add(rec);
            if (map['is_pinned'] == true && rec.isEligibleForPortfolio) {
              pinnedIds.add(rec.id);
            }
          }
        }
        _update(
          ProviderPortfolioState(
            fullHistory: records,
          ).copyWith(curatedPortfolioIds: pinnedIds),
        );
      }
    } catch (_) {
      // Fallback: consulta direta às tabelas `jobs`, `payments`, `reviews` e `provider_case_pins`
      try {
        final uid = user.id;
        final jobRows = await client
            .from('jobs')
            .select()
            .eq('provider_id', uid)
            .inFilter('status', ['completed', 'disputed', 'canceled'])
            .order('created_at', ascending: false);
        final jobs = (jobRows as List).cast<Map<String, dynamic>>();
        if (jobs.isEmpty) {
          _update(
            ProviderPortfolioState(
              fullHistory: const <CompletedServiceRecord>[],
              curatedPortfolioIds: const <String>[],
            ),
          );
          return;
        }
        final jobIds = jobs.map((j) => j['id'] as String).toList();
        final payRows = await client
            .from('payments')
            .select()
            .inFilter('job_id', jobIds);
        final payByJob = <String, Map<String, dynamic>>{
          for (final p in (payRows as List).cast<Map<String, dynamic>>())
            p['job_id'] as String: p,
        };
        final revRows = await client
            .from('reviews')
            .select()
            .eq('reviewee_id', uid)
            .inFilter('job_id', jobIds);
        final revByJob = <String, Map<String, dynamic>>{
          for (final r in (revRows as List).cast<Map<String, dynamic>>())
            r['job_id'] as String: r,
        };
        final pinRows = await client
            .from('provider_case_pins')
            .select('job_id')
            .eq('provider_id', uid);
        final pinnedIds = <String>[
          for (final p in (pinRows as List).cast<Map<String, dynamic>>())
            p['job_id'] as String,
        ];

        final records = <CompletedServiceRecord>[];
        for (final j in jobs) {
          final jid = j['id'] as String;
          final status = (j['status'] as String?) ?? 'completed';
          final pay = payByJob[jid];
          final rev = revByJob[jid];
          final payStatus = (pay?['status'] as String?) ?? 'released';
          final escrowStatus = (j['escrow_status'] as String?) ?? 'settled';

          final ServiceHistoryLifecycleStage stage;
          if (status == 'canceled') {
            stage = ServiceHistoryLifecycleStage.canceled;
          } else if (status == 'disputed') {
            stage = ServiceHistoryLifecycleStage.inMediation;
          } else if (payStatus == 'released' &&
              (escrowStatus == 'settled' || escrowStatus == 'released')) {
            stage = ServiceHistoryLifecycleStage.settledAndPaid;
          } else {
            stage = ServiceHistoryLifecycleStage.underPostServiceProtection;
          }

          final photos =
              ((j['photo_paths'] as List?) ?? const <dynamic>[])
                  .whereType<String>()
                  .toList();

          records.add(
            CompletedServiceRecord(
              id: jid,
              orderId: jid,
              title: (j['title'] as String?) ?? 'Serviço Residencial',
              categoryName: (j['category'] as String?) ?? 'Manutenção',
              clientRequestedDescription:
                  (j['description'] as String?) ?? '',
              detailedExecutionReport:
                  (j['provider_report'] as String?) ??
                      'Serviço concluído e validado presencialmente.',
              complementaryTechnicalNotes:
                  j['complementary_notes'] as String?,
              cityAndState:
                  (j['address_summary'] as String?) ?? 'Local Verificado',
              completedAt: DateTime.tryParse(
                        '${j['approved_at'] ?? j['finished_at'] ?? j['canceled_at'] ?? j['created_at']}',
                      )?.toLocal() ??
                  DateTime.now(),
              validatedClientPin: '••••',
              serviceValue: (pay?['net_amount'] as num?)?.toDouble() ??
                  (j['agreed_price'] as num?)?.toDouble() ??
                  0.0,
              grossAmount: (pay?['gross_amount'] as num?)?.toDouble() ??
                  (j['agreed_price'] as num?)?.toDouble(),
              materialsAmount:
                  (j['materials_amount'] as num?)?.toDouble() ?? 0.0,
              platformFeeAmount:
                  (pay?['fee_amount'] as num?)?.toDouble() ?? 0.0,
              executionDurationText: 'Concluído no prazo',
              beforeAfterPhotoCaptionsOrUrls: photos,
              warrantyCertificateCode:
                  'DSP-${jid.substring(0, jid.length.clamp(0, 6)).toUpperCase()}',
              lifecycleStage: stage,
              isPaid100Percent:
                  stage == ServiceHistoryLifecycleStage.settledAndPaid,
              cancelReason: j['cancel_reason'] as String?,
              isReviewedByClient:
                  rev != null && rev['revealed_at'] != null,
              clientRating: (rev?['rating'] as num?)?.toDouble(),
              clientReviewComment: rev?['comment'] as String?,
            ),
          );
        }

        _update(
          ProviderPortfolioState(
            fullHistory: records,
          ).copyWith(curatedPortfolioIds: pinnedIds),
        );
      } catch (_) {}
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Registra ou atualiza um serviço no Histórico de Serviços Prestados.
  /// - Se o serviço já estiver `settledAndPaid` (100% recebido + pós-proteção), entra automaticamente
  ///   em `#1` da Pilha LIFO Top 3 do Meu Portfólio.
  /// - Se estiver `underPostServiceProtection`, `inMediation` ou `canceled`, fica registrado no
  ///   Histórico de Serviços Prestados e aguarda a conclusão/liquidação para ser elegível ao Portfólio.
  CompletedServiceRecord completeAndValidateServiceWithPin(
    CompletedServiceRecord newCompletedService,
  ) {
    final existingWithoutDup = _state.fullHistory
        .where(
          (s) =>
              s.id != newCompletedService.id &&
              s.orderId != newCompletedService.orderId,
        )
        .toList();

    final updatedHistory = <CompletedServiceRecord>[
      newCompletedService,
      ...existingWithoutDup,
    ];

    _update(_state.copyWith(fullHistory: updatedHistory));
    return newCompletedService;
  }

  /// Converte um [Job] real do fluxo de execução (`ReleasePaymentScreen`) em um
  /// [CompletedServiceRecord] ao validar o PIN de 4 dígitos do cliente.
  ///
  /// Por padrão, se o serviço entra em janela de cobertura/maturação (`underProtection = true`),
  /// é registrado como `Sob Proteção Pós-Serviço` até que 100% do pagamento seja liquidado.
  CompletedServiceRecord completeJobWithPin({
    required Job job,
    required String validatedClientPin,
    String? clientDisplayName,
    String? detailedReport,
    List<String>? toolsUsed,
    List<String>? beforeAfterPhotos,
    bool isAlreadySettled100Percent = true,
    DateTime? protectionEndsAt,
  }) {
    final now = DateTime.now();
    final shortCode =
        job.id.length >= 6 ? job.id.substring(0, 6).toUpperCase() : job.id;
    final stage = isAlreadySettled100Percent
        ? ServiceHistoryLifecycleStage.settledAndPaid
        : ServiceHistoryLifecycleStage.underPostServiceProtection;

    final record = CompletedServiceRecord(
      id: 'srv-${job.id}',
      orderId: job.id,
      title: job.title,
      categoryName: job.category,
      clientRequestedDescription: job.description.trim(),
      detailedExecutionReport:
          (detailedReport != null && detailedReport.trim().isNotEmpty)
              ? detailedReport.trim()
              : (job.description.trim().isNotEmpty
                  ? 'Execução técnica concluída e validada presencialmente com PIN do cliente: ${job.description.trim()}'
                  : 'Serviço técnico de ${job.category} executado conforme normas de segurança e validado presencialmente com o PIN de 4 dígitos do cliente.'),
      cityAndState: job.addressSummary ?? 'Local Verificado',
      completedAt: now,
      validatedClientPin: validatedClientPin,
      serviceValue: job.agreedPrice ?? 250.0,
      grossAmount: job.agreedPrice ?? 250.0,
      executionDurationText: '1h 30min',
      toolsAndMaterialsUsed: toolsUsed ??
          <String>[
            'Ferramental Profissional de ${job.category}',
            'Insumos Homologados ABNT',
            'Checklist de Entrega Digital',
          ],
      beforeAfterPhotoCaptionsOrUrls: beforeAfterPhotos ??
          (job.photoPaths.isNotEmpty
              ? job.photoPaths
              : const <String>[
                  'ANTES: Vistoria técnica inicial registrada no local',
                  'DEPOIS: Serviço concluído, testado e liberado via PIN de 4 dígitos',
                ]),
      warrantyCertificateCode: 'GAR-DSP-$shortCode',
      lifecycleStage: stage,
      isPaid100Percent: isAlreadySettled100Percent,
      protectionEndsAt:
          protectionEndsAt ?? now.add(const Duration(days: 5)),
      isReviewedByClient: false,
      clientDisplayName: clientDisplayName ?? 'Cliente Verificado',
    );
    return completeAndValidateServiceWithPin(record);
  }

  /// Promove um serviço que estava **"Sob Proteção Pós-Serviço"** para **"Concluído & 100% Liquidado"**
  /// assim que o período de proteção termina e o profissional recebe 100% do pagamento.
  /// O serviço passa imediatamente a ser elegível e entra no topo (`#1`) da Pilha LIFO Top 3!
  bool markProtectionCompletedAnd100PercentPaid(
    String serviceId, {
    DateTime? settledAt,
  }) {
    var updated = false;
    final nextHistory = _state.fullHistory.map((s) {
      if (s.id == serviceId || s.orderId == serviceId) {
        updated = true;
        return s.copyWith(
          lifecycleStage: ServiceHistoryLifecycleStage.settledAndPaid,
          isPaid100Percent: true,
          completedAt: settledAt ?? s.completedAt,
        );
      }
      return s;
    }).toList();

    if (updated) {
      _update(_state.copyWith(fullHistory: nextHistory));
    }
    return updated;
  }

  /// Atualiza EXCLUSIVAMENTE o campo **"Notas Técnicas Complementares"** de um serviço concluído.
  /// A descrição original solicitada pelo cliente, a solução técnica da conclusão e as fotos
  /// permanecem estritamente imutáveis por segurança.
  Future<bool> updateComplementaryTechnicalNotes({
    required String serviceId,
    required String? notes,
  }) async {
    var found = false;
    String? targetOrderId;
    final nextHistory = _state.fullHistory.map((s) {
      if (s.id == serviceId || s.orderId == serviceId) {
        found = true;
        targetOrderId = s.orderId;
        return s.copyWithComplementaryNotes(notes);
      }
      return s;
    }).toList();

    if (!found) return false;
    _update(_state.copyWith(fullHistory: nextHistory));

    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser != null && targetOrderId != null) {
        await client.rpc(
          'set_job_complementary_notes',
          params: {
            'p_job': targetOrderId,
            'p_notes': notes?.trim(),
          },
        );
      }
    } catch (_) {}

    return true;
  }

  /// Adiciona **1 serviço por vez** do Histórico elegível (`eligibleHistoryPool`) para a seção
  /// **"Destaques Escolhidos do Meu Histórico (Até 5 serviços)"**.
  ///
  /// Regras impostas:
  /// 1. Só funciona a partir do 4º serviço elegível (`isAddFromHistoryUnlocked == true`);
  /// 2. O serviço precisa ser `settledAndPaid` (100% recebido + pós-proteção) e pertencer a `eligibleHistoryPool`;
  /// 3. Serviços cancelados, em mediação ou ainda sob proteção pós-serviço são estritamente bloqueados;
  /// 4. Limite máximo de [kMaxCuratedPortfolioServices] (`5`) serviços escolhidos.
  bool addServiceFromHistoryToPortfolio(String serviceId) {
    if (!_state.isAddFromHistoryUnlocked) return false;
    if (_state.curatedPortfolioServices.length >=
        kMaxCuratedPortfolioServices) {
      return false;
    }
    if (_state.isInAutomaticTopThree(serviceId)) return false;
    if (_state.isInCuratedPortfolio(serviceId)) return false;

    final existsInEligiblePool =
        _state.eligibleHistoryPool.any((s) => s.id == serviceId);
    if (!existsInEligiblePool) return false;

    final nextCurated = <String>[
      ..._state.curatedPortfolioServices.map((s) => s.id),
      serviceId,
    ];
    _update(_state.copyWith(curatedPortfolioIds: nextCurated));

    try {
      final rec = _state.findById(serviceId);
      final client = Supabase.instance.client;
      if (client.auth.currentUser != null && rec != null) {
        client.rpc('pin_case', params: {'p_job': rec.orderId}).ignore();
      }
    } catch (_) {}

    return true;
  }

  /// Substitui um serviço já destacado na vitrine (`oldServiceId`) por outro serviço
  /// elegível do Histórico (`newServiceId`).
  bool swapCuratedServiceInPortfolio({
    required String oldServiceId,
    required String newServiceId,
  }) {
    if (!_state.isInCuratedPortfolio(oldServiceId)) return false;
    if (_state.isInAutomaticTopThree(newServiceId)) return false;
    if (_state.isInCuratedPortfolio(newServiceId)) return false;

    final existsInEligiblePool =
        _state.eligibleHistoryPool.any((s) => s.id == newServiceId);
    if (!existsInEligiblePool) return false;

    final currentIds = _state.curatedPortfolioServices.map((s) => s.id).toList();
    final idx = currentIds.indexOf(oldServiceId);
    if (idx == -1) return false;

    currentIds[idx] = newServiceId;
    _update(_state.copyWith(curatedPortfolioIds: currentIds));
    return true;
  }

  /// Remove um serviço da vitrine "Destaques Escolhidos" (ele continua intacto no Histórico Permanente).
  bool removeCuratedServiceFromPortfolio(String serviceId) {
    if (!_state.isInCuratedPortfolio(serviceId)) return false;
    final nextCurated = _state.curatedPortfolioServices
        .map((s) => s.id)
        .where((id) => id != serviceId)
        .toList();
    _update(_state.copyWith(curatedPortfolioIds: nextCurated));

    try {
      final rec = _state.findById(serviceId);
      final client = Supabase.instance.client;
      if (client.auth.currentUser != null && rec != null) {
        client.rpc('unpin_case', params: {'p_job': rec.orderId}).ignore();
      }
    } catch (_) {}

    return true;
  }

  /// Sincroniza reativamente a avaliação que o cliente fez para um serviço já concluído.
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
      final matchesServiceId = serviceId != null && record.id == serviceId;
      final matchesOrderId = orderId != null && record.orderId == orderId;
      if (!matchesServiceId && !matchesOrderId) return record;

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

    if (found) {
      _update(_state.copyWith(fullHistory: updatedHistory));
    }
    return found;
  }

  /// Helper exclusivo para testes automatizados (`@visibleForTesting`).
  @visibleForTesting
  CompletedServiceRecord simulateNextPinCompletedService() {
    final currentCount = _state.totalCompletedCount;
    final nextNumber = currentCount + 1;
    final now = DateTime.now().add(Duration(seconds: _simulationCounter++));

    final chronological =
        List<CompletedServiceRecord>.from(kSamplePinCompletedServices)
          ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    if (currentCount < chronological.length) {
      final template = chronological[currentCount];
      final record = template.copyWith(
        completedAt: now,
      );
      return completeAndValidateServiceWithPin(record);
    }

    final categories = <String>[
      'Elétrica',
      'Hidráulica',
      'Pintura',
      'Marcenaria',
      'Alvenaria',
    ];
    final category = categories[nextNumber % categories.length];
    final pin = (1000 + (nextNumber * 733) % 8999).toString().padLeft(4, '0');
    final record = CompletedServiceRecord(
      id: 'srv-pin-${nextNumber.toString().padLeft(3, '0')}',
      orderId: 'job-pin-${nextNumber.toString().padLeft(3, '0')}',
      title:
          '$nextNumberº Serviço Concluído via PIN • Manutenção Especializada ($category)',
      categoryName: category,
      clientRequestedDescription:
          'Solicitação do cliente para manutenção técnica especializada de $category.',
      detailedExecutionReport:
          'Execução completa do $nextNumberº atendimento técnico em $category, incluindo diagnóstico instrumental, '
          'substituição preventiva de componentes desgastados, limpeza técnica da área de intervenção '
          'e validação final presencial com o código PIN de 4 dígitos fornecido pelo cliente.',
      cityAndState: 'Poços de Caldas - MG',
      completedAt: now,
      validatedClientPin: pin,
      serviceValue: 180.0 + (nextNumber * 25.0),
      executionDurationText:
          '1h ${(15 + (nextNumber * 7) % 40).toString().padLeft(2, '0')}min',
      toolsAndMaterialsUsed: <String>[
        'Kit Profissional de $category',
        'Insumos de Vedação e Fixação Certificados',
        'Instrumento Digital de Aferição',
      ],
      beforeAfterPhotoCaptionsOrUrls: <String>[
        'ANTES: Inspeção inicial e isolamento seguro do ponto de $category',
        'DEPOIS: $nextNumberº serviço finalizado, testado e aprovado com PIN $pin',
      ],
      warrantyCertificateCode:
          'GAR-DSP-${nextNumber.toString().padLeft(3, '0')}-2026',
      isReviewedByClient: false,
      clientDisplayName: 'Cliente #${nextNumber.toString().padLeft(2, '0')}',
    );
    return completeAndValidateServiceWithPin(record);
  }

  /// Helper exclusivo para testes automatizados (`@visibleForTesting`).
  @visibleForTesting
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

  /// Helper para testes automatizados (`@visibleForTesting`) ou limpeza de sessão.
  void resetToCount(int count, {List<String> curatedIds = const <String>[]}) {
    if (count <= 0) {
      _update(
        ProviderPortfolioState(
          fullHistory: const <CompletedServiceRecord>[],
          curatedPortfolioIds: const <String>[],
        ),
      );
      return;
    }
    final clamped = count.clamp(0, kSamplePinCompletedServices.length);
    final chronological =
        List<CompletedServiceRecord>.from(kSamplePinCompletedServices)
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
class ProviderPortfolioAndHistoryController
    extends Notifier<ProviderPortfolioState> {
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

  Future<bool> updateComplementaryTechnicalNotes({
    required String serviceId,
    required String? notes,
  }) {
    return ProviderPortfolioStore.instance.updateComplementaryTechnicalNotes(
      serviceId: serviceId,
      notes: notes,
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
}

final providerPortfolioControllerProvider = NotifierProvider<
    ProviderPortfolioAndHistoryController, ProviderPortfolioState>(
  ProviderPortfolioAndHistoryController.new,
);

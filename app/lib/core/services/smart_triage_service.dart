import '../models/marketplace_models.dart';
import '../models/smart_triage_models.dart';
import '../utils/tag_normalizer.dart';

/// Motor de Triagem Inteligente Multimodal + Modo Contenção de Emergência (60s).
///
/// Combina análise semântica normalizada em PT-BR (radicais, sinônimos coloquiais,
/// sinais de risco crítico) com metadados de mídia anexada para classificar:
/// - Categoria ideal (`kCategories`);
/// - Nível de urgência (`UrgencyLevel`);
/// - Síntese técnica e causa raiz provável;
/// - Lista provável de peças (`ProbableMaterialItem`) e ferramental do prestador;
/// - Protocolo de Primeiros Socorros do Imóvel (`EmergencyContainmentGuide`).
class SmartTriageService {
  const SmartTriageService();

  static const SmartTriageService instance = SmartTriageService();

  /// Executa a análise multimodal de forma assíncrona (compatível com pipeline híbrido).
  Future<SmartTriageResult> analyzeMultimodal({
    required String rawText,
    List<String> mediaAttachments = const [],
    String? currentCategory,
    DateTime? now,
  }) async {
    return analyze(
      rawText: rawText,
      mediaAttachments: mediaAttachments,
      currentCategory: currentCategory,
      now: now,
    );
  }

  /// Executa a análise determinística de baixa latência ($O(N)$ no tamanho do texto).
  SmartTriageResult analyze({
    required String rawText,
    List<String> mediaAttachments = const [],
    String? currentCategory,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final combinedRaw = [
      rawText.trim(),
      ...mediaAttachments.map((m) => m.trim()),
    ].where((s) => s.isNotEmpty).join(' ');

    final norm = _normalizeText(combinedRaw);
    final tokens = norm.split(' ').where((t) => t.isNotEmpty).toSet();

    final domain = _detectDomain(norm, tokens, currentCategory);
    final mediaBonus = mediaAttachments.isEmpty
        ? 0.0
        : (0.04 * mediaAttachments.length.clamp(1, 4));

    return switch (domain) {
      _TriageDomain.gas => _buildGasTriage(norm, tokens, timestamp, mediaBonus),
      _TriageDomain.electrical =>
        _buildElectricalTriage(norm, tokens, timestamp, mediaBonus),
      _TriageDomain.plumbing =>
        _buildPlumbingTriage(norm, tokens, timestamp, mediaBonus),
      _TriageDomain.locksmith =>
        _buildLocksmithTriage(norm, tokens, timestamp, mediaBonus),
      _TriageDomain.roof =>
        _buildRoofTriage(norm, tokens, timestamp, mediaBonus),
      _TriageDomain.hvac =>
        _buildHvacTriage(norm, tokens, timestamp, mediaBonus),
      _TriageDomain.carpentry => _buildCarpentryTriage(
          norm,
          tokens,
          timestamp,
          mediaBonus,
          currentCategory: currentCategory,
        ),
    };
  }

  static String _normalizeText(String input) {
    final lower = _stripAccents(input.toLowerCase());
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _stripAccents(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      final idx = from.indexOf(ch);
      buf.write(idx >= 0 ? to[idx] : ch);
    }
    return buf.toString();
  }

  static bool _matchesAny(String norm, Set<String> tokens, List<String> terms) {
    for (final term in terms) {
      if (term.contains(' ')) {
        if (norm.contains(term)) return true;
      } else {
        if (tokens.contains(term) || norm.contains(term)) return true;
      }
    }
    return false;
  }

  static int _scoreTerms(String norm, Set<String> tokens, List<String> terms) {
    var score = 0;
    for (final term in terms) {
      if (term.contains(' ')) {
        if (norm.contains(term)) score += 3;
      } else if (tokens.contains(term)) {
        score += 2;
      } else if (norm.contains(term)) {
        score += 1;
      }
    }
    return score;
  }

  _TriageDomain _detectDomain(
    String norm,
    Set<String> tokens,
    String? currentCategory,
  ) {
    final gasScore = _scoreTerms(norm, tokens, const [
      'cheiro de gas',
      'cheiro forte de gas',
      'vazamento de gas',
      'vazando gas',
      'botijao',
      'glp',
      'pig tail',
      'pigtail',
      'aquecedor a gas',
      'registro de gas',
      'mangueira do gas',
      'fogao vazando',
      'gas encanado',
      'gas',
    ]);
    if (gasScore >= 3) return _TriageDomain.gas;

    final scores = <_TriageDomain, int>{
      _TriageDomain.gas: gasScore,
      _TriageDomain.electrical: _scoreTerms(norm, tokens, const [
        'disjuntor',
        'desarmando',
        'desarma',
        'curto',
        'curto circuito',
        'fio queimado',
        'cheiro de queimado',
        'pipocou',
        'saiu faisca',
        'faiscando',
        'faisca',
        'tomada',
        'chuveiro queimado',
        'chuveiro eletrico',
        'resistencia',
        'quadro eletrico',
        'qdc',
        'oscilacao',
        'fase',
        'sem luz',
        'energia',
        'eletrica',
        'eletricista',
        'interruptor',
        'choque',
      ]),
      _TriageDomain.plumbing: _scoreTerms(norm, tokens, const [
        'estourou o cano',
        'cano estourado',
        'cano rompido',
        'vazando muito',
        'vazamento',
        'vazando',
        'sifao',
        'registro espanado',
        'registro geral',
        'caixa acoplada',
        'transbordando',
        'hydra',
        'valvula',
        'infiltracao',
        'torneira',
        'encanador',
        'encanamento',
        'hidraulica',
        'pvc',
        'ralo',
        'esgoto',
        'entupido',
        'descarga',
      ]),
      _TriageDomain.locksmith: _scoreTerms(norm, tokens, const [
        'chave quebrou',
        'chave quebrou dentro',
        'chave quebrada',
        'fechadura',
        'trancada',
        'trancado para fora',
        'porta batida',
        'porta trancada',
        'cilindro',
        'miolo',
        'multiponto',
        'emperrada',
        'chaveiro',
        'tetra',
        'cadeado',
      ]),
      _TriageDomain.roof: _scoreTerms(norm, tokens, const [
        'goteira',
        'telhado',
        'telha',
        'telha quebrada',
        'calha',
        'calha entupida',
        'forro',
        'laje',
        'chuva',
        'rufo',
        'manta asfaltica',
        'plafon com agua',
      ]),
      _TriageDomain.hvac: _scoreTerms(norm, tokens, const [
        'ar condicionado',
        'ar-condicionado',
        'split',
        'evaporadora',
        'condensadora',
        'pingando agua',
        'ar pingando',
        'nao gela',
        'nao refrigera',
        'dreno',
        'climatizacao',
      ]),
      _TriageDomain.carpentry: _scoreTerms(norm, tokens, const [
        'guarda roupa',
        'armario',
        'porta caindo',
        'dobradica',
        'suporte de tv',
        'cortina cedendo',
        'prateleira',
        'prateleira solta',
        'gaveta',
        'mdf',
        'marcenaria',
        'montagem',
        'montador',
        'bucha',
        'parafuso',
      ]),
    };

    var bestDomain = _TriageDomain.carpentry;
    var bestScore = 0;
    scores.forEach((domain, score) {
      if (score > bestScore) {
        bestScore = score;
        bestDomain = domain;
      }
    });

    if (bestScore > 0) return bestDomain;

    // Fallback pela categoria já selecionada pelo cliente.
    final slug = normalizeTag(currentCategory ?? '');
    return switch (slug) {
      'gas e aquecedores' => _TriageDomain.gas,
      'eletrica' => _TriageDomain.electrical,
      'encanador' || 'desentupidora' || 'impermeabilizacao' =>
        _TriageDomain.plumbing,
      'chaveiro' => _TriageDomain.locksmith,
      'telhados e calhas' => _TriageDomain.roof,
      'ar-condicionado' => _TriageDomain.hvac,
      _ => _TriageDomain.carpentry,
    };
  }

  // ---------------------------------------------------------------------------
  // 1. HIDRÁULICA / ENCANAMENTO
  // ---------------------------------------------------------------------------
  SmartTriageResult _buildPlumbingTriage(
    String norm,
    Set<String> tokens,
    DateTime now,
    double mediaBonus,
  ) {
    final isBurst = _matchesAny(norm, tokens, const [
      'estourou',
      'rompido',
      'rompeu',
      'vazando muito',
      'alta pressao',
      'jorando',
      'jorrando',
      'alagando',
      'registro espanado',
      'transbordando',
    ]);
    final isSiphon = _matchesAny(norm, tokens, const ['sifao', 'pia', 'cubas']);
    final isToilet = _matchesAny(
      norm,
      tokens,
      const ['caixa acoplada', 'hydra', 'descarga', 'vaso'],
    );

    final urgency = isBurst ? UrgencyLevel.criticalEmergency : UrgencyLevel.high;
    final summary = isBurst
        ? 'Vazamento hidráulico ativo de alta vazão com risco de alagamento e infiltração estrutural.'
        : isSiphon
            ? 'Falha de vedação no conjunto de escoamento (sifão/anel de vedação) sob bancada.'
            : isToilet
                ? 'Desregulagem ou desgaste no mecanismo de admissão/obturação de descarga.'
                : 'Vazamento ou falha de estanqueidade em linha hidráulica residencial.';

    final rootCause = isBurst
        ? 'Ruptura de conexão/tubulação PVC sob pressão ou desgaste da sede do registro.'
        : isSiphon
            ? 'Ressecamento do anel de vedação DN40/DN50 ou folga na rosca do sifão extensivo.'
            : isToilet
                ? 'Membrana/obturador da válvula Hydra ou torre de entrada da caixa acoplada desgastada.'
                : 'Fadiga de vedação em junta roscável/soldável ou microfissura na tubulação.';

    return SmartTriageResult(
      id: 'triage-plumbing-${now.millisecondsSinceEpoch}',
      analyzedAt: now,
      suggestedCategoryId: 'encanador',
      suggestedCategoryName: 'Encanador',
      urgencyLevel: urgency,
      diagnosticSummary: summary,
      probableRootCause: rootCause,
      estimatedDurationRange: isBurst ? '60 a 120 min' : '45 a 90 min',
      confidenceScore: (0.91 + mediaBonus).clamp(0.75, 0.99),
      probableMaterials: const [
        ProbableMaterialItem(
          id: 'mat-hid-fita-ptfe',
          name: 'Fita veda-rosca PTFE 18mm x 10m',
          technicalSpec: 'Fita PTFE alta densidade para roscas hidráulicas 1/2" e 3/4"',
          estimatedQuantity: '1 rolo',
        ),
        ProbableMaterialItem(
          id: 'mat-hid-anel-pvc',
          name: 'Anel de vedação PVC DN40/DN50',
          technicalSpec: 'Borracha nitrílica para vedação de sifão e saída de esgoto',
          estimatedQuantity: '1 par',
        ),
        ProbableMaterialItem(
          id: 'mat-hid-sifao',
          name: 'Sifão universal extensivo',
          technicalSpec: 'Polipropileno articulado com copo inspecionável (1" a 1.1/2")',
          estimatedQuantity: '1 un',
          isOptional: true,
        ),
        ProbableMaterialItem(
          id: 'mat-hid-luva-correr',
          name: 'Luva de correr PVC marrom 25mm',
          technicalSpec: 'Reparo rápido de tubulação de água fria PN 750 kPa com o-ring',
          estimatedQuantity: '1 un',
        ),
        ProbableMaterialItem(
          id: 'mat-hid-adesivo-pvc',
          name: 'Adesivo plástico PVC + Solução limpadora',
          technicalSpec: 'Solda fria para conexões PVC marrom água fria (bisnaga 75g)',
          estimatedQuantity: '1 un',
          isOptional: true,
        ),
        ProbableMaterialItem(
          id: 'mat-hid-reparo-hydra',
          name: 'Reparo de válvula Hydra / Caixa acoplada',
          technicalSpec: 'Kit obturador + vedante compatível com 1.1/2" ou mecanismo universal',
          estimatedQuantity: '1 kit',
          isOptional: true,
        ),
      ],
      recommendedProviderTools: const [
        'Chave grifo 12"',
        'Serra arco manual com lâmina bimetal',
        'Chave inglesa ajustável 10"',
        'Secador / pano técnico absorvente',
        'Manômetro de pressão hidráulica',
      ],
      containmentGuide: EmergencyContainmentGuide(
        id: 'contain-plumbing',
        emergencyTypeTitle:
            'Protocolo de Contenção: Vazamento Hidráulico de Alta Pressão',
        targetActionSeconds: 60,
        criticalProhibitions: const [
          'Não encoste em tomadas ou extensões molhadas próximas ao vazamento',
          'Não force registros emperrados com alicates pesados para não quebrar o cano na parede',
        ],
        steps: const [
          ContainmentStep(
            stepNumber: 1,
            title: 'Feche o registro geral imediatamente',
            description:
                'Gire o registro geral do imóvel ou do ambiente (banheiro/cozinha) no sentido horário até estancar o fluxo.',
            iconKey: 'valve',
          ),
          ContainmentStep(
            stepNumber: 2,
            title: 'Abra a torneira mais baixa do ambiente',
            description:
                'Escoe a água acumulada na tubulação para aliviar a pressão sobre o ponto rompido.',
            iconKey: 'faucet',
          ),
          ContainmentStep(
            stepNumber: 3,
            title: 'Afaste móveis e desligue o disjuntor se houver água perto de tomadas',
            description:
                'Se a lâmina d\'água se aproximar de tomadas baixas ou réguas de energia, desarme o circuito no quadro elétrico.',
            iconKey: 'power_off',
            isCriticalSafetyWarning: true,
            safetyWarningBadgeText: 'RISCO DE CHOQUE ELÉTRICO',
          ),
        ],
        emergencyPublicPhone: isBurst ? '199' : null,
        emergencyPublicLabel:
            isBurst ? 'Acionar Defesa Civil (199)' : null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. ELÉTRICA RESIDENCIAL
  // ---------------------------------------------------------------------------
  SmartTriageResult _buildElectricalTriage(
    String norm,
    Set<String> tokens,
    DateTime now,
    double mediaBonus,
  ) {
    final isCritical = _matchesAny(norm, tokens, const [
      'cheiro de queimado',
      'fio queimado',
      'pipocou',
      'saiu faisca',
      'faiscando',
      'faisca',
      'fumaca',
      'curto',
      'curto circuito',
      'derreteu',
      'pegando fogo',
      'choque',
    ]);
    final isShower = _matchesAny(norm, tokens, const ['chuveiro', 'resistencia', 'banho']);

    final urgency =
        isCritical ? UrgencyLevel.criticalEmergency : UrgencyLevel.high;
    final summary = isCritical
        ? 'Anomalia elétrica severa com curto-circuito/sobreaquecimento de condutores e risco térmico.'
        : isShower
            ? 'Desarme por sobrecarga ou falha no circuito exclusivo do chuveiro elétrico.'
            : 'Desarme recorrente de proteção no QDC ou falha de contato em ponto de força.';

    final rootCause = isCritical
        ? 'Conexão frouxa provocando arco voltaico (efeito Joule) ou falha de isolamento entre fase e neutro/terra.'
        : isShower
            ? 'Dimensionamento de disjuntor/emenda oxidada ou resistência em curto parcial.'
            : 'Fadiga térmica do disjuntor termomagnético ou sobrecarga no circuito terminal.';

    return SmartTriageResult(
      id: 'triage-electrical-${now.millisecondsSinceEpoch}',
      analyzedAt: now,
      suggestedCategoryId: 'eletrica',
      suggestedCategoryName: 'Elétrica',
      urgencyLevel: urgency,
      diagnosticSummary: summary,
      probableRootCause: rootCause,
      estimatedDurationRange: '45 a 90 min',
      confidenceScore: (0.93 + mediaBonus).clamp(0.78, 0.99),
      probableMaterials: const [
        ProbableMaterialItem(
          id: 'mat-ele-disjuntor-din',
          name: 'Disjuntor DIN Monopolar/Bipolar Curva C (16A/20A/32A/40A)',
          technicalSpec: 'Padrão IEC/NBR NM 60898 3kA/5kA compatível com barramento DIN',
          estimatedQuantity: '1 un',
        ),
        ProbableMaterialItem(
          id: 'mat-ele-conector-wago',
          name: 'Conector a mola Wago 221 (4mm² / 6mm²)',
          technicalSpec: 'Conector de emenda rápida antichama até 32A/41A (evita aquecimento)',
          estimatedQuantity: '3 un',
        ),
        ProbableMaterialItem(
          id: 'mat-ele-cabo-flex',
          name: 'Cabo flexível antichama 750V (2,5mm² a 6mm²)',
          technicalSpec: 'Condutor de cobre eletrolítico PVC/BWF NBR NM 247-3 para saneamento de pontas',
          estimatedQuantity: '2 metros',
        ),
        ProbableMaterialItem(
          id: 'mat-ele-fita-isolante',
          name: 'Fita isolante 3M Classe A (19mm x 5m)',
          technicalSpec: 'Autoextinguível antichama até 90°C / 750V ABNT NBR NM 60454',
          estimatedQuantity: '1 rolo',
        ),
        ProbableMaterialItem(
          id: 'mat-ele-tomada-20a',
          name: 'Módulo de Tomada 20A padrão NBR 14136',
          technicalSpec: 'Bornes reforçados em latão para aparelhos de maior potência',
          estimatedQuantity: '1 un',
          isOptional: true,
        ),
      ],
      recommendedProviderTools: const [
        'Multímetro digital True RMS',
        'Alicate amperímetro digital',
        'Detector de tensão sem contato',
        'Alicate decapador e prensa-terminais',
        'Chaves fenda/phillips isoladas 1000V VDE',
      ],
      containmentGuide: const EmergencyContainmentGuide(
        id: 'contain-electrical',
        emergencyTypeTitle:
            'Protocolo de Contenção: Curto-Circuito / Risco Elétrico no Imóvel',
        targetActionSeconds: 60,
        criticalProhibitions: [
          'Não toque no quadro elétrico com os pés descalços ou com as mãos úmidas',
          'Não tente forçar ou segurar a alavanca do disjuntor que está desarmando',
          'Nunca jogue água em tomadas, chuveiros ou fiação com fumaça/faísca',
        ],
        steps: [
          ContainmentStep(
            stepNumber: 1,
            title: 'Desligue imediatamente o Disjuntor Geral no QDC',
            description:
                'Calce um sapato de sola de borracha seca e desarme a chave geral do quadro de distribuição.',
            iconKey: 'breaker',
            isCriticalSafetyWarning: true,
            safetyWarningBadgeText: 'RISCO DE CHOQUE ELÉTRICO',
          ),
          ContainmentStep(
            stepNumber: 2,
            title: 'Afaste-se de partes metálicas, registros e paredes úmidas',
            description:
                'Não encoste em torneiras metálicas, box de banheiro ou eletrodomésticos em falha.',
            iconKey: 'bolt_off',
            isCriticalSafetyWarning: true,
            safetyWarningBadgeText: 'FUGA DE CORRENTE',
          ),
          ContainmentStep(
            stepNumber: 3,
            title: 'Retire os aparelhos da tomada somente após cortar a energia',
            description:
                'Com o disjuntor geral desligado, desconecte o equipamento pelo plugue (nunca puxe pelo fio).',
            iconKey: 'power_off',
          ),
        ],
        emergencyPublicPhone: '193',
        emergencyPublicLabel: 'Acionar Corpo de Bombeiros (193)',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. GÁS / AQUECEDORES
  // ---------------------------------------------------------------------------
  SmartTriageResult _buildGasTriage(
    String norm,
    Set<String> tokens,
    DateTime now,
    double mediaBonus,
  ) {
    return SmartTriageResult(
      id: 'triage-gas-${now.millisecondsSinceEpoch}',
      analyzedAt: now,
      suggestedCategoryId: 'gas e aquecedores',
      suggestedCategoryName: 'Gás e Aquecedores',
      urgencyLevel: UrgencyLevel.criticalEmergency,
      diagnosticSummary:
          'Suspeita crítica de vazamento de gás combustível (GLP/GN) ou falha de estanqueidade em aquecedor/fogão.',
      probableRootCause:
          'Fadiga da mangueira flexível/pig-tail, perda de vedação no regulador de pressão ou falha na válvula solenoide.',
      estimatedDurationRange: '40 a 75 min',
      confidenceScore: (0.95 + mediaBonus).clamp(0.82, 0.99),
      probableMaterials: const [
        ProbableMaterialItem(
          id: 'mat-gas-mangueira-aco',
          name: 'Mangueira flexível em malha de aço NBR 14955 (1,25m)',
          technicalSpec: 'Tubo metálico flexível normatizado para gás GLP/GN alta temperatura',
          estimatedQuantity: '1 un',
        ),
        ProbableMaterialItem(
          id: 'mat-gas-regulador',
          name: 'Regulador de pressão de gás com manômetro',
          technicalSpec: 'Válvula reguladora 2,8 kPa certificada INMETRO com indicador de estanqueidade',
          estimatedQuantity: '1 un',
        ),
        ProbableMaterialItem(
          id: 'mat-gas-abracadeira',
          name: 'Par de abraçadeiras sem-fim em aço inox',
          technicalSpec: 'Aço inoxidável AISI 304 para aperto de segurança em espigão',
          estimatedQuantity: '1 par',
        ),
        ProbableMaterialItem(
          id: 'mat-gas-fita-ptfe',
          name: 'Fita veda-rosca específica para gás (alta densidade)',
          technicalSpec: 'PTFE amarela de alta gramatura resistente a hidrocarbonetos (NBR 16358)',
          estimatedQuantity: '1 rolo',
        ),
      ],
      recommendedProviderTools: const [
        'Detector eletrônico de gás combustível (explosímetro)',
        'Espuma técnica de teste de estanqueidade',
        'Chave ajustável calibrada (250mm)',
        'Manômetro de coluna / teste de rede de gás',
      ],
      containmentGuide: const EmergencyContainmentGuide(
        id: 'contain-gas',
        emergencyTypeTitle:
            'Protocolo Crítico: Vazamento de Gás (Risco de Deflagração)',
        targetActionSeconds: 60,
        criticalProhibitions: [
          'Não ligue nem desligue interruptores de luz (qualquer tecla gera faísca interna)',
          'Não utilize fósforos, isqueiros, velas ou acenda bocas do fogão',
          'Não tire nem coloque plugues na tomada no ambiente com cheiro de gás',
        ],
        steps: [
          ContainmentStep(
            stepNumber: 1,
            title: 'Não acione nenhum interruptor elétrico ou aparelho',
            description:
                'Deixe as luzes e aparelhos exatamente como estão para evitar microfaíscas de contato.',
            iconKey: 'no_flash',
            isCriticalSafetyWarning: true,
            safetyWarningBadgeText: 'PROIBIDO ACIONAR INTERRUPTORES',
          ),
          ContainmentStep(
            stepNumber: 2,
            title: 'Feche o registro do gás ou a borboleta do botijão',
            description:
                'Gire a válvula manual do botijão ou o registro de corte rápido da tubulação para a posição fechada.',
            iconKey: 'gas_meter',
          ),
          ContainmentStep(
            stepNumber: 3,
            title: 'Abra todas as janelas e portas externas imediatamente',
            description:
                'Promova ventilação natural cruzada para dissipar a concentração de gás do ambiente.',
            iconKey: 'window',
          ),
          ContainmentStep(
            stepNumber: 4,
            title: 'Retire pessoas e animais do cômodo afetado',
            description:
                'Aguarde em local aberto e ventilado caso o cheiro permaneça intenso.',
            iconKey: 'evacuate',
            isCriticalSafetyWarning: true,
            safetyWarningBadgeText: 'RISCO DE EXPLOSÃO / ASFIXIA',
          ),
        ],
        emergencyPublicPhone: '193',
        emergencyPublicLabel: 'Acionar Corpo de Bombeiros (193)',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. CHAVEIRO / FECHADURAS E ACESSO
  // ---------------------------------------------------------------------------
  SmartTriageResult _buildLocksmithTriage(
    String norm,
    Set<String> tokens,
    DateTime now,
    double mediaBonus,
  ) {
    final isLockedOut = _matchesAny(norm, tokens, const [
      'trancado para fora',
      'preso',
      'porta batida',
      'chave quebrou',
      'chave quebrada',
      'nao abre',
    ]);

    return SmartTriageResult(
      id: 'triage-locksmith-${now.millisecondsSinceEpoch}',
      analyzedAt: now,
      suggestedCategoryId: 'chaveiro',
      suggestedCategoryName: 'Chaveiro',
      urgencyLevel: isLockedOut ? UrgencyLevel.high : UrgencyLevel.medium,
      diagnosticSummary:
          'Bloqueio mecânico de cilindro/fechadura ou fragmento de chave retido no tambor.',
      probableRootCause:
          'Fadiga metálica da lâmina da chave por desalinhamento de lingueta ou travamento dos pinos do cilindro.',
      estimatedDurationRange: '25 a 50 min',
      confidenceScore: (0.92 + mediaBonus).clamp(0.78, 0.99),
      probableMaterials: const [
        ProbableMaterialItem(
          id: 'mat-cha-cilindro-55',
          name: 'Cilindro / Miolo monobloco padrão 55mm',
          technicalSpec: 'Cilindro em latão maciço com 2 chaves multiponto/yale compatível',
          estimatedQuantity: '1 un',
        ),
        ProbableMaterialItem(
          id: 'mat-cha-fechadura-aux',
          name: 'Fechadura auxiliar tetra / rolete de reposição',
          technicalSpec: 'Máquina de embutir testa inox para portas de madeira ou metálicas',
          estimatedQuantity: '1 un',
          isOptional: true,
        ),
        ProbableMaterialItem(
          id: 'mat-cha-grafite',
          name: 'Grafite em pó lubrificante a seco (15g)',
          technicalSpec: 'Lubrificante mineral seco específico para pinos e molas de cilindros',
          estimatedQuantity: '1 frasco',
        ),
      ],
      recommendedProviderTools: const [
        'Kit de michas profissionais de precisão',
        'Extrator de chave quebrada em aço mola',
        'Chave phillips e extrator de rotor',
        'Furadeira de impacto (último recurso em cilindro travado)',
      ],
      containmentGuide: const EmergencyContainmentGuide(
        id: 'contain-locksmith',
        emergencyTypeTitle:
            'Orientação de Preservação: Fechadura / Chave Quebrada',
        targetActionSeconds: 60,
        criticalProhibitions: [
          'Não introduza facas, grampos, clipes ou arames dentro do miolo',
          'Não pingue óleo de cozinha, desengripante oleoso ou supercola na chave quebrada',
        ],
        steps: [
          ContainmentStep(
            stepNumber: 1,
            title: 'Pare de forçar o giro da chave ou da maçaneta',
            description:
                'Forçar o tambor entorta as guardas internas e impede a extração limpa sem troca da máquina.',
            iconKey: 'lock',
          ),
          ContainmentStep(
            stepNumber: 2,
            title: 'Não aplique óleo de cozinha nem supercola no cilindro',
            description:
                'Líquidos colam os pinos de latão, inutilizam a fechadura inteira e triplicam o custo do reparo.',
            iconKey: 'warning',
            isCriticalSafetyWarning: true,
            safetyWarningBadgeText: 'EVITE DANO TOTAL À FECHADURA',
          ),
          ContainmentStep(
            stepNumber: 3,
            title: 'Guarde a parte da chave que ficou na sua mão',
            description:
                'O chaveiro utiliza o fragmento externo junto com a ponta extraída para confeccionar uma chave nova no local.',
            iconKey: 'shield',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. TELHADO / CALHAS / INFILTRAÇÃO DE CHUVA
  // ---------------------------------------------------------------------------
  SmartTriageResult _buildRoofTriage(
    String norm,
    Set<String> tokens,
    DateTime now,
    double mediaBonus,
  ) {
    final activeLeak = _matchesAny(
      norm,
      tokens,
      const ['goteira', 'chovendo', 'forro', 'laje', 'transbordando', 'caindo agua'],
    );

    return SmartTriageResult(
      id: 'triage-roof-${now.millisecondsSinceEpoch}',
      analyzedAt: now,
      suggestedCategoryId: 'telhados e calhas',
      suggestedCategoryName: 'Telhados e Calhas',
      urgencyLevel:
          activeLeak ? UrgencyLevel.criticalEmergency : UrgencyLevel.high,
      diagnosticSummary:
          'Infiltração pluvial ativa por deslocamento/trinca de telha ou obstrução de calha coletora.',
      probableRootCause:
          'Ruptura de telha/cumeeira, falha de vedação no rufo com a alvenaria ou estrangulamento do bocal de descida da calha.',
      estimatedDurationRange: '90 a 180 min',
      confidenceScore: (0.90 + mediaBonus).clamp(0.75, 0.99),
      probableMaterials: const [
        ProbableMaterialItem(
          id: 'mat-tel-manta',
          name: 'Manta asfáltica aluminizada autoadesiva (20cm x 10m)',
          technicalSpec: 'Fita multivedação refletiva para trincas, rufos e encontros de telhado',
          estimatedQuantity: '1 rolo',
        ),
        ProbableMaterialItem(
          id: 'mat-tel-pu40',
          name: 'Selante elástico PU40 Construção Civil (380g)',
          technicalSpec: 'Poliuretano monocomponente resistente a raios UV para calhas e rufos',
          estimatedQuantity: '2 tubos',
        ),
        ProbableMaterialItem(
          id: 'mat-tel-telha',
          name: 'Telha de reposição compatível (cerâmica / fibrocimento)',
          technicalSpec: 'Substituição de peças trincadas por granizo, vento ou dilatação',
          estimatedQuantity: '2 a 4 un',
          isOptional: true,
        ),
        ProbableMaterialItem(
          id: 'mat-tel-rufo',
          name: 'Veda-calha / Rufo polimérico impermeabilizante',
          technicalSpec: 'Vedação de emendas de chapa galvanizada e condutores pluviais',
          estimatedQuantity: '1 un',
          isOptional: true,
        ),
      ],
      recommendedProviderTools: const [
        'Escada extensível com sapata antiderrapante',
        'Kit EPI de trabalho em altura (NR-35)',
        'Espátula de aço e rolo de pressão',
        'Soprador térmico para aderência de manta',
      ],
      containmentGuide: const EmergencyContainmentGuide(
        id: 'contain-roof',
        emergencyTypeTitle:
            'Protocolo de Contenção: Goteira / Infiltração Pluvial Ativa',
        targetActionSeconds: 60,
        criticalProhibitions: [
          'Não suba no telhado molhado ou durante chuva (risco gravíssimo de queda e descarga atmosférica)',
          'Não toque em lustres ou luminárias onde houver gotejamento pelo forro',
        ],
        steps: [
          ContainmentStep(
            stepNumber: 1,
            title: 'Desligue o circuito de iluminação do cômodo afetado',
            description:
                'A água acumulada sobre o forro de gesso/laje passa pelos conduítes do plafon e energiza o teto.',
            iconKey: 'breaker',
            isCriticalSafetyWarning: true,
            safetyWarningBadgeText: 'RISCO DE CHOQUE E QUEDA DE GESSO',
          ),
          ContainmentStep(
            stepNumber: 2,
            title: 'Posicione baldes com um pano dobrado no fundo',
            description:
                'O tecido amortece a queda da gota, evitando que a água respingue em pisos de madeira e paredes.',
            iconKey: 'roof',
          ),
          ContainmentStep(
            stepNumber: 3,
            title: 'Cubra móveis, colchões e eletrônicos com plástico ou lona',
            description:
                'Afaste os equipamentos da vertical da goteira e jamais tente subir no telhado úmido.',
            iconKey: 'shield',
          ),
        ],
        emergencyPublicPhone: '199',
        emergencyPublicLabel: 'Acionar Defesa Civil (199)',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. CLIMATIZAÇÃO / AR-CONDICIONADO
  // ---------------------------------------------------------------------------
  SmartTriageResult _buildHvacTriage(
    String norm,
    Set<String> tokens,
    DateTime now,
    double mediaBonus,
  ) {
    final leakingWater = _matchesAny(
      norm,
      tokens,
      const ['pingando', 'vazando agua', 'escorrendo', 'molhando', 'dreno'],
    );

    return SmartTriageResult(
      id: 'triage-hvac-${now.millisecondsSinceEpoch}',
      analyzedAt: now,
      suggestedCategoryId: 'ar-condicionado',
      suggestedCategoryName: 'Ar-condicionado',
      urgencyLevel: leakingWater ? UrgencyLevel.high : UrgencyLevel.medium,
      diagnosticSummary: leakingWater
          ? 'Transbordamento da bandeja de condensado pela unidade evaporadora interna (Split).'
          : 'Queda de rendimento térmico ou falha de partida no sistema de climatização.',
      probableRootCause: leakingWater
          ? 'Obstrução por biofilme/lodo na mangueira de dreno ou perda de caimento hidráulico da evaporadora.'
          : 'Capacitor de partida esgotado, filtros saturados ou baixa carga de fluido refrigerante.',
      estimatedDurationRange: '45 a 90 min',
      confidenceScore: (0.91 + mediaBonus).clamp(0.76, 0.99),
      probableMaterials: const [
        ProbableMaterialItem(
          id: 'mat-ac-mangueira-dreno',
          name: 'Mangueira cristal / corrugada de dreno 5/8"',
          technicalSpec: 'Tubo flexível anti-estrangulamento para escoamento de condensado',
          estimatedQuantity: '2 metros',
        ),
        ProbableMaterialItem(
          id: 'mat-ac-capacitor',
          name: 'Capacitor permanente 35µF / 450V VAC',
          technicalSpec: 'Capacitor de partida do compressor/ventilador certificado 50/60Hz',
          estimatedQuantity: '1 un',
          isOptional: true,
        ),
        ProbableMaterialItem(
          id: 'mat-ac-fita-elastomerica',
          name: 'Fita elastomérica de isolamento térmico',
          technicalSpec: 'Vedação anticondensação para tubulação frigorígena e conexão de dreno',
          estimatedQuantity: '1 rolo',
        ),
      ],
      recommendedProviderTools: const [
        'Bomba desentupidora de dreno por vácuo/pressão',
        'Manifold digital e termômetro penta',
        'Multímetro True RMS com capacímetro',
        'Bolsa coletora de higienização de Split',
      ],
      containmentGuide: const EmergencyContainmentGuide(
        id: 'contain-hvac',
        emergencyTypeTitle:
            'Protocolo de Contenção: Split Pingando / Falha de Ar-Condicionado',
        targetActionSeconds: 60,
        criticalProhibitions: [
          'Não mantenha o ar-condicionado ligado enquanto goteja pela parte elétrica da evaporadora',
        ],
        steps: [
          ContainmentStep(
            stepNumber: 1,
            title: 'Desligue o aparelho pelo controle remoto imediatamente',
            description:
                'Interrompa a condensação na serpentina para cessar a geração de água na bandeja interna.',
            iconKey: 'ac_unit',
          ),
          ContainmentStep(
            stepNumber: 2,
            title: 'Desarme o disjuntor exclusivo do ar-condicionado no QDC',
            description:
                'Protege a placa eletrônica inversora contra curto-circuito causado por gotejamento interno.',
            iconKey: 'breaker',
            isCriticalSafetyWarning: true,
            safetyWarningBadgeText: 'PROTEÇÃO DA PLACA INVERSORA',
          ),
          ContainmentStep(
            stepNumber: 3,
            title: 'Forre o piso e afaste eletrônicos posicionados abaixo do Split',
            description:
                'Coloque toalhas secas sobre piso laminado/madeira e retire TVs ou tomadas da linha de gotejamento.',
            iconKey: 'shield',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. MARCENARIA / MONTAGEM / REPAROS GERAIS
  // ---------------------------------------------------------------------------
  SmartTriageResult _buildCarpentryTriage(
    String norm,
    Set<String> tokens,
    DateTime now,
    double mediaBonus, {
    String? currentCategory,
  }) {
    final isAssembly = _matchesAny(
      norm,
      tokens,
      const ['montar', 'montagem', 'desmontar', 'caixa fechada', 'guarda roupa novo'],
    );
    final isWallMount = _matchesAny(
      norm,
      tokens,
      const ['suporte de tv', 'cortina', 'varao', 'prateleira', 'quadro', 'bucha'],
    );
    final isFalling = _matchesAny(
      norm,
      tokens,
      const ['caindo', 'cedendo', 'soltou', 'despencando', 'quebrou a dobradica'],
    );

    final matchedCat = _resolveFallbackCategory(
      currentCategory: currentCategory,
      isAssembly: isAssembly,
      isWallMount: isWallMount,
    );

    return SmartTriageResult(
      id: 'triage-carpentry-${now.millisecondsSinceEpoch}',
      analyzedAt: now,
      suggestedCategoryId: normalizeTag(matchedCat),
      suggestedCategoryName: matchedCat,
      urgencyLevel: isFalling ? UrgencyLevel.high : UrgencyLevel.medium,
      diagnosticSummary: isWallMount
          ? 'Ancoragem estrutural ou reinstalação de suporte/prateleira com reforço de fixação em alvenaria/drywall.'
          : 'Regulagem estrutural de marcenaria, substituição de ferragens articuladas e realinhamento de portas/gavetas.',
      probableRootCause: isWallMount
          ? 'Subdimensionamento de bucha para o tipo de parede (oco/drywall) ou fadiga por carga dinâmica.'
          : 'Fadiga da mola da dobradiça caneco 35mm ou esgarçamento dos furos de fixação no MDF/MDP.',
      estimatedDurationRange: '40 a 80 min',
      confidenceScore: (0.89 + mediaBonus).clamp(0.75, 0.98),
      probableMaterials: const [
        ProbableMaterialItem(
          id: 'mat-mar-dobradica-35',
          name: 'Dobradiça caneco 35mm em aço com amortecedor',
          technicalSpec: 'Abertura 110° com pistão integrado e calço de regulagem 3D',
          estimatedQuantity: '2 un',
        ),
        ProbableMaterialItem(
          id: 'mat-mar-buchas',
          name: 'Kit buchas de fixação universal / drywall (6mm, 8mm e 10mm)',
          technicalSpec: 'Buchas de nylon com abas anti-giro para tijolo vazado, concreto e gesso',
          estimatedQuantity: '6 un',
        ),
        ProbableMaterialItem(
          id: 'mat-mar-parafusos',
          name: 'Parafusos chipboard flangeados (4,0x40mm e 3,5x16mm)',
          technicalSpec: 'Aço bicromatizado rosca soberba para MDF/madeira e bucha de parede',
          estimatedQuantity: '12 un',
        ),
        ProbableMaterialItem(
          id: 'mat-mar-cantoneira',
          name: 'Cantoneira de reforço em L (aço zincado) + chapa reparadora',
          technicalSpec: 'Chapa de reparo para recuperar furação espanada em lateral de MDF',
          estimatedQuantity: '2 un',
          isOptional: true,
        ),
      ],
      recommendedProviderTools: const [
        'Parafusadeira profissional com controle de torque',
        'Furadeira de impacto + brocas multimaterial/vídea',
        'Nível a laser / bolha magnético',
        'Detector eletrônico de tubulação e fiação na parede',
      ],
      containmentGuide: const EmergencyContainmentGuide(
        id: 'contain-carpentry',
        emergencyTypeTitle:
            'Protocolo de Preservação: Móvel / Suporte Cedendo',
        targetActionSeconds: 60,
        criticalProhibitions: [
          'Não force o fechamento de portas com dobradiça solta para não arrancar a folha de MDF',
        ],
        steps: [
          ContainmentStep(
            stepNumber: 1,
            title: 'Esvazie imediatamente o peso da prateleira ou suporte afetado',
            description:
                'Retire TV, livros, louças ou roupas pesadas para cessar a tração sobre as buchas e parafusos.',
            iconKey: 'support',
          ),
          ContainmentStep(
            stepNumber: 2,
            title: 'Escore a porta ou peça solta até a chegada do profissional',
            description:
                'Apoie a folha da porta com calço na base para evitar que o peso rasgue a madeira da outra dobradiça.',
            iconKey: 'handyman',
          ),
          ContainmentStep(
            stepNumber: 3,
            title: 'Isole a área abaixo do móvel ou suporte',
            description:
                'Mantenha crianças e animais afastados caso haja risco de desprendimento de peças ou vidros.',
            iconKey: 'shield',
          ),
        ],
      ),
    );
  }

  String _resolveFallbackCategory({
    required String? currentCategory,
    required bool isAssembly,
    required bool isWallMount,
  }) {
    if (isAssembly) return 'Montagem';
    if (isWallMount) return 'Pequenos Reparos';
    if (currentCategory != null &&
        kCategories.any((c) => c.name == currentCategory)) {
      return currentCategory;
    }
    return 'Marcenaria';
  }
}

enum _TriageDomain {
  plumbing,
  electrical,
  gas,
  locksmith,
  roof,
  hvac,
  carpentry,
}

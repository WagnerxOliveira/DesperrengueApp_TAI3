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
/// - Protocolo de Primeiros Socorros do Imóvel (`EmergencyContainmentGuide`) — exibido
///   APENAS quando há risco emergencial real (vazamento de gás, curto elétrico,
///   rompimento hidráulico, infiltração de telhado ativa, chave quebrada ou queda de estrutura).
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
      _TriageDomain.painting =>
        _buildPaintingTriage(norm, tokens, timestamp, mediaBonus),
      _TriageDomain.carpentry => _buildCarpentryTriage(
          norm,
          tokens,
          timestamp,
          mediaBonus,
          currentCategory: currentCategory,
        ),
      _TriageDomain.specialized => _buildSpecializedCategoryTriage(
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

    final slug = normalizeTag(currentCategory ?? '');

    final elecScore = _scoreTerms(norm, tokens, const [
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
    ]);

    final plumbScore = _scoreTerms(norm, tokens, const [
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
      'torneira',
      'encanador',
      'encanamento',
      'hidraulica',
      'pvc',
      'descarga',
    ]);

    final lockScore = _scoreTerms(norm, tokens, const [
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
    ]);

    final roofScore = _scoreTerms(norm, tokens, const [
      'goteira',
      'telhado',
      'telha',
      'telha quebrada',
      'calha',
      'calha entupida',
      'rufo',
      'manta asfaltica',
      'plafon com agua',
    ]);

    final hvacScore = _scoreTerms(norm, tokens, const [
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
    ]);

    final paintScore = _scoreTerms(norm, tokens, const [
      'pintura',
      'pintar',
      'pintor',
      'tinta',
      'massa corrida',
      'massa acrilica',
      'selador',
      'parede descascando',
      'descascando',
      'repintar',
      'demao',
      'lixar parede',
      'textura',
      'grafiato',
      'verniz',
      'esmalte sintetico',
    ]);

    final carpScore = _scoreTerms(norm, tokens, const [
      'guarda roupa',
      'armario',
      'porta caindo',
      'dobradica',
      'prateleira solta',
      'gaveta',
      'mdf',
      'marcenaria',
      'marceneiro',
      'montagem de moveis',
      'montar guarda roupa',
      'montador',
    ]);

    // Se o cliente JÁ escolheu uma categoria oficial na tela, respeitamos a escolha dele
    // (a menos que haja uma emergência crítica inequívoca de outra área no relato, score >= 5).
    if (slug.isNotEmpty) {
      if (elecScore >= 5 && slug != 'eletrica') return _TriageDomain.electrical;
      if (plumbScore >= 5 && slug != 'encanador' && slug != 'desentupidora') {
        return _TriageDomain.plumbing;
      }
      if (roofScore >= 5 && slug != 'telhados e calhas') return _TriageDomain.roof;
      if (lockScore >= 5 && slug != 'chaveiro') return _TriageDomain.locksmith;

      return switch (slug) {
        'pintura' => _TriageDomain.painting,
        'gas e aquecedores' => _TriageDomain.gas,
        'eletrica' => _TriageDomain.electrical,
        'encanador' => _TriageDomain.plumbing,
        'chaveiro' => _TriageDomain.locksmith,
        'telhados e calhas' => _TriageDomain.roof,
        'ar-condicionado' => _TriageDomain.hvac,
        'marcenaria' || 'montagem' || 'pequenos reparos' => _TriageDomain.carpentry,
        _ => _TriageDomain.specialized,
      };
    }

    final scores = <_TriageDomain, int>{
      _TriageDomain.gas: gasScore,
      _TriageDomain.electrical: elecScore,
      _TriageDomain.plumbing: plumbScore,
      _TriageDomain.locksmith: lockScore,
      _TriageDomain.roof: roofScore,
      _TriageDomain.hvac: hvacScore,
      _TriageDomain.painting: paintScore,
      _TriageDomain.carpentry: carpScore,
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

    final detectedCat = _detectSpecializedCategoryFromText(norm, tokens);
    if (detectedCat != null) {
      return _TriageDomain.specialized;
    }

    return _TriageDomain.carpentry;
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
  // 7. PINTURA RESIDENCIAL E TRATAMENTO DE SUPERFÍCIES (SEM PRIMEIROS SOCORROS!)
  // ---------------------------------------------------------------------------
  SmartTriageResult _buildPaintingTriage(
    String norm,
    Set<String> tokens,
    DateTime now,
    double mediaBonus,
  ) {
    final hasMoistureOrMold = _matchesAny(
      norm,
      tokens,
      const ['mofo', 'bolor', 'umidade', 'infiltracao', 'estufando', 'descascando'],
    );
    final hasCracksOrHoles = _matchesAny(
      norm,
      tokens,
      const ['trinca', 'rachadura', 'buraco', 'massa', 'reboco', 'fissura'],
    );
    final isWoodOrMetal = _matchesAny(
      norm,
      tokens,
      const ['portao', 'grade', 'ferro', 'madeira', 'porta', 'janela', 'verniz', 'esmalte'],
    );

    final summary = hasMoistureOrMold
        ? 'Raspagem de película solta, tratamento antimofo/bloqueador de umidade, nivelamento com massa acrílica e repintura de acabamento.'
        : hasCracksOrHoles
            ? 'abertura e tratamento de fissuras, correção com massa corrida/acrílica, lixamento técnico e aplicação de pintura uniforme.'
            : isWoodOrMetal
                ? 'Preparação por lixamento, aplicação de fundo anticorrosivo/selador e pintura em esmalte sintético ou verniz para madeira/metal.'
                : 'Preparação técnica de paredes/tetos, isolamento de rodapés e esquadrias, correção de imperfeições com massa, lixamento e aplicação de tinta acrílica (2 a 3 demãos).';

    final rootCause = hasMoistureOrMold
        ? 'Microinfiltração ou condensação superficial provocando destacamento da película de tinta e proliferação fúngica.'
        : hasCracksOrHoles
            ? 'Retração natural da argamassa/reboco ou desgaste mecânico exigindo regularização antes da cobertura.'
            : isWoodOrMetal
                ? 'Oxidação superficial ou intemperismo solar exigindo proteção anticorrosiva/hidrorrepelente.'
                : 'Desgaste natural da película de tinta, calcinação ou renovação estética e proteção da alvenaria.';

    return SmartTriageResult(
      id: 'triage-painting-${now.millisecondsSinceEpoch}',
      analyzedAt: now,
      suggestedCategoryId: 'pintura',
      suggestedCategoryName: 'Pintura',
      urgencyLevel: hasMoistureOrMold ? UrgencyLevel.medium : UrgencyLevel.low,
      diagnosticSummary: summary[0].toUpperCase() + summary.substring(1),
      probableRootCause: rootCause,
      estimatedDurationRange: '4 a 8 horas (conforme metragem e secagem entre demãos)',
      confidenceScore: (0.94 + mediaBonus).clamp(0.80, 0.99),
      probableMaterials: [
        const ProbableMaterialItem(
          id: 'mat-pin-tinta-acrilica',
          name: 'Tinta Acrílica Premium (Fosco / Acetinado / Semibrilho)',
          technicalSpec: 'Rendimento de alta cobertura lavável (Galão 3,6L ou Lata 18L conforme área)',
          estimatedQuantity: '1 un (3,6L ou 18L)',
        ),
        ProbableMaterialItem(
          id: 'mat-pin-massa',
          name: hasMoistureOrMold
              ? 'Massa Acrílica Resistente à Umidade (Interior/Exterior)'
              : 'Massa Corrida PVA / Massa Acrílica de Nivelamento',
          technicalSpec: 'Correção de porosidades, desníveis e imperfeições na alvenaria',
          estimatedQuantity: '1 galão (3,6L)',
        ),
        const ProbableMaterialItem(
          id: 'mat-pin-selador',
          name: 'Selador Acrílico / Fundo Preparador de Paredes',
          technicalSpec: 'Uniformiza a absorção da parede e aglutina partículas soltas após lixamento',
          estimatedQuantity: '1 galão (3,6L)',
          isOptional: true,
        ),
        const ProbableMaterialItem(
          id: 'mat-pin-kit-lixas',
          name: 'Kit Lixas para Parede e Massa (grãos 120, 180 e 220)',
          technicalSpec: 'Desbaste de nivelamento e acabamento acetinado antes da pintura',
          estimatedQuantity: '6 folhas',
        ),
        const ProbableMaterialItem(
          id: 'mat-pin-protecao',
          name: 'Fita Crepe Larga (48mm) + Lona Plástica de Proteção',
          technicalSpec: 'Isolamento de rodapés, tomadas, batentes e proteção integral do piso/móveis',
          estimatedQuantity: '2 rolos + 1 lona',
        ),
        const ProbableMaterialItem(
          id: 'mat-pin-rolo-trincha',
          name: 'Rolo de Lã Antigota 23cm + Trincha 2" para Recorte',
          technicalSpec: 'Aplicação uniforme sem respingos em paredes e acabamento nos cantos',
          estimatedQuantity: '1 conjunto',
          isOptional: true,
        ),
      ],
      recommendedProviderTools: const [
        'Rolo de lã antigota, garfo gaiola e cabo extensor telescópico',
        'Desempenadeira de aço inox e espátulas de 6", 10" e 12"',
        'Lixadeira orbital / girafa com coletor de pó ou taco lixador',
        'Trinchas de recorte e bandeja/caçamba de pintura',
        'Escada articulada de alumínio e lonas de proteção',
      ],
      // Pintura é serviço planejado/estético: NUNCA exibe Primeiros Socorros do Imóvel!
      containmentGuide: null,
    );
  }

  // ---------------------------------------------------------------------------
  // 8. MARCENARIA / MONTAGEM / PEQUENOS REPAROS
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
    ) ||
        normalizeTag(currentCategory ?? '') == 'montagem';
    final isWallMount = _matchesAny(
      norm,
      tokens,
      const ['suporte de tv', 'cortina', 'varao', 'prateleira', 'quadro', 'bucha'],
    ) ||
        normalizeTag(currentCategory ?? '') == 'pequenos reparos';
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
          : isAssembly
              ? 'Montagem ou desmontagem técnica de mobiliário com esquadrejamento, fixação de fundos e regulagem de portas e corrediças.'
              : 'Regulagem estrutural de marcenaria, substituição de ferragens articuladas e realinhamento de portas/gavetas.',
      probableRootCause: isWallMount
          ? 'Subdimensionamento de bucha para o tipo de parede (oco/drywall) ou fadiga por carga dinâmica.'
          : isAssembly
              ? 'Necessidade de montagem estrutural nivelada seguindo gabarito de ferragens (minifix, cavilhas e corrediças).'
              : 'Fadiga da mola da dobradiça caneco 35mm ou esgarçamento dos furos de fixação no MDF/MDP.',
      estimatedDurationRange: isAssembly ? '90 a 180 min' : '40 a 80 min',
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
      // Só exibe contenção se o móvel/porta/prateleira estiver efetivamente caindo ou cedendo!
      containmentGuide: isFalling
          ? const EmergencyContainmentGuide(
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
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // 9. TODAS AS DEMAIS CATEGORIAS OFICIAIS (ESPECIALIZADAS POR ÁREA)
  // ---------------------------------------------------------------------------
  String? _detectSpecializedCategoryFromText(String norm, Set<String> tokens) {
    if (_matchesAny(norm, tokens, const ['faxina', 'limpeza', 'limpar', 'diarista', 'pos obra'])) {
      return 'Limpeza';
    }
    if (_matchesAny(norm, tokens, const ['pedreiro', 'reboco', 'alvenaria', 'cimento', 'muro', 'contrapiso', 'parede'])) {
      return 'Pedreiro';
    }
    if (_matchesAny(norm, tokens, const ['gesso', 'drywall', 'sanca', 'forro de gesso'])) {
      return 'Gesso';
    }
    if (_matchesAny(norm, tokens, const ['porcelanato', 'ceramica', 'azulejo', 'rejunte', 'piso', 'revestimento'])) {
      return 'Pisos e Revestimentos';
    }
    if (_matchesAny(norm, tokens, const ['grama', 'jardim', 'jardinagem', 'poda', 'arvore', 'mato'])) {
      return 'Jardinagem';
    }
    if (_matchesAny(norm, tokens, const ['barata', 'formiga', 'cupim', 'rato', 'praga', 'dedetizacao', 'escorpiao'])) {
      return 'Dedetização';
    }
    if (_matchesAny(norm, tokens, const ['vidro', 'vidraceiro', 'box', 'espelho', 'blindex'])) {
      return 'Vidraceiro';
    }
    if (_matchesAny(norm, tokens, const ['solda', 'serralheria', 'serralheiro', 'grade', 'corrimao'])) {
      return 'Serralheria';
    }
    if (_matchesAny(norm, tokens, const ['impermeabilizacao', 'impermeabilizar', 'manta liquida', 'umidade'])) {
      return 'Impermeabilização';
    }
    if (_matchesAny(norm, tokens, const ['entupido', 'entupiu', 'desentupir', 'desentupidora', 'caixa de gordura', 'esgoto'])) {
      return 'Desentupidora';
    }
    if (_matchesAny(norm, tokens, const ['piscina', 'cloro', 'agua verde', 'filtro da piscina'])) {
      return 'Piscina';
    }
    if (_matchesAny(norm, tokens, const ['geladeira', 'maquina de lavar', 'lavadora', 'microondas', 'fogao', 'lava loucas'])) {
      return 'Eletrodomésticos';
    }
    if (_matchesAny(norm, tokens, const ['antena', 'parabolica', 'tv', 'sinal digital', 'conversor'])) {
      return 'TV e Antenas';
    }
    if (_matchesAny(norm, tokens, const ['camera', 'alarme', 'cftv', 'dvr', 'sensor de presenca', 'cerca eletrica'])) {
      return 'Câmeras e Alarmes';
    }
    if (_matchesAny(norm, tokens, const ['portao eletronico', 'interfone', 'motor do portao', 'controle de portao'])) {
      return 'Portões e Interfones';
    }
    if (_matchesAny(norm, tokens, const ['energia solar', 'painel solar', 'placa solar', 'inversor solar', 'fotovoltaico'])) {
      return 'Energia Solar';
    }
    if (_matchesAny(norm, tokens, const ['cortina', 'persiana', 'blackout', 'trilho suico'])) {
      return 'Cortinas e Persianas';
    }
    if (_matchesAny(norm, tokens, const ['sofa', 'estofado', 'colchao', 'tapete', 'higienizacao de sofa'])) {
      return 'Estofados e Tapetes';
    }
    if (_matchesAny(norm, tokens, const ['mudanca', 'frete', 'carreto', 'caminhao', 'transporte'])) {
      return 'Mudanças e Fretes';
    }
    if (_matchesAny(norm, tokens, const ['computador', 'notebook', 'wifi', 'roteador', 'rede', 'formatar', 'internet'])) {
      return 'Informática e Redes';
    }
    if (_matchesAny(norm, tokens, const ['idoso', 'cuidador', 'acompanhante'])) {
      return 'Cuidador de Idosos';
    }
    if (_matchesAny(norm, tokens, const ['baba', 'crianca', 'bebe'])) {
      return 'Babá';
    }
    if (_matchesAny(norm, tokens, const ['pet', 'cachorro', 'gato', 'passeador', 'banho e tosa'])) {
      return 'Pet Care';
    }
    return null;
  }

  SmartTriageResult _buildSpecializedCategoryTriage(
    String norm,
    Set<String> tokens,
    DateTime now,
    double mediaBonus, {
    String? currentCategory,
  }) {
    final categoryName = (currentCategory != null &&
            kCategories.any((c) => normalizeTag(c.name) == normalizeTag(currentCategory)))
        ? kCategories.firstWhere((c) => normalizeTag(c.name) == normalizeTag(currentCategory)).name
        : (_detectSpecializedCategoryFromText(norm, tokens) ?? 'Pequenos Reparos');

    final slug = normalizeTag(categoryName);

    final spec = switch (slug) {
      'limpeza' => (
        urgency: UrgencyLevel.low,
        duration: '3 a 6 horas',
        summary: 'Higienização técnica detalhada de ambientes, remoção de sujidades aderidas, desengorduramento e sanitização de superfícies.',
        rootCause: 'Acúmulo de poeira fina, resíduos orgânicos/gordura ou respingos pós-reforma exigindo limpeza profunda com insumos específicos.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-lim-multiuso',
            name: 'Desengordurante Alcalino e Limpador Multiuso Concentrado',
            technicalSpec: 'Ação tensoativa para cozinhas, bancadas, azulejos e pisos laváveis',
            estimatedQuantity: '1 kit (2 frascos)',
          ),
          ProbableMaterialItem(
            id: 'mat-lim-desinfetante',
            name: 'Desinfetante Bactericida + Limpa-Vidros Antiembaçante',
            technicalSpec: 'Sanitização de banheiros, louças sanitárias, espelhos e esquadrias',
            estimatedQuantity: '1 kit',
          ),
          ProbableMaterialItem(
            id: 'mat-lim-microfibra',
            name: 'Panos de Microfibra (não riscam) + Esponjas Dupla Face Macias',
            technicalSpec: 'Alta absorção para móveis, inox, vidros e superfícies sensíveis',
            estimatedQuantity: '4 panos + 2 esponjas',
          ),
          ProbableMaterialItem(
            id: 'mat-lim-sacos-luvas',
            name: 'Sacos de Lixo Reforçados (100L) + Luvas Nitrílicas de Proteção',
            technicalSpec: 'Coleta segura de resíduos e proteção durante o manuseio químico',
            estimatedQuantity: '1 pacote + 1 par',
          ),
        ],
        tools: const [
          'Aspirador de pó e líquidos de alta sucção',
          'Mop giratório de microfibra e rodo limpa-vidros extensor',
          'Escovas de detalhamento para rejuntes e cantos',
          'Baldes separadores e EPIs completos',
        ],
      ),
      'pedreiro' => (
        urgency: UrgencyLevel.medium,
        duration: '3 a 6 horas',
        summary: 'Execução ou reparo de alvenaria, regularização de reboco/emboço, recomposição de argamassa ou chumbamento estrutural.',
        rootCause: 'Desagregação do revestimento argamassado, recalque pontual, umidade na base da parede ou necessidade de adequação civil.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-ped-cimento',
            name: 'Cimento Portland CP-II / Argamassa Pronta de Revestimento',
            technicalSpec: 'Traço estrutural para recomposição de reboco, chumbamento ou contrapiso',
            estimatedQuantity: '1 saco (20kg ou 50kg)',
          ),
          ProbableMaterialItem(
            id: 'mat-ped-areia',
            name: 'Areia Média Lavada Ensacada + Cal Hidratada',
            technicalSpec: 'Agregado mineral limpo para preparo de massa de assentamento e reboco',
            estimatedQuantity: '1 a 2 sacos (20kg)',
          ),
          ProbableMaterialItem(
            id: 'mat-ped-impermeabilizante',
            name: 'Aditivo Impermeabilizante Hidrofugante para Argamassa',
            technicalSpec: 'Bloqueio contra umidade ascendente em rebocos e rodapés (tipo Vedacit/Sika 1)',
            estimatedQuantity: '1 litro',
            isOptional: true,
          ),
          ProbableMaterialItem(
            id: 'mat-ped-tijolos',
            name: 'Blocos Cerâmicos / Tijolos ou Tela de Fibra Anti-Trinca',
            technicalSpec: 'Fechamento de vãos e reforço de juntas de alvenaria',
            estimatedQuantity: 'Conforme área',
            isOptional: true,
          ),
        ],
        tools: const [
          'Colher de pedreiro, desempenadeira e régua de alumínio',
          'Nível a laser / bolha e prumo de face',
          'Martelete rompedor / talhadeira e marreta',
          'Masseira plástica, enxada e EPIs',
        ],
      ),
      'gesso' => (
        urgency: UrgencyLevel.low,
        duration: '2 a 5 horas',
        summary: 'Reparo ou fechamento em forro de gesso/Drywall, tratamento de trincas de dilatação, sancas ou recortes para iluminação.',
        rootCause: 'Trabalhabilidade térmica entre placas de gesso, abertura para manutenção elétrica/hidráulica ou umidade pontual.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-ges-placa',
            name: 'Placa de Gesso Acartonado (Drywall ST ou RU Verde) / Placa 60x60',
            technicalSpec: 'Chapa de 12,5mm para recomposição de forro ou fechamento de visita',
            estimatedQuantity: '1 chapa / recorte',
          ),
          ProbableMaterialItem(
            id: 'mat-ges-massa',
            name: 'Massa para Junta de Drywall + Gesso Cola / Gesso Rápido em Pó',
            technicalSpec: 'Acabamento monolítico sem retração para emendas e chumbamento',
            estimatedQuantity: '1 balde (5kg)',
          ),
          ProbableMaterialItem(
            id: 'mat-ges-fita',
            name: 'Fita Telada Autoadesiva / Microperfurada + Parafusos GN25',
            technicalSpec: 'Armadura de fibra de vidro anti-fissura e fixação em perfil metálico',
            estimatedQuantity: '1 rolo + 25 parafusos',
          ),
        ],
        tools: const [
          'Espátulas e desempenadeira de aço inox para Drywall',
          'Serrote de ponta para gesso, serra copo e estilete',
          'Parafusadeira com ponteira limitadora de profundidade',
          'Nível a laser e lixadeira com aspiração',
        ],
      ),
      'pisos e revestimentos' => (
        urgency: UrgencyLevel.low,
        duration: '3 a 6 horas',
        summary: 'Assentamento, substituição de peças ocas/trincadas ou renovação de rejuntamento em pisos cerâmicos, porcelanatos ou laminados.',
        rootCause: 'Perda de aderência da argamassa colante (desplacamento por dilatação), desgaste do rejunte ou troca estética de revestimento.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-pis-argamassa',
            name: 'Argamassa Colante AC-II / AC-III Flexível (Porcelanato e Cerâmica)',
            technicalSpec: 'Alta aderência química e flexibilidade térmica (saco 20kg)',
            estimatedQuantity: '1 saco (20kg)',
          ),
          ProbableMaterialItem(
            id: 'mat-pis-rejunte',
            name: 'Rejunte Acrílico / Flexível Antimofo Impermeável',
            technicalSpec: 'Acabamento liso de baixa absorção para juntas de 1,5mm a 5mm',
            estimatedQuantity: '1 pote (1kg a 2kg)',
          ),
          ProbableMaterialItem(
            id: 'mat-pis-niveladores',
            name: 'Kit Espaçadores + Cunhas Niveladoras de Porcelanato',
            technicalSpec: 'Garante nivelamento perfeito sem degraus (lippage) entre peças',
            estimatedQuantity: '1 pacote (50 un)',
          ),
        ],
        tools: const [
          'Cortador manual de piso (riscadeira) e serra mármore com disco diamantado',
          'Desempenadeira dentada de aço inox e desempenadeira de borracha para rejunte',
          'Martelo de borracha branca (não mancha) e alicate nivelador',
          'Nível a laser e ventosa de movimentação',
        ],
      ),
      'jardinagem' => (
        urgency: UrgencyLevel.low,
        duration: '2 a 4 horas',
        summary: 'Corte e acabamento de gramado, poda de formação/limpeza de arbustos, erradicação de ervas daninhas e adubação.',
        rootCause: 'Crescimento vegetativo sazonal, compactação do substrato ou necessidade de manutenção paisagística e fitossanitária.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-jar-terra',
            name: 'Substrato Vegetal / Terra Preta Adubada e Húmus de Minhoca',
            technicalSpec: 'Enriquecimento orgânico para canteiros, vasos e recomposição de gramado',
            estimatedQuantity: '1 a 2 sacos (20kg)',
            isOptional: true,
          ),
          ProbableMaterialItem(
            id: 'mat-jar-adubo',
            name: 'Fertilizante Granulado NPK (10-10-10) / Adubo Foliar',
            technicalSpec: 'Reposição de macronutrientes para fortalecimento radicular e folhagem',
            estimatedQuantity: '1 kg',
            isOptional: true,
          ),
          ProbableMaterialItem(
            id: 'mat-jar-sacos',
            name: 'Sacos Reforçados de Ráfia/Polietileno para Resíduos de Poda + Fio de Nylon',
            technicalSpec: 'Acondicionamento de aparas de grama, folhas e galhos podados',
            estimatedQuantity: '5 unidades',
          ),
        ],
        tools: const [
          'Roçadeira / cortador de grama e aparador de cantos',
          'Tesoura de poda, podador de cerca-viva e serrote curvo',
          'Rastelo (vassoura de jardim), sacho, enxada e soprador',
          'EPIs (óculos de proteção, perneira e luvas de raspa)',
        ],
      ),
      'dedetizacao' => (
        urgency: UrgencyLevel.medium,
        duration: '60 a 120 min',
        summary: 'Desinsetização / desratização técnica com barreira química residual, aplicação de gel atrativo e polvilhamento em conduítes/ralos.',
        rootCause: 'Foco de reprodução de pragas urbanas (baratas, formigas, escorpiões, cupins ou roedores) em frestas, caixas de gordura e tubulações.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-ded-calda',
            name: 'Inseticida Domissanitário Microencapsulado Sem Cheiro (Piretroide)',
            technicalSpec: 'Efeito residual prolongado registrado na ANVISA para rodapés e ralos',
            estimatedQuantity: 'Aplicação por área',
          ),
          ProbableMaterialItem(
            id: 'mat-ded-gel',
            name: 'Gel Inseticida Atrativo em Seringa (Baratas e Formigas)',
            technicalSpec: 'Aplicação segura em dobradiças de armários de cozinha e motores sem desocupar o local',
            estimatedQuantity: '1 seringa (10g)',
          ),
          ProbableMaterialItem(
            id: 'mat-ded-iscas',
            name: 'Porta-Iscas Tamper-Resistant + Blocos Parafinados / Pó Químico Seco',
            technicalSpec: 'Controle em caixas de inspeção, forros e conduítes sem umidade',
            estimatedQuantity: 'Kit conforme pontos',
            isOptional: true,
          ),
        ],
        tools: const [
          'Pulverizador profissional de compressão prévia com bico leque',
          'Pistola dosadora de gel de precisão e polvilhadeira técnica',
          'Lanterna de inspeção UV / endoscópica para frestas',
          'Respirador semifacial com filtro químico e EPIs',
        ],
      ),
      'vidraceiro' => (
        urgency: UrgencyLevel.medium,
        duration: '60 a 120 min',
        summary: 'Manutenção preventiva/corretiva de box de banheiro, troca de roldanas, vedação com silicone antimofo ou instalação de vidro/espelho.',
        rootCause: 'Desgaste do rolamento das roldanas excêntricas, ressecamento da vedação de silicone ou desalinhamento do trilho de alumínio.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-vid-roldanas',
            name: 'Par de Roldanas Excêntricas em Latão/Nylon Rolamentadas para Box',
            technicalSpec: 'Pino em latão/inox para vidro temperado 8mm (deslizamento suave e seguro)',
            estimatedQuantity: '1 par (2 un)',
          ),
          ProbableMaterialItem(
            id: 'mat-vid-silicone',
            name: 'Silicone Acético / Neutro Antimofo Transparente ou Branco (280g)',
            technicalSpec: 'Vedação elástica impermeável para trilhos inferiores de box, janelas e pias',
            estimatedQuantity: '1 tubo',
          ),
          ProbableMaterialItem(
            id: 'mat-vid-batedor',
            name: 'Kit Batedores Inferiores/Superiores, Guia Deslizante e Cunhas de Silicone',
            technicalSpec: 'Amortecimento de impacto e guia de alinhamento da folha móvel de vidro',
            estimatedQuantity: '1 kit',
            isOptional: true,
          ),
        ],
        tools: const [
          'Ventosas duplas de alta sucção para manuseio seguro de vidro',
          'Pistola aplicadora profissional de silicone e raspador de junta',
          'Chaves Allen, chave de regulagem de excêntrico e nível de precisão',
          'Furadeira com brocas diamantadas / vídea',
        ],
      ),
      'serralheria' => (
        urgency: UrgencyLevel.medium,
        duration: '60 a 150 min',
        summary: 'Solda estrutural em loco, substituição de gonzos/dobradiças metálicas, troca de roldanas de portão ou reforço de grades.',
        rootCause: 'Oxidação severa na base metálica, fadiga de cordão de solda por esforço repetitivo ou travamento mecânico de gonzo/trilho.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-ser-eletrodos',
            name: 'Eletrodos Revestidos E6013 (2,5mm / 3,25mm) + Discos de Corte e Flap',
            technicalSpec: 'Consumíveis de soldagem estrutural a arco elétrico e acabamento de cordão',
            estimatedQuantity: '1 kit consumível',
          ),
          ProbableMaterialItem(
            id: 'mat-ser-gonzo',
            name: 'Gonzo de Aço Torneado com Aba / Roldana de Aço Canal V para Portão',
            technicalSpec: 'Articulação ou rolamento blindado para folhas de portão e grades',
            estimatedQuantity: '1 par',
          ),
          ProbableMaterialItem(
            id: 'mat-ser-zarcao',
            name: 'Primer Anticorrosivo (Zarcão / Galvite) em Spray ou Lata',
            technicalSpec: 'Proteção imediata do metal recém-soldado contra ferrugem',
            estimatedQuantity: '1 un',
            isOptional: true,
          ),
        ],
        tools: const [
          'Máquina inversora de solda portátil e máscara de escurecimento automático',
          'Esmerilhadeira angular 4.1/2" para corte e desbaste',
          'Esquadros magnéticos, grampos sargento e trena metálica',
          'EPIs completos de soldador (luvas de raspa, avental e óculos)',
        ],
      ),
      'impermeabilizacao' => (
        urgency: UrgencyLevel.medium,
        duration: '3 a 6 horas',
        summary: 'Preparo de substrato, tratamento de trincas/ralos com tela estruturante e aplicação de sistema impermeabilizante flexível.',
        rootCause: 'Fissuração térmica em laje/parede externa, falha na vedação perimetral de ralos/janelas ou capilaridade em rodapés.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-imp-manta-liquida',
            name: 'Manta Líquida Acrílica Elastomérica / Argamassa Polimérica Impermeabilizante',
            technicalSpec: 'Membrana flexível impermeável resistente a raios UV e movimentação térmica',
            estimatedQuantity: '1 balde (4kg a 18kg)',
          ),
          ProbableMaterialItem(
            id: 'mat-imp-tela',
            name: 'Tela de Poliéster Malha 2x2mm para Reforço de Trincas e Meia-Cana',
            technicalSpec: 'Armadura estruturante entre demãos de impermeabilizante',
            estimatedQuantity: '1 rolo',
          ),
          ProbableMaterialItem(
            id: 'mat-imp-selante-pu',
            name: 'Selante de Poliuretano (PU Construção) para Juntas e Esquadrias',
            technicalSpec: 'Vedação elástica de alta aderência em encontros de materiais distintos',
            estimatedQuantity: '1 a 2 tubos',
          ),
        ],
        tools: const [
          'Broxa retangular, trincha larga e rolo de textura/epóxi',
          'Escova de aço e espátula para limpeza profunda do substrato',
          'Aplicador tubular de PU e medidor de umidade',
        ],
      ),
      'desentupidora' => (
        urgency: UrgencyLevel.high,
        duration: '60 a 120 min',
        summary: 'Desobstrução eletromecânica de ramal de esgoto, vaso sanitário, ralo de banheiro, pia de cozinha ou caixa de gordura.',
        rootCause: 'Saturação por placas de gordura saponificada, acúmulo de fios de cabelo/detritos sólidos ou perda de caimento na rede.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-des-anel-cera',
            name: 'Anel de Vedação com Guia para Vaso Sanitário',
            technicalSpec: 'Massa butílica antifungos caso seja necessário remover a bacia sanitária para sonda',
            estimatedQuantity: '1 un',
            isOptional: true,
          ),
          ProbableMaterialItem(
            id: 'mat-des-enzimatico',
            name: 'Desengordurante Biológico / Enzimático para Tubulações e Caixa de Gordura',
            technicalSpec: 'Degradação segura de matéria orgânica sem corroer juntas e anéis de PVC (não ácido)',
            estimatedQuantity: '1 litro',
          ),
          ProbableMaterialItem(
            id: 'mat-des-vedacao-caixa',
            name: 'Cesto Coletor / Vedação de Tampa de Caixa de Gordura e Sifão',
            technicalSpec: 'Estanqueidade contra retorno de odores após limpeza mecânica',
            estimatedQuantity: '1 un',
            isOptional: true,
          ),
        ],
        tools: const [
          'Máquina desentupidora rotativa (K-50 / K-500) com cabos espirais e ponteiras',
          'Bomba desentupidora de alta pressão por hidrojateamento / vácuo manual',
          'Sonda passadora de aço mola e EPIs impermeáveis',
        ],
      ),
      'piscina' => (
        urgency: UrgencyLevel.low,
        duration: '60 a 120 min',
        summary: 'Escovação de paredes/bordas, aspiração do fundo, retrolavagem do filtro de areia e balanceamento químico da água (pH, alcalinidade e cloro).',
        rootCause: 'Desequilíbrio de pH/alcalinidade, decantação de partículas em suspensão ou proliferação inicial de algas por queda de cloro livre.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-pis-cloro',
            name: 'Cloro Granulado Estabilizado (Dicloro 3 em 1 / Hipoclorito)',
            technicalSpec: 'Sanitização oxidante com estabilizador contra fotodegradação solar',
            estimatedQuantity: 'Dosagem conforme m³',
          ),
          ProbableMaterialItem(
            id: 'mat-pis-barrilha',
            name: 'Elevador de pH (Barrilha Leve) + Elevador de Alcalinidade (Bicarbonato)',
            technicalSpec: 'Correção da faixa ideal de pH (7,2 a 7,6) e alcalinidade (80 a 120 ppm)',
            estimatedQuantity: '1 kit corretivo',
          ),
          ProbableMaterialItem(
            id: 'mat-pis-clarificante',
            name: 'Clarificante Floculante + Algicida de Manutenção Sem Cobre',
            technicalSpec: 'Aglutinação de micropartículas para aspiração e prevenção de água verde',
            estimatedQuantity: '1 litro',
          ),
        ],
        tools: const [
          'Cabo telescópico de alumínio, aspirador de fundo com escova e mangueira flutuante',
          'Peneira cata-folhas pelicano e escova curva de nylon',
          'Estojo de teste colorimétrico / fitas 5 em 1 (pH, Cloro Livre, Alcalinidade e Ácido Cianúrico)',
        ],
      ),
      'eletrodomesticos' => (
        urgency: UrgencyLevel.medium,
        duration: '60 a 120 min',
        summary: 'Diagnóstico eletromecânico e substituição de componente em falha (geladeira, lavadora de roupas, lava-louças, fogão ou micro-ondas).',
        rootCause: 'Desgaste da eletrobomba de drenagem/válvula de entrada (lavadoras), falha de sensor NTC/bimetal de degelo (geladeiras) ou capacitor/relé PTC.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-eld-bomba-valvula',
            name: 'Eletrobomba de Drenagem Universal / Válvula Solenoide de Entrada',
            technicalSpec: 'Componente para máquinas de lavar que não centrifugam ou não drenam a água',
            estimatedQuantity: '1 un',
            isOptional: true,
          ),
          ProbableMaterialItem(
            id: 'mat-eld-rele-sensor',
            name: 'Kit Sensor de Temperatura (NTC) + Bimetal Fusível Térmico ou Relé PTC',
            technicalSpec: 'Controle de degelo Frost Free e partida segura do motocompressor de geladeira',
            estimatedQuantity: '1 kit',
            isOptional: true,
          ),
          ProbableMaterialItem(
            id: 'mat-eld-capacitor',
            name: 'Capacitor de Partida / Correia Poli-V ou Mangueira de Entrada/Saída',
            technicalSpec: 'Reposição eletromecânica de tração e estanqueidade de linha branca',
            estimatedQuantity: '1 un',
            isOptional: true,
          ),
        ],
        tools: const [
          'Multímetro True RMS com capacímetro e termômetro digital penta',
          'Jogo de chaves canhão, Torx e extrator de agitador/cesto de lavadora',
          'Alicate amperímetro e ferramentas isoladas de bancada móvel',
        ],
      ),
      'tv e antenas' => (
        urgency: UrgencyLevel.low,
        duration: '45 a 90 min',
        summary: 'Fixação nivelada de suporte de TV em parede/painel de madeira, organização de cabos ou apontamento de antena UHF Digital / Parabólica.',
        rootCause: 'Necessidade de ancoragem segura compatível com padrão VESA do televisor ou atenuação de sinal por oxidação em cabo/conector.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-tva-suporte',
            name: 'Suporte VESA Fixo, Inclinável ou Articulado em Aço Carbono',
            technicalSpec: 'Compatível com telas de 32" a 85" com trava de segurança e gabarito',
            estimatedQuantity: '1 un',
            isOptional: true,
          ),
          ProbableMaterialItem(
            id: 'mat-tva-cabo-rg6',
            name: 'Cabo Coaxial RG6 Dupla Blindagem + Conectores de Compressão F',
            technicalSpec: 'Transmissão de sinal digital HDTV/Satélite sem perda por interferência',
            estimatedQuantity: '5 a 15 metros + 4 conectores',
            isOptional: true,
          ),
          ProbableMaterialItem(
            id: 'mat-tva-parafusos-vesa',
            name: 'Kit Parafusos Métricos VESA (M4/M6/M8) + Buchas de Nylon c/ Aba 10mm',
            technicalSpec: 'Fixação segura na traseira da TV e ancoragem de carga na parede/painel',
            estimatedQuantity: '1 kit completo',
          ),
        ],
        tools: const [
          'Medidor de campo / Localizador digital de sinal (Satlink)',
          'Alicate de compressão coaxial e decapador rotativo RG6',
          'Furadeira de impacto, nível a laser e detector de tubulação/fiação',
        ],
      ),
      'cameras e alarmes' => (
        urgency: UrgencyLevel.medium,
        duration: '90 a 180 min',
        summary: 'Instalação, cabeamento ou configuração de câmeras de segurança (Wi-Fi / IP / Multi-HD), gravador DVR/NVR, sensores e aplicativo móvel.',
        rootCause: 'Expansão de monitoramento patrimonial, perda de comunicação por fonte 12V/conector oxidado ou reconfiguração de rede.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-cam-fonte-conector',
            name: 'Fonte Chaveada 12V Estabilizada + Conectores BNC Mola e P4 Macho/Fêmea',
            technicalSpec: 'Alimentação protegida contra surtos e conexões de vídeo sem ruído',
            estimatedQuantity: '1 fonte + par de conectores por câmera',
          ),
          ProbableMaterialItem(
            id: 'mat-cam-caixa-vbox',
            name: 'Caixa de Sobrepor Hermética (VBOX IP66) + Cabo Coaxial Bipolar / UTP Cat5e',
            technicalSpec: 'Blindagem dos conectores contra chuva/sol e passagem de sinal/alimentação',
            estimatedQuantity: '1 caixa por câmera + metragem de cabo',
          ),
          ProbableMaterialItem(
            id: 'mat-cam-sd',
            name: 'Cartão MicroSD High Endurance (Câmera Wi-Fi) ou Balun Passivo HD',
            technicalSpec: 'Gravação contínua em loop ou casamento de impedância em par trançado',
            estimatedQuantity: '1 un',
            isOptional: true,
          ),
        ],
        tools: const [
          'Monitor testador de CFTV e testador de cabos RJ45/BNC',
          'Furadeira de impacto, passa-fio com alma de aço e escada extensível',
          'Alicate de crimpagem RJ45 e multímetro digital',
        ],
      ),
      'portoes e interfones' => (
        urgency: UrgencyLevel.medium,
        duration: '60 a 120 min',
        summary: 'Manutenção em automatizador de portão (basculante/deslizante), troca de capacitor/placa de comando, codificação de controles ou reparo de interfone/fechadura 12V.',
        rootCause: 'Capacitor de partida esgotado, quebra de imã de fim de curso (reed switch), desgaste da porca acionadora/cremalheira ou rompimento no par telefônico.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-por-capacitor-fim',
            name: 'Capacitor de Partida do Motor (12µF a 30µF) + Sensor Fim de Curso (Reed Switch)',
            technicalSpec: 'Recupera a força de arranque do portão e a parada precisa na abertura/fechamento',
            estimatedQuantity: '1 un de cada',
          ),
          ProbableMaterialItem(
            id: 'mat-por-cremalheira-porca',
            name: 'Porca Acionadora em Nylon/Bronze (Basculante) ou Gomo de Cremalheira (Deslizante)',
            technicalSpec: 'Transmissão mecânica do fuso ou engrenagem do motor',
            estimatedQuantity: '1 un',
            isOptional: true,
          ),
          ProbableMaterialItem(
            id: 'mat-por-controle-interfone',
            name: 'Controle Remoto 433,92MHz Code Learn ou Monofone Universal / Fonte 12V de Interfone',
            technicalSpec: 'Acionamento sem fio criptografado ou comunicação clara com abertura de fechadura',
            estimatedQuantity: '1 a 2 un',
            isOptional: true,
          ),
        ],
        tools: const [
          'Multímetro digital, frequencímetro 433MHz e localizador de cabos (zumbidor)',
          'Jogo de chaves combinadas, Allen e sacador de pino elástico',
          'Ferro de solda, graxa branca de lítio para fuso e parafusadeira',
        ],
      ),
      'energia solar' => (
        urgency: UrgencyLevel.low,
        duration: '90 a 180 min',
        summary: 'Limpeza técnica de módulos fotovoltaicos, inspeção termográfica de conexões MC4, revisão de String Box CC/CA e verificação do inversor.',
        rootCause: 'Sujidade acumulada reduzindo a geração em até 20% (efeito hot-spot) ou atuação de DPS/disjuntor por surto da concessionária.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-sol-mc4',
            name: 'Par de Conectores Fotovoltaicos MC4 IP68 com Terminal Crimpável',
            technicalSpec: 'Conexão estanque resistente a UV para cabos solares de 4mm² e 6mm²',
            estimatedQuantity: '2 pares',
            isOptional: true,
          ),
          ProbableMaterialItem(
            id: 'mat-sol-dps',
            name: 'Dispositivo de Proteção contra Surtos (DPS Solar CC ou CA Classe II)',
            technicalSpec: 'Substituição de cartucho/módulo atuado na String Box de proteção',
            estimatedQuantity: '1 un',
            isOptional: true,
          ),
          ProbableMaterialItem(
            id: 'mat-sol-shampoo',
            name: 'Solução Limpadora Neutro-Biodegradável Antiestática para Módulos Solares',
            technicalSpec: 'Remove fuligem, poeira e dejetos sem agredir a película antirreflexo do vidro',
            estimatedQuantity: '1 litro concentrado',
          ),
        ],
        tools: const [
          'Alicate amperímetro CC/CA 1000V e câmera termográfica / termômetro IR',
          'Haste telescópica com escova de cerdas macias hidroalimentada',
          'Alicate crimpador e chaves extratoras MC4 + EPI de altura (NR-35)',
        ],
      ),
      'cortinas e persianas' => (
        urgency: UrgencyLevel.low,
        duration: '45 a 90 min',
        summary: 'Instalação nivelada de varões, trilhos suíços ou persianas (rolô, horizontal, vertical) com fixação adequada para alvenaria ou teto de gesso.',
        rootCause: 'Instalação de nova peça sob medida, substituição de buchas frouxas no gesso/parede ou troca de comando/corda de recolhimento.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-cor-buchas',
            name: 'Kit Buchas Específicas (Drywall Fly/Toggler para Gesso ou Nylon 8mm c/ Aba para Parede)',
            technicalSpec: 'Fixação de alta resistência à tração vertical e horizontal sem esfarelar o forro',
            estimatedQuantity: '6 a 8 un + parafusos inox',
          ),
          ProbableMaterialItem(
            id: 'mat-cor-comando',
            name: 'Kit Comando Redutor + Corrente Bola / Cordão e Rodízios Deslizantes',
            technicalSpec: 'Reposição para persianas rolô ou trilho suíço que travam ao abrir/fechar',
            estimatedQuantity: '1 kit',
            isOptional: true,
          ),
        ],
        tools: const [
          'Furadeira/parafusadeira com coletor de pó (não suja a cortina nem a parede)',
          'Nível a laser cruzado, trena metálica e detector de perfil de drywall',
          'Escada doméstica de plataforma segura',
        ],
      ),
      'estofados e tapetes' => (
        urgency: UrgencyLevel.low,
        duration: '90 a 180 min',
        summary: 'Higienização profunda por extração a vácuo, flotação de manchas, neutralização de odores e sanitização antiácaros de sofás, colchões e tapetes.',
        rootCause: 'Impregnação de suor, poeira doméstica, ácaros, manchas de líquidos ou urina de pets nas camadas internas da espuma e tecido.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-est-flotador',
            name: 'Shampoo Extrator Flotador de Baixa Espuma + Peróxido Ativo Tira-Manchas',
            technicalSpec: 'Solta a sujeira das fibras sem encharcar a espuma (pH balanceado para linho/suede/veludo)',
            estimatedQuantity: 'Dosagem técnica para o estofado',
          ),
          ProbableMaterialItem(
            id: 'mat-est-neutralizador',
            name: 'Sanitizante Bactericida / Neutralizador Enzimático de Odores e Urina',
            technicalSpec: 'Elimina fungos, ácaros e bactérias causadoras de mau cheiro e alergias',
            estimatedQuantity: 'Aplicação completa',
          ),
          ProbableMaterialItem(
            id: 'mat-est-impermeabilizante',
            name: 'Resina Impermeabilizante Protetora de Tecidos (Não Inflamável à Base d\'Água)',
            technicalSpec: 'Bloqueia penetração de líquidos derramados e facilita a limpeza diária',
            estimatedQuantity: 'Aplicação opcional',
            isOptional: true,
          ),
        ],
        tools: const [
          'Extratora profissional de injeção e sucção de alta potência',
          'Politriz orbital com escova de cerdas macias para tecidos delicados',
          'Pulverizador de compressão prévia e soprador secador laminar',
        ],
      ),
      'mudancas e fretes' => (
        urgency: UrgencyLevel.low,
        duration: '2 a 5 horas',
        summary: 'Embalagem protetora, carregamento técnico, transporte seguro com amarração em veículo adequado e descarga no endereço de destino.',
        rootCause: 'Transporte residencial ou comercial de mobiliário, eletrodomésticos e volumes exigindo proteção contra riscos e impactos.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-mud-stretch',
            name: 'Bobina de Filme Stretch Industrial + Rolo de Plástico Bolha Reforçado',
            technicalSpec: 'Envolvimento hermético de sofás, colchões, geladeiras e tampos de vidro',
            estimatedQuantity: '1 bobina + 1 rolo',
          ),
          ProbableMaterialItem(
            id: 'mat-mud-fitas',
            name: 'Fita Adesiva Acrílica Larga (48mmx100m) + Cantoneiras de Papelão Ondulado',
            technicalSpec: 'Fechamento seguro de caixas e proteção de quinas de móveis planejados/MDF',
            estimatedQuantity: '3 rolos + kit quinas',
          ),
        ],
        tools: const [
          'Carrinho plataforma e carrinho armazém com rodas pneumáticas',
          'Mantas e cobertores acolchoados de proteção para transporte',
          'Cintas catracadas de amarração de carga e jogo de chaves para desmontagem rápida',
        ],
      ),
      'informatica e redes' => (
        urgency: UrgencyLevel.medium,
        duration: '45 a 120 min',
        summary: 'Diagnóstico de computador/notebook, otimização de sistema/SSD, limpeza interna com troca de pasta térmica ou ampliação de cobertura Wi-Fi Mesh / cabeamento Cat6.',
        rootCause: 'Lentidão por disco saturado/superaquecimento térmico, ponto cego de sinal Wi-Fi ou falha de conectorização em cabo de rede RJ45.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-inf-cabo-rj45',
            name: 'Cabo de Rede UTP Cat6 100% Cobre + Conectores RJ45 / Keystone Fêmea',
            technicalSpec: 'Link Gigabit estável para roteadores Mesh, Smart TVs e Home Office',
            estimatedQuantity: 'Metragem local + 4 conectores',
            isOptional: true,
          ),
          ProbableMaterialItem(
            id: 'mat-inf-pasta-ssd',
            name: 'Pasta Térmica de Alta Condutividade (Prata/Cerâmica) + Álcool Isopropílico 99,8%',
            technicalSpec: 'Dissipação térmica da CPU/GPU e limpeza desoxidante de contatos eletrônicos',
            estimatedQuantity: '1 aplicação técnica',
          ),
          ProbableMaterialItem(
            id: 'mat-inf-ssd',
            name: 'Unidade SSD NVMe M.2 / SATA III (Upgrade de Alta Velocidade) ou Roteador Mesh',
            technicalSpec: 'Inicialização até 10x mais rápida ou cobertura Wi-Fi Dual-Band em toda a casa',
            estimatedQuantity: '1 un',
            isOptional: true,
          ),
        ],
        tools: const [
          'Testador digital de cabos de rede RJ45 e alicate de crimpagem/punch down',
          'Kit de chaves de precisão antiestáticas (ESD) e soprador de ar comprimido',
          'Pendrive multiboot de diagnóstico de hardware e analisador de espectro Wi-Fi',
        ],
      ),
      'cuidador de idosos' => (
        urgency: UrgencyLevel.medium,
        duration: 'Plantão / Turno combinado',
        summary: 'Assistência humanizada ao idoso no domicílio: auxílio na mobilidade, higiene, alimentação, administração de medicamentos no horário e companhia ativa.',
        rootCause: 'Necessidade de acompanhamento qualificado e seguro na rotina diária, prevenção de quedas e suporte à família.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-cui-receita',
            name: 'Organizador de Medicamentos + Receituário Médico Atualizado com Horários',
            technicalSpec: 'Deixar separado para conferência segura de dosagens e prescrições',
            estimatedQuantity: '1 checklist familiar',
          ),
          ProbableMaterialItem(
            id: 'mat-cui-higiene',
            name: 'Kit de Higiene Pessoal, Luvas Descartáveis e Hidratante Corporal de Uso Rotineiro',
            technicalSpec: 'Insumos de conforto, troca e prevenção de assaduras/escaras do próprio idoso',
            estimatedQuantity: 'Uso diário',
          ),
          ProbableMaterialItem(
            id: 'mat-cui-contatos',
            name: 'Ficha de Contatos de Emergência da Família e Convênio Médico',
            technicalSpec: 'Telefones principais visíveis para comunicação imediata durante o turno',
            estimatedQuantity: '1 ficha',
          ),
        ],
        tools: const [
          'Oxímetro de dedo e aparelho de pressão arterial (esfigmomanômetro digital)',
          'Termômetro clínico digital e caderno/diário de plantão',
          'Calçado fechado antiderrapante e vestimenta adequada de cuidado',
        ],
      ),
      'baba' => (
        urgency: UrgencyLevel.low,
        duration: 'Turno / Período combinado',
        summary: 'Cuidado atento, recreação pedagógica, alimentação, higiene e supervisão de segurança para bebês e crianças no conforto de casa.',
        rootCause: 'Apoio especializado aos pais/responsáveis com rotina estruturada de alimentação, sono e brincadeiras seguras.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-bab-rotina',
            name: 'Kit Troca e Higiene (Fraldas, Lenços Umedecidos, Pomada e Mudas de Roupa)',
            technicalSpec: 'Deixar separado em local de fácil acesso conforme a idade da criança',
            estimatedQuantity: 'Para o período',
          ),
          ProbableMaterialItem(
            id: 'mat-bab-alimentacao',
            name: 'Refeições / Mamadeiras Preparadas e Orientações de Restrição Alimentar/Alergias',
            technicalSpec: 'Cardápio e horários habituais de alimentação e soneca da criança',
            estimatedQuantity: '1 orientação dos pais',
          ),
        ],
        tools: const [
          'Termômetro infantil digital e kit lúdico de atividades/recreação',
          'Monitoramento constante de segurança no ambiente doméstico',
        ],
      ),
      'pet care' => (
        urgency: UrgencyLevel.low,
        duration: '60 min a período combinado',
        summary: 'Passeio seguro (Dog Walker), visita domiciliar (Pet Sitter), alimentação na medida certa, reposição de água fresca, limpeza do espaço e recreação.',
        rootCause: 'Bem-estar físico e mental do pet, gasto saudável de energia e manutenção da rotina na ausência temporária do tutor.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-pet-guia',
            name: 'Coleira / Peitoral Ajustado com Guia Segura e Plaquinha de Identificação',
            technicalSpec: 'Equipamento de contenção confortável para passeio seguro na rua',
            estimatedQuantity: '1 conjunto por pet',
          ),
          ProbableMaterialItem(
            id: 'mat-pet-higienico',
            name: 'Saquinhos Cata-Caca Biodegradáveis / Tapete Higiênico ou Areia Sanitária',
            technicalSpec: 'Manutenção da higiene durante o passeio e no ambiente interno',
            estimatedQuantity: 'Kit de uso diário',
          ),
          ProbableMaterialItem(
            id: 'mat-pet-racao',
            name: 'Porção de Ração / Petiscos Habitual + Carteira de Vacinação/Contato do Veterinário',
            technicalSpec: 'Alimentação sem quebra de dieta e referência veterinária de segurança',
            estimatedQuantity: 'Conforme rotina',
          ),
        ],
        tools: const [
          'Bebedouro portátil de passeio e guia de segurança reserva',
          'Escova de pelagem e brinquedos de enriquecimento ambiental',
        ],
      ),
      _ => (
        urgency: UrgencyLevel.low,
        duration: '45 a 90 min',
        summary: 'Atendimento técnico de manutenção residencial em $categoryName com inspeção detalhada, ajustes funcionais e acabamento limpo.',
        rootCause: 'Desgaste natural de uso cotidiano ou necessidade de instalação/ajuste técnico especializado no imóvel.',
        materials: const [
          ProbableMaterialItem(
            id: 'mat-gen-fixacao',
            name: 'Kit de Fixação Multimaterial (Buchas de Nylon c/ Aba 6mm/8mm e Parafusos)',
            technicalSpec: 'Insumos universais de ancoragem segura em alvenaria, madeira ou drywall',
            estimatedQuantity: '1 kit',
          ),
          ProbableMaterialItem(
            id: 'mat-gen-vedacao',
            name: 'Silicone Neutro / Fita Dupla Face de Alta Adesão e Acabamento',
            technicalSpec: 'Vedação, amortecimento e fixação complementar sem danos à superfície',
            estimatedQuantity: '1 un',
            isOptional: true,
          ),
        ],
        tools: const [
          'Maleta de ferramentas multipropósito (parafusadeira, chaves de precisão e alicates)',
          'Furadeira de impacto, nível a laser e trena metálica',
          'Detector de tubulação/fiação na parede e pano de limpeza técnica',
        ],
      ),
    };

    return SmartTriageResult(
      id: 'triage-${slug.replaceAll(' ', '-')}-${now.millisecondsSinceEpoch}',
      analyzedAt: now,
      suggestedCategoryId: slug,
      suggestedCategoryName: categoryName,
      urgencyLevel: spec.urgency,
      diagnosticSummary: spec.summary,
      probableRootCause: spec.rootCause,
      estimatedDurationRange: spec.duration,
      confidenceScore: (0.92 + mediaBonus).clamp(0.78, 0.99),
      probableMaterials: spec.materials,
      recommendedProviderTools: spec.tools,
      containmentGuide: null,
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
  painting,
  carpentry,
  specialized,
}

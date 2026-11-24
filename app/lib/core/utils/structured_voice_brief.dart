/// Motor semântico de estruturação extrema de áudio -> texto em PT-BR.
///
/// Combina:
///  1. **Restauração fonética técnica** (`repairTechnicalSpeech`): corrige ruídos
///     comuns do reconhecimento de voz no domínio de manutenção residencial;
///  2. **Extração estruturada determinística** (`structureLocally`): organiza
///     fala coloquial em blocos objetivos (`RESUMO`, `LOCAL E EQUIPAMENTO`,
///     `SINTOMAS`, `HISTÓRICO`, `OBSERVAÇÕES`, `URGÊNCIA / HORÁRIO`) sem nunca
///     inventar fatos que o cliente não disse;
///  3. **Parser reverso** (`StructuredVoiceBrief.tryParseStructuredText`): lê o
///     texto estruturado (inclusive com notas `Foto N:`) para exibição rica
///     na tela do profissional e resumo do cliente.
///
/// Tudo Dart puro, testável, determinístico e 100% resiliente offline.
library;

import 'package:flutter/foundation.dart';

import 'smart_transcript_formatter.dart';
import 'tag_normalizer.dart' show normalizeTag;

@immutable
class StructuredVoiceBrief {
  const StructuredVoiceBrief({
    required this.headline,
    required this.problemSummary,
    this.locationAndEquipment,
    this.observedSymptoms = const [],
    this.timelineAndContext,
    this.clientActionsOrNotes,
    this.urgencyAndAvailability,
    this.suggestedCategory,
    this.safetyRisk = 'none',
    this.rawTranscript = '',
    this.source = 'local_semantic',
    this.photoNotes = const [],
  });

  final String headline;
  final String problemSummary;
  final String? locationAndEquipment;
  final List<String> observedSymptoms;
  final String? timelineAndContext;
  final String? clientActionsOrNotes;
  final String? urgencyAndAvailability;
  final String? suggestedCategory;

  /// `'none' | 'attention' | 'critical'`
  final String safetyRisk;
  final String rawTranscript;

  /// `'ai_groq' | 'ai_gemini' | 'ai_openrouter' | 'local_semantic'`
  final String source;
  final List<String> photoNotes;

  bool get isRemoteAiSource => source.startsWith('ai_');

  bool get hasExtraStructure =>
      (locationAndEquipment?.trim().isNotEmpty ?? false) ||
      observedSymptoms.isNotEmpty ||
      (timelineAndContext?.trim().isNotEmpty ?? false) ||
      (clientActionsOrNotes?.trim().isNotEmpty ?? false) ||
      (urgencyAndAvailability?.trim().isNotEmpty ?? false);

  /// Emite o texto canônico estruturado respeitando [maxLength] sem cortar
  /// palavras no meio.
  String toStructuredText({int maxLength = 900}) {
    final summary = problemSummary.trim();
    if (summary.isEmpty) return rawTranscript.trim();

    // Para falas curtíssimas (< 5 palavras e sem campos extras), evita inflar
    // artificialmente com cabeçalhos redundantes.
    final rawWords = rawTranscript.trim().isNotEmpty
        ? rawTranscript.trim().split(RegExp(r'\s+')).length
        : summary.split(RegExp(r'\s+')).length;
    if (rawWords < 5 && !hasExtraStructure) {
      return _clampCleanly(summary, maxLength);
    }

    final lines = <String>['RESUMO: ${_ensurePeriod(summary)}'];

    final loc = locationAndEquipment?.trim();
    if (loc != null && loc.isNotEmpty) {
      lines.add('LOCAL E EQUIPAMENTO: $loc');
    }

    final cleanSymptoms = observedSymptoms
        .map((s) => s.trim().replaceAll(RegExp(r'[.;]+$'), ''))
        .where((s) => s.isNotEmpty)
        .toList();
    if (cleanSymptoms.isNotEmpty) {
      lines.add('SINTOMAS: ${cleanSymptoms.join('; ')}.');
    }

    final timeline = timelineAndContext?.trim();
    if (timeline != null && timeline.isNotEmpty) {
      lines.add('HISTÓRICO: ${_ensurePeriod(timeline)}');
    }

    final actions = clientActionsOrNotes?.trim();
    if (actions != null && actions.isNotEmpty) {
      lines.add('OBSERVAÇÕES: ${_ensurePeriod(actions)}');
    }

    final urgency = urgencyAndAvailability?.trim();
    if (urgency != null && urgency.isNotEmpty) {
      lines.add('URGÊNCIA / HORÁRIO: $urgency');
    }

    final joined = lines.join('\n');
    if (joined.length <= maxLength) return joined;

    // Compactação progressiva mantendo sempre RESUMO + blocos mais críticos.
    final compacted = <String>[];
    var totalLen = 0;
    for (final line in lines) {
      final sep = compacted.isEmpty ? 0 : 1;
      if (totalLen + sep + line.length <= maxLength) {
        compacted.add(line);
        totalLen += sep + line.length;
      } else if (compacted.isEmpty) {
        return _clampCleanly(line, maxLength);
      } else {
        final remaining = maxLength - totalLen - sep;
        if (remaining >= 24) {
          compacted.add(_clampCleanly(line, remaining));
        }
        break;
      }
    }
    return compacted.join('\n');
  }

  factory StructuredVoiceBrief.fromAiJson(
    Map<String, dynamic> map, {
    required String rawTranscript,
    String source = 'ai_groq',
  }) {
    String? optStr(String key) {
      final v = map[key];
      if (v is! String) return null;
      final t = v.trim();
      if (t.isEmpty ||
          t.toLowerCase() == 'null' ||
          t.toLowerCase() == 'não informado' ||
          t.toLowerCase() == 'nao informado') {
        return null;
      }
      return t;
    }

    final summary = optStr('problem_summary') ??
        optStr('problemSummary') ??
        rawTranscript.trim();
    final headline = optStr('headline') ?? summary;
    final rawSymptoms = map['observed_symptoms'] ?? map['observedSymptoms'];
    final symptoms = <String>[
      if (rawSymptoms is List)
        for (final item in rawSymptoms)
          if (item is String && item.trim().isNotEmpty) item.trim(),
    ];

    final riskRaw = (optStr('safety_risk') ?? optStr('safetyRisk') ?? 'none')
        .toLowerCase();
    final risk = const {'none', 'attention', 'critical'}.contains(riskRaw)
        ? riskRaw
        : 'none';

    return StructuredVoiceBrief(
      headline: _capitalizeFirst(headline),
      problemSummary: _capitalizeFirst(summary),
      locationAndEquipment:
          optStr('location_and_equipment') ?? optStr('locationAndEquipment'),
      observedSymptoms: symptoms,
      timelineAndContext:
          optStr('timeline_and_context') ?? optStr('timelineAndContext'),
      clientActionsOrNotes:
          optStr('client_actions_or_notes') ?? optStr('clientActionsOrNotes'),
      urgencyAndAvailability: optStr('urgency_and_availability') ??
          optStr('urgencyAndAvailability'),
      suggestedCategory:
          optStr('suggested_category') ?? optStr('suggestedCategory'),
      safetyRisk: risk,
      rawTranscript: rawTranscript,
      source: source,
    );
  }

  /// Faz parse de um texto já estruturado (como gravado em `jobs.description`),
  /// separando inclusive eventuais linhas `Foto N: ...`. Retorna `null` se for
  /// texto livre legado sem marcações estruturadas.
  static StructuredVoiceBrief? tryParseStructuredText(String rawDescription) {
    final text = rawDescription.trim();
    if (text.isEmpty) return null;

    String? summary;
    String? location;
    List<String> symptoms = const [];
    String? timeline;
    String? notes;
    String? urgency;
    final photos = <String>[];
    final looseLines = <String>[];

    final photoRe = RegExp(r'^Foto\s+\d+\s*:\s*(.+)$', caseSensitive: false);
    final labelRe = RegExp(
      r'^(RESUMO|LOCAL E EQUIPAMENTO|SINTOMAS|HIST[ÓO]RICO|OBSERVA[ÇC][ÕO]ES|URG[ÊE]NCIA\s*/\s*HOR[ÁA]RIO)\s*:\s*(.+)$',
      caseSensitive: false,
    );

    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final photoMatch = photoRe.firstMatch(line);
      if (photoMatch != null) {
        photos.add(line);
        continue;
      }
      final m = labelRe.firstMatch(line);
      if (m == null) {
        looseLines.add(line);
        continue;
      }
      final key = normalizeTag(m.group(1)!).toUpperCase();
      final val = m.group(2)!.trim();
      if (val.isEmpty) continue;

      if (key.startsWith('RESUMO')) {
        summary = val;
      } else if (key.startsWith('LOCAL')) {
        location = val;
      } else if (key.startsWith('SINTOMAS')) {
        symptoms = val
            .split(RegExp(r'\s*;\s*'))
            .map((e) => e.replaceAll(RegExp(r'[.]+$'), '').trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else if (key.startsWith('HISTORICO')) {
        timeline = val;
      } else if (key.startsWith('OBSERVACOES')) {
        notes = val;
      } else if (key.startsWith('URGENCIA')) {
        urgency = val;
      }
    }

    if (summary == null &&
        location == null &&
        symptoms.isEmpty &&
        timeline == null &&
        notes == null &&
        urgency == null) {
      return null;
    }

    final effectiveSummary =
        summary ?? (looseLines.isNotEmpty ? looseLines.join(' ') : text);
    final norm = normalizeTag(text);
    final safetyRisk = _classifySafetyRisk(norm);

    return StructuredVoiceBrief(
      headline: effectiveSummary,
      problemSummary: effectiveSummary,
      locationAndEquipment: location,
      observedSymptoms: symptoms,
      timelineAndContext: timeline,
      clientActionsOrNotes: notes,
      urgencyAndAvailability: urgency,
      safetyRisk: safetyRisk,
      rawTranscript: text,
      source: 'parsed',
      photoNotes: photos,
    );
  }
}

/// Engine pura em Dart que realiza restauração fonética PT-BR e estruturação
/// semântica determinística (fallback offline ou sem chaves de IA).
class StructuredVoiceBriefEngine {
  const StructuredVoiceBriefEngine._();

  static final List<(RegExp, String)> _phoneticRepairs = [
    (
      RegExp(
        r'\b(?:disjutor|dijuntor|desjuntor|disjunt[ôo])\b',
        caseSensitive: false,
      ),
      'disjuntor',
    ),
    (
      RegExp(
        r'\b(?:choveiro|xuveiro|chuvero)\b',
        caseSensitive: false,
      ),
      'chuveiro',
    ),
    (
      RegExp(
        r'\b(?:lorenzete|lorenzeti|lorezetti|lorenzetti)\b',
        caseSensitive: false,
      ),
      'Lorenzetti',
    ),
    (
      RegExp(r'\b(?:hidra|ydra)\b', caseSensitive: false),
      'Hydra',
    ),
    (
      RegExp(r'\b(?:sifao|cefao|cifao|sif[ãa]u)\b', caseSensitive: false),
      'sifão',
    ),
    (
      RegExp(r'\bgaz\b', caseSensitive: false),
      'gás',
    ),
    (
      RegExp(r'\b(?:infiltracao|infiltrasao|enfiltracao)\b', caseSensitive: false),
      'infiltração',
    ),
    (
      RegExp(r'\b(?:feixadura|fexadura)\b', caseSensitive: false),
      'fechadura',
    ),
    (
      RegExp(r'\b(?:botijao|butijao)\b', caseSensitive: false),
      'botijão',
    ),
    (
      RegExp(r'\bar\s+condicionado\b', caseSensitive: false),
      'ar-condicionado',
    ),
    (
      RegExp(r'\bcurto\s+circuito\b', caseSensitive: false),
      'curto-circuito',
    ),
    (
      RegExp(
        r'\b(110|127|220|380)\s*(?:volts?|v)\b',
        caseSensitive: false,
      ),
      '__VOLTAGE__',
    ),
  ];

  /// Corrige erros fonéticos comuns do STT Android/Web em termos técnicos PT-BR.
  static String repairTechnicalSpeech(String raw) {
    var out = raw;
    for (final (re, repl) in _phoneticRepairs) {
      if (repl == '__VOLTAGE__') {
        out = out.replaceAllMapped(re, (m) => '${m.group(1)}V');
      } else {
        out = out.replaceAll(re, repl);
      }
    }
    // Preserva capitalização se começou com maiúscula
    return out;
  }

  /// Remove saudações/preenchimentos iniciais apenas para produzir um resumo
  /// limpo e objetivo do problema, sem alterar a fala original em outros usos.
  static String stripPoliteOpeners(String text) {
    var t = text.trim();
    final patterns = [
      RegExp(
        r'^(?:ol[áa]|oi+|opa|e\s+a[íi]|bom\s+dia|boa\s+tarde|boa\s+noite|tudo\s+(?:bem|bom))[\s,!.;:-]*',
        caseSensitive: false,
      ),
      RegExp(
        r'^(?:ent[ãa]o|olha|seguinte|tipo\s+assim|tipo|assim|gostaria\s+de\s+falar\s+que|preciso\s+falar\s+que|quero\s+falar\s+que|queria\s+pedir\s+ajuda\s+porque|preciso\s+de\s+ajuda\s+porque)[\s,!.;:-]*',
        caseSensitive: false,
      ),
    ];
    for (var pass = 0; pass < 4; pass++) {
      var changed = false;
      for (final p in patterns) {
        final m = p.firstMatch(t);
        if (m != null && m.start == 0 && m.end < t.length) {
          final rest = t.substring(m.end).trimLeft();
          if (rest.length >= 6) {
            t = rest;
            changed = true;
          }
        }
      }
      if (!changed) break;
    }
    return t;
  }

  /// Remove vícios de oralidade típicos da fala brasileira (`tipo assim`,
  /// `, tá ligado,`, `né`, `meio que`, `então assim`, `aí tipo`) sem remover
  /// nenhum fato técnico ou sintoma relatado pelo cliente.
  static String stripColloquialFillers(String text) {
    var out = text;
    final fillerPatterns = <RegExp>[
      RegExp(
        r'(?:,\s*|\s+)(?:tipo\s+assim|ent[ãa]o\s+assim|a[íi]\s+tipo|sei\s+l[áa])(?:\s*,|\s+)',
        caseSensitive: false,
      ),
      // Somente como intercalação coloquial entre vírgulas (nunca remove "o disjuntor está ligado")
      RegExp(
        r',\s*(?:t[áa]|est[áa])\s+ligado\s*,',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:,\s*|\s+)n[ée](?=\s*[,.;!?]|\s+)',
        caseSensitive: false,
      ),
      RegExp(
        r'\bmeio\s+que\s+',
        caseSensitive: false,
      ),
    ];
    for (final re in fillerPatterns) {
      out = out.replaceAll(re, ' ');
    }
    return out
        .replaceAllMapped(RegExp(r'\s+([,.;!?])'), (m) => m.group(1)!)
        .replaceAll(RegExp(r',\s*,+'), ',')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  static final List<(RegExp, String)> _roomLexicon = [
    (RegExp(r'\bsu[íi]te\b', caseSensitive: false), 'Suíte'),
    (RegExp(r'\bbanheiro(?:\s+social|\s+de\s+cima|\s+de\s+baixo)?\b', caseSensitive: false), 'Banheiro'),
    (RegExp(r'\bcozinha\b', caseSensitive: false), 'Cozinha'),
    (RegExp(r'\b[áa]rea\s+de\s+servi[çc]o\b', caseSensitive: false), 'Área de serviço'),
    (RegExp(r'\blavanderia\b', caseSensitive: false), 'Lavanderia'),
    (RegExp(r'\blavabo\b', caseSensitive: false), 'Lavabo'),
    (RegExp(r'\bsala(?:\s+de\s+estar|\s+de\s+jantar)?\b', caseSensitive: false), 'Sala'),
    (RegExp(r'\bquarto(?:\s+do\s+casal|\s+de\s+h[óo]spedes)?\b', caseSensitive: false), 'Quarto'),
    (RegExp(r'\bescrit[óo]rio\b', caseSensitive: false), 'Escritório'),
    (RegExp(r'\bgaragem\b', caseSensitive: false), 'Garagem'),
    (RegExp(r'\bquintal\b', caseSensitive: false), 'Quintal'),
    (RegExp(r'\bvaranda\b', caseSensitive: false), 'Varanda'),
    (RegExp(r'\bcorredor\b', caseSensitive: false), 'Corredor'),
    (RegExp(r'\btelhado\b', caseSensitive: false), 'Telhado'),
    (RegExp(r'\blaje\b', caseSensitive: false), 'Laje'),
    (RegExp(r"\bcaixa\s+d'?[áa]gua\b", caseSensitive: false), "Caixa d'água"),
    (RegExp(r'\bport[ãa]o\b', caseSensitive: false), 'Portão'),
    (RegExp(r'\bquadro\s+(?:de\s+luz|el[ée]trico|de\s+distribui[çc][ãa]o)\b', caseSensitive: false), 'Quadro elétrico'),
  ];

  static final List<(RegExp, String)> _equipmentLexicon = [
    (RegExp(r'\bchuveiro(?:\s+el[ée]trico)?\b', caseSensitive: false), 'Chuveiro'),
    (RegExp(r'\btorneira\b', caseSensitive: false), 'Torneira'),
    (RegExp(r'\bmisturador\b', caseSensitive: false), 'Misturador'),
    (RegExp(r'\bsif[ãa]o\b', caseSensitive: false), 'Sifão'),
    (RegExp(r'\bpia\b', caseSensitive: false), 'Pia'),
    (RegExp(r'\btanque\b', caseSensitive: false), 'Tanque'),
    (RegExp(r'\bvaso(?:\s+sanit[áa]rio)?\b', caseSensitive: false), 'Vaso sanitário'),
    (RegExp(r'\bcaixa\s+acoplada\b', caseSensitive: false), 'Caixa acoplada'),
    (RegExp(r'\bv[áa]lvula\s+hydra\b|\bhydra\b', caseSensitive: false), 'Válvula Hydra'),
    (RegExp(r'\bregistro(?:\s+geral|\s+de\s+gaveta|\s+de\s+press[ãa]o)?\b', caseSensitive: false), 'Registro'),
    (RegExp(r'\bdisjuntor\b', caseSensitive: false), 'Disjuntor'),
    (RegExp(r'\btomada\b', caseSensitive: false), 'Tomada'),
    (RegExp(r'\binterruptor\b', caseSensitive: false), 'Interruptor'),
    (RegExp(r'\bar[- ]?condicionado(?:\s+split)?\b', caseSensitive: false), 'Ar-condicionado'),
    (RegExp(r'\bevaporadora\b', caseSensitive: false), 'Evaporadora'),
    (RegExp(r'\bcondensadora\b', caseSensitive: false), 'Condensadora'),
    (RegExp(r'\baquecedor(?:\s+a\s+g[áa]s)?\b', caseSensitive: false), 'Aquecedor'),
    (RegExp(r'\bfog[ãa]o\b', caseSensitive: false), 'Fogão'),
    (RegExp(r'\bbotij[ãa]o\b', caseSensitive: false), 'Botijão GLP'),
    (RegExp(r'\bfechadura\b', caseSensitive: false), 'Fechadura'),
    (RegExp(r'\bmotor\s+do?\s+port[ãa]o\b', caseSensitive: false), 'Motor do portão'),
    (RegExp(r'\btelha\b', caseSensitive: false), 'Telha'),
    (RegExp(r'\bcalha\b', caseSensitive: false), 'Calha'),
    (RegExp(r'\bm[áa]quina\s+de\s+lavar\b', caseSensitive: false), 'Máquina de lavar'),
    (RegExp(r'\bgeladeira\b', caseSensitive: false), 'Geladeira'),
  ];

  static final RegExp _brandRe = RegExp(
    r'\b(Lorenzetti|Hydra|Deca|Docol|Tigre|Amanco|Electrolux|Brastemp|Consul|Samsung|LG|Midea|Springer|Carrier|Gree|Daikin|Intelbras|Papaiz|Pado|Stam|Steck|Schneider|Siemens)\b',
    caseSensitive: false,
  );

  static final RegExp _specRe = RegExp(
    r'\b(\d{2,3}\s*V|\d{1,2}\s*A|\d{3,5}\s*W|\d{4,5}\s*BTUs?|1/2\b|3/4\b|\d{2}\s*mm)\b',
    caseSensitive: false,
  );

  static StructuredVoiceBrief structureLocally(
    String input, {
    String? currentCategory,
  }) {
    final cleanedSpeech = repairTechnicalSpeech(
      SmartTranscriptFormatter.format(input),
    ).trim();
    if (cleanedSpeech.isEmpty) {
      return const StructuredVoiceBrief(
        headline: '',
        problemSummary: '',
        rawTranscript: '',
      );
    }

    final withoutOpeners = stripColloquialFillers(
      stripPoliteOpeners(cleanedSpeech),
    );
    final effective =
        withoutOpeners.isNotEmpty ? withoutOpeners : cleanedSpeech;
    final norm = normalizeTag(effective);

    // 1. Cômodos / locais
    final rooms = <String>[];
    for (final (re, label) in _roomLexicon) {
      if (re.hasMatch(effective) && !rooms.contains(label)) {
        rooms.add(label);
      }
    }
    final floorMatch = RegExp(
      r'\b(\d+[º°]?\s*andar|t[ée]rreo|apartamento|ap\.?\s*\d+|sobrado|casa)\b',
      caseSensitive: false,
    ).firstMatch(effective);
    if (floorMatch != null) {
      final f = _capitalizeFirst(floorMatch.group(1)!.trim());
      if (!rooms.any((r) => r.toLowerCase() == f.toLowerCase())) {
        rooms.add(f);
      }
    }

    // 2. Equipamentos + marca + especificações técnicas
    final equipments = <String>[];
    for (final (re, label) in _equipmentLexicon) {
      if (re.hasMatch(effective) && !equipments.contains(label)) {
        equipments.add(label);
      }
    }
    final brands = <String>{
      for (final m in _brandRe.allMatches(effective))
        _capitalizeFirst(m.group(1)!.trim()),
    };
    final specs = <String>{
      for (final m in _specRe.allMatches(effective))
        m.group(1)!.replaceAll(RegExp(r'\s+'), '').toUpperCase(),
    };

    final locEquipParts = <String>[];
    if (equipments.isNotEmpty) {
      final equipLabel = [
        equipments.take(2).join(' / '),
        if (brands.isNotEmpty) brands.first,
        if (specs.isNotEmpty) specs.take(2).join(', '),
      ].join(' · ');
      locEquipParts.add(equipLabel);
    }
    if (rooms.isNotEmpty) {
      locEquipParts.add(rooms.take(2).join(', '));
    }
    final locationAndEquipment =
        locEquipParts.isEmpty ? null : locEquipParts.join(' — ');

    // 3. Separar frases e cláusulas coloquiais para classificar sintomas, histórico, ações e disponibilidade
    final sentences = effective
        .split(
          RegExp(
            r'(?<=[.!?])\s+|\s*;\s*|\s+(?:(?:e|mas)\s+)?(?=(?:eu\s+)?j[áa]\s+(?:desliguei|fechei|tentei|troquei|comprei|chamei)\b|voc[êe]s?\s+(?:consegue[ms]?|pode[ms]?)\b|consegue[ms]?\s+vir\b|d[áa]\s+pra\s+vir\b|preciso\s+para\s+(?:hoje|amanh[ãa]))',
            caseSensitive: false,
          ),
        )
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final symptoms = <String>[];
    final timelineParts = <String>[];
    final actionParts = <String>[];
    final urgencyParts = <String>[];

    // Comparadas contra `normalizeTag(s)` (minúsculas ASCII sem acentos),
    // garantindo que `\b` funcione em palavras acentuadas como `amanhã`, `há`, `já` e `terça`.
    final timelineRe = RegExp(
      r'\b(?:comecou|desde\s+(?:ontem|anteontem|segunda|terca|quarta|quinta|sexta|sabado|domingo|a\s+semana|o\s+mes)|ha\s+\d+\s+(?:horas?|dias?|semanas?|meses?)|faz\s+\d+\s+(?:horas?|dias?|semanas?)|toda\s+vez\s+que|quando\s+eu\s+ligo|depois\s+d[aoe]\s+chuva)\b',
    );
    final actionRe = RegExp(
      r'\b(?:ja\s+(?:desliguei|fechei|tentei|troquei|comprei|tenho|chamei)|nao\s+(?:tentei|tenho)|tenho\s+a?\s*peca|moro\s+no|portaria|escada)\b',
    );
    final urgencyRe = RegExp(
      r'\b(?:urgente|emergencia|agora|o\s+quanto\s+antes|para\s+hoje|ainda\s+hoje|amanha|de\s+manha|(?<!ontem\s)(?<!anteontem\s)a\s+tarde|(?<!ontem\s)(?<!anteontem\s)a\s+noite|fim\s+de\s+semana|segunda|terca|quarta|quinta|sexta|sabado|domingo|consegue[ms]?\s+vir|pode[ms]?\s+vir|qual\s+o?\s+horario)\b',
    );

    for (final s in sentences) {
      final normSentence = normalizeTag(s);
      var classified = false;
      if (actionRe.hasMatch(normSentence)) {
        actionParts.add(_cleanClause(s));
        classified = true;
      }
      if (timelineRe.hasMatch(normSentence)) {
        timelineParts.add(_cleanClause(s));
        classified = true;
      }
      if (urgencyRe.hasMatch(normSentence)) {
        final cleanedU = _cleanClause(s);
        if (!urgencyParts.contains(cleanedU)) urgencyParts.add(cleanedU);
        // Se for apenas pergunta de disponibilidade pura, não polui sintomas.
        if (_isPureAvailabilityQuestion(s)) classified = true;
      }
      if (!classified || _hasSymptomSignal(s)) {
        for (final sub in s.split(RegExp(r'\s*,\s*(?=(?:mas|e|por[ée]m|s[óo]\s+que|tamb[ée]m)\b)', caseSensitive: false))) {
          final clean = _cleanClause(sub);
          if (clean.length >= 6 &&
              !_isPureAvailabilityQuestion(clean) &&
              !symptoms.any((x) => normalizeTag(x) == normalizeTag(clean))) {
            symptoms.add(_capitalizeFirst(clean));
          }
        }
      }
    }

    // Remove o próprio problema se ficar exatamente igual ao summary único
    final summaryCandidate = _buildSummary(
      sentences: sentences,
      symptoms: symptoms,
      fallback: effective,
    );

    final filteredSymptoms = symptoms
        .where((s) =>
            symptoms.length > 1 ||
            _hasSymptomSignal(s) ||
            normalizeTag(s) != normalizeTag(summaryCandidate))
        .take(5)
        .toList();

    final safetyRisk = _classifySafetyRisk(norm);

    String? urgencySummary;
    if (urgencyParts.isNotEmpty) {
      urgencySummary = urgencyParts.join('; ');
    } else if (safetyRisk == 'critical') {
      urgencySummary = 'Atenção imediata recomendada pelo risco relatado';
    }

    return StructuredVoiceBrief(
      headline: _capitalizeFirst(
        _clampCleanly(summaryCandidate, 68),
      ),
      problemSummary: _capitalizeFirst(summaryCandidate),
      locationAndEquipment: locationAndEquipment,
      observedSymptoms: filteredSymptoms,
      timelineAndContext:
          timelineParts.isEmpty ? null : _capitalizeFirst(timelineParts.join('. ')),
      clientActionsOrNotes:
          actionParts.isEmpty ? null : _capitalizeFirst(actionParts.join('. ')),
      urgencyAndAvailability: urgencySummary != null
          ? _capitalizeFirst(urgencySummary)
          : null,
      suggestedCategory: currentCategory,
      safetyRisk: safetyRisk,
      rawTranscript: cleanedSpeech,
      source: 'local_semantic',
    );
  }

  static String _buildSummary({
    required List<String> sentences,
    required List<String> symptoms,
    required String fallback,
  }) {
    if (sentences.isEmpty) return fallback;
    final first = _cleanClause(sentences.first);
    if (first.split(RegExp(r'\s+')).length >= 4 &&
        !_isPureAvailabilityQuestion(first)) {
      return first;
    }
    if (symptoms.isNotEmpty) return symptoms.first;
    return _cleanClause(fallback);
  }

  static bool _isPureAvailabilityQuestion(String s) {
    final n = normalizeTag(s);
    return n.startsWith('voces conseguem') ||
        n.startsWith('voce consegue') ||
        n.startsWith('consegue vir') ||
        n.startsWith('da pra vir') ||
        n.startsWith('da para vir') ||
        n.startsWith('que horas') ||
        n.startsWith('quando voces');
  }

  static bool _hasSymptomSignal(String s) {
    final n = normalizeTag(s);
    return _hasAny(n, const [
      'nao liga',
      'nao esquenta',
      'nao gela',
      'nao funciona',
      'parou',
      'desarma',
      'desarmando',
      'vazando',
      'vaza',
      'pingando',
      'pinga',
      'queimou',
      'quebrou',
      'entupiu',
      'entupido',
      'curto',
      'faisca',
      'choque',
      'cheiro',
      'barulho',
      'solta',
      'solto',
      'travou',
      'emperrou',
      'infiltracao',
      'mofo',
    ]);
  }

  static String _cleanClause(String s) => s
      .trim()
      .replaceAll(RegExp(r'^[,\s]+'), '')
      .replaceAll(RegExp(r'[.!?,\s]+$'), '')
      .trim();
}

String _classifySafetyRisk(String norm) {
  if (_hasAny(norm, const [
    'cheiro de gas',
    'cheiro forte de gas',
    'vazamento de gas',
    'vazando gas',
    'gas vazando',
    'faisca',
    'soltando faisca',
    'pegando fogo',
    'fumaca',
    'cano estourou',
    'estourou o cano',
    'alagando',
  ])) {
    return 'critical';
  }
  if (_hasAny(norm, const [
    'choque',
    'disjuntor',
    'desarmando',
    'desarma',
    'curto',
    'vazando',
    'vazamento',
    'goteira',
    'cheiro de queimado',
  ])) {
    return 'attention';
  }
  return 'none';
}

bool _hasAny(String norm, List<String> terms) {
  for (final t in terms) {
    if (norm.contains(t)) return true;
  }
  return false;
}

String _ensurePeriod(String s) {
  final t = s.trim();
  if (t.isEmpty) return t;
  return RegExp(r'[.!?]$').hasMatch(t) ? t : '$t.';
}

String _capitalizeFirst(String s) {
  final t = s.trimLeft();
  if (t.isEmpty) return t;
  final first = t[0].toUpperCase();
  return '$first${t.substring(1)}';
}

String _clampCleanly(String s, int maxLen) {
  final t = s.trim();
  if (t.length <= maxLen) return t;
  final slice = t.substring(0, maxLen).trimRight();
  final lastSpace = slice.lastIndexOf(' ');
  if (lastSpace > (maxLen * 0.55).round()) {
    return '${slice.substring(0, lastSpace).replaceAll(RegExp(r'[,;:\s]+$'), '')}.';
  }
  return slice;
}

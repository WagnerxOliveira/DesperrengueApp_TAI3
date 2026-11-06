/// Formatador inteligente de relato por voz (Dart puro, testável).
///
/// O reconhecimento de fala entrega texto "cru": tudo minúsculo, sem pontuação, com vícios de
/// fala ("ééé", "hum"). Este formatador transforma isso num relato claro e coeso:
///
///  * vírgulas em pausas e antes de conjunções ("…não liga, mas o disjuntor…");
///  * ponto final ao encerrar cada período; `?` em perguntas;
///  * capitalização correta no início de cada período;
///  * comandos falados ("vírgula", "ponto final", "ponto de interrogação");
///  * remoção de hesitações e palavras repetidas por gagueira.
///
/// Tudo determinístico, sem rede e sem IA externa: roda offline, no Web/PWA também.
library;

import 'tag_normalizer.dart' show normalizeTag;

class SmartTranscriptFormatter {
  const SmartTranscriptFormatter._();

  /// Formata [raw]. Se o motor de voz entregou trechos separados por pausa ([segments]),
  /// cada fronteira vira vírgula (trecho curto) ou ponto (período já completo).
  static String format(String raw, {List<String>? segments}) {
    final hasSegments = segments != null && segments.any((s) => s.trim().isNotEmpty);
    final input = hasSegments ? _joinSegments(segments) : raw;
    final text = _collapseRepeats(_clean(input));
    if (text.isEmpty) return '';

    final out = <String>[];
    for (final s in _dedupeSentences(_split(text))) {
      final pieces = _breakRunOn(s.body);
      for (var i = 0; i < pieces.length; i++) {
        final piece = _commas(pieces[i]);
        final isLast = i == pieces.length - 1;
        final mark = (isLast && s.mark != null) ? s.mark! : (_isQuestion(piece) ? '?' : '.');
        out.add('${_capitalize(piece)}$mark');
      }
    }
    return out.join(' ').replaceAll(_decimalDot, '.');
  }

  /// Junta [base] (texto que o cliente já digitou) com o relato [spoken] já formatado.
  static String append(String base, String spoken) {
    final b = base.trimRight();
    final s = spoken.trim();
    if (s.isEmpty) return b;
    if (b.isEmpty) return s;
    final needsBreak = !RegExp(r'[.!?]$').hasMatch(b);
    return needsBreak ? '$b. $s' : '$b $s';
  }

  // ------------------------------------------------------------------ internos

  static const String _decimalDot = '\uE000';

  static RegExp _word(String alternatives) =>
      RegExp('(?<![\\p{L}\\p{N}])(?:$alternatives)(?![\\p{L}\\p{N}])', caseSensitive: false, unicode: true);

  static final RegExp _qMark = _word('ponto de interroga[cç][aã]o');
  static final RegExp _exMark = _word('ponto de exclama[cç][aã]o');
  static final RegExp _period = _word('ponto final|novo par[aá]grafo');
  static final RegExp _comma = _word('v[ií]rgula');
  static final RegExp _fillers = _word('[ãa]h+|ahn|ahm|hum+|hmm+|hã|éh+|é{2,}|uhm|uh+');
  static final RegExp _stutter = RegExp(
    r'(?<![\p{L}])(o|a|os|as|um|uma|de|da|do|em|no|na|que|eu|e)(?:\s+\1)+(?![\p{L}])',
    caseSensitive: false,
    unicode: true,
  );

  /// Vírgula ANTES destas conjunções (adversativas, conclusivas e explicativas).
  static final RegExp _commaBefore = RegExp(
    r'(?<=\p{L})\s+(?:mas|porém|contudo|todavia|entretanto|só que|pois|portanto|ou seja|então|porque|por favor|por exemplo|inclusive|além disso)(?![\p{L}\p{N}])',
    caseSensitive: false,
    unicode: true,
  );

  static const Set<String> _runOnMarkers = {'ai', 'entao', 'depois', 'agora', 'tambem', 'alem'};

  /// Fala coloquial → escrita correta (só trocas inequívocas, nunca mudam o sentido).
  static const Map<String, String> _colloquial = {
    'pra': 'para',
    'pro': 'para o',
    'tá': 'está',
    'tô': 'estou',
    'vc': 'você',
    'vcs': 'vocês',
    'tb': 'também',
    'tbm': 'também',
    'q': 'que',
    'blz': 'beleza',
    'obg': 'obrigado',
  };
  static final RegExp _colloquialRe = _word('pra|pro|tá|tô|vcs?|tbm?|q|blz|obg');

  /// Saudação no início do relato: "Olá, ..." / "Boa noite, ...".
  static final RegExp _greeting = RegExp(
    r'^(olá|ola|oi|bom dia|boa tarde|boa noite)(?=\s+[\p{L}])',
    caseSensitive: false,
    unicode: true,
  );

  /// Cortesias que fecham o relato: viram frase própria ("... disjuntor. Obrigado.").
  static const Set<String> _courtesy = {'obrigado', 'obrigada', 'valeu', 'agradeco'};

  static const List<String> _questionStarters = [
    'como', 'quando', 'onde', 'aonde', 'qual', 'quais', 'quem', 'quanto', 'quantos', 'quanta', 'quantas',
    'por que', 'o que', 'que horas', 'sera que', 'tem como', 'da pra', 'da para', 'e possivel',
    'voce consegue', 'voces conseguem', 'voce pode', 'voces podem', 'voce poderia', 'voces poderiam',
    'alguem pode', 'alguem consegue', 'existe', 'tudo bem',
  ];

  static String _joinSegments(List<String> segments) {
    final b = StringBuffer();
    for (final raw in segments) {
      final seg = raw.trim();
      if (seg.isEmpty) continue;
      if (b.isEmpty) {
        b.write(seg);
        continue;
      }
      final acc = b.toString();
      if (RegExp(r'[.!?,;:]$').hasMatch(acc)) {
        b.write(' $seg');
      } else {
        // Pausa: se o trecho anterior já é um período "cheio" (≥ 6 palavras), fecha com ponto.
        final sinceStop = acc.split(RegExp(r'[.!?]')).last.trim();
        final words = sinceStop.isEmpty ? 0 : sinceStop.split(RegExp(r'\s+')).length;
        b.write(words >= 6 ? '. $seg' : ', $seg');
      }
    }
    return b.toString();
  }

  static String _clean(String input) {
    var t = input.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    // Protege decimais ("3.5 metros") do divisor de períodos.
    t = t.replaceAllMapped(RegExp(r'(?<=\d)\.(?=\d)'), (_) => _decimalDot);
    t = t
        .replaceAll(_qMark, '?')
        .replaceAll(_exMark, '!')
        .replaceAll(_period, '.')
        .replaceAll(_comma, ',')
        .replaceAll(_fillers, ' ')
        .replaceAllMapped(_stutter, (m) => m.group(1)!)
        .replaceAllMapped(_colloquialRe, (m) => _colloquial[m.group(0)!.toLowerCase()] ?? m.group(0)!)
        .replaceFirstMapped(_greeting, (m) => '${m.group(1)},');
    t = t
        .replaceAll(RegExp(r'\.{2,}'), '.')
        .replaceAll(RegExp(r',{2,}'), ',')
        .replaceAllMapped(RegExp(r'\s+([,.;!?:])'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'([,;!?:])(?=\p{L})', unicode: true), (m) => '${m.group(1)} ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'^[\s,.;!?:]+'), '')
        .trim();
    return t;
  }

  /// Remove repetição imediata de um trecho de 3+ palavras ("preciso de um eletricista preciso de
  /// um eletricista"): vício comum quando o reconhecedor entrega o mesmo trecho duas vezes.
  static String _collapseRepeats(String text) {
    var tokens = text.split(' ').where((t) => t.isNotEmpty).toList();
    String norm(String t) => normalizeTag(t.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''));
    var changed = true;
    while (changed) {
      changed = false;
      outer:
      for (var n = tokens.length ~/ 2; n >= 3; n--) {
        for (var i = 0; i + 2 * n <= tokens.length; i++) {
          var same = true;
          for (var k = 0; k < n; k++) {
            final a = norm(tokens[i + k]);
            if (a.isEmpty || a != norm(tokens[i + n + k])) {
              same = false;
              break;
            }
          }
          if (same) {
            tokens = [...tokens.sublist(0, i + n), ...tokens.sublist(i + 2 * n)];
            changed = true;
            break outer;
          }
        }
      }
    }
    return tokens.join(' ');
  }

  /// Períodos consecutivos repetidos (ou contidos no anterior) são fundidos.
  static List<_Sentence> _dedupeSentences(List<_Sentence> list) {
    String key(String s) =>
        normalizeTag(s.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')).replaceAll(RegExp(r'\s+'), ' ').trim();
    final out = <_Sentence>[];
    for (final s in list) {
      if (out.isNotEmpty) {
        final a = key(out.last.body);
        final b = key(s.body);
        if (a == b || (b.length >= 12 && a.contains(b))) continue;
        if (a.length >= 12 && b.contains(a)) {
          out[out.length - 1] = s;
          continue;
        }
      }
      out.add(s);
    }
    return out;
  }

  static List<_Sentence> _split(String text) {
    final out = <_Sentence>[];
    for (final m in RegExp(r'([^.!?]+)([.!?]+)?').allMatches(text)) {
      final body = m.group(1)!.trim().replaceAll(RegExp(r'[,;:]+$'), '').trim();
      if (body.isEmpty) continue;
      final mk = m.group(2);
      final mark = mk == null ? null : (mk.contains('?') ? '?' : (mk.contains('!') ? '!' : '.'));
      out.add(_Sentence(body, mark));
    }
    return out;
  }

  /// Períodos sem pontuação muito longos são quebrados em marcadores de discurso
  /// ("aí", "então", "depois", "agora"…), desde que sobrem palavras suficientes dos dois lados.
  static List<String> _breakRunOn(String body) {
    final words = body.split(' ');
    // Cortesia final ("obrigado", "valeu") vira frase própria, desde que haja um relato antes.
    for (var i = 4; i < words.length; i++) {
      if (_courtesy.contains(normalizeTag(words[i].replaceAll(RegExp(r'[,;:.!?]'), '')))) {
        final head = words.sublist(0, i).join(' ').replaceAll(RegExp(r'[,;:]+$'), '').trim();
        return [..._breakRunOn(head), words.sublist(i).join(' ').replaceAll(RegExp(r'^[,;:]+'), '').trim()];
      }
    }
    if (words.length <= 18) return [body];
    final pieces = <List<String>>[[]];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      final key = normalizeTag(w.replaceAll(RegExp(r'[,;:]'), ''));
      if (pieces.last.length >= 8 && words.length - i >= 4 && _runOnMarkers.contains(key)) {
        pieces.add([]);
      }
      pieces.last.add(w);
    }
    return [for (final p in pieces) p.join(' ').replaceAll(RegExp(r'[,;:]+$'), '').trim()];
  }

  static String _commas(String piece) => piece.replaceAllMapped(_commaBefore, (m) {
        final before = piece.substring(0, m.start).trimRight();
        if (before.isEmpty || before.split(' ').length < 2 || RegExp(r'[,;:]$').hasMatch(before)) return m.group(0)!;
        return ', ${m.group(0)!.trim()}';
      });

  static bool _isQuestion(String piece) {
    final n = normalizeTag(piece);
    if (n.isEmpty || n.split(' ').length > 16) return false;
    if (n.endsWith(' ne') || n.endsWith(' certo') || n.endsWith(' tudo bem') || n.endsWith(' ta bom')) return true;
    for (final s in _questionStarters) {
      if (n == s || n.startsWith('$s ')) return true;
    }
    return false;
  }

  static String _capitalize(String s) {
    final runes = s.runes.toList();
    for (var i = 0; i < runes.length; i++) {
      final ch = String.fromCharCode(runes[i]);
      if (ch.toLowerCase() != ch.toUpperCase()) {
        return String.fromCharCodes(runes.sublist(0, i)) + ch.toUpperCase() + String.fromCharCodes(runes.sublist(i + 1));
      }
    }
    return s;
  }
}

class _Sentence {
  const _Sentence(this.body, this.mark);
  final String body;
  final String? mark;
}

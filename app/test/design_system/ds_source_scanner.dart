// Scanner compartilhado pelos testes do Design System (linter de design + cobertura de glifos).
//
// ESPELHO de scripts/ui_audit_metrics.mjs: o tokenizador (comentarios/strings) e as regexes
// DEVEM permanecer identicos aos do script Node. Mude os dois juntos.
//
// Escopo: app/lib/**/*.dart exceto features/founder/**, main_founder.dart e
// core/ui/design_system/**. core/ui/** e isento das metricas marcadas `exemptCoreUi`.
import 'dart:io';

class ScanResult {
  ScanResult(this.code, this.strings);

  /// Fonte sem comentarios, com cada literal de string trocado por "".
  final String code;

  /// Conteudo de cada literal (escapes \uXXXX decodificados).
  final List<String> strings;
}

class Metric {
  const Metric(this.key, this.regex, {this.inStrings = false, this.exemptCoreUi = false});
  final String key;
  final RegExp regex;
  final bool inStrings;
  final bool exemptCoreUi;
}

// Ordem fixa = ordem do baseline. Regexes IDENTICAS as de scripts/ui_audit_metrics.mjs.
final List<Metric> metrics = <Metric>[
  Metric('fontSize', RegExp(r'\bfontSize\s*:\s*-?\.?\d')),
  Metric('colorLiteral', RegExp(r'\bColor\(\s*0x'), exemptCoreUi: true),
  Metric('fittedBox', RegExp(r'\bFittedBox\b'), exemptCoreUi: true),
  Metric('materialPageRoute', RegExp(r'\bMaterialPageRoute\b'), exemptCoreUi: true),
  Metric('showModalBottomSheet', RegExp(r'\bshowModalBottomSheet\b'), exemptCoreUi: true),
  Metric('showDialog', RegExp(r'\bshowDialog\b'), exemptCoreUi: true),
  Metric('circularProgress', RegExp(r'\bCircularProgressIndicator\b'), exemptCoreUi: true),
  Metric('ellipsis', RegExp(r'\bTextOverflow\.ellipsis\b')),
  Metric('unembeddedWeight', RegExp(r'\bFontWeight\.w(?:[1-3]00|900)\b')),
  Metric(
    'glyphInText',
    RegExp(
      r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{2193}\u{2B00}-\u{2BFF}\u{231A}\u{231B}\u{23E9}-\u{23FF}]',
      unicode: true,
    ),
    inStrings: true,
  ),
];

bool isExcluded(String rel) =>
    rel.startsWith('features/founder/') ||
    rel == 'main_founder.dart' ||
    rel.startsWith('core/ui/design_system/');

bool isCoreUi(String rel) => rel.startsWith('core/ui/');

final RegExp _identChar = RegExp(r'[A-Za-z0-9_$]');
final RegExp _hex4 = RegExp(r'^[0-9a-fA-F]{4}$');
final RegExp _hex2 = RegExp(r'^[0-9a-fA-F]{2}$');

ScanResult scanDart(String src) {
  final n = src.length;
  var i = 0;
  final strings = <String>[];

  String? at(int k) => k >= 0 && k < n ? src[k] : null;
  bool isIdent(String? c) => c != null && _identChar.hasMatch(c);

  void readEscape(StringBuffer out) {
    final c = at(i + 1);
    if (c == 'u') {
      if (at(i + 2) == '{') {
        final end = src.indexOf('}', i + 3);
        if (end > 0) {
          final cp = int.tryParse(src.substring(i + 3, end), radix: 16);
          if (cp != null && cp <= 0x10ffff) out.write(String.fromCharCode(cp));
          i = end + 1;
          return;
        }
      } else {
        final hex = src.substring(i + 2, i + 6 > n ? n : i + 6);
        if (_hex4.hasMatch(hex)) {
          out.write(String.fromCharCode(int.parse(hex, radix: 16)));
          i += 6;
          return;
        }
      }
    } else if (c == 'x') {
      final hex = src.substring(i + 2, i + 4 > n ? n : i + 4);
      if (_hex2.hasMatch(hex)) {
        out.write(String.fromCharCode(int.parse(hex, radix: 16)));
        i += 4;
        return;
      }
    } else if (c == 'n' || c == 't' || c == 'r') {
      out.write(' ');
      i += 2;
      return;
    }
    if (c != null) out.write(c);
    i += 2;
  }

  late String Function(bool) scanCode;

  void scanString(bool raw) {
    final q = src[i];
    final triple = at(i + 1) == q && at(i + 2) == q;
    i += triple ? 3 : 1;
    final out = StringBuffer();
    while (i < n) {
      final c = src[i];
      if (triple) {
        if (c == q && at(i + 1) == q && at(i + 2) == q) {
          i += 3;
          break;
        }
      } else if (c == q) {
        i += 1;
        break;
      } else if (c == '\n') {
        break;
      }
      if (!raw && c == r'\') {
        readEscape(out);
        continue;
      }
      if (!raw && c == r'$' && at(i + 1) == '{') {
        i += 2;
        scanCode(true);
        continue;
      }
      out.write(c);
      i += 1;
    }
    strings.add(out.toString());
  }

  scanCode = (bool interp) {
    final codeOut = <String>[];
    var depth = 0;
    while (i < n) {
      final c = src[i];
      final d = at(i + 1);
      if (c == '/' && d == '/') {
        while (i < n && src[i] != '\n') {
          i += 1;
        }
        continue;
      }
      if (c == '/' && d == '*') {
        var level = 1;
        i += 2;
        while (i < n && level > 0) {
          if (src[i] == '/' && at(i + 1) == '*') {
            level += 1;
            i += 2;
          } else if (src[i] == '*' && at(i + 1) == '/') {
            level -= 1;
            i += 2;
          } else {
            if (src[i] == '\n') codeOut.add('\n');
            i += 1;
          }
        }
        continue;
      }
      if (c == '"' || c == "'") {
        final raw = at(i - 1) == 'r' && !isIdent(at(i - 2));
        if (raw && codeOut.isNotEmpty) codeOut.removeLast();
        scanString(raw);
        codeOut.add('""');
        continue;
      }
      if (interp) {
        if (c == '{') {
          depth += 1;
        } else if (c == '}') {
          if (depth == 0) {
            i += 1;
            return codeOut.join();
          }
          depth -= 1;
        }
      }
      codeOut.add(c);
      i += 1;
    }
    return codeOut.join();
  };

  final code = scanCode(false);
  return ScanResult(code, strings);
}

/// Contagens nao nulas por metrica para um arquivo (`rel` relativo a lib/).
Map<String, int> countMetrics(String rel, String src) {
  final r = scanDart(src);
  final joined = r.strings.join('\n');
  final counts = <String, int>{};
  for (final m in metrics) {
    if (m.exemptCoreUi && isCoreUi(rel)) continue;
    final c = m.regex.allMatches(m.inStrings ? joined : r.code).length;
    if (c > 0) counts[m.key] = c;
  }
  return counts;
}

/// Todos os .dart de `libDir` (relativos, com `/`), ja filtrados por [isExcluded].
Map<String, File> libFiles(Directory libDir) {
  final out = <String, File>{};
  final base = libDir.absolute.path.replaceAll(r'\', '/');
  for (final e in libDir.listSync(recursive: true, followLinks: false)) {
    if (e is! File || !e.path.endsWith('.dart')) continue;
    var rel = e.absolute.path.replaceAll(r'\', '/');
    rel = rel.substring(base.length + 1);
    if (isExcluded(rel)) continue;
    out[rel] = e;
  }
  return out;
}

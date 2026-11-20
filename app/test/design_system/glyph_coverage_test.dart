// Cobertura de glifos e pesos (spec v2.28.0 §2.1 / §6.3).
//
// Extrai TODAS as strings literais do app (fora de features/founder, main_founder.dart e
// core/ui/design_system) e garante que cada codepoint existe no cmap (format 4/12) dos TTFs
// embarcados em assets/fonts, exceto os explicitamente permitidos em [_allowedMissing]/emoji.
// Tambem confere que os pesos usados (FontWeight.wNNN) possuem arquivo embarcado.
//
// Se falhar por codepoint novo: rode scripts/gen_font_subset.mjs (ver cabecalho do script).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'ds_source_scanner.dart';

/// Codepoints que NAO precisam estar nos subsets, com o motivo.
const Map<int, String> _allowedMissing = <int, String>{
  0x23F1: '⏱ cronometro: emoji/simbolo do sistema (sera trocado por Icon)',
  0x26A1: '⚡ raio: emoji do sistema (sera trocado por Icon)',
  0x2714: '✔ check pesado: emoji do sistema (sera trocado por Icon)',
  0x2794: '➔ seta: simbolo do sistema (sera trocado por Icon)',
  0x2B50: '⭐ estrela: emoji do sistema (sera trocado por Icon)',
  0xE000: 'U+E000 uso privado: sentinela interna em smart_transcript_formatter (nunca renderizado)',
  0xFE0F: 'seletor de variacao de emoji',
  0x200D: 'ZWJ (sequencias de emoji)',
};

bool _isEmoji(int cp) => cp >= 0x1F000; // emoji coloridos: sempre fallback do sistema

/// Texto "de corpo": letras/pontuacao que precisam existir em Inter E Plus Jakarta Sans.
bool _isBodyText(int cp) =>
    cp < 0x2000 || (cp >= 0x2010 && cp <= 0x205E) || cp == 0x20AC || cp == 0x2122;

const Map<String, Set<int>> _expectedWeights = <String, Set<int>>{
  'Inter': <int>{400, 500, 600, 700},
  'PlusJakartaSans': <int>{600, 700, 800},
};

/// Pesos sem arquivo em nenhuma familia; uso legado e contido pelo ratchet
/// (metrica `unembeddedWeight` do design_system_baseline.json).
const Set<int> _legacyUnembedded = <int>{100, 200, 300, 900};

class _EmbeddedFont {
  _EmbeddedFont(this.family, this.asset, this.weight);
  final String family;
  final String asset;
  final int weight;
}

List<_EmbeddedFont> _pubspecFonts() {
  final out = <_EmbeddedFont>[];
  String? family;
  String? asset;
  var inFonts = false;
  for (final raw in File('pubspec.yaml').readAsLinesSync()) {
    final line = raw.replaceAll('\r', '');
    if (RegExp(r'^  fonts:\s*$').hasMatch(line)) {
      inFonts = true;
      continue;
    }
    if (inFonts && RegExp(r'^\S').hasMatch(line) && !line.startsWith('#')) break; // saiu de flutter:
    if (!inFonts) continue;
    final fam = RegExp(r'^\s*-\s*family:\s*(\S+)').firstMatch(line);
    if (fam != null) {
      family = fam.group(1);
      continue;
    }
    final a = RegExp(r'^\s*-\s*asset:\s*(\S+)').firstMatch(line);
    if (a != null) {
      asset = a.group(1);
      continue;
    }
    final w = RegExp(r'^\s*weight:\s*(\d+)').firstMatch(line);
    if (w != null && family != null && asset != null) {
      out.add(_EmbeddedFont(family, asset, int.parse(w.group(1)!)));
      asset = null;
    }
  }
  return out;
}

/// Conjunto de codepoints mapeados no cmap (formatos 4 e 12) de um TTF.
Set<int> readCmap(Uint8List bytes) {
  final dv = ByteData.sublistView(bytes);
  final numTables = dv.getUint16(4);
  var cmapOff = -1;
  for (var i = 0; i < numTables; i++) {
    final o = 12 + i * 16;
    final tag = String.fromCharCodes(bytes.sublist(o, o + 4));
    if (tag == 'cmap') cmapOff = dv.getUint32(o + 8);
  }
  if (cmapOff < 0) throw StateError('TTF sem tabela cmap');
  final out = <int>{};
  final nSub = dv.getUint16(cmapOff + 2);
  for (var s = 0; s < nSub; s++) {
    final so = cmapOff + dv.getUint32(cmapOff + 4 + s * 8 + 4);
    final fmt = dv.getUint16(so);
    if (fmt == 4) {
      final segX2 = dv.getUint16(so + 6);
      final seg = segX2 ~/ 2;
      final endO = so + 14;
      final startO = endO + segX2 + 2;
      final deltaO = startO + segX2;
      final rangeO = deltaO + segX2;
      for (var k = 0; k < seg; k++) {
        final end = dv.getUint16(endO + k * 2);
        final start = dv.getUint16(startO + k * 2);
        final delta = dv.getInt16(deltaO + k * 2);
        final ro = dv.getUint16(rangeO + k * 2);
        for (var c = start; c <= end && c != 0xFFFF; c++) {
          int g;
          if (ro == 0) {
            g = (c + delta) & 0xFFFF;
          } else {
            final gi = rangeO + k * 2 + ro + (c - start) * 2;
            g = dv.getUint16(gi);
            if (g != 0) g = (g + delta) & 0xFFFF;
          }
          if (g != 0) out.add(c);
        }
      }
    } else if (fmt == 12) {
      final nGroups = dv.getUint32(so + 12);
      for (var k = 0; k < nGroups; k++) {
        final o = so + 16 + k * 12;
        final a = dv.getUint32(o);
        final b = dv.getUint32(o + 4);
        final g0 = dv.getUint32(o + 8);
        for (var c = a; c <= b; c++) {
          if (g0 + (c - a) != 0) out.add(c);
        }
      }
    }
  }
  return out;
}

String _fmt(int cp) =>
    'U+${cp.toRadixString(16).toUpperCase().padLeft(4, '0')} ${String.fromCharCode(cp)}';

void main() {
  final fonts = _pubspecFonts();
  final cmaps = <String, Set<int>>{}; // asset -> cmap
  for (final f in fonts) {
    cmaps[f.asset] = readCmap(Uint8List.fromList(File(f.asset).readAsBytesSync()));
  }
  final byFamily = <String, List<_EmbeddedFont>>{};
  for (final f in fonts) {
    byFamily.putIfAbsent(f.family, () => <_EmbeddedFont>[]).add(f);
  }

  test('leitor de cmap: ASCII/acentos presentes, emoji ausente', () {
    for (final f in fonts) {
      final cm = cmaps[f.asset]!;
      for (final c in 'AaZz09 áéíóúãõçÀÇ'.runes) {
        expect(cm.contains(c), isTrue, reason: '${f.asset} sem ${_fmt(c)}');
      }
      expect(cm.contains(0x1F512), isFalse, reason: '${f.asset} nao deveria ter 🔒');
    }
  });

  test('pubspec embarca as familias e pesos da politica v2.28.0 (sem sintese de negrito)', () {
    for (final entry in _expectedWeights.entries) {
      final have = (byFamily[entry.key] ?? <_EmbeddedFont>[]).map((f) => f.weight).toSet();
      expect(have.containsAll(entry.value), isTrue,
          reason: '${entry.key}: pesos embarcados $have, esperado ⊇ ${entry.value}');
    }
    for (final f in fonts) {
      expect(File(f.asset).existsSync(), isTrue, reason: '${f.asset} declarado no pubspec nao existe');
    }
  });

  test('licencas OFL das fontes embarcadas presentes', () {
    expect(File('assets/licenses/OFL_Inter.txt').existsSync(), isTrue);
    expect(File('assets/licenses/OFL_PlusJakartaSans.txt').existsSync(), isTrue);
  });

  test('peso total das fontes <= 640 KB (427 KB da v2.27.0 + ~200 KB)', () {
    final total = fonts.map((f) => File(f.asset).lengthSync()).fold<int>(0, (a, b) => a + b);
    expect(total, lessThanOrEqualTo(640 * 1024), reason: 'fontes somam $total B');
  });

  test('todo codepoint das strings do app existe nos TTFs embarcados (ou esta na allowlist)', () {
    final used = <int, String>{}; // codepoint -> primeiro arquivo
    libFiles(Directory('lib')).forEach((rel, file) {
      for (final s in scanDart(file.readAsStringSync()).strings) {
        for (final cp in s.runes) {
          if (cp < 0x20) continue; // controle
          used.putIfAbsent(cp, () => rel);
        }
      }
    });
    expect(used.length, greaterThan(50), reason: 'extracao de strings falhou?');

    final problems = <String>[];
    used.forEach((cp, rel) {
      if (_isEmoji(cp) || _allowedMissing.containsKey(cp)) return;
      final needAll = _isBodyText(cp);
      for (final entry in byFamily.entries) {
        if (!needAll && entry.key != 'Inter') continue; // simbolos: so Inter (corpo/UI)
        for (final f in entry.value) {
          if (!cmaps[f.asset]!.contains(cp)) {
            problems.add('  - ${_fmt(cp)} ausente em ${f.asset} (primeiro uso: lib/$rel)');
          }
        }
      }
    });
    expect(problems, isEmpty,
        reason: 'Codepoints sem glifo (virariam tofu/fallback inconsistente).\n'
            '${problems.join('\n')}\n'
            'Regere os subsets: veja o cabecalho de scripts/gen_font_subset.mjs '
            '(ou adicione a [_allowedMissing] com justificativa).');
  });

  test('pesos FontWeight.wNNN usados possuem arquivo embarcado (legado contido pelo ratchet)', () {
    final embedded = fonts.map((f) => f.weight).toSet();
    final re = RegExp(r'\bFontWeight\.w(\d00)\b');
    final bad = <String>[];
    libFiles(Directory('lib')).forEach((rel, file) {
      final code = scanDart(file.readAsStringSync()).code;
      final seen = <int>{};
      for (final m in re.allMatches(code)) {
        final w = int.parse(m.group(1)!);
        if (embedded.contains(w) || _legacyUnembedded.contains(w)) continue;
        if (seen.add(w)) bad.add('  - lib/$rel usa w$w sem arquivo embarcado');
      }
    });
    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}

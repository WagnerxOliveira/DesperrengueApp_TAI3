import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// UtilitÃ¡rios de cobertura de glifos (v2.28.0): leitura da tabela `cmap` de
/// TTFs (formatos 4 e 12) e extraÃ§Ã£o de literais de string de arquivos Dart.
///
/// Dart puro (sem Flutter): pode ser usado em testes `test()` e em scripts.

/// Conjunto de codepoints que a fonte mapeia para glifo (â‰  .notdef).
Set<int> readCmapCodepoints(Uint8List bytes) {
  final d = ByteData.sublistView(bytes);
  int u16(int o) => d.getUint16(o);
  int u32(int o) => d.getUint32(o);

  final numTables = u16(4);
  int? cmapOffset;
  for (var i = 0; i < numTables; i++) {
    final rec = 12 + i * 16;
    final tag = String.fromCharCodes(bytes.sublist(rec, rec + 4));
    if (tag == 'cmap') cmapOffset = u32(rec + 8);
  }
  if (cmapOffset == null) throw const FormatException('TTF sem tabela cmap');

  final out = <int>{};
  final n = u16(cmapOffset + 2);
  final seen = <int>{};
  for (var i = 0; i < n; i++) {
    final rec = cmapOffset + 4 + i * 8;
    final sub = cmapOffset + u32(rec + 4);
    if (!seen.add(sub)) continue;
    final format = u16(sub);
    if (format == 4) {
      final segX2 = u16(sub + 6);
      final seg = segX2 ~/ 2;
      final endBase = sub + 14;
      final startBase = endBase + segX2 + 2;
      final deltaBase = startBase + segX2;
      final rangeBase = deltaBase + segX2;
      for (var s = 0; s < seg; s++) {
        final end = u16(endBase + s * 2);
        final start = u16(startBase + s * 2);
        final delta = d.getInt16(deltaBase + s * 2);
        final rangeOffset = u16(rangeBase + s * 2);
        if (start == 0xFFFF) continue;
        for (var c = start; c <= end; c++) {
          int glyph;
          if (rangeOffset == 0) {
            glyph = (c + delta) & 0xFFFF;
          } else {
            final addr = rangeBase + s * 2 + rangeOffset + 2 * (c - start);
            if (addr + 2 > bytes.length) continue;
            final g = u16(addr);
            glyph = g == 0 ? 0 : (g + delta) & 0xFFFF;
          }
          if (glyph != 0) out.add(c);
        }
      }
    } else if (format == 12) {
      final groups = u32(sub + 12);
      for (var g = 0; g < groups; g++) {
        final base = sub + 16 + g * 12;
        final start = u32(base);
        final end = u32(base + 4);
        final startGlyph = u32(base + 8);
        for (var c = start; c <= end; c++) {
          if (startGlyph + (c - start) != 0) out.add(c);
        }
      }
    }
  }
  return out;
}

/// Um literal de string encontrado em cÃ³digo Dart.
class DartStringLiteral {
  const DartStringLiteral(this.value, this.line, this.file);

  /// Valor decodificado (escapes resolvidos; interpolaÃ§Ãµes viram vazio, o
  /// conteÃºdo das `${...}` Ã© varrido como cÃ³digo e gera literais prÃ³prios).
  final String value;
  final int line;
  final String file;
}

/// Extrai TODOS os literais de string de [source] (ignora comentÃ¡rios).
List<DartStringLiteral> extractStringLiterals(String source, String file) {
  final out = <DartStringLiteral>[];
  _Scanner(source, file, out).scanCode(untilBrace: false);
  return out;
}

class _Scanner {
  _Scanner(this.s, this.file, this.out);

  final String s;
  final String file;
  final List<DartStringLiteral> out;
  int i = 0;
  int line = 1;

  bool get eof => i >= s.length;

  void _advance([int n = 1]) {
    for (var k = 0; k < n && i < s.length; k++) {
      if (s.codeUnitAt(i) == 0x0A) line++;
      i++;
    }
  }

  /// Varre cÃ³digo; se [untilBrace], para no `}` que fecha a interpolaÃ§Ã£o.
  void scanCode({required bool untilBrace}) {
    var depth = 0;
    while (!eof) {
      final c = s[i];
      final next = i + 1 < s.length ? s[i + 1] : '';
      if (c == '/' && next == '/') {
        while (!eof && s[i] != '\n') {
          i++;
        }
        continue;
      }
      if (c == '/' && next == '*') {
        _advance(2);
        var nest = 1;
        while (!eof && nest > 0) {
          if (s[i] == '/' && i + 1 < s.length && s[i + 1] == '*') {
            nest++;
            _advance(2);
          } else if (s[i] == '*' && i + 1 < s.length && s[i + 1] == '/') {
            nest--;
            _advance(2);
          } else {
            _advance();
          }
        }
        continue;
      }
      if (untilBrace) {
        if (c == '{') {
          depth++;
        } else if (c == '}') {
          if (depth == 0) {
            i++;
            return;
          }
          depth--;
        }
      }
      var raw = false;
      var qi = i;
      if (c == 'r' && (next == '"' || next == "'") && (i == 0 || !_isIdent(s[i - 1]))) {
        raw = true;
        qi = i + 1;
      }
      final q = s[qi];
      if (q == '"' || q == "'") {
        final triple = qi + 2 < s.length && s[qi + 1] == q && s[qi + 2] == q;
        _advance(qi - i + (triple ? 3 : 1));
        _scanString(q, triple, raw);
        continue;
      }
      _advance();
    }
  }

  bool _isIdent(String ch) {
    final u = ch.codeUnitAt(0);
    return (u >= 48 && u <= 57) || (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || u == 95 || u == 36;
  }

  void _scanString(String q, bool triple, bool raw) {
    final buf = StringBuffer();
    final startLine = line;
    while (!eof) {
      final c = s[i];
      if (!triple && c == '\n') break; // string malformada: aborta
      if (c == q) {
        if (!triple) {
          i++;
          break;
        }
        if (i + 2 < s.length && s[i + 1] == q && s[i + 2] == q) {
          i += 3;
          break;
        }
      }
      if (!raw && c == r'\') {
        _escape(buf);
        continue;
      }
      if (!raw && c == r'$') {
        final n = i + 1 < s.length ? s[i + 1] : '';
        if (n == '{') {
          i += 2;
          scanCode(untilBrace: true);
          continue;
        }
        if (_isIdent(n) && n != r'$') {
          i++;
          while (!eof && _isIdent(s[i]) && s[i] != r'$') {
            i++;
          }
          continue;
        }
      }
      // consome um codepoint inteiro (par substituto incluÃ­do)
      final cu = s.codeUnitAt(i);
      if (cu >= 0xD800 && cu <= 0xDBFF && i + 1 < s.length) {
        buf.write(s.substring(i, i + 2));
        i += 2;
      } else {
        buf.write(c);
        _advance();
      }
    }
    out.add(DartStringLiteral(buf.toString(), startLine, file));
  }

  void _escape(StringBuffer buf) {
    // s[i] == '\'
    final n = i + 1 < s.length ? s[i + 1] : '';
    switch (n) {
      case 'n':
        buf.write('\n');
        i += 2;
      case 't':
        buf.write('\t');
        i += 2;
      case 'r':
        buf.write('\r');
        i += 2;
      case 'b':
      case 'f':
      case 'v':
        buf.write(' ');
        i += 2;
      case 'x':
        final hex = s.substring(i + 2, (i + 4).clamp(0, s.length));
        final v = int.tryParse(hex, radix: 16);
        if (v != null) buf.writeCharCode(v);
        i += 4;
      case 'u':
        if (i + 2 < s.length && s[i + 2] == '{') {
          final close = s.indexOf('}', i);
          final v = int.tryParse(s.substring(i + 3, close), radix: 16);
          if (v != null) buf.writeCharCode(v);
          i = close + 1;
        } else {
          final hex = s.substring(i + 2, (i + 6).clamp(0, s.length));
          final v = int.tryParse(hex, radix: 16);
          if (v != null) buf.writeCharCode(v);
          i += 6;
        }
      case '\n':
        line++;
        i += 2;
      default:
        buf.write(n);
        _advance(2);
    }
  }
}

/// Formata um codepoint como `U+2605 'â˜…'`.
String describeCodepoint(int cp) =>
    'U+${cp.toRadixString(16).toUpperCase().padLeft(4, '0')} \'${String.fromCharCode(cp)}\'';

/// Le um arquivo como UTF-8 tolerante (sem lancar em bytes invalidos).
String readSourceFile(File f) => utf8.decode(f.readAsBytesSync(), allowMalformed: true);

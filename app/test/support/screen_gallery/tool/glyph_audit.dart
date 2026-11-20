// Auditoria de glifos/pesos (Dart puro): `dart run test/support/screen_gallery/tool/glyph_audit.dart`
// (a partir de app/). Lista os codepoints usados em literais de string de lib/ (sem
// features/founder) que NAO existem nos TTFs embarcados, e os pesos FontWeight usados.
import 'dart:io';

import '../glyphs.dart';

const _fonts = <String, List<String>>{
  'PlusJakartaSans': ['PlusJakartaSans-Bold.ttf', 'PlusJakartaSans-ExtraBold.ttf'],
  'Inter': ['Inter-Regular.ttf', 'Inter-Medium.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf'],
};

void main(List<String> args) {
  final cover = <String, Set<int>>{
    for (final e in _fonts.entries)
      e.key: {for (final f in e.value) ...readCmapCodepoints(File('assets/fonts/$f').readAsBytesSync())},
  };
  final all = <int>{for (final s in cover.values) ...s};
  stdout.writeln('cmap Inter: ${cover['Inter']!.length} codepoints | Jakarta: ${cover['PlusJakartaSans']!.length}');

  final missing = <int, List<String>>{};
  final weights = <String, int>{};
  var literals = 0;
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
    final path = f.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart') || path.contains('/features/founder/') || path.endsWith('main_founder.dart')) continue;
    final src = readSourceFile(f);
    for (final m in RegExp(r'FontWeight\.(w\d00|bold|normal)').allMatches(src)) {
      weights[m.group(1)!] = (weights[m.group(1)!] ?? 0) + 1;
    }
    for (final lit in extractStringLiterals(src, path)) {
      literals++;
      for (final cp in lit.value.runes) {
        if (cp < 0x20 || (cp >= 0x7F && cp <= 0x9F)) continue;
        if (!all.contains(cp)) {
          (missing[cp] ??= <String>[]).add('${path.substring(path.indexOf('lib/') + 4)}:${lit.line}');
        }
      }
    }
  }
  stdout.writeln('literais de string analisados: $literals');
  stdout.writeln(
    'pesos usados: ${(weights.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).map((e) => '${e.key}=${e.value}').join(' ')}',
  );
  final sorted = missing.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
  stdout.writeln('codepoints FORA das fontes embarcadas: ${sorted.length}');
  for (final e in sorted) {
    stdout.writeln('${describeCodepoint(e.key)}  x${e.value.length}  ex.: ${e.value.take(3).join(', ')}');
  }
}

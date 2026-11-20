import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/screen_gallery/screen_gallery.dart';

/// Cobertura de glifos e pesos (spec §6.3) — varredura ESTÁTICA de `lib/`
/// (fora de `features/founder/**`): todo codepoint de literal de string precisa
/// existir no `cmap` de um TTF embarcado; pesos usados precisam existir.
///
/// Relatório não-bloqueante: baseline em `baseline/glyphs.json` (só diminui).
/// O `foundation` pode ampliar os subsets (`scripts/gen_font_subset.mjs`); este
/// teste lê `assets/fonts` do disco, então passa a refletir isso sozinho.
void main() {
  final ratchet = Ratchet('glyphs');
  tearDownAll(ratchet.finish);

  Iterable<File> libFiles() sync* {
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final p = e.path.replaceAll(r'\', '/');
      if (p.contains('/features/founder/') || p.endsWith('main_founder.dart')) continue;
      yield e;
    }
  }

  test('pubspec: famílias embarcadas existem e arquivos estão em assets/fonts', () {
    final fams = embeddedFontFiles();
    expect(fams.keys, containsAll(kAllowedFontFamilies), reason: 'pubspec precisa embarcar PlusJakartaSans e Inter');
    for (final fam in fams.entries) {
      for (final file in fam.value.values) {
        expect(File('assets/fonts/$file').existsSync(), isTrue, reason: 'arquivo ausente: assets/fonts/$file');
      }
    }
  });
  test('glifos: todo codepoint de literal de string existe nas fontes embarcadas', () {
    final cover = embeddedCodepoints();
    final byCodepoint = <int, List<String>>{};
    for (final f in libFiles()) {
      final path = f.path.replaceAll(r'\', '/');
      final shown = path.substring(path.indexOf('lib/') + 4);
      for (final lit in extractStringLiterals(readSourceFile(f), shown)) {
        for (final cp in lit.value.runes) {
          if (cp < 0x20 || (cp >= 0x7F && cp <= 0x9F)) continue;
          if (!cover.contains(cp)) (byCodepoint[cp] ??= <String>[]).add('$shown:${lit.line}');
        }
      }
    }
    final log = ViolationLog();
    const v = GalleryVariant(viewport: vp360);
    var total = 0;
    for (final e in byCodepoint.entries) {
      total += e.value.length;
      // 1 violação por OCORRÊNCIA (o ratchet cai a cada uso removido).
      for (var i = 0; i < e.value.length; i++) {
        log.add(GalleryRules.glyphs, '${describeCodepoint(e.key)} em ${e.value[i]}', v, where: e.value[i]);
      }
    }
    // ignore: avoid_print
    print(
      'GALERIA glifos: ${byCodepoint.length} codepoints fora das fontes ($total ocorrências): '
      '${byCodepoint.keys.map(describeCodepoint).join(' ')}',
    );
    ratchet.verify('static/string_literals', log, const <String>[GalleryRules.glyphs]);
  });

  test('pesos: FontWeight inexistente nas fontes embarcadas (w100–w300, w900) e w800 (só Jakarta)', () {
    final missing = ViolationLog();
    final w800 = ViolationLog();
    const v = GalleryVariant(viewport: vp360);
    for (final f in libFiles()) {
      final path = f.path.replaceAll(r'\', '/');
      final shown = path.substring(path.indexOf('lib/') + 4);
      final src = readSourceFile(f);
      final lines = src.split('\n');
      for (var i = 0; i < lines.length; i++) {
        for (final m in RegExp(r'FontWeight\.(w100|w200|w300|w900)').allMatches(lines[i])) {
          missing.add(GalleryRules.weight, '${m.group(1)} em $shown:${i + 1}', v, where: '$shown:${i + 1}');
        }
        if (lines[i].contains('FontWeight.w800')) {
          w800.add(GalleryRules.weight, 'w800 em $shown:${i + 1}', v, where: '$shown:${i + 1}');
        }
      }
    }
    // ignore: avoid_print
    print('GALERIA pesos: inexistentes (w100–w300/w900)=${missing.all.length} · w800 (só Jakarta)=${w800.all.length}');
    ratchet.verify('static/font_weight_missing', missing, const <String>[GalleryRules.weight]);
    ratchet.verify('static/font_weight_w800', w800, const <String>[GalleryRules.weight]);
  });
}

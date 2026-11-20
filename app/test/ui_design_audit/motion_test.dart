import 'dart:io';

import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen_gallery/screen_gallery.dart';
import '../ui_gallery/gallery_registry.dart';

/// Movimento (spec §3 / §6.5): orçamento de duração (tap ≤ 120 ms, página ≤ 220 ms),
/// `disableAnimations` ⇒ estado final imediato, nenhum `repeat()` fora de
/// carregamento/pulso único e zero timers pendentes (o `flutter_test` falha
/// sozinho se uma tela deixar `Timer` vivo depois de desmontada).
///
/// Baseline em `baseline/motion.json` (só diminui).
void main() {
  final ratchet = Ratchet('motion');
  const v = GalleryVariant(viewport: vp390);

  setUpAll(GalleryEnv.init);
  setUp(GalleryEnv.resetSingletons);
  tearDownAll(ratchet.finish);

  // ------------------------------------------------------------ estático
  test('estático: `.repeat(` só em carregamento/pulso (lista versionada; não pode subir)', () {
    final log = ViolationLog();
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final p = e.path.replaceAll(r'\', '/');
      if (p.contains('/features/founder/') || p.endsWith('main_founder.dart')) continue;
      final lines = readSourceFile(e).split('\n');
      final shown = p.substring(p.indexOf('lib/') + 4);
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('.repeat(') && !lines[i].trimLeft().startsWith('//')) {
          log.add(GalleryRules.motion, 'repeat() infinito em $shown:${i + 1}', v, where: '$shown:${i + 1}');
        }
      }
    }
    // ignore: avoid_print
    print('GALERIA movimento: ${log.all.length} `.repeat(` em lib/ (esperado: só skeleton/pulso único)');
    ratchet.verify('static/repeat', log, const <String>[GalleryRules.motion]);
  });

  // ------------------------------------------------------------ transições
  for (final platform in <TargetPlatform>[TargetPlatform.android, TargetPlatform.windows, TargetPlatform.linux]) {
    testWidgets('transição de página ≤ 220 ms · ${platform.name}', (tester) async {
      final log = ViolationLog();
      await loadGalleryFonts();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.resolve(null, Brightness.light).copyWith(platform: platform),
          home: const Scaffold(body: Center(child: Text('origem'))),
        ),
      );
      final r = await measurePageTransition(tester, find.byType(Scaffold));
      // ignore: avoid_print
      print('GALERIA transição ${platform.name}: ida=${r.push.inMilliseconds} ms volta=${r.pop.inMilliseconds} ms');
      if (r.push.inMilliseconds > 220) {
        log.add(GalleryRules.motion, 'push de página ${r.push.inMilliseconds} ms > 220 ms (${platform.name})', v);
      }
      if (r.pop.inMilliseconds > 220) {
        log.add(GalleryRules.motion, 'pop de página ${r.pop.inMilliseconds} ms > 220 ms (${platform.name})', v);
      }
      ratchet.verify('global/page_transition_${platform.name}', log, const <String>[GalleryRules.motion]);
    });
  }

  // ------------------------------------------------------------ toque
  testWidgets('feedback de toque do PrimaryButton: escala assenta em ≤ 120 ms', (tester) async {
    final log = ViolationLog();
    await loadGalleryFonts();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.resolve(null, Brightness.light),
        home: Scaffold(
          body: Center(
            child: PrimaryButton(label: 'Continuar', onPressed: () {}),
          ),
        ),
      ),
    );
    final r = await measurePressScale(tester, find.byType(PrimaryButton));
    // ignore: avoid_print
    print('GALERIA toque PrimaryButton: $r');
    if (!r.hasScaleFeedback) {
      log.add(GalleryRules.motion, 'PrimaryButton sem feedback de escala ao toque (esperado ~0,97)', v);
    } else {
      if (!r.pressSettledIn120) log.add(GalleryRules.motion, 'escala de toque não assenta em 120 ms ($r)', v);
      if (!r.releaseSettledIn120) log.add(GalleryRules.motion, 'retorno da escala não assenta em 120 ms ($r)', v);
    }
    ratchet.verify('global/press_scale_primary_button', log, const <String>[GalleryRules.motion]);
  });

  // ------------------------------------------------- disableAnimations
  for (final screen in galleryScreens()) {
    if (screen.animatesForever || screen.skipRules.contains(GalleryRules.motion)) continue;
    testWidgets('disableAnimations · estado final imediato · ${screen.id}', (tester) async {
      final log = ViolationLog();
      for (final mode in screen.modes) {
        for (final variant in GalleryMatrix.reducedMotion(mode)) {
          await withGalleryRun(tester, screen, variant, settle: false, (run) async {
            // 1º quadro já foi bombeado; mede quanto falta para parar de pedir quadros.
            final d = await measureSettle(tester, () async {}, max: const Duration(seconds: 3));
            if (d.inMilliseconds > 100) {
              log.add(
                GalleryRules.motion,
                'com disableAnimations ainda anima por ${d.inMilliseconds} ms (esperado ≤ 100 ms)',
                variant,
              );
            }
          });
        }
      }
      ratchet.verify(screen.id, log, const <String>[GalleryRules.motion]);
    });
  }
}

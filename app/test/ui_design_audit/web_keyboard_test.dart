import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen_gallery/screen_gallery.dart';
import '../ui_gallery/gallery_registry.dart';

/// Teclado e foco na Web (spec §2.6 / §6.9) via `sendKeyEvent`, em 1280×800:
///  * telas com controles ativáveis precisam ser alcançáveis por `Tab`
///    (o foco primário muda ao menos uma vez);
///  * `Esc` fecha sheets/diálogos.
///
/// Relatório não-bloqueante: baseline em `baseline/keyboard.json` (só diminui);
/// passa a ser exigido por onda depois do `web_a11y`.
void main() {
  final ratchet = Ratchet('keyboard');
  setUpAll(GalleryEnv.init);
  setUp(GalleryEnv.resetSingletons);
  tearDownAll(ratchet.finish);

  for (final screen in galleryScreens()) {
    if (screen.animatesForever || screen.skipRules.contains(GalleryRules.keyboard)) continue;
    testWidgets('teclado/foco · ${screen.id}', (tester) async {
      final log = ViolationLog();
      final variant = GalleryVariant(viewport: vp1280, mode: screen.modes.first);
      await withGalleryRun(tester, screen, variant, (run) async {
        final interactive = collectTapTargets(tester).where((t) => t.enabled && !t.isTextField).length;
        final seen = <FocusNode?>{FocusManager.instance.primaryFocus};
        for (var i = 0; i < 12; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump(const Duration(milliseconds: 16));
          seen.add(FocusManager.instance.primaryFocus);
        }
        if (interactive > 0 && seen.length < 2) {
          log.add(GalleryRules.keyboard, 'Tab não move o foco ($interactive controles ativáveis na tela)', variant);
        }
        if (screen.kind == GalleryKind.sheet) {
          final before = find.byType(BottomSheet).evaluate().length;
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          if (before > 0 && find.byType(BottomSheet).evaluate().isNotEmpty) {
            log.add(GalleryRules.keyboard, 'Esc não fecha o sheet', variant);
          }
        }
      });
      ratchet.verify(screen.id, log, const <String>[GalleryRules.keyboard]);
    });
  }
}

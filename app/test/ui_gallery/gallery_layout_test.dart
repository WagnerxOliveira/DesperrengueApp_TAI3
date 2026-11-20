import 'package:flutter_test/flutter_test.dart';

import '../support/screen_gallery/screen_gallery.dart';
import '../support/screen_gallery/ratchet.dart';
import 'gallery_registry.dart';

/// Layout: zero `RenderFlex overflow`, zero erro de render e nenhum texto
/// cortado lateralmente, em viewports/escalas extremos (claro e escuro).
/// Matriz padrão enxuta; `GALLERY_FULL=1` roda a matriz ampliada (11 combinações).
void main() {
  final ratchet = Ratchet('layout');

  setUpAll(GalleryEnv.init);
  setUp(GalleryEnv.resetSingletons);
  tearDownAll(ratchet.finish);

  for (final screen in galleryScreens()) {
    testWidgets('layout · ${screen.id}', (tester) async {
      final log = ViolationLog();
      for (final mode in screen.modes) {
        for (final variant in galleryLayoutVariants(mode)) {
          await withGalleryRun(tester, screen, variant, (run) async {
            checkLayout(run, log);
          });
        }
      }
      ratchet.verify(screen.id, log, GalleryRules.layoutRules);
    });
  }
}

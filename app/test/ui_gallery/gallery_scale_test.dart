import 'package:flutter_test/flutter_test.dart';

import '../support/screen_gallery/screen_gallery.dart';
import 'gallery_registry.dart';

/// Escala de fonte: o texto renderizado NUNCA fica menor com a escala maior
/// (1.0 → 1.35 → 1.5), contando o encolhimento por `FittedBox`/`Transform`
/// (`TextProbe.effectiveSize`), e o conteúdo continua sem overflow ao reflowar.
void main() {
  final ratchet = Ratchet('scale');
  setUpAll(GalleryEnv.init);
  setUp(GalleryEnv.resetSingletons);
  tearDownAll(ratchet.finish);

  for (final screen in galleryScreens()) {
    if (screen.skipRules.contains(GalleryRules.scaleMonotonic)) continue;
    testWidgets('escala · ${screen.id}', (tester) async {
      final log = ViolationLog();
      for (final mode in screen.modes) {
        Map<String, double>? previous;
        for (final variant in GalleryMatrix.scales(mode)) {
          final sizes = await withGalleryRun(tester, screen, variant, (run) async {
            return renderedSizes(run);
          });
          if (previous != null) checkScaleMonotonic(previous, sizes, variant, log);
          previous = sizes;
        }
      }
      ratchet.verify(screen.id, log, const <String>[GalleryRules.scaleMonotonic]);
    });
  }
}

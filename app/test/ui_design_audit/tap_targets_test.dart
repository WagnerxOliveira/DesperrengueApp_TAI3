import '../support/screen_gallery/screen_gallery.dart';
import '../ui_gallery/gallery_registry.dart';

/// Alvos de toque ≥ 48×48 dp (spec §2.2/§6.2) medidos na árvore de semântica,
/// no celular (360) e na Web (1280). Baseline em `baseline/tap_targets.json`.
void main() {
  defineGallerySuite(
    suite: 'tap_targets',
    label: 'alvos de toque',
    screens: galleryScreens(),
    variants: GalleryMatrix.typography,
    rules: const <String>[GalleryRules.tapTarget],
    check: (run, log) => checkTapTargets(run, log),
  );
}

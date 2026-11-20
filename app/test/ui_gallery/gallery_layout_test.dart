import '../support/screen_gallery/screen_gallery.dart';
import 'gallery_registry.dart';

/// Layout: zero `RenderFlex overflow`, zero erro de render e nenhum texto
/// cortado lateralmente, em viewports/escalas extremos (claro e escuro).
/// Matriz padrão enxuta; `GALLERY_FULL=1` roda a matriz ampliada (11 combinações).
void main() {
  defineGallerySuite(
    suite: 'layout',
    label: 'layout',
    screens: galleryScreens(),
    variants: galleryLayoutVariants,
    rules: GalleryRules.layoutRules,
    check: (run, log) => checkLayout(run, log),
  );
}

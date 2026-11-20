import '../support/screen_gallery/screen_gallery.dart';
import '../ui_gallery/gallery_registry.dart';

/// Tipografia por tela (spec §6.2): nenhum `Text` < 12,5 sp (FittedBox que
/// encolhe conta), corpo ≥ 14 sp, famílias ∈ {PlusJakartaSans, Inter}, pesos
/// existentes nas fontes embarcadas, números com `tabularFigures`, zero
/// emoji/`★✓🔒` em `Text` e todo glifo presente nas fontes embarcadas.
///
/// Não-bloqueante por onda: o baseline em `baseline/typography.json` só diminui.
void main() {
  defineGallerySuite(
    suite: 'typography',
    label: 'tipografia',
    screens: galleryScreens(),
    variants: GalleryMatrix.typography,
    rules: const <String>[
      GalleryRules.minFont,
      GalleryRules.bodyFont,
      GalleryRules.family,
      GalleryRules.weight,
      GalleryRules.tabular,
      GalleryRules.symbols,
      GalleryRules.glyphs,
    ],
    check: (run, log) => checkTypography(run, log),
  );
}

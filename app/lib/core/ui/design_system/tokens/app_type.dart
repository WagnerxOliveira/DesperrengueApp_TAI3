import 'package:flutter/painting.dart';

/// Famílias de fonte EMBARCADAS (nada é buscado em runtime; licença OFL em
/// `assets/licenses/`).
///
/// * **Plus Jakarta Sans** (700/800): títulos, botões e números de destaque.
/// * **Inter** (400–700): corpo e UI.
abstract final class AppFonts {
  static const String jakarta = 'PlusJakartaSans';
  static const String inter = 'Inter';

  /// Fallback explícito de glifo (símbolos fora dos subsets, emoji do sistema).
  static const List<String> fallback = <String>[
    inter,
    'Roboto',
    'Noto Sans',
    'Noto Sans Symbols',
    'Noto Sans Symbols 2',
    'Segoe UI Symbol',
    'Apple Symbols',
    'Apple Color Emoji',
    'Noto Color Emoji',
  ];
}

/// Escala tipográfica global (sp / entrelinha / peso) — §2.1 da spec v2.28.0.
///
/// Regras:
/// * mínimo absoluto [minimumFontSize] (12,5 sp); corpo >= 14 sp;
/// * o tamanho NUNCA encolhe por modo compacto (reflow/rolagem no lugar);
/// * números sempre `tabularFigures` (`figure*` já vêm assim; para texto
///   corrido numérico use [tabular]);
/// * os estilos NÃO trazem cor: herdam do tema (`DefaultTextStyle`) ou use
///   `.copyWith(color: context.tk.textMuted)`.
abstract final class AppType {
  static const double minimumFontSize = 12.5;

  static const List<FontFeature> _tabular = <FontFeature>[FontFeature.tabularFigures()];

  /// Aplica algarismos tabulares a qualquer estilo numérico.
  static TextStyle tabular(TextStyle base) => base.copyWith(fontFeatures: _tabular);

  /// 32/38 · Jakarta 800.
  static const TextStyle displayL = TextStyle(
    fontFamily: AppFonts.jakarta,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
  );

  /// 28/34 · Jakarta 800.
  static const TextStyle display = TextStyle(
    fontFamily: AppFonts.jakarta,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  /// 22/28 · Jakarta 700.
  static const TextStyle headline = TextStyle(
    fontFamily: AppFonts.jakarta,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  /// 18/24 · Jakarta 700 (títulos de seção/AppBar).
  static const TextStyle title = TextStyle(
    fontFamily: AppFonts.jakarta,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  /// 16/22 · Jakarta 700.
  static const TextStyle titleSm = TextStyle(
    fontFamily: AppFonts.jakarta,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
  );

  /// 15/22 · Inter 400.
  static const TextStyle body = TextStyle(
    fontFamily: AppFonts.inter,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
  );

  /// 15/22 · Inter 600.
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: AppFonts.inter,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w600,
  );

  /// 14/20 · Inter 400 (corpo secundário; nunca abaixo de 14).
  static const TextStyle bodySm = TextStyle(
    fontFamily: AppFonts.inter,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  /// 12,5/18 · Inter 500 (legendas/selos — mínimo absoluto).
  static const TextStyle caption = TextStyle(
    fontFamily: AppFonts.inter,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 12.5,
    height: 18 / 12.5,
    fontWeight: FontWeight.w500,
  );

  /// 16/20 · Jakarta 800 (rótulo de botão).
  static const TextStyle button = TextStyle(
    fontFamily: AppFonts.jakarta,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 16,
    height: 20 / 16,
    fontWeight: FontWeight.w800,
  );

  /// 12,5/16 · Inter 700, ls +0,6 (caixa alta só em rótulos curtos).
  static const TextStyle overline = TextStyle(
    fontFamily: AppFonts.inter,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 12.5,
    height: 16 / 12.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );

  /// 36/42 · Jakarta 800 tabular (saldo/valor máximo).
  static const TextStyle figureXl = TextStyle(
    fontFamily: AppFonts.jakarta,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 36,
    height: 42 / 36,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    fontFeatures: _tabular,
  );

  /// 28/34 · Jakarta 800 tabular.
  static const TextStyle figure = TextStyle(
    fontFamily: AppFonts.jakarta,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    fontFeatures: _tabular,
  );

  /// 20/26 · Jakarta 700 tabular (preços em lista).
  static const TextStyle figureSm = TextStyle(
    fontFamily: AppFonts.jakarta,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
  );
}

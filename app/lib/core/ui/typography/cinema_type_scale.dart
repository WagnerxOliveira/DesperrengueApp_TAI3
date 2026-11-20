import 'package:flutter/painting.dart';

import '../design_system/tokens/app_space.dart';
import '../design_system/tokens/app_type.dart';

/// Escala tipográfica, espaçamento e geometria da apresentação pós-cadastro
/// (v2.27.0).
///
/// Regras (nunca quebradas pela tela):
/// - Fontes **embarcadas**: Plus Jakarta Sans (títulos e números de destaque)
///   e Inter (texto corrido e UI). Nada é buscado em runtime.
/// - O tamanho da fonte **nunca** é reduzido por modo compacto: o conteúdo se
///   adapta por reflow/rolagem. O `TextScaler` do sistema é respeitado (com
///   limite de 1.0–1.5 aplicado no palco).
/// - Nenhum texto abaixo de [CinemaType.minimumFontSize] (12.5 sp) e corpo
///   sempre >= 14 sp.
/// - Números sempre com `tabularFigures`.

/// Famílias de fonte embarcadas.
abstract final class CinemaFonts {
  static const String jakarta = AppFonts.jakarta;
  static const String inter = AppFonts.inter;
}

/// Cores de texto e superfície da apresentação.
abstract final class CinemaColors {
  static const Color onAurora = Color(0xFFF8FAFC);
  static const Color onAuroraSoft = Color(0xFFE2E8F0);
  static const Color ink = Color(0xFF0F172A);
  static const Color inkMeta = Color(0xFF475569);
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDeep = Color(0xFF047857);
  static const Color emeraldInk = Color(0xFF064E3B);
  static const Color emeraldMist = Color(0xFFECFDF5);
  static const Color emeraldRing = Color(0xFFA7F3D0);
  static const Color divider = Color(0xFFE6ECF2);
  static const Color porcelain = Color(0xFFF8FAFC);
  static const Color amber = Color(0xFFF59E0B);
  static const Color ctaInk = Color(0xFF0B1320);
}

/// Grade de 4 pt para espaçamentos.
abstract final class CinemaSpace {
  static const double s4 = AppSpace.s4;
  static const double s8 = AppSpace.s8;
  static const double s12 = AppSpace.s12;
  static const double s16 = AppSpace.s16;
  static const double s20 = AppSpace.s20;
  static const double s24 = AppSpace.s24;
  static const double s32 = AppSpace.s32;
}

/// Geometria (raios e alturas mínimas).
abstract final class CinemaGeometry {
  static const double heroRadius = 28;
  static const double itemRadius = 16;
  static const double iconTileRadius = 12;
  static const double pillRadius = 999;

  static const double heroPadding = 20;
  static const double heroPaddingCompact = 16;

  static const double itemMinHeight = 56;
  static const double iconTileSize = 40;
  static const double inputHeight = 56;
  static const double navButtonSize = 56;
  static const double ctaHeight = 56;
  static const double switchHeight = 64;
  static const double privacyStripHeight = 56;
  static const double progressBarHeight = 10;
  static const double pdfBadgeWidth = 28;
  static const double pdfBadgeHeight = 20;
  static const double pinCellSize = 52;
  static const double gaugeRadius = 96;

  /// Largura máxima da coluna central (Web/tablets): nunca esticar em desktop.
  static const double maxColumnWidth = 480;
}

/// Tokens tipográficos (fonte / tamanho / entrelinha / peso).
abstract final class CinemaType {
  /// Mínimo absoluto aceito em qualquer texto da apresentação.
  static const double minimumFontSize = AppType.minimumFontSize;

  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// Título da etapa — Jakarta 30/36, 800, ls −0.6.
  static const TextStyle display = TextStyle(
    fontFamily: CinemaFonts.jakarta,
    fontSize: 30,
    height: 36 / 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: CinemaColors.onAurora,
  );

  /// Subtítulo — Inter 16/24, 400.
  static const TextStyle lead = TextStyle(
    fontFamily: CinemaFonts.inter,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: CinemaColors.onAuroraSoft,
  );

  /// Cabeçalho do card — Jakarta 18/24, 700.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: CinemaFonts.jakarta,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: CinemaColors.ink,
  );

  /// Linha principal de item — Inter 15/22, 600.
  static const TextStyle rowTitle = TextStyle(
    fontFamily: CinemaFonts.inter,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w600,
    color: CinemaColors.ink,
  );

  /// Texto digitado no campo de busca — Inter 16/22, 600.
  static const TextStyle inputText = TextStyle(
    fontFamily: CinemaFonts.inter,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
    color: CinemaColors.ink,
  );

  /// Metadado secundário — Inter 14/20, 500 (corpo >= 14 sp).
  static const TextStyle rowMeta = TextStyle(
    fontFamily: CinemaFonts.inter,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: CinemaColors.inkMeta,
  );

  /// Metadado com algarismos tabulares (datas, percentuais).
  static const TextStyle rowMetaTabular = TextStyle(
    fontFamily: CinemaFonts.inter,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
    color: CinemaColors.inkMeta,
  );

  /// Metadado sobre bloco perola (#F1F5F9): tom mais escuro (contraste >= 7:1).
  static const TextStyle rowMetaDense = TextStyle(
    fontFamily: CinemaFonts.inter,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: Color(0xFF334155),
  );

  /// Valores grandes (R$, %) — Jakarta 32/38, 800, tabular.
  static const TextStyle figure = TextStyle(
    fontFamily: CinemaFonts.jakarta,
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    fontFeatures: _tabular,
    color: CinemaColors.ink,
  );

  /// Valor em destaque máximo (R$ 0,00 da etapa 5) — Jakarta 36/42, 800.
  static const TextStyle figureXl = TextStyle(
    fontFamily: CinemaFonts.jakarta,
    fontSize: 36,
    height: 42 / 36,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    fontFeatures: _tabular,
    color: CinemaColors.ink,
  );

  /// Preços em lista — Jakarta 20/26, 700, tabular.
  static const TextStyle figureSm = TextStyle(
    fontFamily: CinemaFonts.jakarta,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
    color: CinemaColors.ink,
  );

  /// Selos / legendas — Inter 12.5/18, 600 (mínimo absoluto).
  static const TextStyle caption = TextStyle(
    fontFamily: CinemaFonts.inter,
    fontSize: 12.5,
    height: 18 / 12.5,
    fontWeight: FontWeight.w600,
    color: CinemaColors.inkMeta,
  );

  /// CTA — Jakarta 16/20, 800.
  static const TextStyle button = TextStyle(
    fontFamily: CinemaFonts.jakarta,
    fontSize: 16,
    height: 20 / 16,
    fontWeight: FontWeight.w800,
    color: CinemaColors.ctaInk,
  );

  /// Rótulo do cabeçalho ("Etapa 1 de 6", "Pular", "Pausado") — Inter 14/20.
  static const TextStyle chrome = TextStyle(
    fontFamily: CinemaFonts.inter,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    color: Color(0xFFCBD5E1),
  );

  /// Aplica algarismos tabulares a qualquer estilo numérico.
  static TextStyle tabular(TextStyle base) =>
      base.copyWith(fontFeatures: _tabular);
}

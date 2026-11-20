/// Grade de 4 pt (§2.2). Margem lateral de tela: 16 (compact) / 20 (regular) /
/// 24 (>= 600 px) via `context.layout.margin`. Entre seções 24, entre itens 12,
/// dentro de cartões 16–20.
abstract final class AppSpace {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;

  /// Espaço vertical entre seções.
  static const double section = 24;

  /// Espaço entre itens de uma lista/coluna.
  static const double item = 12;

  /// Padding interno de cartões.
  static const double card = 16;
  static const double cardLarge = 20;
}

/// Geometria global: raios e alturas mínimas (§2.2).
abstract final class AppGeometry {
  /// Cartão.
  static const double cardRadius = 20;

  /// Item/linha.
  static const double itemRadius = 16;

  /// Campo de texto / botão compacto.
  static const double fieldRadius = 14;

  /// Botão / hero / topo de sheet.
  static const double buttonRadius = 28;
  static const double heroRadius = 28;
  static const double sheetRadius = 28;

  /// Chip / pílula / avatar.
  static const double pillRadius = 999;

  /// Ladrilho de ícone (leading de linha).
  static const double iconTileRadius = 12;
  static const double iconTileSize = 40;

  /// Alvo de toque mínimo (WCAG 2.2 / Material).
  static const double minTarget = 48;
  static const double itemMinHeight = 56;
  static const double buttonHeight = 56;
  static const double buttonHeightCompact = 48;
  static const double inputHeight = 56;
  static const double progressBarHeight = 10;

  /// Largura máxima da coluna de conteúdo (nunca esticar cartões em desktop).
  static const double maxColumnWidth = 560;
  static const double phoneColumnWidth = 480;
}

import 'package:flutter/widgets.dart';

/// Classe de largura (§2.2).
enum AppWindowClass { compact, regular, medium, expanded }

/// Breakpoints globais: compact < 360 · regular 360–599 · medium 600–899 ·
/// expanded >= 900.
abstract final class AppBreakpoints {
  static const double compact = 360;
  static const double medium = 600;
  static const double expanded = 900;

  static const double marginCompact = 16;
  static const double marginRegular = 20;
  static const double marginWide = 24;

  static AppWindowClass classify(double width) {
    if (width < compact) return AppWindowClass.compact;
    if (width < medium) return AppWindowClass.regular;
    if (width < expanded) return AppWindowClass.medium;
    return AppWindowClass.expanded;
  }

  static double marginFor(AppWindowClass c) => switch (c) {
        AppWindowClass.compact => marginCompact,
        AppWindowClass.regular => marginRegular,
        AppWindowClass.medium || AppWindowClass.expanded => marginWide,
      };
}

/// Resultado de `context.layout`.
@immutable
class AppLayout {
  const AppLayout({required this.width, required this.textScale});

  final double width;

  /// Fator de escala de fonte efetivo (já com o clamp do app).
  final double textScale;

  AppWindowClass get windowClass => AppBreakpoints.classify(width);
  bool get isCompact => windowClass == AppWindowClass.compact;
  bool get isRegular => windowClass == AppWindowClass.regular;
  bool get isMedium => windowClass == AppWindowClass.medium;
  bool get isExpanded => windowClass == AppWindowClass.expanded;

  /// Largura >= 600 (tablet/desktop): habilita 2 colunas onde couber.
  bool get isWide => width >= AppBreakpoints.medium;

  /// Margem lateral de tela: 16 / 20 / 24.
  double get margin => AppBreakpoints.marginFor(windowClass);

  EdgeInsets get pagePadding => EdgeInsets.symmetric(horizontal: margin);

  /// Escala de fonte alta (>= 1,3): reflua Row→Column, use `Wrap`.
  bool get isLargeText => textScale >= 1.3;

  /// Número de colunas sugerido para grades/listas.
  int get gridColumns => isWide ? 2 : 1;
}

extension AppLayoutOnContext on BuildContext {
  /// Largura/escala atuais. Depende de `MediaQuery` (rebuild ao girar/escalar).
  AppLayout get layout {
    final mq = MediaQuery.of(this);
    return AppLayout(width: mq.size.width, textScale: mq.textScaler.scale(10) / 10);
  }
}

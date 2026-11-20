import 'package:flutter/material.dart';

import '../app_tokens.dart';
import 'tokens/app_breakpoints.dart';
import 'tokens/app_space.dart';

/// Fundo de marca atrás da coluna do app em telas largas (Web/desktop/tablet).
abstract final class AppShellColors {
  static const Color brandBackdrop = Color(0xFF0F172A);
}

/// Moldura responsiva do app (substitui o hack `MediaQuery.copyWith(size: 480)`).
///
/// * `<= 600 px`: tela cheia;
/// * `600–899 px`: coluna centralizada de **560**;
/// * `>= 900 px`: coluna do app (**520**, dentro de 480–560) centralizada sobre
///   fundo de marca, com leve sombra — o app NUNCA estica cartões em desktop.
///
/// O `MediaQuery.size` repassado ao app é o da COLUNA, então `context.layout`
/// e `LayoutBuilder` das telas enxergam a largura real disponível. (Painel
/// lateral de marca/desktop completo: onda `web_a11y`.)
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({super.key, required this.child});

  final Widget child;

  /// Largura da coluna do app para uma janela de [windowWidth] px (ou `null` =
  /// tela cheia).
  static double? columnWidthFor(double windowWidth) {
    if (windowWidth <= AppBreakpoints.medium) return null;
    if (windowWidth < AppBreakpoints.expanded) return AppGeometry.maxColumnWidth;
    return 520;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final colW = columnWidthFor(mq.size.width);
    if (colW == null) return child;
    final wide = mq.size.width >= AppBreakpoints.expanded;
    final tk = context.tk;
    return ColoredBox(
      color: AppShellColors.brandBackdrop,
      child: Center(
        child: SizedBox(
          width: colW,
          height: mq.size.height,
          child: MediaQuery(
            data: mq.copyWith(size: Size(colW, mq.size.height)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tk.background,
                boxShadow: wide
                    ? const [BoxShadow(color: Color(0x66000000), blurRadius: 48, offset: Offset(0, 16))]
                    : null,
              ),
              child: ClipRect(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

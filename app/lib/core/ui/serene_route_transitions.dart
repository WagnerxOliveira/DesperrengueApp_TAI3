import 'package:flutter/material.dart';

import 'design_system/app_navigation.dart';

export 'design_system/app_navigation.dart' show AppHero, AppRoute;

/// Configuração acolhedora e serena para Bottom Sheets modais do funil de
/// autenticação (`v2.25.0`). Mantida por compatibilidade; novas telas devem
/// usar `AppSheet.show` (`AppMotion.sheetStyle`).
abstract final class SereneModalSheetConfig {
  static const Duration duration = Duration(milliseconds: 380);
  static const Duration reverseDuration = Duration(milliseconds: 260);

  static const AnimationStyle sheetAnimationStyle = AnimationStyle(
    curve: Curves.easeOutQuart,
    duration: duration,
    reverseCurve: Curves.easeInCubic,
    reverseDuration: reverseDuration,
  );

  static final Color barrierColor = Colors.black.withValues(alpha: 0.54);
}

/// Alias de compatibilidade da rota de página do funil de autenticação
/// (`v2.25.0`), evoluída para [AppRoute] na `v2.28.0`.
///
/// Preserva os padrões históricos (`380ms` ida / `280ms` volta / `14px`) para
/// os testes e telas legadas; novas rotas devem usar [AppRoute] diretamente
/// (`200ms` / `160ms` / `8px`).
class SereneAuthPageRoute<T> extends AppRoute<T> {
  SereneAuthPageRoute({
    required super.builder,
    super.settings,
    bool fullscreenDialog = false,
    super.maintainState = true,
    super.opaque = true,
    super.barrierDismissible = false,
    super.barrierColor,
    super.barrierLabel,
    double verticalOffsetPx = 14.0,
    super.transitionDuration = const Duration(milliseconds: 380),
    super.reverseTransitionDuration = const Duration(milliseconds: 280),
  }) : super(
          fullscreenDialog: fullscreenDialog,
          verticalOffsetPx: verticalOffsetPx,
        );

  /// Constrói a transição de rota serena (FadeThrough + deslocamento vertical).
  static Widget buildRouteTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
    double verticalOffsetPx = 14.0,
  }) =>
      AppFadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        offset: verticalOffsetPx,
        child: child,
      );

  /// Transição equivalente para `AnimatedSwitcher` (ex.: Cinema -> RoleSelection).
  static Widget buildSwitcherTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Widget child,
    double verticalOffsetPx = 14.0,
  }) =>
      AppRoute.buildSwitcherTransition(
        context: context,
        animation: animation,
        child: child,
        verticalOffsetPx: verticalOffsetPx,
      );
}

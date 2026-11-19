import 'package:flutter/material.dart';

/// Curva bidirecional sem alocação de listeners imperativos por frame.
class _SereneBidirectionalCurve extends Animatable<double> {
  const _SereneBidirectionalCurve();

  @override
  double transform(double t) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    return Curves.easeOutCubic.transform(t);
  }

  @override
  double evaluate(Animation<double> animation) {
    final t = animation.value;
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    final activeCurve = animation.status == AnimationStatus.reverse
        ? Curves.easeInCubic
        : Curves.easeOutCubic;
    return activeCurve.transform(t);
  }
}

/// Configuração acolhedora e serena para Bottom Sheets modais do funil de autenticação.
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

/// Rota de página serena reutilizável do funil de autenticação (`v2.25.0`).
///
/// Combina FadeThrough suave com leve translação vertical ascendente de `14px`
/// (`380ms` na ida em `Curves.easeOutCubic`, `280ms` na volta em `Curves.easeInCubic`),
/// respeitando integralmente `MediaQuery.disableAnimationsOf(context)`.
class SereneAuthPageRoute<T> extends PageRouteBuilder<T> {
  SereneAuthPageRoute({
    required this.builder,
    super.settings,
    super.fullscreenDialog,
    super.maintainState = true,
    super.opaque = true,
    super.barrierDismissible = false,
    super.barrierColor,
    super.barrierLabel,
    this.verticalOffsetPx = 14.0,
    super.transitionDuration = const Duration(milliseconds: 380),
    super.reverseTransitionDuration = const Duration(milliseconds: 280),
  }) : super(
         pageBuilder: (routeContext, animation, secondaryAnimation) =>
             builder(routeContext),
         transitionsBuilder:
             (context, animation, secondaryAnimation, child) =>
                 buildRouteTransition(
                   context: context,
                   animation: animation,
                   secondaryAnimation: secondaryAnimation,
                   verticalOffsetPx: verticalOffsetPx,
                   child: child,
                 ),
       );

  final WidgetBuilder builder;
  final double verticalOffsetPx;

  @override
  AnimationController createAnimationController() {
    final navContext = navigator?.context;
    final disable =
        navContext != null && MediaQuery.disableAnimationsOf(navContext);
    return AnimationController(
      duration: disable ? Duration.zero : transitionDuration,
      reverseDuration: disable ? Duration.zero : reverseTransitionDuration,
      debugLabel: debugLabel,
      vsync: navigator!,
    );
  }

  static const _SereneBidirectionalCurve _kPrimaryCurve =
      _SereneBidirectionalCurve();

  static final Animatable<double> _kSecondaryFade = Tween<double>(
    begin: 1.0,
    end: 0.92,
  ).chain(_kPrimaryCurve);

  /// Constrói a transição de rota serena (FadeThrough + `14px` vertical).
  static Widget buildRouteTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
    double verticalOffsetPx = 14.0,
  }) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    final primaryCurved = animation.drive(_kPrimaryCurve);
    final secondaryFade = secondaryAnimation.drive(_kSecondaryFade);

    return FadeTransition(
      opacity: secondaryFade,
      child: FadeTransition(
        opacity: primaryCurved,
        child: AnimatedBuilder(
          animation: primaryCurved,
          child: child,
          builder: (context, settledChild) {
            final curved = primaryCurved.value;
            return Transform.translate(
              offset: Offset(0, verticalOffsetPx * (1.0 - curved)),
              child: settledChild,
            );
          },
        ),
      ),
    );
  }

  /// Transição equivalente para `AnimatedSwitcher` (ex.: Cinema -> RoleSelection),
  /// aplicando `FadeTransition` + deslocamento vertical de `14px` na entrada
  /// e respeitando `MediaQuery.disableAnimationsOf(context)`.
  static Widget buildSwitcherTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Widget child,
    double verticalOffsetPx = 14.0,
  }) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, settledChild) {
          final isOutgoing =
              animation.status == AnimationStatus.reverse ||
              animation.status == AnimationStatus.dismissed;
          final curved = animation.value.clamp(0.0, 1.0);
          final dy = isOutgoing ? 0.0 : verticalOffsetPx * (1.0 - curved);
          return Transform.translate(
            offset: Offset(0, dy),
            child: settledChild,
          );
        },
      ),
    );
  }
}

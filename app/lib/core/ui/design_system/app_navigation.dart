import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens/app_motion.dart';

/// Transição de página padrão do app (§3.2): **fade-through + deslocamento de
/// 8 px** (nunca zoom), 200 ms na ida (`easeOutCubic`) e 160 ms na volta
/// (`easeInCubic`). Respeita `MediaQuery.disableAnimationsOf` (estado final).
///
/// Habilita o **Predictive Back** do Android (14+) quando [predictiveBack] é
/// verdadeiro: o gesto de voltar "escruba" a mesma animação, podendo ser
/// cancelado. Requer `android:enableOnBackInvokedCallback="true"` no manifest.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder({this.predictiveBack = false});

  final bool predictiveBack;

  @override
  Duration get transitionDuration => AppMotion.page;

  @override
  Duration get reverseTransitionDuration => AppMotion.pageReverse;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final transition = AppFadeThroughTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      offset: route.fullscreenDialog ? AppMotion.fullscreenModalOffset : AppMotion.pageOffset,
      child: child,
    );
    if (!predictiveBack) return transition;
    return _AppPredictiveBackObserver(route: route, child: transition);
  }
}

/// Curva bidirecional: `easeOutCubic` na ida, `easeInCubic` na volta (sem
/// alocar listeners por frame).
class _AppPageCurve extends Animatable<double> {
  const _AppPageCurve();

  @override
  double transform(double t) => AppMotion.pageCurve.transform(t);

  @override
  double evaluate(Animation<double> animation) {
    final t = animation.value;
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    final curve = animation.status == AnimationStatus.reverse
        ? AppMotion.pageReverseCurve
        : AppMotion.pageCurve;
    return curve.transform(t);
  }
}

/// Fade-through + deslocamento vertical curto. Usado pelo tema e por [AppRoute].
class AppFadeThroughTransition extends StatelessWidget {
  const AppFadeThroughTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
    this.offset = AppMotion.pageOffset,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;
  final double offset;

  static const Animatable<double> _curve = _AppPageCurve();
  static final Animatable<double> _secondaryFade = Tween<double>(
    begin: 1.0,
    end: 0.92,
  ).chain(_curve);

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final curved = animation.drive(_curve);
    final secondaryOpacity = secondaryAnimation.drive(_secondaryFade);
    return FadeTransition(
      opacity: secondaryOpacity,
      child: FadeTransition(
        opacity: curved,
        child: AnimatedBuilder(
          animation: curved,
          child: child,
          builder: (context, settled) => Transform.translate(
            offset: Offset(0, offset * (1 - curved.value)),
            child: settled,
          ),
        ),
      ),
    );
  }
}
/// Observa o gesto de "voltar" preditivo do Android e conduz a rota (a mesma
/// lógica do detector do Flutter, sem a transição "shared element" própria).
class _AppPredictiveBackObserver<T> extends StatefulWidget {
  const _AppPredictiveBackObserver({required this.route, required this.child});

  final PageRoute<T> route;
  final Widget child;

  @override
  State<_AppPredictiveBackObserver<T>> createState() => _AppPredictiveBackObserverState<T>();
}

class _AppPredictiveBackObserverState<T> extends State<_AppPredictiveBackObserver<T>>
    with WidgetsBindingObserver {
  bool get _enabled => widget.route.isCurrent && widget.route.popGestureEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent || !_enabled) return false;
    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    widget.route.handleUpdateBackGestureProgress(progress: 1 - backEvent.progress);
  }

  @override
  void handleCancelBackGesture() => widget.route.handleCancelBackGesture();

  @override
  void handleCommitBackGesture() => widget.route.handleCommitBackGesture();

  @override
  Widget build(BuildContext context) => widget.child;
}

/// `PageTransitionsTheme` global do app: iOS/macOS = Cupertino (swipe-back);
/// Android = fade-through + Predictive Back; Web/Windows/Linux/Fuchsia =
/// fade-through. As `MaterialPageRoute` herdam isto sem alterar as chamadas.
abstract final class AppPageTransitions {
  static const PageTransitionsTheme theme = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: AppPageTransitionsBuilder(predictiveBack: true),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: AppPageTransitionsBuilder(),
      TargetPlatform.linux: AppPageTransitionsBuilder(),
      TargetPlatform.fuchsia: AppPageTransitionsBuilder(),
    },
  );
}

/// Rota padrão do app (evolução de `SereneAuthPageRoute`).
///
/// Mesma transição do tema (fade-through + 8 px; 200/160 ms). Com
/// [fullscreenModal] sobe 16 px + fade (modal em tela cheia). Use quando
/// precisar de configuração explícita (nome, `fullscreenDialog`, duração);
/// `Navigator.push(MaterialPageRoute(...))` já herda a transição pelo tema.
class AppRoute<T> extends PageRouteBuilder<T> {
  AppRoute({
    required this.builder,
    super.settings,
    bool fullscreenModal = false,
    bool? fullscreenDialog,
    super.maintainState = true,
    super.opaque = true,
    super.barrierDismissible = false,
    super.barrierColor,
    super.barrierLabel,
    double? verticalOffsetPx,
    super.transitionDuration = AppMotion.page,
    super.reverseTransitionDuration = AppMotion.pageReverse,
  })  : verticalOffsetPx = verticalOffsetPx ??
            ((fullscreenDialog ?? fullscreenModal)
                ? AppMotion.fullscreenModalOffset
                : AppMotion.pageOffset),
        super(
          fullscreenDialog: fullscreenDialog ?? fullscreenModal,
          pageBuilder: (routeContext, animation, secondaryAnimation) => builder(routeContext),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              AppFadeThroughTransition(
                animation: animation,
                secondaryAnimation: secondaryAnimation,
                offset: verticalOffsetPx ??
                    ((fullscreenDialog ?? fullscreenModal)
                        ? AppMotion.fullscreenModalOffset
                        : AppMotion.pageOffset),
                child: child,
              ),
        );

  final WidgetBuilder builder;
  final double verticalOffsetPx;

  @override
  AnimationController createAnimationController() {
    final navContext = navigator?.context;
    final disable = navContext != null && (MediaQuery.maybeDisableAnimationsOf(navContext) ?? false);
    return AnimationController(
      duration: disable ? Duration.zero : transitionDuration,
      reverseDuration: disable ? Duration.zero : reverseTransitionDuration,
      debugLabel: debugLabel,
      vsync: navigator!,
    );
  }

  /// Transição equivalente para `AnimatedSwitcher` (fade + deslocamento curto).
  static Widget buildSwitcherTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Widget child,
    double verticalOffsetPx = AppMotion.pageOffset,
  }) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return child;
    }
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, settledChild) {
          final isOutgoing = animation.status == AnimationStatus.reverse ||
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

/// Atalho de shared-element (§3.2): avatar→foto, cartão→detalhe, categoria→
/// lista, portfólio→visualizador. O voo dura <= 220 ms e respeita
/// `disableAnimations`. Use a MESMA [tag] nos dois lados.
class AppHero extends StatelessWidget {
  const AppHero({super.key, required this.tag, required this.child, this.flightShuttleBuilder});

  final Object tag;
  final Widget child;
  final HeroFlightShuttleBuilder? flightShuttleBuilder;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      createRectTween: (begin, end) => MaterialRectArcTween(begin: begin, end: end),
      flightShuttleBuilder: flightShuttleBuilder,
      transitionOnUserGestures: true,
      child: child,
    );
  }
}

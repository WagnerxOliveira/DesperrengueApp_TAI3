import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

/// Duração abstrata (ms) da coreografia de 3 Atos de cada etapa
/// (0–0,75 s entrada / 0,75–3,10 s demonstração / repouso).
///
/// Todos os efeitos declarativos de [ActFx] são expressos nesta linha do
/// tempo normalizada e seguem o `AnimationController` real da etapa (pausa,
/// retomada e `disableAnimations ⇒ estado final` herdados sem custo).
const int kCinemaActMs = 3100;

Duration _actDuration(double fraction) => Duration(
      microseconds: (fraction * kCinemaActMs * 1000).round(),
    );

/// Progresso 0..1 de [act] entre as frações [start] e [end] (com [curve]).
double actProgress(
  Animation<double> act,
  double start,
  double end, [
  Curve curve = Curves.easeOutQuart,
]) {
  final span = end - start;
  if (span <= 0) return act.value >= end ? 1.0 : 0.0;
  return curve.transform(((act.value - start) / span).clamp(0.0, 1.0));
}

/// Entrada em cascata declarativa (`flutter_animate`): fade + deslize vertical
/// em pixels, com `Curves.easeOutQuart`, entre as frações [start] e [end] do
/// ato.
List<Effect<dynamic>> cascadeEffects(
  double start,
  double end, {
  double dy = 12,
  double? scaleFrom,
}) {
  final delay = _actDuration(start);
  final duration = _actDuration(end - start);
  return <Effect<dynamic>>[
    FadeEffect(
      delay: delay,
      duration: duration,
      begin: 0.0,
      end: 1.0,
      curve: Curves.easeOutQuart,
    ),
    if (dy != 0)
      MoveEffect(
        delay: delay,
        duration: duration,
        begin: Offset(0, dy),
        end: Offset.zero,
        curve: Curves.easeOutQuart,
      ),
    if (scaleFrom != null)
      ScaleEffect(
        delay: delay,
        duration: duration,
        begin: Offset(scaleFrom, scaleFrom),
        end: const Offset(1, 1),
        curve: Curves.easeOutQuart,
      ),
  ];
}

/// Adaptador do `flutter_animate` que segue uma [Animation] existente
/// (o controlador do ato da etapa) sem jamais alterar a duração dela.
class CinemaActAdapter extends Adapter {
  CinemaActAdapter(this.animation) : super(animated: false);

  final Animation<double> animation;
  AnimationController? _target;

  void _sync() {
    final target = _target;
    if (target == null) return;
    target.value = animation.value.clamp(0.0, 1.0);
  }

  @override
  void attach(AnimationController controller) {
    _target = controller;
    controller.value = animation.value.clamp(0.0, 1.0);
    animation.addListener(_sync);
  }

  @override
  void detach() {
    animation.removeListener(_sync);
    _target = null;
    super.detach();
  }
}

/// Folha declarativa: aplica [effects] (`flutter_animate`) ao [child] seguindo
/// a linha do tempo [act] da etapa. Vive somente em folhas, preservando
/// `WelcomeStoryHeroCard.build() == 1`.
class ActFx extends StatefulWidget {
  const ActFx({
    super.key,
    required this.act,
    required this.effects,
    required this.child,
  });

  final Animation<double> act;
  final List<Effect<dynamic>> effects;
  final Widget child;

  @override
  State<ActFx> createState() => _ActFxState();
}

class _ActFxState extends State<ActFx> {
  late CinemaActAdapter _adapter = CinemaActAdapter(widget.act);

  @override
  void didUpdateWidget(covariant ActFx oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.act != widget.act) {
      _adapter = CinemaActAdapter(widget.act);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Animate(
      adapter: _adapter,
      effects: <Effect<dynamic>>[
        ...widget.effects,
        // Cauda de 1 ms ancorada em 3,10 s: normaliza o tempo total do ato.
        CustomEffect(
          delay: Duration(milliseconds: kCinemaActMs - 1),
          duration: const Duration(milliseconds: 1),
          builder: (context, value, child) => child,
        ),
      ],
      child: widget.child,
    );
  }
}

/// Ícone Lottie embarcado sincronizado ao ato da etapa
/// (`LottieBuilder.asset(controller:)`, `RenderCache.raster` na Web).
///
/// Se o arquivo não carregar, exibe [fallbackIcon] vetorial.
class CinemaLottie extends StatefulWidget {
  const CinemaLottie({
    super.key,
    required this.asset,
    required this.act,
    required this.size,
    required this.fallbackIcon,
    required this.fallbackColor,
    this.begin = 0.0,
    this.end = 1.0,
    this.curve = Curves.easeOutCubic,
  });

  final String asset;
  final Animation<double> act;
  final double size;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final double begin;
  final double end;
  final Curve curve;

  @override
  State<CinemaLottie> createState() => _CinemaLottieState();
}

class _CinemaLottieState extends State<CinemaLottie> {
  late Animation<double> _progress = _buildProgress();

  Animation<double> _buildProgress() => widget.act.drive(
        CurveTween(
          curve: Interval(widget.begin, widget.end, curve: widget.curve),
        ),
      );

  @override
  void didUpdateWidget(covariant CinemaLottie oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.act != widget.act ||
        oldWidget.begin != widget.begin ||
        oldWidget.end != widget.end ||
        oldWidget.curve != widget.curve) {
      _progress = _buildProgress();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final placeholder = SizedBox(width: size, height: size);
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: LottieBuilder.asset(
          widget.asset,
          controller: _progress,
          width: size,
          height: size,
          fit: BoxFit.contain,
          renderCache: kIsWeb ? RenderCache.raster : null,
          frameBuilder: (context, child, composition) =>
              composition == null ? placeholder : child,
          errorBuilder: (context, error, stackTrace) => Icon(
            widget.fallbackIcon,
            size: size * 0.8,
            color: widget.fallbackColor,
          ),
        ),
      ),
    );
  }
}

/// Caminhos dos Lottie embarcados.
abstract final class CinemaLottieAssets {
  static const String checkBurst = 'assets/lottie/check_burst.json';
  static const String lockClose = 'assets/lottie/lock_close.json';
  static const String sparkleSoft = 'assets/lottie/sparkle_soft.json';
}

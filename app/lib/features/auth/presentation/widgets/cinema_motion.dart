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

Duration _actDuration(double fraction) =>
    Duration(microseconds: (fraction * kCinemaActMs * 1000).round());

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
  double fadeFrom = 0.0,
}) {
  final delay = _actDuration(start);
  final duration = _actDuration(end - start);
  return <Effect<dynamic>>[
    FadeEffect(
      delay: delay,
      duration: duration,
      begin: fadeFrom,
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

/// Efeitos `flutter_animate` compostos sem o widget `Animate` (que agenda um
/// `Future.delayed` por instância): cada [EffectEntry] é criado aqui e o
/// resultado é ligado a um [AnimationController] próprio da folha.
Widget composeEffects({
  required BuildContext context,
  required Widget child,
  required AnimationController controller,
  required List<Effect<dynamic>> effects,
}) {
  var out = child;
  for (final effect in effects) {
    out = effect.build(
      context,
      out,
      controller,
      EffectEntry(
        effect: effect,
        delay: effect.delay ?? Duration.zero,
        duration: effect.duration ?? Duration.zero,
        curve: effect.curve ?? Curves.linear,
        owner: _effectOwner,
      ),
    );
  }
  return out;
}

// Proprietário inerte exigido por `EffectEntry` (nunca é montado).
final Animate _effectOwner = Animate(child: const SizedBox.shrink());

/// Folha declarativa: aplica [effects] (`flutter_animate`) ao [child] seguindo
/// a linha do tempo [act] da etapa (pausa, retomada e
/// `disableAnimations ⇒ estado final` herdados do controlador real). Vive
/// somente em folhas, preservando `WelcomeStoryHeroCard.build() == 1`, e não
/// cria `Timer`.
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

class _ActFxState extends State<ActFx> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Widget? _composed;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: kCinemaActMs),
      value: widget.act.value.clamp(0.0, 1.0),
    );
    widget.act.addListener(_sync);
  }

  void _sync() {
    _controller.value = widget.act.value.clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(covariant ActFx oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.act != widget.act) {
      oldWidget.act.removeListener(_sync);
      widget.act.addListener(_sync);
      _sync();
    }
    if (!identical(oldWidget.child, widget.child) ||
        oldWidget.effects.length != widget.effects.length) {
      _composed = null;
    }
  }

  @override
  void dispose() {
    widget.act.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _composed ??= composeEffects(
      context: context,
      child: widget.child,
      controller: _controller,
      effects: widget.effects,
    );
  }
}

/// Entrada única (fade + deslize) de uma folha, tocada uma vez ao montar.
class IntroFx extends StatefulWidget {
  const IntroFx({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 320),
    this.dy = 12,
  });

  final Widget child;
  final Duration duration;
  final double dy;

  @override
  State<IntroFx> createState() => _IntroFxState();
}

class _IntroFxState extends State<IntroFx> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Widget? _composed;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void didUpdateWidget(covariant IntroFx oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.child, widget.child)) _composed = null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _composed ??= composeEffects(
      context: context,
      child: widget.child,
      controller: _controller,
      effects: <Effect<dynamic>>[
        FadeEffect(
          duration: widget.duration,
          begin: 0.0,
          end: 1.0,
          curve: Curves.easeOutQuart,
        ),
        MoveEffect(
          duration: widget.duration,
          begin: Offset(0, widget.dy),
          end: Offset.zero,
          curve: Curves.easeOutQuart,
        ),
      ],
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
    CurveTween(curve: Interval(widget.begin, widget.end, curve: widget.curve)),
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

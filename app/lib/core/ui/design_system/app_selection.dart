import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_tokens.dart';
import 'app_pressable.dart';
import 'tokens/app_motion.dart';
import 'tokens/app_space.dart';
import 'tokens/app_type.dart';

/// Uma opção do [AppSegmented].
class AppSegment<T> {
  const AppSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Seletor segmentado com **cursor-pílula deslizante** (180 ms) — o mesmo
/// seletor esculpido da etapa 6 da apresentação, agora com tokens globais.
///
/// * trilha `surfaceInset` (claro) / `surface` (escuro) com borda; cursor com
///   `accent`, brilho superior e sombra; altura mínima 56 (cada opção >= 48);
/// * rótulos QUEBRAM em 2 linhas sob escala alta (nunca `…`);
/// * `←`/`→` (e `Enter`/`Space`) na Web/desktop trocam a seleção e movem o
///   foco (respeita RTL); `Semantics(selected)` + grupo mutuamente exclusivo;
/// * `disableAnimations` ⇒ o cursor salta direto para o destino.
///
/// ```dart
/// AppSegmented<UserMode>(
///   segments: const [
///     AppSegment(value: UserMode.client, label: 'Quero contratar', icon: Icons.search_rounded),
///     AppSegment(value: UserMode.provider, label: 'Quero trabalhar'),
///   ],
///   selected: _mode,
///   onChanged: (m) => setState(() => _mode = m),
/// )
/// ```
class AppSegmented<T> extends StatefulWidget {
  const AppSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.expand = true,
  }) : assert(segments.length >= 2, 'AppSegmented precisa de ao menos 2 opções');

  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// `true` (padrão): ocupa a largura disponível; `false`: largura do conteúdo.
  final bool expand;

  @override
  State<AppSegmented<T>> createState() => _AppSegmentedState<T>();
}

class _AppSegmentedState<T> extends State<AppSegmented<T>> {
  static const Duration _slide = Duration(milliseconds: 180);
  static const double _radius = AppGeometry.itemRadius + 4;
  static const double _pad = AppSpace.s4;

  late List<FocusNode> _nodes = _makeNodes(widget.segments.length);

  List<FocusNode> _makeNodes(int n) => List.generate(n, (i) => FocusNode(debugLabel: 'AppSegmented#$i'));

  @override
  void didUpdateWidget(AppSegmented<T> old) {
    super.didUpdateWidget(old);
    if (old.segments.length != widget.segments.length) {
      for (final n in _nodes) {
        n.dispose();
      }
      _nodes = _makeNodes(widget.segments.length);
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  int get _index => widget.segments.indexWhere((s) => s.value == widget.selected);

  void _select(int i) {
    if (i < 0 || i >= widget.segments.length) return;
    final value = widget.segments[i].value;
    if (value != widget.selected) widget.onChanged(value);
  }

  void _move(int delta) {
    final from = _index < 0 ? 0 : _index;
    final to = (from + delta).clamp(0, widget.segments.length - 1);
    if (to == from && _index >= 0) return;
    _select(to);
    _nodes[to].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final reduced = AppMotion.reduced(context);
    final n = widget.segments.length;
    final idx = _index;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final trackFill = tk.isDark ? tk.surface : tk.surfaceInset;

    final cursorX = n <= 1 || idx < 0 ? -1.0 : (idx / (n - 1)) * 2 - 1;

    Widget track = DecoratedBox(
      decoration: BoxDecoration(
        color: trackFill,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: tk.border, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_pad),
        child: Stack(
          children: [
            if (idx >= 0)
              Positioned.fill(
                child: ExcludeSemantics(
                  child: AnimatedAlign(
                    duration: reduced ? Duration.zero : _slide,
                    curve: Curves.easeOutCubic,
                    alignment: AlignmentDirectional(cursorX, 0),
                    child: FractionallySizedBox(
                      widthFactor: 1 / n,
                      heightFactor: 1,
                      child: _Cursor(color: tk.accent),
                    ),
                  ),
                ),
              ),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: _Option(
                        segment: widget.segments[i],
                        selected: i == idx,
                        focusNode: _nodes[i],
                        onTap: () => _select(i),
                        reduced: reduced,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!widget.expand) {
      track = Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        heightFactor: 1,
        child: IntrinsicWidth(child: track),
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _move(rtl ? 1 : -1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _move(rtl ? -1 : 1),
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppGeometry.inputHeight),
          child: track,
        ),
      ),
    );
  }
}

/// Pílula esculpida: preenchimento do acento, brilho superior e sombra dupla.
class _Cursor extends StatelessWidget {
  const _Cursor({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppGeometry.itemRadius));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: color,
        border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 5)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 4, offset: const Offset(0, 1.5)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 12,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: 0.24), Colors.white.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Option<T> extends StatelessWidget {
  const _Option({
    required this.segment,
    required this.selected,
    required this.focusNode,
    required this.onTap,
    required this.reduced,
  });

  final AppSegment<T> segment;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final target = selected ? tk.onAccent : tk.text;
    final style = selected ? AppType.bodyStrong : AppType.body.copyWith(fontWeight: FontWeight.w500);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: AppPressable(
        onTap: onTap,
        focusNode: focusNode,
        scale: 0.98,
        borderRadius: BorderRadius.circular(AppGeometry.itemRadius + 2),
        semanticLabel: segment.label,
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppGeometry.minTarget),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s8),
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: target),
                duration: reduced ? Duration.zero : const Duration(milliseconds: 180),
                builder: (context, color, _) {
                  final c = color ?? target;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (segment.icon != null) ...[
                        Icon(segment.icon, size: 20, color: c),
                        const SizedBox(width: AppSpace.s8),
                      ],
                      Flexible(
                        child: Text(segment.label, textAlign: TextAlign.center, style: style.copyWith(color: c)),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de passos segmentada ("Passo x de y"): cada segmento preenche em
/// 220 ms (`AppMotion.progress`) com `tk.accent` sobre a trilha `tk.border`.
/// `animated: false` ou `disableAnimations` ⇒ preenchimento imediato.
///
/// ```dart
/// AppStepper(total: 5, current: 2) // 2 de 5 preenchidos
/// ```
class AppStepper extends StatelessWidget {
  const AppStepper({super.key, required this.total, required this.current, this.animated = true})
      : assert(total > 0, 'total deve ser > 0');

  final int total;

  /// Passo atual (1-based): os segmentos 1..current ficam preenchidos.
  final int current;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final reduced = AppMotion.reduced(context);
    final step = current.clamp(0, total);
    final duration = (animated && !reduced) ? AppMotion.progress : Duration.zero;
    const radius = BorderRadius.all(Radius.circular(AppGeometry.pillRadius));

    return Semantics(
      label: 'Passo $step de $total',
      excludeSemantics: true,
      child: SizedBox(
        height: AppGeometry.progressBarHeight,
        child: Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: AppSpace.s4 + 2),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: tk.border, borderRadius: radius),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: AnimatedFractionallySizedBox(
                      key: ValueKey('app-stepper-fill-$i'),
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: i < step ? 1 : 0,
                      heightFactor: 1,
                      child: DecoratedBox(decoration: BoxDecoration(color: tk.accent, borderRadius: radius)),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Anel de progresso (0..1) com animação de 250 ms (`AppMotion.count`) entre o
/// valor antigo e o novo; [child] fica centralizado (ex.: o percentual).
///
/// ```dart
/// AppProgressRing(
///   value: 0.72,
///   semanticLabel: 'Perfil completo',
///   child: Text('72%', style: AppType.figureSm),
/// )
/// ```
class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    super.key,
    required this.value,
    this.size = 96,
    this.strokeWidth = 10,
    this.child,
    this.color,
    this.semanticLabel,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Widget? child;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final ring = color ?? tk.accent;
    final duration = AppMotion.d(context, AppMotion.count);

    return Semantics(
      label: semanticLabel ?? 'Progresso',
      value: '${(v * 100).round()}%',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: v),
            duration: duration,
            curve: AppMotion.countCurve,
            builder: (context, animated, child) => CustomPaint(
              painter: _RingPainter(
                value: animated,
                color: ring,
                track: tk.border,
                strokeWidth: strokeWidth,
              ),
              child: Center(child: child),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base);
    if (value <= 0.001) return;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track || old.strokeWidth != strokeWidth;
}

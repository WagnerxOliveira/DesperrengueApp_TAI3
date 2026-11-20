import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/typography/cinema_type_scale.dart';

/// Direção do botão circular de navegação da apresentação.
enum StoryNavDirection { previous, next }

/// Botão circular de navegação (`<` / `>`) **único** para os dois lados da
/// apresentação pós-cadastro: mesma forma, mesmo tamanho (56×56), mesmo vidro,
/// mesma animação — só o chevron espelha.
///
/// - Vidro: preenchimento `rgba(255,255,255,0.14)` + borda 1 px
///   `rgba(255,255,255,0.34)`.
/// - Foco/hover (Web e teclado): anel 2 px `#A7F3D0`.
/// - Pressionado: escala 0.94 com mola criticamente amortecida (~150 ms) e
///   `HapticFeedback.selectionClick()`.
/// - Desabilitado: opacidade 0.35, mas **ocupa o mesmo espaço** (zero "pulo"
///   de layout).
class StoryNavCircleButton extends StatefulWidget {
  const StoryNavCircleButton({
    super.key,
    required this.direction,
    required this.enabled,
    required this.onPressed,
  });

  final StoryNavDirection direction;
  final bool enabled;
  final VoidCallback onPressed;

  static const double size = CinemaGeometry.navButtonSize;
  static const double iconSize = 30;
  static const double disabledOpacity = 0.35;
  static const Color glassFill = Color(0x24FFFFFF); // 0.14
  static const Color glassBorder = Color(0x57FFFFFF); // 0.34
  static const Color iconColor = Color(0xFFF8FAFC);
  static const Color focusRing = CinemaColors.emeraldRing;

  /// Rótulo semântico / tooltip em português.
  String get label =>
      direction == StoryNavDirection.previous ? 'Voltar' : 'Próximo';

  @override
  State<StoryNavCircleButton> createState() => _StoryNavCircleButtonState();
}

class _StoryNavCircleButtonState extends State<StoryNavCircleButton>
    with SingleTickerProviderStateMixin {
  static const double _pressedScale = 0.94;
  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1.0,
    stiffness: 720.0,
    ratio: 1.0,
  );

  late final AnimationController _scale;
  bool _focused = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
      vsync: this,
      lowerBound: 0.8,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _animateScaleTo(double target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _scale.value = target;
      return;
    }
    _scale.animateWith(SpringSimulation(_spring, _scale.value, target, 0.0));
  }

  void _handleTapDown(TapDownDetails _) {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    _animateScaleTo(_pressedScale);
  }

  void _handleTapRelease() {
    _animateScaleTo(1.0);
  }

  void _activate() {
    if (!widget.enabled) return;
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final isPrevious = widget.direction == StoryNavDirection.previous;
    final showRing = enabled && (_focused || _hovered);
    final fill = _hovered && enabled
        ? const Color(0x33FFFFFF) // hover sutil: 0.20
        : StoryNavCircleButton.glassFill;

    final glass = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: StoryNavCircleButton.glassBorder),
      ),
      child: Center(
        child: Icon(
          isPrevious ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
          size: StoryNavCircleButton.iconSize,
          color: StoryNavCircleButton.iconColor,
        ),
      ),
    );

    final ring = IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: showRing ? 1.0 : 0.0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: StoryNavCircleButton.focusRing, width: 2),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: Tooltip(
        message: widget.label,
        excludeFromSemantics: true,
        child: SizedBox(
          width: StoryNavCircleButton.size,
          height: StoryNavCircleButton.size,
          child: FocusableActionDetector(
            enabled: enabled,
            mouseCursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            onShowFocusHighlight: (value) => setState(() => _focused = value),
            onShowHoverHighlight: (value) => setState(() => _hovered = value),
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  _activate();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: _handleTapDown,
              onTapUp: (_) => _handleTapRelease(),
              onTapCancel: _handleTapRelease,
              onTap: _activate,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: enabled ? 1.0 : StoryNavCircleButton.disabledOpacity,
                child: ScaleTransition(
                  scale: _scale,
                  child: Stack(fit: StackFit.expand, children: [glass, ring]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

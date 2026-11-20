import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_tokens.dart';
import 'tokens/app_motion.dart';

/// Escala de toque (0,97) por mola, SEM interferir nos gestos do filho
/// (usa `Listener`). Respeita `disableAnimations`. Use em botões Material
/// (`FilledButton` etc.) e cartões que já têm o próprio `InkWell`.
class AppPressScale extends StatefulWidget {
  const AppPressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = AppMotion.tapScale,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<AppPressScale> createState() => _AppPressScaleState();
}

class _AppPressScaleState extends State<AppPressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v || !mounted) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || AppMotion.reduced(context)) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: _down ? AppMotion.tap : AppMotion.tapRelease,
        curve: _down ? AppMotion.tapCurve : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Wrapper reutilizável de toque/hover/foco/cursor (§2.4):
///
/// * toque: escala 0,97 por mola (<= 120 ms) + película de pressão;
/// * Web/desktop: cursor `click`, hover +4% de claridade (120 ms) e **anel de
///   foco de 2 px do acento** (só no foco por teclado);
/// * `Enter`/`Space` ativam; `Semantics(button: true)` automático;
/// * `haptic: true` dispara `HapticFeedback.selectionClick()` (ações primárias).
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.semanticLabel,
    this.haptic = false,
    this.scale = AppMotion.tapScale,
    this.focusNode,
    this.autofocus = false,
    this.isButton = true,
    this.excludeSemantics = false,
  });

  final Widget child;

  /// `null` = desabilitado (sem efeitos, sem cursor).
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;
  final String? semanticLabel;
  final bool haptic;
  final double scale;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool isButton;
  final bool excludeSemantics;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _activate() {
    final cb = widget.onTap;
    if (cb == null) return;
    if (widget.haptic) HapticFeedback.selectionClick();
    cb();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final reduced = AppMotion.reduced(context);
    final ink = tk.isDark ? Colors.white : tk.text;
    final overlayAlpha = !_enabled ? 0.0 : (_pressed ? 0.08 : (_hovered ? 0.04 : 0.0));
    final showRing = _focused && _enabled && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

    Widget content = Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: reduced ? Duration.zero : AppMotion.fadeShort,
              decoration: BoxDecoration(
                color: ink.withValues(alpha: overlayAlpha),
                borderRadius: widget.borderRadius,
                border: showRing ? Border.all(color: tk.accentInk, width: 2) : null,
              ),
            ),
          ),
        ),
      ],
    );

    content = AppPressScale(enabled: _enabled, scale: widget.scale, child: content);

    return Semantics(
      button: widget.isButton,
      enabled: _enabled,
      label: widget.semanticLabel,
      excludeSemantics: widget.excludeSemantics,
      child: FocusableActionDetector(
        enabled: _enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            _activate();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap == null ? null : _activate,
          onLongPress: widget.onLongPress,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: content,
        ),
      ),
    );
  }

}

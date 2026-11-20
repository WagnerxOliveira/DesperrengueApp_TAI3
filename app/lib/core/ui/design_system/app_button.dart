import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_tokens.dart';
import 'app_pressable.dart';
import 'tokens/app_motion.dart';
import 'tokens/app_space.dart';
import 'tokens/app_type.dart';

enum AppButtonVariant { primary, secondary, tertiary, destructive }

/// Botão do design system (§2.4).
///
/// * `primary` (preenchido, acento do modo) · `secondary` (contorno) ·
///   `tertiary` (texto) · `destructive` (vermelho — só para risco real).
/// * `loading`: o rótulo faz *cross-fade* para um spinner de 20 px **mantendo a
///   largura** do botão; o toque fica bloqueado.
/// * micro-interação de toque: escala 0,97 por mola (<= 120 ms) + `haptic`
///   (`selectionClick`) nas primárias.
/// * o rótulo QUEBRA em 2 linhas sob escala alta (nunca `…`/`FittedBox`).
///
/// Internamente usa `FilledButton`/`OutlinedButton`/`TextButton` (mantém ripple,
/// foco e semântica do Material).
///
/// ```dart
/// AppButton(label: 'Continuar', onPressed: _next, trailingArrow: true)
/// AppButton(label: 'Pagar', loading: _busy, onPressed: _pay)
/// AppButton(label: 'Cancelar pedido', variant: AppButtonVariant.destructive, onPressed: _cancel)
/// ```
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.trailingArrow = false,
    this.loading = false,
    this.expand = true,
    this.compact = false,
    this.haptic,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool trailingArrow;
  final bool loading;

  /// `true` (padrão): ocupa a largura disponível. `false`: largura do conteúdo.
  final bool expand;

  /// Altura 48 (em vez de 56).
  final bool compact;

  /// `null` = háptico só nas primárias/destrutivas.
  final bool? haptic;
  final String? semanticLabel;

  bool get _isPrimaryLike => variant == AppButtonVariant.primary || variant == AppButtonVariant.destructive;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final height = compact ? AppGeometry.buttonHeightCompact : AppGeometry.buttonHeight;
    final doHaptic = haptic ?? _isPrimaryLike;
    final VoidCallback? press = (loading || onPressed == null)
        ? null
        : () {
            if (doHaptic) HapticFeedback.selectionClick();
            onPressed!();
          };

    final child = _AppButtonContent(
      label: label,
      icon: icon,
      trailingArrow: trailingArrow,
      loading: loading,
      semanticLabel: semanticLabel,
    );
    final size = Size(expand ? double.infinity : 0, height);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppGeometry.buttonRadius));

    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
          onPressed: press,
          style: FilledButton.styleFrom(
            minimumSize: size,
            shape: shape,
            disabledBackgroundColor: loading ? tk.accent : null,
            disabledForegroundColor: loading ? tk.onAccent : null,
          ),
          child: child,
        ),
      AppButtonVariant.destructive => FilledButton(
          onPressed: press,
          style: FilledButton.styleFrom(
            minimumSize: size,
            shape: shape,
            backgroundColor: tk.danger,
            foregroundColor: AppTokens.onColor(tk.danger),
            disabledBackgroundColor: loading ? tk.danger : null,
            disabledForegroundColor: loading ? AppTokens.onColor(tk.danger) : null,
          ),
          child: child,
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: press,
          style: OutlinedButton.styleFrom(
            minimumSize: size,
            shape: shape,
            foregroundColor: tk.accentInk,
            disabledForegroundColor: loading ? tk.accentInk : null,
          ).copyWith(
            side: WidgetStateProperty.resolveWith<BorderSide?>((s) {
              if (loading) return BorderSide(color: tk.accentInk, width: 1.5);
              if (s.contains(WidgetState.disabled)) return BorderSide(color: tk.border, width: 1.5);
              if (s.contains(WidgetState.focused)) return BorderSide(color: tk.accentInk, width: 2);
              return BorderSide(color: tk.accentInk, width: 1.5);
            }),
          ),
          child: child,
        ),
      AppButtonVariant.tertiary => TextButton(
          onPressed: press,
          style: TextButton.styleFrom(
            minimumSize: Size(expand ? double.infinity : AppGeometry.minTarget, AppGeometry.minTarget),
            shape: shape,
            foregroundColor: tk.accentInk,
            textStyle: AppType.button,
          ),
          child: child,
        ),
    };
    return AppPressScale(enabled: press != null, child: button);
  }
}

class _AppButtonContent extends StatelessWidget {
  const _AppButtonContent({
    required this.label,
    required this.icon,
    required this.trailingArrow,
    required this.loading,
    required this.semanticLabel,
  });

  final String label;
  final IconData? icon;
  final bool trailingArrow;
  final bool loading;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    final labelRow = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: AppSpace.s8)],
        Flexible(child: Text(label, textAlign: TextAlign.center, semanticsLabel: semanticLabel)),
        if (trailingArrow) ...[
          const SizedBox(width: AppSpace.s8),
          const Icon(Icons.arrow_forward_rounded, size: 20),
        ],
      ],
    );
    // O rótulo permanece no layout (largura estável) e some em cross-fade.
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedOpacity(
          opacity: loading ? 0 : 1,
          duration: reduced ? Duration.zero : AppMotion.fade,
          curve: AppMotion.fadeCurve,
          child: labelRow,
        ),
        if (loading)
          Semantics(
            label: 'Carregando',
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: DefaultTextStyle.of(context).style.color,
              ),
            ),
          ),
      ],
    );
  }
}

/// Botão de ícone 48×48 (alvo de toque mínimo). [tooltip] é OBRIGATÓRIO
/// (rótulo de acessibilidade e dica na Web).
///
/// ```dart
/// AppIconButton(icon: Icons.close_rounded, tooltip: 'Fechar', onPressed: pop)
/// ```
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
    this.size = 24,
    this.filled = false,
    this.selected = false,
    this.selectedIcon,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? color;
  final double size;
  final bool filled;
  final bool selected;
  final IconData? selectedIcon;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppPressScale(
      enabled: onPressed != null,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        isSelected: selected,
        icon: Icon(icon, size: size),
        selectedIcon: selectedIcon == null ? null : Icon(selectedIcon, size: size),
        constraints: const BoxConstraints(minWidth: AppGeometry.minTarget, minHeight: AppGeometry.minTarget),
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppGeometry.minTarget),
          fixedSize: const Size.square(AppGeometry.minTarget),
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: color ?? (filled ? tk.onAccent : tk.text),
          backgroundColor: filled ? tk.accent : null,
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_tokens.dart';
import 'tokens/app_motion.dart';
import 'tokens/app_space.dart';
import 'tokens/app_type.dart';

/// Campo de texto do design system (§2.4 / §3.3).
///
/// * base em [TextField] + [InputDecoration] (mantém semântica, IME, seleção,
///   autofill e teclado da plataforma);
/// * **rótulo flutuante** (o rótulo sobe e o texto flutuante nunca fica abaixo
///   de 12,5 sp visuais) e **borda que anima em 120 ms** (`AppMotion.field`):
///   repouso `border` 1 px, foco `accentInk` 2 px, erro `dangerInk`;
/// * **erro inline**: ícone `error_outline` + mensagem (`dangerInk`) que
///   QUEBRA em várias linhas (nunca `…`), anunciada como região viva, com
///   **shake de 6 px / 160 ms** apenas quando o erro passa de nulo → não-nulo
///   (sem shake sob `disableAnimations`);
/// * `success` mostra um check verde no fim do campo (sem erro);
/// * `maxLength` exibe o contador tabular `n/max` abaixo do campo;
/// * altura mínima 56, raio [AppGeometry.fieldRadius]; preenchimento
///   `surfaceInset` no claro e `surface` no escuro.
///
/// ```dart
/// AppTextField(
///   controller: _email,
///   label: 'E-mail',
///   hint: 'voce@exemplo.com',
///   prefixIcon: Icons.mail_outline_rounded,
///   keyboardType: TextInputType.emailAddress,
///   errorText: _emailInvalido ? 'Informe um e-mail válido' : null,
/// )
/// ```
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.obscureText = false,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.success = false,
    this.semanticLabel,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Rótulo flutuante.
  final String? label;
  final String? hint;

  /// Texto de apoio sob o campo (some enquanto há erro).
  final String? helper;

  /// Mensagem de erro inline. `null` = sem erro.
  final String? errorText;
  final IconData? prefixIcon;

  /// Widget no fim do campo (ex.: botão de mostrar senha). Deve ter alvo >= 48.
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;

  /// Limite de caracteres; quando informado exibe o contador `n/max`.
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;

  /// Mostra o check verde de validação (ignorado quando há erro).
  final bool success;

  /// Rótulo de acessibilidade extra (somado ao rótulo visível).
  final String? semanticLabel;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> with SingleTickerProviderStateMixin {
  /// O rótulo é escalado por 0,75 ao flutuar; o estilo flutuante compensa para
  /// que o tamanho visual final seja >= [AppType.minimumFontSize].
  static const double _floatScale = 0.75;

  late final AnimationController _shake = AnimationController(vsync: this, duration: AppMotion.shake);
  TextEditingController? _ownController;
  FocusNode? _ownFocus;

  TextEditingController get _controller => widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    _focused = _focus.hasFocus;
  }

  void _onFocus() {
    if (_focused != _focus.hasFocus) setState(() => _focused = _focus.hasFocus);
  }

  @override
  void didUpdateWidget(AppTextField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
    if (old.errorText == null && widget.errorText != null && !AppMotion.reduced(context)) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    (widget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
    _ownFocus?.dispose();
    _ownController?.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final reduced = AppMotion.reduced(context);
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final fill = tk.isDark ? tk.surface : tk.surfaceInset;
    final borderColor = hasError
        ? tk.dangerInk
        : (_focused ? tk.accentInk : tk.border);
    final borderWidth = (_focused || hasError) ? 2.0 : 1.0;
    final labelColor = hasError ? tk.dangerInk : (_focused ? tk.accentInk : tk.textMuted);
    final textColor = widget.enabled ? tk.text : tk.textMuted;
    final radius = BorderRadius.circular(AppGeometry.fieldRadius);

    // O `InputDecorator` anima a cor do rótulo em 167 ms e não aceita duração;
    // com movimento reduzido o rótulo mantém a cor fixa (foco/erro seguem
    // sinalizados pela borda de 2 px, pelo ícone e pela mensagem).
    final labelStyle = AppType.body.copyWith(color: reduced ? tk.textMuted : labelColor);
    final floatingStyle = AppType.caption.copyWith(color: labelStyle.color).apply(fontSizeFactor: 1 / _floatScale);

    final trailing = <Widget>[
      if (widget.success && !hasError)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
          child: Semantics(
            label: 'Válido',
            child: Icon(Icons.check_circle_rounded, size: 22, color: tk.successInk),
          ),
        ),
      if (widget.suffix != null) widget.suffix!,
    ];

    final obscure = widget.obscureText;
    final field = TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      obscureText: obscure,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      textCapitalization: widget.textCapitalization,
      autofillHints: widget.autofillHints,
      maxLength: widget.maxLength,
      maxLines: obscure ? 1 : widget.maxLines,
      minLines: obscure ? null : widget.minLines,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      style: AppType.body.copyWith(color: textColor),
      cursorColor: tk.accentInk,
      // O contador é desenhado por nós (tabular, fora da caixa).
      buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => null,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: labelStyle,
        floatingLabelStyle: floatingStyle,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        hintText: widget.hint,
        hintStyle: AppType.body.copyWith(color: tk.textMuted),
        filled: false,
        isDense: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        constraints: const BoxConstraints(minHeight: AppGeometry.inputHeight),
        contentPadding: EdgeInsets.fromLTRB(
          widget.prefixIcon == null ? AppSpace.s16 : 0,
          AppSpace.s12,
          trailing.isEmpty ? AppSpace.s16 : 0,
          AppSpace.s12,
        ),
        prefixIcon: widget.prefixIcon == null
            ? null
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
                child: Icon(widget.prefixIcon, size: 22, color: labelColor),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: AppGeometry.minTarget),
        suffixIcon: trailing.isEmpty ? null : Row(mainAxisSize: MainAxisSize.min, children: trailing),
        suffixIconConstraints: const BoxConstraints(minWidth: AppSpace.s16, minHeight: AppGeometry.minTarget),
      ),
    );

    final boxDecoration = BoxDecoration(
      color: widget.enabled ? fill : fill.withValues(alpha: 0.6),
      borderRadius: radius,
    );
    final outline = BoxDecoration(
      borderRadius: radius,
      border: Border.all(color: borderColor, width: borderWidth),
    );
    // Borda desenhada em `foregroundDecoration`: a espessura anima sem mexer no
    // layout. Com movimento reduzido usa `Container` (nenhum ticker).
    Widget box = reduced
        ? Container(decoration: boxDecoration, foregroundDecoration: outline, child: field)
        : AnimatedContainer(
            duration: AppMotion.field,
            curve: AppMotion.fadeCurve,
            decoration: boxDecoration,
            foregroundDecoration: outline,
            child: field,
          );

    box = AnimatedBuilder(
      animation: _shake,
      child: box,
      builder: (context, child) {
        final t = _shake.value;
        final dx = math.sin(t * 4 * math.pi) * AppMotion.shakeOffset * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );

    if (widget.semanticLabel != null) {
      box = Semantics(label: widget.semanticLabel, child: box);
    }

    final message = hasError
        ? Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.error_outline_rounded, size: 18, color: tk.dangerInk),
                ),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: Text(widget.errorText!, style: AppType.bodySm.copyWith(color: tk.dangerInk)),
                ),
              ],
            ),
          )
        : (widget.helper == null
            ? null
            : Text(widget.helper!, style: AppType.bodySm.copyWith(color: tk.textMuted)));

    final max = widget.maxLength;
    final counter = max == null
        ? null
        : ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final n = _controller.text.characters.length;
              return Semantics(
                label: '$n de $max caracteres',
                excludeSemantics: true,
                child: Text(
                  '$n/$max',
                  style: AppType.tabular(AppType.caption).copyWith(color: n >= max ? tk.text : tk.textMuted),
                ),
              );
            },
          );

    final Widget below = (message == null && counter == null)
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsets.only(top: AppSpace.s8, left: AppSpace.s16, right: AppSpace.s16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: message ?? const SizedBox.shrink()),
                if (counter != null) ...[const SizedBox(width: AppSpace.s12), counter],
              ],
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        box,
        // `AnimatedSize` com duração zero reinicia a animação durante o layout
        // (assert do framework) — por isso, com movimento reduzido, nem entra.
        if (reduced)
          below
        else
          AnimatedSize(duration: AppMotion.field, alignment: Alignment.topCenter, child: below),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../app_tokens.dart';
import 'tokens/app_breakpoints.dart';
import 'tokens/app_space.dart';
import 'tokens/app_type.dart';

/// AppBar do app: título `AppType.title` (Jakarta 18/24) centralizado, que
/// QUEBRA em 2 linhas sob escala alta (nunca `…`), fundo do tema sem elevação.
///
/// ```dart
/// AppScaffold(appBar: AppAppBar(title: 'Detalhes do pedido', actions: [...]), body: ...)
/// ```
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.centerTitle = true,
    this.bottom,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
  });

  final String? title;

  /// Substitui o [title] (ex.: logo da marca).
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppBar(
      backgroundColor: backgroundColor ?? tk.background,
      foregroundColor: tk.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      actions: actions,
      bottom: bottom,
      title: titleWidget ??
          (title == null
              ? null
              : Semantics(
                  header: true,
                  child: Text(title!, maxLines: 2, textAlign: centerTitle ? TextAlign.center : TextAlign.start),
                )),
    );
  }
}

/// Rodapé fixo para o CTA da tela (1 CTA primário por tela): fundo `card`,
/// borda superior, `SafeArea`, margem lateral responsiva (16/20/24) e nota
/// opcional (caption, quebra de linha).
///
/// ```dart
/// AppScaffold(bottomNavigationBar: AppBottomBar(footnote: 'Pagamento protegido', child: AppButton(...)))
/// ```
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, required this.child, this.footnote, this.secondary});

  final Widget child;
  final String? footnote;

  /// Ação secundária (ex.: link) abaixo do CTA.
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tk.surfaceAt(1),
        border: Border(top: BorderSide(color: tk.border)),
        boxShadow: tk.elevation(1).isEmpty
            ? null
            : const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 12, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(margin, AppSpace.s12, margin, AppSpace.s12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              if (secondary != null) ...[const SizedBox(height: AppSpace.s4), secondary!],
              if (footnote != null) ...[
                const SizedBox(height: AppSpace.s8),
                Text(
                  footnote!,
                  textAlign: TextAlign.center,
                  style: AppType.caption.copyWith(color: tk.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

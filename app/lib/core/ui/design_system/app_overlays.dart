import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_tokens.dart';
import 'app_button.dart';
import 'tokens/app_motion.dart';
import 'tokens/app_space.dart';
import 'tokens/app_type.dart';

/// Barra de ações de rodapé compartilhada por [AppSheet] e [AppDialog].
///
/// Lado a lado quando cada botão tem >= 140 de largura e a escala de texto é
/// < 1,3; senão empilha (e inverte a ordem: a ação primária — a ÚLTIMA da lista
/// — vai para o topo, mais perto do polegar).
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.length == 1) return actions.single;
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return LayoutBuilder(
      builder: (context, constraints) {
        final each = (constraints.maxWidth - AppSpace.s12 * (actions.length - 1)) / actions.length;
        final sideBySide = each >= 140 && scale < 1.3;
        if (sideBySide) {
          return Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpace.s12),
                Expanded(child: actions[i]),
              ],
            ],
          );
        }
        final ordered = actions.reversed.toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < ordered.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpace.s12),
              ordered[i],
            ],
          ],
        );
      },
    );
  }
}

/// Fecha a rota atual com `Esc` (Web/desktop).
class _EscToClose extends StatelessWidget {
  const _EscToClose({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
      },
      child: Focus(autofocus: true, skipTraversal: true, child: child),
    );
  }
}

/// Bottom sheet padrão do app (§2.4 / §3.2): **um único** ponto de entrada.
///
/// * `AnimationStyle` global ([AppMotion.sheetStyle]; zero com
///   `disableAnimations`), scrim `tk.scrim`, raio de topo
///   [AppGeometry.sheetRadius], handle 4×36;
/// * cabeçalho (título [AppType.title] + subtítulo), **conteúdo rolável
///   internamente** e **rodapé de ações fixo** (botões [AppButton]; lado a lado
///   se couber, senão empilhados com a primária no topo);
/// * arrastar para fechar, `Esc` na Web, `SafeArea` e padding de teclado.
///
/// ```dart
/// final ok = await AppSheet.show<bool>(
///   context,
///   title: 'Filtrar',
///   subtitle: 'Escolha a categoria',
///   builder: (context) => const CategoryList(),
///   actions: [
///     AppButton(label: 'Aplicar', onPressed: () => Navigator.of(context).pop(true)),
///   ],
/// );
/// ```
abstract final class AppSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    String? title,
    String? subtitle,
    List<Widget>? actions,
    bool isDismissible = true,
    bool enableDrag = true,
    bool showHandle = true,
    bool useRootNavigator = true,
    double maxHeightFactor = 0.92,
    bool isScrollControlled = true,
  }) {
    final tk = context.tk;
    final media = MediaQuery.of(context);
    final reduced = AppMotion.reduced(context);
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: false,
      useSafeArea: false,
      barrierColor: tk.scrim,
      backgroundColor: tk.surfaceAt(8),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppGeometry.sheetRadius)),
      ),
      constraints: BoxConstraints(
        maxWidth: 640,
        maxHeight: media.size.height * maxHeightFactor.clamp(0.3, 1.0),
      ),
      sheetAnimationStyle: reduced ? AnimationStyle.noAnimation : AppMotion.sheetStyle,
      builder: (sheetContext) => _SheetBody(
        title: title,
        subtitle: subtitle,
        actions: actions,
        showHandle: showHandle,
        dismissible: isDismissible,
        builder: builder,
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.showHandle,
    required this.dismissible,
    required this.builder,
  });

  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showHandle;
  final bool dismissible;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final hasActions = actions != null && actions!.isNotEmpty;

    final header = (title != null || subtitle != null)
        ? Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.s20, AppSpace.s4, AppSpace.s20, AppSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Semantics(
                    header: true,
                    child: Text(title!, style: AppType.title.copyWith(color: tk.text)),
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpace.s4),
                  Text(subtitle!, style: AppType.bodySm.copyWith(color: tk.textMuted)),
                ],
              ],
            ),
          )
        : null;

    Widget sheet = Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        bottom: keyboard == 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHandle)
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s12, bottom: AppSpace.s12),
                  child: Center(
                    child: Container(
                      key: const ValueKey('app-sheet-handle'),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tk.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: AppSpace.s12),
            ?header,
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpace.s20, 0, AppSpace.s20, AppSpace.s12),
                child: builder(context),
              ),
            ),
            if (hasActions)
              DecoratedBox(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: tk.border.withValues(alpha: 0.6)))),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.s20, AppSpace.s12, AppSpace.s20, AppSpace.s12),
                  child: _ActionBar(actions: actions!),
                ),
              ),
          ],
        ),
      ),
    );

    sheet = Semantics(
      scopesRoute: true,
      namesRoute: title != null,
      explicitChildNodes: true,
      label: title,
      child: sheet,
    );
    return _EscToClose(enabled: dismissible, child: sheet);
  }
}

/// Diálogo padrão do app: scrim `tk.scrim`, raio [AppGeometry.cardRadius],
/// entra com fade + sobe 24 px (`AppMotion.sheetStyle`; instantâneo com
/// `disableAnimations`), `Esc` fecha na Web.
///
/// ```dart
/// final apagar = await AppDialog.confirm(
///   context,
///   title: 'Excluir endereço?',
///   message: 'Essa ação não pode ser desfeita.',
///   confirmLabel: 'Excluir',
///   destructive: true,
/// );
/// ```
abstract final class AppDialog {
  /// Mostra um diálogo. [actions] ficam fixas no rodapé (use [AppButton]; a
  /// ação primária é a última da lista).
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    String? message,
    Widget? content,
    List<Widget>? actions,
    bool barrierDismissible = true,
    bool useRootNavigator = true,
  }) {
    final tk = context.tk;
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: tk.scrim,
      barrierLabel: 'Fechar',
      useRootNavigator: useRootNavigator,
      animationStyle: AppMotion.reduced(context) ? AnimationStyle.noAnimation : AppMotion.sheetStyle,
      builder: (dialogContext) => _DialogBody(
        title: title,
        message: message,
        content: content,
        actions: actions,
        dismissible: barrierDismissible,
      ),
    );
  }

  /// Confirmação sim/não. Retorna `true` somente se o usuário confirmar
  /// (fechar o diálogo = `false`). [destructive] usa o botão vermelho.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Voltar',
    bool destructive = false,
  }) async {
    final result = await show<bool>(
      context,
      title: title,
      message: message,
      actions: [
        Builder(
          builder: (ctx) => AppButton(
            label: cancelLabel,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ),
        Builder(
          builder: (ctx) => AppButton(
            label: confirmLabel,
            variant: destructive ? AppButtonVariant.destructive : AppButtonVariant.primary,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ),
      ],
    );
    return result ?? false;
  }
}

class _DialogBody extends StatelessWidget {
  const _DialogBody({
    required this.title,
    required this.message,
    required this.content,
    required this.actions,
    required this.dismissible,
  });

  final String title;
  final String? message;
  final Widget? content;
  final List<Widget>? actions;
  final bool dismissible;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final hasActions = actions != null && actions!.isNotEmpty;

    Widget card = Dialog(
      backgroundColor: tk.surfaceAt(12),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s24, vertical: AppSpace.s24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppGeometry.cardRadius)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(title, style: AppType.title.copyWith(color: tk.text)),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: AppSpace.s12),
                        Text(message!, style: AppType.body.copyWith(color: tk.textMuted)),
                      ],
                      if (content != null) ...[const SizedBox(height: AppSpace.s16), content!],
                    ],
                  ),
                ),
              ),
              if (hasActions) ...[
                const SizedBox(height: AppSpace.s24),
                _ActionBar(actions: actions!),
              ],
            ],
          ),
        ),
      ),
    );

    card = Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: card,
    );

    // Sobe 24 px acompanhando a animação da rota (quando houver animação).
    final animation = ModalRoute.of(context)?.animation;
    if (animation != null && !AppMotion.reduced(context)) {
      final curved = CurvedAnimation(parent: animation, curve: AppMotion.sheetCurve);
      card = AnimatedBuilder(
        animation: curved,
        child: card,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - math.min(1.0, curved.value)) * AppMotion.sheetOffset),
          child: child,
        ),
      );
    }
    return _EscToClose(enabled: dismissible, child: card);
  }
}

/// Tipo semântico da [AppSnackbar].
enum AppSnackKind { info, success, warning, error }

/// Snackbar flutuante padrão (§2.4): raio 14, margem 16, ícone por tipo, cores
/// com contraste >= 4,5:1 ([AppTokens.onColor]), `liveRegion` (leitores de
/// tela anunciam). Esconde a anterior antes de mostrar a nova.
///
/// ```dart
/// AppSnackbar.show(context, 'Endereço salvo', kind: AppSnackKind.success);
/// AppSnackbar.show(
///   context,
///   'Pedido cancelado',
///   actionLabel: 'Desfazer',
///   onAction: _undo,
/// );
/// ```
abstract final class AppSnackbar {
  static const double radius = 14;

  /// Cor de fundo do tipo (exposta para testes de contraste).
  static Color background(AppTokens tk, AppSnackKind kind) => switch (kind) {
        AppSnackKind.info => tk.text,
        AppSnackKind.success => tk.successInk,
        AppSnackKind.warning => tk.warningInk,
        AppSnackKind.error => tk.dangerInk,
      };

  static IconData iconOf(AppSnackKind kind) => switch (kind) {
        AppSnackKind.info => Icons.info_outline_rounded,
        AppSnackKind.success => Icons.check_circle_outline_rounded,
        AppSnackKind.warning => Icons.warning_amber_rounded,
        AppSnackKind.error => Icons.error_outline_rounded,
      };

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context,
    String message, {
    AppSnackKind kind = AppSnackKind.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final tk = context.tk;
    final messenger = ScaffoldMessenger.of(context);
    final bg = background(tk, kind);
    final fg = AppTokens.onColor(bg);
    final wide = MediaQuery.sizeOf(context).width > 600;
    messenger.hideCurrentSnackBar();
    return messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        elevation: 4,
        margin: wide ? null : const EdgeInsets.all(AppSpace.s16),
        width: wide ? 480 : null,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
                label: actionLabel,
                textColor: fg,
                disabledTextColor: fg,
                onPressed: onAction,
              )
            : null,
        content: Semantics(
          liveRegion: true,
          container: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ExcludeSemantics(child: Icon(iconOf(kind), size: 22, color: fg)),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                  child: Text(message, style: AppType.bodySm.copyWith(color: fg)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

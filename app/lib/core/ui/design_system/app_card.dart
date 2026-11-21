import 'package:flutter/material.dart';

import '../app_tokens.dart';
import 'app_pressable.dart';
import 'tokens/app_breakpoints.dart';
import 'tokens/app_space.dart';
import 'tokens/app_type.dart';

/// Variantes de [AppCard] (§2.4).
enum AppCardVariant {
  /// Cartão com sombra de 2 camadas (claro) / elevação tonal (escuro).
  elevated,

  /// Cartão com borda de 1 px, sem sombra (compatível com o `AppCard` legado).
  outlined,

  /// Cartão "afundado" (`surface`), sem borda: agrupamentos discretos.
  tonal,

  /// UM elemento herói por bloco: raio 28, padding 20, sombra de nível 2.
  hero,
}

/// Cartão base do app. Substitui `Card`/`Container` com decoração manual.
///
/// * padding 16 (hero 20), raio 20 (hero 28);
/// * com [onTap]: escala 0,97 por mola, hover +4%, foco por teclado com anel de
///   2 px, cursor `click` (via [AppPressable]);
/// * no escuro a elevação é tonal (sem sombra).
///
/// ```dart
/// AppCard(variant: AppCardVariant.elevated, onTap: _open, child: Text('Pedido #12'))
/// ```
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.outlined,
    this.color,
    this.borderColor,
    this.padding,
    this.radius,
    this.onTap,
    this.onLongPress,
    this.margin,
    this.semanticLabel,
  });

  final Widget child;
  final AppCardVariant variant;

  /// Fundo (padrão: token da variante).
  final Color? color;
  final Color? borderColor;

  /// Padrão: 16 (hero: 20).
  final EdgeInsetsGeometry? padding;

  /// Padrão: 20 (hero: 28).
  final double? radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? margin;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final isHero = variant == AppCardVariant.hero;
    final r = radius ?? (isHero ? AppGeometry.heroRadius : AppGeometry.cardRadius);
    final borderRadius = BorderRadius.circular(r);
    final bg = color ??
        switch (variant) {
          AppCardVariant.tonal => tk.surface,
          AppCardVariant.hero => tk.surfaceAt(2),
          AppCardVariant.elevated => tk.surfaceAt(1),
          AppCardVariant.outlined => tk.card,
        };
    final showBorder = variant != AppCardVariant.tonal || borderColor != null;
    final defaultBorder = tk.isDark
        ? Colors.white.withValues(alpha: variant == AppCardVariant.hero ? 0.11 : 0.08)
        : tk.border;
    final shadows = switch (variant) {
      AppCardVariant.elevated => tk.elevation(1),
      AppCardVariant.hero => tk.elevation(2),
      _ => const <BoxShadow>[],
    };
    Widget box = DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: borderRadius,
        border: showBorder ? Border.all(color: borderColor ?? defaultBorder) : null,
        boxShadow: shadows,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(isHero ? AppSpace.cardLarge : AppSpace.card),
        child: child,
      ),
    );
    if (onTap != null || onLongPress != null) {
      box = AppPressable(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius,
        semanticLabel: semanticLabel,
        child: box,
      );
    }
    return margin == null ? box : Padding(padding: margin!, child: box);
  }
}

/// Linha de lista do app: *icon tile* 40×40 (ou widget) + título + subtítulo +
/// no máx. 1 elemento à direita. Altura mínima 56; título/subtítulo QUEBRAM
/// linha (nunca `…` em informação essencial).
///
/// ```dart
/// AppListTile(leadingIcon: Icons.wallet_rounded, title: 'Carteira', subtitle: 'Saldo e extrato', onTap: _open)
/// ```
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    this.leadingIcon,
    this.leading,
    this.leadingColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s8),
  });

  /// Ícone dentro do *icon tile* (40×40, raio 12, tinta suave do acento).
  final IconData? leadingIcon;

  /// Alternativa ao [leadingIcon] (ex.: `AppAvatar`).
  final Widget? leading;
  final Color? leadingColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Mostra uma seta discreta quando não há [trailing] e há [onTap].
  final bool showChevron;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final lead = leading ??
        (leadingIcon == null
            ? null
            : Container(
                width: AppGeometry.iconTileSize,
                height: AppGeometry.iconTileSize,
                decoration: BoxDecoration(
                  color: (leadingColor ?? tk.accent).withValues(alpha: tk.isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
                ),
                child: Icon(leadingIcon, size: 22, color: leadingColor ?? tk.accentInk),
              ));
    final end = trailing ??
        (showChevron && onTap != null
            ? Icon(Icons.chevron_right_rounded, color: tk.textMuted)
            : null);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppGeometry.itemMinHeight),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (lead != null) ...[lead, const SizedBox(width: AppSpace.s12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppType.bodyStrong.copyWith(color: tk.text)),
                  if (subtitle != null)
                    Text(subtitle!, style: AppType.bodySm.copyWith(color: tk.textMuted)),
                ],
              ),
            ),
            if (end != null) ...[const SizedBox(width: AppSpace.s12), end],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return AppPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
      scale: 0.985,
      child: row,
    );
  }
}

/// Seção: título (+ ação opcional) e conteúdo, com ritmo vertical de 24.
///
/// ```dart
/// AppSection(title: 'Próximos serviços', action: LinkButton(...), child: lista)
/// ```
class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.subtitle,
    this.padding = EdgeInsets.zero,
    this.spacing = AppSpace.s12,
  });

  final String title;
  final String? subtitle;

  /// Ação à direita do título (ex.: "Ver tudo").
  final Widget? action;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: AppType.title.copyWith(color: tk.text)),
                ),
              ),
              if (action != null) ...[const SizedBox(width: AppSpace.s8), action!],
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s4),
              child: Text(subtitle!, style: AppType.bodySm.copyWith(color: tk.textMuted)),
            ),
          SizedBox(height: spacing),
          child,
        ],
      ),
    );
  }
}

/// Rótulo/valor. Reflui em COLUNA quando a escala de fonte é alta (>= 1,3) ou
/// quando a largura é curta, em vez de cortar o valor.
///
/// ```dart
/// AppInfoRow(label: 'Prazo', value: 'Hoje, 14:00')
/// AppInfoRow(label: 'Total', valueWidget: AppPrice(value: 180))
/// ```
class AppInfoRow extends StatelessWidget {
  const AppInfoRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.icon,
    this.strong = false,
    this.stacked = false,
  }) : assert(value != null || valueWidget != null, 'Informe value ou valueWidget');

  final String label;
  final String? value;
  final Widget? valueWidget;
  final IconData? icon;

  /// Valor em destaque (peso 600).
  final bool strong;

  /// Força layout editorial empilhado (rótulo acima, valor em 100% da largura abaixo).
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final forceStack = stacked || context.layout.isLargeText;
    final labelW = Row(
      mainAxisSize: forceStack ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 17, color: tk.textMuted), const SizedBox(width: AppSpace.s8)],
        Flexible(
          child: Text(
            label,
            style: AppType.bodySm.copyWith(
              color: tk.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
        child: LayoutBuilder(
          builder: (context, c) {
            final isLongValue = (value?.length ?? 0) > 22;
            final column = forceStack || c.maxWidth < 290 || (c.maxWidth < 360 && isLongValue);
            final effectiveValueW = valueWidget ??
                Text(
                  value!,
                  textAlign: column ? TextAlign.start : TextAlign.end,
                  style: (strong ? AppType.bodyStrong : AppType.body).copyWith(color: tk.text),
                );
            if (column) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 16, color: tk.textMuted),
                        const SizedBox(width: AppSpace.s8),
                      ],
                      Expanded(
                        child: Text(
                          label,
                          style: AppType.bodySm.copyWith(
                            color: tk.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s4),
                  effectiveValueW,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(flex: 4, child: labelW),
                const SizedBox(width: AppSpace.s16),
                Flexible(
                  flex: 6,
                  child: Align(alignment: Alignment.centerRight, child: effectiveValueW),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../media_widgets.dart';
import '../../utils/format.dart';
import 'app_pressable.dart';
import 'tokens/app_motion.dart';
import 'tokens/app_space.dart';
import 'tokens/app_type.dart';

/// Tom semântico de chips/selos. Psicologia de cor (§2.3): verde = segurança /
/// dinheiro protegido · âmbar = atenção · vermelho SÓ para erro/risco real ·
/// azul = informação/profissional · laranja = ação/cliente.
enum AppTone { neutral, info, success, warning, danger, accent }

/// Par (fundo, texto) legível (>= 4,5:1) para um [AppTone].
extension AppToneColors on AppTone {
  (Color bg, Color fg) resolve(AppTokens tk) => switch (this) {
        AppTone.neutral => (tk.surface, tk.text),
        AppTone.info => (tk.infoSoft, tk.isDark ? tk.info : const Color(0xFF14509E)),
        AppTone.success => (tk.successSoft, tk.successInk),
        AppTone.warning => (tk.warningSoft, tk.warningInk),
        AppTone.danger => (tk.dangerSoft, tk.dangerInk),
        AppTone.accent => (tk.accentSoft, tk.accentInk),
      };
}

/// Selo de status (pílula). O rótulo QUEBRA em 2 linhas se faltar espaço (não
/// corta) e, ao mudar de rótulo/tom, faz *cross-fade* de 140 ms.
///
/// ```dart
/// AppStatusChip('Em andamento', tone: AppTone.info, icon: Icons.sync_rounded)
/// ```
class AppStatusChip extends StatelessWidget {
  const AppStatusChip(this.label, {super.key, this.tone = AppTone.info, this.icon, this.color, this.background});

  final String label;
  final AppTone tone;
  final IconData? icon;

  /// Sobrescritas legadas (cor do texto/ícone e fundo).
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final (toneBg, toneFg) = tone.resolve(tk);
    final fg = color ?? toneFg;
    final bg = background ?? (color != null ? color!.withValues(alpha: 0.12) : toneBg);
    final chip = Container(
      key: ValueKey('$label|${bg.toARGB32()}|${fg.toARGB32()}'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s4 + 1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppGeometry.pillRadius)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: AppSpace.s4)],
          Flexible(
            child: Text(label, style: AppType.caption.copyWith(fontWeight: FontWeight.w600, color: fg)),
          ),
        ],
      ),
    );
    return AnimatedSwitcher(
      duration: AppMotion.d(context, AppMotion.fade),
      switchInCurve: AppMotion.fadeCurve,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      child: chip,
    );
  }
}

/// Avatar do app (foto com cache instantâneo, iniciais de fallback, selo de
/// verificado). Tamanho por [radius]. Com [onTap] vira alvo de toque 48+.
///
/// ```dart
/// AppAvatar(name: 'Maria Souza', url: p.photoUrl, radius: 28, verified: true)
/// ```
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.url,
    this.radius = 24,
    this.verified = false,
    this.squircle = false,
    this.onTap,
  });

  final String name;
  final String? url;
  final double radius;
  final bool verified;
  final bool squircle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = InstantUserAvatar(url: url, name: name, radius: radius, verified: verified, isSquircle: squircle);
    if (onTap == null) return avatar;
    return AppPressable(
      onTap: onTap,
      semanticLabel: 'Foto de $name',
      borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: AppGeometry.minTarget, minHeight: AppGeometry.minTarget),
        child: Center(child: avatar),
      ),
    );
  }
}

/// Tamanho de [AppPrice].
enum AppPriceSize { xl, lg, sm }

/// Preço: figura tabular grande + símbolo da moeda menor (alinhado à base).
/// `AppPrice(value: 180)` → **R$** 180,00. Nunca é cortado nem encolhido.
///
/// ```dart
/// AppPrice(value: order.total, size: AppPriceSize.lg)
/// AppPrice.cents(18000, color: context.tk.successInk)
/// ```
class AppPrice extends StatelessWidget {
  const AppPrice({super.key, required this.value, this.size = AppPriceSize.sm, this.color, this.strikethrough = false});

  AppPrice.cents(int cents, {super.key, this.size = AppPriceSize.sm, this.color, this.strikethrough = false})
      : value = cents / 100;

  /// Valor em reais.
  final num value;
  final AppPriceSize size;
  final Color? color;
  final bool strikethrough;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final base = switch (size) {
      AppPriceSize.xl => AppType.figureXl,
      AppPriceSize.lg => AppType.figure,
      AppPriceSize.sm => AppType.figureSm,
    };
    final c = color ?? tk.text;
    final decoration = strikethrough ? TextDecoration.lineThrough : null;
    final full = brl(value);
    final negative = full.startsWith('-');
    final body = full.replaceFirst('-', '').replaceFirst('R\$', '').trim();
    // Moeda menor, mas nunca abaixo do mínimo absoluto (12,5 sp).
    final symbolSize = (base.fontSize! * 0.55).clamp(AppType.minimumFontSize, 20.0);
    return Semantics(
      label: full,
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            if (negative) TextSpan(text: '−', style: base.copyWith(color: c, decoration: decoration)),
            TextSpan(
              text: 'R\$ ',
              style: base.copyWith(fontSize: symbolSize, color: c, decoration: decoration, fontWeight: FontWeight.w700),
            ),
            TextSpan(text: body, style: base.copyWith(color: c, decoration: decoration)),
          ],
        ),
      ),
    );
  }
}

/// Avaliação por estrelas (exibição ou entrada). Entrada: alvos de 48×48 e
/// *pop* de 120 ms na estrela escolhida. [showValue] mostra a nota tabular.
///
/// ```dart
/// AppRating(value: 4.8, count: 132)
/// AppRating(value: nota, size: 32, onChanged: (v) => setState(() => nota = v.toDouble()))
/// ```
class AppRating extends StatelessWidget {
  const AppRating({
    super.key,
    required this.value,
    this.size = 18,
    this.count,
    this.onChanged,
    this.showValue = false,
  });

  final double value;
  final double size;
  final int? count;
  final ValueChanged<int>? onChanged;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final interactive = onChanged != null;
    final stars = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          _Star(
            filled: value >= i,
            half: value < i && value >= i - 0.5,
            size: size,
            interactive: interactive,
            color: value >= i - 0.5 ? tk.star : tk.border,
            onTap: interactive ? () => onChanged!(i) : null,
            semanticLabel: '$i ${i == 1 ? 'estrela' : 'estrelas'}',
          ),
      ],
    );
    if (!showValue && count == null) return stars;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        stars,
        const SizedBox(width: AppSpace.s8),
        if (showValue)
          Text(value.toStringAsFixed(1).replaceFirst('.', ','), style: AppType.tabular(AppType.bodyStrong).copyWith(color: tk.text)),
        if (count != null)
          Padding(
            padding: const EdgeInsets.only(left: AppSpace.s4),
            child: Text('($count)', style: AppType.tabular(AppType.bodySm).copyWith(color: tk.textMuted)),
          ),
      ],
    );
  }
}

class _Star extends StatefulWidget {
  const _Star({
    required this.filled,
    required this.half,
    required this.size,
    required this.interactive,
    required this.color,
    required this.onTap,
    required this.semanticLabel,
  });

  final bool filled;
  final bool half;
  final double size;
  final bool interactive;
  final Color color;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  State<_Star> createState() => _StarState();
}

class _StarState extends State<_Star> {
  double _scale = 1;

  void _pop() {
    if (AppMotion.reduced(context)) return;
    setState(() => _scale = 1.12);
    Future<void>.delayed(AppMotion.fadeShort, () {
      if (mounted) setState(() => _scale = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final icon = AnimatedScale(
      scale: _scale,
      duration: AppMotion.d(context, AppMotion.fadeShort),
      curve: Curves.easeOutBack,
      child: Icon(
        widget.filled ? Icons.star_rounded : (widget.half ? Icons.star_half_rounded : Icons.star_outline_rounded),
        size: widget.size,
        color: widget.color,
      ),
    );
    if (!widget.interactive) return icon;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _pop();
          widget.onTap?.call();
        },
        child: SizedBox(
          width: AppGeometry.minTarget,
          height: AppGeometry.minTarget,
          child: Center(child: icon),
        ),
      ),
    );
  }
}

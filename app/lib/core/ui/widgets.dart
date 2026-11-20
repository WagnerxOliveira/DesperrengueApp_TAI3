import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/app_failure.dart';
import '../utils/format.dart';
import 'design_system/design_system.dart';
import 'media_widgets.dart';

// FACHADA sobre o design system (v2.28.0): as assinaturas públicas abaixo são
// as MESMAS de antes (as telas existentes seguem compilando); por baixo, cada
// widget delega aos componentes `App*` de `design_system/`. Telas novas/migradas
// devem usar `App*` diretamente.
export 'design_system/design_system.dart' show AppCard, AppCardVariant;

/// Botão principal (pílula, largura total, com estado de carregamento).
/// Fachada de [AppButton] (primary).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.trailingArrow = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool trailingArrow;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      loading: loading,
      trailingArrow: trailingArrow,
    );
  }
}

/// Fachada de [AppButton] (secondary).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      variant: AppButtonVariant.secondary,
    );
  }
}

/// Link de texto (ex.: "Cancelar Pedido"). Alvo de toque >= 48.
class LinkButton extends StatelessWidget {
  const LinkButton({super.key, required this.label, required this.onPressed, this.color});

  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AppPressScale(
      enabled: onPressed != null,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(foregroundColor: color),
        child: Text(
          label,
          style: AppType.bodyStrong.copyWith(decoration: TextDecoration.underline, color: color),
        ),
      ),
    );
  }
}

/// Rodapé fixo para o CTA da tela. Fachada de [AppBottomBar].
class BottomBar extends StatelessWidget {
  const BottomBar({super.key, required this.child, this.footnote});

  final Widget child;
  final String? footnote;

  @override
  Widget build(BuildContext context) => AppBottomBar(footnote: footnote, child: child);
}

/// Selo de status. Fachada de [AppStatusChip].
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color, this.background, this.icon});

  final String label;
  final Color? color;
  final Color? background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) =>
      AppStatusChip(label, color: color, background: background, icon: icon);
}

enum BannerTone { info, success, warning, danger, security, promo }

class InfoBanner extends StatelessWidget {
  const InfoBanner(this.text, {super.key, this.tone = BannerTone.info, this.icon, this.title});

  final String text;
  final String? title;
  final BannerTone tone;
  final IconData? icon;

  (Color, Color, Color, IconData) _style(BuildContext context) {
    final tk = context.tk;
    return switch (tone) {
      BannerTone.info => (tk.infoSoft, tk.isDark ? tk.info : const Color(0xFF14509E), tk.info, Icons.info_outline),
      BannerTone.success => (tk.successSoft, tk.successInk, tk.success, Icons.check_circle_outline),
      BannerTone.warning => (tk.warningSoft, tk.warningInk, tk.warning, Icons.warning_amber_rounded),
      BannerTone.danger => (tk.dangerSoft, tk.dangerInk, tk.danger, Icons.error_outline),
      BannerTone.security => (tk.securitySoft, tk.isDark ? tk.security : const Color(0xFF1C5A60), tk.security, Icons.lock_outline),
      BannerTone.promo => (tk.clientSoft, tk.warningInk, tk.clientAccent, Icons.local_offer_outlined),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, accent, defaultIcon) = _style(context);
    return Container(
      padding: const EdgeInsets.all(AppSpace.s16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppGeometry.itemRadius)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, color: accent, size: 22),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s2),
                    child: Text(title!, style: AppType.bodyStrong.copyWith(color: fg)),
                  ),
                Text(text, style: AppType.bodySm.copyWith(color: fg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s8, bottom: AppSpace.s12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text, style: AppType.title.copyWith(color: context.tk.text)),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Barra de progresso do wizard ("1 de 3"). Fachada de [AppStepper].
class StepperBar extends StatelessWidget {
  const StepperBar({super.key, required this.total, required this.current});

  final int total;
  final int current; // 1-based

  @override
  Widget build(BuildContext context) => AppStepper(total: total, current: current);
}

/// Estrelas. Fachada de [AppRating].
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.value, this.size = 18, this.onChanged});

  final double value;
  final double size;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) => AppRating(value: value, size: size, onChanged: onChanged);
}

/// Anel de contagem regressiva (convites de 2h / 5 min).
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.remaining,
    required this.total,
    this.size = 190,
    this.caption,
    this.icon,
  });

  final Duration remaining;
  final Duration total;
  final double size;
  final String? caption;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final accent = tk.accent;
    final frac = total.inSeconds == 0
        ? 0.0
        : (remaining.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(frac, accent, accent.withValues(alpha: 0.18)),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Icon(icon, color: tk.accentInk, size: 26),
              Text(
                clock(remaining),
                style: AppType.figure.copyWith(fontSize: size * 0.2, color: tk.text),
              ),
              if (caption != null)
                Text(caption!, textAlign: TextAlign.center, style: AppType.caption.copyWith(color: tk.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color, this.track);

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * fraction, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color;
}

/// Ondas concêntricas pulsantes (radar de emergência).
class PulseRadar extends StatefulWidget {
  const PulseRadar({super.key, required this.child, this.size = 260});

  final Widget child;
  final double size;

  @override
  State<PulseRadar> createState() => _PulseRadarState();
}

class _PulseRadarState extends State<PulseRadar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations) {
      if (_c.isAnimating) _c.stop();
      _c.value = 0.35;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => CustomPaint(
            painter: _RadarPainter(_c.value, color),
            child: child,
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.width / 2;
    for (var i = 0; i < 4; i++) {
      final p = (t + i / 4) % 1.0;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: (1 - p) * 0.22);
      canvas.drawCircle(center, maxR * (0.3 + 0.7 * p), paint);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t;
}

/// Avatar. Fachada de [InstantUserAvatar] (via [AppAvatar]).
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.url, required this.name, this.radius = 24, this.verified = false});

  final String? url;
  final String name;
  final double radius;
  final bool verified;

  @override
  Widget build(BuildContext context) =>
      AppAvatar(url: url, name: name, radius: radius, verified: verified);
}

/// Carregamento sem forma previsível. Para listas/cartões use `AppSkeleton*`.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => AppLoading(message: message);
}

/// Erro com "Tentar novamente". Fachada de [AppErrorState].
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) =>
      AppErrorState(message: message, onRetry: onRetry, retryLabel: 'Tentar novamente');
}

/// Estado vazio. Fachada de [AppEmptyState].
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.subtitle, this.action});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) =>
      AppEmptyState(icon: icon, title: title, message: subtitle, action: action);
}

/// Logo textual usado nos app bars dos protótipos.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    final ink = context.tk.accentInk;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.handyman_rounded, color: ink, size: size + 2),
        const SizedBox(width: AppSpace.s8),
        Flexible(
          child: Text(
            'Desperrengue',
            style: AppType.title.copyWith(color: ink, fontSize: size, letterSpacing: -0.3),
          ),
        ),
      ],
    );
  }
}

/// Sino com contador de notificações (alvo 48×48; selo com *pop*).
class BellButton extends StatelessWidget {
  const BellButton({super.key, required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final label = count > 0 ? 'Notificações ($count não lidas)' : 'Notificações';
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none_rounded, size: 28),
            if (count > 0)
              Positioned(
                right: -4,
                top: -4,
                child: AnimatedSwitcher(
                  duration: AppMotion.d(context, AppMotion.fadeShort),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                    child: child,
                  ),
                  child: Container(
                    key: ValueKey(count),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: tk.danger, shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: AppType.tabular(AppType.caption).copyWith(
                        color: AppTokens.onColor(tk.danger),
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Confirmação padrão. Fachada de [AppDialog.confirm].
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Voltar',
  bool destructive = false,
}) {
  return AppDialog.confirm(
    context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    destructive: destructive,
  );
}

/// Aviso rápido. Fachada de [AppSnackbar.show].
void showSnack(BuildContext context, String message, {bool error = false}) {
  AppSnackbar.show(context, message, kind: error ? AppSnackKind.error : AppSnackKind.info);
}

/// Traduz erros do Supabase/Postgres em mensagens humanas e sanitizadas para o usuário.
String friendlyError(Object e) => humanizeError(e);

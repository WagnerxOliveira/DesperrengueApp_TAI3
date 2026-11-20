import 'package:flutter/material.dart';

import '../app_tokens.dart';
import 'app_button.dart';
import 'tokens/app_motion.dart';
import 'tokens/app_space.dart';
import 'tokens/app_type.dart';

/// Estado vazio com identidade: ilustração/ícone, título, texto e CTA.
///
/// ```dart
/// AppEmptyState(
///   icon: Icons.receipt_long_rounded,
///   title: 'Nenhum pedido ainda',
///   message: 'Quando você pedir um serviço, ele aparece aqui.',
///   actionLabel: 'Pedir um serviço',
///   onAction: _newRequest,
/// )
/// ```
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.icon,
    this.illustration,
    this.message,
    this.actionLabel,
    this.onAction,
    this.action,
    this.padding = const EdgeInsets.all(AppSpace.s32),
  });

  final String title;
  final IconData? icon;

  /// Ilustração vetorial/Lottie (substitui o [icon]).
  final Widget? illustration;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Ação customizada (tem prioridade sobre [actionLabel]).
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final art = illustration ??
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(color: tk.accentSoft, shape: BoxShape.circle),
          child: Icon(icon ?? Icons.inbox_rounded, size: 40, color: tk.accentInk),
        );
    final cta = action ??
        (actionLabel != null && onAction != null
            ? AppButton(label: actionLabel!, onPressed: onAction, expand: false)
            : null);
    return Center(
      child: SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: art),
              const SizedBox(height: AppSpace.s20),
              Text(title, textAlign: TextAlign.center, style: AppType.title.copyWith(color: tk.text)),
              if (message != null) ...[
                const SizedBox(height: AppSpace.s8),
                Text(message!, textAlign: TextAlign.center, style: AppType.body.copyWith(color: tk.textMuted)),
              ],
              if (cta != null) ...[const SizedBox(height: AppSpace.s24), cta],
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado de erro: ícone + mensagem humana + "Tentar de novo".
///
/// ```dart
/// AppErrorState(message: friendlyError(e), onRetry: _reload)
/// ```
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.title,
    this.retryLabel = 'Tentar de novo',
    this.icon = Icons.cloud_off_rounded,
    this.padding = const EdgeInsets.all(AppSpace.s32),
  });

  final String message;
  final String? title;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Center(
      child: SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: tk.surface, shape: BoxShape.circle),
                child: Icon(icon, size: 36, color: tk.textMuted),
              ),
              const SizedBox(height: AppSpace.s16),
              if (title != null) ...[
                Text(title!, textAlign: TextAlign.center, style: AppType.title.copyWith(color: tk.text)),
                const SizedBox(height: AppSpace.s8),
              ],
              Text(message, textAlign: TextAlign.center, style: AppType.body.copyWith(color: tk.textMuted)),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpace.s20),
                AppButton(
                  label: retryLabel,
                  onPressed: onRetry,
                  variant: AppButtonVariant.secondary,
                  expand: false,
                  compact: true,
                  icon: Icons.refresh_rounded,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Carregamento curto SEM forma previsível (spinner pequeno + legenda). Para
/// conteúdo com forma conhecida use os `AppSkeleton*`.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final reduced = AppMotion.reduced(context);
    return Center(
      child: Semantics(
        liveRegion: true,
        label: message ?? 'Carregando',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                value: reduced ? 0.72 : null,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpace.s16),
              Text(message!, textAlign: TextAlign.center, style: AppType.body.copyWith(color: tk.textMuted)),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- skeletons

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.animation, required super.child});

  /// `null` com movimento reduzido: blocos estáticos.
  final Animation<double>? animation;

  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.animation;

  static bool has(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ShimmerScope>() != null;

  @override
  bool updateShouldNotify(_ShimmerScope old) => old.animation != animation;
}

/// Fornece UM brilho (shimmer de 1,2 s, linear) a todos os blocos abaixo. Só
/// existe enquanto carrega (some junto com o esqueleto). Sem movimento quando
/// `disableAnimations`.
class AppShimmer extends StatefulWidget {
  const AppShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.skeleton);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _c.stop();
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
    return _ShimmerScope(
      animation: AppMotion.reduced(context) ? null : _c,
      child: widget.child,
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.t);

  final double t;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 3 - 1.5), 0, 0);
}

/// Bloco básico de esqueleto (retângulo arredondado). Use a MESMA geometria do
/// conteúdo final. Sem pai [AppShimmer], cria o próprio brilho.
///
/// ```dart
/// AppSkeleton(width: 120, height: 16)
/// ```
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({super.key, this.width, this.height = 16, this.radius = 8, this.circle = false});

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    if (!_ShimmerScope.has(context)) {
      return AppShimmer(child: AppSkeleton(width: width, height: height, radius: radius, circle: circle));
    }
    final tk = context.tk;
    final anim = _ShimmerScope.maybeOf(context);
    final shape = circle ? BoxShape.circle : BoxShape.rectangle;
    final br = circle ? null : BorderRadius.circular(radius);
    if (anim == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: tk.skeletonBase, shape: shape, borderRadius: br),
      );
    }
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: br,
          gradient: LinearGradient(
            colors: [tk.skeletonBase, tk.skeletonHighlight, tk.skeletonBase],
            stops: const [0.25, 0.5, 0.75],
            transform: _SlideGradient(anim.value),
          ),
        ),
      ),
    );
  }
}

/// Esqueleto de texto (N linhas; a última mais curta).
class AppSkeletonText extends StatelessWidget {
  const AppSkeletonText({super.key, this.lines = 3, this.lineHeight = 14, this.lastLineFactor = 0.6, this.spacing = AppSpace.s8});

  final int lines;
  final double lineHeight;
  final double lastLineFactor;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          i == lines - 1 && lines > 1
              ? FractionallySizedBox(widthFactor: lastLineFactor, child: AppSkeleton(height: lineHeight))
              : AppSkeleton(height: lineHeight),
        ],
      ],
    );
  }
}

/// Esqueleto de avatar circular.
class AppSkeletonAvatar extends StatelessWidget {
  const AppSkeletonAvatar({super.key, this.radius = 24});

  final double radius;

  @override
  Widget build(BuildContext context) => AppSkeleton(width: radius * 2, height: radius * 2, circle: true);
}

/// Esqueleto de cartão com a geometria do [AppCard] + linha de lista
/// (avatar/ícone 40–48 + 2 linhas de texto). Ajuste [height] para outros cartões.
///
/// ```dart
/// AppSkeletonCard()              // linha padrão (avatar + 2 linhas)
/// AppSkeletonCard(height: 120)   // bloco simples
/// ```
class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({super.key, this.height, this.avatar = true, this.lines = 2});

  /// `null` = linha de lista (avatar + [lines] linhas); valor = bloco liso.
  final double? height;
  final bool avatar;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final Widget body = height != null
        ? SizedBox(
            height: height,
            width: double.infinity,
            child: const Align(alignment: Alignment.topLeft, child: AppSkeleton(width: 140, height: 16)),
          )
        : Row(
            children: [
              if (avatar) ...[const AppSkeletonAvatar(radius: 24), const SizedBox(width: AppSpace.s12)],
              Expanded(child: AppSkeletonText(lines: lines, lastLineFactor: 0.55)),
            ],
          );
    return Semantics(
      label: 'Carregando',
      child: ExcludeSemantics(
        child: AppShimmer(
          child: Container(
            padding: const EdgeInsets.all(AppSpace.card),
            decoration: BoxDecoration(
              color: tk.card,
              borderRadius: BorderRadius.circular(AppGeometry.cardRadius),
              border: Border.all(color: tk.border),
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// Lista de esqueletos (substitui o spinner de lista).
///
/// ```dart
/// loading ? const AppSkeletonList(count: 4) : ListView(...)
/// ```
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({
    super.key,
    this.count = 4,
    this.itemBuilder,
    this.spacing = AppSpace.item,
    this.padding = const EdgeInsets.all(AppSpace.s16),
  });

  final int count;
  final WidgetBuilder? itemBuilder;
  final double spacing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carregando',
      liveRegion: true,
      child: ExcludeSemantics(
        child: AppShimmer(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: padding,
            child: Column(
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) SizedBox(height: spacing),
                  itemBuilder?.call(context) ?? const AppSkeletonCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Troca esqueleto→conteúdo com *fade-through* de 140 ms (sem salto).
///
/// ```dart
/// AppSkeletonSwitcher(loading: _loading, skeleton: const AppSkeletonList(), child: lista)
/// ```
class AppSkeletonSwitcher extends StatelessWidget {
  const AppSkeletonSwitcher({super.key, required this.loading, required this.skeleton, required this.child});

  final bool loading;
  final Widget skeleton;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.d(context, AppMotion.skeletonToContent),
      switchInCurve: AppMotion.fadeCurve,
      switchOutCurve: AppMotion.fadeCurve,
      child: loading
          ? KeyedSubtree(key: const ValueKey('skeleton'), child: skeleton)
          : KeyedSubtree(key: const ValueKey('content'), child: child),
    );
  }
}

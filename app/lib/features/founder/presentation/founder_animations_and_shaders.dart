import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../core/services/instant_image_cache_engine.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/utils/money.dart';

/// Paleta e tokens semânticos *Obsidian Sovereign Luxury* (v2.12.0).
///
/// Inspirada em Stripe Sigma, Linear, Bloomberg Terminal e Apple Design Awards:
/// - Fundo base grafite-obsidiana `#0E1218` (zero preto puro `#000000` para eliminar halation OLED);
/// - Elevação tonal em degraus (`#141A22` -> `#1A212B` -> `#232C39`) com borda de `1px` `#2B3646`;
/// - Contraste WCAG AAA (`15.6:1`) no texto primário `#EAEFF6` e AA+ no secundário `#A3AEC0`;
/// - Acentos executivos: Imperial Gold (`#F59E0B` -> `#FDE047`), Cyber Cyan (`#52B7C0`),
///   Solvency Emerald (`#3CCB8C`) e Crimson Alert (`#FF7A80`).
@immutable
class FounderSovereignTokens {
  const FounderSovereignTokens._();

  static const Color obsidianBackground = Color(0xFF0E1218);
  static const Color obsidianSurface = Color(0xFF141A22);
  static const Color obsidianCard = Color(0xFF1A212B);
  static const Color obsidianRaised = Color(0xFF232C39);
  static const Color crispBorder = Color(0xFF2B3646);

  static const Color primaryInk = Color(0xFFEAEFF6);
  static const Color mutedInk = Color(0xFFA3AEC0);

  static const Color imperialGold = Color(0xFFF59E0B);
  static const Color imperialGoldBright = Color(0xFFFDE047);
  static const Color imperialGoldSoft = Color(0xFF33260E);

  static const Color cyberCyan = Color(0xFF52B7C0);
  static const Color cyberCyanSoft = Color(0xFF123236);

  static const Color solvencyEmerald = Color(0xFF3CCB8C);
  static const Color solvencyEmeraldSoft = Color(0xFF113125);

  static const Color crimsonAlert = Color(0xFFFF7A80);
  static const Color crimsonAlertSoft = Color(0xFF38191E);

  static const Color royalIndigo = Color(0xFF74A7FF);
  static const Color warmAmber = Color(0xFFFF8F52);

  static const LinearGradient imperialGoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[imperialGoldBright, imperialGold],
  );

  static const LinearGradient cyberEmeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[cyberCyan, solvencyEmerald],
  );

  static const LinearGradient topSpecularGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: <double>[0.0, 0.12, 1.0],
    colors: <Color>[
      Color(0x14FFFFFF),
      Color(0x03FFFFFF),
      Color(0x00FFFFFF),
    ],
  );

  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextStyle monoMetric({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w800,
    Color color = primaryInk,
    double letterSpacing = -0.4,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: tabularFigures,
      height: 1.15,
    );
  }

  static ThemeData buildTheme() {
    final base = AppTheme.resolve(null, Brightness.dark);
    return base.copyWith(
      scaffoldBackgroundColor: obsidianBackground,
      canvasColor: obsidianBackground,
      cardColor: obsidianCard,
      dividerColor: crispBorder,
      extensions: <ThemeExtension<dynamic>>[AppTokens.dark],
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: imperialGold,
        onPrimary: const Color(0xFF111827),
        secondary: cyberCyan,
        surface: obsidianBackground,
        onSurface: primaryInk,
        error: crimsonAlert,
        outline: crispBorder,
      ),
    );
  }
}

/// Cartão executivo *Obsidian Sovereign Luxury* com reflexo especular nos `12%`
/// superiores (`topSpecularGradient`), borda de `1px` (`#2B3646`) e elevação tonal.
class FounderGlassCard extends StatefulWidget {
  const FounderGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 18,
    this.backgroundColor = FounderSovereignTokens.obsidianCard,
    this.borderColor,
    this.accentTopBarColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final Color backgroundColor;
  final Color? borderColor;
  final Color? accentTopBarColor;
  final VoidCallback? onTap;

  @override
  State<FounderGlassCard> createState() => _FounderGlassCardState();
}

class _FounderGlassCardState extends State<FounderGlassCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = widget.borderColor ??
        (_hovered
            ? FounderSovereignTokens.imperialGold.withValues(alpha: 0.55)
            : FounderSovereignTokens.crispBorder);
    final radius = BorderRadius.circular(widget.borderRadius);

    Widget content = Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: radius,
        border: Border.all(color: effectiveBorder, width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: FounderSovereignTokens.topSpecularGradient,
                  ),
                ),
              ),
            ),
            if (widget.accentTopBarColor != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 2.5,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          widget.accentTopBarColor!,
                          widget.accentTopBarColor!.withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: widget.padding,
              child: widget.child,
            ),
          ],
        ),
      ),
    );

    if (widget.onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: widget.onTap,
          child: content,
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: content,
    );
  }
}

/// Orquestrador de entrada escalonada (120 FPS) com curvas quínticas
/// `Cubic(0.22, 1.0, 0.36, 1.0)` e suporte a física `SpringSimulation`.
class StaggeredEntranceOrchestrator extends StatefulWidget {
  const StaggeredEntranceOrchestrator({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 620),
    this.useSpringPhysics = false,
  });

  final Widget Function(BuildContext context, Animation<double> masterAnimation)
      builder;
  final Duration duration;
  final bool useSpringPhysics;

  /// Intervalos canônicos de sobreposição (`0.0..0.45`, `0.12..0.65`, `0.25..1.0`).
  static const List<Interval> canonicalIntervals = <Interval>[
    Interval(0.00, 0.45, curve: Cubic(0.22, 1.0, 0.36, 1.0)),
    Interval(0.12, 0.65, curve: Cubic(0.22, 1.0, 0.36, 1.0)),
    Interval(0.25, 1.00, curve: Cubic(0.22, 1.0, 0.36, 1.0)),
  ];

  static Animation<double> intervalForStage(
    Animation<double> master,
    int stageIndex,
  ) {
    final idx = stageIndex.clamp(0, canonicalIntervals.length - 1);
    return CurvedAnimation(
      parent: master,
      curve: canonicalIntervals[idx],
    );
  }

  /// Calcula posição amortecida via `SpringSimulation` para medidores e agulhas.
  static double evaluateDampedSpring(
    double t, {
    double mass = 1.0,
    double stiffness = 180.0,
    double damping = 22.0,
  }) {
    final clamped = t.clamp(0.0, 1.0);
    final sim = SpringSimulation(
      SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
      0.0,
      1.0,
      0.0,
    );
    return sim.x(clamped * 0.65).clamp(0.0, 1.08);
  }

  @override
  State<StaggeredEntranceOrchestrator> createState() =>
      _StaggeredEntranceOrchestratorState();
}

class _StaggeredEntranceOrchestratorState
    extends State<StaggeredEntranceOrchestrator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    if (widget.useSpringPhysics) {
      final spring = SpringSimulation(
        const SpringDescription(mass: 1.0, stiffness: 185.0, damping: 23.0),
        0.0,
        1.0,
        0.0,
      );
      _controller.animateWith(spring);
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _controller);
  }
}

/// Item de revelação coreografada combinando `FadeTransition` + translação vertical
/// de `14px` + `ScaleTransition(0.97 -> 1.0)` sobre intervalos sobrepostos.
class StaggeredRevealItem extends StatelessWidget {
  const StaggeredRevealItem({
    super.key,
    required this.animation,
    required this.child,
    this.stageIndex = 0,
    this.verticalOffsetPx = 14.0,
    this.initialScale = 0.97,
  });

  final Animation<double> animation;
  final Widget child;
  final int stageIndex;
  final double verticalOffsetPx;
  final double initialScale;

  @override
  Widget build(BuildContext context) {
    final curved = StaggeredEntranceOrchestrator.intervalForStage(
      animation,
      stageIndex,
    );
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, staticChild) {
        final v = curved.value.clamp(0.0, 1.0);
        final dy = (1.0 - v) * verticalOffsetPx;
        final scale = initialScale + (1.0 - initialScale) * v;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: staticChild,
            ),
          ),
        );
      },
    );
  }
}

/// Wrapper de privacidade instantânea (`ClipRect` + `BackdropFilter` `sigma 16x16`)
/// acionado pelo botão de pânico/olho ou pela tecla `Space`.
class FounderPrivacyBlurWrap extends StatelessWidget {
  const FounderPrivacyBlurWrap({
    super.key,
    required this.privacyBlurActive,
    required this.child,
    this.borderRadius = 8,
  });

  final bool privacyBlurActive;
  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!privacyBlurActive) return child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[
          child,
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: FounderSovereignTokens.obsidianBackground
                      .withValues(alpha: 0.38),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Odômetro financeiro em centavos inteiros (`Money.formatBrl`) com algarismos
/// tabulares (`FontFeature.tabularFigures()`) para zero jitter horizontal e
/// desfoque instantâneo (`sigmaX: 16, sigmaY: 16`) quando `privacyBlurActive == true`.
class AnimatedMoneyOdometer extends StatelessWidget {
  const AnimatedMoneyOdometer({
    super.key,
    required this.cents,
    this.privacyBlurActive = false,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 520),
    this.maxLines = 1,
  });

  final int cents;
  final bool privacyBlurActive;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = (style ??
            FounderSovereignTokens.monoMetric(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ))
        .copyWith(fontFeatures: FounderSovereignTokens.tabularFigures);

    final odometer = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: cents.toDouble(), end: cents.toDouble()),
      duration: duration,
      curve: const Cubic(0.22, 1.0, 0.36, 1.0),
      builder: (context, animatedValue, _) {
        final currentCents = animatedValue.round();
        final formatted = '$prefix${Money.formatBrl(currentCents)}$suffix';
        return Text(
          formatted,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: effectiveStyle,
        );
      },
    );

    if (!privacyBlurActive) {
      return odometer;
    }

    return ClipRect(
      child: Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[
          Opacity(
            opacity: 0.85,
            child: odometer,
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                alignment: Alignment.centerLeft,
                color: FounderSovereignTokens.obsidianCard
                    .withValues(alpha: 0.45),
                child: Text(
                  '${prefix}R\$ •••••$suffix',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: effectiveStyle.copyWith(
                    color: FounderSovereignTokens.mutedInk,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Imagem Ultra-HD com calibração exata de DPR (`ResizeImage.resizeIfNeeded`),
/// `FilterQuality.high`, `isAntiAlias: true`, `gaplessPlayback: true` e hit L1
/// em `0 ms` via `InstantImageCacheEngine.instance.peekMemoryBytes`.
class FounderUltraHdImage extends StatefulWidget {
  const FounderUltraHdImage({
    super.key,
    required this.imageUrl,
    this.logicalWidth = 56,
    this.logicalHeight = 56,
    this.borderRadius = 12,
    this.fallbackLabel = 'DESP',
  });

  final String? imageUrl;
  final double logicalWidth;
  final double logicalHeight;
  final double borderRadius;
  final String fallbackLabel;

  @override
  State<FounderUltraHdImage> createState() => _FounderUltraHdImageState();
}

class _FounderUltraHdImageState extends State<FounderUltraHdImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _resolveBytes();
  }

  @override
  void didUpdateWidget(covariant FounderUltraHdImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolveBytes();
    }
  }

  void _resolveBytes() {
    final raw = widget.imageUrl?.trim() ?? '';
    if (raw.isEmpty) {
      _bytes = null;
      return;
    }
    final engine = InstantImageCacheEngine.instance;
    final syncHit = engine.peekMemoryBytes(raw);
    if (syncHit != null &&
        InstantImageCacheEngine.looksLikeValidEncodedImage(syncHit)) {
      _bytes = syncHit;
      return;
    }
    _bytes = null;
    engine.getOrFetchUrlBytes(raw).then((fetched) {
      if (!mounted || fetched == null) return;
      if (InstantImageCacheEngine.looksLikeValidEncodedImage(fetched)) {
        setState(() => _bytes = fetched);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.5);
    final cacheWidth = (widget.logicalWidth * dpr).round().clamp(32, 2048);
    final cacheHeight = (widget.logicalHeight * dpr).round().clamp(32, 2048);
    final radius = BorderRadius.circular(widget.borderRadius);

    final memBytes = _bytes;
    if (memBytes != null) {
      final provider = ResizeImage.resizeIfNeeded(
        cacheWidth,
        cacheHeight,
        MemoryImage(memBytes),
      );
      return ClipRRect(
        borderRadius: radius,
        child: Image(
          image: provider,
          width: widget.logicalWidth,
          height: widget.logicalHeight,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _buildVectorFallback(radius),
        ),
      );
    }

    return _buildVectorFallback(radius);
  }

  Widget _buildVectorFallback(BorderRadius radius) {
    return Container(
      width: widget.logicalWidth,
      height: widget.logicalHeight,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
        border: Border.all(
          color: FounderSovereignTokens.imperialGold.withValues(alpha: 0.45),
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.verified_rounded,
            size: math.min(widget.logicalWidth, widget.logicalHeight) * 0.36,
            color: FounderSovereignTokens.imperialGoldBright,
          ),
          if (widget.logicalHeight >= 44)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                widget.fallbackLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: FounderSovereignTokens.primaryInk,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Brasão vetorial soberano (`CustomPainter` + `RepaintBoundary`) do Founder Cockpit.
class FounderSovereignCrest extends StatelessWidget {
  const FounderSovereignCrest({
    super.key,
    this.size = 44,
    this.isSovereignCeo = true,
  });

  final double size;
  final bool isSovereignCeo;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _FounderSovereignCrestPainter(
            isSovereignCeo: isSovereignCeo,
          ),
        ),
      ),
    );
  }
}

class _FounderSovereignCrestPainter extends CustomPainter {
  const _FounderSovereignCrestPainter({required this.isSovereignCeo});

  final bool isSovereignCeo;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // 1. Hexagonal outer shield
    final shieldPath = Path();
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * (math.pi / 3);
      final pt = Offset(
        center.dx + radius * 0.94 * math.cos(angle),
        center.dy + radius * 0.94 * math.sin(angle),
      );
      if (i == 0) {
        shieldPath.moveTo(pt.dx, pt.dy);
      } else {
        shieldPath.lineTo(pt.dx, pt.dy);
      }
    }
    shieldPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isSovereignCeo
            ? const <Color>[
                Color(0xFF2B2110),
                Color(0xFF141A22),
              ]
            : const <Color>[
                Color(0xFF122C34),
                Color(0xFF141A22),
              ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(shieldPath, fillPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.045).clamp(1.2, 2.4)
      ..shader = (isSovereignCeo
              ? FounderSovereignTokens.imperialGoldGradient
              : FounderSovereignTokens.cyberEmeraldGradient)
          .createShader(Offset.zero & size);
    canvas.drawPath(shieldPath, borderPaint);

    // 2. Inner facet ring
    final innerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = (isSovereignCeo
              ? FounderSovereignTokens.imperialGoldBright
              : FounderSovereignTokens.cyberCyan)
          .withValues(alpha: 0.35);
    canvas.drawCircle(center, radius * 0.64, innerRingPaint);

    // 3. Sovereign Crown / Diamond Vector Emblem in center
    final crownPath = Path()
      ..moveTo(center.dx - radius * 0.38, center.dy + radius * 0.22)
      ..lineTo(center.dx - radius * 0.44, center.dy - radius * 0.16)
      ..lineTo(center.dx - radius * 0.18, center.dy + radius * 0.02)
      ..lineTo(center.dx, center.dy - radius * 0.34)
      ..lineTo(center.dx + radius * 0.18, center.dy + radius * 0.02)
      ..lineTo(center.dx + radius * 0.44, center.dy - radius * 0.16)
      ..lineTo(center.dx + radius * 0.38, center.dy + radius * 0.22)
      ..close();

    final crownPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = (isSovereignCeo
              ? FounderSovereignTokens.imperialGoldGradient
              : FounderSovereignTokens.cyberEmeraldGradient)
          .createShader(Offset.zero & size);
    canvas.drawPath(crownPath, crownPaint);

    // 4. Top jewel dot
    final jewelPaint = Paint()
      ..color = isSovereignCeo
          ? FounderSovereignTokens.imperialGoldBright
          : FounderSovereignTokens.cyberCyan;
    canvas.drawCircle(
      Offset(center.dx, center.dy - radius * 0.44),
      radius * 0.07,
      jewelPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FounderSovereignCrestPainter oldDelegate) {
    return oldDelegate.isSovereignCeo != isSovereignCeo;
  }
}

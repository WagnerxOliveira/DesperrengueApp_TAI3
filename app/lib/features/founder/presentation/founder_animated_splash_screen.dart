import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/boot/app_initialization_service.dart';
import 'founder_animations_and_shaders.dart';

/// Fase 2 da Inicialização Soberana a 120 FPS do `Desperrengue CEO`.
///
/// A Fase 1 é a splash nativa Android 12+ (`#07090D` + `@drawable/android12splash`).
/// Sem qualquer flash branco (`0 ms`), o Flutter assume e coreografa o símbolo
/// oficial *Sovereign Synonym*:
/// - `0%..55%`: Traçado progressivo (`PathMetrics.extractPath`) da **Casa-Escudo "D"**
///   em Ouro Imperial 24k + Check Central em Ciano-Platina + Halo Horológico;
/// - `38%..82%`: Cristalização da **Keystone Diamante de 4 Facetas** a 45° no ápice;
/// - `46%..94%`: Surgimento tipográfico executivo `Desperrengue` + selo `CEO · SOVEREIGN`
///   e partículas sutis de ouro 24k.
class FounderAnimatedSplashScreen extends StatefulWidget {
  const FounderAnimatedSplashScreen({
    super.key,
    required this.init,
    required this.onFinished,
    this.duration = const Duration(milliseconds: 1750),
  });

  final Future<BootResult> init;
  final void Function(BootResult result) onFinished;
  final Duration duration;

  /// Mesmo `#07090D` exato de `android:windowSplashScreenBackground` no flavor `founder`.
  static const Color obsidianSplashBg = Color(0xFF07090D);

  @override
  State<FounderAnimatedSplashScreen> createState() =>
      _FounderAnimatedSplashScreenState();
}

class _FounderAnimatedSplashScreenState
    extends State<FounderAnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _slowNetwork = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _runChoreography();
    _slowTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted && !_controller.isAnimating) {
        setState(() => _slowNetwork = true);
      }
    });
  }

  Future<void> _runChoreography() async {
    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final animFuture = reduceMotion
        ? Future<void>.sync(() => _controller.value = 1.0)
        : _controller.forward().orCancel.catchError((_) {});

    final results = await Future.wait<Object?>(<Future<Object?>>[
      animFuture,
      widget.init,
      if (reduceMotion) Future<void>.delayed(const Duration(milliseconds: 420)),
    ]);
    if (!mounted) return;
    widget.onFinished(results[1] as BootResult);
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  static double _segment(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey<String>('founder-animated-splash-screen'),
      backgroundColor: FounderAnimatedSplashScreen.obsidianSplashBg,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final strokeProgress =
                Curves.easeInOutCubic.transform(_segment(t, 0.0, 0.56));
            final diamondProgress =
                Curves.easeOutBack.transform(_segment(t, 0.36, 0.78));
            final glowWave = math.sin(_segment(t, 0.45, 0.90) * math.pi);
            final textProgress =
                Curves.easeOutCubic.transform(_segment(t, 0.46, 0.88));
            final shimmerProgress = _segment(t, 0.50, 1.0);

            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // Pré-aquecimento silencioso dos glifos vetoriais executivos
                const Positioned(
                  left: 0,
                  top: 0,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.01,
                      child: SizedBox(
                        width: 6,
                        height: 6,
                        child: FittedBox(
                          child: Row(
                            children: <Widget>[
                              FounderPrecisionIcon(FounderIconGlyph.navHome),
                              FounderPrecisionIcon(FounderIconGlyph.navFinance),
                              FounderPrecisionIcon(FounderIconGlyph.navOrders),
                              FounderPrecisionIcon(FounderIconGlyph.navPeople),
                              FounderPrecisionIcon(
                                FounderIconGlyph.shieldVerified,
                              ),
                              FounderPrecisionIcon(FounderIconGlyph.vaultLock),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Partículas sutis de poeira de Ouro 24k
                RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(300, 300),
                    painter: _SovereignGoldMotesPainter(shimmerProgress),
                  ),
                ),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: FounderSovereignTokens.imperialGold
                                .withValues(alpha: 0.24 * glowWave),
                            blurRadius: 46 * glowWave + 2,
                            spreadRadius: 5 * glowWave,
                          ),
                          BoxShadow(
                            color: FounderSovereignTokens.cyberCyan
                                .withValues(alpha: 0.14 * glowWave),
                            blurRadius: 28 * glowWave + 1,
                          ),
                        ],
                      ),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: const Size(118, 118),
                          painter: _AnimatedSovereignCrestStrokePainter(
                            strokeProgress: strokeProgress,
                            diamondProgress: diamondProgress.clamp(0.0, 1.15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Opacity(
                      opacity: textProgress,
                      child: Transform.scale(
                        scale: 0.94 + 0.06 * textProgress,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Text(
                              'Desperrengue',
                              style: TextStyle(
                                color: Color(0xFFF8FAFC),
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E170A),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: FounderSovereignTokens.imperialGold
                                      .withValues(alpha: 0.65),
                                ),
                              ),
                              child: const Text(
                                'PAINEL EXCLUSIVO DO CEO',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                  color:
                                      FounderSovereignTokens.imperialGoldBright,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    AnimatedOpacity(
                      opacity: _slowNetwork ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 260),
                      child: const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: FounderSovereignTokens.imperialGoldBright,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedSovereignCrestStrokePainter extends CustomPainter {
  const _AnimatedSovereignCrestStrokePainter({
    required this.strokeProgress,
    required this.diamondProgress,
  });

  final double strokeProgress;
  final double diamondProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final minSide = math.min(w, h);
    final center = Offset(w / 2, h / 2);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(minSide * 0.03),
      Radius.circular(minSide * 0.26),
    );

    // 1. Cofre Squircle Obsidian Carbon-Onyx
    final bgPaint = Paint()
      ..isAntiAlias = true
      ..shader = const RadialGradient(
        center: Alignment(-0.06, -0.08),
        radius: 0.78,
        colors: <Color>[
          Color(0xFF241B0B),
          Color(0xFF0C1018),
          Color(0xFF05070B),
        ],
        stops: <double>[0.0, 0.56, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, bgPaint);

    // Moldura progressiva em Ouro 24k
    final bezelPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = (minSide * 0.028).clamp(1.2, 2.6)
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          const Color(0xFFFDE047).withValues(alpha: strokeProgress),
          const Color(0xFFF59E0B).withValues(alpha: strokeProgress),
          const Color(0xFF92400E).withValues(alpha: strokeProgress),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, bezelPaint);

    // Halo horológico concêntrico
    if (strokeProgress > 0.15) {
      final haloAlpha = ((strokeProgress - 0.15) / 0.85).clamp(0.0, 1.0) * 0.26;
      canvas.drawCircle(
        center,
        minSide * 0.41,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = FounderSovereignTokens.imperialGoldBright
              .withValues(alpha: haloAlpha),
      );
    }

    // 2. Traçado progressivo da Casa-Escudo "D" + Check Ciano-Platina
    final boxSize = minSide * 0.58;
    final left = center.dx - boxSize / 2;
    final top = center.dy - boxSize / 2;

    canvas.save();
    canvas.translate(left, top);

    double px(double nx) => (nx + 0.012) * boxSize;
    double py(double ny) => (ny + 0.068) * boxSize;

    final dHousePath = Path()
      ..moveTo(px(0.21), py(0.595))
      ..lineTo(px(0.21), py(0.84))
      ..quadraticBezierTo(px(0.21), py(0.91), px(0.28), py(0.91))
      ..lineTo(px(0.49), py(0.91))
      ..arcToPoint(
        Offset(px(0.7375), py(0.3125)),
        radius: Radius.circular(boxSize * 0.35),
        largeArc: false,
        clockwise: false,
      )
      ..lineTo(px(0.555), py(0.130))
      ..quadraticBezierTo(px(0.490), py(0.065), px(0.425), py(0.130))
      ..lineTo(px(0.105), py(0.450));

    final dProgress = (strokeProgress / 0.76).clamp(0.0, 1.0);
    if (dProgress > 0) {
      final dPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = boxSize * 0.130
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFFBEB),
            Color(0xFFFDE047),
            Color(0xFFF59E0B),
            Color(0xFFD97706),
          ],
          stops: <double>[0.0, 0.28, 0.72, 1.0],
        ).createShader(Offset.zero & Size.square(boxSize));
      canvas.drawPath(_extractSubPath(dHousePath, dProgress), dPaint);
    }

    // Keystone Diamante Soberano de 4 Facetas no ápice
    if (diamondProgress > 0.01) {
      final dCx = px(0.490);
      final dCy = py(-0.094);
      final dSpan = boxSize * 0.088 * diamondProgress;
      final pTop = Offset(dCx, dCy - dSpan);
      final pRight = Offset(dCx + dSpan, dCy);
      final pBottom = Offset(dCx, dCy + dSpan);
      final pLeft = Offset(dCx - dSpan, dCy);
      final pMid = Offset(dCx, dCy);

      void drawFacet(Offset a, Offset b, Color color) {
        final p = Path()
          ..moveTo(pMid.dx, pMid.dy)
          ..lineTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..close();
        canvas.drawPath(
          p,
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.fill
            ..color = color.withValues(alpha: diamondProgress.clamp(0.0, 1.0)),
        );
      }

      drawFacet(pLeft, pTop, const Color(0xFFFFFBEB));
      drawFacet(pTop, pRight, const Color(0xFFFDE047));
      drawFacet(pBottom, pLeft, const Color(0xFFFACC15));
      drawFacet(pRight, pBottom, const Color(0xFFD97706));
    }

    // Check Central Ciano-Platina
    final checkProgress = ((strokeProgress - 0.50) / 0.50).clamp(0.0, 1.0);
    if (checkProgress > 0) {
      final checkPath = Path()
        ..moveTo(px(0.380), py(0.555))
        ..lineTo(px(0.470), py(0.645))
        ..lineTo(px(0.625), py(0.455));

      final checkPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = boxSize * 0.122
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: <Color>[
            Color(0xFF0891B2),
            Color(0xFF06B6D4),
            Color(0xFF67E8F9),
            Color(0xFFECFEFF),
          ],
          stops: <double>[0.0, 0.35, 0.75, 1.0],
        ).createShader(Rect.fromLTRB(px(0.35), py(0.44), px(0.65), py(0.66)));
      canvas.drawPath(_extractSubPath(checkPath, checkProgress), checkPaint);
    }

    canvas.restore();
  }

  static Path _extractSubPath(Path fullPath, double progress) {
    if (progress >= 1.0) return fullPath;
    final out = Path();
    for (final metric in fullPath.computeMetrics()) {
      out.addPath(metric.extractPath(0, metric.length * progress), Offset.zero);
    }
    return out;
  }

  @override
  bool shouldRepaint(covariant _AnimatedSovereignCrestStrokePainter old) =>
      old.strokeProgress != strokeProgress ||
      old.diamondProgress != diamondProgress;
}

class _SovereignGoldMotesPainter extends CustomPainter {
  const _SovereignGoldMotesPainter(this.t);

  final double t;

  static const List<(double angle, double radius, Color color)> _motes =
      <(double, double, Color)>[
    (0.35, 92, Color(0xFFFDE047)),
    (1.18, 108, Color(0xFF67E8F9)),
    (2.05, 96, Color(0xFFF59E0B)),
    (2.92, 112, Color(0xFFFDE047)),
    (3.78, 98, Color(0xFF67E8F9)),
    (4.65, 110, Color(0xFFF59E0B)),
    (5.48, 94, Color(0xFFFFFBEB)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final center = Offset(size.width / 2, size.height / 2 - 24);
    final ease = Curves.easeOutCubic.transform(t);
    final opacity = (1.0 - t) * 0.72;
    for (final (angle, dist, color) in _motes) {
      final r = 38 + (dist - 38) * ease;
      final pt = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      canvas.drawCircle(
        pt,
        2.4 * (1.0 - 0.35 * t),
        Paint()..color = color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SovereignGoldMotesPainter old) => old.t != t;
}

/// Portão de Inicialização Soberana do `Desperrengue CEO`: roda [AppInitializationService]
/// concorrentemente à animação 120 FPS e faz transição suave (`FadeTransition`) para [readyChild].
class FounderBootGate extends StatefulWidget {
  const FounderBootGate({
    super.key,
    required this.service,
    required this.readyChild,
    this.splashDuration = const Duration(milliseconds: 1750),
  });

  final AppInitializationService service;
  final Widget readyChild;
  final Duration splashDuration;

  @override
  State<FounderBootGate> createState() => _FounderBootGateState();
}

class _FounderBootGateState extends State<FounderBootGate> {
  late Future<BootResult> _initFuture = widget.service.run();
  BootResult? _bootResult;
  int _attemptKey = 0;

  void _retryBoot() {
    setState(() {
      _attemptKey++;
      _bootResult = null;
      _initFuture = widget.service.run();
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _bootResult;
    Widget current;
    if (result == null) {
      current = FounderAnimatedSplashScreen(
        key: ValueKey<String>('founder-splash-$_attemptKey'),
        init: _initFuture,
        duration: widget.splashDuration,
        onFinished: (r) => setState(() => _bootResult = r),
      );
    } else if (result.backendReady) {
      current = KeyedSubtree(
        key: const ValueKey<String>('founder-boot-ready'),
        child: widget.readyChild,
      );
    } else {
      const errMsg =
          'Não foi possível inicializar o canal criptográfico local. Verifique sua conexão e tente novamente.';
      current = Scaffold(
        key: const ValueKey<String>('founder-boot-failed'),
        backgroundColor: FounderSovereignTokens.obsidianBackground,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: FounderGlassCard(
                  accentTopBarColor: FounderSovereignTokens.crimsonAlert,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const FounderSovereignCrest(size: 56),
                      const SizedBox(height: 16),
                      Text(
                        'Conexão Segura Indisponível',
                        textAlign: TextAlign.center,
                        style: FounderSovereignTokens.monoMetric(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errMsg,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: FounderSovereignTokens.mutedInk,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _retryBoot,
                          icon: const FounderPrecisionIcon(
                            FounderIconGlyph.refreshArc,
                            size: 17,
                            color: Color(0xFF0B0E13),
                            accentColor: Color(0xFF0B0E13),
                            duotoneAlpha: 0.14,
                          ),
                          label: const Text('Reconectar ao Kernel Soberano'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: current,
    );
  }
}

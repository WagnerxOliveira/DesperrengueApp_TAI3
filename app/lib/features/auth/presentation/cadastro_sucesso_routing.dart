import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/profile_service.dart';
import '../../../core/services/welcome_cinema_tracker.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/desperrengue_brand_logo.dart';
import 'auth_gate.dart';

class CadastroSucessoRoutingScreen extends StatefulWidget {
  const CadastroSucessoRoutingScreen({super.key});

  @override
  State<CadastroSucessoRoutingScreen> createState() =>
      _CadastroSucessoRoutingScreenState();
}

class _CadastroSucessoRoutingScreenState
    extends State<CadastroSucessoRoutingScreen>
    with SingleTickerProviderStateMixin {
  static const Color _quietLuxuryNavy = DesperrengueBrandLogoPainter.navyDeep;
  static const Color _brandOrangeAccent =
      DesperrengueBrandLogoPainter.brandOrange;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
      animationBehavior: AnimationBehavior.preserve,
    )..forward();
    _processarTransicaoSessao();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String? _currentAuthUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// Ponte cinematográfica O(1) (480ms) sem clarão branco antes do Welcome Cinema,
  /// alinhada ao eixo óptico do Ato I para formar um único plano-sequência contínuo.
  Future<void> _processarTransicaoSessao() async {
    await WelcomeCinemaTracker.armForFreshRegistration(_currentAuthUserId());
    try {
      unawaited(
        ProfileService().fetchCurrent().then<void>((_) {}, onError: (_) {}),
      );
    } catch (_) {
      // Ambiente de teste sem Supabase inicializado.
    }
    await Future.delayed(const Duration(milliseconds: 480));

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      AppRoute<void>(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AppMotion.reduced(context);
    final dark = AppTokens.dark;
    final emerald = dark.success;
    final emeraldInk = dark.successInk;
    final warmGold = dark.star;

    return PopScope(
      canPop: false,
      child: AppScaffold(
        backgroundColor: _quietLuxuryNavy,
        body: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final t = reduceMotion
                ? 1.0
                : Curves.easeOutCubic.transform(
                    _pulseController.value.clamp(0.0, 1.0),
                  );
            final breathe = reduceMotion ? 0.5 : math.sin(t * math.pi);
            final logoScale = reduceMotion ? 1.0 : (0.94 + 0.06 * t);

            return Stack(
              fit: StackFit.expand,
              children: [
                // Halo radial esmeralda/dourado pulsante no eixo óptico do Ato I
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _CinematicBridgeHaloPainter(
                      progress: t,
                      pulse: breathe,
                      emerald: emerald,
                      warmGold: warmGold,
                      brandOrange: _brandOrangeAccent,
                      navy: _quietLuxuryNavy,
                    ),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s24,
                        vertical: AppSpace.s16,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            key: const Key('cadastro-sucesso-emerald-seal'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.s16,
                              vertical: AppSpace.s8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  emerald.withValues(alpha: 0.20),
                                  warmGold.withValues(alpha: 0.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppGeometry.pillRadius,
                              ),
                              border: Border.all(
                                color: Color.lerp(
                                  emerald,
                                  warmGold,
                                  0.25 * breathe,
                                )!.withValues(alpha: 0.55),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: emerald.withValues(
                                    alpha: 0.16 + 0.10 * breathe,
                                  ),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  color: emerald,
                                  size: 18,
                                ),
                                const SizedBox(width: AppSpace.s8),
                                Flexible(
                                  child: Text(
                                    'Cadastro confirmado!',
                                    textAlign: TextAlign.center,
                                    style: AppType.bodySm.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: emeraldInk,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpace.s24),
                          // Monograma oficial no eixo óptico central do Ato I
                          Transform.scale(
                            scale: logoScale,
                            child: Container(
                              padding: const EdgeInsets.all(AppSpace.s12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _quietLuxuryNavy.withValues(alpha: 0.78),
                                border: Border.all(
                                  color: Color.lerp(
                                    emerald,
                                    _brandOrangeAccent,
                                    t,
                                  )!.withValues(alpha: 0.52),
                                  width: 1.6,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: emerald.withValues(
                                      alpha: 0.18 * (1.0 - 0.3 * t),
                                    ),
                                    blurRadius: 28,
                                  ),
                                  BoxShadow(
                                    color: warmGold.withValues(
                                      alpha: 0.22 * t,
                                    ),
                                    blurRadius: 32,
                                  ),
                                ],
                              ),
                              child: const DesperrengueBrandLogo(
                                size: 74,
                                variant:
                                    DesperrengueLogoVariant.quietLuxuryNavy,
                                borderRadius: AppGeometry.pillRadius,
                                showShadow: false,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpace.s24),
                          Text(
                            'Preparando sua apresentação...',
                            textAlign: TextAlign.center,
                            style: AppType.bodyStrong.copyWith(
                              color: dark.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CinematicBridgeHaloPainter extends CustomPainter {
  const _CinematicBridgeHaloPainter({
    required this.progress,
    required this.pulse,
    required this.emerald,
    required this.warmGold,
    required this.brandOrange,
    required this.navy,
  });

  final double progress;
  final double pulse;
  final Color emerald;
  final Color warmGold;
  final Color brandOrange;
  final Color navy;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.48);
    final outerRadius = size.shortestSide * (0.64 + 0.06 * pulse);
    final innerRadius = size.shortestSide * (0.36 + 0.05 * progress);

    final outerHalo = Paint()
      ..shader = RadialGradient(
        colors: [
          emerald.withValues(alpha: 0.18 + 0.06 * pulse),
          warmGold.withValues(alpha: 0.10 * progress),
          navy.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));
    canvas.drawCircle(center, outerRadius, outerHalo);

    final innerHalo = Paint()
      ..shader = RadialGradient(
        colors: [
          brandOrange.withValues(alpha: 0.16 * progress),
          emerald.withValues(alpha: 0.12),
          navy.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: innerRadius));
    canvas.drawCircle(center, innerRadius, innerHalo);
  }

  @override
  bool shouldRepaint(covariant _CinematicBridgeHaloPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.pulse != pulse;
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/profile_service.dart';
import '../../../core/services/welcome_cinema_tracker.dart';
import '../../../core/ui/app_scaffold.dart';
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
  static const Color _quietLuxuryNavy = Color(0xFF0F172A);
  static const Color _emeraldAccent = Color(0xFF10B981);
  static const Color _warmGoldAccent = Color(0xFFFFB020);
  static const Color _brandOrangeAccent = Color(0xFFFF6D00);

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
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AuthGate(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
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
                    ),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 16.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            key: const Key('cadastro-sucesso-emerald-seal'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _emeraldAccent.withValues(alpha: 0.20),
                                  _warmGoldAccent.withValues(alpha: 0.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Color.lerp(
                                  _emeraldAccent,
                                  _warmGoldAccent,
                                  0.25 * breathe,
                                )!.withValues(alpha: 0.55),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _emeraldAccent.withValues(
                                    alpha: 0.16 + 0.10 * breathe,
                                  ),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  color: _emeraldAccent,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Cadastro confirmado!',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF6EE7B7),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          // Monograma oficial no eixo óptico central do Ato I
                          Transform.scale(
                            scale: logoScale,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _quietLuxuryNavy.withValues(alpha: 0.78),
                                border: Border.all(
                                  color: Color.lerp(
                                    _emeraldAccent,
                                    _brandOrangeAccent,
                                    t,
                                  )!.withValues(alpha: 0.52),
                                  width: 1.6,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _emeraldAccent.withValues(
                                      alpha: 0.18 * (1.0 - 0.3 * t),
                                    ),
                                    blurRadius: 28,
                                  ),
                                  BoxShadow(
                                    color: _warmGoldAccent.withValues(
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
                                borderRadius: 999,
                                showShadow: false,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Preparando sua apresentação...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFCBD5E1),
                              letterSpacing: -0.1,
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
  });

  final double progress;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.48);
    final outerRadius = size.shortestSide * (0.64 + 0.06 * pulse);
    final innerRadius = size.shortestSide * (0.36 + 0.05 * progress);

    final outerHalo = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF10B981).withValues(alpha: 0.18 + 0.06 * pulse),
          const Color(0xFFFFB020).withValues(alpha: 0.10 * progress),
          const Color(0xFF0F172A).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));
    canvas.drawCircle(center, outerRadius, outerHalo);

    final innerHalo = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF6D00).withValues(alpha: 0.16 * progress),
          const Color(0xFF10B981).withValues(alpha: 0.12),
          const Color(0xFF0F172A).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: innerRadius));
    canvas.drawCircle(center, innerRadius, innerHalo);
  }

  @override
  bool shouldRepaint(covariant _CinematicBridgeHaloPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.pulse != pulse;
}

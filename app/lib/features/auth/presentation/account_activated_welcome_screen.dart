import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../client/presentation/widgets/kyc_onboarding_chrome.dart';

/// Tela de **boas-vindas após a ativação da conta** (Cliente e Profissional).
///
/// Aparece quando o usuário toca em "Confirmar e Ativar Minha Conta" no e-mail e
/// volta ao app. É a recompensa emocional do cadastro: uma sequência coreografada,
/// em uma única linha do tempo (1 `AnimationController`, 60/120 FPS, zero rebuild
/// por frame — o desenho vive num `CustomPainter` isolado por `RepaintBoundary`):
///
///  1. um anel safira se desenha em volta do selo (0 → 34%);
///  2. o selo esmeralda "salta" com mola e o check é traçado à mão (20 → 62%);
///  3. ondas de choque + explosão de partículas deterministas (42 → 95%);
///  4. título, subtítulo, benefícios e CTA entram em cascata (50 → 90%).
///
/// Respeita "reduzir movimento" (estado final imediato) e `textScale` até 1,5x.
class AccountActivatedWelcomeScreen extends StatefulWidget {
  const AccountActivatedWelcomeScreen({
    super.key,
    required this.profile,
    required this.mode,
    required this.onContinue,
  });

  final UserProfile profile;
  final UserMode mode;
  final VoidCallback onContinue;

  @override
  State<AccountActivatedWelcomeScreen> createState() =>
      _AccountActivatedWelcomeScreenState();
}

class _AccountActivatedWelcomeScreenState
    extends State<AccountActivatedWelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _total = Duration(milliseconds: 3800);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _total,
  );
  late final List<_Particle> _particles = _buildParticles();

  bool _started = false;
  bool _hapticDiscDone = false;
  bool _hapticCheckDone = false;

  static List<_Particle> _buildParticles() {
    final rnd = math.Random(2026);
    const goldenAngle = 2.399963229728653; // distribuição uniforme sem "raios"
    return List<_Particle>.generate(38, (i) {
      return _Particle(
        angle: i * goldenAngle + rnd.nextDouble() * 0.35,
        travel: 0.9 + rnd.nextDouble() * 1.35,
        size: 2.2 + rnd.nextDouble() * 3.6,
        colorIndex: i,
        shape: i % 3,
        spin: (rnd.nextDouble() - 0.5) * 6.0,
        delay: rnd.nextDouble() * 0.12,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _c.addListener(_hapticTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _c.value = 1.0;
    } else {
      _c.forward(from: 0.0);
    }
  }

  void _hapticTick() {
    final v = _c.value;
    if (!_hapticDiscDone && v >= 0.36) {
      _hapticDiscDone = true;
      HapticFeedback.mediumImpact();
    }
    if (!_hapticCheckDone && v >= 0.56) {
      _hapticCheckDone = true;
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _c.removeListener(_hapticTick);
    _c.dispose();
    super.dispose();
  }

  /// Entrada em cascata (fade + deslocamento) dentro de [start, end] da timeline.
  Widget _reveal({
    required double start,
    required double end,
    required Widget child,
    double dy = 18,
  }) {
    return AnimatedBuilder(
      animation: _c,
      child: child,
      builder: (context, w) {
        final t = Curves.easeOutCubic.transform(_seg(_c.value, start, end));
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * dy), child: w),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.onboarding(Theme.of(context).brightness),
      child: Builder(builder: _buildScaffold),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    final isProvider = widget.mode == UserMode.provider;
    final firstName = widget.profile.firstName;
    final greeting =
        firstName == 'você' ? 'Boas-vindas!' : 'Boas-vindas, $firstName!';
    final validUntil = _formatDate(widget.profile.effectiveKycExpiresAt);

    final benefits = isProvider
        ? <_Benefit>[
            const _Benefit(
              Icons.verified_user_rounded,
              'Perfil verificado',
              'Identidade, documento e antecedentes aprovados.',
            ),
            const _Benefit(
              Icons.payments_rounded,
              'Repasse seguro',
              'Você recebe 85% da mão de obra após a conclusão confirmada por PIN.',
            ),
            _Benefit(
              Icons.event_repeat_rounded,
              'Segurança válida até $validUntil',
              'Avisaremos por e-mail antes da renovação de 90 dias.',
            ),
          ]
        : <_Benefit>[
            const _Benefit(
              Icons.verified_user_rounded,
              'Identidade verificada',
              'Biometria, documento e certidão da Polícia Federal conferidos.',
            ),
            const _Benefit(
              Icons.lock_rounded,
              'Pagamento protegido',
              'Seu dinheiro fica em custódia até você confirmar o serviço com o PIN.',
            ),
            const _Benefit(
              Icons.workspace_premium_rounded,
              'Garantia de 90 dias',
              'Todo serviço pago pelo app tem garantia sobre a mão de obra.',
            ),
          ];

    final subtitle = isProvider
        ? 'Seu e-mail foi confirmado e seu cadastro de Profissional está ativo. Falta só configurar o seu perfil para começar a receber pedidos.'
        : 'Seu e-mail foi confirmado e sua conta está ativa. Agora você pode pedir orçamentos grátis com segurança e garantia.';

    return AppScaffold(
      backgroundColor: tk.background,
      body: KycAmbientBackdrop(
        isProviderMode: false,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final emblem = math.min(
                260.0,
                math.max(
                  168.0,
                  math.min(c.maxWidth * 0.74, c.maxHeight * 0.34),
                ),
              );
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  layout.margin,
                  AppSpace.s16,
                  layout.margin,
                  AppSpace.s24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(
                      0.0,
                      c.maxHeight - AppSpace.s16 - AppSpace.s24,
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: RepaintBoundary(
                              child: Semantics(
                                label: 'Conta ativada com sucesso',
                                excludeSemantics: true,
                                child: SizedBox(
                                  key: const ValueKey('activation-emblem'),
                                  width: emblem,
                                  height: emblem,
                                  child: CustomPaint(
                                    painter: _ActivationPainter(
                                      animation: _c,
                                      particles: _particles,
                                      ringStart: tk.accent,
                                      ringEnd: tk.success,
                                      discStart: tk.success,
                                      discEnd: tk.accent,
                                      check: AppTokens.onColor(tk.success),
                                      palette: <Color>[
                                        tk.accent,
                                        tk.success,
                                        tk.accentInk,
                                        tk.info,
                                        tk.security,
                                        tk.star,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpace.s16),
                          _reveal(
                            start: 0.48,
                            end: 0.64,
                            child: const Center(
                              child: AppStatusChip(
                                'Conta ativada',
                                key: ValueKey('chip-account-activated'),
                                tone: AppTone.success,
                                icon: Icons.verified_rounded,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpace.s12),
                          _reveal(
                            start: 0.52,
                            end: 0.70,
                            child: Semantics(
                              header: true,
                              liveRegion: true,
                              child: Text(
                                greeting,
                                key: const ValueKey('activation-greeting'),
                                textAlign: TextAlign.center,
                                style: (layout.isLargeText
                                        ? AppType.headline
                                        : AppType.display)
                                    .copyWith(color: tk.text),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpace.s8),
                          _reveal(
                            start: 0.58,
                            end: 0.76,
                            child: Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: AppType.body.copyWith(
                                color: tk.textMuted,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpace.s20),
                          for (var i = 0; i < benefits.length; i++) ...[
                            _reveal(
                              start: 0.64 + i * 0.06,
                              end: 0.82 + i * 0.06,
                              dy: 14,
                              child: _BenefitRow(
                                key: ValueKey('activation-benefit-$i'),
                                benefit: benefits[i],
                              ),
                            ),
                            if (i != benefits.length - 1)
                              const SizedBox(height: AppSpace.s8),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: AppBottomBar(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_seg(_c.value, 0.70, 0.86));
            return IgnorePointer(
              ignoring: t < 0.6,
              child: Opacity(
                opacity: t,
                child: AppButton(
                  key: const ValueKey('btn-activation-welcome-continue'),
                  label: isProvider
                      ? 'Configurar meu perfil'
                      : 'Começar a usar o Desperrengue',
                  trailingArrow: true,
                  onPressed: widget.onContinue,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static String _formatDate(DateTime? dt) {
    final target = dt ?? DateTime.now().add(const Duration(days: 90));
    final d = target.day.toString().padLeft(2, '0');
    final m = target.month.toString().padLeft(2, '0');
    final y = target.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }
}

double _seg(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

class _Benefit {
  const _Benefit(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({super.key, required this.benefit});

  final _Benefit benefit;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      variant: AppCardVariant.tonal,
      color: tk.card,
      borderColor: tk.border,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppGeometry.iconTileSize,
            height: AppGeometry.iconTileSize,
            decoration: BoxDecoration(
              color: tk.accentSoft,
              borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
            ),
            child: Icon(benefit.icon, size: 22, color: tk.accentInk),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benefit.title,
                  style: AppType.bodyStrong.copyWith(color: tk.text),
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  benefit.body,
                  style: AppType.bodySm.copyWith(
                    color: tk.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.travel,
    required this.size,
    required this.colorIndex,
    required this.shape,
    required this.spin,
    required this.delay,
  });

  final double angle;
  final double travel;
  final double size;
  final int colorIndex;
  final int shape;
  final double spin;
  final double delay;
}

/// Desenha o selo de ativação inteiro (anel, glow, disco, check, ondas e partículas).
/// Repinta apenas quando o [animation] muda, sem reconstruir nenhum widget.
class _ActivationPainter extends CustomPainter {
  _ActivationPainter({
    required this.animation,
    required this.particles,
    required this.ringStart,
    required this.ringEnd,
    required this.discStart,
    required this.discEnd,
    required this.check,
    required this.palette,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<_Particle> particles;
  final Color ringStart;
  final Color ringEnd;
  final Color discStart;
  final Color discEnd;
  final Color check;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final p = animation.value;
    final center = size.center(Offset.zero);
    final r = size.shortestSide * 0.24; // raio do disco

    final ringT = Curves.easeInOutCubic.transform(_seg(p, 0.00, 0.34));
    final discT = Curves.easeOutBack.transform(_seg(p, 0.20, 0.46));
    final checkT = Curves.easeOutCubic.transform(_seg(p, 0.40, 0.62));
    final burstT = _seg(p, 0.42, 0.95);

    // 1) Aura suave atrás do selo.
    final glowA = 0.22 * Curves.easeOut.transform(_seg(p, 0.18, 0.60));
    if (glowA > 0) {
      canvas.drawCircle(
        center,
        size.shortestSide * 0.48,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              discStart.withValues(alpha: glowA),
              discStart.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.shortestSide * 0.48),
          ),
      );
    }

    // 2) Ondas de choque (3 anéis que se expandem e somem).
    for (var i = 0; i < 3; i++) {
      final t = _seg(p, 0.42 + i * 0.07, 0.80 + i * 0.07);
      if (t <= 0 || t >= 1) continue;
      final e = Curves.easeOutCubic.transform(t);
      canvas.drawCircle(
        center,
        r * (1.15 + e * 2.0),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * (1 - e) + 0.4
          ..color = ringEnd.withValues(alpha: 0.38 * (1 - e)),
      );
    }

    // 3) Anel que se desenha em sentido horário.
    if (ringT > 0) {
      final ringRect = Rect.fromCircle(center: center, radius: r * 1.2);
      canvas.drawArc(
        ringRect,
        -math.pi / 2,
        2 * math.pi * ringT,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.085
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: 3 * math.pi / 2,
            colors: <Color>[ringStart, ringEnd, ringStart],
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(ringRect),
      );
    }

    // 4) Disco esmeralda com mola + sombra de elevação.
    final discR = r * discT.clamp(0.0, 1.25);
    if (discR > 0.5) {
      canvas.drawCircle(
        center.translate(0, r * 0.08),
        discR,
        Paint()
          ..color = discStart.withValues(alpha: 0.28)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.22),
      );
      canvas.drawCircle(
        center,
        discR,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[discStart, discEnd],
          ).createShader(Rect.fromCircle(center: center, radius: discR)),
      );
      // brilho especular sutil
      canvas.drawCircle(
        center.translate(-discR * 0.28, -discR * 0.34),
        discR * 0.42,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              Colors.white.withValues(alpha: 0.30),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: center.translate(-discR * 0.28, -discR * 0.34),
              radius: discR * 0.42,
            ),
          ),
      );
    }

    // 5) Check traçado à mão.
    if (checkT > 0 && discR > r * 0.6) {
      final path = Path()
        ..moveTo(center.dx - r * 0.42, center.dy + r * 0.04)
        ..lineTo(center.dx - r * 0.10, center.dy + r * 0.36)
        ..lineTo(center.dx + r * 0.46, center.dy - r * 0.30);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * checkT),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.17
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = check,
      );
    }

    // 6) Explosão de partículas (círculos, losangos e fitas).
    if (burstT > 0 && burstT < 1) {
      for (final pt in particles) {
        final local = _seg(burstT, pt.delay, 1.0);
        if (local <= 0) continue;
        final e = Curves.easeOutCubic.transform(local);
        final dist = r * 1.3 + r * pt.travel * 1.5 * e;
        final pos = center + Offset(math.cos(pt.angle), math.sin(pt.angle)) * dist;
        final fade = (1 - math.pow(local, 1.7)).toDouble().clamp(0.0, 1.0);
        final s = pt.size * (1 - 0.55 * local);
        final paint = Paint()
          ..color = palette[pt.colorIndex % palette.length]
              .withValues(alpha: 0.95 * fade);
        switch (pt.shape) {
          case 0:
            canvas.drawCircle(pos, s, paint);
          case 1:
            canvas.save();
            canvas.translate(pos.dx, pos.dy);
            canvas.rotate(pt.spin * local + math.pi / 4);
            canvas.drawRect(
              Rect.fromCenter(center: Offset.zero, width: s * 1.7, height: s * 1.7),
              paint,
            );
            canvas.restore();
          default:
            canvas.save();
            canvas.translate(pos.dx, pos.dy);
            canvas.rotate(pt.spin * local * 1.6);
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset.zero, width: s * 3.0, height: s * 1.1),
                Radius.circular(s * 0.5),
              ),
              paint,
            );
            canvas.restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ActivationPainter old) =>
      old.animation != animation ||
      old.ringStart != ringStart ||
      old.ringEnd != ringEnd ||
      old.discStart != discStart ||
      old.discEnd != discEnd ||
      old.check != check ||
      old.palette != palette;
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/category_brand_emblem.dart';
import '../../../core/ui/desperrengue_brand_logo.dart';

/// Apresentação cinematográfica ininterrupta pós-cadastro (120 FPS Impeller/Canvas).
///
/// Conduz o novo usuário em uma linha do tempo única e contínua (`0.0 -> 1.0`,
/// sem cortes secos e sem telas brancas) pelos 4 atos fundamentais antes da
/// `RoleSelectionScreen`:
///  1. **Ato I (`0.00 – 0.25`)**: O que a aplicação faz (`cinema-act-1-mission`)
///  2. **Ato II (`0.25 – 0.50`)**: Para quem é a plataforma (`cinema-act-2-audience`)
///  3. **Ato III (`0.50 – 0.75`)**: O lado do Cliente (`cinema-act-3-client`)
///  4. **Ato IV (`0.75 – 1.00`)**: O lado do Profissional (`cinema-act-4-provider`)
class DesperrengueWelcomeCinemaScreen extends StatefulWidget {
  const DesperrengueWelcomeCinemaScreen({
    super.key,
    this.userFirstName = '',
    required this.onCompleted,
    this.isReplay = false,
    this.totalDuration = const Duration(milliseconds: 14800),
  });

  final String userFirstName;
  final VoidCallback onCompleted;
  final bool isReplay;
  final Duration totalDuration;

  @override
  State<DesperrengueWelcomeCinemaScreen> createState() =>
      _DesperrengueWelcomeCinemaScreenState();
}

class _DesperrengueWelcomeCinemaScreenState
    extends State<DesperrengueWelcomeCinemaScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isPaused = false;
  bool _completedDispatched = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.totalDuration,
      animationBehavior: AnimationBehavior.preserve,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_completedDispatched) {
          _completedDispatched = true;
          HapticFeedback.mediumImpact();
          widget.onCompleted();
        }
      });
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant DesperrengueWelcomeCinemaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalDuration != widget.totalDuration) {
      _controller.duration = widget.totalDuration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pauseForReading() {
    if (_completedDispatched || _isPaused) return;
    setState(() => _isPaused = true);
    _controller.stop(canceled: false);
  }

  void _resumeFromReading() {
    if (!_isPaused) return;
    setState(() => _isPaused = false);
    if (!_completedDispatched && _controller.value < 1.0) {
      _controller.forward();
    }
  }

  void _closeReplay() {
    if (_completedDispatched) return;
    _completedDispatched = true;
    _controller.stop();
    widget.onCompleted();
  }

  String get _cleanFirstName {
    final trimmed = widget.userFirstName.trim();
    if (trimmed.isEmpty ||
        trimmed.toLowerCase() == 'você' ||
        trimmed.toLowerCase() == 'usuário') {
      return '';
    }
    return trimmed;
  }

  static int _actIndexFor(double t) {
    if (t < 0.25) return 0;
    if (t < 0.50) return 1;
    if (t < 0.75) return 2;
    return 3;
  }

  static String _chapterLabelFor(int actIndex) {
    switch (actIndex) {
      case 0:
        return '1/4 · O Desperrengue';
      case 1:
        return '2/4 · Para quem é';
      case 2:
        return '3/4 · Modo Cliente';
      default:
        return '4/4 · Modo Profissional';
    }
  }

  /// Envelope contínuo dentro de cada ato (entrada suave com easeOutCubic e
  /// metamorfose contínua na fronteira entre atos, sem frame em branco).
  static double _actEnvelope(double localT, int actIndex) {
    final fadeIn = Curves.easeOutCubic.transform(
      (localT / 0.14).clamp(0.0, 1.0),
    );
    if (actIndex == 3) {
      return 0.88 + 0.12 * fadeIn;
    }
    final fadeOut = localT > 0.88
        ? 1.0 -
            0.18 *
                Curves.easeInCubic.transform(
                  ((localT - 0.88) / 0.12).clamp(0.0, 1.0),
                )
        : 1.0;
    return (0.86 + 0.14 * fadeIn) * fadeOut;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: widget.isReplay,
      child: AppScaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (_) => _pauseForReading(),
          onLongPressEnd: (_) => _resumeFromReading(),
          onLongPressUp: _resumeFromReading,
          onLongPressCancel: _resumeFromReading,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value.clamp(0.0, 1.0);
              final actIndex = _actIndexFor(t);
              final actStart = actIndex * 0.25;
              final localT = ((t - actStart) / 0.25).clamp(0.0, 1.0);
              final envelope = _actEnvelope(localT, actIndex);

              return Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _AtmosphericCinemaBackgroundPainter(
                        timeline: t,
                        reduceMotion: reduceMotion,
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTopCinemaHud(t, actIndex),
                          const SizedBox(height: 8),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final stageWidth = math.max(
                                  constraints.maxWidth,
                                  284.0,
                                );
                                final isCompact =
                                    constraints.maxHeight < 620 ||
                                        constraints.maxWidth < 350;
                                return Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.center,
                                    child: SizedBox(
                                      width: stageWidth,
                                      child: Opacity(
                                        opacity: envelope.clamp(0.0, 1.0),
                                        child: Transform.translate(
                                          offset: Offset(
                                            0,
                                            (1.0 - envelope) * 14.0,
                                          ),
                                          child: _buildActiveActStage(
                                            actIndex: actIndex,
                                            localT: localT,
                                            globalT: t,
                                            isCompact: isCompact,
                                            reduceMotion: reduceMotion,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildBottomContinuousFooter(t, actIndex),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopCinemaHud(double t, int actIndex) {
    final accentColor = switch (actIndex) {
      0 => const Color(0xFFFF6D00),
      1 => const Color(0xFF38BDF8),
      2 => const Color(0xFFFF8A2B),
      _ => const Color(0xFF22C55E),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra Cinematográfica de 4 Capítulos Contínuos
        SizedBox(
          key: const Key('welcome-cinema-progress-bar'),
          height: 5,
          child: Row(
            children: List.generate(4, (i) {
              final segFill = ((t - i * 0.25) / 0.25).clamp(0.0, 1.0);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 3 ? 6.0 : 0.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: segFill,
                          heightFactor: 1.0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accentColor,
                                  Colors.white.withValues(alpha: 0.92),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _chapterLabelFor(actIndex),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isPaused)
                    Container(
                      key: const Key('cinema-paused-badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6D00).withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: const Color(0xFFFF8A2B).withValues(alpha: 0.65),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.pause_circle_filled_rounded,
                            size: 13,
                            color: Color(0xFFFFB020),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Pausado para leitura',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (widget.isReplay)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextButton.icon(
                  key: const Key('btn-close-replay-cinema'),
                  onPressed: _closeReplay,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 15),
                  label: const Text(
                    'Fechar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomContinuousFooter(double t, int actIndex) {
    final pct = (t * 100).round().clamp(0, 100);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.touch_app_rounded,
                size: 13,
                color: Colors.white.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  _isPaused
                      ? 'Solte a tela para continuar a apresentação'
                      : 'Segure a tela a qualquer momento para pausar a leitura',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$pct%',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveActStage({
    required int actIndex,
    required double localT,
    required double globalT,
    required bool isCompact,
    required bool reduceMotion,
  }) {
    switch (actIndex) {
      case 0:
        return _buildAct1Mission(
          localT: localT,
          isCompact: isCompact,
          reduceMotion: reduceMotion,
        );
      case 1:
        return _buildAct2Audience(
          localT: localT,
          isCompact: isCompact,
          reduceMotion: reduceMotion,
        );
      case 2:
        return _buildAct3Client(
          localT: localT,
          isCompact: isCompact,
        );
      default:
        return _buildAct4Provider(
          localT: localT,
          isCompact: isCompact,
        );
    }
  }

  // ===========================================================================
  // ATO I (0.00 – 0.25) — O QUE O DESPERRENGUE FAZ
  // ===========================================================================
  Widget _buildAct1Mission({
    required double localT,
    required bool isCompact,
    required bool reduceMotion,
  }) {
    final name = _cleanFirstName;
    final badgeText =
        'CADASTRO CONCLUÍDO${name.isNotEmpty ? ' · OLÁ, ${name.toUpperCase()}' : ''}';
    final drawProgress = Curves.easeOutCubic.transform(
      (localT / 0.52).clamp(0.0, 1.0),
    );
    final glowIntensity = 0.35 + 0.65 * math.sin(localT * math.pi);
    final orbitRadius = isCompact ? 86.0 : 102.0;
    final sceneSize = isCompact ? 226.0 : 262.0;

    const categories = <(String, String)>[
      ('Elétrica', 'Elétrica'),
      ('Encanador', 'Hidráulica'),
      ('Ar-condicionado', 'Climatização'),
      ('Chaveiro', 'Chaveiro'),
      ('Pintura', 'Pintura'),
      ('Marcenaria', 'Marcenaria'),
    ];

    return Column(
      key: const Key('cinema-act-1-mission'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildMarketingBadge(
          text: badgeText,
          accent: const Color(0xFFFF6D00),
          icon: Icons.verified_rounded,
        ),
        SizedBox(height: isCompact ? 12 : 16),
        RepaintBoundary(
          child: SizedBox(
            width: sceneSize,
            height: sceneSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _Act1OrbitalFieldPainter(
                      progress: localT,
                      reduceMotion: reduceMotion,
                    ),
                  ),
                ),
                // Emblemas reais das categorias orbitando suavemente o Lar
                for (var i = 0; i < categories.length; i++)
                  Builder(
                    builder: (context) {
                      final baseAngle =
                          (i * 2 * math.pi / categories.length) - math.pi / 2;
                      final rot = reduceMotion ? 0.0 : localT * 0.42;
                      final angle = baseAngle + rot;
                      final entryT = Curves.easeOutBack.transform(
                        ((localT - i * 0.05) / 0.42).clamp(0.0, 1.0),
                      );
                      final dx = math.cos(angle) * orbitRadius * entryT;
                      final dy = math.sin(angle) * orbitRadius * entryT;
                      return Transform.translate(
                        offset: Offset(dx, dy),
                        child: Opacity(
                          opacity: entryT.clamp(0.0, 1.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CategoryBrandEmblem(
                                categoryName: categories[i].$1,
                                size: isCompact ? 38 : 44,
                                showCornerBadge: false,
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A)
                                      .withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.14),
                                  ),
                                ),
                                child: Text(
                                  categories[i].$2,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                // Núcleo Casa-Escudo Oficial "D" + Check Laranja
                Container(
                  width: isCompact ? 82 : 94,
                  height: isCompact ? 82 : 94,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0F172A),
                    border: Border.all(
                      color: const Color(0xFFFF6D00).withValues(alpha: 0.55),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6D00).withValues(alpha: 0.28),
                        blurRadius: 26,
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: DesperrengueBrandLogoPainter(
                      variant: DesperrengueLogoVariant.quietLuxuryNavy,
                      includeBackground: false,
                      adaptiveSafeZoneScale: 0.68,
                      drawProgress: drawProgress,
                      glowIntensity: glowIntensity,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: isCompact ? 12 : 18),
        _buildMarketingHeadline(
          title: 'Imprevistos em casa resolvidos sem estresse.',
          subtitle:
              'O Desperrengue une moradores e profissionais verificados em uma plataforma segura, rápida e transparente.',
          isCompact: isCompact,
        ),
      ],
    );
  }

  // ===========================================================================
  // ATO II (0.25 – 0.50) — PARA QUEM É A PLATAFORMA
  // ===========================================================================
  Widget _buildAct2Audience({
    required double localT,
    required bool isCompact,
    required bool reduceMotion,
  }) {
    final bridgeT = Curves.easeOutCubic.transform(
      (localT / 0.55).clamp(0.0, 1.0),
    );

    return Column(
      key: const Key('cinema-act-2-audience'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildMarketingBadge(
          text: 'FEITO PARA OS DOIS LADOS',
          accent: const Color(0xFF38BDF8),
          icon: Icons.swap_horiz_rounded,
        ),
        SizedBox(height: isCompact ? 12 : 16),
        RepaintBoundary(
          child: Container(
            padding: EdgeInsets.all(isCompact ? 14 : 18),
            decoration: BoxDecoration(
              color: const Color(0xFF13203B).withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: isCompact ? 62 : 74,
                  child: CustomPaint(
                    painter: _Act2DualHemispherePainter(
                      progress: localT,
                      reduceMotion: reduceMotion,
                    ),
                    child: Center(
                      child: Transform.scale(
                        scale: 0.85 + 0.15 * bridgeT,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B2E22),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: const Color(0xFF22C55E),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF22C55E)
                                    .withValues(alpha: 0.30),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                size: 15,
                                color: Color(0xFF4ADE80),
                              ),
                              SizedBox(width: 6),
                              Text(
                                '1 Conta · 2 Perfis',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildHemisphereCard(
                        title: 'Lar Protegido',
                        subtitle: 'Para quem contrata com garantia e segurança',
                        accent: const Color(0xFFFF6D00),
                        icon: Icons.home_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildHemisphereCard(
                        title: 'Especialista Verificado',
                        subtitle: 'Para quem transforma ofício em renda justa',
                        accent: const Color(0xFF38BDF8),
                        icon: Icons.handyman_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildTrustPill(
                      icon: Icons.face_retouching_natural_rounded,
                      label: 'Biometria Facial',
                      accent: const Color(0xFF38BDF8),
                    ),
                    _buildTrustPill(
                      icon: Icons.gavel_rounded,
                      label: 'Antecedentes Validados',
                      accent: const Color(0xFF22C55E),
                    ),
                    _buildTrustPill(
                      icon: Icons.published_with_changes_rounded,
                      label: 'Troca de Modo em 1 Toque',
                      accent: const Color(0xFFFF8A2B),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: isCompact ? 12 : 18),
        _buildMarketingHeadline(
          title: 'Uma única conta. Liberdade para contratar ou trabalhar.',
          subtitle:
              'Para quem busca confiança dentro do próprio lar e para quem transforma talento técnico em renda justa — com biometria e certidão da Polícia Federal.',
          isCompact: isCompact,
        ),
      ],
    );
  }

  Widget _buildHemisphereCard({
    required String title,
    required String subtitle,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.42),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 11.5,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustPill({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ATO III (0.50 – 0.75) — MOSTRANDO O LADO DO CLIENTE
  // ===========================================================================
  Widget _buildAct3Client({
    required double localT,
    required bool isCompact,
  }) {
    final step1T = Curves.easeOutCubic.transform(
      (localT / 0.32).clamp(0.0, 1.0),
    );
    final step2T = Curves.easeOutCubic.transform(
      ((localT - 0.16) / 0.36).clamp(0.0, 1.0),
    );
    final step3T = Curves.easeOutCubic.transform(
      ((localT - 0.34) / 0.40).clamp(0.0, 1.0),
    );

    return Column(
      key: const Key('cinema-act-3-client'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildMarketingBadge(
          text: 'COMO CLIENTE · SUA CASA PROTEGIDA',
          accent: const Color(0xFFFF6D00),
          icon: Icons.shield_rounded,
        ),
        SizedBox(height: isCompact ? 12 : 16),
        RepaintBoundary(
          child: Container(
            padding: EdgeInsets.all(isCompact ? 14 : 16),
            decoration: BoxDecoration(
              color: const Color(0xFF26150E).withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFFF6D00).withValues(alpha: 0.42),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6D00).withValues(alpha: 0.14),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Passo 1: Até 3 orçamentos claros (4,9 ★)
                Transform.translate(
                  offset: Offset((1.0 - step1T) * 18, 0),
                  child: _buildChoreographedStepRow(
                    stepNumber: '1',
                    accent: const Color(0xFFFF6D00),
                    title: 'Até 3 orçamentos claros',
                    subtitle:
                        'Especialistas verificados respondem rápido com avaliação 4,9 ★',
                    trailingBadge: '4,9 ★',
                    highlight: step1T,
                  ),
                ),
                const SizedBox(height: 10),
                // Passo 2: Custódia + Endereço oculto + 0% taxa sobre materiais com nota
                Transform.translate(
                  offset: Offset((1.0 - step2T) * 18, 0),
                  child: _buildChoreographedStepRow(
                    stepNumber: '2',
                    accent: const Color(0xFFFFB020),
                    title: 'Valor protegido em custódia',
                    subtitle:
                        'Endereço oculto até contratar · 0% de taxa sobre materiais com nota',
                    trailingBadge: 'Protegido',
                    highlight: step2T,
                  ),
                ),
                const SizedBox(height: 10),
                // Passo 3: Código PIN de 4 dígitos -> 90 dias de garantia técnica
                Transform.translate(
                  offset: Offset((1.0 - step3T) * 18, 0),
                  child: _buildChoreographedStepRow(
                    stepNumber: '3',
                    accent: const Color(0xFF22C55E),
                    title: 'PIN de 4 dígitos libera o pagamento',
                    subtitle:
                        'Só libera após sua aprovação · Ativa 90 dias de garantia técnica',
                    trailingBadge: '90 dias de garantia técnica',
                    highlight: step3T,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: isCompact ? 12 : 18),
        _buildMarketingHeadline(
          title: 'Peça em segundos. Só libere o pagamento quando aprovar.',
          subtitle:
              'Compare até 3 propostas, acompanhe no mapa ao vivo e conte com pagamento guardado e 90 dias de garantia.',
          isCompact: isCompact,
        ),
      ],
    );
  }

  // ===========================================================================
  // ATO IV (0.75 – 1.00) — MOSTRANDO O LADO DO PROFISSIONAL
  // ===========================================================================
  Widget _buildAct4Provider({
    required double localT,
    required bool isCompact,
  }) {
    final step1T = Curves.easeOutCubic.transform(
      (localT / 0.32).clamp(0.0, 1.0),
    );
    final step2T = Curves.easeOutCubic.transform(
      ((localT - 0.16) / 0.36).clamp(0.0, 1.0),
    );
    final step3T = Curves.easeOutCubic.transform(
      ((localT - 0.34) / 0.40).clamp(0.0, 1.0),
    );

    return Column(
      key: const Key('cinema-act-4-provider'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildMarketingBadge(
          text: 'COMO PROFISSIONAL · SEU TRABALHO VALORIZADO',
          accent: const Color(0xFF38BDF8),
          icon: Icons.workspace_premium_rounded,
        ),
        SizedBox(height: isCompact ? 12 : 16),
        RepaintBoundary(
          child: Container(
            padding: EdgeInsets.all(isCompact ? 14 : 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1F3C).withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.42),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D6FE0).withValues(alpha: 0.18),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Passo 1: Radar de oportunidades reais (Sem leilão predatório)
                Transform.translate(
                  offset: Offset((1.0 - step1T) * 18, 0),
                  child: _buildChoreographedStepRow(
                    stepNumber: '1',
                    accent: const Color(0xFF38BDF8),
                    title: 'Radar de oportunidades reais na sua região',
                    subtitle:
                        'Demandas filtradas pela sua especialidade · Sem leilão predatório',
                    trailingBadge: 'Sem leilão predatório',
                    highlight: step1T,
                  ),
                ),
                const SizedBox(height: 10),
                // Passo 2: Valor já reservado + 0% comissão sobre peças com NF-e + PIX
                Transform.translate(
                  offset: Offset((1.0 - step2T) * 18, 0),
                  child: _buildChoreographedStepRow(
                    stepNumber: '2',
                    accent: const Color(0xFF22C55E),
                    title: 'Valor já reservado antes de sair de casa',
                    subtitle:
                        '0% de comissão sobre peças com NF-e · Saque rápido via PIX',
                    trailingBadge: 'Saque rápido via PIX',
                    highlight: step2T,
                  ),
                ),
                const SizedBox(height: 10),
                // Passo 3: Reputação 5,0 ★ e portfólio
                Transform.translate(
                  offset: Offset((1.0 - step3T) * 18, 0),
                  child: _buildChoreographedStepRow(
                    stepNumber: '3',
                    accent: const Color(0xFFF5B400),
                    title: 'Vitrine técnica e reputação 5,0 ★',
                    subtitle:
                        'Seu portfólio de casos reais destaca seu talento para novos clientes',
                    trailingBadge: '5,0 ★',
                    highlight: step3T,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: isCompact ? 12 : 18),
        _buildMarketingHeadline(
          title: 'Chamados reais na sua região e pagamento garantido.',
          subtitle:
              'Envie orçamentos, atenda com o valor já assegurado na plataforma e receba direto no seu PIX.',
          isCompact: isCompact,
        ),
      ],
    );
  }

  Widget _buildChoreographedStepRow({
    required String stepNumber,
    required Color accent,
    required String title,
    required String subtitle,
    required String trailingBadge,
    required double highlight,
  }) {
    final activeAlpha = (0.35 + 0.65 * highlight).clamp(0.0, 1.0);
    return Opacity(
      opacity: activeAlpha,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05 + 0.04 * highlight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.withValues(alpha: 0.25 + 0.35 * highlight),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent),
              ),
              child: Text(
                stepNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          trailingBadge,
                          style: TextStyle(
                            color: Color.lerp(accent, Colors.white, 0.35),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 11.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketingBadge({
    required String text,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: accent.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketingHeadline({
    required String title,
    required String subtitle,
    required bool isCompact,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 22 : 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.80),
            fontSize: isCompact ? 13 : 14.5,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// PAINTERS VETORIAIS GPU (IMPELLER 120 FPS)
// =============================================================================

/// Fundo atmosférico vivo que transita organicamente entre as 4 atmosferas cromáticas:
/// - Ato I (`0.00..0.25`): Azul-Noite Quiet Luxury (`#0F172A`)
/// - Ato II (`0.25..0.50`): Índigo Dual Soberano (`#13203B`)
/// - Ato III (`0.50..0.75`): Aura Âmbar/Terracota Acolhedora do Cliente (`#26150E` + `#FF6D00`)
/// - Ato IV (`0.75..1.00`): Azul Real/Esmeralda do Profissional (`#0D1F3C` + `#1D6FE0`/`#22C55E`),
///   convergindo suavemente para o tom de entrada da `RoleSelectionScreen` (`#0E1218`).
class _AtmosphericCinemaBackgroundPainter extends CustomPainter {
  const _AtmosphericCinemaBackgroundPainter({
    required this.timeline,
    required this.reduceMotion,
  });

  final double timeline;
  final bool reduceMotion;

  static Color _sampleStops(List<Color> stops, double t) {
    final scaled = (t.clamp(0.0, 1.0)) * (stops.length - 1);
    final idx = scaled.floor().clamp(0, stops.length - 2);
    final frac = scaled - idx;
    return Color.lerp(stops[idx], stops[idx + 1], frac)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bgTop = _sampleStops(
      const [
        Color(0xFF0F172A), // Ato I: Quiet Luxury Navy
        Color(0xFF13203B), // Ato II: Índigo Dual Soberano
        Color(0xFF26150E), // Ato III: Terracota Cliente
        Color(0xFF0D1F3C), // Ato IV: Azul Real Profissional
        Color(0xFF0E1218), // Convergência RoleSelectionScreen
      ],
      timeline,
    );

    final bgBottom = _sampleStops(
      const [
        Color(0xFF090E1A),
        Color(0xFF0C1528),
        Color(0xFF140C09),
        Color(0xFF081326),
        Color(0xFF141A22),
      ],
      timeline,
    );

    final rect = Offset.zero & size;
    final basePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.5, 0),
        Offset(size.width * 0.5, size.height),
        [bgTop, bgBottom],
      );
    canvas.drawRect(rect, basePaint);

    // Halos luminosos orgânicos que se deslocam continuamente
    final haloPrimary = _sampleStops(
      const [
        Color(0xFFFF6D00),
        Color(0xFF38BDF8),
        Color(0xFFFF6D00),
        Color(0xFF1D6FE0),
        Color(0xFFFF8F52),
      ],
      timeline,
    );
    final haloSecondary = _sampleStops(
      const [
        Color(0xFF38BDF8),
        Color(0xFFFF6D00),
        Color(0xFFFFB020),
        Color(0xFF22C55E),
        Color(0xFF74A7FF),
      ],
      timeline,
    );

    final drift = reduceMotion ? 0.0 : math.sin(timeline * math.pi * 2) * 0.08;
    final c1 = Offset(
      size.width * (0.78 + drift),
      size.height * (0.18 - drift * 0.5),
    );
    final c2 = Offset(
      size.width * (0.22 - drift),
      size.height * (0.80 + drift * 0.5),
    );

    final r1 = size.shortestSide * 0.65;
    final r2 = size.shortestSide * 0.72;

    canvas.drawCircle(
      c1,
      r1,
      Paint()
        ..shader = ui.Gradient.radial(
          c1,
          r1,
          [
            haloPrimary.withValues(alpha: 0.22),
            haloPrimary.withValues(alpha: 0.0),
          ],
        ),
    );

    canvas.drawCircle(
      c2,
      r2,
      Paint()
        ..shader = ui.Gradient.radial(
          c2,
          r2,
          [
            haloSecondary.withValues(alpha: 0.18),
            haloSecondary.withValues(alpha: 0.0),
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _AtmosphericCinemaBackgroundPainter old) =>
      old.timeline != timeline || old.reduceMotion != reduceMotion;
}

/// Ondas concêntricas de proteção do lar para o Ato I.
class _Act1OrbitalFieldPainter extends CustomPainter {
  const _Act1OrbitalFieldPainter({
    required this.progress,
    required this.reduceMotion,
  });

  final double progress;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide * 0.44;

    for (var i = 0; i < 3; i++) {
      final pulse = reduceMotion ? 0.0 : ((progress + i * 0.33) % 1.0) * 0.12;
      final r = maxR * (0.48 + i * 0.24 + pulse);
      final alpha = (0.22 - i * 0.05).clamp(0.04, 0.28);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFFF6D00).withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Act1OrbitalFieldPainter old) =>
      old.progress != progress || old.reduceMotion != reduceMotion;
}

/// Arco geodésico vivo conectando os hemisférios Cliente e Profissional no Ato II.
class _Act2DualHemispherePainter extends CustomPainter {
  const _Act2DualHemispherePainter({
    required this.progress,
    required this.reduceMotion,
  });

  final double progress;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final leftNode = Offset(size.width * 0.14, size.height * 0.72);
    final rightNode = Offset(size.width * 0.86, size.height * 0.72);
    final control = Offset(size.width * 0.50, -size.height * 0.10);

    final arcPath = Path()
      ..moveTo(leftNode.dx, leftNode.dy)
      ..quadraticBezierTo(control.dx, control.dy, rightNode.dx, rightNode.dy);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
        leftNode,
        rightNode,
        const [
          Color(0xFFFF6D00),
          Color(0xFF22C55E),
          Color(0xFF38BDF8),
        ],
        const [0.0, 0.5, 1.0],
      );

    canvas.drawPath(arcPath, arcPaint);

    // Nós luminosos das extremidades
    canvas.drawCircle(
      leftNode,
      6,
      Paint()..color = const Color(0xFFFF6D00),
    );
    canvas.drawCircle(
      rightNode,
      6,
      Paint()..color = const Color(0xFF38BDF8),
    );
  }

  @override
  bool shouldRepaint(covariant _Act2DualHemispherePainter old) =>
      old.progress != progress || old.reduceMotion != reduceMotion;
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/category_brand_emblem.dart';
import '../../../core/ui/desperrengue_brand_logo.dart';

/// Obra-prima cinematográfica pós-cadastro (120 FPS Impeller/Canvas — v2.22.0).
///
/// Arquitetura em 7 camadas contínuas:
///  - **Camada A**: Atmosfera volumétrica de aurora em seda + 36 partículas bokeh
///    com paralaxe em 3 planos de profundidade e convergência final para `#0E1218`.
///  - **Camada B**: Dissolução cruzada real com câmera Dolly em profundidade Z
///    nas fronteiras `0.25`, `0.50` e `0.75` (`±0.045`), sem cortes secos.
///  - **Camada C**: Cartões Liquid-Glass com reflexo especular diagonal dinâmico.
///  - **Camada D**: 4 Atos psicológicos com cenas vivas coreografadas em Canvas:
///     1. `0.00 – 0.25`: Catarse no Lar (`cinema-act-1-mission`)
///     2. `0.25 – 0.50`: Ponte Biométrica Dual (`cinema-act-2-audience`)
///     3. `0.50 – 0.75`: Micro-Filme do Cliente (`cinema-act-3-client`)
///     4. `0.75 – 1.00`: Micro-Filme do Profissional (`cinema-act-4-provider`)
///  - **Camada E**: Partitura háptica sincronizada + salto interativo de capítulos.
class DesperrengueWelcomeCinemaScreen extends StatefulWidget {
  const DesperrengueWelcomeCinemaScreen({
    super.key,
    this.userFirstName = '',
    required this.onCompleted,
    this.isReplay = false,
    this.totalDuration = const Duration(milliseconds: 16400),
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
  static const double _kCrossDissolveHalfWindow = 0.045;
  static const List<double> _kHapticMilestones = <double>[
    0.25, // Virada Ato I -> Ato II
    0.50, // Virada Ato II -> Ato III
    0.68, // Conclusão do PIN de 4 dígitos no Ato III
    0.75, // Virada Ato III -> Ato IV
    0.88, // Ignição da 5ª estrela dourada no Ato IV
  ];

  late final AnimationController _controller;
  bool _isPaused = false;
  bool _completedDispatched = false;
  int _lastHapticStep = -1;
  int? _suppressedDissolveBoundary;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.totalDuration,
      animationBehavior: AnimationBehavior.preserve,
    )
      ..addListener(_onTimelineTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_completedDispatched) {
          _completedDispatched = true;
          _lastHapticStep = _kHapticMilestones.length;
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
    _controller.removeListener(_onTimelineTick);
    _controller.dispose();
    super.dispose();
  }

  void _onTimelineTick() {
    if (_completedDispatched) return;
    final t = _controller.value;
    if (_suppressedDissolveBoundary != null) {
      final suppressedBoundaryT = (_suppressedDissolveBoundary! + 1) * 0.25;
      if ((t - suppressedBoundaryT).abs() > _kCrossDissolveHalfWindow) {
        _suppressedDissolveBoundary = null;
      }
    }
    for (var i = _lastHapticStep + 1; i < _kHapticMilestones.length; i++) {
      if (t >= _kHapticMilestones[i]) {
        _lastHapticStep = i;
        HapticFeedback.selectionClick();
      } else {
        break;
      }
    }
  }

  void _syncHapticStepForTimeline(double t) {
    var step = -1;
    for (var i = 0; i < _kHapticMilestones.length; i++) {
      if (t >= _kHapticMilestones[i]) {
        step = i;
      } else {
        break;
      }
    }
    _lastHapticStep = step;
  }

  void _jumpToChapter(int chapterIndex) {
    if (_completedDispatched) return;
    final clampedIndex = chapterIndex.clamp(0, 3);
    final targetT = (clampedIndex * 0.25).clamp(0.0, 0.99);
    _isPaused = false;
    _suppressedDissolveBoundary = clampedIndex > 0 ? clampedIndex - 1 : null;
    _syncHapticStepForTimeline(targetT);
    HapticFeedback.selectionClick();
    _controller.forward(from: targetT);
    setState(() {});
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
    if (t < 0.25 - 1e-5) return 0;
    if (t < 0.50 - 1e-5) return 1;
    if (t < 0.75 - 1e-5) return 2;
    return 3;
  }

  static String _chapterLabelFor(int actIndex) {
    switch (actIndex) {
      case 0:
        return '1/4 · Sua Paz no Lar';
      case 1:
        return '2/4 · Confiança Dual';
      case 2:
        return '3/4 · Você como Cliente';
      default:
        return '4/4 · Você como Profissional';
    }
  }

  /// Calcula as camadas visuais ativas no instante `t`, aplicando dissolução
  /// cruzada com câmera Dolly em profundidade Z nas fronteiras `0.25`, `0.50`
  /// e `0.75` (`±0.045`) sem cortes secos.
  List<_CinemaActRenderLayer> _computeRenderLayers(
    double t,
    int dominantAct,
    bool reduceMotion,
  ) {
    if (!reduceMotion) {
      for (var k = 0; k < 3; k++) {
        if (k == _suppressedDissolveBoundary) continue;
        final boundary = (k + 1) * 0.25;
        final dist = t - boundary;
        if (dist.abs() <= _kCrossDissolveHalfWindow) {
          final rawU = ((dist + _kCrossDissolveHalfWindow) /
                  (_kCrossDissolveHalfWindow * 2.0))
              .clamp(0.0, 1.0);
          final blend = Curves.easeInOutCubic.transform(rawU);

          // Curvas assimétricas de opacidade: o ato anterior apaga antes (0.0 -> 0.62)
          // enquanto o novo ato acende de (0.28 -> 1.0), evitando sobreposição 50%/50% de títulos.
          final outFade = Curves.easeInCubic.transform(
            (rawU / 0.62).clamp(0.0, 1.0),
          );
          final inFade = Curves.easeOutCubic.transform(
            ((rawU - 0.28) / 0.72).clamp(0.0, 1.0),
          );

          final outgoingLocalT = ((t - k * 0.25) / 0.25).clamp(0.0, 1.0);
          final incomingLocalT =
              ((t - (k + 1) * 0.25) / 0.25).clamp(0.0, 1.0);

          return <_CinemaActRenderLayer>[
            _CinemaActRenderLayer(
              actIndex: k,
              localT: outgoingLocalT,
              scale: 1.0 + 0.05 * blend,
              translateY: -12.0 * blend,
              opacity: (1.0 - outFade).clamp(0.0, 1.0),
              includeSemanticActKey: k == dominantAct,
            ),
            _CinemaActRenderLayer(
              actIndex: k + 1,
              localT: incomingLocalT,
              scale: 0.95 + 0.05 * blend,
              translateY: 14.0 * (1.0 - blend),
              opacity: inFade.clamp(0.0, 1.0),
              includeSemanticActKey: (k + 1) == dominantAct,
            ),
          ];
        }
      }
    }

    final localT = ((t - dominantAct * 0.25) / 0.25).clamp(0.0, 1.0);
    var scale = 1.0;
    var translateY = 0.0;
    var opacity = 1.0;

    if (!reduceMotion && dominantAct == 0 && localT < 0.14) {
      final entry = Curves.easeOutCubic.transform(
        (localT / 0.14).clamp(0.0, 1.0),
      );
      scale = 0.96 + 0.04 * entry;
      translateY = (1.0 - entry) * 10.0;
      opacity = 0.88 + 0.12 * entry;
    }

    return <_CinemaActRenderLayer>[
      _CinemaActRenderLayer(
        actIndex: dominantAct,
        localT: localT,
        scale: scale,
        translateY: translateY,
        opacity: opacity,
        includeSemanticActKey: true,
      ),
    ];
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
              final dominantAct = _actIndexFor(t);
              final layers = _computeRenderLayers(
                t,
                dominantAct,
                reduceMotion,
              );

              return Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _VolumetricAuroraBokehPainter(
                        timeline: t,
                        reduceMotion: reduceMotion,
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTopCinemaHud(t, dominantAct),
                          const SizedBox(height: 6),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final stageWidth = math.max(
                                  constraints.maxWidth,
                                  288.0,
                                );
                                final isCompact =
                                    constraints.maxHeight < 630 ||
                                        constraints.maxWidth < 355;

                                return Stack(
                                  fit: StackFit.expand,
                                  alignment: Alignment.center,
                                  children: [
                                    for (final layer in layers)
                                      Positioned.fill(
                                        key: ValueKey<int>(layer.actIndex),
                                        child: IgnorePointer(
                                          ignoring:
                                              !layer.includeSemanticActKey,
                                          child: ExcludeSemantics(
                                            excluding:
                                                !layer.includeSemanticActKey,
                                            child: Opacity(
                                              opacity: layer.opacity
                                                  .clamp(0.0, 1.0),
                                              child: Transform.translate(
                                                offset: Offset(
                                                  0,
                                                  layer.translateY,
                                                ),
                                                child: Transform.scale(
                                                  scale: layer.scale,
                                                  alignment: Alignment.center,
                                                  child: Center(
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      alignment:
                                                          Alignment.center,
                                                      child: SizedBox(
                                                        width: stageWidth,
                                                        child:
                                                            _buildActiveActStage(
                                                          actIndex:
                                                              layer.actIndex,
                                                          localT: layer.localT,
                                                          globalT: t,
                                                          isCompact: isCompact,
                                                          reduceMotion:
                                                              reduceMotion,
                                                          includeSemanticActKey:
                                                              layer
                                                                  .includeSemanticActKey,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildBottomContinuousFooter(t, dominantAct),
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
      0 => const Color(0xFFFF8A2B),
      1 => const Color(0xFF38BDF8),
      2 => const Color(0xFFFF6D00),
      _ => const Color(0xFF22C55E),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra Cinematográfica Interativa de 4 Capítulos Contínuos
        SizedBox(
          key: const Key('welcome-cinema-progress-bar'),
          height: 22,
          child: Row(
            children: List.generate(4, (i) {
              final segFill = ((t - i * 0.25) / 0.25).clamp(0.0, 1.0);
              final isCurrent = i == actIndex;
              return Expanded(
                child: GestureDetector(
                  key: Key('cinema-chapter-tap-$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _jumpToChapter(i),
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i < 3 ? 6.0 : 0.0,
                      top: 8.0,
                      bottom: 8.0,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: isCurrent ? 0.22 : 0.14,
                          ),
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
                                    Colors.white.withValues(alpha: 0.95),
                                  ],
                                ),
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
        const SizedBox(height: 4),
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
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.65),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _chapterLabelFor(actIndex),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
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
                          color:
                              const Color(0xFFFF8A2B).withValues(alpha: 0.65),
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
                          Flexible(
                            child: Text(
                              'Pausado para leitura',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
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
                color: Colors.white.withValues(alpha: 0.56),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  _isPaused
                      ? 'Solte a tela para continuar a experiência'
                      : 'Segure para pausar a leitura · Toque nos capítulos no topo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60),
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
            color: Colors.white.withValues(alpha: 0.72),
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
    required bool includeSemanticActKey,
  }) {
    switch (actIndex) {
      case 0:
        return _buildAct1Mission(
          localT: localT,
          isCompact: isCompact,
          reduceMotion: reduceMotion,
          includeSemanticActKey: includeSemanticActKey,
        );
      case 1:
        return _buildAct2Audience(
          localT: localT,
          isCompact: isCompact,
          reduceMotion: reduceMotion,
          includeSemanticActKey: includeSemanticActKey,
        );
      case 2:
        return _buildAct3Client(
          localT: localT,
          isCompact: isCompact,
          reduceMotion: reduceMotion,
          includeSemanticActKey: includeSemanticActKey,
        );
      default:
        return _buildAct4Provider(
          localT: localT,
          isCompact: isCompact,
          reduceMotion: reduceMotion,
          includeSemanticActKey: includeSemanticActKey,
        );
    }
  }

  // ===========================================================================
  // ATO I (0.00 – 0.25) — CATARSE EMOCIONAL: DA TENSÃO À PAZ NO LAR
  // ===========================================================================
  Widget _buildAct1Mission({
    required double localT,
    required bool isCompact,
    required bool reduceMotion,
    required bool includeSemanticActKey,
  }) {
    final name = _cleanFirstName;
    final badgeText =
        'BEM-VINDO(A)${name.isNotEmpty ? ', ${name.toUpperCase()}' : ''} · SUA PAZ EM CASA COMEÇA AQUI';

    return Column(
      key: includeSemanticActKey ? const Key('cinema-act-1-mission') : null,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildMarketingBadge(
          text: badgeText,
          accent: const Color(0xFFFFB020),
          icon: Icons.verified_rounded,
        ),
        SizedBox(height: isCompact ? 10 : 14),
        _Act1LivingHomeCatharsisStage(
          localT: localT,
          isCompact: isCompact,
          reduceMotion: reduceMotion,
        ),
        SizedBox(height: isCompact ? 12 : 16),
        _buildMarketingHeadline(
          title: 'Todo imprevisto em casa merece alívio imediato.',
          subtitle:
              'Transformamos urgências e cuidados do seu lar em soluções rápidas, humanas e 100% protegidas do início ao fim.',
          isCompact: isCompact,
          goldenShaderHighlight: true,
        ),
      ],
    );
  }

  // ===========================================================================
  // ATO II (0.25 – 0.50) — PERTENCIMENTO, SEGURANÇA MÁXIMA & LIBERDADE DUAL
  // ===========================================================================
  Widget _buildAct2Audience({
    required double localT,
    required bool isCompact,
    required bool reduceMotion,
    required bool includeSemanticActKey,
  }) {
    return Column(
      key: includeSemanticActKey ? const Key('cinema-act-2-audience') : null,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildMarketingBadge(
          text: 'CONFIANÇA VERDADEIRA DOS DOIS LADOS DA PORTA',
          accent: const Color(0xFF38BDF8),
          icon: Icons.verified_user_rounded,
        ),
        SizedBox(height: isCompact ? 10 : 14),
        _Act2BiometricTrustBridgeStage(
          localT: localT,
          isCompact: isCompact,
          reduceMotion: reduceMotion,
        ),
        SizedBox(height: isCompact ? 12 : 16),
        _buildMarketingHeadline(
          title: 'Segurança para quem abre a porta. Respeito para quem trabalha.',
          subtitle:
              'Identidade e antecedentes validados protegem todos. E com um único cadastro, você contrata hoje ou oferece seu talento quando quiser.',
          isCompact: isCompact,
        ),
      ],
    );
  }

  // ===========================================================================
  // ATO III (0.50 – 0.75) — O LADO DO CLIENTE EM AÇÃO VIVA
  // ===========================================================================
  Widget _buildAct3Client({
    required double localT,
    required bool isCompact,
    required bool reduceMotion,
    required bool includeSemanticActKey,
  }) {
    return Column(
      key: includeSemanticActKey ? const Key('cinema-act-3-client') : null,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildMarketingBadge(
          text: 'VOCÊ COMO CLIENTE · CONTROLE E GARANTIA REAL',
          accent: const Color(0xFFFF6D00),
          icon: Icons.shield_rounded,
        ),
        SizedBox(height: isCompact ? 10 : 14),
        _Act3ClientLiveStoryCard(
          localT: localT,
          isCompact: isCompact,
          reduceMotion: reduceMotion,
        ),
        SizedBox(height: isCompact ? 12 : 16),
        _buildMarketingHeadline(
          title: 'Seu dinheiro protegido até você aprovar o resultado.',
          subtitle:
              'Compare até 3 propostas, acompanhe a chegada no mapa ao vivo e só libere o valor com seu código PIN — com 90 dias de garantia.',
          isCompact: isCompact,
        ),
      ],
    );
  }

  // ===========================================================================
  // ATO IV (0.75 – 1.00) — O LADO DO PROFISSIONAL EM AÇÃO VIVA
  // ===========================================================================
  Widget _buildAct4Provider({
    required double localT,
    required bool isCompact,
    required bool reduceMotion,
    required bool includeSemanticActKey,
  }) {
    return Column(
      key: includeSemanticActKey ? const Key('cinema-act-4-provider') : null,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildMarketingBadge(
          text: 'VOCÊ COMO PROFISSIONAL · TALENTO VALORIZADO',
          accent: const Color(0xFF38BDF8),
          icon: Icons.workspace_premium_rounded,
        ),
        SizedBox(height: isCompact ? 10 : 14),
        _Act4ProviderLiveProsperityCard(
          localT: localT,
          isCompact: isCompact,
          reduceMotion: reduceMotion,
        ),
        SizedBox(height: isCompact ? 12 : 16),
        _buildMarketingHeadline(
          title: 'Saia de casa com o pagamento já garantido.',
          subtitle:
              'Atenda pedidos reais na sua região, receba 100% das peças com nota sem taxa e construa uma reputação 5 estrelas no seu PIX.',
          isCompact: isCompact,
        ),
      ],
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
          color: accent.withValues(alpha: 0.58),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 16,
          ),
        ],
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.55,
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
    bool goldenShaderHighlight = false,
  }) {
    final titleWidget = Text(
      title,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: isCompact ? 21.5 : 24.5,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        height: 1.15,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (goldenShaderHighlight)
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFFFE0A3),
                Color(0xFFFFB020),
                Color(0xFFFFFFFF),
              ],
              stops: [0.0, 0.45, 0.78, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.modulate,
            child: titleWidget,
          )
        else
          titleWidget,
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: isCompact ? 12.8 : 14.2,
            fontWeight: FontWeight.w500,
            height: 1.34,
          ),
        ),
      ],
    );
  }
}

class _CinemaActRenderLayer {
  const _CinemaActRenderLayer({
    required this.actIndex,
    required this.localT,
    required this.scale,
    required this.translateY,
    required this.opacity,
    required this.includeSemanticActKey,
  });

  final int actIndex;
  final double localT;
  final double scale;
  final double translateY;
  final double opacity;
  final bool includeSemanticActKey;
}

// =============================================================================
// CAMADA C — CARTÃO LIQUID-GLASS COM REFLEXO ESPECULAR DIAGONAL
// =============================================================================

class _SpecularGlassCard extends StatelessWidget {
  const _SpecularGlassCard({
    required this.localT,
    required this.accentColor,
    required this.backgroundColor,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final double localT;
  final Color accentColor;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: CustomPaint(
            foregroundPainter: _SpecularDiagonalSheenPainter(
              progress: localT,
              accentColor: accentColor,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.42),
                  width: 1.2,
                ),
              ),
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecularDiagonalSheenPainter extends CustomPainter {
  const _SpecularDiagonalSheenPainter({
    required this.progress,
    required this.accentColor,
  });

  final double progress;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final sweepX = -size.width * 0.45 + (size.width * 1.90) * progress;
    final start = Offset(sweepX - size.height * 0.35, 0);
    final end = Offset(sweepX + size.height * 0.35, size.height);

    final sheenPaint = Paint()
      ..shader = ui.Gradient.linear(
        start,
        end,
        [
          Colors.white.withValues(alpha: 0.0),
          accentColor.withValues(alpha: 0.05),
          Colors.white.withValues(alpha: 0.11),
          accentColor.withValues(alpha: 0.04),
          Colors.white.withValues(alpha: 0.0),
        ],
        const [0.0, 0.35, 0.50, 0.65, 1.0],
      );

    canvas.drawRect(Offset.zero & size, sheenPaint);

    // Filete de refração de vidro safira na borda superior
    final topRimPaint = Paint()
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, 0),
        [
          Colors.white.withValues(alpha: 0.04),
          Colors.white.withValues(alpha: 0.28),
          accentColor.withValues(alpha: 0.32),
          Colors.white.withValues(alpha: 0.04),
        ],
        const [0.0, 0.35, 0.68, 1.0],
      );
    canvas.drawLine(
      const Offset(18, 0.8),
      Offset(size.width - 18, 0.8),
      topRimPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpecularDiagonalSheenPainter old) =>
      old.progress != progress || old.accentColor != accentColor;
}

// =============================================================================
// CAMADA D.1 — ATO I: CENA VIVA DA RESIDÊNCIA ARQUITETÔNICA & CATARSE NO LAR
// =============================================================================

class _Act1LivingHomeCatharsisStage extends StatelessWidget {
  const _Act1LivingHomeCatharsisStage({
    required this.localT,
    required this.isCompact,
    required this.reduceMotion,
  });

  final double localT;
  final bool isCompact;
  final bool reduceMotion;

  static const List<(String, String)> _kCategories = <(String, String)>[
    ('Elétrica', 'Elétrica'),
    ('Encanador', 'Hidráulica'),
    ('Ar-condicionado', 'Climatização'),
    ('Chaveiro', 'Chaveiro'),
    ('Pintura', 'Pintura'),
    ('Marcenaria', 'Marcenaria'),
  ];

  @override
  Widget build(BuildContext context) {
    final drawProgress = Curves.easeOutCubic.transform(
      (localT / 0.48).clamp(0.0, 1.0),
    );
    final serenityWave = Curves.easeOutCubic.transform(
      ((localT - 0.20) / 0.52).clamp(0.0, 1.0),
    );
    final glowIntensity = 0.40 + 0.60 * math.sin(localT * math.pi);
    final sceneSize = isCompact ? 228.0 : 258.0;
    final orbitRadius = isCompact ? 86.0 : 100.0;

    return _SpecularGlassCard(
      localT: localT,
      accentColor: Color.lerp(
        const Color(0xFFFF6D00),
        const Color(0xFF22C55E),
        serenityWave * 0.45,
      )!,
      backgroundColor: const Color(0xFF0E182D).withValues(alpha: 0.76),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 14,
        vertical: isCompact ? 10 : 12,
      ),
      child: Center(
        child: SizedBox(
          width: sceneSize,
          height: sceneSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Residência Arquitetônica Brasileira ao Entardecer + Onda de Serenidade
              Positioned.fill(
                child: CustomPaint(
                  painter: _Act1ArchitecturalHomeCatharsisPainter(
                    progress: localT,
                    reduceMotion: reduceMotion,
                  ),
                ),
              ),
              // 6 CategoryBrandEmblems reais orbitando o lar conectados por filamentos
              for (var i = 0; i < _kCategories.length; i++)
                Builder(
                  builder: (context) {
                    final baseAngle =
                        (i * 2 * math.pi / _kCategories.length) - math.pi / 2;
                    final rot = reduceMotion ? 0.0 : localT * 0.36;
                    final angle = baseAngle + rot;
                    final entryT = Curves.easeOutBack.transform(
                      ((localT - i * 0.045) / 0.40).clamp(0.0, 1.0),
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
                              categoryName: _kCategories[i].$1,
                              size: isCompact ? 36 : 42,
                              showCornerBadge: false,
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A)
                                    .withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                              child: Text(
                                _kCategories[i].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.2,
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
              // Monograma Oficial Casa-Escudo "D" no coração da residência
              Transform.translate(
                offset: const Offset(0, -6),
                child: Container(
                  width: isCompact ? 62 : 70,
                  height: isCompact ? 62 : 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                    border: Border.all(
                      color: Color.lerp(
                        const Color(0xFFFF6D00),
                        const Color(0xFFFFD166),
                        serenityWave,
                      )!,
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF8A2B).withValues(alpha: 0.34),
                        blurRadius: 22,
                      ),
                      if (serenityWave > 0.1)
                        BoxShadow(
                          color: const Color(0xFF22C55E)
                              .withValues(alpha: 0.24 * serenityWave),
                          blurRadius: 28,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Act1ArchitecturalHomeCatharsisPainter extends CustomPainter {
  const _Act1ArchitecturalHomeCatharsisPainter({
    required this.progress,
    required this.reduceMotion,
  });

  final double progress;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final maxR = size.shortestSide * 0.44;

    // 1. Filamentos luminosos conectando o lar aos 6 emblemas em órbita
    final rot = reduceMotion ? 0.0 : progress * 0.36;
    for (var i = 0; i < 6; i++) {
      final baseAngle = (i * 2 * math.pi / 6) - math.pi / 2;
      final angle = baseAngle + rot;
      final entryT = Curves.easeOutCubic.transform(
        ((progress - i * 0.045) / 0.40).clamp(0.0, 1.0),
      );
      if (entryT <= 0.01) continue;

      final target = Offset(
        center.dx + math.cos(angle) * maxR * 0.86 * entryT,
        center.dy + math.sin(angle) * maxR * 0.86 * entryT,
      );
      final ctrlAngle = angle - 0.24;
      final ctrl = Offset(
        center.dx + math.cos(ctrlAngle) * maxR * 0.45 * entryT,
        center.dy + math.sin(ctrlAngle) * maxR * 0.45 * entryT,
      );

      final filamentPath = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, target.dx, target.dy);

      canvas.drawPath(
        filamentPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..shader = ui.Gradient.linear(
            center,
            target,
            [
              const Color(0xFFFFB020).withValues(alpha: 0.42 * entryT),
              const Color(0xFF22C55E).withValues(alpha: 0.24 * entryT),
            ],
          ),
      );

      // Fóton viajando pelo filamento até o lar
      final photonT = ((progress * 2.2 + i * 0.17) % 1.0);
      final inv = 1.0 - photonT;
      final px = inv * inv * center.dx +
          2 * inv * photonT * ctrl.dx +
          photonT * photonT * target.dx;
      final py = inv * inv * center.dy +
          2 * inv * photonT * ctrl.dy +
          photonT * photonT * target.dy;
      canvas.drawCircle(
        Offset(px, py),
        2.4,
        Paint()..color = const Color(0xFFFFE082).withValues(alpha: 0.85 * entryT),
      );
    }

    // 2. Silhueta da Residência Arquitetônica Brasileira ao Entardecer
    final homeWidth = size.width * 0.48;
    final homeHeight = size.height * 0.34;
    final homeLeft = center.dx - homeWidth * 0.5;
    final homeTop = center.dy - homeHeight * 0.36;
    final homeBottom = homeTop + homeHeight;

    // Jardim sutil e horizonte acolhedor na base da casa
    final gardenRect = Rect.fromCenter(
      center: Offset(center.dx, homeBottom + 4),
      width: homeWidth * 1.24,
      height: 12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(gardenRect, const Radius.circular(99)),
      Paint()
        ..shader = ui.Gradient.linear(
          gardenRect.centerLeft,
          gardenRect.centerRight,
          [
            const Color(0xFF10B981).withValues(alpha: 0.05),
            const Color(0xFF10B981).withValues(alpha: 0.28),
            const Color(0xFFFFB020).withValues(alpha: 0.26),
            const Color(0xFF10B981).withValues(alpha: 0.05),
          ],
          const [0.0, 0.32, 0.68, 1.0],
        ),
    );

    // Corpo estrutural da residência
    final wallRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        homeLeft + 8,
        homeTop + homeHeight * 0.34,
        homeLeft + homeWidth - 8,
        homeBottom,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      wallRect,
      Paint()
        ..color = const Color(0xFF15223B).withValues(alpha: 0.90),
    );
    canvas.drawRRect(
      wallRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFFFB020).withValues(alpha: 0.45),
    );

    // Telhado geométrico contemporâneo (cumeeira + beirais elegantes)
    final roofPath = Path()
      ..moveTo(homeLeft - 4, homeTop + homeHeight * 0.38)
      ..lineTo(center.dx, homeTop - 6)
      ..lineTo(homeLeft + homeWidth + 4, homeTop + homeHeight * 0.38);
    canvas.drawPath(
      roofPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = ui.Gradient.linear(
          Offset(homeLeft, homeTop),
          Offset(homeLeft + homeWidth, homeTop),
          const [
            Color(0xFFFF6D00),
            Color(0xFFFFD166),
            Color(0xFF22C55E),
          ],
          const [0.0, 0.52, 1.0],
        ),
    );

    // 3. Janelas Iluminadas: Pulso de Imprevisto (0.00..0.26) -> Luz Dourada de Paz (0.22..1.00)
    final serenityT = Curves.easeOutCubic.transform(
      ((progress - 0.22) / 0.48).clamp(0.0, 1.0),
    );
    final tensionFlicker = progress < 0.28
        ? (0.5 + 0.5 * math.sin(progress * math.pi * 24)).clamp(0.0, 1.0) *
            (1.0 - serenityT)
        : 0.0;

    final windowY = homeBottom - 20.0;
    final windowOffsets = <double>[
      homeLeft + 20,
      homeLeft + 36,
      homeLeft + homeWidth - 46,
      homeLeft + homeWidth - 30,
    ];

    for (var w = 0; w < windowOffsets.length; w++) {
      final wx = windowOffsets[w];
      final wRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(wx, windowY, 11, 13),
        const Radius.circular(3),
      );
      final isAlertWindow = w == 0 && tensionFlicker > 0.05;
      final winColor = isAlertWindow
          ? Color.lerp(
              const Color(0xFFFF3D00),
              const Color(0xFFFFB020),
              tensionFlicker,
            )!
          : Color.lerp(
              const Color(0xFF293B5F),
              const Color(0xFFFFD166),
              serenityT,
            )!;

      canvas.drawRRect(
        wRect,
        Paint()..color = winColor.withValues(alpha: 0.35 + 0.60 * serenityT),
      );
      if (serenityT > 0.15) {
        canvas.drawCircle(
          wRect.center,
          10 * serenityT,
          Paint()
            ..color =
                const Color(0xFFFFB020).withValues(alpha: 0.20 * serenityT),
        );
      }
    }

    // Pulso âmbar de imprevisto inicial (localT 0.00..0.26)
    if (progress <= 0.28) {
      final pulseT = (progress / 0.26).clamp(0.0, 1.0);
      final alertCenter = Offset(homeLeft + 25, windowY + 6);
      canvas.drawCircle(
        alertCenter,
        6 + 18 * pulseT,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 * (1.0 - pulseT)
          ..color =
              const Color(0xFFFF6D00).withValues(alpha: 0.75 * (1.0 - pulseT)),
      );
    }

    // 4. Onda luminosa esmeralda-dourada de serenidade (localT 0.22..0.70)
    if (progress >= 0.20 && progress <= 0.82) {
      final waveT = ((progress - 0.20) / 0.55).clamp(0.0, 1.0);
      final waveRadius = maxR * (0.24 + 0.76 * Curves.easeOutCubic.transform(waveT));
      final waveAlpha = (1.0 - waveT).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        waveRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 * waveAlpha + 0.8
          ..shader = ui.Gradient.linear(
            Offset(center.dx - waveRadius, center.dy),
            Offset(center.dx + waveRadius, center.dy),
            [
              const Color(0xFFFFD166).withValues(alpha: 0.65 * waveAlpha),
              const Color(0xFF22C55E).withValues(alpha: 0.72 * waveAlpha),
            ],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Act1ArchitecturalHomeCatharsisPainter old) =>
      old.progress != progress || old.reduceMotion != reduceMotion;
}

// =============================================================================
// CAMADA D.2 — ATO II: PONTE BIOMÉTRICA DUAL & FEIXE ÓPTICO
// =============================================================================

class _Act2BiometricTrustBridgeStage extends StatelessWidget {
  const _Act2BiometricTrustBridgeStage({
    required this.localT,
    required this.isCompact,
    required this.reduceMotion,
  });

  final double localT;
  final bool isCompact;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final shieldScale = 0.88 +
        0.12 *
            Curves.easeOutBack.transform(
              (localT / 0.45).clamp(0.0, 1.0),
            );

    final badge1T = Curves.easeOutBack.transform(
      ((localT - 0.10) / 0.36).clamp(0.0, 1.0),
    );
    final badge2T = Curves.easeOutBack.transform(
      ((localT - 0.20) / 0.36).clamp(0.0, 1.0),
    );
    final badge3T = Curves.easeOutBack.transform(
      ((localT - 0.30) / 0.36).clamp(0.0, 1.0),
    );

    return _SpecularGlassCard(
      localT: localT,
      accentColor: const Color(0xFF38BDF8),
      backgroundColor: const Color(0xFF111E38).withValues(alpha: 0.78),
      padding: EdgeInsets.all(isCompact ? 13 : 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ponte viva com 2 trilhas Bézier de fótons bidirecionais + Escudo Biométrico
          SizedBox(
            height: isCompact ? 68 : 78,
            width: double.infinity,
            child: CustomPaint(
              painter: _Act2BiometricTrustBridgePainter(
                progress: localT,
                reduceMotion: reduceMotion,
              ),
              child: Center(
                child: Transform.scale(
                  scale: shieldScale,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: CustomPaint(
                      foregroundPainter: _BiometricOpticalLaserPainter(
                        progress: localT,
                        reduceMotion: reduceMotion,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A2E23),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: const Color(0xFF22C55E),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF22C55E)
                                  .withValues(alpha: 0.35),
                              blurRadius: 18,
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
                            Flexible(
                              child: Text(
                                '1 Conta · 2 Perfis',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Os dois portais vivos
          Row(
            children: [
              Expanded(
                child: _buildPortalCard(
                  title: 'Quem protege seu lar',
                  subtitle: 'Abre a porta apenas para especialistas validados',
                  accent: const Color(0xFFFF8A2B),
                  icon: Icons.home_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPortalCard(
                  title: 'Quem honra seu ofício',
                  subtitle: 'Transforma talento técnico em renda justa',
                  accent: const Color(0xFF38BDF8),
                  icon: Icons.handyman_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          // 3 insígnias táteis entrando em cascata elástica
          Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.center,
            children: [
              Transform.scale(
                scale: 0.85 + 0.15 * badge1T.clamp(0.0, 1.15),
                child: _buildTactileTrustInsignia(
                  icon: Icons.face_retouching_natural_rounded,
                  label: 'Biometria Facial Ao Vivo',
                  accent: const Color(0xFF38BDF8),
                ),
              ),
              Transform.scale(
                scale: 0.85 + 0.15 * badge2T.clamp(0.0, 1.15),
                child: _buildTactileTrustInsignia(
                  icon: Icons.gavel_rounded,
                  label: 'Certidão Polícia Federal',
                  accent: const Color(0xFF22C55E),
                ),
              ),
              Transform.scale(
                scale: 0.85 + 0.15 * badge3T.clamp(0.0, 1.15),
                child: _buildTactileTrustInsignia(
                  icon: Icons.published_with_changes_rounded,
                  label: 'Alterne em 1 Toque',
                  accent: const Color(0xFFFF8A2B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPortalCard({
    required String title,
    required String subtitle,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 11.2,
              height: 1.24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTactileTrustInsignia({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: accent.withValues(alpha: 0.48)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Act2BiometricTrustBridgePainter extends CustomPainter {
  const _Act2BiometricTrustBridgePainter({
    required this.progress,
    required this.reduceMotion,
  });

  final double progress;
  final bool reduceMotion;

  static Offset _quadBezier(Offset p0, Offset p1, Offset p2, double t) {
    final inv = 1.0 - t;
    return Offset(
      inv * inv * p0.dx + 2 * inv * t * p1.dx + t * t * p2.dx,
      inv * inv * p0.dy + 2 * inv * t * p1.dy + t * t * p2.dy,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final leftPortal = Offset(size.width * 0.12, size.height * 0.66);
    final rightPortal = Offset(size.width * 0.88, size.height * 0.66);
    final upperControl = Offset(size.width * 0.50, -size.height * 0.18);
    final lowerControl = Offset(size.width * 0.50, size.height * 1.18);

    // Trilha Bézier superior (Cliente -> Profissional)
    final upperPath = Path()
      ..moveTo(leftPortal.dx, leftPortal.dy)
      ..quadraticBezierTo(
        upperControl.dx,
        upperControl.dy,
        rightPortal.dx,
        rightPortal.dy,
      );

    // Trilha Bézier inferior (Profissional -> Cliente)
    final lowerPath = Path()
      ..moveTo(rightPortal.dx, rightPortal.dy)
      ..quadraticBezierTo(
        lowerControl.dx,
        lowerControl.dy,
        leftPortal.dx,
        leftPortal.dy,
      );

    final trackShader = ui.Gradient.linear(
      leftPortal,
      rightPortal,
      const [
        Color(0xFFFF8A2B),
        Color(0xFF22C55E),
        Color(0xFF38BDF8),
      ],
      const [0.0, 0.5, 1.0],
    );

    canvas.drawPath(
      upperPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..shader = trackShader,
    );

    canvas.drawPath(
      lowerPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..shader = trackShader,
    );

    // Fótons luminosos viajando continuamente nos dois sentidos a 120 FPS
    for (var i = 0; i < 4; i++) {
      final forwardT =
          reduceMotion ? (0.2 + i * 0.2) : ((progress * 1.8 + i * 0.25) % 1.0);
      final pForward = _quadBezier(
        leftPortal,
        upperControl,
        rightPortal,
        forwardT,
      );
      canvas.drawCircle(
        pForward,
        5.5,
        Paint()..color = const Color(0xFFFFB020).withValues(alpha: 0.28),
      );
      canvas.drawCircle(
        pForward,
        2.6,
        Paint()..color = const Color(0xFFFFF3C4),
      );

      final reverseT =
          reduceMotion ? (0.15 + i * 0.2) : ((progress * 1.8 + i * 0.25) % 1.0);
      final pReverse = _quadBezier(
        rightPortal,
        lowerControl,
        leftPortal,
        reverseT,
      );
      canvas.drawCircle(
        pReverse,
        5.0,
        Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.28),
      );
      canvas.drawCircle(
        pReverse,
        2.4,
        Paint()..color = const Color(0xFFE0F2FE),
      );
    }

    // Portais luminosos nas extremidades
    canvas.drawCircle(
      leftPortal,
      11,
      Paint()..color = const Color(0xFFFF8A2B).withValues(alpha: 0.24),
    );
    canvas.drawCircle(
      leftPortal,
      5.5,
      Paint()..color = const Color(0xFFFF8A2B),
    );

    canvas.drawCircle(
      rightPortal,
      11,
      Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.24),
    );
    canvas.drawCircle(
      rightPortal,
      5.5,
      Paint()..color = const Color(0xFF38BDF8),
    );
  }

  @override
  bool shouldRepaint(covariant _Act2BiometricTrustBridgePainter old) =>
      old.progress != progress || old.reduceMotion != reduceMotion;
}

class _BiometricOpticalLaserPainter extends CustomPainter {
  const _BiometricOpticalLaserPainter({
    required this.progress,
    required this.reduceMotion,
  });

  final double progress;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scanNorm =
        reduceMotion ? 0.5 : (0.5 + 0.45 * math.sin(progress * math.pi * 4));
    final y = size.height * scanNorm;

    final glowRect = Rect.fromLTWH(0, y - 6, size.width, 12);
    canvas.drawRect(
      glowRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, y - 6),
          Offset(0, y + 6),
          [
            const Color(0xFF4ADE80).withValues(alpha: 0.0),
            const Color(0xFF4ADE80).withValues(alpha: 0.30),
            const Color(0xFF4ADE80).withValues(alpha: 0.0),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );

    canvas.drawLine(
      Offset(6, y),
      Offset(size.width - 6, y),
      Paint()
        ..color = const Color(0xFF86EFAC).withValues(alpha: 0.72)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _BiometricOpticalLaserPainter old) =>
      old.progress != progress || old.reduceMotion != reduceMotion;
}

// =============================================================================
// CAMADA D.3 — ATO III: MICRO-FILME INTERATIVO DO CLIENTE EM 3 BATIDAS VISUAIS
// =============================================================================

class _Act3ClientLiveStoryCard extends StatelessWidget {
  const _Act3ClientLiveStoryCard({
    required this.localT,
    required this.isCompact,
    required this.reduceMotion,
  });

  final double localT;
  final bool isCompact;
  final bool reduceMotion;

  static const List<String> _kPinDigits = <String>['4', '8', '2', '9'];

  @override
  Widget build(BuildContext context) {
    final fanT = Curves.easeOutBack.transform(
      (localT / 0.38).clamp(0.0, 1.0),
    );
    final routeT = Curves.easeInOutCubic.transform(
      ((localT - 0.24) / 0.44).clamp(0.0, 1.0),
    );
    final pinMasterT = Curves.easeOutCubic.transform(
      ((localT - 0.56) / 0.42).clamp(0.0, 1.0),
    );

    return _SpecularGlassCard(
      localT: localT,
      accentColor: const Color(0xFFFF6D00),
      backgroundColor: const Color(0xFF23140E).withValues(alpha: 0.84),
      padding: EdgeInsets.all(isCompact ? 12 : 15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // BATIDA 1 (0.00..0.38): Leque 3D de 3 Propostas Claras
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFF8A2B).withValues(alpha: 0.36),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.style_rounded,
                          size: 14,
                          color: Color(0xFFFF8A2B),
                        ),
                        SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Até 3 propostas claras',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6D00).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color:
                              const Color(0xFFFFB020).withValues(alpha: 0.65),
                        ),
                      ),
                      child: const Text(
                        '4,9 ★ / 5,0 ★',
                        style: TextStyle(
                          color: Color(0xFFFFE082),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Leque de 3 mini-cartões de orçamento
                Row(
                  children: [
                    Expanded(
                      child: Transform.rotate(
                        angle: reduceMotion ? 0.0 : -0.045 * fanT,
                        child: _buildMiniProposalCard(
                          label: 'Opção 1',
                          rating: '4,8 ★',
                          tag: 'Rápido',
                          isFeatured: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Transform.scale(
                        scale: 0.95 + 0.07 * fanT.clamp(0.0, 1.1),
                        child: _buildMiniProposalCard(
                          label: 'Escolhido',
                          rating: '4,9 ★',
                          tag: 'Verificado',
                          isFeatured: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Transform.rotate(
                        angle: reduceMotion ? 0.0 : 0.045 * fanT,
                        child: _buildMiniProposalCard(
                          label: 'Opção 3',
                          rating: '5,0 ★',
                          tag: 'Premium',
                          isFeatured: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // BATIDA 2 (0.26..0.68): Rota Viva + Escudo de Custódia
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFB020)
                    .withValues(alpha: 0.25 + 0.35 * routeT),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 28,
                  child: CustomPaint(
                    painter: _Act3LiveRouteEscrowPainter(
                      progress: routeT,
                      reduceMotion: reduceMotion,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: Color(0xFFFFB020),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pagamento guardado · 0% taxa em peças com NF-e · Endereço protegido',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 11.2,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // BATIDA 3 (0.58..1.00): Digitação Coreografada do PIN (4 · 8 · 2 · 9) -> Selo 90 Dias
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A2A1E)
                  .withValues(alpha: 0.45 + 0.40 * pinMasterT),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF22C55E)
                    .withValues(alpha: 0.32 + 0.48 * pinMasterT),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Seu PIN libera ao concluir:',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < _kPinDigits.length; i++)
                          Padding(
                            padding: EdgeInsets.only(left: i > 0 ? 5.0 : 0.0),
                            child: _buildOpticalPinCell(
                              digit: _kPinDigits[i],
                              activation: Curves.easeOutBack.transform(
                                ((localT - (0.56 + i * 0.065)) / 0.14)
                                    .clamp(0.0, 1.0),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E)
                        .withValues(alpha: 0.15 + 0.14 * pinMasterT),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 13,
                        color: Color(0xFF4ADE80),
                      ),
                      SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '✓ Aprovado por você · 90 dias de garantia técnica',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF86EFAC),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniProposalCard({
    required String label,
    required String rating,
    required String tag,
    required bool isFeatured,
  }) {
    final accent =
        isFeatured ? const Color(0xFFFF8A2B) : Colors.white.withValues(alpha: 0.35);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: isFeatured
            ? const Color(0xFFFF6D00).withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isFeatured
              ? const Color(0xFFFFB020)
              : Colors.white.withValues(alpha: 0.14),
          width: isFeatured ? 1.3 : 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: isFeatured ? 0.95 : 0.72),
              fontSize: 9.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            rating,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isFeatured ? const Color(0xFFFFE082) : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            tag,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 9.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpticalPinCell({
    required String digit,
    required double activation,
  }) {
    final clamped = activation.clamp(0.0, 1.0);
    return Transform.scale(
      scale: 0.92 + 0.08 * clamped,
      child: Container(
        width: 26,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Color.lerp(
            Colors.white.withValues(alpha: 0.07),
            const Color(0xFF22C55E).withValues(alpha: 0.28),
            clamped,
          ),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: Color.lerp(
              Colors.white.withValues(alpha: 0.22),
              const Color(0xFF4ADE80),
              clamped,
            )!,
            width: 1.2,
          ),
          boxShadow: clamped > 0.2
              ? [
                  BoxShadow(
                    color:
                        const Color(0xFF22C55E).withValues(alpha: 0.32 * clamped),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Text(
          digit,
          style: TextStyle(
            color: Color.lerp(
              Colors.white.withValues(alpha: 0.45),
              Colors.white,
              clamped,
            ),
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _Act3LiveRouteEscrowPainter extends CustomPainter {
  const _Act3LiveRouteEscrowPainter({
    required this.progress,
    required this.reduceMotion,
  });

  final double progress;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(14, size.height * 0.65);
    final end = Offset(size.width - 14, size.height * 0.55);
    final c1 = Offset(size.width * 0.35, size.height * 0.08);
    final c2 = Offset(size.width * 0.68, size.height * 0.95);

    final routePath = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);

    canvas.drawPath(
      routePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.16),
    );

    final activeT = reduceMotion ? 0.75 : progress.clamp(0.0, 1.0);
    // Subdivisão analítica de De Casteljau da curva cúbica em [0, activeT] (120 FPS, zero PathMetrics)
    final p01 = Offset.lerp(start, c1, activeT)!;
    final p12 = Offset.lerp(c1, c2, activeT)!;
    final p23 = Offset.lerp(c2, end, activeT)!;
    final p012 = Offset.lerp(p01, p12, activeT)!;
    final p123 = Offset.lerp(p12, p23, activeT)!;
    final beacon = Offset.lerp(p012, p123, activeT)!;

    final activeRoutePath = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(p01.dx, p01.dy, p012.dx, p012.dy, beacon.dx, beacon.dy);

    canvas.drawPath(
      activeRoutePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(
          start,
          end,
          const [Color(0xFFFF6D00), Color(0xFF22C55E)],
        ),
    );

    canvas.drawCircle(
      start,
      4.5,
      Paint()..color = const Color(0xFFFF8A2B),
    );
    canvas.drawCircle(
      end,
      5.5,
      Paint()..color = const Color(0xFF22C55E),
    );
    canvas.drawCircle(
      beacon,
      7.5,
      Paint()..color = const Color(0xFFFFB020).withValues(alpha: 0.30),
    );
    canvas.drawCircle(
      beacon,
      3.8,
      Paint()..color = const Color(0xFFFFE082),
    );
  }

  @override
  bool shouldRepaint(covariant _Act3LiveRouteEscrowPainter old) =>
      old.progress != progress || old.reduceMotion != reduceMotion;
}

// =============================================================================
// CAMADA D.4 — ATO IV: MICRO-FILME DE PROSPERIDADE DO PROFISSIONAL
// =============================================================================

class _Act4ProviderLiveProsperityCard extends StatelessWidget {
  const _Act4ProviderLiveProsperityCard({
    required this.localT,
    required this.isCompact,
    required this.reduceMotion,
  });

  final double localT;
  final bool isCompact;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final payoutBarT = Curves.easeOutCubic.transform(
      ((localT - 0.24) / 0.44).clamp(0.0, 1.0),
    );
    final starsMasterT = Curves.easeOutCubic.transform(
      ((localT - 0.56) / 0.42).clamp(0.0, 1.0),
    );

    return _SpecularGlassCard(
      localT: localT,
      accentColor: const Color(0xFF38BDF8),
      backgroundColor: const Color(0xFF0C1D38).withValues(alpha: 0.85),
      padding: EdgeInsets.all(isCompact ? 12 : 15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // BATIDA 1 (0.00..0.36): Sonar 360° de Chamados Reais na Região
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.38),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: isCompact ? 46 : 52,
                  height: isCompact ? 46 : 52,
                  child: CustomPaint(
                    painter: _Act4SonarRadarPainter(
                      progress: localT,
                      reduceMotion: reduceMotion,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Sonar 360° de chamados verificados',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF38BDF8).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'Na sua especialidade · Sem leilão predatório',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF7DD3FC),
                            fontSize: 10.4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // BATIDA 2 (0.28..0.68): Trava Anti-Calote + Barra Luminosa de Repasse PIX
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A2B21).withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF22C55E)
                    .withValues(alpha: 0.35 + 0.40 * payoutBarT),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      size: 14,
                      color: Color(0xFF4ADE80),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '✓ Valor 100% já reservado antes de sair de casa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF86EFAC),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    height: 7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: (0.22 + 0.78 * payoutBarT).clamp(0.0, 1.0),
                          heightFactor: 1.0,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF22C55E),
                                  Color(0xFF38BDF8),
                                  Color(0xFF86EFAC),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '0% de comissão sobre peças com NF-e · Saque rápido no PIX',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // BATIDA 3 (0.60..1.00): Ignição Sequencial das 5 Estrelas Douradas (★ ★ ★ ★ ★ 5,0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF261D0A)
                  .withValues(alpha: 0.45 + 0.40 * starsMasterT),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF5B400)
                    .withValues(alpha: 0.34 + 0.50 * starsMasterT),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.military_tech_rounded,
                      size: 15,
                      color: Color(0xFFFFD166),
                    ),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Vitrine e Reputação 5,0 ★',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 0; s < 5; s++)
                      Builder(
                        builder: (context) {
                          final starT = Curves.easeOutBack.transform(
                            ((localT - (0.58 + s * 0.06)) / 0.14)
                                .clamp(0.0, 1.0),
                          );
                          return Transform.scale(
                            scale: 0.86 + 0.18 * starT.clamp(0.0, 1.15),
                            child: Icon(
                              Icons.star_rounded,
                              size: isCompact ? 13.5 : 15.5,
                              color: Color.lerp(
                                Colors.white.withValues(alpha: 0.28),
                                const Color(0xFFFFD166),
                                starT.clamp(0.0, 1.0),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(width: 5),
                    const Flexible(
                      child: Text(
                        '★ ★ ★ ★ ★ 5,0',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFFFE082),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Act4SonarRadarPainter extends CustomPainter {
  const _Act4SonarRadarPainter({
    required this.progress,
    required this.reduceMotion,
  });

  final double progress;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = size.shortestSide * 0.46;

    // Anéis concêntricos do sonar
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(
        center,
        radius * (i / 3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xFF38BDF8).withValues(alpha: 0.22),
      );
    }

    // Feixe rotativo 360°
    final sweepAngle =
        reduceMotion ? -math.pi / 4 : (progress * math.pi * 4) - math.pi / 2;
    final beamEnd = Offset(
      center.dx + math.cos(sweepAngle) * radius,
      center.dy + math.sin(sweepAngle) * radius,
    );

    canvas.drawLine(
      center,
      beamEnd,
      Paint()
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(
          center,
          beamEnd,
          [
            const Color(0xFF22C55E).withValues(alpha: 0.2),
            const Color(0xFF38BDF8),
          ],
        ),
    );

    // 3 chamados reais verificados pulsando no radar
    const blips = <(double, double)>[
      (-0.7, 0.58),
      (0.85, 0.72),
      (2.3, 0.64),
    ];
    for (var i = 0; i < blips.length; i++) {
      final (angle, distNorm) = blips[i];
      final pos = Offset(
        center.dx + math.cos(angle) * radius * distNorm,
        center.dy + math.sin(angle) * radius * distNorm,
      );
      canvas.drawCircle(
        pos,
        4.5,
        Paint()..color = const Color(0xFF22C55E).withValues(alpha: 0.30),
      );
      canvas.drawCircle(
        pos,
        2.3,
        Paint()..color = const Color(0xFF4ADE80),
      );
    }

    canvas.drawCircle(
      center,
      3.0,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _Act4SonarRadarPainter old) =>
      old.progress != progress || old.reduceMotion != reduceMotion;
}

// =============================================================================
// CAMADA A — ATMOSFERA VOLUMÉTRICA DE AURORA EM SEDA + 36 PARTÍCULAS BOKEH
// =============================================================================

class _BokehParticleSpec {
  const _BokehParticleSpec(
    this.nx,
    this.ny,
    this.radius,
    this.plane,
    this.phase,
    this.warmTint,
  );

  final double nx;
  final double ny;
  final double radius;
  final int plane; // 0 = fundo, 1 = médio, 2 = primeiro plano
  final double phase;
  final bool warmTint;
}

class _VolumetricAuroraBokehPainter extends CustomPainter {
  const _VolumetricAuroraBokehPainter({
    required this.timeline,
    required this.reduceMotion,
  });

  final double timeline;
  final bool reduceMotion;

  // 36 partículas luminosas determinísticas pré-alocadas (zero alocação por frame)
  static const List<_BokehParticleSpec> _kBokehParticles = <_BokehParticleSpec>[
    // Plano 0: Fundo (14 partículas sutis)
    _BokehParticleSpec(0.08, 0.12, 1.8, 0, 0.1, true),
    _BokehParticleSpec(0.22, 0.08, 2.1, 0, 0.7, false),
    _BokehParticleSpec(0.38, 0.16, 1.6, 0, 1.3, true),
    _BokehParticleSpec(0.54, 0.10, 2.2, 0, 1.9, false),
    _BokehParticleSpec(0.71, 0.14, 1.9, 0, 2.5, true),
    _BokehParticleSpec(0.88, 0.09, 2.0, 0, 3.1, false),
    _BokehParticleSpec(0.14, 0.34, 1.7, 0, 3.7, false),
    _BokehParticleSpec(0.84, 0.31, 2.3, 0, 4.2, true),
    _BokehParticleSpec(0.11, 0.62, 1.9, 0, 4.8, true),
    _BokehParticleSpec(0.29, 0.74, 2.1, 0, 5.3, false),
    _BokehParticleSpec(0.67, 0.71, 1.8, 0, 5.9, true),
    _BokehParticleSpec(0.89, 0.66, 2.2, 0, 0.4, false),
    _BokehParticleSpec(0.42, 0.88, 1.7, 0, 1.1, true),
    _BokehParticleSpec(0.77, 0.91, 2.0, 0, 1.8, false),
    // Plano 1: Médio (14 partículas médias)
    _BokehParticleSpec(0.16, 0.22, 3.4, 1, 0.3, true),
    _BokehParticleSpec(0.33, 0.27, 4.0, 1, 0.9, false),
    _BokehParticleSpec(0.64, 0.24, 3.6, 1, 1.5, true),
    _BokehParticleSpec(0.82, 0.20, 4.2, 1, 2.1, false),
    _BokehParticleSpec(0.09, 0.46, 3.8, 1, 2.7, true),
    _BokehParticleSpec(0.26, 0.52, 3.2, 1, 3.3, false),
    _BokehParticleSpec(0.74, 0.48, 4.1, 1, 3.9, true),
    _BokehParticleSpec(0.92, 0.44, 3.5, 1, 4.5, false),
    _BokehParticleSpec(0.19, 0.68, 4.4, 1, 5.1, true),
    _BokehParticleSpec(0.48, 0.64, 3.3, 1, 5.7, false),
    _BokehParticleSpec(0.81, 0.76, 3.9, 1, 0.6, true),
    _BokehParticleSpec(0.15, 0.85, 3.7, 1, 1.4, false),
    _BokehParticleSpec(0.58, 0.84, 4.3, 1, 2.2, true),
    _BokehParticleSpec(0.86, 0.86, 3.5, 1, 3.0, false),
    // Plano 2: Primeiro Plano (8 halos bokeh suaves com maior paralaxe)
    _BokehParticleSpec(0.12, 0.18, 9.5, 2, 0.5, true),
    _BokehParticleSpec(0.85, 0.16, 11.0, 2, 1.2, false),
    _BokehParticleSpec(0.20, 0.40, 10.0, 2, 2.0, false),
    _BokehParticleSpec(0.79, 0.38, 12.0, 2, 2.8, true),
    _BokehParticleSpec(0.14, 0.72, 10.5, 2, 3.6, true),
    _BokehParticleSpec(0.83, 0.68, 11.5, 2, 4.4, false),
    _BokehParticleSpec(0.32, 0.89, 9.0, 2, 5.2, true),
    _BokehParticleSpec(0.70, 0.87, 10.8, 2, 6.0, false),
  ];

  static Color _sampleStops(List<Color> stops, double t) {
    final scaled = (t.clamp(0.0, 1.0)) * (stops.length - 1);
    final idx = scaled.floor().clamp(0, stops.length - 2);
    final frac = scaled - idx;
    return Color.lerp(stops[idx], stops[idx + 1], frac)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Convergência dos últimos 8% (0.92..1.00) para a paleta RoleSelectionScreen (#0E1218)
    final endConvergence =
        Curves.easeInOutCubic.transform(((timeline - 0.92) / 0.08).clamp(0.0, 1.0));

    final rawTop = _sampleStops(
      const [
        Color(0xFF0F172A), // Ato I
        Color(0xFF121F3B), // Ato II
        Color(0xFF24140E), // Ato III
        Color(0xFF0C1D38), // Ato IV
        Color(0xFF0E1218), // Final
      ],
      timeline,
    );
    final rawBottom = _sampleStops(
      const [
        Color(0xFF090E1A),
        Color(0xFF0B1426),
        Color(0xFF120B08),
        Color(0xFF081224),
        Color(0xFF141A22),
      ],
      timeline,
    );

    final bgTop = Color.lerp(rawTop, const Color(0xFF0E1218), endConvergence)!;
    final bgBottom =
        Color.lerp(rawBottom, const Color(0xFF141A22), endConvergence)!;

    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.5, 0),
          Offset(size.width * 0.5, size.height),
          [bgTop, bgBottom],
        ),
    );

    final primaryAurora = _sampleStops(
      const [
        Color(0xFFFF6D00),
        Color(0xFF38BDF8),
        Color(0xFFFF6D00),
        Color(0xFF1D6FE0),
        Color(0xFFFF8F52),
      ],
      timeline,
    );
    final secondaryAurora = _sampleStops(
      const [
        Color(0xFF22C55E),
        Color(0xFFFF8A2B),
        Color(0xFFFFB020),
        Color(0xFF22C55E),
        Color(0xFF74A7FF),
      ],
      timeline,
    );

    // 1. Halos radiais convergentes
    final drift = reduceMotion ? 0.0 : math.sin(timeline * math.pi * 2) * 0.08;
    final c1 = Offset.lerp(
      Offset(
        size.width * (0.78 + drift),
        size.height * (0.18 - drift * 0.5),
      ),
      Offset(size.width * 0.50, size.height * 0.36),
      endConvergence,
    )!;
    final c2 = Offset.lerp(
      Offset(
        size.width * (0.22 - drift),
        size.height * (0.80 + drift * 0.5),
      ),
      Offset(size.width * 0.50, size.height * 0.64),
      endConvergence,
    )!;

    final r1 = size.shortestSide * 0.68;
    final r2 = size.shortestSide * 0.74;

    canvas.drawCircle(
      c1,
      r1,
      Paint()
        ..shader = ui.Gradient.radial(
          c1,
          r1,
          [
            primaryAurora.withValues(alpha: 0.22 * (1.0 - 0.35 * endConvergence)),
            primaryAurora.withValues(alpha: 0.0),
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
            secondaryAurora.withValues(
              alpha: 0.18 * (1.0 - 0.35 * endConvergence),
            ),
            secondaryAurora.withValues(alpha: 0.0),
          ],
        ),
    );

    // 2. Cortinas de Aurora em Seda (Curvas Bézier Multi-Senoidais)
    final phase = reduceMotion ? 0.0 : timeline * math.pi * 2;
    final wave1Y = size.height * (0.28 + 0.04 * math.sin(phase));
    final auroraPath1 = Path()
      ..moveTo(0, wave1Y)
      ..cubicTo(
        size.width * 0.32,
        wave1Y - size.height * (0.09 + 0.03 * math.cos(phase)),
        size.width * 0.68,
        wave1Y + size.height * (0.09 + 0.03 * math.sin(phase * 1.3)),
        size.width,
        wave1Y - size.height * 0.03,
      )
      ..lineTo(size.width, wave1Y + size.height * 0.18)
      ..lineTo(0, wave1Y + size.height * 0.18)
      ..close();

    canvas.drawPath(
      auroraPath1,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, wave1Y - size.height * 0.08),
          Offset(0, wave1Y + size.height * 0.18),
          [
            primaryAurora.withValues(alpha: 0.0),
            primaryAurora.withValues(alpha: 0.11 * (1.0 - 0.5 * endConvergence)),
            secondaryAurora.withValues(alpha: 0.0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    // 3. 36 Partículas Bokeh com Paralaxe em 3 Planos de Profundidade
    for (var i = 0; i < _kBokehParticles.length; i++) {
      final p = _kBokehParticles[i];
      final parallaxSpeed = switch (p.plane) {
        0 => 0.035,
        1 => 0.085,
        _ => 0.15,
      };
      final dyShift = reduceMotion ? 0.0 : -timeline * parallaxSpeed;
      final dxWave = reduceMotion
          ? 0.0
          : math.sin(timeline * math.pi * 2 + p.phase) *
              (0.012 * (p.plane + 1));

      final rawX = ((p.nx + dxWave) % 1.0) * size.width;
      final rawY = ((p.ny + dyShift) % 1.0) * size.height;

      // Convergência suave nos últimos 8% em direção ao eixo central
      final pos = Offset.lerp(
        Offset(rawX, rawY),
        Offset(size.width * 0.5, size.height * 0.5),
        endConvergence * 0.28,
      )!;

      final baseAlpha = switch (p.plane) {
        0 => 0.18,
        1 => 0.22,
        _ => 0.10,
      };
      final twinkle = reduceMotion
          ? 1.0
          : (0.72 + 0.28 * math.sin(timeline * math.pi * 4 + p.phase));
      final color = p.warmTint ? primaryAurora : secondaryAurora;

      canvas.drawCircle(
        pos,
        p.radius,
        Paint()
          ..color = Color.lerp(color, Colors.white, p.plane == 0 ? 0.55 : 0.25)!
              .withValues(
                alpha: (baseAlpha * twinkle * (1.0 - 0.35 * endConvergence))
                    .clamp(0.02, 0.35),
              ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VolumetricAuroraBokehPainter old) =>
      old.timeline != timeline || old.reduceMotion != reduceMotion;
}

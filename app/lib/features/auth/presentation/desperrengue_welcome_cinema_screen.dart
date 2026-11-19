import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/category_brand_emblem.dart';
import '../../../core/ui/desperrengue_brand_logo.dart';

/// Experiência interativa de 6 Stories pós-cadastro estilo Spotify Wrapped,
/// Apple App Store Stories, Instagram Stories e WhatsApp Status (120 FPS).
///
/// Regras ergonômicas e de negócio:
/// - **6 Stories respiráveis** com `8,5s` (`8500ms`) por Story por padrão
///   (`totalDuration = const Duration(milliseconds: 51000)`).
/// - **Navegação interativa completa**:
///   1. Toque na direita (`x >= width * 0.34`, `Key('story-tap-zone-next')`)
///      avança imediatamente para o próximo Story (ou conclui no último).
///   2. Toque na esquerda (`x < width * 0.34`, `Key('story-tap-zone-prev')`)
///      volta para o Story anterior (ou reinicia o Story 1).
///   3. Deslize horizontal (`onHorizontalDragEnd`) para esquerda/direita.
///   4. Segurar o dedo (`onLongPressStart` / `onLongPressEnd` / `onLongPressUp`)
///      pausa imediatamente para leitura (`Key('cinema-paused-badge')`) e
///      retoma do mesmo ponto ao soltar.
///   5. 6 barras superiores clicáveis (`Key('cinema-chapter-tap-0')` .. `5`)
///      dentro de `Key('welcome-cinema-progress-bar')`.
///   6. Barra tátil inferior com `< Anterior` (`Key('btn-story-prev')`),
///      indicador `1 de 6` e `Próximo >` / `Começar agora →`
///      (`Key('btn-story-next')`).
class DesperrengueWelcomeCinemaScreen extends StatefulWidget {
  const DesperrengueWelcomeCinemaScreen({
    super.key,
    this.userFirstName = '',
    required this.onCompleted,
    this.isReplay = false,
    this.totalDuration = const Duration(milliseconds: 51000),
  });

  static const int storyCount = 6;

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
  static const int _kStoryCount = DesperrengueWelcomeCinemaScreen.storyCount;

  static const List<double> _kHapticMilestones = <double>[
    1.0 / 6.0,
    2.0 / 6.0,
    3.0 / 6.0,
    4.0 / 6.0,
    5.0 / 6.0,
  ];

  late final AnimationController _controller;
  bool _isPaused = false;
  bool _completedDispatched = false;
  int _lastHapticStep = -1;
  int _lastObservedStoryIndex = 0;
  int _navigationSlideDirection = 1;
  double _dragDeltaX = 0.0;

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
          _completeShowcase();
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

  void _completeShowcase() {
    if (_completedDispatched) return;
    _completedDispatched = true;
    _isPaused = false;
    _lastHapticStep = _kHapticMilestones.length;
    _controller.stop();
    HapticFeedback.mediumImpact();
    widget.onCompleted();
  }

  void _onTimelineTick() {
    if (_completedDispatched) return;
    final t = _controller.value.clamp(0.0, 1.0);
    final currentStory = _storyIndexFor(t);
    if (currentStory != _lastObservedStoryIndex) {
      _navigationSlideDirection =
          currentStory >= _lastObservedStoryIndex ? 1 : -1;
      _lastObservedStoryIndex = currentStory;
    }
    for (var i = _lastHapticStep + 1; i < _kHapticMilestones.length; i++) {
      if (t >= _kHapticMilestones[i] - 1e-6) {
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
      if (t >= _kHapticMilestones[i] - 1e-6) {
        step = i;
      } else {
        break;
      }
    }
    _lastHapticStep = step;
  }

  static int _storyIndexFor(double t) {
    final scaled = (t.clamp(0.0, 1.0) * _kStoryCount) + 1e-7;
    return scaled.floor().clamp(0, _kStoryCount - 1);
  }

  static double _storyLocalProgress(double t, int storyIndex) {
    return ((t.clamp(0.0, 1.0) * _kStoryCount) - storyIndex).clamp(0.0, 1.0);
  }

  void _jumpToChapter(int chapterIndex) {
    if (_completedDispatched) return;
    final current = _storyIndexFor(_controller.value);
    final clampedIndex = chapterIndex.clamp(0, _kStoryCount - 1);
    final targetT = (clampedIndex / _kStoryCount).clamp(0.0, 0.9999);
    _isPaused = false;
    _navigationSlideDirection = clampedIndex >= current ? 1 : -1;
    _lastObservedStoryIndex = clampedIndex;
    _syncHapticStepForTimeline(targetT);
    HapticFeedback.selectionClick();
    _controller.forward(from: targetT);
    setState(() {});
  }

  void _goToNextStory() {
    if (_completedDispatched) return;
    final current = _storyIndexFor(_controller.value);
    if (current >= _kStoryCount - 1) {
      HapticFeedback.lightImpact();
      _completeShowcase();
      return;
    }
    final nextIndex = current + 1;
    final targetT = (nextIndex / _kStoryCount).clamp(0.0, 0.9999);
    _isPaused = false;
    _navigationSlideDirection = 1;
    _lastObservedStoryIndex = nextIndex;
    _syncHapticStepForTimeline(targetT);
    HapticFeedback.lightImpact();
    _controller.forward(from: targetT);
    setState(() {});
  }

  void _goToPreviousStory() {
    if (_completedDispatched) return;
    final current = _storyIndexFor(_controller.value);
    final prevIndex = current > 0 ? current - 1 : 0;
    final targetT = (prevIndex / _kStoryCount).clamp(0.0, 0.9999);
    _isPaused = false;
    _navigationSlideDirection = -1;
    _lastObservedStoryIndex = prevIndex;
    _syncHapticStepForTimeline(targetT);
    HapticFeedback.selectionClick();
    _controller.forward(from: targetT);
    setState(() {});
  }

  void _handleHorizontalDragStart(DragStartDetails details) {
    _dragDeltaX = 0.0;
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    _dragDeltaX += details.primaryDelta ?? details.delta.dx;
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (_completedDispatched) return;
    final velocity = details.primaryVelocity ?? 0.0;
    final deltaX = _dragDeltaX;
    _dragDeltaX = 0.0;

    if (velocity < -180 || (velocity <= 0 && deltaX < -42)) {
      _goToNextStory();
    } else if (velocity > 180 || (velocity >= 0 && deltaX > 42)) {
      _goToPreviousStory();
    }
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
    _completeShowcase();
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

  static Color _accentForStory(int storyIndex) {
    switch (storyIndex) {
      case 0:
        return const Color(0xFFFF6D00);
      case 1:
        return const Color(0xFF38BDF8);
      case 2:
        return const Color(0xFF10B981);
      case 3:
        return const Color(0xFFF59E0B);
      case 4:
        return const Color(0xFF38BDF8);
      default:
        return const Color(0xFFFF8A2B);
    }
  }

  static String _storyHeaderSubtitle(int storyIndex) {
    switch (storyIndex) {
      case 0:
        return '1/6 · 33 Especialidades & SOS';
      case 1:
        return '2/6 · Pedido por Voz & Cotação';
      case 2:
        return '3/6 · Custódia PIN & Garantia';
      case 3:
        return '4/6 · Prontuário Oficial ABNT';
      case 4:
        return '5/6 · Modo Profissional & PIX';
      default:
        return '6/6 · 1 Conta · 2 Mundos';
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(10.0) / 10.0;

    return PopScope(
      canPop: widget.isReplay,
      child: AppScaffold(
        backgroundColor: const Color(0xFF070D19),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _handleHorizontalDragStart,
          onHorizontalDragUpdate: _handleHorizontalDragUpdate,
          onHorizontalDragEnd: _handleHorizontalDragEnd,
          onLongPressStart: (_) => _pauseForReading(),
          onLongPressEnd: (_) => _resumeFromReading(),
          onLongPressUp: _resumeFromReading,
          onLongPressCancel: _resumeFromReading,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value.clamp(0.0, 1.0);
              final storyIndex = _storyIndexFor(t);
              final localT = _storyLocalProgress(t, storyIndex);

              final perStoryMs = math.max(
                240.0,
                widget.totalDuration.inMilliseconds / _kStoryCount,
              );
              final entryWindow = (320.0 / perStoryMs).clamp(0.035, 0.24);
              final entryProgress = reduceMotion
                  ? 1.0
                  : Curves.easeOutQuart.transform(
                      (localT / entryWindow).clamp(0.0, 1.0),
                    );
              final slideDx =
                  (1.0 - entryProgress) * 18.0 * _navigationSlideDirection;
              final entryScale = 0.985 + (0.015 * entryProgress);
              final entryOpacity = (0.78 + (0.22 * entryProgress)).clamp(
                0.75,
                1.0,
              );

              return Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _StoryAtmospherePainter(
                        storyIndex: storyIndex,
                        localT: localT,
                        globalT: t,
                        reduceMotion: reduceMotion,
                      ),
                    ),
                  ),
                  SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact =
                            constraints.maxHeight < 690 ||
                            constraints.maxWidth < 360 ||
                            textScale > 1.2;

                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            isCompact ? 12 : 18,
                            isCompact ? 6 : 10,
                            isCompact ? 12 : 18,
                            isCompact ? 8 : 14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildTopStoriesHud(
                                storyIndex: storyIndex,
                                localT: localT,
                                isCompact: isCompact,
                              ),
                              SizedBox(height: isCompact ? 6 : 10),
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Opacity(
                                      opacity: entryOpacity,
                                      child: Transform.translate(
                                        offset: Offset(slideDx, 0),
                                        child: Transform.scale(
                                          scale: entryScale,
                                          alignment: Alignment.center,
                                          child: _buildStoryStage(
                                            storyIndex: storyIndex,
                                            localT: localT,
                                            globalT: t,
                                            isCompact: isCompact,
                                            reduceMotion: reduceMotion,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            flex: 34,
                                            child: GestureDetector(
                                              key: const Key(
                                                'story-tap-zone-prev',
                                              ),
                                              behavior:
                                                  HitTestBehavior.translucent,
                                              onTap: _goToPreviousStory,
                                              onLongPressStart: (_) =>
                                                  _pauseForReading(),
                                              onLongPressEnd: (_) =>
                                                  _resumeFromReading(),
                                              onLongPressUp: _resumeFromReading,
                                              onLongPressCancel:
                                                  _resumeFromReading,
                                              child: const SizedBox.expand(),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 66,
                                            child: GestureDetector(
                                              key: const Key(
                                                'story-tap-zone-next',
                                              ),
                                              behavior:
                                                  HitTestBehavior.translucent,
                                              onTap: _goToNextStory,
                                              onLongPressStart: (_) =>
                                                  _pauseForReading(),
                                              onLongPressEnd: (_) =>
                                                  _resumeFromReading(),
                                              onLongPressUp: _resumeFromReading,
                                              onLongPressCancel:
                                                  _resumeFromReading,
                                              child: const SizedBox.expand(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: isCompact ? 6 : 12),
                              _buildBottomStoryNavigation(
                                storyIndex: storyIndex,
                                isCompact: isCompact,
                              ),
                            ],
                          ),
                        );
                      },
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

  // ===========================================================================
  // TOPO: 6 BARRAS DE PROGRESSO ESTILO INSTAGRAM/WHATSAPP + CABEÇALHO DA MARCA
  // ===========================================================================
  Widget _buildTopStoriesHud({
    required int storyIndex,
    required double localT,
    required bool isCompact,
  }) {
    final accent = _accentForStory(storyIndex);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: const Key('welcome-cinema-progress-bar'),
          height: isCompact ? 22 : 28,
          child: Row(
            children: List.generate(_kStoryCount, (i) {
              final double segFill;
              if (i < storyIndex) {
                segFill = 1.0;
              } else if (i == storyIndex) {
                segFill = localT.clamp(0.0, 1.0);
              } else {
                segFill = 0.0;
              }
              final isCurrent = i == storyIndex;

              return Expanded(
                child: GestureDetector(
                  key: Key('cinema-chapter-tap-$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _jumpToChapter(i),
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i < _kStoryCount - 1 ? 5.0 : 0.0,
                      top: isCompact ? 9.0 : 12.0,
                      bottom: isCompact ? 9.0 : 12.0,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: isCurrent ? 0.25 : 0.15,
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
                                    accent,
                                    Colors.white.withValues(alpha: 0.96),
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
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DesperrengueBrandLogo(
              size: isCompact ? 24 : 28,
              borderRadius: isCompact ? 7 : 8,
              showShadow: false,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  const Flexible(
                    child: Text(
                      'Desperrengue',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.verified_rounded,
                    size: 13.5,
                    color: Color(0xFF38BDF8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _storyHeaderSubtitle(storyIndex),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 11.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isPaused)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Container(
                    key: const Key('cinema-paused-badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6D00).withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: const Color(0xFFFF8A2B).withValues(alpha: 0.72),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pause_circle_filled_rounded,
                          size: 12,
                          color: Color(0xFFFFB020),
                        ),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Pausado para leitura',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (widget.isReplay)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: TextButton.icon(
                  key: const Key('btn-close-replay-cinema'),
                  onPressed: _closeReplay,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 8 : 11,
                      vertical: isCompact ? 4 : 6,
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
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text(
                    'Fechar',
                    style: TextStyle(
                      fontSize: 11.5,
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

  // ===========================================================================
  // RODAPÉ TÁTIL DE NAVEGAÇÃO ENTRE STORIES (< ANTERIOR · 1 DE 6 · PRÓXIMO >)
  // ===========================================================================
  Widget _buildBottomStoryNavigation({
    required int storyIndex,
    required bool isCompact,
  }) {
    final canGoBack = storyIndex > 0;
    final isLastStory = storyIndex == _kStoryCount - 1;
    final accent = _accentForStory(storyIndex);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Opacity(
            opacity: canGoBack ? 1.0 : 0.42,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('btn-story-prev'),
                onTap: _goToPreviousStory,
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 8 : 13,
                    vertical: isCompact ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.chevron_left_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          'Anterior',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 11.0 : 12.0,
                            fontWeight: FontWeight.w700,
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
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${storyIndex + 1} de $_kStoryCount',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.90),
                  fontSize: isCompact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                _isPaused
                    ? 'Solte para retomar'
                    : 'Toque nas laterais ou deslize',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.54),
                  fontSize: isCompact ? 9.5 : 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('btn-story-next'),
              onTap: _goToNextStory,
              borderRadius: BorderRadius.circular(99),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 9 : 15,
                  vertical: isCompact ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  gradient: isLastStory
                      ? const LinearGradient(
                          colors: [Color(0xFFFF6D00), Color(0xFFFF8A2B)],
                        )
                      : LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0.24),
                            Colors.white.withValues(alpha: 0.10),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: isLastStory
                        ? const Color(0xFFFFB020)
                        : accent.withValues(alpha: 0.55),
                  ),
                  boxShadow: isLastStory
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFFFF6D00,
                            ).withValues(alpha: 0.38),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        isLastStory ? 'Começar agora →' : 'Próximo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 11.0 : 12.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!isLastStory) ...[
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SELETOR DOS 6 STORIES DO PLANO DE NEGÓCIOS DESPERRENGUE
  // ===========================================================================
  Widget _buildStoryStage({
    required int storyIndex,
    required double localT,
    required double globalT,
    required bool isCompact,
    required bool reduceMotion,
  }) {
    switch (storyIndex) {
      case 0:
        return _buildStory1Ecosystem(
          localT: localT,
          globalT: globalT,
          isCompact: isCompact,
          reduceMotion: reduceMotion,
        );
      case 1:
        return _buildStory2ClientVoice(
          localT: localT,
          globalT: globalT,
          isCompact: isCompact,
          reduceMotion: reduceMotion,
        );
      case 2:
        return _buildStory3ClientProtection(
          localT: localT,
          globalT: globalT,
          isCompact: isCompact,
          reduceMotion: reduceMotion,
        );
      case 3:
        return _buildStory4HomePassport(
          localT: localT,
          globalT: globalT,
          isCompact: isCompact,
          reduceMotion: reduceMotion,
        );
      case 4:
        return _buildStory5ProviderMode(
          localT: localT,
          globalT: globalT,
          isCompact: isCompact,
          reduceMotion: reduceMotion,
        );
      default:
        return _buildStory6DualWorld(
          localT: localT,
          globalT: globalT,
          isCompact: isCompact,
          reduceMotion: reduceMotion,
        );
    }
  }

  Widget _buildEditorialStoryLayout({
    required Key storyKey,
    required Color accentColor,
    required IconData badgeIcon,
    required String badgeText,
    required String title,
    required String subtitle,
    required Widget mockupCard,
    required bool isCompact,
  }) {
    return Column(
      key: storyKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 460,
                maxHeight: isCompact ? 350 : 415,
              ),
              child: mockupCard,
            ),
          ),
        ),
        SizedBox(height: isCompact ? 8 : 14),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 9 : 11,
                vertical: isCompact ? 3.5 : 5,
              ),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    badgeIcon,
                    size: isCompact ? 11.5 : 13,
                    color: accentColor,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      badgeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: isCompact ? 9.5 : 10.8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isCompact ? 6 : 9),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 18.0 : 24.5,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                height: 1.14,
              ),
            ),
            SizedBox(height: isCompact ? 4 : 7),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: isCompact ? 11.5 : 13.8,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeepGlassMockupShell({
    required Color accentColor,
    required String windowTitle,
    required String windowStatusBadge,
    required IconData windowIcon,
    required bool isCompact,
    required Widget child,
    double localT = 0.0,
    bool reduceMotion = false,
  }) {
    final specularShift = reduceMotion ? 0.0 : (localT - 0.5) * 0.45;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isCompact ? 18 : 24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF131D31),
            Color(0xFF0E1626),
            Color(0xFF0A101D),
          ],
        ),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.34),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF020617).withValues(alpha: 0.60),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: accentColor.withValues(alpha: 0.12),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isCompact ? 18 : 24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Reflexo diagonal suave guiado por localT (Glassmorphism 120 FPS)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-0.85 + specularShift, -1.0),
                      end: Alignment(0.85 + specularShift, 1.0),
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.035),
                        accentColor.withValues(alpha: 0.045),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.42, 0.56, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Chanfro especular luminoso superior de vidro premium
            Positioned(
              left: 16,
              right: 16,
              top: 0,
              height: 1.4,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.42),
                        accentColor.withValues(alpha: 0.55),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isCompact ? 11 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barra Superior do Mini-App Mockup
              Row(
                children: [
                  Container(
                    width: isCompact ? 24 : 28,
                    height: isCompact ? 24 : 28,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Icon(
                      windowIcon,
                      size: isCompact ? 13 : 15,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      windowTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.94),
                        fontSize: isCompact ? 11.2 : 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.40),
                        ),
                      ),
                      child: Text(
                        windowStatusBadge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: isCompact ? 9.5 : 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 8 : 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, innerConstraints) {
                    return SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: innerConstraints.maxHeight,
                        ),
                        child: child,
                      ),
                    );
                  },
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

  // ===========================================================================
  // STORY 1 (index 0, Key('cinema-act-1-mission'))
  // O Ecossistema: 33 Especialidades & SOS < 60s
  // ===========================================================================
  Widget _buildStory1Ecosystem({
    required double localT,
    required double globalT,
    required bool isCompact,
    required bool reduceMotion,
  }) {
    final name = _cleanFirstName;
    final badgeText =
        'BEM-VINDO(A)${name.isNotEmpty ? ', ${name.toUpperCase()}' : ''} · 33 ESPECIALIDADES';

    const topRowSpecs = <(String, String, String)>[
      ('Elétrica', 'Elétrica', 'SOS 24h · ★ 4,9'),
      ('Encanador', 'Hidráulica', 'SOS 24h · ★ 5,0'),
      ('Ar-condicionado', 'Climatização', 'Split & PMOC'),
      ('Chaveiro', 'Chaveiro', 'Chegada < 25m'),
      ('Pintura', 'Pintura', 'Acabamento Fino'),
    ];

    const bottomRowSpecs = <(String, String, String)>[
      ('Marcenaria', 'Marcenaria', 'Sob Medida'),
      ('Impermeabilização', 'Impermeabilização', 'Laudo & Garantia'),
      ('Energia Solar', 'Energia Solar', 'Projetos Fotovoltaicos'),
      ('Vidraceiro', 'Vidraçaria', 'Temperado & Box'),
      ('Montagem', 'Montagem', 'Móveis Modulares'),
    ];

    final pulse = reduceMotion
        ? 0.5
        : (0.5 + 0.5 * math.sin(localT * math.pi * 6.0));

    final mockup = _buildDeepGlassMockupShell(
      accentColor: const Color(0xFFFF6D00),
      windowTitle: 'Explorar o Ecossistema Desperrengue',
      windowStatusBadge: '33 Áreas Ativas',
      windowIcon: Icons.grid_view_rounded,
      isCompact: isCompact,
      localT: localT,
      reduceMotion: reduceMotion,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de Busca Viva do App + Pílula Pulsante SOS < 60s
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 12,
              vertical: isCompact ? 7 : 9,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: Color(0xFFFF8A2B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Qual especialista sua casa precisa hoje?',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.80),
                      fontSize: isCompact ? 10.8 : 12.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6D00).withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    ' IA + Voz',
                    style: TextStyle(
                      color: Color(0xFFFFB020),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 7 : 10),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 12,
              vertical: isCompact ? 6.5 : 8.5,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF3B30).withValues(
                    alpha: 0.20 + 0.08 * pulse,
                  ),
                  const Color(0xFFFF6D00).withValues(alpha: 0.16),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF6D00).withValues(
                  alpha: 0.55 + 0.25 * pulse,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF6D00),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6D00).withValues(alpha: 0.85),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚡ Emergência SOS · Resposta < 60s',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 10.8 : 12.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '24/7',
                  style: TextStyle(
                    color: Color(0xFFFFB020),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 8 : 12),
          // 2 Esteiras Horizontais Infinitas (Marquee 120 FPS em sentidos opostos)
          _InfiniteSpecialtyMarqueeBelt(
            items: topRowSpecs,
            phase: reduceMotion ? 0.12 : localT,
            reverse: false,
            isCompact: isCompact,
          ),
          SizedBox(height: isCompact ? 7 : 10),
          _InfiniteSpecialtyMarqueeBelt(
            items: bottomRowSpecs,
            phase: reduceMotion ? 0.35 : localT,
            reverse: true,
            isCompact: isCompact,
          ),
          SizedBox(height: isCompact ? 8 : 12),
          // Rodapé de Selos do Ecossistema
          Row(
            children: [
              Expanded(
                child: _buildMiniMetricChip(
                  icon: Icons.verified_user_rounded,
                  label: '100% Auditados',
                  color: const Color(0xFF10B981),
                  isCompact: isCompact,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniMetricChip(
                  icon: Icons.flash_on_rounded,
                  label: 'Match < 60s',
                  color: const Color(0xFFFF8A2B),
                  isCompact: isCompact,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniMetricChip(
                  icon: Icons.home_repair_service_rounded,
                  label: '33 Categorias',
                  color: const Color(0xFF38BDF8),
                  isCompact: isCompact,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return _buildEditorialStoryLayout(
      storyKey: const Key('cinema-act-1-mission'),
      accentColor: const Color(0xFFFF6D00),
      badgeIcon: Icons.auto_awesome_rounded,
      badgeText: badgeText,
      title: 'Sua casa resolvida por especialistas verificados.',
      subtitle:
          'De um reparo urgente SOS em menos de 60 segundos até manutenções completas, tudo em um só lugar.',
      mockupCard: mockup,
      isCompact: isCompact,
    );
  }

  // ===========================================================================
  // STORY 2 (index 1, Key('cinema-story-2-client-voice'))
  // O Poder do Cliente: Pedido por Voz, Endereço Oculto & 3 Orçamentos
  // ===========================================================================
  Widget _buildStory2ClientVoice({
    required double localT,
    required double globalT,
    required bool isCompact,
    required bool reduceMotion,
  }) {
    final quotes = <(String, String, String, String, Color)>[
      (
        '1º',
        'Ricardo M. · Eletricista NBR 5410',
        '5,0 ★',
        'R\$ 160',
        const Color(0xFF10B981),
      ),
      (
        '2º',
        'Carlos A. · Técnico Sênior',
        '4,9 ★',
        'R\$ 175',
        const Color(0xFF38BDF8),
      ),
      (
        '3º',
        'André S. · Especialista Verificado',
        '4,9 ★',
        'R\$ 190',
        const Color(0xFFFF8A2B),
      ),
    ];

    final mockup = _buildDeepGlassMockupShell(
      accentColor: const Color(0xFF38BDF8),
      windowTitle: 'Novo Chamado Inteligente por Voz',
      windowStatusBadge: 'Até 3 Propostas',
      windowIcon: Icons.mic_rounded,
      isCompact: isCompact,
      localT: localT,
      reduceMotion: reduceMotion,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Gravador Inteligente por Voz com 18 barras senoidais animadas
          Container(
            padding: EdgeInsets.all(isCompact ? 9 : 12),
            decoration: BoxDecoration(
              color: const Color(0xFF172642).withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.42),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: isCompact ? 26 : 30,
                      height: isCompact ? 26 : 30,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF6D00), Color(0xFFFF8A2B)],
                        ),
                      ),
                      child: const Icon(
                        Icons.mic_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: isCompact ? 22 : 26,
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _VoiceWaveformBarsPainter(
                              phase: reduceMotion ? 0.35 : localT,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Text(
                        '📷 Fotos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isCompact ? 6 : 8),
                Text(
                  '"Chuveiro desarmando o disjuntor..."',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.94),
                    fontSize: isCompact ? 11.2 : 12.4,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 6 : 9),
          // 2. Pílula de Privacidade Geográfica
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 9 : 11,
              vertical: isCompact ? 5.5 : 7,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 13.5,
                  color: Color(0xFF34D399),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '🔒 Rua e número ocultos até você contratar',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: isCompact ? 10.2 : 11.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 6 : 9),
          // 3. Lista Viva 1º · 2º · 3º de Orçamentos
          for (var i = 0; i < quotes.length; i++) ...[
            if (i > 0) SizedBox(height: isCompact ? 5 : 6),
            _buildAnimatedProposalRow(
              rank: quotes[i].$1,
              providerName: quotes[i].$2,
              rating: quotes[i].$3,
              price: quotes[i].$4,
              accent: quotes[i].$5,
              isHighlighted: i == 0,
              localT: localT,
              index: i,
              isCompact: isCompact,
              reduceMotion: reduceMotion,
            ),
          ],
        ],
      ),
    );

    return _buildEditorialStoryLayout(
      storyKey: const Key('cinema-story-2-client-voice'),
      accentColor: const Color(0xFF38BDF8),
      badgeIcon: Icons.record_voice_over_rounded,
      badgeText: 'O QUE VOCÊ FAZ COMO CLIENTE · PASSO 1',
      title: 'Peça falando por voz e compare até 3 propostas.',
      subtitle:
          'Descreva seu problema em segundos, mantenha seu endereço protegido na cotação e escolha quem tem a melhor avaliação.',
      mockupCard: mockup,
      isCompact: isCompact,
    );
  }

  Widget _buildAnimatedProposalRow({
    required String rank,
    required String providerName,
    required String rating,
    required String price,
    required Color accent,
    required bool isHighlighted,
    required double localT,
    required int index,
    required bool isCompact,
    required bool reduceMotion,
  }) {
    final staggerStart = index * 0.08;
    final reveal = reduceMotion
        ? 1.0
        : Curves.easeOutBack.transform(
            ((localT - staggerStart) / 0.28).clamp(0.0, 1.0),
          );

    return Transform.translate(
      offset: Offset((1.0 - reveal) * 14.0, 0),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 9 : 11,
          vertical: isCompact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: isHighlighted
              ? accent.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isHighlighted
                ? accent.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                rank,
                style: TextStyle(
                  color: accent,
                  fontSize: isCompact ? 10.0 : 11.0,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                providerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 10.6 : 11.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              rating,
              style: TextStyle(
                color: const Color(0xFFFFB020),
                fontSize: isCompact ? 10.2 : 11.0,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              price,
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 11.0 : 12.0,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // STORY 3 (index 2, Key('cinema-act-3-client'))
  // Proteção Total do Cliente: Mapa ao Vivo, 0% em Peças, PIN & 90 Dias
  // ===========================================================================
  Widget _buildStory3ClientProtection({
    required double localT,
    required double globalT,
    required bool isCompact,
    required bool reduceMotion,
  }) {
    const pinDigits = <String>['4', '8', '2', '9'];

    final mockup = _buildDeepGlassMockupShell(
      accentColor: const Color(0xFF10B981),
      windowTitle: 'Escrow Seguro & Chegada ao Vivo',
      windowStatusBadge: 'Custódia 100%',
      windowIcon: Icons.shield_rounded,
      isCompact: isCompact,
      localT: localT,
      reduceMotion: reduceMotion,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Mapa de Chegada ao Vivo com Rota De Casteljau
          Container(
            height: isCompact ? 76 : 114,
            decoration: BoxDecoration(
              color: const Color(0xFF081A1C),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.36),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _LiveArrivalRadarPainter(
                        progress: reduceMotion
                            ? 0.72
                            : (0.20 + 0.75 * localT).clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 7,
                  right: 8,
                  child: Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF061316,
                            ).withValues(alpha: 0.86),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.50),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.navigation_rounded,
                                size: 11.5,
                                color: Color(0xFF34D399),
                              ),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Chegada acompanhada no mapa',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 6 : 9),
          // 2. Smart Split 0% em Materiais
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 9 : 11,
              vertical: isCompact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 13.5,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Mão de Obra em Custódia',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.90),
                            fontSize: isCompact ? 10.0 : 11.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.50),
                      ),
                    ),
                    child: Text(
                      '0% de taxa sobre peças com NF-e',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF34D399),
                        fontSize: isCompact ? 9.5 : 10.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 6 : 9),
          // 3. Cofre PIN de 4 Dígitos (4 · 8 · 2 · 9) + Garantia 90 dias
          Container(
            padding: EdgeInsets.all(isCompact ? 8 : 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withValues(alpha: 0.14),
                  const Color(0xFFF59E0B).withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < pinDigits.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _buildPinDigitVaultCell(
                        digit: pinDigits[i],
                        isLit: reduceMotion || localT >= (i * 0.12),
                        isCompact: isCompact,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: isCompact ? 6 : 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 13.5,
                      color: Color(0xFF34D399),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '✓ Só libera com seu PIN · 90 dias de garantia em 3 camadas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 10.0 : 11.0,
                          fontWeight: FontWeight.w800,
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

    return _buildEditorialStoryLayout(
      storyKey: const Key('cinema-act-3-client'),
      accentColor: const Color(0xFF10B981),
      badgeIcon: Icons.verified_user_rounded,
      badgeText: 'SUA PROTEÇÃO COMO CLIENTE · RISCO ZERO',
      title: 'Pagamento guardado até você aprovar com seu PIN.',
      subtitle:
          'Zero taxa sobre materiais com nota fiscal, rota ao vivo e 90 dias de garantia técnica assegurada pela plataforma.',
      mockupCard: mockup,
      isCompact: isCompact,
    );
  }

  Widget _buildPinDigitVaultCell({
    required String digit,
    required bool isLit,
    required bool isCompact,
  }) {
    return Container(
      width: isCompact ? 34 : 40,
      height: isCompact ? 34 : 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isLit
            ? const Color(0xFF10B981).withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLit
              ? const Color(0xFF34D399)
              : Colors.white.withValues(alpha: 0.18),
          width: isLit ? 1.4 : 1.0,
        ),
        boxShadow: isLit
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.28),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Text(
        digit,
        style: TextStyle(
          color: Colors.white,
          fontSize: isCompact ? 14.5 : 17.0,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ===========================================================================
  // STORY 4 (index 3, Key('cinema-story-4-passport'))
  // Superpoder Exclusivo do Cliente: Prontuário Oficial da Casa (ABNT NBR 5674)
  // ===========================================================================
  Widget _buildStory4HomePassport({
    required double localT,
    required double globalT,
    required bool isCompact,
    required bool reduceMotion,
  }) {
    final gaugeProgress = reduceMotion
        ? 0.96
        : (0.72 + 0.24 * Curves.easeOutCubic.transform(localT)).clamp(
            0.0,
            0.96,
          );

    const auditItems = <(String, String)>[
      ('✓ Elétrica certificada', 'NBR 5410 · Quadro & DR'),
      ('✓ Ar-condicionado higienizado', 'Laudo PMOC · Clima'),
      ('✓ Fotos Antes/Depois + NF-e', 'Dossiê patrimonial completo'),
    ];

    final mockup = _buildDeepGlassMockupShell(
      accentColor: const Color(0xFFF59E0B),
      windowTitle: 'Passaporte Oficial do Imóvel',
      windowStatusBadge: 'ABNT NBR 5674',
      windowIcon: Icons.workspace_premium_rounded,
      isCompact: isCompact,
      localT: localT,
      reduceMotion: reduceMotion,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Medidor Circular de Alta Precisão + Score 96 / 100
          Container(
            padding: EdgeInsets.all(isCompact ? 9 : 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF59E0B).withValues(alpha: 0.14),
                  const Color(0xFF60A5FA).withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.42),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: isCompact ? 56 : 68,
                  height: isCompact ? 56 : 68,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _PassportScoreArcPainter(progress: gaugeProgress),
                      child: Center(
                        child: Text(
                          '96 / 100',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 11.0 : 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Score de Vistoria do Imóvel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 11.8 : 13.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Manutenção preventiva e corretiva auditada com rastreabilidade digital.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.74),
                          fontSize: isCompact ? 10.0 : 11.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 6 : 9),
          // Histórico Auditado com Checks Luminosos
          for (var i = 0; i < auditItems.length; i++) ...[
            if (i > 0) SizedBox(height: isCompact ? 4 : 6),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 9 : 11,
                vertical: isCompact ? 5.5 : 7,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      auditItems[i].$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF34D399),
                        fontSize: isCompact ? 10.5 : 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      auditItems[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: isCompact ? 9.8 : 10.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: isCompact ? 6 : 9),
          // Selo PDF Oficial ABNT NBR 5674 · SHA-256
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 9 : 11,
              vertical: isCompact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.52),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 14,
                  color: Color(0xFFFBBF24),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'PDF Oficial ABNT NBR 5674 · SHA-256',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 10.2 : 11.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'Vistorias & Seguros',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 9.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return _buildEditorialStoryLayout(
      storyKey: const Key('cinema-story-4-passport'),
      accentColor: const Color(0xFFF59E0B),
      badgeIcon: Icons.verified_rounded,
      badgeText: 'EXCLUSIVO PARA SUA CASA · VALORIZAÇÃO PATRIMONIAL',
      title: 'Prontuário Oficial da Casa em padrão ABNT.',
      subtitle:
          'Cada manutenção gera histórico certificado em PDF para valorizar seu imóvel em vistorias, locações e seguros.',
      mockupCard: mockup,
      isCompact: isCompact,
    );
  }

  // ===========================================================================
  // STORY 5 (index 4, Key('cinema-act-4-provider'))
  // Modo Profissional: Zero Moedas, Pagamento Garantido, PIX & Carreira Diamante
  // ===========================================================================
  Widget _buildStory5ProviderMode({
    required double localT,
    required double globalT,
    required bool isCompact,
    required bool reduceMotion,
  }) {
    const careerTiers = <String>[
      'Bronze',
      'Prata',
      'Ouro',
      '💎 Diamante (5,0 ★)',
    ];

    final mockup = _buildDeepGlassMockupShell(
      accentColor: const Color(0xFF22C55E),
      windowTitle: 'Painel do Especialista Parceiro',
      windowStatusBadge: 'Renda Justa',
      windowIcon: Icons.leaderboard_rounded,
      isCompact: isCompact,
      localT: localT,
      reduceMotion: reduceMotion,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Topo: Zero compra de moedas + Valor 100% reservado
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 8 : 10,
                    vertical: isCompact ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.42),
                    ),
                  ),
                  child: Text(
                    'Zero compra de moedas para orçar',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 9.8 : 10.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 8 : 10,
                    vertical: isCompact ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.42),
                    ),
                  ),
                  child: Text(
                    '✓ Valor 100% reservado antes de sair de casa',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF4ADE80),
                      fontSize: isCompact ? 9.8 : 10.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 6 : 9),
          // 2. Carteira Bipartida & Smart Split -> Saque Rápido no PIX
          Container(
            padding: EdgeInsets.all(isCompact ? 9 : 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '85% livre da mão de obra',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isCompact ? 10.8 : 11.8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '100% integral das peças com NF-e',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF38BDF8),
                              fontSize: isCompact ? 10.0 : 11.0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 8 : 12,
                          vertical: isCompact ? 6 : 7.5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
                          ),
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF22C55E,
                              ).withValues(alpha: 0.32),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.pix_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Saque Rápido no PIX',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isCompact ? 10.0 : 11.0,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 6 : 9),
          // 3. Trilha Meritocrática de Níveis: Bronze -> Prata -> Ouro -> 💎 Diamante (5,0 ★)
          Container(
            padding: EdgeInsets.all(isCompact ? 9 : 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF38BDF8).withValues(alpha: 0.14),
                  const Color(0xFF22C55E).withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.42),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < careerTiers.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        flex: i == 3 ? 2 : 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == 3
                                ? const Color(
                                    0xFF38BDF8,
                                  ).withValues(alpha: 0.24)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: i == 3
                                  ? const Color(0xFF38BDF8)
                                  : Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Text(
                            careerTiers[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: i == 3
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.72),
                              fontSize: isCompact ? 9.2 : 10.2,
                              fontWeight:
                                  i == 3 ? FontWeight.w900 : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: isCompact ? 5 : 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    height: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: reduceMotion
                              ? 1.0
                              : (0.45 + 0.55 * localT).clamp(0.0, 1.0),
                          heightFactor: 1.0,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFF59E0B),
                                  Color(0xFF38BDF8),
                                  Color(0xFF22C55E),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return _buildEditorialStoryLayout(
      storyKey: const Key('cinema-act-4-provider'),
      accentColor: const Color(0xFF38BDF8),
      badgeIcon: Icons.bolt_rounded,
      badgeText: 'PARA VOCÊ COMO PROFISSIONAL · RENDA JUSTA',
      title: 'Orçamentos grátis e pagamento garantido antes de sair.',
      subtitle:
          'Sem leilão predatório e sem perder comissão em materiais: evolua até o nível Diamante e receba rápido no PIX.',
      mockupCard: mockup,
      isCompact: isCompact,
    );
  }

  // ===========================================================================
  // STORY 6 (index 5, Key('cinema-act-2-audience'))
  // 1 Conta · 2 Mundos: Segurança Máxima & Troca em 1 Toque
  // ===========================================================================
  Widget _buildStory6DualWorld({
    required double localT,
    required double globalT,
    required bool isCompact,
    required bool reduceMotion,
  }) {
    final isProviderFocus = !reduceMotion && localT >= 0.50;

    const kycPillars = <(IconData, String, Color)>[
      (Icons.face_retouching_natural_rounded, 'Biometria Facial 3D', Color(0xFF38BDF8)),
      (Icons.badge_rounded, 'Documento Oficial OCR', Color(0xFFFF8A2B)),
      (Icons.local_police_rounded, 'Certidão Polícia Federal', Color(0xFF10B981)),
    ];

    final mockup = _buildDeepGlassMockupShell(
      accentColor: const Color(0xFFFF8A2B),
      windowTitle: '1 Conta · 2 Perfis',
      windowStatusBadge: 'Troca em 1 Toque',
      windowIcon: Icons.swap_horiz_rounded,
      isCompact: isCompact,
      localT: localT,
      reduceMotion: reduceMotion,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chave Seletora Viva Dual-Mode
          Container(
            padding: EdgeInsets.all(isCompact ? 8 : 11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDualModeOptionTile(
                  icon: Icons.home_rounded,
                  title: 'Preciso de um serviço (Cliente)',
                  subtitle: 'Contratar especialistas verificados com garantia',
                  accent: const Color(0xFFFF6D00),
                  isActive: !isProviderFocus,
                  isCompact: isCompact,
                ),
                SizedBox(height: isCompact ? 5 : 7),
                _buildDualModeOptionTile(
                  icon: Icons.handyman_rounded,
                  title: 'Quero trabalhar (Profissional)',
                  subtitle: 'Orçar sem moedas e receber rápido via PIX',
                  accent: const Color(0xFF38BDF8),
                  isActive: isProviderFocus,
                  isCompact: isCompact,
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 6 : 9),
          // 3 Selos de Segurança Máxima (Validação Única Semestral)
          Row(
            children: [
              for (var i = 0; i < kycPillars.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 6 : 8,
                      vertical: isCompact ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: kycPillars[i].$3.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: kycPillars[i].$3.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          kycPillars[i].$1,
                          size: isCompact ? 14 : 16,
                          color: kycPillars[i].$3,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          kycPillars[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 8.8 : 9.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: isCompact ? 6 : 9),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 9 : 11,
              vertical: isCompact ? 5.5 : 7,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.42),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  size: 13.5,
                  color: Color(0xFF34D399),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Validação única semestral libera os dois perfis sem repetir documentos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.94),
                      fontSize: isCompact ? 9.8 : 10.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return _buildEditorialStoryLayout(
      storyKey: const Key('cinema-act-2-audience'),
      accentColor: const Color(0xFFFF8A2B),
      badgeIcon: Icons.published_with_changes_rounded,
      badgeText: '1 CONTA VERIFICADA · LIBERDADE TOTAL',
      title: 'Contrate hoje. Trabalhe quando quiser.',
      subtitle:
          'Com um único cadastro protegido por biometria e Polícia Federal, você alterna entre Cliente e Profissional em 1 toque.',
      mockupCard: mockup,
      isCompact: isCompact,
    );
  }

  Widget _buildDualModeOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required bool isActive,
    required bool isCompact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 9 : 11,
        vertical: isCompact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? accent.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isActive
              ? accent.withValues(alpha: 0.72)
              : Colors.white.withValues(alpha: 0.12),
          width: isActive ? 1.3 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isCompact ? 26 : 30,
            height: isCompact ? 26 : 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: isCompact ? 14 : 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 10.8 : 12.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: isCompact ? 9.5 : 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            isActive
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            size: 16,
            color: isActive ? accent : Colors.white38,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetricChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isCompact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 4.5 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: isCompact ? 11 : 12.5,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: isCompact ? 9.2 : 10.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ESTEIRA HORIZONTAL INFINITA (MARQUEE 120 FPS SEM OVERFLOW) PARA O STORY 1
// =============================================================================
class _InfiniteSpecialtyMarqueeBelt extends StatelessWidget {
  const _InfiniteSpecialtyMarqueeBelt({
    required this.items,
    required this.phase,
    required this.reverse,
    required this.isCompact,
  });

  final List<(String, String, String)> items;
  final double phase;
  final bool reverse;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final tileWidth = isCompact ? 132.0 : 148.0;
    final tileHeight = isCompact ? 56.0 : 60.0;
    const gap = 8.0;
    final step = tileWidth + gap;
    final totalBeltWidth = items.length * step;
    final rawShift = (phase * 145.0) % totalBeltWidth;
    final shift = reverse ? rawShift : -rawShift;

    return SizedBox(
      height: tileHeight,
      child: ClipRect(
        child: ShaderMask(
          shaderCallback: (rect) {
            return const LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.06, 0.94, 1.0],
            ).createShader(rect);
          },
          blendMode: BlendMode.dstIn,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth;
              final tiles = <Widget>[];

              for (var i = 0; i < items.length; i++) {
                var x = (i * step) + shift;
                while (x < -step) {
                  x += totalBeltWidth;
                }
                while (x > totalBeltWidth - step) {
                  x -= totalBeltWidth;
                }

                for (final offsetCycle in <double>[0.0, totalBeltWidth]) {
                  final drawX = x + offsetCycle;
                  if (drawX + tileWidth >= -12 && drawX <= maxW + 12) {
                    tiles.add(
                      Positioned(
                        left: drawX,
                        top: 0,
                        width: tileWidth,
                        height: tileHeight,
                        child: _buildSpecialtyCard(items[i]),
                      ),
                    );
                  }
                }
              }

              return Stack(
                clipBehavior: Clip.hardEdge,
                children: tiles,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialtyCard((String, String, String) spec) {
    final emblemSize = isCompact ? 32.0 : 38.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 7 : 9,
        vertical: isCompact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF18243A).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          CategoryBrandEmblem(
            categoryName: spec.$1,
            size: emblemSize,
            showCornerBadge: false,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 10.0 : 11.2,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                Text(
                  spec.$3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: isCompact ? 8.6 : 9.6,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
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

// =============================================================================
// PAINTERS VETORIAIS 120 FPS (ATMOSFERA, ONDAS DE VOZ, RADAR E SCORE ABNT)
// =============================================================================

class _StoryAtmospherePainter extends CustomPainter {
  const _StoryAtmospherePainter({
    required this.storyIndex,
    required this.localT,
    required this.globalT,
    required this.reduceMotion,
  });

  final int storyIndex;
  final double localT;
  final double globalT;
  final bool reduceMotion;

  static (Color, Color, Color) _paletteFor(int index) {
    switch (index) {
      case 0:
        return (
          const Color(0xFF070D19),
          const Color(0xFFFF6D00),
          const Color(0xFF38BDF8),
        );
      case 1:
        return (
          const Color(0xFF091326),
          const Color(0xFF38BDF8),
          const Color(0xFFFF7A1A),
        );
      case 2:
        return (
          const Color(0xFF061816),
          const Color(0xFF10B981),
          const Color(0xFFF59E0B),
        );
      case 3:
        return (
          const Color(0xFF0A1222),
          const Color(0xFFF59E0B),
          const Color(0xFF60A5FA),
        );
      case 4:
        return (
          const Color(0xFF07152B),
          const Color(0xFF38BDF8),
          const Color(0xFF22C55E),
        );
      default:
        return (
          const Color(0xFF0B1220),
          const Color(0xFFFF6D00),
          const Color(0xFF38BDF8),
        );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final (bgBase, primaryGlow, secondaryGlow) = _paletteFor(storyIndex);
    final rect = Offset.zero & size;

    final basePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        [
          bgBase,
          const Color(0xFF070B14),
        ],
      );
    canvas.drawRect(rect, basePaint);

    final drift = reduceMotion ? 0.0 : math.sin(globalT * math.pi * 4.0) * 24.0;

    final topOrbCenter = Offset(
      size.width * 0.78 + drift,
      size.height * 0.18,
    );
    final topOrbPaint = Paint()
      ..shader = ui.Gradient.radial(
        topOrbCenter,
        size.width * 0.68,
        [
          primaryGlow.withValues(alpha: 0.22),
          primaryGlow.withValues(alpha: 0.05),
          Colors.transparent,
        ],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawCircle(topOrbCenter, size.width * 0.68, topOrbPaint);

    final bottomOrbCenter = Offset(
      size.width * 0.20 - drift * 0.7,
      size.height * 0.72,
    );
    final bottomOrbPaint = Paint()
      ..shader = ui.Gradient.radial(
        bottomOrbCenter,
        size.width * 0.65,
        [
          secondaryGlow.withValues(alpha: 0.16),
          secondaryGlow.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawCircle(bottomOrbCenter, size.width * 0.65, bottomOrbPaint);
  }

  @override
  bool shouldRepaint(covariant _StoryAtmospherePainter oldDelegate) {
    return oldDelegate.storyIndex != storyIndex ||
        oldDelegate.localT != localT ||
        oldDelegate.globalT != globalT ||
        oldDelegate.reduceMotion != reduceMotion;
  }
}

class _VoiceWaveformBarsPainter extends CustomPainter {
  const _VoiceWaveformBarsPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 18;
    final spacing = size.width / barCount;
    final barWidth = (spacing * 0.54).clamp(2.0, 4.5);
    final centerY = size.height / 2;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, 0),
        const [
          Color(0xFFFF6D00),
          Color(0xFF38BDF8),
          Color(0xFF10B981),
        ],
        const [0.0, 0.55, 1.0],
      );

    for (var i = 0; i < barCount; i++) {
      final wave = math.sin((phase * math.pi * 8.0) + (i * 0.65));
      final envelope = math.sin(((i + 1) / (barCount + 1)) * math.pi);
      final normalizedH = (0.28 + 0.72 * ((wave + 1.0) * 0.5) * envelope).clamp(
        0.22,
        1.0,
      );
      final barH = size.height * normalizedH;
      final x = i * spacing + (spacing - barWidth) * 0.5;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barWidth * 0.5, centerY),
          width: barWidth,
          height: barH,
        ),
        const Radius.circular(99),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWaveformBarsPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}

class _LiveArrivalRadarPainter extends CustomPainter {
  const _LiveArrivalRadarPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFF10B981).withValues(alpha: 0.14);

    for (var i = 1; i < 5; i++) {
      final y = (size.height / 5) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var i = 1; i < 7; i++) {
      final x = (size.width / 7) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final p0 = Offset(size.width * 0.14, size.height * 0.76);
    final p1 = Offset(size.width * 0.42, size.height * 0.24);
    final p2 = Offset(size.width * 0.66, size.height * 0.80);
    final p3 = Offset(size.width * 0.86, size.height * 0.42);

    final fullRoute = Path()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);

    canvas.drawPath(
      fullRoute,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.16),
    );

    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
        p0,
        p3,
        const [Color(0xFF38BDF8), Color(0xFF10B981)],
      );

    for (final metric in fullRoute.computeMetrics()) {
      final activeLen = metric.length * progress.clamp(0.0, 1.0);
      final extract = metric.extractPath(0, activeLen);
      canvas.drawPath(extract, activePaint);
      final tangent = metric.getTangentForOffset(activeLen);
      if (tangent != null) {
        canvas.drawCircle(
          tangent.position,
          8.0,
          Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.30),
        );
        canvas.drawCircle(
          tangent.position,
          4.2,
          Paint()..color = Colors.white,
        );
      }
    }

    // Ponto de destino (Imóvel do Cliente)
    canvas.drawCircle(
      p3,
      5.5,
      Paint()..color = const Color(0xFFF59E0B),
    );
  }

  @override
  bool shouldRepaint(covariant _LiveArrivalRadarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _PassportScoreArcPainter extends CustomPainter {
  const _PassportScoreArcPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 4.5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.14);

    canvas.drawArc(
      rect,
      -math.pi * 0.75,
      math.pi * 1.5,
      false,
      trackPaint,
    );

    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.8
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi * 1.5,
        colors: [
          Color(0xFFF59E0B),
          Color(0xFF10B981),
          Color(0xFF38BDF8),
        ],
        transform: GradientRotation(-math.pi * 0.75),
      ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi * 0.75,
      math.pi * 1.5 * progress.clamp(0.0, 1.0),
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PassportScoreArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

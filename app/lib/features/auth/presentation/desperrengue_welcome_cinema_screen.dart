import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/category_brand_emblem.dart';

/// Apresentação interativa pós-cadastro em 6 etapas a 120 FPS (v2.26.0).
///
/// Arquitetura visual e de engenharia:
/// - **Composição Porcelana sobre Aurora**: cartões heróis claros de porcelana
///   acetinada (`#FFFFFF` -> `#F8FAFC`, `borderRadius: 26`, contraste WCAG AAA)
///   flutuando sobre um fundo aurora contínuo em `RepaintBoundary`.
/// - **Ritmo sereno (`10,5s` por etapa, `63000ms` total)**: coreografia finita
///   em 3 Atos (`0.0s–0.75s` entrada em cascata, `0.75s–3.10s` demonstração
///   viva única, `3.10s–10.5s` repouso sereno absoluto sem nenhum `repeat()`).
/// - **Isolamento estrito 120Hz**: `_storyProgressController` notifica apenas
///   `_TopSegmentedProgressBars` em `RepaintBoundary`, preservando
///   `buildCount == 1` estrito em [WelcomeStoryHeroCard] durante o avanço.
/// - **Gestos de latência zero (`Listener` + `PageView`)**: pausa no exato `0ms`
///   em `onPointerDown`, indicador `Pausado` após `220ms` via `Timer` compatível
///   com `FakeAsync`, zonas `32%` / `68%` sem disputa na `GestureArena` e
///   suporte a toque interativo direto na chave seletora dupla da Etapa 6.
class DesperrengueWelcomeCinemaScreen extends StatefulWidget {
  const DesperrengueWelcomeCinemaScreen({
    super.key,
    this.userFirstName = '',
    required this.onCompleted,
    this.isReplay = false,
    this.totalDuration = const Duration(milliseconds: 63000),
    @visibleForTesting this.onActiveHeroBuild,
  });

  static const int storyCount = 6;

  final String userFirstName;
  final VoidCallback onCompleted;
  final bool isReplay;
  final Duration totalDuration;

  @visibleForTesting
  final ValueChanged<int>? onActiveHeroBuild;

  @override
  State<DesperrengueWelcomeCinemaScreen> createState() =>
      _DesperrengueWelcomeCinemaScreenState();
}

/// Card herói central em Porcelana Luminosa com isolamento de rebuilds a 120 FPS.
///
/// Dispara [onActiveHeroBuild] estritamente quando [isActiveStory] é verdadeiro.
/// Todas as micro-animações operam em sub-widgets folhas para garantir que
/// [build] execute apenas 1 vez enquanto o progresso da etapa corre.
class WelcomeStoryHeroCard extends StatelessWidget {
  const WelcomeStoryHeroCard({
    super.key,
    required this.storyIndex,
    required this.isActiveStory,
    required this.accentColor,
    required this.isCompact,
    required this.child,
    this.onActiveHeroBuild,
  });

  final int storyIndex;
  final bool isActiveStory;
  final Color accentColor;
  final bool isCompact;
  final Widget child;
  final ValueChanged<int>? onActiveHeroBuild;

  @override
  Widget build(BuildContext context) {
    if (isActiveStory) {
      onActiveHeroBuild?.call(storyIndex);
    }

    final radius = BorderRadius.circular(isCompact ? 22 : 26);

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFAFBFD),
              Color(0xFFF8FAFC),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
          border: Border.all(
            color: Color.alphaBlend(
              accentColor.withValues(alpha: 0.22),
              const Color(0xFFE2E8F0),
            ),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF040B14).withValues(alpha: 0.38),
              blurRadius: 34,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: accentColor.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: CustomPaint(
            foregroundPainter: _PorcelainCardSpecularPainter(
              accentColor: accentColor,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 12 : 18,
                vertical: isCompact ? 11 : 17,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _PorcelainCardSpecularPainter extends CustomPainter {
  const _PorcelainCardSpecularPainter({required this.accentColor});

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 36) return;
    final bevelRect = Rect.fromLTWH(18, 0, size.width - 36, 1.5);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.92),
          accentColor.withValues(alpha: 0.32),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(bevelRect);
    canvas.drawRect(bevelRect, paint);
  }

  @override
  bool shouldRepaint(covariant _PorcelainCardSpecularPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}

class _DesperrengueWelcomeCinemaScreenState
    extends State<DesperrengueWelcomeCinemaScreen>
    with SingleTickerProviderStateMixin {
  static const int _kStoryCount = DesperrengueWelcomeCinemaScreen.storyCount;
  static const Duration _kHoldPauseDelay = Duration(milliseconds: 220);

  late final AnimationController _storyProgressController;
  late final PageController _pageController;

  final ValueNotifier<int> _activeStoryNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isHoldPausedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> _storyZeroRestartEpoch = ValueNotifier<int>(0);

  bool _completedDispatched = false;
  bool _isProgrammaticPageJump = false;

  int? _activePointerId;
  int? _interactiveControlPointerId;
  Offset _pointerDownPosition = Offset.zero;
  Timer? _holdPauseTimer;
  bool _didHoldPause = false;
  bool _isDragging = false;
  int _settledPageAtPointerDown = 0;
  double _stageWidth = 360.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _storyProgressController = AnimationController(
      vsync: this,
      duration: _safeTotalDuration(widget.totalDuration),
      animationBehavior: AnimationBehavior.preserve,
    )
      ..addListener(_onTimelineBoundaryCheck)
      ..addStatusListener(_onTimelineStatus);

    _storyProgressController.forward();
  }

  static Duration _safeTotalDuration(Duration raw) {
    return raw.inMicroseconds > 0 ? raw : const Duration(milliseconds: 600);
  }

  @override
  void didUpdateWidget(covariant DesperrengueWelcomeCinemaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalDuration != widget.totalDuration) {
      _storyProgressController.duration = _safeTotalDuration(
        widget.totalDuration,
      );
      if (!_completedDispatched &&
          _activePointerId == null &&
          !_isHoldPausedNotifier.value &&
          _storyProgressController.value < 1.0) {
        _storyProgressController.forward();
      }
    }
  }

  @override
  void dispose() {
    _holdPauseTimer?.cancel();
    _holdPauseTimer = null;
    _storyProgressController.removeListener(_onTimelineBoundaryCheck);
    _storyProgressController.removeStatusListener(_onTimelineStatus);
    _storyProgressController.dispose();
    _pageController.dispose();
    _activeStoryNotifier.dispose();
    _isHoldPausedNotifier.dispose();
    _storyZeroRestartEpoch.dispose();
    super.dispose();
  }

  void _onTimelineStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_completedDispatched) {
      _completeShowcase();
    }
  }

  void _onTimelineBoundaryCheck() {
    if (_completedDispatched || _isDragging || _activePointerId != null) {
      return;
    }
    final t = _storyProgressController.value.clamp(0.0, 1.0);
    if (t >= 1.0) {
      _completeShowcase();
      return;
    }
    final computedStory =
        ((t * _kStoryCount) + 1e-9).floor().clamp(0, _kStoryCount - 1);
    if (computedStory != _activeStoryNotifier.value) {
      _activeStoryNotifier.value = computedStory;
      _settledPageAtPointerDown = computedStory;
      HapticFeedback.selectionClick();
      if (_pageController.hasClients) {
        _isProgrammaticPageJump = true;
        _pageController.jumpToPage(computedStory);
        _isProgrammaticPageJump = false;
      }
    }
  }

  void _completeShowcase() {
    if (_completedDispatched) return;
    _completedDispatched = true;
    _holdPauseTimer?.cancel();
    _holdPauseTimer = null;
    _activePointerId = null;
    _interactiveControlPointerId = null;
    _didHoldPause = false;
    _isDragging = false;
    if (_isHoldPausedNotifier.value) {
      _isHoldPausedNotifier.value = false;
    }
    _storyProgressController.stop(canceled: false);
    HapticFeedback.mediumImpact();
    widget.onCompleted();
  }

  void _jumpToStoryImmediate(int targetStory, {bool playSelectionHaptic = true}) {
    if (_completedDispatched) return;
    final clamped = targetStory.clamp(0, _kStoryCount - 1);
    _holdPauseTimer?.cancel();
    _holdPauseTimer = null;
    _didHoldPause = false;
    _isDragging = false;
    if (_isHoldPausedNotifier.value) {
      _isHoldPausedNotifier.value = false;
    }

    if (playSelectionHaptic) {
      HapticFeedback.selectionClick();
    }

    final wasAlreadyStoryZero =
        clamped == 0 && _activeStoryNotifier.value == 0;

    _activeStoryNotifier.value = clamped;
    _settledPageAtPointerDown = clamped;

    if (_pageController.hasClients &&
        (_pageController.page?.round() != clamped)) {
      _isProgrammaticPageJump = true;
      _pageController.jumpToPage(clamped);
      _isProgrammaticPageJump = false;
    }

    if (wasAlreadyStoryZero) {
      _storyZeroRestartEpoch.value++;
    }

    final startFraction = (clamped / _kStoryCount).clamp(0.0, 0.999999);
    _storyProgressController.forward(from: startFraction);
  }

  void _handleNextAction({bool fromStageTap = false}) {
    if (_completedDispatched) return;
    final current = _activeStoryNotifier.value;
    if (current >= _kStoryCount - 1) {
      if (fromStageTap) {
        HapticFeedback.selectionClick();
      }
      _completeShowcase();
      return;
    }
    _jumpToStoryImmediate(current + 1, playSelectionHaptic: true);
  }

  void _handlePreviousAction() {
    if (_completedDispatched) return;
    final current = _activeStoryNotifier.value;
    if (current <= 0) {
      _jumpToStoryImmediate(0, playSelectionHaptic: true);
      return;
    }
    _jumpToStoryImmediate(current - 1, playSelectionHaptic: true);
  }

  void _registerInteractiveControlPointerDown(int pointerId) {
    _interactiveControlPointerId = pointerId;
  }

  void _handleStagePointerDown(PointerDownEvent event) {
    if (_completedDispatched || _activePointerId != null) return;
    _activePointerId = event.pointer;
    _pointerDownPosition = event.localPosition;
    _didHoldPause = false;
    _isDragging = false;
    _settledPageAtPointerDown = _activeStoryNotifier.value;

    // Congela o progresso no exato milissegundo 0ms
    _storyProgressController.stop(canceled: false);

    _holdPauseTimer?.cancel();
    _holdPauseTimer = Timer(_kHoldPauseDelay, () {
      if (!mounted ||
          _completedDispatched ||
          _isDragging ||
          _activePointerId == null) {
        return;
      }
      _didHoldPause = true;
      _isHoldPausedNotifier.value = true;
    });
  }

  void _handleStagePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointerId) return;
    final distance = (event.localPosition - _pointerDownPosition).distance;
    if (distance > 10.0) {
      _holdPauseTimer?.cancel();
      _holdPauseTimer = null;
      _isDragging = true;
      if (_didHoldPause || _isHoldPausedNotifier.value) {
        _didHoldPause = false;
        _isHoldPausedNotifier.value = false;
      }
    }
  }

  void _handleStagePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointerId) return;
    final wasInteractiveControl =
        event.pointer == _interactiveControlPointerId;
    _activePointerId = null;
    _interactiveControlPointerId = null;
    _holdPauseTimer?.cancel();
    _holdPauseTimer = null;

    final wasHoldPause = _didHoldPause;
    final wasDragging = _isDragging;
    _didHoldPause = false;
    _isDragging = false;

    if (_isHoldPausedNotifier.value) {
      _isHoldPausedNotifier.value = false;
    }
    if (_completedDispatched) return;

    // Se foi toque rápido sobre a chave seletora interativa da Etapa 6,
    // preserva a etapa atual e retoma o cronômetro suavemente.
    if (!wasDragging && !wasHoldPause && !wasInteractiveControl) {
      if (event.localPosition.dx < _stageWidth * 0.32) {
        _handlePreviousAction();
      } else {
        _handleNextAction(fromStageTap: true);
      }
      return;
    }

    _resumeTimelineIfSettled();
  }

  void _handleStagePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointerId) return;
    _activePointerId = null;
    _interactiveControlPointerId = null;
    _holdPauseTimer?.cancel();
    _holdPauseTimer = null;
    _didHoldPause = false;
    _isDragging = false;
    if (_isHoldPausedNotifier.value) {
      _isHoldPausedNotifier.value = false;
    }
    if (!_completedDispatched) {
      _resumeTimelineIfSettled();
    }
  }

  void _resumeTimelineIfSettled() {
    if (_completedDispatched ||
        _activePointerId != null ||
        _isHoldPausedNotifier.value) {
      return;
    }
    if (_storyProgressController.value < 1.0 &&
        !_storyProgressController.isAnimating) {
      _storyProgressController.forward();
    }
  }

  void _handlePageChangedBySwipe(int newPage) {
    if (_completedDispatched || _isProgrammaticPageJump) return;
    final clamped = newPage.clamp(0, _kStoryCount - 1);
    if (clamped != _activeStoryNotifier.value) {
      _activeStoryNotifier.value = clamped;
      HapticFeedback.selectionClick();
      _storyProgressController.value =
          (clamped / _kStoryCount).clamp(0.0, 0.999999);
    }
    if (_activePointerId == null && !_isHoldPausedNotifier.value) {
      _storyProgressController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isReplay,
      child: AppScaffold(
        backgroundColor: const Color(0xFF0D1B20),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _SharedAmbientCanvas(
              pageController: _pageController,
              activeStoryListenable: _activeStoryNotifier,
              isProgrammaticJumpGetter: () => _isProgrammaticPageJump,
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScale =
                      MediaQuery.textScalerOf(context).scale(10.0) / 10.0;
                  final isCompact = constraints.maxHeight < 720 ||
                      constraints.maxWidth < 365 ||
                      textScale > 1.20;
                  final isUltraCompact = constraints.maxHeight < 680 ||
                      (constraints.maxWidth <= 335 && textScale >= 1.30);
                  final horizontalPad = isCompact ? 12.0 : 20.0;

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPad,
                      isUltraCompact ? 2.0 : (isCompact ? 4.0 : 8.0),
                      horizontalPad,
                      isUltraCompact ? 4.0 : (isCompact ? 6.0 : 12.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopSegmentedProgressBars(
                          storyProgressController: _storyProgressController,
                          activeStoryListenable: _activeStoryNotifier,
                          onTapChapter: (index) => _jumpToStoryImmediate(index),
                        ),
                        _TopStageHeaderRow(
                          activeStoryListenable: _activeStoryNotifier,
                          isReplay: widget.isReplay,
                          isCompact: isCompact,
                          holdPausedListenable: _isHoldPausedNotifier,
                          onExitPressed: _completeShowcase,
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, stageConstraints) {
                              _stageWidth = math.max(
                                1.0,
                                stageConstraints.maxWidth,
                              );
                              return Listener(
                                behavior: HitTestBehavior.opaque,
                                onPointerDown: _handleStagePointerDown,
                                onPointerMove: _handleStagePointerMove,
                                onPointerUp: _handleStagePointerUp,
                                onPointerCancel: _handleStagePointerCancel,
                                child: NotificationListener<ScrollNotification>(
                                  onNotification: (notification) {
                                    if (notification is ScrollEndNotification) {
                                      _settledPageAtPointerDown =
                                          _activeStoryNotifier.value;
                                      _resumeTimelineIfSettled();
                                    }
                                    return false;
                                  },
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      PageView.builder(
                                        controller: _pageController,
                                        allowImplicitScrolling: false,
                                        physics:
                                            _SereneStoryPageScrollPhysics(
                                          settledPageGetter: () =>
                                              _settledPageAtPointerDown,
                                        ),
                                        itemCount: _kStoryCount,
                                        onPageChanged: _handlePageChangedBySwipe,
                                        itemBuilder: (context, index) {
                                          return _StorySlidePage(
                                            key: Key(
                                              'cinema-story-${index + 1}',
                                            ),
                                            storyIndex: index,
                                            isActiveStory: index ==
                                                _activeStoryNotifier.value,
                                            totalDuration: widget.totalDuration,
                                            isCompact: isCompact,
                                            isUltraCompact: isUltraCompact,
                                            pageController: _pageController,
                                            holdPausedListenable:
                                                _isHoldPausedNotifier,
                                            restartEpochListenable: index == 0
                                                ? _storyZeroRestartEpoch
                                                : null,
                                            onInteractiveControlPointerDown:
                                                _registerInteractiveControlPointerDown,
                                            onActiveHeroBuild:
                                                widget.onActiveHeroBuild,
                                          );
                                        },
                                      ),
                                      Positioned.fill(
                                        child: _PassThroughTapZoneOverlay(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: const [
                                              Expanded(
                                                flex: 32,
                                                child: ColoredBox(
                                                  key: Key(
                                                    'story-tap-zone-prev',
                                                  ),
                                                  color: Colors.transparent,
                                                  child: SizedBox.expand(),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 68,
                                                child: ColoredBox(
                                                  key: Key(
                                                    'story-tap-zone-next',
                                                  ),
                                                  color: Colors.transparent,
                                                  child: SizedBox.expand(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: isUltraCompact ? 4.0 : 8.0),
                        _BottomStoryNavigationBar(
                          activeStoryListenable: _activeStoryNotifier,
                          isCompact: isCompact,
                          isUltraCompact: isUltraCompact,
                          onPrevious: _handlePreviousAction,
                          onNext: () => _handleNextAction(fromStageTap: false),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// OVERLAY DE DESCOBERTA DE ZONAS DE TOQUE (PASS-THROUGH HIT-TEST ZERO ARENA)
// =============================================================================

class _PassThroughTapZoneOverlay extends SingleChildRenderObjectWidget {
  const _PassThroughTapZoneOverlay({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPassThroughTapZoneOverlay();
}

class _RenderPassThroughTapZoneOverlay extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.contains(position)) {
      hitTestChildren(result, position: position);
      result.add(BoxHitTestEntry(this, position));
    }
    return false;
  }
}

// =============================================================================
// PROGRESSÃO CROMÁTICA AURORA DAS 6 ETAPAS (FIEL A 00:00–00:09 DO VÍDEO)
// =============================================================================

class _StoryVisualSpec {
  const _StoryVisualSpec({
    required this.legacyKey,
    required this.bgTop,
    required this.bgMid,
    required this.bgBottom,
    required this.primaryOrb,
    required this.secondaryOrb,
    required this.accent,
    required this.stardustWeight,
  });

  final Key legacyKey;
  final Color bgTop;
  final Color bgMid;
  final Color bgBottom;
  final Color primaryOrb;
  final Color secondaryOrb;
  final Color accent;
  final double stardustWeight;
}

const List<_StoryVisualSpec> _kStorySpecs = <_StoryVisualSpec>[
  // Etapa 1 (00:00–00:01): Verde-Floresta Profundo & Névoa Sálvia-Esmeralda
  _StoryVisualSpec(
    legacyKey: Key('cinema-act-1-mission'),
    bgTop: Color(0xFF0D1B20),
    bgMid: Color(0xFF112526),
    bgBottom: Color(0xFF16302B),
    primaryOrb: Color(0xFF34D399),
    secondaryOrb: Color(0xFF6EE7B7),
    accent: Color(0xFF10B981),
    stardustWeight: 0.0,
  ),
  // Etapa 2 (00:02): Azul-Petróleo Profundo & Bruma Menta
  _StoryVisualSpec(
    legacyKey: Key('cinema-story-2-client-voice'),
    bgTop: Color(0xFF0C1D24),
    bgMid: Color(0xFF10282A),
    bgBottom: Color(0xFF15322D),
    primaryOrb: Color(0xFF2DD4BF),
    secondaryOrb: Color(0xFF6EE7B7),
    accent: Color(0xFF10B981),
    stardustWeight: 0.0,
  ),
  // Etapa 3 (00:03–00:04): Obsidiana-Esmeralda & Aura de Cofre
  _StoryVisualSpec(
    legacyKey: Key('cinema-act-3-client'),
    bgTop: Color(0xFF0E1D22),
    bgMid: Color(0xFF132829),
    bgBottom: Color(0xFF18332E),
    primaryOrb: Color(0xFF6EE7B7),
    secondaryOrb: Color(0xFFA7F3D0),
    accent: Color(0xFF10B981),
    stardustWeight: 0.0,
  ),
  // Etapa 4 (00:05): Safira-Ardósia & Ciano-Esmeralda
  _StoryVisualSpec(
    legacyKey: Key('cinema-story-4-passport'),
    bgTop: Color(0xFF111F2F),
    bgMid: Color(0xFF162B38),
    bgBottom: Color(0xFF1B353E),
    primaryOrb: Color(0xFF38BDF8),
    secondaryOrb: Color(0xFF34D399),
    accent: Color(0xFF10B981),
    stardustWeight: 0.0,
  ),
  // Etapa 5 (00:06–00:07): Ameixa-Índigo Real & Poeira Estelar Dourada
  _StoryVisualSpec(
    legacyKey: Key('cinema-act-4-provider'),
    bgTop: Color(0xFF1B1832),
    bgMid: Color(0xFF231E3E),
    bgBottom: Color(0xFF2B2347),
    primaryOrb: Color(0xFF8B5CF6),
    secondaryOrb: Color(0xFFFCD34D),
    accent: Color(0xFF10B981),
    stardustWeight: 0.85,
  ),
  // Etapa 6 (00:08–00:09): Horizonte Âmbar-Pôr-do-Sol & Esmeralda
  _StoryVisualSpec(
    legacyKey: Key('cinema-act-2-audience'),
    bgTop: Color(0xFF211926),
    bgMid: Color(0xFF3D2622),
    bgBottom: Color(0xFF523020),
    primaryOrb: Color(0xFFFB923C),
    secondaryOrb: Color(0xFF34D399),
    accent: Color(0xFFF59E0B),
    stardustWeight: 1.0,
  ),
];

// =============================================================================
// FUNDO VIVO CONTÍNUO (_SharedAmbientCanvas) — SWIPE 1:1 + BRIDGE SUAVE 520ms
// =============================================================================

class _SharedAmbientCanvas extends StatefulWidget {
  const _SharedAmbientCanvas({
    required this.pageController,
    required this.activeStoryListenable,
    required this.isProgrammaticJumpGetter,
  });

  final PageController pageController;
  final ValueListenable<int> activeStoryListenable;
  final ValueGetter<bool> isProgrammaticJumpGetter;

  @override
  State<_SharedAmbientCanvas> createState() => _SharedAmbientCanvasState();
}

class _SharedAmbientCanvasState extends State<_SharedAmbientCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bridgeController;
  final ValueNotifier<double> _ambientPageNotifier = ValueNotifier<double>(0.0);

  double _bridgeFrom = 0.0;
  double _bridgeTo = 0.0;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.activeStoryListenable.value.toDouble();
    _ambientPageNotifier.value = initial;
    _bridgeFrom = initial;
    _bridgeTo = initial;

    _bridgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..addListener(_onBridgeTick);

    widget.pageController.addListener(_onPageControllerChanged);
    widget.activeStoryListenable.addListener(_onActiveStoryChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion && _bridgeController.isAnimating) {
      _bridgeController.stop();
      _ambientPageNotifier.value = _bridgeTo;
    }
  }

  @override
  void didUpdateWidget(covariant _SharedAmbientCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageController != widget.pageController) {
      oldWidget.pageController.removeListener(_onPageControllerChanged);
      widget.pageController.addListener(_onPageControllerChanged);
    }
    if (oldWidget.activeStoryListenable != widget.activeStoryListenable) {
      oldWidget.activeStoryListenable.removeListener(_onActiveStoryChanged);
      widget.activeStoryListenable.addListener(_onActiveStoryChanged);
    }
  }

  double? _tryReadLivePage() {
    if (!widget.pageController.hasClients) return null;
    try {
      final position = widget.pageController.position;
      if (!position.hasContentDimensions || !position.hasPixels) return null;
      return widget.pageController.page?.clamp(
        0.0,
        (_kStorySpecs.length - 1).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  void _onBridgeTick() {
    final curved = Curves.easeOutCubic.transform(
      _bridgeController.value.clamp(0.0, 1.0),
    );
    _ambientPageNotifier.value =
        _bridgeFrom + ((_bridgeTo - _bridgeFrom) * curved);
  }

  void _onPageControllerChanged() {
    if (widget.isProgrammaticJumpGetter()) return;

    final livePage = _tryReadLivePage();
    if (livePage == null) return;

    if (_bridgeController.isAnimating) {
      final isFractionalSwipe =
          (livePage - livePage.roundToDouble()).abs() > 1e-3;
      if (!isFractionalSwipe && (livePage - _bridgeTo).abs() < 1e-3) {
        return;
      }
      _bridgeController.stop();
    }
    _ambientPageNotifier.value = livePage;
  }

  void _onActiveStoryChanged() {
    final target = widget.activeStoryListenable.value
        .clamp(0, _kStorySpecs.length - 1)
        .toDouble();

    final livePage = _tryReadLivePage();
    final isActivelySwiping = livePage != null &&
        (livePage - livePage.roundToDouble()).abs() > 1e-3;

    if (isActivelySwiping) {
      return;
    }

    if (_reduceMotion) {
      if (_bridgeController.isAnimating) {
        _bridgeController.stop();
      }
      _bridgeFrom = target;
      _bridgeTo = target;
      _ambientPageNotifier.value = target;
      return;
    }

    final current = _ambientPageNotifier.value;
    if ((target - current).abs() <= 1e-3) {
      _ambientPageNotifier.value = target;
      return;
    }

    _bridgeFrom = current;
    _bridgeTo = target;
    _bridgeController.forward(from: 0.0);
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_onPageControllerChanged);
    widget.activeStoryListenable.removeListener(_onActiveStoryChanged);
    _bridgeController.removeListener(_onBridgeTick);
    _bridgeController.dispose();
    _ambientPageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SharedAmbientPainter(
          ambientPageListenable: _ambientPageNotifier,
        ),
      ),
    );
  }
}

class _SharedAmbientPainter extends CustomPainter {
  _SharedAmbientPainter({required this.ambientPageListenable})
      : super(repaint: ambientPageListenable);

  final ValueListenable<double> ambientPageListenable;

  static const List<(double, double, double)> _kAmbientStars =
      <(double, double, double)>[
    (0.14, 0.24, 1.8),
    (0.86, 0.28, 2.2),
    (0.18, 0.72, 2.4),
    (0.82, 0.76, 2.0),
    (0.32, 0.84, 1.6),
    (0.71, 0.86, 2.3),
    (0.52, 0.18, 1.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final page = ambientPageListenable.value.clamp(
      0.0,
      (_kStorySpecs.length - 1).toDouble(),
    );
    final lower = page.floor().clamp(0, _kStorySpecs.length - 1);
    final upper = page.ceil().clamp(0, _kStorySpecs.length - 1);
    final frac = (page - lower).clamp(0.0, 1.0);

    final a = _kStorySpecs[lower];
    final b = _kStorySpecs[upper];

    final bgTop = Color.lerp(a.bgTop, b.bgTop, frac)!;
    final bgMid = Color.lerp(a.bgMid, b.bgMid, frac)!;
    final bgBottom = Color.lerp(a.bgBottom, b.bgBottom, frac)!;
    final primaryOrb = Color.lerp(a.primaryOrb, b.primaryOrb, frac)!;
    final secondaryOrb = Color.lerp(a.secondaryOrb, b.secondaryOrb, frac)!;
    final stardust = ui.lerpDouble(a.stardustWeight, b.stardustWeight, frac)!;

    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [bgTop, bgMid, bgBottom],
          const [0.0, 0.54, 1.0],
        ),
    );

    // Paralaxe radial sutil de exatos 15% da velocidade do swipe horizontal
    final parallaxShift = page * size.width * 0.15;

    // Halo aurora superior direito / central
    final topGlowCenter = Offset(
      (size.width * 0.84) - (parallaxShift * 0.45),
      size.height * 0.30,
    );
    final topRadius = size.width * 0.92;
    canvas.drawCircle(
      topGlowCenter,
      topRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          topGlowCenter,
          topRadius,
          [
            primaryOrb.withValues(alpha: 0.22),
            primaryOrb.withValues(alpha: 0.07),
            Colors.transparent,
          ],
          const [0.0, 0.56, 1.0],
        ),
    );

    // Bruma esmeralda/coral inferior esquerda fiel ao vídeo
    final bottomGlowCenter = Offset(
      (size.width * 0.18) + (parallaxShift * 0.35),
      size.height * 0.78,
    );
    final bottomRadius = size.width * 0.86;
    canvas.drawCircle(
      bottomGlowCenter,
      bottomRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          bottomGlowCenter,
          bottomRadius,
          [
            secondaryOrb.withValues(alpha: 0.18),
            secondaryOrb.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          const [0.0, 0.58, 1.0],
        ),
    );

    // Véu diagonal suave de aurora atrás do cartão de porcelana
    final auroraVeil = Path()
      ..moveTo(-size.width * 0.15, size.height * 0.58)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.42,
        size.width * 1.15,
        size.height * 0.68,
      )
      ..lineTo(size.width * 1.15, size.height * 0.92)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.66,
        -size.width * 0.15,
        size.height * 0.84,
      )
      ..close();
    canvas.drawPath(
      auroraVeil,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height * 0.45),
          Offset(size.width, size.height * 0.85),
          [
            secondaryOrb.withValues(alpha: 0.04),
            primaryOrb.withValues(alpha: 0.10),
            secondaryOrb.withValues(alpha: 0.05),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );

    // Pontos luminosos dourados suaves no horizonte das Etapas 5 e 6
    if (stardust > 0.02) {
      for (final star in _kAmbientStars) {
        final center = Offset(
          (size.width * star.$1) - (parallaxShift * 0.08),
          size.height * star.$2,
        );
        canvas.drawCircle(
          center,
          star.$3 * 3.0,
          Paint()
            ..color = const Color(0xFFFDE68A).withValues(
              alpha: 0.10 * stardust,
            ),
        );
        canvas.drawCircle(
          center,
          star.$3,
          Paint()
            ..color = const Color(0xFFFEF3C7).withValues(
              alpha: 0.46 * stardust,
            ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SharedAmbientPainter oldDelegate) {
    return oldDelegate.ambientPageListenable != ambientPageListenable;
  }
}

// =============================================================================
// FÍSICA DE MOLA CRITICAMENTE AMORTECIDA DO PAGEVIEW
// =============================================================================

class _SereneStoryPageScrollPhysics extends PageScrollPhysics {
  const _SereneStoryPageScrollPhysics({
    required this.settledPageGetter,
    super.parent,
  });

  final ValueGetter<int> settledPageGetter;

  @override
  _SereneStoryPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SereneStoryPageScrollPhysics(
      settledPageGetter: settledPageGetter,
      parent: buildParent(ancestor),
    );
  }

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
        mass: 1.0,
        stiffness: 420.0,
        ratio: 1.0,
      );

  double _pageFromMetrics(ScrollMetrics position) {
    if (position is PageMetrics && position.page != null) {
      return position.page!;
    }
    final dim = position.viewportDimension;
    if (dim <= 0) return 0.0;
    return position.pixels / dim;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final currentPage = _pageFromMetrics(position);
    final originPage = settledPageGetter().toDouble();
    final deltaPage = currentPage - originPage;
    const maxPage = DesperrengueWelcomeCinemaScreen.storyCount - 1.0;

    double targetPage;
    if (velocity > tolerance.velocity ||
        (velocity >= -tolerance.velocity && deltaPage >= 0.20)) {
      targetPage = math.min(maxPage, originPage + 1.0);
    } else if (velocity < -tolerance.velocity ||
        (velocity <= tolerance.velocity && deltaPage <= -0.20)) {
      targetPage = math.max(0.0, originPage - 1.0);
    } else {
      targetPage = originPage.clamp(0.0, maxPage);
    }

    final targetPixels = (targetPage * position.viewportDimension).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    if ((targetPixels - position.pixels).abs() > tolerance.distance ||
        velocity.abs() > tolerance.velocity) {
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        targetPixels,
        velocity,
        tolerance: tolerance,
      );
    }
    return null;
  }
}

// =============================================================================
// TOPO FIEL AO VÍDEO (100% PORTUGUÊS — 6 BARRAS BRANCAS + ETAPA X DE 6 + PULAR)
// =============================================================================

class _TopSegmentedProgressBars extends StatelessWidget {
  const _TopSegmentedProgressBars({
    required this.storyProgressController,
    required this.activeStoryListenable,
    required this.onTapChapter,
  });

  final AnimationController storyProgressController;
  final ValueListenable<int> activeStoryListenable;
  final ValueChanged<int> onTapChapter;

  @override
  Widget build(BuildContext context) {
    const count = DesperrengueWelcomeCinemaScreen.storyCount;

    return RepaintBoundary(
      child: SizedBox(
        key: const Key('welcome-cinema-progress-bar'),
        height: 44.0,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            storyProgressController,
            activeStoryListenable,
          ]),
          builder: (context, _) {
            final t = storyProgressController.value.clamp(0.0, 1.0);
            final activeStory = activeStoryListenable.value.clamp(0, count - 1);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(count, (i) {
                final double fill;
                if (i < activeStory) {
                  fill = 1.0;
                } else if (i == activeStory) {
                  fill = ((t * count) - i).clamp(0.0, 1.0);
                } else {
                  fill = 0.0;
                }

                return Expanded(
                  child: GestureDetector(
                    key: Key('cinema-chapter-tap-$i'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTapChapter(i),
                    child: SizedBox(
                      height: 44.0,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: i < count - 1 ? 5.0 : 0.0,
                          ),
                          child: SizedBox(
                            height: 3.5,
                            width: double.infinity,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.24),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: fill,
                                    heightFactor: 1.0,
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Color(0xFFF8FAFC),
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
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _TopStageHeaderRow extends StatelessWidget {
  const _TopStageHeaderRow({
    required this.activeStoryListenable,
    required this.isReplay,
    required this.isCompact,
    required this.holdPausedListenable,
    required this.onExitPressed,
  });

  final ValueListenable<int> activeStoryListenable;
  final bool isReplay;
  final bool isCompact;
  final ValueListenable<bool> holdPausedListenable;
  final VoidCallback onExitPressed;

  @override
  Widget build(BuildContext context) {
    const total = DesperrengueWelcomeCinemaScreen.storyCount;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: ValueListenableBuilder<int>(
                    valueListenable: activeStoryListenable,
                    builder: (context, storyIndex, _) {
                      final safeStep = (storyIndex + 1).clamp(1, total);
                      return Text(
                        'Etapa $safeStep de $total',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFCBD5E1),
                          fontSize: isCompact ? 12.5 : 13.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      );
                    },
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: holdPausedListenable,
                  builder: (context, isPaused, _) {
                    if (!isPaused) return const SizedBox.shrink();
                    return const Flexible(
                      child: Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: _FadeInPausedBadge(
                          key: Key('cinema-paused-badge'),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: Key(
              isReplay
                  ? 'btn-close-replay-cinema'
                  : 'btn-skip-welcome-cinema',
            ),
            onPressed: onExitPressed,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFF8FAFC),
              backgroundColor: const Color(0xFF13222A).withValues(alpha: 0.72),
              minimumSize: const Size(60, 44),
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 14 : 16,
                vertical: 8,
              ),
              tapTargetSize: MaterialTapTargetSize.padded,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.34),
                  width: 1.0,
                ),
              ),
            ),
            child: Text(
              isReplay ? 'Fechar' : 'Pular',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFF8FAFC),
                fontSize: isCompact ? 12.0 : 13.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FadeInPausedBadge extends StatefulWidget {
  const _FadeInPausedBadge({super.key});

  @override
  State<_FadeInPausedBadge> createState() => _FadeInPausedBadgeState();
}

class _FadeInPausedBadgeState extends State<_FadeInPausedBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _fadeController.value = 1.0;
    } else if (_fadeController.status == AnimationStatus.dismissed) {
      _fadeController.forward();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOutCubic,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF14242E).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pause_rounded,
                size: 12,
                color: Color(0xFFF8FAFC),
              ),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Pausado',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
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

// =============================================================================
// RODAPÉ FIEL AO VÍDEO (6 PONTOS CENTRALIZADOS + PÍLULA LARGA + VOLTAR DISCRETO)
// =============================================================================

class _BottomStoryNavigationBar extends StatelessWidget {
  const _BottomStoryNavigationBar({
    required this.activeStoryListenable,
    required this.isCompact,
    required this.isUltraCompact,
    required this.onPrevious,
    required this.onNext,
  });

  final ValueListenable<int> activeStoryListenable;
  final bool isCompact;
  final bool isUltraCompact;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    const total = DesperrengueWelcomeCinemaScreen.storyCount;

    return ValueListenableBuilder<int>(
      valueListenable: activeStoryListenable,
      builder: (context, storyIndex, _) {
        final isFirst = storyIndex <= 0;
        final isLast = storyIndex >= total - 1;
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        final buttonHeight = isCompact ? 50.0 : 54.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              key: const Key('story-pagination-dots'),
              height: 12.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) {
                  final active = i == storyIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.5),
                    child: AnimatedContainer(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: active ? 18.0 : 6.0,
                      height: 6.0,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: active
                            ? const Color(0xFFF8FAFC)
                            : Colors.white.withValues(alpha: 0.34),
                      ),
                    ),
                  );
                }),
              ),
            ),
            SizedBox(height: isUltraCompact ? 6.0 : 10.0),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: buttonHeight),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!isFirst) ...[
                    Semantics(
                      button: true,
                      label: 'Voltar',
                      child: Tooltip(
                        message: 'Voltar',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const Key('btn-story-prev'),
                            onTap: onPrevious,
                            customBorder: const CircleBorder(),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF14232B)
                                    .withValues(alpha: 0.72),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.30),
                                ),
                              ),
                              child: const SizedBox(
                                width: 48.0,
                                height: 48.0,
                                child: Center(
                                  child: Icon(
                                    Icons.chevron_left_rounded,
                                    size: 24,
                                    color: Color(0xFFF8FAFC),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10.0),
                  ],
                  Expanded(
                    child: _PrimaryWidePillActionButton(
                      key: const Key('btn-story-next'),
                      isAuroraCta: isLast,
                      height: buttonHeight,
                      isCompact: isCompact,
                      onPressed: onNext,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PrimaryWidePillActionButton extends StatelessWidget {
  const _PrimaryWidePillActionButton({
    super.key,
    required this.isAuroraCta,
    required this.height,
    required this.isCompact,
    required this.onPressed,
  });

  final bool isAuroraCta;
  final double height;
  final bool isCompact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: isAuroraCta ? null : const Color(0xFFF8FAFC),
        gradient: isAuroraCta
            ? const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF6EE7B7),
                  Color(0xFFA7F3D0),
                  Color(0xFFFDE68A),
                  Color(0xFFFDBA74),
                ],
                stops: [0.0, 0.36, 0.72, 1.0],
              )
            : null,
        border: Border.all(
          color: isAuroraCta
              ? Colors.white.withValues(alpha: 0.65)
              : const Color(0xFFFFFFFF),
          width: 1.0,
        ),
        boxShadow: isAuroraCta
            ? [
                BoxShadow(
                  color: const Color(0xFF6EE7B7).withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(-6, 6),
                ),
                BoxShadow(
                  color: const Color(0xFFFDBA74).withValues(alpha: 0.30),
                  blurRadius: 22,
                  offset: const Offset(6, 6),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF040B14).withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: Text(
                  isAuroraCta ? 'Começar agora' : 'Próximo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isAuroraCta
                        ? const Color(0xFF0B1320)
                        : const Color(0xFF0F172A),
                    fontSize: isCompact ? 14.5 : 15.8,
                    fontWeight:
                        isAuroraCta ? FontWeight.w900 : FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PÁGINA DA ETAPA COM COREOGRAFIA FINITA EM 3 ATOS (ZERO REPEAT, >= 38% RESPIRO)
// =============================================================================

class _StorySlidePage extends StatefulWidget {
  const _StorySlidePage({
    super.key,
    required this.storyIndex,
    required this.isActiveStory,
    required this.totalDuration,
    required this.isCompact,
    required this.isUltraCompact,
    required this.pageController,
    required this.holdPausedListenable,
    required this.onInteractiveControlPointerDown,
    this.restartEpochListenable,
    this.onActiveHeroBuild,
  });

  final int storyIndex;
  final bool isActiveStory;
  final Duration totalDuration;
  final bool isCompact;
  final bool isUltraCompact;
  final PageController pageController;
  final ValueListenable<bool> holdPausedListenable;
  final ValueChanged<int> onInteractiveControlPointerDown;
  final ValueListenable<int>? restartEpochListenable;
  final ValueChanged<int>? onActiveHeroBuild;

  @override
  State<_StorySlidePage> createState() => _StorySlidePageState();
}

class _StorySlidePageState extends State<_StorySlidePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _actController;
  bool _reduceMotion = false;
  bool _startedInitialChoreography = false;

  Duration _computeActDuration() {
    final perStoryMs = widget.totalDuration.inMilliseconds /
        DesperrengueWelcomeCinemaScreen.storyCount;
    final ms = math.min(3100, math.max(180, (perStoryMs * 0.72).round()));
    return Duration(milliseconds: ms);
  }

  @override
  void initState() {
    super.initState();
    _actController = AnimationController(
      vsync: this,
      duration: _computeActDuration(),
    );
    widget.holdPausedListenable.addListener(_onHoldPauseChanged);
    widget.restartEpochListenable?.addListener(_onRestartSignal);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _actController.value = 1.0;
      _startedInitialChoreography = true;
    } else if (!_startedInitialChoreography) {
      _startedInitialChoreography = true;
      if (!widget.holdPausedListenable.value) {
        _actController.forward(from: 0.0);
      }
    }
  }

  @override
  void didUpdateWidget(covariant _StorySlidePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalDuration != widget.totalDuration) {
      _actController.duration = _computeActDuration();
    }
    if (oldWidget.holdPausedListenable != widget.holdPausedListenable) {
      oldWidget.holdPausedListenable.removeListener(_onHoldPauseChanged);
      widget.holdPausedListenable.addListener(_onHoldPauseChanged);
    }
    if (oldWidget.restartEpochListenable != widget.restartEpochListenable) {
      oldWidget.restartEpochListenable?.removeListener(_onRestartSignal);
      widget.restartEpochListenable?.addListener(_onRestartSignal);
    }
  }

  void _onHoldPauseChanged() {
    if (_reduceMotion) return;
    if (widget.holdPausedListenable.value) {
      if (_actController.isAnimating) {
        _actController.stop(canceled: false);
      }
    } else {
      if (_actController.value < 1.0 && !_actController.isAnimating) {
        _actController.forward();
      }
    }
  }

  void _onRestartSignal() {
    if (_reduceMotion) {
      _actController.value = 1.0;
      return;
    }
    _actController.forward(from: 0.0);
  }

  @override
  void dispose() {
    widget.holdPausedListenable.removeListener(_onHoldPauseChanged);
    widget.restartEpochListenable?.removeListener(_onRestartSignal);
    _actController.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end) {
    return CurvedAnimation(
      parent: _actController,
      curve: Interval(begin, end, curve: Curves.easeOutQuart),
    );
  }

  (String, String) _copyForStory(int index) {
    switch (index) {
      case 0:
        return (
          'Casa Resolvida Sem Dor de Cabeça',
          'Do reparo urgente à manutenção planejada, encontre o especialista certo em poucos toques.',
        );
      case 1:
        return (
          'Privacidade Total ao Pedir',
          'Compare até 3 orçamentos protegidos. Seu endereço fica oculto até contratar.',
        );
      case 2:
        return (
          'Seu Dinheiro 100% Protegido',
          'O valor fica guardado em segurança e só libera com seu código pessoal.',
        );
      case 3:
        return (
          'Sua Casa Mais Valorizada',
          'Histórico inteligente do imóvel pronto em PDF para aluguéis, seguros ou venda.',
        );
      case 4:
        return (
          'Justo para Quem Trabalha',
          'Sem pagar taxas para enviar orçamento e 100% das peças sem desconto.',
        );
      default:
        return (
          'Uma Conta, Dois Caminhos',
          'Contrate serviços ou atenda clientes com uma única conta verificada.',
        );
    }
  }

  Widget _buildHeroDemoContent(int index, bool isCompact, bool isUltraCompact) {
    switch (index) {
      case 0:
        return _Story1SearchAndSpecialtiesDemo(
          actAnimation: _actController,
          isCompact: isCompact,
          isUltraCompact: isUltraCompact,
        );
      case 1:
        return _Story2PrivacyAndQuotesDemo(
          actAnimation: _actController,
          isCompact: isCompact,
          isUltraCompact: isUltraCompact,
        );
      case 2:
        return _Story3ProtectedVaultPinDemo(
          actAnimation: _actController,
          isCompact: isCompact,
          isUltraCompact: isUltraCompact,
        );
      case 3:
        return _Story4PropertyHealthHistoryDemo(
          actAnimation: _actController,
          isCompact: isCompact,
          isUltraCompact: isUltraCompact,
        );
      case 4:
        return _Story5FairProviderPanelDemo(
          actAnimation: _actController,
          isCompact: isCompact,
          isUltraCompact: isUltraCompact,
        );
      default:
        return _Story6DualAccountSwitchDemo(
          actAnimation: _actController,
          isCompact: isCompact,
          isUltraCompact: isUltraCompact,
          onInteractivePointerDown: widget.onInteractiveControlPointerDown,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _kStorySpecs[widget.storyIndex];
    final (titleText, subtitleText) = _copyForStory(widget.storyIndex);
    final isCompact = widget.isCompact;
    final isUltraCompact = widget.isUltraCompact;

    // Ato 1 (0.0s – 0.75s = 0.00 .. 0.242 de 3.10s): cascata sedosa sem quique
    final titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      _interval(0.00, 0.16),
    );
    final titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(_interval(0.00, 0.16));

    final subFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      _interval(0.04, 0.20),
    );
    final subSlide = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(_interval(0.04, 0.20));

    final heroOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      _interval(0.08, 0.242),
    );
    final heroRise = Tween<double>(begin: 18.0, end: 0.0).animate(
      _interval(0.08, 0.242),
    );

    final heroCard = WelcomeStoryHeroCard(
      storyIndex: widget.storyIndex,
      isActiveStory: widget.isActiveStory,
      accentColor: spec.accent,
      isCompact: isCompact,
      onActiveHeroBuild: widget.onActiveHeroBuild,
      child: _buildHeroDemoContent(
        widget.storyIndex,
        isCompact,
        isUltraCompact,
      ),
    );

    final animatedHero = AnimatedBuilder(
      animation: Listenable.merge([heroRise, widget.pageController]),
      child: FadeTransition(
        opacity: heroOpacity,
        child: heroCard,
      ),
      builder: (context, cachedHero) {
        double parallaxX = 0.0;
        if (widget.pageController.hasClients) {
          try {
            final pos = widget.pageController.position;
            if (pos.hasContentDimensions && pos.hasPixels) {
              final p =
                  widget.pageController.page ?? widget.storyIndex.toDouble();
              parallaxX = (p - widget.storyIndex).clamp(-1.0, 1.0) * 16.0;
            }
          } catch (_) {
            parallaxX = 0.0;
          }
        }
        return Transform.translate(
          offset: Offset(parallaxX, heroRise.value),
          child: cachedHero,
        );
      },
    );

    final showStardust = widget.storyIndex == 4 || widget.storyIndex == 5;
    final heroStageWithOptionalStardust = showStardust
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                top: -14,
                bottom: -14,
                left: -8,
                right: -8,
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _GoldenCelebrationStardustPainter(
                        actAnimation: _actController,
                        isWarmSunset: widget.storyIndex == 5,
                      ),
                    ),
                  ),
                ),
              ),
              animatedHero,
            ],
          )
        : animatedHero;

    final titleSize = isUltraCompact ? 18.0 : (isCompact ? 21.0 : 27.5);
    final subSize = isUltraCompact ? 11.4 : (isCompact ? 12.6 : 14.8);

    return CustomScrollView(
      key: spec.legacyKey,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 4),
                  FadeTransition(
                    opacity: titleFade,
                    child: SlideTransition(
                      position: titleSlide,
                      child: Text(
                        titleText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFF8FAFC),
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1.14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isUltraCompact ? 4 : (isCompact ? 6 : 10)),
                  FadeTransition(
                    opacity: subFade,
                    child: SlideTransition(
                      position: subSlide,
                      child: Text(
                        subtitleText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFE2E8F0),
                          fontSize: subSize,
                          fontWeight: FontWeight.w400,
                          height: 1.32,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isUltraCompact ? 10 : (isCompact ? 14 : 22)),
                  heroStageWithOptionalStardust,
                  const Spacer(flex: 5),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Poeira estelar dourada sutil fluindo entre `1.2s–3.1s` e repousando
/// serenamente nas Etapas 5 e 6 (fiel a `00:06–00:09` do vídeo, zero repeat).
class _GoldenCelebrationStardustPainter extends CustomPainter {
  _GoldenCelebrationStardustPainter({
    required this.actAnimation,
    required this.isWarmSunset,
  }) : super(repaint: actAnimation);

  final Animation<double> actAnimation;
  final bool isWarmSunset;

  static const List<(double, double, double, bool)> _kParticles =
      <(double, double, double, bool)>[
    (0.06, 0.88, 3.2, true),
    (0.14, 0.96, 2.2, false),
    (0.24, 0.99, 2.8, false),
    (0.76, 0.98, 2.5, false),
    (0.88, 0.92, 3.4, true),
    (0.95, 0.80, 2.6, true),
    (0.03, 0.72, 2.1, false),
    (0.92, 0.22, 2.4, true),
    (0.08, 0.18, 2.0, false),
    (0.50, 1.01, 2.2, false),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // 1.2s..3.1s de 3.10s -> [0.387 .. 1.0]
    final raw = ((actAnimation.value - 0.387) / (1.0 - 0.387)).clamp(0.0, 1.0);
    if (raw <= 0.001) return;

    final p = Curves.easeOutQuart.transform(raw);
    final primaryGold =
        isWarmSunset ? const Color(0xFFFDE68A) : const Color(0xFFFCD34D);
    final coreCream = const Color(0xFFFFFBEB);

    for (var i = 0; i < _kParticles.length; i++) {
      final item = _kParticles[i];
      final stagger = ((raw - (i * 0.04)) / 0.64).clamp(0.0, 1.0);
      if (stagger <= 0.0) continue;
      final sp = Curves.easeOutQuart.transform(stagger);
      final driftY = (1.0 - sp) * 14.0;
      final center = Offset(
        size.width * item.$1,
        (size.height * item.$2) + driftY,
      );
      final radius = item.$3 * (0.65 + 0.35 * sp);
      final alpha = (0.62 * p * sp).clamp(0.0, 0.65);

      canvas.drawCircle(
        center,
        radius * 2.8,
        Paint()..color = primaryGold.withValues(alpha: alpha * 0.28),
      );

      if (item.$4) {
        _drawFourPointSparkle(canvas, center, radius * 2.1, coreCream, alpha);
      } else {
        canvas.drawCircle(
          center,
          radius,
          Paint()..color = coreCream.withValues(alpha: alpha),
        );
      }
    }
  }

  void _drawFourPointSparkle(
    Canvas canvas,
    Offset c,
    double r,
    Color color,
    double alpha,
  ) {
    final q = r * 0.26;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + q, c.dy - q, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + q, c.dy + q, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - q, c.dy + q, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - q, c.dy - q, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: alpha));
  }

  @override
  bool shouldRepaint(covariant _GoldenCelebrationStardustPainter oldDelegate) {
    return oldDelegate.actAnimation != actAnimation ||
        oldDelegate.isWarmSunset != isWarmSunset;
  }
}

// =============================================================================
// ETAPA 1 (00:00–00:01): BUSCA + GRADE 2x2 VERIFICADA + ATENDIMENTO RÁPIDO
// =============================================================================

class _Story1SearchAndSpecialtiesDemo extends StatelessWidget {
  const _Story1SearchAndSpecialtiesDemo({
    required this.actAnimation,
    required this.isCompact,
    required this.isUltraCompact,
  });

  final Animation<double> actAnimation;
  final bool isCompact;
  final bool isUltraCompact;

  static const String _kFullQuery = 'Trocar resistência do chuveiro';

  @override
  Widget build(BuildContext context) {
    final gap = isUltraCompact ? 7.0 : (isCompact ? 9.0 : 12.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Story1SearchFieldLeaf(
          actAnimation: actAnimation,
          fullQuery: _kFullQuery,
          isCompact: isCompact,
          isUltraCompact: isUltraCompact,
        ),
        SizedBox(height: gap),
        _Story1VerifiedGrid2x2Leaf(
          actAnimation: actAnimation,
          isCompact: isCompact,
          isUltraCompact: isUltraCompact,
        ),
        SizedBox(height: gap),
        _Story1RegionSealLeaf(
          actAnimation: actAnimation,
          isCompact: isCompact,
        ),
      ],
    );
  }
}

class _Story1SearchFieldLeaf extends StatelessWidget {
  const _Story1SearchFieldLeaf({
    required this.actAnimation,
    required this.fullQuery,
    required this.isCompact,
    required this.isUltraCompact,
  });

  final Animation<double> actAnimation;
  final String fullQuery;
  final bool isCompact;
  final bool isUltraCompact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: actAnimation,
      builder: (context, _) {
        // 0.8s..1.8s de 3.10s -> [0.258 .. 0.581]
        final raw = ((actAnimation.value - 0.258) / (0.581 - 0.258)).clamp(
          0.0,
          1.0,
        );
        final progress = Curves.easeOutCubic.transform(raw);
        const minChars = 13; // "Trocar resist"
        final visibleCount = (minChars +
                ((fullQuery.length - minChars) * progress).round())
            .clamp(minChars, fullQuery.length);
        final isFinished = visibleCount >= fullQuery.length;
        final visibleText = isFinished
            ? fullQuery
            : '${fullQuery.substring(0, visibleCount)}...';

        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFF6EE7B7),
                const Color(0xFF10B981),
                progress,
              )!,
              width: 1.35,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 13,
              vertical: isUltraCompact ? 7.5 : (isCompact ? 9 : 11),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Color(0xFF047857),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    visibleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF0F172A),
                      fontSize: isCompact ? 11.8 : 13.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Story1VerifiedGrid2x2Leaf extends StatelessWidget {
  const _Story1VerifiedGrid2x2Leaf({
    required this.actAnimation,
    required this.isCompact,
    required this.isUltraCompact,
  });

  final Animation<double> actAnimation;
  final bool isCompact;
  final bool isUltraCompact;

  static const List<(String, String)> _kItems = <(String, String)>[
    ('Eletricista Verificado', 'Elétrica'),
    ('Encanador', 'Encanador'),
    ('Climatização', 'Ar-condicionado'),
    ('Reparos Gerais', 'Pequenos Reparos'),
  ];

  Widget _buildSpecialtyPill({
    required int index,
    required String displayLabel,
    required String emblemCategory,
    required double progress,
  }) {
    final emblemSize = isUltraCompact ? 20.0 : (isCompact ? 22.0 : 28.0);

    return Opacity(
      opacity: (0.30 + (0.70 * progress)).clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1.0 - progress) * 7.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: index == 0
                  ? const Color(0xFF6EE7B7)
                  : const Color(0xFFE2E8F0),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 7 : 10,
              vertical: isUltraCompact ? 5.5 : (isCompact ? 7 : 8.5),
            ),
            child: Row(
              children: [
                CategoryBrandEmblem(
                  categoryName: emblemCategory,
                  size: emblemSize,
                  showCornerBadge: false,
                ),
                SizedBox(width: isCompact ? 6 : 8),
                Expanded(
                  child: Text(
                    displayLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF0F172A),
                      fontSize: isUltraCompact
                          ? 10.2
                          : (isCompact ? 10.8 : 12.0),
                      fontWeight: FontWeight.w700,
                      height: 1.14,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF10B981),
                  ),
                  child: SizedBox(
                    width: 15,
                    height: 15,
                    child: Center(
                      child: Icon(
                        Icons.check_rounded,
                        size: 10.5,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = isCompact ? 6.0 : 8.0;

    return AnimatedBuilder(
      animation: actAnimation,
      builder: (context, _) {
        double itemProgress(int i) {
          final start = 0.36 + (i * 0.075);
          final end = (start + 0.24).clamp(0.0, 1.0);
          return Curves.easeOutQuart.transform(
            ((actAnimation.value - start) / (end - start)).clamp(0.0, 1.0),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSpecialtyPill(
                    index: 0,
                    displayLabel: _kItems[0].$1,
                    emblemCategory: _kItems[0].$2,
                    progress: itemProgress(0),
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: _buildSpecialtyPill(
                    index: 1,
                    displayLabel: _kItems[1].$1,
                    emblemCategory: _kItems[1].$2,
                    progress: itemProgress(1),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing),
            Row(
              children: [
                Expanded(
                  child: _buildSpecialtyPill(
                    index: 2,
                    displayLabel: _kItems[2].$1,
                    emblemCategory: _kItems[2].$2,
                    progress: itemProgress(2),
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: _buildSpecialtyPill(
                    index: 3,
                    displayLabel: _kItems[3].$1,
                    emblemCategory: _kItems[3].$2,
                    progress: itemProgress(3),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Story1RegionSealLeaf extends StatelessWidget {
  const _Story1RegionSealLeaf({
    required this.actAnimation,
    required this.isCompact,
  });

  final Animation<double> actAnimation;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: actAnimation,
      builder: (context, _) {
        final p = Curves.easeOutQuart.transform(
          ((actAnimation.value - 0.62) / 0.28).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: (0.38 + (0.62 * p)).clamp(0.0, 1.0),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 11 : 14,
                  vertical: isCompact ? 5.5 : 7.0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 15,
                      color: Color(0xFF059669),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Atendimento rápido na sua região',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF064E3B),
                          fontSize: isCompact ? 11.0 : 12.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// ETAPA 2 (00:02): PEDIDO PROTEGIDO + RUA OCULTA + 3 PROPOSTAS CLARAS
// =============================================================================

class _Story2PrivacyAndQuotesDemo extends StatelessWidget {
  const _Story2PrivacyAndQuotesDemo({
    required this.actAnimation,
    required this.isCompact,
    required this.isUltraCompact,
  });

  final Animation<double> actAnimation;
  final bool isCompact;
  final bool isUltraCompact;

  static const List<(String, String, String)> _kProposals =
      <(String, String, String)>[
    ('Proposta 1', 'R\$ 120,00', '4,9'),
    ('Proposta 2', 'R\$ 150,00', '4,8'),
    ('Proposta 3', 'R\$ 180,00', '4,7'),
  ];

  @override
  Widget build(BuildContext context) {
    final gap = isUltraCompact ? 6.5 : (isCompact ? 8.5 : 11.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pedido Protegido',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFF0F172A),
            fontSize: isCompact ? 14.0 : 16.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(height: gap),
        _Story2AddressShieldLeaf(
          actAnimation: actAnimation,
          isCompact: isCompact,
          isUltraCompact: isUltraCompact,
        ),
        SizedBox(height: gap),
        _Story2ProposalsListLeaf(
          actAnimation: actAnimation,
          proposals: _kProposals,
          isCompact: isCompact,
          isUltraCompact: isUltraCompact,
        ),
      ],
    );
  }
}

class _Story2AddressShieldLeaf extends StatelessWidget {
  const _Story2AddressShieldLeaf({
    required this.actAnimation,
    required this.isCompact,
    required this.isUltraCompact,
  });

  final Animation<double> actAnimation;
  final bool isCompact;
  final bool isUltraCompact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: actAnimation,
      builder: (context, _) {
        // 0.85s..1.75s de 3.10s -> [0.274 .. 0.565]
        final shieldProgress = Curves.easeOutQuart.transform(
          ((actAnimation.value - 0.274) / (0.565 - 0.274)).clamp(0.0, 1.0),
        );
        final shielded = shieldProgress >= 0.45;
        final bg = Color.lerp(
          const Color(0xFFF1F5F9),
          const Color(0xFFDCFCE7),
          shieldProgress,
        )!;
        final border = Color.lerp(
          const Color(0xFFCBD5E1),
          const Color(0xFF86EFAC),
          shieldProgress,
        )!;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1.15),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 13,
              vertical: isUltraCompact ? 6.5 : (isCompact ? 8 : 9.5),
            ),
            child: Row(
              children: [
                Icon(
                  shielded ? Icons.lock_rounded : Icons.place_outlined,
                  size: 15,
                  color: shielded
                      ? const Color(0xFF047857)
                      : const Color(0xFF334155),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    shielded
                        ? '🔒 Rua e número protegidos'
                        : 'Ocultando rua e número...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: shielded
                          ? const Color(0xFF064E3B)
                          : const Color(0xFF334155),
                      fontSize: isCompact ? 11.5 : 13.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Story2ProposalsListLeaf extends StatelessWidget {
  const _Story2ProposalsListLeaf({
    required this.actAnimation,
    required this.proposals,
    required this.isCompact,
    required this.isUltraCompact,
  });

  final Animation<double> actAnimation;
  final List<(String, String, String)> proposals;
  final bool isCompact;
  final bool isUltraCompact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: actAnimation,
      builder: (context, _) {
        // Destaque suave da Proposta 1 aos 2.1s (0.677 de 3.10s)
        final selectProgress = Curves.easeOutQuart.transform(
          ((actAnimation.value - 0.65) / 0.24).clamp(0.0, 1.0),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(proposals.length, (i) {
            final item = proposals[i];
            final isBest = i == 0;
            final highlight = isBest ? selectProgress : 0.0;

            return Padding(
              padding: EdgeInsets.only(
                top: i == 0 ? 0 : (isUltraCompact ? 5.0 : 7.0),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.lerp(
                    const Color(0xFFFFFFFF),
                    const Color(0xFFECFDF5),
                    highlight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color.lerp(
                      const Color(0xFFE2E8F0),
                      const Color(0xFF10B981),
                      highlight,
                    )!,
                    width: isBest && highlight > 0.4 ? 1.35 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 10 : 13,
                    vertical: isUltraCompact ? 6.5 : (isCompact ? 8 : 10),
                  ),
                  child: Row(
                    children: [
                      if (isBest && highlight > 0.5) ...[
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 15,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          item.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF0F172A),
                            fontSize: isCompact ? 11.8 : 13.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.$2,
                        maxLines: 1,
                        style: TextStyle(
                          color: isBest && highlight > 0.5
                              ? const Color(0xFF064E3B)
                              : const Color(0xFF0F172A),
                          fontSize: isCompact ? 11.8 : 13.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: isCompact ? 7 : 10),
                      const Icon(
                        Icons.star_rounded,
                        size: 15,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        item.$3,
                        maxLines: 1,
                        style: TextStyle(
                          color: const Color(0xFF0F172A),
                          fontSize: isCompact ? 11.5 : 12.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// =============================================================================
// ETAPA 3 (00:03–00:04): COFRE 3D + CARTÃO SAFIRA + DÍGITOS 4 · 8 · 2 · (9)
// =============================================================================

class _Story3ProtectedVaultPinDemo extends StatelessWidget {
  const _Story3ProtectedVaultPinDemo({
    required this.actAnimation,
    required this.isCompact,
    required this.isUltraCompact,
  });

  final Animation<double> actAnimation;
  final bool isCompact;
  final bool isUltraCompact;

  static const List<String> _kPinDigits = <String>['4', '8', '2', '9'];

  @override
  Widget build(BuildContext context) {
    final gap = isUltraCompact ? 6.5 : (isCompact ? 8.5 : 11.5);

    return AnimatedBuilder(
      animation: actAnimation,
      builder: (context, _) {
        final t = actAnimation.value;
        final approvedOpacity = Curves.easeOutQuart.transform(
          ((t - 0.52) / 0.34).clamp(0.0, 1.0),
        );
        final vaultProgress = Curves.easeOutQuart.transform(
          ((t - 0.20) / 0.65).clamp(0.0, 1.0),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Opacity(
              opacity: (0.28 + (0.72 * approvedOpacity)).clamp(0.0, 1.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Color(0xFF059669),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Serviço aprovado · 90 dias de garantia',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF065F46),
                        fontSize: isCompact ? 11.4 : 12.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: gap),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5F0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCFE8DE)),
              ),
              child: SizedBox(
                height: isUltraCompact ? 68.0 : (isCompact ? 80.0 : 98.0),
                width: double.infinity,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _ProtectedEscrowVaultArtPainter(
                      lockProgress: vaultProgress,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: gap),
            Text(
              'R\$ 180,00 · Guardado com segurança',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF0F172A),
                fontSize: isCompact ? 12.0 : 13.6,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: gap),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2F6),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFD8E1EB)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 12 : 16,
                  vertical: isUltraCompact ? 4.5 : (isCompact ? 6.0 : 7.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_kPinDigits.length, (i) {
                    // 1.0s..2.4s -> [0.323 .. 0.774]
                    final threshold = 0.33 + (i * 0.115);
                    final lit = Curves.easeOutQuart.transform(
                      ((t - threshold) / 0.11).clamp(0.0, 1.0),
                    );
                    final isLit = lit >= 0.45;
                    final isFinalConfirmed = i == _kPinDigits.length - 1;
                    final ringSize =
                        isUltraCompact ? 28.0 : (isCompact ? 31.0 : 35.0);

                    return SizedBox(
                      width: ringSize,
                      height: ringSize,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFinalConfirmed
                              ? Color.lerp(
                                  const Color(0xFFE2E8F0),
                                  const Color(0xFFDCFCE7),
                                  lit,
                                )
                              : Colors.transparent,
                          border: isFinalConfirmed
                              ? Border.all(
                                  color: Color.lerp(
                                    const Color(0xFFCBD5E1),
                                    const Color(0xFF10B981),
                                    lit,
                                  )!,
                                  width: 2.0,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            isLit ? _kPinDigits[i] : '•',
                            style: TextStyle(
                              color: isFinalConfirmed && isLit
                                  ? const Color(0xFF064E3B)
                                  : const Color(0xFF0F172A),
                              fontSize: isCompact ? 15.0 : 17.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Ilustração Vetorial 3D de Cofre Metálico Escovado + Cartão Safira com Chip
/// Dourado sobre palco menta-pérola (fiel a `00:03–00:04` do vídeo).
class _ProtectedEscrowVaultArtPainter extends CustomPainter {
  const _ProtectedEscrowVaultArtPainter({required this.lockProgress});

  final double lockProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 220.0, size.height / 96.0);
    canvas.save();
    canvas.translate(
      (size.width - (220.0 * s)) / 2.0,
      (size.height - (96.0 * s)) / 2.0,
    );
    canvas.scale(s, s);

    // Sombra macia de contato no palco menta-pérola
    canvas.drawOval(
      const Rect.fromLTWH(34, 72, 152, 14),
      Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.12),
    );

    // 1) COFRE METÁLICO TITÂNIO ESCOVADO 3D (ESQUERDA/CENTRO)
    // Lateral esquerda 3D em perspectiva
    final sideDepth = RRect.fromRectAndRadius(
      const Rect.fromLTWH(46, 16, 16, 58),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      sideDepth,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF64748B), Color(0xFF334155)],
        ).createShader(const Rect.fromLTWH(46, 16, 16, 58)),
    );

    // Pés de apoio do cofre
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(56, 72, 12, 5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF1E293B),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(102, 72, 12, 5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF1E293B),
    );

    // Corpo frontal de titânio escovado
    const vaultRect = Rect.fromLTWH(53, 14, 68, 60);
    final vaultRRect = RRect.fromRectAndRadius(
      vaultRect,
      const Radius.circular(8),
    );
    canvas.drawRRect(
      vaultRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF1F5F9),
            Color(0xFFCBD5E1),
            Color(0xFF94A3B8),
          ],
          stops: [0.0, 0.52, 1.0],
        ).createShader(vaultRect),
    );
    canvas.drawRRect(
      vaultRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF64748B),
    );

    // Porta rebaixada do cofre + dobradiças cromadas
    const doorRect = Rect.fromLTWH(60, 21, 54, 46);
    final doorRRect = RRect.fromRectAndRadius(
      doorRect,
      const Radius.circular(5),
    );
    canvas.drawRRect(
      doorRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE2E8F0), Color(0xFF94A3B8)],
        ).createShader(doorRect),
    );
    canvas.drawRRect(
      doorRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFF475569),
    );

    for (final hy in const [27.0, 53.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(57, hy, 5, 8),
          const Radius.circular(1.5),
        ),
        Paint()..color = const Color(0xFF334155),
      );
    }

    // Volante circular central da trava do cofre (gira suavemente até travar)
    const dialCenter = Offset(87, 44);
    canvas.drawCircle(
      dialCenter,
      12.5,
      Paint()..color = const Color(0xFF1E293B),
    );
    canvas.drawCircle(
      dialCenter,
      10.2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = Color.lerp(
          const Color(0xFF94A3B8),
          const Color(0xFF34D399),
          lockProgress,
        )!,
    );

    final angleBase = lockProgress * (math.pi * 0.25);
    final spokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF8FAFC);
    for (var k = 0; k < 4; k++) {
      final a = angleBase + (k * math.pi / 2);
      canvas.drawLine(
        dialCenter,
        Offset(
          dialCenter.dx + math.cos(a) * 7.2,
          dialCenter.dy + math.sin(a) * 7.2,
        ),
        spokePaint,
      );
    }
    canvas.drawCircle(
      dialCenter,
      3.0,
      Paint()..color = const Color(0xFFE2E8F0),
    );

    // 2) CARTÃO SAFIRA PROTEGIDO COM CHIP DOURADO (SOBREPOSTO À DIREITA)
    const cardRect = Rect.fromLTWH(105, 24, 74, 48);
    final cardRRect = RRect.fromRectAndRadius(
      cardRect,
      const Radius.circular(8),
    );

    // Sombra projetada sobre o cofre
    canvas.drawRRect(
      cardRRect.shift(const Offset(-3, 4)),
      Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.24),
    );

    // Gradiente Safira Real
    canvas.drawRRect(
      cardRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B82F6),
            Color(0xFF1D4ED8),
            Color(0xFF1E3A8A),
          ],
          stops: [0.0, 0.55, 1.0],
        ).createShader(cardRect),
    );

    // Reflexo acetinado diagonal no cartão
    canvas.save();
    canvas.clipRRect(cardRRect);
    final sheen = Path()
      ..moveTo(118, 24)
      ..lineTo(148, 24)
      ..lineTo(130, 72)
      ..lineTo(105, 72)
      ..close();
    canvas.drawPath(
      sheen,
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );
    canvas.restore();

    canvas.drawRRect(
      cardRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFF93C5FD).withValues(alpha: 0.65),
    );

    // Chip EMV Dourado esculpido
    const chipRect = Rect.fromLTWH(114, 37, 15, 11);
    final chipRRect = RRect.fromRectAndRadius(
      chipRect,
      const Radius.circular(2.5),
    );
    canvas.drawRRect(
      chipRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
        ).createShader(chipRect),
    );
    canvas.drawLine(
      const Offset(114, 42.5),
      const Offset(129, 42.5),
      Paint()
        ..strokeWidth = 0.8
        ..color = const Color(0xFFB45309),
    );

    // Pontos prateados e selo esmeralda no canto do cartão
    for (var d = 0; d < 4; d++) {
      canvas.drawCircle(
        Offset(116.0 + (d * 5.0), 59.0),
        1.3,
        Paint()..color = const Color(0xFFDBEAFE),
      );
    }
    canvas.drawCircle(
      const Offset(166, 58),
      6.5,
      Paint()..color = const Color(0xFF10B981),
    );
    final check = Path()
      ..moveTo(163.2, 58.0)
      ..lineTo(165.3, 60.1)
      ..lineTo(169.2, 56.0);
    canvas.drawPath(
      check,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ProtectedEscrowVaultArtPainter oldDelegate) {
    return oldDelegate.lockProgress != lockProgress;
  }
}

// =============================================================================
// ETAPA 4 (00:05): SAÚDE DO IMÓVEL 96% (ARCO 180° ESMERALDA) + HISTÓRICO PDF
// =============================================================================

class _Story4PropertyHealthHistoryDemo extends StatelessWidget {
  const _Story4PropertyHealthHistoryDemo({
    required this.actAnimation,
    required this.isCompact,
    required this.isUltraCompact,
  });

  final Animation<double> actAnimation;
  final bool isCompact;
  final bool isUltraCompact;

  static const List<String> _kCertifiedRows = <String>[
    'Revisão Elétrica · 12/10/2026',
    'Climatização · 05/11/2026',
  ];

  @override
  Widget build(BuildContext context) {
    final gap = isUltraCompact ? 6.0 : (isCompact ? 8.0 : 11.0);

    return AnimatedBuilder(
      animation: actAnimation,
      builder: (context, _) {
        final arcProgress = Curves.easeOutQuart.transform(
          ((actAnimation.value - 0.22) / 0.58).clamp(0.0, 1.0),
        );
        final displayedPercent = (72 + (24 * arcProgress).round()).clamp(0, 96);
        final gaugeHeight = isUltraCompact ? 78.0 : (isCompact ? 90.0 : 108.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Saúde do Imóvel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF0F172A),
                      fontSize: isCompact ? 14.0 : 16.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (index) {
                        return Padding(
                          padding: EdgeInsets.only(left: index == 0 ? 0 : 3),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF475569),
                            ),
                            child: SizedBox(width: 3.5, height: 3.5),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: gap),
            SizedBox(
              height: gaugeHeight,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _PropertyHealthSemiArchPainter(
                          progress: 0.96 * arcProgress,
                          strokeWidth: isUltraCompact ? 10.5 : 13.0,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: isUltraCompact ? 14.0 : 18.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$displayedPercent%',
                          maxLines: 1,
                          style: TextStyle(
                            color: const Color(0xFF0F172A),
                            fontSize: isUltraCompact
                                ? 21.0
                                : (isCompact ? 24.0 : 30.0),
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Em dia',
                          maxLines: 1,
                          style: TextStyle(
                            color: const Color(0xFF334155),
                            fontSize: isCompact ? 11.2 : 12.6,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: isCompact ? 16 : 28,
                    bottom: 0,
                    child: Text(
                      '0%',
                      style: TextStyle(
                        color: const Color(0xFF334155),
                        fontSize: isCompact ? 10.2 : 11.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Positioned(
                    right: isCompact ? 12 : 22,
                    bottom: 0,
                    child: Text(
                      '100%',
                      style: TextStyle(
                        color: const Color(0xFF334155),
                        fontSize: isCompact ? 10.2 : 11.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: gap),
            for (var i = 0; i < _kCertifiedRows.length; i++) ...[
              if (i > 0) SizedBox(height: isUltraCompact ? 5.0 : 7.0),
              Opacity(
                opacity: (0.35 +
                        0.65 *
                            Curves.easeOutQuart.transform(
                              ((actAnimation.value - (0.44 + i * 0.14)) / 0.25)
                                  .clamp(0.0, 1.0),
                            ))
                    .clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 9 : 12,
                      vertical: isUltraCompact ? 6.0 : (isCompact ? 7.5 : 9.0),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _kCertifiedRows[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF0F172A),
                              fontSize: isCompact ? 11.4 : 12.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF991B1B),
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.5,
                              vertical: 2.5,
                            ),
                            child: Text(
                              'PDF',
                              style: TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontSize: 9.8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PropertyHealthSemiArchPainter extends CustomPainter {
  const _PropertyHealthSemiArchPainter({
    required this.progress,
    required this.strokeWidth,
  });

  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(
      (size.width / 2) - strokeWidth - 8.0,
      size.height - strokeWidth - 10.0,
    );
    if (radius <= 8.0) return;

    final center = Offset(size.width / 2, size.height - 14.0);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE2E8F0);

    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);

    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= 0.001) return;

    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0xFF34D399),
          Color(0xFF10B981),
          Color(0xFF059669),
        ],
      ).createShader(rect);

    canvas.drawArc(rect, math.pi, math.pi * clamped, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant _PropertyHealthSemiArchPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// =============================================================================
// ETAPA 5 (00:06–00:07): PAINEL DO PROFISSIONAL + R$ 0,00 + REPUTAÇÃO VERIFICADA
// =============================================================================

class _Story5FairProviderPanelDemo extends StatelessWidget {
  const _Story5FairProviderPanelDemo({
    required this.actAnimation,
    required this.isCompact,
    required this.isUltraCompact,
  });

  final Animation<double> actAnimation;
  final bool isCompact;
  final bool isUltraCompact;

  @override
  Widget build(BuildContext context) {
    final gap = isUltraCompact ? 7.0 : (isCompact ? 9.0 : 13.0);

    return AnimatedBuilder(
      animation: actAnimation,
      builder: (context, _) {
        final barProgress = Curves.easeOutQuart.transform(
          ((actAnimation.value - 0.26) / 0.56).clamp(0.0, 1.0),
        );
        final fillFactor = (0.36 + (0.64 * barProgress)).clamp(0.0, 1.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Painel do Profissional',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF0F172A),
                fontSize: isCompact ? 14.0 : 16.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: gap),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 11 : 15,
                  vertical: isUltraCompact ? 8.0 : (isCompact ? 10.0 : 13.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custo para orçar:',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF334155),
                        fontSize: isCompact ? 11.4 : 12.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'R\$ 0,00',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF0F172A),
                        fontSize: isUltraCompact
                            ? 20.0
                            : (isCompact ? 22.5 : 26.0),
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Valor do cliente já garantido antes de sair',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF334155),
                        fontSize: isCompact ? 11.4 : 12.6,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: gap),
            Text(
              'Reputação Verificada',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF0F172A),
                fontSize: isCompact ? 12.2 : 13.8,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: isUltraCompact ? 5.0 : 7.0),
            SizedBox(
              height: isCompact ? 8.0 : 9.5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0xFFE2E8F0)),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fillFactor,
                      heightFactor: 1.0,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF10B981),
                              Color(0xFF0D9488),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: isUltraCompact ? 6.0 : 8.0),
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 17,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '5,0 · Profissional Destaque',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF0F172A),
                      fontSize: isCompact ? 11.8 : 13.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// ETAPA 6 (00:08–00:09): CHAVE SELETORA DUPLA ESCULPIDA DE ALTÍSSIMO PADRÃO
// =============================================================================

class _Story6DualAccountSwitchDemo extends StatefulWidget {
  const _Story6DualAccountSwitchDemo({
    required this.actAnimation,
    required this.isCompact,
    required this.isUltraCompact,
    required this.onInteractivePointerDown,
  });

  final Animation<double> actAnimation;
  final bool isCompact;
  final bool isUltraCompact;
  final ValueChanged<int> onInteractivePointerDown;

  @override
  State<_Story6DualAccountSwitchDemo> createState() =>
      _Story6DualAccountSwitchDemoState();
}

class _Story6DualAccountSwitchDemoState
    extends State<_Story6DualAccountSwitchDemo>
    with SingleTickerProviderStateMixin {
  int? _manualSelectedMode; // null = segue coreografia; 0 = Cliente; 1 = Profissional
  late final AnimationController _manualSwitchController;
  double _manualFrom = 0.0;
  double _manualTo = 1.0;

  @override
  void initState() {
    super.initState();
    _manualSwitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _manualSwitchController.dispose();
    super.dispose();
  }

  double _autoChoreographedPosition(double t) {
    // 0.0s–1.35s (0.00..0.435): Modo Cliente (0.0)
    // 1.35s–2.45s (0.435..0.790): desliza suavemente para Modo Profissional (1.0)
    return Curves.easeOutQuart.transform(
      ((t - 0.435) / (0.790 - 0.435)).clamp(0.0, 1.0),
    );
  }

  double _currentCursorPosition() {
    if (_manualSelectedMode == null) {
      return _autoChoreographedPosition(widget.actAnimation.value);
    }
    final curved = Curves.easeOutQuart.transform(
      _manualSwitchController.value.clamp(0.0, 1.0),
    );
    return _manualFrom + ((_manualTo - _manualFrom) * curved);
  }

  void _handleSelectMode(int targetMode) {
    final currentPos = _currentCursorPosition();
    final targetPos = targetMode == 0 ? 0.0 : 1.0;
    HapticFeedback.selectionClick();
    setState(() {
      _manualSelectedMode = targetMode;
      _manualFrom = currentPos;
      _manualTo = targetPos;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _manualSwitchController.value = 1.0;
    } else {
      _manualSwitchController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = widget.isCompact;
    final isUltraCompact = widget.isUltraCompact;
    final gap = isUltraCompact ? 7.0 : (isCompact ? 9.5 : 13.0);

    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.actAnimation,
        _manualSwitchController,
      ]),
      builder: (context, _) {
        final cursorPos = _currentCursorPosition().clamp(0.0, 1.0);
        final isHarmonyResting = _manualSelectedMode == null &&
            widget.actAnimation.value >= 0.80;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Escolha Seu Perfil',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF0F172A),
                      fontSize: isCompact ? 14.0 : 16.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2F6),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 9 : 11,
                      vertical: 4,
                    ),
                    child: Text(
                      '1 toque',
                      maxLines: 1,
                      style: TextStyle(
                        color: const Color(0xFF0F172A),
                        fontSize: isCompact ? 10.6 : 11.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: gap),
            _LuxuryDualModeSegmentedSwitch(
              key: const Key('dual-mode-luxury-switch'),
              cursorPosition: cursorPos,
              showDualHarmonyGlow: isHarmonyResting,
              isCompact: isCompact,
              isUltraCompact: isUltraCompact,
              onInteractivePointerDown: widget.onInteractivePointerDown,
              onSelectMode: _handleSelectMode,
            ),
            SizedBox(height: gap),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 9 : 12,
                  vertical: isUltraCompact ? 6.0 : (isCompact ? 7.5 : 9.0),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: cursorPos < 0.5
                                ? const Color(0xFF1E3A8A)
                                : const Color(0xFF334155),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Contratar com garantia',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xFF0F172A),
                                fontSize: isCompact ? 10.3 : 11.4,
                                fontWeight: cursorPos < 0.5 || isHarmonyResting
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF94A3B8),
                        ),
                        child: SizedBox(width: 4, height: 4),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: cursorPos >= 0.5
                                ? const Color(0xFF047857)
                                : const Color(0xFF334155),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              'Atender sem pagar para orçar',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xFF0F172A),
                                fontSize: isCompact ? 10.3 : 11.4,
                                fontWeight: cursorPos >= 0.5 || isHarmonyResting
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: gap),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 12 : 16,
                    vertical: isUltraCompact ? 5.5 : (isCompact ? 6.5 : 8.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF047857),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Identidade Verificada',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF064E3B),
                            fontSize: isCompact ? 11.5 : 12.8,
                            fontWeight: FontWeight.w800,
                          ),
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
    );
  }
}

/// Chave Seletora Dupla Esculpida de Altíssimo Padrão (`Modo Cliente` <->
/// `Modo Profissional`): trilho acetinado rebaixado `#E8EEF5` + cursor pílula
/// flutuante com mola `Curves.easeOutQuart` e toque interativo direto.
class _LuxuryDualModeSegmentedSwitch extends StatelessWidget {
  const _LuxuryDualModeSegmentedSwitch({
    super.key,
    required this.cursorPosition,
    required this.showDualHarmonyGlow,
    required this.isCompact,
    required this.isUltraCompact,
    required this.onInteractivePointerDown,
    required this.onSelectMode,
  });

  final double cursorPosition;
  final bool showDualHarmonyGlow;
  final bool isCompact;
  final bool isUltraCompact;
  final ValueChanged<int> onInteractivePointerDown;
  final ValueChanged<int> onSelectMode;

  @override
  Widget build(BuildContext context) {
    final pos = cursorPosition.clamp(0.0, 1.0);
    final isClientActive = pos < 0.5;
    final isProviderActive = pos >= 0.5;
    final switchHeight = isUltraCompact ? 52.0 : (isCompact ? 52.0 : 54.0);

    final thumbStart = Color.lerp(
      const Color(0xFF1E3A8A),
      const Color(0xFF047857),
      pos,
    )!;
    final thumbEnd = Color.lerp(
      const Color(0xFF1D4ED8),
      const Color(0xFF0F766E),
      pos,
    )!;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => onInteractivePointerDown(event.pointer),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE8EEF5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFCBD5E1),
            width: 1.15,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: SizedBox(
            height: switchHeight - 8.0,
            child: Stack(
              children: [
                // Destaque porcelana secundário no modo complementar durante o repouso
                if (showDualHarmonyGlow)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.49,
                      heightFactor: 1.0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ),
                // Cursor pílula flutuante esculpido
                Align(
                  alignment: Alignment((pos * 2.0) - 1.0, 0.0),
                  child: FractionallySizedBox(
                    widthFactor: 0.50,
                    heightFactor: 1.0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [thumbStart, thumbEnd],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: thumbStart.withValues(alpha: 0.30),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Opções interativas de toque direto
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        key: const Key('dual-mode-option-client'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelectMode(0),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 6 : 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.home_rounded,
                                size: isCompact ? 15 : 17,
                                color: isClientActive
                                    ? const Color(0xFFFFFFFF)
                                    : const Color(0xFF1E3A8A),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Modo Cliente',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isClientActive
                                        ? const Color(0xFFFFFFFF)
                                        : const Color(0xFF0F172A),
                                    fontSize: isUltraCompact
                                        ? 10.6
                                        : (isCompact ? 11.2 : 12.5),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        key: const Key('dual-mode-option-provider'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelectMode(1),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 6 : 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.handyman_rounded,
                                size: isCompact ? 14 : 16,
                                color: isProviderActive
                                    ? const Color(0xFFFFFFFF)
                                    : const Color(0xFF047857),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Modo Profissional',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isProviderActive
                                        ? const Color(0xFFFFFFFF)
                                        : const Color(0xFF0F172A),
                                    fontSize: isUltraCompact
                                        ? 10.6
                                        : (isCompact ? 11.2 : 12.5),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

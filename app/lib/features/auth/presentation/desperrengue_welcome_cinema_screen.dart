import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/category_brand_emblem.dart';
import '../../../core/ui/desperrengue_brand_logo.dart';

/// Vitrine interativa pós-cadastro de 6 Stories a 120 FPS (v2.25.0).
///
/// Arquitetura de performance e serenidade visual:
/// - **Ritmo sereno (`10,5s` por Story, `63000ms` total)**: leitura calma com
///   3 Atos finitos (`0.0s–0.75s` entrada em cascata, `0.75s–3.10s` uma única
///   micro-demonstração viva, `3.10s–10.5s` repouso sereno absoluto sem loops).
/// - **Isolamento estrito 120Hz**: `_storyProgressController` notifica
///   exclusivamente `_TopSegmentedProgressBars` em `RepaintBoundary`, garantindo
///   `buildCount == 1` em [WelcomeStoryHeroCard] durante o avanço do tempo.
/// - **Fundo vivo contínuo (`_SharedAmbientCanvas`)**: camada única persistente
///   em `RepaintBoundary` escutando apenas o `PageController`, com interpolação
///   cromática contínua e paralaxe radial de 15%.
/// - **Gestos de latência zero (`Listener` + `PageView`)**: pausa no exato `0ms`
///   em `onPointerDown`, selo `Pausado` após `220ms` via `Timer` compatível com
///   `FakeAsync`, zonas de toque `32%` (voltar/reiniciar) e `68%` (avançar) sem
///   disputa na `GestureArena`, e alvos táteis `>= 44x44dp`.
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

/// Card herói dedicado de cada Story, com isolamento de rebuilds a 120 FPS.
///
/// Dispara [onActiveHeroBuild] apenas quando [isActiveStory] é verdadeiro.
/// Todas as micro-animações internas operam em sub-widgets folhas para que
/// [build] execute estritamente 1 única vez enquanto a barra de progresso corre.
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

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isCompact ? 20 : 24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF172030),
              Color(0xFF131B29),
              Color(0xFF0F1622),
            ],
          ),
          border: Border.all(
            color: Color.alphaBlend(
              accentColor.withValues(alpha: 0.28),
              const Color(0xFF263349),
            ),
            width: 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isCompact ? 20 : 24),
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 14 : 20),
            child: child,
          ),
        ),
      ),
    );
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
    _activePointerId = null;
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

    if (!wasDragging && !wasHoldPause) {
      if (event.localPosition.dx < _stageWidth * 0.32) {
        _handlePreviousAction();
      } else {
        _handleNextAction(fromStageTap: true);
      }
      return;
    }

    // Retoma suavemente de onde parou se seguiu na mesma página (hold-pause ou micro-arraste)
    _resumeTimelineIfSettled();
  }

  void _handleStagePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointerId) return;
    _activePointerId = null;
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

  String get _cleanFirstName {
    final trimmed = widget.userFirstName.trim();
    if (trimmed.isEmpty ||
        trimmed.toLowerCase() == 'você' ||
        trimmed.toLowerCase() == 'usuário') {
      return '';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isReplay,
      child: AppScaffold(
        backgroundColor: const Color(0xFF0C111C),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _SharedAmbientCanvas(pageController: _pageController),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScale =
                      MediaQuery.textScalerOf(context).scale(10.0) / 10.0;
                  final isCompact = constraints.maxHeight < 700 ||
                      constraints.maxWidth < 360 ||
                      textScale > 1.22;
                  final horizontalPad = isCompact ? 12.0 : 20.0;

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPad,
                      isCompact ? 4.0 : 8.0,
                      horizontalPad,
                      isCompact ? 6.0 : 12.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopSegmentedProgressBars(
                          storyProgressController: _storyProgressController,
                          activeStoryListenable: _activeStoryNotifier,
                          onTapChapter: (index) => _jumpToStoryImmediate(index),
                        ),
                        _TopBrandHeaderRow(
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
                                            userFirstName: _cleanFirstName,
                                            totalDuration: widget.totalDuration,
                                            isCompact: isCompact,
                                            pageController: _pageController,
                                            holdPausedListenable:
                                                _isHoldPausedNotifier,
                                            restartEpochListenable: index == 0
                                                ? _storyZeroRestartEpoch
                                                : null,
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
                        SizedBox(height: isCompact ? 4.0 : 8.0),
                        _BottomStoryNavigationBar(
                          activeStoryListenable: _activeStoryNotifier,
                          isCompact: isCompact,
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
// PALETA E ESPECIFICAÇÃO EDITORIAL DOS 6 STORIES (WCAG AA >= 4.5:1)
// =============================================================================

class _StoryVisualSpec {
  const _StoryVisualSpec({
    required this.legacyKey,
    required this.bgTop,
    required this.bgBottom,
    required this.primaryOrb,
    required this.secondaryOrb,
    required this.accent,
    required this.tagBg,
    required this.tagText,
  });

  final Key legacyKey;
  final Color bgTop;
  final Color bgBottom;
  final Color primaryOrb;
  final Color secondaryOrb;
  final Color accent;
  final Color tagBg;
  final Color tagText;
}

const List<_StoryVisualSpec> _kStorySpecs = <_StoryVisualSpec>[
  // Story 1: Casa Resolvida Sem Dor de Cabeça
  _StoryVisualSpec(
    legacyKey: Key('cinema-act-1-mission'),
    bgTop: Color(0xFF0E1320),
    bgBottom: Color(0xFF090D16),
    primaryOrb: Color(0xFFE87A3D),
    secondaryOrb: Color(0xFF38BDF8),
    accent: Color(0xFFFF9B5E),
    tagBg: Color(0xFF281C15),
    tagText: Color(0xFFFFBC94),
  ),
  // Story 2: Privacidade Total ao Pedir
  _StoryVisualSpec(
    legacyKey: Key('cinema-story-2-client-voice'),
    bgTop: Color(0xFF0B151E),
    bgBottom: Color(0xFF081018),
    primaryOrb: Color(0xFF2DD4BF),
    secondaryOrb: Color(0xFF60A5FA),
    accent: Color(0xFF5EEAD4),
    tagBg: Color(0xFF122826),
    tagText: Color(0xFF86EFAC),
  ),
  // Story 3: Seu Dinheiro 100% Protegido
  _StoryVisualSpec(
    legacyKey: Key('cinema-act-3-client'),
    bgTop: Color(0xFF0B1618),
    bgBottom: Color(0xFF081014),
    primaryOrb: Color(0xFF34D399),
    secondaryOrb: Color(0xFF38BDF8),
    accent: Color(0xFF6EE7B7),
    tagBg: Color(0xFF122923),
    tagText: Color(0xFF86EFAC),
  ),
  // Story 4: Sua Casa Mais Valorizada
  _StoryVisualSpec(
    legacyKey: Key('cinema-story-4-passport'),
    bgTop: Color(0xFF101522),
    bgBottom: Color(0xFF0A0E18),
    primaryOrb: Color(0xFFF5B74F),
    secondaryOrb: Color(0xFF60A5FA),
    accent: Color(0xFFFCD34D),
    tagBg: Color(0xFF272114),
    tagText: Color(0xFFFDE68A),
  ),
  // Story 5: Justo para Quem Trabalha
  _StoryVisualSpec(
    legacyKey: Key('cinema-act-4-provider'),
    bgTop: Color(0xFF0C1526),
    bgBottom: Color(0xFF080E1A),
    primaryOrb: Color(0xFF60A5FA),
    secondaryOrb: Color(0xFF34D399),
    accent: Color(0xFF93C5FD),
    tagBg: Color(0xFF152338),
    tagText: Color(0xFFBFDBFE),
  ),
  // Story 6: Uma Conta, Dois Caminhos
  _StoryVisualSpec(
    legacyKey: Key('cinema-act-2-audience'),
    bgTop: Color(0xFF101422),
    bgBottom: Color(0xFF090D18),
    primaryOrb: Color(0xFFFF8F52),
    secondaryOrb: Color(0xFF74A7FF),
    accent: Color(0xFFFFB07A),
    tagBg: Color(0xFF261D19),
    tagText: Color(0xFFFFC8A3),
  ),
];

// =============================================================================
// FUNDO VIVO CONTÍNUO (_SharedAmbientCanvas) — ESCUTA APENAS O PageController
// =============================================================================

class _SharedAmbientCanvas extends StatelessWidget {
  const _SharedAmbientCanvas({required this.pageController});

  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SharedAmbientPainter(pageController: pageController),
      ),
    );
  }
}

class _SharedAmbientPainter extends CustomPainter {
  _SharedAmbientPainter({required this.pageController})
      : super(repaint: pageController);

  final PageController pageController;

  double _resolveFractionalPage() {
    if (!pageController.hasClients) return 0.0;
    try {
      final position = pageController.position;
      if (!position.hasContentDimensions || !position.hasPixels) {
        return pageController.initialPage.toDouble();
      }
      return (pageController.page ?? pageController.initialPage.toDouble())
          .clamp(0.0, (_kStorySpecs.length - 1).toDouble());
    } catch (_) {
      return 0.0;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final page = _resolveFractionalPage();
    final lower = page.floor().clamp(0, _kStorySpecs.length - 1);
    final upper = page.ceil().clamp(0, _kStorySpecs.length - 1);
    final frac = (page - lower).clamp(0.0, 1.0);

    final a = _kStorySpecs[lower];
    final b = _kStorySpecs[upper];

    final bgTop = Color.lerp(a.bgTop, b.bgTop, frac)!;
    final bgBottom = Color.lerp(a.bgBottom, b.bgBottom, frac)!;
    final primaryOrb = Color.lerp(a.primaryOrb, b.primaryOrb, frac)!;
    final secondaryOrb = Color.lerp(a.secondaryOrb, b.secondaryOrb, frac)!;

    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [bgTop, bgBottom],
        ),
    );

    // Paralaxe sutil de exatos 15% da velocidade do swipe horizontal
    final parallaxShift = page * size.width * 0.15;

    final topGlowCenter = Offset(
      (size.width * 0.86) - parallaxShift,
      size.height * 0.20,
    );
    final topRadius = size.width * 0.78;
    canvas.drawCircle(
      topGlowCenter,
      topRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          topGlowCenter,
          topRadius,
          [
            primaryOrb.withValues(alpha: 0.16),
            primaryOrb.withValues(alpha: 0.04),
            Colors.transparent,
          ],
          const [0.0, 0.55, 1.0],
        ),
    );

    final bottomGlowCenter = Offset(
      (size.width * 0.14) + parallaxShift,
      size.height * 0.78,
    );
    final bottomRadius = size.width * 0.72;
    canvas.drawCircle(
      bottomGlowCenter,
      bottomRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          bottomGlowCenter,
          bottomRadius,
          [
            secondaryOrb.withValues(alpha: 0.12),
            secondaryOrb.withValues(alpha: 0.03),
            Colors.transparent,
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _SharedAmbientPainter oldDelegate) {
    return oldDelegate.pageController != pageController;
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
// TOPO ISOLADO EM REPAINTBOUNDARY: 6 BARRAS INTERATIVAS >= 44dp + MARCA/PULAR
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
                                  color: Colors.white.withValues(
                                    alpha: i == activeStory ? 0.24 : 0.16,
                                  ),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: fill,
                                    heightFactor: 1.0,
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Color(0xFFF1F5F9),
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

class _TopBrandHeaderRow extends StatelessWidget {
  const _TopBrandHeaderRow({
    required this.isReplay,
    required this.isCompact,
    required this.holdPausedListenable,
    required this.onExitPressed,
  });

  final bool isReplay;
  final bool isCompact;
  final ValueListenable<bool> holdPausedListenable;
  final VoidCallback onExitPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44.0),
      child: Row(
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
                      color: Color(0xFFF1F5F9),
                      fontSize: 13.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
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
          const SizedBox(width: 6),
          TextButton(
            key: Key(
              isReplay
                  ? 'btn-close-replay-cinema'
                  : 'btn-skip-welcome-cinema',
            ),
            onPressed: onExitPressed,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE2E8F0),
              backgroundColor: const Color(0xFF1B2434),
              minimumSize: const Size(52, 44),
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 12 : 14,
                vertical: 8,
              ),
              tapTargetSize: MaterialTapTargetSize.padded,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99),
                side: const BorderSide(color: Color(0xFF2D3B52)),
              ),
            ),
            child: Text(
              isReplay ? 'Fechar' : 'Pular',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFF1F5F9),
                fontSize: isCompact ? 12.0 : 12.5,
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
          color: const Color(0xFF232F44),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0xFF3A4B69)),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pause_rounded,
                size: 12,
                color: Color(0xFFE2E8F0),
              ),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Pausado',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFF1F5F9),
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
// RODAPÉ LIMPO E RESPIRÁVEL (>= 48dp DE ALTURA DE TOQUE)
// =============================================================================

class _BottomStoryNavigationBar extends StatelessWidget {
  const _BottomStoryNavigationBar({
    required this.activeStoryListenable,
    required this.isCompact,
    required this.onPrevious,
    required this.onNext,
  });

  final ValueListenable<int> activeStoryListenable;
  final bool isCompact;
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

        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: IgnorePointer(
                  ignoring: isFirst,
                  child: AnimatedOpacity(
                    opacity: isFirst ? 0.0 : 1.0,
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: TextButton.icon(
                      key: const Key('btn-story-prev'),
                      onPressed: onPrevious,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFE2E8F0),
                        backgroundColor: const Color(0xFF172030),
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 10 : 14,
                          vertical: 10,
                        ),
                        tapTargetSize: MaterialTapTargetSize.padded,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99),
                          side: const BorderSide(color: Color(0xFF2A384E)),
                        ),
                      ),
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        size: 18,
                        color: Color(0xFFE2E8F0),
                      ),
                      label: Text(
                        'Voltar',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFF1F5F9),
                          fontSize: isCompact ? 12.0 : 13.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${storyIndex + 1} de $total',
                maxLines: 1,
                style: TextStyle(
                  color: const Color(0xFFAEC0D6),
                  fontSize: isCompact ? 11.5 : 12.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: isLast ? 2 : 1,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const Key('btn-story-next'),
                    onPressed: onNext,
                    style: TextButton.styleFrom(
                      foregroundColor: isLast
                          ? const Color(0xFF0B111E)
                          : const Color(0xFFF1F5F9),
                      backgroundColor: isLast
                          ? const Color(0xFFFF9E57)
                          : const Color(0xFF1E2A3D),
                      minimumSize: const Size(56, 48),
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 14 : 18,
                        vertical: 10,
                      ),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99),
                        side: BorderSide(
                          color: isLast
                              ? const Color(0xFFFFB880)
                              : const Color(0xFF33445E),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            isLast ? 'Começar agora' : 'Próximo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isLast
                                  ? const Color(0xFF0B111E)
                                  : const Color(0xFFF1F5F9),
                              fontSize: isCompact ? 12.5 : 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isLast
                              ? Icons.arrow_forward_rounded
                              : Icons.chevron_right_rounded,
                          size: 18,
                          color: isLast
                              ? const Color(0xFF0B111E)
                              : const Color(0xFFF1F5F9),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// PÁGINA DO STORY COM COREOGRAFIA FINITA EM 3 ATOS (ZERO REPEAT, >= 38% RESPIRO)
// =============================================================================

class _StorySlidePage extends StatefulWidget {
  const _StorySlidePage({
    super.key,
    required this.storyIndex,
    required this.isActiveStory,
    required this.userFirstName,
    required this.totalDuration,
    required this.isCompact,
    required this.pageController,
    required this.holdPausedListenable,
    this.restartEpochListenable,
    this.onActiveHeroBuild,
  });

  final int storyIndex;
  final bool isActiveStory;
  final String userFirstName;
  final Duration totalDuration;
  final bool isCompact;
  final PageController pageController;
  final ValueListenable<bool> holdPausedListenable;
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

  (String, String, String) _copyForStory(int index) {
    switch (index) {
      case 0:
        final greeting = widget.userFirstName.isNotEmpty
            ? 'BEM-VINDO(A), ${widget.userFirstName.toUpperCase()}'
            : 'BEM-VINDO(A)';
        return (
          greeting,
          'Sua casa resolvida sem dor de cabeça',
          'Do reparo urgente à manutenção planejada, encontre o especialista certo perto de você em poucos toques.',
        );
      case 1:
        return (
          'SEGURANÇA DA SUA CASA',
          'Privacidade total antes de contratar',
          'Explique por áudio ou foto e compare até 3 orçamentos claros. Seu endereço completo fica oculto até você escolher quem contratar.',
        );
      case 2:
        return (
          'PAGAMENTO PROTEGIDO',
          'Seu dinheiro 100% protegido sempre',
          'O valor fica guardado na plataforma. O profissional só recebe quando o serviço termina e você confirma com seu código pessoal.',
        );
      case 3:
        return (
          'HISTÓRICO INTELIGENTE',
          'Sua casa mais valorizada',
          'Cada manutenção concluída fica registrada automaticamente no histórico do seu imóvel, pronto em PDF para aluguéis, seguros ou venda.',
        );
      case 4:
        return (
          'MODO PROFISSIONAL',
          'Justo para quem trabalha',
          'Sem pagar taxas para enviar orçamento. Receba 100% do valor das peças sem desconto e construa sua reputação na cidade.',
        );
      default:
        return (
          'LIBERDADE EM 1 TOQUE',
          'Uma conta, dois caminhos',
          'Contrate serviços para sua casa ou atenda clientes na sua área usando uma única conta verificada com identidade segura.',
        );
    }
  }

  Widget _buildHeroDemoContent(int index, bool isCompact) {
    switch (index) {
      case 0:
        return _Story1SearchAndSpecialtiesDemo(
          actAnimation: _actController,
          isCompact: isCompact,
        );
      case 1:
        return _Story2PrivacyAndQuotesDemo(
          actAnimation: _actController,
          isCompact: isCompact,
        );
      case 2:
        return _Story3ProtectedVaultPinDemo(
          actAnimation: _actController,
          isCompact: isCompact,
        );
      case 3:
        return _Story4PropertyHealthHistoryDemo(
          actAnimation: _actController,
          isCompact: isCompact,
        );
      case 4:
        return _Story5FairProviderPanelDemo(
          actAnimation: _actController,
          isCompact: isCompact,
        );
      default:
        return _Story6DualAccountSwitchDemo(
          actAnimation: _actController,
          isCompact: isCompact,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _kStorySpecs[widget.storyIndex];
    final (tagText, titleText, subtitleText) = _copyForStory(widget.storyIndex);
    final isCompact = widget.isCompact;

    // Ato 1 (0.0s – 0.75s = 0.00 .. 0.242 de 3.10s): cascata sedosa sem quique
    final tagFade = Tween<double>(begin: 0.35, end: 1.0).animate(
      _interval(0.00, 0.12),
    );
    final tagSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(_interval(0.00, 0.12));

    final titleFade = Tween<double>(begin: 0.35, end: 1.0).animate(
      _interval(0.03, 0.16),
    );
    final titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(_interval(0.03, 0.16));

    final subFade = Tween<double>(begin: 0.35, end: 1.0).animate(
      _interval(0.06, 0.20),
    );
    final subSlide = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(_interval(0.06, 0.20));

    final heroOpacity = Tween<double>(begin: 0.32, end: 1.0).animate(
      _interval(0.07, 0.242),
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
      child: _buildHeroDemoContent(widget.storyIndex, isCompact),
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
              parallaxX = (p - widget.storyIndex).clamp(-1.0, 1.0) * 18.0;
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
                  const Spacer(flex: 5),
                  FadeTransition(
                    opacity: tagFade,
                    child: SlideTransition(
                      position: tagSlide,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: spec.tagBg,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: spec.accent.withValues(alpha: 0.36),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 10 : 12,
                            vertical: isCompact ? 4 : 5.5,
                          ),
                          child: Text(
                            tagText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: spec.tagText,
                              fontSize: isCompact ? 10.2 : 11.2,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isCompact ? 8 : 14),
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
                          fontSize: isCompact ? 20.5 : 27.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isCompact ? 6 : 10),
                  FadeTransition(
                    opacity: subFade,
                    child: SlideTransition(
                      position: subSlide,
                      child: Text(
                        subtitleText,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFCBD5E1),
                          fontSize: isCompact ? 12.5 : 14.8,
                          fontWeight: FontWeight.w400,
                          height: 1.38,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isCompact ? 14 : 24),
                  animatedHero,
                  const Spacer(flex: 6),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// MICRO-DEMONSTRAÇÕES VIVAS EM SUB-WIDGETS FOLHAS (ATO 2: 0.75s–3.10s -> REPOUSO)
// =============================================================================

/// Story 1/6: Barra de busca preenchendo `"Trocar resistência do chuveiro"`
/// (`0.8s–1.8s`) + 3 chips `CategoryBrandEmblem` (`Elétrica`, `Encanador`,
/// `Ar-condicionado`) + selo calmo `Atendimento rápido na sua região`.
class _Story1SearchAndSpecialtiesDemo extends StatelessWidget {
  const _Story1SearchAndSpecialtiesDemo({
    required this.actAnimation,
    required this.isCompact,
  });

  final Animation<double> actAnimation;
  final bool isCompact;

  static const String _kFullQuery = 'Trocar resistência do chuveiro';
  static const List<String> _kSpecialties = <String>[
    'Elétrica',
    'Encanador',
    'Ar-condicionado',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Story1SearchFieldLeaf(
          actAnimation: actAnimation,
          fullQuery: _kFullQuery,
          isCompact: isCompact,
        ),
        SizedBox(height: isCompact ? 10 : 14),
        _Story1SpecialtiesEmergenceLeaf(
          actAnimation: actAnimation,
          specialties: _kSpecialties,
          isCompact: isCompact,
        ),
        SizedBox(height: isCompact ? 10 : 14),
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
  });

  final Animation<double> actAnimation;
  final String fullQuery;
  final bool isCompact;

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
        final minChars = 7;
        final visibleCount = (minChars +
                ((fullQuery.length - minChars) * progress).round())
            .clamp(minChars, fullQuery.length);
        final visibleText = fullQuery.substring(0, visibleCount);
        final isFinished = visibleCount >= fullQuery.length;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF1C273A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isFinished
                  ? const Color(0xFFFF9B5E).withValues(alpha: 0.48)
                  : const Color(0xFF2D3C56),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 11 : 14,
              vertical: isCompact ? 9 : 11,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Color(0xFFFFB07A),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    visibleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFF1F5F9),
                      fontSize: isCompact ? 12.2 : 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isFinished) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: Color(0xFF6EE7B7),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Story1SpecialtiesEmergenceLeaf extends StatelessWidget {
  const _Story1SpecialtiesEmergenceLeaf({
    required this.actAnimation,
    required this.specialties,
    required this.isCompact,
  });

  final Animation<double> actAnimation;
  final List<String> specialties;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: actAnimation,
      builder: (context, _) {
        return Wrap(
          spacing: isCompact ? 6 : 8,
          runSpacing: isCompact ? 6 : 8,
          children: List.generate(specialties.length, (i) {
            final start = 0.42 + (i * 0.09);
            final end = (start + 0.24).clamp(0.0, 1.0);
            final p = Curves.easeOutQuart.transform(
              ((actAnimation.value - start) / (end - start)).clamp(0.0, 1.0),
            );
            final name = specialties[i];

            return Opacity(
              opacity: (0.28 + (0.72 * p)).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1.0 - p) * 8.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2537),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: i == 0
                          ? const Color(0xFFFF9B5E).withValues(alpha: 0.48)
                          : const Color(0xFF2C3B54),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 8 : 10,
                      vertical: isCompact ? 5.5 : 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CategoryBrandEmblem(
                          categoryName: name,
                          size: isCompact ? 22 : 26,
                          showCornerBadge: false,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFFF1F5F9),
                              fontSize: isCompact ? 11.5 : 12.5,
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
          }),
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
          opacity: (0.35 + (0.65 * p)).clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF132923),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: const Color(0xFF34D399).withValues(alpha: 0.36),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 10 : 12,
                vertical: isCompact ? 6.5 : 8,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    size: 15,
                    color: Color(0xFF6EE7B7),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Atendimento rápido na sua região',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFD1FAE5),
                        fontSize: isCompact ? 11.2 : 12.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Story 2/6: Linha de endereço transicionando (`0.9s–1.8s`) para escudo
/// `🔒 Rua e número protegidos` + 3 propostas comparativas com destaque suave
/// de seleção aos `2.2s`.
class _Story2PrivacyAndQuotesDemo extends StatelessWidget {
  const _Story2PrivacyAndQuotesDemo({
    required this.actAnimation,
    required this.isCompact,
  });

  final Animation<double> actAnimation;
  final bool isCompact;

  static const List<(String, String, String)> _kProposals =
      <(String, String, String)>[
    ('Ricardo M.', '★ 5,0', 'R\$ 160'),
    ('Carlos A.', '★ 4,9', 'R\$ 175'),
    ('André S.', '★ 4,9', 'R\$ 190'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Story2AddressShieldLeaf(
          actAnimation: actAnimation,
          isCompact: isCompact,
        ),
        SizedBox(height: isCompact ? 10 : 14),
        _Story2ProposalsListLeaf(
          actAnimation: actAnimation,
          proposals: _kProposals,
          isCompact: isCompact,
        ),
      ],
    );
  }
}

class _Story2AddressShieldLeaf extends StatelessWidget {
  const _Story2AddressShieldLeaf({
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
        // 0.9s..1.8s de 3.10s -> [0.290 .. 0.581]
        final shieldProgress = Curves.easeOutQuart.transform(
          ((actAnimation.value - 0.290) / (0.581 - 0.290)).clamp(0.0, 1.0),
        );
        final shielded = shieldProgress >= 0.45;
        final bg = Color.lerp(
          const Color(0xFF1B2638),
          const Color(0xFF132B24),
          shieldProgress,
        )!;
        final border = Color.lerp(
          const Color(0xFF2D3C54),
          const Color(0xFF34D399).withValues(alpha: 0.48),
          shieldProgress,
        )!;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 13,
              vertical: isCompact ? 8 : 10,
            ),
            child: Row(
              children: [
                Icon(
                  shielded ? Icons.shield_rounded : Icons.place_outlined,
                  size: 16,
                  color: shielded
                      ? const Color(0xFF6EE7B7)
                      : const Color(0xFFAEC0D6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shielded
                        ? '🔒 Rua e número protegidos'
                        : 'Sua região · Ocultando endereço...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: shielded
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFE2E8F0),
                      fontSize: isCompact ? 11.8 : 13.0,
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
  });

  final Animation<double> actAnimation;
  final List<(String, String, String)> proposals;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: actAnimation,
      builder: (context, _) {
        // Destaque suave da escolha ideal aos 2.2s (0.710 de 3.10s)
        final selectProgress = Curves.easeOutQuart.transform(
          ((actAnimation.value - 0.66) / 0.24).clamp(0.0, 1.0),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(proposals.length, (i) {
            final item = proposals[i];
            final isBest = i == 0;
            final highlight = isBest ? selectProgress : 0.0;

            return Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : (isCompact ? 6 : 8)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.lerp(
                    const Color(0xFF1A2435),
                    const Color(0xFF152D29),
                    highlight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color.lerp(
                      const Color(0xFF2A384F),
                      const Color(0xFF5EEAD4).withValues(alpha: 0.62),
                      highlight,
                    )!,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 10 : 12,
                    vertical: isCompact ? 7.5 : 9.5,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isBest && highlight > 0.5
                            ? Icons.check_circle_rounded
                            : Icons.person_outline_rounded,
                        size: 16,
                        color: isBest && highlight > 0.5
                            ? const Color(0xFF6EE7B7)
                            : const Color(0xFFAEC0D6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFFF1F5F9),
                            fontSize: isCompact ? 11.8 : 13.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.$2,
                        maxLines: 1,
                        style: TextStyle(
                          color: const Color(0xFFFCD34D),
                          fontSize: isCompact ? 11.2 : 12.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        item.$3,
                        maxLines: 1,
                        style: TextStyle(
                          color: isBest && highlight > 0.5
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFE2E8F0),
                          fontSize: isCompact ? 12.0 : 13.2,
                          fontWeight: FontWeight.w800,
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

/// Story 3/6: Cofre `R$ 180,00 · Guardado com segurança` + 4 dígitos do código
/// pessoal acendendo um a um (`1.0s–2.4s`: `•` -> `4` · `8` · `2` · `9`) +
/// selo sereno `✓ Serviço aprovado · 90 dias de garantia`.
class _Story3ProtectedVaultPinDemo extends StatelessWidget {
  const _Story3ProtectedVaultPinDemo({
    required this.actAnimation,
    required this.isCompact,
  });

  final Animation<double> actAnimation;
  final bool isCompact;

  static const List<String> _kPinDigits = <String>['4', '8', '2', '9'];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: actAnimation,
      builder: (context, _) {
        final t = actAnimation.value;
        // 2.4s..2.95s -> [0.774 .. 0.95] aprovação final serena
        final approvedProgress = Curves.easeOutQuart.transform(
          ((t - 0.76) / 0.20).clamp(0.0, 1.0),
        );
        final isApproved = approvedProgress >= 0.5;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(
                  const Color(0xFF1A2536),
                  const Color(0xFF132B23),
                  approvedProgress,
                ),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: Color.lerp(
                    const Color(0xFF2B3B54),
                    const Color(0xFF34D399).withValues(alpha: 0.52),
                    approvedProgress,
                  )!,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 10 : 13,
                  vertical: isCompact ? 8 : 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isApproved
                              ? Icons.verified_user_rounded
                              : Icons.lock_outline_rounded,
                          size: 16,
                          color: const Color(0xFF6EE7B7),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'R\$ 180,00 · Guardado com segurança',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFFF1F5F9),
                              fontSize: isCompact ? 12.0 : 13.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isApproved) ...[
                      SizedBox(height: isCompact ? 4 : 6),
                      Text(
                        '✓ Serviço aprovado · 90 dias de garantia',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF86EFAC),
                          fontSize: isCompact ? 11.2 : 12.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: isCompact ? 12 : 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_kPinDigits.length, (i) {
                // Entre 1.0s (0.323) e 2.4s (0.774), acende 1 a 1 com calma
                final digitThreshold = 0.34 + (i * 0.115);
                final litProgress = Curves.easeOutQuart.transform(
                  ((t - digitThreshold) / 0.12).clamp(0.0, 1.0),
                );
                final isLit = litProgress >= 0.45;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 4,
                      right: i == _kPinDigits.length - 1 ? 0 : 4,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          const Color(0xFF1A2334),
                          const Color(0xFF152C26),
                          litProgress,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color.lerp(
                            const Color(0xFF2B3950),
                            const Color(0xFF6EE7B7).withValues(alpha: 0.58),
                            litProgress,
                          )!,
                        ),
                      ),
                      child: SizedBox(
                        height: isCompact ? 42 : 48,
                        child: Center(
                          child: Text(
                            isLit ? _kPinDigits[i] : '•',
                            style: TextStyle(
                              color: isLit
                                  ? const Color(0xFFF8FAFC)
                                  : const Color(0xFFA8B6C8),
                              fontSize: isCompact ? 17.0 : 19.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

/// Story 4/6: Cartão `Saúde do Imóvel` com arco circular `SweepGradient` sem
/// costura deslizando até `96% · Em dia`, revelando 2 registros verificados
/// (`Revisão Elétrica` e `Climatização` com `Comprovante em PDF`).
class _Story4PropertyHealthHistoryDemo extends StatelessWidget {
  const _Story4PropertyHealthHistoryDemo({
    required this.actAnimation,
    required this.isCompact,
  });

  final Animation<double> actAnimation;
  final bool isCompact;

  static const List<String> _kRecords = <String>[
    'Revisão Elétrica',
    'Climatização',
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: actAnimation,
      builder: (context, _) {
        final arcProgress = Curves.easeOutQuart.transform(
          ((actAnimation.value - 0.24) / 0.58).clamp(0.0, 1.0),
        );
        final displayedPercent = (72 + (24 * arcProgress).round()).clamp(0, 96);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: isCompact ? 52 : 60,
                  height: isCompact ? 52 : 60,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _SeamlessHealthArcPainter(
                        progress: 0.96 * arcProgress,
                      ),
                      child: Center(
                        child: Text(
                          '$displayedPercent%',
                          style: TextStyle(
                            color: const Color(0xFFF8FAFC),
                            fontSize: isCompact ? 12.5 : 14.0,
                            fontWeight: FontWeight.w800,
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
                        'Saúde do Imóvel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFF8FAFC),
                          fontSize: isCompact ? 13.2 : 14.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$displayedPercent% · Em dia',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF86EFAC),
                          fontSize: isCompact ? 11.8 : 12.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isCompact ? 10 : 14),
            for (var i = 0; i < _kRecords.length; i++) ...[
              if (i > 0) SizedBox(height: isCompact ? 6 : 8),
              Opacity(
                opacity: (0.35 +
                        0.65 *
                            Curves.easeOutQuart.transform(
                              ((actAnimation.value - (0.45 + i * 0.14)) / 0.25)
                                  .clamp(0.0, 1.0),
                            ))
                    .clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2436),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2B3A52)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 10 : 12,
                      vertical: isCompact ? 7.5 : 9.5,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                          color: Color(0xFFFCD34D),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _kRecords[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFFF1F5F9),
                              fontSize: isCompact ? 11.8 : 13.0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Comprovante em PDF',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFFBFDBFE),
                              fontSize: isCompact ? 10.8 : 11.8,
                              fontWeight: FontWeight.w600,
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

class _SeamlessHealthArcPainter extends CustomPainter {
  const _SeamlessHealthArcPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 4.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2A3950);

    canvas.drawArc(
      rect,
      -math.pi * 0.75,
      math.pi * 1.5,
      false,
      trackPaint,
    );

    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= 0.001) return;

    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.2
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi * 1.5,
        colors: [
          Color(0xFFFCD34D),
          Color(0xFF34D399),
          Color(0xFF60A5FA),
        ],
        transform: GradientRotation(-math.pi * 0.75),
      ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi * 0.75,
      math.pi * 1.5 * clamped,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SeamlessHealthArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Story 5/6: Painel do Profissional com `Custo para orçar: R$ 0,00`,
/// `Valor do cliente já garantido antes de sair` e barra de reputação até
/// `★ 5,0 · Profissional Destaque`.
class _Story5FairProviderPanelDemo extends StatelessWidget {
  const _Story5FairProviderPanelDemo({
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
        final barProgress = Curves.easeOutQuart.transform(
          ((actAnimation.value - 0.28) / 0.56).clamp(0.0, 1.0),
        );
        final fillFactor = (0.35 + (0.65 * barProgress)).clamp(0.0, 1.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF132A23),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF34D399).withValues(alpha: 0.42),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 10 : 13,
                  vertical: isCompact ? 8 : 10,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: Color(0xFF6EE7B7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Custo para orçar: R\$ 0,00',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFD1FAE5),
                          fontSize: isCompact ? 12.0 : 13.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: isCompact ? 8 : 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF1A2538),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2C3C56)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 10 : 13,
                  vertical: isCompact ? 8 : 10,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: Color(0xFF93C5FD),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Valor do cliente já garantido antes de sair',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFE2E8F0),
                          fontSize: isCompact ? 11.5 : 12.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: isCompact ? 10 : 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '★ 5,0 · Profissional Destaque',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFFDE68A),
                      fontSize: isCompact ? 11.8 : 13.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isCompact ? 6 : 8),
            SizedBox(
              height: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0xFF233047)),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fillFactor,
                      heightFactor: 1.0,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF60A5FA),
                              Color(0xFF34D399),
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
        );
      },
    );
  }
}

/// Story 6/6: Seletor tátil realista (Segmented Pill) que desliza com mola
/// suave de `Modo Cliente` para `Modo Profissional` aos `1.4s` e volta aos
/// `2.4s` a exibir os dois perfis integrados sob o selo `Identidade Verificada`.
class _Story6DualAccountSwitchDemo extends StatelessWidget {
  const _Story6DualAccountSwitchDemo({
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
        final t = actAnimation.value;
        // Fase 1 (< 0.42): foco Modo Cliente
        // Fase 2 (0.42 .. 0.77, ~1.4s..2.4s): desliza para Modo Profissional
        // Fase 3 (>= 0.77, >= 2.4s): ambos os perfis integrados em repouso
        final toProvider = Curves.easeOutQuart.transform(
          ((t - 0.42) / 0.18).clamp(0.0, 1.0),
        );
        final toUnified = Curves.easeOutQuart.transform(
          ((t - 0.77) / 0.19).clamp(0.0, 1.0),
        );

        final clientEmphasis =
            ((1.0 - toProvider) + (toProvider * toUnified)).clamp(0.32, 1.0);
        final providerEmphasis = toProvider.clamp(0.32, 1.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF182233),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2B3A52)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Row(
                  children: [
                    Expanded(
                      child: _SegmentedRolePillOption(
                        icon: Icons.home_outlined,
                        label: 'Modo Cliente',
                        emphasis: clientEmphasis,
                        activeBg: const Color(0xFF2B2019),
                        activeBorder: const Color(0xFFFF9E57),
                        activeInk: const Color(0xFFFFC8A3),
                        isCompact: isCompact,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _SegmentedRolePillOption(
                        icon: Icons.handyman_outlined,
                        label: 'Modo Profissional',
                        emphasis: providerEmphasis,
                        activeBg: const Color(0xFF17273F),
                        activeBorder: const Color(0xFF74A7FF),
                        activeInk: const Color(0xFFBFDBFE),
                        isCompact: isCompact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: isCompact ? 10 : 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(
                  const Color(0xFF1A2436),
                  const Color(0xFF132A23),
                  toUnified,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color.lerp(
                    const Color(0xFF2C3B54),
                    const Color(0xFF34D399).withValues(alpha: 0.45),
                    toUnified,
                  )!,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 10 : 13,
                  vertical: isCompact ? 8 : 10,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 16,
                      color: Color(0xFF6EE7B7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Identidade Verificada',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFD1FAE5),
                          fontSize: isCompact ? 11.8 : 13.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '1 conta · 2 perfis',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFAEC0D6),
                          fontSize: isCompact ? 10.8 : 11.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SegmentedRolePillOption extends StatelessWidget {
  const _SegmentedRolePillOption({
    required this.icon,
    required this.label,
    required this.emphasis,
    required this.activeBg,
    required this.activeBorder,
    required this.activeInk,
    required this.isCompact,
  });

  final IconData icon;
  final String label;
  final double emphasis;
  final Color activeBg;
  final Color activeBorder;
  final Color activeInk;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final factor = ((emphasis - 0.32) / 0.68).clamp(0.0, 1.0);
    final bg = Color.lerp(
      const Color(0xFF182233),
      activeBg,
      factor,
    )!;
    final border = Color.lerp(
      Colors.transparent,
      activeBorder.withValues(alpha: 0.65),
      factor,
    )!;
    final textColor = Color.lerp(
      const Color(0xFFAEC0D6),
      const Color(0xFFF8FAFC),
      factor,
    )!;
    final iconColor = Color.lerp(
      const Color(0xFFAEC0D6),
      activeInk,
      factor,
    )!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 8 : 10,
          vertical: isCompact ? 9 : 11,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isCompact ? 14 : 16, color: iconColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: isCompact ? 11.0 : 12.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

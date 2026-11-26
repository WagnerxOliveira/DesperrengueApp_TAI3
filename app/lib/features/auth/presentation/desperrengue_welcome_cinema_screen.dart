import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/typography/cinema_type_scale.dart';
import '../../../core/ui/typography/font_licenses.dart';
import 'widgets/cinema_motion.dart';
import 'widgets/cinema_story_cards_a.dart';
import 'widgets/cinema_story_cards_b.dart';
import 'widgets/story_nav_circle_button.dart';

/// Apresentação interativa pós-cadastro em 6 etapas a 120 FPS (v2.27.0).
///
/// v2.27.0 — tipografia premium embarcada (Plus Jakarta Sans + Inter, escala
/// em `cinema_type_scale.dart`, fonte NUNCA reduzida por modo compacto),
/// botões `<` / `>` idênticos (`StoryNavCircleButton`), cards redesenhados
/// com `flutter_animate` + `lottie` somente em folhas, coluna central máx.
/// 480 e atalhos de teclado (←/→/Espaço/Esc) na Web.
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
    this.onClose,
    this.isReplay = false,
    this.totalDuration = const Duration(milliseconds: 63000),
    @visibleForTesting this.onActiveHeroBuild,
  });

  static const int storyCount = 6;

  final String userFirstName;
  final VoidCallback onCompleted;

  /// Callback opcional acionado pelo botão discreto de fechar (`×`).
  /// Quando omitido, encerra a apresentação pelo mesmo fluxo seguro de [onCompleted].
  final VoidCallback? onClose;
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

    final radius = BorderRadius.circular(CinemaGeometry.heroRadius);

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFFAFBFD), Color(0xFFF8FAFC)],
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
              padding: EdgeInsets.all(
                isCompact
                    ? CinemaGeometry.heroPaddingCompact
                    : CinemaGeometry.heroPadding,
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const int _kStoryCount = DesperrengueWelcomeCinemaScreen.storyCount;
  static const Duration _kHoldPauseDelay = Duration(milliseconds: 220);

  late final AnimationController _storyProgressController;
  late final PageController _pageController;

  final ValueNotifier<int> _activeStoryNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isHoldPausedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> _storyZeroRestartEpoch = ValueNotifier<int>(0);
  final GlobalKey _stageKey = GlobalKey(debugLabel: 'cinema-stage');

  bool _completedDispatched = false;
  bool _isProgrammaticPageJump = false;
  bool _lifecyclePaused = false;

  int? _activePointerId;
  int? _interactiveControlPointerId;
  Offset _pointerDownPosition = Offset.zero;
  Timer? _holdPauseTimer;
  bool _didHoldPause = false;
  bool _isDragging = false;
  int _settledPageAtPointerDown = 0;

  double get _stageWidth {
    final size = _stageKey.currentContext?.size;
    return math.max(1.0, size?.width ?? 360.0);
  }

  @override
  void initState() {
    super.initState();
    // Licenças OFL das fontes embarcadas (Plus Jakarta Sans e Inter): uma vez.
    registerCinemaFontLicenses();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: 0);
    _storyProgressController =
        AnimationController(
            vsync: this,
            duration: _safeTotalDuration(widget.totalDuration),
            animationBehavior: AnimationBehavior.preserve,
          )
          ..addListener(_onTimelineBoundaryCheck)
          ..addStatusListener(_onTimelineStatus);

    _storyProgressController.forward();
  }

  /// Pausa ao perder o foco da aba/app (Web: `visibilitychange`) e retoma ao
  /// voltar, sem mostrar o selo "Pausado" de gesto.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_completedDispatched) return;
    if (state == AppLifecycleState.resumed) {
      if (!_lifecyclePaused) return;
      _lifecyclePaused = false;
      if (_activePointerId == null) {
        if (_isHoldPausedNotifier.value) {
          _isHoldPausedNotifier.value = false;
        }
        _resumeTimelineIfSettled();
      }
    } else {
      if (_lifecyclePaused) return;
      _lifecyclePaused = true;
      _storyProgressController.stop(canceled: false);
      if (!_isHoldPausedNotifier.value) {
        _isHoldPausedNotifier.value = true;
      }
    }
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
          !_lifecyclePaused &&
          _activePointerId == null &&
          !_isHoldPausedNotifier.value &&
          _storyProgressController.value < 1.0) {
        _storyProgressController.forward();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    final computedStory = ((t * _kStoryCount) + 1e-9).floor().clamp(
      0,
      _kStoryCount - 1,
    );
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

  void _completeShowcase({bool viaCloseButton = false}) {
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
    if (viaCloseButton) {
      HapticFeedback.lightImpact();
      (widget.onClose ?? widget.onCompleted)();
    } else {
      HapticFeedback.mediumImpact();
      widget.onCompleted();
    }
  }

  void _jumpToStoryImmediate(
    int targetStory, {
    bool playSelectionHaptic = true,
  }) {
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

    final wasAlreadyStoryZero = clamped == 0 && _activeStoryNotifier.value == 0;

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

  void _handleNextAction({bool fromStageTap = false, bool playHaptic = true}) {
    if (_completedDispatched) return;
    final current = _activeStoryNotifier.value;
    if (current >= _kStoryCount - 1) {
      if (fromStageTap) {
        HapticFeedback.selectionClick();
      }
      _completeShowcase();
      return;
    }
    _jumpToStoryImmediate(current + 1, playSelectionHaptic: playHaptic);
  }

  void _handlePreviousAction({bool playHaptic = true}) {
    if (_completedDispatched) return;
    final current = _activeStoryNotifier.value;
    if (current <= 0) {
      _jumpToStoryImmediate(0, playSelectionHaptic: playHaptic);
      return;
    }
    _jumpToStoryImmediate(current - 1, playSelectionHaptic: playHaptic);
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
    final wasInteractiveControl = event.pointer == _interactiveControlPointerId;
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
        _lifecyclePaused ||
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
      _storyProgressController.value = (clamped / _kStoryCount).clamp(
        0.0,
        0.999999,
      );
    }
    if (_activePointerId == null &&
        !_isHoldPausedNotifier.value &&
        !_lifecyclePaused) {
      _storyProgressController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isReplay,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _handlePreviousAction(),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _handleNextAction(),
          const SingleActivator(LogicalKeyboardKey.space): () =>
              _handleNextAction(),
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              _completeShowcase(viaCloseButton: true),
        },
        child: Focus(
          autofocus: true,
          debugLabel: 'welcome-cinema-keyboard',
          child: AppScaffold(
            backgroundColor: const Color(0xFF0D1B20),
            // Palco com escala de fonte limitada a 1.0–1.5: a fonte nunca
            // encolhe; o excesso vira reflow e rolagem interna do card.
            body: MediaQuery.withClampedTextScaling(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _SharedAmbientCanvas(
                    pageController: _pageController,
                    activeStoryListenable: _activeStoryNotifier,
                    isProgrammaticJumpGetter: () => _isProgrammaticPageJump,
                  ),
                  SafeArea(child: _buildStageColumn()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageColumn() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Apenas espaçamentos mudam no modo compacto; a fonte NUNCA encolhe.
        final isCompact =
            constraints.maxHeight < 720 || constraints.maxWidth < 365;
        final horizontalPad = isCompact ? CinemaSpace.s16 : CinemaSpace.s20;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            isCompact ? CinemaSpace.s4 : CinemaSpace.s8,
            horizontalPad,
            isCompact ? CinemaSpace.s8 : CinemaSpace.s12,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: CinemaGeometry.maxColumnWidth,
                minHeight: constraints.maxHeight,
                maxHeight: constraints.maxHeight,
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
                    holdPausedListenable: _isHoldPausedNotifier,
                    onSkipPressed: () => _completeShowcase(),
                    onClosePressed: () =>
                        _completeShowcase(viaCloseButton: true),
                  ),
                  Expanded(child: _buildStage(isCompact: isCompact)),
                  const SizedBox(height: CinemaSpace.s12),
                  _BottomStoryNavigationBar(
                    activeStoryListenable: _activeStoryNotifier,
                    onPrevious: () => _handlePreviousAction(playHaptic: false),
                    onNext: () => _handleNextAction(playHaptic: false),
                    onStart: () => _handleNextAction(playHaptic: false),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStage({required bool isCompact}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handleStagePointerDown,
        onPointerMove: _handleStagePointerMove,
        onPointerUp: _handleStagePointerUp,
        onPointerCancel: _handleStagePointerCancel,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollEndNotification &&
                notification.metrics.axis == Axis.horizontal) {
              _settledPageAtPointerDown = _activeStoryNotifier.value;
              _resumeTimelineIfSettled();
            }
            return false;
          },
          child: Stack(
            key: _stageKey,
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                allowImplicitScrolling: false,
                physics: _SereneStoryPageScrollPhysics(
                  settledPageGetter: () => _settledPageAtPointerDown,
                ),
                itemCount: _kStoryCount,
                onPageChanged: _handlePageChangedBySwipe,
                itemBuilder: (context, index) {
                  return _StorySlidePage(
                    key: Key('cinema-story-${index + 1}'),
                    storyIndex: index,
                    isActiveStory: index == _activeStoryNotifier.value,
                    totalDuration: widget.totalDuration,
                    isCompact: isCompact,
                    pageController: _pageController,
                    holdPausedListenable: _isHoldPausedNotifier,
                    restartEpochListenable: index == 0
                        ? _storyZeroRestartEpoch
                        : null,
                    onInteractiveControlPointerDown:
                        _registerInteractiveControlPointerDown,
                    onActiveHeroBuild: widget.onActiveHeroBuild,
                  );
                },
              ),
              const Positioned.fill(
                child: _PassThroughTapZoneOverlay(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 32,
                        child: ColoredBox(
                          key: Key('story-tap-zone-prev'),
                          color: Colors.transparent,
                          child: SizedBox.expand(),
                        ),
                      ),
                      Expanded(
                        flex: 68,
                        child: ColoredBox(
                          key: Key('story-tap-zone-next'),
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
    final isActivelySwiping =
        livePage != null && (livePage - livePage.roundToDouble()).abs() > 1e-3;

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
            ..color = const Color(0xFFFDE68A)
                .withValues(alpha: 0.10 * stardust),
        );
        canvas.drawCircle(
          center,
          star.$3,
          Paint()
            ..color = const Color(0xFFFEF3C7)
                .withValues(alpha: 0.46 * stardust),
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
        height: 48.0,
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
                      height: 48.0,
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
    required this.holdPausedListenable,
    required this.onSkipPressed,
    required this.onClosePressed,
  });

  final ValueListenable<int> activeStoryListenable;
  final bool isReplay;
  final ValueListenable<bool> holdPausedListenable;
  final VoidCallback onSkipPressed;
  final VoidCallback onClosePressed;

  @override
  Widget build(BuildContext context) {
    const total = DesperrengueWelcomeCinemaScreen.storyCount;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: CinemaSpace.s8,
              runSpacing: CinemaSpace.s4,
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: activeStoryListenable,
                  builder: (context, storyIndex, _) {
                    final safeStep = (storyIndex + 1).clamp(1, total);
                    return Text(
                      'Etapa $safeStep de $total',
                      style: CinemaType.chrome,
                    );
                  },
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: holdPausedListenable,
                  builder: (context, isPaused, _) {
                    if (!isPaused) return const SizedBox.shrink();
                    return const _FadeInPausedBadge(
                      key: Key('cinema-paused-badge'),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: CinemaSpace.s8),
          if (isReplay)
            _CinemaDiscreetPillButton(
              key: const Key('btn-close-replay-cinema'),
              label: 'Fechar',
              tooltip: 'Fechar apresentação',
              leadingIcon: Icons.close_rounded,
              onPressed: onClosePressed,
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _CinemaDiscreetPillButton(
                  key: const Key('btn-skip-welcome-cinema'),
                  label: 'Pular',
                  tooltip: 'Pular apresentação',
                  onPressed: onSkipPressed,
                ),
                const SizedBox(width: CinemaSpace.s4),
                _CinemaDiscreetCloseIconButton(
                  key: const Key('btn-close-welcome-cinema'),
                  onPressed: onClosePressed,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Pílula translúcida discreta do cabeçalho (`Pular` no pós-cadastro ou
/// `× Fechar` no modo replay), com alvo tátil >= 48×48 dp, contraste AAA
/// sobre todas as auroras, anel de foco esmeralda (Web/teclado) e mola tátil.
class _CinemaDiscreetPillButton extends StatefulWidget {
  const _CinemaDiscreetPillButton({
    super.key,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.leadingIcon,
  });

  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final IconData? leadingIcon;

  @override
  State<_CinemaDiscreetPillButton> createState() =>
      _CinemaDiscreetPillButtonState();
}

class _CinemaDiscreetPillButtonState extends State<_CinemaDiscreetPillButton>
    with SingleTickerProviderStateMixin {
  static const double _pressedScale = 0.95;
  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1.0,
    stiffness: 720.0,
    ratio: 1.0,
  );

  late final AnimationController _scale;
  bool _focused = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
      vsync: this,
      lowerBound: 0.85,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _animateScaleTo(double target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _scale.value = target;
      return;
    }
    _scale.animateWith(SpringSimulation(_spring, _scale.value, target, 0.0));
  }

  void _handleTapDown(TapDownDetails _) {
    HapticFeedback.selectionClick();
    _animateScaleTo(_pressedScale);
  }

  void _handleTapRelease() {
    _animateScaleTo(1.0);
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = _focused || _hovered;
    final fill = CinemaColors.chromePillSurface.withValues(
      alpha: _hovered ? 0.68 : 0.46,
    );
    final borderColor = highlighted
        ? CinemaColors.emeraldRing
        : Colors.white.withValues(alpha: 0.24);

    return Semantics(
      button: true,
      label: widget.tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.tooltip,
        excludeFromSemantics: true,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          onShowHoverHighlight: (value) => setState(() => _hovered = value),
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _handleTapDown,
            onTapUp: (_) => _handleTapRelease(),
            onTapCancel: _handleTapRelease,
            onTap: widget.onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
              child: Center(
                widthFactor: 1.0,
                child: ScaleTransition(
                  scale: _scale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(
                        CinemaGeometry.pillRadius,
                      ),
                      border: Border.all(
                        color: borderColor,
                        width: highlighted ? 1.5 : 1.0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CinemaSpace.s12,
                        vertical: CinemaSpace.s8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (widget.leadingIcon != null) ...[
                            Icon(
                              widget.leadingIcon,
                              size: 16,
                              color: CinemaColors.onAurora,
                            ),
                            const SizedBox(width: CinemaSpace.s4),
                          ],
                          Text(
                            widget.label,
                            style: CinemaType.chrome.copyWith(
                              color: CinemaColors.onAurora,
                              fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

/// Botão circular translúcido discreto de fechar (`×`) da apresentação,
/// alinhado à mesma linguagem de vidro de [StoryNavCircleButton]:
/// - Alvo tátil WCAG/Material `48×48 dp` com círculo visual discreto `36×36 dp`;
/// - Vidro sutil (`rgba(255,255,255,0.10)`) + borda hairline `0.26`;
/// - Anel esmeralda `2 px` (`#A7F3D0`) em foco/hover (Web e teclado);
/// - Mola criticamente amortecida (`0.92`) respeitando `disableAnimations`.
class _CinemaDiscreetCloseIconButton extends StatefulWidget {
  const _CinemaDiscreetCloseIconButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  static const double touchSize = 48.0;
  static const double visualSize = 36.0;
  static const double iconSize = 18.0;
  static const Color glassFill = CinemaColors.closeGlassFill;
  static const Color glassHoverFill = CinemaColors.closeGlassHoverFill;
  static const Color glassBorder = CinemaColors.closeGlassBorder;

  @override
  State<_CinemaDiscreetCloseIconButton> createState() =>
      _CinemaDiscreetCloseIconButtonState();
}

class _CinemaDiscreetCloseIconButtonState
    extends State<_CinemaDiscreetCloseIconButton>
    with SingleTickerProviderStateMixin {
  static const double _pressedScale = 0.92;
  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1.0,
    stiffness: 720.0,
    ratio: 1.0,
  );

  late final AnimationController _scale;
  bool _focused = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
      vsync: this,
      lowerBound: 0.80,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _animateScaleTo(double target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _scale.value = target;
      return;
    }
    _scale.animateWith(SpringSimulation(_spring, _scale.value, target, 0.0));
  }

  void _handleTapDown(TapDownDetails _) {
    HapticFeedback.selectionClick();
    _animateScaleTo(_pressedScale);
  }

  void _handleTapRelease() {
    _animateScaleTo(1.0);
  }

  @override
  Widget build(BuildContext context) {
    final showRing = _focused || _hovered;
    final fill = _hovered
        ? _CinemaDiscreetCloseIconButton.glassHoverFill
        : _CinemaDiscreetCloseIconButton.glassFill;

    final glass = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(
          color: _CinemaDiscreetCloseIconButton.glassBorder,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.close_rounded,
          size: _CinemaDiscreetCloseIconButton.iconSize,
          color: CinemaColors.onAurora,
        ),
      ),
    );

    final ring = IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: showRing ? 1.0 : 0.0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: CinemaColors.emeraldRing, width: 2.0),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: 'Fechar apresentação',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Fechar apresentação',
        excludeFromSemantics: true,
        child: SizedBox(
          width: _CinemaDiscreetCloseIconButton.touchSize,
          height: _CinemaDiscreetCloseIconButton.touchSize,
          child: FocusableActionDetector(
            mouseCursor: SystemMouseCursors.click,
            onShowFocusHighlight: (value) => setState(() => _focused = value),
            onShowHoverHighlight: (value) => setState(() => _hovered = value),
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onPressed();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: _handleTapDown,
              onTapUp: (_) => _handleTapRelease(),
              onTapCancel: _handleTapRelease,
              onTap: widget.onPressed,
              child: Center(
                child: ScaleTransition(
                  scale: _scale,
                  child: SizedBox(
                    width: _CinemaDiscreetCloseIconButton.visualSize,
                    height: _CinemaDiscreetCloseIconButton.visualSize,
                    child: Stack(fit: StackFit.expand, children: [glass, ring]),
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
          borderRadius: BorderRadius.circular(CinemaGeometry.pillRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CinemaSpace.s12,
            vertical: CinemaSpace.s4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.pause_rounded,
                size: 16,
                color: CinemaColors.onAurora,
              ),
              const SizedBox(width: CinemaSpace.s4),
              Text(
                'Pausado',
                style: CinemaType.caption.copyWith(
                  color: CinemaColors.onAurora,
                  fontWeight: FontWeight.w700,
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
// RODAPÉ SIMÉTRICO: [ < ]  ● ● ● ● ● ●  [ > ]  +  CTA "Começar agora" (ETAPA 6)
// =============================================================================

class _BottomStoryNavigationBar extends StatelessWidget {
  const _BottomStoryNavigationBar({
    required this.activeStoryListenable,
    required this.onPrevious,
    required this.onNext,
    required this.onStart,
  });

  final ValueListenable<int> activeStoryListenable;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    const total = DesperrengueWelcomeCinemaScreen.storyCount;

    return ValueListenableBuilder<int>(
      valueListenable: activeStoryListenable,
      builder: (context, storyIndex, _) {
        final isFirst = storyIndex <= 0;
        final isLast = storyIndex >= total - 1;
        final reduceMotion = MediaQuery.disableAnimationsOf(context);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLast) ...[
              _StartCtaButton(
                key: const Key('btn-story-start'),
                onPressed: onStart,
                animateEntrance: !reduceMotion,
              ),
              const SizedBox(height: CinemaSpace.s12),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                StoryNavCircleButton(
                  key: const Key('btn-story-prev'),
                  direction: StoryNavDirection.previous,
                  enabled: !isFirst,
                  onPressed: onPrevious,
                ),
                Expanded(
                  child: Center(
                    child: SizedBox(
                      key: const Key('story-pagination-dots'),
                      height: 16.0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List.generate(total, (i) {
                          final active = i == storyIndex;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: CinemaSpace.s4,
                            ),
                            child: AnimatedContainer(
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              width: active ? 24.0 : 8.0,
                              height: 8.0,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  CinemaGeometry.pillRadius,
                                ),
                                color: active
                                    ? CinemaColors.onAurora
                                    : Colors.white.withValues(alpha: 0.34),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
                StoryNavCircleButton(
                  key: const Key('btn-story-next'),
                  direction: StoryNavDirection.next,
                  enabled: !isLast,
                  onPressed: onNext,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// CTA aurora de largura total (56 px) da Etapa 6: entra com fade + 12 px.
class _StartCtaButton extends StatefulWidget {
  const _StartCtaButton({
    super.key,
    required this.onPressed,
    required this.animateEntrance,
  });

  final VoidCallback onPressed;
  final bool animateEntrance;

  @override
  State<_StartCtaButton> createState() => _StartCtaButtonState();
}

class _StartCtaButtonState extends State<_StartCtaButton> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CinemaGeometry.pillRadius);
    final highlighted = _focused || _hovered;

    Widget button = Semantics(
      button: true,
      label: 'Começar agora',
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF6EE7B7),
                  Color(0xFFA7F3D0),
                  Color(0xFFFDE68A),
                  Color(0xFFFDBA74),
                ],
                stops: [0.0, 0.36, 0.72, 1.0],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6EE7B7)
                      .withValues(alpha: highlighted ? 0.42 : 0.28),
                  blurRadius: 20,
                  offset: const Offset(-6, 6),
                ),
                BoxShadow(
                  color: const Color(0xFFFDBA74)
                      .withValues(alpha: highlighted ? 0.44 : 0.30),
                  blurRadius: 22,
                  offset: const Offset(6, 6),
                ),
              ],
            ),
            position: DecorationPosition.background,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: _focused
                    ? Border.all(color: Colors.white, width: 3)
                    : null,
              ),
              child: SizedBox(
                height: CinemaGeometry.ctaHeight,
                width: double.infinity,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CinemaSpace.s20,
                    ),
                    child: Text(
                      'Começar agora',
                      textAlign: TextAlign.center,
                      style: CinemaType.button,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.animateEntrance) {
      button = IntroFx(child: button);
    }
    return button;
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
    final perStoryMs =
        widget.totalDuration.inMilliseconds /
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

  Widget _buildHeroDemoContent(int index) {
    switch (index) {
      case 0:
        return CinemaStory1Card(act: _actController);
      case 1:
        return CinemaStory2Card(act: _actController);
      case 2:
        return CinemaStory3Card(act: _actController);
      case 3:
        return CinemaStory4Card(act: _actController);
      case 4:
        return CinemaStory5Card(act: _actController);
      default:
        return CinemaStory6Card(
          act: _actController,
          onInteractivePointerDown: widget.onInteractiveControlPointerDown,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _kStorySpecs[widget.storyIndex];
    final (titleText, subtitleText) = _copyForStory(widget.storyIndex);

    // Ato 1 (0.0s – 0.75s = 0.00 .. 0.242 de 3.10s): cascata sedosa sem quique
    final titleFx = ActFx(
      act: _actController,
      effects: cascadeEffects(0.00, 0.16),
      child: Text(titleText, style: CinemaType.display),
    );
    final leadFx = ActFx(
      act: _actController,
      effects: cascadeEffects(0.04, 0.20),
      child: Text(subtitleText, style: CinemaType.lead),
    );

    final heroCard = WelcomeStoryHeroCard(
      storyIndex: widget.storyIndex,
      isActiveStory: widget.isActiveStory,
      accentColor: spec.accent,
      isCompact: widget.isCompact,
      onActiveHeroBuild: widget.onActiveHeroBuild,
      child: _buildHeroDemoContent(widget.storyIndex),
    );

    final animatedHero = AnimatedBuilder(
      animation: widget.pageController,
      child: ActFx(
        act: _actController,
        effects: cascadeEffects(0.08, 0.242, dy: 18),
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
          offset: Offset(parallaxX, 0),
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

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleFx,
        const SizedBox(height: CinemaSpace.s8),
        leadFx,
        const SizedBox(height: CinemaSpace.s20),
        heroStageWithOptionalStardust,
      ],
    );

    // Rolagem vertical interna da página: se o conteúdo exceder a altura
    // (fonte ampliada, telas baixas) a página rola — a fonte nunca encolhe.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          key: spec.legacyKey,
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: const Alignment(0, -0.12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: CinemaSpace.s8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: CinemaGeometry.maxColumnWidth,
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        );
      },
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
    final primaryGold = isWarmSunset
        ? const Color(0xFFFDE68A)
        : const Color(0xFFFCD34D);
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

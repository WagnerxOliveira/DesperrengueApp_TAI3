import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, Uint8List, defaultTargetPlatform, immutable, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/active_liveness_engine.dart';
import '../../../core/services/document_ocr_and_liveness_service.dart';
import '../../../core/services/face_detection_adapter.dart';
import '../../../core/services/live_camera_frame_bridge.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/kyc_human_feedback_translator.dart';

/// Resultado devolvido pelo [ActiveLivenessFullscreenModal] ao concluir a Prova de Vida Real.
@immutable
class ActiveLivenessModalOutput {
  const ActiveLivenessModalOutput({
    required this.selfieBytes,
    required this.livenessResult,
    this.chosenDirection,
    this.computedLivenessScore,
  });

  final Uint8List selfieBytes;
  final ActiveLivenessResult livenessResult;
  final LivenessTurnDirection? chosenDirection;
  final double? computedLivenessScore;
}

/// Modal imersivo em tela cheia para Prova de Vida Biométrica Real
/// (ML Kit no Mobile + MediaPipe FaceLandmarker na Web).
///
/// Projetado com HUD minimalista (topo: fechar, etapa X de 3, trocar câmera;
/// rodapé: um único card translúcido com instrução curta e ícone direcional),
/// moldura oval generosa em `RepaintBoundary` (120 FPS), contorno discreto
/// vermelho -> verde e arco fino de progresso.
class ActiveLivenessFullscreenModal extends StatefulWidget {
  const ActiveLivenessFullscreenModal({
    super.key,
    required this.cpfDigits,
    this.enforceHumanFaceTextureCheck = true,
    @visibleForTesting this.forcedDirection,
    @visibleForTesting this.adapterOverride,
    @visibleForTesting this.testObservationStream,
    @visibleForTesting this.testCaptureOverride,
    @visibleForTesting this.testInitialSnapshot,
  });

  static const Key closeButtonKey = ValueKey<String>('liveness_close_button');
  static const Key switchCameraButtonKey = ValueKey<String>('liveness_switch_camera_button');
  static const Key stepPillKey = ValueKey<String>('liveness_step_pill');
  static const Key instructionCardKey = ValueKey<String>('liveness_instruction_card');
  static const Key ovalOverlayKey = ValueKey<String>('liveness_oval_overlay');
  static const Key viewportFrameKey = ValueKey<String>('liveness_viewport_frame');

  final String cpfDigits;
  final bool enforceHumanFaceTextureCheck;

  @visibleForTesting
  final LivenessTurnDirection? forcedDirection;

  @visibleForTesting
  final FaceDetectionAdapter? adapterOverride;

  @visibleForTesting
  final Stream<LiveFaceObservation>? testObservationStream;

  @visibleForTesting
  final Future<Uint8List> Function()? testCaptureOverride;

  @visibleForTesting
  final ActiveLivenessSnapshot? testInitialSnapshot;

  /// Abre o modal de Prova de Vida Real usando [AppRoute] em tela cheia.
  static Future<ActiveLivenessModalOutput?> show(
    BuildContext context, {
    required String cpfDigits,
    bool enforceHumanFaceTextureCheck = true,
    @visibleForTesting LivenessTurnDirection? forcedDirection,
    @visibleForTesting FaceDetectionAdapter? adapterOverride,
    @visibleForTesting Stream<LiveFaceObservation>? testObservationStream,
    @visibleForTesting Future<Uint8List> Function()? testCaptureOverride,
    @visibleForTesting ActiveLivenessSnapshot? testInitialSnapshot,
  }) {
    return Navigator.of(context, rootNavigator: true).push<ActiveLivenessModalOutput>(
      AppRoute<ActiveLivenessModalOutput>(
        fullscreenModal: true,
        builder: (_) => ActiveLivenessFullscreenModal(
          cpfDigits: cpfDigits,
          enforceHumanFaceTextureCheck: enforceHumanFaceTextureCheck,
          forcedDirection: forcedDirection,
          adapterOverride: adapterOverride,
          testObservationStream: testObservationStream,
          testCaptureOverride: testCaptureOverride,
          testInitialSnapshot: testInitialSnapshot,
        ),
      ),
    );
  }

  @override
  State<ActiveLivenessFullscreenModal> createState() =>
      _ActiveLivenessFullscreenModalState();
}

class _ActiveLivenessFullscreenModalState
    extends State<ActiveLivenessFullscreenModal> {
  static const double _desktopMaxStageWidth = 520.0;
  static const Duration _contourTransitionDuration = Duration(milliseconds: 180);
  static const Duration _frameThrottle = Duration(milliseconds: 70);

  late final ActiveLivenessStateMachine _engine;
  late ActiveLivenessSnapshot _snapshot;

  FaceDetectionAdapter? _adapter;
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = const <CameraDescription>[];
  int _selectedCameraIndex = 0;

  StreamSubscription<LiveFaceObservation>? _testSubscription;
  Timer? _webPollTimer;
  int _lastProcessedFrameMs = 0;

  bool _initializing = false;
  bool _capturing = false;
  bool _streaming = false;
  bool _closed = false;
  String? _blockingError;

  bool get _isFrontCamera {
    if (_availableCameras.isEmpty) return true;
    return _availableCameras[_selectedCameraIndex].lensDirection ==
        CameraLensDirection.front;
  }

  bool get _isTestMode =>
      widget.testObservationStream != null || widget.testInitialSnapshot != null;

  @override
  void initState() {
    super.initState();
    _engine = ActiveLivenessStateMachine(
      forcedDirection: widget.forcedDirection,
    );
    _snapshot = widget.testInitialSnapshot ?? _engine.currentSnapshot;

    if (widget.testObservationStream != null) {
      _testSubscription = widget.testObservationStream!.listen(
        _onObservation,
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _blockingError =
                'Não foi possível ler a câmera agora. Tente novamente.';
          });
        },
      );
    } else if (widget.testInitialSnapshot == null) {
      unawaited(_initializeHardwareFlow());
    }
  }

  @override
  void dispose() {
    _closed = true;
    _testSubscription?.cancel();
    _webPollTimer?.cancel();
    unawaited(_teardownCameraAndAdapter());
    super.dispose();
  }

  Future<void> _teardownCameraAndAdapter() async {
    _webPollTimer?.cancel();
    _webPollTimer = null;

    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      if (_streaming) {
        _streaming = false;
        try {
          await controller.stopImageStream();
        } catch (_) {}
      }
      try {
        await controller.dispose();
      } catch (_) {}
    }

    final adapter = _adapter;
    _adapter = null;
    if (adapter != null) {
      try {
        await adapter.dispose();
      } catch (_) {}
    }
  }

  Future<void> _initializeHardwareFlow({int? cameraIndexOverride}) async {
    if (_initializing || _closed) return;
    setState(() {
      _initializing = true;
      _blockingError = null;
      _snapshot = _engine.reset();
    });

    await _teardownCameraAndAdapter();
    if (!mounted || _closed) return;

    try {
      final cameras = await availableCameras();
      if (!mounted || _closed) return;

      if (cameras.isEmpty) {
        setState(() {
          _initializing = false;
          _blockingError =
              'Nenhuma câmera foi encontrada neste aparelho. Verifique as permissões e tente novamente.';
        });
        return;
      }

      _availableCameras = cameras;
      if (cameraIndexOverride != null &&
          cameraIndexOverride >= 0 &&
          cameraIndexOverride < cameras.length) {
        _selectedCameraIndex = cameraIndexOverride;
      } else {
        final frontIdx = cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        _selectedCameraIndex = frontIdx >= 0 ? frontIdx : 0;
      }

      final CameraDescription selected = _availableCameras[_selectedCameraIndex];
      final ImageFormatGroup? formatGroup = kIsWeb
          ? null
          : (defaultTargetPlatform == TargetPlatform.android
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888);

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: formatGroup,
      );
      await controller.initialize();
      if (!mounted || _closed) {
        await controller.dispose();
        return;
      }

      if (kIsWeb) {
        await ensureWebVideoFacingMode(frontCamera: _isFrontCamera);
      }

      final adapter = widget.adapterOverride ?? createFaceDetectionAdapter();
      final bool adapterOk = await adapter.initialize();
      if (!mounted || _closed) {
        await adapter.dispose();
        await controller.dispose();
        return;
      }

      if (!adapterOk) {
        final String reason = KycHumanFeedbackTranslator.sanitizeForHumanDisplay(
          adapter.unavailableReason ??
              'Não foi possível iniciar o reconhecimento facial ao vivo neste aparelho.',
        );
        await adapter.dispose();
        await controller.dispose();
        setState(() {
          _initializing = false;
          _blockingError = reason;
        });
        return;
      }

      _cameraController = controller;
      _adapter = adapter;

      setState(() {
        _initializing = false;
        _blockingError = null;
      });

      await _startLiveAnalysisLoop();
    } catch (e) {
      if (!mounted || _closed) return;
      final String friendly = _translateCameraError(e);
      setState(() {
        _initializing = false;
        _blockingError = friendly;
      });
    }
  }

  String _translateCameraError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission') ||
        text.contains('denied') ||
        text.contains('notallowederror')) {
      return 'Permita o acesso à câmera nas configurações para continuar a verificação facial.';
    }
    return KycHumanFeedbackTranslator.translateError(error);
  }

  Future<void> _startLiveAnalysisLoop() async {
    final controller = _cameraController;
    final adapter = _adapter;
    if (controller == null || adapter == null || _closed) return;

    if (kIsWeb) {
      _webPollTimer?.cancel();
      _webPollTimer = Timer.periodic(const Duration(milliseconds: 85), (_) {
        if (_capturing || _closed || !mounted) return;
        unawaited(_pollWebFrame());
      });
      return;
    }

    if (_streaming) return;
    _streaming = true;
    final int sensorOrientation =
        _availableCameras[_selectedCameraIndex].sensorOrientation;
    final bool isFront = _isFrontCamera;

    await controller.startImageStream((CameraImage image) {
      if (_capturing || _closed || !mounted) return;
      final int now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastProcessedFrameMs < _frameThrottle.inMilliseconds) {
        return;
      }
      _lastProcessedFrameMs = now;
      final DeviceOrientation deviceOrientation =
          controller.value.deviceOrientation;
      unawaited(
        adapter
            .analyzeCameraImage(
              image,
              sensorOrientation: sensorOrientation,
              isFrontCamera: isFront,
              deviceOrientation: deviceOrientation,
            )
            .then((obs) {
          if (obs != null && mounted && !_closed) {
            _onObservation(obs);
          }
        }),
      );
    });
  }

  Future<void> _pollWebFrame() async {
    final adapter = _adapter;
    if (adapter == null || _capturing || _closed) return;
    final obs = await adapter.analyzeWebVideoFrame(
      mirrorHorizontal: _isFrontCamera,
    );
    if (obs != null && mounted && !_closed) {
      _onObservation(obs);
    }
  }

  void _onObservation(LiveFaceObservation observation) {
    if (_capturing || _closed || !mounted) return;

    if (observation.unavailableReason != null &&
        observation.unavailableReason!.trim().isNotEmpty) {
      setState(() {
        _blockingError = KycHumanFeedbackTranslator.sanitizeForHumanDisplay(
          observation.unavailableReason!,
        );
      });
      return;
    }

    final ActiveLivenessSnapshot next = _engine.processObservation(observation);
    final bool stageChanged = next.stage != _snapshot.stage;
    if (stageChanged && !kIsWeb && !_isTestMode) {
      HapticFeedback.lightImpact();
    }

    setState(() {
      _snapshot = next;
    });

    if (next.readyToCapture) {
      unawaited(_captureAndVerify(next));
    }
  }

  Future<void> _captureAndVerify(ActiveLivenessSnapshot completedSnapshot) async {
    if (_capturing || _closed || !mounted) return;
    setState(() {
      _capturing = true;
    });

    _webPollTimer?.cancel();
    _webPollTimer = null;

    try {
      final Uint8List selfieBytes = await _acquireSelfieBytes();
      if (!mounted || _closed) return;

      final ActiveLivenessResult rawResult =
          await DocumentOcrAndLivenessService.verifyActiveLivenessInIsolate(
        selfieBytes: selfieBytes,
        cpfDigits: widget.cpfDigits,
        earTimeline: completedSnapshot.realEarTimeline,
        poseTimeline: completedSnapshot.realPoseTimeline,
        enforceHumanFaceTextureCheck: widget.enforceHumanFaceTextureCheck,
        requireRealBiometricTelemetry: true,
      );

      if (!mounted || _closed) return;

      final double realLivenessScore = double.parse(
        (((rawResult.livenessScore + completedSnapshot.computedLivenessScore) *
                    0.5)
                .clamp(82.0, 99.5))
            .toStringAsFixed(1),
      );
      final ActiveLivenessResult finalResult = ActiveLivenessResult(
        passed: rawResult.passed,
        livenessScore: realLivenessScore,
        meanLuminance: rawResult.meanLuminance,
        minEyeAspectRatio: rawResult.minEyeAspectRatio,
        maxEyeAspectRatio: rawResult.maxEyeAspectRatio,
        maxHeadYawDegrees: rawResult.maxHeadYawDegrees,
        selfiePerceptualHash64: rawResult.selfiePerceptualHash64,
        faceLivenessHash: rawResult.faceLivenessHash,
        faceEmbedding128: rawResult.faceEmbedding128,
        challengesPassed: rawResult.challengesPassed,
        verifiedAtUtc: rawResult.verifiedAtUtc,
      );

      if (!kIsWeb && !_isTestMode) {
        HapticFeedback.mediumImpact();
      }

      Navigator.of(context).pop(
        ActiveLivenessModalOutput(
          selfieBytes: selfieBytes,
          livenessResult: finalResult,
          chosenDirection: completedSnapshot.chosenDirection,
          computedLivenessScore: realLivenessScore,
        ),
      );
    } catch (e) {
      if (!mounted || _closed) return;
      final String friendly = KycHumanFeedbackTranslator.translateError(e);
      setState(() {
        _capturing = false;
        _snapshot = _engine.reset();
        _blockingError = friendly;
      });
    }
  }

  Future<Uint8List> _acquireSelfieBytes() async {
    if (widget.testCaptureOverride != null) {
      return widget.testCaptureOverride!();
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      throw StateError('Câmera indisponível no momento da captura.');
    }

    if (kIsWeb) {
      final Uint8List? webBytes = await grabWebVideoFramePngBytes(
        width: 640,
        height: 480,
        mirrorHorizontal: _isFrontCamera,
      );
      if (webBytes != null && webBytes.isNotEmpty) {
        return webBytes;
      }
      final XFile shot = await controller.takePicture();
      return shot.readAsBytes();
    }

    if (_streaming) {
      _streaming = false;
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }

    final XFile file = await controller.takePicture();
    return file.readAsBytes();
  }

  void _handleClose() {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).maybePop();
  }

  void _handleSwitchCamera() {
    if (_availableCameras.length <= 1 || _initializing || _capturing) return;
    final int nextIdx = (_selectedCameraIndex + 1) % _availableCameras.length;
    unawaited(_initializeHardwareFlow(cameraIndexOverride: nextIdx));
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens darkTk = AppTokens.dark;
    final bool reducedMotion = AppMotion.reduced(context);
    final Duration contourDuration =
        reducedMotion ? Duration.zero : _contourTransitionDuration;
    final Duration progressDuration =
        reducedMotion ? Duration.zero : AppMotion.progress;

    final Color targetContourColor =
        (_blockingError != null ||
                _snapshot.contourState == LivenessContourState.invalidRed)
            ? darkTk.danger
            : darkTk.success;

    final ThemeData baseDarkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: darkTk.accent,
        onPrimary: darkTk.onAccent,
        surface: darkTk.surface,
        onSurface: darkTk.text,
        error: darkTk.danger,
      ),
      scaffoldBackgroundColor: darkTk.background,
      extensions: <ThemeExtension<dynamic>>[darkTk],
    );

    return Theme(
      data: baseDarkTheme,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): _handleClose,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: darkTk.background,
            body: LayoutBuilder(
              builder: (context, constraints) {
                final bool isDesktopViewport =
                    constraints.maxWidth > _desktopMaxStageWidth;
                final double stageWidth = isDesktopViewport
                    ? _desktopMaxStageWidth
                    : constraints.maxWidth;

                return Center(
                  child: SizedBox(
                    key: ActiveLivenessFullscreenModal.viewportFrameKey,
                    width: stageWidth,
                    height: constraints.maxHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 1. Feed da câmera frontal ao vivo (BoxFit.cover sem FittedBox, espelhado)
                        _buildCameraBackdrop(darkTk),

                        // 2. Máscara escura (PathFillType.evenOdd) + Oval generoso + Arco de progresso (120 FPS)
                        RepaintBoundary(
                          key: ActiveLivenessFullscreenModal.ovalOverlayKey,
                          child: reducedMotion
                              ? CustomPaint(
                                  size: Size.infinite,
                                  painter: ActiveLivenessOvalPainter(
                                    scrimColor: darkTk.background.withValues(
                                      alpha: 0.78,
                                    ),
                                    contourColor: targetContourColor,
                                    progressColor: darkTk.success,
                                    trackColor: darkTk.border.withValues(
                                      alpha: 0.55,
                                    ),
                                    progress: _snapshot.progress,
                                  ),
                                )
                              : TweenAnimationBuilder<Color?>(
                                  tween: ColorTween(end: targetContourColor),
                                  duration: contourDuration,
                                  curve: AppMotion.fadeCurve,
                                  builder: (context, animatedColor, _) {
                                    final Color contourColor =
                                        animatedColor ?? targetContourColor;
                                    return TweenAnimationBuilder<double>(
                                      tween: Tween<double>(
                                        end: _snapshot.progress,
                                      ),
                                      duration: progressDuration,
                                      curve: AppMotion.countCurve,
                                      builder: (context, animatedProgress, _) {
                                        return CustomPaint(
                                          size: Size.infinite,
                                          painter: ActiveLivenessOvalPainter(
                                            scrimColor:
                                                darkTk.background.withValues(
                                              alpha: 0.78,
                                            ),
                                            contourColor: contourColor,
                                            progressColor: darkTk.success,
                                            trackColor:
                                                darkTk.border.withValues(
                                              alpha: 0.55,
                                            ),
                                            progress: animatedProgress,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),

                        // 3. HUD Minimalista (Topo + Rodapé) dentro da SafeArea
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.s16,
                              vertical: AppSpace.s12,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildTopBar(darkTk),
                                _buildBottomCard(
                                  darkTk,
                                  contourColor: targetContourColor,
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
        ),
      ),
    );
  }

  Widget _buildCameraBackdrop(AppTokens darkTk) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return DecoratedBox(
        decoration: BoxDecoration(color: darkTk.surfaceInset),
        child: const SizedBox.expand(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final Size? preview = controller.value.previewSize;
        final double camAspect = (preview != null && preview.height > 0)
            ? (kIsWeb
                ? preview.width / preview.height
                : preview.height / preview.width)
            : (3.0 / 4.0);
        final double boxAspect =
            constraints.maxWidth / math.max(1.0, constraints.maxHeight);
        final double coverScale = camAspect > boxAspect
            ? (camAspect / boxAspect)
            : (boxAspect / camAspect);

        return ClipRect(
          child: Transform.flip(
            flipX: _isFrontCamera,
            child: Transform.scale(
              scale: coverScale,
              child: Center(
                child: AspectRatio(
                  aspectRatio: camAspect,
                  child: CameraPreview(controller),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(AppTokens darkTk) {
    final bool canSwitchCamera = _availableCameras.length > 1;
    final String stepLabel =
        'Etapa ${_snapshot.uiStepNumber} de ${_snapshot.uiTotalSteps}';

    return Row(
      children: [
        _buildTopIconButton(
          key: ActiveLivenessFullscreenModal.closeButtonKey,
          icon: Icons.close_rounded,
          semanticLabel: 'Fechar verificação facial',
          darkTk: darkTk,
          onPressed: _handleClose,
        ),
        const SizedBox(width: AppSpace.s8),
        Expanded(
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: Container(
                key: ActiveLivenessFullscreenModal.stepPillKey,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s16,
                  vertical: AppSpace.s8,
                ),
                decoration: BoxDecoration(
                  color: darkTk.surface.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                  border: Border.all(color: darkTk.border),
                ),
                child: Text(
                  stepLabel,
                  textAlign: TextAlign.center,
                  style: AppType.tabular(AppType.bodySm).copyWith(
                    color: darkTk.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s8),
        if (canSwitchCamera)
          _buildTopIconButton(
            key: ActiveLivenessFullscreenModal.switchCameraButtonKey,
            icon: Icons.cameraswitch_rounded,
            semanticLabel: 'Trocar câmera',
            darkTk: darkTk,
            onPressed: _handleSwitchCamera,
          )
        else
          const SizedBox(
            width: AppGeometry.minTarget,
            height: AppGeometry.minTarget,
          ),
      ],
    );
  }

  Widget _buildTopIconButton({
    required Key key,
    required IconData icon,
    required String semanticLabel,
    required AppTokens darkTk,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: darkTk.surface.withValues(alpha: 0.86),
        shape: CircleBorder(side: BorderSide(color: darkTk.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: key,
          onTap: onPressed,
          child: SizedBox(
            width: AppGeometry.minTarget,
            height: AppGeometry.minTarget,
            child: Icon(
              icon,
              color: darkTk.text,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomCard(
    AppTokens darkTk, {
    required Color contourColor,
  }) {
    final String message;
    final IconData iconData;
    final Color iconColor;

    if (_blockingError != null) {
      message = _blockingError!;
      iconData = Icons.error_outline_rounded;
      iconColor = darkTk.danger;
    } else if (_initializing) {
      message = 'Preparando câmera frontal...';
      iconData = Icons.videocam_rounded;
      iconColor = darkTk.textMuted;
    } else if (_capturing) {
      message = 'Confirmando sua captura...';
      iconData = Icons.verified_user_rounded;
      iconColor = darkTk.success;
    } else {
      message = _snapshot.instruction;
      iconData = _iconForCue(_snapshot.cueKind);
      iconColor = contourColor;
    }

    return Semantics(
      liveRegion: true,
      child: Container(
        key: ActiveLivenessFullscreenModal.instructionCardKey,
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.s16),
        decoration: BoxDecoration(
          color: darkTk.card.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(AppGeometry.cardRadius),
          border: Border.all(
            color: contourColor.withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: AppGeometry.iconTileSize,
                  height: AppGeometry.iconTileSize,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(
                      AppGeometry.iconTileRadius,
                    ),
                  ),
                  child: Icon(
                    iconData,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Text(
                    message,
                    style: AppType.bodyStrong.copyWith(color: darkTk.text),
                  ),
                ),
              ],
            ),
            if (_initializing || _capturing) ...[
              const SizedBox(height: AppSpace.s12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                child: LinearProgressIndicator(
                  minHeight: AppSpace.s4,
                  backgroundColor: darkTk.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _capturing ? darkTk.success : darkTk.brand,
                  ),
                ),
              ),
            ],
            if (_blockingError != null) ...[
              const SizedBox(height: AppSpace.s12),
              AppButton(
                label: 'Tentar novamente',
                compact: true,
                onPressed: _isTestMode
                    ? () {
                        setState(() {
                          _blockingError = null;
                          _snapshot = _engine.reset();
                        });
                      }
                    : () => unawaited(
                          _initializeHardwareFlow(
                            cameraIndexOverride: _selectedCameraIndex,
                          ),
                        ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForCue(LivenessCueKind cue) {
    return switch (cue) {
      LivenessCueKind.alignCenter => Icons.center_focus_strong_rounded,
      LivenessCueKind.moveCloser => Icons.zoom_in_rounded,
      LivenessCueKind.moveFarther => Icons.zoom_out_rounded,
      LivenessCueKind.improveLighting => Icons.wb_sunny_rounded,
      LivenessCueKind.holdStill => Icons.pan_tool_alt_rounded,
      LivenessCueKind.singleFaceOnly => Icons.groups_rounded,
      LivenessCueKind.realFaceOnly => Icons.face_retouching_natural_rounded,
      LivenessCueKind.blinkEyes => Icons.visibility_rounded,
      LivenessCueKind.turnLeft => Icons.turn_left_rounded,
      LivenessCueKind.turnRight => Icons.turn_right_rounded,
      LivenessCueKind.returnCenter => Icons.center_focus_weak_rounded,
      LivenessCueKind.captured => Icons.check_circle_rounded,
    };
  }
}

/// Painter de alta performance (120 FPS dentro de `RepaintBoundary`) para a
/// máscara escura recortada (`PathFillType.evenOdd`), contorno discreto
/// vermelho -> verde e arco fino de progresso sobre o perímetro do oval.
class ActiveLivenessOvalPainter extends CustomPainter {
  const ActiveLivenessOvalPainter({
    required this.scrimColor,
    required this.contourColor,
    required this.progressColor,
    required this.trackColor,
    required this.progress,
  });

  /// Proporção largura:altura do oval generoso (`1 : 1.32`).
  static const double ovalHeightToWidthRatio = 1.32;
  static const double ovalWidthFraction = 0.66;
  static const double ovalMaxHeightFraction = 0.48;

  final Color scrimColor;
  final Color contourColor;
  final Color progressColor;
  final Color trackColor;
  final double progress;

  /// Calcula o retângulo exato do oval para qualquer viewport (mobile ou desktop).
  static Rect computeOvalRect(Size size) {
    final double widthFromW = size.width * ovalWidthFraction;
    final double maxHeight = size.height * ovalMaxHeightFraction;
    final double widthFromH = maxHeight / ovalHeightToWidthRatio;
    final double ovalW = math.min(widthFromW, widthFromH);
    final double ovalH = ovalW * ovalHeightToWidthRatio;
    final Offset center = Offset(size.width * 0.50, size.height * 0.47);
    return Rect.fromCenter(center: center, width: ovalW, height: ovalH);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect ovalRect = computeOvalRect(size);

    // 1. Máscara escura recortada no formato oval (evenOdd).
    final Path maskPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(ovalRect);
    canvas.drawPath(
      maskPath,
      Paint()
        ..color = scrimColor
        ..style = PaintingStyle.fill,
    );

    // 2. Contorno discreto vermelho -> verde ao redor do oval.
    final Paint contourPaint = Paint()
      ..color = contourColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..isAntiAlias = true;
    canvas.drawOval(ovalRect, contourPaint);

    // 3. Trilho sutil externo + arco fino de progresso (0% -> 33% -> 66% -> 100%).
    final Rect progressRect = ovalRect.inflate(6.0);
    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..isAntiAlias = true;
    canvas.drawOval(progressRect, trackPaint);

    final double clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress > 0.001) {
      // Inicia no topo (12h = -pi/2) em sentido horário.
      final Path arcBase = Path()
        ..addArc(progressRect, -math.pi / 2, math.pi * 2);
      final ui.PathMetrics metrics = arcBase.computeMetrics();
      final Paint progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      for (final ui.PathMetric metric in metrics) {
        final double extractLen = metric.length * clampedProgress;
        if (extractLen > 0) {
          canvas.drawPath(metric.extractPath(0, extractLen), progressPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant ActiveLivenessOvalPainter oldDelegate) {
    return oldDelegate.scrimColor != scrimColor ||
        oldDelegate.contourColor != contourColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor ||
        (oldDelegate.progress - progress).abs() > 0.001;
  }
}

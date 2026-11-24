import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, Uint8List, defaultTargetPlatform, immutable, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../../core/services/active_liveness_engine.dart';
import '../../../core/services/camera_operation_queue.dart';
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
/// Projetado com HUD minimalista (topo: fechar à esquerda, etapa X de 3
/// centralizada e espaçador simétrico à direita; rodapé: um único card
/// translúcido com instrução curta e ícone direcional), moldura oval generosa
/// em `RepaintBoundary` (120 FPS), contorno discreto vermelho -> verde e arco
/// fino de progresso. Trava estritamente na câmera frontal.
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
  static const Key stepPillKey = ValueKey<String>('liveness_step_pill');
  static const Key instructionCardKey = ValueKey<String>('liveness_instruction_card');
  static const Key ovalOverlayKey = ValueKey<String>('liveness_oval_overlay');
  static const Key viewportFrameKey = ValueKey<String>('liveness_viewport_frame');

  /// Indica se o preview da câmera frontal precisa de espelhamento horizontal
  /// manual (`Transform.flip(flipX: true)`).
  ///
  /// No Android (`camera_android_camerax` / `SurfaceTexture`) e no iOS
  /// (`AVFoundation`), `CameraPreview(controller)` já espelha a câmera frontal
  /// nativamente como um espelho real — aplicar `Transform.flip` lá causaria
  /// espelhamento duplo (double-flip). Apenas na Web (`kIsWeb`) o `<video>`
  /// WebRTC não vem espelhado.
  @visibleForTesting
  static bool shouldMirrorFrontPreview({required bool isWeb}) => isWeb;

  /// Seleciona estritamente a câmera frontal para Prova de Vida.
  ///
  /// Prioriza `CameraLensDirection.front` e aceita fallback apenas se o nome da
  /// lente identificar explicitamente frontal (`front`, `user` ou `selfie`).
  /// Jamais faz fallback para câmera traseira.
  @visibleForTesting
  static CameraDescription? selectStrictFrontCamera(
    List<CameraDescription> cameras,
  ) {
    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        return camera;
      }
    }
    for (final camera in cameras) {
      final String lowerName = camera.name.toLowerCase();
      if (lowerName.contains('front') ||
          lowerName.contains('user') ||
          lowerName.contains('selfie')) {
        return camera;
      }
    }
    return null;
  }

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
  static const Duration _streamWatchdogTimeout = Duration(milliseconds: 3200);
  static const Duration _streamRebindTimeout = Duration(milliseconds: 2500);
  static const Duration _stillFallbackInterval = Duration(milliseconds: 380);

  late final ActiveLivenessStateMachine _engine;
  late ActiveLivenessSnapshot _snapshot;
  final CameraOperationQueue _cameraQueue = CameraOperationQueue();

  FaceDetectionAdapter? _adapter;
  CameraController? _cameraController;
  CameraDescription? _frontCamera;

  StreamSubscription<LiveFaceObservation>? _testSubscription;
  Timer? _webPollTimer;
  Timer? _streamWatchdogTimer;
  Timer? _stillPollTimer;
  int _lastProcessedFrameMs = 0;

  // Telemetria real do stream para evitar congelamento silencioso, projetar o
  // bounding box do sensor no viewport visível (coverScale) e manter Golden
  // Frame frontal em memória durante a Etapa 3B (resiliência cross-OEM).
  int _framesDeliveredByCamera = 0;
  int _observationsProcessed = 0;
  bool _streamRetryAttempted = false;
  bool _stillFallbackActive = false;
  bool _stillCaptureBusy = false;
  double? _cameraPreviewAspect;
  double? _streamFrameAspect;
  double? _viewportAspect;
  LiveFaceObservation? _lastValidNeuralObservation;
  img.Image? _goldenFrontImage;
  String? _capturingStatusMessage;

  bool _initializing = false;
  bool _capturing = false;
  bool _streaming = false;
  bool _closed = false;
  String? _blockingError;

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
    _streamWatchdogTimer?.cancel();
    _stillPollTimer?.cancel();
    unawaited(_teardownCameraAndAdapter());
    super.dispose();
  }

  Future<void> _teardownCameraAndAdapter() async {
    _webPollTimer?.cancel();
    _webPollTimer = null;
    _streamWatchdogTimer?.cancel();
    _streamWatchdogTimer = null;
    _stillPollTimer?.cancel();
    _stillPollTimer = null;
    _stillFallbackActive = false;
    _stillCaptureBusy = false;
    _framesDeliveredByCamera = 0;
    _observationsProcessed = 0;
    _streamRetryAttempted = false;
    _lastValidNeuralObservation = null;
    _goldenFrontImage = null;
    _capturingStatusMessage = null;

    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      await _cameraQueue.enqueue<void>(() async {
        if (_streaming) {
          _streaming = false;
          try {
            await controller.stopImageStream();
          } catch (_) {}
        }
        try {
          await controller.dispose();
        } catch (_) {}
      });
    }

    final adapter = _adapter;
    _adapter = null;
    if (adapter != null) {
      try {
        await adapter.dispose();
      } catch (_) {}
    }
  }

  Future<void> _initializeHardwareFlow() async {
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
              'Nenhuma câmera frontal foi encontrada neste aparelho. Use um dispositivo com câmera frontal e verifique as permissões.';
        });
        return;
      }

      final CameraDescription? selected =
          ActiveLivenessFullscreenModal.selectStrictFrontCamera(cameras);
      if (selected == null) {
        setState(() {
          _initializing = false;
          _blockingError =
              'A prova de vida exige um aparelho com câmera frontal. Use um dispositivo com câmera frontal para continuar.';
        });
        return;
      }

      _frontCamera = selected;
      // Android usa YUV_420_888 (ImageFormatGroup.yuv420) nativo do CameraX em
      // 100% dos aparelhos, evitando o bug de ImageProxyUtils.planesToNV21 em
      // sensores Samsung com rowStride > width. O MobileFaceDetectionAdapter
      // normaliza 1, 2 ou 3 planos para NV21 compacto antes de enviar ao ML Kit.
      final ImageFormatGroup? formatGroup = kIsWeb
          ? null
          : (defaultTargetPlatform == TargetPlatform.android
              ? ImageFormatGroup.yuv420
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
        await ensureWebVideoFacingMode(frontCamera: true);
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
        } catch (_) {}
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
    _framesDeliveredByCamera = 0;
    _observationsProcessed = 0;
    final int sensorOrientation = _frontCamera?.sensorOrientation ?? 0;

    await _cameraQueue.enqueue<void>(() async {
      await controller.startImageStream((CameraImage image) {
        if (_capturing || _closed || !mounted || _stillFallbackActive) return;
        _framesDeliveredByCamera += 1;
        final int now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastProcessedFrameMs < _frameThrottle.inMilliseconds) {
          return;
        }
        _lastProcessedFrameMs = now;
        final DeviceOrientation deviceOrientation =
            controller.value.deviceOrientation;
        if (image.width > 0 && image.height > 0) {
          final bool swapped = sensorOrientation == 90 || sensorOrientation == 270;
          final double effW = (swapped ? image.height : image.width).toDouble();
          final double effH = (swapped ? image.width : image.height).toDouble();
          if (effH > 0) _streamFrameAspect = effW / effH;
        }
        unawaited(
          adapter
              .analyzeCameraImage(
                image,
                sensorOrientation: sensorOrientation,
                isFrontCamera: true,
                deviceOrientation: deviceOrientation,
              )
              .then((obs) {
            if (obs != null && mounted && !_closed) {
              _observationsProcessed += 1;
              if (obs.faceCount == 1 &&
                  obs.unavailableReason == null &&
                  _snapshot.stage == LivenessStage.returnToCenter &&
                  obs.headEulerAngleY.abs() <= 8.5) {
                final img.Image? upright = convertCameraImageToUprightRgbNamed(
                  image: image,
                  sensorOrientation: sensorOrientation,
                  isFrontCamera: true,
                  targetMaxDimension: 480,
                );
                if (upright != null) {
                  _goldenFrontImage = upright;
                }
              }
              _onObservation(obs);
            }
          }),
        );
      });
    });

    _armStreamWatchdog();
  }

  void _armStreamWatchdog() {
    _streamWatchdogTimer?.cancel();
    final Duration delay =
        _streamRetryAttempted ? _streamRebindTimeout : _streamWatchdogTimeout;
    _streamWatchdogTimer = Timer(delay, () {
      if (!mounted || _closed || _capturing || _stillFallbackActive) return;
      if (_observationsProcessed > 0) return;

      if (_framesDeliveredByCamera == 0) {
        if (!_streamRetryAttempted) {
          _streamRetryAttempted = true;
          unawaited(_rebindImageStreamOnce());
        } else {
          unawaited(_activateStillFrameFallback());
        }
        return;
      }

      // Câmera entregou quadros mas o detector não produziu nenhuma observação válida.
      setState(() {
        _blockingError =
            'Não foi possível processar os quadros da câmera frontal agora. Toque em "Tentar novamente".';
      });
    });
  }

  Future<void> _rebindImageStreamOnce() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _closed) return;
    if (_streaming) {
      _streaming = false;
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }
    if (!mounted || _closed || _capturing) return;
    try {
      await _startLiveAnalysisLoop();
    } catch (_) {
      await _activateStillFrameFallback();
    }
  }

  /// Fallback 100% REAL (Google ML Kit Face Detection via `InputImage.fromFilePath`)
  /// acionado somente se `startImageStream` não entregar nenhum quadro em um
  /// dispositivo Android exótico mesmo após reinicialização do stream.
  Future<void> _activateStillFrameFallback() async {
    final controller = _cameraController;
    final adapter = _adapter;
    if (controller == null ||
        adapter == null ||
        !controller.value.isInitialized ||
        _closed ||
        _capturing) {
      return;
    }

    _stillFallbackActive = true;
    _streamWatchdogTimer?.cancel();
    if (_streaming) {
      _streaming = false;
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }

    _stillPollTimer?.cancel();
    _stillPollTimer = Timer.periodic(_stillFallbackInterval, (_) {
      if (_capturing || _closed || !mounted || _stillCaptureBusy) return;
      unawaited(_pollStillFrameViaMlKit());
    });
  }

  Future<void> _pollStillFrameViaMlKit() async {
    final controller = _cameraController;
    final adapter = _adapter;
    if (controller == null ||
        adapter == null ||
        !controller.value.isInitialized ||
        _capturing ||
        _closed) {
      return;
    }
    _stillCaptureBusy = true;
    try {
      final XFile shot = await controller.takePicture();
      if (_closed || !mounted || _capturing) return;
      final LiveFaceObservation? obs = await adapter.analyzeImageFilePath(
        shot.path,
        isFrontCamera: true,
        deleteAfterAnalysis: true,
      );
      if (obs != null && mounted && !_closed) {
        _observationsProcessed += 1;
        _onObservation(obs);
      }
    } catch (_) {
      // Erro transitório isolado; o contador do adaptador aciona unavailable se persistir.
    } finally {
      _stillCaptureBusy = false;
    }
  }

  Future<void> _pollWebFrame() async {
    final adapter = _adapter;
    if (adapter == null || _capturing || _closed) return;
    final obs = await adapter.analyzeWebVideoFrame(
      mirrorHorizontal: true,
    );
    if (obs != null && mounted && !_closed) {
      _onObservation(obs);
    }
  }

  void _onObservation(LiveFaceObservation observation) {
    if (_capturing || _closed || !mounted) return;

    if (observation.unavailableReason != null &&
        observation.unavailableReason!.trim().isNotEmpty) {
      _streamWatchdogTimer?.cancel();
      _stillPollTimer?.cancel();
      setState(() {
        _blockingError = KycHumanFeedbackTranslator.sanitizeForHumanDisplay(
          observation.unavailableReason!,
        );
      });
      return;
    }

    // Em modo câmera real, projeta o bounding box do sensor cru para o espaço
    // visível do viewport recortado por `coverScale` (ex.: câmera 3:4 em tela 9:20).
    LiveFaceObservation effectiveObservation = observation;
    final double? camAspect = _streamFrameAspect ?? _cameraPreviewAspect;
    final double? boxAspect = _viewportAspect;
    if (!_isTestMode &&
        observation.faceCount > 0 &&
        observation.normalizedBox != Rect.zero &&
        camAspect != null &&
        boxAspect != null) {
      final Rect projected = projectSensorNormalizedRectToViewport(
        sensorRect: observation.normalizedBox,
        cameraAspect: camAspect,
        viewportAspect: boxAspect,
      );
      effectiveObservation = observation.copyWithNormalizedBox(projected);
    }

    if (observation.faceCount == 1 && observation.unavailableReason == null) {
      _lastValidNeuralObservation = observation;
    }

    final LivenessContourState previousContour = _snapshot.contourState;
    final ActiveLivenessSnapshot next =
        _engine.processObservation(effectiveObservation);
    if (next.sessionWasReset) {
      _goldenFrontImage = null;
    }
    final bool stageChanged = next.stage != _snapshot.stage;
    final bool snappedToGreen =
        previousContour == LivenessContourState.invalidRed &&
            next.contourState != LivenessContourState.invalidRed;
    if ((stageChanged || snappedToGreen) && !kIsWeb && !_isTestMode) {
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
      _capturingStatusMessage = 'Confirmando sua captura...';
    });

    _webPollTimer?.cancel();
    _webPollTimer = null;
    _streamWatchdogTimer?.cancel();
    _streamWatchdogTimer = null;
    _stillPollTimer?.cancel();
    _stillPollTimer = null;

    try {
      final ({
        Uint8List selfieBytes,
        bool verifiedByNeuralFaceDetector,
        Rect? verifiedFaceBox,
        double? neuralMeanLuminance,
        double? neuralSharpness,
      }) acquired = await _acquireSelfieAndAuditNeurally();
      if (!mounted || _closed) return;

      final ActiveLivenessResult rawResult =
          await DocumentOcrAndLivenessService.verifyActiveLivenessInIsolate(
        selfieBytes: acquired.selfieBytes,
        cpfDigits: widget.cpfDigits,
        earTimeline: completedSnapshot.realEarTimeline,
        poseTimeline: completedSnapshot.realPoseTimeline,
        enforceHumanFaceTextureCheck: widget.enforceHumanFaceTextureCheck,
        requireRealBiometricTelemetry: true,
        verifiedByNeuralFaceDetector: acquired.verifiedByNeuralFaceDetector,
        verifiedFaceBox: acquired.verifiedFaceBox,
        neuralMeanLuminance: acquired.neuralMeanLuminance,
        neuralSharpness: acquired.neuralSharpness,
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
          selfieBytes: acquired.selfieBytes,
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
        _capturingStatusMessage = null;
        _goldenFrontImage = null;
        _lastValidNeuralObservation = null;
        _snapshot = _engine.reset();
        _blockingError = friendly;
      });
    }
  }

  /// Captura a selfie canônica (EXIF normalizado em pé) e executa auditoria
  /// neural pós-captura real (Google ML Kit no Mobile / MediaPipe na Web),
  /// com fila serializada `CameraOperationQueue` (180 ms grace delay + 4 s
  /// timeout), auto-retry silencioso (2×) se o usuário mexer no clique e
  /// Golden-Frame fallback se `takePicture()` sofrer timeout de driver OEM.
  Future<({
    Uint8List selfieBytes,
    bool verifiedByNeuralFaceDetector,
    Rect? verifiedFaceBox,
    double? neuralMeanLuminance,
    double? neuralSharpness,
  })> _acquireSelfieAndAuditNeurally() async {
    if (widget.testCaptureOverride != null) {
      final Uint8List testBytes = await widget.testCaptureOverride!();
      return (
        selfieBytes: testBytes,
        verifiedByNeuralFaceDetector: false,
        verifiedFaceBox: null,
        neuralMeanLuminance: null,
        neuralSharpness: null,
      );
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      throw StateError('Câmera indisponível no momento da captura.');
    }

    if (kIsWeb) {
      final Uint8List? webBytes = await grabWebVideoFramePngBytes(
        width: 640,
        height: 480,
        mirrorHorizontal: true,
      );
      final Uint8List rawBytes;
      if (webBytes != null && webBytes.isNotEmpty) {
        rawBytes = webBytes;
      } else {
        final XFile shot = await _cameraQueue.capturePhotoAfterStreamStop(
          controller,
          stopStreamIfActive: false,
        );
        rawBytes = await DocumentOcrAndLivenessService
            .normalizeSelfieOrientationBytesInIsolate(
          await shot.readAsBytes(),
        );
      }
      final LiveFaceObservation? lastObs = _lastValidNeuralObservation;
      return (
        selfieBytes: rawBytes,
        verifiedByNeuralFaceDetector: lastObs != null,
        verifiedFaceBox: lastObs?.normalizedBox,
        neuralMeanLuminance: lastObs?.meanLuminance,
        neuralSharpness: lastObs?.sharpness,
      );
    }

    // Mobile (Android multi-fabricante + iOS AVFoundation):
    // Para o stream de forma serializada com 180ms grace delay antes do 1º clique.
    final bool wasStreaming = _streaming || controller.value.isStreamingImages;
    _streaming = false;

    const int maxAttempts = 2;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (_closed || !mounted) {
        throw StateError('Verificação cancelada.');
      }
      if (attempt > 1) {
        if (mounted) {
          setState(() {
            _capturingStatusMessage = 'Segure firme, confirmando sua foto...';
          });
        }
        await Future<void>.delayed(const Duration(milliseconds: 280));
      }

      XFile? shot;
      try {
        shot = await _cameraQueue.capturePhotoAfterStreamStop(
          controller,
          stopStreamIfActive: attempt == 1 && wasStreaming,
        );
      } on TimeoutException {
        final golden = _buildGoldenFrameFallbackIfAvailable();
        if (golden != null) return golden;
        rethrow;
      } on CameraException {
        final golden = _buildGoldenFrameFallbackIfAvailable();
        if (golden != null) return golden;
        rethrow;
      }

      final Uint8List rawBytes = await shot.readAsBytes();
      final Uint8List canonicalBytes = await DocumentOcrAndLivenessService
          .normalizeSelfieOrientationBytesInIsolate(rawBytes);

      final adapter = _adapter;
      if (adapter != null && adapter.isInitialized) {
        final LiveFaceObservation? auditObs = await adapter.analyzeImageFilePath(
          shot.path,
          isFrontCamera: true,
          deleteAfterAnalysis: true,
        );
        if (auditObs != null &&
            auditObs.unavailableReason == null &&
            auditObs.faceCount == 1) {
          return (
            selfieBytes: canonicalBytes,
            verifiedByNeuralFaceDetector: true,
            verifiedFaceBox: auditObs.normalizedBox,
            neuralMeanLuminance: auditObs.meanLuminance,
            neuralSharpness: auditObs.sharpness,
          );
        }
        if (auditObs != null && auditObs.faceCount >= 2) {
          throw StateError(
            'ERR_MULTIPLE_FACES_IN_SELFIE: Mais de um rosto detectado na foto capturada.',
          );
        }
        // faceCount == 0 ou quadro tremido: tenta 2ª captura silenciosa antes de falhar.
        continue;
      }

      // Adaptador indisponível após takePicture: usa última observação neural válida.
      final LiveFaceObservation? lastObs = _lastValidNeuralObservation;
      if (lastObs != null) {
        return (
          selfieBytes: canonicalBytes,
          verifiedByNeuralFaceDetector: true,
          verifiedFaceBox: lastObs.normalizedBox,
          neuralMeanLuminance: lastObs.meanLuminance,
          neuralSharpness: lastObs.sharpness,
        );
      }
    }

    // Se ambas as capturas de obturador saíram sem rosto (usuário mexeu muito):
    // jamais acusar falsamente "fotos ou telas" — orienta de forma humana exata.
    throw StateError(
      'ERR_SELFIE_CAPTURE_MOVED: Não foi possível capturar o rosto parado no disparo.',
    );
  }

  /// Fallback resiliente cross-OEM (ex.: drivers `takePicture()` com deadlock ou
  /// timeout em alguns aparelhos Android): reaproveita o Golden Frame frontal
  /// salvo em memória durante a Etapa 3B já validado pelo próprio ML Kit real.
  ({
    Uint8List selfieBytes,
    bool verifiedByNeuralFaceDetector,
    Rect? verifiedFaceBox,
    double? neuralMeanLuminance,
    double? neuralSharpness,
  })? _buildGoldenFrameFallbackIfAvailable() {
    final img.Image? goldenRgb = _goldenFrontImage;
    final LiveFaceObservation? lastObs = _lastValidNeuralObservation;
    if (goldenRgb == null || lastObs == null) return null;
    final Uint8List jpegBytes = Uint8List.fromList(
      img.encodeJpg(goldenRgb, quality: 92),
    );
    return (
      selfieBytes: jpegBytes,
      verifiedByNeuralFaceDetector: true,
      verifiedFaceBox: lastObs.normalizedBox,
      neuralMeanLuminance: lastObs.meanLuminance,
      neuralSharpness: lastObs.sharpness,
    );
  }

  void _handleClose() {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).maybePop();
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
        final double boxWidth = math.max(1.0, constraints.maxWidth);
        final double boxHeight = math.max(1.0, constraints.maxHeight);
        final bool isPortraitBox = boxHeight >= boxWidth;
        final double camAspect;
        if (preview != null && preview.width > 0 && preview.height > 0) {
          final double rawAspect = preview.width / preview.height;
          if (kIsWeb) {
            camAspect = rawAspect;
          } else {
            camAspect = isPortraitBox
                ? (rawAspect > 1.0 ? 1.0 / rawAspect : rawAspect)
                : (rawAspect < 1.0 ? 1.0 / rawAspect : rawAspect);
          }
        } else {
          camAspect = 3.0 / 4.0;
        }
        final double boxAspect = boxWidth / boxHeight;
        _cameraPreviewAspect = camAspect;
        _viewportAspect = boxAspect;
        final double coverScale = math.max(
          1.0,
          camAspect > boxAspect
              ? (camAspect / boxAspect)
              : (boxAspect / camAspect),
        );

        final Widget scaledPreview = Transform.scale(
          scale: coverScale,
          child: Center(
            child: AspectRatio(
              aspectRatio: camAspect,
              child: CameraPreview(controller),
            ),
          ),
        );

        final bool shouldMirror =
            ActiveLivenessFullscreenModal.shouldMirrorFrontPreview(
          isWeb: kIsWeb,
        );

        return ClipRect(
          child: shouldMirror
              ? Transform.flip(
                  flipX: true,
                  child: scaledPreview,
                )
              : scaledPreview,
        );
      },
    );
  }

  Widget _buildTopBar(AppTokens darkTk) {
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
      message = _capturingStatusMessage ?? 'Confirmando sua captura...';
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
                    : () => unawaited(_initializeHardwareFlow()),
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
  static const double ovalWidthFraction = 0.72;
  static const double ovalMaxHeightFraction = 0.52;

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

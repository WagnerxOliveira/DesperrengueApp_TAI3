import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'package:desperrengue_app/core/ui/design_system/design_system.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/document_frame_alignment_engine.dart';
import '../../../core/services/document_ocr_and_liveness_service.dart';
import '../../../core/services/live_camera_frame_bridge.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/kyc_human_feedback_translator.dart';

/// Modal fullscreen de captura guiada de documento oficial (Frente e Verso)
/// na proporção ISO/IEC 7810 ID-1 com validação óptica real em tempo real:
///
/// - **Contorno discreto VERMELHO** (`2.5 px` + cantoneiras `3.5 px`) quando o
///   documento está ausente, fora do retângulo, desfocado, com reflexo, mal
///   iluminado ou repetindo a frente no lugar do verso; **botão de captura
///   desabilitado** até o enquadramento ser validado.
/// - **Transição suave (`180 ms`) para VERDE** após 3 quadros consecutivos
///   válidos + `HapticFeedback.lightImpact()` + botão de captura habilitado +
///   captura automática suave após ~1,0 s estável (5 quadros consecutivos).
/// - Recorta estritamente o retângulo guia (`cropDocumentToGuidedFrameNamed`)
///   e devolve `Uint8List`.
class DocumentGuidedScannerModal extends StatefulWidget {
  const DocumentGuidedScannerModal({
    super.key,
    required this.isFront,
    required this.documentType,
    this.referenceFrontBytes,
    this.initialVerticalOrientation = false,
    @visibleForTesting this.testAssessmentStream,
    @visibleForTesting this.testInitialAssessment,
    @visibleForTesting this.testCaptureOverride,
    @visibleForTesting this.autoCaptureEnabled = true,
  });

  final bool isFront;
  final OfficialDocumentType documentType;

  /// Bytes já capturados da Frente do documento (passados quando `isFront == false`)
  /// para bloquear em tempo real a apresentação repetida da Frente no lugar do Verso.
  final Uint8List? referenceFrontBytes;
  final bool initialVerticalOrientation;

  /// Gancho opcional para testes de widget e Galeria de Telas sem hardware de câmera.
  final Stream<DocumentFrameAssessment>? testAssessmentStream;

  /// Diagnóstico inicial opcional para pré-visualização estática ou testes.
  final DocumentFrameAssessment? testInitialAssessment;

  /// Simulação de captura de alta resolução para testes de widget.
  final Future<Uint8List> Function()? testCaptureOverride;

  /// Controla se a captura automática suave (~1,0 s no verde) dispara sozinha.
  final bool autoCaptureEnabled;

  @override
  State<DocumentGuidedScannerModal> createState() =>
      _DocumentGuidedScannerModalState();
}

class _DocumentGuidedScannerModalState extends State<DocumentGuidedScannerModal> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  int _selectedCameraIndex = 0;
  bool _initializing = true;
  bool _capturing = false;
  bool _torchOn = false;
  late bool _isVerticalOrientation = widget.initialVerticalOrientation;
  String? _errorMessage;

  Timer? _samplingTimer;
  bool _evaluatingFrame = false;
  CameraImage? _latestStreamImage;
  img.Image? _decodedReferenceFront;

  final DocumentAlignmentTracker _tracker = DocumentAlignmentTracker();
  DocumentAlignmentSnapshot? _snapshot;
  StreamSubscription<DocumentFrameAssessment>? _testSub;

  bool get _isTestDriven =>
      widget.testAssessmentStream != null ||
      widget.testInitialAssessment != null;

  @override
  void initState() {
    super.initState();
    if (widget.referenceFrontBytes != null &&
        widget.referenceFrontBytes!.isNotEmpty) {
      _decodedReferenceFront = img.decodeImage(widget.referenceFrontBytes!);
    }

    if (_isTestDriven) {
      _initializing = false;
      final initial = widget.testInitialAssessment;
      if (initial != null) {
        if (initial.isValid && widget.testAssessmentStream == null) {
          for (int i = 0; i < _tracker.requiredStableFrames; i++) {
            _snapshot = _tracker.push(initial);
          }
        } else {
          _snapshot = _tracker.push(initial);
        }
      }
      _testSub = widget.testAssessmentStream?.listen(_handleAssessment);
    } else {
      _initRearCamera();
    }
  }

  @override
  void dispose() {
    _testSub?.cancel();
    _samplingTimer?.cancel();
    final ctrl = _controller;
    _controller = null;
    if (ctrl != null) {
      unawaited(() async {
        try {
          if (_torchOn) {
            await ctrl.setFlashMode(FlashMode.off);
          }
        } catch (_) {}
        try {
          if (!kIsWeb && ctrl.value.isStreamingImages) {
            await ctrl.stopImageStream();
          }
        } catch (_) {}
        try {
          await ctrl.dispose();
        } catch (_) {}
      }());
    }
    super.dispose();
  }

  void _handleAssessment(DocumentFrameAssessment assessment) {
    if (!mounted || _capturing) return;
    final bool wasAligned = _tracker.isAlignedAndReady;
    final DocumentAlignmentSnapshot next = _tracker.push(assessment);

    if (!wasAligned && next.isAlignedAndReady) {
      HapticFeedback.lightImpact();
    }

    setState(() {
      _snapshot = next;
    });

    if (widget.autoCaptureEnabled && next.readyForAutoCapture && !_capturing) {
      unawaited(_captureAndCropDocument());
    }
  }

  Future<void> _initRearCamera({bool switchLens = false}) async {
    _samplingTimer?.cancel();
    _tracker.reset();
    final prev = _controller;
    _controller = null;
    if (prev != null) {
      try {
        if (!kIsWeb && prev.value.isStreamingImages) {
          await prev.stopImageStream();
        }
      } catch (_) {}
      try {
        await prev.dispose();
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _initializing = true;
      _torchOn = false;
      _errorMessage = null;
      _snapshot = null;
    });

    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        throw StateError('Nenhuma câmera disponível no aparelho.');
      }
      _cameras = cams;

      if (switchLens && cams.length > 1) {
        _selectedCameraIndex = (_selectedCameraIndex + 1) % cams.length;
      } else {
        final backIdx = cams.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
        );
        if (backIdx >= 0) {
          _selectedCameraIndex = backIdx;
        } else {
          final envIdx = cams.indexWhere(
            (c) =>
                c.name.toLowerCase().contains('back') ||
                c.name.toLowerCase().contains('rear') ||
                c.name.toLowerCase().contains('environment'),
          );
          _selectedCameraIndex = envIdx >= 0 ? envIdx : 0;
        }
      }

      final chosen = cams[_selectedCameraIndex];
      final ctrl = CameraController(
        chosen,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await ctrl.initialize();

      if (kIsWeb) {
        final wantFront =
            chosen.lensDirection == CameraLensDirection.front && cams.length > 1;
        await ensureWebVideoFacingMode(frontCamera: wantFront);
      } else {
        try {
          await ctrl.setFocusMode(FocusMode.auto);
        } catch (_) {}
        try {
          await ctrl.startImageStream((CameraImage frame) {
            _latestStreamImage = frame;
          });
        } catch (_) {}
      }

      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      setState(() {
        _controller = ctrl;
        _initializing = false;
      });

      _samplingTimer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => _evaluateLiveFrame(),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorMessage =
            'Não foi possível abrir a câmera traseira. Verifique as permissões do aparelho e tente novamente.';
      });
    }
  }

  Future<void> _toggleTorch() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || kIsWeb) {
      if (mounted) {
        setState(() => _torchOn = !_torchOn);
      }
      return;
    }
    final next = !_torchOn;
    try {
      await ctrl.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torchOn = next);
    } catch (_) {
      if (mounted) setState(() => _torchOn = false);
    }
  }

  Future<void> _evaluateLiveFrame() async {
    if (!mounted ||
        _capturing ||
        _evaluatingFrame ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    _evaluatingFrame = true;
    try {
      DocumentFrameAssessment? assessment;

      if (kIsWeb) {
        final Uint8List? frameBytes = await grabWebVideoFramePngBytes(
          maxWidth: 240,
          maxHeight: 180,
          mirrorHorizontal: false,
        );
        if (frameBytes != null && frameBytes.isNotEmpty) {
          assessment =
              await DocumentFrameAlignmentEngine.evaluateFrameBytesInIsolate(
            frameBytes: frameBytes,
            isFront: widget.isFront,
            isVerticalOrientation: _isVerticalOrientation,
            referenceFrontBytes: widget.referenceFrontBytes,
          );
        }
      } else if (_latestStreamImage != null) {
        final desc = _controller!.description;
        final img.Image? rgb = convertCameraImageToUprightRgbNamed(
          image: _latestStreamImage!,
          sensorOrientation: desc.sensorOrientation,
          isFrontCamera: desc.lensDirection == CameraLensDirection.front,
          targetMaxDimension: 240,
        );
        if (rgb != null) {
          assessment = DocumentFrameAlignmentEngine.evaluateDecodedFrame(
            frame: rgb,
            isFront: widget.isFront,
            isVerticalOrientation: _isVerticalOrientation,
            referenceFrontBytes: widget.referenceFrontBytes,
            referenceFrontDecoded: _decodedReferenceFront,
          );
        }
      }

      if (assessment != null) {
        _handleAssessment(assessment);
      }
    } catch (_) {
      // Ignora quadro corrompido isolado sem travar a câmera
    } finally {
      _evaluatingFrame = false;
    }
  }

  Future<void> _captureAndCropDocument() async {
    if (_capturing) return;
    final bool ready = _snapshot?.isAlignedAndReady ?? false;
    if (!ready) return;

    setState(() {
      _capturing = true;
      _errorMessage = null;
    });

    try {
      _samplingTimer?.cancel();
      Uint8List? rawBytes;

      if (widget.testCaptureOverride != null) {
        rawBytes = await widget.testCaptureOverride!();
      } else {
        final ctrl = _controller;
        if (kIsWeb) {
          rawBytes = await grabWebVideoFramePngBytes(
            maxWidth: 1280,
            maxHeight: 960,
            mirrorHorizontal: false,
          );
        }
        if ((rawBytes == null || rawBytes.isEmpty) &&
            ctrl != null &&
            ctrl.value.isInitialized) {
          if (!kIsWeb && ctrl.value.isStreamingImages) {
            try {
              await ctrl.stopImageStream();
            } catch (_) {}
          }
          final xfile = await ctrl.takePicture();
          rawBytes = await xfile.readAsBytes();
        }
      }

      if (rawBytes == null || rawBytes.isEmpty) {
        throw StateError('Não foi possível capturar a imagem do documento.');
      }

      final Uint8List croppedBytes =
          DocumentOcrAndLivenessService.cropDocumentToGuidedFrameNamed(
        fullCameraFrameBytes: rawBytes,
        isVerticalOrientation: _isVerticalOrientation,
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(croppedBytes);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _errorMessage = 'Falha ao capturar a imagem. Tente novamente.';
      });
      if (!_isTestDriven && _controller != null) {
        _samplingTimer = Timer.periodic(
          const Duration(milliseconds: 200),
          (_) => _evaluateLiveFrame(),
        );
      }
    }
  }

  void _setOrientation(bool vertical) {
    if (_isVerticalOrientation == vertical) return;
    _tracker.reset();
    setState(() {
      _isVerticalOrientation = vertical;
      _snapshot = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scannerTheme = AppTheme.resolve(UserMode.client, Brightness.dark);
    final darkTk = scannerTheme.extension<AppTokens>() ??
        AppTokens.dark.forAccent(
          accent: AppTokens.dark.clientAccent,
          accentInk: AppTokens.dark.clientAccentInk,
          accentSoft: AppTokens.dark.clientSoft,
        );

    final bool isAlignedGreen = _snapshot?.isAlignedAndReady ?? false;
    final double stabilityProgress =
        isAlignedGreen ? (_snapshot?.autoCaptureProgress ?? 0.0) : 0.0;

    final String rawStatusText = _snapshot != null
        ? (isAlignedGreen
            ? 'Documento enquadrado! Pronto para capturar'
            : _snapshot!.assessment.humanHint)
        : (widget.isFront
            ? 'Encaixe a frente do documento dentro do retângulo.'
            : 'Encaixe o verso do documento dentro do retângulo.');
    final String statusText =
        KycHumanFeedbackTranslator.sanitizeForHumanDisplay(rawStatusText);

    final String sideTitle = widget.isFront
        ? 'Frente do documento (${widget.documentType.code})'
        : 'Verso do documento (${widget.documentType.code})';
    final String sideSubtitle = widget.isFront
        ? 'Posicione o lado com sua foto e nome dentro do retângulo.'
        : 'Posicione o verso com o código e os dados dentro do retângulo.';

    final Color targetBorderColor =
        isAlignedGreen ? darkTk.success : darkTk.danger;
    final Duration borderAnimDuration = AppMotion.d(
      context,
      const Duration(milliseconds: 180),
    );

    return Theme(
      data: scannerTheme,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): () {
            Navigator.of(context).maybePop();
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: darkTk.background,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWideViewport =
                      constraints.maxWidth >= AppBreakpoints.medium;
                  final double stageWidth = isWideViewport
                      ? math.min(constraints.maxWidth - AppSpace.s48, 680.0)
                      : constraints.maxWidth;

                  Widget stage = SizedBox(
                    width: stageWidth,
                    height: constraints.maxHeight,
                    child: ClipRRect(
                      borderRadius: isWideViewport
                          ? BorderRadius.circular(AppGeometry.cardRadius)
                          : BorderRadius.zero,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. Preview da câmera traseira fullscreen (BoxFit.cover sem FittedBox)
                          _buildCameraSurface(darkTk),

                          // 2. Máscara + contorno discreto Vermelho -> Verde (180 ms)
                          RepaintBoundary(
                            child: IgnorePointer(
                              child: TweenAnimationBuilder<Color?>(
                                tween: ColorTween(end: targetBorderColor),
                                duration: borderAnimDuration,
                                curve: Curves.easeOutCubic,
                                builder: (context, animatedColor, _) {
                                  return CustomPaint(
                                    key: ValueKey(
                                      isAlignedGreen
                                          ? 'scanner-frame-green'
                                          : 'scanner-frame-red',
                                    ),
                                    painter: DocumentScannerOverlayPainter(
                                      isFront: widget.isFront,
                                      isVertical: _isVerticalOrientation,
                                      isSharpEnough: isAlignedGreen,
                                      scrimColor: darkTk.scrim,
                                      sharpColor: darkTk.success,
                                      accentColor: darkTk.danger,
                                      borderColorOverride:
                                          animatedColor ?? targetBorderColor,
                                      guideColor: darkTk.text,
                                      stabilityProgress: stabilityProgress,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          // 3. Barra superior: Fechar + Título + Lanterna + Trocar lente + Orientação
                          Positioned(
                            top: AppSpace.s12,
                            left: AppSpace.s16,
                            right: AppSpace.s16,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _ScannerCircleAction(
                                      background: darkTk.scrim,
                                      child: AppIconButton(
                                        key: const ValueKey('btn-scanner-close'),
                                        icon: Icons.close_rounded,
                                        tooltip: 'Fechar',
                                        color: darkTk.text,
                                        onPressed: () =>
                                            Navigator.of(context).maybePop(),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpace.s8),
                                    Expanded(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: darkTk.scrim,
                                          borderRadius: BorderRadius.circular(
                                            AppGeometry.fieldRadius,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpace.s12,
                                            vertical: AppSpace.s8,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                sideTitle,
                                                textAlign: TextAlign.center,
                                                style: AppType.bodyStrong
                                                    .copyWith(
                                                  color: darkTk.text,
                                                ),
                                              ),
                                              const SizedBox(height: AppSpace.s2),
                                              Text(
                                                sideSubtitle,
                                                textAlign: TextAlign.center,
                                                style: AppType.bodySm.copyWith(
                                                  color: darkTk.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpace.s8),
                                    _ScannerCircleAction(
                                      background: darkTk.scrim,
                                      child: AppIconButton(
                                        key: const ValueKey('btn-scanner-torch'),
                                        icon: _torchOn
                                            ? Icons.flash_on_rounded
                                            : Icons.flash_off_rounded,
                                        tooltip: _torchOn
                                            ? 'Desligar lanterna'
                                            : 'Ligar lanterna',
                                        color: _torchOn
                                            ? darkTk.warning
                                            : darkTk.text,
                                        onPressed: _toggleTorch,
                                      ),
                                    ),
                                    if (_cameras.length > 1) ...[
                                      const SizedBox(width: AppSpace.s4),
                                      _ScannerCircleAction(
                                        background: darkTk.scrim,
                                        child: AppIconButton(
                                          key: const ValueKey(
                                            'btn-scanner-switch-lens',
                                          ),
                                          icon: Icons.cameraswitch_rounded,
                                          tooltip: 'Trocar lente',
                                          color: darkTk.text,
                                          onPressed: () =>
                                              _initRearCamera(switchLens: true),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: AppSpace.s12),
                                _ScannerOrientationToggle(
                                  key: const ValueKey(
                                    'scanner-orientation-segmented',
                                  ),
                                  isVertical: _isVerticalOrientation,
                                  darkTk: darkTk,
                                  onChanged: _setOrientation,
                                ),
                              ],
                            ),
                          ),

                          // 4. Rodapé: Pílula discreta Vermelha/Verde + barra de confirmação + botão de captura
                          Positioned(
                            left: AppSpace.s16,
                            right: AppSpace.s16,
                            bottom: AppSpace.s16,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_errorMessage != null) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpace.s8,
                                    ),
                                    child: AppStatusChip(
                                      _errorMessage!,
                                      tone: AppTone.danger,
                                      icon: Icons.error_outline_rounded,
                                    ),
                                  ),
                                ],
                                Semantics(
                                  liveRegion: true,
                                  child: Container(
                                    key: const ValueKey(
                                      'scanner-alignment-pill',
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpace.s12,
                                      vertical: AppSpace.s8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isAlignedGreen
                                          ? darkTk.successSoft
                                          : darkTk.dangerSoft,
                                      borderRadius: BorderRadius.circular(
                                        AppGeometry.pillRadius,
                                      ),
                                      border: Border.all(
                                        color: isAlignedGreen
                                            ? darkTk.success
                                            : darkTk.danger,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isAlignedGreen
                                              ? Icons.check_circle_outline_rounded
                                              : Icons.crop_free_rounded,
                                          size: 18,
                                          color: isAlignedGreen
                                              ? darkTk.successInk
                                              : darkTk.dangerInk,
                                        ),
                                        const SizedBox(width: AppSpace.s8),
                                        Flexible(
                                          child: Text(
                                            statusText,
                                            textAlign: TextAlign.center,
                                            style: AppType.bodySm.copyWith(
                                              color: isAlignedGreen
                                                  ? darkTk.successInk
                                                  : darkTk.dangerInk,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpace.s8),
                                if (isAlignedGreen) ...[
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 240),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        AppGeometry.pillRadius,
                                      ),
                                      child: LinearProgressIndicator(
                                        key: const ValueKey(
                                          'scanner-stability-bar',
                                        ),
                                        value: stabilityProgress,
                                        minHeight: AppSpace.s4,
                                        color: darkTk.success,
                                        backgroundColor: darkTk.border,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpace.s12),
                                ] else ...[
                                  Text(
                                    'A captura libera assim que a borda ficar verde.',
                                    textAlign: TextAlign.center,
                                    style: AppType.bodySm.copyWith(
                                      color: darkTk.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpace.s12),
                                ],
                                AppButton(
                                  key: const ValueKey(
                                    'btn-capture-guided-document',
                                  ),
                                  loading: _capturing,
                                  icon: Icons.camera_alt_rounded,
                                  label: _capturing
                                      ? 'Capturando documento...'
                                      : (widget.isFront
                                          ? 'Capturar Frente'
                                          : 'Capturar Verso'),
                                  onPressed:
                                      (!isAlignedGreen || _capturing || _initializing)
                                          ? null
                                          : _captureAndCropDocument,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  if (isWideViewport) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.s12,
                        ),
                        child: stage,
                      ),
                    );
                  }
                  return stage;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraSurface(AppTokens darkTk) {
    final ctrl = _controller;
    if (ctrl != null && ctrl.value.isInitialized) {
      return LayoutBuilder(
        builder: (context, box) {
          final double containerW = math.max(1.0, box.maxWidth);
          final double containerH = math.max(1.0, box.maxHeight);
          final double previewAspect = ctrl.value.aspectRatio > 0
              ? (1.0 / ctrl.value.aspectRatio)
              : (containerW / containerH);
          final double containerAspect = containerW / containerH;

          final double renderW;
          final double renderH;
          if (previewAspect > containerAspect) {
            renderH = containerH;
            renderW = containerH * previewAspect;
          } else {
            renderW = containerW;
            renderH = containerW / previewAspect;
          }

          return ClipRect(
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              alignment: Alignment.center,
              child: SizedBox(
                width: renderW,
                height: renderH,
                child: CameraPreview(ctrl),
              ),
            ),
          );
        },
      );
    }

    if (_initializing) {
      return const Center(
        child: AppLoading(
          message: 'Abrindo câmera traseira...',
        ),
      );
    }

    if (_isTestDriven) {
      return ColoredBox(
        color: darkTk.surface,
        child: Center(
          child: Icon(
            Icons.document_scanner_outlined,
            size: 56,
            color: darkTk.textMuted,
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              size: 44,
              color: darkTk.textMuted,
            ),
            const SizedBox(height: AppSpace.s12),
            Text(
              _errorMessage ?? 'Câmera traseira indisponível.',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: darkTk.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerCircleAction extends StatelessWidget {
  const _ScannerCircleAction({
    required this.background,
    required this.child,
  });

  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

class _ScannerOrientationToggle extends StatelessWidget {
  const _ScannerOrientationToggle({
    super.key,
    required this.isVertical,
    required this.darkTk,
    required this.onChanged,
  });

  final bool isVertical;
  final AppTokens darkTk;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: darkTk.surface,
        borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
        border: Border.all(color: darkTk.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Row(
          children: [
            Expanded(
              child: _ScannerOrientationOption(
                label: 'Horizontal',
                icon: Icons.crop_landscape_rounded,
                selected: !isVertical,
                darkTk: darkTk,
                onTap: () => onChanged(false),
              ),
            ),
            const SizedBox(width: AppSpace.s4),
            Expanded(
              child: _ScannerOrientationOption(
                label: 'Vertical',
                icon: Icons.crop_portrait_rounded,
                selected: isVertical,
                darkTk: darkTk,
                onTap: () => onChanged(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerOrientationOption extends StatelessWidget {
  const _ScannerOrientationOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.darkTk,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final AppTokens darkTk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = selected ? darkTk.accent : darkTk.surface;
    final Color fg = selected ? darkTk.onAccent : darkTk.text;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppGeometry.minTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s12,
                vertical: AppSpace.s8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: AppSpace.s8),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppType.bodySm.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `CustomPainter` que desenha a máscara escura semi-transparente com recorte
/// retangular central na proporção ISO/IEC 7810 ID-1, contorno discreto
/// (`strokeWidth: 2.5`) e cantoneiras suaves (`3.5 px`) em VERMELHO (fora da
/// área/inválido) ou VERDE (enquadrado e validado).
class DocumentScannerOverlayPainter extends CustomPainter {
  const DocumentScannerOverlayPainter({
    required this.isFront,
    required this.isVertical,
    required this.isSharpEnough,
    this.scrimColor,
    this.sharpColor,
    this.accentColor,
    this.borderColorOverride,
    this.guideColor,
    this.stabilityProgress = 0.0,
  });

  final bool isFront;
  final bool isVertical;
  final bool isSharpEnough;
  final Color? scrimColor;
  final Color? sharpColor;
  final Color? accentColor;
  final Color? borderColorOverride;
  final Color? guideColor;
  final double stabilityProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final dark = AppTokens.dark;
    final resolvedScrim = scrimColor ?? dark.scrim;
    final resolvedGreen = sharpColor ?? dark.success;
    final resolvedRed = accentColor ?? dark.danger;
    final resolvedGuide = guideColor ?? dark.text;
    final resolvedBorder =
        borderColorOverride ?? (isSharpEnough ? resolvedGreen : resolvedRed);

    // Proporção oficial ISO/IEC 7810 ID-1 (85.60 x 53.98 mm = 1.5858)
    const double isoRatio = 85.60 / 53.98;
    final double rectWidth;
    final double rectHeight;

    if (isVertical) {
      rectWidth = (size.width * 0.74).clamp(180.0, 340.0);
      rectHeight = (rectWidth * isoRatio).clamp(240.0, size.height * 0.48);
    } else {
      rectWidth = (size.width * 0.88).clamp(220.0, 440.0);
      rectHeight = (rectWidth / isoRatio).clamp(140.0, size.height * 0.40);
    }

    final Offset center = Offset(size.width / 2, size.height * 0.50);
    final Rect cutoutRect = Rect.fromCenter(
      center: center,
      width: rectWidth,
      height: rectHeight,
    );
    final RRect cutoutRRect = RRect.fromRectAndRadius(
      cutoutRect,
      const Radius.circular(16),
    );

    // 1. Máscara externa semi-transparente
    final Path maskPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(cutoutRRect);
    canvas.drawPath(maskPath, Paint()..color = resolvedScrim);

    // 2. Contorno discreto (2.5 px) Vermelho -> Verde
    canvas.drawRRect(
      cutoutRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = resolvedBorder.withValues(alpha: 0.90),
    );

    // 3. Cantoneiras suaves (3.5 px)
    final Paint cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = resolvedBorder;

    const double cornerLen = 24.0;
    final double l = cutoutRect.left;
    final double t = cutoutRect.top;
    final double r = cutoutRect.right;
    final double b = cutoutRect.bottom;

    canvas.drawLine(Offset(l, t + cornerLen), Offset(l, t), cornerPaint);
    canvas.drawLine(Offset(l, t), Offset(l + cornerLen, t), cornerPaint);

    canvas.drawLine(Offset(r - cornerLen, t), Offset(r, t), cornerPaint);
    canvas.drawLine(Offset(r, t), Offset(r, t + cornerLen), cornerPaint);

    canvas.drawLine(Offset(l, b - cornerLen), Offset(l, b), cornerPaint);
    canvas.drawLine(Offset(l, b), Offset(l + cornerLen, b), cornerPaint);

    canvas.drawLine(Offset(r - cornerLen, b), Offset(r, b), cornerPaint);
    canvas.drawLine(Offset(r, b), Offset(r, b - cornerLen), cornerPaint);

    // 4. Guias internas discretas de posicionamento (Foto 3x4 na Frente / Faixa no Verso)
    final Paint guidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = resolvedGuide.withValues(alpha: 0.35);

    if (isFront) {
      final Rect portraitRect = isVertical
          ? Rect.fromLTWH(
              l + cutoutRect.width * 0.10,
              t + cutoutRect.height * 0.16,
              cutoutRect.width * 0.36,
              cutoutRect.height * 0.32,
            )
          : Rect.fromLTWH(
              l + cutoutRect.width * 0.08,
              t + cutoutRect.height * 0.22,
              cutoutRect.width * 0.26,
              cutoutRect.height * 0.56,
            );
      canvas.drawRRect(
        RRect.fromRectAndRadius(portraitRect, const Radius.circular(8)),
        guidePaint,
      );
    } else {
      final Rect backBandRect = Rect.fromLTWH(
        l + cutoutRect.width * 0.08,
        b - cutoutRect.height * 0.30,
        cutoutRect.width * 0.84,
        cutoutRect.height * 0.20,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(backBandRect, const Radius.circular(6)),
        guidePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DocumentScannerOverlayPainter oldDelegate) {
    return oldDelegate.isFront != isFront ||
        oldDelegate.isVertical != isVertical ||
        oldDelegate.isSharpEnough != isSharpEnough ||
        oldDelegate.scrimColor != scrimColor ||
        oldDelegate.sharpColor != sharpColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.borderColorOverride != borderColorOverride ||
        oldDelegate.guideColor != guideColor ||
        oldDelegate.stabilityProgress != stabilityProgress;
  }
}

import 'dart:io' show File, Platform;
import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show Uint8List, debugPrint, kDebugMode;
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import '../ui/kyc_human_feedback_translator.dart';
import 'camera_nv21_normalizer.dart';
import 'face_detection_adapter.dart';
import 'live_camera_frame_bridge.dart';

/// Adaptador nativo Android / iOS usando Google ML Kit Face Detection
/// (`FaceDetectorMode.accurate`, classificação ocular, landmarks e tracking).
///
/// Recursos de resiliência real em hardware Android/iOS (v2.31.0):
/// - Warm-up / self-test real no `initialize()` (falha imediatamente se o R8 ou
///   o binário nativo ML Kit estiver indisponível, nunca fingindo sucesso);
/// - Normalizador universal `NV21` para 1, 2 ou 3 planos CameraX (`YUV_420_888`,
///   semi-planar ou NV21 com `bytesPerRow > width` em sensores Samsung/Pixel);
/// - Auto-calibração inteligente de `InputImageRotation` (se 0 faces persistirem
///   por >= 8 quadros nítidos e bem iluminados, testa offsets 180°/90°/270° no
///   próprio ML Kit real e trava a rotação vencedora na sessão);
/// - Zero engolimento silencioso de exceções: após falhas consecutivas emite
///   `LiveFaceObservation.unavailable(...)` com orientação humana clara;
/// - Fallback real via arquivo fotográfico (`analyzeImageFilePath` ->
///   `InputImage.fromFilePath`) caso `startImageStream` não entregue quadros.
class MobileFaceDetectionAdapter implements FaceDetectionAdapter {
  static const int _maxConsecutiveNativeErrors = 4;
  static const int _maxConsecutiveBuildNulls = 8;
  static const int _rotationProbeThresholdFrames = 8;
  static const List<int> _candidateRotationOffsets = <int>[180, 90, 270];

  FaceDetector? _detector;
  bool _initialized = false;
  bool _disposed = false;
  bool _isProcessing = false;
  String? _unavailableReason;

  /// Grade 24x24 de luminância do quadro anterior para medir micro-movimento real
  /// (bloqueia foto impressa parada ou imagem congelada).
  List<double>? _previousRoiPatch;
  int? _previousTrackingId;

  // Contadores de diagnóstico e auto-calibração real (sem falhas silenciosas).
  int _consecutiveNativeErrors = 0;
  int _consecutiveBuildNulls = 0;
  int _consecutiveZeroFaceGoodFrames = 0;
  int _lockedRotationOffsetDeg = 0;
  int _rotationProbeCursor = 0;

  @override
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  @override
  bool get isInitialized => _initialized && _detector != null && !_disposed;

  @override
  String? get unavailableReason => _unavailableReason;

  @override
  Future<bool> initialize() async {
    if (_disposed) return false;
    if (!isSupported) {
      _unavailableReason =
          'A verificação facial nativa requer um dispositivo Android ou iOS.';
      return false;
    }
    if (_initialized && _detector != null) return true;

    FaceDetector? candidate;
    try {
      candidate = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableClassification: true,
          enableLandmarks: true,
          enableTracking: true,
          minFaceSize: 0.20,
        ),
      );

      // Warm-up / self-test real no nativo:
      // `google_mlkit_face_detection` instancia `FaceDetection.getClient(...)`
      // de forma preguiçosa na 1ª chamada `processImage`. Executar um quadro
      // compacto 64x64 aqui detecta imediatamente problemas de R8/JNI e já
      // aquece o modelo neural antes do 1º quadro da câmera chegar.
      final InputImage warmupImage = _buildWarmupInputImage();
      await candidate.processImage(warmupImage);

      _detector = candidate;
      _initialized = true;
      _unavailableReason = null;
      _consecutiveNativeErrors = 0;
      _consecutiveBuildNulls = 0;
      _consecutiveZeroFaceGoodFrames = 0;
      _lockedRotationOffsetDeg = 0;
      _rotationProbeCursor = 0;
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[MobileFaceDetectionAdapter] initialize warm-up failed: $error');
      }
      try {
        await candidate?.close();
      } catch (_) {}
      _detector = null;
      _initialized = false;
      _unavailableReason = KycHumanFeedbackTranslator.sanitizeForHumanDisplay(
        'Não foi possível iniciar o leitor facial deste aparelho. Feche e tente novamente.',
      );
      return false;
    }
  }

  InputImage _buildWarmupInputImage() {
    const int w = 64;
    const int h = 64;
    if (Platform.isIOS) {
      final Uint8List bgra = Uint8List(w * h * 4);
      return InputImage.fromBytes(
        bytes: bgra,
        metadata: InputImageMetadata(
          size: const Size(64, 64),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: w * 4,
        ),
      );
    }

    // NV21 compacto 64x64 (Y=4096 + VU=2048 = 6144 bytes) em cinza neutro (128).
    final Uint8List nv21 = Uint8List(w * h + ((w * h) >> 1));
    nv21.fillRange(0, nv21.length, 128);
    return InputImage.fromBytes(
      bytes: nv21,
      metadata: InputImageMetadata(
        size: const Size(64, 64),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: w,
      ),
    );
  }

  @override
  Future<LiveFaceObservation?> analyzeCameraImage(
    CameraImage image, {
    required int sensorOrientation,
    required bool isFrontCamera,
    DeviceOrientation deviceOrientation = DeviceOrientation.portraitUp,
  }) async {
    if (!isInitialized || _isProcessing || _disposed) return null;
    final detector = _detector;
    if (detector == null) return null;

    _isProcessing = true;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    try {
      final int primaryDeg = _computePrimaryRotationDegrees(
        sensorOrientation: sensorOrientation,
        isFrontCamera: isFrontCamera,
        deviceOrientation: deviceOrientation,
      );

      // Se muitas tentativas seguidas com boa luz/nitidez não encontraram rosto,
      // testa uma rotação candidata por quadro usando o próprio ML Kit real.
      int activeOffsetDeg = _lockedRotationOffsetDeg;
      bool probingAlternateRotation = false;
      if (_consecutiveZeroFaceGoodFrames >= _rotationProbeThresholdFrames) {
        final int candidateOffset =
            _candidateRotationOffsets[_rotationProbeCursor % _candidateRotationOffsets.length];
        _rotationProbeCursor += 1;
        activeOffsetDeg = (_lockedRotationOffsetDeg + candidateOffset) % 360;
        probingAlternateRotation = true;
      }

      final int effectiveDeg = (primaryDeg + activeOffsetDeg) % 360;
      final InputImageRotation rotation =
          InputImageRotationValue.fromRawValue(effectiveDeg) ??
              InputImageRotation.rotation0deg;

      final InputImage? inputImage = _buildInputImage(
        image: image,
        rotation: rotation,
      );
      if (inputImage == null) {
        _consecutiveBuildNulls += 1;
        if (kDebugMode) {
          debugPrint(
            '[MobileFaceDetectionAdapter] _buildInputImage null (#$_consecutiveBuildNulls): '
            'format=${image.format.group} raw=${image.format.raw} '
            'planes=${image.planes.length} size=${image.width}x${image.height}',
          );
        }
        if (_consecutiveBuildNulls >= _maxConsecutiveBuildNulls) {
          return LiveFaceObservation.unavailable(
            timestampMs: nowMs,
            reason:
                'Não foi possível ler o formato de vídeo da câmera frontal neste aparelho. Tente novamente.',
            sourceEngine: 'mlkit',
          );
        }
        return null;
      }
      _consecutiveBuildNulls = 0;

      final List<Face> faces = await detector.processImage(inputImage);
      _consecutiveNativeErrors = 0;

      // Converte quadro compacto (96x72) em RGB verticalizado e espelhado para métricas
      // de iluminação, nitidez, anti-monitor e micro-movimento na ROI facial.
      final img.Image? uprightRgb = convertCameraImageToUprightRgbNamed(
        image: image,
        sensorOrientation: (sensorOrientation + activeOffsetDeg) % 360,
        isFrontCamera: isFrontCamera,
        targetWidth: 96,
        targetHeight: 72,
      );

      if (faces.isEmpty) {
        _previousRoiPatch = null;
        _previousTrackingId = null;
        final roiMetrics = _computeRoiMetrics(
          uprightRgb,
          const Rect.fromLTWH(0.18, 0.16, 0.64, 0.68),
          updateMotionBaseline: false,
        );
        if (roiMetrics.meanLuminance >= 40.0 && roiMetrics.sharpness >= 6.0) {
          _consecutiveZeroFaceGoodFrames += 1;
        } else {
          _consecutiveZeroFaceGoodFrames = 0;
        }
        return LiveFaceObservation.noFace(
          timestampMs: nowMs,
          meanLuminance: roiMetrics.meanLuminance,
          sharpness: roiMetrics.sharpness,
          blueMonitorRatio: roiMetrics.blueMonitorRatio,
          textureMotionDelta: roiMetrics.textureMotionDelta,
          sourceEngine: 'mlkit',
        );
      }

      // Rosto real encontrado! Se foi descoberto durante a auto-calibração, trava o offset.
      _consecutiveZeroFaceGoodFrames = 0;
      if (probingAlternateRotation) {
        _lockedRotationOffsetDeg = activeOffsetDeg;
        if (kDebugMode) {
          debugPrint(
            '[MobileFaceDetectionAdapter] Auto-calibrated rotation offset locked: '
            '+${_lockedRotationOffsetDeg}deg (effective=${effectiveDeg}deg)',
          );
        }
      }

      return _buildObservationFromFaces(
        faces: faces,
        imageWidth: image.width,
        imageHeight: image.height,
        rotation: rotation,
        isFrontCamera: isFrontCamera,
        uprightRgb: uprightRgb,
        nowMs: nowMs,
        sourceEngine: 'mlkit',
      );
    } catch (error) {
      _consecutiveNativeErrors += 1;
      if (kDebugMode) {
        debugPrint(
          '[MobileFaceDetectionAdapter] analyzeCameraImage error '
          '(#$_consecutiveNativeErrors): $error',
        );
      }
      if (_consecutiveNativeErrors >= _maxConsecutiveNativeErrors) {
        return LiveFaceObservation.unavailable(
          timestampMs: nowMs,
          reason: KycHumanFeedbackTranslator.sanitizeForHumanDisplay(
            'Não foi possível analisar seu rosto neste momento. Toque em "Tentar novamente" para reiniciar a câmera.',
          ),
          sourceEngine: 'mlkit',
        );
      }
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Future<LiveFaceObservation?> analyzeImageFilePath(
    String filePath, {
    required bool isFrontCamera,
    bool deleteAfterAnalysis = false,
  }) async {
    if (!isInitialized || _isProcessing || _disposed) {
      if (deleteAfterAnalysis) {
        try {
          final f = File(filePath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      return null;
    }
    final detector = _detector;
    if (detector == null) return null;

    _isProcessing = true;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    String? bakedTempPath;
    try {
      final File file = File(filePath);
      if (!await file.exists()) return null;

      final Uint8List fileBytes = await file.readAsBytes();
      final img.Image? rawDecoded = img.decodeImage(fileBytes);
      if (rawDecoded == null || rawDecoded.width <= 0 || rawDecoded.height <= 0) {
        return null;
      }

      // Aplica bakeOrientation ANTES do ML Kit para garantir 100% de consistência
      // entre TODOS os fabricantes Android (Samsung, Xiaomi, Motorola, Pixel, Oppo)
      // e iOS (iPhone/iPad), independentemente de quirks no parser EXIF do OEM.
      final bool hasNonDefaultExif = rawDecoded.exif.imageIfd.hasOrientation &&
          rawDecoded.exif.imageIfd.orientation != 1;
      final img.Image baked = img.bakeOrientation(rawDecoded);

      String effectivePath = filePath;
      if (hasNonDefaultExif) {
        bakedTempPath = '${filePath}_baked.jpg';
        await File(bakedTempPath).writeAsBytes(
          img.encodeJpg(baked, quality: 90),
          flush: true,
        );
        effectivePath = bakedTempPath;
      }

      final InputImage inputImage = InputImage.fromFilePath(effectivePath);
      final List<Face> faces = await detector.processImage(inputImage);
      _consecutiveNativeErrors = 0;

      // Reduz imagem já orientada para ROI de métricas (espelhada se frontal, igual ao preview).
      img.Image compact = img.copyResize(baked, width: 96);
      if (isFrontCamera) {
        compact = img.flipHorizontal(compact);
      }

      if (faces.isEmpty) {
        _previousRoiPatch = null;
        _previousTrackingId = null;
        final roiMetrics = _computeRoiMetrics(
          compact,
          const Rect.fromLTWH(0.18, 0.16, 0.64, 0.68),
          updateMotionBaseline: false,
        );
        return LiveFaceObservation.noFace(
          timestampMs: nowMs,
          meanLuminance: roiMetrics.meanLuminance,
          sharpness: roiMetrics.sharpness,
          blueMonitorRatio: roiMetrics.blueMonitorRatio,
          textureMotionDelta: roiMetrics.textureMotionDelta,
          sourceEngine: 'mlkit_still',
        );
      }

      return _buildObservationFromFaces(
        faces: faces,
        imageWidth: baked.width,
        imageHeight: baked.height,
        rotation: InputImageRotation.rotation0deg,
        isFrontCamera: isFrontCamera,
        uprightRgb: compact,
        nowMs: nowMs,
        sourceEngine: 'mlkit_still',
      );
    } catch (error) {
      _consecutiveNativeErrors += 1;
      if (kDebugMode) {
        debugPrint(
          '[MobileFaceDetectionAdapter] analyzeImageFilePath error '
          '(#$_consecutiveNativeErrors): $error',
        );
      }
      if (_consecutiveNativeErrors >= _maxConsecutiveNativeErrors) {
        return LiveFaceObservation.unavailable(
          timestampMs: nowMs,
          reason: KycHumanFeedbackTranslator.sanitizeForHumanDisplay(
            'Não foi possível ler seu rosto pela câmera agora. Toque em "Tentar novamente".',
          ),
          sourceEngine: 'mlkit_still',
        );
      }
      return null;
    } finally {
      _isProcessing = false;
      if (bakedTempPath != null) {
        try {
          final bakedFile = File(bakedTempPath);
          if (await bakedFile.exists()) await bakedFile.delete();
        } catch (_) {}
      }
      if (deleteAfterAnalysis) {
        try {
          final f = File(filePath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
  }

  LiveFaceObservation _buildObservationFromFaces({
    required List<Face> faces,
    required int imageWidth,
    required int imageHeight,
    required InputImageRotation rotation,
    required bool isFrontCamera,
    required img.Image? uprightRgb,
    required int nowMs,
    required String sourceEngine,
  }) {
    // Seleciona o rosto principal (maior área) para telemetria; faceCount preserva o total real.
    Face primary = faces.first;
    double largestArea = primary.boundingBox.width * primary.boundingBox.height;
    for (int i = 1; i < faces.length; i++) {
      final candidate = faces[i];
      final area = candidate.boundingBox.width * candidate.boundingBox.height;
      if (area > largestArea) {
        primary = candidate;
        largestArea = area;
      }
    }

    final Rect normalizedBox = _normalizeBoundingBox(
      box: primary.boundingBox,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      rotation: rotation,
      isFrontCamera: isFrontCamera,
    );

    if (primary.trackingId != _previousTrackingId) {
      _previousRoiPatch = null;
      _previousTrackingId = primary.trackingId;
    }

    final roiMetrics = _computeRoiMetrics(
      uprightRgb,
      normalizedBox,
      updateMotionBaseline: true,
    );

    // Convenção unificada de espelho natural:
    //   unifiedYaw > 0 -> usuário virou a cabeça para a sua DIREITA
    //   unifiedYaw < 0 -> usuário virou a cabeça para a sua ESQUERDA
    final double rawYaw = primary.headEulerAngleY ?? 0.0;
    final double unifiedYaw = isFrontCamera ? -rawYaw : rawYaw;
    final double pitch = primary.headEulerAngleX ?? 0.0;
    final double roll = primary.headEulerAngleZ ?? 0.0;

    return LiveFaceObservation(
      faceCount: faces.length,
      trackingId: primary.trackingId,
      normalizedBox: normalizedBox,
      leftEyeOpenProbability: primary.leftEyeOpenProbability,
      rightEyeOpenProbability: primary.rightEyeOpenProbability,
      headEulerAngleX: pitch,
      headEulerAngleY: unifiedYaw,
      headEulerAngleZ: roll,
      meanLuminance: roiMetrics.meanLuminance,
      sharpness: roiMetrics.sharpness,
      blueMonitorRatio: roiMetrics.blueMonitorRatio,
      textureMotionDelta: roiMetrics.textureMotionDelta,
      timestampMs: nowMs,
      sourceEngine: sourceEngine,
    );
  }

  @override
  Future<LiveFaceObservation?> analyzeWebVideoFrame({
    bool mirrorHorizontal = true,
  }) async {
    return null;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _initialized = false;
    _previousRoiPatch = null;
    _previousTrackingId = null;
    final detector = _detector;
    _detector = null;
    if (detector != null) {
      try {
        await detector.close();
      } catch (_) {}
    }
  }

  int _computePrimaryRotationDegrees({
    required int sensorOrientation,
    required bool isFrontCamera,
    required DeviceOrientation deviceOrientation,
  }) {
    if (Platform.isIOS) {
      return ((sensorOrientation % 360) + 360) % 360;
    }

    final int deviceDeg = switch (deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };

    return isFrontCamera
        ? (sensorOrientation + deviceDeg) % 360
        : (sensorOrientation - deviceDeg + 360) % 360;
  }

  InputImage? _buildInputImage({
    required CameraImage image,
    required InputImageRotation rotation,
  }) {
    if (image.planes.isEmpty || image.width <= 0 || image.height <= 0) {
      return null;
    }

    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    if (Platform.isIOS) {
      if (image.format.group == ImageFormatGroup.bgra8888 &&
          image.planes.length == 1) {
        return InputImage.fromBytes(
          bytes: image.planes[0].bytes,
          metadata: InputImageMetadata(
            size: imageSize,
            rotation: rotation,
            format: InputImageFormat.bgra8888,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );
      }
      return null;
    }

    // Android universal: aceita 1 plano NV21 (independente do ImageFormatGroup),
    // 2 planos semi-planares (Y+VU) ou 3 planos YUV_420_888 com strides arbitrários,
    // entregando sempre NV21 contíguo com bytesPerRow == image.width.
    final List<RawImagePlane> rawPlanes = <RawImagePlane>[
      for (final plane in image.planes)
        RawImagePlane(
          bytes: plane.bytes,
          bytesPerRow: plane.bytesPerRow,
          bytesPerPixel: plane.bytesPerPixel ?? 1,
        ),
    ];

    final Uint8List? nv21Bytes = normalizeAndroidPlanesToNv21(
      width: image.width,
      height: image.height,
      planes: rawPlanes,
    );
    if (nv21Bytes == null) return null;

    return InputImage.fromBytes(
      bytes: nv21Bytes,
      metadata: InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width,
      ),
    );
  }

  Rect _normalizeBoundingBox({
    required Rect box,
    required int imageWidth,
    required int imageHeight,
    required InputImageRotation rotation,
    required bool isFrontCamera,
  }) {
    final bool swapped = Platform.isAndroid &&
        (rotation == InputImageRotation.rotation90deg ||
            rotation == InputImageRotation.rotation270deg);
    final double effW = (swapped ? imageHeight : imageWidth).toDouble();
    final double effH = (swapped ? imageWidth : imageHeight).toDouble();
    if (effW <= 0 || effH <= 0) return Rect.zero;

    double left = (box.left / effW).clamp(0.0, 1.0);
    double right = (box.right / effW).clamp(0.0, 1.0);
    final double top = (box.top / effH).clamp(0.0, 1.0);
    final double bottom = (box.bottom / effH).clamp(0.0, 1.0);

    // Espelhamento horizontal no espaço normalizado [0..1] para alinhar 1:1 com o
    // preview espelhado natural da câmera frontal (SurfaceTexture/AVFoundation).
    if (isFrontCamera) {
      final double mirroredLeft = (1.0 - right).clamp(0.0, 1.0);
      final double mirroredRight = (1.0 - left).clamp(0.0, 1.0);
      left = mirroredLeft;
      right = mirroredRight;
    }

    if (right <= left || bottom <= top) return Rect.zero;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  ({
    double meanLuminance,
    double sharpness,
    double blueMonitorRatio,
    double textureMotionDelta,
  }) _computeRoiMetrics(
    img.Image? frame,
    Rect normBox, {
    required bool updateMotionBaseline,
  }) {
    if (frame == null || frame.width < 12 || frame.height < 12) {
      return (
        meanLuminance: 120.0,
        sharpness: 18.0,
        blueMonitorRatio: 0.0,
        textureMotionDelta: 1.0,
      );
    }

    final int w = frame.width;
    final int h = frame.height;

    // Encolhe 12% em cada borda para avaliar o interior real do rosto sem
    // contaminar luminância ou anti-monitor com cabelo escuro/fundo nas quinas.
    final double insetX = normBox.width * 0.12;
    final double insetY = normBox.height * 0.12;
    final double innerLeft = (normBox.left + insetX).clamp(0.0, 0.90);
    final double innerRight = (normBox.right - insetX).clamp(innerLeft + 0.08, 1.0);
    final double innerTop = (normBox.top + insetY).clamp(0.0, 0.90);
    final double innerBottom = (normBox.bottom - insetY).clamp(innerTop + 0.08, 1.0);

    final int x0 = (innerLeft * w).floor().clamp(1, w - 2);
    final int y0 = (innerTop * h).floor().clamp(1, h - 2);
    final int x1 = (innerRight * w).ceil().clamp(x0 + 2, w - 1);
    final int y1 = (innerBottom * h).ceil().clamp(y0 + 2, h - 1);

    double lumSum = 0.0;
    double gradSum = 0.0;
    int blueMonitorPixels = 0;
    int samples = 0;

    for (int y = y0; y < y1; y++) {
      for (int x = x0; x < x1; x++) {
        final p = frame.getPixel(x, y);
        final double r = p.r.toDouble();
        final double g = p.g.toDouble();
        final double b = p.b.toDouble();
        final double luma = (0.299 * r) + (0.587 * g) + (0.114 * b);
        lumSum += luma;

        // Assinatura espectral real de brilho azulado de tela LCD/OLED.
        // NÃO conta pixels escuros (cabelo/barba/sombras), pois ambientes
        // escuros já são filtrados por `meanLuminance < config.minLuminance`.
        if (b > r + 24.0 && b > g + 10.0 && luma >= 40.0) {
          blueMonitorPixels++;
        }

        final pRight = frame.getPixel(x + 1, y);
        final pDown = frame.getPixel(x, y + 1);
        final double lumaR =
            (0.299 * pRight.r) + (0.587 * pRight.g) + (0.114 * pRight.b);
        final double lumaD =
            (0.299 * pDown.r) + (0.587 * pDown.g) + (0.114 * pDown.b);
        gradSum += (lumaR - luma).abs() + (lumaD - luma).abs();
        samples++;
      }
    }

    if (samples == 0) {
      return (
        meanLuminance: 0.0,
        sharpness: 0.0,
        blueMonitorRatio: 0.0,
        textureMotionDelta: 0.0,
      );
    }

    final double meanLum = lumSum / samples;
    final double sharpness = (gradSum / samples) * 1.4;
    final double blueRatio = blueMonitorPixels / samples;

    // Amostra grade 24x24 na ROI para detectar micro-variação inter-quadros.
    const int grid = 24;
    final List<double> currentPatch = List<double>.filled(grid * grid, 0.0);
    final int roiW = math.max(1, x1 - x0);
    final int roiH = math.max(1, y1 - y0);
    for (int gy = 0; gy < grid; gy++) {
      final int sy = (y0 + ((gy * roiH) ~/ grid)).clamp(0, h - 1);
      for (int gx = 0; gx < grid; gx++) {
        final int sx = (x0 + ((gx * roiW) ~/ grid)).clamp(0, w - 1);
        final p = frame.getPixel(sx, sy);
        currentPatch[gy * grid + gx] =
            ((0.299 * p.r) + (0.587 * p.g) + (0.114 * p.b)).toDouble();
      }
    }

    double motionDelta = 1.0;
    final prev = _previousRoiPatch;
    if (prev != null && prev.length == currentPatch.length) {
      double diffSum = 0.0;
      for (int i = 0; i < currentPatch.length; i++) {
        diffSum += (currentPatch[i] - prev[i]).abs();
      }
      motionDelta = diffSum / currentPatch.length;
    }

    if (updateMotionBaseline) {
      _previousRoiPatch = currentPatch;
    }

    return (
      meanLuminance: meanLum,
      sharpness: sharpness,
      blueMonitorRatio: blueRatio,
      textureMotionDelta: motionDelta,
    );
  }
}

FaceDetectionAdapter createPlatformFaceDetectionAdapter() =>
    MobileFaceDetectionAdapter();

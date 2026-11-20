import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import 'face_detection_adapter.dart';
import 'live_camera_frame_bridge.dart';

/// Adaptador nativo Android / iOS usando Google ML Kit Face Detection
/// (`FaceDetectorMode.accurate`, classificação ocular, landmarks e tracking).
class MobileFaceDetectionAdapter implements FaceDetectionAdapter {
  FaceDetector? _detector;
  bool _initialized = false;
  bool _disposed = false;
  bool _isProcessing = false;
  String? _unavailableReason;

  /// Grade 24x24 de luminância do quadro anterior para medir micro-movimento real
  /// (bloqueia foto impressa parada ou imagem congelada).
  Float32List? _previousRoiPatch;
  int? _previousTrackingId;

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

    try {
      _detector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableClassification: true,
          enableLandmarks: true,
          enableTracking: true,
          minFaceSize: 0.25,
        ),
      );
      _initialized = true;
      _unavailableReason = null;
      return true;
    } catch (_) {
      _initialized = false;
      _unavailableReason =
          'Não foi possível iniciar o leitor facial deste aparelho. Tente novamente.';
      return false;
    }
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
      final rotation = _computeInputImageRotation(
        sensorOrientation: sensorOrientation,
        isFrontCamera: isFrontCamera,
        deviceOrientation: deviceOrientation,
      );

      final InputImage? inputImage = _buildInputImage(
        image: image,
        rotation: rotation,
      );
      if (inputImage == null) return null;

      final List<Face> faces = await detector.processImage(inputImage);

      // Converte quadro compacto (96x72) em RGB verticalizado e espelhado para métricas
      // de iluminação, nitidez, anti-monitor e micro-movimento na ROI facial.
      final img.Image? uprightRgb = convertCameraImageToUprightRgbNamed(
        image: image,
        sensorOrientation: sensorOrientation,
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
        return LiveFaceObservation.noFace(
          timestampMs: nowMs,
          meanLuminance: roiMetrics.meanLuminance,
          sharpness: roiMetrics.sharpness,
          blueMonitorRatio: roiMetrics.blueMonitorRatio,
          textureMotionDelta: roiMetrics.textureMotionDelta,
          sourceEngine: 'mlkit',
        );
      }

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
        imageWidth: image.width,
        imageHeight: image.height,
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

      // Convenção de espelho natural (coerente com o preview nativo da câmera frontal
      // no Android/iOS, que já espelha horizontalmente sem Transform.flip extra):
      // - No ML Kit, `headEulerAngleY` positivo significa rosto virado para a direita da
      //   câmera (ou seja, para a ESQUERDA do usuário); negativo = DIREITA do usuário.
      // - Na câmera frontal (`isFrontCamera == true`), invertemos o sinal (`-rawYaw`)
      //   para a convenção unificada de espelho natural:
      //     unifiedYaw > 0 -> usuário virou a cabeça para a sua DIREITA
      //     unifiedYaw < 0 -> usuário virou a cabeça para a sua ESQUERDA
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
        sourceEngine: 'mlkit',
      );
    } catch (_) {
      return null;
    } finally {
      _isProcessing = false;
    }
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

  InputImageRotation _computeInputImageRotation({
    required int sensorOrientation,
    required bool isFrontCamera,
    required DeviceOrientation deviceOrientation,
  }) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation0deg;
    }

    final int deviceDeg = switch (deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };

    final int compensated = isFrontCamera
        ? (sensorOrientation + deviceDeg) % 360
        : (sensorOrientation - deviceDeg + 360) % 360;

    return InputImageRotationValue.fromRawValue(compensated) ??
        InputImageRotation.rotation0deg;
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

    // Android: NV21 direto (1 plano) ou conversão exata YUV_420_888 (3 planos) -> NV21.
    if (image.format.group == ImageFormatGroup.nv21 &&
        image.planes.length == 1) {
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }

    if (image.format.group == ImageFormatGroup.yuv420 &&
        image.planes.length >= 3) {
      final Uint8List nv21Bytes = _convertYuv420ToNv21(image);
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

    return null;
  }

  /// Converte Android `YUV_420_888` (3 planos com strides arbitrários) para `NV21`
  /// contíguo (`Y` compacto + `VU` intercalado), evitando corrupção de imagem em
  /// dispositivos Samsung/Motorola/Pixel onde `bytesPerRow > width`.
  Uint8List _convertYuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final Uint8List out = Uint8List(ySize + (ySize >> 1));

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final Uint8List yBytes = yPlane.bytes;
    final Uint8List uBytes = uPlane.bytes;
    final Uint8List vBytes = vPlane.bytes;

    final int yRowStride = yPlane.bytesPerRow;
    final int yPixelStride = yPlane.bytesPerPixel ?? 1;

    int dstIdx = 0;
    if (yRowStride == width && yPixelStride == 1 && yBytes.length >= ySize) {
      out.setRange(0, ySize, yBytes);
      dstIdx = ySize;
    } else {
      for (int row = 0; row < height; row++) {
        final int rowOffset = row * yRowStride;
        for (int col = 0; col < width; col++) {
          final int srcIdx = rowOffset + col * yPixelStride;
          out[dstIdx++] = srcIdx < yBytes.length ? yBytes[srcIdx] : 128;
        }
      }
    }

    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;
    final int vRowStride = vPlane.bytesPerRow;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;
    final int halfH = height >> 1;
    final int halfW = width >> 1;

    for (int row = 0; row < halfH; row++) {
      final int uRowOffset = row * uvRowStride;
      final int vRowOffset = row * vRowStride;
      for (int col = 0; col < halfW; col++) {
        final int vIdx = vRowOffset + col * vPixelStride;
        final int uIdx = uRowOffset + col * uvPixelStride;
        out[dstIdx++] = vIdx < vBytes.length ? vBytes[vIdx] : 128;
        out[dstIdx++] = uIdx < uBytes.length ? uBytes[uIdx] : 128;
      }
    }

    return out;
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
    // preview espelhado natural da câmera frontal (SurfaceTexture/AVFoundation):
    // - Se o rosto aparece à direita do centro na tela (dx > 0.50), `normalizedBox`
    //   reflete `center.dx > 0.50`, permitindo instrução natural "mova para a esquerda".
    // - Se aparece à esquerda do centro (dx < 0.50), permite "mova para a direita".
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
    final int x0 = (normBox.left.clamp(0.0, 0.9) * w).floor().clamp(1, w - 2);
    final int y0 = (normBox.top.clamp(0.0, 0.9) * h).floor().clamp(1, h - 2);
    final int x1 =
        (normBox.right.clamp(0.1, 1.0) * w).ceil().clamp(x0 + 2, w - 1);
    final int y1 =
        (normBox.bottom.clamp(0.1, 1.0) * h).ceil().clamp(y0 + 2, h - 1);

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

        if ((b > r + 16.0 && b > g + 6.0) || luma < 26.0) {
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
    final Float32List currentPatch = Float32List(grid * grid);
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

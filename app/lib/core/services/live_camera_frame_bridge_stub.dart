import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Converte um [CameraImage] nativo (Android YUV420 / NV21 ou iOS BGRA8888)
/// em uma imagem [img.Image] RGB reduzida (`targetWidth` x `targetHeight`) e
/// devidamente rotacionada conforme [sensorOrientation] (ex.: 270° na câmera frontal Samsung).
img.Image? convertCameraImageToUprightRgb([
  CameraImage? positionalCameraImage,
  int? positionalSensorOrientation,
  bool? positionalIsFrontCamera,
  int targetWidth = 160,
  int targetHeight = 120,
]) {
  return convertCameraImageToUprightRgbNamed(
    image: positionalCameraImage,
    sensorOrientation: positionalSensorOrientation ?? 0,
    isFrontCamera: positionalIsFrontCamera ?? true,
    targetWidth: targetWidth,
    targetHeight: targetHeight,
  );
}

img.Image? convertCameraImageToUprightRgbNamed({
  CameraImage? image,
  required int sensorOrientation,
  required bool isFrontCamera,
  int targetWidth = 160,
  int targetHeight = 120,
  int? targetMaxDimension,
}) {
  final cameraImage = image;
  if (cameraImage == null) return null;
  final effectiveW = targetMaxDimension ?? targetWidth;
  final effectiveH = targetMaxDimension != null
      ? ((targetMaxDimension * 3) ~/ 4)
      : targetHeight;
  try {
    final int srcW = cameraImage.width;
    final int srcH = cameraImage.height;
    if (srcW <= 0 || srcH <= 0 || cameraImage.planes.isEmpty) return null;

    final img.Image rawSampled = img.Image(width: effectiveW, height: effectiveH);
    final planes = cameraImage.planes;

    if (planes.length == 1 && cameraImage.format.group == ImageFormatGroup.bgra8888) {
      // iOS BGRA8888
      final Uint8List bytes = planes[0].bytes;
      final int rowStride = planes[0].bytesPerRow;
      for (int ty = 0; ty < effectiveH; ty++) {
        final int sy = (ty * srcH) ~/ effectiveH;
        for (int tx = 0; tx < effectiveW; tx++) {
          final int sx = (tx * srcW) ~/ effectiveW;
          final int offset = sy * rowStride + sx * 4;
          if (offset + 2 < bytes.length) {
            final int b = bytes[offset];
            final int g = bytes[offset + 1];
            final int r = bytes[offset + 2];
            rawSampled.setPixelRgb(tx, ty, r, g, b);
          }
        }
      }
    } else {
      // Android YUV_420_888 ou NV21
      final Plane yPlane = planes[0];
      final Uint8List yBytes = yPlane.bytes;
      final int yRowStride = yPlane.bytesPerRow;
      final int yPixelStride = yPlane.bytesPerPixel ?? 1;

      final bool hasUvPlanes = planes.length >= 3;
      final Uint8List? uBytes =
          hasUvPlanes ? planes[1].bytes : (planes.length == 2 ? planes[1].bytes : null);
      final Uint8List? vBytes =
          hasUvPlanes ? planes[2].bytes : (planes.length == 2 ? planes[1].bytes : null);
      final int uvRowStride = hasUvPlanes
          ? planes[1].bytesPerRow
          : (planes.length == 2 ? planes[1].bytesPerRow : 0);
      final int uvPixelStride = hasUvPlanes ? (planes[1].bytesPerPixel ?? 1) : 2;

      for (int ty = 0; ty < effectiveH; ty++) {
        final int sy = (ty * srcH) ~/ effectiveH;
        final int uvy = sy >> 1;
        for (int tx = 0; tx < effectiveW; tx++) {
          final int sx = (tx * srcW) ~/ effectiveW;
          final int uvx = sx >> 1;

          final int yIdx = sy * yRowStride + sx * yPixelStride;
          final int yVal = yIdx < yBytes.length ? yBytes[yIdx] : 128;

          int uVal = 128;
          int vVal = 128;
          if (uBytes != null && vBytes != null) {
            final int uvIdx = uvy * uvRowStride + uvx * uvPixelStride;
            if (hasUvPlanes) {
              if (uvIdx < uBytes.length) uVal = uBytes[uvIdx];
              if (uvIdx < vBytes.length) vVal = vBytes[uvIdx];
            } else if (uvIdx + 1 < uBytes.length) {
              // NV21 interleave (V, U)
              vVal = uBytes[uvIdx];
              uVal = uBytes[uvIdx + 1];
            }
          }

          final int c = yVal - 16;
          final int d = uVal - 128;
          final int e = vVal - 128;
          final int r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
          final int g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
          final int b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);
          rawSampled.setPixelRgb(tx, ty, r, g, b);
        }
      }
    }

    img.Image upright = rawSampled;
    final int normAngle = ((sensorOrientation % 360) + 360) % 360;
    if (normAngle == 90 || normAngle == 270) {
      upright = img.copyRotate(rawSampled, angle: normAngle);
    } else if (normAngle == 180) {
      upright = img.copyRotate(rawSampled, angle: 180);
    }

    if (isFrontCamera) {
      upright = img.flipHorizontal(upright);
    }
    return upright;
  } catch (_) {
    return null;
  }
}

/// Na plataforma nativa (Android/iOS), o controle de facingMode é feito diretamente via
/// `CameraDescription.lensDirection`.
Future<bool> ensureWebVideoFacingMode({required bool frontCamera}) async {
  return false;
}

/// Na plataforma nativa, a captura de quadros em tempo real usa `CameraController.startImageStream`.
Future<Uint8List?> grabWebVideoFramePngBytes({
  int width = 160,
  int height = 120,
  int? maxWidth,
  int? maxHeight,
  bool mirrorHorizontal = false,
}) async {
  return null;
}

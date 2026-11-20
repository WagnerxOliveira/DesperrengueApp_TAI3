import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;

/// Descritor puro de um plano bruto de imagem de câmera (independente de
/// `Platform` / `CameraImage`, permitindo cobertura total em testes unitários).
@immutable
class RawImagePlane {
  const RawImagePlane({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel = 1,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;
}

/// Normaliza qualquer layout de planos entregue pela câmera Android (`CameraX`
/// `YUV_420_888` de 3 planos com row-stride/pixel-stride arbitrários, semi-planar
/// de 2 planos `Y+VU` ou `NV21` de 1 plano contíguo/padded) para um buffer
/// **`NV21` compacto e contíguo** de tamanho exato `width * height + (width~/2)*(height~/2)*2`
/// (`bytesPerRow == width`), exigido pelo Google ML Kit `InputImage.fromBytes`.
///
/// Resolve:
/// - padding de linha (`bytesPerRow > width`) em sensores Samsung Exynos/Snapdragon,
///   Motorola e Pixel;
/// - buffer superdimensionado (`bytes.length > expectedSize`) gerado pelo
///   `ImageProxyUtils.planesToNV21` do `camera_android_camerax`;
/// - divergências entre `ImageFormatGroup` reportado e quantidade real de planos.
///
/// Retorna `null` somente se as dimensões ou os bytes forem insuficientes/corrompidos.
Uint8List? normalizeAndroidPlanesToNv21({
  required int width,
  required int height,
  required List<RawImagePlane> planes,
}) {
  if (width <= 0 || height <= 0 || planes.isEmpty) {
    return null;
  }

  final int halfW = width >> 1;
  final int halfH = height >> 1;
  if (halfW <= 0 || halfH <= 0) {
    return null;
  }

  final int ySize = width * height;
  final int uvRowBytes = halfW * 2;
  final int uvSize = uvRowBytes * halfH;
  final int expectedSize = ySize + uvSize;

  // Caso 1: 1 plano (NV21 contíguo, NV21 com trailing padding ou NV21 com row-padding).
  if (planes.length == 1) {
    final RawImagePlane plane = planes[0];
    final Uint8List src = plane.bytes;
    final int rowStride = plane.bytesPerRow <= 0 ? width : plane.bytesPerRow;

    if (rowStride <= width) {
      if (src.length < expectedSize) return null;
      if (src.length == expectedSize) return src;
      return Uint8List.sublistView(src, 0, expectedSize);
    }

    // Remove row padding (bytesPerRow > width) linha a linha em Y e VU.
    final int yPlaneOffset = rowStride * height;
    final int minRequiredWithStride =
        yPlaneOffset + rowStride * (halfH - 1) + uvRowBytes;
    if (src.length < minRequiredWithStride) {
      // Fallback: alguns drivers reportam bytesPerRow maior mas entregam buffer compacto.
      if (src.length >= expectedSize) {
        return src.length == expectedSize
            ? src
            : Uint8List.sublistView(src, 0, expectedSize);
      }
      return null;
    }

    final Uint8List out = Uint8List(expectedSize);
    int dst = 0;
    for (int row = 0; row < height; row++) {
      final int srcStart = row * rowStride;
      out.setRange(dst, dst + width, src, srcStart);
      dst += width;
    }
    for (int row = 0; row < halfH; row++) {
      final int srcStart = yPlaneOffset + row * rowStride;
      out.setRange(dst, dst + uvRowBytes, src, srcStart);
      dst += uvRowBytes;
    }
    return out;
  }

  // Caso 2: 2 planos semi-planares (Y + VU intercalado).
  if (planes.length == 2) {
    final RawImagePlane yPlane = planes[0];
    final RawImagePlane vuPlane = planes[1];
    final int yRowStride = yPlane.bytesPerRow <= 0 ? width : yPlane.bytesPerRow;
    final int yPixelStride = yPlane.bytesPerPixel <= 0 ? 1 : yPlane.bytesPerPixel;
    final int vuRowStride =
        vuPlane.bytesPerRow <= 0 ? uvRowBytes : vuPlane.bytesPerRow;

    final int minYRequired = (height - 1) * yRowStride + (width - 1) * yPixelStride + 1;
    final int minVuRequired = (halfH - 1) * vuRowStride + uvRowBytes;
    if (yPlane.bytes.length < minYRequired || vuPlane.bytes.length < minVuRequired) {
      return null;
    }

    final Uint8List out = Uint8List(expectedSize);
    int dst = 0;
    if (yRowStride == width && yPixelStride == 1) {
      out.setRange(0, ySize, yPlane.bytes, 0);
      dst = ySize;
    } else {
      for (int row = 0; row < height; row++) {
        final int rowOffset = row * yRowStride;
        if (yPixelStride == 1) {
          out.setRange(dst, dst + width, yPlane.bytes, rowOffset);
          dst += width;
        } else {
          for (int col = 0; col < width; col++) {
            out[dst++] = yPlane.bytes[rowOffset + col * yPixelStride];
          }
        }
      }
    }

    if (vuRowStride == uvRowBytes) {
      out.setRange(dst, dst + uvSize, vuPlane.bytes, 0);
    } else {
      for (int row = 0; row < halfH; row++) {
        final int rowOffset = row * vuRowStride;
        out.setRange(dst, dst + uvRowBytes, vuPlane.bytes, rowOffset);
        dst += uvRowBytes;
      }
    }
    return out;
  }

  // Caso 3: 3+ planos padrão Android YUV_420_888 (Y, U, V) com strides arbitrários.
  final RawImagePlane yPlane = planes[0];
  final RawImagePlane uPlane = planes[1];
  final RawImagePlane vPlane = planes[2];

  final Uint8List yBytes = yPlane.bytes;
  final Uint8List uBytes = uPlane.bytes;
  final Uint8List vBytes = vPlane.bytes;

  final int yRowStride = yPlane.bytesPerRow <= 0 ? width : yPlane.bytesPerRow;
  final int yPixelStride = yPlane.bytesPerPixel <= 0 ? 1 : yPlane.bytesPerPixel;
  final int uRowStride = uPlane.bytesPerRow <= 0 ? halfW : uPlane.bytesPerRow;
  final int uPixelStride = uPlane.bytesPerPixel <= 0 ? 1 : uPlane.bytesPerPixel;
  final int vRowStride = vPlane.bytesPerRow <= 0 ? halfW : vPlane.bytesPerRow;
  final int vPixelStride = vPlane.bytesPerPixel <= 0 ? 1 : vPlane.bytesPerPixel;

  final int minYRequired = (height - 1) * yRowStride + (width - 1) * yPixelStride + 1;
  final int minURequired = (halfH - 1) * uRowStride + (halfW - 1) * uPixelStride + 1;
  final int minVRequired = (halfH - 1) * vRowStride + (halfW - 1) * vPixelStride + 1;
  if (yBytes.length < minYRequired ||
      uBytes.length < minURequired ||
      vBytes.length < minVRequired) {
    return null;
  }

  final Uint8List out = Uint8List(expectedSize);
  int dst = 0;

  if (yRowStride == width && yPixelStride == 1) {
    out.setRange(0, ySize, yBytes, 0);
    dst = ySize;
  } else {
    for (int row = 0; row < height; row++) {
      final int rowOffset = row * yRowStride;
      if (yPixelStride == 1) {
        out.setRange(dst, dst + width, yBytes, rowOffset);
        dst += width;
      } else {
        for (int col = 0; col < width; col++) {
          out[dst++] = yBytes[rowOffset + col * yPixelStride];
        }
      }
    }
  }

  // NV21 intercala V seguido de U (V0, U0, V1, U1, ...).
  for (int row = 0; row < halfH; row++) {
    final int uRowOffset = row * uRowStride;
    final int vRowOffset = row * vRowStride;
    for (int col = 0; col < halfW; col++) {
      out[dst++] = vBytes[vRowOffset + col * vPixelStride];
      out[dst++] = uBytes[uRowOffset + col * uPixelStride];
    }
  }

  return out;
}

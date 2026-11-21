import 'dart:typed_data';

import 'ocr_text_geometry.dart';

/// Resultado bruto da leitura OCR/QR on-device em plataformas móveis.
class PlatformDocumentOcrOutput {
  const PlatformDocumentOcrOutput({
    required this.frontText,
    required this.backText,
    required this.qrPayloads,
    required this.frontRotationDegrees,
    required this.backRotationDegrees,
    required this.availableOnPlatform,
    this.frontLines = const <OcrTextLineBox>[],
    this.backLines = const <OcrTextLineBox>[],
  });

  final String frontText;
  final String backText;
  final List<String> qrPayloads;
  final int frontRotationDegrees;
  final int backRotationDegrees;
  final bool availableOnPlatform;
  final List<OcrTextLineBox> frontLines;
  final List<OcrTextLineBox> backLines;
}

/// Stub para Web / plataformas sem Google ML Kit nativo.
/// A camada superior acionará o reforço online (`kyc-argon-vision-gate`) quando disponível.
Future<PlatformDocumentOcrOutput> extractDocumentOcrOnDevice({
  required Uint8List frontImageBytes,
  required Uint8List backImageBytes,
}) async {
  return const PlatformDocumentOcrOutput(
    frontText: '',
    backText: '',
    qrPayloads: <String>[],
    frontRotationDegrees: 0,
    backRotationDegrees: 0,
    availableOnPlatform: false,
    frontLines: <OcrTextLineBox>[],
    backLines: <OcrTextLineBox>[],
  );
}

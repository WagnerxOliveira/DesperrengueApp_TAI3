import 'dart:typed_data';

/// Resultado bruto da leitura OCR/QR on-device em plataformas móveis.
class PlatformDocumentOcrOutput {
  const PlatformDocumentOcrOutput({
    required this.frontText,
    required this.backText,
    required this.qrPayloads,
    required this.frontRotationDegrees,
    required this.backRotationDegrees,
    required this.availableOnPlatform,
  });

  final String frontText;
  final String backText;
  final List<String> qrPayloads;
  final int frontRotationDegrees;
  final int backRotationDegrees;
  final bool availableOnPlatform;
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
  );
}

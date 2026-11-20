import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Resultado bruto da leitura OCR/QR on-device em plataformas móveis (Android/iOS).
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

/// Executa OCR real on-device com Google ML Kit (`TextRecognitionScript.latin`)
/// na Frente e no Verso recortados — testando automaticamente `0°`, `90°` e `270°`
/// se o texto inicial vier vazio ou curto — além de escanear QR Code SERPRO/VIO
/// no Verso com `BarcodeScanner`. Todos os arquivos temporários são apagados em `finally`.
Future<PlatformDocumentOcrOutput> extractDocumentOcrOnDevice({
  required Uint8List frontImageBytes,
  required Uint8List backImageBytes,
}) async {
  if (!(Platform.isAndroid || Platform.isIOS)) {
    return const PlatformDocumentOcrOutput(
      frontText: '',
      backText: '',
      qrPayloads: <String>[],
      frontRotationDegrees: 0,
      backRotationDegrees: 0,
      availableOnPlatform: false,
    );
  }

  final TextRecognizer textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  final BarcodeScanner barcodeScanner = BarcodeScanner(
    formats: const <BarcodeFormat>[
      BarcodeFormat.qrCode,
      BarcodeFormat.pdf417,
      BarcodeFormat.dataMatrix,
    ],
  );

  try {
    final Directory tempDir = await getTemporaryDirectory();
    final int batchId = DateTime.now().microsecondsSinceEpoch;

    final ({String text, int rotation}) frontRead =
        await _recognizeTextMultiOrientation(
      recognizer: textRecognizer,
      imageBytes: frontImageBytes,
      tempDir: tempDir,
      prefix: 'dsp_ocr_front_$batchId',
    );

    final ({String text, int rotation}) backRead =
        await _recognizeTextMultiOrientation(
      recognizer: textRecognizer,
      imageBytes: backImageBytes,
      tempDir: tempDir,
      prefix: 'dsp_ocr_back_$batchId',
    );

    final List<String> qrPayloads = await _scanQrCodesSafe(
      scanner: barcodeScanner,
      imageBytes: backImageBytes,
      tempDir: tempDir,
      prefix: 'dsp_qr_back_$batchId',
    );

    return PlatformDocumentOcrOutput(
      frontText: frontRead.text,
      backText: backRead.text,
      qrPayloads: qrPayloads,
      frontRotationDegrees: frontRead.rotation,
      backRotationDegrees: backRead.rotation,
      availableOnPlatform: true,
    );
  } finally {
    try {
      await textRecognizer.close();
    } catch (_) {}
    try {
      await barcodeScanner.close();
    } catch (_) {}
  }
}

Future<({String text, int rotation})> _recognizeTextMultiOrientation({
  required TextRecognizer recognizer,
  required Uint8List imageBytes,
  required Directory tempDir,
  required String prefix,
}) async {
  if (imageBytes.isEmpty) {
    return (text: '', rotation: 0);
  }

  String bestText = await _processSingleBytesForText(
    recognizer: recognizer,
    bytes: imageBytes,
    tempDir: tempDir,
    fileName: '${prefix}_0.jpg',
  );
  int bestRotation = 0;

  // Se texto vier vazio ou curto (< 28 caracteres úteis), testa 90° e 270°
  if (_meaningfulCharCount(bestText) < 28) {
    final img.Image? decoded = img.decodeImage(imageBytes);
    if (decoded != null) {
      for (final int angle in const <int>[90, 270, 180]) {
        final img.Image rotated = img.copyRotate(decoded, angle: angle);
        final Uint8List rotatedBytes =
            Uint8List.fromList(img.encodeJpg(rotated, quality: 92));
        final String candidate = await _processSingleBytesForText(
          recognizer: recognizer,
          bytes: rotatedBytes,
          tempDir: tempDir,
          fileName: '${prefix}_$angle.jpg',
        );
        if (_meaningfulCharCount(candidate) > _meaningfulCharCount(bestText)) {
          bestText = candidate;
          bestRotation = angle;
          if (_meaningfulCharCount(bestText) >= 48) {
            break;
          }
        }
      }
    }
  }

  return (text: bestText.trim(), rotation: bestRotation);
}

Future<String> _processSingleBytesForText({
  required TextRecognizer recognizer,
  required Uint8List bytes,
  required Directory tempDir,
  required String fileName,
}) async {
  final File tempFile = File('${tempDir.path}${Platform.pathSeparator}$fileName');
  try {
    await tempFile.writeAsBytes(bytes, flush: true);
    final InputImage inputImage = InputImage.fromFilePath(tempFile.path);
    final RecognizedText recognized = await recognizer.processImage(inputImage);
    return recognized.text;
  } catch (_) {
    return '';
  } finally {
    try {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (_) {}
  }
}

Future<List<String>> _scanQrCodesSafe({
  required BarcodeScanner scanner,
  required Uint8List imageBytes,
  required Directory tempDir,
  required String prefix,
}) async {
  if (imageBytes.isEmpty) return const <String>[];

  final File tempFile = File('${tempDir.path}${Platform.pathSeparator}$prefix.jpg');
  try {
    await tempFile.writeAsBytes(imageBytes, flush: true);
    final InputImage inputImage = InputImage.fromFilePath(tempFile.path);
    final List<Barcode> barcodes = await scanner.processImage(inputImage);
    final List<String> payloads = <String>[];
    for (final b in barcodes) {
      final String raw = (b.rawValue ?? b.displayValue ?? '').trim();
      if (raw.isNotEmpty) {
        payloads.add(raw);
      }
    }
    return payloads;
  } catch (_) {
    return const <String>[];
  } finally {
    try {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (_) {}
  }
}

int _meaningfulCharCount(String text) =>
    text.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ0-9]'), '').length;

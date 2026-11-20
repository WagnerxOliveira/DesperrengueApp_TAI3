import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

const MethodChannel _documentPickerChannel = MethodChannel(
  'br.com.desperrengue.app/document_picker',
);

bool get isAndroidNativePickerSupported => Platform.isAndroid;

/// Dispara o seletor nativo Android SAF posicionado diretamente na pasta `Downloads`
/// (sem exigir `READ_EXTERNAL_STORAGE`).
///
/// Retorna `null` quando o usuário cancela a seleção.
/// Propaga `MissingPluginException` / `PlatformException` para que a fachada decida
/// entre fallback para `FilePicker` ou exibição de erro amigável (ex.: > 15 MB).
Future<({Uint8List bytes, String fileName})?> pickDocumentInDownloadsNative() async {
  if (!Platform.isAndroid) return null;
  final raw = await _documentPickerChannel.invokeMapMethod<String, dynamic>(
    'pickDocumentInDownloads',
  );
  if (raw == null) return null;

  final dynamic rawBytes = raw['bytes'];
  final Uint8List bytes;
  if (rawBytes is Uint8List) {
    bytes = rawBytes;
  } else if (rawBytes is List<int>) {
    bytes = Uint8List.fromList(rawBytes);
  } else {
    return null;
  }
  if (bytes.isEmpty) return null;

  final fileName = (raw['fileName'] as String?)?.trim() ?? '';
  return (
    bytes: bytes,
    fileName: fileName.isNotEmpty ? fileName : 'certidao_pf.pdf',
  );
}

/// Renderiza a primeira página de um PDF escaneado em PNG (via `android.graphics.pdf.PdfRenderer`)
/// para permitir OCR + leitura do QR Code da Polícia Federal.
Future<Uint8List?> renderPdfFirstPagePngNative(
  Uint8List pdfBytes, {
  int targetWidth = 1600,
}) async {
  if (!Platform.isAndroid || pdfBytes.isEmpty) return null;
  try {
    final result = await _documentPickerChannel.invokeMethod<dynamic>(
      'renderPdfFirstPagePng',
      <String, dynamic>{
        'bytes': pdfBytes,
        'targetWidth': targetWidth,
      },
    );
    if (result is Uint8List && result.isNotEmpty) return result;
    if (result is List<int> && result.isNotEmpty) {
      return Uint8List.fromList(result);
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Executa OCR on-device (`google_mlkit_text_recognition` Latin) + leitura de QR Code
/// (`google_mlkit_barcode_scanning`) sobre bytes de imagem, gravando e removendo
/// o arquivo temporário com segurança em `finally`.
Future<({String text, String? qrPayload})> recognizeTextAndQrFromImageBytesNative(
  Uint8List imageBytes, {
  String extension = 'jpg',
}) async {
  if (!(Platform.isAndroid || Platform.isIOS) || imageBytes.isEmpty) {
    return (text: '', qrPayload: null);
  }

  final safeExt = switch (extension.trim().toLowerCase()) {
    'png' => 'png',
    'webp' => 'webp',
    _ => 'jpg',
  };

  File? tempFile;
  TextRecognizer? textRecognizer;
  BarcodeScanner? barcodeScanner;

  try {
    final tempDir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    tempFile = File('${tempDir.path}/pf_cert_$stamp.$safeExt');
    await tempFile.writeAsBytes(imageBytes, flush: true);

    final inputImage = InputImage.fromFilePath(tempFile.path);
    textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    barcodeScanner = BarcodeScanner(
      formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    );

    String extractedText = '';
    String? qrPayload;

    try {
      final recognized = await textRecognizer.processImage(inputImage);
      extractedText = recognized.text.trim();
    } catch (_) {
      // OCR falhou em ambiente sem Google Play Services; segue para barcode/fallback
    }

    try {
      final barcodes = await barcodeScanner.processImage(inputImage);
      for (final b in barcodes) {
        final val = (b.rawValue ?? b.displayValue ?? '').trim();
        if (val.isEmpty) continue;
        final lower = val.toLowerCase();
        if (lower.contains('pf.gov.br') ||
            lower.contains('validar-cac') ||
            lower.contains('epol-sinic')) {
          qrPayload = val;
          break;
        }
        qrPayload ??= val;
      }
    } catch (_) {
      // Barcode scanning indisponível; segue normalmente
    }

    return (text: extractedText, qrPayload: qrPayload);
  } catch (_) {
    return (text: '', qrPayload: null);
  } finally {
    if (textRecognizer != null) {
      try {
        await textRecognizer.close();
      } catch (_) {}
    }
    if (barcodeScanner != null) {
      try {
        await barcodeScanner.close();
      } catch (_) {}
    }
    if (tempFile != null) {
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }
}

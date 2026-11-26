import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'ocr_text_geometry.dart';

/// Resultado bruto da leitura OCR/QR on-device em plataformas móveis (Android/iOS).
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

typedef _OcrPassOutput = ({
  String text,
  List<OcrTextLineBox> lines,
  int rotation,
});

/// Executa OCR espacial real on-device com Google ML Kit (`TextRecognitionScript.latin`)
/// na Frente e no Verso recortados:
///  * Preserva todas as `TextLine` com suas coordenadas 2D (`OcrTextLineBox`) para
///    pareamento geométrico exato de campos tabulares (CNH Clássica & CNH 2022).
///  * Aplica `bakeOrientation` e, quando a 1ª passada não capturar datas ou CPF
///    nítidos, executa 2ª passada com realce de contraste (suprimindo o fundo
///    guilloché verde da CNH) e testes de rotação `90°`, `270°` e `180°`.
///  * Escaneia QR Code SERPRO/VIO no Verso com `BarcodeScanner`.
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
      frontLines: <OcrTextLineBox>[],
      backLines: <OcrTextLineBox>[],
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

    final _OcrPassOutput frontRead = await _recognizeTextSpatialMultiPass(
      recognizer: textRecognizer,
      imageBytes: frontImageBytes,
      tempDir: tempDir,
      prefix: 'dsp_ocr_front_$batchId',
      expectDatesAndCpf: true,
    );

    final _OcrPassOutput backRead = await _recognizeTextSpatialMultiPass(
      recognizer: textRecognizer,
      imageBytes: backImageBytes,
      tempDir: tempDir,
      prefix: 'dsp_ocr_back_$batchId',
      expectDatesAndCpf: false,
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
      frontLines: frontRead.lines,
      backLines: backRead.lines,
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

Future<_OcrPassOutput> _recognizeTextSpatialMultiPass({
  required TextRecognizer recognizer,
  required Uint8List imageBytes,
  required Directory tempDir,
  required String prefix,
  required bool expectDatesAndCpf,
}) async {
  if (imageBytes.isEmpty) {
    return (text: '', lines: const <OcrTextLineBox>[], rotation: 0);
  }

  final img.Image? rawDecoded = img.decodeImage(imageBytes);
  final img.Image? baked =
      rawDecoded != null ? img.bakeOrientation(rawDecoded) : null;
  final double baseW = (baked?.width ?? 1000).toDouble();
  final double baseH = (baked?.height ?? 1000).toDouble();

  final Uint8List pass0Bytes = baked != null &&
          rawDecoded!.exif.imageIfd.hasOrientation &&
          rawDecoded.exif.imageIfd.orientation != 1
      ? Uint8List.fromList(img.encodeJpg(baked, quality: 94))
      : imageBytes;

  _OcrPassOutput best = await _processSingleBytesSpatial(
    recognizer: recognizer,
    bytes: pass0Bytes,
    imageWidth: baseW,
    imageHeight: baseH,
    rotation: 0,
    tempDir: tempDir,
    fileName: '${prefix}_0.jpg',
  );
  int bestScore = _ocrQualityScore(best.text, expectDatesAndCpf);

  // Passada 2A (realce de contraste anti-guilloché): dispara sempre que ainda
  // não houver data de nascimento plausível na frente OU score abaixo de 105.
  // Corrige o caso real da CNH 2022 onde 4a Emissão e 4b Validade aparecem na
  // 1ª passada mas o campo 3 (Data de Nascimento) fica mascarado pelo fundo verde.
  if (baked != null &&
      expectDatesAndCpf &&
      (!_hasPlausibleBirthDatePattern(best.text) || bestScore < 105)) {
    final img.Image enhanced = _enhanceDocumentInkContrast(baked);
    final Uint8List enhancedBytes =
        Uint8List.fromList(img.encodeJpg(enhanced, quality: 95));
    final _OcrPassOutput enhancedPass = await _processSingleBytesSpatial(
      recognizer: recognizer,
      bytes: enhancedBytes,
      imageWidth: enhanced.width.toDouble(),
      imageHeight: enhanced.height.toDouble(),
      rotation: 0,
      tempDir: tempDir,
      fileName: '${prefix}_0_enh.jpg',
    );
    final int enhancedScore =
        _ocrQualityScore(enhancedPass.text, expectDatesAndCpf);
    final bool bestHasBirth = _hasPlausibleBirthDatePattern(best.text);
    final bool enhHasBirth = _hasPlausibleBirthDatePattern(enhancedPass.text);
    if (enhancedScore > bestScore && (enhHasBirth || !bestHasBirth)) {
      best = enhancedPass;
      bestScore = enhancedScore;
    } else if (enhHasBirth && !bestHasBirth) {
      // Preserva linhas enriquecidas que resgataram a data de nascimento.
      best = (
        text: '${best.text}\n${enhancedPass.text}'.trim(),
        lines: <OcrTextLineBox>[...best.lines, ...enhancedPass.lines],
        rotation: best.rotation,
      );
      bestScore = _ocrQualityScore(best.text, expectDatesAndCpf);
    }
  }

  // Passada 2B (zoom 1.6x + realce na metade superior): na CNH 2022 e CNH Clássica,
  // o campo 3 ("DATA, LOCAL E UF DE NASCIMENTO") fica na metade superior com fonte
  // menor sobre fundo guilloché. Recorta 58% superiores, amplia 1.6x e remapeia
  // as caixas normalizadas para a geometria original do documento.
  if (baked != null &&
      expectDatesAndCpf &&
      !_hasPlausibleBirthDatePattern(best.text)) {
    final int cropH = math.max(64, (baked.height * 0.58).round());
    final img.Image topCrop = img.copyCrop(
      baked,
      x: 0,
      y: 0,
      width: baked.width,
      height: math.min(cropH, baked.height),
    );
    final int upscaledW = math.min(2400, (topCrop.width * 1.6).round());
    final int upscaledH = math.min(1800, (topCrop.height * 1.6).round());
    final double scaleX = upscaledW / baked.width;
    final double scaleY = upscaledH / cropH;
    final img.Image topUpscaled = _enhanceDocumentInkContrast(
      img.copyResize(
        topCrop,
        width: upscaledW,
        height: upscaledH,
        interpolation: img.Interpolation.cubic,
      ),
    );
    final Uint8List topBytes =
        Uint8List.fromList(img.encodeJpg(topUpscaled, quality: 95));
    final _OcrPassOutput topPass = await _processSingleBytesSpatial(
      recognizer: recognizer,
      bytes: topBytes,
      imageWidth: upscaledW.toDouble(),
      imageHeight: upscaledH.toDouble(),
      rotation: 0,
      tempDir: tempDir,
      fileName: '${prefix}_0_top_zoom.jpg',
    );
    if (_hasPlausibleBirthDatePattern(topPass.text)) {
      final List<OcrTextLineBox> remappedLines = topPass.lines
          .map(
            (l) => OcrTextLineBox(
              text: l.text,
              left: l.left / scaleX,
              top: l.top / scaleY,
              right: l.right / scaleX,
              bottom: l.bottom / scaleY,
              imageWidth: baseW,
              imageHeight: baseH,
            ),
          )
          .toList(growable: false);
      best = (
        text: '${best.text}\n${topPass.text}'.trim(),
        lines: <OcrTextLineBox>[...best.lines, ...remappedLines],
        rotation: best.rotation,
      );
      bestScore = _ocrQualityScore(best.text, expectDatesAndCpf);
    }
  }

  // Passada 3 (multi-orientação): dispara se texto veio curto OU se faltam
  // datas plausíveis de nascimento na frente (foto enviada de pé em 90°/270° ou 180°).
  final bool needsRotationRetry = _meaningfulCharCount(best.text) < 36 ||
      (expectDatesAndCpf && !_hasPlausibleBirthDatePattern(best.text));

  if (baked != null && needsRotationRetry) {
    for (final int angle in const <int>[90, 270, 180]) {
      final img.Image rotated = img.copyRotate(baked, angle: angle);
      final Uint8List rotatedBytes =
          Uint8List.fromList(img.encodeJpg(rotated, quality: 94));
      final _OcrPassOutput candidate = await _processSingleBytesSpatial(
        recognizer: recognizer,
        bytes: rotatedBytes,
        imageWidth: rotated.width.toDouble(),
        imageHeight: rotated.height.toDouble(),
        rotation: angle,
        tempDir: tempDir,
        fileName: '${prefix}_$angle.jpg',
      );
      final int candidateScore =
          _ocrQualityScore(candidate.text, expectDatesAndCpf);
      if (candidateScore > bestScore) {
        best = candidate;
        bestScore = candidateScore;
        if (bestScore >= 120 &&
            (!expectDatesAndCpf || _hasPlausibleBirthDatePattern(best.text))) {
          break;
        }
      }
    }
  }

  return (
    text: best.text.trim(),
    lines: best.lines,
    rotation: best.rotation,
  );
}

/// Realça tinta preta de campos impressos sobre o fundo verde/amarelo guilloché
/// de CNHs e RGs brasileiros usando extração de canal vermelho/luminância +
/// estiramento linear de contraste (percentis 3%..97%).
img.Image _enhanceDocumentInkContrast(img.Image source) {
  final img.Image work = source.clone();
  final int w = work.width;
  final int h = work.height;
  final List<int> hist = List<int>.filled(256, 0);

  // Na CNH (fundo verde-claro + tinta preta), o canal vermelho escurece o
  // verde de fundo menos que a tinta preta, mas a luminância ponderada com
  // peso extra em G/R neutraliza o padrão guilloché e preserva traços finos.
  final int step = math.max(1, (w * h) ~/ 24000);
  int samples = 0;
  for (int i = 0; i < w * h; i += step) {
    final int x = i % w;
    final int y = i ~/ w;
    final p = work.getPixel(x, y);
    final int lum = ((0.35 * p.r) + (0.50 * p.g) + (0.15 * p.b))
        .round()
        .clamp(0, 255);
    hist[lum]++;
    samples++;
  }

  int lo = 0;
  int hi = 255;
  final int loTarget = (samples * 0.03).round();
  final int hiTarget = (samples * 0.97).round();
  int acc = 0;
  for (int v = 0; v < 256; v++) {
    acc += hist[v];
    if (acc >= loTarget) {
      lo = v;
      break;
    }
  }
  acc = 0;
  for (int v = 0; v < 256; v++) {
    acc += hist[v];
    if (acc >= hiTarget) {
      hi = v;
      break;
    }
  }

  final int span = math.max(24, hi - lo);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = work.getPixel(x, y);
      final double lum = (0.35 * p.r) + (0.50 * p.g) + (0.15 * p.b);
      final int stretched =
          (((lum - lo) * 255.0) / span).round().clamp(0, 255);
      work.setPixelRgb(x, y, stretched, stretched, stretched);
    }
  }
  return work;
}

Future<_OcrPassOutput> _processSingleBytesSpatial({
  required TextRecognizer recognizer,
  required Uint8List bytes,
  required double imageWidth,
  required double imageHeight,
  required int rotation,
  required Directory tempDir,
  required String fileName,
}) async {
  final File tempFile = File('${tempDir.path}${Platform.pathSeparator}$fileName');
  try {
    await tempFile.writeAsBytes(bytes, flush: true);
    final InputImage inputImage = InputImage.fromFilePath(tempFile.path);
    final RecognizedText recognized = await recognizer.processImage(inputImage);

    final List<OcrTextLineBox> lines = <OcrTextLineBox>[];
    for (final TextBlock block in recognized.blocks) {
      for (final TextLine line in block.lines) {
        final String clean = line.text.trim();
        if (clean.isEmpty) continue;
        final box = line.boundingBox;
        lines.add(
          OcrTextLineBox(
            text: clean,
            left: box.left,
            top: box.top,
            right: box.right,
            bottom: box.bottom,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
          ),
        );
      }
    }

    return (
      text: recognized.text,
      lines: lines,
      rotation: rotation,
    );
  } catch (_) {
    return (text: '', lines: const <OcrTextLineBox>[], rotation: rotation);
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

bool _hasPlausibleBirthDatePattern(String text) {
  final int maxBirthYear = DateTime.now().year - 10;
  final RegExp re = RegExp(
    r'(?<!\d)(\d{2})[/.\-\s]+(\d{2})[/.\-\s]+((?:19|20)\d{2})(?!\d)',
  );
  for (final m in re.allMatches(text)) {
    final int? d = int.tryParse(m.group(1)!);
    final int? mo = int.tryParse(m.group(2)!);
    final int? y = int.tryParse(m.group(3)!);
    if (d != null &&
        mo != null &&
        y != null &&
        d >= 1 &&
        d <= 31 &&
        mo >= 1 &&
        mo <= 12 &&
        y >= 1915 &&
        y <= maxBirthYear) {
      return true;
    }
  }
  return false;
}

int _ocrQualityScore(String text, bool expectDatesAndCpf) {
  int score = math.min(70, _meaningfulCharCount(text) ~/ 2);
  if (expectDatesAndCpf) {
    if (RegExp(r'\d{3}\.?\d{3}\.?\d{3}[\-\s]?\d{2}').hasMatch(text)) {
      score += 30;
    }
    final dateMatches =
        RegExp(r'(?<!\d)\d{2}[/.\-\s]+\d{2}[/.\-\s]+(?:19|20)\d{2}(?!\d)')
            .allMatches(text)
            .length;
    score += math.min(35, dateMatches * 15);
    if (_hasPlausibleBirthDatePattern(text)) {
      score += 25;
    }
    final upper = text.toUpperCase();
    if (upper.contains('NASCIMENTO') || upper.contains('NASC')) score += 10;
    if (upper.contains('NOME')) score += 8;
  }
  return score;
}

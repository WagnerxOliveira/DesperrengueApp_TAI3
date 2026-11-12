import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Evidência fotográfica capturada exclusivamente pela câmera nativa em tempo real,
/// autenticada por Hash Perceptual de 64 bits (`pHash`) e telemetria GPS anti-spoofing.
class CapturedForensicPhoto {
  final Uint8List bytes;
  final int perceptualHash64;
  final DateTime capturedAtUtc;
  final double latitude;
  final double longitude;
  final double gpsAccuracyMeters;
  final bool isMockLocationDetected;

  const CapturedForensicPhoto({
    required this.bytes,
    required this.perceptualHash64,
    required this.capturedAtUtc,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracyMeters,
    required this.isMockLocationDetected,
  });
}

/// Métricas forenses detalhadas da comparação estrutural entre Frente e Verso do Documento
/// sobre o Recorte Interno de Segurança (Core ROI Inset de 12%).
class DocumentRoiDistinctionMetrics {
  final int frontDHash64;
  final int backDHash64;
  final int dHashHammingDistance;
  final double mad64x64;
  final double quadrantVarianceDelta;
  final bool isDuplicate;

  const DocumentRoiDistinctionMetrics({
    required this.frontDHash64,
    required this.backDHash64,
    required this.dHashHammingDistance,
    required this.mad64x64,
    required this.quadrantVarianceDelta,
    required this.isDuplicate,
  });
}

/// Guarda Criptográfica de Câmera Nativa e Detecção de Fraude Visual (`RN-AF-03` e `RN-AF-06`).
///
/// Toda decodificação de imagem e cálculo matricial 8x8/9x8 de luminância é executado em um
/// Worker Isolate secundário (`Isolate.run`), mantendo a UI Thread livre em 120 FPS (< 8.33ms/frame).
class PerceptualHashGuard {
  static final ImagePicker _picker = ImagePicker();

  /// Captura evidência exclusivamente via hardware de câmera nativa (`ImageSource.camera`),
  /// bloqueando seleção da galeria, localização simulada (Fake GPS) e calculando o `pHash`
  /// em Worker Isolate paralelo com downsampling no ISP do hardware (`1280px`).
  static Future<CapturedForensicPhoto> captureStrictlyFromCamera({
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    final Position pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 10),
      ),
    );

    if (pos.isMocked) {
      throw StateError(
        'Bloqueio de Segurança: Localização simulada (Fake GPS) detectada no dispositivo.',
      );
    }

    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 86,
      preferredCameraDevice: preferredCameraDevice,
    );

    if (photo == null) {
      throw StateError('Captura de evidência cancelada.');
    }

    final Uint8List bytes = await photo.readAsBytes();
    final int pHash = await Isolate.run(() => compute64BitPerceptualHash(bytes));

    return CapturedForensicPhoto(
      bytes: bytes,
      perceptualHash64: pHash,
      capturedAtUtc: DateTime.now().toUtc(),
      latitude: pos.latitude,
      longitude: pos.longitude,
      gpsAccuracyMeters: pos.accuracy,
      isMockLocationDetected: pos.isMocked,
    );
  }

  /// Recorta o Miolo Interno de Segurança (`insetRatio`, padrão `12%` em cada borda)
  /// descartando completamente a mesa, o teclado ou a borda do monitor ao redor do documento.
  static img.Image cropCoreRoiInset(
    img.Image source, {
    double insetRatio = 0.12,
  }) {
    final double clampedInset = insetRatio.clamp(0.0, 0.30);
    final int x = (source.width * clampedInset).round();
    final int y = (source.height * clampedInset).round();
    final int w = math.max(16, source.width - (2 * x));
    final int h = math.max(16, source.height - (2 * y));
    if (w >= source.width || h >= source.height) return source;
    return img.copyCrop(source, x: x, y: y, width: w, height: h);
  }

  /// Calcula o Hash Perceptual Médio de 64 bits (`aHash` / `pHash` 8x8) em aritmética inteira
  /// de ponto fixo (`(77*R + 150*G + 29*B) >> 8`).
  static int compute64BitPerceptualHash(Uint8List imageBytes) {
    final img.Image? decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw ArgumentError('Imagem de evidência corrompida ou ilegível.');
    }

    final img.Image small = img.copyResize(
      decoded,
      width: 8,
      height: 8,
      interpolation: img.Interpolation.average,
    );

    final Uint8List luma = Uint8List(64);
    int sum = 0;
    int idx = 0;

    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        final pixel = small.getPixel(x, y);
        final int lum =
            ((77 * pixel.r.toInt()) + (150 * pixel.g.toInt()) + (29 * pixel.b.toInt())) >> 8;
        luma[idx++] = lum;
        sum += lum;
      }
    }

    final int mean = sum >> 6; // Divisão inteira exata por 64
    int hash = 0;
    for (int i = 0; i < 64; i++) {
      if (luma[i] >= mean) {
        hash |= (1 << i);
      }
    }
    return hash;
  }

  /// Calcula o **dHash de Gradiente Horizontal de 64 bits (`9x8`)** estritamente sobre o
  /// Miolo Interno (`insetRatio = 0.12`) da imagem do documento, comparando $I(x, y) > I(x+1, y)$.
  static int compute64BitDifferenceHashRoi(
    img.Image decoded, {
    double insetRatio = 0.12,
  }) {
    final img.Image core = cropCoreRoiInset(decoded, insetRatio: insetRatio);
    final img.Image small = img.copyResize(
      core,
      width: 9,
      height: 8,
      interpolation: img.Interpolation.average,
    );

    int dHash = 0;
    int bitIndex = 0;
    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        final pLeft = small.getPixel(x, y);
        final pRight = small.getPixel(x + 1, y);
        final int lumLeft =
            ((77 * pLeft.r.toInt()) + (150 * pLeft.g.toInt()) + (29 * pLeft.b.toInt())) >> 8;
        final int lumRight =
            ((77 * pRight.r.toInt()) + (150 * pRight.g.toInt()) + (29 * pRight.b.toInt())) >> 8;
        if (lumLeft > lumRight) {
          dHash |= (1 << bitIndex);
        }
        bitIndex++;
      }
    }
    return dHash;
  }

  /// Calcula o `dHash` de 64 bits diretamente a partir dos bytes de imagem (`Uint8List`)
  /// sobre o Core ROI Inset (padrão `12%`).
  static int computeCoreRoiDHash64(
    Uint8List imageBytes, {
    double insetRatio = 0.12,
  }) {
    final img.Image? decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw ArgumentError('Imagem ilegível para cálculo de dHash64.');
    }
    return compute64BitDifferenceHashRoi(decoded, insetRatio: insetRatio);
  }

  /// Atalho compatível para cálculo de `dHash` de 64 bits sobre bytes de imagem.
  static int computeDHash64(
    Uint8List imageBytes, {
    double insetRatio = 0.0,
  }) {
    final img.Image? decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw ArgumentError('Imagem ilegível para cálculo de dHash64.');
    }
    return compute64BitDifferenceHashRoi(decoded, insetRatio: insetRatio);
  }

  /// Formata um inteiro de 64 bits em string hexadecimal de 16 caracteres sem sinal.
  static String toHex64(int hash64) {
    final BigInt unsigned = BigInt.from(hash64).toUnsigned(64);
    return unsigned.toRadixString(16).padLeft(16, '0');
  }

  /// Avalia matematicamente a distinção estrutural entre Frente e Verso do documento sobre o
  /// Recorte Interno de Segurança (Core ROI Inset de 12%), combinando:
  /// 1. `dHash` de Gradiente Horizontal (`9x8`)
  /// 2. Diferença Absoluta Média ($MAD_{64\times64}$) normalizada de `[0..255]`
  /// 3. Diferença de Variância entre os 4 Quadrantes ($\Delta\sigma_{\text{quad}}^2$)
  ///
  /// Duas fotos só são rejeitadas como duplicadas (`isDuplicate == true`) se cumprirem
  /// **SIMULTANEAMENTE**:
  /// $\text{hammingDistance64}(dHash_{\text{frente}}, dHash_{\text{verso}}) \le 2 \land MAD_{64\times64} < 6.5 \land \Delta\sigma_{\text{quad}}^2 < 15.0$.
  static DocumentRoiDistinctionMetrics evaluateDocumentFrontBackDistinction([
    Uint8List? posFrontBytes,
    Uint8List? posBackBytes,
    double posInsetRatio = 0.12,
  ]) {
    if (posFrontBytes == null || posBackBytes == null) {
      throw ArgumentError('Imagens da frente e do verso são obrigatórias.');
    }
    final img.Image? frontDecoded = img.decodeImage(posFrontBytes);
    final img.Image? backDecoded = img.decodeImage(posBackBytes);
    if (frontDecoded == null || backDecoded == null) {
      throw ArgumentError('Imagens da frente ou do verso do documento ilegíveis.');
    }

    final int frontDHash = compute64BitDifferenceHashRoi(frontDecoded, insetRatio: posInsetRatio);
    final int backDHash = compute64BitDifferenceHashRoi(backDecoded, insetRatio: posInsetRatio);
    final int hamming = hammingDistance64(frontDHash, backDHash);

    final List<double> frontGrid = _extractNormalizedGray64x64(frontDecoded, insetRatio: posInsetRatio);
    final List<double> backGrid = _extractNormalizedGray64x64(backDecoded, insetRatio: posInsetRatio);

    double absDiffSum = 0.0;
    for (int i = 0; i < 4096; i++) {
      absDiffSum += (frontGrid[i] - backGrid[i]).abs();
    }
    final double mad = absDiffSum / 4096.0;

    final List<double> frontQuadVars = _computeQuadrantVariances64(frontGrid);
    final List<double> backQuadVars = _computeQuadrantVariances64(backGrid);
    double quadVarDelta = 0.0;
    for (int q = 0; q < 4; q++) {
      quadVarDelta += (frontQuadVars[q] - backQuadVars[q]).abs();
    }
    quadVarDelta /= 4.0;

    final bool isDuplicate = (hamming <= 2) && (mad < 6.5) && (quadVarDelta < 15.0);

    return DocumentRoiDistinctionMetrics(
      frontDHash64: frontDHash,
      backDHash64: backDHash,
      dHashHammingDistance: hamming,
      mad64x64: mad,
      quadrantVarianceDelta: quadVarDelta,
      isDuplicate: isDuplicate,
    );
  }

  /// Atalho booleano determinístico para verificar se Frente e Verso são a mesma foto reciclada.
  static bool isDuplicateDocumentFrontAndBack(
    Uint8List frontBytes,
    Uint8List backBytes, {
    double insetRatio = 0.12,
  }) {
    return evaluateDocumentFrontBackDistinction(
      frontBytes,
      backBytes,
      insetRatio,
    ).isDuplicate;
  }

  /// Executa a verificação combinada (`Core ROI 12%` + `dHash 64-bit` + `MAD 64x64`)
  /// em um Isolate secundário (`Isolate.run`), mantendo 120 FPS na thread principal.
  static Future<DocumentRoiDistinctionMetrics>
      evaluateDocumentFrontBackDistinctionInIsolate(
    Uint8List frontBytes,
    Uint8List backBytes, {
    double insetRatio = 0.12,
  }) {
    return Isolate.run(
      () => evaluateDocumentFrontBackDistinction(
        frontBytes,
        backBytes,
        insetRatio,
      ),
    );
  }

  /// Calcula o `dHash` de 64 bits da região central (`Core ROI Inset 12%`) em `Isolate.run`.
  static Future<int> computeCoreRoiDHash64InIsolate(
    Uint8List imageBytes, {
    double insetRatio = 0.12,
  }) {
    return Isolate.run(
      () => computeCoreRoiDHash64(imageBytes, insetRatio: insetRatio),
    );
  }

  static List<double> _extractNormalizedGray64x64(
    img.Image decoded, {
    required double insetRatio,
  }) {
    final img.Image core = cropCoreRoiInset(decoded, insetRatio: insetRatio);
    final img.Image grid = img.copyResize(
      core,
      width: 64,
      height: 64,
      interpolation: img.Interpolation.average,
    );
    final List<double> raw = List<double>.filled(4096, 0.0);
    double minV = 255.0;
    double maxV = 0.0;
    int idx = 0;
    for (int y = 0; y < 64; y++) {
      for (int x = 0; x < 64; x++) {
        final p = grid.getPixel(x, y);
        final double lum = ((0.299 * p.r) + (0.587 * p.g) + (0.114 * p.b));
        raw[idx++] = lum;
        if (lum < minV) minV = lum;
        if (lum > maxV) maxV = lum;
      }
    }
    final double range = maxV - minV;
    if (range < 8.0) return raw;
    return [for (final v in raw) ((v - minV) / range) * 255.0];
  }

  static List<double> _computeQuadrantVariances64(List<double> grid64) {
    final List<double> vars = List<double>.filled(4, 0.0);
    for (int qy = 0; qy < 2; qy++) {
      for (int qx = 0; qx < 2; qx++) {
        final int qIdx = qy * 2 + qx;
        double sum = 0.0;
        for (int y = qy * 32; y < (qy + 1) * 32; y++) {
          for (int x = qx * 32; x < (qx + 1) * 32; x++) {
            sum += grid64[y * 64 + x];
          }
        }
        final double mean = sum / 1024.0;
        double sqSum = 0.0;
        for (int y = qy * 32; y < (qy + 1) * 32; y++) {
          for (int x = qx * 32; x < (qx + 1) * 32; x++) {
            final double d = grid64[y * 64 + x] - mean;
            sqSum += d * d;
          }
        }
        vars[qIdx] = math.sqrt(sqSum / 1024.0);
      }
    }
    return vars;
  }

  /// Algoritmo de Brian Kernighan $O(1)$ para contagem de bits divergentes (Distância de Hamming).
  static int hammingDistance64(int hashA, int hashB) {
    int x = hashA ^ hashB;
    int distance = 0;
    while (x != 0) {
      x &= (x - 1);
      distance++;
    }
    return distance;
  }

  /// Retorna `true` se as duas imagens forem duplicadas, recicladas ou meramente
  /// recompactadas com brilho/corte leve (`Distância de Hamming < 5`).
  static bool isDuplicateEvidence(int hashA, int hashB, {int threshold = 5}) {
    return hammingDistance64(hashA, hashB) < threshold;
  }

  /// Calcula a distância geodésica esférica de Haversine em metros entre duas coordenadas.
  static double computeHaversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusM = 6371000.0;
    final double dLat = (lat2 - lat1) * (math.pi / 180.0);
    final double dLon = (lon2 - lon1) * (math.pi / 180.0);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }
}

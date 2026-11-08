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

/// Guarda Criptográfica de Câmera Nativa e Detecção de Fraude Visual (`RN-AF-03` e `RN-AF-06`).
///
/// Toda decodificação de imagem e cálculo matricial 8x8 de luminância é executado em um
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

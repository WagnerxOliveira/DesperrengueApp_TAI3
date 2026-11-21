import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Qualidade real do fix GNSS capturado com base em `Position.accuracy` (metros).
enum LocationFixQuality {
  /// Fix de alta precisão (<= 25 m) — confiável para travar rua e pino.
  precise,

  /// Fix moderado (25 m .. 65 m) — boa aproximação, recomendar conferência rápida.
  moderate,

  /// Fix degradado (> 65 m, comum em torre celular/Wi-Fi dentro de prédios) —
  /// nunca deve ser tratado como pino exato sem confirmação manual no mapa.
  coarse,
}

enum LocationAcquisitionStatus {
  ok,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  reducedAccuracyOnly,
  unavailable,
}

class PreciseLocationFix {
  const PreciseLocationFix({
    required this.status,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.quality,
    this.isMocked = false,
  });

  final LocationAcquisitionStatus status;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final LocationFixQuality? quality;
  final bool isMocked;

  bool get hasCoordinates =>
      status == LocationAcquisitionStatus.ok &&
      latitude != null &&
      longitude != null;

  static LocationFixQuality classifyAccuracy(double accuracyMeters) {
    if (accuracyMeters <= 25.0) return LocationFixQuality.precise;
    if (accuracyMeters <= 65.0) return LocationFixQuality.moderate;
    return LocationFixQuality.coarse;
  }
}

/// Motor de aquisição GNSS de alta precisão com janela de convergência (Best-Fix Window):
///  1. Verifica GPS ativo, permissões e se o Android 12+/iOS 14+ concedeu
///     apenas "Localização aproximada" (`LocationAccuracyStatus.reduced`);
///  2. Usa `AndroidSettings(bestForNavigation, Fused)` / `AppleSettings(bestForNavigation)`;
///  3. Coleta fixes em stream por até [convergenceWindow] descartando fixes antigos
///     (> 15 s) ou mockados, parando imediatamente ao atingir `accuracy <= 18 m`
///     ou devolvendo o menor `accuracy` observado na janela.
class PreciseLocationAcquisitionService {
  const PreciseLocationAcquisitionService._();

  static const double targetInstantAccuracyMeters = 18.0;
  static const Duration maxFixAge = Duration(seconds: 15);
  static const Duration defaultConvergenceWindow = Duration(seconds: 6);

  /// Seleciona o melhor fix entre candidatos recebidos (função pura e testável).
  static Position? pickBestFreshPosition(
    Iterable<Position> samples, {
    required DateTime nowUtc,
    bool rejectMocked = true,
  }) {
    Position? best;
    for (final pos in samples) {
      if (rejectMocked && pos.isMocked) continue;
      if (pos.latitude == 0.0 && pos.longitude == 0.0) continue;
      if (pos.latitude.isNaN || pos.longitude.isNaN) continue;
      final age = nowUtc.difference(pos.timestamp.toUtc());
      if (age > maxFixAge && age.inSeconds > 0) continue;
      final acc = pos.accuracy.isFinite && pos.accuracy > 0
          ? pos.accuracy
          : 9999.0;
      if (best == null) {
        best = pos;
      } else {
        final bestAcc = best.accuracy.isFinite && best.accuracy > 0
            ? best.accuracy
            : 9999.0;
        if (acc < bestAcc) {
          best = pos;
        }
      }
    }
    return best;
  }

  static LocationSettings _platformBestSettings() {
    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: false,
        intervalDuration: const Duration(milliseconds: 800),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.other,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  static Future<PreciseLocationFix> acquire({
    Duration convergenceWindow = defaultConvergenceWindow,
    void Function(String statusText)? onProgress,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const PreciseLocationFix(
          status: LocationAcquisitionStatus.serviceDisabled,
        );
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        return const PreciseLocationFix(
          status: LocationAcquisitionStatus.permissionDenied,
        );
      }
      if (perm == LocationPermission.deniedForever) {
        return const PreciseLocationFix(
          status: LocationAcquisitionStatus.permissionDeniedForever,
        );
      }

      // Android 12+ / iOS 14+: detecta quando o usuário autorizou somente
      // "Localização aproximada" (erro intencional do OS de 1 a 3 km!).
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        try {
          final accStatus = await Geolocator.getLocationAccuracy();
          if (accStatus == LocationAccuracyStatus.reduced) {
            return const PreciseLocationFix(
              status: LocationAcquisitionStatus.reducedAccuracyOnly,
            );
          }
        } catch (_) {
          // Alguns aparelhos/emuladores antigos não suportam getLocationAccuracy.
        }
      }

      onProgress?.call('Refinando sinal de GPS...');
      final settings = _platformBestSettings();

      Position? best = await _collectBestFromStream(
        settings: settings,
        convergenceWindow: convergenceWindow,
        onProgress: onProgress,
      );

      // Fallback seguro caso o stream não emita a tempo
      best ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final acc = best.accuracy.isFinite && best.accuracy > 0
          ? best.accuracy
          : 50.0;
      return PreciseLocationFix(
        status: LocationAcquisitionStatus.ok,
        latitude: best.latitude,
        longitude: best.longitude,
        accuracyMeters: acc,
        quality: PreciseLocationFix.classifyAccuracy(acc),
        isMocked: best.isMocked,
      );
    } catch (_) {
      return const PreciseLocationFix(
        status: LocationAcquisitionStatus.unavailable,
      );
    }
  }

  static Future<Position?> _collectBestFromStream({
    required LocationSettings settings,
    required Duration convergenceWindow,
    void Function(String statusText)? onProgress,
  }) async {
    final completer = Completer<Position?>();
    Position? best;
    StreamSubscription<Position>? sub;
    Timer? timer;

    void finish() {
      if (completer.isCompleted) return;
      timer?.cancel();
      sub?.cancel();
      completer.complete(best);
    }

    timer = Timer(convergenceWindow, finish);

    try {
      sub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (pos) {
          if (pos.latitude == 0.0 && pos.longitude == 0.0) return;
          if (pos.latitude.isNaN || pos.longitude.isNaN) return;

          final nowUtc = DateTime.now().toUtc();
          final age = nowUtc.difference(pos.timestamp.toUtc());
          final bool isFresh = age <= maxFixAge || age.isNegative;

          final double acc = pos.accuracy.isFinite && pos.accuracy > 0
              ? pos.accuracy
              : 9999.0;

          if (best == null) {
            best = pos;
          } else {
            final bestAcc = best!.accuracy.isFinite && best!.accuracy > 0
                ? best!.accuracy
                : 9999.0;
            if (isFresh && acc < bestAcc) {
              best = pos;
            }
          }

          if (acc.isFinite && acc < 1000) {
            onProgress?.call('Precisão atual: ±${acc.round()} m...');
          }

          if (isFresh && acc <= targetInstantAccuracyMeters) {
            finish();
          }
        },
        onError: (_) => finish(),
        cancelOnError: true,
      );
    } catch (_) {
      finish();
    }

    return completer.future;
  }
}

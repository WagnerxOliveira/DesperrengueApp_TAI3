import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Resultado bruto retornado pelo Geocoder nativo do sistema operacional:
///  * Android: `android.location.Geocoder` (Google Play Services / Google Maps — custo zero)
///  * iOS: `CLGeocoder` (CoreLocation / Apple Maps — custo zero)
class NativeReversedPlacemark {
  const NativeReversedPlacemark({
    required this.street,
    required this.number,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.latitude,
    required this.longitude,
    required this.source,
  });

  final String street;
  final String number;
  final String neighborhood;
  final String city;
  final String state;
  final String postalCode;
  final double latitude;
  final double longitude;
  final String source;
}

typedef NativeReverseGeocoderFn = Future<NativeReversedPlacemark?> Function(
  double lat,
  double lng,
);

/// Ponte segura para o Geocoder nativo do Android (`android.location.Geocoder`)
/// e do iOS (`CLGeocoder`). Em Web/Desktop ou quando o canal nativo não está
/// registrado (ex.: testes unitários), retorna `null` silenciosamente.
class NativeReverseGeocoder {
  const NativeReverseGeocoder._();

  static const MethodChannel _channel = MethodChannel(
    'br.com.desperrengue.app/native_geocoder',
  );

  static Future<NativeReversedPlacemark?> reverseGeocode(
    double lat,
    double lng,
  ) async {
    if (kIsWeb) return null;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }

    try {
      final raw = await _channel
          .invokeMapMethod<String, dynamic>(
            'reverseGeocode',
            <String, dynamic>{'lat': lat, 'lng': lng},
          )
          .timeout(const Duration(seconds: 5));
      if (raw == null) return null;

      final street = (raw['street'] as String?)?.trim() ?? '';
      final number = (raw['number'] as String?)?.trim() ?? '';
      final neighborhood = (raw['neighborhood'] as String?)?.trim() ?? '';
      final city = (raw['city'] as String?)?.trim() ?? '';
      final state = (raw['state'] as String?)?.trim() ?? '';
      final postalCode = (raw['postalCode'] as String?)?.trim() ?? '';
      final rLat = (raw['latitude'] as num?)?.toDouble() ?? lat;
      final rLng = (raw['longitude'] as num?)?.toDouble() ?? lng;
      final source = (raw['source'] as String?)?.trim() ?? 'native_geocoder';

      if (street.isEmpty && city.isEmpty) return null;

      return NativeReversedPlacemark(
        street: street,
        number: number,
        neighborhood: neighborhood,
        city: city,
        state: state,
        postalCode: postalCode,
        latitude: rLat,
        longitude: rLng,
        source: source,
      );
    } catch (_) {
      return null;
    }
  }
}

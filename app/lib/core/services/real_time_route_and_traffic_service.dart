import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/geocode_models.dart';
import '../models/scheduling_models.dart';
import '../models/structured_service_address.dart';
import '../utils/geo.dart';
import 'accurate_geo_routing_service.dart';

/// Nível semântico de condição do trânsito urbano em tempo real.
enum TrafficConditionLevel {
  fluent,
  moderate,
  heavy,
}

/// Telemetria completa de rota viária, condição de trânsito e previsão de chegada (ETA).
@immutable
class RouteTrafficSnapshot {
  const RouteTrafficSnapshot({
    required this.polylinePoints,
    required this.distanceKm,
    required this.baseDurationMinutes,
    required this.trafficAdjustedMinutes,
    required this.trafficFactor,
    required this.condition,
    required this.conditionLabel,
    required this.estimatedArrival,
    required this.isRoadGeometry,
  });

  final List<LatLng> polylinePoints;
  final double distanceKm;
  final int baseDurationMinutes;
  final int trafficAdjustedMinutes;
  final double trafficFactor;
  final TrafficConditionLevel condition;
  final String conditionLabel;
  final DateTime estimatedArrival;
  final bool isRoadGeometry;

  /// Ex.: `'3,4 km'` ou `'850 m'`.
  String get formattedDistance {
    final meters = (distanceKm * 1000).round();
    if (meters < 1000) {
      return '${math.max(1, meters)} m';
    }
    final formatted = distanceKm < 100
        ? distanceKm.toStringAsFixed(1)
        : distanceKm.toStringAsFixed(0);
    return '${formatted.replaceAll('.', ',')} km';
  }

  /// Ex.: `'11 min'` ou `'1h 05 min'`.
  String get formattedEta {
    final mins = math.max(1, trafficAdjustedMinutes);
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m.toString().padLeft(2, '0')} min';
  }

  /// Horário local previsto de chegada no formato `'HH:mm'`.
  String get formattedArrivalTime {
    final local = estimatedArrival.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _CachedRouteGeometry {
  const _CachedRouteGeometry({
    required this.points,
    required this.distanceMeters,
    required this.baseDurationSeconds,
    required this.isRoadGeometry,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double baseDurationSeconds;
  final bool isRoadGeometry;
}

/// Motor de Roteamento Viário OSRM + Modelo Dinâmico de Trânsito Urbano +
/// Resolução Estruturada de Endereços com Preservação Inegociável de Fachada.
class RealTimeRouteAndTrafficService {
  RealTimeRouteAndTrafficService({
    http.Client? client,
    this.geocoder,
  })  : _client = client ?? http.Client(),
        _hasCustomClient = client != null;

  static RealTimeRouteAndTrafficService instance = RealTimeRouteAndTrafficService();

  final http.Client _client;
  final bool _hasCustomClient;
  final AddressGeocoder? geocoder;

  static const Duration kOsrmTimeout = Duration(milliseconds: 3500);
  static const int _kMaxRouteCacheEntries = 192;

  final LinkedHashMap<String, _CachedRouteGeometry> _routeLru =
      LinkedHashMap<String, _CachedRouteGeometry>();

  @visibleForTesting
  void clearCache() => _routeLru.clear();

  static String _roundCoord(double v) => ((v * 10000).round() / 10000).toStringAsFixed(4);

  static String _routeCacheKey(LatLng origin, LatLng destination) =>
      '${_roundCoord(origin.latitude)},${_roundCoord(origin.longitude)}->'
      '${_roundCoord(destination.latitude)},${_roundCoord(destination.longitude)}';

  static bool _isFlutterTestBinding() {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  /// Ponto de partida urbano de referência quando o GPS em tempo real ainda não emitiu posição.
  static LatLng defaultUrbanOriginForDestination(LatLng destination) {
    const pocosHub = LatLng(-21.7878, -46.5662);
    final distToHub = haversineMeters(
      pocosHub.latitude,
      pocosHub.longitude,
      destination.latitude,
      destination.longitude,
    );
    if (distToHub >= 350 && distToHub <= 35000) {
      return pocosHub;
    }
    // Se o destino estiver muito próximo ao hub central ou em outra cidade, projeta um hub
    // operacional realista a ~2,1 km na malha urbana local.
    return LatLng(
      destination.latitude + 0.0135,
      destination.longitude + 0.0145,
    );
  }

  /// Calcula rota rua a rua (OSRM Driving API com timeout de 3.5s, cache LRU `1e-4` e
  /// fallback determinístico de malha urbana ortogonal suavizada caso offline/em testes) +
  /// telemetria realista de trânsito sensível à faixa horária e sinuosidade viária.
  Future<RouteTrafficSnapshot> computeRoute({
    required LatLng origin,
    required LatLng destination,
    DateTime? departureTime,
  }) async {
    final effectiveDeparture = (departureTime ?? DateTime.now()).toLocal();
    final key = _routeCacheKey(origin, destination);

    var geometry = _routeLru.remove(key);
    if (geometry != null) {
      _routeLru[key] = geometry;
      return _buildSnapshotFromGeometry(geometry, origin, destination, effectiveDeparture);
    }

    geometry = await _fetchOrSynthesizeGeometry(origin: origin, destination: destination);
    _routeLru[key] = geometry;
    while (_routeLru.length > _kMaxRouteCacheEntries) {
      _routeLru.remove(_routeLru.keys.first);
    }

    return _buildSnapshotFromGeometry(geometry, origin, destination, effectiveDeparture);
  }

  Future<_CachedRouteGeometry> _fetchOrSynthesizeGeometry({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final straightMeters = haversineMeters(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );

    if (straightMeters < 12) {
      final microMesh = <LatLng>[
        origin,
        LatLng(
          (origin.latitude + destination.latitude) / 2 + 0.00004,
          (origin.longitude + destination.longitude) / 2 - 0.00004,
        ),
        destination,
      ];
      return _CachedRouteGeometry(
        points: List<LatLng>.unmodifiable(microMesh),
        distanceMeters: math.max(50.0, straightMeters),
        baseDurationSeconds: 60.0,
        isRoadGeometry: false,
      );
    }

    final shouldQueryNetwork = _hasCustomClient || !_isFlutterTestBinding();
    if (shouldQueryNetwork) {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=true',
      );
      try {
        final res = await _client
            .get(
              url,
              headers: const {
                'User-Agent': 'Desperrengue/2.9 (suporte@desperrengue.tech)',
                'Accept': 'application/json',
              },
            )
            .timeout(kOsrmTimeout);
        if (res.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
          if (decoded is Map<String, dynamic>) {
            final parsed = parseOsrmRoute(decoded);
            if (parsed != null && parsed.points.length >= 2 && parsed.distanceM > 0) {
              final pts = <LatLng>[
                for (final p in parsed.points) LatLng(p.lat, p.lng),
              ];
              return _CachedRouteGeometry(
                points: List<LatLng>.unmodifiable(pts),
                distanceMeters: parsed.distanceM,
                baseDurationSeconds: parsed.durationS > 0
                    ? parsed.durationS
                    : (parsed.distanceM / 8.33),
                isRoadGeometry: true,
              );
            }
          }
        }
      } catch (_) {
        // Offline / timeout / ambiente isolado: usa malha urbana ortogonal suavizada abaixo.
      }
    }

    final meshPoints = buildSmoothedUrbanMeshPolyline(origin, destination);
    final meshMeters = _computePolylineMeters(meshPoints);
    final effectiveMeters = math.max(
      meshMeters,
      straightMeters * AccurateGeoRoutingService.kUrbanRoadTortuosityFactor,
    );
    // Velocidade base urbana livre de ~31 km/h (~8.6 m/s).
    final baseSeconds = math.max(60.0, effectiveMeters / 8.6);
    return _CachedRouteGeometry(
      points: List<LatLng>.unmodifiable(meshPoints),
      distanceMeters: effectiveMeters,
      baseDurationSeconds: baseSeconds,
      isRoadGeometry: false,
    );
  }

  RouteTrafficSnapshot _buildSnapshotFromGeometry(
    _CachedRouteGeometry geometry,
    LatLng origin,
    LatLng destination,
    DateTime departure,
  ) {
    final straightMeters = math.max(
      1.0,
      haversineMeters(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      ),
    );
    final sinuosityRatio = (geometry.distanceMeters / straightMeters).clamp(1.0, 2.2);
    final sinuosityPenalty = ((sinuosityRatio - 1.15).clamp(0.0, 0.85)) * 0.12;

    final traffic = evaluateUrbanTrafficModel(
      departureTime: departure,
      sinuosityPenalty: sinuosityPenalty,
    );

    final distanceKm = double.parse((geometry.distanceMeters / 1000.0).toStringAsFixed(2));
    final rawBaseMinutes = geometry.baseDurationSeconds / 60.0;
    final baseDurationMinutes = math.max(1, rawBaseMinutes.round());
    final rawAdjusted = (rawBaseMinutes * traffic.factor).ceil();
    final trafficAdjustedMinutes = switch (traffic.condition) {
      TrafficConditionLevel.heavy => math.max(baseDurationMinutes + 1, rawAdjusted),
      TrafficConditionLevel.moderate => math.max(baseDurationMinutes, rawAdjusted),
      TrafficConditionLevel.fluent => math.max(1, rawAdjusted),
    };

    return RouteTrafficSnapshot(
      polylinePoints: geometry.points,
      distanceKm: distanceKm <= 0 ? 0.05 : distanceKm,
      baseDurationMinutes: baseDurationMinutes,
      trafficAdjustedMinutes: trafficAdjustedMinutes,
      trafficFactor: double.parse(traffic.factor.toStringAsFixed(2)),
      condition: traffic.condition,
      conditionLabel: traffic.label,
      estimatedArrival: departure.add(Duration(minutes: trafficAdjustedMinutes)),
      isRoadGeometry: geometry.isRoadGeometry,
    );
  }

  /// Modelo determinístico de tráfego urbano sensível à faixa horária local e sinuosidade:
  /// - Pico manhã (`07:00–09:00`): Trânsito Intenso
  /// - Almoço (`11:30–13:30`): Trânsito Moderado
  /// - Pico tarde/noite (`17:00–19:30`): Trânsito Intenso
  /// - Madrugada (`22:00–05:59`) e entre-picos: Trânsito Fluido
  @visibleForTesting
  static ({TrafficConditionLevel condition, String label, double factor}) evaluateUrbanTrafficModel({
    required DateTime departureTime,
    double sinuosityPenalty = 0.0,
  }) {
    final local = departureTime.toLocal();
    final minsOfDay = local.hour * 60 + local.minute;

    // Pico manhã: 07:00 (420) até 09:00 (540)
    if (minsOfDay >= 420 && minsOfDay <= 540) {
      return (
        condition: TrafficConditionLevel.heavy,
        label: 'Trânsito Intenso',
        factor: 1.48 + sinuosityPenalty,
      );
    }

    // Pico tarde: 17:00 (1020) até 19:30 (1170)
    if (minsOfDay >= 1020 && minsOfDay <= 1170) {
      return (
        condition: TrafficConditionLevel.heavy,
        label: 'Trânsito Intenso',
        factor: 1.56 + sinuosityPenalty,
      );
    }

    // Almoço: 11:30 (690) até 13:30 (810)
    if (minsOfDay >= 690 && minsOfDay <= 810) {
      return (
        condition: TrafficConditionLevel.moderate,
        label: 'Trânsito Moderado',
        factor: 1.26 + (sinuosityPenalty * 0.75),
      );
    }

    // Madrugada fluida: 22:00 (1320) até 05:59 (359)
    if (minsOfDay >= 1320 || minsOfDay < 360) {
      return (
        condition: TrafficConditionLevel.fluent,
        label: 'Trânsito Fluido',
        factor: 1.00 + (sinuosityPenalty * 0.25),
      );
    }

    // Entre-picos diurnos
    return (
      condition: TrafficConditionLevel.fluent,
      label: 'Trânsito Fluido',
      factor: 1.08 + (sinuosityPenalty * 0.45),
    );
  }

  /// Constrói malha viária urbana ortogonal suavizada (com curvas Bezier nas esquinas e rotação
  /// determinística de quarteirões), garantindo que rotas offline ou em `flutter test` NUNCA
  /// sejam renderizadas como uma linha reta seca de 2 pontos.
  @visibleForTesting
  static List<LatLng> buildSmoothedUrbanMeshPolyline(LatLng origin, LatLng destination) {
    final dLat = destination.latitude - origin.latitude;
    final dLng = destination.longitude - origin.longitude;
    final norm = math.sqrt(dLat * dLat + dLng * dLng);
    if (norm < 1e-5) {
      return <LatLng>[
        origin,
        LatLng(origin.latitude + 0.00005, origin.longitude - 0.00005),
        destination,
      ];
    }

    // Ângulo determinístico da malha urbana local (entre 18° e 32°) baseado nas coordenadas.
    final seed = (((origin.latitude * 1000).round().abs() * 31) +
            ((destination.longitude * 1000).round().abs() * 17)) %
        15;
    final theta = (18 + seed) * math.pi / 180.0;
    final cosT = math.cos(theta);
    final sinT = math.sin(theta);

    // Projeta o vetor (dLat, dLng) nos eixos ortogonais da malha urbana rotacionada (u, v).
    final uTotal = dLat * cosT + dLng * sinT;
    final vTotal = -dLat * sinT + dLng * cosT;

    LatLng fromGrid(double u, double v) {
      final lat = origin.latitude + (u * cosT - v * sinT);
      final lng = origin.longitude + (u * sinT + v * cosT);
      return LatLng(lat, lng);
    }

    // Caso o deslocamento caia quase 100% sobre um único eixo, injeta um desvio realista de quadra
    // (~12% da extensão) para contornar quarteirões em vez de formar reta colinear.
    final minCross = norm * 0.14;
    final effectiveV = vTotal.abs() < minCross
        ? (vTotal >= 0 ? minCross : -minCross)
        : vTotal;

    // 5 vértices-âncora formando corredor arterial -> avenida coletora -> rua local:
    final c0 = origin;
    final c1 = fromGrid(uTotal * 0.36, effectiveV * 0.08);
    final c2 = fromGrid(uTotal * 0.42, effectiveV * 0.68);
    final c3 = fromGrid(uTotal * 0.86, effectiveV * 0.74);
    final c4 = fromGrid(uTotal * 0.92, vTotal);
    final c5 = destination;

    final controlChain = <LatLng>[c0, c1, c2, c3, c4, c5];
    return _smoothCornersBezier(controlChain);
  }

  static List<LatLng> _smoothCornersBezier(List<LatLng> anchors) {
    if (anchors.length <= 2) return anchors;
    final out = <LatLng>[anchors.first];

    for (var i = 1; i < anchors.length - 1; i++) {
      final prev = anchors[i - 1];
      final curr = anchors[i];
      final next = anchors[i + 1];

      final enter = LatLng(
        curr.latitude + (prev.latitude - curr.latitude) * 0.24,
        curr.longitude + (prev.longitude - curr.longitude) * 0.24,
      );
      final exit = LatLng(
        curr.latitude + (next.latitude - curr.latitude) * 0.24,
        curr.longitude + (next.longitude - curr.longitude) * 0.24,
      );

      out.add(enter);
      // Ponto intermediário da curva quadrática Bezier na esquina (t = 0.5):
      out.add(
        LatLng(
          0.25 * enter.latitude + 0.50 * curr.latitude + 0.25 * exit.latitude,
          0.25 * enter.longitude + 0.50 * curr.longitude + 0.25 * exit.longitude,
        ),
      );
      out.add(exit);
    }

    out.add(anchors.last);
    return out;
  }

  static double _computePolylineMeters(List<LatLng> points) {
    var sum = 0.0;
    for (var i = 1; i < points.length; i++) {
      sum += haversineMeters(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return sum;
  }

  /// Resolve um endereço em `StructuredServiceAddress` completo e verificado:
  /// - Se `latitude`/`longitude` já existirem e forem precisos (`house`/`exact`/`pinConfirmed`),
  ///   retorna imediatamente preservando todos os campos estruturados;
  /// - Se ausentes ou imprecisos (`locality`), resolve via `AccurateGeoRoutingService` /
  ///   `PreciseGeocoder` (com cache persistente) travando `houseNumber`, `streetName`,
  ///   `neighborhood`, `city` e `uf` informados pelo cliente sem jamais sobrescrevê-los!
  Future<StructuredServiceAddress> resolveExactAddress({
    required String addressLine,
    String? summary,
    String? cep,
    String? referencePoint,
    double? latitude,
    double? longitude,
    DestinationPrecision? precision,
    bool pinConfirmed = false,
  }) async {
    final initialPrecision = pinConfirmed
        ? DestinationPrecision.exact
        : (precision ?? DestinationPrecision.street);

    var structured = StructuredServiceAddress.parse(
      addressLine,
      summary: summary,
      cep: cep,
      referencePoint: referencePoint,
      latitude: latitude,
      longitude: longitude,
      precision: initialPrecision,
      pinConfirmed: pinConfirmed,
    );

    // Enriquece metadados ausentes (ex.: CEP oficial ou bairro faltante) a partir das âncoras
    // homologadas, sem jamais tocar nos campos preenchidos pelo cliente.
    final anchorMeta = AccurateGeoRoutingService.lookupHomologatedAnchor(
      addressLine,
      summary: summary,
    );
    if (anchorMeta != null) {
      structured = structured.enrichMissing(
        streetName: anchorMeta.canonicalStreet,
        neighborhood: anchorMeta.neighborhood,
        city: anchorMeta.city,
        uf: anchorMeta.uf,
        cep: anchorMeta.cep,
      );
    }

    final hasValidCoords = latitude != null &&
        longitude != null &&
        !(latitude == 0 && longitude == 0);

    if (hasValidCoords) {
      final isPrecise = pinConfirmed ||
          precision == DestinationPrecision.exact ||
          (precision == DestinationPrecision.house &&
              AccurateGeoRoutingService.areCoordinatesConsistentWithAddress(
                addressLine,
                latitude,
                longitude,
                summary: summary,
                pinConfirmed: pinConfirmed,
              ));
      if (isPrecise) {
        return structured.copyWith(
          latitude: latitude,
          longitude: longitude,
          precision: pinConfirmed
              ? DestinationPrecision.exact
              : (precision ?? DestinationPrecision.house),
          pinConfirmed: pinConfirmed,
        );
      }
    }

    final effectiveCep = structured.cepDigits.isNotEmpty ? structured.cepDigits : cep;
    GeocodeHit? hit;

    if (geocoder != null) {
      try {
        hit = await geocoder!.geocode(
          addressLine,
          summary: summary,
          cep: effectiveCep,
        );
      } catch (_) {}
    }

    hit ??= await AccurateGeoRoutingService(
      client: _hasCustomClient ? _client : null,
    ).resolveExactAddress(
      addressLine,
      summary: summary,
      cep: effectiveCep,
    );

    if (hit == null) {
      return structured;
    }

    // Caso o display retornado traga CEP/bairro que estavam em branco no input original,
    // enriquece apenas lacunas vazias — NUNCA sobrescrevendo houseNumber/streetName/neighborhood/city!
    StructuredServiceAddress? displayParsed;
    if (hit.display.trim().isNotEmpty &&
        (structured.cep.isEmpty || structured.neighborhood.isEmpty || structured.uf.isEmpty)) {
      displayParsed = StructuredServiceAddress.parse(hit.display);
    }

    final resolvedPrecision = (structured.houseNumber.isNotEmpty &&
            hit.precision == DestinationPrecision.street &&
            anchorMeta != null)
        ? DestinationPrecision.house
        : hit.precision;

    return structured.enrichMissing(
      neighborhood: displayParsed?.neighborhood,
      city: displayParsed?.city,
      uf: displayParsed?.uf,
      cep: displayParsed?.cep,
      latitude: hit.lat,
      longitude: hit.lng,
      precision: pinConfirmed ? DestinationPrecision.exact : resolvedPrecision,
      pinConfirmed: pinConfirmed,
    );
  }
}

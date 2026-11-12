import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show LatLng;

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

/// Modo contextual de enquadramento e semântica cartográfica por status do pedido.
enum MapContextMode {
  liveProviderTransit,
  propertyFocus,
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

  static const Duration kOsrmTimeout = Duration(milliseconds: 4500);
  static const int _kMaxRouteCacheEntries = 192;

  static const Set<String> _kActiveTransitStatuses = <String>{
    'scheduled',
    'in_progress',
    'en_route',
    'provider_en_route',
  };

  final LinkedHashMap<String, _CachedRouteGeometry> _routeLru =
      LinkedHashMap<String, _CachedRouteGeometry>();

  @visibleForTesting
  void clearCache() => _routeLru.clear();

  static String _normalizeOrderStatus(String? orderStatus) {
    if (orderStatus == null) return '';
    final trimmed = orderStatus.trim();
    if (trimmed.isEmpty) return '';
    return trimmed
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]}_${m[2]}',
        )
        .replaceAll(RegExp(r'[\s\-]+'), '_')
        .toLowerCase();
  }

  /// Resolve o modo contextual do mapa conforme o status do pedido:
  /// - [MapContextMode.liveProviderTransit] SOMENTE se [userRequestedReferenceRoute] for `true`
  ///   OU ([hasAssignedProviderOrigin] for `true` E [orderStatus] normalizado pertencer a
  ///   `{'scheduled', 'in_progress', 'en_route', 'provider_en_route'}`).
  /// - [MapContextMode.propertyFocus] para `'open'`, `'awaiting_payment'`, `'awaiting_approval'`,
  ///   `'completed'`, `'canceled'`, `'disputed'`, `null`, ou quando não há `providerOrigin` real e
  ///   o usuário não solicitou visualizar rota de referência.
  static MapContextMode resolveContextMode({
    String? orderStatus,
    bool hasAssignedProviderOrigin = false,
    bool userRequestedReferenceRoute = false,
  }) {
    if (userRequestedReferenceRoute) {
      return MapContextMode.liveProviderTransit;
    }
    final normalized = _normalizeOrderStatus(orderStatus);
    if (hasAssignedProviderOrigin && _kActiveTransitStatuses.contains(normalized)) {
      return MapContextMode.liveProviderTransit;
    }
    return MapContextMode.propertyFocus;
  }

  /// Retorna `true` EXCLUSIVAMENTE quando há prestador real atribuído ([hasAssignedProviderOrigin])
  /// E o pedido está em trânsito/execução ativa (`scheduled`, `in_progress`, `en_route`,
  /// `provider_en_route`). Jamais retorna `true` para `open`, `completed`, `canceled`, `disputed`
  /// ou rotas meramente referenciais.
  static bool shouldShowArrivalClock({
    String? orderStatus,
    required bool hasAssignedProviderOrigin,
  }) {
    if (!hasAssignedProviderOrigin) return false;
    final normalized = _normalizeOrderStatus(orderStatus);
    return _kActiveTransitStatuses.contains(normalized);
  }

  /// Desloca o centro da câmera na latitude (projeção Web Mercator no [zoom] informado) para que
  /// [target] fique 100% cravado no centro óptico exato da janela livre entre [topOverlayPx] e
  /// [bottomOverlayPx].
  static LatLng computeOpticallyCenteredTarget({
    required LatLng target,
    required double zoom,
    required double topOverlayPx,
    required double bottomOverlayPx,
  }) {
    final degPerPixelLat =
        (360.0 / (256.0 * math.pow(2.0, zoom))) * math.cos(target.latitude * math.pi / 180.0);
    final southShiftDeg = ((bottomOverlayPx - topOverlayPx) / 2.0) * degPerPixelLat;
    final centeredLat = (target.latitude - southShiftDeg).clamp(-85.05112878, 85.05112878);
    return LatLng(centeredLat, target.longitude);
  }

  /// Calcula [CameraFit.bounds] seguro cobrindo [points] e [destination] (expandindo simetricamente
  /// em `±0.0008` se a amplitude em latitude ou longitude for `< 0.0008`) com margens ópticas que
  /// preservam a barra superior, os controles laterais (`+44px` à direita) e o card inferior.
  static CameraFit computeRouteCameraFit({
    required List<LatLng> points,
    required LatLng destination,
    double topOverlayPx = 104,
    double bottomOverlayPx = 176,
    double horizontalPaddingPx = 44,
    double maxZoom = 16.8,
  }) {
    var minLat = destination.latitude;
    var maxLat = destination.latitude;
    var minLng = destination.longitude;
    var maxLng = destination.longitude;

    for (final pt in points) {
      if (!pt.latitude.isFinite || !pt.longitude.isFinite) continue;
      if (pt.latitude < minLat) minLat = pt.latitude;
      if (pt.latitude > maxLat) maxLat = pt.latitude;
      if (pt.longitude < minLng) minLng = pt.longitude;
      if (pt.longitude > maxLng) maxLng = pt.longitude;
    }

    if ((maxLat - minLat) < 0.0008) {
      final midLat = (minLat + maxLat) / 2.0;
      minLat = midLat - 0.0008;
      maxLat = midLat + 0.0008;
    }
    if ((maxLng - minLng) < 0.0008) {
      final midLng = (minLng + maxLng) / 2.0;
      minLng = midLng - 0.0008;
      maxLng = midLng + 0.0008;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    return CameraFit.bounds(
      bounds: bounds,
      padding: EdgeInsets.fromLTRB(
        horizontalPaddingPx,
        topOverlayPx,
        horizontalPaddingPx + 44,
        bottomOverlayPx,
      ),
      maxZoom: maxZoom,
    );
  }

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

  @visibleForTesting
  static List<Uri> buildOsrmCascadeUrls(LatLng origin, LatLng destination) {
    final coordPair =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    const query = 'overview=full&geometries=geojson&steps=true';
    return <Uri>[
      Uri.parse('https://router.project-osrm.org/route/v1/driving/$coordPair?$query'),
      Uri.parse('https://routing.openstreetmap.de/routed-car/route/v1/driving/$coordPair?$query'),
    ];
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

  /// Calcula rota rua a rua (cascata OSRM dupla com timeout de 4.5s cada, cache LRU `1e-4` e
  /// fallback em arco geodésico suave contínuo `C∞` caso offline/em testes) + telemetria realista
  /// de trânsito sensível à faixa horária e sinuosidade viária.
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
      final microArc = buildGeodesicArcPolyline(origin, destination, segments: 12);
      return _CachedRouteGeometry(
        points: microArc,
        distanceMeters: math.max(50.0, straightMeters),
        baseDurationSeconds: 60.0,
        isRoadGeometry: false,
      );
    }

    final shouldQueryNetwork = _hasCustomClient || !_isFlutterTestBinding();
    if (shouldQueryNetwork) {
      for (final url in buildOsrmCascadeUrls(origin, destination)) {
        try {
          final res = await _client
              .get(
                url,
                headers: const {
                  'User-Agent': 'Desperrengue/2.10 (suporte@desperrengue.tech)',
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
          // Falha/timeout no endpoint OSRM atual: tenta o mirror secundário em seguida.
        }
      }
    }

    final arcPoints = buildGeodesicArcPolyline(origin, destination);
    final arcMeters = _computePolylineMeters(arcPoints);
    final effectiveMeters = math.max(
      arcMeters,
      straightMeters * AccurateGeoRoutingService.kUrbanRoadTortuosityFactor,
    );
    // Velocidade base urbana livre de ~31 km/h (~8.6 m/s).
    final baseSeconds = math.max(60.0, effectiveMeters / 8.6);
    return _CachedRouteGeometry(
      points: List<LatLng>.unmodifiable(arcPoints),
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

  /// Gera um arco geodésico quadrático suave contínuo (`C∞`) de [segments] amostras (`t` de `0.0`
  /// a `1.0`) com flecha lateral suave de `0.07 * norm` perpendicular à corda — ZERO quinas,
  /// ZERO dobras de 90° e ZERO formato em "L".
  static List<LatLng> buildGeodesicArcPolyline(
    LatLng origin,
    LatLng destination, {
    int segments = 28,
  }) {
    final count = math.max(4, segments);
    final dLat = destination.latitude - origin.latitude;
    final dLng = destination.longitude - origin.longitude;
    final norm = math.sqrt(dLat * dLat + dLng * dLng);
    if (norm < 1e-7) {
      return List<LatLng>.unmodifiable(<LatLng>[origin, destination]);
    }

    final sagitta = 0.07 * norm;
    final perpLat = (-dLng / norm) * sagitta;
    final perpLng = (dLat / norm) * sagitta;

    final points = <LatLng>[];
    for (var i = 0; i <= count; i++) {
      if (i == 0) {
        points.add(origin);
        continue;
      }
      if (i == count) {
        points.add(destination);
        continue;
      }
      final t = i / count;
      final envelope = 4.0 * t * (1.0 - t);
      points.add(
        LatLng(
          origin.latitude + (dLat * t) + (perpLat * envelope),
          origin.longitude + (dLng * t) + (perpLng * envelope),
        ),
      );
    }
    return List<LatLng>.unmodifiable(points);
  }

  /// Mantido por compatibilidade retroativa: delega integralmente para [buildGeodesicArcPolyline],
  /// garantindo curva geodésica suave contínua `C∞` sem nenhuma quina ou formato em "L".
  @visibleForTesting
  static List<LatLng> buildSmoothedUrbanMeshPolyline(LatLng origin, LatLng destination) =>
      buildGeodesicArcPolyline(origin, destination);

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

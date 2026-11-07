import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/geocode_models.dart';
import '../../../core/models/scheduling_models.dart';
import '../../../core/services/precise_geocoder.dart';
import '../../../core/services/scheduling_service.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/utils/geo.dart';
import 'service_map_widgets.dart' show LocationPickerSheet, MapAttribution, buildTileLayer;

/// Fonte da posição do usuário em tempo real (produção: `geolocator`).
typedef UserPositionStream = Stream<GeoFix> Function();

/// Resolve um endereço em coordenadas (produção: Nominatim/OSM).
typedef AddressResolver = Future<GeocodeHit?> Function(String addressLine, String? summary);

/// Stream de GPS real. Lança [LocationUnavailable] se o serviço/permissão não estiverem
/// disponíveis. Funciona no Web/PWA (API de geolocalização do navegador) e nativo.
Stream<GeoFix> geolocatorPositionStream() async* {
  if (!await Geolocator.isLocationServiceEnabled()) throw const LocationUnavailable('Ative o GPS/localização do aparelho.');
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
    throw const LocationUnavailable('Permissão de localização negada. Mostrando só o endereço.');
  }
  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 3),
  ).map((p) => GeoFix(p.latitude, p.longitude, accuracyM: p.accuracy));
}

class LocationUnavailable implements Exception {
  const LocationUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Mapa interativo (OpenStreetMap Standard + GPS em tempo real + Menor Rota pelas Ruas OSRM)
/// do endereço do serviço, aberto a partir de qualquer endereço clicável no aplicativo.
///
/// Mostra as ruas e nomes das ruas com nitidez, o marcador exato do endereço, a posição VIVA
/// do usuário, a polilinha do caminho mais curto até o ponto de encontro e permite ajustar o
/// pino atualizando automaticamente o endereço por geocodificação reversa.
class LiveLocationMapSheet extends StatefulWidget {
  const LiveLocationMapSheet({
    super.key,
    required this.addressLine,
    this.summary,
    this.latitude,
    this.longitude,
    this.precision,
    this.pinConfirmed = false,
    this.onAdjustPin,
    this.onAddressChanged,
    this.positionStream,
    this.resolver,
    this.routing,
    this.reverseGeocoder,
    this.tileLayer,
  });

  final String addressLine;
  final String? summary;

  /// Coordenadas já conhecidas do endereço (evita geocodificar de novo).
  final double? latitude;
  final double? longitude;

  /// Qualidade do ponto conhecido (rua/bairro = aproximado). Padrão: casa.
  final DestinationPrecision? precision;

  /// O cliente já confirmou o pino exato no mapa.
  final bool pinConfirmed;

  /// Só o DONO do pedido passa isto: habilita "Ajustar o ponto exato" (arrasta o mapa até a porta).
  final Future<void> Function(double lat, double lng)? onAdjustPin;

  /// Chamado quando o cliente ajusta o pino no mapa e o endereço é atualizado por geocodificação reversa.
  final FutureOr<void> Function(ReversedAddress address)? onAddressChanged;

  /// Injetáveis (testes).
  final UserPositionStream? positionStream;
  final AddressResolver? resolver;
  final RoutingService? routing;
  final Future<ReversedAddress?> Function(double lat, double lng, {String? fallbackLine})? reverseGeocoder;
  final Widget? tileLayer;

  static Future<void> show(
    BuildContext context, {
    required String addressLine,
    String? summary,
    double? latitude,
    double? longitude,
    DestinationPrecision? precision,
    bool pinConfirmed = false,
    Future<void> Function(double lat, double lng)? onAdjustPin,
    FutureOr<void> Function(ReversedAddress address)? onAddressChanged,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.92,
          child: LiveLocationMapSheet(
            addressLine: addressLine,
            summary: summary,
            latitude: latitude,
            longitude: longitude,
            precision: precision,
            pinConfirmed: pinConfirmed,
            onAdjustPin: onAdjustPin,
            onAddressChanged: onAddressChanged,
          ),
        ),
      );

  @override
  State<LiveLocationMapSheet> createState() => _LiveLocationMapSheetState();
}

class _LiveLocationMapSheetState extends State<LiveLocationMapSheet> {
  final _map = MapController();
  late final RoutingService _routing = widget.routing ?? RoutingService();
  StreamSubscription<GeoFix>? _sub;
  late String _addressLine = widget.addressLine;
  late String? _summary = widget.summary;
  LatLng? _dest;
  late DestinationPrecision _precision = widget.precision ?? DestinationPrecision.house;
  late bool _pinConfirmed = widget.pinConfirmed;
  GeoFix? _me;
  RouteInfo? _route;
  GeoFix? _routedFrom;
  LatLng? _routedTo;
  DateTime? _lastRouteAt;
  bool _fetchingRoute = false;
  String? _gpsNote;
  bool _resolving = false;
  bool _destFailed = false;
  bool _fitted = false;

  static const _fallback = LatLng(-21.7900318, -46.5647928);

  bool get _canRouteInEnv => widget.tileLayer == null || widget.routing != null;

  @override
  void initState() {
    super.initState();
    if (widget.latitude != null && widget.longitude != null) {
      _dest = LatLng(widget.latitude!, widget.longitude!);
      // Em produção, se o pino ainda não foi confirmado manualmente, geocodifica o endereço
      // para garantir que o mapa centralize exatamente na rua/número do endereço clicado.
      if (!widget.pinConfirmed && widget.tileLayer == null) {
        _resolveDestination(keepExistingOnNull: true);
      }
    } else {
      _resolveDestination();
    }
    _startGps();
  }

  Future<void> _resolveDestination({bool keepExistingOnNull = false}) async {
    setState(() => _resolving = true);
    try {
      final resolver = widget.resolver ?? ((line, summary) => PreciseGeocoder().geocode(line, summary: summary));
      final hit = await resolver(_addressLine, _summary);
      if (!mounted) return;
      setState(() {
        if (hit == null) {
          if (!keepExistingOnNull && _dest == null) {
            _destFailed = true;
          }
        } else {
          _dest = LatLng(hit.lat, hit.lng);
          _precision = hit.precision;
          _destFailed = false;
        }
      });
      _fit();
      _updateRoute(force: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fit();
      });
    } catch (_) {
      if (mounted && !keepExistingOnNull && _dest == null) {
        setState(() => _destFailed = true);
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _startGps() {
    try {
      _sub = (widget.positionStream ?? geolocatorPositionStream)().listen(
        (fix) {
          if (!mounted) return;
          setState(() {
            _me = fix;
            _gpsNote = null;
          });
          if (!_fitted) _fit();
          _updateRoute();
        },
        onError: (Object e) {
          if (mounted) setState(() => _gpsNote = e is LocationUnavailable ? e.message : 'Não foi possível acompanhar o seu GPS.');
        },
      );
    } catch (e) {
      _gpsNote = 'Não foi possível acompanhar o seu GPS.';
    }
  }

  Future<void> _updateRoute({bool force = false}) async {
    if (!_canRouteInEnv) return;
    final me = _me;
    final dest = _dest;
    if (me == null || dest == null || _fetchingRoute || !mounted) return;

    final movedMe = _routedFrom == null ? double.infinity : haversineMeters(me.lat, me.lng, _routedFrom!.lat, _routedFrom!.lng);
    final movedDest = _routedTo == null
        ? double.infinity
        : haversineMeters(dest.latitude, dest.longitude, _routedTo!.latitude, _routedTo!.longitude);
    final stale = _lastRouteAt == null || DateTime.now().difference(_lastRouteAt!) > const Duration(seconds: 20);
    if (!force && _route != null && movedMe < 40 && movedDest < 5 && !stale) return;

    final firstRoute = _route == null;
    _fetchingRoute = true;
    try {
      final r = await _routing.route(
        fromLat: me.lat,
        fromLng: me.lng,
        toLat: dest.latitude,
        toLng: dest.longitude,
      );
      if (!mounted) return;
      setState(() {
        _route = r ?? _route;
        _routedFrom = me;
        _routedTo = dest;
        _lastRouteAt = DateTime.now();
      });
      if ((firstRoute || force) && r != null) {
        final dist = haversineMeters(me.lat, me.lng, dest.latitude, dest.longitude);
        if (dist <= 25000) {
          _fit(includeMe: true);
        }
      }
    } catch (_) {
    } finally {
      _fetchingRoute = false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _map.dispose();
    super.dispose();
  }

  /// O dono arrasta o mapa até a porta e confirma: o ponto vira "pino confirmado" e o endereço é
  /// atualizado automaticamente por geocodificação reversa.
  Future<void> _adjustPin() async {
    final dest = _dest;
    final adjust = widget.onAdjustPin;
    if (adjust == null) return;
    ReversedAddress? resolvedAddr;
    final ok = await LocationPickerSheet.show(
      context,
      addressLine: _addressLine,
      reverseGeocoder: widget.reverseGeocoder,
      initial: dest == null
          ? null
          : JobDestination(
              lat: dest.latitude,
              lng: dest.longitude,
              precision: _precision,
              radiusM: 100,
              source: _pinConfirmed ? 'client_pin' : 'client_geocode',
            ),
      onAddressResolved: (addr) async {
        resolvedAddr = addr;
        if (mounted) {
          setState(() {
            _addressLine = addr.fullLine;
            _summary = addr.summary;
          });
        }
        if (widget.onAddressChanged != null) {
          await widget.onAddressChanged!(addr);
        }
      },
      onConfirm: (lat, lng) async {
        await adjust(lat, lng);
        if (mounted) {
          setState(() {
            _dest = LatLng(lat, lng);
            _precision = DestinationPrecision.house;
            _pinConfirmed = true;
            _destFailed = false;
          });
        }
      },
    );
    if (ok == true && mounted) {
      if (resolvedAddr != null) {
        setState(() {
          _addressLine = resolvedAddr!.fullLine;
          _summary = resolvedAddr!.summary;
        });
      }
      _fit();
      _updateRoute(force: true);
    }
  }

  void _fit({bool includeMe = false}) {
    final dest = _dest;
    final me = _me;
    if (dest == null && me == null) return;
    try {
      if (dest != null) {
        final nearMe = me != null && haversineMeters(me.lat, me.lng, dest.latitude, dest.longitude) <= 3500;
        if ((includeMe || nearMe) && me != null) {
          final pts = <LatLng>[
            dest,
            LatLng(me.lat, me.lng),
            ...?_route?.points.map((e) => LatLng(e.lat, e.lng)),
          ];
          _map.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(64), maxZoom: 17));
        } else {
          _map.move(dest, 17);
        }
      } else if (me != null) {
        _map.move(LatLng(me.lat, me.lng), 16);
      }
      _fitted = true;
    } catch (_) {
      // O controlador ainda não está pronto; o próximo evento tenta de novo.
    }
  }

  Future<void> _openExternalNav(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final dest = _dest;
    final me = _me;
    final meters = (dest != null && me != null) ? haversineMeters(me.lat, me.lng, dest.latitude, dest.longitude) : null;
    final approx = !_pinConfirmed && _precision != DestinationPrecision.house && _precision != DestinationPrecision.exact;

    final routePoints = <LatLng>[
      if (_route != null && _route!.points.length >= 2)
        for (final p in _route!.points) LatLng(p.lat, p.lng)
      else if (me != null && dest != null) ...[
        LatLng(me.lat, me.lng),
        dest,
      ],
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
          child: Row(
            children: [
              Icon(Icons.place_rounded, color: tk.clientAccent),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: dest == null ? null : () => _fit(includeMe: false),
                  borderRadius: BorderRadius.circular(8),
                  child: Text(
                    _addressLine,
                    key: const ValueKey('live-map-address-line'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              IconButton(tooltip: 'Fechar', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
            ],
          ),
        ),
        for (final note in [
          if (_destFailed) 'Não encontramos este endereço no mapa. Confira rua e número.',
          if (!_destFailed && approx)
            widget.onAdjustPin != null
                ? 'Localização aproximada (pela rua/bairro). Toque em "Ajustar o ponto exato" e arraste o mapa até a sua casa.'
                : 'Localização aproximada: o pino pode estar a algumas dezenas de metros da casa.',
          ?_gpsNote,
        ])
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: tk.warningSoft, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: tk.warningInk),
                const SizedBox(width: 8),
                Expanded(child: Text(note, style: TextStyle(fontSize: 12.5, color: tk.warningInk))),
              ],
            ),
          ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                FlutterMap(
                  key: const ValueKey('live-map'),
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: dest ?? (me != null ? LatLng(me.lat, me.lng) : _fallback),
                    initialZoom: dest != null ? 17 : 13,
                    minZoom: 3,
                    maxZoom: 19,
                    onMapReady: _fit,
                  ),
                  children: [
                    widget.tileLayer ?? buildTileLayer(context),
                    if (routePoints.length >= 2)
                      PolylineLayer(
                        key: const ValueKey('live-route-polyline'),
                        polylines: [
                          Polyline(
                            points: routePoints,
                            strokeWidth: 5.5,
                            color: const Color(0xFF2563EB),
                            borderStrokeWidth: 2.0,
                            borderColor: Colors.white,
                          ),
                        ],
                      ),
                    if (me != null && me.accuracyM != null)
                      CircleLayer(circles: [
                        CircleMarker(
                          point: LatLng(me.lat, me.lng),
                          radius: me.accuracyM!,
                          useRadiusInMeter: true,
                          color: tk.info.withValues(alpha: 0.14),
                          borderColor: tk.info.withValues(alpha: 0.6),
                          borderStrokeWidth: 1,
                        ),
                      ]),
                    MarkerLayer(markers: [
                      if (dest != null)
                        Marker(
                          point: dest,
                          width: 48,
                          height: 48,
                          alignment: Alignment.topCenter,
                          child: Icon(Icons.location_on_rounded, size: 44, color: tk.danger),
                        ),
                      if (me != null)
                        Marker(
                          point: LatLng(me.lat, me.lng),
                          width: 26,
                          height: 26,
                          child: Container(
                            decoration: BoxDecoration(
                              color: tk.info,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(color: tk.shadow, blurRadius: 6)],
                            ),
                          ),
                        ),
                    ]),
                    const MapAttribution(),
                  ],
                ),
                if (_resolving) const Positioned(top: 12, left: 12, child: _Pill(label: 'Localizando endereço…', loading: true)),
                if (widget.onAdjustPin != null && _dest != null)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: FloatingActionButton.extended(
                      key: const ValueKey('adjust-pin'),
                      heroTag: 'adjust_pin',
                      onPressed: _adjustPin,
                      icon: Icon(_pinConfirmed ? Icons.check_circle_rounded : Icons.edit_location_alt_rounded),
                      label: Text(_pinConfirmed ? 'Ponto confirmado · ajustar' : 'Ajustar o ponto exato'),
                    ),
                  ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'live_fit',
                        onPressed: () => _fit(includeMe: true),
                        tooltip: 'Enquadrar caminho completo',
                        child: const Icon(Icons.center_focus_strong_rounded),
                      ),
                      if (dest != null) ...[
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'live_focus_dest',
                          onPressed: () => _fit(includeMe: false),
                          tooltip: 'Focar no ponto de encontro',
                          child: const Icon(Icons.place_rounded),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.viewPaddingOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_route != null) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: tk.clientAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.route_rounded, size: 18, color: tk.clientAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Menor caminho pelas ruas: ${formatMeters(_route!.distanceM)} · ~${formatEta(_route!.eta)}',
                          key: const ValueKey('shortest-route-summary'),
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: tk.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                children: [
                  Icon(Icons.my_location_rounded, color: me == null ? tk.textMuted : tk.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      me == null
                          ? 'Aguardando o seu GPS…'
                          : (meters == null
                              ? 'Sua posição em tempo real'
                              : '${formatMeters(meters)} do endereço'
                                  '${me.accuracyM != null ? ' · precisão ±${me.accuracyM!.round()} m' : ''}'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (me != null) Icon(Icons.fiber_manual_record_rounded, size: 12, color: tk.success),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dest == null
                          ? 'Marcador do endereço indisponível no momento.'
                          : '${dest.latitude.toStringAsFixed(5)}, ${dest.longitude.toStringAsFixed(5)}',
                      style: TextStyle(fontSize: 12, color: tk.textMuted),
                    ),
                  ),
                  if (dest != null && widget.tileLayer == null) ...[
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      ),
                      onPressed: () => _openExternalNav(
                        Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${dest.latitude},${dest.longitude}&travelmode=driving'),
                      ),
                      icon: const Icon(Icons.navigation_rounded, size: 15),
                      label: const Text('Maps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      ),
                      onPressed: () => _openExternalNav(
                        Uri.parse('https://waze.com/ul?ll=${dest.latitude},${dest.longitude}&navigate=yes'),
                      ),
                      icon: const Icon(Icons.alt_route_rounded, size: 15),
                      label: const Text('Waze', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.loading = false});
  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tk.card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: tk.shadow, blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading) ...[
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
          ],
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

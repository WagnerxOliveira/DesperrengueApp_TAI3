import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/scheduling_models.dart';
import '../../../core/services/accurate_geo_routing_service.dart';
import '../../../core/services/precise_geocoder.dart';
import '../../../core/services/scheduling_service.dart';
import 'package:desperrengue_app/core/ui/design_system/design_system.dart';
import '../../../core/ui/widgets.dart' show friendlyError;
import '../../../core/utils/geo.dart';

/// Camada de blocos 100% gratuita e sem chave de API: OpenStreetMap Standard (mostra ruas,
/// nomes de ruas, números, bairros e pontos de referência nitidamente no tema claro e escuro).
Widget buildTileLayer(BuildContext context) {
  return TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'br.com.desperrengue.app',
    maxNativeZoom: 19,
  );
}

class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        margin: const EdgeInsets.all(AppSpace.s4),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8 - 2, vertical: AppSpace.s2),
        decoration: BoxDecoration(
          color: tk.card.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(AppSpace.s8 - 2),
        ),
        child: Text(
          '© OpenStreetMap contributors',
          style: AppType.caption.copyWith(color: tk.textMuted),
        ),
      ),
    );
  }
}

class _MapFabButton extends StatelessWidget {
  const _MapFabButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tk.surfaceAt(2),
        shape: BoxShape.circle,
        border: Border.all(color: tk.border),
        boxShadow: tk.elevation(2),
      ),
      child: AppIconButton(
        icon: icon,
        tooltip: tooltip,
        color: tk.text,
        size: 22,
        onPressed: onPressed,
      ),
    );
  }
}

Future<void> _openExternal(BuildContext context, Uri uri) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      AppSnackbar.show(
        context,
        'Não foi possível abrir o aplicativo de navegação.',
        kind: AppSnackKind.error,
      );
    }
  } catch (_) {
    if (context.mounted) {
      AppSnackbar.show(
        context,
        'Não foi possível abrir o aplicativo de navegação.',
        kind: AppSnackKind.error,
      );
    }
  }
}

/// Mapa da rota: pino do profissional (GPS ao vivo), pino do cliente, polilinha real nas ruas,
/// distância/ETA (OSRM) e atalhos para Google Maps / Waze.
class MapaRotaServicoModal extends StatefulWidget {
  const MapaRotaServicoModal({
    super.key,
    required this.destination,
    required this.addressLabel,
    required this.position,
    this.routing,
  });

  final JobDestination destination;
  final String addressLabel;

  /// Posição do profissional, atualizada pela tela de origem (stream único do GPS).
  final ValueListenable<GeoFix?> position;

  /// Injetável para testes (padrão: OSRM público).
  final RoutingService? routing;

  static Future<void> show(
    BuildContext context, {
    required JobDestination destination,
    required String addressLabel,
    required ValueListenable<GeoFix?> position,
  }) =>
      AppSheet.show<void>(
        context,
        enableDrag: false,
        maxHeightFactor: 0.92,
        builder: (sheetCtx) => SizedBox(
          height: (MediaQuery.sizeOf(sheetCtx).height * 0.82).clamp(360.0, 760.0),
          child: MapaRotaServicoModal(
            destination: destination,
            addressLabel: addressLabel,
            position: position,
          ),
        ),
      );

  @override
  State<MapaRotaServicoModal> createState() => _MapaRotaServicoModalState();
}

class _MapaRotaServicoModalState extends State<MapaRotaServicoModal> {
  late final RoutingService _routing = widget.routing ?? RoutingService();
  final _map = MapController();
  RouteInfo? _route;
  GeoFix? _routedFrom;
  DateTime? _lastRouteAt;
  bool _fetching = false;

  LatLng get _dest => LatLng(widget.destination.lat, widget.destination.lng);

  @override
  void initState() {
    super.initState();
    widget.position.addListener(_onPosition);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPosition());
  }

  @override
  void dispose() {
    widget.position.removeListener(_onPosition);
    super.dispose();
  }

  Future<void> _onPosition() async {
    final p = widget.position.value;
    if (p == null || _fetching || !mounted) return;
    // Só recalcula a rota se andou > 80 m ou passaram 20 s (respeita o servidor público do OSRM).
    final moved = _routedFrom == null ? double.infinity : haversineMeters(p.lat, p.lng, _routedFrom!.lat, _routedFrom!.lng);
    final stale = _lastRouteAt == null || DateTime.now().difference(_lastRouteAt!) > const Duration(seconds: 20);
    if (_route != null && moved < 80 && !stale) return;
    _fetching = true;
    final r = await _routing.route(fromLat: p.lat, fromLng: p.lng, toLat: _dest.latitude, toLng: _dest.longitude);
    _fetching = false;
    if (!mounted) return;
    setState(() {
      _route = r ?? _route;
      _routedFrom = p;
      _lastRouteAt = DateTime.now();
    });
    _fit();
  }

  void _fit() {
    final p = widget.position.value;
    final pts = <LatLng>[
      _dest,
      if (p != null) LatLng(p.lat, p.lng),
      ...?_route?.points.map((e) => LatLng(e.lat, e.lng)),
    ];
    if (pts.length < 2) return;
    try {
      _map.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(56), maxZoom: 17));
    } catch (_) {
      // O controlador ainda não está pronto; o próximo evento de posição tenta de novo.
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final dest = widget.destination;
    final p = widget.position.value;
    final straight = p == null ? null : haversineMeters(p.lat, p.lng, dest.lat, dest.lng);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.s16, 0, AppSpace.s4, AppSpace.s8),
          child: Row(
            children: [
              Icon(Icons.place_rounded, color: tk.providerAccentInk),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  widget.addressLabel,
                  maxLines: 2,
                  style: AppType.bodyStrong.copyWith(color: tk.text),
                ),
              ),
              AppIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Fechar',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        if (!dest.usableForCheckIn || dest.needsClientPin)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(AppSpace.s16, 0, AppSpace.s16, AppSpace.s8),
            padding: const EdgeInsets.all(AppSpace.s12 - 2),
            decoration: BoxDecoration(
              color: tk.warningSoft,
              borderRadius: BorderRadius.circular(AppSpace.s12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: tk.warningInk),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: Text(
                    dest.usableForCheckIn
                        ? 'Localização aproximada: o pino pode estar a algumas dezenas de metros da casa.'
                        : 'Localização aproximada (só a região). Peça ao cliente para confirmar o local no mapa.',
                    style: AppType.caption.copyWith(color: tk.warningInk),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
            child: ValueListenableBuilder<GeoFix?>(
              valueListenable: widget.position,
              builder: (context, pos, _) => Stack(
                children: [
                  RepaintBoundary(
                    child: FlutterMap(
                      mapController: _map,
                      options: MapOptions(initialCenter: _dest, initialZoom: 16, minZoom: 3, maxZoom: 19),
                      children: [
                        buildTileLayer(context),
                        if (_route != null)
                          PolylineLayer(polylines: [
                            Polyline(
                              points: [for (final e in _route!.points) LatLng(e.lat, e.lng)],
                              strokeWidth: 5.5,
                              color: tk.info,
                              borderStrokeWidth: 2,
                              borderColor: AppTokens.onColor(tk.info),
                            ),
                          ]),
                        CircleLayer(circles: [
                          if (dest.usableForCheckIn)
                            CircleMarker(
                              point: _dest,
                              radius: dest.radiusM,
                              useRadiusInMeter: true,
                              color: tk.success.withValues(alpha: 0.15),
                              borderColor: tk.success,
                              borderStrokeWidth: 1.5,
                            ),
                        ]),
                        MarkerLayer(markers: [
                          Marker(
                            point: _dest,
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: Icon(Icons.home_rounded, size: 40, color: tk.danger),
                          ),
                          if (pos != null)
                            Marker(
                              point: LatLng(pos.lat, pos.lng),
                              width: 28,
                              height: 28,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: tk.providerAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTokens.onColor(tk.providerAccent), width: 3),
                                  boxShadow: [BoxShadow(color: tk.shadow, blurRadius: 6)],
                                ),
                              ),
                            ),
                        ]),
                        const MapAttribution(),
                      ],
                    ),
                  ),
                  Positioned(
                    right: AppSpace.s12 - 2,
                    top: AppSpace.s12 - 2,
                    child: _MapFabButton(
                      icon: Icons.center_focus_strong_rounded,
                      tooltip: 'Enquadrar rota',
                      onPressed: _fit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(AppSpace.s16, AppSpace.s12, AppSpace.s16, AppSpace.s12 + MediaQuery.viewPaddingOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.route_rounded, color: tk.providerAccentInk),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Text(
                      _route != null
                          ? 'Menor caminho: ${formatMeters(_route!.distanceM)} · chegada em ${formatEta(_route!.eta)}'
                          : straight != null
                              ? '${formatMeters(straight)} em linha reta'
                              : 'Aguardando o seu GPS…',
                      style: AppType.tabular(AppType.titleSm).copyWith(color: tk.text),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s12 - 2),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Google Maps',
                      icon: Icons.navigation_rounded,
                      variant: AppButtonVariant.secondary,
                      compact: true,
                      onPressed: () => _openExternal(
                        context,
                        Uri.parse(
                          AccurateGeoRoutingService.buildGoogleMapsNavigationUrl(
                            originLat: p?.lat,
                            originLng: p?.lng,
                            fullFormattedAddress: widget.addressLabel,
                            destLat: dest.lat,
                            destLng: dest.lng,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s12 - 2),
                  Expanded(
                    child: AppButton(
                      label: 'Waze',
                      icon: Icons.alt_route_rounded,
                      variant: AppButtonVariant.secondary,
                      compact: true,
                      onPressed: () => _openExternal(context, Uri.parse('https://waze.com/ul?ll=${dest.lat},${dest.lng}&navigate=yes')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s4),
              Text('Abrir navegação externa', style: AppType.caption.copyWith(color: tk.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// O CLIENTE confirma o local exato do serviço no mapa. O servidor passa a validar a presença do
/// profissional contra este ponto (raio de 100 m).
///
/// Como nos apps de entrega: o pino fica FIXO no centro da tela e o cliente ARRASTA o mapa até a
/// porta da casa (mais preciso e fácil que tocar com o dedo). Também aceita um toque no mapa e o
/// botão "Usar minha localização" (GPS) para quem está em casa.
/// Ao mover o pino, faz geocodificação reversa automática para atualizar rua, número e bairro.
class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({
    super.key,
    required this.initial,
    required this.onConfirm,
    this.onAddressResolved,
    this.addressLine,
    this.tileLayer,
    this.reverseGeocoder,
  });

  final JobDestination? initial;
  final Future<void> Function(double lat, double lng) onConfirm;
  final FutureOr<void> Function(ReversedAddress address)? onAddressResolved;

  /// Endereço que o cliente informou (mostrado no topo e atualizado ao arrastar o pino).
  final String? addressLine;

  /// Injetável nos testes (padrão: [buildTileLayer]).
  final Widget? tileLayer;

  /// Injetável nos testes (padrão: [PreciseGeocoder.reverseGeocode]).
  final Future<ReversedAddress?> Function(double lat, double lng, {String? fallbackLine})? reverseGeocoder;

  static Future<bool?> show(
    BuildContext context, {
    required JobDestination? initial,
    required Future<void> Function(double lat, double lng) onConfirm,
    FutureOr<void> Function(ReversedAddress address)? onAddressResolved,
    String? addressLine,
    Future<ReversedAddress?> Function(double lat, double lng, {String? fallbackLine})? reverseGeocoder,
  }) =>
      AppSheet.show<bool>(
        context,
        enableDrag: false,
        maxHeightFactor: 0.92,
        builder: (sheetCtx) => SizedBox(
          height: (MediaQuery.sizeOf(sheetCtx).height * 0.82).clamp(360.0, 760.0),
          child: LocationPickerSheet(
            initial: initial,
            onConfirm: onConfirm,
            onAddressResolved: onAddressResolved,
            addressLine: addressLine,
            reverseGeocoder: reverseGeocoder,
          ),
        ),
      );

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _map = MapController();
  LatLng? _pin;
  late String _currentAddressLine = widget.addressLine ?? '';
  ReversedAddress? _resolvedAddress;
  Timer? _reverseTimer;
  int _reverseSeq = 0;
  bool _reversing = false;
  bool _pinMoved = false;
  bool _busy = false;
  bool _locating = false;

  // Centro de Poços de Caldas como último recurso; normalmente há um destino aproximado ou o GPS.
  static const _fallback = LatLng(-21.7900318, -46.5647928);

  LatLng get _start => widget.initial == null ? _fallback : LatLng(widget.initial!.lat, widget.initial!.lng);

  bool get _canReverseInEnv => widget.tileLayer == null || widget.reverseGeocoder != null;

  @override
  void initState() {
    super.initState();
    _pin = _start;
    if (widget.initial == null && widget.tileLayer == null && (widget.addressLine ?? '').trim().isNotEmpty) {
      _resolveAddress();
    }
  }

  Future<void> _resolveAddress() async {
    try {
      final hit = await PreciseGeocoder().geocode(widget.addressLine!);
      if (!mounted || hit == null) return;
      final ll = LatLng(hit.lat, hit.lng);
      setState(() => _pin = ll);
      try {
        _map.move(ll, hit.precision == DestinationPrecision.locality ? 15 : 18);
      } catch (_) {}
    } catch (_) {}
  }

  void _scheduleReverseGeocode(LatLng target) {
    _pinMoved = true;
    if (!_canReverseInEnv) return;
    _reverseTimer?.cancel();
    _reverseTimer = Timer(const Duration(milliseconds: 350), () {
      _runReverseGeocode(target);
    });
  }

  Future<ReversedAddress?> _runReverseGeocode(LatLng target) async {
    if (!_canReverseInEnv) return null;
    final seq = ++_reverseSeq;
    if (mounted) setState(() => _reversing = true);
    try {
      final fn = widget.reverseGeocoder ??
          (double la, double ln, {String? fallbackLine}) =>
              PreciseGeocoder().reverseGeocode(la, ln, fallbackLine: fallbackLine);
      final rev = await fn(
        target.latitude,
        target.longitude,
        fallbackLine: _currentAddressLine.isNotEmpty ? _currentAddressLine : widget.addressLine,
      );
      if (!mounted || seq != _reverseSeq) return rev;
      if (rev != null && rev.fullLine.trim().isNotEmpty) {
        setState(() {
          _resolvedAddress = rev;
          _currentAddressLine = rev.fullLine;
        });
      }
      return rev;
    } catch (_) {
      return null;
    } finally {
      if (mounted && seq == _reverseSeq) {
        setState(() => _reversing = false);
      }
    }
  }

  @override
  void dispose() {
    _reverseTimer?.cancel();
    _map.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) AppSnackbar.show(context, 'Permissão de localização negada.', kind: AppSnackKind.error);
        return;
      }
      final p = await Geolocator.getCurrentPosition();
      final ll = LatLng(p.latitude, p.longitude);
      if (!mounted) return;
      setState(() {
        _pin = ll;
        _pinMoved = true;
      });
      _map.move(ll, 19);
      await _runReverseGeocode(ll);
    } catch (_) {
      if (mounted) AppSnackbar.show(context, 'Não foi possível obter a localização.', kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _confirm() async {
    final pin = _pin;
    if (pin == null || _busy) return;
    _reverseTimer?.cancel();
    setState(() => _busy = true);
    try {
      if (_pinMoved && _resolvedAddress == null && _canReverseInEnv) {
        await _runReverseGeocode(pin);
      }
      await widget.onConfirm(pin.latitude, pin.longitude);
      if (_resolvedAddress != null && widget.onAddressResolved != null) {
        await widget.onAddressResolved!(_resolvedAddress!);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.s16, 0, AppSpace.s16, AppSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Confirme o local do serviço', style: AppType.title.copyWith(color: tk.text)),
              const SizedBox(height: AppSpace.s4),
              if (_currentAddressLine.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s4),
                  child: Row(
                    children: [
                      Icon(Icons.place_rounded, size: 18, color: tk.clientAccentInk),
                      const SizedBox(width: AppSpace.s8 - 2),
                      Expanded(
                        child: Text(
                          _currentAddressLine,
                          key: const ValueKey('picker-address-line'),
                          maxLines: 2,
                          style: AppType.bodyStrong.copyWith(color: tk.text),
                        ),
                      ),
                      if (_reversing) ...[
                        const SizedBox(width: AppSpace.s8),
                        const AppSkeleton(width: 16, height: 16, circle: true),
                      ],
                    ],
                  ),
                ),
              Text(
                'Arraste o mapa até deixar o pino em cima da sua casa. O endereço é atualizado automaticamente e o profissional só consegue iniciar o serviço a menos de 100 m deste ponto.',
                style: AppType.bodySm.copyWith(color: tk.textMuted),
              ),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
            child: Stack(
              children: [
                RepaintBoundary(
                  child: FlutterMap(
                    key: const ValueKey('pin-map'),
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: _start,
                      initialZoom: widget.initial == null ? 13 : (widget.initial!.precision == DestinationPrecision.locality ? 15 : 18),
                      minZoom: 3,
                      maxZoom: 19,
                      // Arrastar/zoom → o pino acompanha o CENTRO do mapa e atualiza o endereço.
                      onPositionChanged: (camera, hasGesture) {
                        if (hasGesture) {
                          setState(() => _pin = camera.center);
                          _scheduleReverseGeocode(camera.center);
                        }
                      },
                      onTap: (_, ll) {
                        setState(() => _pin = ll);
                        _map.move(ll, _map.camera.zoom);
                        _scheduleReverseGeocode(ll);
                      },
                    ),
                    children: [
                      widget.tileLayer ?? buildTileLayer(context),
                      const MapAttribution(),
                    ],
                  ),
                ),
                // Pino fixo no centro (a ponta do pino = centro exato do mapa).
                IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 44),
                      child: Icon(Icons.location_on_rounded, key: const ValueKey('center-pin'), size: 48, color: tk.danger),
                    ),
                  ),
                ),
                Positioned(
                  right: AppSpace.s12 - 2,
                  top: AppSpace.s12 - 2,
                  child: _MapFabButton(
                    icon: _locating ? Icons.gps_not_fixed_rounded : Icons.my_location_rounded,
                    tooltip: 'Usar minha localização',
                    onPressed: _locating ? null : _useMyLocation,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(AppSpace.s16, AppSpace.s12, AppSpace.s16, AppSpace.s12 + MediaQuery.viewPaddingOf(context).bottom),
          child: AppButton(
            label: 'Confirmar este local',
            icon: Icons.check_rounded,
            loading: _busy,
            onPressed: _pin == null ? null : _confirm,
          ),
        ),
      ],
    );
  }
}

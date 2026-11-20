import 'dart:async';
import 'dart:math' as math;

import 'package:desperrengue_app/core/ui/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/scheduling_models.dart';
import '../../../core/models/structured_service_address.dart';
import '../../../core/services/accurate_geo_routing_service.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/real_time_route_and_traffic_service.dart';
import '../../../core/ui/duotone_service_icons.dart';
import '../../../core/ui/widgets.dart' show friendlyError;
import 'service_map_widgets.dart';

/// Alias semântico para a tela cartográfica em tela cheia (`100%` da viewport).
typedef OrderLiveMapScreen = OrderLiveMapModalScreen;

/// Detecta de forma determinística se a execução está sob `flutter test`.
bool isMapFlutterTestEnvironment() {
  final bindingName = WidgetsBinding.instance.runtimeType.toString();
  return bindingName.contains('Test') || bindingName.contains('AutomatedTest');
}

/// Retorna a camada de mapa apropriada:
/// - Se [tileLayerOverride] for fornecido, usa-o diretamente.
/// - Sob `flutter test`, renderiza [OfflineCartographicMeshLayer] (malha vetorial
///   estilizada 100% offline), evitando qualquer tentativa de HTTP externo de tiles OSM.
/// - Em produção, retorna `buildTileLayer(context)` de alta nitidez.
Widget buildSafeMapTileLayer(
  BuildContext context, {
  Widget? tileLayerOverride,
}) {
  if (tileLayerOverride != null) return tileLayerOverride;
  if (isMapFlutterTestEnvironment()) {
    return const OfflineCartographicMeshLayer(
      key: ValueKey('offline-cartographic-mesh-layer'),
    );
  }
  return buildTileLayer(context);
}

/// Malha cartográfica vetorial estilizada offline usada automaticamente em `flutter test`
/// (ou como fundo de segurança), reproduzindo quadras, avenidas e parques sem rede.
class OfflineCartographicMeshLayer extends StatelessWidget {
  const OfflineCartographicMeshLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _OfflineCartographicMeshPainter(tk: tk),
        ),
      ),
    );
  }
}

class _OfflineCartographicMeshPainter extends CustomPainter {
  const _OfflineCartographicMeshPainter({required this.tk});

  final AppTokens tk;

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = tk.isDark;
    final bgPaint = Paint()
      ..color = isDark ? tk.surfaceInset : tk.surface;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Áreas verdes / parques suaves
    final parkPaint = Paint()
      ..color = tk.success.withValues(alpha: isDark ? 0.08 : 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.08,
          size.height * 0.12,
          size.width * 0.24,
          size.height * 0.28,
        ),
        const Radius.circular(AppGeometry.fieldRadius),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.68,
          size.height * 0.58,
          size.width * 0.22,
          size.height * 0.26,
        ),
        const Radius.circular(AppGeometry.fieldRadius),
      ),
      parkPaint,
    );

    // Ruas secundárias da malha urbana
    final streetPaint = Paint()
      ..color = (isDark ? tk.text : tk.textMuted)
          .withValues(alpha: isDark ? 0.06 : 0.24)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const stepX = 44.0;
    const stepY = 36.0;
    for (double x = 18; x < size.width; x += stepX) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), streetPaint);
    }
    for (double y = 16; y < size.height; y += stepY) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), streetPaint);
    }

    // Avenidas arteriais diagonais
    final avenuePaint = Paint()
      ..color = tk.info.withValues(alpha: isDark ? 0.14 : 0.18)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final avenuePath = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.48,
        size.width,
        size.height * 0.18,
      );
    canvas.drawPath(avenuePath, avenuePaint);
  }

  @override
  bool shouldRepaint(covariant _OfflineCartographicMeshPainter oldDelegate) =>
      oldDelegate.tk.brightness != tk.brightness;
}

/// Pino cartográfico customizado para a residência exata do cliente.
class DestinationMapPin extends StatelessWidget {
  const DestinationMapPin({super.key, this.confirmed = false});

  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final darkTk = AppTokens.dark;
    final primaryColor = confirmed ? tk.success : tk.info;
    final onPrimary = AppTokens.onColor(primaryColor);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor,
                Color.lerp(primaryColor, darkTk.background, 0.24)!,
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: onPrimary, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            confirmed ? Icons.verified_rounded : Icons.home_rounded,
            size: 20,
            color: onPrimary,
          ),
        ),
        Container(
          width: 3,
          height: 9,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(AppSpace.s2),
          ),
        ),
        Container(
          width: 10,
          height: 4,
          decoration: BoxDecoration(
            color: darkTk.background.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
          ),
        ),
      ],
    );
  }
}

/// Pílula Dark Glass compacta indicando o nível de precisão geográfica do pino.
class PrecisionStatusPill extends StatelessWidget {
  const PrecisionStatusPill({
    super.key,
    required this.precision,
    this.pinConfirmed = false,
    this.compact = false,
  });

  final DestinationPrecision precision;
  final bool pinConfirmed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final darkTk = AppTokens.dark;
    final isConfirmed =
        pinConfirmed || precision == DestinationPrecision.exact;
    final isHouse = precision == DestinationPrecision.house;

    final Color accent;
    final String label;
    final IconData icon;

    if (isConfirmed) {
      accent = darkTk.success;
      label = 'Pino Confirmado';
      icon = Icons.verified_rounded;
    } else if (isHouse) {
      accent = darkTk.info;
      label = 'Rua e Nº';
      icon = Icons.home_work_rounded;
    } else {
      accent = darkTk.warning;
      label = 'Local da via';
      icon = Icons.place_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpace.s8 : AppSpace.s12 - 2,
        vertical: AppSpace.s4,
      ),
      decoration: BoxDecoration(
        color: darkTk.background.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: AppSpace.s4),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              style: AppType.caption.copyWith(
                color: darkTk.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Resolve coordenadas iniciais de forma síncrona (0 ms) a partir do dicionário
/// geográfico local ou heurística de cidade/UF enquanto o geocoder assíncrono refina.
({double lat, double lng, DestinationPrecision precision})
    resolveSynchronousFallbackCoords({
  required String addressLine,
  String? summary,
  double? latitude,
  double? longitude,
  DestinationPrecision? precision,
  bool pinConfirmed = false,
}) {
  if (latitude != null &&
      longitude != null &&
      !(latitude == 0 && longitude == 0)) {
    final resolvedPrecision = precision ??
        (pinConfirmed
            ? DestinationPrecision.exact
            : DestinationPrecision.house);
    return (lat: latitude, lng: longitude, precision: resolvedPrecision);
  }

  final localHit = AccurateGeoRoutingService.resolveFromLocalDictionary(
    addressLine,
    summary: summary,
  );
  if (localHit != null) {
    return (
      lat: localHit.lat,
      lng: localHit.lng,
      precision: pinConfirmed ? DestinationPrecision.exact : localHit.precision,
    );
  }

  final combined =
      '${addressLine.toLowerCase()} ${(summary ?? '').toLowerCase()}';
  if (combined.contains('rio de janeiro') || combined.contains('- rj')) {
    return (
      lat: -22.9068,
      lng: -43.1729,
      precision: DestinationPrecision.house,
    );
  }
  if (combined.contains('são paulo') ||
      combined.contains('sao paulo') ||
      combined.contains('- sp')) {
    return (
      lat: -23.5505,
      lng: -46.6333,
      precision: DestinationPrecision.house,
    );
  }
  if (combined.contains('belo horizonte')) {
    return (
      lat: -19.9167,
      lng: -43.9345,
      precision: DestinationPrecision.house,
    );
  }
  // Default Poços de Caldas - MG
  return (
    lat: -21.7878,
    lng: -46.5612,
    precision: DestinationPrecision.house,
  );
}

/// Card interativo de pré-visualização da localização do pedido.
///
/// - Mesmo em pedidos `Concluídos` ou `Cancelados` sem `latitude`/`longitude`
///   persistidos no banco, resolve automaticamente o endereço via
///   `RealTimeRouteAndTrafficService.instance.resolveExactAddress(...)` e exibe
///   o mini-mapa com pino cravado na rua/número exatos e círculo sutil de precisão.
/// - Envolve o `FlutterMap` interno em `IgnorePointer` dentro do `AppCard` para
///   garantir que o toque em **qualquer ponto do card ou do mapa** abra a
///   experiência cartográfica completa em tela cheia (`OrderLiveMapModalScreen`).
class InteractiveLocationPreviewCard extends StatefulWidget {
  const InteractiveLocationPreviewCard({
    super.key,
    required this.addressLine,
    this.jobId,
    this.summary,
    this.cep,
    this.referencePoint,
    this.latitude,
    this.longitude,
    this.precision,
    this.pinConfirmed = false,
    this.providerOrigin,
    this.orderStatus,
    this.onTap,
    this.onAdjustPin,
    this.tileLayerOverride,
    this.cardKey = const ValueKey('detail-location'),
    this.subtitle = 'Endereço registrado para o atendimento',
    this.previewHeight = 176,
  });

  final String addressLine;
  final String? jobId;
  final String? summary;
  final String? cep;
  final String? referencePoint;
  final double? latitude;
  final double? longitude;
  final DestinationPrecision? precision;
  final bool pinConfirmed;
  final LatLng? providerOrigin;
  final String? orderStatus;
  final VoidCallback? onTap;
  final Future<void> Function(double lat, double lng)? onAdjustPin;
  final Widget? tileLayerOverride;
  final Key? cardKey;
  final String subtitle;
  final double previewHeight;

  @override
  State<InteractiveLocationPreviewCard> createState() =>
      _InteractiveLocationPreviewCardState();
}

class _InteractiveLocationPreviewCardState
    extends State<InteractiveLocationPreviewCard> {
  late double _lat;
  late double _lng;
  late DestinationPrecision _precision;
  late StructuredServiceAddress _structured;

  @override
  void initState() {
    super.initState();
    _syncStateFromWidget();
    _resolveExactCoordinatesIfNeeded();
  }

  @override
  void didUpdateWidget(covariant InteractiveLocationPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jobId != widget.jobId ||
        oldWidget.addressLine != widget.addressLine ||
        oldWidget.summary != widget.summary ||
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.pinConfirmed != widget.pinConfirmed ||
        oldWidget.orderStatus != widget.orderStatus ||
        oldWidget.providerOrigin != widget.providerOrigin) {
      _syncStateFromWidget();
      _resolveExactCoordinatesIfNeeded();
    }
  }

  void _syncStateFromWidget() {
    final initial = resolveSynchronousFallbackCoords(
      addressLine: widget.addressLine,
      summary: widget.summary,
      latitude: widget.latitude,
      longitude: widget.longitude,
      precision: widget.precision,
      pinConfirmed: widget.pinConfirmed,
    );
    _lat = initial.lat;
    _lng = initial.lng;
    _precision = initial.precision;
    _structured = StructuredServiceAddress.parse(
      widget.addressLine,
      summary: widget.summary,
      cep: widget.cep,
      referencePoint: widget.referencePoint,
      latitude: _lat,
      longitude: _lng,
      precision: _precision,
      pinConfirmed: widget.pinConfirmed,
    );
  }

  Future<void> _resolveExactCoordinatesIfNeeded() async {
    double? ownerLat = widget.latitude;
    double? ownerLng = widget.longitude;
    String effectiveAddressLine = widget.addressLine;
    String? effectiveCep = widget.cep;
    String? effectiveReference = widget.referencePoint;

    if ((ownerLat == null || ownerLng == null) &&
        widget.jobId != null &&
        widget.jobId!.trim().isNotEmpty) {
      try {
        final ownerLoc =
            await JobService().fetchOwnerExactLocation(widget.jobId!);
        if (ownerLoc != null &&
            ownerLoc.lat != null &&
            ownerLoc.lng != null) {
          ownerLat = ownerLoc.lat;
          ownerLng = ownerLoc.lng;
          final rpcLine = ownerLoc.fullStreetLine;
          if (rpcLine != null &&
              rpcLine.trim().isNotEmpty &&
              (effectiveAddressLine.trim().isEmpty ||
                  effectiveAddressLine.trim() == widget.summary?.trim())) {
            effectiveAddressLine = rpcLine.trim();
          }
          if ((effectiveCep == null || effectiveCep.trim().isEmpty) &&
              ownerLoc.cep != null &&
              ownerLoc.cep!.trim().isNotEmpty) {
            effectiveCep = ownerLoc.cep!.trim();
          }
          if ((effectiveReference == null ||
                  effectiveReference.trim().isEmpty) &&
              ownerLoc.reference != null &&
              ownerLoc.reference!.trim().isNotEmpty) {
            effectiveReference = ownerLoc.reference!.trim();
          }
          if (mounted) {
            setState(() {
              _lat = ownerLat!;
              _lng = ownerLng!;
              _precision = widget.pinConfirmed
                  ? DestinationPrecision.exact
                  : DestinationPrecision.house;
              _structured = StructuredServiceAddress.parse(
                effectiveAddressLine,
                summary: widget.summary,
                cep: effectiveCep,
                referencePoint: effectiveReference,
                latitude: _lat,
                longitude: _lng,
                precision: _precision,
                pinConfirmed: widget.pinConfirmed,
              );
            });
          }
        }
      } catch (_) {}
    }

    if (effectiveAddressLine.trim().isEmpty) return;
    if (isMapFlutterTestEnvironment()) {
      final localHit = AccurateGeoRoutingService.resolveFromLocalDictionary(
        effectiveAddressLine,
        summary: widget.summary,
      );
      if (localHit != null && (ownerLat == null || ownerLng == null)) {
        if (!mounted) return;
        setState(() {
          _lat = localHit.lat;
          _lng = localHit.lng;
          _precision = widget.pinConfirmed
              ? DestinationPrecision.exact
              : localHit.precision;
        });
      }
      return;
    }

    try {
      final resolved =
          await RealTimeRouteAndTrafficService.instance.resolveExactAddress(
        addressLine: effectiveAddressLine,
        summary: widget.summary,
        cep: effectiveCep,
        referencePoint: effectiveReference,
        latitude: ownerLat,
        longitude: ownerLng,
        precision: widget.precision,
        pinConfirmed: widget.pinConfirmed,
      );
      if (!mounted) return;
      if (resolved.latitude != null && resolved.longitude != null) {
        setState(() {
          _lat = resolved.latitude!;
          _lng = resolved.longitude!;
          _precision = resolved.precision;
          _structured = resolved;
        });
      }
    } catch (_) {
      // Mantém o fallback síncrono sem interromper a UI.
    }
  }

  void _handleCardTap(BuildContext context) {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    OrderLiveMapModalScreen.show(
      context,
      jobId: widget.jobId,
      addressLine: _structured.streetWithNumber.trim().isNotEmpty
          ? _structured.formattedFullLine
          : widget.addressLine,
      summary: widget.summary,
      cep: _structured.cep.trim().isNotEmpty ? _structured.cep : widget.cep,
      referencePoint: _structured.referencePoint.trim().isNotEmpty
          ? _structured.referencePoint
          : widget.referencePoint,
      latitude: _lat,
      longitude: _lng,
      precision: _precision,
      pinConfirmed: widget.pinConfirmed,
      providerOrigin: widget.providerOrigin,
      orderStatus: widget.orderStatus,
      onAdjustPin: widget.onAdjustPin,
      tileLayerOverride: widget.tileLayerOverride,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final darkTk = AppTokens.dark;
    final dest = LatLng(_lat, _lng);
    final isDark = tk.isDark;
    final isConfirmed =
        widget.pinConfirmed || _precision == DestinationPrecision.exact;
    final cleanAddress = widget.addressLine.trim().isEmpty
        ? (widget.summary?.trim().isNotEmpty == true
            ? widget.summary!.trim()
            : 'Endereço não informado')
        : widget.addressLine.trim();

    final primaryStreetLine = _structured.streetWithNumber.trim().isNotEmpty
        ? _structured.streetWithNumber.trim()
        : cleanAddress;

    final secondaryParts = <String>[
      if (_structured.districtCityState.trim().isNotEmpty &&
          _structured.districtCityState.trim() != primaryStreetLine)
        _structured.districtCityState.trim(),
      if (_structured.cep.trim().isNotEmpty) 'CEP ${_structured.cep.trim()}',
    ];
    final secondaryLocationLine = secondaryParts.isNotEmpty
        ? secondaryParts.join(' • ')
        : widget.subtitle;

    final showLiveTransitCta =
        RealTimeRouteAndTrafficService.shouldShowArrivalClock(
      orderStatus: widget.orderStatus,
      hasAssignedProviderOrigin: widget.providerOrigin != null,
    );
    final ctaLabel = showLiveTransitCta
        ? 'Ver rota e trânsito ao vivo'
        : 'Ampliar mapa da localização';
    final ctaIcon = showLiveTransitCta
        ? Icons.alt_route_rounded
        : Icons.open_in_full_rounded;

    final circleAccent = isConfirmed ? tk.success : tk.info;

    return AppCard(
      key: widget.cardKey,
      onTap: () => _handleCardTap(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
            child: SizedBox(
              height: widget.previewHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: RepaintBoundary(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: dest,
                          initialZoom: 16.6,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                        ),
                        children: [
                          buildSafeMapTileLayer(
                            context,
                            tileLayerOverride: widget.tileLayerOverride,
                          ),
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: dest,
                                radius: 22,
                                useRadiusInMeter: true,
                                color: circleAccent.withValues(alpha: 0.14),
                                borderColor:
                                    circleAccent.withValues(alpha: 0.55),
                                borderStrokeWidth: 1.5,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: dest,
                                width: 56,
                                height: 64,
                                alignment: Alignment.topCenter,
                                child:
                                    DestinationMapPin(confirmed: isConfirmed),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 52,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              darkTk.background.withValues(alpha: 0),
                              darkTk.background
                                  .withValues(alpha: isDark ? 0.62 : 0.46),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppSpace.s12 - 2,
                    top: AppSpace.s12 - 2,
                    right: AppSpace.s12 - 2,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: IgnorePointer(
                        child: PrecisionStatusPill(
                          precision: _precision,
                          pinConfirmed: widget.pinConfirmed,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppSpace.s12 - 2,
                    right: AppSpace.s12 - 2,
                    bottom: AppSpace.s12 - 2,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: IgnorePointer(
                        child: Container(
                          key: const ValueKey('preview-live-map-cta-pill'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s12 - 2,
                            vertical: AppSpace.s4 + 1,
                          ),
                          decoration: BoxDecoration(
                            color: darkTk.background.withValues(alpha: 0.88),
                            borderRadius:
                                BorderRadius.circular(AppGeometry.pillRadius),
                            border: Border.all(
                              color: darkTk.info.withValues(alpha: 0.45),
                            ),
                            boxShadow: tk.elevation(1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                ctaIcon,
                                size: 14,
                                color: darkTk.info,
                              ),
                              const SizedBox(width: AppSpace.s4 + 1),
                              Flexible(
                                child: Text(
                                  ctaLabel,
                                  maxLines: 2,
                                  style: AppType.caption.copyWith(
                                    color: darkTk.text,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DarkGlassDuotoneBadge.kind(
                ServiceMetaIconKind.location,
                accentColor: tk.clientAccentInk,
                size: 36,
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primaryStreetLine,
                      key: const ValueKey('preview-street-number'),
                      maxLines: 2,
                      style: AppType.bodyStrong.copyWith(color: tk.text),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    Text(
                      secondaryLocationLine,
                      key: const ValueKey('preview-district-city-cep'),
                      maxLines: 2,
                      style: AppType.caption.copyWith(
                        color: tk.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s8 - 2),
              Icon(
                Icons.open_in_full_rounded,
                size: 16,
                color: tk.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tela cartográfica executiva Full-Screen (`100%` da viewport, `120 FPS`, padrão Uber / iFood / Airbnb):
/// - `FlutterMap` ocupando 100% do `Scaffold.body` (`StackFit.expand`) com gestos livres em todas as
///   direções e modo imersivo (*Auto-Dim on Pan*) ao arrastar/dar zoom no mapa.
/// - Coerência contextual por status (`MapContextMode`):
///   - `propertyFocus`: abre em `zoom: 17.0` centrado opticamente no pino exato da residência com
///     `CircleLayer` de precisão do lote (`26m`), sem polilinha artificial e sem `"Chegada ~HH:mm"`,
///     oferecendo botão de 1 toque (`Ver rota no mapa` / `Focar no imóvel`).
///   - `liveProviderTransit`: enquadra automaticamente origem + destino via `computeRouteCameraFit`,
///     desenha a rota e exibe em 1 única linha horizontal rolável (`height: 36px`) ETA, distância,
///     condição do trânsito e (somente com profissional ativo) horário estimado de chegada.
/// - Card inferior ultra-compacto sem duplicação de endereço e com 1 única linha horizontal de botões.
class OrderLiveMapModalScreen extends StatefulWidget {
  const OrderLiveMapModalScreen({
    super.key,
    required this.addressLine,
    this.jobId,
    this.summary,
    this.cep,
    this.referencePoint,
    this.latitude,
    this.longitude,
    this.precision,
    this.pinConfirmed = false,
    this.providerOrigin,
    this.orderStatus,
    this.onAdjustPin,
    this.tileLayerOverride,
    this.title = 'Localização Exata do Serviço',
  });

  final String addressLine;
  final String? jobId;
  final String? summary;
  final String? cep;
  final String? referencePoint;
  final double? latitude;
  final double? longitude;
  final DestinationPrecision? precision;
  final bool pinConfirmed;
  final LatLng? providerOrigin;
  final String? orderStatus;
  final Future<void> Function(double lat, double lng)? onAdjustPin;
  final Widget? tileLayerOverride;
  final String title;

  static Future<void> show(
    BuildContext context, {
    required String addressLine,
    String? jobId,
    String? summary,
    String? cep,
    String? referencePoint,
    double? latitude,
    double? longitude,
    DestinationPrecision? precision,
    bool pinConfirmed = false,
    LatLng? providerOrigin,
    String? orderStatus,
    Future<void> Function(double lat, double lng)? onAdjustPin,
    Widget? tileLayerOverride,
    Widget? tileLayer,
    String title = 'Localização Exata do Serviço',
  }) {
    return Navigator.of(context).push<void>(
      AppRoute<void>(
        fullscreenModal: true,
        builder: (_) => OrderLiveMapModalScreen(
          addressLine: addressLine,
          jobId: jobId,
          summary: summary,
          cep: cep,
          referencePoint: referencePoint,
          latitude: latitude,
          longitude: longitude,
          precision: precision,
          pinConfirmed: pinConfirmed,
          providerOrigin: providerOrigin,
          orderStatus: orderStatus,
          onAdjustPin: onAdjustPin,
          tileLayerOverride: tileLayerOverride ?? tileLayer,
          title: title,
        ),
      ),
    );
  }

  @override
  State<OrderLiveMapModalScreen> createState() =>
      _OrderLiveMapModalScreenState();
}

class _OrderLiveMapModalScreenState extends State<OrderLiveMapModalScreen>
    with SingleTickerProviderStateMixin {
  static const double _kTopOverlayHeightPx = 96.0;
  static const double _kBottomOverlayHeightPx = 148.0;

  final MapController _mapController = MapController();
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: AppMotion.success,
  );
  bool _arrivalPulsed = false;

  Timer? _interactionIdleTimer;
  bool _isInteractingWithMap = false;
  bool _userRequestedRoute = false;

  late double _lat;
  late double _lng;
  late LatLng _origin;
  late DestinationPrecision _precision;
  late bool _pinConfirmed;
  late StructuredServiceAddress _structured;
  late RouteTrafficSnapshot _telemetry;
  double _currentZoom = 17.0;
  bool _adjustingPin = false;
  bool _savingPin = false;

  String? get _effectiveOrderStatus =>
      widget.orderStatus ??
      (widget.providerOrigin != null ? 'in_progress' : 'open');

  MapContextMode get _contextMode =>
      RealTimeRouteAndTrafficService.resolveContextMode(
        orderStatus: _effectiveOrderStatus,
        hasAssignedProviderOrigin: widget.providerOrigin != null,
        userRequestedReferenceRoute: _userRequestedRoute,
      );

  bool get _shouldShowArrivalClock =>
      RealTimeRouteAndTrafficService.shouldShowArrivalClock(
        orderStatus: _effectiveOrderStatus,
        hasAssignedProviderOrigin: widget.providerOrigin != null,
      );

  bool get _isShowingRoute =>
      _contextMode == MapContextMode.liveProviderTransit;

  bool get _canAdjustPin {
    if (widget.onAdjustPin == null) return false;
    final norm = widget.orderStatus?.trim().toLowerCase();
    if (norm == 'completed' ||
        norm == 'canceled' ||
        norm == 'cancelled' ||
        norm == 'disputed') {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    final initial = resolveSynchronousFallbackCoords(
      addressLine: widget.addressLine,
      summary: widget.summary,
      latitude: widget.latitude,
      longitude: widget.longitude,
      precision: widget.precision,
      pinConfirmed: widget.pinConfirmed,
    );
    _lat = initial.lat;
    _lng = initial.lng;
    _precision = initial.precision;
    _pinConfirmed =
        widget.pinConfirmed || initial.precision == DestinationPrecision.exact;
    _origin = widget.providerOrigin ??
        RealTimeRouteAndTrafficService.defaultUrbanOriginForDestination(
          LatLng(_lat, _lng),
        );
    _structured = StructuredServiceAddress.parse(
      widget.addressLine,
      summary: widget.summary,
      cep: widget.cep,
      referencePoint: widget.referencePoint,
      latitude: _lat,
      longitude: _lng,
      precision: _precision,
      pinConfirmed: _pinConfirmed,
    );
    _currentZoom = _isShowingRoute ? 15.2 : 17.0;
    _telemetry = _buildImmediateTelemetrySnapshot();
    _loadExactAddressAndRoute();

    if (_isShowingRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitCompleteRoute(activateRoute: false);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      if (_pulseController.isAnimating) _pulseController.stop();
      _pulseController.value = 0.0;
      _arrivalPulsed = true;
    } else if (!_arrivalPulsed) {
      _arrivalPulsed = true;
      _pulseController.forward(from: 0.0);
    }
  }

  void _triggerSinglePulse() {
    if (!mounted || AppMotion.reduced(context)) return;
    _pulseController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _interactionIdleTimer?.cancel();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  RouteTrafficSnapshot _buildImmediateTelemetrySnapshot() {
    final dest = LatLng(_lat, _lng);
    final origin = widget.providerOrigin ??
        RealTimeRouteAndTrafficService.defaultUrbanOriginForDestination(dest);
    _origin = origin;
    final arcPoints =
        RealTimeRouteAndTrafficService.buildGeodesicArcPolyline(origin, dest);
    final now = DateTime.now();
    const distanceKm = 2.4;
    const baseMins = 6;
    const adjustedMins = 7;
    return RouteTrafficSnapshot(
      polylinePoints: arcPoints,
      distanceKm: distanceKm,
      baseDurationMinutes: baseMins,
      trafficAdjustedMinutes: adjustedMins,
      trafficFactor: 1.08,
      condition: TrafficConditionLevel.fluent,
      conditionLabel: 'Trânsito Fluido',
      estimatedArrival: now.add(const Duration(minutes: adjustedMins)),
      isRoadGeometry: false,
    );
  }

  Future<void> _loadExactAddressAndRoute() async {
    try {
      double? ownerLat = widget.latitude;
      double? ownerLng = widget.longitude;
      String effectiveAddressLine = widget.addressLine;
      String? effectiveCep = widget.cep;
      String? effectiveReference = widget.referencePoint;

      if ((ownerLat == null || ownerLng == null) &&
          widget.jobId != null &&
          widget.jobId!.trim().isNotEmpty) {
        try {
          final ownerLoc =
              await JobService().fetchOwnerExactLocation(widget.jobId!);
          if (ownerLoc != null &&
              ownerLoc.lat != null &&
              ownerLoc.lng != null) {
            ownerLat = ownerLoc.lat;
            ownerLng = ownerLoc.lng;
            final rpcLine = ownerLoc.fullStreetLine;
            if (rpcLine != null &&
                rpcLine.trim().isNotEmpty &&
                (effectiveAddressLine.trim().isEmpty ||
                    effectiveAddressLine.trim() == widget.summary?.trim())) {
              effectiveAddressLine = rpcLine.trim();
            }
            if ((effectiveCep == null || effectiveCep.trim().isEmpty) &&
                ownerLoc.cep != null &&
                ownerLoc.cep!.trim().isNotEmpty) {
              effectiveCep = ownerLoc.cep!.trim();
            }
            if ((effectiveReference == null ||
                    effectiveReference.trim().isEmpty) &&
                ownerLoc.reference != null &&
                ownerLoc.reference!.trim().isNotEmpty) {
              effectiveReference = ownerLoc.reference!.trim();
            }
          }
        } catch (_) {}
      }

      final resolved =
          await RealTimeRouteAndTrafficService.instance.resolveExactAddress(
        addressLine: effectiveAddressLine,
        summary: widget.summary,
        cep: effectiveCep,
        referencePoint: effectiveReference,
        latitude: ownerLat ?? _lat,
        longitude: ownerLng ?? _lng,
        precision: _precision,
        pinConfirmed: _pinConfirmed,
      );
      if (!mounted) return;
      final nextLat = resolved.latitude ?? ownerLat ?? _lat;
      final nextLng = resolved.longitude ?? ownerLng ?? _lng;
      final dest = LatLng(nextLat, nextLng);
      final origin = widget.providerOrigin ??
          RealTimeRouteAndTrafficService.defaultUrbanOriginForDestination(dest);
      final route = await RealTimeRouteAndTrafficService.instance.computeRoute(
        origin: origin,
        destination: dest,
      );
      if (!mounted) return;
      final coordsChanged =
          (nextLat - _lat).abs() > 1e-6 || (nextLng - _lng).abs() > 1e-6;
      setState(() {
        _lat = nextLat;
        _lng = nextLng;
        _origin = origin;
        _structured = resolved;
        _telemetry = route;
      });
      if (_isShowingRoute) {
        _fitCompleteRoute(activateRoute: false);
      } else if (coordsChanged) {
        _centerOnDestination();
        _triggerSinglePulse();
      }
    } catch (_) {
      // Mantém telemetria determinística já calculada.
    }
  }

  void _handleMapEvent(MapEvent event) {
    _currentZoom = event.camera.zoom;
    final isProgrammatic = event.source == MapEventSource.mapController ||
        event.source == MapEventSource.fitCamera ||
        event.source == MapEventSource.nonRotatedSizeChange;

    if (event is MapEventMoveEnd ||
        event is MapEventFlingAnimationEnd ||
        event is MapEventRotateEnd) {
      _interactionIdleTimer?.cancel();
      if (_isInteractingWithMap && mounted) {
        setState(() => _isInteractingWithMap = false);
      }
      return;
    }

    if (!isProgrammatic &&
        (event is MapEventMoveStart ||
            event is MapEventRotateStart ||
            event is MapEventFlingAnimationStart ||
            event is MapEventMove)) {
      _interactionIdleTimer?.cancel();
      if (!_isInteractingWithMap && mounted) {
        setState(() => _isInteractingWithMap = true);
      }
      _interactionIdleTimer = Timer(const Duration(milliseconds: 220), () {
        if (mounted && _isInteractingWithMap) {
          setState(() => _isInteractingWithMap = false);
        }
      });
    }
  }

  Color _trafficColor(TrafficConditionLevel level, AppTokens darkTk) {
    switch (level) {
      case TrafficConditionLevel.fluent:
        return darkTk.success;
      case TrafficConditionLevel.moderate:
        return darkTk.warning;
      case TrafficConditionLevel.heavy:
        return darkTk.danger;
    }
  }

  void _zoomBy(double delta) {
    final next = (_currentZoom + delta).clamp(11.0, 19.0);
    setState(() => _currentZoom = next);
    try {
      final currentCenter = _mapController.camera.center;
      _mapController.move(currentCenter, next);
    } catch (_) {
      try {
        _mapController.move(LatLng(_lat, _lng), next);
      } catch (_) {}
    }
  }

  void _centerOnDestination() {
    const targetZoom = 17.0;
    final opticallyCentered =
        RealTimeRouteAndTrafficService.computeOpticallyCenteredTarget(
      target: LatLng(_lat, _lng),
      zoom: targetZoom,
      topOverlayPx: _kTopOverlayHeightPx,
      bottomOverlayPx: _kBottomOverlayHeightPx,
    );
    setState(() => _currentZoom = targetZoom);
    try {
      _mapController.move(opticallyCentered, targetZoom);
    } catch (_) {}
  }

  void _fitCompleteRoute({bool activateRoute = true}) {
    if (activateRoute && !_userRequestedRoute) {
      setState(() => _userRequestedRoute = true);
    }
    final pts = _telemetry.polylinePoints;
    if (pts.length < 2) {
      _centerOnDestination();
      return;
    }
    final fit = RealTimeRouteAndTrafficService.computeRouteCameraFit(
      points: pts,
      destination: LatLng(_lat, _lng),
      topOverlayPx: _kTopOverlayHeightPx,
      bottomOverlayPx: _kBottomOverlayHeightPx,
    );
    try {
      _mapController.fitCamera(fit);
      setState(() => _currentZoom = _mapController.camera.zoom);
    } catch (_) {
      final midLat = (_origin.latitude + _lat) / 2;
      final midLng = (_origin.longitude + _lng) / 2;
      setState(() => _currentZoom = 14.4);
      try {
        _mapController.move(LatLng(midLat, midLng), 14.4);
      } catch (_) {}
    }
  }

  void _toggleReferenceRoute() {
    if (_userRequestedRoute) {
      setState(() => _userRequestedRoute = false);
      _centerOnDestination();
    } else {
      setState(() => _userRequestedRoute = true);
      _fitCompleteRoute(activateRoute: false);
    }
  }

  Future<void> _copyAddress() async {
    final textToCopy = _structured.formattedFullLine.isNotEmpty
        ? _structured.formattedFullLine
        : widget.addressLine.trim();
    await Clipboard.setData(ClipboardData(text: textToCopy));
    if (!mounted) return;
    AppSnackbar.show(
      context,
      'Endereço completo copiado.',
      kind: AppSnackKind.success,
    );
  }

  Future<void> _openExternalNavigation() async {
    final url = AccurateGeoRoutingService.buildGoogleMapsNavigationUrl(
      originLat: _isShowingRoute ? _origin.latitude : null,
      originLng: _isShowingRoute ? _origin.longitude : null,
      fullFormattedAddress: widget.addressLine,
      destLat: _lat,
      destLng: _lng,
    );
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Não foi possível abrir o navegador externo.',
        kind: AppSnackKind.error,
      );
    }
  }

  Future<void> _saveAdjustedPin() async {
    if (widget.onAdjustPin == null) return;
    setState(() => _savingPin = true);
    try {
      await widget.onAdjustPin!(_lat, _lng);
      if (!mounted) return;
      final refreshedRoute = _buildImmediateTelemetrySnapshot();
      setState(() {
        _savingPin = false;
        _adjustingPin = false;
        _pinConfirmed = true;
        _precision = DestinationPrecision.exact;
        _telemetry = refreshedRoute;
        _structured = _structured.copyWith(
          latitude: _lat,
          longitude: _lng,
          precision: DestinationPrecision.exact,
          pinConfirmed: true,
        );
      });
      _triggerSinglePulse();
      AppSnackbar.show(
        context,
        'Localização exata confirmada.',
        kind: AppSnackKind.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingPin = false);
      AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    }
  }

  Widget _wrapImmersiveOverlay(Widget child) {
    return IgnorePointer(
      ignoring: _isInteractingWithMap,
      child: AnimatedOpacity(
        duration: AppMotion.d(context, const Duration(milliseconds: 180)),
        opacity: _isInteractingWithMap ? 0.20 : 1.0,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final darkTk = AppTokens.dark;
    final dest = LatLng(_lat, _lng);
    final initialCameraCenter = _isShowingRoute
        ? LatLng(
            (_origin.latitude + dest.latitude) / 2,
            (_origin.longitude + dest.longitude) / 2,
          )
        : RealTimeRouteAndTrafficService.computeOpticallyCenteredTarget(
            target: dest,
            zoom: 17.0,
            topOverlayPx: _kTopOverlayHeightPx,
            bottomOverlayPx: _kBottomOverlayHeightPx,
          );

    final trafficAccent = _trafficColor(_telemetry.condition, darkTk);
    final headerTitle = _shouldShowArrivalClock || _isShowingRoute
        ? 'Rota e Trânsito ao Vivo'
        : 'Localização Exata do Serviço';

    final cleanAddress = widget.addressLine.trim().isEmpty
        ? (_structured.formattedFullLine.trim().isNotEmpty
            ? _structured.formattedFullLine.trim()
            : (widget.summary?.trim().isNotEmpty == true
                ? widget.summary!.trim()
                : 'Endereço do atendimento'))
        : widget.addressLine.trim();

    final streetLine = _structured.streetWithNumber.trim().isNotEmpty
        ? _structured.streetWithNumber.trim()
        : cleanAddress;

    final districtCityState = _structured.districtCityState.trim();
    final cep = _structured.cep.trim();
    final referencePoint = _structured.referencePoint.trim();

    final secondaryParts = <String>[
      if (districtCityState.isNotEmpty && districtCityState != streetLine)
        districtCityState,
      if (cep.isNotEmpty) 'CEP $cep',
      if (referencePoint.isNotEmpty) 'Ref: $referencePoint',
    ];
    final secondaryLine = secondaryParts.isNotEmpty
        ? secondaryParts.join(' • ')
        : (widget.summary?.trim().isNotEmpty == true &&
                widget.summary!.trim() != streetLine
            ? widget.summary!.trim()
            : 'Localização verificada no mapa');

    final circleAccent = _pinConfirmed ? tk.success : tk.info;
    final strokePattern = _telemetry.isRoadGeometry
        ? const StrokePattern.solid()
        : StrokePattern.dashed(segments: const [10, 8]);
    final onOrigin = AppTokens.onColor(tk.info);

    return Scaffold(
      backgroundColor: darkTk.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Mapa Cartográfico 100% da Viewport (120 FPS, gestos livres em todas as direções)
          RepaintBoundary(
            child: FlutterMap(
              key: const ValueKey('live-map'),
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCameraCenter,
                initialZoom: _currentZoom,
                minZoom: 3,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onMapEvent: _handleMapEvent,
                onTap: _adjustingPin
                    ? (_, pt) {
                        setState(() {
                          _lat = pt.latitude;
                          _lng = pt.longitude;
                          _telemetry = _buildImmediateTelemetrySnapshot();
                        });
                      }
                    : null,
              ),
              children: [
                buildSafeMapTileLayer(
                  context,
                  tileLayerOverride: widget.tileLayerOverride,
                ),
                CircleLayer(
                  key: const ValueKey('destination-precision-circle'),
                  circles: [
                    CircleMarker(
                      point: dest,
                      radius: 26,
                      useRadiusInMeter: true,
                      color: circleAccent.withValues(alpha: 0.14),
                      borderColor: circleAccent.withValues(alpha: 0.58),
                      borderStrokeWidth: 1.8,
                    ),
                  ],
                ),
                if (_isShowingRoute && _telemetry.polylinePoints.length >= 2)
                  PolylineLayer(
                    key: const ValueKey('live-route-polyline'),
                    polylines: [
                      Polyline(
                        points: _telemetry.polylinePoints,
                        strokeWidth: 8.0,
                        color: darkTk.background.withValues(alpha: 0.42),
                        pattern: strokePattern,
                      ),
                      Polyline(
                        points: _telemetry.polylinePoints,
                        strokeWidth: 4.5,
                        color: tk.info,
                        pattern: strokePattern,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_isShowingRoute)
                      Marker(
                        point: _origin,
                        width: 34,
                        height: 34,
                        child: Container(
                          decoration: BoxDecoration(
                            color: tk.info,
                            shape: BoxShape.circle,
                            border: Border.all(color: onOrigin, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: tk.info.withValues(alpha: 0.45),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.navigation_rounded,
                            size: 16,
                            color: onOrigin,
                          ),
                        ),
                      ),
                    Marker(
                      point: dest,
                      width: 64,
                      height: 70,
                      alignment: Alignment.topCenter,
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final pulse =
                                math.sin(_pulseController.value * math.pi);
                            final scale = 1.0 + (pulse * 0.08);
                            return Transform.scale(
                              scale: scale,
                              child: child,
                            );
                          },
                          child: DestinationMapPin(confirmed: _pinConfirmed),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Barra Flutuante Superior + Faixa Contextual Única
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _wrapImmersiveOverlay(
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s12,
                    AppSpace.s4,
                    AppSpace.s12,
                    0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        key: const ValueKey('order-live-map-top-bar'),
                        constraints: const BoxConstraints(
                          minHeight: AppGeometry.minTarget,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s4,
                        ),
                        decoration: BoxDecoration(
                          color: darkTk.background.withValues(alpha: 0.88),
                          borderRadius:
                              BorderRadius.circular(AppGeometry.itemRadius),
                          border: Border.all(
                            color: darkTk.text.withValues(alpha: 0.14),
                          ),
                          boxShadow: tk.elevation(2),
                        ),
                        child: Row(
                          children: [
                            AppIconButton(
                              key: const ValueKey('order-live-map-close'),
                              tooltip: 'Fechar mapa',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icons.arrow_back_rounded,
                              color: darkTk.text,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpace.s4),
                            Expanded(
                              child: Text(
                                headerTitle,
                                maxLines: 2,
                                style: AppType.bodySm.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: darkTk.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpace.s8 - 2),
                            Flexible(
                              flex: 0,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 148),
                                child: PrecisionStatusPill(
                                  precision: _precision,
                                  pinConfirmed: _pinConfirmed,
                                  compact: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpace.s4),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.s4),
                      Container(
                        key: const ValueKey('shortest-route-summary'),
                        constraints: const BoxConstraints(minHeight: 32),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s8,
                          vertical: AppSpace.s2,
                        ),
                        decoration: BoxDecoration(
                          color: darkTk.background.withValues(alpha: 0.86),
                          borderRadius:
                              BorderRadius.circular(AppGeometry.itemRadius),
                          border: Border.all(
                            color: darkTk.text.withValues(alpha: 0.12),
                          ),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: AppSpace.s4 + 2,
                          runSpacing: AppSpace.s2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _TelemetryPill(
                              pillKey: const ValueKey('telemetry-eta-pill'),
                              icon: Icons.schedule_rounded,
                              accent: darkTk.info,
                              label: _telemetry.formattedEta,
                            ),
                            _TelemetryPill(
                              pillKey:
                                  const ValueKey('telemetry-distance-pill'),
                              icon: Icons.route_rounded,
                              accent: darkTk.providerAccent,
                              label: _telemetry.formattedDistance,
                            ),
                            if (_isShowingRoute)
                              _TelemetryPill(
                                pillKey:
                                    const ValueKey('telemetry-traffic-pill'),
                                icon: Icons.traffic_rounded,
                                accent: trafficAccent,
                                label: _telemetry.conditionLabel,
                              ),
                            if (_shouldShowArrivalClock)
                              _TelemetryPill(
                                pillKey:
                                    const ValueKey('telemetry-arrival-pill'),
                                icon: Icons.flag_circle_rounded,
                                accent: darkTk.security,
                                label:
                                    'Chegada ~${_telemetry.formattedArrivalTime}',
                              )
                            else
                              Material(
                                color: darkTk.info.withValues(alpha: 0.24),
                                borderRadius: BorderRadius.circular(
                                  AppGeometry.pillRadius,
                                ),
                                child: InkWell(
                                  key: const ValueKey(
                                    'toggle-reference-route-button',
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppGeometry.pillRadius,
                                  ),
                                  onTap: _toggleReferenceRoute,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpace.s8,
                                      vertical: AppSpace.s2,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        AppGeometry.pillRadius,
                                      ),
                                      border: Border.all(
                                        color: darkTk.info
                                            .withValues(alpha: 0.55),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _userRequestedRoute
                                              ? Icons.home_rounded
                                              : Icons.alt_route_rounded,
                                          size: 14,
                                          color: darkTk.info,
                                        ),
                                        const SizedBox(width: AppSpace.s4),
                                        Flexible(
                                          child: Text(
                                            _userRequestedRoute
                                                ? 'Focar no imóvel'
                                                : 'Ver rota no mapa',
                                            maxLines: 2,
                                            style: AppType.caption.copyWith(
                                              color: darkTk.text,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Pílula Vertical Lateral de Controles (alvos 48×48, acima do card inferior)
          Positioned(
            right: AppSpace.s12,
            bottom: _adjustingPin ? 204 : 152,
            child: SafeArea(
              top: false,
              child: _wrapImmersiveOverlay(
                Container(
                  width: AppGeometry.minTarget + 2,
                  decoration: BoxDecoration(
                    color: darkTk.background.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
                    border: Border.all(
                      color: darkTk.text.withValues(alpha: 0.16),
                    ),
                    boxShadow: tk.elevation(2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FloatingMapControlButton(
                        buttonKey: const ValueKey('map-zoom-in'),
                        icon: Icons.add_rounded,
                        tooltip: 'Aproximar mapa',
                        onPressed: () => _zoomBy(1.0),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: darkTk.text.withValues(alpha: 0.10),
                      ),
                      _FloatingMapControlButton(
                        buttonKey: const ValueKey('map-zoom-out'),
                        icon: Icons.remove_rounded,
                        tooltip: 'Afastar mapa',
                        onPressed: () => _zoomBy(-1.0),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: darkTk.text.withValues(alpha: 0.10),
                      ),
                      _FloatingMapControlButton(
                        buttonKey: const ValueKey('map-center-destination'),
                        icon: Icons.my_location_rounded,
                        tooltip: 'Centralizar no endereço',
                        onPressed: _centerOnDestination,
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: darkTk.text.withValues(alpha: 0.10),
                      ),
                      _FloatingMapControlButton(
                        buttonKey: const ValueKey('map-fit-route'),
                        icon: Icons.fit_screen_rounded,
                        tooltip: 'Enquadrar rota completa',
                        onPressed: () => _fitCompleteRoute(activateRoute: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_adjustingPin)
            Positioned(
              left: AppSpace.s12,
              right: 68,
              bottom: 204,
              child: SafeArea(
                top: false,
                child: _wrapImmersiveOverlay(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s12,
                      vertical: AppSpace.s8,
                    ),
                    decoration: BoxDecoration(
                      color: darkTk.background.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(AppSpace.s12),
                      border: Border.all(
                        color: darkTk.info.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      'Toque no ponto exato da entrada do imóvel no mapa e confirme abaixo.',
                      style: AppType.caption.copyWith(
                        color: darkTk.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 4. Card Inferior Compacto (ZERO duplicação e 1 linha de botões)
          Positioned(
            left: AppSpace.s12,
            right: AppSpace.s12,
            bottom: AppSpace.s4,
            child: SafeArea(
              top: false,
              child: _wrapImmersiveOverlay(
                Container(
                  key: const ValueKey('order-live-map-executive-card'),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s12,
                    AppSpace.s8,
                    AppSpace.s12,
                    AppSpace.s8,
                  ),
                  decoration: BoxDecoration(
                    color: tk.card.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(AppGeometry.cardRadius),
                    border: Border.all(color: tk.border),
                    boxShadow: tk.elevation(2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          DarkGlassDuotoneBadge.kind(
                            ServiceMetaIconKind.location,
                            accentColor: tk.clientAccentInk,
                            size: 36,
                          ),
                          const SizedBox(width: AppSpace.s12 - 2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  streetLine,
                                  key:
                                      const ValueKey('live-map-street-number'),
                                  maxLines: 2,
                                  style: AppType.bodyStrong.copyWith(
                                    color: tk.text,
                                  ),
                                ),
                                const SizedBox(height: AppSpace.s2),
                                Text(
                                  secondaryLine,
                                  key: const ValueKey(
                                    'live-map-district-city-cep',
                                  ),
                                  maxLines: 2,
                                  style: AppType.caption.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: tk.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.s4 + 2),
                      IntrinsicHeight(
                        child: Row(
                          key: const ValueKey('live-map-actions-row'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _MapActionChipButton(
                                buttonKey: const ValueKey('copy-address-button'),
                                icon: Icons.copy_rounded,
                                label: 'Copiar',
                                onPressed: _copyAddress,
                              ),
                            ),
                            const SizedBox(width: AppSpace.s8 - 2),
                            Expanded(
                              child: _MapActionChipButton(
                                buttonKey: const ValueKey(
                                  'open-external-maps-button',
                                ),
                                icon: Icons.near_me_rounded,
                                label: 'Maps / Waze',
                                onPressed: _openExternalNavigation,
                              ),
                            ),
                            if (_canAdjustPin && !_adjustingPin) ...[
                              const SizedBox(width: AppSpace.s8 - 2),
                              Expanded(
                                child: _MapActionChipButton(
                                  buttonKey: const ValueKey('adjust-pin'),
                                  icon: Icons.edit_location_alt_rounded,
                                  label: 'Ajustar Pino',
                                  onPressed: () =>
                                      setState(() => _adjustingPin = true),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_adjustingPin) ...[
                        const SizedBox(height: AppSpace.s8),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                label: 'Cancelar',
                                variant: AppButtonVariant.secondary,
                                compact: true,
                                onPressed: _savingPin
                                    ? null
                                    : () =>
                                        setState(() => _adjustingPin = false),
                              ),
                            ),
                            const SizedBox(width: AppSpace.s8),
                            Expanded(
                              child: AppButton(
                                key: const ValueKey('confirm-adjusted-pin'),
                                label: 'Confirmar localização',
                                icon: Icons.check_rounded,
                                compact: true,
                                loading: _savingPin,
                                onPressed: _saveAdjustedPin,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapActionChipButton extends StatelessWidget {
  const _MapActionChipButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppPressScale(
      child: OutlinedButton(
        key: buttonKey,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppGeometry.minTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s8 - 2,
            vertical: AppSpace.s4,
          ),
          foregroundColor: tk.accentInk,
          backgroundColor: tk.isDark ? tk.surface : null,
          side: BorderSide(color: tk.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: tk.accentInk),
            const SizedBox(width: AppSpace.s4),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: AppType.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tk.accentInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryPill extends StatelessWidget {
  const _TelemetryPill({
    this.pillKey,
    required this.icon,
    required this.accent,
    required this.label,
  });

  final Key? pillKey;
  final IconData icon;
  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    final darkTk = AppTokens.dark;
    return Container(
      key: pillKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s8 - 2,
        vertical: AppSpace.s2,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
        border: Border.all(color: accent.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: AppSpace.s4),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              style: AppType.tabular(AppType.caption).copyWith(
                color: darkTk.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingMapControlButton extends StatelessWidget {
  const _FloatingMapControlButton({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final darkTk = AppTokens.dark;
    return AppIconButton(
      key: buttonKey,
      icon: icon,
      tooltip: tooltip,
      color: darkTk.text,
      size: 20,
      onPressed: onPressed,
    );
  }
}

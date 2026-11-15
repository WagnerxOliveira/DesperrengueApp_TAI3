import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../core/analytics/founder_dashboard_models.dart';
import '../../../core/ui/category_brand_emblem.dart';
import '../data/founder_cockpit_repository.dart';
import 'founder_animations_and_shaders.dart';
import 'founder_executive_calendar_sheet.dart';

bool _isRunningInWidgetTest() {
  final bindingName = WidgetsBinding.instance.runtimeType.toString();
  return bindingName.contains('TestWidgetsFlutterBinding') ||
      bindingName.contains('AutomatedTestWidgetsFlutterBinding') ||
      bindingName.contains('LiveTestWidgetsFlutterBinding');
}

String _formatDateBrShort(DateTime? utc) {
  if (utc == null) return '—';
  final brt = utc.toUtc().subtract(const Duration(hours: 3));
  final dd = brt.day.toString().padLeft(2, '0');
  final mm = brt.month.toString().padLeft(2, '0');
  final yyyy = brt.year.toString().padLeft(4, '0');
  return '$dd/$mm/$yyyy';
}

Color founderStatusColor(String status) {
  switch (status.trim().toLowerCase()) {
    case 'in_progress':
    case 'awaiting_approval':
      return FounderSovereignTokens.imperialGoldBright;
    case 'completed':
      return FounderSovereignTokens.solvencyEmerald;
    case 'scheduled':
      return FounderSovereignTokens.cyberCyan;
    case 'disputed':
      return FounderSovereignTokens.crimsonAlert;
    case 'canceled':
    case 'cancelled':
      return FounderSovereignTokens.mutedInk;
    default:
      return FounderSovereignTokens.warmAmber;
  }
}

String founderStatusLabelPt(String status) {
  switch (status.trim().toLowerCase()) {
    case 'open':
      return 'Aguardando orçamento';
    case 'awaiting_payment':
      return 'Aguardando PIX';
    case 'scheduled':
      return 'Agendado';
    case 'in_progress':
      return 'Em atendimento';
    case 'awaiting_approval':
      return 'Aguardando aprovação';
    case 'completed':
      return 'Concluído';
    case 'disputed':
      return 'Com problema';
    case 'canceled':
    case 'cancelled':
      return 'Cancelado';
    default:
      return status;
  }
}

String _humanEscrowLabelPt(String raw) {
  switch (raw.trim().toUpperCase()) {
    case 'HELD':
    case 'LOCKED':
    case 'FUNDED':
      return 'Dinheiro protegido';
    case 'RELEASED':
    case 'SETTLED':
      return 'Liberado ao profissional';
    case 'DISPUTED':
    case 'FROZEN':
      return 'Retido para análise';
    case 'REFUNDED':
      return 'Devolvido ao cliente';
    case 'NONE':
    case '':
      return 'Aguardando pagamento';
    default:
      return 'Pagamento protegido';
  }
}

String _humanKycLabelPt(String? raw) {
  switch ((raw ?? '').trim().toUpperCase()) {
    case 'APPROVED':
    case 'ACTIVE':
    case 'VERIFIED':
      return 'Documentos aprovados';
    case 'PENDING':
    case 'IN_REVIEW':
      return 'Documentos em análise';
    case 'REJECTED':
      return 'Documento recusado';
    default:
      return 'Documentos pendentes';
  }
}

String _humanQuoteStatusPt(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'accepted':
    case 'approved':
      return 'Aceito';
    case 'rejected':
    case 'declined':
      return 'Recusado';
    case 'expired':
      return 'Expirado';
    default:
      return 'Aguardando resposta';
  }
}

String _humanLedgerEntryLabelPt(Map<String, dynamic> entry) {
  final raw =
      (entry['entry_kind'] ?? entry['kind'] ?? '').toString().toUpperCase();
  if (raw.contains('ESCROW') || raw.contains('HOLD') || raw.contains('DEPOSIT')) {
    return 'Valor pago pelo cliente (guardado)';
  }
  if (raw.contains('PROVIDER') || raw.contains('PAYOUT')) {
    return 'Repasse para o profissional';
  }
  if (raw.contains('FEE') ||
      raw.contains('TAKE_RATE') ||
      raw.contains('PLATFORM')) {
    return 'Comissão do Desperrengue';
  }
  if (raw.contains('WARRANTY') || raw.contains('POOL')) {
    return 'Reserva de garantia (90 dias)';
  }
  if (raw.contains('REFUND')) {
    return 'Devolução ao cliente';
  }
  return 'Movimentação financeira registrada';
}

/// Estima o ganho líquido aproximado da plataforma (`~12,69%` sobre serviço sem peças)
/// quando apenas `amountCents` está disponível no pino cartográfico.
int _estimateNetProfitFromAmountCents(int amountCents) {
  if (amountCents <= 0) return 0;
  return (amountCents * 1269) ~/ 10000;
}

// ============================================================================
// 1. MAPA EXECUTIVO AO VIVO + ÍCONES ESCULPIDOS + TELA CHEIA INTERATIVA
// ============================================================================

/// Matriz *Uber Black Velvet* de alto contraste para mapa noturno executivo:
/// preserva avenidas nítidas em grafite-azulado sem esbranquiçar quadras.
const ColorFilter _kObsidianMapTileFilter = ColorFilter.matrix(<double>[
  -0.21, -0.53, -0.13, 0, 198, // R
  -0.19, -0.49, -0.12, 0, 209, // G
  -0.15, -0.42, -0.10, 0, 228, // B
  0, 0, 0, 1, 0, // A
]);

/// Matriz arquitetônica limpa para modo diurno executivo com contraste suave.
const ColorFilter _kDaylightMapTileFilter = ColorFilter.matrix(<double>[
  0.94, 0.02, 0.01, 0, 4, // R
  0.01, 0.95, 0.02, 0, 4, // G
  0.01, 0.02, 0.97, 0, 6, // B
  0, 0, 0, 1, 0, // A
]);

LatLng _computeMapCenter(List<CeoLiveMapPoint> pts) {
  const brazilCenter = LatLng(-21.7878, -46.5614);
  if (pts.isEmpty) return brazilCenter;
  var sumLat = 0.0;
  var sumLng = 0.0;
  for (final p in pts) {
    sumLat += p.lat;
    sumLng += p.lng;
  }
  return LatLng(sumLat / pts.length, sumLng / pts.length);
}

double _computeMapZoom(List<CeoLiveMapPoint> pts) {
  if (pts.isEmpty) return 12.8;
  if (pts.length == 1) return 14.2;
  var minLat = pts.first.lat;
  var maxLat = pts.first.lat;
  var minLng = pts.first.lng;
  var maxLng = pts.first.lng;
  for (final p in pts) {
    if (p.lat < minLat) minLat = p.lat;
    if (p.lat > maxLat) maxLat = p.lat;
    if (p.lng < minLng) minLng = p.lng;
    if (p.lng > maxLng) maxLng = p.lng;
  }
  final span = math.max((maxLat - minLat).abs(), (maxLng - minLng).abs());
  if (span < 0.02) return 14.2;
  if (span < 0.08) return 12.5;
  if (span < 0.35) return 10.6;
  if (span < 1.5) return 8.4;
  if (span < 6.0) return 6.2;
  return 4.5;
}

List<CeoLiveMapPoint> _filterMapPoints(
  List<CeoLiveMapPoint> source,
  String statusFilter,
) {
  return source.where((p) {
    if (!p.lat.isFinite || !p.lng.isFinite) return false;
    if (p.lat == 0 && p.lng == 0) return false;
    switch (statusFilter) {
      case 'execution':
        return p.status == 'in_progress' || p.status == 'awaiting_approval';
      case 'scheduled':
        return p.status == 'scheduled';
      case 'open':
        return p.status == 'open' || p.status == 'awaiting_payment';
      case 'completed':
        return p.status == 'completed';
      case 'disputed':
        return p.status == 'disputed';
      default:
        return true;
    }
  }).toList(growable: false);
}

class FounderLiveGeoRadarCard extends StatefulWidget {
  const FounderLiveGeoRadarCard({
    super.key,
    required this.points,
    required this.onInspectOrder,
    this.privacyBlurActive = false,
    this.enableNetworkTiles,
  });

  final List<CeoLiveMapPoint> points;
  final void Function(String jobId, String orderCode) onInspectOrder;
  final bool privacyBlurActive;
  final bool? enableNetworkTiles;

  @override
  State<FounderLiveGeoRadarCard> createState() =>
      _FounderLiveGeoRadarCardState();
}

class _FounderLiveGeoRadarCardState extends State<FounderLiveGeoRadarCard> {
  final MapController _mapController = MapController();
  String _statusFilter = 'all';
  String? _selectedJobId;
  bool _nightMode = true;

  List<CeoLiveMapPoint> get _filteredPoints =>
      _filterMapPoints(widget.points, _statusFilter);

  void _fitAllPoints() {
    HapticFeedback.selectionClick();
    final pts = _filteredPoints;
    try {
      _mapController.move(_computeMapCenter(pts), _computeMapZoom(pts));
    } catch (_) {}
  }

  void _zoomBy(double delta) {
    HapticFeedback.selectionClick();
    try {
      final cam = _mapController.camera;
      final nextZoom = (cam.zoom + delta).clamp(3.0, 18.5);
      _mapController.move(cam.center, nextZoom);
    } catch (_) {}
  }

  void _selectPin(CeoLiveMapPoint p) {
    HapticFeedback.selectionClick();
    setState(() => _selectedJobId = p.jobId);
    try {
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(
        LatLng(p.lat, p.lng),
        math.max(currentZoom, 13.8),
      );
    } catch (_) {}
  }

  Future<void> _openFullScreenMap() async {
    HapticFeedback.mediumImpact();
    await FounderFullScreenMapModal.show(
      context,
      points: widget.points,
      initialFilter: _statusFilter,
      initialSelectedJobId: _selectedJobId,
      initialNightMode: _nightMode,
      privacyBlurActive: widget.privacyBlurActive,
      enableNetworkTiles: widget.enableNetworkTiles,
      onInspectOrder: widget.onInspectOrder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pts = _filteredPoints;
    final useNetworkTiles =
        widget.enableNetworkTiles ?? !_isRunningInWidgetTest();

    CeoLiveMapPoint? selectedPoint;
    if (_selectedJobId != null) {
      for (final p in pts) {
        if (p.jobId == _selectedJobId) {
          selectedPoint = p;
          break;
        }
      }
    }
    selectedPoint ??= pts.isNotEmpty ? pts.first : null;

    return FounderGlassCard(
      key: const ValueKey<String>('ceo-live-geo-radar-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: FounderSovereignTokens.imperialGoldSoft,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: FounderSovereignTokens.imperialGold
                        .withValues(alpha: 0.42),
                  ),
                ),
                child: const Icon(
                  Icons.map_rounded,
                  size: 18,
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Mapa de Serviços (${pts.length})',
                      style: FounderSovereignTokens.titleStyle(fontSize: 16),
                    ),
                    Text(
                      'Toque em um ícone de profissão ou abra o mapa grande',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FounderSovereignTokens.subtitleStyle(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                key: const ValueKey<String>('ceo-expand-fullscreen-map-btn'),
                onPressed: _openFullScreenMap,
                style: FilledButton.styleFrom(
                  backgroundColor: FounderSovereignTokens.imperialGoldSoft,
                  foregroundColor: FounderSovereignTokens.imperialGoldBright,
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  side: BorderSide(
                    color: FounderSovereignTokens.imperialGold
                        .withValues(alpha: 0.48),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.open_in_full_rounded, size: 15),
                label: const Text(
                  'Mapa grande',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _buildFilterChip('all', 'Todos (${widget.points.length})'),
                const SizedBox(width: 6),
                _buildFilterChip('execution', 'Em atendimento'),
                const SizedBox(width: 6),
                _buildFilterChip('scheduled', 'Agendados'),
                const SizedBox(width: 6),
                _buildFilterChip('open', 'Aguardando PIX'),
                const SizedBox(width: 6),
                _buildFilterChip('completed', 'Concluídos'),
                const SizedBox(width: 6),
                _buildFilterChip('disputed', 'Com problema'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FounderPrivacyBlurWrap(
            privacyBlurActive: widget.privacyBlurActive,
            borderRadius: 18,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  color: _nightMode
                      ? const Color(0xFF0A0F18)
                      : const Color(0xFFE9EEF5),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: FounderSovereignTokens.crispBorderStrong,
                  ),
                ),
                child: Stack(
                  children: <Widget>[
                    // Malha urbana vetorial arquitetônica (garante beleza imediata mesmo offline)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ExecutiveOfflineCityMapPainter(
                          nightMode: _nightMode,
                        ),
                      ),
                    ),
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _computeMapCenter(pts),
                        initialZoom: _computeMapZoom(pts),
                        backgroundColor: Colors.transparent,
                      ),
                      children: <Widget>[
                        if (useNetworkTiles)
                          ColorFiltered(
                            colorFilter: _nightMode
                                ? _kObsidianMapTileFilter
                                : _kDaylightMapTileFilter,
                            child: TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'br.com.desperrengue.app.founder',
                              maxNativeZoom: 19,
                            ),
                          ),
                        MarkerLayer(
                          markers: <Marker>[
                            for (final p in pts)
                              Marker(
                                point: LatLng(p.lat, p.lng),
                                width: selectedPoint?.jobId == p.jobId ? 60 : 50,
                                height: selectedPoint?.jobId == p.jobId ? 68 : 58,
                                alignment: Alignment.topCenter,
                                child: GestureDetector(
                                  onTap: () => _selectPin(p),
                                  child: FounderLuxuryMapMarker(
                                    categoryName: p.categoryName,
                                    status: p.status,
                                    selected: selectedPoint?.jobId == p.jobId,
                                    isExact: p.isExactPin,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    // Topo esquerdo: status ao vivo + botão Noite/Claro
                    Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          _MapGlassBadge(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const LiveBreathingPulseDot(
                                  color: FounderSovereignTokens.solvencyEmerald,
                                  size: 6.5,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  pts.isEmpty
                                      ? 'Radar pronto'
                                      : '${pts.length} ${pts.length == 1 ? "serviço" : "serviços"}',
                                  style: const TextStyle(
                                    color: FounderSovereignTokens.primaryInk,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _MapHudIconButton(
                                key: const ValueKey<String>(
                                  'ceo-map-theme-toggle-btn',
                                ),
                                icon: _nightMode
                                    ? Icons.dark_mode_rounded
                                    : Icons.light_mode_rounded,
                                label: _nightMode ? 'Noite' : 'Claro',
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _nightMode = !_nightMode);
                                },
                              ),
                              const SizedBox(width: 6),
                              _MapHudIconButton(
                                icon: Icons.fullscreen_rounded,
                                tooltip: 'Abrir em tela cheia',
                                onTap: _openFullScreenMap,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Controles flutuantes de zoom e centralização à direita
                    Positioned(
                      right: 10,
                      bottom: 28,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _MapHudIconButton(
                            icon: Icons.add_rounded,
                            tooltip: 'Aproximar mapa',
                            onTap: () => _zoomBy(1.0),
                          ),
                          const SizedBox(height: 6),
                          _MapHudIconButton(
                            icon: Icons.remove_rounded,
                            tooltip: 'Afastar mapa',
                            onTap: () => _zoomBy(-1.0),
                          ),
                          const SizedBox(height: 6),
                          _MapHudIconButton(
                            icon: Icons.my_location_rounded,
                            tooltip: 'Centralizar serviços',
                            onTap: _fitAllPoints,
                          ),
                        ],
                      ),
                    ),
                    if (pts.isEmpty)
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: FounderSovereignTokens.obsidianSurface
                                .withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: FounderSovereignTokens.crispBorderStrong,
                            ),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.explore_outlined,
                                color: FounderSovereignTokens.imperialGoldBright,
                                size: 24,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Nenhum serviço no mapa neste momento',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: FounderSovereignTokens.primaryInk,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Assim que um pedido for aberto no Desperrengue, o ícone da profissão aparecerá aqui em tempo real.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: FounderSovereignTokens.mutedInk,
                                  fontSize: 11.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      left: 10,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: FounderSovereignTokens.obsidianBackground
                              .withValues(alpha: 0.80),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '© OpenStreetMap',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: FounderSovereignTokens.mutedInk,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const _MapStatusLegendStrip(),
          if (selectedPoint != null) ...<Widget>[
            const SizedBox(height: 12),
            _SelectedMapOrderDock(
              point: selectedPoint,
              privacyBlurActive: widget.privacyBlurActive,
              openButtonKey: const ValueKey<String>(
                'ceo-open-order-details-btn',
              ),
              onInspectOrder: () => widget.onInspectOrder(
                selectedPoint!.jobId,
                selectedPoint.orderCode,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final active = _statusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _statusFilter = key);
      },
      selectedColor: FounderSovereignTokens.imperialGoldSoft,
      backgroundColor: FounderSovereignTokens.obsidianSurface,
      side: BorderSide(
        color: active
            ? FounderSovereignTokens.imperialGold
            : FounderSovereignTokens.crispBorder,
      ),
      labelStyle: TextStyle(
        color: active
            ? FounderSovereignTokens.imperialGoldBright
            : FounderSovereignTokens.mutedInk,
        fontSize: 12,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Modal Cartográfico de Tela Cheia (`Abrir mapa grande`) com controles HUD,
/// navegação rápida `< Anterior · Próximo >` entre serviços ativos e inspeção direta.
class FounderFullScreenMapModal extends StatefulWidget {
  const FounderFullScreenMapModal({
    super.key,
    required this.points,
    required this.onInspectOrder,
    this.initialFilter = 'all',
    this.initialSelectedJobId,
    this.initialNightMode = true,
    this.privacyBlurActive = false,
    this.enableNetworkTiles,
  });

  final List<CeoLiveMapPoint> points;
  final void Function(String jobId, String orderCode) onInspectOrder;
  final String initialFilter;
  final String? initialSelectedJobId;
  final bool initialNightMode;
  final bool privacyBlurActive;
  final bool? enableNetworkTiles;

  static Future<void> show(
    BuildContext context, {
    required List<CeoLiveMapPoint> points,
    required void Function(String jobId, String orderCode) onInspectOrder,
    String initialFilter = 'all',
    String? initialSelectedJobId,
    bool initialNightMode = true,
    bool privacyBlurActive = false,
    bool? enableNetworkTiles,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 210),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FounderFullScreenMapModal(
            key: const ValueKey<String>('ceo-fullscreen-map-modal'),
            points: points,
            onInspectOrder: onInspectOrder,
            initialFilter: initialFilter,
            initialSelectedJobId: initialSelectedJobId,
            initialNightMode: initialNightMode,
            privacyBlurActive: privacyBlurActive,
            enableNetworkTiles: enableNetworkTiles,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: const Cubic(0.22, 1.0, 0.36, 1.0),
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<FounderFullScreenMapModal> createState() =>
      _FounderFullScreenMapModalState();
}

class _FounderFullScreenMapModalState extends State<FounderFullScreenMapModal> {
  final MapController _mapController = MapController();
  late String _statusFilter = widget.initialFilter;
  late String? _selectedJobId = widget.initialSelectedJobId;
  late bool _nightMode = widget.initialNightMode;

  List<CeoLiveMapPoint> get _filteredPoints =>
      _filterMapPoints(widget.points, _statusFilter);

  void _fitAll() {
    HapticFeedback.selectionClick();
    final pts = _filteredPoints;
    try {
      _mapController.move(_computeMapCenter(pts), _computeMapZoom(pts));
    } catch (_) {}
  }

  void _zoomBy(double delta) {
    HapticFeedback.selectionClick();
    try {
      final cam = _mapController.camera;
      _mapController.move(cam.center, (cam.zoom + delta).clamp(3.0, 18.5));
    } catch (_) {}
  }

  void _focusPoint(CeoLiveMapPoint p) {
    HapticFeedback.selectionClick();
    setState(() => _selectedJobId = p.jobId);
    try {
      final zoom = math.max(_mapController.camera.zoom, 14.2);
      _mapController.move(LatLng(p.lat, p.lng), zoom);
    } catch (_) {}
  }

  void _stepSelection(int delta, List<CeoLiveMapPoint> pts) {
    if (pts.isEmpty) return;
    var currentIdx = pts.indexWhere((p) => p.jobId == _selectedJobId);
    if (currentIdx < 0) currentIdx = 0;
    final nextIdx = (currentIdx + delta) % pts.length;
    final normalizedIdx = nextIdx < 0 ? nextIdx + pts.length : nextIdx;
    _focusPoint(pts[normalizedIdx]);
  }

  @override
  Widget build(BuildContext context) {
    final pts = _filteredPoints;
    final useNetworkTiles =
        widget.enableNetworkTiles ?? !_isRunningInWidgetTest();

    CeoLiveMapPoint? selectedPoint;
    var selectedIdx = 0;
    if (_selectedJobId != null) {
      for (var i = 0; i < pts.length; i++) {
        if (pts[i].jobId == _selectedJobId) {
          selectedPoint = pts[i];
          selectedIdx = i;
          break;
        }
      }
    }
    if (selectedPoint == null && pts.isNotEmpty) {
      selectedPoint = pts.first;
      selectedIdx = 0;
    }

    return Scaffold(
      backgroundColor: _nightMode
          ? const Color(0xFF0A0F18)
          : const Color(0xFFE9EEF5),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _ExecutiveOfflineCityMapPainter(nightMode: _nightMode),
            ),
          ),
          Positioned.fill(
            child: FounderPrivacyBlurWrap(
              privacyBlurActive: widget.privacyBlurActive,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: selectedPoint != null
                      ? LatLng(selectedPoint.lat, selectedPoint.lng)
                      : _computeMapCenter(pts),
                  initialZoom:
                      selectedPoint != null ? 14.0 : _computeMapZoom(pts),
                  backgroundColor: Colors.transparent,
                ),
                children: <Widget>[
                  if (useNetworkTiles)
                    ColorFiltered(
                      colorFilter: _nightMode
                          ? _kObsidianMapTileFilter
                          : _kDaylightMapTileFilter,
                      child: TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                            'br.com.desperrengue.app.founder',
                        maxNativeZoom: 19,
                      ),
                    ),
                  MarkerLayer(
                    markers: <Marker>[
                      for (final p in pts)
                        Marker(
                          point: LatLng(p.lat, p.lng),
                          width: selectedPoint?.jobId == p.jobId ? 64 : 52,
                          height: selectedPoint?.jobId == p.jobId ? 72 : 60,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            onTap: () => _focusPoint(p),
                            child: FounderLuxuryMapMarker(
                              categoryName: p.categoryName,
                              status: p.status,
                              selected: selectedPoint?.jobId == p.jobId,
                              isExact: p.isExactPin,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Barra superior de comando em vidro escuro
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: FounderSovereignTokens.obsidianBackground
                              .withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: FounderSovereignTokens.crispBorderStrong,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            IconButton(
                              key: const ValueKey<String>(
                                'ceo-close-fullscreen-map-btn',
                              ),
                              tooltip: 'Voltar',
                              onPressed: () => Navigator.of(context).pop(),
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    FounderSovereignTokens.obsidianCard,
                                side: const BorderSide(
                                  color: FounderSovereignTokens.crispBorder,
                                ),
                                minimumSize: const Size(40, 40),
                              ),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: FounderSovereignTokens.primaryInk,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Mapa Operacional em Tempo Real',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: FounderSovereignTokens.titleStyle(
                                      fontSize: 15,
                                    ),
                                  ),
                                  Row(
                                    children: <Widget>[
                                      const LiveBreathingPulseDot(
                                        color: FounderSovereignTokens
                                            .solvencyEmerald,
                                        size: 6,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          '${pts.length} ${pts.length == 1 ? "serviço visível" : "serviços visíveis"}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: FounderSovereignTokens
                                              .subtitleStyle(fontSize: 11.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            _MapHudIconButton(
                              icon: _nightMode
                                  ? Icons.dark_mode_rounded
                                  : Icons.light_mode_rounded,
                              label: _nightMode ? 'Noite' : 'Claro',
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _nightMode = !_nightMode);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        _buildOverlayFilterChip(
                          'all',
                          'Todos (${widget.points.length})',
                        ),
                        const SizedBox(width: 6),
                        _buildOverlayFilterChip('execution', 'Em atendimento'),
                        const SizedBox(width: 6),
                        _buildOverlayFilterChip('scheduled', 'Agendados'),
                        const SizedBox(width: 6),
                        _buildOverlayFilterChip('open', 'Aguardando PIX'),
                        const SizedBox(width: 6),
                        _buildOverlayFilterChip('completed', 'Concluídos'),
                        const SizedBox(width: 6),
                        _buildOverlayFilterChip('disputed', 'Com problema'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Controles flutuantes de zoom e centralização na lateral direita
          Positioned(
            right: 14,
            top: MediaQuery.paddingOf(context).top + 132,
            child: Column(
              children: <Widget>[
                _MapHudIconButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Aproximar',
                  onTap: () => _zoomBy(1.0),
                ),
                const SizedBox(height: 8),
                _MapHudIconButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Afastar',
                  onTap: () => _zoomBy(-1.0),
                ),
                const SizedBox(height: 8),
                _MapHudIconButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Enquadrar todos',
                  onTap: _fitAll,
                ),
              ],
            ),
          ),
          // Doca inferior flutuante com legenda + cartão do pedido selecionado
          Positioned(
            left: 14,
            right: 14,
            bottom: MediaQuery.paddingOf(context).bottom + 14,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: FounderSovereignTokens.obsidianBackground
                            .withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: FounderSovereignTokens.crispBorder,
                        ),
                      ),
                      child: const _MapStatusLegendStrip(),
                    ),
                    const SizedBox(height: 10),
                    if (selectedPoint != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: FounderSovereignTokens.obsidianBackground
                              .withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: FounderSovereignTokens.crispBorderStrong,
                          ),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x80000000),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (pts.length > 1) ...<Widget>[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  TextButton.icon(
                                    onPressed: () => _stepSelection(-1, pts),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor:
                                          FounderSovereignTokens.secondaryInk,
                                    ),
                                    icon: const Icon(
                                      Icons.chevron_left_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Anterior',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Text(
                                    'Serviço ${selectedIdx + 1} de ${pts.length}',
                                    style: FounderSovereignTokens.monoMetric(
                                      fontSize: 11.5,
                                      color: FounderSovereignTokens
                                          .imperialGoldBright,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _stepSelection(1, pts),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor:
                                          FounderSovereignTokens.secondaryInk,
                                    ),
                                    icon: const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Próximo',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(
                                height: 10,
                                color: FounderSovereignTokens.crispBorder,
                              ),
                            ],
                            _SelectedMapOrderDock(
                              point: selectedPoint,
                              privacyBlurActive: widget.privacyBlurActive,
                              transparentBackground: true,
                              onInspectOrder: () => widget.onInspectOrder(
                                selectedPoint!.jobId,
                                selectedPoint.orderCode,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: FounderSovereignTokens.obsidianBackground
                              .withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: FounderSovereignTokens.crispBorderStrong,
                          ),
                        ),
                        child: const Text(
                          'Nenhum serviço ativo encontrado para este filtro no momento.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: FounderSovereignTokens.secondaryInk,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildOverlayFilterChip(String code, String label) {
    final active = _statusFilter == code;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _statusFilter = code);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? FounderSovereignTokens.imperialGold
              : FounderSovereignTokens.obsidianBackground
                  .withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: active
                ? FounderSovereignTokens.imperialGoldBright
                : FounderSovereignTokens.crispBorderStrong,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? const Color(0xFF0B0E13)
                : FounderSovereignTokens.primaryInk,
            fontSize: 12,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Marcador cartográfico esculpido (*Teardrop Medallion*) com brasão vetorial
/// Duotone das 33 profissões ([CategoryBrandEmblem]), anel semântico de status,
/// sombra de contato no solo e halo vivo nos atendimentos em andamento.
class FounderLuxuryMapMarker extends StatelessWidget {
  const FounderLuxuryMapMarker({
    super.key,
    required this.categoryName,
    required this.status,
    required this.selected,
    required this.isExact,
  });

  final String categoryName;
  final String status;
  final bool selected;
  final bool isExact;

  @override
  Widget build(BuildContext context) {
    final statusColor = founderStatusColor(status);
    final st = status.trim().toLowerCase();
    final isLiveActive =
        st == 'in_progress' || st == 'awaiting_approval' || st == 'disputed';
    final headSize = selected ? 44.0 : 36.0;
    final emblemSize = selected ? 26.0 : 21.0;

    return AnimatedScale(
      scale: selected ? 1.06 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: const Cubic(0.22, 1.0, 0.36, 1.0),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: <Widget>[
          // Sombra elíptica realista no ponto exato do solo
          Positioned(
            bottom: 1,
            child: Container(
              width: selected ? 20 : 15,
              height: selected ? 6 : 4.5,
              decoration: BoxDecoration(
                color: const Color(0x88000000),
                borderRadius: BorderRadius.circular(99),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: statusColor.withValues(alpha: selected ? 0.45 : 0.22),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          // Halo luminoso para serviços em execução ou selecionados
          if (selected || isLiveActive)
            Positioned(
              top: 0,
              child: Container(
                width: headSize + 8,
                height: headSize + 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: statusColor.withValues(alpha: selected ? 0.58 : 0.32),
                    width: selected ? 1.8 : 1.2,
                  ),
                ),
              ),
            ),
          // Corpo gota esculpido + ponta precisa
          Positioned(
            top: 4,
            child: CustomPaint(
              size: Size(headSize, headSize + 10),
              painter: _LuxuryPinDropPainter(
                ringColor: selected
                    ? FounderSovereignTokens.imperialGoldBright
                    : statusColor,
                fillColor: const Color(0xFF131924),
                selected: selected,
              ),
              child: SizedBox(
                width: headSize,
                height: headSize + 10,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: headSize,
                    height: headSize,
                    child: Center(
                      child: CategoryBrandEmblem(
                        categoryName: categoryName,
                        size: emblemSize,
                        showCornerBadge: false,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Ponto semântico indicador de status no canto superior direito
          Positioned(
            top: 3,
            right: selected ? 5 : 4,
            child: Container(
              width: selected ? 11 : 9,
              height: selected ? 11 : 9,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF0B0E13),
                  width: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LuxuryPinDropPainter extends CustomPainter {
  const _LuxuryPinDropPainter({
    required this.ringColor,
    required this.fillColor,
    required this.selected,
  });

  final Color ringColor;
  final Color fillColor;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final tip = Offset(radius, size.height - 1);

    final dropPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius - 1))
      ..moveTo(radius - 6.5, radius + radius * 0.68)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(radius + 6.5, radius + radius * 0.68)
      ..close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(dropPath, fillPaint);

    final borderPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 2.4 : 1.8
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(center, radius - 1.2, borderPaint);

    final tipPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.fill;
    final pointerTriangle = Path()
      ..moveTo(radius - 4.8, size.width - 3.2)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(radius + 4.8, size.width - 3.2)
      ..close();
    canvas.drawPath(pointerTriangle, tipPaint);
  }

  @override
  bool shouldRepaint(covariant _LuxuryPinDropPainter oldDelegate) {
    return oldDelegate.ringColor != ringColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.selected != selected;
  }
}

/// Malha urbana vetorial arquitetônica de fundo (garante estética executiva mesmo offline).
class _ExecutiveOfflineCityMapPainter extends CustomPainter {
  const _ExecutiveOfflineCityMapPainter({required this.nightMode});

  final bool nightMode;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: nightMode
            ? const <Color>[Color(0xFF0A0F18), Color(0xFF101826)]
            : const <Color>[Color(0xFFE7ECF3), Color(0xFFDCE4EE)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // Áreas verdes / parques sutis
    final parkPaint = Paint()
      ..color = nightMode
          ? const Color(0xFF0E201C)
          : const Color(0xFFD2E5DA);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, size.height * 0.14, size.width * 0.22, size.height * 0.24),
        const Radius.circular(14),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.68, size.height * 0.56, size.width * 0.24, size.height * 0.26),
        const Radius.circular(16),
      ),
      parkPaint,
    );

    // Ruas locais
    final streetPaint = Paint()
      ..color = nightMode
          ? const Color(0x16FFFFFF)
          : const Color(0x180F172A)
      ..strokeWidth = 1.0;

    const cols = 8;
    const rows = 6;
    for (var c = 1; c < cols; c++) {
      final x = (size.width / cols) * c;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), streetPaint);
    }
    for (var r = 1; r < rows; r++) {
      final y = (size.height / rows) * r;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), streetPaint);
    }

    // Avenidas arteriais diagonais elegantes
    final avenuePaint = Paint()
      ..color = nightMode
          ? const Color(0x285BA8FF)
          : const Color(0x3394A3B8)
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke;

    final av1 = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.48,
        size.width,
        size.height * 0.18,
      );
    final av2 = Path()
      ..moveTo(size.width * 0.18, 0)
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.52,
        size.width * 0.84,
        size.height,
      );
    canvas.drawPath(av1, avenuePaint);
    canvas.drawPath(av2, avenuePaint);
  }

  @override
  bool shouldRepaint(covariant _ExecutiveOfflineCityMapPainter oldDelegate) =>
      oldDelegate.nightMode != nightMode;
}

class _MapGlassBadge extends StatelessWidget {
  const _MapGlassBadge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianBackground.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: FounderSovereignTokens.crispBorderStrong),
      ),
      child: child,
    );
  }
}

class _MapHudIconButton extends StatelessWidget {
  const _MapHudIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.label,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget btn = Material(
      color: FounderSovereignTokens.obsidianBackground.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.symmetric(
            horizontal: label != null ? 10 : 8,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: FounderSovereignTokens.crispBorderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: FounderSovereignTokens.primaryInk,
              ),
              if (label != null) ...<Widget>[
                const SizedBox(width: 5),
                Text(
                  label!,
                  style: const TextStyle(
                    color: FounderSovereignTokens.primaryInk,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (tooltip != null) {
      btn = Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

class _MapStatusLegendStrip extends StatelessWidget {
  const _MapStatusLegendStrip();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: const <Widget>[
        _LegendDotItem(
          color: FounderSovereignTokens.imperialGoldBright,
          label: 'Em atendimento',
        ),
        _LegendDotItem(
          color: FounderSovereignTokens.cyberCyan,
          label: 'Agendado',
        ),
        _LegendDotItem(
          color: FounderSovereignTokens.warmAmber,
          label: 'Aguardando PIX',
        ),
        _LegendDotItem(
          color: FounderSovereignTokens.solvencyEmerald,
          label: 'Concluído',
        ),
        _LegendDotItem(
          color: FounderSovereignTokens.crimsonAlert,
          label: 'Com problema',
        ),
      ],
    );
  }
}

class _LegendDotItem extends StatelessWidget {
  const _LegendDotItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: FounderSovereignTokens.mutedInk,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SelectedMapOrderDock extends StatelessWidget {
  const _SelectedMapOrderDock({
    required this.point,
    required this.privacyBlurActive,
    required this.onInspectOrder,
    this.openButtonKey,
    this.transparentBackground = false,
  });

  final CeoLiveMapPoint point;
  final bool privacyBlurActive;
  final VoidCallback onInspectOrder;
  final Key? openButtonKey;
  final bool transparentBackground;

  @override
  Widget build(BuildContext context) {
    final estNetCents = _estimateNetProfitFromAmountCents(point.amountCents);
    return Container(
      padding: transparentBackground
          ? EdgeInsets.zero
          : const EdgeInsets.all(14),
      decoration: transparentBackground
          ? null
          : BoxDecoration(
              color: FounderSovereignTokens.obsidianSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FounderSovereignTokens.crispBorder),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CategoryBrandEmblem(
                categoryName: point.categoryName,
                size: 42,
                showCornerBadge: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          point.categoryName,
                          style: FounderSovereignTokens.titleStyle(
                            fontSize: 14.5,
                          ),
                        ),
                        _StatusTag(
                          label: founderStatusLabelPt(point.status),
                          color: founderStatusColor(point.status),
                        ),
                        Text(
                          point.orderCode,
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 11.5,
                            color: FounderSovereignTokens.mutedInk,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${point.neighborhood.isNotEmpty ? "${point.neighborhood}, " : ""}${point.city}'
                      ' · Cliente: ${point.clientName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FounderSovereignTokens.subtitleStyle(
                        fontSize: 12,
                        color: FounderSovereignTokens.secondaryInk,
                      ),
                    ),
                    if (point.providerName != null)
                      Text(
                        'Profissional: ${point.providerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FounderSovereignTokens.subtitleStyle(
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: FounderSovereignTokens.crispBorder),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Wrap(
                spacing: 14,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        'Total: ',
                        style: TextStyle(
                          color: FounderSovereignTokens.mutedInk,
                          fontSize: 12,
                        ),
                      ),
                      AnimatedMoneyOdometer(
                        cents: point.amountCents,
                        privacyBlurActive: privacyBlurActive,
                        style: FounderSovereignTokens.monoMetric(
                          fontSize: 14,
                          color: FounderSovereignTokens.primaryInk,
                        ),
                      ),
                    ],
                  ),
                  if (estNetCents > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          'Seu lucro est.: +',
                          style: TextStyle(
                            color: FounderSovereignTokens.solvencyEmerald,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        AnimatedMoneyOdometer(
                          cents: estNetCents,
                          privacyBlurActive: privacyBlurActive,
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 13.5,
                            color: FounderSovereignTokens.solvencyEmerald,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              FilledButton.tonalIcon(
                key: openButtonKey,
                onPressed: onInspectOrder,
                style: FilledButton.styleFrom(
                  backgroundColor: FounderSovereignTokens.imperialGoldSoft,
                  foregroundColor: FounderSovereignTokens.imperialGoldBright,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  side: BorderSide(
                    color: FounderSovereignTokens.imperialGold
                        .withValues(alpha: 0.45),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_rounded, size: 15),
                label: const Text(
                  'Ver pedido',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. DETALHES COMPLETOS DO PEDIDO EM TEMPO REAL (`ceo_inspect_order_forensics`)
// ============================================================================

class FounderOrderForensicSheet extends StatefulWidget {
  const FounderOrderForensicSheet({
    super.key,
    required this.repository,
    required this.jobId,
    this.initialOrderCode,
    this.privacyBlurActive = false,
  });

  final FounderCockpitRepository repository;
  final String jobId;
  final String? initialOrderCode;
  final bool privacyBlurActive;

  static Future<void> show(
    BuildContext context, {
    required FounderCockpitRepository repository,
    required String jobId,
    String? initialOrderCode,
    bool privacyBlurActive = false,
  }) {
    if (jobId.trim().isEmpty) return Future<void>.value();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: FounderSovereignTokens.obsidianBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.90,
        child: FounderOrderForensicSheet(
          repository: repository,
          jobId: jobId,
          initialOrderCode: initialOrderCode,
          privacyBlurActive: privacyBlurActive,
        ),
      ),
    );
  }

  @override
  State<FounderOrderForensicSheet> createState() =>
      _FounderOrderForensicSheetState();
}

class _FounderOrderForensicSheetState extends State<FounderOrderForensicSheet> {
  late Future<CeoOrderForensicsDossier> _future =
      widget.repository.inspectOrderForensics(widget.jobId);

  void _reload() {
    setState(() {
      _future = widget.repository.inspectOrderForensics(widget.jobId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final codeSuffix = (widget.initialOrderCode ?? '').trim();
    return Column(
      key: const ValueKey<String>('ceo-order-forensic-sheet'),
      children: <Widget>[
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: FounderSovereignTokens.crispBorderStrong,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.receipt_long_rounded,
                color: FounderSovereignTokens.imperialGoldBright,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  codeSuffix.isEmpty
                      ? 'Detalhes do Pedido'
                      : 'Detalhes do Pedido $codeSuffix',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FounderSovereignTokens.titleStyle(fontSize: 17),
                ),
              ),
              IconButton(
                tooltip: 'Atualizar informações',
                onPressed: _reload,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 19,
                  color: FounderSovereignTokens.mutedInk,
                ),
              ),
              IconButton(
                tooltip: 'Fechar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: FounderSovereignTokens.mutedInk,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: FounderSovereignTokens.crispBorder),
        Expanded(
          child: FutureBuilder<CeoOrderForensicsDossier>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: FounderSovereignTokens.imperialGoldBright,
                  ),
                );
              }
              if (snap.hasError || !snap.hasData) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.error_outline_rounded,
                          color: FounderSovereignTokens.crimsonAlert,
                          size: 36,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          snap.error?.toString() ??
                              'Não foi possível carregar os detalhes deste pedido agora.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: FounderSovereignTokens.primaryInk,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final d = snap.data!;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _buildHeaderSection(d),
                  const SizedBox(height: 12),
                  _buildUnitProfitBreakdownCard(d),
                  const SizedBox(height: 12),
                  _buildTimelineSection(d),
                  const SizedBox(height: 12),
                  _buildActorsSection(d),
                  const SizedBox(height: 12),
                  _buildLocationAndCheckinSection(d),
                  const SizedBox(height: 12),
                  _buildQuotesSection(d),
                  const SizedBox(height: 12),
                  _buildPaymentsAndLedgerSection(d),
                  const SizedBox(height: 12),
                  _buildFiscalAndReviewsSection(d),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSection(CeoOrderForensicsDossier d) {
    final stColor = founderStatusColor(d.status);
    return FounderGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CategoryBrandEmblem(
                categoryName: d.category,
                size: 48,
                showCornerBadge: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          d.orderCode,
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: FounderSovereignTokens.imperialGoldBright,
                          ),
                        ),
                        _StatusTag(
                          label: founderStatusLabelPt(d.status),
                          color: stColor,
                        ),
                        _StatusTag(
                          label: _humanEscrowLabelPt(d.escrowStatus),
                          color: FounderSovereignTokens.cyberCyan,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${d.category} · ${d.title}',
                      style: FounderSovereignTokens.titleStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (d.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              d.description,
              style: FounderSovereignTokens.subtitleStyle(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnitProfitBreakdownCard(CeoOrderForensicsDossier d) {
    final labor = d.laborCents > 0
        ? d.laborCents
        : math.max(0, d.agreedPriceCents - d.materialsCents);
    final platformFeeCents = (labor * 1350) ~/ 10000;
    final warrantyCents = (labor * 150) ~/ 10000;
    final providerNetCents = math.max(
      0,
      labor - platformFeeCents - warrantyCents,
    );
    final taxEstimateCents = (platformFeeCents * 600) ~/ 10000;
    final netProfitCents = math.max(0, platformFeeCents - taxEstimateCents);

    return FounderGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Quanto o Desperrengue ganha neste pedido',
            style: FounderSovereignTokens.titleStyle(fontSize: 15),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _MoneyKpiMini(
                    label: 'Total pago pelo cliente',
                    cents: d.agreedPriceCents,
                    privacyBlurActive: widget.privacyBlurActive,
                    color: FounderSovereignTokens.primaryInk,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MoneyKpiMini(
                    label: 'Seu lucro líquido est.',
                    cents: netProfitCents,
                    privacyBlurActive: widget.privacyBlurActive,
                    color: FounderSovereignTokens.solvencyEmerald,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _MoneyKpiMini(
                    label: 'Líquido do profissional',
                    cents: providerNetCents + d.materialsCents,
                    privacyBlurActive: widget.privacyBlurActive,
                    color: FounderSovereignTokens.secondaryInk,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MoneyKpiMini(
                    label: 'Peças sem taxa (0%)',
                    cents: d.materialsCents,
                    privacyBlurActive: widget.privacyBlurActive,
                    color: FounderSovereignTokens.imperialGoldBright,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(CeoOrderForensicsDossier d) {
    final st = d.status.trim().toLowerCase();
    final isCanceled = st == 'canceled' || st == 'cancelled';
    final quoteAccepted = d.agreedPriceCents > 0 ||
        d.provider != null ||
        const <String>{
          'scheduled',
          'in_progress',
          'awaiting_approval',
          'completed',
        }.contains(st);
    final paymentProtected = d.payments.isNotEmpty ||
        d.escrowStatus.toUpperCase() != 'NONE' ||
        const <String>{
          'scheduled',
          'in_progress',
          'awaiting_approval',
          'completed',
        }.contains(st);
    final checkinDone = d.job['checkin_distance_m'] != null ||
        const <String>{
          'in_progress',
          'awaiting_approval',
          'completed',
        }.contains(st);
    final completed = st == 'completed';

    final steps = <({String title, String subtitle, bool done})>[
      (
        title: 'Pedido aberto pelo cliente',
        subtitle: 'Registrado no aplicativo Desperrengue',
        done: true,
      ),
      (
        title: 'Orçamento aprovado',
        subtitle: quoteAccepted
            ? 'Profissional selecionado para o atendimento'
            : 'Aguardando escolha de orçamento',
        done: quoteAccepted && !isCanceled,
      ),
      (
        title: 'Pagamento protegido no app',
        subtitle: paymentProtected
            ? _humanEscrowLabelPt(d.escrowStatus)
            : 'Aguardando confirmação do PIX',
        done: paymentProtected && !isCanceled,
      ),
      (
        title: 'Chegada no endereço',
        subtitle: d.job['checkin_distance_m'] != null
            ? 'Presença confirmada por GPS (${d.job['checkin_distance_m']}m)'
            : (checkinDone
                ? 'Atendimento iniciado'
                : 'Aguardando chegada do profissional'),
        done: checkinDone && !isCanceled,
      ),
      (
        title: isCanceled ? 'Pedido cancelado' : 'Serviço concluído',
        subtitle: completed
            ? 'Atendimento finalizado com sucesso'
            : (isCanceled
                ? 'Este pedido foi encerrado sem execução'
                : 'Aguardando conclusão e aprovação final'),
        done: completed,
      ),
    ];

    return FounderGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Etapas do atendimento',
            style: FounderSovereignTokens.titleStyle(fontSize: 15),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      Icon(
                        steps[i].done
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 19,
                        color: steps[i].done
                            ? FounderSovereignTokens.solvencyEmerald
                            : FounderSovereignTokens.mutedInk,
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 1.5,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: steps[i].done
                                ? FounderSovereignTokens.solvencyEmerald
                                    .withValues(alpha: 0.45)
                                : FounderSovereignTokens.crispBorder,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i == steps.length - 1 ? 0 : 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            steps[i].title,
                            style: TextStyle(
                              color: steps[i].done
                                  ? FounderSovereignTokens.primaryInk
                                  : FounderSovereignTokens.secondaryInk,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            steps[i].subtitle,
                            style: const TextStyle(
                              color: FounderSovereignTokens.mutedInk,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActorsSection(CeoOrderForensicsDossier d) {
    final c = d.client;
    final p = d.provider;
    return FounderGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Pessoas envolvidas',
            style: FounderSovereignTokens.titleStyle(fontSize: 15),
          ),
          const SizedBox(height: 12),
          _ActorRow(
            role: 'Cliente',
            name: (c['full_name'] ?? 'Cliente').toString(),
            subtitle:
                '${c['city'] ?? "Cidade não informada"} · ${_humanKycLabelPt(c['client_kyc_status']?.toString())}',
            avatarUrl: c['avatar_url']?.toString(),
            accent: FounderSovereignTokens.imperialGoldBright,
          ),
          const Divider(height: 20, color: FounderSovereignTokens.crispBorder),
          if (p != null)
            _ActorRow(
              role: 'Profissional responsável',
              name: (p['full_name'] ?? 'Profissional').toString(),
              subtitle:
                  '${p['city'] ?? "Cidade não informada"} · ${_humanKycLabelPt(p['verification_status']?.toString())} · ${p['jobs_done'] ?? 0} concluídos',
              avatarUrl: p['avatar_url']?.toString(),
              accent: FounderSovereignTokens.solvencyEmerald,
            )
          else
            const Text(
              'Ainda sem profissional definido (aguardando aceite de orçamento).',
              style: TextStyle(
                color: FounderSovereignTokens.mutedInk,
                fontSize: 12.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationAndCheckinSection(CeoOrderForensicsDossier d) {
    final loc = d.location;
    final checkinDist = d.job['checkin_distance_m'];
    return FounderGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Local do atendimento',
            style: FounderSovereignTokens.titleStyle(fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            '${loc['neighborhood'] ?? "Bairro não informado"} · ${loc['city'] ?? "—"}${loc['uf'] != null ? "/${loc['uf']}" : ""}',
            style: const TextStyle(
              color: FounderSovereignTokens.primaryInk,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if ((loc['address_line'] ?? '').toString().trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: FounderPrivacyBlurWrap(
                privacyBlurActive: widget.privacyBlurActive,
                child: Text(
                  'Endereço: ${loc['address_line']}',
                  style: const TextStyle(
                    color: FounderSovereignTokens.mutedInk,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Icon(
                checkinDist != null
                    ? Icons.verified_rounded
                    : Icons.schedule_rounded,
                size: 15,
                color: checkinDist != null
                    ? FounderSovereignTokens.solvencyEmerald
                    : FounderSovereignTokens.mutedInk,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  checkinDist != null
                      ? 'Presença no local confirmada por GPS ($checkinDist metros)'
                      : 'Chegada ao local ainda não registrada por GPS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: checkinDist != null
                        ? FounderSovereignTokens.solvencyEmerald
                        : FounderSovereignTokens.mutedInk,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuotesSection(CeoOrderForensicsDossier d) {
    return FounderGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Orçamentos recebidos (${d.quotes.length})',
            style: FounderSovereignTokens.titleStyle(fontSize: 15),
          ),
          const SizedBox(height: 8),
          if (d.quotes.isEmpty)
            const Text(
              'Nenhum orçamento enviado ainda para este pedido.',
              style: TextStyle(
                color: FounderSovereignTokens.mutedInk,
                fontSize: 12.5,
              ),
            )
          else
            for (final q in d.quotes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${q['provider_name'] ?? "Profissional"} · ${_humanQuoteStatusPt(q['status']?.toString())}',
                        style: const TextStyle(
                          color: FounderSovereignTokens.primaryInk,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    AnimatedMoneyOdometer(
                      cents: (q['amount_cents'] is num)
                          ? (q['amount_cents'] as num).round()
                          : 0,
                      privacyBlurActive: widget.privacyBlurActive,
                      style: FounderSovereignTokens.monoMetric(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: FounderSovereignTokens.imperialGoldBright,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildPaymentsAndLedgerSection(CeoOrderForensicsDossier d) {
    return FounderGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Movimentação financeira (${d.ledgerTxns.length})',
            style: FounderSovereignTokens.titleStyle(fontSize: 15),
          ),
          const SizedBox(height: 8),
          if (d.payments.isEmpty && d.ledgerTxns.isEmpty)
            const Text(
              'Nenhum pagamento processado para este pedido até agora.',
              style: TextStyle(
                color: FounderSovereignTokens.mutedInk,
                fontSize: 12.5,
              ),
            ),
          for (final l in d.ledgerTxns)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _humanLedgerEntryLabelPt(l),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: FounderSovereignTokens.primaryInk,
                      ),
                    ),
                  ),
                  AnimatedMoneyOdometer(
                    cents: (l['amount_cents'] is num)
                        ? (l['amount_cents'] as num).round()
                        : 0,
                    privacyBlurActive: widget.privacyBlurActive,
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: FounderSovereignTokens.solvencyEmerald,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFiscalAndReviewsSection(CeoOrderForensicsDossier d) {
    return FounderGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Notas fiscais e avaliações',
            style: FounderSovereignTokens.titleStyle(fontSize: 15),
          ),
          const SizedBox(height: 8),
          if (d.fiscalDocuments.isEmpty &&
              d.mediations.isEmpty &&
              d.reviews.isEmpty)
            const Text(
              'Sem notas fiscais ou avaliações registradas até o momento.',
              style: TextStyle(
                color: FounderSovereignTokens.mutedInk,
                fontSize: 12.5,
              ),
            ),
          for (final f in d.fiscalDocuments)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Nota fiscal de peças: ${f['nfe_access_key'] ?? "—"}',
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 11.5,
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
              ),
            ),
          for (final r in d.reviews)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Nota ${r['rating'] ?? 5} ★ — "${r['comment'] ?? ""}"',
                style: const TextStyle(
                  color: FounderSovereignTokens.primaryInk,
                  fontSize: 12.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MoneyKpiMini extends StatelessWidget {
  const _MoneyKpiMini({
    required this.label,
    required this.cents,
    required this.privacyBlurActive,
    required this.color,
  });

  final String label;
  final int cents;
  final bool privacyBlurActive;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FounderSovereignTokens.crispBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FounderSovereignTokens.mutedInk,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedMoneyOdometer(
            cents: cents,
            privacyBlurActive: privacyBlurActive,
            style: FounderSovereignTokens.monoMetric(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActorRow extends StatelessWidget {
  const _ActorRow({
    required this.role,
    required this.name,
    required this.subtitle,
    required this.accent,
    this.avatarUrl,
  });

  final String role;
  final String name;
  final String subtitle;
  final Color accent;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        FounderUltraHdImage(
          imageUrl: avatarUrl,
          logicalWidth: 42,
          logicalHeight: 42,
          borderRadius: 12,
          fallbackLabel: name,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                role,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                name,
                style: const TextStyle(
                  color: FounderSovereignTokens.primaryInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: FounderSovereignTokens.mutedInk,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 3. MODAL DE REGISTRO DE GASTO DA EMPRESA (`private.ceo_expense_entries`)
// ============================================================================

class FounderRealExpenseModal extends StatefulWidget {
  const FounderRealExpenseModal({
    super.key,
    required this.repository,
  });

  final FounderCockpitRepository repository;

  static Future<bool?> show(
    BuildContext context, {
    required FounderCockpitRepository repository,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: FounderSovereignTokens.obsidianBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => FounderRealExpenseModal(repository: repository),
    );
  }

  @override
  State<FounderRealExpenseModal> createState() =>
      _FounderRealExpenseModalState();
}

class _FounderRealExpenseModalState extends State<FounderRealExpenseModal> {
  // Todos os campos iniciam 100% vazios (zero pré-preenchimento!)
  final TextEditingController _categoryCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _amountBrlCtrl = TextEditingController();

  String _expenseKind = 'FIXED_OPEX';
  DateTime _competenceDate =
      DateTime.now().toUtc().subtract(const Duration(hours: 3));
  bool _saving = false;
  String? _errorMsg;

  static const List<String> _kQuickCategorySuggestions = <String>[
    'Servidor e nuvem',
    'Contabilidade',
    'Marketing e anúncios',
    'Impostos e taxas',
  ];

  @override
  void dispose() {
    _categoryCtrl.dispose();
    _descriptionCtrl.dispose();
    _amountBrlCtrl.dispose();
    super.dispose();
  }

  int _parseBrlToCents(String raw) {
    final cleaned = raw.replaceAll('R\$', '').replaceAll(' ', '').trim();
    if (cleaned.isEmpty) return 0;
    final normalized = cleaned.contains(',')
        ? cleaned.replaceAll('.', '').replaceAll(',', '.')
        : cleaned;
    final parsed = double.tryParse(normalized);
    if (parsed == null || !parsed.isFinite || parsed <= 0) return 0;
    return (parsed * 100).round();
  }

  Future<void> _submit() async {
    final cat = _categoryCtrl.text.trim();
    final desc = _descriptionCtrl.text.trim();
    final cents = _parseBrlToCents(_amountBrlCtrl.text);

    if (cat.isEmpty) {
      setState(() => _errorMsg = 'Informe o nome ou categoria do gasto.');
      return;
    }
    if (cents <= 0) {
      setState(
        () => _errorMsg = 'Informe um valor maior que R\$ 0,00.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _errorMsg = null;
    });

    try {
      await widget.repository.recordRealExpense(
        competenceDate: _competenceDate,
        expenseKind: _expenseKind,
        category: cat,
        description: desc,
        amountCents: cents,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMsg = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final dateStr =
        '${_competenceDate.day.toString().padLeft(2, '0')}/${_competenceDate.month.toString().padLeft(2, '0')}/${_competenceDate.year}';

    return Padding(
      key: const ValueKey<String>('ceo-real-expense-modal'),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.add_card_rounded,
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Registrar gasto da empresa',
                    style: FounderSovereignTokens.titleStyle(fontSize: 17),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: FounderSovereignTokens.mutedInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Seus gastos reais são descontados automaticamente para mostrar seu lucro líquido verdadeiro.',
              style: FounderSovereignTokens.subtitleStyle(),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildKindChip('FIXED_OPEX', 'Gasto fixo mensal'),
                _buildKindChip('VARIABLE_PSP_CLOUD', 'Taxa de PIX e sistema'),
                _buildKindChip('TAX_EXTRA', 'Imposto ou taxa extra'),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final suggestion in _kQuickCategorySuggestions)
                  ActionChip(
                    label: Text(
                      suggestion,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: FounderSovereignTokens.secondaryInk,
                      ),
                    ),
                    backgroundColor: FounderSovereignTokens.obsidianSurface,
                    side: const BorderSide(
                      color: FounderSovereignTokens.crispBorder,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _categoryCtrl.text = suggestion);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('ceo-expense-category-input'),
              controller: _categoryCtrl,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              style: const TextStyle(color: FounderSovereignTokens.primaryInk),
              decoration: InputDecoration(
                labelText: 'Qual foi o gasto? (ex.: Contabilidade, Servidor)',
                filled: true,
                fillColor: FounderSovereignTokens.obsidianCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('ceo-expense-amount-input'),
              controller: _amountBrlCtrl,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: FounderSovereignTokens.monoMetric(
                fontSize: 16,
                color: FounderSovereignTokens.imperialGoldBright,
              ),
              decoration: InputDecoration(
                labelText: 'Valor pago em R\$ (ex.: 149,90)',
                prefixText: 'R\$ ',
                filled: true,
                fillColor: FounderSovereignTokens.obsidianCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('ceo-expense-description-input'),
              controller: _descriptionCtrl,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              style: const TextStyle(color: FounderSovereignTokens.primaryInk),
              decoration: InputDecoration(
                labelText: 'Observação ou comprovante (opcional)',
                filled: true,
                fillColor: FounderSovereignTokens.obsidianCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              key: const ValueKey<String>('ceo-expense-date-picker-btn'),
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final picked =
                    await FounderExecutiveCalendarSheet.pickSingleDate(
                  context,
                  initialDate: _competenceDate,
                  firstDate: DateTime(2024, 1, 1),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null && mounted) {
                  setState(() => _competenceDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: FounderSovereignTokens.obsidianCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: FounderSovereignTokens.imperialGold
                        .withValues(alpha: 0.42),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: FounderSovereignTokens.imperialGoldBright,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Data do gasto',
                        style: TextStyle(
                          color: FounderSovereignTokens.secondaryInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      dateStr,
                      style: FounderSovereignTokens.monoMetric(
                        fontSize: 13.5,
                        color: FounderSovereignTokens.imperialGoldBright,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: FounderSovereignTokens.mutedInk,
                    ),
                  ],
                ),
              ),
            ),
            if (_errorMsg != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                _errorMsg!,
                style: const TextStyle(
                  color: FounderSovereignTokens.crimsonAlert,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey<String>('ceo-expense-save-btn'),
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: FounderSovereignTokens.imperialGold,
                  foregroundColor: const Color(0xFF0B0E14),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text(
                  'Salvar gasto',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKindChip(String code, String label) {
    final selected = _expenseKind == code;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _expenseKind = code),
      selectedColor: FounderSovereignTokens.imperialGoldSoft,
      backgroundColor: FounderSovereignTokens.obsidianSurface,
      side: BorderSide(
        color: selected
            ? FounderSovereignTokens.imperialGold
            : FounderSovereignTokens.crispBorder,
      ),
      labelStyle: TextStyle(
        color: selected
            ? FounderSovereignTokens.imperialGoldBright
            : FounderSovereignTokens.mutedInk,
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

// ============================================================================
// 4. DIRETÓRIO SINCRONIZADO DE PESSOAS + FICHA EXECUTIVA AO TOQUE
// ============================================================================

class FounderUsersCrmDirectoryCard extends StatefulWidget {
  const FounderUsersCrmDirectoryCard({
    super.key,
    required this.repository,
    this.privacyBlurActive = false,
    this.externalRoleFilter,
    this.onRoleFilterChanged,
  });

  final FounderCockpitRepository repository;
  final bool privacyBlurActive;
  final String? externalRoleFilter;
  final ValueChanged<String>? onRoleFilterChanged;

  @override
  State<FounderUsersCrmDirectoryCard> createState() =>
      _FounderUsersCrmDirectoryCardState();
}

class _FounderUsersCrmDirectoryCardState
    extends State<FounderUsersCrmDirectoryCard> {
  // Campo de busca 100% vazio ao iniciar!
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  late String _roleFilter = widget.externalRoleFilter ?? 'all';
  bool _loading = true;
  String? _error;
  List<CeoRealUserDirectoryRow> _users = const <CeoRealUserDirectoryRow>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadUsers());
  }

  @override
  void didUpdateWidget(covariant FounderUsersCrmDirectoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.externalRoleFilter;
    if (incoming != null &&
        incoming != oldWidget.externalRoleFilter &&
        incoming != _roleFilter) {
      _roleFilter = incoming;
      unawaited(_loadUsers());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rpcFilter = (_roleFilter == 'kyc_verified' ||
              _roleFilter == 'only_provider')
          ? (_roleFilter == 'only_provider' ? 'provider' : 'all')
          : _roleFilter;
      var list = await widget.repository.listRealUsersDirectory(
        search: _searchCtrl.text,
        roleFilter: rpcFilter,
        limit: 90,
      );
      if (_roleFilter == 'kyc_verified') {
        list = list.where((u) => u.isKycApproved).toList(growable: false);
      } else if (_roleFilter == 'only_provider') {
        list = list
            .where((u) => u.isProvider && !u.isClient)
            .toList(growable: false);
      }
      if (!mounted) return;
      setState(() {
        _users = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _setRoleFilter(String next) {
    HapticFeedback.selectionClick();
    setState(() => _roleFilter = next);
    widget.onRoleFilterChanged?.call(next);
    unawaited(_loadUsers());
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), _loadUsers);
  }

  @override
  Widget build(BuildContext context) {
    return FounderGlassCard(
      key: const ValueKey<String>('ceo-users-crm-directory-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.people_alt_rounded,
                size: 19,
                color: FounderSovereignTokens.imperialGoldBright,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Clientes e profissionais (${_users.length})',
                  style: FounderSovereignTokens.titleStyle(fontSize: 16),
                ),
              ),
              IconButton(
                tooltip: 'Atualizar lista',
                onPressed: _loadUsers,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: FounderSovereignTokens.mutedInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey<String>('ceo-users-directory-search-input'),
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            style: const TextStyle(
              color: FounderSovereignTokens.primaryInk,
              fontSize: 13.5,
            ),
            decoration: InputDecoration(
              hintText: 'Buscar por nome, cidade ou profissão…',
              hintStyle: const TextStyle(
                color: FounderSovereignTokens.mutedInk,
                fontSize: 12.5,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 18,
                color: FounderSovereignTokens.mutedInk,
              ),
              isDense: true,
              filled: true,
              fillColor: FounderSovereignTokens.obsidianSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: FounderSovereignTokens.crispBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: FounderSovereignTokens.crispBorder,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _buildRoleChip('all', 'Todos'),
                const SizedBox(width: 6),
                _buildRoleChip('client', 'Só Clientes'),
                const SizedBox(width: 6),
                _buildRoleChip('only_provider', 'Só Profissionais'),
                const SizedBox(width: 6),
                _buildRoleChip('dual', 'Ambos (Os 2 modos)'),
                const SizedBox(width: 6),
                _buildRoleChip('kyc_pending', 'Documentos Pendentes'),
                const SizedBox(width: 6),
                _buildRoleChip('kyc_verified', 'Documentos Aprovados'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: FounderSovereignTokens.imperialGoldBright,
                  ),
                ),
              ),
            )
          else if (_error != null)
            Text(
              _error!,
              style: const TextStyle(
                color: FounderSovereignTokens.crimsonAlert,
                fontSize: 12,
              ),
            )
          else if (_users.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FounderSovereignTokens.crispBorder),
              ),
              child: const Text(
                'Nenhuma pessoa encontrada para este filtro.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: FounderSovereignTokens.mutedInk,
                  fontSize: 12.5,
                ),
              ),
            )
          else
            Column(
              children: <Widget>[
                for (final u in _users.take(30))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: FounderSovereignTokens.obsidianSurface,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          FounderUserDetailSheet.show(
                            context,
                            user: u,
                            privacyBlurActive: widget.privacyBlurActive,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: FounderSovereignTokens.crispBorder,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              FounderUltraHdImage(
                                imageUrl: u.avatarUrl,
                                logicalWidth: 44,
                                logicalHeight: 44,
                                borderRadius: 22,
                                fallbackLabel: u.fullName,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: <Widget>[
                                        Text(
                                          u.fullName,
                                          style: const TextStyle(
                                            color: FounderSovereignTokens
                                                .primaryInk,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        _StatusTag(
                                          label: u.isClient && u.isProvider
                                              ? 'Ambos (2 modos)'
                                              : (u.isProvider
                                                  ? 'Só Profissional'
                                                  : 'Só Cliente'),
                                          color: u.isClient && u.isProvider
                                              ? FounderSovereignTokens
                                                  .imperialGoldBright
                                              : (u.isProvider
                                                  ? FounderSovereignTokens
                                                      .cyberCyan
                                                  : FounderSovereignTokens
                                                      .secondaryInk),
                                        ),
                                        _StatusTag(
                                          label: u.isKycApproved
                                              ? 'Verificado'
                                              : 'Em análise',
                                          color: u.isKycApproved
                                              ? FounderSovereignTokens
                                                  .solvencyEmerald
                                              : FounderSovereignTokens
                                                  .warmAmber,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${u.city.isNotEmpty ? u.city : "Sem cidade"} · '
                                      '${u.clientJobsCount} pedidos · '
                                      '${u.jobsDone} atendimentos'
                                      '${u.ratingCount > 0 ? " · Nota ${u.ratingAvg.toStringAsFixed(1).replaceAll('.', ',')} ★" : ""}',
                                      style: const TextStyle(
                                        color: FounderSovereignTokens.mutedInk,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    if (u.specialties.isNotEmpty) ...<Widget>[
                                      const SizedBox(height: 3),
                                      Text(
                                        u.specialties.take(4).join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: FounderSovereignTokens
                                              .imperialGoldBright,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (u.totalCustodyCents > 0)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: <Widget>[
                                      const Text(
                                        'Saldo',
                                        style: TextStyle(
                                          color:
                                              FounderSovereignTokens.mutedInk,
                                          fontSize: 10,
                                        ),
                                      ),
                                      AnimatedMoneyOdometer(
                                        cents: u.totalCustodyCents,
                                        privacyBlurActive:
                                            widget.privacyBlurActive,
                                        style:
                                            FounderSovereignTokens.monoMetric(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: FounderSovereignTokens
                                              .solvencyEmerald,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: FounderSovereignTokens.mutedInk,
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
        ],
      ),
    );
  }

  Widget _buildRoleChip(String code, String label) {
    final active = _roleFilter == code;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => _setRoleFilter(code),
      selectedColor: FounderSovereignTokens.imperialGoldSoft,
      backgroundColor: FounderSovereignTokens.obsidianSurface,
      side: BorderSide(
        color: active
            ? FounderSovereignTokens.imperialGold
            : FounderSovereignTokens.crispBorder,
      ),
      labelStyle: TextStyle(
        color: active
            ? FounderSovereignTokens.imperialGoldBright
            : FounderSovereignTokens.mutedInk,
        fontSize: 12,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Ficha executiva detalhada de Cliente ou Profissional ao tocar no diretório.
class FounderUserDetailSheet extends StatelessWidget {
  const FounderUserDetailSheet({
    super.key,
    required this.user,
    this.privacyBlurActive = false,
  });

  final CeoRealUserDirectoryRow user;
  final bool privacyBlurActive;

  static Future<void> show(
    BuildContext context, {
    required CeoRealUserDirectoryRow user,
    bool privacyBlurActive = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FounderSovereignTokens.obsidianBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => FounderUserDetailSheet(
        key: const ValueKey<String>('ceo-user-detail-sheet'),
        user: user,
        privacyBlurActive: privacyBlurActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FounderSovereignTokens.crispBorderStrong,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                FounderUltraHdImage(
                  imageUrl: user.avatarUrl,
                  logicalWidth: 56,
                  logicalHeight: 56,
                  borderRadius: 28,
                  fallbackLabel: user.fullName,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user.fullName,
                        style: FounderSovereignTokens.titleStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: <Widget>[
                          _StatusTag(
                            label: user.roleLabelPt,
                            color: user.isClient && user.isProvider
                                ? FounderSovereignTokens.imperialGoldBright
                                : (user.isProvider
                                    ? FounderSovereignTokens.cyberCyan
                                    : FounderSovereignTokens.secondaryInk),
                          ),
                          _StatusTag(
                            label: user.isKycApproved
                                ? 'Documentos aprovados'
                                : 'Documentos pendentes',
                            color: user.isKycApproved
                                ? FounderSovereignTokens.solvencyEmerald
                                : FounderSovereignTokens.warmAmber,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: FounderSovereignTokens.mutedInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FounderGlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Cidade: ${user.city.isNotEmpty ? user.city : "Não informada"} · Cadastro em ${_formatDateBrShort(user.createdAt)}',
                    style: FounderSovereignTokens.subtitleStyle(
                      color: FounderSovereignTokens.secondaryInk,
                    ),
                  ),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: _MoneyKpiMini(
                            label: 'Saldo disponível cliente',
                            cents: user.clientWalletAvailableCents,
                            privacyBlurActive: privacyBlurActive,
                            color: FounderSovereignTokens.primaryInk,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MoneyKpiMini(
                            label: 'Em serviço (protegido)',
                            cents: user.clientWalletEscrowCents,
                            privacyBlurActive: privacyBlurActive,
                            color: FounderSovereignTokens.imperialGoldBright,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: _MoneyKpiMini(
                            label: 'Carteira profissional',
                            cents: user.providerWalletCents,
                            privacyBlurActive: privacyBlurActive,
                            color: FounderSovereignTokens.solvencyEmerald,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: FounderSovereignTokens.obsidianSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: FounderSovereignTokens.crispBorder,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Text(
                                  'Histórico na plataforma',
                                  style: TextStyle(
                                    color: FounderSovereignTokens.mutedInk,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${user.clientJobsCount} pedidos · ${user.jobsDone} atendimentos',
                                  style: FounderSovereignTokens.monoMetric(
                                    fontSize: 12.5,
                                    color: FounderSovereignTokens.primaryInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (user.specialties.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                'Profissões atendidas',
                style: FounderSovereignTokens.titleStyle(fontSize: 14.5),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.specialties.map((spec) {
                  return Container(
                    padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                    decoration: BoxDecoration(
                      color: FounderSovereignTokens.obsidianCard,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: FounderSovereignTokens.crispBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        CategoryBrandEmblem(
                          categoryName: spec,
                          size: 22,
                          showCornerBadge: false,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          spec,
                          style: const TextStyle(
                            color: FounderSovereignTokens.primaryInk,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

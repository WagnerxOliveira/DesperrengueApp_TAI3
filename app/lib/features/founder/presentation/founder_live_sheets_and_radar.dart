import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/analytics/founder_dashboard_models.dart';
import '../data/founder_cockpit_repository.dart';
import 'founder_animations_and_shaders.dart';

bool _isRunningInWidgetTest() {
  final bindingName = WidgetsBinding.instance.runtimeType.toString();
  return bindingName.contains('TestWidgetsFlutterBinding') ||
      bindingName.contains('AutomatedTestWidgetsFlutterBinding') ||
      bindingName.contains('LiveTestWidgetsFlutterBinding');
}

String _formatDateTimeBr(DateTime? utc) {
  if (utc == null) return '—';
  final brt = utc.toUtc().subtract(const Duration(hours: 3));
  final dd = brt.day.toString().padLeft(2, '0');
  final mm = brt.month.toString().padLeft(2, '0');
  final yyyy = brt.year.toString().padLeft(4, '0');
  final hh = brt.hour.toString().padLeft(2, '0');
  final min = brt.minute.toString().padLeft(2, '0');
  return '$dd/$mm/$yyyy às $hh:$min';
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
      return 'Aberto';
    case 'awaiting_payment':
      return 'Aguardando PIX';
    case 'scheduled':
      return 'Agendado';
    case 'in_progress':
      return 'Em Execução';
    case 'awaiting_approval':
      return 'Aguardando Aprovação';
    case 'completed':
      return 'Concluído';
    case 'disputed':
      return 'Em Mediação';
    case 'canceled':
    case 'cancelled':
      return 'Cancelado';
    default:
      return status;
  }
}

// ============================================================================
// 1. RADAR CARTOGRÁFICO EM TEMPO REAL (`public.job_geo` + `FlutterMap` Dark)
// ============================================================================

/// Matriz de cor escura para transformar blocos OpenStreetMap em cartografia
/// executiva *Obsidian Slate* sem depender de chaves externas pagas.
const ColorFilter _kObsidianMapTileFilter = ColorFilter.matrix(<double>[
  -0.24, -0.58, -0.14, 0, 215, // R
  -0.22, -0.54, -0.12, 0, 224, // G
  -0.18, -0.48, -0.10, 0, 238, // B
  0, 0, 0, 1, 0, // A
]);

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

  static const LatLng _kBrazilCenter = LatLng(-15.7801, -47.9292);

  List<CeoLiveMapPoint> get _filteredPoints {
    return widget.points.where((p) {
      if (!p.lat.isFinite || !p.lng.isFinite) return false;
      if (p.lat == 0 && p.lng == 0) return false;
      switch (_statusFilter) {
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

  LatLng _computeInitialCenter(List<CeoLiveMapPoint> pts) {
    if (pts.isEmpty) return _kBrazilCenter;
    var sumLat = 0.0;
    var sumLng = 0.0;
    for (final p in pts) {
      sumLat += p.lat;
      sumLng += p.lng;
    }
    return LatLng(sumLat / pts.length, sumLng / pts.length);
  }

  double _computeInitialZoom(List<CeoLiveMapPoint> pts) {
    if (pts.isEmpty) return 4.0;
    if (pts.length == 1) return 13.5;
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
    if (span < 0.02) return 14.0;
    if (span < 0.08) return 12.2;
    if (span < 0.35) return 10.5;
    if (span < 1.5) return 8.2;
    if (span < 6.0) return 6.0;
    return 4.3;
  }

  void _fitAllPoints() {
    HapticFeedback.selectionClick();
    final pts = _filteredPoints;
    try {
      _mapController.move(
        _computeInitialCenter(pts),
        _computeInitialZoom(pts),
      );
    } catch (_) {}
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
      accentTopBarColor: FounderSovereignTokens.cyberCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.radar_rounded,
                          size: 18,
                          color: FounderSovereignTokens.cyberCyan,
                        ),
                      ),
                    ),
                    TextSpan(
                      text:
                          'Radar Cartográfico ao Vivo (${pts.length} pinos reais)',
                    ),
                  ],
                ),
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _fitAllPoints,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  foregroundColor: FounderSovereignTokens.primaryInk,
                  side: const BorderSide(
                    color: FounderSovereignTokens.crispBorder,
                  ),
                ),
                icon: const Icon(Icons.my_location_rounded, size: 14),
                label: const Text(
                  'Enquadrar',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _buildFilterChip('all', 'Todos (${widget.points.length})'),
                const SizedBox(width: 6),
                _buildFilterChip('execution', 'Em Execução'),
                const SizedBox(width: 6),
                _buildFilterChip('scheduled', 'Agendados'),
                const SizedBox(width: 6),
                _buildFilterChip('open', 'Abertos / PIX'),
                const SizedBox(width: 6),
                _buildFilterChip('completed', 'Concluídos'),
                const SizedBox(width: 6),
                _buildFilterChip('disputed', 'Mediação'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FounderPrivacyBlurWrap(
            privacyBlurActive: widget.privacyBlurActive,
            borderRadius: 14,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: FounderSovereignTokens.crispBorder),
                ),
                child: Stack(
                  children: <Widget>[
                    // Grade tática vetorial sempre presente sob os blocos
                    const Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _TacticalRadarGridPainter(),
                        ),
                      ),
                    ),
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _computeInitialCenter(pts),
                        initialZoom: _computeInitialZoom(pts),
                        backgroundColor: Colors.transparent,
                      ),
                      children: <Widget>[
                        if (useNetworkTiles)
                          ColorFiltered(
                            colorFilter: _kObsidianMapTileFilter,
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
                                width: 42,
                                height: 42,
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selectedJobId = p.jobId);
                                  },
                                  child: _RadarPinWidget(
                                    color: founderStatusColor(p.status),
                                    selected: selectedPoint?.jobId == p.jobId,
                                    isExact: p.isExactPin,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    if (pts.isEmpty)
                      Center(
                        child: Container(
                          margin: const EdgeInsets.all(18),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: FounderSovereignTokens.obsidianSurface
                                .withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: FounderSovereignTokens.crispBorder,
                            ),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.explore_off_rounded,
                                color: FounderSovereignTokens.cyberCyan,
                                size: 24,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Nenhum pino georreferenciado neste filtro',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: FounderSovereignTokens.primaryInk,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Assim que um pedido real for publicado no Desperrengue, sua coordenada aparecerá ao vivo aqui.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: FounderSovereignTokens.mutedInk,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      right: 8,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: FounderSovereignTokens.obsidianBackground
                              .withValues(alpha: 0.84),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '© OpenStreetMap · Visão Soberana CEO',
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
          if (selectedPoint != null) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: founderStatusColor(selectedPoint.status)
                      .withValues(alpha: 0.45),
                ),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            selectedPoint.orderCode,
                            style: FounderSovereignTokens.monoMetric(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: founderStatusColor(selectedPoint.status),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: founderStatusColor(selectedPoint.status)
                                  .withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              founderStatusLabelPt(selectedPoint.status),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: founderStatusColor(selectedPoint.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${selectedPoint.categoryName} · ${selectedPoint.neighborhood.isNotEmpty ? "${selectedPoint.neighborhood}, " : ""}${selectedPoint.city}',
                        style: const TextStyle(
                          color: FounderSovereignTokens.primaryInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cliente: ${selectedPoint.clientName}'
                        '${selectedPoint.providerName != null ? " · Prestador: ${selectedPoint.providerName}" : ""}',
                        style: const TextStyle(
                          color: FounderSovereignTokens.mutedInk,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      AnimatedMoneyOdometer(
                        cents: selectedPoint.amountCents,
                        privacyBlurActive: widget.privacyBlurActive,
                        style: FounderSovereignTokens.monoMetric(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: FounderSovereignTokens.imperialGoldBright,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => widget.onInspectOrder(
                          selectedPoint!.jobId,
                          selectedPoint.orderCode,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              FounderSovereignTokens.imperialGoldSoft,
                          foregroundColor:
                              FounderSovereignTokens.imperialGoldBright,
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                        icon: const Icon(Icons.policy_rounded, size: 15),
                        label: const Text(
                          'Dossiê Forense',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
      selectedColor: FounderSovereignTokens.cyberCyanSoft,
      backgroundColor: FounderSovereignTokens.obsidianSurface,
      side: BorderSide(
        color: active
            ? FounderSovereignTokens.cyberCyan
            : FounderSovereignTokens.crispBorder,
      ),
      labelStyle: TextStyle(
        color: active
            ? FounderSovereignTokens.cyberCyan
            : FounderSovereignTokens.mutedInk,
        fontSize: 11.5,
        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _RadarPinWidget extends StatelessWidget {
  const _RadarPinWidget({
    required this.color,
    required this.selected,
    required this.isExact,
  });

  final Color color;
  final bool selected;
  final bool isExact;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.18 : 1.0,
      duration: const Duration(milliseconds: 180),
      child: Center(
        child: Container(
          width: selected ? 30 : 24,
          height: selected ? 30 : 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.24),
            border: Border.all(
              color: color,
              width: selected ? 2.2 : 1.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: color.withValues(alpha: selected ? 0.55 : 0.28),
                blurRadius: selected ? 12 : 6,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Container(
            width: isExact ? 9 : 7,
            height: isExact ? 9 : 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _TacticalRadarGridPainter extends CustomPainter {
  const _TacticalRadarGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1A2433).withValues(alpha: 0.55)
      ..strokeWidth = 0.8;

    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = FounderSovereignTokens.cyberCyan.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = math.min(size.width, size.height) * 0.44;
    canvas.drawCircle(center, maxR * 0.45, ringPaint);
    canvas.drawCircle(center, maxR * 0.85, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 2. DOSSIÊ FORENSE COMPLETO DE PEDIDO REAL (`ceo_inspect_order_forensics`)
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
    return Column(
      key: const ValueKey<String>('ceo-order-forensic-sheet'),
      children: <Widget>[
        const SizedBox(height: 8),
        Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: FounderSovereignTokens.crispBorder,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 10),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.policy_rounded,
                color: FounderSovereignTokens.imperialGoldBright,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dossiê Forense em Tempo Real ${widget.initialOrderCode ?? ""}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Atualizar dossiê',
                onPressed: _reload,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
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
                              'Não foi possível carregar os registros forenses deste pedido.',
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
                          label: const Text('Tentar Novamente'),
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
      accentTopBarColor: stColor,
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
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
              ),
              _StatusTag(
                label: founderStatusLabelPt(d.status),
                color: stColor,
              ),
              _StatusTag(
                label: 'Escrow: ${d.escrowStatus}',
                color: FounderSovereignTokens.cyberCyan,
              ),
              _StatusTag(
                label: 'Pagamento: ${d.paymentStatus}',
                color: FounderSovereignTokens.solvencyEmerald,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${d.category} · ${d.title}',
            style: const TextStyle(
              color: FounderSovereignTokens.primaryInk,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (d.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              d.description,
              style: const TextStyle(
                color: FounderSovereignTokens.mutedInk,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: <Widget>[
              _MoneyKpiMini(
                label: 'Valor Acordado (GMV)',
                cents: d.agreedPriceCents,
                privacyBlurActive: widget.privacyBlurActive,
                color: FounderSovereignTokens.imperialGoldBright,
              ),
              _MoneyKpiMini(
                label: 'Mão de Obra',
                cents: d.laborCents,
                privacyBlurActive: widget.privacyBlurActive,
                color: FounderSovereignTokens.primaryInk,
              ),
              _MoneyKpiMini(
                label: 'Peças Isentas (0%)',
                cents: d.materialsCents,
                privacyBlurActive: widget.privacyBlurActive,
                color: FounderSovereignTokens.cyberCyan,
              ),
            ],
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
            'Partes Identificadas na Ordem',
            style: FounderSovereignTokens.monoMetric(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _ActorRow(
            role: 'Cliente Solicitante',
            name: (c['full_name'] ?? 'Cliente').toString(),
            subtitle:
                'Cidade: ${c['city'] ?? "—"} · KYC: ${c['client_kyc_status'] ?? "NOT_SUBMITTED"}',
            avatarUrl: c['avatar_url']?.toString(),
            accent: FounderSovereignTokens.warmAmber,
          ),
          const Divider(height: 18, color: FounderSovereignTokens.crispBorder),
          if (p != null)
            _ActorRow(
              role: 'Prestador Designado',
              name: (p['full_name'] ?? 'Prestador').toString(),
              subtitle:
                  'Cidade: ${p['city'] ?? "—"} · Status: ${p['verification_status'] ?? "PENDING"} · OS Concluídas: ${p['jobs_done'] ?? 0}',
              avatarUrl: p['avatar_url']?.toString(),
              accent: FounderSovereignTokens.cyberCyan,
            )
          else
            const Text(
              'Nenhum prestador designado até o momento (aguardando aceite de orçamento).',
              style: TextStyle(
                color: FounderSovereignTokens.mutedInk,
                fontSize: 12,
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
            'Geolocalização & Auditoria de Presença Física (GPS)',
            style: FounderSovereignTokens.monoMetric(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bairro/Cidade: ${loc['neighborhood'] ?? "—"} · ${loc['city'] ?? "—"}/${loc['uf'] ?? ""}',
            style: const TextStyle(
              color: FounderSovereignTokens.primaryInk,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if ((loc['address_line'] ?? '').toString().trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: FounderPrivacyBlurWrap(
                privacyBlurActive: widget.privacyBlurActive,
                child: Text(
                  'Endereço Custodiado: ${loc['address_line']}',
                  style: const TextStyle(
                    color: FounderSovereignTokens.mutedInk,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'Check-in GPS: ${checkinDist != null ? "${checkinDist}m do pino" : "Ainda não realizado"}',
            style: FounderSovereignTokens.monoMetric(
              fontSize: 11.5,
              color: checkinDist != null
                  ? FounderSovereignTokens.solvencyEmerald
                  : FounderSovereignTokens.mutedInk,
            ),
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
            'Propostas / Orçamentos (${d.quotes.length}) & Convites (${d.invites.length})',
            style: FounderSovereignTokens.monoMetric(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (d.quotes.isEmpty)
            const Text(
              'Nenhuma proposta enviada ainda para este pedido.',
              style: TextStyle(
                color: FounderSovereignTokens.mutedInk,
                fontSize: 12,
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
                        '${q['provider_name'] ?? "Prestador"} · Status: ${q['status'] ?? "pending"}',
                        style: const TextStyle(
                          color: FounderSovereignTokens.primaryInk,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    AnimatedMoneyOdometer(
                      cents: (q['amount_cents'] is num)
                          ? (q['amount_cents'] as num).round()
                          : 0,
                      privacyBlurActive: widget.privacyBlurActive,
                      style: FounderSovereignTokens.monoMetric(
                        fontSize: 12,
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
            'Pagamentos (${d.payments.length}) · Razão Contábil (${d.ledgerTxns.length}) · Maturação (${d.maturationEntries.length})',
            style: FounderSovereignTokens.monoMetric(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (d.payments.isEmpty && d.ledgerTxns.isEmpty)
            const Text(
              'Nenhuma liquidação financeira registrada para esta ordem ainda.',
              style: TextStyle(
                color: FounderSovereignTokens.mutedInk,
                fontSize: 12,
              ),
            ),
          for (final l in d.ledgerTxns)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${l['entry_kind'] ?? l['kind'] ?? "LEDGER"} · ${l['bucket'] ?? ""}',
                      style: FounderSovereignTokens.monoMetric(
                        fontSize: 11.5,
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
                      fontSize: 11.5,
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
            'Documentos Fiscais NF-e (${d.fiscalDocuments.length}) · Mediações (${d.mediations.length}) · Avaliações (${d.reviews.length})',
            style: FounderSovereignTokens.monoMetric(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (d.fiscalDocuments.isEmpty &&
              d.mediations.isEmpty &&
              d.reviews.isEmpty)
            const Text(
              'Sem notas fiscais, mediações ou avaliações anexadas até o momento.',
              style: TextStyle(
                color: FounderSovereignTokens.mutedInk,
                fontSize: 12,
              ),
            ),
          for (final f in d.fiscalDocuments)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'NF-e 44 dígitos: ${f['nfe_access_key'] ?? "—"} · Status SEFAZ: ${f['sefaz_status'] ?? "PENDING"}',
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 11.5,
                  color: FounderSovereignTokens.cyberCyan,
                ),
              ),
            ),
          for (final r in d.reviews)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Avaliação ${r['rating'] ?? 5}★: "${r['comment'] ?? ""}"',
                style: const TextStyle(
                  color: FounderSovereignTokens.primaryInk,
                  fontSize: 12,
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
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: FounderSovereignTokens.mutedInk,
            fontSize: 10.5,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedMoneyOdometer(
          cents: cents,
          privacyBlurActive: privacyBlurActive,
          style: FounderSovereignTokens.monoMetric(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
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
          fallbackLabel: role.substring(0, 3).toUpperCase(),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                role,
                style: TextStyle(
                  color: accent,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                name,
                style: const TextStyle(
                  color: FounderSovereignTokens.primaryInk,
                  fontSize: 13.5,
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
// 3. MODAL DE LANÇAMENTO DE DESPESA REAL (`private.ceo_expense_entries`)
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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

  @override
  void dispose() {
    _categoryCtrl.dispose();
    _descriptionCtrl.dispose();
    _amountBrlCtrl.dispose();
    super.dispose();
  }

  int _parseBrlToCents(String raw) {
    final cleaned = raw
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .trim();
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
      setState(() => _errorMsg = 'Informe a categoria contábil da despesa.');
      return;
    }
    if (cents <= 0) {
      setState(
        () => _errorMsg = 'Informe um valor real maior que R\$ 0,00.',
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
                  Icons.receipt_long_rounded,
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Registrar Despesa Operacional Real',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
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
            const SizedBox(height: 6),
            const Text(
              'O DRE Soberano utiliza exclusivamente despesas reais lançadas por você (zero estimativas fixas).',
              style: TextStyle(
                color: FounderSovereignTokens.mutedInk,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildKindChip('FIXED_OPEX', 'OPEX Fixo'),
                _buildKindChip('VARIABLE_PSP_CLOUD', 'Variável (PSP / Cloud)'),
                _buildKindChip('TAX_EXTRA', 'Tributo / Taxa Extra'),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey<String>('ceo-expense-category-input'),
              controller: _categoryCtrl,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              style: const TextStyle(color: FounderSovereignTokens.primaryInk),
              decoration: InputDecoration(
                labelText: 'Categoria (ex.: Infraestrutura Cloud, Contabilidade)',
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
                labelText: 'Valor Real em R\$ (ex.: 149,90)',
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
                labelText: 'Descrição / Comprovante (opcional)',
                filled: true,
                fillColor: FounderSovereignTokens.obsidianCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _competenceDate,
                  firstDate: DateTime(2024, 1, 1),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null && mounted) {
                  setState(() => _competenceDate = picked);
                }
              },
              icon: const Icon(Icons.calendar_today_rounded, size: 15),
              label: Text('Data de Competência: $dateStr'),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey<String>('ceo-expense-save-btn'),
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: FounderSovereignTokens.imperialGold,
                  foregroundColor: const Color(0xFF111827),
                  minimumSize: const Size.fromHeight(46),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text(
                  'Lançar no DRE Soberano',
                  style: TextStyle(fontWeight: FontWeight.w800),
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
      labelStyle: TextStyle(
        color: selected
            ? FounderSovereignTokens.imperialGoldBright
            : FounderSovereignTokens.mutedInk,
        fontSize: 11.5,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }
}

// ============================================================================
// 4. DIRETÓRIO CRM PESQUISÁVEL DE USUÁRIOS REAIS (`ceo_list_real_users_directory`)
// ============================================================================

class FounderUsersCrmDirectoryCard extends StatefulWidget {
  const FounderUsersCrmDirectoryCard({
    super.key,
    required this.repository,
    this.privacyBlurActive = false,
  });

  final FounderCockpitRepository repository;
  final bool privacyBlurActive;

  @override
  State<FounderUsersCrmDirectoryCard> createState() =>
      _FounderUsersCrmDirectoryCardState();
}

class _FounderUsersCrmDirectoryCardState
    extends State<FounderUsersCrmDirectoryCard> {
  // Campo de busca 100% vazio ao iniciar!
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _roleFilter = 'all';
  bool _loading = true;
  String? _error;
  List<CeoRealUserDirectoryRow> _users = const <CeoRealUserDirectoryRow>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadUsers());
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
      final list = await widget.repository.listRealUsersDirectory(
        search: _searchCtrl.text,
        roleFilter: _roleFilter,
        limit: 80,
      );
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

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), _loadUsers);
  }

  @override
  Widget build(BuildContext context) {
    return FounderGlassCard(
      key: const ValueKey<String>('ceo-users-crm-directory-card'),
      accentTopBarColor: FounderSovereignTokens.imperialGold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.badge_rounded,
                size: 18,
                color: FounderSovereignTokens.imperialGoldBright,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Diretório Real de Usuários & Prestadores (${_users.length})',
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Recarregar diretório real',
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
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'Buscar por nome real, cidade ou especialidade…',
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
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _buildRoleChip('all', 'Todos'),
                const SizedBox(width: 6),
                _buildRoleChip('client', 'Clientes'),
                const SizedBox(width: 6),
                _buildRoleChip('provider', 'Prestadores'),
                const SizedBox(width: 6),
                _buildRoleChip('dual', 'Modo Híbrido'),
                const SizedBox(width: 6),
                _buildRoleChip('kyc_pending', 'KYC Pendente'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
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
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FounderSovereignTokens.crispBorder),
              ),
              child: const Text(
                'Nenhum perfil cadastrado corresponde a este filtro no momento.',
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
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FounderSovereignTokens.obsidianSurface,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: FounderSovereignTokens.crispBorder),
                    ),
                    child: Row(
                      children: <Widget>[
                        FounderUltraHdImage(
                          imageUrl: u.avatarUrl,
                          logicalWidth: 40,
                          logicalHeight: 40,
                          borderRadius: 10,
                          fallbackLabel: u.isProvider ? 'PRO' : 'CLI',
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: <Widget>[
                                  Text(
                                    u.fullName,
                                    style: const TextStyle(
                                      color: FounderSovereignTokens.primaryInk,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  _StatusTag(
                                    label: u.roleLabelPt,
                                    color: u.isClient && u.isProvider
                                        ? FounderSovereignTokens
                                            .imperialGoldBright
                                        : (u.isProvider
                                            ? FounderSovereignTokens.cyberCyan
                                            : FounderSovereignTokens.warmAmber),
                                  ),
                                  if (u.isKycApproved)
                                    const _StatusTag(
                                      label: 'KYC Verificado',
                                      color:
                                          FounderSovereignTokens.solvencyEmerald,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${u.city.isNotEmpty ? u.city : "Cidade não informada"} · '
                                'Pedidos Cliente: ${u.clientJobsCount} · '
                                'OS Prestador: ${u.jobsDone}'
                                '${u.ratingCount > 0 ? " · ${u.ratingAvg.toStringAsFixed(1)}★ (${u.ratingCount})" : ""}'
                                ' · Desde ${_formatDateTimeBr(u.createdAt)}',
                                style: const TextStyle(
                                  color: FounderSovereignTokens.mutedInk,
                                  fontSize: 11,
                                ),
                              ),
                              if (u.specialties.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 3),
                                Text(
                                  'Especialidades: ${u.specialties.take(4).join(", ")}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: FounderSovereignTokens.cyberCyan,
                                    fontSize: 10.5,
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
                                  'Saldo/Custódia',
                                  style: TextStyle(
                                    color: FounderSovereignTokens.mutedInk,
                                    fontSize: 9.5,
                                  ),
                                ),
                                AnimatedMoneyOdometer(
                                  cents: u.totalCustodyCents,
                                  privacyBlurActive: widget.privacyBlurActive,
                                  style: FounderSovereignTokens.monoMetric(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        FounderSovereignTokens.solvencyEmerald,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _roleFilter = code);
        unawaited(_loadUsers());
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
        fontSize: 11.5,
        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

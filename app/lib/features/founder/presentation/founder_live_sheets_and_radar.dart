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
      return 'Em andamento';
    case 'awaiting_approval':
      return 'Aguardando aprovação';
    case 'completed':
      return 'Concluído';
    case 'disputed':
      return 'Em disputa';
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

String _humanPaymentLabelPt(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'paid':
    case 'succeeded':
    case 'approved':
    case 'completed':
      return 'PIX confirmado';
    case 'pending':
    case 'awaiting_payment':
      return 'Aguardando PIX';
    case 'refunded':
      return 'Estornado';
    case 'failed':
    case 'canceled':
      return 'Não concluído';
    default:
      return 'Em processamento';
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

// ============================================================================
// 1. MAPA DE SERVIÇOS EM TEMPO REAL (`public.job_geo` + `FlutterMap` Dark)
// ============================================================================

/// Matriz de cor escura estilo mobilidade executiva (*Velvet Slate*) para OpenStreetMap.
const ColorFilter _kObsidianMapTileFilter = ColorFilter.matrix(<double>[
  -0.22, -0.55, -0.13, 0, 206, // R
  -0.20, -0.51, -0.12, 0, 216, // G
  -0.16, -0.45, -0.10, 0, 232, // B
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.location_on_rounded,
                    size: 19,
                    color: FounderSovereignTokens.cyberCyan,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Mapa de serviços (${pts.length})',
                      style: FounderSovereignTokens.titleStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _fitAllPoints,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  foregroundColor: FounderSovereignTokens.primaryInk,
                  side: const BorderSide(
                    color: FounderSovereignTokens.crispBorder,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.my_location_rounded, size: 14),
                label: const Text(
                  'Centralizar',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
                _buildFilterChip('execution', 'Em andamento'),
                const SizedBox(width: 6),
                _buildFilterChip('scheduled', 'Agendados'),
                const SizedBox(width: 6),
                _buildFilterChip('open', 'Aguardando PIX'),
                const SizedBox(width: 6),
                _buildFilterChip('completed', 'Concluídos'),
                const SizedBox(width: 6),
                _buildFilterChip('disputed', 'Em disputa'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FounderPrivacyBlurWrap(
            privacyBlurActive: widget.privacyBlurActive,
            borderRadius: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 256,
                decoration: BoxDecoration(
                  color: FounderSovereignTokens.obsidianBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: FounderSovereignTokens.crispBorder),
                ),
                child: Stack(
                  children: <Widget>[
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _computeInitialCenter(pts),
                        initialZoom: _computeInitialZoom(pts),
                        backgroundColor:
                            FounderSovereignTokens.obsidianBackground,
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
                                  child: _MapPinWidget(
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
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: FounderSovereignTokens.obsidianSurface
                                .withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: FounderSovereignTokens.crispBorder,
                            ),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.map_outlined,
                                color: FounderSovereignTokens.mutedInk,
                                size: 24,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Nenhum serviço no mapa para este filtro',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: FounderSovereignTokens.primaryInk,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Quando um cliente abrir um pedido no Desperrengue, a localização aparecerá aqui em tempo real.',
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
                      right: 8,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: FounderSovereignTokens.obsidianBackground
                              .withValues(alpha: 0.85),
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
          if (selectedPoint != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FounderSovereignTokens.crispBorder),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            selectedPoint.orderCode,
                            style: FounderSovereignTokens.monoMetric(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: FounderSovereignTokens.primaryInk,
                            ),
                          ),
                          _StatusTag(
                            label: founderStatusLabelPt(selectedPoint.status),
                            color: founderStatusColor(selectedPoint.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${selectedPoint.categoryName} · ${selectedPoint.neighborhood.isNotEmpty ? "${selectedPoint.neighborhood}, " : ""}${selectedPoint.city}',
                        style: const TextStyle(
                          color: FounderSovereignTokens.primaryInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cliente: ${selectedPoint.clientName}'
                        '${selectedPoint.providerName != null ? " · Profissional: ${selectedPoint.providerName}" : ""}',
                        style: const TextStyle(
                          color: FounderSovereignTokens.mutedInk,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      AnimatedMoneyOdometer(
                        cents: selectedPoint.amountCents,
                        privacyBlurActive: widget.privacyBlurActive,
                        style: FounderSovereignTokens.monoMetric(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: FounderSovereignTokens.imperialGoldBright,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        key: const ValueKey<String>(
                          'ceo-open-order-details-btn',
                        ),
                        onPressed: () => widget.onInspectOrder(
                          selectedPoint!.jobId,
                          selectedPoint.orderCode,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              FounderSovereignTokens.imperialGoldSoft,
                          foregroundColor:
                              FounderSovereignTokens.imperialGoldBright,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(
                          Icons.receipt_long_rounded,
                          size: 15,
                        ),
                        label: const Text(
                          'Ver pedido',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
        fontSize: 12,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MapPinWidget extends StatelessWidget {
  const _MapPinWidget({
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
            color: color.withValues(alpha: 0.22),
            border: Border.all(
              color: color,
              width: selected ? 2.2 : 1.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: color.withValues(alpha: selected ? 0.50 : 0.24),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
            color: FounderSovereignTokens.crispBorder,
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
      showTopAccentBar: true,
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
                label: _humanEscrowLabelPt(d.escrowStatus),
                color: FounderSovereignTokens.cyberCyan,
              ),
              _StatusTag(
                label: _humanPaymentLabelPt(d.paymentStatus),
                color: FounderSovereignTokens.solvencyEmerald,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${d.category} · ${d.title}',
            style: FounderSovereignTokens.titleStyle(fontSize: 16),
          ),
          if (d.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              d.description,
              style: FounderSovereignTokens.subtitleStyle(),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: <Widget>[
              _MoneyKpiMini(
                label: 'Total combinado',
                cents: d.agreedPriceCents,
                privacyBlurActive: widget.privacyBlurActive,
                color: FounderSovereignTokens.imperialGoldBright,
              ),
              _MoneyKpiMini(
                label: 'Mão de obra',
                cents: d.laborCents,
                privacyBlurActive: widget.privacyBlurActive,
                color: FounderSovereignTokens.primaryInk,
              ),
              _MoneyKpiMini(
                label: 'Peças (sem taxa)',
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
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    steps[i].done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: steps[i].done
                        ? FounderSovereignTokens.solvencyEmerald
                        : FounderSovereignTokens.mutedInk,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
              accent: FounderSovereignTokens.cyberCyan,
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
                  color: FounderSovereignTokens.cyberCyan,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: FounderSovereignTokens.mutedInk,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              label: Text('Data do gasto: $dateStr'),
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
// 4. LISTA DE CLIENTES E PROFISSIONAIS (`ceo_list_real_users_directory`)
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
                _buildRoleChip('client', 'Só clientes'),
                const SizedBox(width: 6),
                _buildRoleChip('provider', 'Profissionais'),
                const SizedBox(width: 6),
                _buildRoleChip('dual', 'Clientes e profissionais'),
                const SizedBox(width: 6),
                _buildRoleChip('kyc_pending', 'Documentos pendentes'),
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
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FounderSovereignTokens.obsidianSurface,
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: FounderSovereignTokens.crispBorder),
                    ),
                    child: Row(
                      children: <Widget>[
                        FounderUltraHdImage(
                          imageUrl: u.avatarUrl,
                          logicalWidth: 42,
                          logicalHeight: 42,
                          borderRadius: 21,
                          fallbackLabel: u.isProvider ? 'PRO' : 'CLI',
                        ),
                        const SizedBox(width: 12),
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
                                      fontSize: 13.5,
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
                                      label: 'Verificado',
                                      color:
                                          FounderSovereignTokens.solvencyEmerald,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${u.city.isNotEmpty ? u.city : "Sem cidade"} · '
                                '${u.clientJobsCount} pedidos · '
                                '${u.jobsDone} atendimentos'
                                '${u.ratingCount > 0 ? " · Nota ${u.ratingAvg.toStringAsFixed(1).replaceAll('.', ',')} ★" : ""}'
                                ' · Desde ${_formatDateBrShort(u.createdAt)}',
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
                                    color: FounderSovereignTokens.cyberCyan,
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
                                  'Na carteira',
                                  style: TextStyle(
                                    color: FounderSovereignTokens.mutedInk,
                                    fontSize: 10,
                                  ),
                                ),
                                AnimatedMoneyOdometer(
                                  cents: u.totalCustodyCents,
                                  privacyBlurActive: widget.privacyBlurActive,
                                  style: FounderSovereignTokens.monoMetric(
                                    fontSize: 12.5,
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
        fontSize: 12,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

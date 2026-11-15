import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/analytics/founder_accountant_pack_service.dart';
import '../../../core/analytics/founder_dashboard_models.dart';
import '../../../core/analytics/founder_dp_optimization_engine.dart';
import '../../../core/utils/money.dart';
import 'founder_animations_and_shaders.dart';

// ============================================================================
// INNOVATION 1: BIVARIATE SUPPLY × DEMAND NEIGHBORHOOD HEATMAP & KNAPSACK BOOSTER
// ============================================================================

class FounderNeighborhoodBivariateHeatmapWidget extends StatefulWidget {
  const FounderNeighborhoodBivariateHeatmapWidget({
    super.key,
    required this.snapshot,
    this.privacyBlurActive = false,
    this.onExecuteStrategicAction,
  });

  final FounderDashboardSnapshot snapshot;
  final bool privacyBlurActive;
  final Future<void> Function(String actionCode, Map<String, dynamic> payload)?
      onExecuteStrategicAction;

  @override
  State<FounderNeighborhoodBivariateHeatmapWidget> createState() =>
      _FounderNeighborhoodBivariateHeatmapWidgetState();
}

class _FounderNeighborhoodBivariateHeatmapWidgetState
    extends State<FounderNeighborhoodBivariateHeatmapWidget> {
  int _selectedCellIdx = 0;
  KnapsackAllocationPlan? _activePlan;
  bool _boosterTriggered = false;

  void _triggerBooster() {
    HapticFeedback.mediumImpact();
    const optimizer = KnapsackGrowthAndBoosterOptimizer();
    final candidates =
        KnapsackGrowthAndBoosterOptimizer.buildCandidatesFromSnapshot(
      widget.snapshot,
    );
    final plan = optimizer.optimize(
      budgetCents: 120000,
      candidates: candidates,
    );
    setState(() {
      _activePlan = plan;
      _boosterTriggered = true;
    });
    widget.onExecuteStrategicAction?.call(
      'TRIGGER_SMART_SUPPLY_BOOSTER',
      <String, dynamic>{
        'budget_cents': plan.budgetCents,
        'allocated_cost_cents': plan.totalCostCents,
        'expected_net_profit_cents': plan.totalExpectedNetProfitCents,
        'selected_actions_count': plan.selectedActions.length,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cells = widget.snapshot.neighborhoodHeatmap;
    final selected = cells.isNotEmpty
        ? cells[_selectedCellIdx.clamp(0, cells.length - 1)]
        : null;

    return FounderGlassCard(
      key: const ValueKey<String>('founder-innovation-1-bivariate-heatmap'),
      accentTopBarColor: FounderSovereignTokens.imperialGold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                'Bairros onde faltam profissionais',
                style: FounderSovereignTokens.titleStyle(fontSize: 16),
              ),
              FilledButton.icon(
                key: const ValueKey<String>('innovation-1-trigger-booster-btn'),
                onPressed: _triggerBooster,
                style: FilledButton.styleFrom(
                  backgroundColor: FounderSovereignTokens.imperialGold,
                  foregroundColor: const Color(0xFF0B0E14),
                  minimumSize: const Size(0, 36),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 16),
                label: const Text(
                  'Simular incentivo nos bairros',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (cells.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FounderSovereignTokens.crispBorder),
              ),
              child: const Text(
                'Ainda não há pedidos suficientes por bairro neste período para sugerir incentivos.',
                style: TextStyle(
                  color: FounderSovereignTokens.mutedInk,
                  fontSize: 12.5,
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List<Widget>.generate(cells.length, (i) {
              final c = cells[i];
              final isSelected = i == _selectedCellIdx;
              final col = c.needsSupplyBooster
                  ? FounderSovereignTokens.crimsonAlert
                  : (c.demandScore >= 75
                      ? FounderSovereignTokens.imperialGoldBright
                      : FounderSovereignTokens.solvencyEmerald);
              return InkWell(
                key: ValueKey<String>('bivariate-cell-${c.neighborhood}'),
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCellIdx = i);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? col.withValues(alpha: 0.22)
                        : FounderSovereignTokens.obsidianSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? col
                          : col.withValues(alpha: 0.45),
                      width: isSelected ? 1.6 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        c.neighborhood,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: FounderSovereignTokens.primaryInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Procura ${c.demandScore} · Profissionais ${c.supplyScore}',
                        style: FounderSovereignTokens.monoMetric(
                          fontSize: 10.5,
                          color: col,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          if (selected != null) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: FounderSovereignTokens.crispBorder),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: <Widget>[
                  Text(
                    '${selected.neighborhood}: ${selected.quadrantLabelPt}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: FounderSovereignTokens.imperialGoldBright,
                    ),
                  ),
                  Text(
                    'Pedidos sem atendimento: ${selected.unmetOrdersCount} · Profissionais ativos: ${selected.activeProvidersCount}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: FounderSovereignTokens.mutedInk,
                    ),
                  ),
                  Text(
                    'Incentivo sugerido: ${widget.privacyBlurActive ? "R\$ •••••" : Money.formatBrl(selected.suggestedBoosterCents)} '
                    '· Retorno estimado: ${widget.privacyBlurActive ? "R\$ •••••" : Money.formatBrl(selected.expectedIncrementalNetCents)}',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 11,
                      color: FounderSovereignTokens.solvencyEmerald,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_boosterTriggered && _activePlan != null) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              key: const ValueKey<String>('innovation-1-knapsack-result'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.solvencyEmeraldSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: FounderSovereignTokens.solvencyEmerald,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Simulação concluída (${_activePlan!.selectedActions.length} bairros priorizados · '
                    'Retorno ${_activePlan!.blendedRoiMultiple.toStringAsFixed(1)}x)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: FounderSovereignTokens.solvencyEmerald,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Investimento: ${Money.formatBrl(_activePlan!.totalCostCents)} · '
                    'Lucro adicional estimado: ${Money.formatBrl(_activePlan!.totalExpectedNetProfitCents)} '
                    '(+${_activePlan!.totalExpectedNewOrders} pedidos)',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 11.5,
                      color: FounderSovereignTokens.primaryInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// INNOVATION 2: FORENSIC PER-ORDER MICRO-P&L INSPECTOR (#DESP-XXXX)
// ============================================================================

class FounderMicroPnlOrderInspectorWidget extends StatefulWidget {
  const FounderMicroPnlOrderInspectorWidget({
    super.key,
    required this.orders,
    this.privacyBlurActive = false,
  });

  final List<OrderMicroPnlRecord> orders;
  final bool privacyBlurActive;

  @override
  State<FounderMicroPnlOrderInspectorWidget> createState() =>
      _FounderMicroPnlOrderInspectorWidgetState();
}

class _FounderMicroPnlOrderInspectorWidgetState
    extends State<FounderMicroPnlOrderInspectorWidget> {
  int _selectedOrderIdx = 0;

  @override
  Widget build(BuildContext context) {
    final list = widget.orders;
    final selected = list.isNotEmpty
        ? list[_selectedOrderIdx.clamp(0, list.length - 1)]
        : null;

    return FounderGlassCard(
      key: const ValueKey<String>('founder-innovation-2-micro-pnl'),
      accentTopBarColor: FounderSovereignTokens.cyberCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Ganho detalhado por pedido',
            style: FounderSovereignTokens.titleStyle(fontSize: 16),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List<Widget>.generate(list.length, (i) {
              final o = list[i];
              final isSelected = i == _selectedOrderIdx;
              final isDuress = o.escrowStatus == 'FROZEN_UNDER_DURESS';
              return InkWell(
                key: ValueKey<String>('micro-pnl-row-${o.orderCode}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedOrderIdx = i);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? FounderSovereignTokens.cyberCyanSoft
                        : FounderSovereignTokens.obsidianSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDuress
                          ? FounderSovereignTokens.crimsonAlert
                          : (isSelected
                              ? FounderSovereignTokens.cyberCyan
                              : FounderSovereignTokens.crispBorder),
                    ),
                  ),
                  child: Text(
                    '${o.orderCode} · ${o.categoryName}',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDuress
                          ? FounderSovereignTokens.crimsonAlert
                          : FounderSovereignTokens.primaryInk,
                    ),
                  ),
                ),
              );
            }),
          ),
          if (selected != null) ...<Widget>[
            const SizedBox(height: 12),
            FounderPrivacyBlurWrap(
              privacyBlurActive: widget.privacyBlurActive,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FounderSovereignTokens.obsidianSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FounderSovereignTokens.crispBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        FounderUltraHdImage(
                          imageUrl: selected.evidencePhotoUrl ??
                              selected.providerAvatarUrl,
                          logicalWidth: 48,
                          logicalHeight: 48,
                          fallbackLabel: selected.orderCode,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${selected.orderCode} · ${selected.categoryName} (${selected.neighborhood})',
                              style: FounderSovereignTokens.monoMetric(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              selected.splitConservationOk
                                  ? 'Divisão de valores 100% conferida'
                                  : 'Atenção na conferência de valores',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: selected.escrowStatus ==
                                        'FROZEN_UNDER_DURESS'
                                    ? FounderSovereignTokens.crimsonAlert
                                    : FounderSovereignTokens.solvencyEmerald,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: <Widget>[
                        _MicroChip(
                          'Total pago',
                          Money.formatBrl(selected.gmvCents),
                          FounderSovereignTokens.imperialGoldBright,
                        ),
                        _MicroChip(
                          'Mão de obra',
                          Money.formatBrl(selected.laborCents),
                          FounderSovereignTokens.primaryInk,
                        ),
                        _MicroChip(
                          'Peças s/ taxa',
                          Money.formatBrl(selected.materialsExemptCents),
                          FounderSovereignTokens.cyberCyan,
                        ),
                        _MicroChip(
                          '85% Profissional',
                          Money.formatBrl(selected.providerNetCents),
                          FounderSovereignTokens.royalIndigo,
                        ),
                        _MicroChip(
                          '13,5% App',
                          Money.formatBrl(selected.platformFeeCents),
                          FounderSovereignTokens.imperialGold,
                        ),
                        _MicroChip(
                          '1,5% Garantia',
                          Money.formatBrl(selected.poolCarveoutCents),
                          FounderSovereignTokens.warmAmber,
                        ),
                        _MicroChip(
                          'Imposto 6%',
                          Money.formatBrl(selected.taxDasCents),
                          FounderSovereignTokens.warmAmber,
                        ),
                        _MicroChip(
                          'Taxas PIX',
                          Money.formatBrl(selected.pixCloudCostCents),
                          FounderSovereignTokens.mutedInk,
                        ),
                        _MicroChip(
                          'Seu lucro',
                          Money.formatBrl(selected.netMarginCents),
                          FounderSovereignTokens.solvencyEmerald,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nota fiscal de peças: ${selected.nfeAccessKey ?? "Sem compra de peças (só mão de obra)"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FounderSovereignTokens.monoMetric(
                        fontSize: 10.5,
                        color: selected.hasValid44DigitNfeKey
                            ? FounderSovereignTokens.solvencyEmerald
                            : FounderSovereignTokens.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// INNOVATION 3: STOCHASTIC MONTE CARLO FINANCIAL TIME-MACHINE (1.000 RUNS)
// ============================================================================

class FounderMonteCarloSimulatorWidget extends StatefulWidget {
  const FounderMonteCarloSimulatorWidget({
    super.key,
    required this.snapshot,
    this.privacyBlurActive = false,
  });

  final FounderDashboardSnapshot snapshot;
  final bool privacyBlurActive;

  @override
  State<FounderMonteCarloSimulatorWidget> createState() =>
      _FounderMonteCarloSimulatorWidgetState();
}

class _FounderMonteCarloSimulatorWidgetState
    extends State<FounderMonteCarloSimulatorWidget> {
  late FounderMonteCarloParams _params;
  late FounderMonteCarloResult _result;

  @override
  void initState() {
    super.initState();
    _params = FounderMonteCarloParams.fromSnapshot(widget.snapshot);
    _result = runMonteCarloSimulationSync(_params);
  }

  Future<void> _updateParams(FounderMonteCarloParams next) async {
    setState(() => _params = next);
    final res = await runMonteCarloSimulationOffThread(next);
    if (mounted) {
      setState(() => _result = res);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FounderGlassCard(
      key: const ValueKey<String>('founder-innovation-3-monte-carlo'),
      accentTopBarColor: FounderSovereignTokens.solvencyEmerald,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                'Simulador de crescimento futuro (12 meses)',
                style: FounderSovereignTokens.titleStyle(fontSize: 16),
              ),
              _MicroChip(
                'Chance de lucro',
                '${_result.breakEvenProbabilityPct.toStringAsFixed(1)}%',
                FounderSovereignTokens.solvencyEmerald,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSliderRow(
            sliderKey: const ValueKey<String>('mc-slider-growth'),
            label:
                'Crescimento mensal de pedidos: ${(_params.monthlyOrderGrowthBps / 100).toStringAsFixed(1)}%',
            value: _params.monthlyOrderGrowthBps.toDouble().clamp(200, 2500),
            min: 200,
            max: 2500,
            onChanged: (v) => _updateParams(
              _params.copyWith(monthlyOrderGrowthBps: v.round()),
            ),
          ),
          _buildSliderRow(
            sliderKey: const ValueKey<String>('mc-slider-cac'),
            label:
                'Custo para atrair 1 cliente: ${Money.formatBrl(_params.cacCents)}',
            value: _params.cacCents.toDouble().clamp(1000, 7000),
            min: 1000,
            max: 7000,
            onChanged: (v) => _updateParams(
              _params.copyWith(cacCents: v.round()),
            ),
          ),
          _buildSliderRow(
            sliderKey: const ValueKey<String>('mc-slider-takerate'),
            label:
                'Comissão média sobre mão de obra: ${(_params.effectiveTakeRateOnLaborBps / 100).toStringAsFixed(1)}%',
            value: _params.effectiveTakeRateOnLaborBps
                .toDouble()
                .clamp(1000, 1800),
            min: 1000,
            max: 1800,
            onChanged: (v) => _updateParams(
              _params.copyWith(effectiveTakeRateOnLaborBps: v.round()),
            ),
          ),
          _buildSliderRow(
            sliderKey: const ValueKey<String>('mc-slider-claims'),
            label:
                'Acionamento de garantia: ${(_params.warrantyClaimRateBps / 100).toStringAsFixed(2)}%',
            value: _params.warrantyClaimRateBps.toDouble().clamp(20, 400),
            min: 20,
            max: 400,
            onChanged: (v) => _updateParams(
              _params.copyWith(warrantyClaimRateBps: v.round()),
            ),
          ),
          const SizedBox(height: 8),
          FounderPrivacyBlurWrap(
            privacyBlurActive: widget.privacyBlurActive,
            child: SizedBox(
              width: double.infinity,
              height: 140,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _MonteCarloFanChartPainter(result: _result),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              _MicroChip(
                'Cenário cauteloso',
                widget.privacyBlurActive
                    ? 'R\$ •••••'
                    : Money.formatBrl(_result.p10CashCents.last),
                _result.p10CashCents.last < 0
                    ? FounderSovereignTokens.crimsonAlert
                    : FounderSovereignTokens.warmAmber,
              ),
              _MicroChip(
                'Cenário provável',
                widget.privacyBlurActive
                    ? 'R\$ •••••'
                    : Money.formatBrl(_result.p50CashCents.last),
                FounderSovereignTokens.imperialGoldBright,
              ),
              _MicroChip(
                'Cenário otimista',
                widget.privacyBlurActive
                    ? 'R\$ •••••'
                    : Money.formatBrl(_result.p90CashCents.last),
                FounderSovereignTokens.solvencyEmerald,
              ),
              _MicroChip(
                'Reserva saudável',
                '${_result.poolSolvencyProbabilityPct.toStringAsFixed(1)}%',
                FounderSovereignTokens.cyberCyan,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required Key sliderKey,
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: FounderSovereignTokens.secondaryInk,
          ),
        ),
        SizedBox(
          height: 28,
          child: Slider(
            key: sliderKey,
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _MonteCarloFanChartPainter extends CustomPainter {
  const _MonteCarloFanChartPainter({required this.result});

  final FounderMonteCarloResult result;

  @override
  void paint(Canvas canvas, Size size) {
    final n = result.p50CashCents.length;
    if (n < 2) return;

    var minVal = result.p10CashCents.first;
    var maxVal = result.p90CashCents.first;
    for (var i = 0; i < n; i++) {
      minVal = math.min(minVal, result.p10CashCents[i]);
      maxVal = math.max(maxVal, result.p90CashCents[i]);
    }
    final span = math.max(1, maxVal - minVal);
    double xAt(int i) => 10 + (i / (n - 1)) * (size.width - 20);
    double yAt(int v) =>
        10 + (size.height - 20) * (1.0 - ((v - minVal) / span).clamp(0.0, 1.0));

    final fanPath = Path();
    for (var i = 0; i < n; i++) {
      final pt = Offset(xAt(i), yAt(result.p90CashCents[i]));
      if (i == 0) {
        fanPath.moveTo(pt.dx, pt.dy);
      } else {
        fanPath.lineTo(pt.dx, pt.dy);
      }
    }
    for (var i = n - 1; i >= 0; i--) {
      fanPath.lineTo(xAt(i), yAt(result.p10CashCents[i]));
    }
    fanPath.close();

    canvas.drawPath(
      fanPath,
      Paint()
        ..color = FounderSovereignTokens.cyberCyan.withValues(alpha: 0.20),
    );

    final p50Path = Path();
    for (var i = 0; i < n; i++) {
      final pt = Offset(xAt(i), yAt(result.p50CashCents[i]));
      if (i == 0) {
        p50Path.moveTo(pt.dx, pt.dy);
      } else {
        p50Path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(
      p50Path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = FounderSovereignTokens.solvencyEmerald,
    );
  }

  @override
  bool shouldRepaint(covariant _MonteCarloFanChartPainter oldDelegate) {
    return oldDelegate.result.terminalMedianCashCents !=
        result.terminalMedianCashCents;
  }
}

// ============================================================================
// INNOVATION 4: EXECUTIVE C-LEVEL COPILOT (AI CFO & COO READ-ONLY)
// ============================================================================

class FounderExecutiveCopilotWidget extends StatefulWidget {
  const FounderExecutiveCopilotWidget({
    super.key,
    required this.snapshot,
  });

  final FounderDashboardSnapshot snapshot;

  @override
  State<FounderExecutiveCopilotWidget> createState() =>
      _FounderExecutiveCopilotWidgetState();
}

class _FounderExecutiveCopilotWidgetState
    extends State<FounderExecutiveCopilotWidget> {
  final TextEditingController _promptController = TextEditingController();
  final FounderExecutiveCopilotEngine _engine =
      const FounderExecutiveCopilotEngine();
  late CopilotBriefingResponse _currentResponse;

  @override
  void initState() {
    super.initState();
    _currentResponse = _engine.answerExecutivePrompt(
      FounderExecutiveCopilotEngine.canonicalQuickQuestions.first,
      widget.snapshot,
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _ask(String question) {
    if (question.trim().isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentResponse = _engine.answerExecutivePrompt(
        question,
        widget.snapshot,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final questions = FounderExecutiveCopilotEngine.canonicalQuickQuestions;

    return FounderGlassCard(
      key: const ValueKey<String>('founder-innovation-4-copilot'),
      accentTopBarColor: FounderSovereignTokens.imperialGoldBright,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Assistente Financeiro do CEO',
            style: FounderSovereignTokens.titleStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List<Widget>.generate(questions.length, (i) {
              return InkWell(
                key: ValueKey<String>('copilot-chip-$i'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => _ask(questions[i]),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: FounderSovereignTokens.obsidianSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: FounderSovereignTokens.imperialGold
                          .withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    questions[i],
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: FounderSovereignTokens.imperialGoldBright,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('copilot-prompt-field'),
                  controller: _promptController,
                  style: FounderSovereignTokens.monoMetric(fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'Pergunte sobre seu lucro, pedidos ou bairros…',
                    isDense: true,
                  ),
                  onSubmitted: _ask,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey<String>('copilot-ask-btn'),
                onPressed: () => _ask(_promptController.text),
                icon: const Icon(
                  Icons.send_rounded,
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FounderSovereignTokens.obsidianSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FounderSovereignTokens.cyberCyan),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _currentResponse.headline,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FounderSovereignTokens.imperialGoldBright,
                  ),
                ),
                const SizedBox(height: 6),
                for (final b in _currentResponse.bulletInsights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $b',
                      style: const TextStyle(
                        fontSize: 12,
                        color: FounderSovereignTokens.primaryInk,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Recomendação Executiva: ${_currentResponse.recommendedAction}',
                  style: const TextStyle(
                    fontSize: 11.5,
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
}

// ============================================================================
// INNOVATION 5: ANTI-BYPASS RADAR (WAGNER-FISCHER DP) & SEFAZ PHASE 2 MONITOR
// ============================================================================

class FounderAntiBypassAndSefazRadarWidget extends StatefulWidget {
  const FounderAntiBypassAndSefazRadarWidget({
    super.key,
    required this.securityWatch,
  });

  final FounderSecurityAndSefazWatch securityWatch;

  @override
  State<FounderAntiBypassAndSefazRadarWidget> createState() =>
      _FounderAntiBypassAndSefazRadarWidgetState();
}

class _FounderAntiBypassAndSefazRadarWidgetState
    extends State<FounderAntiBypassAndSefazRadarWidget> {
  final TextEditingController _phraseController = TextEditingController();
  final AntiBypassAndLeakageDetector _detector =
      const AntiBypassAndLeakageDetector();
  late BypassRiskAssessment _assessment;

  @override
  void initState() {
    super.initState();
    _runDetector('');
  }

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  void _runDetector(String text) {
    final trimmed = text.trim();
    setState(() {
      _assessment = _detector.evaluateRisk(
        chatSnippet: trimmed,
        cancelledWithinMinutesAfterChat: null,
        laborCents: 0,
        materialsExemptCents: 0,
        hasVerified44DigitNfe: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.securityWatch;

    return FounderGlassCard(
      key: const ValueKey<String>('founder-innovation-5-antibypass-sefaz'),
      accentTopBarColor: s.intrusionCanariesCount > 0
          ? FounderSovereignTokens.crimsonAlert
          : FounderSovereignTokens.imperialGold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Notas fiscais de peças e proteção contra desvios',
            style: FounderSovereignTokens.titleStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              _MicroChip(
                'Notas fiscais (>26h)',
                '${s.pendingSefazOver26hCount} pendentes',
                FounderSovereignTokens.warmAmber,
              ),
              _MicroChip(
                'Cancelamentos analisados',
                '${s.canceledClawbackCount}',
                FounderSovereignTokens.cyberCyan,
              ),
              _MicroChip(
                'Endereços protegidos',
                s.geoPrivacyLeakBps == 0 ? '100%' : 'Atenção',
                FounderSovereignTokens.solvencyEmerald,
              ),
              _MicroChip(
                'Acessos indevidos bloqueados',
                '${s.intrusionCanariesCount}',
                s.intrusionCanariesCount > 0
                    ? FounderSovereignTokens.crimsonAlert
                    : FounderSovereignTokens.solvencyEmerald,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey<String>('antibypass-test-field'),
            controller: _phraseController,
            style: const TextStyle(
              fontSize: 12.5,
              color: FounderSovereignTokens.primaryInk,
            ),
            decoration: const InputDecoration(
              labelText: 'Testar frase contra troca de contato fora do app',
              isDense: true,
            ),
            onChanged: _runDetector,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FounderSovereignTokens.obsidianSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _assessment.compositeRiskBps >= 5000
                    ? FounderSovereignTokens.crimsonAlert
                    : FounderSovereignTokens.solvencyEmerald,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${_assessment.severity.labelPt} · Score Composto: ${_assessment.compositeRiskPct.toStringAsFixed(1)}%',
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _assessment.compositeRiskBps >= 5000
                        ? FounderSovereignTokens.crimsonAlert
                        : FounderSovereignTokens.solvencyEmerald,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Texto Desofuscado: "${_assessment.normalizedPreview}"',
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 10.5,
                    color: FounderSovereignTokens.mutedInk,
                  ),
                ),
                for (final flag in _assessment.reasonFlags)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '• $flag',
                      style: const TextStyle(
                        fontSize: 11,
                        color: FounderSovereignTokens.primaryInk,
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
}

// ============================================================================
// INNOVATION 6: 1-CLICK MONTHLY ACCOUNTING-TAX PACK CPC 47 / IFRS 15 EXPORTER
// ============================================================================

class FounderAccountantPackExporterWidget extends StatefulWidget {
  const FounderAccountantPackExporterWidget({
    super.key,
    required this.snapshot,
    this.onExecuteStrategicAction,
  });

  final FounderDashboardSnapshot snapshot;
  final Future<void> Function(String actionCode, Map<String, dynamic> payload)?
      onExecuteStrategicAction;

  @override
  State<FounderAccountantPackExporterWidget> createState() =>
      _FounderAccountantPackExporterWidgetState();
}

class _FounderAccountantPackExporterWidgetState
    extends State<FounderAccountantPackExporterWidget> {
  MonthlyAccountantPackArtifact? _artifact;
  bool _generating = false;

  Future<void> _exportPack() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      HapticFeedback.mediumImpact();
      const service = FounderAccountantPackService();
      final pack = await service.generateMonthlyPackOffThread(widget.snapshot);
      if (mounted) {
        setState(() => _artifact = pack);
      }
      widget.onExecuteStrategicAction?.call(
        'EXPORT_CPC47_ACCOUNTING_PACK',
        <String, dynamic>{
          'competence': pack.competenceLabel,
          'sha256_seal': pack.sha256SealHex,
          'pdf_bytes': pack.pdfBytes.length,
        },
      );
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pack = _artifact;

    return FounderGlassCard(
      key: const ValueKey<String>('founder-innovation-6-accountant-pack'),
      accentTopBarColor: FounderSovereignTokens.solvencyEmerald,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                'Relatório para o Contador (PDF e Planilha)',
                style: FounderSovereignTokens.titleStyle(fontSize: 16),
              ),
              FilledButton.icon(
                key: const ValueKey<String>('export-cpc47-pack-btn'),
                onPressed: _generating ? null : _exportPack,
                style: FilledButton.styleFrom(
                  backgroundColor: FounderSovereignTokens.solvencyEmerald,
                  foregroundColor: const Color(0xFF0B0E14),
                  minimumSize: const Size(0, 38),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: Text(
                  _generating
                      ? 'Preparando documentos…'
                      : 'Baixar fechamento do mês (PDF + Planilha)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Separa automaticamente o que pertence aos profissionais (85% mão de obra + peças) do faturamento do Desperrengue (13,5%), pronto para sua contabilidade.',
            style: FounderSovereignTokens.subtitleStyle(),
          ),
          if (pack != null) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              key: const ValueKey<String>('accountant-pack-seal-box'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: FounderSovereignTokens.solvencyEmerald,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Fechamento ${pack.competenceLabel} pronto · '
                    '${pack.verifyIntegrity() ? "Documento conferido" : "Verifique os dados"}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: FounderSovereignTokens.solvencyEmerald,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Código de verificação: ${pack.sha256SealHex}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 10,
                      color: FounderSovereignTokens.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// INNOVATION 7: SILENT DURESS WAR ROOM (FROZEN_UNDER_DURESS + POLICE DOSSIER)
// ============================================================================

class FounderSilentDuressWarRoomWidget extends StatefulWidget {
  const FounderSilentDuressWarRoomWidget({
    super.key,
    required this.securityWatch,
    this.onExecuteStrategicAction,
  });

  final FounderSecurityAndSefazWatch securityWatch;
  final Future<void> Function(String actionCode, Map<String, dynamic> payload)?
      onExecuteStrategicAction;

  @override
  State<FounderSilentDuressWarRoomWidget> createState() =>
      _FounderSilentDuressWarRoomWidgetState();
}

class _FounderSilentDuressWarRoomWidgetState
    extends State<FounderSilentDuressWarRoomWidget> {
  DuressForensicDossierArtifact? _dossier;
  bool _generating = false;

  Future<void> _generateDossier(DuressIncidentRecord incident) async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      HapticFeedback.heavyImpact();
      const service = FounderAccountantPackService();
      final doc = await service.generateDuressPoliceDossierOffThread(incident);
      if (mounted) {
        setState(() => _dossier = doc);
      }
      widget.onExecuteStrategicAction?.call(
        'GENERATE_DURESS_POLICE_DOSSIER',
        <String, dynamic>{
          'incident_id': doc.incidentId,
          'order_code': doc.orderCode,
          'sha256_seal': doc.sha256SealHex,
        },
      );
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidents = widget.securityWatch.duressIncidents;
    final activeIncident = incidents.isNotEmpty ? incidents.first : null;

    return FounderGlassCard(
      key: const ValueKey<String>('founder-innovation-7-duress-war-room'),
      accentTopBarColor: activeIncident != null
          ? FounderSovereignTokens.crimsonAlert
          : FounderSovereignTokens.solvencyEmerald,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                'Alertas de emergência em atendimentos',
                style: FounderSovereignTokens.titleStyle(
                  fontSize: 16,
                  color: activeIncident != null
                      ? FounderSovereignTokens.crimsonAlert
                      : FounderSovereignTokens.primaryInk,
                ),
              ),
              if (activeIncident != null)
                FilledButton.icon(
                  key: const ValueKey<String>('generate-duress-dossier-btn'),
                  onPressed: _generating
                      ? null
                      : () => _generateDossier(activeIncident),
                  style: FilledButton.styleFrom(
                    backgroundColor: FounderSovereignTokens.crimsonAlert,
                    foregroundColor: const Color(0xFF0B0E14),
                    minimumSize: const Size(0, 36),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  icon: const Icon(Icons.shield_rounded, size: 16),
                  label: Text(
                    _generating
                        ? 'Preparando relatório…'
                        : 'Gerar relatório de ocorrência',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (activeIncident == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.solvencyEmeraldSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: FounderSovereignTokens.solvencyEmerald
                      .withValues(alpha: 0.45),
                ),
              ),
              child: const Text(
                'Tudo tranquilo — nenhum alerta de emergência registrado nos atendimentos.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: FounderSovereignTokens.solvencyEmerald,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.crimsonAlertSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: FounderSovereignTokens.crimsonAlert),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Incidente ${activeIncident.incidentId} · Ordem ${activeIncident.orderCode} · '
                    'Retido: ${Money.formatBrl(activeIncident.frozenAmountCents)}',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: FounderSovereignTokens.primaryInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Tx Bloqueio: ${activeIncident.ledgerFreezeTxId} · Macrozona: ${activeIncident.coarseNeighborhood}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: FounderSovereignTokens.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
          if (_dossier != null) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              key: const ValueKey<String>('duress-dossier-seal-box'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: FounderSovereignTokens.cyberCyan),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Dossiê Pericial ${_dossier!.incidentId} Emitido (${_dossier!.pdfBytes.length} bytes) · '
                    'Integridade: ${_dossier!.verifyIntegrity() ? "ÍNTEGRA" : "FALHA"}',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: FounderSovereignTokens.cyberCyan,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Selo SHA-256: ${_dossier!.sha256SealHex}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 10,
                      color: FounderSovereignTokens.primaryInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MicroChip extends StatelessWidget {
  const _MicroChip(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        '$label: $value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: FounderSovereignTokens.monoMetric(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

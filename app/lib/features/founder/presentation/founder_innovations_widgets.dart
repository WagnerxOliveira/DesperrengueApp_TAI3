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
                'Inovação 1 · Mapa Bivariado Oferta × Demanda & Knapsack Booster',
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              FilledButton.icon(
                key: const ValueKey<String>('innovation-1-trigger-booster-btn'),
                onPressed: _triggerBooster,
                style: FilledButton.styleFrom(
                  backgroundColor: FounderSovereignTokens.imperialGold,
                  foregroundColor: const Color(0xFF111827),
                  minimumSize: const Size(0, 36),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 16),
                label: const Text(
                  'Disparar Smart Supply Booster',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                        style: FounderSovereignTokens.monoMetric(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: FounderSovereignTokens.primaryInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dem ${c.demandScore} × Oferta ${c.supplyScore}',
                        style: FounderSovereignTokens.monoMetric(
                          fontSize: 10,
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
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: FounderSovereignTokens.imperialGoldBright,
                    ),
                  ),
                  Text(
                    'OS reprimidas: ${selected.unmetOrdersCount} · Técnicos: ${selected.activeProvidersCount}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: FounderSovereignTokens.mutedInk,
                    ),
                  ),
                  Text(
                    'Booster Sugerido: ${widget.privacyBlurActive ? "R\$ •••••" : Money.formatBrl(selected.suggestedBoosterCents)} '
                    '-> Retorno Líq.: ${widget.privacyBlurActive ? "R\$ •••••" : Money.formatBrl(selected.expectedIncrementalNetCents)}',
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.solvencyEmeraldSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: FounderSovereignTokens.solvencyEmerald,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Mochila 0/1 Executada (${_activePlan!.selectedActions.length} alavancas ótimas · '
                    'ROI ${_activePlan!.blendedRoiMultiple.toStringAsFixed(2)}x)',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: FounderSovereignTokens.solvencyEmerald,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Custo Alocado: ${Money.formatBrl(_activePlan!.totalCostCents)} -> '
                    'Lucro Incremental: ${Money.formatBrl(_activePlan!.totalExpectedNetProfitCents)} '
                    '(+${_activePlan!.totalExpectedNewOrders} OS)',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 11,
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
            'Inovação 2 · Inspetor Forense Micro-P&L por Ordem (#DESP)',
            style: FounderSovereignTokens.monoMetric(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
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
                              'Status Custódia: ${selected.escrowStatus} · '
                              'Invariante Split: ${selected.splitConservationOk ? "EXATA (0 centavos)" : "ALERTA"}',
                              style: TextStyle(
                                fontSize: 11,
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
                          'GMV Bruto',
                          Money.formatBrl(selected.gmvCents),
                          FounderSovereignTokens.imperialGoldBright,
                        ),
                        _MicroChip(
                          'Mão de Obra',
                          Money.formatBrl(selected.laborCents),
                          FounderSovereignTokens.primaryInk,
                        ),
                        _MicroChip(
                          'Peças 0% Taxa',
                          Money.formatBrl(selected.materialsExemptCents),
                          FounderSovereignTokens.cyberCyan,
                        ),
                        _MicroChip(
                          '85% Técnico',
                          Money.formatBrl(selected.providerNetCents),
                          FounderSovereignTokens.royalIndigo,
                        ),
                        _MicroChip(
                          '13,5% App',
                          Money.formatBrl(selected.platformFeeCents),
                          FounderSovereignTokens.imperialGold,
                        ),
                        _MicroChip(
                          '1,5% Pool',
                          Money.formatBrl(selected.poolCarveoutCents),
                          FounderSovereignTokens.warmAmber,
                        ),
                        _MicroChip(
                          'DAS 6%',
                          Money.formatBrl(selected.taxDasCents),
                          FounderSovereignTokens.crimsonAlert,
                        ),
                        _MicroChip(
                          'PIX/Cloud',
                          Money.formatBrl(selected.pixCloudCostCents),
                          FounderSovereignTokens.mutedInk,
                        ),
                        _MicroChip(
                          'Margem Líq.',
                          Money.formatBrl(selected.netMarginCents),
                          FounderSovereignTokens.solvencyEmerald,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chave NF-e (44 dígitos): ${selected.nfeAccessKey ?? "Sem peças vinculadas (100% Mão de Obra)"}',
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
                'Inovação 3 · Máquina do Tempo Estocástica Monte Carlo (1.000 Trajetórias)',
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _MicroChip(
                'Prob. Break-Even',
                '${_result.breakEvenProbabilityPct.toStringAsFixed(1)}%',
                FounderSovereignTokens.solvencyEmerald,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSliderRow(
            sliderKey: const ValueKey<String>('mc-slider-growth'),
            label:
                'Crescimento OS/mês: ${(_params.monthlyOrderGrowthBps / 100).toStringAsFixed(1)}%',
            value: _params.monthlyOrderGrowthBps.toDouble().clamp(200, 2500),
            min: 200,
            max: 2500,
            onChanged: (v) => _updateParams(
              _params.copyWith(monthlyOrderGrowthBps: v.round()),
            ),
          ),
          _buildSliderRow(
            sliderKey: const ValueKey<String>('mc-slider-cac'),
            label: 'CAC Unitário: ${Money.formatBrl(_params.cacCents)}',
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
                'Take Rate s/ MO: ${(_params.effectiveTakeRateOnLaborBps / 100).toStringAsFixed(1)}%',
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
                'Sinistralidade Pool: ${(_params.warrantyClaimRateBps / 100).toStringAsFixed(2)}%',
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
                'P10 (12m)',
                widget.privacyBlurActive
                    ? 'R\$ •••••'
                    : Money.formatBrl(_result.p10CashCents.last),
                FounderSovereignTokens.crimsonAlert,
              ),
              _MicroChip(
                'P50 Mediana (12m)',
                widget.privacyBlurActive
                    ? 'R\$ •••••'
                    : Money.formatBrl(_result.p50CashCents.last),
                FounderSovereignTokens.imperialGoldBright,
              ),
              _MicroChip(
                'P90 Otimista (12m)',
                widget.privacyBlurActive
                    ? 'R\$ •••••'
                    : Money.formatBrl(_result.p90CashCents.last),
                FounderSovereignTokens.solvencyEmerald,
              ),
              _MicroChip(
                'Solvência Pool ICA>=1,5x',
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
          style: FounderSovereignTokens.monoMetric(
            fontSize: 11,
            color: FounderSovereignTokens.mutedInk,
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
            'Inovação 4 · Copiloto Executivo C-Level (AI CFO & COO Read-Only)',
            style: FounderSovereignTokens.monoMetric(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
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
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 10.5,
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
                    hintText: 'Pergunte ao AI CFO sobre DRE, LTV, SEFAZ ou Booster...',
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
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: FounderSovereignTokens.cyberCyan,
                  ),
                ),
                const SizedBox(height: 6),
                for (final b in _currentResponse.bulletInsights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $b',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: FounderSovereignTokens.primaryInk,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Recomendação Executiva: ${_currentResponse.recommendedAction}',
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 11,
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
  final TextEditingController _phraseController = TextEditingController(
    text: 'm3 ch4m4 n0 z.4.p nove nove oito sete seis cinco quatro tres',
  );
  final AntiBypassAndLeakageDetector _detector =
      const AntiBypassAndLeakageDetector();
  late BypassRiskAssessment _assessment;

  @override
  void initState() {
    super.initState();
    _runDetector(_phraseController.text);
  }

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  void _runDetector(String text) {
    setState(() {
      _assessment = _detector.evaluateRisk(
        chatSnippet: text,
        cancelledWithinMinutesAfterChat: 12,
        laborCents: 3000,
        materialsExemptCents: 27000,
        hasVerified44DigitNfe: false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.securityWatch;

    return FounderGlassCard(
      key: const ValueKey<String>('founder-innovation-5-antibypass-sefaz'),
      accentTopBarColor: FounderSovereignTokens.crimsonAlert,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Inovação 5 · Radar Anti-Bypass (Wagner-Fischer DP) & Monitor SEFAZ (> 26h)',
            style: FounderSovereignTokens.monoMetric(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              _MicroChip(
                'SEFAZ Fase 2 (>26h)',
                '${s.pendingSefazOver26hCount} pendentes',
                FounderSovereignTokens.warmAmber,
              ),
              _MicroChip(
                'Clawbacks Cancelamento',
                '${s.canceledClawbackCount}',
                FounderSovereignTokens.cyberCyan,
              ),
              _MicroChip(
                'Vazamento Geo',
                '${s.geoPrivacyLeakBps} bps (Zero)',
                FounderSovereignTokens.solvencyEmerald,
              ),
              _MicroChip(
                'Canários Intrusão',
                '${s.intrusionCanariesCount}',
                FounderSovereignTokens.crimsonAlert,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey<String>('antibypass-test-field'),
            controller: _phraseController,
            style: FounderSovereignTokens.monoMetric(fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'Simulador Ao Vivo Wagner-Fischer DP (Desofuscação Chat)',
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
                'Inovação 6 · Exportador Contábil-Fiscal CPC 47 / IFRS 15 (1-Clique)',
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              FilledButton.icon(
                key: const ValueKey<String>('export-cpc47-pack-btn'),
                onPressed: _generating ? null : _exportPack,
                style: FilledButton.styleFrom(
                  backgroundColor: FounderSovereignTokens.solvencyEmerald,
                  foregroundColor: const Color(0xFF111827),
                  minimumSize: const Size(0, 36),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: Text(
                  _generating
                      ? 'Gerando %PDF-1.4...'
                      : 'Gerar Pacote Mensal CPC 47 (%PDF-1.4 + CSV)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Segrega juridicamente o GMV Bruto entre Repasse de Terceiros (85% MO + 100% Peças NF-e a 0%) '
            'e Receita Tributável da Plataforma (13,5% Anexo III a 6%), comprovando > 91% de economia legal.',
            style: TextStyle(
              fontSize: 11.5,
              color: FounderSovereignTokens.mutedInk,
            ),
          ),
          if (pack != null) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              key: const ValueKey<String>('accountant-pack-seal-box'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: FounderSovereignTokens.solvencyEmerald,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Pacote Competência ${pack.competenceLabel} · PDF ${pack.pdfBytes.length} bytes · '
                    'Integridade: ${pack.verifyIntegrity() ? "VERIFICADA" : "FALHA"}',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: FounderSovereignTokens.solvencyEmerald,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Selo SHA-256: ${pack.sha256SealHex}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 10,
                      color: FounderSovereignTokens.primaryInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hash PDF: ${pack.pdfSha256Hex}',
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
    final activeIncident = incidents.isNotEmpty
        ? incidents.first
        : DuressIncidentRecord.fromJson(const <String, dynamic>{});

    return FounderGlassCard(
      key: const ValueKey<String>('founder-innovation-7-duress-war-room'),
      accentTopBarColor: FounderSovereignTokens.crimsonAlert,
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
                'Inovação 7 · Sala de Guerra Silent Duress (FROZEN_UNDER_DURESS)',
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: FounderSovereignTokens.crimsonAlert,
                ),
              ),
              FilledButton.icon(
                key: const ValueKey<String>('generate-duress-dossier-btn'),
                onPressed: _generating
                    ? null
                    : () => _generateDossier(activeIncident),
                style: FilledButton.styleFrom(
                  backgroundColor: FounderSovereignTokens.crimsonAlert,
                  foregroundColor: const Color(0xFF111827),
                  minimumSize: const Size(0, 36),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: const Icon(Icons.policy_rounded, size: 16),
                label: Text(
                  _generating
                      ? 'Assinando Dossiê...'
                      : 'Emitir Dossiê Policial Assinado (SHA-256)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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

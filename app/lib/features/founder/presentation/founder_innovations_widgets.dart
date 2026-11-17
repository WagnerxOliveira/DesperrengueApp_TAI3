import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/analytics/founder_accountant_pack_service.dart';
import '../../../core/analytics/founder_dashboard_models.dart';
import '../../../core/analytics/founder_dp_optimization_engine.dart';
import '../../../core/utils/money.dart';
import 'founder_animations_and_shaders.dart';

class _InnovationCardHeader extends StatelessWidget {
  const _InnovationCardHeader({
    required this.glyph,
    required this.title,
    this.iconColor = FounderSovereignTokens.imperialGoldBright,
    this.titleColor = FounderSovereignTokens.primaryInk,
  });

  final FounderIconGlyph glyph;
  final String title;
  final Color iconColor;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FounderPrecisionIcon(
          glyph,
          size: 18,
          color: iconColor,
          accentColor: iconColor,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: FounderSovereignTokens.titleStyle(
              fontSize: 16,
              color: titleColor,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// INNOVATION 1: BIVARIATE SUPPLY × DEMAND NEIGHBORHOOD HEATMAP & BOOSTER
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

  String _fmtBrl(int cents) =>
      widget.privacyBlurActive ? 'R\$ •••••' : Money.formatBrl(cents);

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
              const _InnovationCardHeader(
                glyph: FounderIconGlyph.sparkBolt,
                title: 'Bairros onde faltam profissionais',
                iconColor: FounderSovereignTokens.imperialGoldBright,
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
                icon: const FounderPrecisionIcon(
                  FounderIconGlyph.sparkBolt,
                  size: 15,
                  color: Color(0xFF0B0E14),
                  accentColor: Color(0xFF0B0E14),
                ),
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
                      color: isSelected ? col : col.withValues(alpha: 0.45),
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
                    'Incentivo sugerido: ${_fmtBrl(selected.suggestedBoosterCents)} '
                    '· Retorno estimado: ${_fmtBrl(selected.expectedIncrementalNetCents)}',
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
                    'Investimento: ${_fmtBrl(_activePlan!.totalCostCents)} · '
                    'Lucro adicional estimado: ${_fmtBrl(_activePlan!.totalExpectedNetProfitCents)} '
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

  String _fmtBrl(int cents) =>
      widget.privacyBlurActive ? 'R\$ •••••' : Money.formatBrl(cents);

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
          const _InnovationCardHeader(
            glyph: FounderIconGlyph.moneySplitSankey,
            title: 'Ganho detalhado por pedido',
            iconColor: FounderSovereignTokens.cyberCyan,
          ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FounderSovereignTokens.crispBorder),
              ),
              child: Row(
                children: <Widget>[
                  const FounderPrecisionIcon(
                    FounderIconGlyph.moneySplitSankey,
                    size: 16,
                    color: FounderSovereignTokens.mutedInk,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Assim que houver pedidos concluídos, o ganho detalhado por atendimento aparecerá aqui.',
                      style: FounderSovereignTokens.subtitleStyle(
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...<Widget>[
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
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FounderSovereignTokens.obsidianSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: FounderSovereignTokens.crispBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          FounderUltraHdImage(
                            imageUrl: selected.evidencePhotoUrl ??
                                selected.providerAvatarUrl,
                            logicalWidth: 44,
                            logicalHeight: 44,
                            fallbackLabel: selected.orderCode,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '${selected.orderCode} · ${selected.categoryName} (${selected.neighborhood})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: FounderSovereignTokens.monoMetric(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  selected.splitConservationOk
                                      ? 'Divisão de valores 100% conferida'
                                      : 'Atenção na conferência de valores',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: selected.escrowStatus ==
                                            'FROZEN_UNDER_DURESS'
                                        ? FounderSovereignTokens.crimsonAlert
                                        : FounderSovereignTokens.solvencyEmerald,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Faixa executiva limpa com os 3 indicadores principais
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: FounderSovereignTokens.obsidianCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: FounderSovereignTokens.crispBorder,
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final netColor = selected.netMarginCents < 0
                                ? FounderSovereignTokens.crimsonAlert
                                : FounderSovereignTokens.solvencyEmerald;
                            if (constraints.maxWidth >= 340) {
                              return Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _ExecutiveKpiCell(
                                      label: 'Total pago',
                                      value: _fmtBrl(selected.gmvCents),
                                      valueColor:
                                          FounderSovereignTokens.primaryInk,
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 30,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    color: FounderSovereignTokens.crispBorder,
                                  ),
                                  Expanded(
                                    child: _ExecutiveKpiCell(
                                      label: 'Comissão 13,5%',
                                      value: _fmtBrl(selected.platformFeeCents),
                                      valueColor: FounderSovereignTokens
                                          .imperialGoldBright,
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 30,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    color: FounderSovereignTokens.crispBorder,
                                  ),
                                  Expanded(
                                    child: _ExecutiveKpiCell(
                                      label: 'Seu lucro líquido',
                                      value: _fmtBrl(selected.netMarginCents),
                                      valueColor: netColor,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _QuietBreakdownLine(
                                  label: 'Total pago',
                                  value: _fmtBrl(selected.gmvCents),
                                  valueColor: FounderSovereignTokens.primaryInk,
                                ),
                                const Divider(
                                  height: 12,
                                  thickness: 1,
                                  color: FounderSovereignTokens.crispBorder,
                                ),
                                _QuietBreakdownLine(
                                  label: 'Comissão 13,5%',
                                  value: _fmtBrl(selected.platformFeeCents),
                                  valueColor:
                                      FounderSovereignTokens.imperialGoldBright,
                                ),
                                const Divider(
                                  height: 12,
                                  thickness: 1,
                                  color: FounderSovereignTokens.crispBorder,
                                ),
                                _QuietBreakdownLine(
                                  label: 'Seu lucro líquido',
                                  value: _fmtBrl(selected.netMarginCents),
                                  valueColor: netColor,
                                  emphasize: true,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Detalhamento silencioso com divisores finos
                      _QuietBreakdownLine(
                        label: 'Repasse ao profissional (85% mão de obra)',
                        value: _fmtBrl(selected.providerNetCents),
                      ),
                      const Divider(
                        height: 10,
                        thickness: 1,
                        color: FounderSovereignTokens.crispBorder,
                      ),
                      _QuietBreakdownLine(
                        label: 'Peças reembolsadas (isento de comissão)',
                        value: _fmtBrl(selected.materialsExemptCents),
                      ),
                      const Divider(
                        height: 10,
                        thickness: 1,
                        color: FounderSovereignTokens.crispBorder,
                      ),
                      _QuietBreakdownLine(
                        label: 'Reserva de garantia (1,5%)',
                        value: _fmtBrl(selected.poolCarveoutCents),
                      ),
                      const Divider(
                        height: 10,
                        thickness: 1,
                        color: FounderSovereignTokens.crispBorder,
                      ),
                      _QuietBreakdownLine(
                        label: 'Imposto Simples Nacional (6%)',
                        value: _fmtBrl(selected.taxDasCents),
                      ),
                      const Divider(
                        height: 10,
                        thickness: 1,
                        color: FounderSovereignTokens.crispBorder,
                      ),
                      _QuietBreakdownLine(
                        label: 'Processamento PIX e sistema',
                        value: _fmtBrl(selected.pixCloudCostCents),
                      ),
                      const Divider(
                        height: 12,
                        thickness: 1,
                        color: FounderSovereignTokens.crispBorder,
                      ),
                      Row(
                        children: <Widget>[
                          FounderPrecisionIcon(
                            FounderIconGlyph.nfeBarcode,
                            size: 14,
                            color: selected.hasValid44DigitNfeKey
                                ? FounderSovereignTokens.solvencyEmerald
                                : FounderSovereignTokens.mutedInk,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Nota fiscal de peças: ${selected.nfeAccessKey ?? "Sem compra de peças (só mão de obra)"}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FounderSovereignTokens.monoMetric(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: selected.hasValid44DigitNfeKey
                                    ? FounderSovereignTokens.solvencyEmerald
                                    : FounderSovereignTokens.mutedInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ExecutiveKpiCell extends StatelessWidget {
  const _ExecutiveKpiCell({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: FounderSovereignTokens.mutedInk,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FounderSovereignTokens.monoMetric(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _QuietBreakdownLine extends StatelessWidget {
  const _QuietBreakdownLine({
    required this.label,
    required this.value,
    this.valueColor = FounderSovereignTokens.secondaryInk,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
              color: emphasize
                  ? FounderSovereignTokens.primaryInk
                  : FounderSovereignTokens.mutedInk,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FounderSovereignTokens.monoMetric(
            fontSize: emphasize ? 12.5 : 11.5,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
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

  String _fmtBrl(int cents) =>
      widget.privacyBlurActive ? 'R\$ •••••' : Money.formatBrl(cents);

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
              const _InnovationCardHeader(
                glyph: FounderIconGlyph.monteCarloCone,
                title: 'Simulador de crescimento futuro (12 meses)',
                iconColor: FounderSovereignTokens.solvencyEmerald,
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
            label: 'Custo para atrair 1 cliente: ${_fmtBrl(_params.cacCents)}',
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
            child: Container(
              width: double.infinity,
              height: 144,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FounderSovereignTokens.crispBorder),
              ),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _MonteCarloFanChartPainter(result: _result),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              _MicroChip(
                'Cenário cauteloso',
                _fmtBrl(_result.p10CashCents.last),
                _result.p10CashCents.last < 0
                    ? FounderSovereignTokens.crimsonAlert
                    : FounderSovereignTokens.warmAmber,
              ),
              _MicroChip(
                'Cenário provável',
                _fmtBrl(_result.p50CashCents.last),
                FounderSovereignTokens.imperialGoldBright,
              ),
              _MicroChip(
                'Cenário otimista',
                _fmtBrl(_result.p90CashCents.last),
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
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.0,
              activeTrackColor: FounderSovereignTokens.imperialGold,
              inactiveTrackColor: FounderSovereignTokens.obsidianRaised,
              thumbColor: FounderSovereignTokens.imperialGoldBright,
              overlayColor:
                  FounderSovereignTokens.imperialGold.withValues(alpha: 0.14),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 13.0),
            ),
            child: Slider(
              key: sliderKey,
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
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
    double xAt(int i) => 12 + (i / (n - 1)) * (size.width - 24);
    double yAt(int v) =>
        10 + (size.height - 20) * (1.0 - ((v - minVal) / span).clamp(0.0, 1.0));

    if (minVal <= 0 && maxVal >= 0) {
      final zeroY = yAt(0);
      final zeroPaint = Paint()
        ..color = FounderSovereignTokens.imperialGold.withValues(alpha: 0.35)
        ..strokeWidth = 1.0;
      for (var x = 12.0; x < size.width - 12.0; x += 8.0) {
        canvas.drawLine(
          Offset(x, zeroY),
          Offset(math.min(x + 4.0, size.width - 12.0), zeroY),
          zeroPaint,
        );
      }
    }

    final fanPath = Path();
    final upperEdge = Path();
    final lowerEdge = Path();
    for (var i = 0; i < n; i++) {
      final ptTop = Offset(xAt(i), yAt(result.p90CashCents[i]));
      final ptBot = Offset(xAt(i), yAt(result.p10CashCents[i]));
      if (i == 0) {
        fanPath.moveTo(ptTop.dx, ptTop.dy);
        upperEdge.moveTo(ptTop.dx, ptTop.dy);
        lowerEdge.moveTo(ptBot.dx, ptBot.dy);
      } else {
        fanPath.lineTo(ptTop.dx, ptTop.dy);
        upperEdge.lineTo(ptTop.dx, ptTop.dy);
        lowerEdge.lineTo(ptBot.dx, ptBot.dy);
      }
    }
    for (var i = n - 1; i >= 0; i--) {
      fanPath.lineTo(xAt(i), yAt(result.p10CashCents[i]));
    }
    fanPath.close();

    canvas.drawPath(
      fanPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            FounderSovereignTokens.solvencyEmerald.withValues(alpha: 0.22),
            FounderSovereignTokens.cyberCyan.withValues(alpha: 0.10),
          ],
        ).createShader(Offset.zero & size),
    );

    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = FounderSovereignTokens.cyberCyan.withValues(alpha: 0.42);
    canvas.drawPath(upperEdge, edgePaint);
    canvas.drawPath(lowerEdge, edgePaint);

    final p50Path = Path();
    for (var i = 0; i < n; i++) {
      final pt = Offset(xAt(i), yAt(result.p50CashCents[i]));
      if (i == 0) {
        p50Path.moveTo(pt.dx, pt.dy);
      } else {
        p50Path.lineTo(pt.dx, pt.dy);
      }
    }
    final medianColor = result.p50CashCents.last < 0
        ? FounderSovereignTokens.crimsonAlert
        : FounderSovereignTokens.solvencyEmerald;
    canvas.drawPath(
      p50Path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = medianColor,
    );
    canvas.drawCircle(
      Offset(xAt(n - 1), yAt(result.p50CashCents.last)),
      4.0,
      Paint()..color = medianColor,
    );
  }

  @override
  bool shouldRepaint(covariant _MonteCarloFanChartPainter oldDelegate) {
    return oldDelegate.result.terminalMedianCashCents !=
            result.terminalMedianCashCents ||
        oldDelegate.result.breakEvenProbabilityBps !=
            result.breakEvenProbabilityBps ||
        oldDelegate.result.p10CashCents.last != result.p10CashCents.last ||
        oldDelegate.result.p90CashCents.last != result.p90CashCents.last;
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
          const _InnovationCardHeader(
            glyph: FounderIconGlyph.copilotAiStar,
            title: 'Assistente Financeiro do CEO',
            iconColor: FounderSovereignTokens.imperialGoldBright,
          ),
          const SizedBox(height: 10),
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
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: FounderSovereignTokens.primaryInk,
                    height: 1.35,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Pergunte sobre seu lucro, pedidos ou bairros…',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: FounderSovereignTokens.mutedInk,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: FounderSovereignTokens.obsidianSurface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: FounderSovereignTokens.crispBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: FounderSovereignTokens.imperialGold,
                      ),
                    ),
                  ),
                  onSubmitted: _ask,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey<String>('copilot-ask-btn'),
                onPressed: () => _ask(_promptController.text),
                tooltip: 'Enviar pergunta',
                icon: const FounderPrecisionIcon(
                  FounderIconGlyph.sendVector,
                  size: 18,
                  color: FounderSovereignTokens.imperialGoldBright,
                  accentColor: FounderSovereignTokens.imperialGoldBright,
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
              border: Border.all(
                color: FounderSovereignTokens.cyberCyan.withValues(alpha: 0.55),
              ),
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
// INNOVATION 5: ANTI-BYPASS RADAR & SEFAZ PHASE 2 MONITOR
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
    final hasInput = _phraseController.text.trim().isNotEmpty;
    final riskColor = _assessment.compositeRiskBps >= 5000
        ? FounderSovereignTokens.crimsonAlert
        : (_assessment.compositeRiskBps >= 2000
            ? FounderSovereignTokens.warmAmber
            : FounderSovereignTokens.solvencyEmerald);

    return FounderGlassCard(
      key: const ValueKey<String>('founder-innovation-5-antibypass-sefaz'),
      accentTopBarColor: s.intrusionCanariesCount > 0
          ? FounderSovereignTokens.crimsonAlert
          : FounderSovereignTokens.imperialGold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _InnovationCardHeader(
            glyph: FounderIconGlyph.nfeBarcode,
            title: 'Notas fiscais de peças e proteção contra desvios',
            iconColor: s.intrusionCanariesCount > 0
                ? FounderSovereignTokens.crimsonAlert
                : FounderSovereignTokens.imperialGoldBright,
          ),
          const SizedBox(height: 10),
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
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: FounderSovereignTokens.primaryInk,
            ),
            decoration: InputDecoration(
              labelText: 'Testar frase contra troca de contato fora do app',
              labelStyle: const TextStyle(
                fontSize: 12.5,
                color: FounderSovereignTokens.mutedInk,
              ),
              isDense: true,
              filled: true,
              fillColor: FounderSovereignTokens.obsidianSurface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: FounderSovereignTokens.crispBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: FounderSovereignTokens.imperialGold,
                ),
              ),
            ),
            onChanged: _runDetector,
          ),
          const SizedBox(height: 8),
          if (!hasInput)
            Text(
              'Digite uma frase acima para verificar automaticamente tentativas de contato por fora do aplicativo.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FounderSovereignTokens.subtitleStyle(fontSize: 11.5),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: riskColor.withValues(alpha: 0.65)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${_assessment.severity.labelPt} · Risco identificado: ${_assessment.compositeRiskPct.toStringAsFixed(1).replaceAll(".", ",")}%',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: riskColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Texto analisado: "${_assessment.normalizedPreview}"',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: FounderSovereignTokens.secondaryInk,
                    ),
                  ),
                  for (final flag in _assessment.reasonFlags)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        '• $flag',
                        style: const TextStyle(
                          fontSize: 11.5,
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
// INNOVATION 6: 1-CLICK MONTHLY ACCOUNTING-TAX PACK EXPORTER
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
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const _InnovationCardHeader(
                glyph: FounderIconGlyph.accountingPackPdf,
                title: 'Relatório para o Contador (PDF e Planilha)',
                iconColor: FounderSovereignTokens.solvencyEmerald,
              ),
              FilledButton.icon(
                key: const ValueKey<String>('export-cpc47-pack-btn'),
                onPressed: _generating ? null : _exportPack,
                style: FilledButton.styleFrom(
                  backgroundColor: FounderSovereignTokens.solvencyEmerald,
                  foregroundColor: const Color(0xFF0B0E14),
                  minimumSize: const Size(0, 38),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const FounderPrecisionIcon(
                  FounderIconGlyph.accountingPackPdf,
                  size: 16,
                  color: Color(0xFF0B0E14),
                  accentColor: Color(0xFF0B0E14),
                ),
                label: Text(
                  _generating ? 'Preparando…' : 'Baixar fechamento',
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
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: <Widget>[
                      OutlinedButton.icon(
                        key: const ValueKey<String>('copy-accountant-csv-btn'),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: pack.csvContent),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Planilha CSV copiada para enviar ao contador.',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              FounderSovereignTokens.solvencyEmerald,
                          side: BorderSide(
                            color: FounderSovereignTokens.solvencyEmerald
                                .withValues(alpha: 0.45),
                          ),
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                        icon: const FounderPrecisionIcon(
                          FounderIconGlyph.clipboardOtp,
                          size: 14,
                          color: FounderSovereignTokens.solvencyEmerald,
                          accentColor: FounderSovereignTokens.solvencyEmerald,
                        ),
                        label: const Text(
                          'Copiar planilha CSV',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey<String>('copy-accountant-seal-btn'),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: pack.sha256SealHex),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Selo SHA-256 copiado para a área de transferência.',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FounderSovereignTokens.secondaryInk,
                          side: const BorderSide(
                            color: FounderSovereignTokens.crispBorder,
                          ),
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                        icon: const FounderPrecisionIcon(
                          FounderIconGlyph.clipboardOtp,
                          size: 14,
                          color: FounderSovereignTokens.secondaryInk,
                        ),
                        label: const Text(
                          'Copiar selo SHA-256',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
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
}

// ============================================================================
// INNOVATION 7: SILENT DURESS WAR ROOM (FROZEN_UNDER_DURESS + POLICE DOSSIER)
// ============================================================================

class FounderSilentDuressWarRoomWidget extends StatefulWidget {
  const FounderSilentDuressWarRoomWidget({
    super.key,
    required this.securityWatch,
    this.privacyBlurActive = false,
    this.onExecuteStrategicAction,
  });

  final FounderSecurityAndSefazWatch securityWatch;
  final bool privacyBlurActive;
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
              _InnovationCardHeader(
                glyph: FounderIconGlyph.duressEmergencyShield,
                title: 'Alertas de emergência em atendimentos',
                iconColor: activeIncident != null
                    ? FounderSovereignTokens.crimsonAlert
                    : FounderSovereignTokens.solvencyEmerald,
                titleColor: activeIncident != null
                    ? FounderSovereignTokens.crimsonAlert
                    : FounderSovereignTokens.primaryInk,
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const FounderPrecisionIcon(
                    FounderIconGlyph.duressEmergencyShield,
                    size: 16,
                    color: Color(0xFF0B0E14),
                    accentColor: Color(0xFF0B0E14),
                  ),
                  label: Text(
                    _generating ? 'Preparando…' : 'Gerar dossiê de ocorrência',
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
                    'Retido: ${widget.privacyBlurActive ? "R\$ •••••" : Money.formatBrl(activeIncident.frozenAmountCents)}',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: FounderSovereignTokens.primaryInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Bloqueio preventivo: ${activeIncident.ledgerFreezeTxId} · Região: ${activeIncident.coarseNeighborhood}',
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
                    'Relatório ${_dossier!.incidentId} pronto (${_dossier!.pdfBytes.length} bytes) · '
                    '${_dossier!.verifyIntegrity() ? "Documento conferido" : "Verifique os dados"}',
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: FounderSovereignTokens.cyberCyan,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Código de verificação: ${_dossier!.sha256SealHex}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 10,
                      color: FounderSovereignTokens.primaryInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey<String>('copy-duress-manifest-btn'),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _dossier!.chainOfCustodyJson),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Manifesto de custódia copiado com selo SHA-256.',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FounderSovereignTokens.cyberCyan,
                      side: BorderSide(
                        color: FounderSovereignTokens.cyberCyan
                            .withValues(alpha: 0.45),
                      ),
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    icon: const FounderPrecisionIcon(
                      FounderIconGlyph.clipboardOtp,
                      size: 14,
                      color: FounderSovereignTokens.cyberCyan,
                      accentColor: FounderSovereignTokens.cyberCyan,
                    ),
                    label: const Text(
                      'Copiar dossiê assinado',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
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

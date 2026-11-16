import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/analytics/founder_dashboard_models.dart';
import '../../../core/analytics/founder_dp_optimization_engine.dart';
import '../../../core/utils/money.dart';
import 'founder_animations_and_shaders.dart';

void _paintCanvasLabel(
  Canvas canvas,
  String text,
  Offset position, {
  required TextStyle style,
  double maxWidth = 160,
  int maxLines = 1,
  TextAlign textAlign = TextAlign.center,
  bool centerHorizontally = false,
  bool centerVertically = false,
}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: textAlign,
    maxLines: maxLines,
    ellipsis: '…',
  )..layout(maxWidth: math.max(16, maxWidth));

  final dx = centerHorizontally ? position.dx - tp.width / 2 : position.dx;
  final dy = centerVertically ? position.dy - tp.height / 2 : position.dy;
  tp.paint(canvas, Offset(dx, dy));
}

class _ChartTitleWithIcon extends StatelessWidget {
  const _ChartTitleWithIcon({
    required this.glyph,
    required this.title,
    this.iconColor = FounderSovereignTokens.imperialGoldBright,
  });

  final FounderIconGlyph glyph;
  final String title;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FounderPrecisionIcon(
          glyph,
          size: 17,
          color: iconColor,
          accentColor: iconColor,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: FounderSovereignTokens.titleStyle(fontSize: 15.5),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// CHART 1: SANKEY DIAGRAM (SMART SPLIT MONEY FLOW)
// ============================================================================

class FounderSankeyMoneyFlowChart extends StatefulWidget {
  const FounderSankeyMoneyFlowChart({
    super.key,
    required this.dre,
    required this.animation,
    this.privacyBlurActive = false,
  });

  final FounderDreCents dre;
  final Animation<double> animation;
  final bool privacyBlurActive;

  @override
  State<FounderSankeyMoneyFlowChart> createState() =>
      _FounderSankeyMoneyFlowChartState();
}

class _FounderSankeyMoneyFlowChartState
    extends State<FounderSankeyMoneyFlowChart> {
  int _selectedNodeIndex = 0;

  List<({String label, int cents, Color color, String detail})> _buildNodes() {
    final d = widget.dre;
    return <({String label, int cents, Color color, String detail})>[
      (
        label: 'Total pago nos serviços',
        cents: d.gmvTotalCents,
        color: FounderSovereignTokens.imperialGoldBright,
        detail: 'Soma de tudo que os clientes pagaram (mão de obra + peças)',
      ),
      (
        label: '85% Profissional',
        cents: d.providerNetLaborCents,
        color: FounderSovereignTokens.royalIndigo,
        detail: 'Repasse direto pela mão de obra do profissional',
      ),
      (
        label: '100% Peças (sem taxa)',
        cents: d.materialsExemptCents,
        color: FounderSovereignTokens.cyberCyan,
        detail: 'Reembolso integral das peças com nota fiscal comprovada',
      ),
      (
        label: '13,5% Faturamento do App',
        cents: d.platformGrossRevenueCents,
        color: FounderSovereignTokens.imperialGold,
        detail: 'Comissão do Desperrengue pela intermediação do serviço',
      ),
      (
        label: '1,5% Reserva de garantia',
        cents: d.warrantyPoolCarveoutCents,
        color: FounderSovereignTokens.warmAmber,
        detail: 'Reserva dedicada à garantia de 90 dias dos atendimentos',
      ),
      (
        label: 'Imposto (6%)',
        cents: d.simplesNacionalTaxCents,
        color: FounderSovereignTokens.warmAmber,
        detail:
            'Calculado apenas sobre a comissão do app (economia de ${(d.taxSavingsBps / 100).toStringAsFixed(1)}%)',
      ),
      (
        label: 'Taxas de PIX e sistema',
        cents: d.variablePspAndCloudCents,
        color: FounderSovereignTokens.mutedInk,
        detail: 'Custos operacionais de processamento de PIX e nuvem',
      ),
      (
        label: 'Seu Lucro Líquido',
        cents: d.netProfitEbitdaCents,
        color: d.netProfitEbitdaCents < 0
            ? FounderSovereignTokens.crimsonAlert
            : FounderSovereignTokens.solvencyEmerald,
        detail: 'O que sobra livre no caixa da empresa após impostos e gastos',
      ),
    ];
  }

  void _handlePoint(Offset localPos, Size size) {
    final nodes = _buildNodes();
    final colWidth = size.width / 3;
    int picked = _selectedNodeIndex;
    if (localPos.dx < colWidth) {
      picked = 0;
    } else if (localPos.dx < colWidth * 2) {
      final weights0 = FounderSankeyMoneyFlowPainter.computeStage0Weights(widget.dre);
      final relY = (localPos.dy / math.max(1, size.height)).clamp(0.0, 0.9999);
      var accum = 0.0;
      var band = 3;
      for (var i = 0; i < weights0.length; i++) {
        accum += weights0[i];
        if (relY <= accum) {
          band = i;
          break;
        }
      }
      picked = 1 + band;
    } else {
      final weights1 = FounderSankeyMoneyFlowPainter.computeStage1Weights(widget.dre);
      final relY = (localPos.dy / math.max(1, size.height)).clamp(0.0, 0.9999);
      var accum = 0.0;
      var band = 2;
      for (var j = 0; j < weights1.length; j++) {
        accum += weights1[j];
        if (relY <= accum) {
          band = j;
          break;
        }
      }
      picked = 5 + band;
    }
    if (picked < nodes.length && picked != _selectedNodeIndex) {
      HapticFeedback.selectionClick();
      setState(() => _selectedNodeIndex = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _buildNodes();
    final active = nodes[_selectedNodeIndex.clamp(0, nodes.length - 1)];

    return FounderGlassCard(
      key: const ValueKey<String>('founder-chart-1-sankey'),
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
              const _ChartTitleWithIcon(
                glyph: FounderIconGlyph.moneySplitSankey,
                title: 'Divisão automática do dinheiro',
                iconColor: FounderSovereignTokens.imperialGoldBright,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: FounderSovereignTokens.solvencyEmeraldSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: FounderSovereignTokens.solvencyEmerald.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  'Economia de imposto: ${(widget.dre.taxSavingsBps / 100).toStringAsFixed(1)}%',
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: FounderSovereignTokens.solvencyEmerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FounderPrivacyBlurWrap(
            privacyBlurActive: widget.privacyBlurActive,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize = Size(constraints.maxWidth, 210);
                return MouseRegion(
                  onHover: (e) => _handlePoint(e.localPosition, canvasSize),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _handlePoint(d.localPosition, canvasSize),
                    child: SizedBox(
                      width: canvasSize.width,
                      height: canvasSize.height,
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: widget.animation,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: FounderSankeyMoneyFlowPainter(
                                dre: widget.dre,
                                progress: widget.animation.value.clamp(0.0, 1.0),
                                selectedNodeIndex: _selectedNodeIndex,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FounderSovereignTokens.obsidianSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: active.color.withValues(alpha: 0.45)),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: active.color,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  active.label,
                  style: FounderSovereignTokens.titleStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: active.color,
                  ),
                ),
                AnimatedMoneyOdometer(
                  cents: active.cents,
                  privacyBlurActive: widget.privacyBlurActive,
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  active.detail,
                  style: const TextStyle(
                    fontSize: 11,
                    color: FounderSovereignTokens.mutedInk,
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

typedef FounderSankeyPainter = FounderSankeyMoneyFlowPainter;

class FounderSankeyMoneyFlowPainter extends CustomPainter {
  const FounderSankeyMoneyFlowPainter({
    required this.dre,
    required this.progress,
    required this.selectedNodeIndex,
  });

  final FounderDreCents dre;
  final double progress;
  final int selectedNodeIndex;

  static List<double> _proportionalWeightsWithFloor(
    List<int> centsList, {
    required List<double> fallback,
    double minFloor = 0.12,
  }) {
    final n = centsList.length;
    if (n == 0) return const <double>[];
    final sanitized =
        centsList.map((c) => math.max(0, c).toDouble()).toList(growable: false);
    final total = sanitized.fold<double>(0.0, (acc, v) => acc + v);
    if (total <= 0) return fallback;

    final floor = math.min(minFloor, 1.0 / n);
    final weights = List<double>.filled(n, 0.0);
    final locked = List<bool>.filled(n, false);
    var remainingShare = 1.0;
    var remainingRaw = total;

    while (true) {
      var clampedAny = false;
      if (remainingRaw <= 0) {
        final unlocked = locked.where((flag) => !flag).length;
        if (unlocked > 0) {
          final equalShare = remainingShare / unlocked;
          for (var i = 0; i < n; i++) {
            if (!locked[i]) weights[i] = equalShare;
          }
        }
        break;
      }
      for (var i = 0; i < n; i++) {
        if (locked[i]) continue;
        final share = remainingShare * (sanitized[i] / remainingRaw);
        if (share < floor) {
          weights[i] = floor;
          locked[i] = true;
          remainingShare = math.max(0.0, remainingShare - floor);
          remainingRaw = math.max(0.0, remainingRaw - sanitized[i]);
          clampedAny = true;
        }
      }
      if (!clampedAny) {
        for (var i = 0; i < n; i++) {
          if (!locked[i]) {
            weights[i] = remainingShare * (sanitized[i] / remainingRaw);
          }
        }
        break;
      }
    }
    return weights;
  }

  static List<double> computeStage0Weights(FounderDreCents dre) {
    const fallback = <double>[0.42, 0.22, 0.24, 0.12];
    if (dre.gmvTotalCents <= 0) return fallback;
    return _proportionalWeightsWithFloor(
      <int>[
        dre.providerNetLaborCents,
        dre.materialsExemptCents,
        dre.platformGrossRevenueCents,
        dre.warrantyPoolCarveoutCents,
      ],
      fallback: fallback,
      minFloor: 0.12,
    );
  }

  static List<double> computeStage1Weights(FounderDreCents dre) {
    const fallback = <double>[0.22, 0.16, 0.62];
    if (dre.gmvTotalCents <= 0) return fallback;
    return _proportionalWeightsWithFloor(
      <int>[
        dre.simplesNacionalTaxCents,
        dre.variablePspAndCloudCents,
        math.max(0, dre.netProfitEbitdaCents),
      ],
      fallback: fallback,
      minFloor: 0.12,
    );
  }

  void _drawCubicRibbon(
    Canvas canvas, {
    required Offset startTop,
    required Offset startBottom,
    required Offset endTop,
    required Offset endBottom,
    required Color startColor,
    required Color endColor,
    required double alpha,
  }) {
    final midX = (startTop.dx + endTop.dx) / 2;
    final path = Path()
      ..moveTo(startTop.dx, startTop.dy)
      ..cubicTo(midX, startTop.dy, midX, endTop.dy, endTop.dx, endTop.dy)
      ..lineTo(endBottom.dx, endBottom.dy)
      ..cubicTo(midX, endBottom.dy, midX, startBottom.dy, startBottom.dx, startBottom.dy)
      ..close();

    final rect = Rect.fromPoints(
      Offset(startTop.dx, math.min(startTop.dy, endTop.dy)),
      Offset(endBottom.dx, math.max(startBottom.dy, endBottom.dy)),
    );
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: <Color>[
          startColor.withValues(alpha: alpha),
          endColor.withValues(alpha: alpha),
        ],
      ).createShader(rect);
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.05, 1.0);
    const leftX = 12.0;
    final midX = size.width * 0.44;
    final rightX = size.width - 18.0;
    const nodeW = 10.0;

    const gmvTop = 22.0;
    final gmvBottom = size.height - 22.0;
    final gmvH = (gmvBottom - gmvTop) * p;

    final weights0 = computeStage0Weights(dre);
    final weights1 = computeStage1Weights(dre);

    const midGap = 10.0;
    final midAvailH = math.max(64.0, size.height - 28.0 - midGap * 3);
    final midSpecs = <({String name, int cents, Color color})>[
      (
        name: '85% Prof.',
        cents: dre.providerNetLaborCents,
        color: FounderSovereignTokens.royalIndigo,
      ),
      (
        name: '100% Peças',
        cents: dre.materialsExemptCents,
        color: FounderSovereignTokens.cyberCyan,
      ),
      (
        name: '13,5% App',
        cents: dre.platformGrossRevenueCents,
        color: FounderSovereignTokens.imperialGold,
      ),
      (
        name: '1,5% Gar.',
        cents: dre.warrantyPoolCarveoutCents,
        color: FounderSovereignTokens.warmAmber,
      ),
    ];

    final midTargets = <({String name, int cents, Color color, Rect rect})>[];
    var midY = 14.0;
    for (var i = 0; i < midSpecs.length; i++) {
      final fullH = midAvailH * weights0[i];
      midTargets.add((
        name: midSpecs[i].name,
        cents: midSpecs[i].cents,
        color: midSpecs[i].color,
        rect: Rect.fromLTWH(midX, midY, nodeW, fullH * p),
      ));
      midY += fullH + midGap;
    }

    const rightGap = 14.0;
    final rightAvailH = math.max(54.0, size.height - 44.0 - rightGap * 2);
    final rightSpecs = <({String name, int cents, Color color})>[
      (
        name: 'Imp. 6%',
        cents: dre.simplesNacionalTaxCents,
        color: FounderSovereignTokens.warmAmber,
      ),
      (
        name: 'Taxas PIX',
        cents: dre.variablePspAndCloudCents,
        color: FounderSovereignTokens.mutedInk,
      ),
      (
        name: 'Lucro',
        cents: dre.netProfitEbitdaCents,
        color: dre.netProfitEbitdaCents < 0
            ? FounderSovereignTokens.crimsonAlert
            : FounderSovereignTokens.solvencyEmerald,
      ),
    ];

    final rightTargets = <({String name, int cents, Color color, Rect rect})>[];
    var rightY = 22.0;
    for (var j = 0; j < rightSpecs.length; j++) {
      final fullH = rightAvailH * weights1[j];
      rightTargets.add((
        name: rightSpecs[j].name,
        cents: rightSpecs[j].cents,
        color: rightSpecs[j].color,
        rect: Rect.fromLTWH(rightX, rightY, nodeW, fullH * p),
      ));
      rightY += fullH + rightGap;
    }

    // Ribbons Stage 0 -> Stage 1
    var cursorY = gmvTop;
    for (var i = 0; i < midTargets.length; i++) {
      final sliceH = gmvH * weights0[i];
      final target = midTargets[i];
      _drawCubicRibbon(
        canvas,
        startTop: Offset(leftX + nodeW, cursorY),
        startBottom: Offset(leftX + nodeW, cursorY + sliceH),
        endTop: Offset(target.rect.left, target.rect.top),
        endBottom: Offset(target.rect.left, target.rect.bottom),
        startColor: FounderSovereignTokens.imperialGoldBright,
        endColor: target.color,
        alpha: selectedNodeIndex == (i + 1) ? 0.52 : 0.26,
      );
      cursorY += sliceH;
    }

    // Ribbons Stage 1 (13.5% App) -> Stage 2
    final appNode = midTargets[2].rect;
    var appCursor = appNode.top;
    for (var j = 0; j < rightTargets.length; j++) {
      final sliceH = appNode.height * weights1[j];
      final target = rightTargets[j];
      _drawCubicRibbon(
        canvas,
        startTop: Offset(appNode.right, appCursor),
        startBottom: Offset(appNode.right, appCursor + sliceH),
        endTop: Offset(target.rect.left, target.rect.top),
        endBottom: Offset(target.rect.left, target.rect.bottom),
        startColor: FounderSovereignTokens.imperialGold,
        endColor: target.color,
        alpha: selectedNodeIndex == (5 + j) ? 0.56 : 0.28,
      );
      appCursor += sliceH;
    }

    // Draw nodes + labels
    final gmvRect = Rect.fromLTWH(leftX, gmvTop, nodeW, gmvH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(gmvRect, const Radius.circular(4)),
      Paint()..color = FounderSovereignTokens.imperialGoldBright,
    );
    _paintCanvasLabel(
      canvas,
      'Total',
      Offset(leftX + nodeW + 5, gmvTop + 4),
      style: FounderSovereignTokens.monoMetric(
        fontSize: 10,
        color: FounderSovereignTokens.primaryInk,
      ),
      maxWidth: math.max(36, midX - leftX - 20),
    );

    final midLabelMaxW =
        math.max(30.0, ((rightX - (midX + nodeW)) * 0.50).clamp(30.0, 84.0));
    for (final m in midTargets) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(m.rect, const Radius.circular(4)),
        Paint()..color = m.color,
      );
      _paintCanvasLabel(
        canvas,
        m.name,
        Offset(m.rect.right + 5, m.rect.center.dy),
        style: FounderSovereignTokens.monoMetric(
          fontSize: 9.5,
          color: FounderSovereignTokens.primaryInk,
        ),
        maxWidth: midLabelMaxW,
        centerVertically: true,
      );
    }

    final rightLabelMaxW =
        math.max(30.0, ((rightX - (midX + nodeW)) * 0.46).clamp(30.0, 76.0));
    for (final r in rightTargets) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.rect, const Radius.circular(4)),
        Paint()..color = r.color,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: r.name,
          style: FounderSovereignTokens.monoMetric(
            fontSize: 9.5,
            color: r.color,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: rightLabelMaxW);

      final dx = math.max(midX + nodeW + 8, r.rect.left - tp.width - 6);
      final dy = r.rect.center.dy - tp.height / 2;
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant FounderSankeyMoneyFlowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedNodeIndex != selectedNodeIndex ||
        oldDelegate.dre.gmvTotalCents != dre.gmvTotalCents ||
        oldDelegate.dre.providerNetLaborCents != dre.providerNetLaborCents ||
        oldDelegate.dre.materialsExemptCents != dre.materialsExemptCents ||
        oldDelegate.dre.netProfitEbitdaCents != dre.netProfitEbitdaCents;
  }
}

// ============================================================================
// CHART 2: MONTHLY J-CURVE + BREAK-EVEN LINE (O(1) PREFIX-SUM)
// ============================================================================

class FounderJCurveBreakEvenChart extends StatefulWidget {
  const FounderJCurveBreakEvenChart({
    super.key,
    required this.dailySeries,
    required this.animation,
    this.privacyBlurActive = false,
  });

  final List<FounderDailyMetricPoint> dailySeries;
  final Animation<double> animation;
  final bool privacyBlurActive;

  @override
  State<FounderJCurveBreakEvenChart> createState() =>
      _FounderJCurveBreakEvenChartState();
}

class _FounderJCurveBreakEvenChartState
    extends State<FounderJCurveBreakEvenChart> {
  int _selectedWindowDays = 30;
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final timeline = PrefixSumFinancialTimeline(widget.dailySeries);
    final windowAgg = timeline.queryLastDays(_selectedWindowDays);
    final slice = widget.dailySeries.length <= _selectedWindowDays
        ? widget.dailySeries
        : widget.dailySeries.sublist(
            widget.dailySeries.length - _selectedWindowDays,
          );
    final activePoint = (slice.isNotEmpty && _hoveredIndex != null)
        ? slice[_hoveredIndex!.clamp(0, slice.length - 1)]
        : (slice.isNotEmpty ? slice.last : null);

    return FounderGlassCard(
      key: const ValueKey<String>('founder-chart-2-jcurve'),
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
              const _ChartTitleWithIcon(
                glyph: FounderIconGlyph.profitJCurve,
                title: 'Evolução diária e ponto de equilíbrio',
                iconColor: FounderSovereignTokens.solvencyEmerald,
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: <int>[7, 30, 90, 365].map((days) {
                  final label = days == 365 ? '1 ano' : '${days}d';
                  final selected = _selectedWindowDays == days;
                  return InkWell(
                    key: ValueKey<String>('jcurve-window-${days}d'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedWindowDays = days;
                        _hoveredIndex = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? FounderSovereignTokens.imperialGold
                            : FounderSovereignTokens.obsidianSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? FounderSovereignTokens.imperialGoldBright
                              : FounderSovereignTokens.crispBorder,
                        ),
                      ),
                      child: Text(
                        label,
                        style: FounderSovereignTokens.monoMetric(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? const Color(0xFF111827)
                              : FounderSovereignTokens.primaryInk,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: <Widget>[
              _MetricPill(
                label: 'Serviços no período',
                valueText: '${windowAgg.ordersCount}',
                color: FounderSovereignTokens.cyberCyan,
              ),
              _MetricPill(
                label: 'Total pago',
                valueText: widget.privacyBlurActive
                    ? 'R\$ •••••'
                    : Money.formatBrl(windowAgg.gmvCents),
                color: FounderSovereignTokens.imperialGoldBright,
              ),
              _MetricPill(
                label: 'Seu lucro',
                valueText: widget.privacyBlurActive
                    ? 'R\$ •••••'
                    : Money.formatBrl(windowAgg.netProfitCents),
                color: windowAgg.netProfitCents >= 0
                    ? FounderSovereignTokens.solvencyEmerald
                    : FounderSovereignTokens.crimsonAlert,
              ),
            ],
          ),
          const SizedBox(height: 10),
          FounderPrivacyBlurWrap(
            privacyBlurActive: widget.privacyBlurActive,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize = Size(constraints.maxWidth, 185);
                void updateIdx(Offset pos) {
                  if (slice.isEmpty) return;
                  final idx = ((pos.dx / math.max(1, canvasSize.width)) *
                          slice.length)
                      .floor()
                      .clamp(0, slice.length - 1);
                  if (idx != _hoveredIndex) {
                    HapticFeedback.selectionClick();
                    setState(() => _hoveredIndex = idx);
                  }
                }

                return MouseRegion(
                  onHover: (e) => updateIdx(e.localPosition),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => updateIdx(d.localPosition),
                    child: SizedBox(
                      width: canvasSize.width,
                      height: canvasSize.height,
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: widget.animation,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: FounderJCurvePainter(
                                points: slice,
                                progress: widget.animation.value.clamp(0.0, 1.0),
                                hoveredIndex: _hoveredIndex,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (activePoint != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Dia ${activePoint.dayIso} · ${activePoint.ordersCount} serviços · '
              'Lucro: ${widget.privacyBlurActive ? "R\$ •••••" : Money.formatBrl(activePoint.netProfitCents)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FounderSovereignTokens.monoMetric(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: FounderSovereignTokens.mutedInk,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FounderJCurvePainter extends CustomPainter {
  const FounderJCurvePainter({
    required this.points,
    required this.progress,
    required this.hoveredIndex,
  });

  final List<FounderDailyMetricPoint> points;
  final double progress;
  final int? hoveredIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const padLeft = 10.0;
    const padRight = 10.0;
    const padTop = 18.0;
    const padBottom = 22.0;
    final plotW = math.max(1.0, size.width - padLeft - padRight);
    final plotH = math.max(1.0, size.height - padTop - padBottom);

    // Build cumulative net profit curve (J-curve trajectory)
    final cumulative = <int>[];
    var running = 0;
    var minVal = 0;
    var maxVal = 10000;
    for (final pt in points) {
      running += pt.netProfitCents;
      cumulative.add(running);
      if (running < minVal) minVal = running;
      if (running > maxVal) maxVal = running;
    }
    final span = math.max(1, maxVal - minVal);
    double yFor(int v) =>
        padTop + plotH * (1.0 - ((v - minVal) / span).clamp(0.0, 1.0));

    final zeroY = yFor(0);

    // Draw break-even reference line
    final dashPaint = Paint()
      ..color = FounderSovereignTokens.imperialGold.withValues(alpha: 0.55)
      ..strokeWidth = 1.2;
    for (var x = padLeft; x < size.width - padRight; x += 10) {
      canvas.drawLine(
        Offset(x, zeroY),
        Offset(math.min(x + 5, size.width - padRight), zeroY),
        dashPaint,
      );
    }
    _paintCanvasLabel(
      canvas,
      'Ponto de equilíbrio (R\$ 0,00)',
      Offset(padLeft + 4, math.max(2, zeroY - 14)),
      style: FounderSovereignTokens.monoMetric(
        fontSize: 9.5,
        color: FounderSovereignTokens.imperialGoldBright,
      ),
      maxWidth: plotW - 8,
    );

    final fullPath = Path();
    if (cumulative.length == 1) {
      final y = yFor(cumulative.first);
      fullPath
        ..moveTo(padLeft, y)
        ..lineTo(padLeft + plotW, y);
    } else {
      for (var i = 0; i < cumulative.length; i++) {
        final x = padLeft + (i / (cumulative.length - 1)) * plotW;
        final y = yFor(cumulative[i]);
        if (i == 0) {
          fullPath.moveTo(x, y);
        } else {
          fullPath.lineTo(x, y);
        }
      }
    }

    final p = progress.clamp(0.05, 1.0);
    final extracted = Path();
    for (final metric in fullPath.computeMetrics()) {
      final extractLen = metric.length * p;
      final sub = metric.extractPath(0.0, extractLen);
      extracted.addPath(sub, Offset.zero);

      if (minVal >= 0 && extractLen > 0) {
        final startTan = metric.getTangentForOffset(0.0);
        final endTan = metric.getTangentForOffset(extractLen);
        if (startTan != null && endTan != null) {
          final areaPath = Path.from(sub)
            ..lineTo(endTan.position.dx, zeroY)
            ..lineTo(startTan.position.dx, zeroY)
            ..close();
          final areaPaint = Paint()
            ..style = PaintingStyle.fill
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                FounderSovereignTokens.solvencyEmerald.withValues(alpha: 0.22),
                FounderSovereignTokens.cyberCyan.withValues(alpha: 0.08),
                FounderSovereignTokens.obsidianCard.withValues(alpha: 0.0),
              ],
            ).createShader(Rect.fromLTWH(padLeft, padTop, plotW, plotH));
          canvas.drawPath(areaPath, areaPaint);
        }
      }
    }

    final gradientColors = minVal < 0
        ? const <Color>[
            FounderSovereignTokens.crimsonAlert,
            FounderSovereignTokens.imperialGoldBright,
            FounderSovereignTokens.solvencyEmerald,
          ]
        : const <Color>[
            FounderSovereignTokens.cyberCyan,
            FounderSovereignTokens.imperialGoldBright,
            FounderSovereignTokens.solvencyEmerald,
          ];

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: gradientColors,
      ).createShader(Offset.zero & size);
    canvas.drawPath(extracted, linePaint);

    final activeIdx =
        (hoveredIndex ?? (cumulative.length - 1)).clamp(0, cumulative.length - 1);
    final activeX = padLeft +
        (cumulative.length == 1
            ? plotW / 2
            : (activeIdx / (cumulative.length - 1)) * plotW);
    final activeY = yFor(cumulative[activeIdx]);
    canvas.drawCircle(
      Offset(activeX, activeY),
      4.5,
      Paint()
        ..color = cumulative[activeIdx] < 0
            ? FounderSovereignTokens.crimsonAlert
            : FounderSovereignTokens.solvencyEmerald,
    );
  }

  @override
  bool shouldRepaint(covariant FounderJCurvePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.points.length != points.length;
  }
}

// ============================================================================
// CHART 3: DEMOGRAPHIC VENN DIAGRAM & SCOPED LGPD OFFBOARDING FUNNEL
// ============================================================================

class FounderDemographicsVennChart extends StatefulWidget {
  const FounderDemographicsVennChart({
    super.key,
    required this.demographics,
    required this.animation,
  });

  final FounderDemographicsSummary demographics;
  final Animation<double> animation;

  @override
  State<FounderDemographicsVennChart> createState() =>
      _FounderDemographicsVennChartState();
}

class _FounderDemographicsVennChartState
    extends State<FounderDemographicsVennChart> {
  int _selectedSegment = 2; // 0=Client, 1=Provider, 2=Dual-Mode

  @override
  Widget build(BuildContext context) {
    final d = widget.demographics;
    final segments = <({String title, int count, Color color})>[
      (
        title: 'Só clientes',
        count: d.onlyClientsCount,
        color: FounderSovereignTokens.warmAmber,
      ),
      (
        title: 'Só profissionais',
        count: d.onlyProvidersCount,
        color: FounderSovereignTokens.royalIndigo,
      ),
      (
        title: 'Clientes e profissionais',
        count: d.dualModeBothCount,
        color: FounderSovereignTokens.imperialGoldBright,
      ),
    ];
    final current = segments[_selectedSegment.clamp(0, 2)];

    return FounderGlassCard(
      key: const ValueKey<String>('founder-chart-3-demographics-venn'),
      accentTopBarColor: FounderSovereignTokens.cyberCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const _ChartTitleWithIcon(
                glyph: FounderIconGlyph.dualModeVenn,
                title: 'Perfis de clientes e profissionais',
                iconColor: FounderSovereignTokens.cyberCyan,
              ),
              _MetricPill(
                label: 'Total no app',
                valueText: '${d.totalUsersCount} pessoas',
                color: FounderSovereignTokens.imperialGoldBright,
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = Size(constraints.maxWidth, 165);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final relX = details.localPosition.dx /
                      math.max(1, canvasSize.width);
                  final next = relX < 0.42
                      ? 0
                      : (relX > 0.58 ? 1 : 2);
                  HapticFeedback.selectionClick();
                  setState(() => _selectedSegment = next);
                },
                child: SizedBox(
                  width: canvasSize.width,
                  height: canvasSize.height,
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: widget.animation,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: FounderDemographicsVennPainter(
                            demographics: d,
                            progress: widget.animation.value.clamp(0.0, 1.0),
                            selectedSegment: _selectedSegment,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              _MetricPill(
                label: current.title,
                valueText: '${current.count}',
                color: current.color,
              ),
              _MetricPill(
                label: 'Documentos aprovados',
                valueText: '${d.kycVerifiedCount}',
                color: FounderSovereignTokens.solvencyEmerald,
              ),
              _MetricPill(
                label: 'Contas encerradas',
                valueText: '${d.totalLgpdOffboardings}',
                color: FounderSovereignTokens.crimsonAlert,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FounderDemographicsVennPainter extends CustomPainter {
  const FounderDemographicsVennPainter({
    required this.demographics,
    required this.progress,
    required this.selectedSegment,
  });

  final FounderDemographicsSummary demographics;
  final double progress;
  final int selectedSegment;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.1, 1.0);
    final vennCenterY = size.height * 0.43;
    final r = math.min(size.width * 0.20, size.height * 0.34) * p;
    final leftCenter = Offset(size.width * 0.39, vennCenterY);
    final rightCenter = Offset(size.width * 0.61, vennCenterY);

    // Left circle: Only Clients
    canvas.drawCircle(
      leftCenter,
      r,
      Paint()
        ..color = FounderSovereignTokens.warmAmber.withValues(
          alpha: selectedSegment == 0 ? 0.42 : 0.24,
        ),
    );
    canvas.drawCircle(
      leftCenter,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selectedSegment == 0 ? 2.4 : 1.3
        ..color = FounderSovereignTokens.warmAmber,
    );

    // Right circle: Only Providers
    canvas.drawCircle(
      rightCenter,
      r,
      Paint()
        ..color = FounderSovereignTokens.royalIndigo.withValues(
          alpha: selectedSegment == 1 ? 0.42 : 0.24,
        ),
    );
    canvas.drawCircle(
      rightCenter,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selectedSegment == 1 ? 2.4 : 1.3
        ..color = FounderSovereignTokens.royalIndigo,
    );

    // Dual-Mode Golden Intersection lens highlight
    final midX = (leftCenter.dx + rightCenter.dx) / 2;
    canvas.drawCircle(
      Offset(midX, vennCenterY),
      r * 0.45,
      Paint()
        ..color = FounderSovereignTokens.imperialGoldBright.withValues(
          alpha: selectedSegment == 2 ? 0.48 : 0.28,
        ),
    );

    _paintCanvasLabel(
      canvas,
      'Clientes\n${demographics.onlyClientsCount}',
      Offset(leftCenter.dx - r * 0.44, vennCenterY),
      style: FounderSovereignTokens.monoMetric(
        fontSize: 10,
        color: FounderSovereignTokens.primaryInk,
      ),
      maxWidth: math.max(58.0, r * 1.25),
      maxLines: 2,
      textAlign: TextAlign.center,
      centerHorizontally: true,
      centerVertically: true,
    );
    _paintCanvasLabel(
      canvas,
      'Ambos\n${demographics.dualModeBothCount}',
      Offset(midX, vennCenterY),
      style: FounderSovereignTokens.monoMetric(
        fontSize: 10,
        color: FounderSovereignTokens.imperialGoldBright,
      ),
      maxWidth: math.max(50.0, r * 1.05),
      maxLines: 2,
      textAlign: TextAlign.center,
      centerHorizontally: true,
      centerVertically: true,
    );
    _paintCanvasLabel(
      canvas,
      'Prof.\n${demographics.onlyProvidersCount}',
      Offset(rightCenter.dx + r * 0.44, vennCenterY),
      style: FounderSovereignTokens.monoMetric(
        fontSize: 10,
        color: FounderSovereignTokens.primaryInk,
      ),
      maxWidth: math.max(58.0, r * 1.25),
      maxLines: 2,
      textAlign: TextAlign.center,
      centerHorizontally: true,
      centerVertically: true,
    );

    // Bottom LGPD offboarding bars
    final barY = size.height - 24;
    final barW = (size.width - 24) / 3;
    final bars = <({String label, int val, Color col})>[
      (
        label: 'Saída Cliente: ${demographics.lgpdDeletedClientCount}',
        val: demographics.lgpdDeletedClientCount,
        col: FounderSovereignTokens.warmAmber,
      ),
      (
        label: 'Saída Prof.: ${demographics.lgpdDeletedProviderCount}',
        val: demographics.lgpdDeletedProviderCount,
        col: FounderSovereignTokens.cyberCyan,
      ),
      (
        label: 'Conta Excluída: ${demographics.lgpdDeletedAllCount}',
        val: demographics.lgpdDeletedAllCount,
        col: FounderSovereignTokens.crimsonAlert,
      ),
    ];

    for (var i = 0; i < bars.length; i++) {
      final bx = 12 + i * barW;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, barY, (barW - 8) * p, 16),
          const Radius.circular(4),
        ),
        Paint()..color = bars[i].col.withValues(alpha: 0.25),
      );
      _paintCanvasLabel(
        canvas,
        bars[i].label,
        Offset(bx + 4, barY + 2),
        style: FounderSovereignTokens.monoMetric(
          fontSize: 9,
          color: bars[i].col,
        ),
        maxWidth: barW - 14,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FounderDemographicsVennPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedSegment != selectedSegment ||
        oldDelegate.demographics.totalUsersCount !=
            demographics.totalUsersCount;
  }
}

// ============================================================================
// CHART 4: PIRATE AARRR FUNNEL (LTV/CAC 9,65x)
// ============================================================================

class FounderPirateAarrrFunnelChart extends StatefulWidget {
  const FounderPirateAarrrFunnelChart({
    super.key,
    required this.funnel,
    required this.animation,
  });

  final FounderAarrrFunnelSummary funnel;
  final Animation<double> animation;

  @override
  State<FounderPirateAarrrFunnelChart> createState() =>
      _FounderPirateAarrrFunnelChartState();
}

class _FounderPirateAarrrFunnelChartState
    extends State<FounderPirateAarrrFunnelChart> {
  int _selectedStage = 0;

  @override
  Widget build(BuildContext context) {
    final f = widget.funnel;
    final ratio = (f.ltvToCacRatioBps / 10000).toStringAsFixed(2).replaceAll('.', ',');

    return FounderGlassCard(
      key: const ValueKey<String>('founder-chart-4-aarrr-funnel'),
      accentTopBarColor: FounderSovereignTokens.imperialGoldBright,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const _ChartTitleWithIcon(
                glyph: FounderIconGlyph.userClient,
                title: 'Jornada do cadastro ao serviço recorrente',
                iconColor: FounderSovereignTokens.imperialGoldBright,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: FounderSovereignTokens.imperialGoldGradient,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Retorno $ratio' 'x',
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = Size(constraints.maxWidth, 165);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  final stage = ((d.localPosition.dy /
                              math.max(1, canvasSize.height)) *
                          5)
                      .floor()
                      .clamp(0, 4);
                  HapticFeedback.selectionClick();
                  setState(() => _selectedStage = stage);
                },
                child: SizedBox(
                  width: canvasSize.width,
                  height: canvasSize.height,
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: widget.animation,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: FounderAarrrFunnelPainter(
                            funnel: f,
                            progress: widget.animation.value.clamp(0.0, 1.0),
                            selectedStage: _selectedStage,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class FounderAarrrFunnelPainter extends CustomPainter {
  const FounderAarrrFunnelPainter({
    required this.funnel,
    required this.progress,
    required this.selectedStage,
  });

  final FounderAarrrFunnelSummary funnel;
  final double progress;
  final int selectedStage;

  @override
  void paint(Canvas canvas, Size size) {
    final stages = <({String name, int count, Color color})>[
      (
        name: 'Cadastros',
        count: funnel.acquisitionCount,
        color: FounderSovereignTokens.royalIndigo,
      ),
      (
        name: 'Documentos aprovados',
        count: funnel.activationCount,
        color: FounderSovereignTokens.cyberCyan,
      ),
      (
        name: 'Fizeram pedido',
        count: funnel.retentionCount,
        color: FounderSovereignTokens.solvencyEmerald,
      ),
      (
        name: 'Serviços pagos',
        count: funnel.revenueCount,
        color: FounderSovereignTokens.imperialGold,
      ),
      (
        name: 'Voltaram a pedir',
        count: funnel.referralCount,
        color: FounderSovereignTokens.imperialGoldBright,
      ),
    ];

    final maxCount = math.max(1, stages.first.count);
    final rowH = size.height / stages.length;
    final centerX = size.width / 2;

    for (var i = 0; i < stages.length; i++) {
      final topRatio =
          (stages[i].count / maxCount).clamp(0.22, 1.0) * progress.clamp(0.1, 1.0);
      final bottomRatio = i + 1 < stages.length
          ? (stages[i + 1].count / maxCount).clamp(0.18, 1.0) *
              progress.clamp(0.1, 1.0)
          : topRatio * 0.85;

      final topW = (size.width - 16) * topRatio;
      final bottomW = (size.width - 16) * bottomRatio;
      final topY = i * rowH + 2;
      final bottomY = (i + 1) * rowH - 2;

      final trap = Path()
        ..moveTo(centerX - topW / 2, topY)
        ..lineTo(centerX + topW / 2, topY)
        ..lineTo(centerX + bottomW / 2, bottomY)
        ..lineTo(centerX - bottomW / 2, bottomY)
        ..close();

      canvas.drawPath(
        trap,
        Paint()
          ..color = stages[i].color.withValues(
                alpha: selectedStage == i ? 0.45 : 0.24,
              ),
      );
      canvas.drawPath(
        trap,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selectedStage == i ? 1.8 : 1.0
          ..color = stages[i].color,
      );

      _paintCanvasLabel(
        canvas,
        '${stages[i].name}: ${stages[i].count}',
        Offset(centerX, (topY + bottomY) / 2),
        style: FounderSovereignTokens.monoMetric(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: FounderSovereignTokens.primaryInk,
        ),
        maxWidth: size.width - 28,
        centerHorizontally: true,
        centerVertically: true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FounderAarrrFunnelPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedStage != selectedStage;
  }
}

// ============================================================================
// CHART 5: 33-CATEGORY LIQUIDITY QUADRANT BUBBLE SCATTER
// ============================================================================

class FounderCategoryLiquidityBubbleChart extends StatefulWidget {
  const FounderCategoryLiquidityBubbleChart({
    super.key,
    required this.categories,
    required this.animation,
    this.privacyBlurActive = false,
  });

  final List<CategoryLiquidityPoint> categories;
  final Animation<double> animation;
  final bool privacyBlurActive;

  @override
  State<FounderCategoryLiquidityBubbleChart> createState() =>
      _FounderCategoryLiquidityBubbleChartState();
}

class _FounderCategoryLiquidityBubbleChartState
    extends State<FounderCategoryLiquidityBubbleChart> {
  int _selectedCategoryIdx = 0;

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories;
    final selected = cats.isNotEmpty
        ? cats[_selectedCategoryIdx.clamp(0, cats.length - 1)]
        : null;

    return FounderGlassCard(
      key: const ValueKey<String>('founder-chart-5-category-bubbles'),
      accentTopBarColor: FounderSovereignTokens.royalIndigo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _ChartTitleWithIcon(
                glyph: FounderIconGlyph.sparkBolt,
                title: 'Procura × profissionais nas ${cats.length} profissões',
                iconColor: FounderSovereignTokens.royalIndigo,
              ),
              _MetricPill(
                label: 'Profissões no app',
                valueText: '${cats.length}',
                color: FounderSovereignTokens.cyberCyan,
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = Size(constraints.maxWidth, 190);
              void pickNearest(Offset localPos) {
                if (cats.isEmpty) return;
                final maxSupply = cats.fold<int>(
                  1,
                  (m, c) => math.max(m, c.activeProvidersCount),
                );
                final maxDemand = cats.fold<int>(
                  1,
                  (m, c) => math.max(m, c.demandCount),
                );
                var bestIdx = 0;
                var bestDist = double.infinity;
                for (var i = 0; i < cats.length; i++) {
                  final cx = 18 +
                      (cats[i].activeProvidersCount / maxSupply) *
                          (canvasSize.width - 36);
                  final cy = canvasSize.height -
                      20 -
                      (cats[i].demandCount / maxDemand) *
                          (canvasSize.height - 38);
                  final d = (Offset(cx, cy) - localPos).distance;
                  if (d < bestDist) {
                    bestDist = d;
                    bestIdx = i;
                  }
                }
                if (bestIdx != _selectedCategoryIdx) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCategoryIdx = bestIdx);
                }
              }

              return MouseRegion(
                onHover: (e) => pickNearest(e.localPosition),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => pickNearest(d.localPosition),
                  child: SizedBox(
                    width: canvasSize.width,
                    height: canvasSize.height,
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: widget.animation,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: FounderCategoryBubblePainter(
                              categories: cats,
                              progress: widget.animation.value.clamp(0.0, 1.0),
                              selectedIndex: _selectedCategoryIdx,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (selected != null) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: <Widget>[
                _MetricPill(
                  label: selected.categoryName,
                  valueText:
                      'Demanda ${selected.demandCount} · Oferta ${selected.activeProvidersCount}',
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
                _MetricPill(
                  label: 'Ticket Médio',
                  valueText: widget.privacyBlurActive
                      ? 'R\$ •••••'
                      : Money.formatBrl(selected.avgTicketCents),
                  color: FounderSovereignTokens.solvencyEmerald,
                ),
                _MetricPill(
                  label: 'Conversão',
                  valueText:
                      '${(selected.conversionBps / 100).toStringAsFixed(1)}%',
                  color: FounderSovereignTokens.cyberCyan,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class FounderCategoryBubblePainter extends CustomPainter {
  const FounderCategoryBubblePainter({
    required this.categories,
    required this.progress,
    required this.selectedIndex,
  });

  final List<CategoryLiquidityPoint> categories;
  final double progress;
  final int selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final midX = size.width / 2;
    final midY = size.height / 2;
    final axisPaint = Paint()
      ..color = FounderSovereignTokens.crispBorder
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(12, midY), Offset(size.width - 12, midY), axisPaint);
    canvas.drawLine(Offset(midX, 12), Offset(midX, size.height - 12), axisPaint);

    _paintCanvasLabel(
      canvas,
      'Muita procura / poucos profissionais',
      const Offset(16, 14),
      style: FounderSovereignTokens.monoMetric(
        fontSize: 9,
        color: FounderSovereignTokens.crimsonAlert,
      ),
      maxWidth: midX - 20,
    );
    _paintCanvasLabel(
      canvas,
      'Bom equilíbrio',
      Offset(midX + 6, 14),
      style: FounderSovereignTokens.monoMetric(
        fontSize: 9,
        color: FounderSovereignTokens.solvencyEmerald,
      ),
      maxWidth: midX - 20,
    );

    if (categories.isEmpty) return;
    final maxSupply = categories.fold<int>(
      1,
      (m, c) => math.max(m, c.activeProvidersCount),
    );
    final maxDemand = categories.fold<int>(
      1,
      (m, c) => math.max(m, c.demandCount),
    );
    final maxTicket = categories.fold<int>(
      1,
      (m, c) => math.max(m, c.avgTicketCents),
    );

    for (var i = 0; i < categories.length; i++) {
      final c = categories[i];
      final x = 18 + (c.activeProvidersCount / maxSupply) * (size.width - 36);
      final y =
          size.height - 20 - (c.demandCount / maxDemand) * (size.height - 38);
      final r = (4.5 + (c.avgTicketCents / maxTicket) * 7.5) *
          progress.clamp(0.1, 1.0);
      final isSelected = i == selectedIndex;
      final col = c.demandCount > c.activeProvidersCount * 3
          ? FounderSovereignTokens.crimsonAlert
          : (c.conversionBps >= 6500
              ? FounderSovereignTokens.solvencyEmerald
              : FounderSovereignTokens.cyberCyan);

      canvas.drawCircle(
        Offset(x, y),
        isSelected ? r + 2.5 : r,
        Paint()..color = col.withValues(alpha: isSelected ? 0.85 : 0.45),
      );
      if (isSelected) {
        canvas.drawCircle(
          Offset(x, y),
          r + 4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = FounderSovereignTokens.imperialGoldBright,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant FounderCategoryBubblePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.categories.length != categories.length;
  }
}

// ============================================================================
// CHART 6: TREASURY & ESCROW MATURATION HISTOGRAM (D+0/D+2, D+5, D+7, DURESS)
// ============================================================================

class FounderTreasuryEscrowHistogramChart extends StatefulWidget {
  const FounderTreasuryEscrowHistogramChart({
    super.key,
    required this.treasury,
    required this.animation,
    this.privacyBlurActive = false,
  });

  final FounderTreasurySummary treasury;
  final Animation<double> animation;
  final bool privacyBlurActive;

  @override
  State<FounderTreasuryEscrowHistogramChart> createState() =>
      _FounderTreasuryEscrowHistogramChartState();
}

class _FounderTreasuryEscrowHistogramChartState
    extends State<FounderTreasuryEscrowHistogramChart> {
  int _selectedBar = 0;

  @override
  Widget build(BuildContext context) {
    final t = widget.treasury;
    final buckets = <({String label, int cents, Color color})>[
      (
        label: 'Até 2 dias',
        cents: t.maturationD0D2Cents,
        color: FounderSovereignTokens.solvencyEmerald,
      ),
      (
        label: 'Em 5 dias',
        cents: t.maturationD5Cents,
        color: FounderSovereignTokens.cyberCyan,
      ),
      (
        label: 'Em 7 dias',
        cents: t.maturationD7Cents,
        color: FounderSovereignTokens.royalIndigo,
      ),
      (
        label: 'Em disputa',
        cents: t.frozenMediationCents,
        color: FounderSovereignTokens.warmAmber,
      ),
      (
        label: 'Segurança',
        cents: t.frozenUnderDuressCents,
        color: FounderSovereignTokens.crimsonAlert,
      ),
    ];
    final current = buckets[_selectedBar.clamp(0, buckets.length - 1)];

    return FounderGlassCard(
      key: const ValueKey<String>('founder-chart-6-treasury-histogram'),
      accentTopBarColor: FounderSovereignTokens.cyberCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const _ChartTitleWithIcon(
                glyph: FounderIconGlyph.walletVault,
                title: 'Dinheiro guardado por prazo de liberação',
                iconColor: FounderSovereignTokens.cyberCyan,
              ),
              _MetricPill(
                label: 'Rendimento est. (CDI)',
                valueText: widget.privacyBlurActive
                    ? 'R\$ •••••'
                    : Money.formatBrl(t.estimatedMonthlyCdiFloatCents),
                color: FounderSovereignTokens.imperialGoldBright,
              ),
            ],
          ),
          const SizedBox(height: 10),
          FounderPrivacyBlurWrap(
            privacyBlurActive: widget.privacyBlurActive,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize = Size(constraints.maxWidth, 165);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) {
                    final idx = ((d.localPosition.dx /
                                math.max(1, canvasSize.width)) *
                            buckets.length)
                        .floor()
                        .clamp(0, buckets.length - 1);
                    HapticFeedback.selectionClick();
                    setState(() => _selectedBar = idx);
                  },
                  child: SizedBox(
                    width: canvasSize.width,
                    height: canvasSize.height,
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: widget.animation,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: FounderTreasuryHistogramPainter(
                              buckets: buckets,
                              progress: widget.animation.value.clamp(0.0, 1.0),
                              selectedBar: _selectedBar,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: <Widget>[
              _MetricPill(
                label: current.label,
                valueText: widget.privacyBlurActive
                    ? 'R\$ •••••'
                    : Money.formatBrl(current.cents),
                color: current.color,
              ),
              _MetricPill(
                label: 'Carteiras Disponíveis',
                valueText: widget.privacyBlurActive
                    ? 'R\$ •••••'
                    : Money.formatBrl(t.availableWalletsCents),
                color: FounderSovereignTokens.solvencyEmerald,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FounderTreasuryHistogramPainter extends CustomPainter {
  const FounderTreasuryHistogramPainter({
    required this.buckets,
    required this.progress,
    required this.selectedBar,
  });

  final List<({String label, int cents, Color color})> buckets;
  final double progress;
  final int selectedBar;

  static String _shortBucketAxisLabel(String raw) {
    final normalized = raw.trim();
    final lower = normalized.toLowerCase();
    if (lower.contains('2 dia') || lower.contains('2d')) return 'Até 2d';
    if (lower.contains('5 dia') || lower.contains('5d')) return 'Em 5d';
    if (lower.contains('7 dia') || lower.contains('7d')) return 'Em 7d';
    if (lower.contains('disputa') || lower.contains('media')) return 'Disputa';
    if (lower.contains('seguran')) return 'Segur.';
    if (normalized.length <= 8) return normalized;
    return '${normalized.substring(0, 7).trimRight()}.';
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    final maxCents = buckets.fold<int>(1, (m, b) => math.max(m, b.cents));
    final slotW = size.width / buckets.length;
    final maxBarH = size.height - 38;

    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final ratio = (b.cents / maxCents).clamp(0.08, 1.0);
      final barH = maxBarH * ratio * progress.clamp(0.05, 1.0);
      final barW = math.min(44.0, slotW * 0.62);
      final left = i * slotW + (slotW - barW) / 2;
      final top = size.height - 22 - barH;

      final rrect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, top, barW, barH),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = b.color.withValues(alpha: selectedBar == i ? 0.85 : 0.48),
      );
      _paintCanvasLabel(
        canvas,
        _shortBucketAxisLabel(b.label),
        Offset(i * slotW + slotW / 2, size.height - 16),
        style: FounderSovereignTokens.monoMetric(
          fontSize: 9,
          color: selectedBar == i
              ? b.color
              : FounderSovereignTokens.mutedInk,
        ),
        maxWidth: slotW - 2,
        centerHorizontally: true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FounderTreasuryHistogramPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedBar != selectedBar;
  }
}

// ============================================================================
// CHART 7: ACTUARIAL SPEEDOMETER GAUGE (WARRANTY POOL ICA >= 1,50x)
// ============================================================================

class FounderActuarialSpeedometerChart extends StatelessWidget {
  const FounderActuarialSpeedometerChart({
    super.key,
    required this.pool,
    required this.animation,
    this.privacyBlurActive = false,
  });

  final FounderActuarialPoolSummary pool;
  final Animation<double> animation;
  final bool privacyBlurActive;

  @override
  Widget build(BuildContext context) {
    final icaRatio = (pool.icaRatioBps / 10000).toStringAsFixed(2).replaceAll('.', ',');
    final fcrPct = (pool.fcrLayer1Bps / 100).toStringAsFixed(1).replaceAll('.', ',');

    return FounderGlassCard(
      key: const ValueKey<String>('founder-chart-7-actuarial-speedometer'),
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
              const _ChartTitleWithIcon(
                glyph: FounderIconGlyph.shieldVerified,
                title: 'Saúde da reserva de garantia (90 dias)',
                iconColor: FounderSovereignTokens.solvencyEmerald,
              ),
              _MetricPill(
                label: 'Resolvidos de 1ª',
                valueText: '$fcrPct%',
                color: FounderSovereignTokens.solvencyEmerald,
              ),
            ],
          ),
          const SizedBox(height: 10),
          FounderPrivacyBlurWrap(
            privacyBlurActive: privacyBlurActive,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize = Size(constraints.maxWidth, 165);
                return SizedBox(
                  width: canvasSize.width,
                  height: canvasSize.height,
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: FounderActuarialGaugePainter(
                            icaRatioBps: pool.icaRatioBps,
                            progress: animation.value.clamp(0.0, 1.0),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: <Widget>[
              _MetricPill(
                label: 'Cobertura da reserva',
                valueText: '$icaRatio' 'x (ideal >= 1,50x)',
                color: pool.icaRatioBps >= 15000
                    ? FounderSovereignTokens.solvencyEmerald
                    : FounderSovereignTokens.crimsonAlert,
              ),
              _MetricPill(
                label: 'Saldo da reserva',
                valueText: privacyBlurActive
                    ? 'R\$ •••••'
                    : Money.formatBrl(pool.runningBalanceCents),
                color: FounderSovereignTokens.imperialGoldBright,
              ),
              _MetricPill(
                label: 'Valores recuperados',
                valueText: privacyBlurActive
                    ? 'R\$ •••••'
                    : Money.formatBrl(pool.clawbackRecoveredCents),
                color: FounderSovereignTokens.cyberCyan,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FounderActuarialGaugePainter extends CustomPainter {
  const FounderActuarialGaugePainter({
    required this.icaRatioBps,
    required this.progress,
  });

  final int icaRatioBps;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.78);
    final radius = math.min(size.width * 0.36, size.height * 0.64);
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = math.pi * 0.85;
    const totalSweep = math.pi * 1.3;

    // 3 zones: Crimson (<1.0x), Amber (1.0x..1.5x), Emerald (>=1.5x up to 2.5x)
    final zones = <({double from, double to, Color color})>[
      (from: 0.0, to: 0.40, color: FounderSovereignTokens.crimsonAlert),
      (from: 0.40, to: 0.60, color: FounderSovereignTokens.imperialGold),
      (from: 0.60, to: 1.00, color: FounderSovereignTokens.solvencyEmerald),
    ];

    for (final z in zones) {
      canvas.drawArc(
        rect,
        startAngle + totalSweep * z.from,
        totalSweep * (z.to - z.from) - 0.03,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..color = z.color.withValues(alpha: 0.75),
      );
    }

    // Damped spring needle
    final normalizedIca = (icaRatioBps / 25000).clamp(0.0, 1.0);
    final damped =
        StaggeredEntranceOrchestrator.evaluateDampedSpring(progress) *
            normalizedIca;
    final needleAngle = startAngle + totalSweep * damped.clamp(0.0, 1.0);
    final needleTip = Offset(
      center.dx + (radius - 10) * math.cos(needleAngle),
      center.dy + (radius - 10) * math.sin(needleAngle),
    );

    canvas.drawLine(
      center,
      needleTip,
      Paint()
        ..color = FounderSovereignTokens.imperialGoldBright
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      center,
      6.5,
      Paint()..color = FounderSovereignTokens.primaryInk,
    );

    final icaText =
        '${(icaRatioBps / 10000).toStringAsFixed(2).replaceAll('.', ',')}x';
    _paintCanvasLabel(
      canvas,
      icaText,
      Offset(center.dx, center.dy - radius * 0.42),
      style: FounderSovereignTokens.monoMetric(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: FounderSovereignTokens.solvencyEmerald,
      ),
      maxWidth: radius * 1.6,
      centerHorizontally: true,
      centerVertically: true,
    );
  }

  @override
  bool shouldRepaint(covariant FounderActuarialGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.icaRatioBps != icaRatioBps;
  }
}

// ============================================================================
// CHART 8: MONTHLY COHORT RETENTION HEATMAP
// ============================================================================

class FounderCohortRetentionHeatmapChart extends StatelessWidget {
  const FounderCohortRetentionHeatmapChart({
    super.key,
    required this.cohorts,
    required this.animation,
  });

  final List<CohortRetentionRow> cohorts;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return FounderGlassCard(
      key: const ValueKey<String>('founder-chart-8-cohort-heatmap'),
      accentTopBarColor: FounderSovereignTokens.cyberCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _ChartTitleWithIcon(
            glyph: FounderIconGlyph.calendarExec,
            title: 'Clientes que voltam a pedir nos meses seguintes',
            iconColor: FounderSovereignTokens.cyberCyan,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = Size(constraints.maxWidth, 165);
              return SizedBox(
                width: canvasSize.width,
                height: canvasSize.height,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: FounderCohortHeatmapPainter(
                          cohorts: cohorts,
                          progress: animation.value.clamp(0.0, 1.0),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class FounderCohortHeatmapPainter extends CustomPainter {
  const FounderCohortHeatmapPainter({
    required this.cohorts,
    required this.progress,
  });

  final List<CohortRetentionRow> cohorts;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (cohorts.isEmpty) return;
    final rows = cohorts.take(5).toList();
    final labelColW = math.min(64.0, size.width * 0.24);
    final colsCount = 6;
    final cellW = math.max(16.0, (size.width - labelColW) / colsCount);
    final cellH = math.max(16.0, (size.height - 20) / rows.length);

    for (var c = 0; c < colsCount; c++) {
      _paintCanvasLabel(
        canvas,
        'M$c',
        Offset(labelColW + c * cellW + cellW / 2, 4),
        style: FounderSovereignTokens.monoMetric(
          fontSize: 9,
          color: FounderSovereignTokens.mutedInk,
        ),
        maxWidth: cellW - 2,
        centerHorizontally: true,
      );
    }

    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final top = 20 + r * cellH;
      _paintCanvasLabel(
        canvas,
        row.cohortMonthIso,
        Offset(2, top + cellH / 2),
        style: FounderSovereignTokens.monoMetric(
          fontSize: 9,
          color: FounderSovereignTokens.primaryInk,
        ),
        maxWidth: labelColW - 4,
        centerVertically: true,
      );

      for (var c = 0; c < colsCount && c < row.retentionByMonthBps.length; c++) {
        final bps = row.retentionByMonthBps[c];
        final intensity = ((bps / 10000) * progress).clamp(0.08, 1.0);
        final rect = Rect.fromLTWH(
          labelColW + c * cellW + 2,
          top + 2,
          cellW - 4,
          cellH - 4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()
            ..color = Color.lerp(
              FounderSovereignTokens.obsidianSurface,
              FounderSovereignTokens.solvencyEmerald,
              intensity,
            )!,
        );
        _paintCanvasLabel(
          canvas,
          '${(bps / 100).round()}%',
          rect.center,
          style: FounderSovereignTokens.monoMetric(
            fontSize: 8.5,
            color: FounderSovereignTokens.primaryInk,
          ),
          maxWidth: cellW - 6,
          centerHorizontally: true,
          centerVertically: true,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant FounderCohortHeatmapPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.cohorts.length != cohorts.length;
  }
}

// ============================================================================
// CHART 9: KYC FINOPS THERMOMETER (TIER-0 R$ 0,00 vs ARGON vs CARBON)
// ============================================================================

class FounderKycFinOpsThermometerChart extends StatelessWidget {
  const FounderKycFinOpsThermometerChart({
    super.key,
    required this.kycFinOps,
    required this.animation,
    this.privacyBlurActive = false,
  });

  final FounderKycFinOpsSummary kycFinOps;
  final Animation<double> animation;
  final bool privacyBlurActive;

  @override
  Widget build(BuildContext context) {
    return FounderGlassCard(
      key: const ValueKey<String>('founder-chart-9-kyc-thermometer'),
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
              const _ChartTitleWithIcon(
                glyph: FounderIconGlyph.biometricId,
                title: 'Verificação de documentos e economia',
                iconColor: FounderSovereignTokens.solvencyEmerald,
              ),
              _MetricPill(
                label: 'Economia no sistema',
                valueText: privacyBlurActive
                    ? 'R\$ •••••'
                    : Money.formatBrl(kycFinOps.cloudSavingsCents),
                color: FounderSovereignTokens.solvencyEmerald,
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = Size(constraints.maxWidth, 125);
              return SizedBox(
                width: canvasSize.width,
                height: canvasSize.height,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: FounderKycThermometerPainter(
                          kycFinOps: kycFinOps,
                          progress: animation.value.clamp(0.0, 1.0),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class FounderKycThermometerPainter extends CustomPainter {
  const FounderKycThermometerPainter({
    required this.kycFinOps,
    required this.progress,
  });

  final FounderKycFinOpsSummary kycFinOps;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final total = math.max(
      1,
      kycFinOps.tier0LocalCount +
          kycFinOps.argonCloudCount +
          kycFinOps.carbonSerproCount,
    );
    final rows = <({String label, int count, Color color})>[
      (
        label: 'Validação rápida no celular',
        count: kycFinOps.tier0LocalCount,
        color: FounderSovereignTokens.solvencyEmerald,
      ),
      (
        label: 'Leitura automática de documento',
        count: kycFinOps.argonCloudCount,
        color: FounderSovereignTokens.cyberCyan,
      ),
      (
        label: 'Consulta oficial complementar',
        count: kycFinOps.carbonSerproCount,
        color: FounderSovereignTokens.imperialGold,
      ),
    ];

    final rowH = size.height / rows.length;
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final y = i * rowH + 6;
      final ratio = (r.count / total).clamp(0.06, 1.0) * progress.clamp(0.1, 1.0);
      final barW = (size.width - 16) * ratio;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(8, y + 16, size.width - 16, 12),
          const Radius.circular(6),
        ),
        Paint()..color = FounderSovereignTokens.obsidianSurface,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(8, y + 16, barW, 12),
          const Radius.circular(6),
        ),
        Paint()..color = r.color,
      );
      _paintCanvasLabel(
        canvas,
        '${r.label}: ${r.count} (${((r.count / total) * 100).toStringAsFixed(1)}%)',
        Offset(8, y),
        style: FounderSovereignTokens.monoMetric(
          fontSize: 9.5,
          color: FounderSovereignTokens.primaryInk,
        ),
        maxWidth: size.width - 16,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FounderKycThermometerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.kycFinOps.tier0LocalCount != kycFinOps.tier0LocalCount;
  }
}

// ============================================================================
// CHART 10: 5-STEP TIERED WATERFALL & 112 GAMIFICATION MEDALS (90 PROV + 22 CLIENT)
// ============================================================================

class FounderTieredWaterfallMedalsChart extends StatelessWidget {
  const FounderTieredWaterfallMedalsChart({
    super.key,
    required this.waterfall,
    required this.dre,
    required this.animation,
    this.privacyBlurActive = false,
  });

  final FounderTieredWaterfallSummary waterfall;
  final FounderDreCents dre;
  final Animation<double> animation;
  final bool privacyBlurActive;

  @override
  Widget build(BuildContext context) {
    return FounderGlassCard(
      key: const ValueKey<String>('founder-chart-10-waterfall-medals'),
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
              _ChartTitleWithIcon(
                glyph: FounderIconGlyph.starRating,
                title:
                    'Níveis de comissão e conquistas (${waterfall.totalMedals} medalhas)',
                iconColor: FounderSovereignTokens.imperialGoldBright,
              ),
              _MetricPill(
                label: 'Medalhas',
                valueText: '${waterfall.totalMedals}',
                color: FounderSovereignTokens.imperialGoldBright,
              ),
            ],
          ),
          const SizedBox(height: 10),
          FounderPrivacyBlurWrap(
            privacyBlurActive: privacyBlurActive,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize = Size(constraints.maxWidth, 160);
                return SizedBox(
                  width: canvasSize.width,
                  height: canvasSize.height,
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: FounderWaterfallMedalsPainter(
                            dre: dre,
                            waterfall: waterfall,
                            progress: animation.value.clamp(0.0, 1.0),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FounderWaterfallMedalsPainter extends CustomPainter {
  const FounderWaterfallMedalsPainter({
    required this.dre,
    required this.waterfall,
    required this.progress,
  });

  final FounderDreCents dre;
  final FounderTieredWaterfallSummary waterfall;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final steps = <({String label, int cents, Color color})>[
      (
        label: 'Total pago',
        cents: dre.gmvTotalCents,
        color: FounderSovereignTokens.imperialGoldBright,
      ),
      (
        label: 'Profissional',
        cents: dre.providerNetLaborCents + dre.materialsExemptCents,
        color: FounderSovereignTokens.royalIndigo,
      ),
      (
        label: 'App 13,5%',
        cents: dre.platformGrossRevenueCents,
        color: FounderSovereignTokens.cyberCyan,
      ),
      (
        label: 'Impostos',
        cents: dre.simplesNacionalTaxCents +
            dre.warrantyPoolCarveoutCents +
            dre.variablePspAndCloudCents,
        color: FounderSovereignTokens.warmAmber,
      ),
      (
        label: 'Seu Lucro',
        cents: dre.netProfitEbitdaCents.abs(),
        color: dre.netProfitEbitdaCents < 0
            ? FounderSovereignTokens.crimsonAlert
            : FounderSovereignTokens.solvencyEmerald,
      ),
    ];

    final maxVal = math.max(1, dre.gmvTotalCents);
    final slotW = size.width / steps.length;
    final maxBarH = size.height - 46;

    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      final ratio = (s.cents / maxVal).clamp(0.10, 1.0) * progress.clamp(0.1, 1.0);
      final barH = maxBarH * ratio;
      final barW = math.min(40.0, slotW * 0.6);
      final left = i * slotW + (slotW - barW) / 2;
      final top = size.height - 34 - barH;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barW, barH),
          const Radius.circular(5),
        ),
        Paint()..color = s.color.withValues(alpha: 0.72),
      );
      _paintCanvasLabel(
        canvas,
        s.label,
        Offset(i * slotW + slotW / 2, size.height - 30),
        style: FounderSovereignTokens.monoMetric(
          fontSize: 8.5,
          color: FounderSovereignTokens.primaryInk,
        ),
        maxWidth: slotW - 4,
        centerHorizontally: true,
      );
    }

    // Bottom 112 medals bar (90 Provider + 22 Client)
    final barY = size.height - 14;
    final totalW = (size.width - 16) * progress.clamp(0.1, 1.0);
    final provW = totalW * (waterfall.providerMedalsTotal / 112.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, barY, provW, 10),
        const Radius.circular(4),
      ),
      Paint()..color = FounderSovereignTokens.royalIndigo,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8 + provW + 2, barY, math.max(4, totalW - provW - 2), 10),
        const Radius.circular(4),
      ),
      Paint()..color = FounderSovereignTokens.warmAmber,
    );
  }

  @override
  bool shouldRepaint(covariant FounderWaterfallMedalsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.dre.gmvTotalCents != dre.gmvTotalCents;
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.valueText,
    required this.color,
  });

  final String label;
  final String valueText;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        '$label: $valueText',
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

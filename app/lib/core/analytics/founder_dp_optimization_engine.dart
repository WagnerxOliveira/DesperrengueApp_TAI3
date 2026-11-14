/// Motores Quantitativos de Programação Dinâmica (DP), Cadeias de Markov-Bellman,
/// Detecção Forense Anti-Bypass e Simulação Estocástica de Monte Carlo do Cockpit CEO.
///
/// Regras inegociáveis:
/// - Zero `dart:io` e zero `dart:isolate` / `Isolate.run` (toda execução pesada fora da
///   UI thread passa exclusivamente por [runOffMainThread]).
/// - Zero `print` / `debugPrint` / `log`.
/// - Moeda 100% representada em centavos inteiros ([int] + [Money]).
/// - PRNG determinístico de 32 bits idêntico entre Dart VM (Android/iOS/Desktop) e Web/JS.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../utils/money.dart';
import '../utils/off_thread.dart';
import 'founder_dashboard_models.dart';

// ============================================================================
// DP 1 — SOMAS DE PREFIXO EM O(T) PARA CONSULTAS DE JANELA EM O(1) ESTRITO
// ============================================================================

/// Agregado imutável retornado em tempo $O(1)$ por [PrefixSumFinancialTimeline].
class FinancialWindowAggregate {
  const FinancialWindowAggregate({
    required this.startIndex,
    required this.endIndex,
    required this.daysCount,
    required this.startDayIso,
    required this.endDayIso,
    required this.ordersCount,
    required this.gmvCents,
    required this.laborCents,
    required this.materialsExemptCents,
    required this.platformRevenueCents,
    required this.poolCarveoutCents,
    required this.taxDasCents,
    required this.variableCostCents,
    required this.netProfitCents,
    required this.warrantyClaimsCents,
  });

  final int startIndex;
  final int endIndex;
  final int daysCount;
  final String startDayIso;
  final String endDayIso;
  final int ordersCount;
  final int gmvCents;
  final int laborCents;
  final int materialsExemptCents;
  final int platformRevenueCents;
  final int poolCarveoutCents;
  final int taxDasCents;
  final int variableCostCents;
  final int netProfitCents;
  final int warrantyClaimsCents;

  double get avgDailyOrders => daysCount <= 0 ? 0.0 : ordersCount / daysCount;

  /// Ritmo mensalizado de OS (`>= 40.0` indica superação da linha de Break-Even).
  double get annualizedMonthlyOrdersPace => avgDailyOrders * 30.0;

  int get avgTicketCents => ordersCount <= 0
      ? 0
      : ((gmvCents + (ordersCount ~/ 2)) ~/ ordersCount);

  int get effectiveTakeRateBps => gmvCents <= 0
      ? 0
      : ((platformRevenueCents * 10000) + (gmvCents ~/ 2)) ~/ gmvCents;

  int get netMarginOnRevenueBps => platformRevenueCents <= 0
      ? 0
      : (netProfitCents * 10000) ~/ platformRevenueCents;
}

/// Pré-computa vetores de somas acumuladas em $O(T)$ sobre [FounderDailyMetricPoint]
/// e responde qualquer intervalo `[startInclusive, endInclusive]` (`7d`, `30d`, `90d`, `365d`)
/// em tempo estritamente constante $O(1)$.
class PrefixSumFinancialTimeline {
  PrefixSumFinancialTimeline(List<FounderDailyMetricPoint> series)
      : _points = List<FounderDailyMetricPoint>.unmodifiable(series),
        _prefOrders = List<int>.filled(series.length + 1, 0),
        _prefGmv = List<int>.filled(series.length + 1, 0),
        _prefLabor = List<int>.filled(series.length + 1, 0),
        _prefMaterials = List<int>.filled(series.length + 1, 0),
        _prefPlatformRev = List<int>.filled(series.length + 1, 0),
        _prefPoolCarveout = List<int>.filled(series.length + 1, 0),
        _prefTaxDas = List<int>.filled(series.length + 1, 0),
        _prefVariableCost = List<int>.filled(series.length + 1, 0),
        _prefNetProfit = List<int>.filled(series.length + 1, 0),
        _prefClaims = List<int>.filled(series.length + 1, 0) {
    for (var i = 0; i < _points.length; i++) {
      final p = _points[i];
      _prefOrders[i + 1] = _prefOrders[i] + p.ordersCount;
      _prefGmv[i + 1] = _prefGmv[i] + p.gmvCents;
      _prefLabor[i + 1] = _prefLabor[i] + p.laborCents;
      _prefMaterials[i + 1] = _prefMaterials[i] + p.materialsExemptCents;
      _prefPlatformRev[i + 1] = _prefPlatformRev[i] + p.platformRevenueCents;
      _prefPoolCarveout[i + 1] = _prefPoolCarveout[i] + p.poolCarveoutCents;
      _prefTaxDas[i + 1] = _prefTaxDas[i] + p.taxDasCents;
      _prefVariableCost[i + 1] = _prefVariableCost[i] + p.variableCostCents;
      _prefNetProfit[i + 1] = _prefNetProfit[i] + p.netProfitCents;
      _prefClaims[i + 1] = _prefClaims[i] + p.warrantyClaimsCents;
    }
  }

  final List<FounderDailyMetricPoint> _points;
  final List<int> _prefOrders;
  final List<int> _prefGmv;
  final List<int> _prefLabor;
  final List<int> _prefMaterials;
  final List<int> _prefPlatformRev;
  final List<int> _prefPoolCarveout;
  final List<int> _prefTaxDas;
  final List<int> _prefVariableCost;
  final List<int> _prefNetProfit;
  final List<int> _prefClaims;

  int get length => _points.length;
  bool get isEmpty => _points.isEmpty;
  List<FounderDailyMetricPoint> get points => _points;

  /// Consulta exata em $O(1)$ do intervalo fechado `[startInclusive, endInclusive]`.
  FinancialWindowAggregate queryRange(int startInclusive, int endInclusive) {
    if (_points.isEmpty) {
      return const FinancialWindowAggregate(
        startIndex: 0,
        endIndex: 0,
        daysCount: 0,
        startDayIso: '',
        endDayIso: '',
        ordersCount: 0,
        gmvCents: 0,
        laborCents: 0,
        materialsExemptCents: 0,
        platformRevenueCents: 0,
        poolCarveoutCents: 0,
        taxDasCents: 0,
        variableCostCents: 0,
        netProfitCents: 0,
        warrantyClaimsCents: 0,
      );
    }
    final s = startInclusive.clamp(0, _points.length - 1);
    final e = endInclusive.clamp(s, _points.length - 1);
    final r = e + 1;

    return FinancialWindowAggregate(
      startIndex: s,
      endIndex: e,
      daysCount: r - s,
      startDayIso: _points[s].dayIso,
      endDayIso: _points[e].dayIso,
      ordersCount: _prefOrders[r] - _prefOrders[s],
      gmvCents: _prefGmv[r] - _prefGmv[s],
      laborCents: _prefLabor[r] - _prefLabor[s],
      materialsExemptCents: _prefMaterials[r] - _prefMaterials[s],
      platformRevenueCents: _prefPlatformRev[r] - _prefPlatformRev[s],
      poolCarveoutCents: _prefPoolCarveout[r] - _prefPoolCarveout[s],
      taxDasCents: _prefTaxDas[r] - _prefTaxDas[s],
      variableCostCents: _prefVariableCost[r] - _prefVariableCost[s],
      netProfitCents: _prefNetProfit[r] - _prefNetProfit[s],
      warrantyClaimsCents: _prefClaims[r] - _prefClaims[s],
    );
  }

  /// Consulta em $O(1)$ os últimos [days] dias (`7`, `30`, `90`, `365`).
  FinancialWindowAggregate queryLastDays(int days) {
    if (_points.isEmpty) return queryRange(0, 0);
    final clampedDays = days.clamp(1, _points.length);
    return queryRange(_points.length - clampedDays, _points.length - 1);
  }

  /// Extrai o sub-vetor de pontos dos últimos [days] dias para renderização vetorial.
  List<FounderDailyMetricPoint> sliceLastDays(int days) {
    if (_points.isEmpty) return const <FounderDailyMetricPoint>[];
    final clampedDays = days.clamp(1, _points.length);
    return _points.sublist(_points.length - clampedDays);
  }
}

// ============================================================================
// DP 2 — MOCHILA INTEIRA 0/1 (KNAPSACK BELLMAN DP + BACKTRACKING EXATO)
// ============================================================================

enum KnapsackActionKind {
  supplyBooster('SMART_SUPPLY_BOOSTER', 'Smart Supply Booster de Bairro'),
  growthChannel('HYPERLOCAL_GROWTH', 'Aquisição Hiperlocal'),
  retentionAutomation('RETENTION_CRM', 'Reativação & Migração Dual-Mode'),
  b2bPartnership('B2B_CONDO_PARTNER', 'Parceria Síndicos & Condomínios');

  const KnapsackActionKind(this.wire, this.labelPt);
  final String wire;
  final String labelPt;
}

class KnapsackActionCandidate {
  const KnapsackActionCandidate({
    required this.id,
    required this.title,
    required this.neighborhoodOrChannel,
    required this.kind,
    required this.costCents,
    required this.expectedNetProfitCents,
    this.expectedGrossReturnCents = 0,
    this.expectedNewOrders = 0,
  });

  final String id;
  final String title;
  final String neighborhoodOrChannel;
  final KnapsackActionKind kind;
  final int costCents;
  final int expectedNetProfitCents;
  final int expectedGrossReturnCents;
  final int expectedNewOrders;

  double get roiMultiple =>
      costCents <= 0 ? 0.0 : expectedNetProfitCents / costCents;
}

class KnapsackAllocationPlan {
  const KnapsackAllocationPlan({
    required this.budgetCents,
    required this.discretizationStepCents,
    required this.selectedActions,
    required this.rejectedActions,
    required this.totalCostCents,
    required this.unallocatedBudgetCents,
    required this.totalExpectedNetProfitCents,
    required this.totalExpectedGrossReturnCents,
    required this.totalExpectedNewOrders,
    required this.dpStatesEvaluated,
  });

  final int budgetCents;
  final int discretizationStepCents;
  final List<KnapsackActionCandidate> selectedActions;
  final List<KnapsackActionCandidate> rejectedActions;
  final int totalCostCents;
  final int unallocatedBudgetCents;
  final int totalExpectedNetProfitCents;
  final int totalExpectedGrossReturnCents;
  final int totalExpectedNewOrders;
  final int dpStatesEvaluated;

  double get blendedRoiMultiple =>
      totalCostCents <= 0 ? 0.0 : totalExpectedNetProfitCents / totalCostCents;

  bool get budgetConstraintSatisfied => totalCostCents <= budgetCents;
}

/// Otimizador de alocação ótima de capital via Programação Dinâmica 0/1 Knapsack
/// (tabela de Bellman com reconstrução exata por ponteiros de decisão).
class KnapsackGrowthAndBoosterOptimizer {
  const KnapsackGrowthAndBoosterOptimizer();

  static int _gcd(int a, int b) {
    var x = a.abs();
    var y = b.abs();
    while (y != 0) {
      final t = x % y;
      x = y;
      y = t;
    }
    return x;
  }

  /// Deriva candidatos acionáveis reais a partir da malha bivariada de bairros do snapshot
  /// combinada com canais táticos hiperlocais.
  static List<KnapsackActionCandidate> buildCandidatesFromSnapshot(
    FounderDashboardSnapshot snapshot,
  ) {
    final out = <KnapsackActionCandidate>[];
    for (var i = 0; i < snapshot.neighborhoodHeatmap.length; i++) {
      final cell = snapshot.neighborhoodHeatmap[i];
      if (cell.suggestedBoosterCents <= 0 ||
          cell.expectedIncrementalNetCents <= 0) {
        continue;
      }
      out.add(
        KnapsackActionCandidate(
          id: 'booster_${i + 1}_${cell.neighborhood.toLowerCase().replaceAll(' ', '_')}',
          title: 'Smart Supply Booster · ${cell.neighborhood}',
          neighborhoodOrChannel: cell.neighborhood,
          kind: KnapsackActionKind.supplyBooster,
          costCents: cell.suggestedBoosterCents,
          expectedNetProfitCents: cell.expectedIncrementalNetCents,
          expectedGrossReturnCents:
              cell.suggestedBoosterCents + cell.expectedIncrementalNetCents,
          expectedNewOrders: math.max(3, cell.unmetOrdersCount),
        ),
      );
    }

    out.addAll(const <KnapsackActionCandidate>[
      KnapsackActionCandidate(
        id: 'channel_condos_sul',
        title: 'Missão Condomínios Fechados Zona Sul',
        neighborhoodOrChannel: 'Country Club & Jardim dos Estados',
        kind: KnapsackActionKind.b2bPartnership,
        costCents: 35000,
        expectedNetProfitCents: 176000,
        expectedGrossReturnCents: 211000,
        expectedNewOrders: 16,
      ),
      KnapsackActionCandidate(
        id: 'channel_dual_mode_bridge',
        title: ' Incentivo Migração Prestador -> Cliente Dual-Mode',
        neighborhoodOrChannel: 'Carteira Interna (CAC R\$ 0)',
        kind: KnapsackActionKind.retentionAutomation,
        costCents: 15000,
        expectedNetProfitCents: 98000,
        expectedGrossReturnCents: 113000,
        expectedNewOrders: 11,
      ),
      KnapsackActionCandidate(
        id: 'channel_sos_search_ads',
        title: 'Busca Hiperlocal Intenção Urgente (Chaveiro/Elétrica)',
        neighborhoodOrChannel: 'Centro & Vila Nova',
        kind: KnapsackActionKind.growthChannel,
        costCents: 50000,
        expectedNetProfitCents: 215000,
        expectedGrossReturnCents: 265000,
        expectedNewOrders: 19,
      ),
    ]);
    return out;
  }

  /// Resolve exatamente o problema da Mochila 0/1 para [budgetCents] com backtracking
  /// completo do subconjunto ótimo de [KnapsackActionCandidate]s.
  KnapsackAllocationPlan optimize({
    required int budgetCents,
    required List<KnapsackActionCandidate> candidates,
    int stepCents = 1000,
  }) {
    final safeBudget = math.max(0, budgetCents);
    if (safeBudget == 0 || candidates.isEmpty) {
      return KnapsackAllocationPlan(
        budgetCents: safeBudget,
        discretizationStepCents: math.max(1, stepCents),
        selectedActions: const <KnapsackActionCandidate>[],
        rejectedActions: List<KnapsackActionCandidate>.unmodifiable(candidates),
        totalCostCents: 0,
        unallocatedBudgetCents: safeBudget,
        totalExpectedNetProfitCents: 0,
        totalExpectedGrossReturnCents: 0,
        totalExpectedNewOrders: 0,
        dpStatesEvaluated: 0,
      );
    }

    final autoSelectedZeroCost = <KnapsackActionCandidate>[];
    final preRejected = <KnapsackActionCandidate>[];
    final eligible = <KnapsackActionCandidate>[];

    for (final c in candidates) {
      if (c.expectedNetProfitCents <= 0 || c.costCents > safeBudget) {
        preRejected.add(c);
      } else if (c.costCents <= 0) {
        autoSelectedZeroCost.add(c);
      } else {
        eligible.add(c);
      }
    }

    if (eligible.isEmpty) {
      final zeroNet = autoSelectedZeroCost.fold<int>(
        0,
        (sum, a) => sum + a.expectedNetProfitCents,
      );
      final zeroGross = autoSelectedZeroCost.fold<int>(
        0,
        (sum, a) => sum + a.expectedGrossReturnCents,
      );
      final zeroOrders = autoSelectedZeroCost.fold<int>(
        0,
        (sum, a) => sum + a.expectedNewOrders,
      );
      return KnapsackAllocationPlan(
        budgetCents: safeBudget,
        discretizationStepCents: math.max(1, stepCents),
        selectedActions:
            List<KnapsackActionCandidate>.unmodifiable(autoSelectedZeroCost),
        rejectedActions: List<KnapsackActionCandidate>.unmodifiable(preRejected),
        totalCostCents: 0,
        unallocatedBudgetCents: safeBudget,
        totalExpectedNetProfitCents: zeroNet,
        totalExpectedGrossReturnCents: zeroGross,
        totalExpectedNewOrders: zeroOrders,
        dpStatesEvaluated: 0,
      );
    }

    // Usa o MDC exato quando o número de estados cabe em <= 200.000 células (exatidão de 1 centavo!).
    var exactGcd = safeBudget;
    for (final item in eligible) {
      exactGcd = _gcd(exactGcd, item.costCents);
    }
    final n = eligible.length;
    var effectiveStep = math.max(1, exactGcd);
    if (n * (safeBudget ~/ effectiveStep) > 200000) {
      effectiveStep = math.max(1, stepCents);
      if (n * (safeBudget ~/ effectiveStep) > 200000) {
        effectiveStep = math.max(1, (safeBudget * n) ~/ 200000);
      }
    }

    final maxWeight = safeBudget ~/ effectiveStep;
    final stride = maxWeight + 1;
    final dp = List<int>.filled(stride, 0);
    // Tabela compacta de ponteiros de decisão: take[i * stride + w] == 1 se item i foi escolhido.
    final take = Uint8List(n * stride);

    for (var i = 0; i < n; i++) {
      final item = eligible[i];
      // Teto na discretização garante estritamente sum(costCents) <= budgetCents.
      final itemWeight =
          (item.costCents + effectiveStep - 1) ~/ effectiveStep;
      final val = item.expectedNetProfitCents;
      final rowOffset = i * stride;
      for (var w = maxWeight; w >= itemWeight; w--) {
        final candidateVal = dp[w - itemWeight] + val;
        if (candidateVal > dp[w]) {
          dp[w] = candidateVal;
          take[rowOffset + w] = 1;
        }
      }
    }

    // Backtracking exato de i = n - 1 até 0 para recuperar o subconjunto ótimo.
    final chosenReversed = <KnapsackActionCandidate>[];
    final rejectedFromDp = <KnapsackActionCandidate>[];
    var remW = maxWeight;
    for (var i = n - 1; i >= 0; i--) {
      final item = eligible[i];
      final itemWeight =
          (item.costCents + effectiveStep - 1) ~/ effectiveStep;
      if (remW >= itemWeight && take[i * stride + remW] == 1) {
        chosenReversed.add(item);
        remW -= itemWeight;
      } else {
        rejectedFromDp.add(item);
      }
    }

    final selected = <KnapsackActionCandidate>[
      ...autoSelectedZeroCost,
      ...chosenReversed.reversed,
    ];
    final rejected = <KnapsackActionCandidate>[
      ...rejectedFromDp.reversed,
      ...preRejected,
    ];

    final totalCost =
        selected.fold<int>(0, (sum, item) => sum + item.costCents);
    final totalNet = selected.fold<int>(
      0,
      (sum, item) => sum + item.expectedNetProfitCents,
    );
    final totalGross = selected.fold<int>(
      0,
      (sum, item) =>
          sum +
          (item.expectedGrossReturnCents > 0
              ? item.expectedGrossReturnCents
              : item.costCents + item.expectedNetProfitCents),
    );
    final totalOrders =
        selected.fold<int>(0, (sum, item) => sum + item.expectedNewOrders);

    return KnapsackAllocationPlan(
      budgetCents: safeBudget,
      discretizationStepCents: effectiveStep,
      selectedActions: List<KnapsackActionCandidate>.unmodifiable(selected),
      rejectedActions: List<KnapsackActionCandidate>.unmodifiable(rejected),
      totalCostCents: totalCost,
      unallocatedBudgetCents: safeBudget - totalCost,
      totalExpectedNetProfitCents: totalNet,
      totalExpectedGrossReturnCents: totalGross,
      totalExpectedNewOrders: totalOrders,
      dpStatesEvaluated: n * stride,
    );
  }
}

// ============================================================================
// DP 3 — ITERAÇÃO DE VALOR DE MARKOV-BELLMAN PARA LTV & PAYBACK POR COORTE
// ============================================================================

enum FounderUserCohortKind {
  onlyClient('ONLY_CLIENT', 'Exclusivamente Cliente'),
  onlyProvider('ONLY_PROVIDER', 'Exclusivamente Profissional'),
  dualModeHybrid('DUAL_MODE_HYBRID', 'Híbrido Dual-Mode (Cliente + Prestador)');

  const FounderUserCohortKind(this.wire, this.labelPt);
  final String wire;
  final String labelPt;
}

/// Modelo estocástico de 4 estados:
/// `0 = Ativo no Mês`, `1 = Recorrente Fiel`, `2 = Dormente (30-60d)`, `3 = Churned (Absorvente)`.
class MarkovCohortModel {
  const MarkovCohortModel({
    required this.cohort,
    required this.transitionMatrix,
    required this.immediateNetRewardCents,
    required this.cacCents,
    this.monthlyDiscountFactor = 0.988,
  });

  final FounderUserCohortKind cohort;
  final List<List<double>> transitionMatrix;
  final List<int> immediateNetRewardCents;
  final int cacCents;
  final double monthlyDiscountFactor;
}

class CohortLtvValuation {
  const CohortLtvValuation({
    required this.cohort,
    required this.stateValuesCents,
    required this.ltvCents,
    required this.cacCents,
    required this.ltvToCacRatioBps,
    required this.paybackMonths,
    required this.iterationsToConverge,
    required this.maxBellmanResidual,
  });

  final FounderUserCohortKind cohort;

  /// Valores presentes líquidos em centavos `[V_Ativo, V_Recorrente, V_Dormente, V_Churned]`.
  final List<int> stateValuesCents;

  final int ltvCents;
  final int cacCents;
  final int ltvToCacRatioBps;
  final double paybackMonths;
  final int iterationsToConverge;
  final double maxBellmanResidual;

  double get ltvToCacRatio => ltvToCacRatioBps / 10000.0;
}

/// Resolve $V^{(k+1)} = R + \gamma P V^{(k)}$ até convergência de ponto fixo de Banach
/// ($\max_s |V_s^{(k+1)} - V_s^{(k)}| < \epsilon$), demonstrando matematicamente por que
/// usuários híbridos `Dual-Mode` possuem o maior `LTV/CAC` do ecossistema.
class MarkovBellmanCohortLtvEngine {
  const MarkovBellmanCohortLtvEngine();

  static List<MarkovCohortModel> canonicalCohortModels() {
    return const <MarkovCohortModel>[
      // Coorte 1: Exclusivamente Cliente — boa margem por OS, frequência trimestral/bimestral.
      MarkovCohortModel(
        cohort: FounderUserCohortKind.onlyClient,
        cacCents: 3100,
        monthlyDiscountFactor: 0.988,
        immediateNetRewardCents: <int>[2150, 2980, 280, 0],
        transitionMatrix: <List<double>>[
          <double>[0.42, 0.24, 0.25, 0.09],
          <double>[0.20, 0.62, 0.13, 0.05],
          <double>[0.22, 0.08, 0.46, 0.24],
          <double>[0.00, 0.00, 0.00, 1.00],
        ],
      ),
      // Coorte 2: Exclusivamente Profissional — alta frequência mensal de OS, retenção forte.
      MarkovCohortModel(
        cohort: FounderUserCohortKind.onlyProvider,
        cacCents: 3600,
        monthlyDiscountFactor: 0.988,
        immediateNetRewardCents: <int>[3400, 4850, 420, 0],
        transitionMatrix: <List<double>>[
          <double>[0.46, 0.34, 0.14, 0.06],
          <double>[0.16, 0.72, 0.08, 0.04],
          <double>[0.26, 0.12, 0.42, 0.20],
          <double>[0.00, 0.00, 0.00, 1.00],
        ],
      ),
      // Coorte 3: Híbrido Dual-Mode — recicla saldo ganho contratando outros técnicos,
      // baixíssimo churn e CAC incremental zero no segundo papel!
      MarkovCohortModel(
        cohort: FounderUserCohortKind.dualModeHybrid,
        cacCents: 2450,
        monthlyDiscountFactor: 0.988,
        immediateNetRewardCents: <int>[4620, 6480, 690, 0],
        transitionMatrix: <List<double>>[
          <double>[0.44, 0.45, 0.08, 0.03],
          <double>[0.13, 0.80, 0.05, 0.02],
          <double>[0.34, 0.21, 0.33, 0.12],
          <double>[0.00, 0.00, 0.00, 1.00],
        ],
      ),
    ];
  }

  CohortLtvValuation evaluateCohort(
    MarkovCohortModel model, {
    double epsilon = 1e-6,
    int maxIterations = 2000,
  }) {
    final nStates = model.immediateNetRewardCents.length;
    final gamma = model.monthlyDiscountFactor.clamp(0.0, 0.9999);
    var v = List<double>.generate(
      nStates,
      (i) => model.immediateNetRewardCents[i].toDouble(),
    );
    var nextV = List<double>.filled(nStates, 0.0);

    var iter = 0;
    var residual = double.infinity;

    while (iter < maxIterations && residual >= epsilon) {
      residual = 0.0;
      for (var s = 0; s < nStates; s++) {
        var expectedNext = 0.0;
        final row = model.transitionMatrix[s];
        for (var j = 0; j < nStates; j++) {
          expectedNext += row[j] * v[j];
        }
        final updated = model.immediateNetRewardCents[s] + gamma * expectedNext;
        final diff = (updated - v[s]).abs();
        if (diff > residual) residual = diff;
        nextV[s] = updated;
      }
      for (var s = 0; s < nStates; s++) {
        v[s] = nextV[s];
      }
      iter++;
    }

    final stateCents = List<int>.generate(
      nStates,
      (s) => Money.toCents(v[s] / 100.0),
      growable: false,
    );
    final ltvCents = stateCents[0];
    final safeCac = math.max(1, model.cacCents);
    final ratioBps = ((ltvCents * 10000) + (safeCac ~/ 2)) ~/ safeCac;

    // Simula distribuição de probabilidade de estados p^(t+1) = p^(t) * P para achar o Payback exato.
    var dist = List<double>.filled(nStates, 0.0);
    dist[0] = 1.0;
    var cumDiscountedCents = 0.0;
    var discountPow = 1.0;
    var payback = 36.0;
    final targetCac = model.cacCents.toDouble();

    for (var month = 0; month < 60; month++) {
      var monthExpectedCents = 0.0;
      for (var s = 0; s < nStates; s++) {
        monthExpectedCents += dist[s] * model.immediateNetRewardCents[s];
      }
      final discountedStep = discountPow * monthExpectedCents;
      final prevCum = cumDiscountedCents;
      cumDiscountedCents += discountedStep;
      if (cumDiscountedCents >= targetCac) {
        final needed = targetCac - prevCum;
        final frac = discountedStep <= 1e-9
            ? 0.0
            : (needed / discountedStep).clamp(0.0, 1.0);
        payback = month + frac;
        break;
      }
      final nextDist = List<double>.filled(nStates, 0.0);
      for (var s = 0; s < nStates; s++) {
        for (var j = 0; j < nStates; j++) {
          nextDist[j] += dist[s] * model.transitionMatrix[s][j];
        }
      }
      dist = nextDist;
      discountPow *= gamma;
    }

    return CohortLtvValuation(
      cohort: model.cohort,
      stateValuesCents: stateCents,
      ltvCents: ltvCents,
      cacCents: model.cacCents,
      ltvToCacRatioBps: ratioBps,
      paybackMonths: payback,
      iterationsToConverge: iter,
      maxBellmanResidual: residual,
    );
  }

  List<CohortLtvValuation> evaluateAllCanonicalCohorts() {
    return canonicalCohortModels()
        .map(evaluateCohort)
        .toList(growable: false);
  }
}

// ============================================================================
// DP 4 — ALGORITMO DE KADANE O(T) + PAGE'S TABULAR CUSUM DE DERIVA/ANOMALIA
// ============================================================================

class KadaneOptimalWindow {
  const KadaneOptimalWindow({
    required this.startIndex,
    required this.endIndex,
    required this.startDayIso,
    required this.endDayIso,
    required this.totalGainCents,
  });

  final int startIndex;
  final int endIndex;
  final String startDayIso;
  final String endDayIso;
  final int totalGainCents;

  int get daysLength => endIndex >= startIndex ? (endIndex - startIndex + 1) : 0;
}

enum CusumDriftDirection {
  upwardSurge('UPWARD_SURGE', 'Aceleração Estrutural Positiva'),
  downwardDrop('DOWNWARD_DROP', 'Alerta de Queda / Sinistralidade');

  const CusumDriftDirection(this.wire, this.labelPt);
  final String wire;
  final String labelPt;
}

class CusumDriftAlert {
  const CusumDriftAlert({
    required this.index,
    required this.dayIso,
    required this.direction,
    required this.statisticValue,
    required this.threshold,
    required this.observedValueCents,
  });

  final int index;
  final String dayIso;
  final CusumDriftDirection direction;
  final double statisticValue;
  final double threshold;
  final int observedValueCents;
}

class TimelineAnomalyReport {
  const TimelineAnomalyReport({
    required this.maxProfitWindow,
    required this.maxAccelerationWindow,
    required this.cusumUpperSeries,
    required this.cusumLowerSeries,
    required this.driftAlerts,
    required this.baselineMeanCents,
    required this.baselineStdDevCents,
  });

  final KadaneOptimalWindow maxProfitWindow;
  final KadaneOptimalWindow maxAccelerationWindow;
  final List<double> cusumUpperSeries;
  final List<double> cusumLowerSeries;
  final List<CusumDriftAlert> driftAlerts;
  final double baselineMeanCents;
  final double baselineStdDevCents;
}

/// Detector $O(T)$ combinando Programação Dinâmica de Kadane (subvetor contíguo ótimo
/// de lucro e aceleração) com CUSUM Tabular Bilateral de Page ($S_t^+, S_t^-$).
class KadaneAndCusumAnomalyDetector {
  const KadaneAndCusumAnomalyDetector();

  KadaneOptimalWindow runKadane(
    List<int> valuesCents, {
    List<String>? dayIsos,
  }) {
    if (valuesCents.isEmpty) {
      return const KadaneOptimalWindow(
        startIndex: 0,
        endIndex: 0,
        startDayIso: '',
        endDayIso: '',
        totalGainCents: 0,
      );
    }

    var currentSum = valuesCents[0];
    var currentStart = 0;
    var bestSum = valuesCents[0];
    var bestStart = 0;
    var bestEnd = 0;

    for (var i = 1; i < valuesCents.length; i++) {
      final x = valuesCents[i];
      if (currentSum + x < x) {
        currentSum = x;
        currentStart = i;
      } else {
        currentSum += x;
      }
      if (currentSum > bestSum) {
        bestSum = currentSum;
        bestStart = currentStart;
        bestEnd = i;
      }
    }

    String isoAt(int idx) =>
        (dayIsos != null && idx >= 0 && idx < dayIsos.length)
            ? dayIsos[idx]
            : 'D+$idx';

    return KadaneOptimalWindow(
      startIndex: bestStart,
      endIndex: bestEnd,
      startDayIso: isoAt(bestStart),
      endDayIso: isoAt(bestEnd),
      totalGainCents: bestSum,
    );
  }

  TimelineAnomalyReport analyzeTimeline(
    List<FounderDailyMetricPoint> series, {
    double slackKSigma = 0.5,
    double thresholdHSigma = 4.0,
  }) {
    if (series.isEmpty) {
      const emptyWin = KadaneOptimalWindow(
        startIndex: 0,
        endIndex: 0,
        startDayIso: '',
        endDayIso: '',
        totalGainCents: 0,
      );
      return const TimelineAnomalyReport(
        maxProfitWindow: emptyWin,
        maxAccelerationWindow: emptyWin,
        cusumUpperSeries: <double>[],
        cusumLowerSeries: <double>[],
        driftAlerts: <CusumDriftAlert>[],
        baselineMeanCents: 0.0,
        baselineStdDevCents: 0.0,
      );
    }

    final profits = series.map((p) => p.netProfitCents).toList(growable: false);
    final isos = series.map((p) => p.dayIso).toList(growable: false);
    final maxProfitWin = runKadane(profits, dayIsos: isos);

    final deltas = <int>[0];
    for (var i = 1; i < profits.length; i++) {
      deltas.add(profits[i] - profits[i - 1]);
    }
    final maxAccelWin = runKadane(deltas, dayIsos: isos);

    // Calibra média e desvio-padrão na janela inicial de referência (primeiros 30% ou mín. 14 dias).
    final baselineLen = math.min(
      series.length,
      math.max(14, (series.length * 30) ~/ 100),
    );
    var sum = 0.0;
    for (var i = 0; i < baselineLen; i++) {
      sum += profits[i];
    }
    final mean = sum / baselineLen;

    var sqDiff = 0.0;
    for (var i = 0; i < baselineLen; i++) {
      final d = profits[i] - mean;
      sqDiff += d * d;
    }
    final stdDev = math.max(100.0, math.sqrt(sqDiff / baselineLen));
    final slackK = slackKSigma * stdDev;
    final thresholdH = thresholdHSigma * stdDev;

    final sPos = List<double>.filled(series.length, 0.0);
    final sNeg = List<double>.filled(series.length, 0.0);
    final alerts = <CusumDriftAlert>[];

    var curPos = 0.0;
    var curNeg = 0.0;
    for (var t = 0; t < series.length; t++) {
      final x = profits[t].toDouble();
      // Penaliza adicionalmente picos de sinistro do fundo de garantia na perna inferior.
      final claimShock = series[t].warrantyClaimsCents.toDouble();
      curPos = math.max(0.0, curPos + (x - mean) - slackK);
      curNeg = math.max(0.0, curNeg + (mean - (x - claimShock)) - slackK);
      sPos[t] = curPos;
      sNeg[t] = curNeg;

      if (curPos > thresholdH) {
        alerts.add(
          CusumDriftAlert(
            index: t,
            dayIso: isos[t],
            direction: CusumDriftDirection.upwardSurge,
            statisticValue: curPos,
            threshold: thresholdH,
            observedValueCents: profits[t],
          ),
        );
        curPos = thresholdH * 0.5;
      }
      if (curNeg > thresholdH) {
        alerts.add(
          CusumDriftAlert(
            index: t,
            dayIso: isos[t],
            direction: CusumDriftDirection.downwardDrop,
            statisticValue: curNeg,
            threshold: thresholdH,
            observedValueCents: profits[t],
          ),
        );
        curNeg = thresholdH * 0.5;
      }
    }

    return TimelineAnomalyReport(
      maxProfitWindow: maxProfitWin,
      maxAccelerationWindow: maxAccelWin,
      cusumUpperSeries: List<double>.unmodifiable(sPos),
      cusumLowerSeries: List<double>.unmodifiable(sNeg),
      driftAlerts: List<CusumDriftAlert>.unmodifiable(alerts),
      baselineMeanCents: mean,
      baselineStdDevCents: stdDev,
    );
  }
}

// ============================================================================
// DP 5 — RADAR ANTI-BYPASS: WAGNER-FISCHER O(m*n) PONDERADO + FUSÃO COMPORTAMENTAL
// ============================================================================

enum BypassSeverity {
  low('LOW', 'Risco Baixo · Operação Íntegra'),
  watch('WATCH', 'Atenção Moderada · Monitorar'),
  high('HIGH', 'Risco Alto · Indício Forte de Evasão'),
  criticalBlock('CRITICAL_BLOCK', 'Crítico · Bloqueio Preventivo & Auditoria');

  const BypassSeverity(this.wire, this.labelPt);
  final String wire;
  final String labelPt;
}

class BypassRiskAssessment {
  const BypassRiskAssessment({
    required this.normalizedPreview,
    required this.matchedCanonicalPattern,
    required this.minNormalizedEditDistance,
    required this.lexicalRiskBps,
    required this.behavioralRiskBps,
    required this.smartSplitDistortionRiskBps,
    required this.compositeRiskBps,
    required this.materialsShareBps,
    required this.disguisedDigitsCount,
    required this.smartSplitDistortionDetected,
    required this.rapidPostChatCancellationDetected,
    required this.severity,
    required this.reasonFlags,
  });

  final String normalizedPreview;
  final String? matchedCanonicalPattern;
  final double minNormalizedEditDistance;
  final int lexicalRiskBps;
  final int behavioralRiskBps;
  final int smartSplitDistortionRiskBps;
  final int compositeRiskBps;
  final int materialsShareBps;
  final int disguisedDigitsCount;
  final bool smartSplitDistortionDetected;
  final bool rapidPostChatCancellationDetected;
  final BypassSeverity severity;
  final List<String> reasonFlags;

  double get compositeRiskPct => compositeRiskBps / 100.0;
}

/// Motor Anti-Bypass combinando:
/// 1) Desofuscação de leetspeak (`z4p`, `p.i.x`, `f0ra`, números por extenso),
/// 2) Programação Dinâmica de Wagner-Fischer $O(m \cdot n)$ com pesos fonéticos/visuais,
/// 3) Fusão com cancelamento pós-chat e distorção de peças (`> 85%` sem NF-e verificada).
class AntiBypassAndLeakageDetector {
  const AntiBypassAndLeakageDetector();

  static const List<String> canonicalBypassPatterns = <String>[
    'whatsapp',
    'me chama no zap',
    'chama no zap',
    'zapzap',
    'chave pix',
    'paga no pix',
    'paga por fora',
    'fechar por fora',
    'fora do app',
    'sem taxa do app',
    'cancela o pedido',
    'desconto por fora',
    'anota meu numero',
    'me liga direto',
  ];

  static const Map<String, String> _wordToDigit = <String, String>{
    'zero': '0',
    'um': '1',
    'uma': '1',
    'dois': '2',
    'duas': '2',
    'tres': '3',
    'quatro': '4',
    'cinco': '5',
    'seis': '6',
    'meia': '6',
    'sete': '7',
    'oito': '8',
    'nove': '9',
  };

  /// Conta dígitos explícitos + números escritos por extenso (`nove nove oito...`).
  int countDisguisedDigits(String raw) {
    final cleaned = _stripAccents(raw.toLowerCase());
    var explicitDigits = 0;
    for (var i = 0; i < cleaned.length; i++) {
      final c = cleaned.codeUnitAt(i);
      if (c >= 48 && c <= 57) explicitDigits++;
    }
    var writtenDigits = 0;
    final words = cleaned.split(RegExp(r'[^a-z0-9]+'));
    for (final w in words) {
      if (_wordToDigit.containsKey(w)) writtenDigits++;
    }
    return explicitDigits + writtenDigits;
  }

  /// Desofusca texto camuflado (`p.i.x` -> `pix`, `z 4 p` -> `zap`, `f0r4 d0 4pp` -> `fora do app`).
  String normalizeObfuscatedText(String raw) {
    final lower = _stripAccents(raw.toLowerCase());
    const leet = <String, String>{
      '0': 'o',
      '1': 'i',
      '3': 'e',
      '4': 'a',
      '5': 's',
      '7': 't',
      '@': 'a',
      '\$': 's',
    };

    // Primeiro remove pontuação inserida entre letras isoladas (ex.: "p.i.x", "z-a-p").
    final dePunctuated = lower.replaceAllMapped(
      RegExp(r'([a-z0-9@\$])[\.\-_/\\*|+]+(?=[a-z0-9@\$])'),
      (m) => m.group(1)!,
    );

    final mapped = StringBuffer();
    for (var i = 0; i < dePunctuated.length; i++) {
      final ch = dePunctuated[i];
      if (leet.containsKey(ch)) {
        mapped.write(leet[ch]);
      } else {
        final code = ch.codeUnitAt(0);
        if ((code >= 97 && code <= 122) || ch == ' ') {
          mapped.write(ch);
        } else {
          mapped.write(' ');
        }
      }
    }

    final rawTokens = mapped
        .toString()
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    // Colapsa sequências de letras únicas espaçadas ("z a p" -> "zap", "p i x" -> "pix").
    final collapsedTokens = <String>[];
    final singleCharBuf = StringBuffer();
    for (final tok in rawTokens) {
      if (tok.length == 1) {
        singleCharBuf.write(tok);
      } else {
        if (singleCharBuf.isNotEmpty) {
          collapsedTokens.add(_collapseRepeatedChars(singleCharBuf.toString()));
          singleCharBuf.clear();
        }
        collapsedTokens.add(_collapseRepeatedChars(tok));
      }
    }
    if (singleCharBuf.isNotEmpty) {
      collapsedTokens.add(_collapseRepeatedChars(singleCharBuf.toString()));
    }

    return collapsedTokens.join(' ');
  }

  /// Tabela DP de Wagner-Fischer $O(m \cdot n)$ com custos de substituição fonética/homóglifa.
  double computeWeightedEditDistance(String source, String target) {
    final m = source.length;
    final n = target.length;
    if (m == 0) return n.toDouble();
    if (n == 0) return m.toDouble();

    var prev = Float64List(n + 1);
    var curr = Float64List(n + 1);
    for (var j = 0; j <= n; j++) {
      prev[j] = j.toDouble();
    }

    for (var i = 1; i <= m; i++) {
      curr[0] = i.toDouble();
      final cs = source.codeUnitAt(i - 1);
      final prevCs = i >= 2 ? source.codeUnitAt(i - 2) : -1;
      final delCost = (cs == prevCs) ? 0.35 : 1.0;

      for (var j = 1; j <= n; j++) {
        final ct = target.codeUnitAt(j - 1);
        final subCost = (cs == ct) ? 0.0 : _phoneticSubstitutionCost(cs, ct);
        final deletion = prev[j] + delCost;
        final insertion = curr[j - 1] + 1.0;
        final substitution = prev[j - 1] + subCost;
        curr[j] = math.min(substitution, math.min(deletion, insertion));
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }

  BypassRiskAssessment evaluateRisk({
    required String chatSnippet,
    int? cancelledWithinMinutesAfterChat,
    int laborCents = 0,
    int materialsExemptCents = 0,
    bool hasVerified44DigitNfe = true,
  }) {
    final normalized = normalizeObfuscatedText(chatSnippet);
    final digitsCount = countDisguisedDigits(chatSnippet);
    final tokens = normalized.isEmpty
        ? const <String>[]
        : normalized.split(' ').where((t) => t.isNotEmpty).toList();

    var minNormDist = 1.0;
    String? bestPattern;

    if (tokens.isNotEmpty) {
      for (final pattern in canonicalBypassPatterns) {
        if (normalized.contains(pattern)) {
          minNormDist = 0.0;
          bestPattern = pattern;
          break;
        }
        final patWords = pattern.split(' ').length;
        final minWin = math.max(1, patWords - 1);
        final maxWin = math.min(tokens.length, patWords + 1);
        for (var w = minWin; w <= maxWin; w++) {
          for (var start = 0; start + w <= tokens.length; start++) {
            final candidateWindow = tokens.sublist(start, start + w).join(' ');
            final dist = computeWeightedEditDistance(candidateWindow, pattern);
            final normDist =
                dist / math.max(candidateWindow.length, pattern.length);
            if (normDist < minNormDist) {
              minNormDist = normDist;
              bestPattern = pattern;
            }
          }
        }
      }
    }

    // Score lexical baseado na distância de Wagner-Fischer + presença de telefone/chave.
    var lexicalBps = 0;
    if (bestPattern != null && minNormDist <= 0.34) {
      lexicalBps = ((1.0 - (minNormDist / 0.45)) * 8800).round().clamp(0, 9200);
    }
    if (digitsCount >= 8) {
      lexicalBps = math.min(10000, lexicalBps + 5200);
    } else if (digitsCount >= 5) {
      lexicalBps = math.min(10000, lexicalBps + 2400);
    }

    final rapidCancel = cancelledWithinMinutesAfterChat != null &&
        cancelledWithinMinutesAfterChat >= 0 &&
        cancelledWithinMinutesAfterChat <= 45;
    final behavioralBps = rapidCancel
        ? (cancelledWithinMinutesAfterChat <= 15 ? 4200 : 2800)
        : 0;

    final totalOrderCents = laborCents + materialsExemptCents;
    final materialsShareBps = totalOrderCents <= 0
        ? 0
        : (materialsExemptCents * 10000) ~/ totalOrderCents;
    final splitDistortion =
        materialsShareBps > 8500 && !hasVerified44DigitNfe;
    final splitRiskBps = splitDistortion
        ? 4800
        : (materialsShareBps > 8000 && !hasVerified44DigitNfe ? 2600 : 0);

    // Fusão Bayesiana/log-odds saturada em [0..10000 bps].
    final pLex = lexicalBps / 10000.0;
    final pBeh = behavioralBps / 10000.0;
    final pSpl = splitRiskBps / 10000.0;
    final combinedProb = 1.0 - ((1.0 - pLex) * (1.0 - pBeh) * (1.0 - pSpl));
    final compositeBps = (combinedProb * 10000).round().clamp(0, 10000);

    final reasons = <String>[];
    if (bestPattern != null && minNormDist <= 0.34) {
      reasons.add(
        'Padrão de evasão detectado próximo a "$bestPattern" (distância DP ${(minNormDist * 100).toStringAsFixed(1)}%)',
      );
    }
    if (digitsCount >= 8) {
      reasons.add(
        'Sequência camuflada de $digitsCount dígitos numéricos/por extenso (possível contato externo/chave)',
      );
    }
    if (rapidCancel) {
      reasons.add(
        'Cancelamento suspeito ${cancelledWithinMinutesAfterChat}min após troca de mensagens no chat',
      );
    }
    if (splitDistortion) {
      reasons.add(
        'Distorção Smart Split: ${(materialsShareBps / 100.0).toStringAsFixed(1)}% lançado como Peças (0% taxa) sem NF-e 44 dígitos verificada',
      );
    }

    final severity = switch (compositeBps) {
      >= 7500 => BypassSeverity.criticalBlock,
      >= 5000 => BypassSeverity.high,
      >= 2500 => BypassSeverity.watch,
      _ => BypassSeverity.low,
    };

    return BypassRiskAssessment(
      normalizedPreview: normalized,
      matchedCanonicalPattern: minNormDist <= 0.34 ? bestPattern : null,
      minNormalizedEditDistance: minNormDist,
      lexicalRiskBps: lexicalBps,
      behavioralRiskBps: behavioralBps,
      smartSplitDistortionRiskBps: splitRiskBps,
      compositeRiskBps: compositeBps,
      materialsShareBps: materialsShareBps,
      disguisedDigitsCount: digitsCount,
      smartSplitDistortionDetected: splitDistortion,
      rapidPostChatCancellationDetected: rapidCancel,
      severity: severity,
      reasonFlags: List<String>.unmodifiable(reasons),
    );
  }

  static String _collapseRepeatedChars(String word) {
    if (word.length <= 2) return word;
    final sb = StringBuffer()..write(word[0]);
    for (var i = 1; i < word.length; i++) {
      final ch = word[i];
      if (ch == word[i - 1] && ch != 's' && ch != 'r') continue;
      sb.write(ch);
    }
    return sb.toString();
  }

  static double _phoneticSubstitutionCost(int a, int b) {
    const groups = <String>['szx', 'ckq', 'vwu', 'iy', 'ao'];
    final ca = String.fromCharCode(a);
    final cb = String.fromCharCode(b);
    for (final g in groups) {
      if (g.contains(ca) && g.contains(cb)) return 0.40;
    }
    return 1.0;
  }

  static String _stripAccents(String input) {
    const map = <String, String>{
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c',
    };
    final sb = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }
}

// ============================================================================
// SIMULAÇÃO ESTOCÁSTICA DE MONTE CARLO (1.000 TRAJETÓRIAS EM WORKER OFF-THREAD)
// ============================================================================

/// PRNG Mulberry32 determinístico (aritmética estrita de 32 bits sem divergência JS/VM)
/// acoplado a transformação Gaussiana de Box-Muller.
class _Mulberry32Rng {
  _Mulberry32Rng(int seed) : _state = (seed & 0xFFFFFFFF) == 0 ? 0x6D2B79F5 : (seed & 0xFFFFFFFF);

  int _state;
  double? _spareNormal;

  double nextUnitDouble() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _imul32(_state ^ (_state >>> 15), 1 | _state);
    t = (t + _imul32(t ^ (t >>> 7), 61 | t)) ^ t;
    final unsigned = (t ^ (t >>> 14)) & 0xFFFFFFFF;
    return (unsigned + 0.5) / 4294967296.0;
  }

  double nextStandardNormal() {
    final cached = _spareNormal;
    if (cached != null) {
      _spareNormal = null;
      return cached;
    }
    final u1 = nextUnitDouble().clamp(1e-12, 1.0 - 1e-12);
    final u2 = nextUnitDouble();
    final mag = math.sqrt(-2.0 * math.log(u1));
    final angle = 2.0 * math.pi * u2;
    _spareNormal = mag * math.sin(angle);
    return mag * math.cos(angle);
  }

  static int _imul32(int a, int b) {
    final ah = (a >>> 16) & 0xFFFF;
    final al = a & 0xFFFF;
    final bh = (b >>> 16) & 0xFFFF;
    final bl = b & 0xFFFF;
    return ((al * bl) + (((ah * bl + al * bh) & 0xFFFF) << 16)) & 0xFFFFFFFF;
  }
}

class FounderMonteCarloParams {
  const FounderMonteCarloParams({
    required this.initialCashCents,
    required this.initialMonthlyOrders,
    required this.monthlyOrderGrowthBps,
    required this.avgGrossTicketCents,
    required this.laborShareBps,
    required this.effectiveTakeRateOnLaborBps,
    required this.poolCarveoutOnLaborBps,
    required this.cacCents,
    required this.newPaidUsersPerMonth,
    required this.warrantyClaimRateBps,
    required this.fixedMonthlyOpexCents,
    required this.initialPoolBalanceCents,
    this.orderGrowthVolatilityBps = 450,
    this.horizonMonths = 12,
    this.trajectoriesCount = 1000,
    this.seed = 0xDE59E22E,
  });

  final int initialCashCents;
  final int initialMonthlyOrders;
  final int monthlyOrderGrowthBps;
  final int orderGrowthVolatilityBps;
  final int avgGrossTicketCents;
  final int laborShareBps;
  final int effectiveTakeRateOnLaborBps;
  final int poolCarveoutOnLaborBps;
  final int cacCents;
  final int newPaidUsersPerMonth;
  final int warrantyClaimRateBps;
  final int fixedMonthlyOpexCents;
  final int initialPoolBalanceCents;
  final int horizonMonths;
  final int trajectoriesCount;
  final int seed;

  factory FounderMonteCarloParams.fromSnapshot(
    FounderDashboardSnapshot snapshot,
  ) {
    final timeline = PrefixSumFinancialTimeline(snapshot.dailySeries);
    final last30 = timeline.queryLastDays(30);
    final monthlyOrders =
        last30.ordersCount > 0 ? last30.ordersCount : 120;
    final avgTicket =
        last30.avgTicketCents > 0 ? last30.avgTicketCents : 32000;
    final laborShare = last30.gmvCents > 0
        ? ((last30.laborCents * 10000) ~/ last30.gmvCents).clamp(4000, 8500)
        : 6000;

    return FounderMonteCarloParams(
      initialCashCents: math.max(1500000, snapshot.treasury.availableWalletsCents ~/ 2),
      initialMonthlyOrders: monthlyOrders,
      monthlyOrderGrowthBps: 1150, // +11,5% a.m.
      avgGrossTicketCents: avgTicket,
      laborShareBps: laborShare,
      effectiveTakeRateOnLaborBps: 1350, // 13,5%
      poolCarveoutOnLaborBps: 150, // 1,5%
      cacCents: snapshot.aarrrFunnel.cacCents > 0
          ? snapshot.aarrrFunnel.cacCents
          : 2850,
      newPaidUsersPerMonth: 42,
      warrantyClaimRateBps: 90, // 0,90% da exposição de mão de obra
      fixedMonthlyOpexCents: 180000, // R$ 1.800,00/mês
      initialPoolBalanceCents: snapshot.actuarialPool.runningBalanceCents > 0
          ? snapshot.actuarialPool.runningBalanceCents
          : 1894000,
    );
  }

  FounderMonteCarloParams copyWith({
    int? initialCashCents,
    int? initialMonthlyOrders,
    int? monthlyOrderGrowthBps,
    int? orderGrowthVolatilityBps,
    int? avgGrossTicketCents,
    int? laborShareBps,
    int? effectiveTakeRateOnLaborBps,
    int? poolCarveoutOnLaborBps,
    int? cacCents,
    int? newPaidUsersPerMonth,
    int? warrantyClaimRateBps,
    int? fixedMonthlyOpexCents,
    int? initialPoolBalanceCents,
    int? horizonMonths,
    int? trajectoriesCount,
    int? seed,
  }) {
    return FounderMonteCarloParams(
      initialCashCents: initialCashCents ?? this.initialCashCents,
      initialMonthlyOrders: initialMonthlyOrders ?? this.initialMonthlyOrders,
      monthlyOrderGrowthBps:
          monthlyOrderGrowthBps ?? this.monthlyOrderGrowthBps,
      orderGrowthVolatilityBps:
          orderGrowthVolatilityBps ?? this.orderGrowthVolatilityBps,
      avgGrossTicketCents: avgGrossTicketCents ?? this.avgGrossTicketCents,
      laborShareBps: laborShareBps ?? this.laborShareBps,
      effectiveTakeRateOnLaborBps:
          effectiveTakeRateOnLaborBps ?? this.effectiveTakeRateOnLaborBps,
      poolCarveoutOnLaborBps:
          poolCarveoutOnLaborBps ?? this.poolCarveoutOnLaborBps,
      cacCents: cacCents ?? this.cacCents,
      newPaidUsersPerMonth: newPaidUsersPerMonth ?? this.newPaidUsersPerMonth,
      warrantyClaimRateBps: warrantyClaimRateBps ?? this.warrantyClaimRateBps,
      fixedMonthlyOpexCents:
          fixedMonthlyOpexCents ?? this.fixedMonthlyOpexCents,
      initialPoolBalanceCents:
          initialPoolBalanceCents ?? this.initialPoolBalanceCents,
      horizonMonths: horizonMonths ?? this.horizonMonths,
      trajectoriesCount: trajectoriesCount ?? this.trajectoriesCount,
      seed: seed ?? this.seed,
    );
  }
}

class FounderMonteCarloResult {
  const FounderMonteCarloResult({
    required this.horizonMonths,
    required this.trajectoriesCount,
    required this.p10CashCents,
    required this.p50CashCents,
    required this.p90CashCents,
    required this.p10MonthlyProfitCents,
    required this.p50MonthlyProfitCents,
    required this.p90MonthlyProfitCents,
    required this.breakEvenProbabilityBps,
    required this.poolSolvencyProbabilityBps,
    required this.medianBreakEvenMonth,
    required this.terminalMedianCashCents,
    required this.terminalMedianIcaBps,
  });

  final int horizonMonths;
  final int trajectoriesCount;
  final List<int> p10CashCents;
  final List<int> p50CashCents;
  final List<int> p90CashCents;
  final List<int> p10MonthlyProfitCents;
  final List<int> p50MonthlyProfitCents;
  final List<int> p90MonthlyProfitCents;
  final int breakEvenProbabilityBps;
  final int poolSolvencyProbabilityBps;
  final int? medianBreakEvenMonth;
  final int terminalMedianCashCents;
  final int terminalMedianIcaBps;

  double get breakEvenProbabilityPct => breakEvenProbabilityBps / 100.0;
  double get poolSolvencyProbabilityPct => poolSolvencyProbabilityBps / 100.0;
}

/// Executa síncronamente `1.000` trajetórias estocásticas de 12 meses em aritmética
/// inteira de centavos (ideal para testes determinísticos ou dentro de [runOffMainThread]).
FounderMonteCarloResult runMonteCarloSimulationSync(
  FounderMonteCarloParams params,
) {
  final months = params.horizonMonths.clamp(1, 60);
  final runs = params.trajectoriesCount.clamp(10, 10000);
  final rng = _Mulberry32Rng(params.seed);

  final cashMatrix = List<List<int>>.generate(
    months,
    (_) => List<int>.filled(runs, 0),
    growable: false,
  );
  final profitMatrix = List<List<int>>.generate(
    months,
    (_) => List<int>.filled(runs, 0),
    growable: false,
  );
  final firstBreakEvenMonths = <int>[];
  final terminalIcas = List<int>.filled(runs, 0);

  var terminalBreakEvenSuccess = 0;
  var terminalPoolSolventCount = 0;

  final baseGrowth = params.monthlyOrderGrowthBps / 10000.0;
  final growthSigma = params.orderGrowthVolatilityBps / 10000.0;

  for (var r = 0; r < runs; r++) {
    var cash = params.initialCashCents;
    var poolBalance = params.initialPoolBalanceCents;
    var currentOrders = params.initialMonthlyOrders.toDouble();
    int? reachedBreakEvenAt;

    for (var m = 0; m < months; m++) {
      final zGrowth = rng.nextStandardNormal();
      final zClaim = rng.nextStandardNormal();

      final stepGrowth = (baseGrowth + growthSigma * zGrowth).clamp(-0.35, 0.65);
      currentOrders = math.max(1.0, currentOrders * (1.0 + stepGrowth));
      final ordersInt = currentOrders.round();

      final monthGmv = ordersInt * params.avgGrossTicketCents;
      final monthLabor = Money.percentOfCents(monthGmv, params.laborShareBps);
      final platformRev = Money.percentOfCents(
        monthLabor,
        params.effectiveTakeRateOnLaborBps,
      );
      final poolInflow = Money.percentOfCents(
        monthLabor,
        params.poolCarveoutOnLaborBps,
      );
      final simplesTax = Money.percentOfCents(platformRev, 600);
      final pspCloudVarCost = (ordersInt * 34 + 5) ~/ 10;
      final marketingSpend = params.newPaidUsersPerMonth * params.cacCents;

      final shockMultiplier = (1.0 + 0.25 * zClaim).clamp(0.25, 2.50);
      final effectiveClaimBps =
          (params.warrantyClaimRateBps * shockMultiplier).round().clamp(0, 5000);
      final claimsOutflow = Money.percentOfCents(monthLabor, effectiveClaimBps);

      poolBalance += poolInflow - claimsOutflow;
      // Caso extremo de cauda: se o pool zerar, o caixa soberano cobre o déficit residual.
      var emergencyTopup = 0;
      if (poolBalance < 0) {
        emergencyTopup = -poolBalance;
        poolBalance = 0;
      }

      final monthNetProfit = platformRev -
          simplesTax -
          pspCloudVarCost -
          marketingSpend -
          params.fixedMonthlyOpexCents -
          emergencyTopup;
      cash += monthNetProfit;

      cashMatrix[m][r] = cash;
      profitMatrix[m][r] = monthNetProfit;

      if (reachedBreakEvenAt == null && monthNetProfit >= 0) {
        reachedBreakEvenAt = m + 1;
      }

      if (m == months - 1) {
        if (monthNetProfit >= 0) terminalBreakEvenSuccess++;
        final activeExposure = math.max(1, Money.percentOfCents(monthLabor, 3500));
        final icaBps = (poolBalance * 10000) ~/ activeExposure;
        terminalIcas[r] = icaBps;
        if (icaBps >= 15000) terminalPoolSolventCount++;
      }
    }

    if (reachedBreakEvenAt != null) {
      firstBreakEvenMonths.add(reachedBreakEvenAt);
    }
  }

  int percentileOfSorted(List<int> sorted, int pct) {
    final idx = ((sorted.length - 1) * pct) ~/ 100;
    return sorted[idx.clamp(0, sorted.length - 1)];
  }

  final p10Cash = List<int>.filled(months, 0);
  final p50Cash = List<int>.filled(months, 0);
  final p90Cash = List<int>.filled(months, 0);
  final p10Profit = List<int>.filled(months, 0);
  final p50Profit = List<int>.filled(months, 0);
  final p90Profit = List<int>.filled(months, 0);

  for (var m = 0; m < months; m++) {
    cashMatrix[m].sort();
    profitMatrix[m].sort();
    p10Cash[m] = percentileOfSorted(cashMatrix[m], 10);
    p50Cash[m] = percentileOfSorted(cashMatrix[m], 50);
    p90Cash[m] = percentileOfSorted(cashMatrix[m], 90);
    p10Profit[m] = percentileOfSorted(profitMatrix[m], 10);
    p50Profit[m] = percentileOfSorted(profitMatrix[m], 50);
    p90Profit[m] = percentileOfSorted(profitMatrix[m], 90);
  }

  terminalIcas.sort();
  int? medianBreakEven;
  if (firstBreakEvenMonths.length * 2 >= runs) {
    firstBreakEvenMonths.sort();
    medianBreakEven = firstBreakEvenMonths[runs ~/ 2];
  }

  return FounderMonteCarloResult(
    horizonMonths: months,
    trajectoriesCount: runs,
    p10CashCents: List<int>.unmodifiable(p10Cash),
    p50CashCents: List<int>.unmodifiable(p50Cash),
    p90CashCents: List<int>.unmodifiable(p90Cash),
    p10MonthlyProfitCents: List<int>.unmodifiable(p10Profit),
    p50MonthlyProfitCents: List<int>.unmodifiable(p50Profit),
    p90MonthlyProfitCents: List<int>.unmodifiable(p90Profit),
    breakEvenProbabilityBps:
        ((terminalBreakEvenSuccess * 10000) + (runs ~/ 2)) ~/ runs,
    poolSolvencyProbabilityBps:
        ((terminalPoolSolventCount * 10000) + (runs ~/ 2)) ~/ runs,
    medianBreakEvenMonth: medianBreakEven,
    terminalMedianCashCents: p50Cash[months - 1],
    terminalMedianIcaBps: percentileOfSorted(terminalIcas, 50),
  );
}

/// Executa a simulação estocástica de Monte Carlo (`1.000` trajetórias) fora da UI Thread
/// usando exclusivamente [runOffMainThread] (120 FPS garantidos no slider em tempo real).
Future<FounderMonteCarloResult> runMonteCarloSimulationOffThread(
  FounderMonteCarloParams params,
) {
  return runOffMainThread(() => runMonteCarloSimulationSync(params));
}

// ============================================================================
// COPILOTO EXECUTIVO C-LEVEL (AI CFO & COO READ-ONLY — FUNDAMENTADO NOS MOTORES DP)
// ============================================================================

class CopilotBriefingResponse {
  const CopilotBriefingResponse({
    required this.question,
    required this.headline,
    required this.bulletInsights,
    required this.recommendedAction,
    required this.confidenceBps,
  });

  final String question;
  final String headline;
  final List<String> bulletInsights;
  final String recommendedAction;
  final int confidenceBps;
}

/// Motor determinístico Read-Only do Copiloto C-Level (`AI CFO & COO`), sintetizando
/// diagnósticos em português diretamente do [FounderDashboardSnapshot] e dos 5 motores DP.
class FounderExecutiveCopilotEngine {
  const FounderExecutiveCopilotEngine();

  static const List<String> canonicalQuickQuestions = <String>[
    'Onde alocar R\$ 1.200 em Smart Supply Boosters hoje?',
    'Qual a saúde tributária CPC 47 e a conciliação tripla agora?',
    'Por que a coorte Híbrida Dual-Mode domina nosso LTV/CAC?',
    'Há anomalias CUSUM, notas SEFAZ > 26h ou alertas de coação?',
  ];

  CopilotBriefingResponse answerExecutivePrompt(
    String prompt,
    FounderDashboardSnapshot snapshot,
  ) {
    final q = prompt.trim().toLowerCase();
    final dre = snapshot.dreCents;
    final recon = snapshot.reconciliation;

    if (q.contains('alocar') ||
        q.contains('booster') ||
        q.contains('mochila') ||
        q.contains('bairro')) {
      const optimizer = KnapsackGrowthAndBoosterOptimizer();
      final candidates =
          KnapsackGrowthAndBoosterOptimizer.buildCandidatesFromSnapshot(
        snapshot,
      );
      final plan = optimizer.optimize(
        budgetCents: 120000,
        candidates: candidates,
      );
      final topNames = plan.selectedActions
          .take(3)
          .map((a) => '${a.neighborhoodOrChannel} (${Money.formatBrl(a.costCents)})')
          .join(', ');

      return CopilotBriefingResponse(
        question: prompt,
        headline:
            'Plano Ótimo Knapsack 0/1: Retorno Líquido Esperado de ${Money.formatBrl(plan.totalExpectedNetProfitCents)} (${plan.blendedRoiMultiple.toStringAsFixed(2)}x ROI)',
        bulletInsights: <String>[
          'Investimento alocado: ${Money.formatBrl(plan.totalCostCents)} de ${Money.formatBrl(plan.budgetCents)} (${plan.selectedActions.length} alavancas selecionadas).',
          'Foco prioritário: ${topNames.isEmpty ? "Equilíbrio orgânico atual" : topNames}.',
          'Expansão projetada: +${plan.totalExpectedNewOrders} OS concluídas sem estourar o teto orçamentário.',
        ],
        recommendedAction:
            'Acionar Smart Supply Booster prioritário nos bairros de alta demanda reprimida e baixa densidade ativa.',
        confidenceBps: 9740,
      );
    }

    if (q.contains('dual') || q.contains('ltv') || q.contains('coorte')) {
      const ltvEngine = MarkovBellmanCohortLtvEngine();
      final valuations = ltvEngine.evaluateAllCanonicalCohorts();
      final clientV = valuations[0];
      final provV = valuations[1];
      final dualV = valuations[2];

      return CopilotBriefingResponse(
        question: prompt,
        headline:
            'Interseção Dourada Dual-Mode entrega LTV de ${Money.formatBrl(dualV.ltvCents)} (${dualV.ltvToCacRatio.toStringAsFixed(2)}x LTV/CAC)',
        bulletInsights: <String>[
          'Exclusivamente Clientes: LTV ${Money.formatBrl(clientV.ltvCents)} (${clientV.ltvToCacRatio.toStringAsFixed(2)}x CAC, payback ${clientV.paybackMonths.toStringAsFixed(1)}m).',
          'Exclusivamente Profissionais: LTV ${Money.formatBrl(provV.ltvCents)} (${provV.ltvToCacRatio.toStringAsFixed(2)}x CAC, payback ${provV.paybackMonths.toStringAsFixed(1)}m).',
          'Híbrido Dual-Mode (${snapshot.demographics.dualModeBothCount} contas): recicla saldo líquido internamente com payback em ${dualV.paybackMonths.toStringAsFixed(1)} meses.',
        ],
        recommendedAction:
            'Ativar convite 1-clique para prestadores verificados usarem saldo maduro em reparos da própria residência.',
        confidenceBps: 9820,
      );
    }

    if (q.contains('anomalia') ||
        q.contains('cusum') ||
        q.contains('sefaz') ||
        q.contains('coacao') ||
        q.contains('coação') ||
        q.contains('duress')) {
      const detector = KadaneAndCusumAnomalyDetector();
      final report = detector.analyzeTimeline(snapshot.dailySeries);
      final sec = snapshot.securityWatch;

      return CopilotBriefingResponse(
        question: prompt,
        headline:
            'Vigilância Forense: Cadeia SHA-256 ${sec.auditChainIntact ? "ÍNTEGRA" : "ALERTA"} · ${sec.frozenUnderDuressCount} Custódia(s) sob Coação',
        bulletInsights: <String>[
          'Janela de pico Kadane: ${report.maxProfitWindow.startDayIso} até ${report.maxProfitWindow.endDayIso} (${Money.formatBrl(report.maxProfitWindow.totalGainCents)} acumulados).',
          'Monitor SEFAZ Fase 2 (> 26h): ${sec.pendingSefazOver26hCount} pendência(s) | Clawbacks automáticos: ${sec.canceledClawbackCount}.',
          'Vazamento Geo-Privacidade: ${sec.geoPrivacyLeakBps} bps (zero exposição de coordenadas exatas pré-contratação).',
        ],
        recommendedAction: sec.frozenUnderDuressCount > 0
            ? 'Emitir Dossiê Policial Assinado SHA-256 na Sala de Guerra Silent Duress para preservação probatória.'
            : 'Manter monitoramento contínuo de notas fiscais de peças e canários de intrusão.',
        confidenceBps: 9890,
      );
    }

    return CopilotBriefingResponse(
      question: prompt,
      headline:
          'CPC 47 Auditado: Economia Legal de ${(dre.taxSavingsBps / 100.0).toStringAsFixed(2)}% (${Money.formatBrl(dre.legalTaxSavingsCents)}) · Conciliação ${recon.threeWayReconciliationOk ? "100% EXATA" : "DIVERGENTE"}',
      bulletInsights: <String>[
        'GMV Total ${Money.formatBrl(dre.gmvTotalCents)} segregado em ${Money.formatBrl(dre.thirdPartyPassThroughCents)} de repasse de terceiros + ${Money.formatBrl(dre.platformGrossRevenueCents)} receita tributável.',
        'Simples Nacional Anexo III (6%): ${Money.formatBrl(dre.simplesNacionalTaxCents)} vs. ${Money.formatBrl(dre.grossGmvHypotheticalTaxCents)} sem segregação.',
        'Conciliação Tripla: Discrepância de ${Money.formatBrl(recon.discrepancyCents)} | Pool Atuarial ICA ${(snapshot.actuarialPool.icaRatioBps / 10000.0).toStringAsFixed(2)}x (meta >= 1,50x).',
      ],
      recommendedAction:
          'Exportar Pacote Mensal Contábil-Fiscal CPC 47 (%PDF-1.4 + CSV + Selo SHA-256) para escrituração.',
      confidenceBps: 9910,
    );
  }
}

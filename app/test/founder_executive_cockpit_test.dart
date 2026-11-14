import 'dart:convert';

import 'package:desperrengue_app/core/analytics/founder_accountant_pack_service.dart';
import 'package:desperrengue_app/core/analytics/founder_dashboard_models.dart';
import 'package:desperrengue_app/core/analytics/founder_dp_optimization_engine.dart';
import 'package:desperrengue_app/features/founder/data/founder_cockpit_repository.dart';
import 'package:desperrengue_app/features/founder/presentation/founder_animations_and_shaders.dart';
import 'package:desperrengue_app/features/founder/presentation/founder_cockpit_screen.dart';
import 'package:desperrengue_app/main_founder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapFounderTestApp({
  required Widget child,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final theme = FounderSovereignTokens.buildTheme();
  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const <Locale>[Locale('pt', 'BR')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      builder: (context, inner) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: textScaler),
          child: inner ?? const SizedBox.shrink(),
        );
      },
      home: child,
    ),
  );
}

void main() {
  // ===========================================================================
  // PILLAR 1: SOVEREIGN EXCLUSIVITY, 3-DELEGATE HARD CAP & KILL-SWITCH (RED-TEAM)
  // ===========================================================================
  group('Pillar 1 — Sovereign Exclusivity & 3-Delegate Kernel Hard Cap', () {
    test('CEO-only initial seat, unauthorized intruder & substring spoof blocked, wrong PIN rejected', () async {
      final repo = FounderCockpitRepository(
        initialSnapshot: FounderDashboardSnapshot.deterministicDemo(daysWindow: 365),
        defaultCeoPin: '202611',
      );

      expect(repo.currentSnapshot.aclSeats.ceoSeat, isNotNull);
      expect(repo.currentSnapshot.aclSeats.ceoSeat!.isActive, isTrue);
      expect(repo.currentSnapshot.aclSeats.activeDelegates, isEmpty);
      expect(repo.currentSnapshot.aclSeats.remainingSlots, equals(3));
      expect(repo.currentSnapshot.aclSeats.isAtHardCap, isFalse);

      // Wrong PIN rejected
      await expectLater(
        () => repo.unlockStepUpVault(
          credentialEmail: 'wagner.ceo@desperrengue.com.br',
          masterPin: '000000',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('ERR_INVALID_MASTER_PIN'),
          ),
        ),
      );

      // Unauthorized external email AND substring spoof ('impostor_ceo@evil.org') blocked with 42501
      for (final badEmail in const <String>[
        'intruder@external-attacker.org',
        'impostor_ceo@evil.org',
        'fake_wagner@evil.org',
      ]) {
        await expectLater(
          () => repo.unlockStepUpVault(
            credentialEmail: badEmail,
            masterPin: '202611',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('ERR_UNAUTHORIZED_FOUNDER_SEAT_42501'),
            ),
          ),
        );
      }

      // Legitimate Sovereign CEO unlocks FULL_SOVEREIGN session
      final ceoSession = await repo.unlockStepUpVault(
        credentialEmail: 'wagner.ceo@desperrengue.com.br',
        masterPin: '202611',
      );
      expect(ceoSession.seatRole, equals(FounderSeatRole.sovereignCeo));
      expect(
        ceoSession.permissionScope,
        equals(FounderPermissionScope.fullSovereign),
      );
      expect(repo.isSessionActive(ceoSession.stepUpCredentialHex), isTrue);
    });

    test(
      'Authorizes Slots 1..3, blocks 4th delegate with ERR_MAX_3_AUTHORIZED_DELEGATES_EXCEEDED, '
      'blocks FULL_SOVEREIGN escalation, and executes immediate Slot 2 Kill-Switch',
      () async {
        final repo = FounderCockpitRepository(
          initialSnapshot: FounderDashboardSnapshot.deterministicDemo(daysWindow: 90),
          defaultCeoPin: '202611',
        );
        final ceoSession = await repo.unlockStepUpVault(
          credentialEmail: 'wagner.ceo@desperrengue.com.br',
          masterPin: '202611',
        );

        // Delegate can NEVER receive FULL_SOVEREIGN
        await expectLater(
          () => repo.authorizeDelegate(
            stepUpCredentialHex: ceoSession.stepUpCredentialHex,
            targetEmail: 'escalated@audit.com.br',
            permissionScope: FounderPermissionScope.fullSovereign,
            initialPin: '654321',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('ERR_DELEGATE_CANNOT_HOLD_FULL_SOVEREIGN'),
            ),
          ),
        );

        // Authorize Slot 1, Slot 2, Slot 3
        await repo.authorizeDelegate(
          stepUpCredentialHex: ceoSession.stepUpCredentialHex,
          targetEmail: 'contador@contabilidade.com.br',
          permissionScope: FounderPermissionScope.financeTaxAuditor,
          initialPin: '611111',
        );
        final afterSlot2 = await repo.authorizeDelegate(
          stepUpCredentialHex: ceoSession.stepUpCredentialHex,
          targetEmail: 'diretor.ops@desperrengue.com.br',
          permissionScope: FounderPermissionScope.operationsSecurity,
          initialPin: '622222',
        );
        final afterSlot3 = await repo.authorizeDelegate(
          stepUpCredentialHex: ceoSession.stepUpCredentialHex,
          targetEmail: 'conselheiro@fundo.com.br',
          permissionScope: FounderPermissionScope.readOnlyAnalytics,
          initialPin: '633333',
        );

        expect(afterSlot3.aclSeats.activeDelegates.length, equals(3));
        expect(afterSlot3.aclSeats.isAtHardCap, isTrue);
        expect(afterSlot3.aclSeats.remainingSlots, equals(0));
        expect(afterSlot3.aclSeats.activeSlotAt(1)?.emailSnapshot, 'contador@contabilidade.com.br');
        expect(afterSlot3.aclSeats.activeSlotAt(2)?.emailSnapshot, 'diretor.ops@desperrengue.com.br');
        expect(afterSlot3.aclSeats.activeSlotAt(3)?.emailSnapshot, 'conselheiro@fundo.com.br');

        // 4th delegate attempt MUST fail hard with ERR_MAX_3_AUTHORIZED_DELEGATES_EXCEEDED
        await expectLater(
          () => repo.authorizeDelegate(
            stepUpCredentialHex: ceoSession.stepUpCredentialHex,
            targetEmail: 'quarto.excedente@audit.com.br',
            permissionScope: FounderPermissionScope.readOnlyAnalytics,
            initialPin: '644444',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('ERR_MAX_3_AUTHORIZED_DELEGATES_EXCEEDED'),
            ),
          ),
        );

        // Slot 2 delegate logs in and obtains active session, but CANNOT manage ACL
        final slot2Seat = afterSlot2.aclSeats.activeSlotAt(2)!;
        final slot2Session = await repo.unlockStepUpVault(
          credentialEmail: 'diretor.ops@desperrengue.com.br',
          masterPin: '622222',
        );
        expect(slot2Session.seatRole, equals(FounderSeatRole.authorizedDelegate));
        expect(
          slot2Session.permissionScope,
          equals(FounderPermissionScope.operationsSecurity),
        );
        expect(repo.isSessionActive(slot2Session.stepUpCredentialHex), isTrue);

        await expectLater(
          () => repo.revokeDelegate(
            stepUpCredentialHex: slot2Session.stepUpCredentialHex,
            targetUserId: afterSlot3.aclSeats.activeSlotAt(1)!.userId,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('ERR_ONLY_SOVEREIGN_CEO_CAN_REVOKE_DELEGATES'),
            ),
          ),
        );

        // Sovereign CEO re-authenticates and fires Kill-Switch on Slot 2
        final ceoSession2 = await repo.unlockStepUpVault(
          credentialEmail: 'wagner.ceo@desperrengue.com.br',
          masterPin: '202611',
        );
        final afterRevoke = await repo.revokeDelegate(
          stepUpCredentialHex: ceoSession2.stepUpCredentialHex,
          targetUserId: slot2Seat.userId,
        );

        expect(afterRevoke.aclSeats.activeDelegates.length, equals(2));
        expect(afterRevoke.aclSeats.activeSlotAt(2), isNull);
        expect(afterRevoke.aclSeats.isAtHardCap, isFalse);

        // Slot 2's active session is IMMEDIATELY dead (0ms tolerance)
        expect(repo.isSessionActive(slot2Session.stepUpCredentialHex), isFalse);
        await expectLater(
          () => repo.fetchCockpitSnapshot(
            stepUpCredentialHex: slot2Session.stepUpCredentialHex,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('ERR_STEPUP_SESSION_REVOKED_OR_EXPIRED'),
            ),
          ),
        );
        await expectLater(
          () => repo.unlockStepUpVault(
            credentialEmail: 'diretor.ops@desperrengue.com.br',
            masterPin: '622222',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('ERR_UNAUTHORIZED_FOUNDER_SEAT_42501'),
            ),
          ),
        );

        // Freed Slot 2 can now welcome a replacement delegate
        final afterReplacement = await repo.authorizeDelegate(
          stepUpCredentialHex: ceoSession2.stepUpCredentialHex,
          targetEmail: 'substituto.seguranca@desperrengue.com.br',
          permissionScope: FounderPermissionScope.operationsSecurity,
          initialPin: '655555',
        );
        expect(afterReplacement.aclSeats.activeDelegates.length, equals(3));
        expect(
          afterReplacement.aclSeats.activeSlotAt(2)?.emailSnapshot,
          equals('substituto.seguranca@desperrengue.com.br'),
        );
      },
    );
  });

  // ===========================================================================
  // PILLAR 2: EXACT 4-GROUP DEMOGRAPHICS, LGPD OFFBOARDING & JSON WIRE PARITY
  // ===========================================================================
  group('Pillar 2 — Exact 4-Group Demographics, Scoped LGPD & Wire Contract', () {
    test('4-group partition invariant + LGPD scoped counters + 33 categories round-trip', () {
      final snap = FounderDashboardSnapshot.deterministicDemo(daysWindow: 365);
      final d = snap.demographics;

      expect(d.onlyClientsCount, greaterThan(0));
      expect(d.onlyProvidersCount, greaterThan(0));
      expect(d.dualModeBothCount, greaterThan(0));
      expect(
        d.onlyClientsCount + d.onlyProvidersCount + d.dualModeBothCount,
        equals(d.totalUsersCount),
      );
      expect(d.partitionInvariantOk, isTrue);

      expect(d.lgpdDeletedClientCount, equals(19));
      expect(d.lgpdDeletedProviderCount, equals(6));
      expect(d.lgpdDeletedAllCount, equals(9));
      expect(d.totalLgpdOffboardings, equals(34));

      // Canonical JSON contract keys (#127)
      final json = snap.toJson();
      expect(json.containsKey('user_demographics'), isTrue);
      expect(json.containsKey('financial_dre_cents'), isTrue);
      expect(json.containsKey('three_way_reconciliation'), isTrue);
      expect(json.containsKey('treasury_and_escrow_cents'), isTrue);
      expect(json.containsKey('actuarial_warranty_pool'), isTrue);
      expect(json.containsKey('category_liquidity_matrix'), isTrue);
      expect(json.containsKey('security_and_sefaz_watch'), isTrue);
      expect(json.containsKey('sovereign_acl_seats'), isTrue);
      expect(json.containsKey('daily_time_series'), isTrue);
      expect(json.containsKey('recent_orders_micro_pnl'), isTrue);

      final decoded = FounderDashboardSnapshot.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(decoded.categoryLiquidity.length, equals(33));
      expect(decoded.demographics.partitionInvariantOk, isTrue);
      expect(decoded.dreCents.gmvTotalCents, equals(snap.dreCents.gmvTotalCents));
      expect(decoded.reconciliation.threeWayReconciliationOk, isTrue);
      expect(decoded.tieredWaterfall.totalMedals, equals(112));
      expect(decoded.tieredWaterfall.providerMedalsTotal, equals(90));
      expect(decoded.tieredWaterfall.clientMedalsTotal, equals(22));
    });
  });

  // ===========================================================================
  // PILLAR 3: BIGINT CPC 47 DRE & THREE-WAY RECONCILIATION (1-CENTAVO PRECISION)
  // ===========================================================================
  group('Pillar 3 — BIGINT CPC 47 DRE & Three-Way Reconciliation', () {
    test('Zero centavo drift across prime/odd labor & material splits + >91% legal tax reduction', () {
      const primeTestCases = <(int, int, int)>[
        (1, 0, 0),
        (3, 7, 0),
        (99, 101, 0),
        (10001, 25003, 0),
        (199999, 349997, 800),
        (2400000, 1800000, 12000),
      ];

      for (final (labor, mat, sos) in primeTestCases) {
        final dre = FounderDreCents.computeFromComponents(
          laborGrossCents: labor,
          materialsExemptCents: mat,
          sosFeeRevenueCents: sos,
          completedOrdersCount: 55,
          fixedOpexCents: 180000,
        );
        expect(
          dre.allAccountingInvariantsOk,
          isTrue,
          reason: 'Invariant drift for labor=$labor, mat=$mat, sos=$sos',
        );
        expect(
          dre.providerNetLaborCents +
              dre.baseLaborFee135Cents +
              dre.warrantyPoolCarveoutCents,
          equals(labor),
        );
      }

      // Verify >91% legal tax reduction under CPC 47 / IFRS 15 when materials are exempt at 0%
      final benchmarkDre = FounderDreCents.computeFromComponents(
        laborGrossCents: 2000000,
        materialsExemptCents: 1600000,
        sosFeeRevenueCents: 0,
        completedOrdersCount: 95,
        fixedOpexCents: 180000,
      );
      expect(benchmarkDre.simplesNacionalTaxCents, equals(16200));
      expect(benchmarkDre.grossGmvHypotheticalTaxCents, equals(216000));
      expect(benchmarkDre.taxSavingsBps, greaterThan(9100));
    });

    test('Three-Way Reconciliation immediately flags any +1 or -1 centavo discrepancy', () {
      const baseCustody = 12610500;
      const settledOut = 14250000;
      const pixConfirmed = baseCustody + settledOut;

      final exact = FounderThreeWayReconciliation.compute(
        pixTopupsConfirmedCents: pixConfirmed,
        ledgerNetSumCents: baseCustody,
        walletsAndEscrowTotalCents: baseCustody,
        cumulativePlatformSettledOutCents: settledOut,
      );
      expect(exact.threeWayReconciliationOk, isTrue);
      expect(exact.discrepancyCents, equals(0));

      for (final delta in const <int>[1, -1]) {
        final pertPix = FounderThreeWayReconciliation.compute(
          pixTopupsConfirmedCents: pixConfirmed + delta,
          ledgerNetSumCents: baseCustody,
          walletsAndEscrowTotalCents: baseCustody,
          cumulativePlatformSettledOutCents: settledOut,
        );
        expect(pertPix.threeWayReconciliationOk, isFalse);
        expect(pertPix.discrepancyCents.abs(), equals(1));

        final pertLedger = FounderThreeWayReconciliation.compute(
          pixTopupsConfirmedCents: pixConfirmed,
          ledgerNetSumCents: baseCustody + delta,
          walletsAndEscrowTotalCents: baseCustody,
          cumulativePlatformSettledOutCents: settledOut,
        );
        expect(pertLedger.threeWayReconciliationOk, isFalse);
        expect(pertLedger.discrepancyCents.abs(), equals(1));

        final pertWallets = FounderThreeWayReconciliation.compute(
          pixTopupsConfirmedCents: pixConfirmed,
          ledgerNetSumCents: baseCustody,
          walletsAndEscrowTotalCents: baseCustody + delta,
          cumulativePlatformSettledOutCents: settledOut,
        );
        expect(pertWallets.threeWayReconciliationOk, isFalse);
        expect(pertWallets.discrepancyCents.abs(), equals(1));
      }
    });
  });

  // ===========================================================================
  // PILLAR 4: ALL 5 DP ENGINES + MONTE CARLO (1,000) + %PDF-1.4 & SHA-256 PACKS
  // ===========================================================================
  group('Pillar 4 — 5 Dynamic Programming Engines, Off-Thread Monte Carlo & %PDF-1.4 Packs', () {
    final snapshot = FounderDashboardSnapshot.deterministicDemo(daysWindow: 365);

    test('DP 1 (PrefixSumFinancialTimeline) answers 7d/30d/90d/365d & arbitrary ranges in O(1) with 0 drift', () {
      final timeline = PrefixSumFinancialTimeline(snapshot.dailySeries);
      expect(timeline.length, equals(365));

      for (final window in const <int>[7, 30, 90, 365]) {
        final fast = timeline.queryLastDays(window);
        final slice = snapshot.dailySeries.sublist(365 - window);
        expect(fast.daysCount, equals(window));
        expect(fast.ordersCount, equals(slice.fold<int>(0, (s, e) => s + e.ordersCount)));
        expect(fast.gmvCents, equals(slice.fold<int>(0, (s, e) => s + e.gmvCents)));
        expect(fast.netProfitCents, equals(slice.fold<int>(0, (s, e) => s + e.netProfitCents)));
      }

      for (var s = 0; s < 365; s += 37) {
        for (var e = s; e < 365; e += 53) {
          final fast = timeline.queryRange(s, e);
          var naiveGmv = 0;
          var naiveProfit = 0;
          for (var k = s; k <= e; k++) {
            naiveGmv += snapshot.dailySeries[k].gmvCents;
            naiveProfit += snapshot.dailySeries[k].netProfitCents;
          }
          expect(fast.gmvCents, equals(naiveGmv));
          expect(fast.netProfitCents, equals(naiveProfit));
        }
      }
    });

    test('DP 2 (KnapsackGrowthAndBoosterOptimizer) matches exact brute-force 2^N global optimum', () {
      const optimizer = KnapsackGrowthAndBoosterOptimizer();
      final candidates = KnapsackGrowthAndBoosterOptimizer.buildCandidatesFromSnapshot(snapshot);
      const budgetCents = 120000;

      final plan = optimizer.optimize(
        budgetCents: budgetCents,
        candidates: candidates,
      );
      expect(plan.budgetConstraintSatisfied, isTrue);
      expect(plan.totalCostCents, lessThanOrEqualTo(budgetCents));
      expect(
        plan.selectedActions.length + plan.rejectedActions.length,
        equals(candidates.length),
      );

      final n = candidates.length;
      var bruteBestProfit = 0;
      for (var mask = 0; mask < (1 << n); mask++) {
        var cost = 0;
        var profit = 0;
        for (var i = 0; i < n; i++) {
          if ((mask & (1 << i)) != 0) {
            cost += candidates[i].costCents;
            profit += candidates[i].expectedNetProfitCents;
          }
        }
        if (cost <= budgetCents && profit > bruteBestProfit) {
          bruteBestProfit = profit;
        }
      }
      expect(plan.totalExpectedNetProfitCents, equals(bruteBestProfit));
    });

    test('DP 3 (MarkovBellmanCohortLtvEngine) converges & proves Dual-Mode LTV/CAC dominance', () {
      const engine = MarkovBellmanCohortLtvEngine();
      final valuations = engine.evaluateAllCanonicalCohorts();
      expect(valuations.length, equals(3));

      final onlyClient = valuations[0];
      final onlyProvider = valuations[1];
      final dualHybrid = valuations[2];

      for (final v in valuations) {
        expect(v.maxBellmanResidual, lessThan(1e-6));
        expect(v.stateValuesCents[3], equals(0));
      }

      expect(dualHybrid.ltvCents, greaterThan(onlyProvider.ltvCents));
      expect(onlyProvider.ltvCents, greaterThan(onlyClient.ltvCents));
      expect(dualHybrid.ltvToCacRatioBps, greaterThan(onlyProvider.ltvToCacRatioBps));
      expect(dualHybrid.ltvToCacRatioBps, greaterThan(onlyClient.ltvToCacRatioBps));
      expect(dualHybrid.paybackMonths, lessThan(onlyClient.paybackMonths));
    });

    test('DP 4 (KadaneAndCusumAnomalyDetector) matches O(T^2) max subarray & detects CUSUM shocks', () {
      const detector = KadaneAndCusumAnomalyDetector();
      const sample = <int>[-4200, 3100, -900, 6400, 5200, -12000, 4800, 1900, -500];
      final kadane = detector.runKadane(sample);

      var bruteBest = sample.first;
      for (var i = 0; i < sample.length; i++) {
        var acc = 0;
        for (var j = i; j < sample.length; j++) {
          acc += sample[j];
          if (acc > bruteBest) bruteBest = acc;
        }
      }
      expect(kadane.totalGainCents, equals(bruteBest));
      expect(kadane.startIndex, equals(1));
      expect(kadane.endIndex, equals(4));

      final shockedSeries = List<FounderDailyMetricPoint>.generate(
        snapshot.dailySeries.length,
        (i) {
          final base = snapshot.dailySeries[i];
          if (i >= 180 && i <= 185) {
            return FounderDailyMetricPoint(
              dayIso: base.dayIso,
              ordersCount: base.ordersCount,
              gmvCents: base.gmvCents,
              laborCents: base.laborCents,
              materialsExemptCents: base.materialsExemptCents,
              platformRevenueCents: base.platformRevenueCents,
              poolCarveoutCents: base.poolCarveoutCents,
              taxDasCents: base.taxDasCents,
              variableCostCents: base.variableCostCents,
              netProfitCents: -95000,
              warrantyClaimsCents: 120000,
            );
          }
          return base;
        },
      );
      final report = detector.analyzeTimeline(shockedSeries);
      expect(report.driftAlerts, isNotEmpty);
      expect(
        report.driftAlerts.any((a) => a.direction == CusumDriftDirection.downwardDrop),
        isTrue,
      );
      expect(
        report.driftAlerts.any((a) => a.direction == CusumDriftDirection.upwardSurge),
        isTrue,
      );
    });

    test('DP 5 (AntiBypassAndLeakageDetector) catches obfuscated leetspeak, post-chat cancel & split distortion', () {
      const detector = AntiBypassAndLeakageDetector();

      final evasive = detector.evaluateRisk(
        chatSnippet: 'm3 ch4m4 n0 z.4.p nove nove oito sete seis cinco quatro tres p.i.x f0r4 d0 4pp',
        cancelledWithinMinutesAfterChat: 9,
        laborCents: 2000,
        materialsExemptCents: 28000,
        hasVerified44DigitNfe: false,
      );
      expect(evasive.severity, equals(BypassSeverity.criticalBlock));
      expect(evasive.compositeRiskBps, greaterThanOrEqualTo(7500));
      expect(evasive.smartSplitDistortionDetected, isTrue);
      expect(evasive.rapidPostChatCancellationDetected, isTrue);
      expect(evasive.disguisedDigitsCount, greaterThanOrEqualTo(8));

      final clean = detector.evaluateRisk(
        chatSnippet: 'Instalei o disjuntor bipolar no quadro interno e anexei a foto de conclusão.',
        cancelledWithinMinutesAfterChat: null,
        laborCents: 22000,
        materialsExemptCents: 14000,
        hasVerified44DigitNfe: true,
      );
      expect(clean.severity, equals(BypassSeverity.low));
      expect(clean.smartSplitDistortionDetected, isFalse);
      expect(clean.rapidPostChatCancellationDetected, isFalse);
    });

    test('Monte Carlo (1,000 runs off-thread) is deterministic & monotonic + Copilot answers all domains', () async {
      final params = FounderMonteCarloParams.fromSnapshot(snapshot).copyWith(
        trajectoriesCount: 1000,
        horizonMonths: 12,
        seed: 0x20261114,
      );
      final runA = await runMonteCarloSimulationOffThread(params);
      final runB = await runMonteCarloSimulationOffThread(params);

      expect(runA.trajectoriesCount, equals(1000));
      expect(runA.horizonMonths, equals(12));
      expect(runA.p50CashCents, equals(runB.p50CashCents));
      expect(runA.terminalMedianCashCents, equals(runB.terminalMedianCashCents));

      for (var m = 0; m < 12; m++) {
        expect(runA.p10CashCents[m], lessThanOrEqualTo(runA.p50CashCents[m]));
        expect(runA.p50CashCents[m], lessThanOrEqualTo(runA.p90CashCents[m]));
      }

      const copilot = FounderExecutiveCopilotEngine();
      for (final q in FounderExecutiveCopilotEngine.canonicalQuickQuestions) {
        final ans = copilot.answerExecutivePrompt(q, snapshot);
        expect(ans.headline, isNotEmpty);
        expect(ans.bulletInsights.length, greaterThanOrEqualTo(3));
        expect(ans.confidenceBps, greaterThan(9500));
      }
    });

    test('CPC 47 %PDF-1.4 + RFC-4180 CSV + Duress Police Dossier verify SHA-256 & detect 1-byte tampering', () async {
      const service = FounderAccountantPackService();

      final pack = await service.generateMonthlyPackOffThread(
        snapshot,
        competenceLabel: '2026-11',
        csvDelimiter: ';',
      );
      final pdfHeader = ascii.decode(pack.pdfBytes.sublist(0, 8));
      final pdfTail = ascii.decode(pack.pdfBytes.sublist(pack.pdfBytes.length - 6));
      expect(pdfHeader, equals('%PDF-1.4'));
      expect(pdfTail, contains('%%EOF'));
      expect(pack.sha256SealHex.length, equals(64));
      expect(pack.csvContent, contains('CONSOLIDADO_CPC47_MENSAL;2026-11'));
      expect(pack.verifyIntegrity(), isTrue);

      final tamperedPdf = Uint8List.fromList(pack.pdfBytes);
      tamperedPdf[tamperedPdf.length ~/ 2] ^= 0xFF;
      final tamperedPack = MonthlyAccountantPackArtifact(
        competenceLabel: pack.competenceLabel,
        generatedAtUtc: pack.generatedAtUtc,
        pdfBytes: tamperedPdf,
        csvContent: pack.csvContent,
        sha256SealHex: pack.sha256SealHex,
        pdfSha256Hex: pack.pdfSha256Hex,
        csvSha256Hex: pack.csvSha256Hex,
        canonicalPayloadToSign: pack.canonicalPayloadToSign,
        summaryMetricsCents: pack.summaryMetricsCents,
      );
      expect(tamperedPack.verifyIntegrity(), isFalse);

      final incident = snapshot.securityWatch.duressIncidents.first;
      final dossier = await service.generateDuressPoliceDossierOffThread(
        incident,
        authorizedByEmail: 'wagner.ceo@desperrengue.com.br',
      );
      expect(ascii.decode(dossier.pdfBytes.sublist(0, 8)), equals('%PDF-1.4'));
      expect(dossier.verifyIntegrity(), isTrue);
      expect(dossier.chainOfCustodyJson, contains('FROZEN_UNDER_DURESS'));
      expect(dossier.chainOfCustodyJson, contains('"exact_coordinates_redacted": true'));
      expect(dossier.chainOfCustodyJson, contains('wa***@desperrengue.com.br'));

      final tamperedDossierBytes = Uint8List.fromList(dossier.pdfBytes);
      tamperedDossierBytes[42] ^= 0x01;
      final badDossier = DuressForensicDossierArtifact(
        incidentId: dossier.incidentId,
        orderCode: dossier.orderCode,
        generatedAtUtc: dossier.generatedAtUtc,
        pdfBytes: tamperedDossierBytes,
        chainOfCustodyJson: dossier.chainOfCustodyJson,
        sha256SealHex: dossier.sha256SealHex,
        pdfSha256Hex: dossier.pdfSha256Hex,
        canonicalManifestPayload: dossier.canonicalManifestPayload,
      );
      expect(badDossier.verifyIntegrity(), isFalse);
    });
  });

  // ===========================================================================
  // PILLAR 5: FULL WIDGET, INTERACTIVE FLOWS & MULTI-VIEWPORT TORTURE SUITE
  // ===========================================================================
  group('Pillar 5 — Vault Flow, Blur Guards, 10 Charts, 7 Innovations & Multi-Viewport Torture', () {
    testWidgets(
      'Step-Up Vault lock -> wrong PIN error -> unlock -> Space/Eye Privacy Blur (EditableText guard) -> 10m Auto-Lock',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = FounderCockpitRepository(
          initialSnapshot: FounderDashboardSnapshot.deterministicDemo(daysWindow: 30),
          defaultCeoPin: '202611',
        );

        await tester.pumpWidget(
          _wrapFounderTestApp(
            child: FounderCockpitScreen(
              repository: repo,
              inactivityTimeout: const Duration(minutes: 10),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey<String>('founder-stepup-vault-card')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('founder-widescreen-3col-layout')), findsNothing);

        // Wrong PIN surfaces vault-error-banner
        await tester.enterText(
          find.byKey(const ValueKey<String>('vault-pin-field')),
          '000000',
        );
        await tester.tap(find.byKey(const ValueKey<String>('vault-unlock-button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey<String>('vault-error-banner')), findsOneWidget);
        expect(find.textContaining('ERR_INVALID_MASTER_PIN'), findsOneWidget);

        // Valid CEO PIN unlocks 3-column panoramic command center
        await tester.enterText(
          find.byKey(const ValueKey<String>('vault-pin-field')),
          '202611',
        );
        await tester.tap(find.byKey(const ValueKey<String>('vault-unlock-button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey<String>('founder-widescreen-3col-layout')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('founder-privacy-active-badge')), findsNothing);

        // Toggle Privacy Blur ON via TopBar Eye button
        await tester.tap(find.byKey(const ValueKey<String>('founder-privacy-blur-toggle')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey<String>('founder-privacy-active-badge')), findsOneWidget);

        // Toggle Privacy Blur OFF via Space key when NOT focused inside EditableText
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey<String>('founder-privacy-active-badge')), findsNothing);

        // Focus inside Copilot TextField -> pressing Space MUST NOT trigger Privacy Blur
        final promptField = find.byKey(const ValueKey<String>('copilot-prompt-field'));
        await tester.ensureVisible(promptField);
        await tester.tap(promptField);
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(find.byKey(const ValueKey<String>('founder-privacy-active-badge')), findsNothing);

        // Auto-lock after 10 minutes of inactivity
        await tester.pump(const Duration(minutes: 10, seconds: 2));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey<String>('founder-stepup-vault-card')), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'Widescreen 1440x900 renders all 10 CustomPainter charts, exercises Innovations & 3-Slot ACL Kill-Switch with ZERO overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final snap = FounderDashboardSnapshot.deterministicDemo(daysWindow: 365);
        final repo = FounderCockpitRepository(initialSnapshot: snap);

        await tester.pumpWidget(
          _wrapFounderTestApp(
            child: FounderCockpitScreen(
              repository: repo,
              initialUnlockedSnapshot: snap,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        const allTenChartKeys = <String>[
          'founder-chart-1-sankey',
          'founder-chart-2-jcurve',
          'founder-chart-3-demographics-venn',
          'founder-chart-4-aarrr-funnel',
          'founder-chart-5-category-bubbles',
          'founder-chart-6-treasury-histogram',
          'founder-chart-7-actuarial-speedometer',
          'founder-chart-8-cohort-heatmap',
          'founder-chart-9-kyc-thermometer',
          'founder-chart-10-waterfall-medals',
        ];
        for (final k in allTenChartKeys) {
          expect(find.byKey(ValueKey<String>(k)), findsOneWidget, reason: 'Missing chart $k');
        }

        const allSevenInnovationKeys = <String>[
          'founder-innovation-1-bivariate-heatmap',
          'founder-innovation-2-micro-pnl',
          'founder-innovation-3-monte-carlo',
          'founder-innovation-4-copilot',
          'founder-innovation-5-antibypass-sefaz',
          'founder-innovation-6-accountant-pack',
          'founder-innovation-7-duress-war-room',
        ];
        for (final k in allSevenInnovationKeys) {
          expect(find.byKey(ValueKey<String>(k)), findsOneWidget, reason: 'Missing innovation $k');
        }

        // Switch J-Curve window chips
        final chip90d = find.byKey(const ValueKey<String>('jcurve-window-90d'));
        await tester.ensureVisible(chip90d);
        await tester.tap(chip90d);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Trigger Smart Supply Booster (Knapsack 0/1)
        final boosterBtn = find.byKey(const ValueKey<String>('innovation-1-trigger-booster-btn'));
        await tester.ensureVisible(boosterBtn);
        await tester.tap(boosterBtn);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey<String>('innovation-1-knapsack-result')), findsOneWidget);

        // Trigger Off-Thread CPC 47 Monthly Pack & Duress Police Dossier
        final exportPackBtn = find.byKey(const ValueKey<String>('export-cpc47-pack-btn'));
        await tester.ensureVisible(exportPackBtn);
        await tester.runAsync(() async {
          await tester.tap(exportPackBtn);
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey<String>('accountant-pack-seal-box')), findsOneWidget);

        final duressBtn = find.byKey(const ValueKey<String>('generate-duress-dossier-btn'));
        await tester.ensureVisible(duressBtn);
        await tester.runAsync(() async {
          await tester.tap(duressBtn);
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey<String>('duress-dossier-seal-box')), findsOneWidget);

        // Exercise Sovereign ACL 3-Slot Authorization -> Hard Cap Lock Banner -> Kill-Switch
        final emailField = find.byKey(const ValueKey<String>('acl-delegate-email-field'));
        final authBtn = find.byKey(const ValueKey<String>('acl-authorize-button'));
        for (final email in const <String>[
          'slot1@audit.com.br',
          'slot2@ops.com.br',
          'slot3@board.com.br',
        ]) {
          await tester.ensureVisible(emailField);
          await tester.enterText(emailField, email);
          await tester.ensureVisible(authBtn);
          await tester.tap(authBtn);
          await tester.pumpAndSettle();
        }
        expect(find.byKey(const ValueKey<String>('acl-hard-cap-kernel-banner')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('acl-kill-switch-slot-2')), findsOneWidget);

        // Fire Kill-Switch on Slot 2
        final killSlot2 = find.byKey(const ValueKey<String>('acl-kill-switch-slot-2'));
        await tester.ensureVisible(killSlot2);
        await tester.tap(killSlot2);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey<String>('acl-hard-cap-kernel-banner')), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'Pocket 6-Tab Torture Suite across 320x700 @ 1.4x textScaler AND 480x900 with ZERO RenderFlex overflow',
      (WidgetTester tester) async {
        final viewports = <({Size size, TextScaler scaler, String label})>[
          (
            size: const Size(320, 700),
            scaler: const TextScaler.linear(1.4),
            label: '320x700 @ 1.4x torture',
          ),
          (
            size: const Size(480, 900),
            scaler: TextScaler.noScaling,
            label: '480x900 mobile pocket',
          ),
        ];

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        for (final vp in viewports) {
          tester.view.physicalSize = vp.size;
          tester.view.devicePixelRatio = 1.0;

          final snap = FounderDashboardSnapshot.deterministicDemo(daysWindow: 30);
          await tester.pumpWidget(
            _wrapFounderTestApp(
              textScaler: vp.scaler,
              child: FounderCockpitScreen(initialUnlockedSnapshot: snap),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Overflow on initial tab 0 (${vp.label})',
          );
          expect(find.byKey(const ValueKey<String>('founder-pocket-6tab-layout')), findsOneWidget);

          for (var tabIdx = 0; tabIdx < 6; tabIdx++) {
            final tabFinder = find.byKey(ValueKey<String>('founder-tab-$tabIdx'));
            await tester.ensureVisible(tabFinder);
            await tester.tap(tabFinder);
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'Overflow on pocket tab $tabIdx (${vp.label})',
            );
          }
        }

        // Smoke-pump DesperrengueFounderApp root entrypoint (main_founder.dart)
        tester.view.physicalSize = const Size(480, 900);
        await tester.pumpWidget(const ProviderScope(child: DesperrengueFounderApp()));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey<String>('founder-stepup-vault-card')), findsOneWidget);
        expect(find.byType(FounderSovereignCrest), findsWidgets);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'FounderSovereignCrest renders G1 Casa-Escudo D + 4-Facet Apex Diamond Keystone + Cyan Check cleanly across CEO & Delegate modes',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrapFounderTestApp(
            child: const Scaffold(
              body: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FounderSovereignCrest(
                      key: ValueKey<String>('crest-ceo-24'),
                      size: 24,
                      isSovereignCeo: true,
                    ),
                    SizedBox(width: 12),
                    FounderSovereignCrest(
                      key: ValueKey<String>('crest-ceo-96'),
                      size: 96,
                      isSovereignCeo: true,
                    ),
                    SizedBox(width: 12),
                    FounderSovereignCrest(
                      key: ValueKey<String>('crest-delegate-48'),
                      size: 48,
                      isSovereignCeo: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey<String>('crest-ceo-24')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('crest-ceo-96')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('crest-delegate-48')), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const ValueKey<String>('crest-ceo-96'))),
          equals(const Size(96, 96)),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}

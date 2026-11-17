import 'dart:convert';

import 'package:desperrengue_app/core/analytics/founder_accountant_pack_service.dart';
import 'package:desperrengue_app/core/analytics/founder_dashboard_models.dart';
import 'package:desperrengue_app/core/analytics/founder_dp_optimization_engine.dart';
import 'package:desperrengue_app/core/services/legal_mandate_service.dart';
import 'package:desperrengue_app/features/auth/presentation/verificacao_step6c_termos.dart';
import 'package:desperrengue_app/features/founder/data/founder_cockpit_repository.dart';
import 'package:desperrengue_app/features/founder/presentation/founder_animations_and_shaders.dart';
import 'package:desperrengue_app/features/founder/presentation/founder_treasury_and_slu_widgets.dart';
import 'package:desperrengue_app/features/founder/presentation/founder_update_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'founder_executive_cockpit_test.dart' show FakeCeoBackendGateway;

Widget _wrapHost(
  Widget child, {
  TextScaler scaler = TextScaler.noScaling,
  EdgeInsets viewPadding = const EdgeInsets.only(top: 28, bottom: 48),
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
          data: mq.copyWith(
            textScaler: scaler,
            viewPadding: viewPadding,
            padding: viewPadding,
          ),
          child: Scaffold(body: inner ?? const SizedBox.shrink()),
        );
      },
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Suíte Red Team 12 Rodadas — Tesouraria Bivalente, Quant & Ponte Cross-App', () {
    test('Round 1 — Trava física Zero-Digitação PIX rejeita qualquer chave extra injetada', () async {
      final gw = FakeCeoBackendGateway(pbkdf2Iterations: 1200);
      final res = await gw.invokeTreasuryAuthority(<String, dynamic>{
        'action': 'request_profit_distribution',
        'stepup_token': 'a' * 64,
        'device_hash': 'b' * 64,
        'requested_cents': 5000,
        'pix_key': 'invasor@fraude.com',
      });
      expect(res['ok'], isFalse);
      expect(res['error_code'], equals('ERR_FORBIDDEN_DESTINATION_OVERRIDE'));
      expect(
        gw.recordedCanaryCodes,
        contains('EDGE_FORBIDDEN_DESTINATION_OVERRIDE'),
      );
    });

    test('Round 2 — Equação de Teto Seguro bloqueia 1 centavo acima do teto e protege 85% + 1,5%', () async {
      const bt = CeoBivalentTreasuryState(
        operatingMode: 'SANDBOX_PRE_CNPJ',
        settlementPsp: 'ASAAS_SANDBOX',
        sluLegalName: 'HOMOLOGACAO PRE-CNPJ',
        sluCnpjConfigured: false,
        solePartnerCpfConfigured: false,
        cnaePrimary: '6319-4/00',
        cnaeSecondary: '8211-3/00',
        beneficiaryFullName: 'Wagner Oliveira',
        destinationLockMode: 'LOCKED_SOLE_PARTNER_CPF_ACCOUNT',
        allowTypedPixKeys: false,
        bankDisplayLabel: 'Conta Pessoa Física Titular Único',
        duressModeStatus: 'NORMAL',
        cumulativePlatformRevenue135Cents: 50000,
        untouchableCustodyTotalCents: 310000,
        providerCustody85Cents: 280000,
        clientEscrowAndWalletsCents: 25000,
        activeExecutionEscrowCents: 0,
        materialsExempt0PctCents: 40000,
        warrantyPool15Cents: 5000,
        das6PctUnpaidProvisionCents: 3000,
        das6PctPaidCents: 0,
        corporateExpensesPaidCents: 5000,
        corporateExpensesScheduledCents: 2000,
        priorDistributionsCents: 0,
        safetyBufferCents: 30000,
        withdrawableProfitCents: 10000, // R$ 100,00 exatos
        reconciliationDiscrepancyCents: 0,
        blockedReason: 'NONE',
      );

      final gw = FakeCeoBackendGateway(
        pbkdf2Iterations: 1200,
        initialSnapshot: FounderDashboardSnapshot.emptyZero().copyWith(
          bivalentTreasury: bt,
        ),
      );
      final repo = FounderCockpitRepository(gateway: gw, pbkdf2Iterations: 1200);
      addTearDown(repo.dispose);
      await gw.preSealAndUnlockForTest(repo: repo);

      // Tentativa de sacar 1 centavo acima (10.001 > 10.000) -> bloqueio imediato!
      await expectLater(
        () => repo.requestProfitDistribution(requestedCents: 10001),
        throwsA(
          isA<CeoVaultSecurityException>().having(
            (e) => e.errorCode,
            'errorCode',
            equals('ERR_SAFE_CEILING_EXCEEDED'),
          ),
        ),
      );

      // Saque exato dentro do teto (10.000) -> aprovado e reduz teto restante para 0!
      final okRes = await repo.requestProfitDistribution(requestedCents: 10000);
      expect(okRes['ok'], isTrue);
      expect(repo.currentSnapshot.bivalentTreasury.withdrawableProfitCents, equals(0));
      // Custódia de terceiros (R$ 3.100,00) permanece 100% intocada!
      expect(
        repo.currentSnapshot.bivalentTreasury.untouchableCustodyTotalCents,
        equals(310000),
      );
    });

    test('Round 3 — Knapsack 0/1 e Monte Carlo imunes a custo negativo, banco zerado e overflow 32-bit', () {
      final zeroSnap = FounderDashboardSnapshot.emptyZero();
      expect(
        KnapsackGrowthAndBoosterOptimizer.buildCandidatesFromSnapshot(zeroSnap),
        isEmpty,
      );

      const opt = KnapsackGrowthAndBoosterOptimizer();
      final plan = opt.optimize(
        budgetCents: 0,
        candidates: const <KnapsackActionCandidate>[
          KnapsackActionCandidate(
            id: 'neg_attack',
            title: 'Ataque custo negativo',
            neighborhoodOrChannel: 'Teste',
            kind: KnapsackActionKind.growthChannel,
            costCents: -5000,
            expectedNetProfitCents: 999999,
          ),
          KnapsackActionCandidate(
            id: 'zero_legit',
            title: 'Ação orgânica custo zero',
            neighborhoodOrChannel: 'Interno',
            kind: KnapsackActionKind.retentionAutomation,
            costCents: 0,
            expectedNetProfitCents: 4500,
          ),
        ],
      );
      expect(plan.selectedActions.map((a) => a.id), equals(<String>['zero_legit']));
      expect(plan.totalCostCents, equals(0));

      final mcZero = runMonteCarloSimulationSync(
        FounderMonteCarloParams.fromSnapshot(zeroSnap),
      );
      expect(mcZero.p50CashCents.last, equals(0));
      expect(mcZero.terminalMedianIcaBps, equals(15000));
    });

    test('Round 4 — Orçamento alto no Knapsack nunca perde item único exato por arredondamento de teto', () {
      const opt = KnapsackGrowthAndBoosterOptimizer();
      final plan = opt.optimize(
        budgetCents: 500000000,
        stepCents: 1,
        candidates: const <KnapsackActionCandidate>[
          KnapsackActionCandidate(
            id: 'exact_fit',
            title: 'Expansão Regional Exata',
            neighborhoodOrChannel: 'Sul de Minas',
            kind: KnapsackActionKind.b2bPartnership,
            costCents: 500000000,
            expectedNetProfitCents: 1200000000,
          ),
          KnapsackActionCandidate(
            id: 'small_filler',
            title: 'Ação menor',
            neighborhoodOrChannel: 'Bairro',
            kind: KnapsackActionKind.supplyBooster,
            costCents: 137,
            expectedNetProfitCents: 500,
          ),
        ],
      );
      expect(plan.budgetConstraintSatisfied, isTrue);
      expect(plan.totalExpectedNetProfitCents, equals(1200000000));
    });

    test('Round 5 — FROZEN_UNDER_DURESS emite comprovante dissimulado sem vazar strings sensíveis nem mover caixa', () async {
      final duressBt = CeoBivalentTreasuryState.fromJson(
        <String, dynamic>{
          ...const CeoBivalentTreasuryState.emptyZero().toJson(),
          'duress_mode_status': 'FROZEN_UNDER_DURESS',
          'withdrawable_profit_cents': 0,
        },
      );
      final gw = FakeCeoBackendGateway(
        pbkdf2Iterations: 1200,
        initialSnapshot: FounderDashboardSnapshot.emptyZero().copyWith(
          bivalentTreasury: duressBt,
        ),
      );
      final repo = FounderCockpitRepository(gateway: gw, pbkdf2Iterations: 1200);
      addTearDown(repo.dispose);
      await gw.preSealAndUnlockForTest(repo: repo);

      final decoy = await repo.requestProfitDistribution(requestedCents: 25000);
      expect(decoy['ok'], isTrue);
      expect(decoy['settlement_status'], equals('COMPLETED'));
      final encoded = jsonEncode(decoy).toLowerCase();
      expect(encoded.contains('duress'), isFalse);
      expect(encoded.contains('falso'), isFalse);
      expect(
        gw.recordedCanaryCodes,
        contains('CEO_TREASURY_DURESS_DECOY_ISSUED'),
      );
    });

    test('Round 6 — Anti-CSV Formula Injection neutraliza células maliciosas (=CMD, +SUM, @IMPORT) preservando inteiros negativos', () {
      final snap = FounderDashboardSnapshot.emptyZero(
        generatedAt: DateTime.utc(2026, 11, 1, 1, 30), // 2026-10-31 22:30 BRT!
      ).copyWith(
        dreCents: FounderDreCents.computeFromComponents(
          laborGrossCents: 10000,
          materialsExemptCents: 0,
          sosFeeRevenueCents: 0,
          completedOrdersCount: 1,
          fixedOpexCents: 5000, // gera netProfit negativo legitimo (-3731)
        ),
        recentOrdersMicroPnl: <OrderMicroPnlRecord>[
          OrderMicroPnlRecord(
            orderCode: '#DESP-CSV1',
            jobId: 'job-csv-1',
            title: '=HYPERLINK("http://evil.org")',
            categoryName: '=CMD|\' /C calc\'!A0',
            neighborhood: '@SUM(1+1)',
            createdAt: DateTime.utc(2026, 10, 31, 20),
            status: 'completed',
            clientName: 'Cliente Real',
            providerName: 'Profissional Real',
            gmvCents: 10000,
            laborCents: 10000,
            materialsExemptCents: 0,
            nfeVerified: false,
            providerNetCents: 8500,
            platformFeeCents: 1350,
            poolCarveoutCents: 150,
            taxDasCents: 81,
            pixCloudCostCents: 0,
            netMarginCents: 1269,
            escrowStatus: 'RELEASED_TO_MATURATION',
          ),
        ],
      );

      const svc = FounderAccountantPackService();
      final pack = svc.generateMonthlyPackSync(snap);
      // Fronteira BRT: 01/11 01:30 UTC == 31/10 22:30 BRT -> competência 2026-10!
      expect(pack.competenceLabel, equals('2026-10'));
      expect(pack.csvContent, contains("'=CMD|"));
      expect(pack.csvContent, contains("'@SUM(1+1)"));
      expect(pack.csvContent, contains(';-3731;')); // inteiro negativo contábil preservado sem aspas!
      expect(pack.verifyIntegrity(), isTrue);
    });

    test('Round 7 — Dossiê Policial Forense usa carimbo UTC real (sem data hardcoded) e valida SHA-256', () {
      const svc = FounderAccountantPackService();
      final inc = DuressIncidentRecord(
        incidentId: 'DUR-TEST0001',
        orderCode: '#DESP-DUR01',
        jobId: 'job-dur-1',
        triggeredAt: DateTime.utc(2026, 11, 16, 22, 0),
        frozenAmountCents: 35000,
        custodyStatus: 'FROZEN_UNDER_DURESS',
        maskedVictimRole: 'PRESTADOR_CREDENCIADO',
        maskedAccountRef: 'USR-ABCD-****',
        coarseNeighborhood: 'Centro · Poços de Caldas',
        deviceIntegrityHash: 'c' * 64,
        ledgerFreezeTxId: 'LEDGER-FRZ-0001',
        evidenceChainHashes: <String>['d' * 64],
      );
      final before = DateTime.now().toUtc().subtract(const Duration(seconds: 2));
      final dossier = svc.generateDuressPoliceDossierSync(inc);
      expect(dossier.generatedAtUtc.isAfter(before), isTrue);
      expect(dossier.verifyIntegrity(), isTrue);
    });

    test('Round 8 — OTA Soberano bloqueia digest SHA-256 malformado e limpa marca legada 202.6M', () async {
      final installer = FounderNativeOtaInstaller(isAndroidOverride: true);
      addTearDown(installer.dispose);

      await installer.downloadAndInstall(
        const FounderUpdateInfo(
          version: '2.19.0',
          build: 239914800,
          currentBuild: 239914750,
          apkUrl:
              'https://github.com/org/repo/releases/download/beta-latest/desperrengue-founder-ceo.apk',
          sha256: 'NOT_A_VALID_64_HEX_SHA256',
        ),
      );
      expect(installer.progressNotifier.value.phase, equals(FounderOtaInstallPhase.error));
      expect(
        installer.progressNotifier.value.errorMessage,
        contains('bloqueada por segurança'),
      );
    });

    test('Round 9 — Cláusula-Mandato Art. 653 gera selo SHA-256 determinístico de 64 hexadecimais', () {
      final hash1 = LegalMandateService.currentDocumentSha256Hex;
      final hash2 = LegalMandateService.currentDocumentSha256Hex;
      expect(hash1, equals(hash2));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash1), isTrue);
      expect(LegalMandateService.canonicalFullText, contains('85,0%'));
      expect(LegalMandateService.canonicalFullText, contains('13,5%'));
      expect(LegalMandateService.canonicalFullText, contains('1,5%'));
      expect(LegalMandateService.canonicalFullText, contains('653'));
    });

    testWidgets('Round 10 — Tela pública de Termos e Mandato Legal renderiza todas as 5 cláusulas e o selo SHA-256', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: VerificacaoStep6cTermosScreen()),
      );
      await tester.pump();

      expect(find.textContaining('DOCUMENTO OFICIAL · MANDATO ART. 653 CC'), findsOneWidget);
      expect(find.textContaining('Cláusula-Mandato Mercantil Expressa'), findsOneWidget);
      expect(find.text(LegalMandateService.currentDocumentSha256Hex), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Round 11 — Tortura Geométrica 320×640 @ 1.35x + Barra Android 48dp nos cartões Bivalente e Semáforo SLU', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final gw = FakeCeoBackendGateway(pbkdf2Iterations: 1200);
      final repo = FounderCockpitRepository(gateway: gw, pbkdf2Iterations: 1200);
      try {
        await tester.runAsync(() => gw.preSealAndUnlockForTest(repo: repo));

      await tester.pumpWidget(
        _wrapHost(
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: <Widget>[
                FounderBivalentTreasuryCard(
                  repository: repo,
                  treasuryState: const CeoBivalentTreasuryState.emptyZero(),
                ),
                const SizedBox(height: 12),
                FounderSluGoLiveSemaphoreCard(
                  repository: repo,
                  semaphore: const CeoSluGoLiveSemaphore.emptyZero(),
                ),
              ],
            ),
          ),
          scaler: const TextScaler.linear(1.35),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

        // Expande fórmula do teto, rotina mensal e cronograma D-30 -> D+0 em 320px @ 1.35x!
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('ceo-toggle-ceiling-formula-btn')),
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey<String>('ceo-toggle-ceiling-formula-btn')),
        );
        await tester.pump();
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('ceo-toggle-monthly-routine-btn')),
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey<String>('ceo-toggle-monthly-routine-btn')),
        );
        await tester.pump();
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('ceo-toggle-slu-roadmap-btn')),
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey<String>('ceo-toggle-slu-roadmap-btn')),
        );
        await tester.pump();

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        repo.dispose();
      }
    });

    testWidgets('Round 12 — Modo Privacidade (`privacyBlurActive: true`) mascara 100% dos valores em reais da Tesouraria e Semáforo', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const richTreasury = CeoBivalentTreasuryState(
        operatingMode: 'SANDBOX_PRE_CNPJ',
        settlementPsp: 'ASAAS_SANDBOX',
        sluLegalName: 'HOMOLOGACAO',
        sluCnpjConfigured: false,
        solePartnerCpfConfigured: false,
        cnaePrimary: '6319-4/00',
        cnaeSecondary: '8211-3/00',
        beneficiaryFullName: 'Wagner Oliveira',
        destinationLockMode: 'LOCKED_SOLE_PARTNER_CPF_ACCOUNT',
        allowTypedPixKeys: false,
        bankDisplayLabel: 'Conta Pessoa Física Titular Único',
        duressModeStatus: 'NORMAL',
        cumulativePlatformRevenue135Cents: 987654,
        untouchableCustodyTotalCents: 543210,
        providerCustody85Cents: 500000,
        clientEscrowAndWalletsCents: 30000,
        activeExecutionEscrowCents: 0,
        materialsExempt0PctCents: 0,
        warrantyPool15Cents: 13210,
        das6PctUnpaidProvisionCents: 59259,
        das6PctPaidCents: 0,
        corporateExpensesPaidCents: 12345,
        corporateExpensesScheduledCents: 0,
        priorDistributionsCents: 0,
        safetyBufferCents: 30000,
        withdrawableProfitCents: 886050,
        reconciliationDiscrepancyCents: 0,
        blockedReason: 'NONE',
      );
      const richSem = CeoSluGoLiveSemaphore(
        operatingMode: 'SANDBOX_PRE_CNPJ',
        allFourCriteriaGreen: true,
        criteriaGreenCount: 4,
        criterion1Stability7dOk: true,
        zeroDriftDaysElapsed: 9,
        zeroDriftTargetDays: 7,
        sandboxPayoutsTestedCount: 3,
        criterion2P0P1ZeroedOk: true,
        criterion3PocosLiquidityOk: true,
        pocosProvidersTotalCount: 22,
        pocosProvidersActiveCount: 19,
        pocosProvidersMinTarget: 15,
        pocosProvidersIdealTarget: 20,
        criterion4TakeoffReserveOk: true,
        takeoffReserveSavedCents: 135000,
        takeoffReserveMinCents: 100000,
        takeoffReserveTargetCents: 130000,
        legalMandateAcceptedUsersCount: 28,
        legalMandateProvidersCount: 22,
      );

      final gw = FakeCeoBackendGateway(pbkdf2Iterations: 1200);
      final repo = FounderCockpitRepository(gateway: gw, pbkdf2Iterations: 1200);
      try {
        await tester.pumpWidget(
        _wrapHost(
          SingleChildScrollView(
            child: Column(
              children: <Widget>[
                FounderBivalentTreasuryCard(
                  repository: repo,
                  treasuryState: richTreasury,
                  privacyBlurActive: true,
                ),
                FounderSluGoLiveSemaphoreCard(
                  repository: repo,
                  semaphore: richSem,
                  privacyBlurActive: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Nenhum valor real (8.860,50 ou 1.350,00) pode aparecer quando privacyBlurActive == true!
      expect(find.textContaining('8.860,50'), findsNothing);
      expect(find.textContaining('1.350,00'), findsNothing);
      expect(find.textContaining('•••••'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        repo.dispose();
      }
    });
  });
}

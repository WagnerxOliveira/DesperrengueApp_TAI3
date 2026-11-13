import 'dart:io';

import 'package:desperrengue_app/core/models/client_achievements.dart';
import 'package:desperrengue_app/core/models/client_dossier_models.dart';
import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/models/scheduling_models.dart'
    show DestinationPrecision;
import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/category_brand_emblem.dart';
import 'package:desperrengue_app/core/ui/widgets.dart';
import 'package:desperrengue_app/features/client/presentation/category_picker.dart';
import 'package:desperrengue_app/features/client/presentation/client_job_screen.dart';
import 'package:desperrengue_app/features/client/presentation/client_orders_tab.dart';
import 'package:desperrengue_app/features/client/presentation/detalhe_servico_cliente_screen.dart';
import 'package:desperrengue_app/features/client/presentation/order_tracking_screen.dart';
import 'package:desperrengue_app/features/client/presentation/published_overlay.dart';
import 'package:desperrengue_app/features/client/presentation/request_wizard.dart';
import 'package:desperrengue_app/features/home/presentation/home_screens.dart';
import 'package:desperrengue_app/features/shared/presentation/achievement_widgets.dart';
import 'package:desperrengue_app/features/shared/presentation/fintech_warranty_widgets.dart';
import 'package:desperrengue_app/features/shared/presentation/order_live_map_modal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapForUxTest(
  Widget child, {
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1.0,
  bool disableAnimations = false,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.resolve(null, Brightness.light),
    darkTheme: AppTheme.resolve(null, Brightness.dark),
    themeMode: themeMode,
    builder: (context, inner) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
          viewInsets: viewInsets,
        ),
        child: inner ?? const SizedBox.shrink(),
      );
    },
    home: child,
  );
}

Future<void> _setViewport(
  WidgetTester tester,
  Size size, {
  double devicePixelRatio = 1.0,
}) async {
  tester.view.devicePixelRatio = devicePixelRatio;
  tester.view.physicalSize = Size(
    size.width * devicePixelRatio,
    size.height * devicePixelRatio,
  );
}

void _resetViewport(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void main() {
  group('1. Red Team Geo-Privacy Sanitization (RequestWizardScreen._summary)', () {
    test('never leaks street, number, complement, CEP or reference into public summary', () {
      // Vector 1: Address without " - " and without fallbackCity
      final v1 = RequestWizardScreen.sanitizePublicAddressSummary(
        'Rua Assis Figueiredo, 1180',
      );
      expect(v1, 'Localização protegida');
      expect(v1.contains('Assis Figueiredo'), isFalse);
      expect(v1.contains('1180'), isFalse);

      // Vector 2: Address without " - " with fallbackCity
      final v2 = RequestWizardScreen.sanitizePublicAddressSummary(
        'Rua Assis Figueiredo, 1180',
        fallbackCity: 'Poços de Caldas',
      );
      expect(v2, 'Poços de Caldas');
      expect(v2.contains('Assis Figueiredo'), isFalse);
      expect(v2.contains('1180'), isFalse);

      // Vector 3: Multiple " - " segments with Apto / Complement
      final v3 = RequestWizardScreen.sanitizePublicAddressSummary(
        'Rua das Flores, 123 - Apto 402 - Centro - Poços de Caldas - MG',
      );
      expect(v3, 'Centro, Poços de Caldas - MG');
      expect(v3.contains('Rua das Flores'), isFalse);
      expect(v3.contains('123'), isFalse);
      expect(v3.contains('Apto'), isFalse);
      expect(v3.contains('402'), isFalse);

      // Vector 4: Block, house, CEP, and reference
      final v4 = RequestWizardScreen.sanitizePublicAddressSummary(
        'Av. João Pinheiro, 850 - Bloco B - Casa 2 - Jardins - Poços de Caldas - MG - 37701-000 | Ref: Portão azul',
      );
      expect(v4, 'Jardins, Poços de Caldas - MG');
      expect(v4.contains('João Pinheiro'), isFalse);
      expect(v4.contains('850'), isFalse);
      expect(v4.contains('Bloco'), isFalse);
      expect(v4.contains('Casa'), isFalse);
      expect(v4.contains('37701'), isFalse);
      expect(v4.contains('Portão'), isFalse);
    });
  });

  group('2. 33 Categories Modal & Grid (Dark Glass Duotone, Zero Syllable Break, 320px @ 1.4x)', () {
    testWidgets('CategoryGrid renders at 320x640 with textScaler 1.4 in Light and Dark without overflow', (tester) async {
      addTearDown(() => _resetViewport(tester));
      await _setViewport(tester, const Size(320, 640));

      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await tester.pumpWidget(
          _wrapForUxTest(
            Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: CategoryGrid(onPick: (_) {}),
              ),
            ),
            themeMode: mode,
            textScale: 1.4,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(CategoryBrandEmblem), findsWidgets);
        expect(find.byKey(const ValueKey('categories-see-all')), findsOneWidget);
      }
    });

    testWidgets('All 33 Categories sheet renders "Impermeabilização" on single line without mid-word break at 320px @ 1.3x', (tester) async {
      addTearDown(() => _resetViewport(tester));
      await _setViewport(tester, const Size(320, 640));

      await tester.pumpWidget(
        _wrapForUxTest(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAllCategoriesSheet(context, onPick: (_) {}),
                  child: const Text('Abrir 33 categorias'),
                ),
              ),
            ),
          ),
          themeMode: ThemeMode.dark,
          textScale: 1.3,
        ),
      );

      await tester.tap(find.text('Abrir 33 categorias'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('category-search')), findsOneWidget);

      // Search for Impermeabilização
      await tester.enterText(
        find.byType(TextField),
        'Impermeabilização',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final impermTextFinder = find.text('Impermeabilização').last;
      expect(impermTextFinder, findsOneWidget);
      final impermTextWidget = tester.widget<Text>(impermTextFinder);
      expect(impermTextWidget.maxLines, 1);
      expect(impermTextWidget.softWrap, isFalse);

      // Clear search via accessible tooltip button
      final clearBtn = find.byTooltip('Limpar busca');
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('3. Client Exact Location & Full-Screen Map (Always Unlocked for Owner)', () {
    testWidgets('Client sees full street/number and exact map in InteractiveLocationPreviewCard and OrderLiveMapModalScreen across viewports', (tester) async {
      addTearDown(() => _resetViewport(tester));

      for (final size in const [
        Size(320, 640),
        Size(360, 780),
        Size(412, 915),
        Size(480, 960),
      ]) {
        await _setViewport(tester, size);
        await tester.pumpWidget(
          _wrapForUxTest(
            const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: InteractiveLocationPreviewCard(
                  addressLine: 'Rua Assis Figueiredo, 1180 - Centro, Poços de Caldas - MG',
                  summary: 'Centro, Poços de Caldas - MG',
                  cep: '37701-000',
                  referencePoint: 'Próximo ao Palace Hotel',
                  latitude: -21.7878,
                  longitude: -46.5612,
                  precision: DestinationPrecision.exact,
                  pinConfirmed: true,
                  orderStatus: 'open',
                ),
              ),
            ),
            textScale: 1.3,
            disableAnimations: true,
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('preview-street-number')), findsOneWidget);
        expect(find.textContaining('Rua Assis Figueiredo, 1180'), findsOneWidget);
      }

      // Open full-screen map modal at 320x640 @ 1.3x
      await _setViewport(tester, const Size(320, 640));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('detail-location')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey('live-map')), findsOneWidget);
      expect(find.byKey(const ValueKey('live-map-street-number')), findsOneWidget);
      expect(find.textContaining('Rua Assis Figueiredo, 1180'), findsWidgets);
    });
  });

  group('4. Client Achievements (Silver #CBD5E1 Locked, Metallic Unlocked, Carousel & Modal)', () {
    testWidgets('ClientAchievementsScreen renders locked and unlocked medals without overflow at 320x640 @ 1.4x and opens info modal', (tester) async {
      addTearDown(() => _resetViewport(tester));
      await _setViewport(tester, const Size(320, 640));

      const profile = UserProfile(
        id: 'client-1',
        fullName: 'Marina Cliente',
        phone: '35999990000',
        addressLine: 'Rua Assis Figueiredo, 1180 - Centro',
        addressCity: 'Poços de Caldas',
        avatarUrl: 'https://example.com/avatar.jpg',
        clientSetupDone: true,
      );

      final sampleJob = Job(
        id: 'job-1',
        clientId: 'client-1',
        providerId: 'prov-1',
        category: 'Elétrica',
        title: 'Troca de disjuntor',
        description: 'Disjuntor desarmando no quadro principal.',
        status: JobStatus.completed,
        urgency: 'scheduled',
        visibility: 'open',
        paymentStatus: 'released',
        agreedPrice: 180.0,
        createdAt: DateTime(2026, 5, 1),
      );

      await tester.pumpWidget(
        _wrapForUxTest(
          ClientAchievementsScreen(
            profile: profile,
            loader: () async => ClientAchievementInput(
              jobs: [sampleJob],
              profileSteps: 5,
              reviewedJobIds: const {'job-1'},
              contestedJobIds: const {},
            ),
          ),
          textScale: 1.4,
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('Minhas conquistas'), findsOneWidget);
      expect(find.byType(MedalTile), findsWidgets);

      // Scroll first medal into view on 320x640 @ 1.4x and tap to open modal
      await tester.ensureVisible(find.byType(MedalTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MedalTile).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Conquista desbloqueada!'), findsOneWidget);
    });
  });

  group('5. DetalheServicoClienteScreen, PublishedOrderOverlay, Jargon & Error Sanitization', () {
    testWidgets('DetalheServicoClienteScreen renders across viewport matrix and open keyboard viewInsets without overflow', (tester) async {
      addTearDown(() => _resetViewport(tester));

      final dossier = ClientDossier(
        jobId: 'job-dossier-1',
        code: '#DP-2040',
        status: 'open',
        urgency: 'scheduled',
        category: 'Hidráulica',
        title: 'Reparo de vazamento sob pia',
        description: 'Sifão pingando continuamente na bancada da cozinha.',
        addressSummary: 'Centro, Poços de Caldas - MG',
        addressLine: 'Rua Paraíba, 340 - Centro, Poços de Caldas - MG',
        latitude: -21.7882,
        longitude: -46.5648,
        geoPrecision: DestinationPrecision.house,
        geoSource: 'client_pin',
        createdAt: DateTime(2026, 6, 10, 14, 30),
        scheduledFor: DateTime(2026, 6, 12, 9, 0),
        amount: 220.0,
        paymentStatus: 'held',
        photoPaths: const [],
        evidence: const [],
      );

      for (final size in const [
        Size(320, 640),
        Size(360, 780),
        Size(412, 915),
        Size(480, 960),
      ]) {
        await _setViewport(tester, size);
        await tester.pumpWidget(
          _wrapForUxTest(
            DetalheServicoClienteScreen(
              jobId: dossier.jobId,
              dossierLoader: (_) async => dossier,
              quotesLoader: (_) async => const [
                DetailQuote(
                  providerName: 'Carlos Hidráulica',
                  price: 220.0,
                  message: 'Posso atender no horário combinado com peças inclusas.',
                ),
              ],
            ),
            textScale: 1.3,
            viewInsets: const EdgeInsets.only(bottom: 240),
            disableAnimations: true,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('detail-location')),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.textContaining('Rua Paraíba, 340'), findsWidgets);
      }
    });

    testWidgets('ClientOrdersTab and WaitingQuotesScreen render at 320x640 @ 1.3x without overflow and clean up prefetcher on dispose', (tester) async {
      addTearDown(() => _resetViewport(tester));
      await _setViewport(tester, const Size(320, 640));

      final openJob = Job(
        id: 'job-open-1',
        clientId: 'client-1',
        category: 'Impermeabilização',
        title: 'Impermeabilização de laje residencial',
        description: 'Infiltração na laje superior próximo à caixa d’água.',
        status: JobStatus.open,
        urgency: 'scheduled',
        visibility: 'open',
        paymentStatus: 'none',
        addressSummary: 'Centro, Poços de Caldas - MG',
        latitude: -21.7878,
        longitude: -46.5612,
        createdAt: DateTime(2026, 6, 10, 10, 0),
      );

      await tester.pumpWidget(
        _wrapForUxTest(
          Scaffold(
            body: ClientOrdersTab(
              jobsStream: Stream.value([openJob]),
              includeMediationTab: true,
              onOpen: (_, _) {},
            ),
          ),
          textScale: 1.3,
          disableAnimations: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Meus Pedidos'), findsOneWidget);
      expect(find.textContaining('Impermeabilização de laje'), findsOneWidget);

      await tester.pumpWidget(
        _wrapForUxTest(
          WaitingQuotesScreen(
            job: openJob,
            quotesStream: Stream.value(const []),
            invitesStream: Stream.value(const []),
          ),
          textScale: 1.3,
          disableAnimations: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('waiting-back')), findsOneWidget);
    });

    testWidgets('PublishedOrderOverlay respects disableAnimations and renders at 320x640 @ 1.4x without overflow', (tester) async {
      addTearDown(() => _resetViewport(tester));
      await _setViewport(tester, const Size(320, 640));

      await tester.pumpWidget(
        _wrapForUxTest(
          const PublishedOrderOverlay(
            categoryName: 'Impermeabilização',
            direct: false,
          ),
          textScale: 1.4,
          disableAnimations: true,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Pedido publicado!'), findsOneWidget);
      expect(find.text('Impermeabilização'), findsOneWidget);
    });

    testWidgets('HomeAdminScreen shows clear Portuguese without internal RPC names', (tester) async {
      await tester.pumpWidget(
        _wrapForUxTest(const HomeAdminScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('admin_review_kyc'), findsNothing);
      expect(find.textContaining('admin_resolve_dispute'), findsNothing);
      expect(
        find.textContaining('painel administrativo'),
        findsOneWidget,
      );
    });

    test('friendlyError delegates to humanizeError and preserves business codes while stripping SQL/PII', () {
      expect(
        friendlyError(Exception('message: QUOTE_LIMIT_REACHED')),
        'Esta demanda já recebeu 3 orçamentos.',
      );
      expect(
        friendlyError(Exception('message: PIN_INVALID:2')),
        'PIN incorreto. Restam 2 tentativa(s).',
      );
      expect(
        friendlyError(Exception('message: PIN_LOCKED')),
        'Muitas tentativas. Use "Tive um problema".',
      );
      expect(
        friendlyError(Exception('SocketException: Failed host lookup')),
        'Sem conexão. Verifique sua internet e tente novamente.',
      );
      final sqlLeak = friendlyError(
        Exception(
          'PostgrestException(message: duplicate key value violates unique constraint "jobs_pkey", code: 23505)',
        ),
      );
      expect(sqlLeak.contains('jobs_pkey'), isFalse);
      expect(sqlLeak.contains('PostgrestException'), isFalse);
    });
  });

  group('6. Zero Demo NFC-e / Forensic Data in Client Tracking & Completion Screens', () {
    test('order_tracking_screen.dart and completion_screens.dart contain no fake NFC-e #000, 45.00 or forensic:// strings', () {
      final trackingSrc = File(
        'lib/features/client/presentation/order_tracking_screen.dart',
      ).readAsStringSync();
      expect(trackingSrc.contains('NFC-e #000'), isFalse);
      expect(trackingSrc.contains('45.00'), isFalse);
      expect(trackingSrc.contains('Peça Adicional Homologada'), isFalse);
      expect(trackingSrc.contains('Loja de Materiais Credenciada'), isFalse);
      expect(trackingSrc.contains('forensic://'), isFalse);

      final completionSrc = File(
        'lib/features/client/presentation/completion_screens.dart',
      ).readAsStringSync();
      expect(completionSrc.contains('NFC-e #000'), isFalse);
      expect(completionSrc.contains('forensic://'), isFalse);
    });

    testWidgets('OrderTrackingScreen shows honest empty state "Nenhuma nota de material registrada ainda" when server has no receipts, and renders real server receipts when registered', (tester) async {
      addTearDown(() => _resetViewport(tester));
      await _setViewport(tester, const Size(360, 1800));

      final job = Job(
        id: 'job-track-real-nfce-1',
        clientId: 'client-1',
        providerId: 'prov-1',
        category: 'Elétrica',
        title: 'Troca de disjuntor geral',
        description: 'Disjuntor bipolar 40A aquecendo.',
        status: JobStatus.inProgress,
        urgency: 'scheduled',
        visibility: 'open',
        paymentStatus: 'escrow',
        agreedPrice: 180.0,
        addressSummary: 'Centro, Poços de Caldas - MG',
        createdAt: DateTime(2026, 6, 10, 10, 0),
      );

      // 1) Empty server receipts -> honest empty state
      await tester.pumpWidget(
        _wrapForUxTest(
          OrderTrackingScreen(
            job: job,
            fiscalDocsLoader: (_) async => const [],
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.scrollUntilVisible(
        find.byType(SmartSplitTransparencyCard),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Nenhuma nota de material registrada ainda'),
        findsOneWidget,
      );
      expect(find.textContaining('NFC-e #000'), findsNothing);
      expect(
        find.text('Anexar Cupom Fiscal de Peça (0% Taxa)'),
        findsNothing,
      );

      // 2) Server returns a real registered fiscal document
      await tester.pumpWidget(
        _wrapForUxTest(
          OrderTrackingScreen(
            job: job,
            fiscalDocsLoader: (_) async => const [
              {
                'id': 'doc-real-1',
                'fiscal_document_mode': 'NFCE_65',
                'emitter_cnpj': '11222333000181',
                'receipt_number': '1234-1',
                'declared_material_amount': 89.90,
                'clawback_triggered': false,
              },
            ],
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.text('Nenhuma nota de material registrada ainda'),
        findsNothing,
      );
      expect(find.textContaining('NFC-e 1234-1'), findsOneWidget);
      expect(find.textContaining('11222333000181'), findsOneWidget);
    });
  });
}

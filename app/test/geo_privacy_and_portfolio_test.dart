import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:desperrengue_app/core/models/client_dossier_models.dart';
import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/models/provider_portfolio_models.dart';
import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/accurate_geo_routing_service.dart';
import 'package:desperrengue_app/core/state/provider_portfolio_controller.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/features/client/presentation/detalhe_servico_cliente_screen.dart';
import 'package:desperrengue_app/features/provider/presentation/provider_portfolio_widgets.dart';
import 'package:desperrengue_app/features/shared/presentation/review_widgets.dart';

Widget _wrapWithTheme(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.resolve(null, Brightness.light),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  // ===========================================================================
  // FRENTE 1: TRAVA TEMPORAL DE PRIVACIDADE + GEOCODIFICAÇÃO 99%+ PRECISA
  // ===========================================================================
  group('Frente 1 — Trava Temporal de Privacidade (isServiceDayUnlocked)', () {
    test('data agendada futura retorna false e oculta rua/número do profissional', () {
      final futureDate = DateTime.now().add(const Duration(days: 3));
      expect(
        isServiceDayUnlocked(futureDate, status: JobStatus.scheduled),
        isFalse,
      );

      final view = AccurateGeoRoutingService.resolveProviderAddressView(
        fullAddressLine:
            'Avenida Padre Cletus Francis Cox, 1661 - Jardim Country Club, Poços de Caldas - MG',
        addressSummary: 'Jardim Country Club, Poços de Caldas - MG',
        scheduledDate: futureDate,
        status: JobStatus.scheduled,
      );

      expect(view.isUnlocked, isFalse);
      expect(view.cityAndState, 'Poços de Caldas - MG');
      expect(view.primaryTitle, contains('Raio aproximado de'));
      expect(view.primaryTitle, contains('Poços de Caldas - MG'));
      expect(view.primaryTitle, isNot(contains('1661')));
      expect(
        view.privacyBadgeText,
        contains(
          'Endereço exato e rota no mapa serão liberados automaticamente no dia agendado para o serviço',
        ),
      );
    });

    test('data agendada igual a hoje retorna true e libera endereço completo + rota', () {
      final today = DateTime.now();
      expect(
        isServiceDayUnlocked(today, status: JobStatus.scheduled),
        isTrue,
      );

      final view = AccurateGeoRoutingService.resolveProviderAddressView(
        fullAddressLine:
            'Avenida Padre Cletus Francis Cox, 1661 - Jardim Country Club, Poços de Caldas - MG',
        addressSummary: 'Jardim Country Club, Poços de Caldas - MG',
        scheduledDate: today,
        status: JobStatus.scheduled,
      );

      expect(view.isUnlocked, isTrue);
      expect(
        view.primaryTitle,
        'Avenida Padre Cletus Francis Cox, 1661 - Jardim Country Club, Poços de Caldas - MG',
      );
    });

    testWidgets('ProviderPrivacyAddressCard oculta botão de mapa antes do dia e libera no dia do serviço', (tester) async {
      var openedRouteCount = 0;
      final futureView = AccurateGeoRoutingService.resolveProviderAddressView(
        fullAddressLine:
            'Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG',
        scheduledDate: DateTime.now().add(const Duration(days: 4)),
        status: JobStatus.scheduled,
      );

      await tester.pumpWidget(
        _wrapWithTheme(
          ProviderPrivacyAddressCard(
            view: futureView,
            onOpenMapRoute: () => openedRouteCount++,
          ),
        ),
      );

      expect(find.byKey(const ValueKey('provider-privacy-locked-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('provider-open-precise-route-btn')), findsNothing);
      expect(find.textContaining('Raio aproximado de'), findsOneWidget);
      expect(find.textContaining('203'), findsNothing);

      // Agora no dia do serviço:
      final todayView = AccurateGeoRoutingService.resolveProviderAddressView(
        fullAddressLine:
            'Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG',
        scheduledDate: DateTime.now(),
        status: JobStatus.scheduled,
      );

      await tester.pumpWidget(
        _wrapWithTheme(
          ProviderPrivacyAddressCard(
            view: todayView,
            onOpenMapRoute: () => openedRouteCount++,
          ),
        ),
      );

      expect(find.byKey(const ValueKey('provider-privacy-unlocked-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('provider-open-precise-route-btn')), findsOneWidget);
      expect(
        find.text('Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('provider-privacy-unlocked-card')));
      await tester.pump();
      expect(openedRouteCount, 1);
    });

    testWidgets('Visão do Usuário Cliente exibe endereço estritamente informativo (somente leitura)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final dossier = ClientDossier.fromMap(const <String, dynamic>{
        'job_id': 'job-ro-1',
        'code': '#DSP-RO1',
        'title': 'Reparo elétrico',
        'description': 'Troca de tomada',
        'category': 'Elétrica',
        'status': 'scheduled',
        'created_at': '2026-10-19T10:00:00Z',
        'payment_status': 'held',
        'amount': 150.0,
        'address_line': 'Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG',
        'address_summary': 'Maria Imaculada, Poços de Caldas - MG',
        'photo_paths': <String>[],
        'evidence': <dynamic>[],
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.resolve(null, Brightness.light),
            home: DetalheServicoClienteScreen(
              jobId: 'job-ro-1',
              dossierLoader: (_) async => dossier,
              quotesLoader: (_) async => const <DetailQuote>[],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Rua Padre José Geraldi, 203'), findsOneWidget);
      expect(find.textContaining('Maria Imaculada, Poços de Caldas - MG'), findsOneWidget);
      expect(find.textContaining('Rua Padre José Geraldi'), findsOneWidget);
      expect(find.text('Toque para ver no mapa'), findsNothing);
    });
  });

  group('Frente 1 — AccurateGeoRoutingService (99%+ Precisão e Google Maps URL)', () {
    test('resolveExactAddress retorna coordenadas exatas da rua/número e detecta divergência', () {
      const address =
          'Avenida Padre Cletus Francis Cox, 1661 - Jardim Country Club, Poços de Caldas - MG';
      final hit = AccurateGeoRoutingService.resolveFromLocalDictionary(address);
      expect(hit, isNotNull);
      expect(hit!.lat, closeTo(-21.8012, 0.01));
      expect(hit.lng, closeTo(-46.5998, 0.01));

      // Coordenadas exatas são consistentes:
      expect(
        AccurateGeoRoutingService.areCoordinatesConsistentWithAddress(
          address,
          hit.lat,
          hit.lng,
        ),
        isTrue,
      );

      // Coordenadas do centro da cidade ou outra rua (> 450 m de distância) são detectadas como divergentes:
      expect(
        AccurateGeoRoutingService.areCoordinatesConsistentWithAddress(
          address,
          -21.7878,
          -46.5612,
        ),
        isFalse,
      );
    });

    test('buildGoogleMapsNavigationUrl gera URL oficial com origin, destination textual codificado e travelmode=driving', () {
      const address =
          'Avenida Padre Cletus Francis Cox, 1661 - Jardim Country Club, Poços de Caldas - MG';
      final url = AccurateGeoRoutingService.buildGoogleMapsNavigationUrl(
        originLat: -21.79509,
        originLng: -46.59495,
        fullFormattedAddress: address,
      );

      expect(url, startsWith('https://www.google.com/maps/dir/?api=1'));
      expect(url, contains('origin=-21.795090,-46.594950'));
      expect(url, contains('destination=${Uri.encodeComponent(address)}'));
      expect(url, endsWith('&travelmode=driving'));
    });
  });

  // ===========================================================================
  // FRENTE 2: MEU PORTFÓLIO INTELIGENTE (TOP 3 LIFO + ATÉ 5 DESTAQUES) E
  //           HISTÓRICO REAL EM 4 ESTADOS + ISOLAMENTO CLIENTE VS PROFISSIONAL
  // ===========================================================================
  group('Frente 2 — Zero Fake Data, Elegibilidade Pós-Proteção 100%, Top 3 LIFO + Até 5 Destaques e Notas Complementares', () {
    late ProviderPortfolioStore store;

    setUp(() {
      store = ProviderPortfolioStore.instance;
      store.resetToCount(0);
    });

    tearDown(() {
      store.resetToCount(0);
    });

    CompletedServiceRecord makeService(
      int n, {
      bool reviewed = false,
      ServiceHistoryLifecycleStage stage =
          ServiceHistoryLifecycleStage.settledAndPaid,
      bool isPaid100Percent = true,
    }) {
      return CompletedServiceRecord(
        id: 'test-srv-$n',
        orderId: 'test-order-$n',
        title: 'Serviço Técnico #$n',
        categoryName: 'Elétrica',
        clientRequestedDescription: 'O cliente solicitou reparo elétrico completo #$n.',
        detailedExecutionReport: 'Relatório técnico completo do serviço #$n.',
        cityAndState: 'Poços de Caldas - MG',
        completedAt: DateTime(2026, 11, 1, 10, n),
        validatedClientPin: (1000 + n).toString(),
        serviceValue: 150.0 + (n * 20),
        executionDurationText: '1h 15min',
        toolsAndMaterialsUsed: <String>['Ferramenta #$n'],
        beforeAfterPhotoCaptionsOrUrls: <String>[
          'ANTES: Estado inicial #$n',
          'DEPOIS: Execução finalizada #$n',
          'DETALHE: Acabamento técnico #$n',
        ],
        warrantyCertificateCode: 'GAR-TEST-$n',
        lifecycleStage: stage,
        isPaid100Percent: isPaid100Percent,
        isReviewedByClient: reviewed,
        clientRating: reviewed ? 5.0 : null,
        clientReviewComment: reviewed ? 'Avaliação inicial #$n' : null,
      );
    }

    test('Zero Fake Data: inicia vazio e bloqueia serviços Sob Proteção Pós-Serviço, Em Mediação ou Cancelados de entrarem no Portfólio', () {
      expect(store.state.fullHistory, isEmpty);
      expect(store.state.automaticTopThree, isEmpty);
      expect(store.state.curatedPortfolioServices, isEmpty);

      // Registra serviços em Sob Proteção Pós-Serviço, Em Mediação e Cancelado:
      store.completeAndValidateServiceWithPin(
        makeService(
          101,
          stage: ServiceHistoryLifecycleStage.underPostServiceProtection,
          isPaid100Percent: false,
        ),
      );
      store.completeAndValidateServiceWithPin(
        makeService(
          102,
          stage: ServiceHistoryLifecycleStage.inMediation,
          isPaid100Percent: false,
        ),
      );
      store.completeAndValidateServiceWithPin(
        makeService(
          103,
          stage: ServiceHistoryLifecycleStage.canceled,
          isPaid100Percent: false,
        ),
      );

      // Estão registrados no Histórico de Serviços Prestados:
      expect(store.state.totalHistoryRecordsCount, 3);
      expect(store.state.underProtectionServices, hasLength(1));
      expect(store.state.inMediationServices, hasLength(1));
      expect(store.state.canceledServices, hasLength(1));

      // Mas NENHUM entra no Meu Portfólio (Top 3 ou Destaques):
      expect(store.state.totalCompletedCount, 0);
      expect(store.state.automaticTopThree, isEmpty);
      expect(store.addServiceFromHistoryToPortfolio('test-srv-101'), isFalse);
      expect(store.addServiceFromHistoryToPortfolio('test-srv-102'), isFalse);
      expect(store.addServiceFromHistoryToPortfolio('test-srv-103'), isFalse);

      // Quando o serviço 101 conclui a janela Sob Proteção Pós-Serviço e recebe 100% do pagamento:
      expect(store.markProtectionCompletedAnd100PercentPaid('test-srv-101'), isTrue);
      expect(store.state.totalCompletedCount, 1);
      expect(store.state.underProtectionServices, isEmpty);
      expect(store.state.automaticTopThree.map((s) => s.id), <String>['test-srv-101']);
    });

    test('com 1, 2 ou 3 serviços 100% liquidados: isAddFromHistoryUnlocked == false e não permite adicionar do Histórico', () {
      store.completeAndValidateServiceWithPin(makeService(1));
      expect(store.state.totalCompletedCount, 1);
      expect(store.state.automaticTopThree.map((s) => s.id), <String>['test-srv-1']);
      expect(store.state.isAddFromHistoryUnlocked, isFalse);
      expect(store.state.eligibleHistoryPool, isEmpty);
      expect(store.addServiceFromHistoryToPortfolio('test-srv-1'), isFalse);

      store.completeAndValidateServiceWithPin(makeService(2));
      expect(store.state.totalCompletedCount, 2);
      expect(
        store.state.automaticTopThree.map((s) => s.id),
        <String>['test-srv-2', 'test-srv-1'],
      );
      expect(store.state.isAddFromHistoryUnlocked, isFalse);

      store.completeAndValidateServiceWithPin(makeService(3));
      expect(store.state.totalCompletedCount, 3);
      expect(
        store.state.automaticTopThree.map((s) => s.id),
        <String>['test-srv-3', 'test-srv-2', 'test-srv-1'],
      );
      expect(store.state.isAddFromHistoryUnlocked, isFalse);
      expect(store.state.eligibleHistoryPool, isEmpty);
      expect(store.addServiceFromHistoryToPortfolio('test-srv-1'), isFalse);
    });

    test('ao concluir o 4º ao 9º serviço 100% liquidado: Top 3 LIFO rotaciona e permite escolher até 5 destaques do Histórico (bloqueando o 6º)', () {
      for (var i = 1; i <= 4; i++) {
        store.completeAndValidateServiceWithPin(makeService(i));
      }

      expect(store.state.totalCompletedCount, 4);
      expect(store.state.isAddFromHistoryUnlocked, isTrue);

      // 4º serviço entrou em #1; 1º serviço saiu do Top 3 mas permanece em fullHistory e eligibleHistoryPool:
      expect(
        store.state.automaticTopThree.map((s) => s.id),
        <String>['test-srv-4', 'test-srv-3', 'test-srv-2'],
      );
      expect(
        store.state.eligibleHistoryPool.map((s) => s.id),
        <String>['test-srv-1'],
      );

      // Tentar adicionar um serviço que está nos 3 últimos não é permitido:
      expect(store.addServiceFromHistoryToPortfolio('test-srv-4'), isFalse);
      expect(store.addServiceFromHistoryToPortfolio('test-srv-3'), isFalse);

      // Adicionar o 1º serviço elegível do Histórico funciona:
      expect(store.addServiceFromHistoryToPortfolio('test-srv-1'), isTrue);
      expect(
        store.state.curatedPortfolioServices.map((s) => s.id),
        <String>['test-srv-1'],
      );

      // Conclui do 5º ao 9º serviço para testar o limite máximo de 5 destaques escolhidos:
      for (var i = 5; i <= 9; i++) {
        store.completeAndValidateServiceWithPin(makeService(i));
      }

      expect(store.state.totalCompletedCount, 9);
      expect(
        store.state.automaticTopThree.map((s) => s.id),
        <String>['test-srv-9', 'test-srv-8', 'test-srv-7'],
      );
      expect(
        store.state.eligibleHistoryPool.map((s) => s.id),
        <String>[
          'test-srv-6',
          'test-srv-5',
          'test-srv-4',
          'test-srv-3',
          'test-srv-2',
          'test-srv-1',
        ],
      );

      expect(store.addServiceFromHistoryToPortfolio('test-srv-2'), isTrue);
      expect(store.addServiceFromHistoryToPortfolio('test-srv-3'), isTrue);
      expect(store.addServiceFromHistoryToPortfolio('test-srv-4'), isTrue);
      expect(store.addServiceFromHistoryToPortfolio('test-srv-5'), isTrue);
      expect(store.state.curatedPortfolioServices, hasLength(5));

      // Tentar adicionar um 6º destaque escolhido retorna false (limite máximo = 5):
      expect(store.addServiceFromHistoryToPortfolio('test-srv-6'), isFalse);
      expect(store.state.curatedPortfolioServices, hasLength(5));

      // Remover um serviço de curatedPortfolioServices remove apenas da vitrine, mantendo fullHistory intacto:
      expect(store.removeCuratedServiceFromPortfolio('test-srv-2'), isTrue);
      expect(store.state.curatedPortfolioServices, hasLength(4));
      expect(store.state.fullHistory, hasLength(9));
    });

    test('Imutabilidade Pós-Conclusão + Notas Técnicas Complementares e Avaliação Reativa', () async {
      store.completeAndValidateServiceWithPin(makeService(1, reviewed: false));
      store.completeAndValidateServiceWithPin(makeService(2, reviewed: false));
      store.completeAndValidateServiceWithPin(makeService(3, reviewed: false));
      store.completeAndValidateServiceWithPin(makeService(4, reviewed: false));
      store.addServiceFromHistoryToPortfolio('test-srv-1');

      // Atualiza Notas Técnicas Complementares do serviço #4:
      final updatedNotes = await store.updateComplementaryTechnicalNotes(
        serviceId: 'test-srv-4',
        notes: 'Aplicados disjuntores curva C Siemens e cabo 4mm².',
      );
      expect(updatedNotes, isTrue);

      final s4 = store.state.findById('test-srv-4')!;
      expect(s4.complementaryTechnicalNotes, 'Aplicados disjuntores curva C Siemens e cabo 4mm².');
      // Solicitação original do cliente e relatório de conclusão permanecem imutáveis:
      expect(s4.clientRequestedDescription, 'O cliente solicitou reparo elétrico completo #4.');
      expect(s4.detailedExecutionReport, 'Relatório técnico completo do serviço #4.');
      expect(s4.beforeAfterPhotoCaptionsOrUrls, hasLength(3));

      // Sincroniza avaliação do cliente:
      final okTop = store.syncClientEvaluationToHistoryAndPortfolio(
        serviceId: 'test-srv-4',
        rating: 5.0,
        comment: 'Serviço #4 impecável!',
        praiseTags: const <String>['Pontual', 'Excelente'],
      );
      expect(okTop, isTrue);
      expect(store.state.findById('test-srv-4')!.clientRating, 5.0);
    });

    testWidgets('UI Profissional vs Cliente: Galeria deslizável (1ª à última foto), edição de Notas Complementares pelo Profissional e omissão silenciosa de valores para o Cliente', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      // Inicia com 3 serviços concluídos:
      store.resetToCount(3);

      await tester.pumpWidget(
        _wrapWithTheme(
          const Padding(
            padding: EdgeInsets.all(16),
            child: ProviderSmartPortfolioSection(
              isOwner: true,
              syncOnMount: false,
            ),
          ),
        ),
      );
      await tester.pump();

      // Com 3 serviços, o botão de adicionar do Histórico NÃO existe e o aviso de bloqueio aparece:
      expect(find.byKey(const ValueKey('portfolio-curated-locked-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn-add-from-history-one-by-one')), findsNothing);
      expect(find.byKey(const ValueKey('btn-open-full-history')), findsOneWidget);

      // Conclui o 4º serviço 100% liquidado:
      store.simulateNextPinCompletedService();
      await tester.pumpAndSettle();

      expect(store.state.totalCompletedCount, 4);
      expect(find.byKey(const ValueKey('portfolio-curated-locked-card')), findsNothing);
      expect(find.byKey(const ValueKey('btn-add-from-history-one-by-one')), findsOneWidget);

      // Toca no 1º card do Top 3 para abrir o modal de detalhes completos como PROFISSIONAL:
      final top1Id = store.state.automaticTopThree.first.id;
      await tester.tap(find.byKey(ValueKey('portfolio-top3-card-0-$top1Id')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('detail-sheet-service-title')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-sheet-client-request')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-sheet-execution-report')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-sheet-immutable-lock-badge')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-sheet-complementary-notes-section')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-sheet-photo-pageview')), findsOneWidget);
      expect(find.text('Foto 1 de 3'), findsOneWidget);

      // Desliza para o lado na galeria de fotos (da 1ª para a 2ª foto):
      await tester.drag(
        find.byKey(const ValueKey('detail-sheet-photo-pageview')),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Foto 2 de 3'), findsOneWidget);

      // Edita e salva Notas Técnicas Complementares como Profissional:
      await tester.tap(find.byKey(const ValueKey('btn-edit-complementary-notes')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('input-complementary-notes')),
        'Nota técnica complementar adicionada pelo profissional no pós-obra.',
      );
      await tester.tap(find.byKey(const ValueKey('btn-save-complementary-notes')));
      await tester.pumpAndSettle();
      expect(
        find.text('Nota técnica complementar adicionada pelo profissional no pós-obra.'),
        findsOneWidget,
      );

      // Fecha o modal do profissional:
      Navigator.of(tester.element(find.byKey(const ValueKey('detail-sheet-service-title')))).pop();
      await tester.pumpAndSettle();

      // =======================================================================
      // VISÃO DO USUÁRIO CLIENTE (`isOwner: false`):
      // - NÃO vê botão de Histórico do Profissional;
      // - NÃO vê valores em R$ nem avisos dizendo que valores estão ocultos;
      // - NÃO vê botões de editar;
      // - Vê o que foi solicitado, a solução aplicada, as Notas Complementares e as fotos.
      // =======================================================================
      await tester.pumpWidget(
        _wrapWithTheme(
          const Padding(
            padding: EdgeInsets.all(16),
            child: ProviderSmartPortfolioSection(
              isOwner: false,
              syncOnMount: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('btn-open-full-history')), findsNothing);
      expect(find.textContaining('R\$'), findsNothing);

      await tester.tap(find.byKey(ValueKey('portfolio-top3-card-0-$top1Id')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('detail-sheet-client-request')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-sheet-execution-report')), findsOneWidget);
      expect(
        find.text('Nota técnica complementar adicionada pelo profissional no pós-obra.'),
        findsOneWidget,
      );
      // Nenhum botão de edição, nenhum aviso de bloqueio e nenhum valor R$ para o Cliente:
      expect(find.byKey(const ValueKey('btn-edit-complementary-notes')), findsNothing);
      expect(find.byKey(const ValueKey('detail-sheet-immutable-lock-badge')), findsNothing);
      expect(find.textContaining('R\$'), findsNothing);
    });

    test('UserProfile humaniza e-mail em fullName para displayName ("Wagner Oliveira") e firstName ("Wagner") sem exibir "Olá, você"', () {
      const profile = UserProfile(
        id: 'u1',
        fullName: 'wagneroliveira9819@gmail.com',
        isClient: true,
        isProvider: true,
      );
      expect(profile.displayName, 'Wagner Oliveira');
      expect(profile.firstName, 'Wagner');
      expect(profile.emailAddressIfPresent, 'wagneroliveira9819@gmail.com');
    });

    testWidgets('Meus selos (BadgeWall): todos os 6 selos exibem barra de progresso e abrem informativo elegante ao tocar (ex.: Super Profissional)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrapWithTheme(
          const Padding(
            padding: EdgeInsets.all(16),
            child: BadgeWall(
              earned: <String>[],
              tagCounts: <String, int>{'Super pontual': 4},
              fiveStarCount: 3,
              showProgress: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Super Profissional mostra 3/20 e Sempre Pontual mostra 4/15:
      expect(find.text('3/20'), findsOneWidget);
      expect(find.text('4/15'), findsOneWidget);

      // Toca em "Super Profissional" e abre o informativo elegante:
      await tester.tap(find.byKey(const ValueKey('badge-item-super')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('badge-sheet-title-super')), findsOneWidget);
      expect(find.text('Como conquistar'), findsOneWidget);
      expect(find.text('Dicas práticas no dia a dia'), findsOneWidget);
      expect(find.text('Vantagem real no perfil'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('btn-badge-sheet-close')));
      await tester.tap(find.byKey(const ValueKey('btn-badge-sheet-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('badge-sheet-title-super')), findsNothing);
    });

    testWidgets('ProviderFullHistoryScreen: filtros em faixa horizontal única com showCheckmark: false garantem zero quebra para baixo ao clicar em Sob Proteção Pós-Serviço ou Em Mediação', (tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      store.resetToCount(2);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.resolve(null, Brightness.light),
            home: const ProviderFullHistoryScreen(syncOnMount: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('history-filter-strip')), findsOneWidget);
      final initialStripHeight = tester.getSize(find.byKey(const ValueKey('history-filter-strip'))).height;
      final initialProtectionDy = tester.getTopLeft(find.byKey(const ValueKey('history-chip-protection'))).dy;

      // Clica em "Sob Proteção Pós-Serviço":
      await tester.ensureVisible(find.byKey(const ValueKey('history-chip-protection')));
      await tester.tap(find.byKey(const ValueKey('history-chip-protection')));
      await tester.pumpAndSettle();

      final afterProtectionStripHeight = tester.getSize(find.byKey(const ValueKey('history-filter-strip'))).height;
      final afterProtectionDy = tester.getTopLeft(find.byKey(const ValueKey('history-chip-protection'))).dy;
      expect(afterProtectionStripHeight, equals(initialStripHeight));
      expect(afterProtectionDy, equals(initialProtectionDy));

      // Clica em "Em Mediação":
      await tester.ensureVisible(find.byKey(const ValueKey('history-chip-mediation')));
      await tester.tap(find.byKey(const ValueKey('history-chip-mediation')));
      await tester.pumpAndSettle();

      final afterMediationStripHeight = tester.getSize(find.byKey(const ValueKey('history-filter-strip'))).height;
      expect(afterMediationStripHeight, equals(initialStripHeight));
    });
  });
}

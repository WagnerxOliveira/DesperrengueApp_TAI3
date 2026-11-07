import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:desperrengue_app/core/models/client_dossier_models.dart';
import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/models/provider_portfolio_models.dart';
import 'package:desperrengue_app/core/services/accurate_geo_routing_service.dart';
import 'package:desperrengue_app/core/state/provider_portfolio_controller.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/features/client/presentation/detalhe_servico_cliente_screen.dart';
import 'package:desperrengue_app/features/provider/presentation/provider_portfolio_widgets.dart';

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

      expect(find.text('Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG'), findsOneWidget);
      expect(find.text('Endereço registrado para o atendimento'), findsOneWidget);
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
  // FRENTE 2: MEU PORTFÓLIO INTELIGENTE + HISTÓRICO PERMANENTE VIA PIN
  // ===========================================================================
  group('Frente 2 — Rotação Automática por PIN, Desbloqueio no 4º Serviço e Avaliação Reativa', () {
    late ProviderPortfolioStore store;

    setUp(() {
      store = ProviderPortfolioStore.instance;
      store.resetToCount(0);
    });

    tearDown(() {
      // Restaura o estado padrão com 4 serviços após os testes
      store.resetToCount(
        4,
        curatedIds: <String>[kSamplePinCompletedServices.first.id],
      );
    });

    CompletedServiceRecord makeService(int n, {bool reviewed = false}) {
      return CompletedServiceRecord(
        id: 'test-srv-$n',
        orderId: 'test-order-$n',
        title: 'Serviço Técnico #$n',
        categoryName: 'Elétrica',
        detailedExecutionReport: 'Relatório técnico completo do serviço #$n.',
        cityAndState: 'Poços de Caldas - MG',
        completedAt: DateTime(2026, 11, 1, 10, n),
        validatedClientPin: (1000 + n).toString(),
        serviceValue: 150.0 + (n * 20),
        executionDurationText: '1h 15min',
        toolsAndMaterialsUsed: <String>['Ferramenta #$n'],
        beforeAfterPhotoCaptionsOrUrls: <String>['Antes/Depois #$n'],
        warrantyCertificateCode: 'GAR-TEST-$n',
        isReviewedByClient: reviewed,
        clientRating: reviewed ? 5.0 : null,
        clientReviewComment: reviewed ? 'Avaliação inicial #$n' : null,
      );
    }

    test('com 1, 2 ou 3 serviços concluídos via PIN: isAddFromHistoryUnlocked == false e não permite adicionar do Histórico', () {
      // 1º serviço
      store.completeAndValidateServiceWithPin(makeService(1));
      expect(store.state.totalCompletedCount, 1);
      expect(store.state.automaticTopThree.map((s) => s.id), <String>['test-srv-1']);
      expect(store.state.isAddFromHistoryUnlocked, isFalse);
      expect(store.state.eligibleHistoryPool, isEmpty);
      expect(store.addServiceFromHistoryToPortfolio('test-srv-1'), isFalse);

      // 2º serviço
      store.completeAndValidateServiceWithPin(makeService(2));
      expect(store.state.totalCompletedCount, 2);
      expect(
        store.state.automaticTopThree.map((s) => s.id),
        <String>['test-srv-2', 'test-srv-1'],
      );
      expect(store.state.isAddFromHistoryUnlocked, isFalse);

      // 3º serviço
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

    test('ao concluir o 4º serviço via PIN: entra em #1, empurra o 1º para eligibleHistoryPool (mantendo-o em fullHistory) e desbloqueia adição 1 por vez até 3', () {
      store.completeAndValidateServiceWithPin(makeService(1));
      store.completeAndValidateServiceWithPin(makeService(2));
      store.completeAndValidateServiceWithPin(makeService(3));

      // Conclui o 4º serviço via PIN:
      store.completeAndValidateServiceWithPin(makeService(4));

      expect(store.state.totalCompletedCount, 4);
      expect(store.state.isAddFromHistoryUnlocked, isTrue);

      // 4º serviço entrou em #1; 1º serviço saiu do Top 3 mas permanece em fullHistory e eligibleHistoryPool:
      expect(
        store.state.automaticTopThree.map((s) => s.id),
        <String>['test-srv-4', 'test-srv-3', 'test-srv-2'],
      );
      expect(
        store.state.fullHistory.map((s) => s.id),
        <String>['test-srv-4', 'test-srv-3', 'test-srv-2', 'test-srv-1'],
      );
      expect(
        store.state.eligibleHistoryPool.map((s) => s.id),
        <String>['test-srv-1'],
      );

      // Tentar adicionar um serviço que está nos 3 últimos não é permitido:
      expect(store.addServiceFromHistoryToPortfolio('test-srv-4'), isFalse);
      expect(store.addServiceFromHistoryToPortfolio('test-srv-3'), isFalse);

      // Adicionar o 1º serviço elegível do Histórico funciona (1 por vez):
      expect(store.addServiceFromHistoryToPortfolio('test-srv-1'), isTrue);
      expect(
        store.state.curatedPortfolioServices.map((s) => s.id),
        <String>['test-srv-1'],
      );

      // Conclui 5º, 6º e 7º serviços via PIN para testar o limite máximo de 3 destaques escolhidos:
      store.completeAndValidateServiceWithPin(makeService(5));
      store.completeAndValidateServiceWithPin(makeService(6));
      store.completeAndValidateServiceWithPin(makeService(7));

      expect(store.state.totalCompletedCount, 7);
      expect(
        store.state.automaticTopThree.map((s) => s.id),
        <String>['test-srv-7', 'test-srv-6', 'test-srv-5'],
      );
      expect(
        store.state.eligibleHistoryPool.map((s) => s.id),
        <String>['test-srv-4', 'test-srv-3', 'test-srv-2', 'test-srv-1'],
      );

      expect(store.addServiceFromHistoryToPortfolio('test-srv-2'), isTrue);
      expect(store.addServiceFromHistoryToPortfolio('test-srv-3'), isTrue);
      expect(store.state.curatedPortfolioServices, hasLength(3));

      // Tentar adicionar um 4º destaque escolhido retorna false (limite máximo = 3):
      expect(store.addServiceFromHistoryToPortfolio('test-srv-4'), isFalse);
      expect(store.state.curatedPortfolioServices, hasLength(3));

      // Remover um serviço de curatedPortfolioServices remove apenas da vitrine, mantendo fullHistory intacto:
      expect(store.removeCuratedServiceFromPortfolio('test-srv-2'), isTrue);
      expect(
        store.state.curatedPortfolioServices.map((s) => s.id),
        <String>['test-srv-1', 'test-srv-3'],
      );
      expect(store.state.fullHistory, hasLength(7));
    });

    test('syncClientEvaluationToHistoryAndPortfolio sincroniza nota e comentário reativamente no Histórico e no Portfólio', () {
      store.completeAndValidateServiceWithPin(makeService(1, reviewed: false));
      store.completeAndValidateServiceWithPin(makeService(2, reviewed: false));
      store.completeAndValidateServiceWithPin(makeService(3, reviewed: false));
      store.completeAndValidateServiceWithPin(makeService(4, reviewed: false));
      store.addServiceFromHistoryToPortfolio('test-srv-1');

      expect(store.state.automaticTopThree.first.isReviewedByClient, isFalse);
      expect(store.state.curatedPortfolioServices.first.isReviewedByClient, isFalse);

      // Cliente avalia o serviço #4 (no Top 3) e o serviço #1 (nos Destaques Escolhidos do Histórico):
      final okTop = store.syncClientEvaluationToHistoryAndPortfolio(
        serviceId: 'test-srv-4',
        rating: 5.0,
        comment: 'Serviço #4 impecável!',
        praiseTags: const <String>['Pontual', 'Excelente'],
      );
      final okCurated = store.syncClientEvaluationToHistoryAndPortfolio(
        orderId: 'test-order-1',
        rating: 4.8,
        comment: 'Serviço #1 muito bem feito!',
        praiseTags: const <String>['Limpo'],
      );

      expect(okTop, isTrue);
      expect(okCurated, isTrue);

      final top4 = store.state.automaticTopThree.firstWhere((s) => s.id == 'test-srv-4');
      expect(top4.isReviewedByClient, isTrue);
      expect(top4.clientRating, 5.0);
      expect(top4.clientReviewComment, 'Serviço #4 impecável!');

      final curated1 = store.state.curatedPortfolioServices.firstWhere((s) => s.id == 'test-srv-1');
      expect(curated1.isReviewedByClient, isTrue);
      expect(curated1.clientRating, 4.8);
      expect(curated1.clientReviewComment, 'Serviço #1 muito bem feito!');
    });

    testWidgets('UI ProviderSmartPortfolioSection oculta botão de adicionar com <= 3 serviços, desbloqueia no 4º e abre detalhes completos ao clicar', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      // Inicia com 3 serviços concluídos:
      store.resetToCount(3);

      await tester.pumpWidget(
        _wrapWithTheme(
          const Padding(
            padding: EdgeInsets.all(16),
            child: ProviderSmartPortfolioSection(isOwner: true),
          ),
        ),
      );
      await tester.pump();

      // Com 3 serviços, o botão de adicionar do Histórico NÃO existe e o aviso de bloqueio aparece:
      expect(find.byKey(const ValueKey('portfolio-curated-locked-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn-add-from-history-one-by-one')), findsNothing);

      // Simula a conclusão do 4º serviço com PIN pela própria UI:
      await tester.tap(find.byKey(const ValueKey('btn-simulate-next-pin-service')));
      await tester.pumpAndSettle();

      expect(store.state.totalCompletedCount, 4);
      expect(find.byKey(const ValueKey('portfolio-curated-locked-card')), findsNothing);
      expect(find.byKey(const ValueKey('btn-add-from-history-one-by-one')), findsOneWidget);

      // Toca no 1º card do Top 3 para abrir o modal de detalhes completos:
      final top1Id = store.state.automaticTopThree.first.id;
      await tester.tap(find.byKey(ValueKey('portfolio-top3-card-0-$top1Id')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('detail-sheet-service-title')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-sheet-pin-seal')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-sheet-execution-report')), findsOneWidget);
    });
  });
}

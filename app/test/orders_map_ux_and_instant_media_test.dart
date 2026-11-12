import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:desperrengue_app/core/models/client_dossier_models.dart';
import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/services/instant_image_cache_engine.dart';
import 'package:desperrengue_app/core/state/unread_orders_badge_controller.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/media_widgets.dart';
import 'package:desperrengue_app/core/ui/widgets.dart';
import 'package:desperrengue_app/core/utils/order_utils.dart';
import 'package:desperrengue_app/features/client/presentation/client_job_screen.dart';
import 'package:desperrengue_app/features/client/presentation/client_orders_tab.dart';
import 'package:desperrengue_app/features/client/presentation/detalhe_servico_cliente_screen.dart';
import 'package:desperrengue_app/features/shared/presentation/order_live_map_modal_screen.dart';
import 'package:latlong2/latlong.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.dark}) => MaterialApp(
      theme: AppTheme.resolve(null, brightness),
      home: child,
    );

Job _makeJob({
  required String id,
  required JobStatus status,
  required String title,
  String description = 'Descrição detalhada do pedido.',
  String category = 'Faxina e Limpeza',
  String? providerId,
  double? agreedPrice,
  String? addressSummary = 'Rua Padre José, 200 - Centro, Poços de Caldas - MG',
  double? latitude,
  double? longitude,
}) =>
    Job(
      id: id,
      clientId: 'client-wagner',
      providerId: providerId,
      title: title,
      description: description,
      category: category,
      status: status,
      paymentStatus: status == JobStatus.completed ? 'released' : 'pending',
      urgency: 'scheduled',
      visibility: 'public',
      createdAt: DateTime.utc(2026, 11, 12, 13, 0),
      scheduledFor: DateTime.utc(2026, 11, 17, 13, 0),
      agreedPrice: agreedPrice,
      addressSummary: addressSummary,
      latitude: latitude,
      longitude: longitude,
    );

Map<String, dynamic> _dossierMap({
  required String id,
  required String status,
  required String title,
  String category = 'Faxina e Limpeza',
  String description = 'Preciso de uma faxineira para trabalhar terça feira dia 17/11/2026, às 13h00.',
  String addressLine = 'Rua Padre José, 200 - Centro, Poços de Caldas - MG',
  double? latitude = -21.7878,
  double? longitude = -46.5614,
  String geoPrecision = 'house',
  String geoSource = 'client_geocode',
  double amount = 180.0,
  String? providerAvatarUrl,
}) =>
    <String, dynamic>{
      'job_id': id,
      'code': '#DESP-${id.substring(0, 5).toUpperCase()}',
      'title': title,
      'description': description,
      'category': category,
      'status': status,
      'urgency': 'scheduled',
      'created_at': '2026-11-12T13:00:00Z',
      'scheduled_for': '2026-11-17T13:00:00Z',
      'started_at': status == 'completed' ? '2026-11-12T13:05:00Z' : null,
      'finished_at': status == 'completed' ? '2026-11-12T15:30:00Z' : null,
      'canceled_at': status == 'canceled' ? '2026-11-12T14:00:00Z' : null,
      'cancel_reason': status == 'canceled' ? 'Cancelado pelo cliente.' : null,
      'address_summary': 'Centro • Poços de Caldas - MG',
      'photo_paths': const <String>['u/foto1.jpg', 'u/foto2.jpg'],
      'geo_precision': geoPrecision,
      'geo_source': geoSource,
      'address_line': addressLine,
      'latitude': latitude,
      'longitude': longitude,
      'amount': amount,
      'payment_status': status == 'completed' ? 'released' : (status == 'canceled' ? 'refunded' : 'pending'),
      'provider': status == 'completed'
          ? <String, dynamic>{
              'id': 'prov-wagner',
              'name': 'Wagner Oliveira',
              'title': 'Especialista Verificado',
              'rating_avg': 5.0,
              'rating_count': 18,
              'avatar_url': ?providerAvatarUrl,
            }
          : null,
      'evidence': <dynamic>[],
      'my_review': null,
    };

void main() {
  final Uint8List kValid1x1Png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+X2ZkAAAAASUVORK5CYII=',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UnreadOrdersBadgeController.instance.resetForTesting();
    InstantImageCacheEngine.instance.clearForTesting();
  });

  group('1. Decremento Instantâneo O(1) de Badges (1 -> 0) nas Abas de Pedidos', () {
    testWidgets(
      'Badges em Em Andamento, Concluídos, Cancelados e Em Mediação começam em 1 e caem para 0 (isLabelVisible: false) no exato clique do card',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final activeJob = _makeJob(
          id: 'cd070-active-id',
          status: JobStatus.open,
          title: 'Preciso de uma faxineira para trabalhar terça feira dia 17/11/2026, às 13h00.',
        );
        final doneJob = _makeJob(
          id: '278fd-done-id',
          status: JobStatus.completed,
          title: 'Olá Wagner, boa noite, tudo bem ? Preciso de um reparo hidráulico urgente.',
          category: 'Hidráulica',
          providerId: 'prov-1',
          agreedPrice: 220.0,
        );
        final canceledJob = _makeJob(
          id: 'c96ab-canceled-id',
          status: JobStatus.canceled,
          title: 'Troca de fechadura',
          category: 'Chaveiro',
        );
        final disputedJob = _makeJob(
          id: 'disp9-mediation-id',
          status: JobStatus.disputed,
          title: 'Reparo elétrico em garantia',
          category: 'Elétrica',
        );

        final openedIds = <String>[];
        final buckets = OrderBuckets.from([activeJob, doneJob, canceledJob, disputedJob]);

        await tester.pumpWidget(
          _host(
            Scaffold(
              body: OrdersTabs(
                buckets: buckets,
                includeMediationTab: true,
                onOpen: (_, job) => openedIds.add(job.id),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        Badge badgeFor(OrderTab tab) => tester.widget<Badge>(
              find.byKey(ValueKey('orders-tab-badge-${tab.name}')),
            );

        // Inicialmente todas as 4 abas possuem 1 pedido não visualizado -> badge visível com '1'
        expect(badgeFor(OrderTab.inProgress).isLabelVisible, isTrue);
        expect(badgeFor(OrderTab.completed).isLabelVisible, isTrue);
        expect(badgeFor(OrderTab.canceled).isLabelVisible, isTrue);
        expect(badgeFor(OrderTab.mediation).isLabelVisible, isTrue);
        expect(find.byKey(ValueKey('order-unread-dot-${activeJob.id}')), findsOneWidget);

        // 1) Toca no card de "Em Andamento" (#DESP-CD070) -> decrementa imediatamente 1 -> 0
        await tester.tap(find.byKey(ValueKey('order-card-${activeJob.id}')));
        await tester.pump();

        expect(openedIds, contains(activeJob.id));
        expect(badgeFor(OrderTab.inProgress).isLabelVisible, isFalse);
        expect(find.byKey(ValueKey('order-unread-dot-${activeJob.id}')), findsNothing);
        expect(UnreadOrdersBadgeController.instance.countUnread(OrderTab.inProgress, [activeJob]), 0);

        // 2) Vai para "Concluídos" (#DESP-278FD) e toca no card -> decrementa imediatamente 1 -> 0
        await tester.tap(find.text('Concluídos'));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('order-unread-dot-${doneJob.id}')), findsOneWidget);
        // Verifica também que a saudação crua "Olá Wagner, boa noite..." foi higienizada no título do card
        expect(find.textContaining('Olá Wagner'), findsNothing);

        await tester.tap(find.byKey(ValueKey('order-card-${doneJob.id}')));
        await tester.pump();
        expect(badgeFor(OrderTab.completed).isLabelVisible, isFalse);
        expect(UnreadOrdersBadgeController.instance.countUnread(OrderTab.completed, [doneJob]), 0);

        // 3) Vai para "Cancelados" (#DESP-C96AB) e toca no card -> decrementa imediatamente 1 -> 0
        await tester.tap(find.text('Cancelados'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('order-card-${canceledJob.id}')));
        await tester.pump();
        expect(badgeFor(OrderTab.canceled).isLabelVisible, isFalse);
        expect(UnreadOrdersBadgeController.instance.countUnread(OrderTab.canceled, [canceledJob]), 0);

        // 4) Vai para "Em Mediação" e toca no card -> decrementa imediatamente 1 -> 0
        await tester.tap(find.text('Em Mediação'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('order-card-${disputedJob.id}')));
        await tester.pump();
        expect(badgeFor(OrderTab.mediation).isLabelVisible, isFalse);
        expect(UnreadOrdersBadgeController.instance.countUnread(OrderTab.mediation, [disputedJob]), 0);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('2. Cabeçalho Hierárquico em 2 Andares Anti-Overflow (320x640, 360x780, 412x915, 480x960)', () {
    for (final viewport in const [Size(320, 640), Size(360, 780), Size(412, 915), Size(480, 960)]) {
      testWidgets(
        'DetalheServicoClienteScreen em viewport ${viewport.width.toInt()}x${viewport.height.toInt()} renderiza título em 100% da largura abaixo das pílulas sem quebra vertical',
        (tester) async {
          await tester.binding.setSurfaceSize(viewport);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final data = _dossierMap(
            id: 'cd070-long-title',
            status: 'open',
            title: 'Preciso de uma faxineira para trabalhar terça feira dia 17/11/2026, às 13h00.',
            category: 'Faxina e Limpeza',
          );

          await tester.pumpWidget(
            _host(
              DetalheServicoClienteScreen(
                jobId: 'cd070-long-title',
                dossierLoader: (_) async => ClientDossier.fromMap(data),
                quotesLoader: (_) async => const [],
                imageBuilder: (_, path, _) => Container(key: ValueKey('img:$path'), color: Colors.blueGrey),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(tester.takeException(), isNull);

          final pillRect = tester.getRect(find.byKey(const ValueKey('detail-category-pill')));
          final titleFinder = find.byKey(const ValueKey('detail-headline-title'));
          expect(titleFinder, findsOneWidget);
          final titleRect = tester.getRect(titleFinder);

          // Prova geométrica: o título está no 2º andar (abaixo da pílula) e ocupa a largura do card
          expect(
            titleRect.top,
            greaterThanOrEqualTo(pillRect.bottom),
            reason: 'O título deve ficar no Andar 2 (abaixo das pílulas do Andar 1), jamais esmagado ao lado de StatusChip',
          );
          expect(
            titleRect.width,
            greaterThanOrEqualTo(viewport.width - 80),
            reason: 'O título deve ocupar 100% da largura interna do AppCard',
          );
        },
      );
    }

    testWidgets(
      'Higieniza saudação conversacional ("Olá Wagner, boa noite, tudo bem ? ...") no cabeçalho mantendo descrição completa em "O que você pediu"',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 2600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const rawConversational =
            'Olá Wagner, boa noite, tudo bem ? Preciso de um técnico para consertar vazamento no sifão da cozinha.';
        final data = _dossierMap(
          id: '278fd-greeting',
          status: 'completed',
          title: rawConversational,
          description: rawConversational,
          category: 'Hidráulica',
        );

        await tester.pumpWidget(
          _host(
            DetalheServicoClienteScreen(
              jobId: '278fd-greeting',
              dossierLoader: (_) async => ClientDossier.fromMap(data),
              imageBuilder: (_, path, _) => Container(key: ValueKey('img:$path'), color: Colors.blueGrey),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final headlineWidget = tester.widget<Text>(find.byKey(const ValueKey('detail-headline-title')));
        expect(headlineWidget.data, isNot(startsWith('Olá Wagner')));
        expect(headlineWidget.data!.toLowerCase(), contains('consertar vazamento'));
        // E a descrição original completa continua preservada na seção "O que você pediu":
        expect(find.text(rawConversational), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('3. Mapa Sempre Presente e Tela Cheia Real (100% Viewport, Zero Duplicação, 1 Linha de Botões e Coerência por Status)', () {
    for (final viewport in const [Size(360, 780), Size(412, 915)]) {
      for (final status in const ['open', 'completed', 'canceled', 'disputed']) {
        testWidgets(
          'Estado "$status" em ${viewport.width.toInt()}x${viewport.height.toInt()} abre OrderLiveMapModalScreen em 100% da tela (>=62% livre), 1x endereço, 1 linha de botões e sem "Chegada ~"',
          (tester) async {
            await tester.binding.setSurfaceSize(viewport);
            addTearDown(() => tester.binding.setSurfaceSize(null));

            const address =
                'Travessa Pedro de Castro Souza, 200 - Country Club, Poços de Caldas - MG';

            final data = _dossierMap(
              id: 'job-$status-map',
              status: status,
              title: 'Reparo hidráulico especializado',
              category: 'Hidráulica',
              addressLine: address,
              latitude: null,
              longitude: null,
            );

            await tester.pumpWidget(
              _host(
                DetalheServicoClienteScreen(
                  jobId: 'job-$status-map',
                  dossierLoader: (_) async => ClientDossier.fromMap(data),
                  quotesLoader: (_) async => const [],
                  imageBuilder: (_, path, _) =>
                      Container(key: ValueKey('img:$path'), color: Colors.blueGrey),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));

            final locationCard = find.byKey(const ValueKey('detail-location'));
            await tester.scrollUntilVisible(
              locationCard,
              180,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pump();

            expect(locationCard, findsOneWidget);
            expect(
              find.byKey(const ValueKey('preview-live-map-cta-pill')),
              findsOneWidget,
            );
            // No card de preview em Detalhe do serviço, o nome da rua aparece exatamente 1 vez (sem pílulas duplicadas)
            expect(
              find.textContaining('Travessa Pedro de Castro Souza'),
              findsOneWidget,
            );

            await tester.tap(locationCard);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));
            await tester.pump(const Duration(milliseconds: 450));

            // 1) Tela cheia real: FlutterMap ocupa 100% da tela (>= 95% da viewport) e janela central livre >= 62%
            final mapSize =
                tester.getSize(find.byKey(const ValueKey('live-map')));
            expect(
              mapSize.height,
              greaterThanOrEqualTo(viewport.height * 0.95),
              reason:
                  'OrderLiveMapModalScreen deve ocupar 100% da tela (nunca ~140px)',
            );

            final topStripBottom = tester
                .getRect(find.byKey(const ValueKey('shortest-route-summary')))
                .bottom;
            final bottomCardTop = tester
                .getRect(
                  find.byKey(const ValueKey('order-live-map-executive-card')),
                )
                .top;
            final unobstructedHeight = bottomCardTop - topStripBottom;
            expect(
              unobstructedHeight,
              greaterThanOrEqualTo(viewport.height * 0.62),
              reason:
                  'Janela vertical desobstruída entre o topo e o card inferior deve ser >= 62% da altura da tela',
            );

            // 2) Zero duplicação/triplicação de endereço na tela do mapa:
            expect(
              find.byKey(const ValueKey('live-map-street-number')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('live-map-district-city-cep')),
              findsOneWidget,
            );
            expect(
              find.textContaining('Travessa Pedro de Castro Souza'),
              findsOneWidget,
              reason:
                  'O nome da rua deve aparecer EXATAMENTE 1 VEZ na tela do mapa (zero duplicação/triplicação)',
            );
            expect(find.textContaining('200'), findsOneWidget);
            expect(find.textContaining('Poços de Caldas'), findsOneWidget);

            // 3) 1 única linha horizontal de botões (mesmo dy central):
            final copyCenterDy = tester
                .getCenter(find.byKey(const ValueKey('copy-address-button')))
                .dy;
            final mapsCenterDy = tester
                .getCenter(
                  find.byKey(const ValueKey('open-external-maps-button')),
                )
                .dy;
            expect((copyCenterDy - mapsCenterDy).abs(), lessThan(1.0));

            if (status == 'open') {
              final adjustFinder = find.byKey(const ValueKey('adjust-pin'));
              expect(adjustFinder, findsOneWidget);
              final adjustCenterDy = tester.getCenter(adjustFinder).dy;
              expect((copyCenterDy - adjustCenterDy).abs(), lessThan(1.0));
            } else {
              expect(find.byKey(const ValueKey('adjust-pin')), findsNothing);
            }

            // 4) Coerência contextual por status: sem técnico ativo -> SEM "Chegada ~HH:mm" e SEM polilinha inicial:
            expect(
              find.byKey(const ValueKey('telemetry-distance-pill')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('telemetry-eta-pill')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('telemetry-arrival-pill')),
              findsNothing,
            );
            expect(find.textContaining('Chegada ~'), findsNothing);
            expect(
              find.byKey(const ValueKey('live-route-polyline')),
              findsNothing,
            );

            // Botão de 1 toque para ver rota de referência sem inventar "Chegada ~HH:mm":
            final toggleRouteBtn =
                find.byKey(const ValueKey('toggle-reference-route-button'));
            expect(toggleRouteBtn, findsOneWidget);
            await tester.tap(toggleRouteBtn);
            await tester.pump();
            expect(
              find.byKey(const ValueKey('live-route-polyline')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('telemetry-arrival-pill')),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets(
      'Em 320x640 com onAdjustPin ativo e quando providerOrigin é fornecido em in_progress: 3 botões em 1 única linha horizontal e rota + Chegada ~HH:mm visíveis',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _host(
            OrderLiveMapModalScreen(
              addressLine:
                  'Travessa Pedro de Castro Souza, 200 - Country Club, Poços de Caldas - MG',
              latitude: -21.7878,
              longitude: -46.5614,
              providerOrigin: const LatLng(-21.7800, -46.5550),
              orderStatus: 'in_progress',
              onAdjustPin: (_, _) async {},
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Em in_progress com providerOrigin ativo, exibe polilinha + Chegada ~HH:mm:
        expect(find.byKey(const ValueKey('live-route-polyline')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('telemetry-arrival-pill')),
          findsOneWidget,
        );
        expect(find.textContaining('Chegada ~'), findsOneWidget);

        // Mesmo em 320x640, os 3 botões ficam alinhados na mesma linha horizontal:
        final dy1 = tester
            .getCenter(find.byKey(const ValueKey('copy-address-button')))
            .dy;
        final dy2 = tester
            .getCenter(find.byKey(const ValueKey('open-external-maps-button')))
            .dy;
        final dy3 =
            tester.getCenter(find.byKey(const ValueKey('adjust-pin'))).dy;
        expect((dy1 - dy2).abs(), lessThan(1.0));
        expect((dy1 - dy3).abs(), lessThan(1.0));

        // Modo imersivo Auto-Dim on Pan: arrastar o mapa reduz opacidade dos overlays para 0.20 e restaura para 1.0 após soltar:
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('live-map'))),
        );
        await gesture.moveBy(const Offset(0, -64));
        await tester.pump(const Duration(milliseconds: 50));

        final dimmedOpacities = tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .map((w) => w.opacity)
            .toList();
        expect(dimmedOpacities, contains(0.20));

        await gesture.up();
        await tester.pump(const Duration(milliseconds: 260));

        final restoredOpacities = tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .map((w) => w.opacity)
            .toList();
        expect(restoredOpacities, isNot(contains(0.20)));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('4. Nova Tela "Pedido publicado" (WaitingQuotesScreen — LiveSearchRadarHeader & OrderPublishStepper)', () {
    for (final width in const [320.0, 360.0, 480.0]) {
      testWidgets(
        'Renderiza LiveSearchRadarHeader (120 FPS), OrderPublishStepper de 4 estágios, estado vazio e cards comparativos sem overflow em ${width.toInt()}px',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 2600));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final job = _makeJob(
            id: 'job-waiting-01',
            status: JobStatus.open,
            title: 'Trocar disjuntor bipolar',
            description: 'O disjuntor desarma toda hora no quadro principal.',
            category: 'Elétrica',
            latitude: -21.7878,
            longitude: -46.5614,
          );

          // 4.1 Sem orçamentos ainda
          await tester.pumpWidget(
            _host(
              WaitingQuotesScreen(
                job: job,
                quotesStream: Stream.value(const <Quote>[]),
                invitesStream: Stream.value(const <JobInvite>[]),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.byKey(const ValueKey('waiting-back')), findsOneWidget);
          expect(find.byKey(const ValueKey('waiting-hero')), findsOneWidget);
          expect(find.byKey(const ValueKey('live-radar-specialists-badge')), findsOneWidget);
          expect(find.byKey(const ValueKey('waiting-steps')), findsOneWidget);
          expect(find.textContaining('1. Pedido Publicado'), findsOneWidget);
          expect(find.textContaining('2. Especialistas Notificados'), findsOneWidget);
          expect(find.textContaining('3. Aguardando Propostas (0/3)'), findsOneWidget);
          expect(find.textContaining('4. Contratação Segura'), findsOneWidget);
          expect(find.byKey(const ValueKey('waiting-summary')), findsOneWidget);
          expect(find.byKey(const ValueKey('waiting-slots')), findsOneWidget);
          expect(find.text('Pagamento Protegido em Custódia'), findsOneWidget);
          expect(find.text('0% de taxa sobre materiais'), findsOneWidget);
          expect(find.byKey(const ValueKey('waiting-cancel')), findsOneWidget);
          expect(tester.takeException(), isNull);

          // 4.2 Com orçamento recebido
          final sampleQuote = Quote(
            id: 'q-1',
            jobId: job.id,
            providerId: 'prov-1',
            price: 195.0,
            message: 'Chego em 20 minutos com disjuntor novo.',
            estimatedHours: 1.5,
            status: 'pending',
            createdAt: DateTime.utc(2026, 11, 12, 13, 10),
          );

          await tester.pumpWidget(
            _host(
              WaitingQuotesScreen(
                job: job,
                quotesStream: Stream.value([sampleQuote]),
                invitesStream: Stream.value(const <JobInvite>[]),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text('1 orçamento recebido'), findsOneWidget);
          expect(find.textContaining('3. Aguardando Propostas (1/3)'), findsOneWidget);
          expect(find.text('R\$ 195,00'), findsOneWidget);
          expect(find.text('Ver orçamento'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('5. Renderização Instantânea de Avatar e Fotos em 0 ms via Cache L1 (Zero Pop-in)', () {
    testWidgets(
      'InstantCachedImage e UserAvatar pré-aquecidos em RAM renderizam RawImage já no primeiro frame (0 ms)',
      (tester) async {
        const avatarUrl = 'https://cdn.desperrengue.test/avatars/wagner-oliveira.png';
        const storagePath = 'service-evidence/278fd/foto-1.png';

        // Pré-aquece no Cache L1 em RAM antes de montar a árvore de widgets
        InstantImageCacheEngine.instance.putMemoryBytes(avatarUrl, kValid1x1Png);
        InstantImageCacheEngine.instance.putMemoryBytes(
          InstantImageCacheEngine.storageCacheKey(storagePath),
          kValid1x1Png,
        );

        await tester.pumpWidget(
          _host(
            const Scaffold(
              body: Column(
                children: [
                  UserAvatar(
                    url: avatarUrl,
                    name: 'Wagner Oliveira',
                    radius: 28,
                    verified: true,
                  ),
                  InstantCachedImage(
                    storagePath: storagePath,
                    width: 120,
                    height: 120,
                  ),
                ],
              ),
            ),
          ),
        );

        // No exato primeiro frame (sem nenhum pump adicional!), ambos já exibem MemoryImage decodificado
        expect(InstantImageCacheEngine.instance.peekMemoryBytes(avatarUrl), isNotNull);
        expect(
          InstantImageCacheEngine.instance.peekMemoryBytes(
            InstantImageCacheEngine.storageCacheKey(storagePath),
          ),
          isNotNull,
        );
        expect(find.byType(Image), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    test(
      'Hidratação paralela de Boot (L2 avatares + badges lidos) restaura RAM antes do frame 1',
      () async {
        const persistedAvatarUrl = 'https://cdn.desperrengue.test/avatars/persisted-l2.png';
        final doneJob = _makeJob(
          id: '278fd-persisted',
          status: JobStatus.completed,
          title: 'Reparo hidráulico',
          providerId: 'prov-wagner',
          agreedPrice: 220.0,
        );

        final mockClient = MockClient(
          (_) async => http.Response.bytes(kValid1x1Png, 200),
        );

        // Sessão 1: salva avatar compacto em L2 e marca pedido como visualizado
        final fetched = await InstantImageCacheEngine.instance.getOrFetchUrlBytes(
          persistedAvatarUrl,
          client: mockClient,
        );
        expect(fetched, isNotNull);
        await UnreadOrdersBadgeController.instance.markViewed(doneJob);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Simula reinício frio do app (limpa apenas a memória volátil L1 e estado em RAM)
        InstantImageCacheEngine.instance.clearForTesting();
        UnreadOrdersBadgeController.instance.resetForTesting();
        expect(InstantImageCacheEngine.instance.peekMemoryBytes(persistedAvatarUrl), isNull);

        // Equivalente exato ao BootGate._warmUp() durante a splash animada
        InstantImageCacheEngine.instance.configureGlobalImageCache();
        await Future.wait<void>([
          InstantImageCacheEngine.instance.ensurePersistentCacheLoaded(),
          UnreadOrdersBadgeController.instance.ensureLoaded(),
        ]);

        // Antes do 1º frame do app: L1 já hidratada (0 ms) e badge já lembra leitura
        expect(InstantImageCacheEngine.instance.peekMemoryBytes(persistedAvatarUrl), isNotNull);
        expect(UnreadOrdersBadgeController.instance.isUnread(doneJob), isFalse);
      },
    );

    test(
      'EagerImagePrefetcher.prefetchJobs pré-aquece avatares por providerId e deduplica _warmedProviderIds na sessão',
      () async {
        const providerAvatarUrl = 'https://cdn.desperrengue.test/avatars/prov-wagner-278fd.png';
        final job1 = _makeJob(
          id: '278fd-done-1',
          status: JobStatus.completed,
          title: 'Serviço concluído 1',
          providerId: 'prov-wagner',
        );
        final job2SameProvider = _makeJob(
          id: '991aa-done-2',
          status: JobStatus.completed,
          title: 'Serviço concluído 2',
          providerId: 'prov-wagner',
        );

        var resolverCalls = 0;
        var avatarHttpCalls = 0;
        final mockClient = MockClient((req) async {
          if (req.url.toString() == providerAvatarUrl) {
            avatarHttpCalls++;
            return http.Response.bytes(kValid1x1Png, 200);
          }
          return http.Response('', 404);
        });

        Future<Map<String, ProviderCard>> fakeResolver(Iterable<String> ids) async {
          resolverCalls++;
          return <String, ProviderCard>{
            for (final id in ids)
              id: const ProviderCard(
                id: 'prov-wagner',
                fullName: 'Wagner Oliveira',
                avatarUrl: providerAvatarUrl,
              ),
          };
        }

        // 1ª chamada (ex.: Home ou Meus Pedidos em 00:14): aquece e deduplica os 2 jobs do mesmo prestador
        EagerImagePrefetcher.prefetchJobs(
          [job1, job2SameProvider],
          providerResolver: fakeResolver,
          client: mockClient,
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(resolverCalls, 1);
        expect(avatarHttpCalls, 1);
        expect(EagerImagePrefetcher.debugWarmedProviderIds, contains('prov-wagner'));
        expect(InstantImageCacheEngine.instance.peekMemoryBytes(providerAvatarUrl), isNotNull);

        // 2ª chamada na mesma sessão (ex.: rebuild do stream): zero reconsulta!
        EagerImagePrefetcher.prefetchJobs(
          [job1],
          providerResolver: fakeResolver,
          client: mockClient,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(resolverCalls, 1);
        expect(avatarHttpCalls, 1);

        // clearForTesting reseta _warmedProviderIds para isolamento entre suítes
        InstantImageCacheEngine.instance.clearForTesting();
        expect(EagerImagePrefetcher.debugWarmedProviderIds, isEmpty);
      },
    );

    testWidgets(
      'Cold-miss guard em DetalheServicoClienteScreen._load aguarda avatar antes de exibir _content (zero círculo escuro no frame 1)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const coldAvatarUrl = 'https://cdn.desperrengue.test/avatars/cold-miss-278fd.png';
        expect(InstantImageCacheEngine.instance.peekMemoryBytes(coldAvatarUrl), isNull);

        final mockClient = MockClient((req) async {
          if (req.url.toString() == coldAvatarUrl) {
            return http.Response.bytes(kValid1x1Png, 200);
          }
          return http.Response('', 404);
        });

        final dossier = ClientDossier.fromMap(
          _dossierMap(
            id: '278fd-cold-miss',
            status: 'completed',
            title: 'Instalação hidráulica residencial',
            providerAvatarUrl: coldAvatarUrl,
          ),
        );

        await tester.pumpWidget(
          _host(
            DetalheServicoClienteScreen(
              jobId: dossier.jobId,
              dossierLoader: (_) async => dossier,
              imageBuilder: (_, _, _) => const SizedBox(width: 80, height: 80),
              avatarHttpClient: mockClient,
            ),
          ),
        );

        // Avança microtasks de _load() até o 1º frame em que _content monta na árvore
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));

        // No exato frame em que o detalhe #DESP-278FD aparece, os bytes do avatar já estão em L1 RAM!
        expect(find.byKey(const ValueKey('provider-profile')), findsOneWidget);
        expect(find.text('Wagner Oliveira'), findsOneWidget);
        expect(InstantImageCacheEngine.instance.peekMemoryBytes(coldAvatarUrl), isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

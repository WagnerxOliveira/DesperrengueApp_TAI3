import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  group('3. Mapa Sempre Presente e Modal Interativo em TODOS os Estados (Em Andamento, Concluídos, Cancelados, Em Mediação)', () {
    for (final status in const ['open', 'completed', 'canceled', 'disputed']) {
      testWidgets(
        'Estado "$status" exibe mini-mapa (mesmo sem coordenadas prévias no banco) e abre OrderLiveMapModalScreen ao tocar em detail-location',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(412, 2600));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          // Simula pedido (inclusive concluído #DESP-278FD, cancelado #DESP-C96AB ou em mediação) sem latitude/longitude salvas:
          final address = status == 'completed'
              ? 'Travessa Pedro de Castro Souza, 200 - Centro, Poços de Caldas - MG'
              : 'Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG';
          final expectedStreet = status == 'completed'
              ? 'Travessa Pedro de Castro Souza'
              : 'Rua Padre José Geraldi';
          final expectedNumber = status == 'completed' ? '200' : '203';
          final expectedDistrict = status == 'completed' ? 'Centro' : 'Maria Imaculada';

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
                imageBuilder: (_, path, _) => Container(key: ValueKey('img:$path'), color: Colors.blueGrey),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          final locationCard = find.byKey(const ValueKey('detail-location'));
          expect(locationCard, findsOneWidget);
          expect(find.byKey(const ValueKey('preview-live-map-cta-pill')), findsOneWidget);

          await tester.ensureVisible(locationCard);
          await tester.pump();
          await tester.tap(locationCard);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Verifica que o modal cartográfico completo abriu com Rua, Número, Bairro, Cidade, km e min
          expect(find.byKey(const ValueKey('order-live-map-executive-card')), findsOneWidget);
          expect(find.byKey(const ValueKey('live-map-street-number')), findsOneWidget);
          expect(find.textContaining(expectedStreet), findsWidgets);
          expect(find.textContaining(expectedNumber), findsWidgets);
          expect(find.textContaining(expectedDistrict), findsWidgets);
          expect(find.textContaining('Poços de Caldas'), findsWidgets);
          expect(find.byKey(const ValueKey('telemetry-distance-pill')), findsOneWidget);
          expect(find.byKey(const ValueKey('telemetry-eta-pill')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
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
  });
}

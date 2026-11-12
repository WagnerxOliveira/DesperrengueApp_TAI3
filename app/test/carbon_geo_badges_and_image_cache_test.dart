import 'dart:convert';
import 'dart:typed_data';

import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/models/scheduling_models.dart';
import 'package:desperrengue_app/core/models/structured_service_address.dart';
import 'package:desperrengue_app/core/services/accurate_geo_routing_service.dart';
import 'package:desperrengue_app/core/services/geocoding_service.dart';
import 'package:desperrengue_app/core/services/instant_image_cache_engine.dart';
import 'package:desperrengue_app/core/services/precise_geocoder.dart';
import 'package:desperrengue_app/core/services/real_time_route_and_traffic_service.dart';
import 'package:desperrengue_app/core/state/unread_orders_badge_controller.dart';
import 'package:desperrengue_app/core/utils/order_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PNG válido minimalista 1x1 transparente (sem usar dart:io — 100% Web/Mobile safe).
final Uint8List _kTransparentPng1x1 = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

Job _makeJob({
  required String id,
  required JobStatus status,
  String? providerId,
  double? agreedPrice,
  List<String> photoPaths = const <String>[],
}) {
  return Job(
    id: id,
    clientId: 'client-wagner',
    title: 'Serviço $id',
    description: 'Descrição técnica do pedido $id',
    category: 'Elétrica',
    status: status,
    paymentStatus: agreedPrice != null ? 'escrow' : 'pending',
    urgency: 'scheduled',
    visibility: 'open',
    createdAt: DateTime(2026, 11, 11, 12, 37),
    providerId: providerId,
    agreedPrice: agreedPrice,
    photoPaths: photoPaths,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PreciseGeocoder.clearCache();
    AccurateGeoRoutingService.clearCache();
    GeocodingService.clearCache();
    RealTimeRouteAndTrafficService.instance.clearCache();
    UnreadOrdersBadgeController.instance.resetForTesting();
    InstantImageCacheEngine.instance.clearForTesting(clearGlobalImageCache: true);
  });

  // ===========================================================================
  // A) StructuredServiceAddress — Parsing Brasileiro Real & Regra Inegociável
  // ===========================================================================
  group('StructuredServiceAddress — Parsing exato e preservação de fachada', () {
    test('extrai com 100% de fidelidade os dois endereços reais do vídeo (Poços de Caldas - MG)', () {
      const videoAddr1 =
          'Travessa Pedro de Castro Souza, 200 - Country Club, Poços de Caldas - MG';
      final a1 = StructuredServiceAddress.parse(videoAddr1);

      expect(a1.streetName, 'Travessa Pedro de Castro Souza');
      expect(a1.houseNumber, '200');
      expect(a1.complement, isEmpty);
      expect(a1.neighborhood, 'Country Club');
      expect(a1.city, 'Poços de Caldas');
      expect(a1.uf, 'MG');
      expect(a1.hasCoordinates, isFalse);
      expect(a1.streetWithNumber, 'Travessa Pedro de Castro Souza, 200');
      expect(a1.districtCityState, 'Country Club, Poços de Caldas - MG');
      expect(a1.formattedFullLine, videoAddr1);

      const videoAddr2 =
          'Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG';
      final a2 = StructuredServiceAddress.parse(
        videoAddr2,
        latitude: -21.80271,
        longitude: -46.60281,
        precision: DestinationPrecision.house,
      );

      expect(a2.streetName, 'Rua Padre José Geraldi');
      expect(a2.houseNumber, '203');
      expect(a2.neighborhood, 'Maria Imaculada');
      expect(a2.city, 'Poços de Caldas');
      expect(a2.uf, 'MG');
      expect(a2.hasCoordinates, isTrue);
      expect(a2.streetWithNumber, 'Rua Padre José Geraldi, 203');
      expect(a2.districtCityState, 'Maria Imaculada, Poços de Caldas - MG');
      expect(a2.formattedFullLine, videoAddr2);
    });

    test('suporta S/N, alfanuméricos (120A), complemento, referência "| Ref:" e CEP embutido', () {
      final sn = StructuredServiceAddress.parse(
        'Rua das Flores, s/n - Centro, Poços de Caldas - MG',
      );
      expect(sn.streetName, 'Rua das Flores');
      expect(sn.houseNumber, 'S/N');
      expect(sn.neighborhood, 'Centro');
      expect(sn.city, 'Poços de Caldas');
      expect(sn.uf, 'MG');

      final alpha = StructuredServiceAddress.parse(
        'Avenida João Pinheiro, 120A, Apto 302 - Centro, Poços de Caldas - MG, CEP 37701-386 | Ref: Em frente à praça',
      );
      expect(alpha.streetName, 'Avenida João Pinheiro');
      expect(alpha.houseNumber, '120A');
      expect(alpha.complement, 'Apto 302');
      expect(alpha.neighborhood, 'Centro');
      expect(alpha.city, 'Poços de Caldas');
      expect(alpha.uf, 'MG');
      expect(alpha.cep, '37701-386');
      expect(alpha.cepDigits, '37701386');
      expect(alpha.referencePoint, 'Em frente à praça');

      final roundTrip = StructuredServiceAddress.fromJson(alpha.toJson());
      expect(roundTrip, equals(alpha));
    });

    test('REGRA INEGOCIÁVEL: enrichMissing jamais apaga nem sobrescreve houseNumber, streetName, neighborhood ou city do cliente', () {
      final original = StructuredServiceAddress.parse(
        'Travessa Pedro de Castro Souza, 200 - Country Club, Poços de Caldas - MG',
      );

      // Mesmo que o OSM/Nominatim devolva número vazio/diferente ou bairro genérico:
      final enriched = original.enrichMissing(
        streetName: 'Rua Genérica OSM',
        houseNumber: '',
        neighborhood: 'Zona Oeste',
        city: 'Outra Cidade',
        uf: 'SP',
        cep: '37701354',
        latitude: -21.78845,
        longitude: -46.59250,
        precision: DestinationPrecision.house,
      );

      expect(enriched.streetName, 'Travessa Pedro de Castro Souza');
      expect(enriched.houseNumber, '200');
      expect(enriched.neighborhood, 'Country Club');
      expect(enriched.city, 'Poços de Caldas');
      expect(enriched.uf, 'MG');
      expect(enriched.cep, '37701-354');
      expect(enriched.hasCoordinates, isTrue);
      expect(enriched.formattedFullLine, original.formattedFullLine);
    });
  });

  // ===========================================================================
  // B) Geocodificação Persistente + Rota OSRM + Trânsito Urbano Dinâmico
  // ===========================================================================
  group('PreciseGeocoder, AccurateGeoRoutingService & RealTimeRouteAndTrafficService', () {
    test('resolve instantaneamente pedidos antigos sem lat/lng (Concluídos / Cancelados do vídeo) com CEP oficial e cache persistente', () async {
      final svc = RealTimeRouteAndTrafficService();

      // Caso real de Concluídos no vídeo (#DESP-278FD sem coordenadas prévias):
      final resolvedConcluido = await svc.resolveExactAddress(
        addressLine: 'Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG',
        latitude: null,
        longitude: null,
      );

      expect(resolvedConcluido.hasCoordinates, isTrue);
      expect(resolvedConcluido.streetName, 'Rua Padre José Geraldi');
      expect(resolvedConcluido.houseNumber, '203');
      expect(resolvedConcluido.neighborhood, 'Maria Imaculada');
      expect(resolvedConcluido.city, 'Poços de Caldas');
      expect(resolvedConcluido.uf, 'MG');
      expect(resolvedConcluido.cep, '37701-110');
      expect(resolvedConcluido.precision, DestinationPrecision.house);
      expect(resolvedConcluido.latitude!, closeTo(-21.8026, 0.003));
      expect(resolvedConcluido.longitude!, closeTo(-46.6027, 0.003));

      // Caso real de Em Andamento no vídeo (#DESP-CD070):
      final resolvedAndamento = await svc.resolveExactAddress(
        addressLine: 'Travessa Pedro de Castro Souza, 200 - Country Club, Poços de Caldas - MG',
      );

      expect(resolvedAndamento.hasCoordinates, isTrue);
      expect(resolvedAndamento.streetName, 'Travessa Pedro de Castro Souza');
      expect(resolvedAndamento.houseNumber, '200');
      expect(resolvedAndamento.neighborhood, 'Country Club');
      expect(resolvedAndamento.city, 'Poços de Caldas');
      expect(resolvedAndamento.uf, 'MG');
      expect(resolvedAndamento.cep, '37701-354');
      expect(resolvedAndamento.precision, DestinationPrecision.house);

      // Hit síncrono em 0 ms no cache LRU do AccurateGeoRoutingService:
      final syncHit = AccurateGeoRoutingService.peekCachedExactAddress(
        'Travessa Pedro de Castro Souza, 200 - Country Club, Poços de Caldas - MG',
        cep: '37701354',
      );
      expect(syncHit, isNotNull);
      expect(syncHit!.lat, equals(resolvedAndamento.latitude));
    });

    test('PreciseGeocoder: BrasilAPI CEP v2 + persistência em SharedPreferences sobrevivendo a restart de memória', () async {
      var httpCalls = 0;
      final client = MockClient((req) async {
        httpCalls++;
        if (req.url.host == 'photon.komoot.io') {
          return http.Response('{"features":[]}', 200);
        }
        if (req.url.host == 'cep.awesomeapi.com.br') {
          return http.Response('{}', 404); // Simula falha da AwesomeAPI
        }
        if (req.url.host == 'brasilapi.com.br') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'cep': '37701354',
                'state': 'MG',
                'city': 'Poços de Caldas',
                'neighborhood': 'Country Club',
                'street': 'Travessa Pedro de Castro Souza',
                'location': {
                  'type': 'Point',
                  'coordinates': {
                    'longitude': '-46.59245',
                    'latitude': '-21.78845',
                  },
                },
              }),
            ),
            200,
          );
        }
        return http.Response('[]', 200);
      });

      final geocoder = PreciseGeocoder(client: client, useCache: true);
      const addr = 'Travessa Pedro de Castro Souza, 200 - Country Club, Poços de Caldas - MG';
      final hit1 = await geocoder.geocode(addr, cep: '37701-354');
      expect(hit1, isNotNull);
      expect(hit1!.precision, DestinationPrecision.street);
      expect(hit1.lat, closeTo(-21.78845, 1e-5));
      final firstCallCount = httpCalls;
      expect(firstCallCount, greaterThan(0));

      // Segunda chamada: hit em L1 LRU RAM sem fazer NENHUM request HTTP:
      final hit2 = await geocoder.geocode(addr, cep: '37701-354');
      expect(hit2!.lat, equals(hit1.lat));
      expect(httpCalls, equals(firstCallCount));

      // Simula reinicialização do app (limpa RAM mas mantém SharedPreferences):
      await Future<void>.delayed(const Duration(milliseconds: 20));
      PreciseGeocoder.clearCache();

      final offlineGeocoder = PreciseGeocoder(
        client: MockClient((_) async => throw Exception('offline')),
        useCache: true,
      );
      final hitFromDisk = await offlineGeocoder.geocode(addr, cep: '37701-354');
      expect(hitFromDisk, isNotNull);
      expect(hitFromDisk!.lat, closeTo(-21.78845, 1e-5));
    });

    test('RealTimeRouteAndTrafficService.computeRoute: OSRM + cache LRU 1e-4 + faixas horárias de trânsito + fallback de malha urbana ortogonal suavizada', () async {
      var osrmNetworkCalls = 0;
      final mockOsrm = MockClient((req) async {
        osrmNetworkCalls++;
        expect(req.url.host, 'router.project-osrm.org');
        expect(req.url.queryParameters['overview'], 'full');
        expect(req.url.queryParameters['geometries'], 'geojson');
        expect(req.url.queryParameters['steps'], 'true');
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'distance': 3420.0,
                'duration': 420.0, // 7 min livres
                'geometry': {
                  'coordinates': [
                    [-46.5662, -21.7878],
                    [-46.5780, -21.7895],
                    [-46.5860, -21.7880],
                    [-46.5925, -21.7885],
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final routeSvc = RealTimeRouteAndTrafficService(client: mockOsrm);
      const origin = LatLng(-21.78780, -46.56620);
      const dest = LatLng(-21.78845, -46.59250);

      // 1) Pico tarde (18:15) -> Trânsito Intenso:
      final rushDeparture = DateTime(2026, 11, 12, 18, 15);
      final rushSnap = await routeSvc.computeRoute(
        origin: origin,
        destination: dest,
        departureTime: rushDeparture,
      );
      expect(osrmNetworkCalls, 1);
      expect(rushSnap.isRoadGeometry, isTrue);
      expect(rushSnap.distanceKm, closeTo(3.42, 0.01));
      expect(rushSnap.formattedDistance, '3,4 km');
      expect(rushSnap.condition, TrafficConditionLevel.heavy);
      expect(rushSnap.conditionLabel, 'Trânsito Intenso');
      expect(rushSnap.trafficAdjustedMinutes, greaterThan(rushSnap.baseDurationMinutes));
      expect(rushSnap.formattedEta, '${rushSnap.trafficAdjustedMinutes} min');

      // 2) Coordenada levemente deslocada dentro de 1e-4 em horário de madrugada (03:10):
      // Deve bater no cache LRU (zero chamadas extras ao OSRM!) e recalcular Trânsito Fluido!
      final dawnDeparture = DateTime(2026, 11, 12, 3, 10);
      final dawnSnap = await routeSvc.computeRoute(
        origin: const LatLng(-21.78782, -46.56619),
        destination: const LatLng(-21.78847, -46.59249),
        departureTime: dawnDeparture,
      );
      expect(osrmNetworkCalls, 1, reason: 'Cache LRU 1e-4 deve evitar segunda chamada de rede');
      expect(dawnSnap.condition, TrafficConditionLevel.fluent);
      expect(dawnSnap.conditionLabel, 'Trânsito Fluido');
      expect(dawnSnap.trafficAdjustedMinutes, lessThan(rushSnap.trafficAdjustedMinutes));

      // 3) Faixa de almoço (12:20) -> Trânsito Moderado:
      final lunchSnap = await routeSvc.computeRoute(
        origin: origin,
        destination: dest,
        departureTime: DateTime(2026, 11, 12, 12, 20),
      );
      expect(lunchSnap.condition, TrafficConditionLevel.moderate);
      expect(lunchSnap.conditionLabel, 'Trânsito Moderado');

      // 4) Fallback offline (rede indisponível) -> Malha urbana ortogonal suavizada (NUNCA linha reta seca de 2 pontos!):
      final offlineSvc = RealTimeRouteAndTrafficService(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      final fallbackSnap = await offlineSvc.computeRoute(
        origin: origin,
        destination: const LatLng(-21.80271, -46.60281),
        departureTime: DateTime(2026, 11, 12, 8, 0), // Pico manhã
      );
      expect(fallbackSnap.isRoadGeometry, isFalse);
      expect(fallbackSnap.polylinePoints.length, greaterThanOrEqualTo(10));
      expect(fallbackSnap.polylinePoints.first, equals(origin));
      expect(fallbackSnap.polylinePoints.last, equals(const LatLng(-21.80271, -46.60281)));
      expect(fallbackSnap.condition, TrafficConditionLevel.heavy);
      expect(fallbackSnap.conditionLabel, 'Trânsito Intenso');
      expect(fallbackSnap.formattedArrivalTime, matches(RegExp(r'^\d{2}:\d{2}$')));
    });
  });

  // ===========================================================================
  // C) UnreadOrdersBadgeController — Decremento O(1) em 0 ms nas 4 Abas
  // ===========================================================================
  group('UnreadOrdersBadgeController — Máquina de Estados O(1) em 0 ms', () {
    test('decrementa 1 -> 0 de forma 100% síncrona (0 ms antes do await) em Em Andamento, Concluídos, Cancelados e Em Mediação', () async {
      final ctrl = UnreadOrdersBadgeController(currentUserIdResolver: () => 'wagner-uid');

      final jobOpen = _makeJob(id: 'cd070-00000', status: JobStatus.open);
      final jobDone = _makeJob(
        id: '278fd-00000',
        status: JobStatus.completed,
        providerId: 'prov-1',
        agreedPrice: 150.0,
      );
      final jobCanceled = _makeJob(
        id: 'c96ab-00000',
        status: JobStatus.canceled,
        providerId: 'prov-2',
        agreedPrice: 300.0,
      );
      final jobDisputed = _makeJob(
        id: 'disp1-00000',
        status: JobStatus.disputed,
        providerId: 'prov-3',
        agreedPrice: 220.0,
      );

      final buckets = OrderBuckets.from([jobOpen, jobDone, jobCanceled, jobDisputed]);

      expect(ctrl.countUnread(OrderTab.inProgress, buckets.inProgress), 1);
      expect(ctrl.countUnread(OrderTab.completed, buckets.completed), 1);
      expect(ctrl.countUnread(OrderTab.canceled, buckets.canceled), 1);
      expect(ctrl.countUnread(OrderTab.mediation, buckets.mediation), 1);

      var notifications = 0;
      ctrl.addListener(() => notifications++);

      // Toca em Em Andamento: ANTES mesmo do `await`, o contador já caiu para 0 e notificou!
      final pendingFuture1 = ctrl.markViewed(jobOpen, tab: OrderTab.inProgress);
      expect(notifications, 1, reason: 'notifyListeners deve disparar em 0 ms síncrono');
      expect(ctrl.isUnread(jobOpen, tab: OrderTab.inProgress), isFalse);
      expect(ctrl.countUnread(OrderTab.inProgress, buckets.inProgress), 0);
      await pendingFuture1;

      // Toca em Concluídos:
      final pendingFuture2 = ctrl.markViewed(jobDone, tab: OrderTab.completed);
      expect(notifications, 2);
      expect(ctrl.countUnread(OrderTab.completed, buckets.completed), 0);
      await pendingFuture2;

      // Toca em Cancelados:
      final pendingFuture3 = ctrl.markViewed(jobCanceled, tab: OrderTab.canceled);
      expect(notifications, 3);
      expect(ctrl.countUnread(OrderTab.canceled, buckets.canceled), 0);
      await pendingFuture3;

      // Toca em Em Mediação:
      final pendingFuture4 = ctrl.markViewed(jobDisputed, tab: OrderTab.mediation);
      expect(notifications, 4);
      expect(ctrl.countUnread(OrderTab.mediation, buckets.mediation), 0);
      await pendingFuture4;

      // Novo controller simulando reabertura do app: hidrata de SharedPreferences e mantém tudo 0!
      final restartedCtrl = UnreadOrdersBadgeController(currentUserIdResolver: () => 'wagner-uid');
      await restartedCtrl.ensureLoaded();
      expect(restartedCtrl.countUnread(OrderTab.inProgress, buckets.inProgress), 0);
      expect(restartedCtrl.countUnread(OrderTab.completed, buckets.completed), 0);
      expect(restartedCtrl.countUnread(OrderTab.canceled, buckets.canceled), 0);
      expect(restartedCtrl.countUnread(OrderTab.mediation, buckets.mediation), 0);
    });

    test('volta a notificar automaticamente quando o pedido muda de status ou preço acordado', () async {
      final ctrl = UnreadOrdersBadgeController();
      final initialJob = _makeJob(id: 'job-trans-1', status: JobStatus.open);

      await ctrl.markViewed(initialJob);
      expect(ctrl.isUnread(initialJob), isFalse);

      // Recebeu proposta aceita / agendado:
      final scheduledJob = _makeJob(
        id: 'job-trans-1',
        status: JobStatus.scheduled,
        providerId: 'prov-99',
        agreedPrice: 180.0,
      );
      expect(ctrl.isUnread(scheduledJob), isTrue);
      expect(ctrl.countUnread(OrderTab.inProgress, [scheduledJob]), 1);

      // Marcado via DetalheServicoClienteScreen direto por jobId:
      await ctrl.markViewedByIdAndStatus(
        jobId: 'job-trans-1',
        status: JobStatus.scheduled,
        providerId: 'prov-99',
        price: 180.0,
      );
      expect(ctrl.isUnread(scheduledJob), isFalse);

      // Migrou para Concluídos: gera nova assinatura não lida na aba Concluídos!
      final completedJob = _makeJob(
        id: 'job-trans-1',
        status: JobStatus.completed,
        providerId: 'prov-99',
        agreedPrice: 180.0,
      );
      expect(ctrl.isUnread(completedJob), isTrue);
      expect(ctrl.countUnread(OrderTab.completed, [completedJob]), 1);
    });
  });

  // ===========================================================================
  // D) InstantImageCacheEngine & EagerImagePrefetcher — Latência 0 ms em RAM
  // ===========================================================================
  group('InstantImageCacheEngine & EagerImagePrefetcher — Latência Zero (0 ms)', () {
    test('hit síncrono 0 ms em L1 RAM + deduplicação _inFlight + memoização de 45 min para Storage privado', () async {
      var currentTime = DateTime(2026, 11, 12, 12, 0);
      final engine = InstantImageCacheEngine(
        maxMemoryBytes: 1024 * 1024,
        clock: () => currentTime,
      );
      engine.configureGlobalImageCache();

      var httpDownloads = 0;
      final client = MockClient((req) async {
        httpDownloads++;
        await Future<void>.delayed(const Duration(milliseconds: 25));
        return http.Response.bytes(_kTransparentPng1x1, 200);
      });

      const avatarUrl = 'https://cdn.desperrengue.app/avatars/wagner.png';
      expect(engine.peekMemoryBytes(avatarUrl), isNull);

      // Dispara 8 downloads simultâneos na mesma URL: _inFlight deve fazer apenas 1 GET HTTP!
      final results = await Future.wait([
        for (var i = 0; i < 8; i++) engine.getOrFetchUrlBytes(avatarUrl, client: client),
      ]);
      expect(httpDownloads, 1);
      for (final r in results) {
        expect(r, isNotNull);
        expect(r!.lengthInBytes, _kTransparentPng1x1.lengthInBytes);
      }

      // Agora está residente em L1 RAM: peekMemoryBytes responde em 0 ms síncrono!
      final sw = Stopwatch()..start();
      final instantBytes = engine.peekMemoryBytes(avatarUrl);
      sw.stop();
      expect(instantBytes, isNotNull);
      expect(sw.elapsedMilliseconds, lessThanOrEqualTo(1));

      // Teste de Storage privado com chave estável 'storage:$path' e TTL de 45 min da URL assinada:
      var signCalls = 0;
      Future<String?> resolver(String path) async {
        signCalls++;
        return 'https://project.supabase.co/storage/v1/object/sign/job-media/$path?token=tok_$signCalls';
      }

      const privatePath = 'user-1/foto_chuveiro.png';
      final priv1 = await engine.getOrFetchSignedStorageBytes(
        privatePath,
        urlResolver: resolver,
        client: client,
      );
      expect(priv1, isNotNull);
      expect(signCalls, 1);
      expect(httpDownloads, 2);

      // Lookup síncrono tanto por 'storage:...' quanto pelo path puro:
      expect(engine.peekMemoryBytes('storage:$privatePath'), isNotNull);
      expect(engine.peekMemoryBytes(privatePath), isNotNull);

      // Mesmo limpando apenas L1 (ou com URL de token diferente), testamos memoização de 45 min:
      final engine2 = InstantImageCacheEngine(clock: () => currentTime);
      await engine2.getOrFetchSignedStorageBytes(privatePath, urlResolver: resolver, client: client);
      expect(signCalls, 2);

      // Remove apenas da L1 por despejo LRU usando um engine com limite curto para validar TTL da URL assinada:
      final smallEngine = InstantImageCacheEngine(
        maxMemoryBytes: 200,
        maxPersistedItemBytes: 0, // desativa L2 para testar re-fetch com URL memoizada
        clock: () => currentTime,
      );
      await smallEngine.getOrFetchSignedStorageBytes('p1.png', urlResolver: resolver, client: client);
      final callsAfterP1 = signCalls;
      // Evicta 'storage:p1.png' inserindo outra imagem de 150 bytes:
      smallEngine.putMemoryBytes('evictor', Uint8List(150));
      expect(smallEngine.peekMemoryBytes('storage:p1.png'), isNull);

      // Avança 20 min (< 45 min): NÃO chama resolver novamente!
      currentTime = currentTime.add(const Duration(minutes: 20));
      await smallEngine.getOrFetchSignedStorageBytes('p1.png', urlResolver: resolver, client: client);
      expect(signCalls, equals(callsAfterP1));

      // Evicta novamente e avança +30 min (total 50 min > 45 min): renova URL assinada!
      smallEngine.putMemoryBytes('evictor2', Uint8List(150));
      currentTime = currentTime.add(const Duration(minutes: 30));
      await smallEngine.getOrFetchSignedStorageBytes('p1.png', urlResolver: resolver, client: client);
      expect(signCalls, equals(callsAfterP1 + 1));
    });

    testWidgets('renderiza Image em 0 ms já no 1º frame quando pré-aquecida na L1 e EagerImagePrefetcher é seguro sem Supabase', (tester) async {
      const key = 'https://cdn.desperrengue.app/avatars/instant_test.png';
      InstantImageCacheEngine.instance.putMemoryBytes(key, _kTransparentPng1x1);

      // EagerImagePrefetcher nunca lança erro mesmo sem Supabase inicializado:
      EagerImagePrefetcher.prefetchJobs([
        _makeJob(
          id: 'job-img-1',
          status: JobStatus.open,
          photoPaths: const ['uid/photo1.jpg', 'https://cdn.desperrengue.app/avatars/instant_test.png'],
        ),
      ]);

      final syncBytes = InstantImageCacheEngine.instance.peekMemoryBytes(key);
      expect(syncBytes, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Image(
              key: const ValueKey('zero-ms-avatar'),
              image: InstantImageCacheEngine.instance.buildMemoryProvider(
                syncBytes!,
                cacheWidth: 104,
                cacheHeight: 104,
              ),
              gaplessPlayback: true,
            ),
          ),
        ),
      );

      // Já no primeiro frame (sem precisar de pumpAndSettle) o widget Image está montado e limpo:
      expect(find.byKey(const ValueKey('zero-ms-avatar')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

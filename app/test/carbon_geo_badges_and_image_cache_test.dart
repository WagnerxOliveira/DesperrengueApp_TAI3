import 'dart:convert';
import 'dart:math' as math;
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
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:shared_preferences/shared_preferences.dart';

/// Calcula a maior variação angular (em graus) entre quaisquer dois vetores de segmentos
/// consecutivos de uma polilinha. Uma curva quadrada em "L" teria ~90°; o arco geodésico C∞ tem < 2°.
double _maxConsecutiveTurnAngleDegrees(List<LatLng> pts) {
  if (pts.length < 3) return 0.0;
  var maxDeg = 0.0;
  for (var i = 1; i < pts.length - 1; i++) {
    final v1Lat = pts[i].latitude - pts[i - 1].latitude;
    final v1Lng = pts[i].longitude - pts[i - 1].longitude;
    final v2Lat = pts[i + 1].latitude - pts[i].latitude;
    final v2Lng = pts[i + 1].longitude - pts[i].longitude;
    final n1 = math.sqrt(v1Lat * v1Lat + v1Lng * v1Lng);
    final n2 = math.sqrt(v2Lat * v2Lat + v2Lng * v2Lng);
    if (n1 < 1e-12 || n2 < 1e-12) continue;
    final cosTheta = ((v1Lat * v2Lat + v1Lng * v2Lng) / (n1 * n2)).clamp(-1.0, 1.0);
    final deg = math.acos(cosTheta) * 180.0 / math.pi;
    if (deg > maxDeg) maxDeg = deg;
  }
  return maxDeg;
}

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

      // 4) Fallback offline (ambos servidores OSRM indisponíveis) -> Arco geodésico C∞ suave (ZERO dobra de 90° em "L"):
      final offlineSvc = RealTimeRouteAndTrafficService(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      final fallbackSnap = await offlineSvc.computeRoute(
        origin: origin,
        destination: const LatLng(-21.80271, -46.60281),
        departureTime: DateTime(2026, 11, 12, 8, 0), // Pico manhã
      );
      expect(fallbackSnap.isRoadGeometry, isFalse);
      expect(fallbackSnap.polylinePoints.length, 29);
      expect(fallbackSnap.polylinePoints.first, equals(origin));
      expect(fallbackSnap.polylinePoints.last, equals(const LatLng(-21.80271, -46.60281)));
      expect(_maxConsecutiveTurnAngleDegrees(fallbackSnap.polylinePoints), lessThan(15.0));
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

  // ===========================================================================
  // E) Coerência Contextual por Status, Cascata OSRM Dupla, Arco Geodésico C∞
  //    (Zero Linha em "L") e Geometria Óptica de Câmera
  // ===========================================================================
  group('Coerência Contextual, Cascata OSRM Dupla, Arco Geodésico C∞ e Geometria Óptica', () {
    test('1) resolveContextMode e shouldShowArrivalClock garantem coerência semântica absoluta em todos os status', () {
      const inactiveOrNonTransitStatuses = <String?>[
        null,
        '',
        'open',
        'awaiting_payment',
        'awaitingPayment',
        'awaiting_approval',
        'awaitingApproval',
        'completed',
        'canceled',
        'disputed',
      ];

      for (final st in inactiveOrNonTransitStatuses) {
        // Sem origem de prestador e sem pedido manual de rota -> foco puro no imóvel:
        expect(
          RealTimeRouteAndTrafficService.resolveContextMode(
            orderStatus: st,
            hasAssignedProviderOrigin: false,
            userRequestedReferenceRoute: false,
          ),
          MapContextMode.propertyFocus,
          reason: 'Status "$st" sem prestador deve focar no imóvel',
        );

        // Mesmo que alguma coordenada de prestador venha em pedido open/completed/canceled/disputed,
        // NÃO entra em liveProviderTransit sozinho e JAMAIS mostra "Chegada ~HH:mm":
        expect(
          RealTimeRouteAndTrafficService.resolveContextMode(
            orderStatus: st,
            hasAssignedProviderOrigin: true,
            userRequestedReferenceRoute: false,
          ),
          MapContextMode.propertyFocus,
          reason: 'Status "$st" não possui deslocamento ativo',
        );
        expect(
          RealTimeRouteAndTrafficService.shouldShowArrivalClock(
            orderStatus: st,
            hasAssignedProviderOrigin: false,
          ),
          isFalse,
          reason: 'Status "$st" sem prestador jamais exibe relógio de chegada',
        );
        expect(
          RealTimeRouteAndTrafficService.shouldShowArrivalClock(
            orderStatus: st,
            hasAssignedProviderOrigin: true,
          ),
          isFalse,
          reason: 'Status "$st" com histórico de prestador jamais exibe relógio de chegada',
        );

        // Quando o usuário clica explicitamente para ver a rota de referência:
        // resolveContextMode libera visualização da rota, mas shouldShowArrivalClock segue FALSE!
        expect(
          RealTimeRouteAndTrafficService.resolveContextMode(
            orderStatus: st,
            hasAssignedProviderOrigin: false,
            userRequestedReferenceRoute: true,
          ),
          MapContextMode.liveProviderTransit,
          reason: 'Toque explícito do usuário libera rota referencial em "$st"',
        );
      }

      const activeTransitStatuses = <String>[
        'scheduled',
        'in_progress',
        'inProgress',
        'en_route',
        'enRoute',
        'provider_en_route',
        'providerEnRoute',
        ' IN_PROGRESS ',
      ];

      for (final st in activeTransitStatuses) {
        // Sem origem real de prestador atribuído -> ainda foca no imóvel e NÃO inventa chegada:
        expect(
          RealTimeRouteAndTrafficService.resolveContextMode(
            orderStatus: st,
            hasAssignedProviderOrigin: false,
            userRequestedReferenceRoute: false,
          ),
          MapContextMode.propertyFocus,
          reason: 'Status "$st" sem origem real de prestador deve focar no imóvel',
        );
        expect(
          RealTimeRouteAndTrafficService.shouldShowArrivalClock(
            orderStatus: st,
            hasAssignedProviderOrigin: false,
          ),
          isFalse,
          reason: 'Status "$st" sem origem real jamais inventa Chegada ~HH:mm',
        );

        // Com origem real de prestador atribuído -> trânsito ao vivo + relógio de chegada autorizado!
        expect(
          RealTimeRouteAndTrafficService.resolveContextMode(
            orderStatus: st,
            hasAssignedProviderOrigin: true,
            userRequestedReferenceRoute: false,
          ),
          MapContextMode.liveProviderTransit,
          reason: 'Status "$st" com prestador atribuído deve exibir rota ao vivo',
        );
        expect(
          RealTimeRouteAndTrafficService.shouldShowArrivalClock(
            orderStatus: st,
            hasAssignedProviderOrigin: true,
          ),
          isTrue,
          reason: 'Status "$st" com prestador atribuído deve exibir Chegada ~HH:mm',
        );
      }
    });

    test('2) Cascata OSRM resiliente: quando router.project-osrm.org falha/sofre rate-limit, routing.openstreetmap.de entrega geometria viária rua a rua real', () async {
      expect(RealTimeRouteAndTrafficService.kOsrmTimeout, const Duration(milliseconds: 4500));

      const origin = LatLng(-21.78780, -46.56620);
      const dest = LatLng(-21.78845, -46.59250);

      final cascadeUrls = RealTimeRouteAndTrafficService.buildOsrmCascadeUrls(origin, dest);
      expect(cascadeUrls.length, 2);
      expect(cascadeUrls[0].host, 'router.project-osrm.org');
      expect(cascadeUrls[0].path, contains('/route/v1/driving/'));
      expect(cascadeUrls[1].host, 'routing.openstreetmap.de');
      expect(cascadeUrls[1].path, contains('/routed-car/route/v1/driving/'));

      final contactedHosts = <String>[];
      final realStreetCoordinates = <List<double>>[
        [-46.56620, -21.78780],
        [-46.56950, -21.78850],
        [-46.57420, -21.79010],
        [-46.58110, -21.79180],
        [-46.58800, -21.78990],
        [-46.59120, -21.78790],
        [-46.59250, -21.78845],
      ];

      final cascadeClient = MockClient((req) async {
        contactedHosts.add(req.url.host);
        expect(req.url.queryParameters['overview'], 'full');
        expect(req.url.queryParameters['geometries'], 'geojson');
        expect(req.url.queryParameters['steps'], 'true');

        if (req.url.host == 'router.project-osrm.org') {
          // Simula rate-limit / indisponibilidade no 4G do servidor primário:
          return http.Response('{"message":"Too Many Requests"}', 429);
        }
        if (req.url.host == 'routing.openstreetmap.de') {
          return http.Response(
            jsonEncode({
              'code': 'Ok',
              'routes': [
                {
                  'distance': 3680.0,
                  'duration': 455.0,
                  'geometry': {
                    'type': 'LineString',
                    'coordinates': realStreetCoordinates,
                  },
                },
              ],
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final svc = RealTimeRouteAndTrafficService(client: cascadeClient);
      final snap = await svc.computeRoute(
        origin: origin,
        destination: dest,
        departureTime: DateTime(2026, 11, 12, 14, 30),
      );

      expect(
        contactedHosts,
        equals(<String>['router.project-osrm.org', 'routing.openstreetmap.de']),
      );
      expect(snap.isRoadGeometry, isTrue);
      expect(snap.distanceKm, closeTo(3.68, 0.01));
      expect(snap.polylinePoints.length, realStreetCoordinates.length);
      for (var i = 0; i < realStreetCoordinates.length; i++) {
        expect(snap.polylinePoints[i].longitude, closeTo(realStreetCoordinates[i][0], 1e-6));
        expect(snap.polylinePoints[i].latitude, closeTo(realStreetCoordinates[i][1], 1e-6));
      }
    });

    test('3) Suavidade angular estrita de buildGeodesicArcPolyline (< 15° e < 20°): zero dobra quadrada de 90° em "L" em qualquer direção', () {
      const testPairs = <(LatLng, LatLng)>[
        // Leste-Oeste puro (caso clássico onde malhas ortogonais faziam "L" de 90°):
        (LatLng(-21.78780, -46.56620), LatLng(-21.78780, -46.59250)),
        // Norte-Sul puro:
        (LatLng(-21.78000, -46.58000), LatLng(-21.81000, -46.58000)),
        // Diagonal Country Club -> Centro:
        (LatLng(-21.78845, -46.59250), LatLng(-21.78780, -46.56620)),
        // Diagonal Maria Imaculada -> Centro:
        (LatLng(-21.80271, -46.60281), LatLng(-21.78780, -46.56620)),
        // Curta distância de quarteirão (~200 m):
        (LatLng(-21.78795, -46.59190), LatLng(-21.78895, -46.59310)),
      ];

      for (final (origin, dest) in testPairs) {
        final arc = RealTimeRouteAndTrafficService.buildGeodesicArcPolyline(origin, dest);
        final legacyAlias =
            RealTimeRouteAndTrafficService.buildSmoothedUrbanMeshPolyline(origin, dest);

        expect(arc.length, 29); // segments = 28 -> 29 amostras de t=0.0 a t=1.0
        expect(arc.first, equals(origin));
        expect(arc.last, equals(dest));
        expect(legacyAlias, equals(arc));

        // Verifica flecha lateral suave exata de 0.07 * norm perpendicular à corda em t = 0.5 (índice 14):
        final dLat = dest.latitude - origin.latitude;
        final dLng = dest.longitude - origin.longitude;
        final norm = math.sqrt(dLat * dLat + dLng * dLng);
        final chordMidLat = (origin.latitude + dest.latitude) / 2.0;
        final chordMidLng = (origin.longitude + dest.longitude) / 2.0;
        final midPoint = arc[14];
        final offsetLat = midPoint.latitude - chordMidLat;
        final offsetLng = midPoint.longitude - chordMidLng;
        final offsetNorm = math.sqrt(offsetLat * offsetLat + offsetLng * offsetLng);
        final dotWithChord = (offsetLat * dLat) + (offsetLng * dLng);

        expect(offsetNorm, closeTo(0.07 * norm, 1e-9));
        expect(dotWithChord.abs(), lessThan(1e-12), reason: 'Flecha lateral deve ser 100% perpendicular à corda');

        final maxAngle = _maxConsecutiveTurnAngleDegrees(arc);
        expect(
          maxAngle,
          lessThan(15.0),
          reason: 'Nenhum par consecutivo pode ter variação >= 15° (encontrado: $maxAngle°)',
        );
        expect(maxAngle, lessThan(20.0));
      }
    });

    testWidgets('4) computeOpticallyCenteredTarget e computeRouteCameraFit compensam overlays com precisão Web Mercator e enquadram sem erro', (tester) async {
      const target = LatLng(-21.78845, -46.59250);
      const zoom = 17.0;

      // Quando bottomOverlayPx > topOverlayPx (card inferior maior que barra superior),
      // o centro da câmera desloca-se para o sul (latitude menor) para subir o pino ao centro óptico:
      final centered = RealTimeRouteAndTrafficService.computeOpticallyCenteredTarget(
        target: target,
        zoom: zoom,
        topOverlayPx: 96.0,
        bottomOverlayPx: 176.0,
      );
      final expectedDegPerPx =
          (360.0 / (256.0 * math.pow(2.0, zoom))) * math.cos(target.latitude * math.pi / 180.0);
      final expectedLat = target.latitude - ((176.0 - 96.0) / 2.0) * expectedDegPerPx;

      expect(centered.latitude, closeTo(expectedLat, 1e-10));
      expect(centered.latitude, lessThan(target.latitude));
      expect(centered.longitude, equals(target.longitude));

      // Overlays simétricos -> deslocamento zero:
      final symmetric = RealTimeRouteAndTrafficService.computeOpticallyCenteredTarget(
        target: target,
        zoom: zoom,
        topOverlayPx: 120.0,
        bottomOverlayPx: 120.0,
      );
      expect(symmetric.latitude, closeTo(target.latitude, 1e-12));
      expect(symmetric.longitude, equals(target.longitude));

      // Validação de computeRouteCameraFit (rota completa + caso degenerado de coordenadas idênticas):
      final routePoints = RealTimeRouteAndTrafficService.buildGeodesicArcPolyline(
        const LatLng(-21.78780, -46.56620),
        target,
      );
      final routeFit = RealTimeRouteAndTrafficService.computeRouteCameraFit(
        points: routePoints,
        destination: target,
      );
      final degenerateFit = RealTimeRouteAndTrafficService.computeRouteCameraFit(
        points: const <LatLng>[target],
        destination: target,
      );

      final mapController = MapController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 844,
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: centered,
                  initialZoom: zoom,
                ),
                children: const [],
              ),
            ),
          ),
        ),
      );

      // Aplicar CameraFit tanto na rota completa quanto em coordenadas idênticas jamais lança erro:
      mapController.fitCamera(routeFit);
      await tester.pump();
      expect(mapController.camera.zoom, lessThanOrEqualTo(16.8 + 1e-6));

      mapController.fitCamera(degenerateFit);
      await tester.pump();
      expect(mapController.camera.zoom, lessThanOrEqualTo(16.8 + 1e-6));
      expect(tester.takeException(), isNull);
    });
  });
}

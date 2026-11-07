import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:desperrengue_app/core/models/client_dossier_models.dart';
import 'package:desperrengue_app/core/models/geocode_models.dart';
import 'package:desperrengue_app/core/models/scheduling_models.dart';
import 'package:desperrengue_app/core/services/geocoding_service.dart';
import 'package:desperrengue_app/core/services/precise_geocoder.dart';
import 'package:desperrengue_app/core/services/scheduling_service.dart';
import 'package:desperrengue_app/core/services/text_refine_service.dart';

/// Localização exata: cascata ViaCEP → Photon + AwesomeAPI(CEP) → Nominatim, sempre validando
/// cidade/UF (nunca aceitar "Rua X" de outra cidade) — e o refinamento que só melhora o ponto.
class _Backend implements SchedulingBackend {
  final saved = <({double lat, double lng, String source, String precision})>[];
  bool fail = false;

  @override
  Future<DateTime> serverTime() async => DateTime.now();
  @override
  Future<JobDestination?> destination(String jobId) async => null;
  @override
  Future<StartResult> startJob(String jobId, {GeoFix? position, bool simulate = false}) => throw UnimplementedError();
  @override
  Future<JobDestination?> setLocation(String jobId, double lat, double lng, {String source = 'client_pin', String precision = 'house'}) async {
    if (fail) throw StateError('rede');
    saved.add((lat: lat, lng: lng, source: source, precision: precision));
    return JobDestination(lat: lat, lng: lng, precision: DestinationPrecision.parse(precision), radiusM: 250, source: source);
  }
}

class _Geo implements AddressGeocoder {
  _Geo(this.hit);
  final GeocodeHit? hit;
  int calls = 0;
  @override
  Future<GeocodeHit?> geocode(String addressLine, {String? summary, String? cep}) async {
    calls++;
    return hit;
  }
}

const _line = 'Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG';

Map<String, dynamic> photon({required double lat, required double lng, String city = 'Poços de Caldas', String state = 'Minas Gerais', String? street, String? number, String type = 'house', String key = 'place'}) => {
      'type': 'Feature',
      'geometry': {'type': 'Point', 'coordinates': [lng, lat]},
      'properties': {
        'countrycode': 'BR',
        'city': city,
        'state': state,
        'osm_key': key,
        'type': type,
        'street': ?street,
        'housenumber': ?number,
        'name': street ?? city,
      },
    };

http.Response json(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  final parts = parseAddressLine(_line);

  group('parseAddressLine — todos os formatos de endereço do app', () {
    test('remove sufixo "| Ref: ..." e extrai rua, número, bairro, cidade e UF', () {
      final p = parseAddressLine('Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG | Ref: Perto da igreja');
      expect(p.street, 'Rua Padre José Geraldi');
      expect(p.number, '203');
      expect(p.hood, 'Maria Imaculada');
      expect(p.city, 'Poços de Caldas');
      expect(p.uf, 'MG');
    });

    test('suporta formato de 4 partes com hífens (Rua, N - Bairro - Cidade - UF)', () {
      final p = parseAddressLine('Rua Padre José Geraldi, 203 - Maria Imaculada - Poços de Caldas - MG');
      expect(p.street, 'Rua Padre José Geraldi');
      expect(p.number, '203');
      expect(p.hood, 'Maria Imaculada');
      expect(p.city, 'Poços de Caldas');
      expect(p.uf, 'MG');
    });

    test('suporta resumo de 2 partes (Bairro, Cidade - UF) e fallback via summary', () {
      final p1 = parseAddressLine('Maria Imaculada, Poços de Caldas - MG');
      expect(p1.street, '');
      expect(p1.hood, 'Maria Imaculada');
      expect(p1.city, 'Poços de Caldas');
      expect(p1.uf, 'MG');

      final p2 = parseAddressLine('Rua Padre José Geraldi, 203 - Maria Imaculada', summary: 'Poços de Caldas, MG');
      expect(p2.street, 'Rua Padre José Geraldi');
      expect(p2.number, '203');
      expect(p2.hood, 'Maria Imaculada');
      expect(p2.city, 'Poços de Caldas');
      expect(p2.uf, 'MG');
    });
  });

  group('cityMatches (nunca aceitar outra cidade)', () {
    test('mesma cidade/UF casa; outra cidade ou outra UF não', () {
      expect(PreciseGeocoder.cityMatches(parts, 'Rua X, Poços de Caldas, Minas Gerais'), isTrue);
      expect(PreciseGeocoder.cityMatches(parts, 'pocos de caldas MG'), isTrue, reason: 'sem acento e com a sigla');
      expect(PreciseGeocoder.cityMatches(parts, 'Rua Padre José Geraldi, Embu das Artes, São Paulo'), isFalse);
      expect(PreciseGeocoder.cityMatches(parts, 'Poços de Caldas, Bahia'), isFalse, reason: 'cidade igual, estado errado');
    });

    test('ufFullName', () {
      expect(ufFullName('mg'), 'Minas Gerais');
      expect(ufFullName('SP'), 'São Paulo');
      expect(ufFullName('XX'), '');
    });
  });

  group('parsePhoton', () {
    test('número + rua conferem → casa; só a rua → rua; lugar qualquer → localidade', () {
      final body = {
        'features': [
          photon(lat: -21.8027, lng: -46.6028, street: 'Rua Padre José Geraldi', number: '203'),
          photon(lat: -21.8030, lng: -46.6030, street: 'Rua Padre José Geraldi', type: 'street', key: 'highway'),
          photon(lat: -21.7900, lng: -46.5647, type: 'city'),
        ],
      };
      final r = PreciseGeocoder.parsePhoton(body, parts);
      expect(r.map((c) => c.precision), [DestinationPrecision.house, DestinationPrecision.street, DestinationPrecision.locality]);
    });

    test('descarta resultado de outra cidade (o bug do "Padre José Geraldi" em Embu das Artes)', () {
      final body = {
        'features': [photon(lat: -23.64, lng: -46.85, city: 'Embu das Artes', state: 'São Paulo', street: 'Rua Padre José Geraldi', number: '203')],
      };
      expect(PreciseGeocoder.parsePhoton(body, parts), isEmpty);
    });

    test('descarta fora do Brasil e payload inválido', () {
      final f = photon(lat: 1, lng: 2, street: 'Rua Padre José Geraldi', number: '203');
      (f['properties'] as Map)['countrycode'] = 'PT';
      expect(PreciseGeocoder.parsePhoton({'features': [f]}, parts), isEmpty);
      expect(PreciseGeocoder.parsePhoton(null, parts), isEmpty);
      expect(PreciseGeocoder.parsePhoton({'features': 'x'}, parts), isEmpty);
    });

    test('número diferente não vira "casa"', () {
      final body = {'features': [photon(lat: -21.8, lng: -46.6, street: 'Rua Padre José Geraldi', number: '999')]};
      expect(PreciseGeocoder.parsePhoton(body, parts).single.precision, DestinationPrecision.locality);
    });
  });

  group('parseAwesome (CEP → ponto da rua)', () {
    test('aceita a mesma cidade como "rua"', () {
      final r = PreciseGeocoder.parseAwesome({'lat': '-21.8027', 'lng': '-46.6028', 'city': 'Poços de Caldas', 'state': 'MG', 'address': 'Rua Padre José Geraldi'}, parts);
      expect(r.single.precision, DestinationPrecision.street);
      expect(r.single.lat, closeTo(-21.8027, 1e-9));
    });

    test('rejeita cidade diferente, coordenada 0,0 e corpo inválido', () {
      expect(PreciseGeocoder.parseAwesome({'lat': '-23.6', 'lng': '-46.8', 'city': 'Embu das Artes', 'state': 'SP'}, parts), isEmpty);
      expect(PreciseGeocoder.parseAwesome({'lat': '0', 'lng': '0', 'city': 'Poços de Caldas', 'state': 'MG'}, parts), isEmpty);
      expect(PreciseGeocoder.parseAwesome('x', parts), isEmpty);
    });
  });

  group('pickBest', () {
    const house = GeocodeCandidate(-21.80, -46.60, DestinationPrecision.house, 'photon');
    const street = GeocodeCandidate(-21.81, -46.61, DestinationPrecision.street, 'awesomeapi');
    const loc = GeocodeCandidate(-21.79, -46.56, DestinationPrecision.locality, 'nominatim');

    test('maior precisão vence; vazio → null', () {
      expect(PreciseGeocoder.pickBest(const [loc, street, house]), same(house));
      expect(PreciseGeocoder.pickBest(const []), isNull);
    });

    test('empate de precisão: a que mais fontes confirmam (≤ 400 m) vence', () {
      const a = GeocodeCandidate(-21.800, -46.600, DestinationPrecision.street, 'a');
      const b = GeocodeCandidate(-21.900, -46.700, DestinationPrecision.street, 'b'); // isolada
      const c = GeocodeCandidate(-21.9005, -46.7003, DestinationPrecision.street, 'c'); // concorda com b
      expect(PreciseGeocoder.pickBest(const [a, b, c]), same(b));
    });

    test('empate total: ordem das fontes', () {
      const a = GeocodeCandidate(-21.0, -46.0, DestinationPrecision.street, 'a');
      const b = GeocodeCandidate(-22.0, -47.0, DestinationPrecision.street, 'b');
      expect(PreciseGeocoder.pickBest(const [a, b]), same(a));
    });
  });

  group('cascata completa (HTTP simulado)', () {
    MockClient net({Object? viacep, Object? photonBody, Object? awesome, void Function(Uri)? onCall}) => MockClient((req) async {
          onCall?.call(req.url);
          if (req.url.host == 'viacep.com.br') return json(viacep ?? []);
          if (req.url.host == 'photon.komoot.io') return json(photonBody ?? {'features': []});
          if (req.url.host == 'cep.awesomeapi.com.br') return awesome == null ? http.Response('{}', 404) : json(awesome);
          return http.Response('', 500);
        });

    test('CEP informado: pula o ViaCEP e a casa do Photon vence o ponto da rua', () async {
      final hosts = <String>[];
      final g = PreciseGeocoder(
        client: net(
          photonBody: {'features': [photon(lat: -21.80271, lng: -46.60281, street: 'Rua Padre José Geraldi', number: '203')]},
          awesome: {'lat': '-21.8027', 'lng': '-46.6028', 'city': 'Poços de Caldas', 'state': 'MG', 'address': 'Rua Padre José Geraldi'},
          onCall: (u) => hosts.add(u.host),
        ),
        fallback: _Geo(null),
      );
      final hit = await g.geocode(_line, cep: '37701-000');
      expect(hit!.precision, DestinationPrecision.house);
      expect(hit.lat, closeTo(-21.80271, 1e-6));
      expect(hosts, isNot(contains('viacep.com.br')));
      expect(hosts, containsAll(['photon.komoot.io', 'cep.awesomeapi.com.br']));
    });

    test('sem CEP: descobre o CEP no ViaCEP e usa o ponto da rua da AwesomeAPI', () async {
      final g = PreciseGeocoder(
        client: net(
          viacep: [{'cep': '37701-110', 'bairro': 'Maria Imaculada'}],
          awesome: {'lat': '-21.8027', 'lng': '-46.6028', 'city': 'Poços de Caldas', 'state': 'MG', 'address': 'Rua Padre José Geraldi'},
        ),
        fallback: _Geo(null),
      );
      final hit = await g.geocode(_line);
      expect(hit!.precision, DestinationPrecision.street);
      expect(hit.lat, closeTo(-21.8027, 1e-9));
    });

    test('só resultados de OUTRA cidade: cai no Nominatim (fallback) — nunca devolve a cidade errada', () async {
      final fallback = _Geo(const GeocodeHit(lat: -21.79, lng: -46.56, precision: DestinationPrecision.locality, display: 'Poços de Caldas, Minas Gerais'));
      final g = PreciseGeocoder(
        client: net(photonBody: {'features': [photon(lat: -23.64, lng: -46.85, city: 'Embu das Artes', state: 'São Paulo', street: 'Rua Padre José Geraldi', number: '203')]}),
        fallback: fallback,
      );
      final hit = await g.geocode(_line, cep: '37701000');
      expect(fallback.calls, 1);
      expect(hit!.precision, DestinationPrecision.locality);
      expect(hit.lat, closeTo(-21.79, 1e-9));
    });

    test('tudo falha (sem rede): null, sem lançar', () async {
      final g = PreciseGeocoder(client: MockClient((_) async => throw Exception('sem rede')), fallback: _Geo(null));
      expect(await g.geocode(_line, cep: '37701000'), isNull);
    });

    test('endereço vazio: nem consulta', () async {
      var calls = 0;
      final g = PreciseGeocoder(client: MockClient((_) async {
        calls++;
        return http.Response('', 500);
      }), fallback: _Geo(null));
      expect(await g.geocode(''), isNull);
      expect(calls, 0);
    });
  });

  group('refineGeocodedLocation: só troca o ponto quando MELHORA', () {
    const street = GeocodeHit(lat: -21.8027, lng: -46.6028, precision: DestinationPrecision.street);
    const house = GeocodeHit(lat: -21.8027, lng: -46.6028, precision: DestinationPrecision.house);

    test('ponto de cidade (locality) → rua: grava como client_geocode/street', () async {
      final b = _Backend();
      final r = await refineGeocodedLocation(jobId: 'j', addressLine: _line, current: DestinationPrecision.locality, geocoder: _Geo(street), backend: b);
      expect(r, isNotNull);
      expect(b.saved.single.source, 'client_geocode');
      expect(b.saved.single.precision, 'street');
    });

    test('mesma precisão ou pior: não grava', () async {
      final b = _Backend();
      expect(await refineGeocodedLocation(jobId: 'j', addressLine: _line, current: DestinationPrecision.street, geocoder: _Geo(street), backend: b), isNull);
      expect(await refineGeocodedLocation(jobId: 'j', addressLine: _line, current: DestinationPrecision.house, geocoder: _Geo(street), backend: b), isNull);
      expect(b.saved, isEmpty);
    });

    test('sem ponto prévio: qualquer resultado entra; "casa" é gravada como house', () async {
      final b = _Backend();
      await refineGeocodedLocation(jobId: 'j', addressLine: _line, current: null, geocoder: _Geo(house), backend: b);
      expect(b.saved.single.precision, 'house');
    });

    test('geocodificador sem resultado ou backend falhando: null e sem exceção', () async {
      final b = _Backend()..fail = true;
      expect(await refineGeocodedLocation(jobId: 'j', addressLine: _line, current: null, geocoder: _Geo(null), backend: b), isNull);
      expect(await refineGeocodedLocation(jobId: 'j', addressLine: _line, current: null, geocoder: _Geo(street), backend: b), isNull);
    });
  });

  group('Dossiê do cliente: precisão/origem do ponto', () {
    Map<String, dynamic> base(Map<String, dynamic> extra) => {
          'job_id': '1a2b3c4d-0000-0000-0000-000000000000',
          'code': '#DESP-1A2B3',
          'title': 'T',
          'description': 'D',
          'category': 'Elétrica',
          'status': 'scheduled',
          'created_at': '2026-10-19T10:00:00Z',
          'photo_paths': <dynamic>[],
          'amount': 10,
          'payment_status': 'pending',
          'evidence': <dynamic>[],
          ...extra,
        };

    test('lê geo_precision e geo_source', () {
      final d = ClientDossier.fromMap(base({'latitude': -21.8, 'longitude': -46.6, 'geo_precision': 'locality', 'geo_source': 'client_geocode'}));
      expect(d.geoPrecision, DestinationPrecision.locality);
      expect(d.geoSource, 'client_geocode');
      expect(d.latitude, -21.8);
    });

    test('dossiê antigo (sem os campos novos) continua válido', () {
      final d = ClientDossier.fromMap(base({}));
      expect(d.geoPrecision, isNull);
      expect(d.geoSource, isNull);
    });
  });

  group('LanguageToolRefiner', () {
    Map<String, dynamic> m(int offset, int length, String cat, List<String> reps) => {
          'offset': offset,
          'length': length,
          'rule': {'category': {'id': cat}},
          'replacements': [for (final r in reps) {'value': r}],
        };

    test('aplica só correções cosméticas (caixa, acento, pontuação)', () {
      const text = 'preciso de um eletricista tambem';
      final out = LanguageToolRefiner.applyMatches(text, [m(0, 7, 'CASING', ['Preciso']), m(26, 6, 'TYPOS', ['também'])]);
      expect(out, 'Preciso de um eletricista também');
    });

    test('NUNCA troca uma palavra por outra (sentido do relato intacto)', () {
      const text = 'o chuveiro queimou';
      expect(LanguageToolRefiner.applyMatches(text, [m(2, 8, 'TYPOS', ['banheiro'])]), text);
    });

    test('ignora categorias de gramática/estilo e offsets inválidos', () {
      const text = 'a casa esta suja';
      expect(LanguageToolRefiner.applyMatches(text, [m(7, 4, 'GRAMMAR', ['está'])]), text);
      expect(LanguageToolRefiner.applyMatches(text, [m(99, 4, 'TYPOS', ['está'])]), text);
      expect(LanguageToolRefiner.applyMatches(text, [m(-1, 4, 'TYPOS', ['está'])]), text);
      expect(LanguageToolRefiner.applyMatches(text, [m(7, 0, 'TYPOS', ['está'])]), text);
    });

    test('várias correções, inclusive vizinhas, sem corromper os índices', () {
      const text = 'nao tem luz e o disjuntor cai';
      final out = LanguageToolRefiner.applyMatches(text, [m(0, 3, 'TYPOS', ['não']), m(0, 1, 'CASING', ['N'])]);
      expect(out.length, greaterThanOrEqualTo(text.length - 1));
      expect(out.endsWith('o disjuntor cai'), isTrue);
    });

    test('refine via HTTP: usa a resposta da API', () async {
      late Uri seen;
      late Map<String, String> sent;
      final client = MockClient((req) async {
        seen = req.url;
        sent = req.bodyFields;
        return json({'matches': [m(0, 7, 'CASING', ['Preciso'])]});
      });
      final out = await LanguageToolRefiner(client: client).refine('preciso de ajuda');
      expect(out, 'Preciso de ajuda');
      expect(seen.host, 'api.languagetool.org');
      expect(sent['language'], 'pt-BR');
      expect(sent['text'], 'preciso de ajuda');
    });

    test('falhas de rede/HTTP/JSON devolvem o texto original', () async {
      expect(await LanguageToolRefiner(client: MockClient((_) async => http.Response('x', 500))).refine('preciso de ajuda'), 'preciso de ajuda');
      expect(await LanguageToolRefiner(client: MockClient((_) async => throw Exception('rede'))).refine('preciso de ajuda'), 'preciso de ajuda');
      expect(await LanguageToolRefiner(client: MockClient((_) async => http.Response('não é json', 200))).refine('preciso de ajuda'), 'preciso de ajuda');
    });

    test('texto curto demais ou grande demais nem vai para a rede', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return json({'matches': []});
      });
      final r = LanguageToolRefiner(client: client);
      expect(await r.refine('oi'), 'oi');
      final big = 'a' * (LanguageToolRefiner.maxChars + 1);
      expect(await r.refine(big), big);
      expect(calls, 0);
    });
  });
}

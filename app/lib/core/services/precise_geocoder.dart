import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/geocode_models.dart';
import '../models/scheduling_models.dart';
import '../utils/geo.dart';
import '../utils/tag_normalizer.dart' show normalizeTag;
import 'geocoding_service.dart';

/// Geocodificação de ALTA PRECISÃO para endereços brasileiros, só com serviços gratuitos e sem
/// chave, em cascata e com validação:
///
///  1. **CEP** do endereço (informado ou descoberto no ViaCEP por UF + cidade + rua) — também
///     confirma o nome oficial da rua/bairro;
///  2. **Photon** (OpenStreetMap, busca estruturada rua + número + cidade): devolve a CASA quando
///     o OSM tem o número, senão a rua;
///  3. **AwesomeAPI CEP**: ponto da rua pelo CEP (independe de o OSM ter o número);
///  4. **Nominatim** (consultas em cascata) como último recurso;
///  5. centro do bairro/cidade (`locality`) só se nada melhor existir.
///
/// Cada candidato é validado (país, UF e CIDADE precisam bater com o endereço — acabou o ponto
/// "em outra cidade") e o vencedor é o de maior precisão; fontes que concordam (≤ 400 m) desempatam.
/// O resultado é só o PONTO INICIAL: o cliente confirma o pino exato no mapa (ver
/// [LocationPickerSheet]), que é o que garante a precisão da porta.
class PreciseGeocoder implements AddressGeocoder {
  PreciseGeocoder({http.Client? client, AddressGeocoder? fallback, this.timeout = const Duration(seconds: 8)})
      : _client = client ?? http.Client(),
        _fallback = fallback ?? GeocodingService(client: client);

  final http.Client _client;
  final AddressGeocoder _fallback;
  final Duration timeout;

  static const _headers = {'User-Agent': 'Desperrengue/1.0 (suporte@desperrengue.tech)', 'Accept-Language': 'pt-BR'};

  @override
  Future<GeocodeHit?> geocode(String addressLine, {String? summary, String? cep}) async {
    final parts = parseAddressLine(addressLine, summary: summary);
    if (parts.street.isEmpty && parts.city.isEmpty) return null;

    var zip = _digits(cep);
    if (zip.length != 8) zip = await _cepByAddress(parts) ?? '';

    final results = await Future.wait([
      _photon(parts, zip),
      zip.length == 8 ? _awesomeCep(parts, zip) : Future<List<GeocodeCandidate>>.value(const []),
    ]);
    final candidates = [for (final r in results) ...r];
    var best = pickBest(candidates);

    // Sem rua/casa confiável: tenta o Nominatim (que também traz bairro/cidade).
    if (best == null || best.precision == DestinationPrecision.locality) {
      final nominatim = await _fallback.geocode(addressLine, summary: summary, cep: zip.isEmpty ? null : zip);
      if (nominatim != null && cityMatches(parts, nominatim.display)) {
        best = pickBest([...candidates, GeocodeCandidate(nominatim.lat, nominatim.lng, nominatim.precision, 'nominatim', nominatim.display)]);
      } else if (best == null && nominatim != null) {
        best = GeocodeCandidate(nominatim.lat, nominatim.lng, nominatim.precision, 'nominatim', nominatim.display);
      }
    }
    if (best == null) return null;
    return GeocodeHit(lat: best.lat, lng: best.lng, precision: best.precision, display: best.display);
  }

  // ------------------------------------------------------------------ escolha

  /// Escolhe o melhor candidato: maior precisão; empate → mais fontes concordando (≤ 400 m);
  /// persistindo → a ordem das fontes. Pura e testável.
  static GeocodeCandidate? pickBest(List<GeocodeCandidate> list) {
    if (list.isEmpty) return null;
    int rank(DestinationPrecision p) => switch (p) {
          DestinationPrecision.exact => 4,
          DestinationPrecision.house => 3,
          DestinationPrecision.street => 2,
          DestinationPrecision.locality => 1,
        };
    int agreement(GeocodeCandidate c) =>
        list.where((o) => !identical(o, c) && haversineMeters(c.lat, c.lng, o.lat, o.lng) <= 400).length;
    final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
    indexed.sort((a, b) {
      final byRank = rank(b.$2.precision).compareTo(rank(a.$2.precision));
      if (byRank != 0) return byRank;
      final byAgree = agreement(b.$2).compareTo(agreement(a.$2));
      if (byAgree != 0) return byAgree;
      return a.$1.compareTo(b.$1);
    });
    return indexed.first.$2;
  }

  /// A cidade (e a UF, quando conhecida) do resultado batem com o endereço pedido?
  static bool cityMatches(AddressParts p, String text) {
    final hay = normalizeTag(text);
    final city = normalizeTag(p.city);
    if (city.isNotEmpty && !hay.contains(city)) return false;
    final uf = p.uf.trim();
    if (uf.length == 2) {
      final name = normalizeTag(ufFullName(uf));
      if (name.isNotEmpty && !hay.contains(name) && !RegExp('(^|[^a-z])${uf.toLowerCase()}([^a-z]|\$)').hasMatch(hay)) return false;
    }
    return true;
  }

  // ------------------------------------------------------------------- fontes

  /// ViaCEP por endereço: UF + cidade + rua → CEP (prefere o do mesmo bairro).
  Future<String?> _cepByAddress(AddressParts p) async {
    if (p.uf.length != 2 || p.city.isEmpty || p.street.trim().length < 3) return null;
    final street = p.street.replaceFirst(RegExp(r'^(r\.?|rua|av\.?|avenida|al\.?|alameda|tv\.?|travessa|pça\.?|praça|estrada|rodovia)\s+', caseSensitive: false), '');
    final uri = Uri.parse('https://viacep.com.br/ws/${p.uf.toUpperCase()}/${Uri.encodeComponent(p.city)}/${Uri.encodeComponent(street)}/json/');
    final body = await _getJson(uri);
    if (body is! List || body.isEmpty) return null;
    final rows = body.whereType<Map>().toList();
    final hood = normalizeTag(p.hood);
    final same = hood.isEmpty ? null : rows.where((r) => normalizeTag('${r['bairro'] ?? ''}') == hood).firstOrNull;
    final pick = same ?? rows.first;
    final z = _digits('${pick['cep'] ?? ''}');
    return z.length == 8 ? z : null;
  }

  /// Photon (OSM): busca estruturada. Aceita só resultados do Brasil, da UF e da CIDADE certas.
  Future<List<GeocodeCandidate>> _photon(AddressParts p, String zip) async {
    final q = [
      if (p.street.isNotEmpty) p.number.isEmpty ? p.street : '${p.street} ${p.number}',
      if (p.hood.isNotEmpty) p.hood,
      if (p.city.isNotEmpty) p.city,
      if (p.uf.isNotEmpty) p.uf,
      'Brasil',
    ].join(', ');
    final body = await _getJson(Uri.https('photon.komoot.io', '/api/', {'q': q, 'limit': '8', 'lang': 'default'}));
    return parsePhoton(body, p);
  }

  /// Interpreta o GeoJSON do Photon (público para teste). Filtra por país/UF/cidade e classifica.
  static List<GeocodeCandidate> parsePhoton(Object? body, AddressParts p) {
    final features = (body is Map ? body['features'] : null);
    if (features is! List) return const [];
    final street = normalizeTag(p.street.replaceFirst(RegExp(r'^(r\.?|rua|av\.?|avenida|al\.?|alameda|tv\.?|travessa|praça|estrada|rodovia)\s+', caseSensitive: false), ''));
    final out = <GeocodeCandidate>[];
    for (final f in features.whereType<Map>()) {
      final props = (f['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
      final coords = ((f['geometry'] as Map?)?['coordinates']) as List?;
      if (coords == null || coords.length < 2) continue;
      final lng = (coords[0] as num?)?.toDouble();
      final lat = (coords[1] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      if ('${props['countrycode'] ?? 'BR'}'.toUpperCase() != 'BR') continue;
      final place = '${props['city'] ?? ''} ${props['town'] ?? ''} ${props['village'] ?? ''} ${props['county'] ?? ''} ${props['district'] ?? ''} ${props['state'] ?? ''}';
      if (!cityMatches(p, place)) continue;
      final name = normalizeTag('${props['street'] ?? ''} ${props['name'] ?? ''}');
      final type = '${props['type'] ?? ''}';
      final sameStreet = street.isNotEmpty && name.contains(street);
      final hn = normalizeTag('${props['housenumber'] ?? ''}');
      DestinationPrecision prec;
      if (hn.isNotEmpty && hn == normalizeTag(p.number) && (sameStreet || street.isEmpty)) {
        prec = DestinationPrecision.house;
      } else if ((type == 'street' || '${props['osm_key']}' == 'highway') && (sameStreet || street.isEmpty)) {
        prec = DestinationPrecision.street;
      } else {
        prec = DestinationPrecision.locality;
      }
      out.add(GeocodeCandidate(lat, lng, prec, 'photon', '${props['name'] ?? ''}, ${props['city'] ?? ''}'));
    }
    return out;
  }

  /// AwesomeAPI CEP: ponto da rua. Confere a cidade para descartar CEPs trocados.
  Future<List<GeocodeCandidate>> _awesomeCep(AddressParts p, String zip) async {
    final body = await _getJson(Uri.https('cep.awesomeapi.com.br', '/json/$zip'));
    return parseAwesome(body, p);
  }

  static List<GeocodeCandidate> parseAwesome(Object? body, AddressParts p) {
    if (body is! Map) return const [];
    final lat = double.tryParse('${body['lat'] ?? ''}');
    final lng = double.tryParse('${body['lng'] ?? ''}');
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return const [];
    if (!cityMatches(p, '${body['city'] ?? ''} ${body['state'] ?? ''}')) return const [];
    return [GeocodeCandidate(lat, lng, DestinationPrecision.street, 'awesomeapi', '${body['address'] ?? ''}, ${body['city'] ?? ''}')];
  }

  Future<Object?> _getJson(Uri uri) async {
    try {
      final res = await _client.get(uri, headers: _headers).timeout(timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
    } catch (_) {
      return null;
    }
  }

  static String _digits(String? s) => (s ?? '').replaceAll(RegExp(r'\D'), '');
}

/// Um ponto sugerido por uma das fontes.
class GeocodeCandidate {
  const GeocodeCandidate(this.lat, this.lng, this.precision, this.source, [this.display = '']);

  final double lat;
  final double lng;
  final DestinationPrecision precision;
  final String source;
  final String display;
}

/// UF → nome do estado ("MG" → "Minas Gerais").
String ufFullName(String uf) => _ufNames[uf.trim().toUpperCase()] ?? '';

const Map<String, String> _ufNames = {
  'AC': 'Acre', 'AL': 'Alagoas', 'AP': 'Amapá', 'AM': 'Amazonas', 'BA': 'Bahia', 'CE': 'Ceará',
  'DF': 'Distrito Federal', 'ES': 'Espírito Santo', 'GO': 'Goiás', 'MA': 'Maranhão',
  'MT': 'Mato Grosso', 'MS': 'Mato Grosso do Sul', 'MG': 'Minas Gerais', 'PA': 'Pará',
  'PB': 'Paraíba', 'PR': 'Paraná', 'PE': 'Pernambuco', 'PI': 'Piauí', 'RJ': 'Rio de Janeiro',
  'RN': 'Rio Grande do Norte', 'RS': 'Rio Grande do Sul', 'RO': 'Rondônia', 'RR': 'Roraima',
  'SC': 'Santa Catarina', 'SP': 'São Paulo', 'SE': 'Sergipe', 'TO': 'Tocantins',
};

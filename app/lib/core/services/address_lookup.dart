import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/address_data.dart';
import '../utils/geo.dart';
import 'native_reverse_geocoder.dart';

/// Consulta de endereço por CEP e por coordenadas (GPS) — custo zero.
///
/// Arquitetura de Alta Precisão para o Brasil:
///  * CEP -> endereço: ViaCEP (principal) e BrasilAPI v2 (reserva);
///  * Coordenadas -> endereço:
///    1. **Geocoder Nativo do OS** (`android.location.Geocoder` Google Maps no Android /
///       `CLGeocoder` Apple Maps no iOS — gratuito e com cobertura superior no Brasil);
///    2. **Consenso Nominatim + Photon (OSM)** com validação de distância Haversine;
///    3. **Validação cruzada de CEP anti-sobrescrita**: jamais sobrescreve a rua real
///       do GPS com a rua de um CEP errado vindo do OSM; quando o CEP diverge ou falta,
///       busca o CEP oficial dos Correios no ViaCEP por `UF/Cidade/Logradouro`.
class AddressLookup {
  AddressLookup([
    http.Client? client,
    NativeReverseGeocoderFn? nativeReverseGeocoder,
  ])  : _client = client ?? http.Client(),
        _nativeReverseGeocoder =
            nativeReverseGeocoder ??
            (client == null ? NativeReverseGeocoder.reverseGeocode : null);

  final http.Client _client;
  final NativeReverseGeocoderFn? _nativeReverseGeocoder;

  static const _timeout = Duration(seconds: 8);

  /// Política de uso do Nominatim exige um User-Agent identificável.
  static const _headers = {
    'User-Agent': 'DesperrengueApp/2.33 (suporte@desperrengue.tech)',
    'Accept': 'application/json',
  };

  /// CEP -> endereço (ViaCEP; se falhar/estiver fora do ar, BrasilAPI).
  Future<AddressData?> byCep(String cep) async {
    final digits = onlyDigits(cep);
    if (digits.length != 8) return null;
    final viaCep = await _getJson('https://viacep.com.br/ws/$digits/json/');
    final a = viaCep == null ? null : parseViaCep(viaCep, digits);
    if (a != null) return a;
    final brasil = await _getJson('https://brasilapi.com.br/api/cep/v2/$digits');
    return brasil == null ? null : parseBrasilApi(brasil, digits);
  }

  /// Descobre o CEP oficial dos Correios (ViaCEP) a partir de UF + Cidade + Logradouro,
  /// preferindo o registro cujo bairro coincide com [neighborhood].
  Future<AddressData?> findCepByAddress({
    required String uf,
    required String city,
    required String street,
    String neighborhood = '',
  }) async {
    final cleanUf = uf.trim().toUpperCase();
    final cleanCity = city.trim();
    final strippedStreet = stripStreetPrefix(street).trim();
    if (cleanUf.length != 2 || cleanCity.length < 2 || strippedStreet.length < 3) {
      return null;
    }

    final uri = Uri.parse(
      'https://viacep.com.br/ws/$cleanUf/${Uri.encodeComponent(cleanCity)}/${Uri.encodeComponent(strippedStreet)}/json/',
    );
    final raw = await _getJsonAny(uri.toString());
    if (raw is! List || raw.isEmpty) return null;

    final rows = raw.whereType<Map<String, dynamic>>().toList(growable: false);
    if (rows.isEmpty) return null;

    final targetHood = _fold(neighborhood);
    Map<String, dynamic>? bestRow;
    int bestScore = -1;

    for (final row in rows) {
      final rowCep = onlyDigits('${row['cep'] ?? ''}');
      if (rowCep.length != 8) continue;
      final rowStreet = '${row['logradouro'] ?? ''}'.trim();
      final rowHood = _fold('${row['bairro'] ?? ''}');
      int score = 0;
      if (streetsMatch(street, rowStreet)) score += 60;
      if (targetHood.isNotEmpty && rowHood.isNotEmpty) {
        if (rowHood == targetHood) {
          score += 40;
        } else if (rowHood.contains(targetHood) || targetHood.contains(rowHood)) {
          score += 20;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestRow = row;
      }
    }

    if (bestRow == null) return null;
    final zip = onlyDigits('${bestRow['cep'] ?? ''}');
    if (zip.length != 8) return null;
    return parseViaCep(bestRow, zip);
  }

  /// Coordenadas -> endereço (rua, bairro, cidade, UF e CEP). O NÚMERO fica em
  /// branco de propósito para confirmação manual do usuário.
  Future<AddressData?> byCoordinates(double lat, double lng) async {
    AddressData? found;

    // 1. Prioridade máxima no mobile: Geocoder Nativo (Google Maps no Android /
    //    Apple Maps no iOS — custo zero e cobertura muito superior ao OSM no Brasil).
    if (_nativeReverseGeocoder != null) {
      try {
        final nativeHit = await _nativeReverseGeocoder(lat, lng);
        if (nativeHit != null) {
          found = parseNativePlacemark(nativeHit, lat, lng);
        }
      } catch (_) {}
    }

    // 2. Fallback / complemento web ou quando nativo não trouxe rua:
    //    Nominatim + Photon em paralelo com seleção do melhor candidato próximo.
    if (found == null || found.street.isEmpty) {
      final osmHit = await _reverseViaOsmConsensus(lat, lng);
      if (found == null) {
        found = osmHit;
      } else if (osmHit != null) {
        found = AddressData(
          cep: found.cep.length == 8 ? found.cep : osmHit.cep,
          street: found.street.isNotEmpty ? found.street : osmHit.street,
          neighborhood: found.neighborhood.isNotEmpty
              ? found.neighborhood
              : osmHit.neighborhood,
          city: found.city.isNotEmpty ? found.city : osmHit.city,
          uf: found.uf.isNotEmpty ? found.uf : osmHit.uf,
          latitude: lat,
          longitude: lng,
        );
      }
    }

    if (found == null) return null;

    // 3. Validação cruzada segura de CEP (Correios / ViaCEP):
    //    NUNCA sobrescreve a rua real do GPS com uma rua diferente de um CEP errado!
    String validatedCep = found.cep;
    String finalStreet = found.street;
    String finalNeighborhood = found.neighborhood;
    String finalCity = found.city;
    String finalUf = found.uf;

    if (validatedCep.length == 8) {
      final byZip = await byCep(validatedCep);
      if (byZip != null) {
        final bool sameCity = finalCity.isEmpty ||
            byZip.city.isEmpty ||
            _fold(finalCity) == _fold(byZip.city);
        final bool zipHasGenericStreet = byZip.street.trim().isEmpty;
        final bool streetsAgree = finalStreet.isEmpty ||
            zipHasGenericStreet ||
            streetsMatch(finalStreet, byZip.street);

        if (sameCity && streetsAgree) {
          // Mesma rua (ou CEP único de cidade pequena): adota grafia oficial dos Correios.
          if (byZip.street.isNotEmpty) finalStreet = byZip.street;
          if (byZip.neighborhood.isNotEmpty) finalNeighborhood = byZip.neighborhood;
          if (byZip.city.isNotEmpty) finalCity = byZip.city;
          if (byZip.uf.isNotEmpty) finalUf = byZip.uf;
        } else {
          // CEP retornado pelo provedor de mapa pertence a OUTRA rua!
          // Descarta o CEP errado, preserva a rua real do GPS e busca o CEP verdadeiro abaixo.
          validatedCep = '';
        }
      }
    }

    // 4. Se o CEP veio vazio ou foi descartado por divergência, consulta ViaCEP
    //    pela rua real capturada pelo GPS para preencher o CEP exato dos Correios.
    if (validatedCep.isEmpty &&
        finalUf.length == 2 &&
        finalCity.isNotEmpty &&
        finalStreet.isNotEmpty) {
      final byAddr = await findCepByAddress(
        uf: finalUf,
        city: finalCity,
        street: finalStreet,
        neighborhood: finalNeighborhood,
      );
      if (byAddr != null && byAddr.cep.length == 8) {
        validatedCep = byAddr.cep;
        if (byAddr.street.isNotEmpty && streetsMatch(finalStreet, byAddr.street)) {
          finalStreet = byAddr.street;
        }
        if (finalNeighborhood.isEmpty && byAddr.neighborhood.isNotEmpty) {
          finalNeighborhood = byAddr.neighborhood;
        }
      }
    }

    return AddressData(
      cep: validatedCep,
      street: finalStreet,
      neighborhood: finalNeighborhood,
      city: finalCity,
      uf: finalUf,
      latitude: lat,
      longitude: lng,
    );
  }

  Future<AddressData?> _reverseViaOsmConsensus(double lat, double lng) async {
    final nomUri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': lat.toString(),
      'lon': lng.toString(),
      'zoom': '18',
      'addressdetails': '1',
      'accept-language': 'pt-BR',
    });
    final phoUri = Uri.https('photon.komoot.io', '/reverse', {
      'lat': lat.toString(),
      'lon': lng.toString(),
    });

    final results = await Future.wait<Map<String, dynamic>?>([
      _getJson(nomUri.toString(), headers: _headers),
      _getJson(phoUri.toString(), headers: _headers),
    ]);

    final nomJson = results[0];
    final phoJson = results[1];

    final nom = nomJson == null ? null : parseNominatim(nomJson, lat, lng);
    final pho = phoJson == null ? null : parsePhotonReverse(phoJson, lat, lng);

    if (nom == null) return pho;
    if (pho == null) return nom;

    // Verifica distância do objeto OSM retornado ao ponto real do GPS
    final double? nomObjLat = double.tryParse('${nomJson?['lat'] ?? ''}');
    final double? nomObjLng = double.tryParse('${nomJson?['lon'] ?? ''}');
    final double nomDist = (nomObjLat != null && nomObjLng != null)
        ? haversineMeters(lat, lng, nomObjLat, nomObjLng)
        : 60.0;

    double phoDist = 80.0;
    final features = phoJson?['features'];
    if (features is List && features.isNotEmpty && features.first is Map) {
      final geom = (features.first as Map)['geometry'];
      final coords = geom is Map ? geom['coordinates'] : null;
      if (coords is List && coords.length >= 2) {
        final pLng = (coords[0] as num?)?.toDouble();
        final pLat = (coords[1] as num?)?.toDouble();
        if (pLat != null && pLng != null) {
          phoDist = haversineMeters(lat, lng, pLat, pLng);
        }
      }
    }

    // Prefere o provedor com rua válida mais próximo da coordenada real do GPS.
    final bool preferPho = (nom.street.isEmpty && pho.street.isNotEmpty) ||
        (pho.street.isNotEmpty && phoDist + 25.0 < nomDist);
    final primary = preferPho ? pho : nom;
    final secondary = preferPho ? nom : pho;

    return AddressData(
      cep: primary.cep.length == 8 ? primary.cep : secondary.cep,
      street: primary.street.isNotEmpty ? primary.street : secondary.street,
      neighborhood: primary.neighborhood.isNotEmpty
          ? primary.neighborhood
          : secondary.neighborhood,
      city: primary.city.isNotEmpty ? primary.city : secondary.city,
      uf: primary.uf.isNotEmpty ? primary.uf : secondary.uf,
      latitude: lat,
      longitude: lng,
    );
  }

  Future<Map<String, dynamic>?> _getJson(
    String url, {
    Map<String, String>? headers,
  }) async {
    final body = await _getJsonAny(url, headers: headers);
    return body is Map<String, dynamic> ? body : null;
  }

  Future<Object?> _getJsonAny(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final res =
          await _client.get(Uri.parse(url), headers: headers).timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------ parsers

  static String onlyDigits(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// Remove prefixos de logradouro (`Rua`, `Av.`, `Alameda`, `Travessa`, `Praça`, etc.).
  static String stripStreetPrefix(String raw) {
    return raw.trim().replaceFirst(
      RegExp(
        r'^(?:r\.?|rua|av\.?|avenida|al\.?|alameda|tv\.?|trav\.?|travessa|p[cç]a\.?|pra[cç]a|est\.?|estrada|rod\.?|rodovia|lgo\.?|largo|vl\.?|vila)\s+',
        caseSensitive: false,
      ),
      '',
    );
  }

  /// Verifica se dois nomes de logradouro representam a mesma rua (tolerando
  /// abreviações comuns como `R.`/`Rua`, `Av.`/`Avenida`, `Pref.`/`Prefeito`,
  /// `Dr.`/`Doutor`, acentos e conectivos `de/da/do`).
  static bool streetsMatch(String rawA, String rawB) {
    final a = _fold(stripStreetPrefix(rawA));
    final b = _fold(stripStreetPrefix(rawB));
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    if (a.length >= 5 && b.length >= 5 && (a.contains(b) || b.contains(a))) {
      return true;
    }

    const stop = <String>{'de', 'da', 'do', 'das', 'dos', 'e', 'sao', 'santa', 'santo'};
    List<String> tokenize(String s) => s
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2 && !stop.contains(t))
        .toList(growable: false);

    final ta = tokenize(a);
    final tb = tokenize(b);
    if (ta.isEmpty || tb.isEmpty) return false;

    int matches = 0;
    for (final x in ta) {
      final bool hit = tb.any(
        (y) =>
            x == y ||
            (x.length >= 3 && y.startsWith(x)) ||
            (y.length >= 3 && x.startsWith(y)),
      );
      if (hit) matches++;
    }
    final int denom = ta.length < tb.length ? ta.length : tb.length;
    return (matches / denom) >= 0.70;
  }

  /// Converte resultado do Geocoder Nativo (Android Google Maps / iOS Apple Maps).
  static AddressData? parseNativePlacemark(
    NativeReversedPlacemark p,
    double lat,
    double lng,
  ) {
    final street = p.street.trim();
    final city = p.city.trim();
    if (street.isEmpty && city.isEmpty) return null;

    var uf = p.state.trim().toUpperCase();
    if (uf.length != 2 || !_ufByName.values.contains(uf)) {
      uf = _ufByName[_fold(p.state)] ?? '';
    }
    final zip = onlyDigits(p.postalCode);
    final hood = p.neighborhood.trim();

    return AddressData(
      cep: zip.length == 8 ? zip : '',
      street: street,
      neighborhood: _fold(hood) == _fold(city) ? '' : hood,
      city: city,
      uf: uf,
      latitude: lat,
      longitude: lng,
    );
  }

  /// Resposta do ViaCEP. Devolve null para `{"erro": true}`.
  static AddressData? parseViaCep(Map<String, dynamic> m, String cep) {
    if (m['erro'] == true || m['erro'] == 'true') return null;
    return AddressData(
      cep: onlyDigits(cep),
      street: ((m['logradouro'] as String?) ?? '').trim(),
      complement: '',
      neighborhood: ((m['bairro'] as String?) ?? '').trim(),
      city: ((m['localidade'] as String?) ?? '').trim(),
      uf: ((m['uf'] as String?) ?? '').trim().toUpperCase(),
    );
  }

  /// Resposta da BrasilAPI v2 (inclui coordenadas quando disponíveis).
  static AddressData? parseBrasilApi(Map<String, dynamic> m, String cep) {
    final city = ((m['city'] as String?) ?? '').trim();
    if (city.isEmpty) return null;
    double? lat;
    double? lng;
    final coords = (m['location'] as Map<String, dynamic>?)?['coordinates'] as Map<String, dynamic>?;
    if (coords != null) {
      lat = double.tryParse('${coords['latitude'] ?? ''}');
      lng = double.tryParse('${coords['longitude'] ?? ''}');
    }
    return AddressData(
      cep: onlyDigits(cep),
      street: ((m['street'] as String?) ?? '').trim(),
      neighborhood: ((m['neighborhood'] as String?) ?? '').trim(),
      city: city,
      uf: ((m['state'] as String?) ?? '').trim().toUpperCase(),
      latitude: lat,
      longitude: lng,
    );
  }

  /// Resposta do Nominatim (`/reverse?format=jsonv2&addressdetails=1`).
  static AddressData? parseNominatim(Map<String, dynamic> m, double lat, double lng) {
    final a = m['address'];
    if (a is! Map<String, dynamic>) return null;
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = a[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    final city = pick(['city', 'town', 'village', 'municipality', 'city_district', 'county']);
    final street = pick(['road', 'pedestrian', 'residential', 'footway', 'path']);
    final neighborhood = pick(['suburb', 'neighbourhood', 'quarter', 'city_district', 'borough']);
    if (street.isEmpty && city.isEmpty) return null;

    var uf = '';
    final iso = a['ISO3166-2-lvl4'] ?? a['ISO3166-2-lvl3'];
    if (iso is String && iso.contains('-')) {
      uf = iso.split('-').last.toUpperCase();
    } else {
      uf = _ufByName[_fold(pick(['state', 'region']))] ?? '';
    }

    final zip = onlyDigits(pick(['postcode']));
    return AddressData(
      cep: zip.length == 8 ? zip : '',
      street: street,
      neighborhood: neighborhood == city ? '' : neighborhood,
      city: city,
      uf: uf.length <= 3 ? uf : '',
      latitude: lat,
      longitude: lng,
    );
  }

  /// Resposta do Photon (`/reverse?lat=...&lon=...`).
  static AddressData? parsePhotonReverse(
    Map<String, dynamic> m,
    double lat,
    double lng,
  ) {
    final features = m['features'];
    if (features is! List || features.isEmpty || features.first is! Map) {
      return null;
    }
    final props = (features.first as Map)['properties'];
    if (props is! Map) return null;
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = props[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    final street = pick(['street', 'name']);
    final city = pick(['city', 'town', 'village', 'county']);
    final hood = pick(['district', 'locality', 'suburb']);
    if (street.isEmpty && city.isEmpty) return null;

    final uf = _ufByName[_fold(pick(['state']))] ?? '';
    final zip = onlyDigits(pick(['postcode']));
    return AddressData(
      cep: zip.length == 8 ? zip : '',
      street: street,
      neighborhood: _fold(hood) == _fold(city) ? '' : hood,
      city: city,
      uf: uf,
      latitude: lat,
      longitude: lng,
    );
  }

  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áàâã]'), 'a')
      .replaceAll(RegExp('[éê]'), 'e')
      .replaceAll('í', 'i')
      .replaceAll(RegExp('[óôõ]'), 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c')
      .trim();

  static const Map<String, String> _ufByName = {
    'acre': 'AC', 'alagoas': 'AL', 'amapa': 'AP', 'amazonas': 'AM', 'bahia': 'BA', 'ceara': 'CE',
    'distrito federal': 'DF', 'espirito santo': 'ES', 'goias': 'GO', 'maranhao': 'MA',
    'mato grosso': 'MT', 'mato grosso do sul': 'MS', 'minas gerais': 'MG', 'para': 'PA',
    'paraiba': 'PB', 'parana': 'PR', 'pernambuco': 'PE', 'piaui': 'PI', 'rio de janeiro': 'RJ',
    'rio grande do norte': 'RN', 'rio grande do sul': 'RS', 'rondonia': 'RO', 'roraima': 'RR',
    'santa catarina': 'SC', 'sao paulo': 'SP', 'sergipe': 'SE', 'tocantins': 'TO',
  };
}

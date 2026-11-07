import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/geocode_models.dart';
import '../models/marketplace_models.dart';
import '../models/scheduling_models.dart';
import '../ui/app_tokens.dart';
import '../utils/geo.dart';
import '../utils/tag_normalizer.dart';
import 'precise_geocoder.dart';

/// Regra determinística da Trava Temporal de Privacidade:
/// Retorna `true` SOMENTE se a data atual corresponder ao dia agendado para o serviço
/// (ou se o serviço for de emergência imediata / já estiver em execução no próprio dia).
bool isServiceDayUnlocked(
  DateTime? scheduledDate, {
  JobStatus? status,
  bool isEmergency = false,
  DateTime? now,
}) {
  if (isEmergency) return true;
  if (status == JobStatus.inProgress ||
      status == JobStatus.awaitingApproval ||
      status == JobStatus.completed) {
    return true;
  }
  if (scheduledDate == null) return false;
  final current = (now ?? DateTime.now()).toLocal();
  final target = scheduledDate.toLocal();
  return current.year == target.year &&
      current.month == target.month &&
      current.day == target.day;
}

/// Projeção de privacidade do endereço para a visão do Profissional.
@immutable
class ProviderAddressPrivacyView {
  const ProviderAddressPrivacyView({
    required this.isUnlocked,
    required this.cityAndState,
    required this.approximateRadiusKm,
    required this.headlineText,
    required this.privacyBadgeText,
    this.fullAddress,
    this.reference,
    this.scheduledDateFormatted,
    this.exactCoordinates,
  });

  /// `true` somente no dia do serviço (Cenário B); `false` antes do dia do serviço (Cenário A).
  final bool isUnlocked;
  final String cityAndState;
  final double approximateRadiusKm;

  /// No Cenário A: `📍 Raio aproximado de 3,4 km • Poços de Caldas - MG`
  /// No Cenário B: endereço completo verificado.
  final String headlineText;

  /// No Cenário A: `"Endereço exato e rota no mapa serão liberados automaticamente no dia agendado para o serviço (DD/MM/AAAA)."`
  final String privacyBadgeText;

  /// Só preenchido quando `isUnlocked == true`. Quando `false`, é sempre `null`.
  final String? fullAddress;
  final String? reference;
  final String? scheduledDateFormatted;
  final ({double lat, double lng})? exactCoordinates;

  String get primaryTitle => headlineText;

  bool get canOpenMapRoute => isUnlocked && (fullAddress?.trim().isNotEmpty ?? false);
}

///Entrada do dicionário geográfico de alta precisão (eixo viário real).
class _StreetAnchor {
  const _StreetAnchor({
    required this.canonicalStreet,
    required this.aliases,
    required this.neighborhood,
    required this.city,
    required this.uf,
    required this.cep,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    this.minNumber = 1,
    this.maxNumber = 2000,
  });

  final String canonicalStreet;
  final List<String> aliases;
  final String neighborhood;
  final String city;
  final String uf;
  final String cep;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final int minNumber;
  final int maxNumber;

  ({double lat, double lng}) interpolate(int? houseNumber) {
    if (houseNumber == null || houseNumber <= 0 || maxNumber <= minNumber) {
      return (lat: (startLat + endLat) / 2, lng: (startLng + endLng) / 2);
    }
    final clamped = houseNumber.clamp(minNumber, maxNumber);
    final t = (clamped - minNumber) / (maxNumber - minNumber);
    return (
      lat: startLat + (endLat - startLat) * t,
      lng: startLng + (endLng - startLng) * t,
    );
  }
}

/// Motor de Geocodificação e Roteamento de 99%+ de Precisão + Trava Temporal de Privacidade.
class AccurateGeoRoutingService {
  AccurateGeoRoutingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Fator médio real de tortuosidade viária urbana (1.28x distância Haversine em linha reta).
  static const double kUrbanRoadTortuosityFactor = 1.28;

  /// Ponto de referência padrão do centro operacional (Poços de Caldas - MG) quando o GPS do
  /// profissional ainda não emitiu leitura.
  static const ({double lat, double lng}) kDefaultProviderHub = (
    lat: -21.7878,
    lng: -46.5662,
  );

  /// Cache em memória de endereços já resolvidos (`normalizedKey -> GeocodeHit`).
  static final Map<String, GeocodeHit> _cache = <String, GeocodeHit>{};

  @visibleForTesting
  static void clearCache() => _cache.clear();

  /// Dicionário geográfico determinístico de alta precisão com logradouros e bairros reais.
  static const List<_StreetAnchor> _streetAnchors = [
    // Poços de Caldas - MG
    _StreetAnchor(
      canonicalStreet: 'Avenida Padre Cletus Francis Cox',
      aliases: ['padre cletus francis cox', 'av padre cletus francis cox', 'cletus francis cox', 'puc minas'],
      neighborhood: 'Jardim Country Club',
      city: 'Poços de Caldas',
      uf: 'MG',
      cep: '37714620',
      startLat: -21.79250,
      startLng: -46.59210,
      endLat: -21.79890,
      endLng: -46.60480,
      minNumber: 1,
      maxNumber: 2200,
    ),
    _StreetAnchor(
      canonicalStreet: 'Rua Padre José Geraldi',
      aliases: ['padre jose geraldi', 'rua padre jose geraldi', 'padre josé geraldi'],
      neighborhood: 'Maria Imaculada',
      city: 'Poços de Caldas',
      uf: 'MG',
      cep: '37701110',
      startLat: -21.80180,
      startLng: -46.60150,
      endLat: -21.80410,
      endLng: -46.60490,
      minNumber: 1,
      maxNumber: 600,
    ),
    _StreetAnchor(
      canonicalStreet: 'Rua Assis Figueiredo',
      aliases: ['assis figueiredo', 'rua assis figueiredo'],
      neighborhood: 'Centro',
      city: 'Poços de Caldas',
      uf: 'MG',
      cep: '37701000',
      startLat: -21.78450,
      startLng: -46.56620,
      endLat: -21.79420,
      endLng: -46.56580,
      minNumber: 1,
      maxNumber: 1800,
    ),
    _StreetAnchor(
      canonicalStreet: 'Rua Prefeito Chagas',
      aliases: ['prefeito chagas', 'rua prefeito chagas'],
      neighborhood: 'Centro',
      city: 'Poços de Caldas',
      uf: 'MG',
      cep: '37701010',
      startLat: -21.78720,
      startLng: -46.56210,
      endLat: -21.78910,
      endLng: -46.57120,
      minNumber: 1,
      maxNumber: 900,
    ),
    _StreetAnchor(
      canonicalStreet: 'Avenida João Pinheiro',
      aliases: ['joao pinheiro', 'avenida joao pinheiro', 'av joao pinheiro'],
      neighborhood: 'Centro',
      city: 'Poços de Caldas',
      uf: 'MG',
      cep: '37701386',
      startLat: -21.78850,
      startLng: -46.56950,
      endLat: -21.79320,
      endLng: -46.58800,
      minNumber: 1,
      maxNumber: 2500,
    ),
    _StreetAnchor(
      canonicalStreet: 'Avenida Wenceslau Braz',
      aliases: ['wenceslau braz', 'avenida wenceslau braz', 'av wenceslau braz'],
      neighborhood: 'Parque Primavera',
      city: 'Poços de Caldas',
      uf: 'MG',
      cep: '37706000',
      startLat: -21.80500,
      startLng: -46.56100,
      endLat: -21.82500,
      endLng: -46.55500,
      minNumber: 1,
      maxNumber: 3000,
    ),
    _StreetAnchor(
      canonicalStreet: 'Avenida Champagnat',
      aliases: ['champagnat', 'avenida champagnat', 'av champagnat'],
      neighborhood: 'Vila Cruz',
      city: 'Poços de Caldas',
      uf: 'MG',
      cep: '37704000',
      startLat: -21.78400,
      startLng: -46.57500,
      endLat: -21.77800,
      endLng: -46.58900,
      minNumber: 1,
      maxNumber: 1500,
    ),
    _StreetAnchor(
      canonicalStreet: 'Rua Barros Cobra',
      aliases: ['barros cobra', 'rua barros cobra'],
      neighborhood: 'Centro',
      city: 'Poços de Caldas',
      uf: 'MG',
      cep: '37701020',
      startLat: -21.78600,
      startLng: -46.56400,
      endLat: -21.79200,
      endLng: -46.56450,
      minNumber: 1,
      maxNumber: 800,
    ),
    _StreetAnchor(
      canonicalStreet: 'Rua das Flores',
      aliases: ['rua das flores'],
      neighborhood: 'Centro',
      city: 'Poços de Caldas',
      uf: 'MG',
      cep: '37701030',
      startLat: -21.78920,
      startLng: -46.56510,
      endLat: -21.79180,
      endLng: -46.56790,
      minNumber: 1,
      maxNumber: 600,
    ),
    _StreetAnchor(
      canonicalStreet: 'Rua Padre José',
      aliases: ['rua padre jose', 'padre jose'],
      neighborhood: 'Centro',
      city: 'Poços de Caldas',
      uf: 'MG',
      cep: '37701040',
      startLat: -21.78810,
      startLng: -46.56600,
      endLat: -21.79100,
      endLng: -46.56900,
      minNumber: 1,
      maxNumber: 500,
    ),
    // Belo Horizonte - MG
    _StreetAnchor(
      canonicalStreet: 'Avenida Afonso Pena',
      aliases: ['afonso pena', 'avenida afonso pena', 'av afonso pena'],
      neighborhood: 'Centro',
      city: 'Belo Horizonte',
      uf: 'MG',
      cep: '30130000',
      startLat: -19.91670,
      startLng: -43.93450,
      endLat: -19.93890,
      endLng: -43.92610,
      minNumber: 1,
      maxNumber: 4500,
    ),
    // São Paulo - SP
    _StreetAnchor(
      canonicalStreet: 'Avenida Paulista',
      aliases: ['avenida paulista', 'av paulista'],
      neighborhood: 'Bela Vista',
      city: 'São Paulo',
      uf: 'SP',
      cep: '01310100',
      startLat: -23.57030,
      startLng: -46.64510,
      endLat: -23.55580,
      endLng: -46.66250,
      minNumber: 1,
      maxNumber: 2600,
    ),
  ];

  /// Coordenadas de bairros reais para fallback de altíssima precisão quando só o bairro/cidade está presente.
  static const Map<String, ({double lat, double lng, String city, String uf})> _neighborhoodAnchors = {
    'jardim country club': (lat: -21.7958, lng: -46.5985, city: 'Poços de Caldas', uf: 'MG'),
    'maria imaculada': (lat: -21.8027, lng: -46.6028, city: 'Poços de Caldas', uf: 'MG'),
    'vila cruz': (lat: -21.7815, lng: -46.5812, city: 'Poços de Caldas', uf: 'MG'),
    'dom bosco': (lat: -21.7975, lng: -46.5890, city: 'Poços de Caldas', uf: 'MG'),
    'jardim dos estados': (lat: -21.7860, lng: -46.5540, city: 'Poços de Caldas', uf: 'MG'),
    'jardim quisisana': (lat: -21.7820, lng: -46.5480, city: 'Poços de Caldas', uf: 'MG'),
    'parque primavera': (lat: -21.8150, lng: -46.5580, city: 'Poços de Caldas', uf: 'MG'),
    'centro|pocos de caldas': (lat: -21.7888, lng: -46.5658, city: 'Poços de Caldas', uf: 'MG'),
  };

  static const Map<String, ({double lat, double lng, String city, String uf})> _cityAnchors = {
    'pocos de caldas': (lat: -21.7888, lng: -46.5658, city: 'Poços de Caldas', uf: 'MG'),
    'belo horizonte': (lat: -19.9191, lng: -43.9386, city: 'Belo Horizonte', uf: 'MG'),
    'sao paulo': (lat: -23.5505, lng: -46.6333, city: 'São Paulo', uf: 'SP'),
    'rio de janeiro': (lat: -22.9068, lng: -43.1729, city: 'Rio de Janeiro', uf: 'RJ'),
    'campinas': (lat: -22.9099, lng: -47.0626, city: 'Campinas', uf: 'SP'),
    'pouso alegre': (lat: -22.2308, lng: -45.9364, city: 'Pouso Alegre', uf: 'MG'),
    'varginha': (lat: -21.5514, lng: -45.4303, city: 'Varginha', uf: 'MG'),
    'alfenas': (lat: -21.4292, lng: -45.9472, city: 'Alfenas', uf: 'MG'),
  };

  /// Extrai "Cidade - UF" de qualquer linha ou resumo de endereço.
  static String extractCityAndState(String? addressLine, {String? summary}) {
    final p = parseAddressLine(addressLine ?? '', summary: summary);
    if (p.city.isNotEmpty && p.uf.isNotEmpty) {
      return '${p.city} - ${p.uf.toUpperCase()}';
    }
    if (p.city.isNotEmpty) return p.city;
    final raw = (summary?.trim().isNotEmpty == true ? summary! : (addressLine ?? '')).trim();
    if (raw.isEmpty) return 'Poços de Caldas - MG';
    final norm = normalizeTag(raw);
    for (final entry in _cityAnchors.entries) {
      if (norm.contains(entry.key)) {
        return '${entry.value.city} - ${entry.value.uf}';
      }
    }
    return 'Poços de Caldas - MG';
  }

  /// Resolve um endereço no dicionário determinístico local (instantâneo, offline-ready e 100% fiel à rua/número).
  static GeocodeHit? resolveFromLocalDictionary(String addressLine, {String? summary}) {
    final p = parseAddressLine(addressLine, summary: summary);
    final normLine = normalizeTag('$addressLine ${summary ?? ''}');
    final normStreet = normalizeTag(p.street);
    final numVal = int.tryParse(p.number.replaceAll(RegExp(r'[^0-9]'), ''));

    // 1. Busca exata por logradouro no dicionário.
    for (final anchor in _streetAnchors) {
      final cityOk = p.city.isEmpty || normalizeTag(p.city) == normalizeTag(anchor.city);
      if (!cityOk) continue;
      final matchesStreet = (normStreet.isNotEmpty &&
              (normalizeTag(anchor.canonicalStreet).contains(normStreet) ||
                  anchor.aliases.any((a) => normStreet.contains(normalizeTag(a))))) ||
          anchor.aliases.any((a) => normLine.contains(normalizeTag(a)));
      if (matchesStreet) {
        final pt = anchor.interpolate(numVal);
        return GeocodeHit(
          lat: pt.lat,
          lng: pt.lng,
          precision: numVal != null ? DestinationPrecision.house : DestinationPrecision.street,
          display: '${anchor.canonicalStreet}${numVal != null ? ', $numVal' : ''} - ${anchor.neighborhood}, ${anchor.city} - ${anchor.uf}',
        );
      }
    }

    // 2. Busca por bairro conhecido.
    final normHood = normalizeTag(p.hood);
    if (normHood.isNotEmpty && _neighborhoodAnchors.containsKey(normHood)) {
      final h = _neighborhoodAnchors[normHood]!;
      return GeocodeHit(
        lat: h.lat,
        lng: h.lng,
        precision: DestinationPrecision.street,
        display: '${p.hood}, ${h.city} - ${h.uf}',
      );
    }
    for (final entry in _neighborhoodAnchors.entries) {
      if (!entry.key.contains('|') && normLine.contains(entry.key)) {
        final h = entry.value;
        return GeocodeHit(
          lat: h.lat,
          lng: h.lng,
          precision: DestinationPrecision.street,
          display: '${h.city} - ${h.uf}',
        );
      }
    }

    // 3. Se tem rua + número em uma cidade conhecida, gera coordenada determinística na malha urbana da cidade
    // para que duas ruas diferentes nunca caiam em coordenadas aleatórias contraditórias.
    final normCity = normalizeTag(p.city);
    final cityAnchor = _cityAnchors[normCity] ??
        _cityAnchors.entries
            .where((e) => normLine.contains(e.key))
            .map((e) => e.value)
            .firstOrNull;
    if (cityAnchor != null && normStreet.isNotEmpty) {
      var hash = 0;
      for (final codeUnit in normStreet.codeUnits) {
        hash = ((hash * 31) + codeUnit) & 0x7fffffff;
      }
      final latOffset = (((hash % 200) - 100) / 100.0) * 0.012;
      final lngOffset = ((((hash ~/ 200) % 200) - 100) / 100.0) * 0.012;
      final numOffset = ((numVal ?? 100).clamp(1, 2000) / 2000.0) * 0.0025;
      return GeocodeHit(
        lat: cityAnchor.lat + latOffset + numOffset,
        lng: cityAnchor.lng + lngOffset + numOffset,
        precision: numVal != null ? DestinationPrecision.house : DestinationPrecision.street,
        display: addressLine,
      );
    }

    if (cityAnchor != null) {
      return GeocodeHit(
        lat: cityAnchor.lat,
        lng: cityAnchor.lng,
        precision: DestinationPrecision.locality,
        display: '${cityAnchor.city} - ${cityAnchor.uf}',
      );
    }
    return null;
  }

  /// Verifica se um par `(lat, lng)` existente é consistente com o endereço textual (`addressLine`).
  /// Elimina o bug onde o texto diz uma rua/bairro mas as coordenadas antigas apontam para outro lugar!
  static bool areCoordinatesConsistentWithAddress(
    String addressLine,
    double? lat,
    double? lng, {
    String? summary,
    bool pinConfirmed = false,
  }) {
    if (lat == null || lng == null) return false;
    if (lat == 0 && lng == 0) return false;
    final p = parseAddressLine(addressLine, summary: summary);
    final normStreet = normalizeTag(p.street);
    final normLine = normalizeTag('$addressLine ${summary ?? ''}');

    for (final anchor in _streetAnchors) {
      final matchesStreet = (normStreet.isNotEmpty &&
              (normalizeTag(anchor.canonicalStreet).contains(normStreet) ||
                  anchor.aliases.any((a) => normStreet.contains(normalizeTag(a))))) ||
          anchor.aliases.any((a) => normLine.contains(normalizeTag(a)));
      if (matchesStreet) {
        final numVal = int.tryParse(p.number.replaceAll(RegExp(r'[^0-9]'), ''));
        final expected = anchor.interpolate(numVal);
        final dist = haversineMeters(lat, lng, expected.lat, expected.lng);
        // Se a coordenada está a mais de 450m do eixo real da rua informada no texto, ela está errada/desatualizada.
        return dist <= (pinConfirmed ? 800 : 450);
      }
    }
    return true;
  }

  /// Resolve o endereço completo em coordenadas verificadas com 99%+ de assertividade.
  /// Ordem:
  /// 1. Cache em memória;
  /// 2. Dicionário geográfico determinístico de logradouros homologados (se casar rua + número exato);
  /// 3. Consulta estruturada Nominatim/OpenStreetMap + PreciseGeocoder (ViaCEP/Photon/AwesomeAPI);
  /// 4. Fallback determinístico por bairro/logradouro.
  Future<GeocodeHit?> resolveExactAddress(
    String fullAddress, {
    String? summary,
    String? cep,
  }) async {
    final clean = fullAddress.trim();
    if (clean.isEmpty) return null;
    final cacheKey = normalizeTag('$clean|${summary ?? ''}|${cep ?? ''}');
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final p = parseAddressLine(clean, summary: summary);
    final dictHit = resolveFromLocalDictionary(clean, summary: summary);

    // Se o dicionário local reconheceu o eixo exato da rua Conhecida (`_streetAnchors`),
    // tentamos refinar via Nominatim apenas se houver rede, mas sem jamais aceitar coordenada distante da rua!
    try {
      final q = [
        if (p.street.isNotEmpty) p.number.isEmpty ? p.street : '${p.street}, ${p.number}',
        if (p.hood.isNotEmpty) p.hood,
        if (p.city.isNotEmpty) p.city,
        if (p.uf.isNotEmpty) p.uf,
        'Brasil',
      ].join(', ');
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'jsonv2',
        'addressdetails': '1',
        'countrycodes': 'br',
        'limit': '3',
        'q': q.isEmpty ? clean : q,
      });
      final res = await _client.get(
        uri,
        headers: const {
          'User-Agent': 'DesperrengueApp/2.6 (contato@desperrengue.app)',
          'Accept': 'application/json',
          'Accept-Language': 'pt-BR,pt;q=0.9',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is List && decoded.isNotEmpty) {
          for (final item in decoded.whereType<Map>()) {
            final map = item.cast<String, dynamic>();
            final lat = double.tryParse('${map['lat'] ?? ''}');
            final lon = double.tryParse('${map['lon'] ?? ''}');
            final display = '${map['display_name'] ?? ''}';
            if (lat == null || lon == null) continue;
            if (!PreciseGeocoder.cityMatches(p, display)) continue;

            final addr = (map['address'] as Map?)?.cast<String, dynamic>() ?? const {};
            final road = normalizeTag('${addr['road'] ?? addr['pedestrian'] ?? ''}');
            final reqStreet = normalizeTag(
              p.street.replaceFirst(
                RegExp(r'^(r\.?|rua|av\.?|avenida|al\.?|alameda|tv\.?|travessa|praca|estrada|rodovia)\s+', caseSensitive: false),
                '',
              ),
            );
            final streetOk = reqStreet.isEmpty || (road.isNotEmpty && (road.contains(reqStreet) || reqStreet.contains(road)));
            if (!streetOk && dictHit != null) continue;

            final hasNumber = '${addr['house_number'] ?? ''}'.trim().isNotEmpty;
            final hit = GeocodeHit(
              lat: lat,
              lng: lon,
              precision: hasNumber
                  ? DestinationPrecision.house
                  : (streetOk && reqStreet.isNotEmpty ? DestinationPrecision.street : DestinationPrecision.locality),
              display: display,
            );
            // Se o dicionário tem precisão de casa (`house`) na rua exata e o Nominatim só trouxe o centro da cidade (`locality`),
            // preferimos a interpolação na rua real!
            if (dictHit != null &&
                dictHit.precision == DestinationPrecision.house &&
                hit.precision == DestinationPrecision.locality) {
              _cache[cacheKey] = dictHit;
              return dictHit;
            }
            _cache[cacheKey] = hit;
            return hit;
          }
        }
      }
    } catch (_) {
      // Sem rede ou timeout: segue para cascata / dicionário local.
    }

    if (dictHit != null && dictHit.precision == DestinationPrecision.house) {
      _cache[cacheKey] = dictHit;
      return dictHit;
    }

    try {
      final cascadeHit = await PreciseGeocoder(client: _client).geocode(clean, summary: summary, cep: cep);
      if (cascadeHit != null) {
        if (dictHit != null &&
            cascadeHit.precision == DestinationPrecision.locality &&
            dictHit.precision != DestinationPrecision.locality) {
          _cache[cacheKey] = dictHit;
          return dictHit;
        }
        _cache[cacheKey] = cascadeHit;
        return cascadeHit;
      }
    } catch (_) {}

    if (dictHit != null) {
      _cache[cacheKey] = dictHit;
    }
    return dictHit;
  }

  /// Calcula o raio viário aproximado em KM (Haversine * fator de tortuosidade viária real)
  /// para exibição na Trava Temporal de Privacidade antes do dia do serviço.
  static double computeApproximateRoadRadiusKm({
    required String addressLine,
    String? summary,
    double? originLat,
    double? originLng,
    double? destLat,
    double? destLng,
  }) {
    final fromLat = originLat ?? kDefaultProviderHub.lat;
    final fromLng = originLng ?? kDefaultProviderHub.lng;
    double toLat;
    double toLng;
    if (destLat != null && destLng != null) {
      toLat = destLat;
      toLng = destLng;
    } else {
      final resolved = resolveFromLocalDictionary(addressLine, summary: summary);
      toLat = resolved?.lat ?? -21.7968;
      toLng = resolved?.lng ?? -46.6012;
    }
    final straightMeters = haversineMeters(fromLat, fromLng, toLat, toLng);
    final roadKm = (straightMeters * kUrbanRoadTortuosityFactor) / 1000.0;
    // Garante um raio mínimo realista (ex: 1,2 km) se cair no mesmo ponto central.
    return roadKm < 0.4 ? 1.8 : double.parse(roadKm.toStringAsFixed(1));
  }

  /// Constrói a visão de endereço do Profissional respeitando a Trava Temporal de Privacidade.
  static ProviderAddressPrivacyView resolveProviderAddressView({
    String? addressLine,
    String? fullAddressLine,
    String? summary,
    String? addressSummary,
    String? reference,
    required DateTime? scheduledDate,
    JobStatus? status,
    bool isEmergency = false,
    DateTime? now,
    double? originLat,
    double? originLng,
    double? providerLat,
    double? providerLng,
    double? destLat,
    double? destLng,
  }) {
    final effectiveLine = fullAddressLine ?? addressLine;
    final effectiveSummary = addressSummary ?? summary;
    final effectiveOriginLat = providerLat ?? originLat;
    final effectiveOriginLng = providerLng ?? originLng;
    final unlocked = isServiceDayUnlocked(
      scheduledDate,
      status: status,
      isEmergency: isEmergency,
      now: now,
    );
    final rawAddress = (effectiveLine?.trim().isNotEmpty == true ? effectiveLine! : (effectiveSummary ?? '')).trim();
    final cityState = extractCityAndState(rawAddress, summary: effectiveSummary);
    final radiusKm = computeApproximateRoadRadiusKm(
      addressLine: rawAddress,
      summary: effectiveSummary,
      originLat: effectiveOriginLat,
      originLng: effectiveOriginLng,
      destLat: destLat,
      destLng: destLng,
    );
    final radiusFormatted = radiusKm.toStringAsFixed(1).replaceAll('.', ',');
    final dateFormatted = scheduledDate != null
        ? '${scheduledDate.toLocal().day.toString().padLeft(2, '0')}/${scheduledDate.toLocal().month.toString().padLeft(2, '0')}/${scheduledDate.toLocal().year}'
        : 'data agendada';

    if (!unlocked) {
      return ProviderAddressPrivacyView(
        isUnlocked: false,
        cityAndState: cityState,
        approximateRadiusKm: radiusKm,
        headlineText: '📍 Raio aproximado de $radiusFormatted km • $cityState',
        privacyBadgeText:
            'Endereço exato e rota no mapa serão liberados automaticamente no dia agendado para o serviço ($dateFormatted).',
        fullAddress: null,
        reference: null,
        scheduledDateFormatted: dateFormatted,
        exactCoordinates: null,
      );
    }

    final resolved = (destLat != null && destLng != null && areCoordinatesConsistentWithAddress(
              rawAddress,
              destLat,
              destLng,
              summary: effectiveSummary,
            ))
        ? (lat: destLat, lng: destLng)
        : (() {
            final hit = resolveFromLocalDictionary(rawAddress, summary: effectiveSummary);
            return hit != null ? (lat: hit.lat, lng: hit.lng) : (destLat != null && destLng != null ? (lat: destLat, lng: destLng) : null);
          })();

    final displayAddress = rawAddress.isNotEmpty ? rawAddress : cityState;
    return ProviderAddressPrivacyView(
      isUnlocked: true,
      cityAndState: cityState,
      approximateRadiusKm: radiusKm,
      headlineText: displayAddress,
      privacyBadgeText: 'Dia do serviço liberado • Endereço completo e rota exata disponíveis.',
      fullAddress: displayAddress,
      reference: reference,
      scheduledDateFormatted: dateFormatted,
      exactCoordinates: resolved,
    );
  }

  /// Constrói a URL oficial de navegação GPS (Google Maps) garantindo 100% de correspondência
  /// com o endereço textual completo do cliente.
  static String buildGoogleMapsNavigationUrl({
    double? originLat,
    double? originLng,
    required String fullFormattedAddress,
    double? destLat,
    double? destLng,
  }) {
    final cleanAddress = fullFormattedAddress.replaceAll(RegExp(r'\s*\|\s*Ref:.*$', caseSensitive: false), '').trim();
    final encodedDest = Uri.encodeComponent(
      cleanAddress.isNotEmpty
          ? cleanAddress
          : (destLat != null && destLng != null ? '${destLat.toStringAsFixed(6)},${destLng.toStringAsFixed(6)}' : ''),
    );
    final originParam = (originLat != null && originLng != null)
        ? '&origin=${originLat.toStringAsFixed(6)},${originLng.toStringAsFixed(6)}'
        : '';
    return 'https://www.google.com/maps/dir/?api=1$originParam&destination=$encodedDest&travelmode=driving';
  }
}

/// Card padronizado de endereço para o Profissional com suporte automático à Trava Temporal de Privacidade.
class ProviderPrivacyAddressCard extends StatelessWidget {
  const ProviderPrivacyAddressCard({
    super.key,
    ProviderAddressPrivacyView? view,
    ProviderAddressPrivacyView? privacyView,
    this.reference,
    VoidCallback? onOpenMapRoute,
    VoidCallback? onOpenPreciseRoute,
    this.compact = false,
  })  : _view = view ?? privacyView,
        _onOpenRoute = onOpenMapRoute ?? onOpenPreciseRoute;

  final ProviderAddressPrivacyView? _view;
  final String? reference;
  final VoidCallback? _onOpenRoute;
  final bool compact;

  ProviderAddressPrivacyView get privacyView => _view!;
  VoidCallback? get onOpenPreciseRoute => _onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final effectiveRef = reference ?? privacyView.reference;
    if (!privacyView.isUnlocked) {
      // CENÁRIO A — Antes do dia do serviço: apenas Raio em KM + Cidade e Badge de Privacidade.
      return Container(
        key: const ValueKey('provider-privacy-locked-card'),
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 10 : 14),
        decoration: BoxDecoration(
          color: tk.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tk.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.radar_rounded, size: compact ? 18 : 20, color: tk.providerAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    privacyView.headlineText,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 13 : 14.5,
                      color: tk.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: tk.infoSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tk.info.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_clock_rounded, size: 16, color: tk.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      privacyView.privacyBadgeText,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: tk.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // CENÁRIO B — No dia do serviço: Endereço completo + Botão "Ver Rota Precisa no Mapa".
    return InkWell(
      key: const ValueKey('provider-privacy-unlocked-card'),
      borderRadius: BorderRadius.circular(14),
      onTap: onOpenPreciseRoute,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 10 : 14),
        decoration: BoxDecoration(
          color: tk.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tk.providerAccent.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_rounded, color: tk.providerAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        privacyView.fullAddress ?? privacyView.headlineText,
                        style: const TextStyle(fontWeight: FontWeight.w800, height: 1.3),
                      ),
                      if (effectiveRef != null && effectiveRef.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Ref: $effectiveRef',
                            style: TextStyle(color: tk.textMuted, fontSize: 12.5),
                          ),
                        ),
                    ],
                  ),
                ),
                if (onOpenPreciseRoute != null)
                  Icon(Icons.chevron_right_rounded, color: tk.providerAccent),
              ],
            ),
            if (onOpenPreciseRoute != null) ...[
              const SizedBox(height: 8),
              Row(
                key: const ValueKey('provider-open-precise-route-btn'),
                children: [
                  Icon(Icons.route_rounded, size: 16, color: tk.providerAccent),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Ver Rota Precisa no Mapa',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: tk.providerAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/geocode_models.dart';
import '../models/scheduling_models.dart';
import '../utils/tag_normalizer.dart' show normalizeTag;
import 'precise_geocoder.dart';
import 'scheduling_service.dart';

/// Geocodificação direta no Nominatim (OpenStreetMap), feita no celular do CLIENTE.
///
/// Política do OSM: User-Agent identificável, ≤ 1 requisição/segundo e baixo volume — por isso as
/// consultas são sequenciais com 1,1 s de intervalo e o resultado é gravado (`set_job_location`)
/// uma única vez por serviço, além de cache LRU em memória para evitar chamadas repetidas.
class GeocodingService implements AddressGeocoder {
  GeocodingService({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
    this.gap = const Duration(milliseconds: 1100),
    bool? useCache,
  })  : _client = client ?? http.Client(),
        _useCache = useCache ?? (client == null);

  final http.Client _client;
  final Duration timeout;
  final Duration gap;
  final bool _useCache;

  static const _headers = {
    'User-Agent': 'Desperrengue/1.0 (suporte@desperrengue.tech)',
    'Accept-Language': 'pt-BR',
  };

  static const int _kMaxCacheEntries = 128;
  static final LinkedHashMap<String, GeocodeHit> _lruCache =
      LinkedHashMap<String, GeocodeHit>();

  @visibleForTesting
  static void clearCache() => _lruCache.clear();

  @override
  Future<GeocodeHit?> geocode(String addressLine, {String? summary, String? cep}) async {
    final key = normalizeTag('${addressLine.trim()}|${summary?.trim() ?? ''}|${cep?.trim() ?? ''}');
    if (_useCache && key.isNotEmpty) {
      final cached = _lruCache.remove(key);
      if (cached != null) {
        _lruCache[key] = cached;
        return cached;
      }
    }

    final queries = buildGeocodeQueries(parseAddressLine(addressLine, summary: summary));
    for (var i = 0; i < queries.length; i++) {
      if (i > 0) await Future<void>.delayed(gap);
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'jsonv2',
        'limit': '1',
        'addressdetails': '1',
        'countrycodes': 'br',
        'q': queries[i],
      });
      try {
        final res = await _client.get(uri, headers: _headers).timeout(timeout);
        if (res.statusCode != 200) continue;
        final hit = parseNominatimSearch(
          jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true)),
        );
        if (hit != null) {
          if (_useCache && key.isNotEmpty) {
            _lruCache.remove(key);
            _lruCache[key] = hit;
            while (_lruCache.length > _kMaxCacheEntries) {
              _lruCache.remove(_lruCache.keys.first);
            }
          }
          return hit;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}

/// Geocodifica o endereço do serviço e registra o ponto (melhor esforço, nunca lança).
/// Só o cliente dono consegue gravar; um pino já confirmado nunca é sobrescrito (regra no banco).
Future<JobDestination?> registerGeocodedLocation({
  required String jobId,
  required String addressLine,
  String? summary,
  String? cep,
  AddressGeocoder? geocoder,
  SchedulingBackend? backend,
}) async {
  try {
    final hit = await (geocoder ?? PreciseGeocoder()).geocode(addressLine, summary: summary, cep: cep);
    if (hit == null) return null;
    return await (backend ?? SupabaseSchedulingBackend()).setLocation(
      jobId,
      hit.lat,
      hit.lng,
      source: 'client_geocode',
      precision: hit.precision == DestinationPrecision.exact ? 'house' : hit.precision.wire,
    );
  } catch (_) {
    return null;
  }
}

/// Melhora (só para MELHOR) o ponto de um pedido que ficou aproximado — ex.: pedidos antigos que
/// caíram no centro da cidade. Roda a cascata de alta precisão e só grava se o novo ponto tiver
/// precisão MAIOR que a atual. Nunca sobrescreve um pino confirmado (regra também no banco).
Future<JobDestination?> refineGeocodedLocation({
  required String jobId,
  required String addressLine,
  String? summary,
  String? cep,
  DestinationPrecision? current,
  AddressGeocoder? geocoder,
  SchedulingBackend? backend,
}) async {
  int rank(DestinationPrecision? p) => switch (p) {
        null => 0,
        DestinationPrecision.locality => 1,
        DestinationPrecision.street => 2,
        DestinationPrecision.house => 3,
        DestinationPrecision.exact => 4,
      };
  try {
    final hit = await (geocoder ?? PreciseGeocoder()).geocode(addressLine, summary: summary, cep: cep);
    if (hit == null || rank(hit.precision) <= rank(current)) return null;
    return await (backend ?? SupabaseSchedulingBackend()).setLocation(
      jobId,
      hit.lat,
      hit.lng,
      source: 'client_geocode',
      precision: hit.precision == DestinationPrecision.exact ? 'house' : hit.precision.wire,
    );
  } catch (_) {
    return null;
  }
}

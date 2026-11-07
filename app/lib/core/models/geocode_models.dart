/// Geocodificação de endereço (Nominatim/OSM) em Dart puro: montagem das consultas e parse.
///
/// O app do CLIENTE geocodifica no próprio celular (o Nominatim público bloqueia IPs de
/// datacenter, então não dá para fazer no servidor) e registra o ponto com a qualidade
/// (`house`/`street`/`locality`) via `set_job_location`. A qualidade define o raio do geofence.
library;

import 'scheduling_models.dart';

/// Partes do endereço "Rua X, 203 - Bairro, Cidade - MG".
class AddressParts {
  const AddressParts({required this.street, required this.number, required this.hood, required this.city, required this.uf});
  final String street;
  final String number;
  final String hood;
  final String city;
  final String uf;
}

AddressParts parseAddressLine(String line, {String? summary}) {
  final cleanLine = line.split('|').first.trim();
  final cleanSummary = summary?.split('|').first.trim();
  final parts = cleanLine.split(' - ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  final first = parts.isNotEmpty ? parts.first : cleanLine;
  final streetBits = first.split(',').map((s) => s.trim()).toList();
  final street = streetBits.first;
  final number = RegExp(r'\d+').firstMatch(streetBits.length > 1 ? streetBits[1] : '')?.group(0) ?? '';

  var hood = '';
  var city = '';
  var uf = '';

  bool isUfToken(String s) => RegExp(r'^[A-Za-z]{2}$').hasMatch(s.trim());

  if (parts.length >= 4) {
    // Formato 4 blocos: "Rua X, 203 - Bairro - Cidade - MG"
    hood = parts[1];
    city = parts[2];
    uf = parts[3].toUpperCase();
  } else if (parts.length == 3) {
    // Formato 3 blocos: "Rua X, 203 - Bairro, Cidade - MG" ou "Rua X, 203 - Cidade - MG"
    final placeBits = parts[1].split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (placeBits.length > 1) {
      hood = placeBits.first;
      city = placeBits.last;
    } else {
      city = placeBits.isNotEmpty ? placeBits.first : '';
    }
    uf = parts[2].toUpperCase();
  } else if (parts.length == 2) {
    if (isUfToken(parts[1])) {
      uf = parts[1].toUpperCase();
      if (streetBits.length >= 2 && number.isEmpty) {
        return AddressParts(
          street: '',
          number: '',
          hood: streetBits.first,
          city: streetBits.last,
          uf: uf,
        );
      } else if (streetBits.length == 1) {
        return AddressParts(street: '', number: '', hood: '', city: streetBits.first, uf: uf);
      } else if (streetBits.length >= 3) {
        hood = streetBits.length >= 4 ? streetBits[2] : '';
        city = streetBits.last;
      }
    } else {
      final placeBits = parts[1].split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (placeBits.length > 1) {
        hood = placeBits.first;
        city = placeBits.last;
      } else if (cleanSummary != null && cleanSummary.isNotEmpty) {
        hood = placeBits.firstOrNull ?? '';
      } else {
        city = placeBits.firstOrNull ?? '';
      }
    }
  }

  if ((city.isEmpty || uf.isEmpty) && cleanSummary != null && cleanSummary.isNotEmpty) {
    // Usa o resumo público ("Bairro, Cidade - UF", "Cidade - UF" ou "Cidade, UF") para completar cidade/UF.
    final s = cleanSummary.split(' - ').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    if (s.isNotEmpty) {
      if (s.length >= 3 && isUfToken(s.last)) {
        if (hood.isEmpty) hood = s[s.length - 3];
        if (city.isEmpty) city = s[s.length - 2];
        if (uf.isEmpty) uf = s.last.toUpperCase();
      } else {
        final place = s.first;
        if (uf.isEmpty && s.length > 1) uf = s.last.toUpperCase();
        final placeBits = place.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
        if (s.length == 1 && placeBits.length >= 2 && isUfToken(placeBits.last)) {
          if (uf.isEmpty) uf = placeBits.last.toUpperCase();
          if (city.isEmpty) city = placeBits[placeBits.length - 2];
          if (hood.isEmpty && placeBits.length >= 3) hood = placeBits.first;
        } else {
          if (city.isEmpty) {
            city = placeBits.length > 1 ? placeBits.last : (placeBits.isNotEmpty ? placeBits.first : '');
          }
          if (hood.isEmpty && placeBits.length > 1) {
            hood = placeBits.first;
          }
        }
      }
    }
  }
  return AddressParts(street: street, number: number, hood: hood, city: city, uf: uf);
}

/// Consultas do mais específico (rua + número) ao menos (só a cidade), sem repetição.
List<String> buildGeocodeQueries(AddressParts a) {
  final tail = [a.city, a.uf, 'Brasil'].where((s) => s.isNotEmpty).join(', ');
  final hood = a.hood.isEmpty ? '' : '${a.hood}, ';
  final out = <String>[
    if (a.street.isNotEmpty && a.number.isNotEmpty) '${a.street} ${a.number}, $hood$tail',
    if (a.street.isNotEmpty) '${a.street}, $hood$tail',
    if (a.hood.isNotEmpty && a.city.isNotEmpty) '${a.hood}, $tail',
    if (a.city.isNotEmpty) tail,
  ];
  final seen = <String>{};
  return [for (final q in out) if (q.trim().isNotEmpty && seen.add(q)) q];
}

class GeocodeHit {
  const GeocodeHit({required this.lat, required this.lng, required this.precision, this.display = ''});
  final double lat;
  final double lng;
  final DestinationPrecision precision;
  final String display;
}

/// Resposta do Nominatim `/search?format=jsonv2&addressdetails=1&limit=1`.
GeocodeHit? parseNominatimSearch(Object? body) {
  if (body is! List || body.isEmpty || body.first is! Map) return null;
  final r = (body.first as Map).cast<String, dynamic>();
  final lat = double.tryParse('${r['lat'] ?? ''}');
  final lng = double.tryParse('${r['lon'] ?? ''}');
  if (lat == null || lng == null) return null;
  final addr = (r['address'] as Map?)?.cast<String, dynamic>() ?? const {};
  final type = '${r['addresstype'] ?? ''}';
  DestinationPrecision p;
  if (addr['house_number'] != null) {
    p = DestinationPrecision.house;
  } else if (r['class'] == 'highway' || const ['road', 'residential', 'pedestrian', 'footway', 'path', 'street'].contains(type)) {
    p = DestinationPrecision.street;
  } else {
    p = DestinationPrecision.locality;
  }
  return GeocodeHit(lat: lat, lng: lng, precision: p, display: '${r['display_name'] ?? ''}');
}

/// Geocodificador de endereço (Nominatim, cascata de alta precisão…). Interface para injetar fakes.
abstract class AddressGeocoder {
  /// [cep] (opcional) melhora a precisão: dá o ponto da rua mesmo quando o OSM não tem o número.
  Future<GeocodeHit?> geocode(String addressLine, {String? summary, String? cep});
}

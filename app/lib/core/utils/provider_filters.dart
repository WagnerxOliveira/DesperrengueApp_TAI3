/// Filtros puros da busca de profissionais: raio (Haversine), cold-start e categoria.
library;

import '../models/marketplace_models.dart';
import 'geo.dart';
import 'tag_normalizer.dart';

/// Degraus do seletor de raio (barra de arrastar), em km. O último (`null`) é "Toda a região".
/// Mais finos perto de casa (onde a diferença importa) e mais largos até 100 km.
const List<int?> kRadiusSteps = [1, 2, 3, 5, 7, 10, 15, 20, 25, 30, 40, 50, 75, 100, null];

/// Índice do degrau "Toda a região" (padrão: nunca gera falso vazio).
final int kRadiusAllIndex = kRadiusSteps.length - 1;

/// "5 km" / "Toda a região".
String radiusLabel(int? km) => km == null ? 'Toda a região' : '$km km';

/// Nome da categoria do app que corresponde a um termo digitado (aceita sinônimo:
/// "eletricista" → "Elétrica", "hidráulica" → "Encanador"). Null se não for categoria.
String? categoryNameForTerm(String? term) {
  final slug = canonicalTag(term);
  if (slug.isEmpty) return null;
  for (final c in kCategories) {
    if (canonicalTag(c.name) == slug) return c.name;
  }
  return null;
}

/// Isolamento estrito: só sobrevivem profissionais com a tag da [category]
/// (qualquer uma de N tags). Um único `Set` lookup por profissional.
List<ProviderCard> filterByCategory(Iterable<ProviderCard> providers, String? category) {
  final slug = canonicalTag(category);
  if (slug.isEmpty) return providers.toList();
  return [
    for (final p in providers)
      if (p.slugs.contains(slug)) p,
  ];
}

/// Aplica o raio a partir da posição do cliente.
///
///  * "Toda a região": nunca filtra (profissional novo sem GPS também aparece).
///  * Cliente sem coordenadas: não há como medir → não filtra (nunca falso vazio).
///  * Profissional com GPS: entra se `haversine ≤ raio` (distância fica em `distanceKm`).
///  * Profissional SEM GPS (cadastro recente): fallback pela cidade — entra se for a
///    mesma cidade do cliente; sem cidade conhecida de nenhum dos lados, entra também.
List<ProviderCard> applyRadius(
  List<ProviderCard> providers, {
  required double? clientLat,
  required double? clientLng,
  required int? radiusKm,
  String? clientCity,
}) {
  final hasClientPos = clientLat != null && clientLng != null;
  final cityKey = _cityKey(clientCity);
  final out = <ProviderCard>[];
  for (final p in providers) {
    final hasPos = p.latitude != null && p.longitude != null;
    final km = (hasClientPos && hasPos) ? haversineMeters(clientLat, clientLng, p.latitude!, p.longitude!) / 1000.0 : null;
    final withDist = km == null ? p : p.withDistance(km);
    if (radiusKm == null || !hasClientPos) {
      out.add(withDist);
      continue;
    }
    if (km != null) {
      if (km <= radiusKm) out.add(withDist);
      continue;
    }
    // Sem coordenadas do profissional: fallback para a cidade/região padrão.
    final pCity = _cityKey(p.city);
    if (cityKey.isEmpty || pCity.isEmpty || cityKey == pCity) out.add(withDist);
  }
  return out;
}

/// "São Paulo - SP" / "Sao Paulo" → `sao paulo` (cidade sem UF, normalizada).
String _cityKey(String? city) {
  if (city == null) return '';
  final first = city.split(RegExp(r'\s+-\s+|,')).first;
  return normalizeTag(first);
}

/// Cold-start: profissional verificado e ativo, ainda sem nenhum serviço concluído.
bool isNewOnPlatform(ProviderCard p) => p.jobsDone == 0;

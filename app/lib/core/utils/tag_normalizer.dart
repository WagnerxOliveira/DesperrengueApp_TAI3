/// Normalização canônica de tags/categorias de serviço (Dart puro, testável).
///
/// Problema que resolve: o profissional grava `specialties` como texto livre/rotulado
/// ("Encanador", "encanador", "Hidráulica") e o cliente escolhe a categoria "Encanador".
/// Comparar strings cruas (e com diferença de caixa/acento) gerava o falso vazio
/// "Nenhum profissional encontrado".
///
/// Estratégia: toda tag vira um **slug canônico** (sem acento, minúsculo, sem espaços
/// extras, sinônimos mapeados). O match é um lookup `Set<String>.contains` — O(1) por
/// verificação depois que o conjunto do profissional foi montado (O(k), k = nº de tags,
/// pequeno e limitado).
///
/// ATENÇÃO: a função SQL `public.norm_tag` (migration `20261106120000_category_match_*`)
/// espelha estas regras. Ao mudar [kTagAliases], atualize as duas pontas.
library;

/// Mapa sinônimo → slug canônico. Chaves já normalizadas (sem acento/minúsculas).
/// O slug canônico de cada categoria do app é `normalizeTag(nome)`; sinônimos de profissões
/// ("eletricista", "pintor"…) apontam para ele. Espelhado em `public.norm_tag` (SQL): o teste
/// `tag_alias_parity_test.dart` falha se as duas pontas divergirem.
const Map<String, String> kTagAliases = {
  // Elétrica
  'eletrica': 'eletrica',
  'eletricista': 'eletrica',
  'eletricidade': 'eletrica',
  'instalacao eletrica': 'eletrica',
  'instalacoes eletricas': 'eletrica',
  // Encanador
  'encanador': 'encanador',
  'encanamento': 'encanador',
  'hidraulica': 'encanador',
  'hidraulico': 'encanador',
  'bombeiro hidraulico': 'encanador',
  // Limpeza
  'limpeza': 'limpeza',
  'diarista': 'limpeza',
  'faxina': 'limpeza',
  'faxineira': 'limpeza',
  'faxineiro': 'limpeza',
  // Montagem
  'montagem': 'montagem',
  'montador': 'montagem',
  'montagem de moveis': 'montagem',
  'montador de moveis': 'montagem',
  // Pintura
  'pintura': 'pintura',
  'pintor': 'pintura',
  // Chaveiro
  'chaveiro': 'chaveiro',
  'chaveiros': 'chaveiro',
  // Pedreiro
  'pedreiro': 'pedreiro',
  'alvenaria': 'pedreiro',
  // Gesso
  'gesso': 'gesso',
  'gesseiro': 'gesso',
  'drywall': 'gesso',
  // Marcenaria
  'marcenaria': 'marcenaria',
  'marceneiro': 'marcenaria',
  'carpintaria': 'marcenaria',
  'carpinteiro': 'marcenaria',
  // Ar-condicionado
  'ar condicionado': 'ar-condicionado',
  'arcondicionado': 'ar-condicionado',
  'climatizacao': 'ar-condicionado',
  'refrigeracao': 'ar-condicionado',
  'split': 'ar-condicionado',
  // Pequenos Reparos
  'marido de aluguel': 'pequenos reparos',
  'faz tudo': 'pequenos reparos',
  'reparos': 'pequenos reparos',
  // Jardinagem
  'jardineiro': 'jardinagem',
  'paisagismo': 'jardinagem',
  'paisagista': 'jardinagem',
  // Dedetização
  'dedetizador': 'dedetizacao',
  'controle de pragas': 'dedetizacao',
  'desinsetizacao': 'dedetizacao',
  // Vidraceiro
  'vidracaria': 'vidraceiro',
  'vidros': 'vidraceiro',
  // Serralheria
  'serralheiro': 'serralheria',
  'soldador': 'serralheria',
  // Telhados e Calhas
  'telhadista': 'telhados e calhas',
  'telhado': 'telhados e calhas',
  'calheiro': 'telhados e calhas',
  'calhas': 'telhados e calhas',
  // Impermeabilização
  'impermeabilizador': 'impermeabilizacao',
  // Desentupidora
  'desentupidor': 'desentupidora',
  'desentupimento': 'desentupidora',
  // Piscina
  'piscineiro': 'piscina',
  // Eletrodomésticos
  'assistencia tecnica': 'eletrodomesticos',
  'conserto de geladeira': 'eletrodomesticos',
  'tecnico de eletrodomesticos': 'eletrodomesticos',
  // TV e Antenas
  'antenista': 'tv e antenas',
  'instalacao de tv': 'tv e antenas',
  // Câmeras e Alarmes
  'cftv': 'cameras e alarmes',
  'alarme': 'cameras e alarmes',
  'alarmes': 'cameras e alarmes',
  'cameras': 'cameras e alarmes',
  'seguranca eletronica': 'cameras e alarmes',
  // Portões e Interfones
  'portao eletronico': 'portoes e interfones',
  'interfone': 'portoes e interfones',
  'automacao de portoes': 'portoes e interfones',
  // Energia Solar
  'placa solar': 'energia solar',
  'painel solar': 'energia solar',
  'fotovoltaica': 'energia solar',
  // Gás e Aquecedores
  'gas': 'gas e aquecedores',
  'aquecedor': 'gas e aquecedores',
  'instalador de gas': 'gas e aquecedores',
  // Pisos e Revestimentos
  'azulejista': 'pisos e revestimentos',
  'ladrilheiro': 'pisos e revestimentos',
  'pisos': 'pisos e revestimentos',
  'revestimentos': 'pisos e revestimentos',
  // Cortinas e Persianas
  'cortina': 'cortinas e persianas',
  'persiana': 'cortinas e persianas',
  // Estofados e Tapetes
  'limpeza de estofados': 'estofados e tapetes',
  'lavagem de sofa': 'estofados e tapetes',
  'tapeceiro': 'estofados e tapetes',
  // Mudanças e Fretes
  'mudanca': 'mudancas e fretes',
  'frete': 'mudancas e fretes',
  'fretes': 'mudancas e fretes',
  'carreto': 'mudancas e fretes',
  // Informática e Redes
  'informatica': 'informatica e redes',
  'tecnico de informatica': 'informatica e redes',
  'wifi': 'informatica e redes',
  'redes': 'informatica e redes',
  // Cuidador de Idosos
  'cuidador': 'cuidador de idosos',
  'cuidadora': 'cuidador de idosos',
  // Babá
  'nanny': 'baba',
  // Pet Care
  'pet sitter': 'pet care',
  'banho e tosa': 'pet care',
  'passeador de caes': 'pet care',
};
const Map<String, String> _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

final RegExp _spaces = RegExp(r'\s+');

/// Remove acentos, converte para minúsculas, faz trim e colapsa espaços.
/// `"  ENCANADOR  "` → `"encanador"`, `"Elétrica"` → `"eletrica"`.
String normalizeTag(String? raw) {
  if (raw == null) return '';
  final lower = raw.trim().toLowerCase();
  if (lower.isEmpty) return '';
  final b = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    b.write(_accents[ch] ?? ch);
  }
  return b.toString().replaceAll(_spaces, ' ').trim();
}

/// Slug canônico: normaliza e resolve sinônimos (`hidraulica` → `encanador`).
/// Tags desconhecidas continuam válidas (o slug é só a forma normalizada).
String canonicalTag(String? raw) {
  final n = normalizeTag(raw);
  if (n.isEmpty) return '';
  return kTagAliases[n] ?? n;
}

/// Conjunto de slugs canônicos (descarta vazios). Lookup posterior é O(1).
Set<String> canonicalTagSet(Iterable<String> tags) {
  final out = <String>{};
  for (final t in tags) {
    final c = canonicalTag(t);
    if (c.isNotEmpty) out.add(c);
  }
  return out;
}

/// `true` se alguma das [tags] do profissional corresponde à [category] escolhida.
/// Use [canonicalTagSet] uma vez por profissional quando for testar várias categorias.
bool tagsMatchCategory(Iterable<String> tags, String? category) {
  final slug = canonicalTag(category);
  if (slug.isEmpty) return false;
  return canonicalTagSet(tags).contains(slug);
}

/// Variante O(1) quando o conjunto já foi pré-computado.
bool slugSetMatchesCategory(Set<String> slugs, String? category) {
  final slug = canonicalTag(category);
  return slug.isNotEmpty && slugs.contains(slug);
}

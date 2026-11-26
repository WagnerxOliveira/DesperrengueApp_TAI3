/// Formatação humana de nomes de pessoas (pt-BR). Dart puro: testável sem Flutter.
///
/// Resolve os casos reais de nome "feio" na interface:
///  * tudo colado: `WAGNEROLIVEIRA`, `wagneroliveira`, `WagnerOliveira`
///    -> `Wagner Oliveira`;
///  * tudo em MAIÚSCULAS (nome vindo do documento/OCR): `WAGNER OLIVEIRA CLAUDIANO`
///    -> `Wagner Oliveira Claudiano`;
///  * conectivos em minúsculas (`Maria da Silva`, `José dos Santos`);
///  * nomes compostos com hífen/apóstrofo (`Ana-Clara`, `D'Ávila`).
///
/// Nomes já bem escritos (caixa mista) são preservados exatamente como estão.
library;

class PersonNameFormatter {
  const PersonNameFormatter._();

  static const Set<String> _connectives = <String>{
    'de',
    'da',
    'do',
    'das',
    'dos',
    'e',
  };

  /// Sobrenomes brasileiros comuns (minúsculos, sem acento) usados para separar
  /// nomes digitados/gerados sem espaço.
  static const List<String> _commonSurnames = <String>[
    'oliveira', 'silva', 'santos', 'souza', 'sousa', 'pereira', 'costa',
    'ferreira', 'almeida', 'nascimento', 'lima', 'araujo', 'fernandes',
    'carvalho', 'gomes', 'martins', 'rocha', 'ribeiro', 'alves', 'monteiro',
    'mendes', 'barros', 'freitas', 'barbosa', 'pinto', 'moura', 'cavalcanti',
    'dias', 'castro', 'campos', 'cardoso', 'teixeira', 'correia', 'moreira',
    'vieira', 'marques', 'machado', 'lopes', 'ramos', 'melo', 'nunes',
    'rodrigues', 'goncalves', 'batista', 'pacheco', 'andrade', 'nogueira',
    'miranda', 'azevedo', 'medeiros', 'siqueira', 'borges', 'coelho',
    'duarte', 'tavares', 'farias', 'bezerra', 'cunha', 'peixoto', 'amaral',
    'claudiano', 'henrique', 'franco', 'guedes', 'sampaio', 'xavier',
  ];

  static final List<String> _surnamesLongestFirst = (<String>[..._commonSurnames]
    ..sort((a, b) => b.length.compareTo(a.length)));

  static final RegExp _letters = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ]+$");
  static final RegExp _camelBoundary = RegExp(r'(?<=[a-zà-ÿ])(?=[A-ZÀ-Þ])');

  /// Menor tamanho de token que ainda tentamos separar (evita "cortar" nomes
  /// curtos legítimos como "Marina" ou "Joana").
  static const int _minGluedLength = 8;

  /// Nome pronto para exibir: separa palavras coladas e corrige a caixa.
  /// Devolve string vazia se [raw] for vazio.
  static String humanize(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return '';

    final tokens = <String>[
      for (final token in cleaned.split(' ')) ..._splitGlued(token),
    ];

    final lettersOnly = cleaned.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
    final needsCaseFix = lettersOnly == lettersOnly.toUpperCase() ||
        lettersOnly == lettersOnly.toLowerCase();

    final out = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      out.add(needsCaseFix ? _titleToken(tokens[i], isFirst: i == 0) : tokens[i]);
    }
    return out.join(' ');
  }

  /// Primeiro nome bem formatado (`Wagner`), ou vazio se não houver nome.
  static String firstName(String raw) {
    final full = humanize(raw);
    if (full.isEmpty) return '';
    return full.split(' ').first;
  }

  /// Nome humano a partir da parte local de um e-mail
  /// (`wagneroliveira9819@gmail.com` -> `Wagner Oliveira`). Null se não der.
  static String? fromEmail(String rawEmail) {
    final trimmed = rawEmail.trim();
    if (!trimmed.contains('@')) return null;
    final local = trimmed.split('@').first.replaceAll(RegExp(r'[0-9]+'), '');
    final parts = local
        .split(RegExp(r'[._\-]+'))
        .map((e) => e.replaceAll(RegExp(r'[^a-zA-ZÀ-ÿ]'), '').trim())
        .where((e) => e.length >= 2)
        .toList();
    if (parts.isEmpty) return null;
    if (parts.length >= 2) {
      return parts.map((p) => _capitalize(p)).join(' ');
    }
    final single = parts.first.toLowerCase();
    if (single.length < 3) return null;
    return _splitByKnownSurnames(parts.first).map(_capitalize).join(' ');
  }

  // ------------------------------------------------------------------ interno

  static List<String> _splitGlued(String token) {
    if (!_letters.hasMatch(token)) return <String>[token];

    // CamelCase: "WagnerOliveira" -> [Wagner, Oliveira]. Só separa quando todas as
    // partes têm >= 3 letras (preserva "McDonald", "DiCaprio", "DeSouza").
    final camel = token.split(_camelBoundary);
    if (camel.length > 1 && camel.every((p) => p.length >= 3)) return camel;

    if (token.length < _minGluedLength) return <String>[token];
    return _splitByKnownSurnames(token);
  }

  /// Separa `wagneroliveira` em `[wagner, oliveira]` pelo maior sobrenome
  /// conhecido no final do token. Preserva acentos/caixa originais.
  static List<String> _splitByKnownSurnames(String token) {
    final key = _asciiKey(token);
    for (final surname in _surnamesLongestFirst) {
      if (key.length - surname.length >= 3 && key.endsWith(surname)) {
        final cut = token.length - surname.length;
        return <String>[
          ..._splitByKnownSurnames(token.substring(0, cut)),
          token.substring(cut),
        ];
      }
    }
    return <String>[token];
  }

  /// Minúsculo e sem acento, MANTENDO o mesmo comprimento (índices 1:1).
  static String _asciiKey(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final sb = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final idx = from.indexOf(ch);
      sb.write(idx >= 0 ? to[idx] : ch);
    }
    return sb.toString();
  }

  static String _capitalize(String w) {
    if (w.isEmpty) return w;
    return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
  }

  static String _titleToken(String token, {required bool isFirst}) {
    final lower = token.toLowerCase();
    if (!isFirst && _connectives.contains(lower)) return lower;
    return lower.splitMapJoin(
      RegExp(r"[-'’]"),
      onMatch: (m) => m[0]!,
      onNonMatch: _capitalize,
    );
  }
}

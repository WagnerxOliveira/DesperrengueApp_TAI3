/// Defesa em profundidade (LGPD) para textos de endereço que podem chegar ao
/// profissional/portfólio público: reduz qualquer resumo de endereço a **área
/// grossa** (bairro + cidade/UF), removendo rua, número, complemento, bloco,
/// apartamento, CEP e referências.
///
/// Segunda camada: a primeira é o servidor (`address_summary` já deve vir sem
/// rua) e o `GeoPrivacyPolicyEngine`. Este filtro cobre dado legado/mal
/// formatado (ex.: `Rua das Flores, 123 - Apto 402 - Centro - Poços de Caldas - MG`).
///
/// Dart puro (sem Flutter), seguro em isolates/Web.
library;

class AddressPrivacy {
  const AddressPrivacy._();

  static final RegExp _streetPrefix = RegExp(
    r'^(rua|r\.|avenida|av\.?|travessa|tv\.?|alameda|al\.?|estrada|est\.?|rodovia|rod\.?|pra[cç]a|p[cç]a\.?|largo|beco|viela|via|quadra|qd\.?|lote|lt\.?|bloco|bl\.?|apto?\.?|apartamento|casa|sala|conjunto|cj\.?|fundos|esquina|pr[oó]ximo|perto|ao lado|em frente|refer[eê]ncia|cep)\b',
    caseSensitive: false,
  );
  static final RegExp _hasDigit = RegExp(r'\d');
  static final RegExp _separators = RegExp(r'\s+[-–—•|/]\s+|\s*[,;]\s*|\n');
  static final RegExp _uf = RegExp(r'^[A-Za-z]{2}$');

  /// `true` se [segment] parece parte sensível (rua/número/complemento/CEP).
  static bool _isSensitive(String segment) {
    final s = segment.trim();
    if (s.isEmpty) return true;
    if (_streetPrefix.hasMatch(s)) return true;
    if (_hasDigit.hasMatch(s)) return true; // número, CEP, apto, "km 12"
    return false;
  }

  /// Mantém só bairro/cidade/UF. Se nada sobrar, devolve [fallback].
  ///
  /// Exemplos:
  ///  * `Rua das Flores, 123 - Centro - Poços de Caldas - MG` → `Centro - Poços de Caldas - MG`
  ///  * `Country Club • Poços de Caldas - MG` → `Country Club • Poços de Caldas - MG`
  ///  * `Av. Brasil, 1450 — Centro` → `Centro`
  static String coarseArea(String? raw, {String fallback = 'Local protegido'}) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return fallback;
    final parts = text
        .split(_separators)
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final safe = <String>[];
    for (final p in parts) {
      if (_isSensitive(p)) continue;
      safe.add(p);
    }
    if (safe.isEmpty) return fallback;
    // Nada sensível encontrado e já é curto (≤3 trechos): preserva o formato original.
    if (safe.length == parts.length && parts.length <= 3) return text;
    // Mantém no máximo bairro, cidade e UF (os 3 últimos trechos seguros).
    final tail = safe.length > 3 ? safe.sublist(safe.length - 3) : safe;
    final hasUf = tail.isNotEmpty && _uf.hasMatch(tail.last);
    if (hasUf && tail.length >= 2) {
      final head = tail.sublist(0, tail.length - 1).join(' - ');
      return '$head - ${tail.last.toUpperCase()}';
    }
    return tail.join(' - ');
  }
}

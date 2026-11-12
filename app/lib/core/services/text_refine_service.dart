import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/address_privacy.dart';
import '../utils/tag_normalizer.dart' show normalizeTag;

/// Refina um texto já estruturado (acentos, maiúsculas, pontuação). Nunca lança: se algo
/// falhar devolve o texto original.
abstract class TextRefiner {
  Future<String> refine(String text);
}

/// Revisor ortográfico/gramatical gratuito **LanguageTool** (API pública, sem chave) para pt-BR.
///
/// O texto vem do ditado por voz — o reconhecimento costuma entregar tudo sem acento e sem
/// maiúsculas ("tambem", "nao"). Aplicamos APENAS correções "cosméticas" seguras: o conjunto de
/// letras da palavra não muda (só caixa, acento ou pontuação). Nenhuma sugestão que troque uma
/// palavra por outra é aplicada, então o sentido do relato nunca é alterado.
///
/// Privacidade: só o texto do relato é enviado, e só depois que o cliente para a gravação.
/// E-mails, números (CPF/telefone/CEP/nº) e "Rua ..." são mascarados com `#` (mesmo comprimento)
/// antes de sair do aparelho ([AddressPrivacy.maskForThirdParty]). Falha de rede/limite → o texto local (já formatado) é mantido.
class LanguageToolRefiner implements TextRefiner {
  LanguageToolRefiner({http.Client? client, this.timeout = const Duration(seconds: 6), Uri? endpoint})
      : _client = client ?? http.Client(),
        _endpoint = endpoint ?? Uri.https('api.languagetool.org', '/v2/check');

  final http.Client _client;
  final Duration timeout;
  final Uri _endpoint;

  /// Limite de segurança do plano gratuito (20 mil caracteres/requisição).
  static const int maxChars = 3000;

  @override
  Future<String> refine(String text) async {
    final input = text.trim();
    if (input.length < 3 || input.length > maxChars) return text;
    try {
      final res = await _client.post(_endpoint, body: {'language': 'pt-BR', 'text': AddressPrivacy.maskForThirdParty(input)}).timeout(timeout);
      if (res.statusCode != 200) return text;
      final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final matches = (json['matches'] as List?)?.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() ?? const [];
      return applyMatches(input, matches);
    } catch (_) {
      return text;
    }
  }

  /// Aplica as correções seguras de [matches] (formato da API) ao [text]. Pura e testável.
  static String applyMatches(String text, List<Map<String, dynamic>> matches) {
    final edits = <({int start, int end, String value})>[];
    for (final m in matches) {
      final offset = (m['offset'] as num?)?.toInt();
      final length = (m['length'] as num?)?.toInt();
      if (offset == null || length == null || offset < 0 || length <= 0 || offset + length > text.length) continue;
      final category = ((m['rule'] as Map?)?['category'] as Map?)?['id'] as String? ?? '';
      if (!const {'CASING', 'TYPOS', 'PUNCTUATION', 'TYPOGRAPHY'}.contains(category)) continue;
      final reps = (m['replacements'] as List?)?.whereType<Map>().map((r) => '${r['value']}').toList() ?? const <String>[];
      if (reps.isEmpty) continue;
      final original = text.substring(offset, offset + length);
      // Primeira sugestão que só muda caixa, acento ou pontuação; qualquer outra é ignorada.
      final safe = reps.where((r) => _sameLetters(original, r) && r != original).toList();
      if (safe.isEmpty) continue;
      edits.add((start: offset, end: offset + length, value: safe.first));
    }
    edits.sort((a, b) => b.start.compareTo(a.start));
    var out = text;
    var limit = text.length + 1;
    for (final e in edits) {
      if (e.end > limit) continue; // sobreposição: mantém a primeira (maior offset)
      out = out.replaceRange(e.start, e.end, e.value);
      limit = e.start;
    }
    return out;
  }

  /// Mesmas letras, ignorando caixa, acento e pontuação/espaços.
  static bool _sameLetters(String a, String b) => _letters(a) == _letters(b);

  static String _letters(String s) => normalizeTag(s).replaceAll(RegExp(r'[^a-z0-9]'), '');
}

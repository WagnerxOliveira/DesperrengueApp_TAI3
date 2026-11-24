import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/address_privacy.dart';
import '../utils/structured_voice_brief.dart';
import '../utils/tag_normalizer.dart' show normalizeTag;

/// Refina um texto já estruturado (acentos, maiúsculas, pontuação). Nunca lança: se algo
/// falhar devolve o texto original.
abstract class TextRefiner {
  Future<String> refine(String text);
}

typedef RemoteVoiceStructurer = Future<StructuredVoiceBrief?> Function(
  String transcript, {
  String? categoryHint,
  List<String> photoNotes,
});

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

/// Refinador e estruturador gratuito em 3 camadas:
///  1. IA gratuita na nuvem (`voice-triage-structurer`: Groq / Gemini Free / OpenRouter Free);
///  2. Corretor ortográfico gratuito LanguageTool (`pt-BR`, sem chave);
///  3. Motor semântico local `StructuredVoiceBriefEngine` (determinístico e offline).
class StructuredVoiceRefiner implements TextRefiner {
  StructuredVoiceRefiner({
    TextRefiner? grammarRefiner,
    this.remoteStructurer,
    this.categoryProvider,
    this.photoNotesProvider,
    this.onBriefReady,
    this.maxLength = 900,
    this.remoteTimeout = const Duration(seconds: 6),
  }) : _grammarRefiner =
            grammarRefiner ??
            LanguageToolRefiner(timeout: const Duration(milliseconds: 3500));

  final TextRefiner _grammarRefiner;
  final RemoteVoiceStructurer? remoteStructurer;
  final String? Function()? categoryProvider;
  final List<String> Function()? photoNotesProvider;
  final ValueChanged<StructuredVoiceBrief>? onBriefReady;
  final int maxLength;
  final Duration remoteTimeout;

  @override
  Future<String> refine(String text) async {
    final raw = text.trim();
    if (raw.length < 4) return text;
    final repaired = StructuredVoiceBriefEngine.repairTechnicalSpeech(raw);
    final categoryHint = categoryProvider?.call();
    final photoNotes = photoNotesProvider?.call() ?? const <String>[];

    // 1. Camada remota gratuita (Edge Function multi-provedor Groq/Gemini/OpenRouter)
    try {
      final structurer = remoteStructurer ?? _defaultRemoteStructurer;
      final remote = await structurer(
        _maskPiiPreservingTechnicalSpecs(repaired),
        categoryHint: categoryHint,
        photoNotes: photoNotes,
      ).timeout(remoteTimeout);

      if (remote != null && remote.problemSummary.trim().isNotEmpty) {
        onBriefReady?.call(remote);
        return remote.toStructuredText(maxLength: maxLength);
      }
    } catch (_) {
      // Fallback transparente para camada gratuita local + LanguageTool.
    }

    // 2. Camada gratuita LanguageTool (acentos/pontuação sem chave)
    var polished = repaired;
    try {
      polished = await _grammarRefiner.refine(repaired);
    } catch (_) {
      polished = repaired;
    }

    // 3. Estruturação semântica determinística local
    final localBrief = StructuredVoiceBriefEngine.structureLocally(
      polished,
      currentCategory: categoryHint,
    );
    if (localBrief.problemSummary.trim().isEmpty) return polished;
    onBriefReady?.call(localBrief);
    return localBrief.toStructuredText(maxLength: maxLength);
  }

  static Future<StructuredVoiceBrief?> _defaultRemoteStructurer(
    String transcript, {
    String? categoryHint,
    List<String> photoNotes = const [],
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return null;
    final res = await Supabase.instance.client.functions.invoke(
      'voice-triage-structurer',
      body: <String, dynamic>{
        'transcript': transcript,
        if (categoryHint != null && categoryHint.trim().isNotEmpty)
          'category_hint': categoryHint.trim(),
        if (photoNotes.isNotEmpty) 'photo_notes': photoNotes,
      },
    );
    if (res.status < 200 || res.status >= 300 || res.data is! Map) {
      return null;
    }
    final data = Map<String, dynamic>.from(res.data as Map);
    final structured = data['structured'];
    if (structured is! Map) return null;
    final provider = (data['provider'] as String?) ?? 'ai_groq';
    return StructuredVoiceBrief.fromAiJson(
      Map<String, dynamic>.from(structured),
      rawTranscript: transcript,
      source: provider,
    );
  }

  /// Mascara e-mails/ruas/números longos (CPF/telefone), mas preserva medidas
  /// técnicas de 2–5 dígitos seguidas de unidade (110V, 220V, 32A, 9000 BTUs).
  static String _maskPiiPreservingTechnicalSpecs(String input) {
    final protected = <String, String>{};
    var idx = 0;
    final withTokens = input.replaceAllMapped(
      RegExp(
        r'\b\d{2,5}\s*(?:V|A|W|BTUs?|mm|cm|m)\b',
        caseSensitive: false,
      ),
      (m) {
        final token = '__SPEC_${idx++}__';
        protected[token] = m.group(0)!;
        return token;
      },
    );
    var masked = AddressPrivacy.maskForThirdParty(withTokens);
    for (final entry in protected.entries) {
      masked = masked.replaceAll(entry.key, entry.value);
    }
    return masked;
  }
}

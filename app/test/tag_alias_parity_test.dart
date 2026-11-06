import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/utils/tag_normalizer.dart';

/// `public.norm_tag` (SQL) e `kTagAliases` (Dart) precisam dar a MESMA resposta: o índice GIN do
/// banco e o filtro local do app dependem disso. Este teste lê a migration e compara as duas pontas.
void main() {
  const migration = '../supabase/migrations/20261107120000_expanded_categories.sql';

  Map<String, String> sqlAliases() {
    final sql = File(migration).readAsStringSync();
    final out = <String, String>{};
    final re = RegExp(r"when\s+n\s+in\s*\(([^)]*)\)\s*then\s*'([^']*)'", multiLine: true);
    for (final m in re.allMatches(sql)) {
      for (final k in RegExp(r"'([^']*)'").allMatches(m.group(1)!)) {
        final key = k.group(1)!;
        expect(out.containsKey(key), isFalse, reason: 'chave repetida no SQL: $key');
        out[key] = m.group(2)!;
      }
    }
    // Atalho `when 'x' then` sem `in` também seria lido por engano como divergência: não existe.
    return out;
  }

  final dartAliases = {for (final e in kTagAliases.entries) if (e.key != e.value) e.key: e.value};

  test('norm_tag (SQL) e kTagAliases (Dart) têm exatamente os mesmos sinônimos', () {
    final sql = sqlAliases();
    expect(sql, isNotEmpty);
    expect(sql.keys.toSet().difference(dartAliases.keys.toSet()), isEmpty, reason: 'sinônimos só no SQL');
    expect(dartAliases.keys.toSet().difference(sql.keys.toSet()), isEmpty, reason: 'sinônimos só no Dart');
    for (final e in dartAliases.entries) {
      expect(sql[e.key], e.value, reason: 'destino diferente para "${e.key}"');
    }
  });

  test('toda chave de sinônimo já está normalizada (sem acento/maiúscula/espaço duplo)', () {
    for (final k in kTagAliases.keys) {
      expect(normalizeTag(k), k, reason: k);
    }
  });

  test('todo destino de sinônimo é o slug de uma categoria do app e é ponto fixo (sem cadeia)', () {
    final slugs = {for (final c in kCategories) normalizeTag(c.name)};
    for (final v in kTagAliases.values) {
      expect(slugs, contains(v), reason: 'destino "$v" não é uma categoria');
      expect(canonicalTag(v), v, reason: 'cadeia de sinônimos em "$v"');
    }
  });

  test('catálogo: 33 categorias únicas e nenhuma "engolida" por sinônimo', () {
    expect(kCategories, hasLength(33));
    final names = kCategories.map((c) => normalizeTag(c.name)).toList();
    expect(names.toSet(), hasLength(names.length));
    for (final c in kCategories) {
      expect(canonicalTag(c.name), normalizeTag(c.name), reason: c.name);
    }
  });

  test('profissões comuns casam com a categoria certa', () {
    const casos = {
      'Eletricista': 'Elétrica',
      'Hidráulica': 'Encanador',
      'Jardineiro': 'Jardinagem',
      'Dedetizador': 'Dedetização',
      'Ar condicionado': 'Ar-condicionado',
      'Nanny': 'Babá',
      'Passeador de cães': 'Pet Care',
      'Painel solar': 'Energia Solar',
      'Marido de aluguel': 'Pequenos Reparos',
    };
    for (final e in casos.entries) {
      expect(tagsMatchCategory([e.key], e.value), isTrue, reason: '${e.key} → ${e.value}');
      expect(tagsMatchCategory([e.key], 'Pintura'), isFalse, reason: '${e.key} não é Pintura');
    }
  });
}

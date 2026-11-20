import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'checks.dart';

/// Ratchet versionado ("só diminui") da galeria.
///
/// Cada suíte tem o seu JSON em `test/ui_design_audit/baseline/<suite>.json`
/// (`{"<regra>|<tela>": <nº de violações distintas>}`). O teste FALHA se a
/// contagem de uma (regra, tela) SUBIR em relação ao baseline (ou se uma tela
/// nova tiver violação sem estar no baseline). Quando DESCE, imprime a dica para
/// baixar o baseline (e falha só com `GALLERY_STRICT_RATCHET=1`).
///
/// Atualizar o baseline (depois de corrigir telas):
/// `GALLERY_UPDATE_BASELINE=1 flutter test test/ui_gallery test/ui_design_audit`
class Ratchet {
  Ratchet(this.suite) : file = File('test/ui_design_audit/baseline/$suite.json') {
    if (file.existsSync()) {
      final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      baseline = raw.map((k, v) => MapEntry(k, (v as num).toInt()));
    }
  }

  final String suite;
  final File file;
  Map<String, int> baseline = <String, int>{};

  /// Contagens medidas nesta execução.
  final Map<String, int> measured = <String, int>{};

  /// Violações detalhadas por chave (para a mensagem de falha).
  final Map<String, List<Violation>> details = <String, List<Violation>>{};

  static bool get updateMode => Platform.environment['GALLERY_UPDATE_BASELINE'] == '1';
  static bool get strict => Platform.environment['GALLERY_STRICT_RATCHET'] == '1';
  static bool get verbose => Platform.environment['GALLERY_VERBOSE'] == '1';

  String key(String rule, String screenId) => '$rule|$screenId';

  /// Registra e verifica [log] de [screenId] para as regras [rules].
  void verify(String screenId, ViolationLog log, Iterable<String> rules) {
    final improved = <String>[];
    final failures = <String>[];
    for (final rule in rules) {
      final list = log.byRule(rule);
      final k = key(rule, screenId);
      measured[k] = list.length;
      details[k] = list;
      final allowed = baseline[k] ?? 0;
      if (updateMode) continue;
      if (list.length > allowed) {
        failures.add('[$rule] ${list.length} violações (baseline $allowed) — regressão:\n${summarize(list, max: 12)}');
      } else if (list.length < allowed) {
        improved.add('$rule: $allowed → ${list.length}');
      }
      if (verbose && list.isNotEmpty) {
        // ignore: avoid_print
        print('[$suite] $screenId [$rule] ${list.length}\n${summarize(list, max: 6)}');
      }
    }
    if (improved.isNotEmpty) {
      // ignore: avoid_print
      print('RATCHET[$suite] $screenId melhorou (baixe o baseline): ${improved.join(', ')}');
      if (strict) failures.add('baseline obsoleto (GALLERY_STRICT_RATCHET=1): ${improved.join(', ')}');
    }
    if (failures.isNotEmpty) {
      fail('$suite · $screenId\n${failures.join('\n')}\n'
          'Se a violação é intencional/aceita, rode GALLERY_UPDATE_BASELINE=1 (e justifique no PR).');
    }
  }

  /// Chame em `tearDownAll`: imprime o resumo e, no modo update, grava o JSON.
  void finish() {
    final total = measured.values.fold<int>(0, (a, b) => a + b);
    final byRule = <String, int>{};
    measured.forEach((k, v) {
      final rule = k.split('|').first;
      byRule[rule] = (byRule[rule] ?? 0) + v;
    });
    // ignore: avoid_print
    print('GALERIA[$suite] violações medidas: $total ${byRule.isEmpty ? '' : byRule.entries.map((e) => '${e.key}=${e.value}').join(' ')}');
    if (!updateMode) return;
    final merged = <String, int>{...baseline, ...measured}..removeWhere((_, v) => v == 0);
    final sorted = Map.fromEntries(merged.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    file.createSync(recursive: true);
    file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(sorted)}\n');
    // ignore: avoid_print
    print('GALERIA[$suite] baseline gravado: ${file.path} (${sorted.length} entradas)');
  }
}

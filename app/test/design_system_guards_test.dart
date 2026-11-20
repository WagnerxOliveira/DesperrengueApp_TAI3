// Linter de design (spec v2.28.0 §2.5) com ratchet: a contagem de cada ocorrencia proibida
// por arquivo pode apenas DIMINUIR em relacao a app/test/design_system_baseline.json.
//
//  * contagem SUBIU em arquivo do baseline  -> falha
//  * arquivo novo (fora do baseline) com qualquer ocorrencia proibida -> falha
//  * contagem DIMINUIU -> passa; atualize o baseline para travar o ganho:
//        node scripts/ui_audit_metrics.mjs --update <arquivo>
//
// Escopo/regexes: ver test/design_system/ds_source_scanner.dart (espelho de
// scripts/ui_audit_metrics.mjs). Exclui features/founder/**, main_founder.dart,
// core/ui/design_system/**; core/ui/** isento de Color/FittedBox/rotas/sheets/dialogs/spinners.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'design_system/ds_source_scanner.dart';

const _hint = r'Se voce REMOVEU ocorrencias, rode `node scripts/ui_audit_metrics.mjs --update <arquivo>` '
    '(na raiz do repo) e comite o baseline. Se adicionou, use os componentes do Design System '
    '(AppType/AppColors tokens, AppRoute, AppSheet.show/AppDialog.show, AppSkeleton) em vez de '
    'literais/rotas/dialogs diretos.';

const _why = <String, String>{
  'fontSize': 'fontSize: literal numerico (use AppType.* / textTheme)',
  'colorLiteral': 'Color(0x...) fora de core/ui (use tokens context.tk / AppTokens)',
  'fittedBox': 'FittedBox (reflua o layout; nunca encolha o texto)',
  'materialPageRoute': 'MaterialPageRoute direto (use AppRoute)',
  'showModalBottomSheet': 'showModalBottomSheet direto (use AppSheet.show)',
  'showDialog': 'showDialog direto (use AppDialog.show)',
  'circularProgress': 'CircularProgressIndicator em tela (use AppSkeleton*; spinner so em botao loading)',
  'ellipsis': 'TextOverflow.ellipsis (nao corte informacao essencial)',
  'unembeddedWeight': 'FontWeight w100-w300/w900 sem arquivo embarcado (use w400-w800 / AppType)',
  'glyphInText': 'emoji/simbolo (★ ✓ 🔒 →) em string (use Icon/SvgPicture/Lottie)',
};

Map<String, Map<String, int>> _loadBaseline() {
  final raw = jsonDecode(File('test/design_system_baseline.json').readAsStringSync()) as Map<String, dynamic>;
  final out = <String, Map<String, int>>{};
  raw.forEach((k, v) {
    if (k.startsWith('~') || k.startsWith('_')) return;
    out[k] = (v as Map<String, dynamic>).map((m, c) => MapEntry(m, c as int));
  });
  return out;
}

void main() {
  final baseline = _loadBaseline();
  final files = libFiles(Directory('lib'));
  final current = <String, Map<String, int>>{};
  files.forEach((rel, f) {
    final c = countMetrics(rel, f.readAsStringSync());
    if (c.isNotEmpty) current[rel] = c;
  });

  test('ratchet: nenhuma ocorrencia proibida pode aumentar nem surgir em arquivo novo', () {
    final problems = <String>[];
    current.forEach((rel, counts) {
      final base = baseline[rel];
      counts.forEach((metric, cur) {
        final old = base?[metric] ?? 0;
        if (cur > old) {
          problems.add(base == null
              ? '  - $rel (arquivo FORA do baseline): $metric = $cur, permitido 0 -> ${_why[metric]}'
              : '  - $rel: $metric subiu de $old para $cur -> ${_why[metric]}');
        }
      });
    });
    expect(problems, isEmpty, reason: 'Design System: contagens acima do baseline.\n${problems.join('\n')}\n$_hint');
  });

  test('baseline nao referencia arquivos inexistentes/isentos (limpe com --update)', () {
    final stale = baseline.keys.where((rel) => !files.containsKey(rel)).toList()..sort();
    expect(
      stale,
      isEmpty,
      reason: 'Arquivos no baseline que nao existem mais (ou ficaram isentos):\n  ${stale.join('\n  ')}\n'
          'Rode: node scripts/ui_audit_metrics.mjs --update ${stale.join(' ')}',
    );
  });

  test('baseline: uma linha por arquivo, ordenada por caminho (merges limpos)', () {
    final lines = File('test/design_system_baseline.json')
        .readAsLinesSync()
        .where((l) => l.startsWith('  "') && !l.startsWith('  "~'))
        .map((l) => jsonDecode('{${l.trim().replaceAll(RegExp(r',$'), '')}}') as Map<String, dynamic>)
        .map((m) => m.keys.single)
        .toList();
    expect(lines.length, baseline.length);
    final sorted = [...lines]..sort();
    expect(lines, sorted, reason: 'Linhas do baseline fora de ordem: regenere com node scripts/ui_audit_metrics.mjs');
  });

  group('scanner', () {
    test('ignora comentarios e conteudo de strings; conta codigo real', () {
      const src = r'''
// fontSize: 12  FittedBox
/* showDialog(  /* aninhado */ Color(0xFF000000) */
final a = 'fontSize: 13 FittedBox';
final b = r'Color(0xFF) $x';
final c = Text('ok', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900));
final d = FittedBox();
''';
      final counts = countMetrics('features/x.dart', src);
      expect(counts['fontSize'], 1);
      expect(counts['fittedBox'], 1);
      expect(counts['unembeddedWeight'], 1);
      expect(counts.containsKey('colorLiteral'), isFalse);
      expect(counts.containsKey('showDialog'), isFalse);
    });

    test('glifos em strings (inclusive escapes) mas nao em comentarios; core/ui isento de Color', () {
      const src = r'''
// ★ comentario
final a = Text('Nota ★ 5');
final b = Text('\u2713 ok \u{1F512}');
final c = Text('ação · preço — R$ ${x ? '→' : 'b'}');
final d = Color(0xFF123456);
''';
      expect(countMetrics('features/x.dart', src)['glyphInText'], 4);
      expect(countMetrics('features/x.dart', src)['colorLiteral'], 1);
      expect(countMetrics('core/ui/widgets.dart', src).containsKey('colorLiteral'), isFalse);
    });
  });
}

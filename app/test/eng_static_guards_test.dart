import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardas estáticas (rodam na suíte): impedem regressões de privacidade e
/// portabilidade que revisão humana deixa passar.
List<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

String _rel(File f) => f.path.replaceAll('\\', '/');

void main() {
  final libFiles = _dartFiles('lib');

  test('zero dart:io em lib/ (Web-safe) — exceto com conditional import', () {
    final offenders = <String>[];
    for (final f in libFiles) {
      final text = f.readAsStringSync();
      final importsIo = RegExp(r"^import\s+'dart:io'", multiLine: true).hasMatch(text);
      final conditional = text.contains('dart.library.io') || text.contains('dart.library.html');
      if (importsIo && !conditional) offenders.add(_rel(f));
    }
    expect(offenders, isEmpty, reason: 'dart:io quebra a build Web: $offenders');
  });

  test('todo uploadBinary fora do MediaService passa por sanitizeForUpload (EXIF/GPS)', () {
    final offenders = <String>[];
    for (final f in libFiles) {
      final text = f.readAsStringSync();
      if (!text.contains('uploadBinary(') && !text.contains('.upload(')) continue;
      if (!text.contains('sanitizeForUpload')) offenders.add(_rel(f));
    }
    expect(offenders, isEmpty, reason: 'upload sem higienizar EXIF: $offenders');
  });

  test('Isolate.run só dentro de runOffMainThread (fallback Web)', () {
    final offenders = <String>[];
    for (final f in libFiles) {
      if (_rel(f).endsWith('core/utils/off_thread.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i].trimLeft();
        if (l.startsWith('//')) continue;
        if (l.contains('Isolate.run(') || l.contains('Isolate.spawn(') || l.startsWith("import 'dart:isolate'")) {
          offenders.add('${_rel(f)}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'use runOffMainThread (Web-safe): $offenders');
  });

  test('nenhum print/debugPrint de PII, token ou coordenada', () {
    final logCall = RegExp(r'\b(debugPrint|print|log)\s*\(');
    final sensitive = RegExp(
      r'cpf|token|jwt|password|senha|telefone|phone|endere[cç]o|address|latitude|longitude|\blat\b|\blng\b|pos\.|position|e-?mail',
      caseSensitive: false,
    );
    final offenders = <String>[];
    for (final f in libFiles) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (logCall.hasMatch(l) && sensitive.hasMatch(l) && !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///')) {
          offenders.add('${_rel(f)}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'log com dado sensível: $offenders');
  });
}

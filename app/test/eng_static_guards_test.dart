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

bool _isFounderOnlyLibFile(String relPath) {
  final normalized = relPath.startsWith('./') ? relPath.substring(2) : relPath;
  return normalized == 'lib/main_founder.dart' ||
      normalized.endsWith('/lib/main_founder.dart') ||
      normalized.startsWith('lib/features/founder/') ||
      normalized.contains('/lib/features/founder/') ||
      normalized.startsWith('lib/core/analytics/founder_') ||
      normalized.contains('/lib/core/analytics/founder_');
}

File _repoFile(String repoRelativePath) {
  if (repoRelativePath.startsWith('app/')) {
    final fromInsideApp = File(repoRelativePath.substring(4));
    if (fromInsideApp.existsSync()) return fromInsideApp;
  }
  final fromParent = File('../$repoRelativePath');
  if (fromParent.existsSync()) return fromParent;
  final fromRoot = File(repoRelativePath);
  if (fromRoot.existsSync()) return fromRoot;
  throw StateError('Arquivo obrigatório não encontrado: $repoRelativePath (cwd: ${Directory.current.path})');
}

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

  test('zero footprint do Founder Cockpit nos arquivos públicos de lib/ (isolamento matemático)', () {
    final directiveLeak = RegExp(
      r'''^\s*(?:import|export|part)\s+['"](?:[^'"]*/)?(?:main_founder\.dart|founder/|founder_[a-z0-9_]+\.dart)''',
      multiLine: true,
    );
    final symbolOrPathLeak = RegExp(
      r'main_founder\.dart|features/founder/|core/analytics/founder_|\bFounder(?:Cockpit|Sovereign|DpOptimization|AccountantPack)\w*\b',
    );
    final offenders = <String>[];
    final publicFiles = libFiles.where((f) => !_isFounderOnlyLibFile(_rel(f))).toList();
    expect(publicFiles, isNotEmpty, reason: 'deve escanear a árvore pública em lib/');

    for (final f in publicFiles) {
      final rel = _rel(f);
      final text = f.readAsStringSync();
      if (directiveLeak.hasMatch(text)) {
        offenders.add('$rel (import/export/part founder)');
        continue;
      }
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trimLeft();
        if (trimmed.startsWith('//')) continue;
        if (symbolOrPathLeak.hasMatch(trimmed)) {
          offenders.add('$rel:${i + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'APK público jamais pode importar, exportar ou referenciar módulos Founder: $offenders',
    );
  });

  test('isolamento Dual-APK preservado em build.gradle.kts, AndroidManifest.xml e beta-release.yml', () {
    final gradle = _repoFile('app/android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('applicationId = "br.com.desperrengue.app"'));
    expect(gradle, contains('project.hasProperty("founderApp")'));
    expect(gradle, contains('project.hasProperty("dart-defines")'));
    expect(gradle, contains('FOUNDER_APP=true'));
    expect(gradle, contains('applicationIdSuffix = ".founder"'));
    expect(gradle, contains('manifestPlaceholders["appLabel"] = "Desperrengue CEO"'));
    expect(gradle, contains('manifestPlaceholders["appLabel"] = "Desperrengue"'));
    expect(gradle, contains('manifestPlaceholders["authScheme"] = "br.com.desperrengue.app.founder"'));
    expect(gradle, contains('manifestPlaceholders["authScheme"] = "br.com.desperrengue.app"'));
    expect(gradle, contains('manifestPlaceholders["onboardingScheme"] = "desperrengue-founder"'));
    expect(gradle, contains('manifestPlaceholders["onboardingScheme"] = "desperrengue"'));

    final manifest = _repoFile('app/android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:label="\${appLabel}"'));
    expect(manifest, contains('android:scheme="\${authScheme}"'));
    expect(manifest, contains('android:scheme="\${onboardingScheme}"'));
    expect(manifest.contains('android:label="Desperrengue"'), isFalse);

    final workflow = _repoFile('.github/workflows/beta-release.yml').readAsStringSync();
    expect(workflow, contains('--target=lib/main.dart'));
    expect(workflow, contains('--target=lib/main_founder.dart'));
    expect(workflow, contains('--obfuscate'));
    expect(workflow, contains('--split-debug-info=build/founder-symbols'));
    expect(workflow, contains('-PfounderApp=true'));
    expect(workflow, contains('--dart-define=FOUNDER_APP=true'));
    expect(workflow, contains('FOUNDER_SHA256='));
    expect(workflow, contains('"\$RUNNER_TEMP/desperrengue.apk"'));
    expect(workflow, contains('"\$RUNNER_TEMP/desperrengue-founder-ceo.apk"'));

    final releaseCreateMatch = RegExp(
      r'gh release create beta-latest[\s\S]*?--notes-file',
    ).firstMatch(workflow);
    expect(releaseCreateMatch, isNotNull, reason: 'gh release create beta-latest deve existir no workflow');
    final releaseCmd = releaseCreateMatch!.group(0)!;
    expect(releaseCmd, contains('"\$RUNNER_TEMP/desperrengue.apk"'));
    expect(releaseCmd, contains('"\$RUNNER_TEMP/desperrengue-founder-ceo.apk"'));
  });
}

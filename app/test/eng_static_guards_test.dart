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
    final condPattern = RegExp(r"if\s*\(\s*dart\.library\.io\s*\)\s*'([^']+)'");
    final uncondImportPattern = RegExp(
      r"^import\s+'([^']+)'\s*(?:as\s+\w+\s*)?(?:(?:show|hide)[^;]*)?;",
      multiLine: true,
    );
    final conditionalIoTargets = <String>{};
    final allTexts = <String, String>{};
    for (final f in libFiles) {
      final rel = _rel(f);
      final text = f.readAsStringSync();
      allTexts[rel] = text;
      final dir = rel.contains('/') ? rel.substring(0, rel.lastIndexOf('/') + 1) : '';
      for (final m in condPattern.allMatches(text)) {
        final target = m.group(1)!;
        conditionalIoTargets.add(target.startsWith('package:') ? target : '$dir$target');
      }
    }

    final offenders = <String>[];
    for (final entry in allTexts.entries) {
      final rel = entry.key;
      final text = entry.value;
      final importsIo = RegExp(r"^import\s+'dart:io'", multiLine: true).hasMatch(text);
      if (!importsIo) continue;
      final selfConditional = text.contains('dart.library.io') || text.contains('dart.library.html');
      final isConditionalTarget = conditionalIoTargets.contains(rel);
      if (!selfConditional && !isConditionalTarget) {
        offenders.add(rel);
        continue;
      }
      if (isConditionalTarget) {
        final base = rel.split('/').last;
        for (final other in allTexts.entries) {
          for (final m in uncondImportPattern.allMatches(other.value)) {
            final uri = m.group(1)!;
            if (uri == base || uri.endsWith('/$base')) {
              offenders.add('${other.key} importa $rel sem conditional import (dart.library.io)');
            }
          }
        }
      }
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

  test('isolamento do ícone e splash exclusivos Desperrengue CEO (src/founder/res vs src/main/res)', () {
    final gradle = _repoFile('app/android/app/build.gradle.kts').readAsStringSync();
    final gradleCodeOnly = gradle
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    final founderOverlayBlock = RegExp(
      r'if\s*\(\s*isFounderBuild\s*\)\s*\{\s*sourceSets[\s\S]*?res\.srcDirs\("src/\$name/res",\s*"src/founder/res"\)',
    ).firstMatch(gradleCodeOnly);
    expect(
      founderOverlayBlock,
      isNotNull,
      reason: 'src/founder/res deve ser ativado estritamente dentro de `if (isFounderBuild)`',
    );
    expect(
      'src/founder/res'.allMatches(gradleCodeOnly).length,
      equals(1),
      reason: 'src/founder/res não pode vazar fora do bloco condicional isFounderBuild',
    );
    expect(
      gradleCodeOnly.contains('getByName("main").res.srcDirs'),
      isFalse,
      reason: 'main sourceSet nunca deve misturar src/founder/res (evita Duplicate resources e vazamento público)',
    );

    const binaryPairs = <String>[
      'mipmap-mdpi/ic_launcher.png',
      'mipmap-hdpi/ic_launcher.png',
      'mipmap-xhdpi/ic_launcher.png',
      'mipmap-xxhdpi/ic_launcher.png',
      'mipmap-xxxhdpi/ic_launcher.png',
      'mipmap-mdpi/ic_launcher_round.png',
      'mipmap-hdpi/ic_launcher_round.png',
      'mipmap-xhdpi/ic_launcher_round.png',
      'mipmap-xxhdpi/ic_launcher_round.png',
      'mipmap-xxxhdpi/ic_launcher_round.png',
      'drawable-xxxhdpi/ic_launcher_background.png',
      'drawable-xxxhdpi/ic_launcher_foreground.png',
      'drawable-xxxhdpi/ic_launcher_monochrome.png',
      'drawable-xxxhdpi/android12splash.png',
    ];

    for (final relRes in binaryPairs) {
      final publicFile = _repoFile('app/android/app/src/main/res/$relRes');
      final founderFile = _repoFile('app/android/app/src/founder/res/$relRes');
      final publicBytes = publicFile.readAsBytesSync();
      final founderBytes = founderFile.readAsBytesSync();
      expect(publicBytes, isNotEmpty, reason: 'recurso público vazio: $relRes');
      expect(founderBytes, isNotEmpty, reason: 'recurso CEO vazio: $relRes');
      expect(
        founderBytes,
        isNot(equals(publicBytes)),
        reason: 'recurso CEO $relRes deve divergir byte-a-byte do ícone/splash público',
      );
    }

    final publicColors = _repoFile('app/android/app/src/main/res/values/colors.xml').readAsStringSync();
    final founderColors = _repoFile('app/android/app/src/founder/res/values/colors.xml').readAsStringSync();
    expect(publicColors, contains('#0F172A'));
    expect(founderColors, contains('#07090D'));

    final publicV31 = _repoFile('app/android/app/src/main/res/values-v31/styles.xml').readAsStringSync();
    final founderV31 = _repoFile('app/android/app/src/founder/res/values-v31/styles.xml').readAsStringSync();
    expect(publicV31, contains('#0F172A'));
    expect(founderV31, contains('#07090D'));
  });

  test('Zero-Fake Policy & Cofre Monocrático Desperrengue CEO: zero dados demo, zero delegados e zero campos pré-preenchidos', () {
    final forbiddenPatterns = <RegExp>[
      RegExp(r'\bdeterministicDemo\b'),
      RegExp(r'\bAUTHORIZED_DELEGATE\b'),
      RegExp(r'\bFounderSeatRole\b'),
      RegExp(r'\bFounderPermissionScope\b'),
      RegExp(r'\bSovereignDelegateSlot\b'),
      RegExp(r'wagner\.ceo@desperrengue\.com\.br'),
      RegExp(r'_buildDefaultNeighborhoodHeatmap'),
      RegExp(r'_buildDefaultCohortRows'),
    ];

    final offenders = <String>[];
    for (final f in libFiles) {
      final rel = _rel(f);
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//') || line.startsWith('///')) continue;
        for (final pat in forbiddenPatterns) {
          if (pat.hasMatch(line)) {
            offenders.add('$rel:${i + 1} (${pat.pattern})');
          }
        }
      }
      if (_isFounderOnlyLibFile(rel)) {
        final fullText = f.readAsStringSync();
        if (RegExp(r'TextEditingController\s*\(\s*text\s*:').hasMatch(fullText)) {
          offenders.add('$rel (TextEditingController pré-preenchido proibido)');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Zero-Fake Policy ou proibição de pré-preenchimento/delegados violada: $offenders',
    );

    final mainActivity = _repoFile(
      'app/android/app/src/main/kotlin/br/com/desperrengue/app/MainActivity.kt',
    ).readAsStringSync();
    expect(mainActivity, contains('FLAG_SECURE'));
    expect(mainActivity, contains('br.com.desperrengue.app.founder/security'));
    expect(mainActivity, contains('br.com.desperrengue.app.founder/ota'));
    expect(mainActivity, contains('br.com.desperrengue.app/ota'));
    expect(mainActivity, contains('FounderOtaFileProvider'));
    expect(mainActivity, contains('PublicOtaFileProvider'));
    expect(mainActivity, contains('verifyDownloadedApkSignature'));
    expect(mainActivity, contains('ERR_OTA_SHA256_MISMATCH'));
    expect(mainActivity, contains('ERR_OTA_SIGNATURE_MISMATCH'));
    expect(mainActivity, contains('ERR_OTA_PACKAGE_MISMATCH'));

    final manifest = _repoFile('app/android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
    expect(
      manifest.contains('REQUEST_INSTALL_PACKAGES'),
      isFalse,
      reason: 'Manifesto base (Play Store) jamais pode declarar REQUEST_INSTALL_PACKAGES',
    );
    expect(
      manifest.contains('FounderOtaFileProvider'),
      isFalse,
      reason: 'Provider de auto-update CEO jamais pode existir no manifesto público',
    );
    expect(
      manifest.contains('PublicOtaFileProvider'),
      isFalse,
      reason: 'Provider OTA beta fica isolado em src/beta/AndroidManifest.xml (fora do AAB da Play Store)',
    );

    final betaManifest = _repoFile('app/android/app/src/beta/AndroidManifest.xml').readAsStringSync();
    expect(betaManifest, contains('android.permission.REQUEST_INSTALL_PACKAGES'));
    expect(betaManifest, contains('br.com.desperrengue.app.PublicOtaFileProvider'));
    expect(betaManifest, contains('android:authorities="\${applicationId}.ota.provider"'));
    expect(betaManifest, contains('android:exported="false"'));

    // XML 1.0 (Seção 2.5): comentários `<!-- ... -->` jamais podem conter `--` interno (quebra ManifestMerger2):
    for (final manifestRel in <String>[
      'app/android/app/src/main/AndroidManifest.xml',
      'app/android/app/src/beta/AndroidManifest.xml',
      'app/android/app/src/founder/AndroidManifest.xml',
    ]) {
      final xmlText = _repoFile(manifestRel).readAsStringSync();
      for (final commentMatch in RegExp(r'<!--([\s\S]*?)-->').allMatches(xmlText)) {
        expect(
          commentMatch.group(1)!.contains('--'),
          isFalse,
          reason: '$manifestRel contém "--" proibido dentro de comentário XML (quebra ManifestMerger2)',
        );
      }
    }

    final founderManifest = _repoFile('app/android/app/src/founder/AndroidManifest.xml').readAsStringSync();
    expect(founderManifest, contains('android.permission.REQUEST_INSTALL_PACKAGES'));
    expect(founderManifest, contains('br.com.desperrengue.app.FounderOtaFileProvider'));
    expect(founderManifest, contains('android:exported="false"'));
    expect(founderManifest, contains('android:scheme="desperrengue-founder"'));
    expect(founderManifest, contains('android:host="vault"'));
    expect(founderManifest, contains('android:pathPrefix="/reset-password"'));
    expect(
      manifest.contains('android:host="vault"'),
      isFalse,
      reason: 'Deep-link de redefinição do Cofre CEO jamais pode existir no manifesto público',
    );

    final gradle = _repoFile('app/android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('manifest.srcFile("src/founder/AndroidManifest.xml")'));
    expect(gradle, contains('isBetaUpdatesBuild'));
    expect(gradle, contains('manifest.srcFile("src/beta/AndroidManifest.xml")'));

    final workflow = _repoFile('.github/workflows/beta-release.yml').readAsStringSync();
    expect(workflow, contains('-PbetaUpdates=true'));
    expect(workflow, contains('--dart-define=BETA_UPDATES=true'));
  });

  test('Cofre Soberano v2.14+: zero OAuth cross-app para Marketplace, teto físico de 64 chars e política de senha forte', () {
    final forbiddenFounderOAuth = <RegExp>[
      RegExp(r'\bsignInWithOAuth\b'),
      RegExp(r'\bOAuthProvider\b'),
      RegExp(r'\bsignInWithGoogleOAuth\b'),
      RegExp(r'Autenticar Conta Google Soberana'),
      RegExp(r'br\.com\.desperrengue\.app://'),
      RegExp(r'br\.com\.desperrengue\.app\.founder://login-callback'),
    ];

    final offenders = <String>[];
    for (final f in libFiles) {
      final rel = _rel(f);
      if (!_isFounderOnlyLibFile(rel)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//') || line.startsWith('///')) continue;
        for (final pat in forbiddenFounderOAuth) {
          if (pat.hasMatch(line)) {
            offenders.add('$rel:${i + 1} (${pat.pattern})');
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Módulos Founder jamais podem invocar OAuth externo ou redirecionar ao Marketplace: $offenders',
    );

    final gateSource = _repoFile(
      'app/lib/features/founder/presentation/founder_auth_and_vault_gate.dart',
    ).readAsStringSync();
    expect(
      gateSource,
      contains('LengthLimitingTextInputFormatter(CeoStrongPasswordPolicy.maxLength)'),
    );
    expect(gateSource, contains('maxLength: CeoStrongPasswordPolicy.maxLength'));
    expect(gateSource, contains('CeoStrongPasswordPolicy.evaluate'));

    final mainFounderSource = _repoFile('app/lib/main_founder.dart').readAsStringSync();
    expect(
      mainFounderSource,
      contains('detectSessionInUri: false'),
      reason: 'main_founder.dart deve desativar captura OAuth global de URI',
    );
  });
}

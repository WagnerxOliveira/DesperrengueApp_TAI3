import 'dart:io';

import 'package:flutter/services.dart';

/// Fontes embarcadas e seus pesos reais, LIDAS de `pubspec.yaml` (bloco
/// `flutter: fonts:`) — assim a galeria acompanha sozinha o que o `foundation`
/// embarcar (ex.: Inter 800, subsets ampliados). Exige `cwd == app/` (padrão do
/// `flutter test`).
Map<String, Map<int, String>> embeddedFontFiles() => _embedded ??= _parsePubspecFonts();

Map<String, Map<int, String>>? _embedded;

Map<String, Map<int, String>> _parsePubspecFonts() {
  final yaml = File('pubspec.yaml').readAsStringSync();
  final start = yaml.indexOf('\n  fonts:');
  if (start < 0) return <String, Map<int, String>>{};
  final families = <String, Map<int, String>>{};
  String? fam;
  String? pending;
  void flush() {
    if (pending != null && fam != null) families[fam]![400] = pending!; // sem weight: = 400
    pending = null;
  }

  for (final line in yaml.substring(start + 1).split('\n')) {
    if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) break; // saiu do bloco flutter:
    final f = RegExp(r'^\s*-\s*family:\s*(\S+)').firstMatch(line);
    if (f != null) {
      flush();
      fam = f.group(1);
      families[fam!] = <int, String>{};
      continue;
    }
    final a = RegExp(r'^\s*-\s*asset:\s*assets/fonts/(\S+)').firstMatch(line);
    if (a != null) {
      flush();
      pending = a.group(1);
      continue;
    }
    final w = RegExp(r'^\s*weight:\s*(\d+)').firstMatch(line);
    if (w != null && pending != null && fam != null) {
      families[fam]![int.parse(w.group(1)!)] = pending!;
      pending = null;
    }
  }
  flush();
  return families;
}

/// Famílias permitidas em texto de tela (spec §2.1).
const Set<String> kAllowedFontFamilies = <String>{'PlusJakartaSans', 'Inter'};

/// Famílias de ÍCONE (não contam como texto).
const Set<String> kIconFontFamilies = <String>{
  'MaterialIcons',
  'MaterialIconsOutlined',
  'MaterialIconsRounded',
  'MaterialIconsSharp',
  'CupertinoIcons',
};

bool _loaded = false;

/// Carrega as fontes REAIS no motor de teste (idempotente).
///
/// Além de `PlusJakartaSans`/`Inter`, registra o Inter também sob o nome
/// `Roboto` quando [mapDefaultFontToInter] é verdadeiro: no `flutter test` o
/// texto sem família cai em Ahem (cada glifo = 1 em de largura), o que
/// superestima muito a largura e gera overflow falso nas telas ainda não
/// migradas. Mapeando a fonte padrão para a métrica do Inter, a medição fica
/// realista (a fonte efetiva continua `null`/`Roboto` para os testes de
/// família, que acusam o desvio do mesmo jeito).
Future<void> loadGalleryFonts({bool mapDefaultFontToInter = true}) async {
  if (_loaded) return;
  Future<void> load(String family, Iterable<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }

  for (final e in embeddedFontFiles().entries) {
    await load(e.key, e.value.values);
  }
  if (mapDefaultFontToInter) {
    await load('Roboto', (embeddedFontFiles()['Inter'] ?? const <int, String>{}).values);
  }
  _loaded = true;
}

/// Bytes de um TTF embarcado (lê direto do disco, para testes sem engine).
Uint8List readFontFileSync(String fileName) {
  final f = File('assets/fonts/$fileName');
  if (!f.existsSync()) {
    throw StateError('Fonte não encontrada: ${f.path} (rode a partir de app/).');
  }
  return f.readAsBytesSync();
}

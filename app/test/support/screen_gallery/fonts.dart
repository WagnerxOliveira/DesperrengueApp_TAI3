import 'dart:io';

import 'package:flutter/services.dart';

/// Fontes embarcadas e seus pesos reais (espelha `pubspec.yaml`).
///
/// Mantido AQUI (e conferido por `glyph_coverage_test`) para que a galeria
/// saiba quais famílias/pesos existem de verdade. Se o `foundation` embarcar
/// novos arquivos (ex.: Inter 800, subset ampliado), atualize esta tabela —
/// o teste de pubspec acusa divergência.
const Map<String, Map<int, String>> kEmbeddedFontFiles = <String, Map<int, String>>{
  'PlusJakartaSans': <int, String>{
    700: 'PlusJakartaSans-Bold.ttf',
    800: 'PlusJakartaSans-ExtraBold.ttf',
  },
  'Inter': <int, String>{
    400: 'Inter-Regular.ttf',
    500: 'Inter-Medium.ttf',
    600: 'Inter-SemiBold.ttf',
    700: 'Inter-Bold.ttf',
  },
};

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

  for (final e in kEmbeddedFontFiles.entries) {
    await load(e.key, e.value.values);
  }
  if (mapDefaultFontToInter) {
    await load('Roboto', kEmbeddedFontFiles['Inter']!.values);
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

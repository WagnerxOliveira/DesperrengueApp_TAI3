@Tags(<String>['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen_gallery/screen_gallery.dart';
import 'gallery_registry.dart';

/// Goldens das telas-chave (claro/escuro × celular 390 e Web 1280).
///
/// SÓ no CI Linux (ver `app/dart_test.yaml`): o texto renderiza diferente entre
/// SOs, então os PNG em `test/ui_gallery/goldens/` são gerados/comparados lá.
/// Não roda no `flutter test` padrão (tag `golden` ignorada) e também se
/// auto-ignora fora do Linux.
///
/// Telas-chave: `kGoldenScreenIds` (16 telas × claro/escuro × celular 390 / Web 1280).
/// Para incluir uma tela, acrescente o id do registro aqui.
const List<String> kGoldenScreenIds = <String>[
  // Onda 1 — Entrada e identidade
  'auth/login',
  'auth/cadastro_dados_basicos_vazio',
  'auth/role_selection_ambos_perfis',
  'auth/existing_account_detected_sheet',
  // Onda 2 — Cliente (núcleo)
  'client/category_grid',
  'client/provider_search',
  'client/request_wizard_0',
  // Onda 3 — Cliente (pedidos e dinheiro)
  'client/carteira',
  'client/insufficient_funds_sheet',
  'client/orders_tab_cheia',
  'client/detalhe_servico_concluido',
  // Onda 4 — Profissional
  'provider/wallet_cheia',
  'provider/dossie_concluido',
  'provider/quote_form',
  // Onda 5 — Compartilhadas
  'shared/chat_screen',
  'shared/support_center',
];

void main() {
  setUpAll(GalleryEnv.init);
  setUp(GalleryEnv.resetSingletons);

  final screens = galleryScreens().where((s) => kGoldenScreenIds.contains(s.id));
  for (final screen in screens) {
    for (final vp in <GalleryViewport>[vp390, vp1280]) {
      for (final b in <Brightness>[Brightness.light, Brightness.dark]) {
        final name = '${screen.id.replaceAll('/', '_')}_${vp.name}_${b.name}';
        testWidgets('golden · $name', (tester) async {
          if (!Platform.isLinux) {
            markTestSkipped('Goldens só no Linux (CI).');
            return;
          }
          final variant = GalleryVariant(viewport: vp, brightness: b, mode: screen.modes.first);
          await withGalleryRun(tester, screen, variant, (run) async {
            await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
          });
        });
      }
    }
  }
}

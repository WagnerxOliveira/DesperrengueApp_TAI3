import '../support/screen_gallery/screen_gallery.dart';
import 'registry/auth_screens.dart';
import 'registry/client_screens.dart';
import 'registry/provider_screens.dart';
import 'registry/seed_screens.dart';
import 'registry/shared_screens.dart';

/// REGISTRO DA GALERIA DE TELAS (v2.28.0).
///
/// Único ponto de entrada dos donos de tela: para registrar uma tela, envie
/// pelo board a linha `GalleryScreen(...)` (id, source, wave, owner, builder,
/// overrides/interact) — o `qagal` a insere em `registry/<grupo>.dart`.
/// Todos os testes de `ui_gallery/` e `ui_design_audit/` iteram sobre esta lista.
///
/// Convenções:
///  * `id` = `<grupo>/<arquivo_sem_ext>[_variante]`, estável (chave do ratchet).
///  * `modes`: modo(s) de tema em que a tela vive (`{null}` = tema da marca).
///  * `animatesForever: true` se a tela tem animação infinita legítima.
///  * Use `SampleData`/`FakeWalletService`/`FakeProfileService` (`fakes.dart`).
List<GalleryScreen> galleryScreens() => <GalleryScreen>[
      ...seedScreens(),
      ...authScreens(),
      ...clientScreens(),
      ...providerScreens(),
      ...coreUiScreens(),
      ...sharedScreens(),
    ];

/// Telas do grupo/onda informados (ex.: `wave: 1`).
List<GalleryScreen> galleryScreensOfWave(int wave) =>
    galleryScreens().where((s) => s.wave == wave).toList();

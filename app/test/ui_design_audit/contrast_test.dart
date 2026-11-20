import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen_gallery/screen_gallery.dart';
import '../ui_gallery/gallery_registry.dart';

/// Contraste WCAG real por `Text`/`Icon` sobre o fundo efetivo: texto ≥ 4,5:1
/// (≥ 3:1 se grande ≥ 24 px ou ≥ 18,66 px em negrito) e ícones ≥ 3:1, em claro
/// e escuro. Baseline em `baseline/contrast.json`.
void main() {
  defineGallerySuite(
    suite: 'contrast',
    label: 'contraste',
    screens: galleryScreens(),
    variants: GalleryMatrix.contrast,
    rules: const <String>[GalleryRules.contrast],
    check: (run, log) => checkContrast(run, log),
  );

  // Tokens de tema: texto/acento sobre fundo e cartão, nos dois acentos e nos
  // dois brilhos (contratos do spec §2.3). `accentInk` (≥ 4,5:1) é exigido
  // assim que o `foundation` o entregar (ver `AppTokens`).
  group('tokens de tema · contraste', () {
    for (final mode in <UserMode?>[null, UserMode.client, UserMode.provider]) {
      for (final b in Brightness.values) {
        test('texto principal/mudo ≥ 4,5:1 sobre fundo e cartão · ${mode?.wire ?? 'marca'} · ${b.name}', () {
          final tk = (AppTheme.resolve(mode, b).extension<AppTokens>())!;
          for (final bg in <Color>[tk.background, tk.card, tk.surface]) {
            expect(
              contrastRatio(tk.text, bg),
              greaterThanOrEqualTo(4.5),
              reason: 'text sobre ${bg.toARGB32().toRadixString(16)}',
            );
            expect(
              contrastRatio(tk.textMuted, bg),
              greaterThanOrEqualTo(4.5),
              reason: 'textMuted sobre ${bg.toARGB32().toRadixString(16)}',
            );
          }
        });
      }
    }

    test('acento de preenchimento como TEXTO sobre o fundo claro (informativo: marca laranja ≈ 3,05:1)', () {
      final light = AppTokens.light;
      final client = contrastRatio(light.clientAccent, light.background);
      final provider = contrastRatio(light.providerAccent, light.background);
      // ignore: avoid_print
      print(
        'GALERIA contraste acento/branco: cliente=${client.toStringAsFixed(2)}:1 profissional=${provider.toStringAsFixed(2)}:1',
      );
      expect(provider, greaterThanOrEqualTo(4.5));
      // O laranja de marca NÃO passa como texto < 24px (spec §1.2.3); o teste
      // registra o valor e passa a exigir `accentInk` quando existir no tema.
      expect(client, greaterThan(2.9));
    });
  });
}

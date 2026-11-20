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
  // dois brilhos (contratos do spec §2.3).
  group('tokens de tema · contraste', () {
    for (final mode in <UserMode?>[null, UserMode.client, UserMode.provider]) {
      for (final b in Brightness.values) {
        test('texto, mudo, accentInk e dangerInk ≥ 4,5:1 sobre fundo/cartão/superfície · ${mode?.wire ?? 'marca'} · ${b.name}', () {
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
            expect(
              contrastRatio(tk.accentInk, bg),
              greaterThanOrEqualTo(4.5),
              reason: 'accentInk sobre ${bg.toARGB32().toRadixString(16)}',
            );
            expect(
              contrastRatio(tk.dangerInk, bg),
              greaterThanOrEqualTo(4.5),
              reason: 'dangerInk sobre ${bg.toARGB32().toRadixString(16)}',
            );
          }
          expect(contrastRatio(tk.onAccent, tk.accent), greaterThanOrEqualTo(3.0), reason: 'onAccent sobre accent');
        });
      }
    }

    test('clientAccentInk (≥ 4,5:1) corrige o contraste do laranja de marca sobre branco', () {
      final light = AppTokens.light;
      final fill = contrastRatio(light.clientAccent, light.background);
      final ink = contrastRatio(light.clientAccentInk, light.background);
      final provider = contrastRatio(light.providerAccentInk, light.background);
      // ignore: avoid_print
      print(
        'GALERIA contraste acento/branco: fill=${fill.toStringAsFixed(2)}:1 '
        'clientAccentInk=${ink.toStringAsFixed(2)}:1 providerAccentInk=${provider.toStringAsFixed(2)}:1',
      );
      expect(ink, greaterThanOrEqualTo(4.5));
      expect(provider, greaterThanOrEqualTo(4.5));
    });
  });
}

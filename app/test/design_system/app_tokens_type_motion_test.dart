import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/app_tokens.dart';
import 'package:desperrengue_app/core/ui/design_system/tokens/app_breakpoints.dart';
import 'package:desperrengue_app/core/ui/design_system/tokens/app_motion.dart';
import 'package:desperrengue_app/core/ui/design_system/tokens/app_space.dart';
import 'package:desperrengue_app/core/ui/design_system/tokens/app_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppTokens _tokens(UserMode? mode, Brightness b) =>
    AppTheme.resolve(mode, b).extension<AppTokens>()!;

void main() {
  group('contraste dos pares de tokens (WCAG AA)', () {
    for (final b in Brightness.values) {
      for (final mode in <UserMode?>[null, UserMode.client, UserMode.provider]) {
        final label = '${b.name} / ${mode?.name ?? 'marca'}';
        test('texto e superfícies ≥ 4,5:1 — $label', () {
          final tk = _tokens(mode, b);
          for (final bg in [tk.background, tk.card, tk.surface]) {
            expect(AppTokens.contrast(tk.text, bg), greaterThanOrEqualTo(4.5), reason: 'text');
            expect(AppTokens.contrast(tk.textMuted, bg), greaterThanOrEqualTo(4.5), reason: 'textMuted');
            expect(AppTokens.contrast(tk.accentInk, bg), greaterThanOrEqualTo(4.5), reason: 'accentInk');
            expect(AppTokens.contrast(tk.dangerInk, bg), greaterThanOrEqualTo(4.5), reason: 'dangerInk');
            expect(AppTokens.contrast(tk.successInk, bg), greaterThanOrEqualTo(4.5), reason: 'successInk');
            expect(AppTokens.contrast(tk.warningInk, bg), greaterThanOrEqualTo(4.5), reason: 'warningInk');
          }
        });

        test('acento: onAccent sobre accent e accentInk sobre accentSoft — $label', () {
          final tk = _tokens(mode, b);
          expect(AppTokens.contrast(tk.onAccent, tk.accent), greaterThanOrEqualTo(4.5));
          expect(AppTokens.contrast(tk.accentInk, tk.accentSoft), greaterThanOrEqualTo(4.5));
        });

        test('tintas semânticas sobre o próprio fundo suave ≥ 4,5:1 — $label', () {
          final tk = _tokens(mode, b);
          expect(AppTokens.contrast(tk.successInk, tk.successSoft), greaterThanOrEqualTo(4.5));
          expect(AppTokens.contrast(tk.warningInk, tk.warningSoft), greaterThanOrEqualTo(4.5));
          expect(AppTokens.contrast(tk.dangerInk, tk.dangerSoft), greaterThanOrEqualTo(4.5));
          expect(AppTokens.contrast(AppTokens.onColor(tk.danger), tk.danger), greaterThanOrEqualTo(4.5));
        });

        test('esqueleto distinguível do cartão e shimmer mais claro que a base — $label', () {
          final tk = _tokens(mode, b);
          expect(AppTokens.contrast(tk.skeletonBase, tk.card), greaterThan(1.05));
          expect(tk.skeletonHighlight, isNot(tk.skeletonBase));
        });
      }
    }

    test('o acento laranja de PREENCHIMENTO continua 3:1 em ícones/bordas e a tinta fica ≥ 4,5:1', () {
      final tk = _tokens(UserMode.client, Brightness.light);
      expect(AppTokens.contrast(tk.accent, tk.background), greaterThanOrEqualTo(3.0));
      expect(AppTokens.contrast(tk.accentInk, tk.background), greaterThanOrEqualTo(4.5));
    });
  });

  group('elevação', () {
    test('claro: sombras de 2 camadas, nunca preto puro; escuro: elevação tonal sem sombra', () {
      final light = AppTokens.light;
      for (final level in [1, 2, 3]) {
        final s = light.elevation(level);
        expect(s.length, 2);
        for (final shadow in s) {
          expect(shadow.color.toARGB32() & 0x00FFFFFF, isNot(0x000000));
        }
      }
      expect(AppTokens.dark.elevation(1), isEmpty);
      expect(
        AppTokens.dark.surfaceAt(4).computeLuminance(),
        greaterThan(AppTokens.dark.card.computeLuminance()),
      );
    });
  });

  group('escala tipográfica (§2.1)', () {
    test('tamanhos/entrelinhas exatos e mínimos', () {
      expect(AppType.displayL.fontSize, 32);
      expect(AppType.displayL.height! * 32, closeTo(38, 0.001));
      expect(AppType.display.fontSize, 28);
      expect(AppType.headline.fontSize, 22);
      expect(AppType.title.fontSize, 18);
      expect(AppType.titleSm.fontSize, 16);
      expect(AppType.body.fontSize, 15);
      expect(AppType.bodySm.fontSize, 14);
      expect(AppType.caption.fontSize, 12.5);
      expect(AppType.button.fontSize, 16);
      expect(AppType.figureXl.fontSize, 36);
      expect(AppType.figure.fontSize, 28);
      expect(AppType.figureSm.fontSize, 20);
      for (final s in [
        AppType.displayL, AppType.display, AppType.headline, AppType.title, AppType.titleSm, AppType.body,
        AppType.bodyStrong, AppType.bodySm, AppType.caption, AppType.button, AppType.overline,
        AppType.figureXl, AppType.figure, AppType.figureSm,
      ]) {
        expect(s.fontSize, greaterThanOrEqualTo(AppType.minimumFontSize));
        expect({AppFonts.jakarta, AppFonts.inter}, contains(s.fontFamily));
      }
      for (final s in [AppType.body, AppType.bodyStrong, AppType.bodySm]) {
        expect(s.fontSize, greaterThanOrEqualTo(14));
      }
    });

    test('figure* usam algarismos tabulares e só pesos embarcados (Jakarta 700/800, Inter 400–700)', () {
      for (final s in [AppType.figureXl, AppType.figure, AppType.figureSm]) {
        expect(s.fontFeatures, contains(const FontFeature.tabularFigures()));
        expect(s.fontFamily, AppFonts.jakarta);
      }
      for (final s in [AppType.displayL, AppType.display, AppType.headline, AppType.title, AppType.button]) {
        expect(s.fontFamily, AppFonts.jakarta);
        expect([FontWeight.w700, FontWeight.w800], contains(s.fontWeight));
      }
      for (final s in [AppType.body, AppType.bodyStrong, AppType.bodySm, AppType.caption, AppType.overline]) {
        expect(s.fontFamily, AppFonts.inter);
        expect([FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700], contains(s.fontWeight));
      }
    });

    test('ThemeData define fontFamily e textTheme completo (Text sem estilo sai certo)', () {
      for (final b in Brightness.values) {
        final t = AppTheme.resolve(UserMode.client, b);
        expect(t.textTheme.bodyMedium!.fontFamily, AppFonts.inter);
        expect(t.textTheme.bodyMedium!.fontSize, 15);
        expect(t.textTheme.titleLarge!.fontFamily, AppFonts.jakarta);
        expect(t.textTheme.labelLarge!.fontWeight, FontWeight.w800);
        expect(t.appBarTheme.titleTextStyle!.fontFamily, AppFonts.jakarta);
        expect(t.textTheme.bodyMedium!.color, t.extension<AppTokens>()!.text);
      }
    });
  });

  group('grade, geometria e breakpoints', () {
    test('grade de 4 pt', () {
      for (final v in [AppSpace.s4, AppSpace.s8, AppSpace.s12, AppSpace.s16, AppSpace.s20, AppSpace.s24, AppSpace.s32, AppSpace.s40, AppSpace.s48]) {
        expect(v % 4, 0);
      }
      expect(AppGeometry.minTarget, 48);
      expect(AppGeometry.cardRadius, 20);
      expect(AppGeometry.sheetRadius, 28);
    });

    test('classificação por largura e margens 16/20/24', () {
      expect(AppBreakpoints.classify(320), AppWindowClass.compact);
      expect(AppBreakpoints.classify(359.9), AppWindowClass.compact);
      expect(AppBreakpoints.classify(360), AppWindowClass.regular);
      expect(AppBreakpoints.classify(599), AppWindowClass.regular);
      expect(AppBreakpoints.classify(600), AppWindowClass.medium);
      expect(AppBreakpoints.classify(899), AppWindowClass.medium);
      expect(AppBreakpoints.classify(900), AppWindowClass.expanded);
      expect(AppBreakpoints.marginFor(AppWindowClass.compact), 16);
      expect(AppBreakpoints.marginFor(AppWindowClass.regular), 20);
      expect(AppBreakpoints.marginFor(AppWindowClass.medium), 24);
      expect(AppBreakpoints.marginFor(AppWindowClass.expanded), 24);
    });

    testWidgets('context.layout reflete largura e escala de fonte', (t) async {
      late AppLayout layout;
      await t.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(1.4)),
        child: Builder(builder: (c) {
          layout = c.layout;
          return const SizedBox();
        }),
      ));
      expect(layout.isCompact, isTrue);
      expect(layout.margin, 16);
      expect(layout.isLargeText, isTrue);
      expect(layout.isWide, isFalse);
    });
  });

  group('movimento (§3.1)', () {
    test('orçamentos de duração', () {
      expect(AppMotion.tap.inMilliseconds, lessThanOrEqualTo(120));
      expect(AppMotion.tapRelease.inMilliseconds, lessThanOrEqualTo(160));
      expect(AppMotion.tapScale, 0.97);
      expect(AppMotion.page.inMilliseconds, 200);
      expect(AppMotion.pageReverse.inMilliseconds, 160);
      expect(AppMotion.pageOffset, 8);
      expect(AppMotion.sheet.inMilliseconds, 220);
      expect(AppMotion.sheetReverse.inMilliseconds, 180);
      expect(AppMotion.fade.inMilliseconds, inInclusiveRange(120, 160));
      expect(AppMotion.count.inMilliseconds, 250);
      expect(AppMotion.stagger.inMilliseconds, 160);
      expect(AppMotion.staggerDelay.inMilliseconds, 24);
      expect(AppMotion.staggerMax, 6);
      expect(AppMotion.skeleton.inMilliseconds, 1200);
      expect(AppMotion.skeletonToContent.inMilliseconds, 140);
    });

    testWidgets('AppMotion.d zera a duração com disableAnimations', (t) async {
      late Duration d;
      await t.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(builder: (c) {
          d = AppMotion.d(c, AppMotion.page);
          return const SizedBox();
        }),
      ));
      expect(d, Duration.zero);
    });
  });
}

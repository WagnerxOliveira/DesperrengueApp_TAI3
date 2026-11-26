import 'package:desperrengue_app/core/services/welcome_cinema_tracker.dart';
import 'package:desperrengue_app/core/ui/app_tokens.dart';
import 'package:desperrengue_app/core/ui/typography/cinema_type_scale.dart';
import 'package:desperrengue_app/features/auth/presentation/desperrengue_welcome_cinema_screen.dart';
import 'package:desperrengue_app/features/auth/presentation/widgets/cinema_card_parts.dart';
import 'package:desperrengue_app/features/auth/presentation/widgets/cinema_motion.dart';
import 'package:desperrengue_app/features/auth/presentation/widgets/story_nav_circle_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/cinema_test_helpers.dart';

/// v2.27.0 — Tipografia premium, botões de navegação idênticos e cards internos.
/// Contrato: seção 3 ("Testes obrigatórios") do prompt mestre.

const Size _kPhone = Size(390, 844);

/// Emojis/glifos proibidos em `Text` (renderizam diferente em cada plataforma).
final RegExp _kForbiddenGlyphs = RegExp(
  '[\u{1F300}-\u{1FAFF}\u2600-\u27BF\u2B50\u2605\u2713\u2714\uFE0F]',
  unicode: true,
);

/// Valor numérico/monetário/percentual isolado (deve usar algarismos tabulares).
final RegExp _kNumericValue = RegExp(r'^(R\$\s)?\d[\d.,]*%?$');

Finder _btn(String key) => find.byKey(Key(key));

/// Cor sólida do primeiro fundo opaco encontrado subindo a árvore (mistura
/// sobre branco quando semitransparente); porcelana (#FFFFFF) por padrão.
Color _backgroundBehind(Element element) {
  Color? found;
  element.visitAncestorElements((a) {
    final w = a.widget;
    Color? c;
    if (w is DecoratedBox && w.decoration is BoxDecoration) {
      final d = w.decoration as BoxDecoration;
      c = d.color;
      final g = d.gradient;
      if (c == null && g is LinearGradient && g.colors.isNotEmpty) {
        c = g.colors.first;
      }
    } else if (w is ColoredBox) {
      c = w.color;
    }
    if (c != null && c.a > 0.5) {
      found = c;
      return false;
    }
    return true;
  });
  return Color.alphaBlend(found ?? Colors.white, Colors.white);
}

BoxDecoration _glassOf(WidgetTester tester, Finder button) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: button, matching: find.byType(DecoratedBox)).first,
  );
  return box.decoration as BoxDecoration;
}

BoxDecoration _ringOf(WidgetTester tester, Finder button) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: button, matching: find.byType(DecoratedBox)).last,
  );
  return box.decoration as BoxDecoration;
}

double _outerOpacity(WidgetTester tester, Finder button) => tester
    .widget<AnimatedOpacity>(
      find
          .descendant(of: button, matching: find.byType(AnimatedOpacity))
          .first,
    )
    .opacity;

double _ringOpacity(WidgetTester tester, Finder button) => tester
    .widget<AnimatedOpacity>(
      find
          .descendant(of: button, matching: find.byType(AnimatedOpacity))
          .last,
    )
    .opacity;

/// Percorre a etapa em 3 instantes (entrada, demonstração, repouso) e devolve
/// os textos de cada instante.
Future<List<List<CinemaTextInfo>>> _sampleStory(
  WidgetTester tester,
  int story,
) async {
  final samples = <List<CinemaTextInfo>>[];
  await goToStory(tester, story);
  samples.add(collectCinemaTexts(tester));
  await tester.pump(const Duration(milliseconds: 900));
  samples.add(collectCinemaTexts(tester));
  await tester.pump(const Duration(milliseconds: 2600));
  samples.add(collectCinemaTexts(tester));
  await tester.pump(const Duration(milliseconds: 1500));
  samples.add(collectCinemaTexts(tester));
  return samples;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadCinemaFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    WelcomeCinemaTracker.resetMemoryStateForTesting();
  });

  // ---------------------------------------------------------------------------
  group('1. Paridade dos botões `<` e `>` (StoryNavCircleButton)', () {
    testWidgets(
      'btn-story-prev e btn-story-next: mesmo Size 56x56, mesma decoração, mesmo ícone/Tooltip/Semantics em TODAS as etapas',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpCinema(tester, size: _kPhone);
        final prev = _btn('btn-story-prev');
        final next = _btn('btn-story-next');

        for (var story = 0; story < 6; story++) {
          await goToStory(tester, story);
          await tester.pump(const Duration(milliseconds: 400));

          expect(prev, findsOneWidget, reason: '`<` nunca some (etapa ${story + 1})');
          expect(next, findsOneWidget, reason: '`>` nunca some (etapa ${story + 1})');

          // Mesmo Size 56x56
          expect(tester.getSize(prev), const Size(56, 56));
          expect(tester.getSize(next), const Size(56, 56));
          expect(
            tester.widget<StoryNavCircleButton>(prev).runtimeType,
            tester.widget<StoryNavCircleButton>(next).runtimeType,
            reason: 'um único widget para os dois lados',
          );

          // Mesma decoração (vidro 0.14 + borda 0.34, círculo) e mesmo anel de foco
          final prevGlass = _glassOf(tester, prev);
          final nextGlass = _glassOf(tester, next);
          expect(prevGlass, equals(nextGlass));
          expect(prevGlass.shape, BoxShape.circle);
          expect(prevGlass.color, const Color(0x24FFFFFF));
          expect(prevGlass.border, Border.all(color: const Color(0x57FFFFFF)));
          expect(_ringOf(tester, prev), equals(_ringOf(tester, next)));
          expect(prevGlass.boxShadow, isNull, reason: 'sem sombra pesada');

          // Ícones espelhados, mesmo tamanho (30) e mesma cor (#F8FAFC)
          final prevIcon = tester.widget<Icon>(
            find.descendant(of: prev, matching: find.byType(Icon)),
          );
          final nextIcon = tester.widget<Icon>(
            find.descendant(of: next, matching: find.byType(Icon)),
          );
          expect(prevIcon.icon, Icons.chevron_left_rounded);
          expect(nextIcon.icon, Icons.chevron_right_rounded);
          expect(prevIcon.size, 30);
          expect(nextIcon.size, 30);
          expect(prevIcon.color, const Color(0xFFF8FAFC));
          expect(nextIcon.color, const Color(0xFFF8FAFC));

          // Tooltip + Semantics idênticos em estrutura, em português
          expect(
            tester
                .widget<Tooltip>(
                  find.descendant(of: prev, matching: find.byType(Tooltip)),
                )
                .message,
            'Voltar',
          );
          expect(
            tester
                .widget<Tooltip>(
                  find.descendant(of: next, matching: find.byType(Tooltip)),
                )
                .message,
            'Próximo',
          );
          final prevSem = tester.getSemantics(prev);
          final nextSem = tester.getSemantics(next);
          expect(prevSem.label, 'Voltar');
          expect(nextSem.label, 'Próximo');
          expect(prevSem.hasFlag(SemanticsFlag.isButton), isTrue);
          expect(nextSem.hasFlag(SemanticsFlag.isButton), isTrue);
          expect(prevSem.rect.size, nextSem.rect.size);

          // Os rótulos NÃO aparecem mais como texto visual
          expect(find.text('Próximo'), findsNothing);
          expect(find.text('Voltar'), findsNothing);
          expect(find.bySemanticsLabel('Voltar'), findsOneWidget);
          expect(find.bySemanticsLabel('Próximo'), findsOneWidget);

          // Estado: `<` desabilitado na 1 / `>` desabilitado na 6 (opacidade .35)
          final prevEnabled = story > 0;
          final nextEnabled = story < 5;
          expect(_outerOpacity(tester, prev), prevEnabled ? 1.0 : 0.35);
          expect(_outerOpacity(tester, next), nextEnabled ? 1.0 : 0.35);
          expect(
            prevSem.hasFlag(SemanticsFlag.isEnabled),
            prevEnabled,
            reason: 'semântica de `<` na etapa ${story + 1}',
          );
          expect(
            nextSem.hasFlag(SemanticsFlag.isEnabled),
            nextEnabled,
            reason: 'semântica de `>` na etapa ${story + 1}',
          );
        }
        semantics.dispose();
      },
    );

    testWidgets(
      'zero pulo de layout: `<` e `>` ficam na MESMA posição nas etapas 1, 2, ..., 6 e os 6 pontos ficam centralizados entre eles',
      (tester) async {
        await pumpCinema(tester, size: _kPhone);
        final prev = _btn('btn-story-prev');
        final next = _btn('btn-story-next');
        final dots = _btn('story-pagination-dots');

        final prevPos = tester.getTopLeft(prev);
        final nextPos = tester.getTopLeft(next);

        for (var story = 0; story < 6; story++) {
          await goToStory(tester, story);
          await tester.pump(const Duration(milliseconds: 400));
          expect(
            tester.getTopLeft(next),
            nextPos,
            reason: '`>` pulou na etapa ${story + 1}',
          );
          expect(
            tester.getTopLeft(prev),
            prevPos,
            reason: '`<` pulou na etapa ${story + 1}',
          );
          final prevRect = tester.getRect(prev);
          final nextRect = tester.getRect(next);
          final dotsRect = tester.getRect(dots);
          expect(
            dotsRect.center.dx,
            closeTo((prevRect.right + nextRect.left) / 2, 0.5),
            reason: 'pontos descentralizados na etapa ${story + 1}',
          );
          expect(dotsRect.center.dy, closeTo(prevRect.center.dy, 1.0));
          expect(prevRect.center.dy, closeTo(nextRect.center.dy, 0.01));
        }
      },
    );

    testWidgets(
      'Etapa 6: `btn-story-start` (Começar agora, 56dp, aurora) existe só nela, fica ACIMA da linha `<` `>` e o `>` fica desabilitado',
      (tester) async {
        var completed = 0;
        await pumpCinema(
          tester,
          size: _kPhone,
          onCompleted: () => completed++,
        );
        final start = _btn('btn-story-start');

        for (var story = 0; story < 5; story++) {
          await goToStory(tester, story);
          expect(start, findsNothing, reason: 'CTA só na etapa 6');
        }
        await goToStory(tester, 5);
        await tester.pump(const Duration(milliseconds: 600));
        expect(start, findsOneWidget);
        expect(
          find.descendant(of: start, matching: find.text('Começar agora')),
          findsOneWidget,
        );
        expect(tester.getSize(start).height, 56);
        expect(
          tester.getSize(start).width,
          greaterThan(240),
          reason: 'largura total do palco',
        );
        expect(
          tester.getRect(start).bottom,
          lessThanOrEqualTo(tester.getRect(_btn('btn-story-prev')).top),
          reason: 'CTA acima da linha de navegação',
        );

        // Aurora #6EE7B7 -> #A7F3D0 -> #FDE68A -> #FDBA74 e texto #0B1320 w800 16sp
        final deco = tester
            .widget<DecoratedBox>(
              find
                  .descendant(of: start, matching: find.byType(DecoratedBox))
                  .first,
            )
            .decoration as BoxDecoration;
        expect(
          (deco.gradient! as LinearGradient).colors,
          const <Color>[
            Color(0xFF6EE7B7),
            Color(0xFFA7F3D0),
            Color(0xFFFDE68A),
            Color(0xFFFDBA74),
          ],
        );
        final ctaText = tester.widget<Text>(
          find.descendant(of: start, matching: find.text('Começar agora')),
        );
        final ctaStyle = DefaultTextStyle.of(
          tester.element(find.descendant(of: start, matching: find.byType(Text))),
        ).style.merge(ctaText.style);
        expect(ctaStyle.fontSize, 16);
        expect(ctaStyle.fontWeight, FontWeight.w800);
        expect(ctaStyle.color, const Color(0xFF0B1320));

        // `>` desabilitado: tocar não conclui
        await tester.tap(_btn('btn-story-next'), warnIfMissed: false);
        await tester.pump();
        expect(completed, 0);

        // CTA conclui
        await tester.tap(start);
        await tester.pump();
        expect(completed, 1);
      },
    );

    testWidgets(
      'toque em `>`/`<` navega; `<` na etapa 1 desabilitado não faz nada; pressionado aplica escala 0.94 e solta de volta a 1.0',
      (tester) async {
        await pumpCinema(tester, size: _kPhone);
        final prev = _btn('btn-story-prev');
        final next = _btn('btn-story-next');

        await tester.tap(prev, warnIfMissed: false);
        await tester.pump();
        expect(find.byKey(const Key('cinema-story-1')), findsOneWidget);

        await tester.tap(next);
        await tester.pump();
        expect(find.byKey(const Key('cinema-story-2')), findsOneWidget);
        await tester.tap(prev);
        await tester.pump();
        expect(find.byKey(const Key('cinema-story-1')), findsOneWidget);

        final scaleFinder = find.descendant(
          of: next,
          matching: find.byType(ScaleTransition),
        );
        expect(tester.widget<ScaleTransition>(scaleFinder).scale.value, 1.0);
        final g = await tester.startGesture(tester.getCenter(next));
        // 1º pump dispara o onTapDown (timer de 100ms); o 2º inicia a mola (ticker)
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          tester.widget<ScaleTransition>(scaleFinder).scale.value,
          closeTo(0.94, 0.012),
        );
        await g.up();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          tester.widget<ScaleTransition>(scaleFinder).scale.value,
          closeTo(1.0, 0.005),
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  group('2. Tipografia embarcada (Plus Jakarta Sans / Inter) nas 6 etapas', () {
    testWidgets(
      'nenhum Text < 12.5sp; corpo >= 14sp; fontFamily ∈ {PlusJakartaSans, Inter}; números com tabularFigures; zero emoji 🔒★✓',
      (tester) async {
        await pumpCinema(tester, size: _kPhone);
        final violations = <String>[];

        for (var story = 0; story < 6; story++) {
          final samples = await _sampleStory(tester, story);
          for (final (sampleIdx, texts) in samples.indexed) {
            expect(texts, isNotEmpty, reason: 'etapa ${story + 1} sem texto');
            for (final t in texts) {
              final where = 'etapa ${story + 1}/amostra $sampleIdx $t';
              if (t.fontSize < CinemaType.minimumFontSize) {
                violations.add('fontSize < 12.5: $where');
              }
              // Corpo (texto com mais de 20 caracteres) >= 14sp
              if (t.content.trim().length > 20 && t.fontSize < 14) {
                violations.add('corpo < 14sp: $where');
              }
              if (!kCinemaAllowedFontFamilies.contains(t.family)) {
                violations.add('fontFamily fora da marca (${t.family}): $where');
              }
              if (_kNumericValue.hasMatch(t.content.trim()) && !t.isTabular) {
                violations.add('valor numérico sem tabularFigures: $where');
              }
              if (_kForbiddenGlyphs.hasMatch(t.content)) {
                violations.add('emoji/glifo proibido em Text: $where');
              }
              if (t.style.fontStyle == FontStyle.italic) {
                violations.add('itálico sintético (sem fonte itálica): $where');
              }
            }
          }
        }
        expect(violations.toSet().toList(), isEmpty, reason: violations.toSet().join('\n'));
      },
    );

    testWidgets(
      'o fontSize declarado não varia com o modo compacto (320x640 vs 390x844 vs 1080x2400) — a fonte só segue o TextScaler',
      (tester) async {
        final sizesByViewport = <String, Map<String, double>>{};
        for (final vp in const <CinemaViewport>[
          (size: Size(320, 640), dpr: 1.0, scale: 1.0, label: 'compacto'),
          (size: Size(390, 844), dpr: 1.0, scale: 1.0, label: 'normal'),
          (size: Size(1080, 2400), dpr: 2.75, scale: 1.0, label: 'alto'),
        ]) {
          await pumpCinema(
            tester,
            size: vp.size,
            dpr: vp.dpr,
            key: ValueKey('typo-compact-${vp.label}'),
          );
          final map = <String, double>{};
          for (var story = 0; story < 6; story++) {
            await goToStory(tester, story);
            await settleStory(tester);
            for (final t in collectCinemaTexts(tester)) {
              map['${story + 1}|${t.content}'] = t.fontSize;
            }
          }
          sizesByViewport[vp.label] = map;
        }
        final base = sizesByViewport['normal']!;
        for (final label in const <String>['compacto', 'alto']) {
          for (final entry in sizesByViewport[label]!.entries) {
            if (!base.containsKey(entry.key)) continue;
            expect(
              entry.value,
              base[entry.key],
              reason: 'fontSize de "${entry.key}" mudou em $label',
            );
          }
        }
      },
    );

    testWidgets(
      'tokens de CinemaType respeitam a escala do contrato (display 30/36, lead 16/24, rowTitle 15/22, caption 12.5/18, figure 32/38 tabular, button 16/20)',
      (tester) async {
        expect(CinemaType.display.fontSize, 30);
        expect(CinemaType.display.height, closeTo(36 / 30, 1e-9));
        expect(CinemaType.display.fontFamily, 'PlusJakartaSans');
        expect(CinemaType.display.fontWeight, FontWeight.w800);
        expect(CinemaType.lead.fontSize, 16);
        expect(CinemaType.lead.height, closeTo(24 / 16, 1e-9));
        expect(CinemaType.lead.fontFamily, 'Inter');
        expect(CinemaType.cardTitle.fontSize, 18);
        expect(CinemaType.rowTitle.fontSize, 15);
        expect(CinemaType.rowTitle.fontWeight, FontWeight.w600);
        expect(CinemaType.caption.fontSize, 12.5);
        expect(CinemaType.minimumFontSize, 12.5);
        expect(CinemaType.figure.fontSize, 32);
        expect(CinemaType.figureSm.fontSize, 20);
        expect(CinemaType.button.fontSize, 16);
        expect(CinemaType.button.fontWeight, FontWeight.w800);
        for (final style in <TextStyle>[
          CinemaType.figure,
          CinemaType.figureXl,
          CinemaType.figureSm,
        ]) {
          expect(
            style.fontFeatures,
            contains(const FontFeature.tabularFigures()),
          );
        }
        for (final style in <TextStyle>[
          CinemaType.display,
          CinemaType.lead,
          CinemaType.cardTitle,
          CinemaType.rowTitle,
          CinemaType.rowMeta,
          CinemaType.figure,
          CinemaType.figureXl,
          CinemaType.figureSm,
          CinemaType.caption,
          CinemaType.button,
          CinemaType.chrome,
          CinemaType.inputText,
        ]) {
          expect(style.fontSize, greaterThanOrEqualTo(12.5));
          expect(<String?>['PlusJakartaSans', 'Inter'], contains(style.fontFamily));
        }
      },
    );

    testWidgets(
      'zero emoji/glifos 🔒★✓ também em Tooltip e Semantics da apresentação',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpCinema(tester, size: _kPhone);
        for (var story = 0; story < 6; story++) {
          await goToStory(tester, story);
          await settleStory(tester);
          for (final e in find.byType(Tooltip).evaluate()) {
            final msg = (e.widget as Tooltip).message ?? '';
            expect(_kForbiddenGlyphs.hasMatch(msg), isFalse, reason: msg);
          }
          for (final e in find.byType(RichText).evaluate()) {
            final plain = (e.widget as RichText).text.toPlainText();
            // Ícones Material usam glifos de fonte própria (MaterialIcons); ignorar
            final style = (e.widget as RichText).text.style;
            if (style?.fontFamily == 'MaterialIcons' ||
                style?.fontFamily == 'MaterialIcons-Round') {
              continue;
            }
            expect(_kForbiddenGlyphs.hasMatch(plain), isFalse, reason: plain);
          }
        }
        semantics.dispose();
      },
    );
  });

  // ---------------------------------------------------------------------------
  group('3. Geometria (grade de 4 pt, itens >= 56, alvos >= 48)', () {
    testWidgets(
      'itens de lista (CinemaListRow) têm altura >= 56, padding 16/12 e ícones/emblemas em contêiner 40x40',
      (tester) async {
        await pumpCinema(tester, size: _kPhone);
        const expectedRows = <int, int>{0: 3, 1: 3, 3: 2};
        for (final entry in expectedRows.entries) {
          await goToStory(tester, entry.key);
          await settleStory(tester);
          final rows = find.byType(CinemaListRow);
          expect(
            rows,
            findsNWidgets(entry.value),
            reason: 'etapa ${entry.key + 1}: itens de lista',
          );
          for (final row in rows.evaluate()) {
            final size = tester.getSize(find.byWidget(row.widget));
            expect(
              size.height,
              greaterThanOrEqualTo(56),
              reason: 'item de lista da etapa ${entry.key + 1} com ${size.height}dp',
            );
            final padding = tester.widget<Padding>(
              find
                  .descendant(
                    of: find.byWidget(row.widget),
                    matching: find.byType(Padding),
                  )
                  .first,
            );
            expect(
              padding.padding,
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            );
          }
        }

        // Emblemas da etapa 1 em 40x40 (CinemaGeometry.iconTileSize)
        await goToStory(tester, 0);
        await settleStory(tester);
        for (final e in find.byType(SizedBox).evaluate()) {
          final w = e.widget as SizedBox;
          if (w.width == 40 && w.height == 40) {
            expect(tester.getSize(find.byWidget(w)), const Size(40, 40));
          }
        }
        expect(CinemaGeometry.iconTileSize, 40);
        expect(CinemaGeometry.itemMinHeight, 56);
        expect(CinemaGeometry.itemRadius, 16);
        expect(CinemaGeometry.heroRadius, 28);
        expect(CinemaGeometry.heroPadding, 20);
      },
    );

    testWidgets(
      'paddings e gaps dentro do card herói pertencem à escala de 4 pt (4·8·12·16·20·24·32), nas 6 etapas',
      (tester) async {
        await pumpCinema(tester, size: _kPhone);
        final offenders = <String>[];
        for (var story = 0; story < 6; story++) {
          await goToStory(tester, story);
          await settleStory(tester);
          final hero = find.byType(WelcomeStoryHeroCard);
          for (final e in find
              .descendant(of: hero, matching: find.byType(Padding))
              .evaluate()) {
            final p = (e.widget as Padding).padding;
            if (p is! EdgeInsets) continue;
            for (final v in <double>[p.left, p.top, p.right, p.bottom]) {
              if (v != 0 && !onFourPointScale(v)) {
                offenders.add('etapa ${story + 1}: Padding $p');
              }
            }
          }
          for (final e in find
              .descendant(of: hero, matching: find.byType(SizedBox))
              .evaluate()) {
            final w = e.widget as SizedBox;
            // Somente espaçadores puros (sem filho): gaps de layout
            if (w.child != null) continue;
            final gaps = <double?>[
              if (w.width != null && w.height == null) w.width,
              if (w.height != null && w.width == null) w.height,
            ];
            for (final g in gaps) {
              if (g != null && g != 0 && g != 1 && !onFourPointScale(g)) {
                offenders.add('etapa ${story + 1}: SizedBox gap $g');
              }
            }
          }
        }
        expect(offenders.toSet().toList(), isEmpty, reason: offenders.toSet().join('\n'));
      },
    );

    testWidgets(
      'alvos de toque >= 48dp: Pular, `<`, `>`, CTA, opções do switch e segmentos de capítulo',
      (tester) async {
        for (final vp in const <CinemaViewport>[
          (size: Size(320, 640), dpr: 1.0, scale: 1.0, label: '320x640'),
          (size: Size(390, 844), dpr: 1.0, scale: 1.0, label: '390x844'),
        ]) {
          await pumpCinema(
            tester,
            size: vp.size,
            key: ValueKey('targets-${vp.label}'),
          );

          void expect48(Finder f, String label) {
            expect(f, findsOneWidget, reason: label);
            final s = tester.getSize(f);
            expect(
              s.width,
              greaterThanOrEqualTo(48),
              reason: '$label largura ${s.width} em ${vp.label}',
            );
            expect(
              s.height,
              greaterThanOrEqualTo(48),
              reason: '$label altura ${s.height} em ${vp.label}',
            );
          }

          expect48(_btn('btn-skip-welcome-cinema'), 'Pular');
          expect48(_btn('btn-close-welcome-cinema'), 'Fechar apresentação');
          expect48(_btn('btn-story-prev'), '<');
          expect48(_btn('btn-story-next'), '>');
          for (var i = 0; i < 6; i++) {
            final bar = find.byKey(Key('cinema-chapter-tap-$i'));
            // Segmentos de capítulo (atalho de scrub): alvo >= 48dp de altura
            expect(
              tester.getSize(bar).height,
              greaterThanOrEqualTo(48),
              reason: 'segmento $i em ${vp.label}',
            );
          }
          await goToStory(tester, 5);
          await settleStory(tester);
          expect48(_btn('btn-story-start'), 'Começar agora');
          await tester.ensureVisible(_btn('dual-mode-luxury-switch'));
          await tester.pump();
          expect48(_btn('dual-mode-option-client'), 'Modo Cliente');
          expect48(_btn('dual-mode-option-provider'), 'Modo Profissional');
          expect(
            tester.getSize(_btn('dual-mode-luxury-switch')).height,
            greaterThanOrEqualTo(64),
            reason: 'switch segmentado com 64dp (${vp.label})',
          );
        }
      },
    );
  });

  // ---------------------------------------------------------------------------
  group('4. Escala de fonte e viewports (zero overflow, fonte nunca reduzida)', () {
    for (final vp in kCinemaMatrix) {
      testWidgets('zero RenderFlex overflow nas 6 etapas em ${vp.label}', (
        tester,
      ) async {
        await pumpCinema(
          tester,
          size: vp.size,
          dpr: vp.dpr,
          textScale: vp.scale,
          key: ValueKey('typo-matrix-${vp.label}'),
        );
        expect(tester.takeException(), isNull);

        for (var story = 0; story < 6; story++) {
          await goToStory(tester, story);
          expect(
            tester.takeException(),
            isNull,
            reason: 'abrir etapa ${story + 1} em ${vp.label}',
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull, reason: 'Ato 1 etapa ${story + 1} em ${vp.label}');
          await tester.pump(const Duration(milliseconds: 1350));
          expect(tester.takeException(), isNull, reason: 'Ato 2 etapa ${story + 1} em ${vp.label}');
          await tester.pump(const Duration(milliseconds: 2550));
          expect(tester.takeException(), isNull, reason: 'Ato 3 etapa ${story + 1} em ${vp.label}');

          // Nenhum texto fora da largura da tela (sem corte lateral)
          for (final t in collectCinemaTexts(tester)) {
            final box = t.element.renderObject! as RenderBox;
            if (!box.attached || !box.hasSize) continue;
            final rect = MatrixUtils.transformRect(
              box.getTransformTo(null),
              Offset.zero & box.size,
            );
            expect(
              rect.left,
              greaterThanOrEqualTo(-0.5),
              reason: '${t.content} cortado à esquerda em ${vp.label}',
            );
            expect(
              rect.right,
              lessThanOrEqualTo(vp.size.width / vp.dpr + 0.5),
              reason: '${t.content} cortado à direita em ${vp.label}',
            );
          }
        }

        // Web/desktop: cartão nunca estica (coluna central <= 480dp)
        final logicalWidth = vp.size.width / vp.dpr;
        if (logicalWidth >= 900) {
          await goToStory(tester, 0);
          await settleStory(tester);
          final hero = tester.getRect(find.byType(WelcomeStoryHeroCard));
          expect(
            hero.width,
            lessThanOrEqualTo(CinemaGeometry.maxColumnWidth + 0.5),
            reason: 'cartão esticado em ${vp.label}',
          );
          expect(
            hero.center.dx,
            closeTo(logicalWidth / 2, 1.0),
            reason: 'coluna central em ${vp.label}',
          );
        }
        expect(tester.takeException(), isNull);
      });
    }

    for (final storyIdx in List<int>.generate(6, (i) => i)) {
      testWidgets(
        'fonte NUNCA menor em 1.35x/1.5x do que em 1.0x (320x640, etapa ${storyIdx + 1})',
        (tester) async {
          final byScale = <double, Map<String, List<double>>>{};
          final declaredByScale = <double, Map<String, double>>{};
          for (final scale in const <double>[1.0, 1.35, 1.5]) {
            await pumpCinema(
              tester,
              size: const Size(320, 640),
              textScale: scale,
              key: ValueKey('typo-scale-$storyIdx-$scale'),
            );
            await goToStory(tester, storyIdx);
            await settleStory(tester);
            expect(tester.takeException(), isNull);
            final rendered = <String, List<double>>{};
            final declared = <String, double>{};
            for (final t in collectCinemaTexts(tester)) {
              rendered.putIfAbsent(t.content, () => <double>[]).add(t.renderedFontSize);
              declared[t.content] = t.fontSize;
            }
            byScale[scale] = rendered;
            declaredByScale[scale] = declared;
          }
          final base = byScale[1.0]!;
          for (final scale in const <double>[1.35, 1.5]) {
            for (final e in base.entries) {
              final scaled = byScale[scale]![e.key];
              if (scaled == null) continue;
              final baseMax = e.value.reduce((a, b) => a > b ? a : b);
              final scaledMax = scaled.reduce((a, b) => a > b ? a : b);
              expect(
                scaledMax,
                greaterThanOrEqualTo(baseMax),
                reason: '"${e.key}" encolheu em ${scale}x ($scaledMax < $baseMax)',
              );
              expect(
                declaredByScale[scale]![e.key]!,
                greaterThanOrEqualTo(declaredByScale[1.0]![e.key]!),
                reason: 'fontSize declarado de "${e.key}" reduzido em ${scale}x',
              );
              // O texto ampliado de fato cresce (respeita o TextScaler do sistema)
              expect(
                scaledMax,
                closeTo(baseMax * scale, 0.51),
                reason: '"${e.key}" não acompanhou o TextScaler ${scale}x',
              );
            }
          }
        },
      );
    }

    testWidgets(
      'TextScaler do sistema é limitado a 1.5x no palco (2.0x pedido ⇒ 1.5x aplicado), sem overflow',
      (tester) async {
        await pumpCinema(
          tester,
          size: const Size(360, 780),
          textScale: 2.0,
          key: const ValueKey('typo-clamp'),
        );
        for (var story = 0; story < 6; story++) {
          await goToStory(tester, story);
          await settleStory(tester);
          expect(tester.takeException(), isNull, reason: 'etapa ${story + 1} @2.0x');
          final title = collectCinemaTexts(tester)
              .firstWhere((t) => t.fontSize == CinemaType.display.fontSize);
          expect(title.renderedFontSize, closeTo(30 * 1.5, 0.01));
        }
      },
    );
  });

  // ---------------------------------------------------------------------------
  group('5. Isolamento 120 Hz — WelcomeStoryHeroCard.build() == 1 (inclui Lottie/flutter_animate)', () {
    for (final storyIdx in List<int>.generate(6, (i) => i)) {
      testWidgets(
        'etapa ${storyIdx + 1}: onActiveHeroBuild ⇒ buildCount == 1 em pump(3s) e em 190 frames x 16ms',
        (tester) async {
          // Sub-caso A: pump único de 3s
          final builds = <int, int>{};
          await pumpCinema(
            tester,
            size: _kPhone,
            key: ValueKey('iso-a-$storyIdx'),
            onActiveHeroBuild: (i) => builds[i] = (builds[i] ?? 0) + 1,
          );
          if (storyIdx > 0) {
            await goToStory(tester, storyIdx);
          }
          expect(builds[storyIdx], 1, reason: 'montagem inicial etapa ${storyIdx + 1}');
          await tester.pump(const Duration(seconds: 3));
          expect(
            builds[storyIdx],
            1,
            reason: 'rebuild do herói durante pump(3s) na etapa ${storyIdx + 1}',
          );
          expect(tester.takeException(), isNull);

          // Sub-caso B: 190 frames de 16ms
          builds.clear();
          await pumpCinema(
            tester,
            size: _kPhone,
            key: ValueKey('iso-b-$storyIdx'),
            onActiveHeroBuild: (i) => builds[i] = (builds[i] ?? 0) + 1,
          );
          if (storyIdx > 0) {
            await goToStory(tester, storyIdx);
          }
          expect(builds[storyIdx], 1);
          for (var f = 0; f < 190; f++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(
            builds[storyIdx],
            1,
            reason: 'rebuild do herói em 190 frames na etapa ${storyIdx + 1}',
          );
          // Repouso até o fim do tempo da etapa também sem rebuild
          await tester.pump(const Duration(seconds: 5));
          expect(builds[storyIdx], 1);
          expect(tester.takeException(), isNull);

          // Desmonta sem timers pendentes (Lottie / flutter_animate)
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'animações Lottie embarcadas (check_burst / lock_close / sparkle_soft) estão presentes nas etapas 1–3 e rodam sem rebuild do herói',
      (tester) async {
        final builds = <int, int>{};
        await pumpCinema(
          tester,
          size: _kPhone,
          key: const ValueKey('iso-lottie'),
          onActiveHeroBuild: (i) => builds[i] = (builds[i] ?? 0) + 1,
        );
        var etapasComLottie = 0;
        for (var story = 0; story < 6; story++) {
          await goToStory(tester, story);
          for (var f = 0; f < 120; f++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          if (find.byType(CinemaLottie).evaluate().isNotEmpty) {
            etapasComLottie++;
            expect(
              find.byType(LottieBuilder),
              findsWidgets,
              reason: 'CinemaLottie sem LottieBuilder na etapa ${story + 1} (fallback ativo?)',
            );
          }
          expect(builds[story], 1, reason: 'etapa ${story + 1}');
        }
        expect(
          etapasComLottie,
          greaterThanOrEqualTo(3),
          reason: 'check_burst (1), lock_close (2) e sparkle_soft (3) esperados',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'reduce-motion (disableAnimations): estado final imediato com Lottie no último frame, sem timers e buildCount == 1',
      (tester) async {
        final builds = <int, int>{};
        await pumpCinema(
          tester,
          size: _kPhone,
          disableAnimations: true,
          key: const ValueKey('iso-reduce'),
          onActiveHeroBuild: (i) => builds[i] = (builds[i] ?? 0) + 1,
        );
        for (var story = 0; story < 6; story++) {
          await goToStory(tester, story);
          await tester.pump(const Duration(milliseconds: 50));
          expect(builds[story], 1);
          expect(tester.takeException(), isNull);
        }
        // Em repouso: nenhum Lottie animando
        for (final e in find.byType(LottieBuilder).evaluate()) {
          final w = e.widget as LottieBuilder;
          expect(w.repeat ?? true, isFalse, reason: 'Lottie em loop (zero repeat)');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });

  // ---------------------------------------------------------------------------
  group('7. Contraste WCAG dos textos do card herói (>= 4.5:1; >= 7:1 sobre porcelana)', () {
    testWidgets(
      'todo Text do card nas 6 etapas tem >= 4.5:1 contra o fundo real e >= 7:1 quando o fundo é porcelana/claro',
      (tester) async {
        await pumpCinema(tester, size: _kPhone);
        final fails = <String>[];
        var checked = 0;
        var porcelainChecked = 0;
        for (var story = 0; story < 6; story++) {
          await goToStory(tester, story);
          await settleStory(tester);
          final hero = find.byType(WelcomeStoryHeroCard);
          for (final e in find
              .descendant(of: hero, matching: find.byType(Text))
              .evaluate()) {
            final w = e.widget as Text;
            final content = w.data ?? w.textSpan?.toPlainText() ?? '';
            if (content.trim().isEmpty) continue;
            // A chave seletora tem cursor animado: coberta por pares explícitos no teste da UI.
            var insideSwitch = false;
            e.visitAncestorElements((a) {
              final k = a.widget.key;
              if (k is Key &&
                  (k.toString().contains('dual-mode-option') ||
                      k.toString().contains('dual-mode-luxury-switch'))) {
                insideSwitch = true;
                return false;
              }
              return true;
            });
            if (insideSwitch) continue;

            final style = DefaultTextStyle.of(e).style.merge(w.style);
            final fg = style.color ?? const Color(0xFF000000);
            final bg = _backgroundBehind(e);
            final fgOpaque = Color.alphaBlend(fg, bg);
            final ratio = AppTokens.contrast(fgOpaque, bg);
            checked++;
            final light = bg.computeLuminance() > 0.80;
            if (light) porcelainChecked++;
            final needed = light ? 7.0 : 4.5;
            if (ratio < needed) {
              fails.add(
                'etapa ${story + 1} "$content" fg=$fgOpaque bg=$bg => ${ratio.toStringAsFixed(2)}:1 (< $needed)',
              );
            }
          }
        }
        expect(checked, greaterThan(40));
        expect(porcelainChecked, greaterThan(25));
        expect(fails, isEmpty, reason: fails.join('\n'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  group('6. Web / teclado / foco visível / hover', () {
    testWidgets(
      '→ e Espaço avançam, ← volta, Esc conclui; ← na etapa 1 não faz nada',
      (tester) async {
        var completed = 0;
        await pumpCinema(
          tester,
          size: const Size(1280, 800),
          onCompleted: () => completed++,
          key: const ValueKey('kb-nav'),
        );
        bool active(int i) =>
            find.byKey(Key('cinema-story-${i + 1}')).evaluate().isNotEmpty;

        expect(active(0), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(active(0), isTrue, reason: '← na etapa 1 não faz nada');
        expect(completed, 0);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(active(1), isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(active(2), isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(active(1), isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(active(4), isTrue);
        expect(completed, 0);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(completed, 1, reason: 'Esc pula/fecha a apresentação');
      },
    );

    testWidgets(
      '→/Espaço na última etapa concluem exatamente 1 vez (comportamento do `>` do palco)',
      (tester) async {
        var completed = 0;
        await pumpCinema(
          tester,
          size: const Size(1280, 800),
          onCompleted: () => completed++,
          key: const ValueKey('kb-last'),
        );
        await goToStory(tester, 5);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(completed, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(completed, 1, reason: 'sem conclusão dupla');
      },
    );

    testWidgets(
      'foco visível: Tab leva o foco aos botões e o anel esmeralda 2px #A7F3D0 aparece; Enter/Espaço ativam o CTA',
      (tester) async {
        var completed = 0;
        await pumpCinema(
          tester,
          size: const Size(1280, 800),
          onCompleted: () => completed++,
          key: const ValueKey('kb-focus'),
        );
        final next = _btn('btn-story-next');
        expect(_ringOpacity(tester, next), 0.0);

        var focused = false;
        for (var i = 0; i < 10 && !focused; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump(const Duration(milliseconds: 200));
          focused = _ringOpacity(tester, next) == 1.0;
        }
        expect(focused, isTrue, reason: 'Tab nunca focou o `>`');
        final ring = _ringOf(tester, next);
        expect(ring.shape, BoxShape.circle);
        expect(ring.border, Border.all(color: const Color(0xFFA7F3D0), width: 2));

        // Enter com foco em `>` avança (ActivateIntent)
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(find.byKey(const Key('cinema-story-2')), findsOneWidget);

        // CTA da etapa 6: foco por Tab e ativação por Enter
        await goToStory(tester, 5);
        await tester.pump(const Duration(milliseconds: 600));
        final start = _btn('btn-story-start');
        bool startFocused() {
          final c = find.descendant(
            of: start,
            matching: find.byType(DecoratedBox),
          );
          final deco = tester.widget<DecoratedBox>(c.first).decoration
              as BoxDecoration;
          final shadow = deco.boxShadow?.first.color.a ?? 0;
          return shadow > 0.35;
        }

        var startOk = false;
        for (var i = 0; i < 12 && !startOk; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump(const Duration(milliseconds: 120));
          startOk = startFocused();
        }
        expect(startOk, isTrue, reason: 'foco/hover visível do CTA (brilho .42)');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(completed, 1);
      },
    );

    testWidgets(
      'hover (Web/desktop): cursor de mão e anel de foco sutil em `<`/`>` habilitados; desabilitado não mostra anel',
      (tester) async {
        await pumpCinema(
          tester,
          size: const Size(1280, 800),
          key: const ValueKey('hover'),
        );
        // Em navegador/desktop o modo de realce é "tradicional" (mouse/teclado);
        // no flutter_test o padrão é o de toque (Android) e suprimiria o hover.
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(
          () => FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.automatic,
        );
        await goToStory(tester, 2);
        await tester.pump(const Duration(milliseconds: 300));
        final next = _btn('btn-story-next');
        final prev = _btn('btn-story-prev');

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await tester.pump();

        await mouse.moveTo(tester.getCenter(next));
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.click,
        );
        expect(_ringOpacity(tester, next), 1.0);
        expect(_ringOpacity(tester, prev), 0.0);

        await mouse.moveTo(tester.getCenter(prev));
        await tester.pump(const Duration(milliseconds: 200));
        expect(_ringOpacity(tester, prev), 1.0);
        expect(_ringOpacity(tester, next), 0.0);

        // `<` desabilitado (etapa 1): sem anel e cursor padrão
        await goToStory(tester, 0);
        await tester.pump(const Duration(milliseconds: 300));
        await mouse.moveTo(tester.getCenter(prev) + const Offset(1, 1));
        await tester.pump(const Duration(milliseconds: 200));
        expect(_ringOpacity(tester, prev), 0.0);
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          isNot(SystemMouseCursors.click),
        );
        await mouse.moveTo(tester.getCenter(next));
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.click,
        );

        // Hover no botão discreto de fechar (`×`): cursor click e anel esmeralda #A7F3D0
        final closeBtn = _btn('btn-close-welcome-cinema');
        expect(_ringOpacity(tester, closeBtn), 0.0);
        await mouse.moveTo(tester.getCenter(closeBtn));
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.click,
        );
        expect(_ringOpacity(tester, closeBtn), 1.0);
      },
    );

    testWidgets(
      'perda de foco da aba (AppLifecycleState.paused) congela o cronômetro e retoma ao voltar (resumed)',
      (tester) async {
        await pumpCinema(
          tester,
          size: const Size(1280, 800),
          key: const ValueKey('lifecycle'),
        );
        await tester.pump(const Duration(seconds: 2));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        await tester.pump(const Duration(seconds: 15));
        expect(
          find.byKey(const Key('cinema-story-1')),
          findsOneWidget,
          reason: 'aba em segundo plano não pode avançar a apresentação',
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        await tester.pump(const Duration(seconds: 8));
        expect(find.byKey(const Key('cinema-story-1')), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        expect(find.byKey(const Key('cinema-story-2')), findsOneWidget);
      },
    );
  });
}

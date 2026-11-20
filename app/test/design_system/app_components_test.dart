import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/app_tokens.dart';
import 'package:desperrengue_app/core/ui/design_system/app_button.dart';
import 'package:desperrengue_app/core/ui/design_system/app_card.dart';
import 'package:desperrengue_app/core/ui/design_system/app_chrome.dart';
import 'package:desperrengue_app/core/ui/design_system/app_navigation.dart';
import 'package:desperrengue_app/core/ui/design_system/app_pressable.dart';
import 'package:desperrengue_app/core/ui/design_system/app_states.dart';
import 'package:desperrengue_app/core/ui/design_system/app_status.dart';
import 'package:desperrengue_app/core/ui/design_system/responsive_shell.dart';
import 'package:desperrengue_app/core/ui/widgets.dart' show InfoBanner, BannerTone, PulseRadar;
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(
  Widget child, {
  Brightness brightness = Brightness.light,
  UserMode? mode = UserMode.client,
  bool disableAnimations = false,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: AppTheme.resolve(mode, brightness),
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        disableAnimations: disableAnimations,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('AppButton', () {
    testWidgets('toca e dispara onPressed; alvo >= 48 de altura', (t) async {
      var n = 0;
      await t.pumpWidget(_app(AppButton(label: 'Continuar', onPressed: () => n++)));
      await t.tap(find.text('Continuar'));
      await t.pumpAndSettle();
      expect(n, 1);
      expect(t.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
    });

    testWidgets('loading bloqueia toque, mostra spinner de 20 px e mantém a largura', (t) async {
      await t.pumpWidget(_app(AppButton(label: 'Pagar agora', onPressed: () {}, expand: false)));
      final w0 = t.getSize(find.byType(FilledButton)).width;
      var n = 0;
      await t.pumpWidget(_app(AppButton(label: 'Pagar agora', onPressed: () => n++, loading: true, expand: false)));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(t.getSize(find.byType(CircularProgressIndicator)), const Size(20, 20));
      expect(t.getSize(find.byType(FilledButton)).width, w0);
      expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      await t.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(n, 0);
    });

    testWidgets('desabilitado: onPressed nulo e sem spinner', (t) async {
      await t.pumpWidget(_app(const AppButton(label: 'Enviar', onPressed: null)));
      expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('variantes usam o botão Material correspondente', (t) async {
      await t.pumpWidget(_app(Column(children: [
        AppButton(label: 'a', onPressed: () {}, variant: AppButtonVariant.secondary),
        AppButton(label: 'b', onPressed: () {}, variant: AppButtonVariant.tertiary),
        AppButton(label: 'c', onPressed: () {}, variant: AppButtonVariant.destructive),
      ])));
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('escala de toque 0,97 durante o pressionamento e volta a 1', (t) async {
      await t.pumpWidget(_app(AppButton(label: 'Tocar', onPressed: () {})));
      final gesture = await t.startGesture(t.getCenter(find.text('Tocar')));
      await t.pump(const Duration(milliseconds: 120));
      final scaleDown = t.widget<AnimatedScale>(find.byType(AnimatedScale).first).scale;
      expect(scaleDown, closeTo(0.97, 0.001));
      await gesture.up();
      await t.pumpAndSettle();
      expect(t.widget<AnimatedScale>(find.byType(AnimatedScale).first).scale, 1.0);
    });

    testWidgets('rótulo longo quebra em vez de cortar (escala 1,5, 320 px)', (t) async {
      await t.pumpWidget(_app(
        AppButton(label: 'Confirmar o serviço e liberar o pagamento protegido', onPressed: () {}),
        size: const Size(320, 640),
        textScale: 1.5,
      ));
      expect(t.takeException(), isNull);
      expect(find.textContaining('Confirmar o serviço'), findsOneWidget);
    });

    testWidgets('AppIconButton tem alvo 48×48', (t) async {
      await t.pumpWidget(_app(AppIconButton(icon: Icons.close_rounded, tooltip: 'Fechar', onPressed: () {})));
      expect(t.getSize(find.byType(IconButton)), const Size(48, 48));
    });
  });

  group('AppPressable', () {
    testWidgets('Enter ativa pelo teclado e o foco por teclado mostra o anel', (t) async {
      var n = 0;
      await t.pumpWidget(_app(AppPressable(onTap: () => n++, child: const SizedBox(width: 80, height: 48, child: Text('x')))));
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(n, 1);
      final ring = t.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).any(
            (c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).border != null,
          );
      expect(ring, isTrue);
    });

    testWidgets('desabilitado não reage e não dá erro', (t) async {
      await t.pumpWidget(_app(const AppPressable(onTap: null, child: SizedBox(width: 80, height: 48, child: Text('x')))));
      await t.tap(find.text('x'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('AppCard / AppListTile / AppInfoRow', () {
    testWidgets('AppCard: variantes renderizam, com onTap dispara', (t) async {
      var n = 0;
      await t.pumpWidget(_app(Column(children: [
        for (final v in AppCardVariant.values) AppCard(variant: v, child: Text(v.name)),
        AppCard(onTap: () => n++, child: const Text('tocar')),
      ])));
      await t.tap(find.text('tocar'));
      await t.pumpAndSettle();
      expect(n, 1);
      expect(t.takeException(), isNull);
    });

    testWidgets('AppCard no escuro não usa sombra (elevação tonal)', (t) async {
      await t.pumpWidget(_app(const AppCard(variant: AppCardVariant.elevated, child: Text('x')), brightness: Brightness.dark));
      final deco = t.widgetList<DecoratedBox>(find.byType(DecoratedBox)).map((d) => d.decoration).whereType<BoxDecoration>();
      expect(deco.any((d) => (d.boxShadow ?? const []).isNotEmpty), isFalse);
    });

    testWidgets('AppListTile: altura mínima 56 e leading 40×40', (t) async {
      await t.pumpWidget(_app(AppListTile(leadingIcon: Icons.wallet_rounded, title: 'Carteira', subtitle: 'Saldo', onTap: () {})));
      expect(t.getSize(find.byType(AppListTile)).height, greaterThanOrEqualTo(56));
      final tile = t.getSize(find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 40));
      expect(tile, const Size(40, 40));
    });

    testWidgets('AppInfoRow: lado a lado em escala 1,0 e em coluna em escala 1,5', (t) async {
      await t.pumpWidget(_app(const AppInfoRow(label: 'Prazo', value: 'Hoje, 14:00')));
      expect(t.getTopLeft(find.text('Hoje, 14:00')).dy, t.getTopLeft(find.text('Prazo')).dy);
      await t.pumpWidget(_app(const AppInfoRow(label: 'Prazo', value: 'Hoje, 14:00'), textScale: 1.5));
      expect(t.getTopLeft(find.text('Hoje, 14:00')).dy, greaterThan(t.getTopLeft(find.text('Prazo')).dy));
    });
  });

  group('status, preço, avaliação', () {
    testWidgets('AppStatusChip troca de rótulo com cross-fade e sem sobras', (t) async {
      await t.pumpWidget(_app(const AppStatusChip('Aberto', tone: AppTone.success)));
      await t.pumpWidget(_app(const AppStatusChip('Concluído', tone: AppTone.info)));
      await t.pumpAndSettle();
      expect(find.text('Aberto'), findsNothing);
      expect(find.text('Concluído'), findsOneWidget);
    });

    testWidgets('AppPrice mostra moeda e valor com algarismos tabulares', (t) async {
      await t.pumpWidget(_app(const AppPrice(value: 1234.5, size: AppPriceSize.lg)));
      final rich = t.widget<RichText>(find.descendant(of: find.byType(AppPrice), matching: find.byType(RichText)).first);
      final text = rich.text.toPlainText();
      expect(text, contains('R\$'));
      expect(text, contains('1.234,50'));
      var tabular = false;
      rich.text.visitChildren((s) {
        if (s is TextSpan && (s.style?.fontFeatures?.contains(const FontFeature.tabularFigures()) ?? false)) tabular = true;
        return true;
      });
      expect(tabular, isTrue);
    });

    testWidgets('AppRating interativo: alvos 48 e callback com a nota', (t) async {
      int? picked;
      await t.pumpWidget(_app(AppRating(value: 2, size: 24, onChanged: (v) => picked = v)));
      final star = t.getSize(find.byIcon(Icons.star_rounded).first);
      expect(star.width, lessThanOrEqualTo(48));
      expect(t.getSize(find.bySemanticsLabel('4 estrelas')), const Size(48, 48));
      await t.tap(find.bySemanticsLabel('4 estrelas'));
      await t.pumpAndSettle();
      expect(picked, 4);
    });
  });

  group('estados e esqueletos', () {
    testWidgets('AppEmptyState e AppErrorState: CTA e retry funcionam', (t) async {
      var a = 0;
      var r = 0;
      await t.pumpWidget(_app(Column(children: [
        SizedBox(height: 360, child: AppEmptyState(title: 'Nada por aqui', message: 'Volte depois', actionLabel: 'Pedir', onAction: () => a++)),
        SizedBox(height: 360, child: AppErrorState(message: 'Sem conexão', onRetry: () => r++)),
      ])));
      await t.tap(find.text('Pedir'));
      await t.ensureVisible(find.text('Tentar de novo'));
      await t.pumpAndSettle();
      await t.tap(find.text('Tentar de novo'));
      expect(a, 1);
      expect(r, 1);
    });

    testWidgets('esqueleto anima só enquanto montado e para com disableAnimations', (t) async {
      await t.pumpWidget(_app(const AppSkeletonList(count: 2)));
      await t.pump(const Duration(milliseconds: 600));
      expect(t.hasRunningAnimations, isTrue);
      await t.pumpWidget(_app(const AppSkeletonList(count: 2), disableAnimations: true));
      await t.pump();
      await t.pumpAndSettle(); // não pode ficar pendente
      expect(t.takeException(), isNull);
      await t.pumpWidget(_app(const SizedBox()));
      await t.pumpAndSettle();
      expect(t.hasRunningAnimations, isFalse);
    });

    testWidgets('AppSkeletonSwitcher: skeleton → conteúdo em 140 ms', (t) async {
      Widget build(bool loading) => _app(AppSkeletonSwitcher(
            loading: loading,
            skeleton: const AppSkeletonCard(height: 80),
            child: const Text('pronto'),
          ));
      await t.pumpWidget(build(true));
      expect(find.text('pronto'), findsNothing);
      await t.pumpWidget(build(false));
      await t.pump(const Duration(milliseconds: 150));
      expect(find.text('pronto'), findsOneWidget);
    });

    testWidgets('AppSkeleton* respeitam geometria e não estouram em 320 px / 1,5×', (t) async {
      await t.pumpWidget(_app(
        const Column(children: [AppSkeletonCard(), AppSkeletonText(lines: 3), AppSkeletonAvatar()]),
        size: const Size(320, 640),
        textScale: 1.5,
      ));
      expect(t.takeException(), isNull);
    });
  });

  group('navegação', () {
    testWidgets('tema usa o builder próprio: 200 ms ida, 160 ms volta, +8 px', (t) async {
      final theme = AppTheme.resolve(null, Brightness.light);
      final builders = theme.pageTransitionsTheme.builders;
      for (final p in [TargetPlatform.android, TargetPlatform.windows, TargetPlatform.linux]) {
        final b = builders[p]!;
        expect(b, isA<AppPageTransitionsBuilder>());
        expect(b.transitionDuration, const Duration(milliseconds: 200));
        expect(b.reverseTransitionDuration, const Duration(milliseconds: 160));
      }
      expect(builders[TargetPlatform.iOS], isA<CupertinoPageTransitionsBuilder>());
      expect((builders[TargetPlatform.android]! as AppPageTransitionsBuilder).predictiveBack, isTrue);
    });

    testWidgets('MaterialPageRoute herda a transição: abre em ~200 ms e fecha em ~160 ms', (t) async {
      final key = GlobalKey<NavigatorState>();
      await t.pumpWidget(MaterialApp(
        navigatorKey: key,
        theme: AppTheme.resolve(null, Brightness.light).copyWith(platform: TargetPlatform.android),
        home: const Scaffold(body: Text('A')),
      ));
      key.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('B'))));
      await t.pump();
      await t.pump(const Duration(milliseconds: 210));
      expect(t.hasRunningAnimations, isFalse);
      expect(find.text('B'), findsOneWidget);
      key.currentState!.pop();
      await t.pump();
      await t.pump(const Duration(milliseconds: 170));
      expect(t.hasRunningAnimations, isFalse);
      expect(find.text('B'), findsNothing);
    });

    testWidgets('AppRoute: fade-through com disableAnimations não deixa timers', (t) async {
      final key = GlobalKey<NavigatorState>();
      await t.pumpWidget(MaterialApp(
        navigatorKey: key,
        theme: AppTheme.resolve(null, Brightness.light),
        builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: child!),
        home: const Scaffold(body: Text('A')),
      ));
      key.currentState!.push(AppRoute<void>(builder: (_) => const Scaffold(body: Text('B')), fullscreenModal: true));
      await t.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
    });
  });

  group('chrome e shell', () {
    testWidgets('AppAppBar e AppBottomBar renderizam com título/nota que quebram', (t) async {
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.resolve(UserMode.provider, Brightness.dark),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            appBar: const AppAppBar(title: 'Detalhes do serviço contratado'),
            body: const SizedBox(),
            bottomNavigationBar: AppBottomBar(footnote: 'Pagamento protegido até a conclusão', child: AppButton(label: 'Aprovar', onPressed: () {})),
          ),
        ),
      ));
      expect(t.takeException(), isNull);
      expect(find.text('Pagamento protegido até a conclusão'), findsOneWidget);
    });

    test('ResponsiveShell: tela cheia ≤ 600, coluna 560 até 899, 520 em desktop', () {
      expect(ResponsiveShell.columnWidthFor(390), isNull);
      expect(ResponsiveShell.columnWidthFor(600), isNull);
      expect(ResponsiveShell.columnWidthFor(601), 560);
      expect(ResponsiveShell.columnWidthFor(899), 560);
      expect(ResponsiveShell.columnWidthFor(900), 520);
      expect(ResponsiveShell.columnWidthFor(1920), 520);
    });

    testWidgets('ResponsiveShell: em 1280×800 o app enxerga largura de 520 e exibe painel lateral', (t) async {
      late double w;
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.resolve(null, Brightness.light),
        home: ResponsiveShell(child: Builder(builder: (c) {
          w = MediaQuery.sizeOf(c).width;
          return const Scaffold(body: Text('conteúdo'));
        })),
      ));
      expect(w, 520);
      expect(t.getSize(find.byType(Scaffold)).width, 520);
      expect(find.byKey(const ValueKey('responsive_shell_side_panel')), findsOneWidget);
      expect(find.text('Pagamento protegido'), findsOneWidget);
      expect(find.text('Profissionais verificados'), findsOneWidget);
      expect(find.text('Endereço preservado'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('ResponsiveShell: sem overflow em 1040×600 @ 1,5× e sem painel em 920×800', (t) async {
      t.view.physicalSize = const Size(1040, 600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.resolve(UserMode.client, Brightness.dark),
        home: const MediaQuery(
          data: MediaQueryData(size: Size(1040, 600), textScaler: TextScaler.linear(1.5)),
          child: ResponsiveShell(child: Scaffold(body: Text('conteúdo'))),
        ),
      ));
      expect(find.byKey(const ValueKey('responsive_shell_side_panel')), findsOneWidget);
      expect(t.takeException(), isNull);

      t.view.physicalSize = const Size(920, 800);
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.resolve(UserMode.client, Brightness.light),
        home: const ResponsiveShell(child: Scaffold(body: Text('conteúdo'))),
      ));
      expect(find.byKey(const ValueKey('responsive_shell_side_panel')), findsNothing);
      expect(t.getSize(find.byType(Scaffold)).width, 520);
      expect(t.takeException(), isNull);
    });

    test('AppShellColors: contraste WCAG AA ≥ 4,5:1 no painel lateral desktop', () {
      for (final bg in [AppShellColors.brandBackdrop, AppShellColors.brandSurface]) {
        expect(AppTokens.contrast(AppShellColors.onBrand, bg), greaterThanOrEqualTo(4.5));
        expect(AppTokens.contrast(AppShellColors.onBrandMuted, bg), greaterThanOrEqualTo(4.5));
      }
      expect(ResponsiveShell.showsSidePanelFor(1039), isFalse);
      expect(ResponsiveShell.showsSidePanelFor(1040), isTrue);
    });

    testWidgets('Web/desktop: AppScrollBehavior exibe Scrollbar em desktop e tema aplica cursor/foco 2 px', (t) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.resolve(UserMode.client, Brightness.light).copyWith(platform: TargetPlatform.windows),
        scrollBehavior: const AppScrollBehavior(),
        home: Scaffold(
          body: ListView.builder(
            controller: controller,
            itemCount: 40,
            itemBuilder: (_, i) => SizedBox(height: 48, child: Text('Item $i')),
          ),
        ),
      ));
      expect(find.byType(Scrollbar), findsOneWidget);

      final theme = AppTheme.resolve(UserMode.client, Brightness.light);
      for (final style in [
        theme.filledButtonTheme.style!,
        theme.outlinedButtonTheme.style!,
        theme.textButtonTheme.style!,
        theme.iconButtonTheme.style!,
      ]) {
        expect(style.mouseCursor?.resolve(<WidgetState>{}), SystemMouseCursors.click);
        expect(style.side?.resolve(<WidgetState>{WidgetState.focused})?.width, 2);
      }
    });

    testWidgets('AppRating interativo: navegável por Tab e ativável por Enter', (t) async {
      int? picked;
      await t.pumpWidget(_app(AppRating(value: 0, size: 24, onChanged: (v) => picked = v)));
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(picked, 1);
    });

    testWidgets('PulseRadar e AppLoading param imediatamente com disableAnimations', (t) async {
      await t.pumpWidget(_app(
        const Column(children: [
          PulseRadar(size: 120, child: Icon(Icons.bolt_rounded)),
          AppLoading(message: 'Aguarde'),
        ]),
        disableAnimations: true,
      ));
      await t.pump();
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('InfoBanner usa tintas semânticas de alto contraste nos ícones', (t) async {
      await t.pumpWidget(_app(Column(children: [
        for (final tone in BannerTone.values) InfoBanner('Aviso ${tone.name}', tone: tone),
      ])));
      final tk = AppTokens.light;
      final icons = t.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons.any((i) => i.color == tk.warningInk), isTrue);
      expect(icons.any((i) => i.color == tk.successInk), isTrue);
      expect(icons.any((i) => i.color == tk.warning), isFalse);
    });
  });
}

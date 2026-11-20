import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/app_tokens.dart';
import 'package:desperrengue_app/core/ui/design_system/app_button.dart';
import 'package:desperrengue_app/core/ui/design_system/app_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Launch = Future<void> Function(BuildContext context);

Widget _host(
  _Launch launch, {
  Brightness brightness = Brightness.light,
  bool reduced = false,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: AppTheme.resolve(null, brightness),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduced,
        textScaler: TextScaler.linear(textScale),
      ),
      child: app!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(onPressed: () => launch(context), child: const Text('abrir')),
        ),
      ),
    ),
  );
}

void _expectNoSmallText(WidgetTester tester) {
  for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
    final size = w.text.style?.fontSize;
    if (size != null) {
      expect(size, greaterThanOrEqualTo(12.5), reason: 'texto "${w.text.toPlainText()}" abaixo de 12,5');
    }
  }
}

void main() {
  for (final brightness in Brightness.values) {
    group('AppSheet (${brightness.name})', () {
      Future<void> open(WidgetTester tester, {bool dismissible = true, bool reduced = false}) async {
        await tester.pumpWidget(_host(
          (context) => AppSheet.show<void>(
            context,
            title: 'Filtrar',
            subtitle: 'Escolha as opções',
            isDismissible: dismissible,
            enableDrag: dismissible,
            builder: (context) => const Text('conteúdo do sheet'),
            actions: [
              AppButton(label: 'Limpar', variant: AppButtonVariant.secondary, onPressed: () {}),
              AppButton(label: 'Aplicar', onPressed: () {}),
            ],
          ),
          brightness: brightness,
          reduced: reduced,
        ));
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
      }

      testWidgets('abre com cabeçalho, handle, rodapé e fecha com Esc', (tester) async {
        await open(tester);
        expect(find.text('Filtrar'), findsOneWidget);
        expect(find.text('Escolha as opções'), findsOneWidget);
        expect(find.text('conteúdo do sheet'), findsOneWidget);
        expect(find.byKey(const ValueKey('app-sheet-handle')), findsOneWidget);
        expect(tester.getSize(find.byKey(const ValueKey('app-sheet-handle'))), const Size(36, 4));
        expect(find.widgetWithText(FilledButton, 'Aplicar'), findsOneWidget);
        for (final b in tester.widgetList<ButtonStyleButton>(find.byWidgetPredicate((w) => w is ButtonStyleButton))) {
          expect(tester.getSize(find.byWidget(b)).height, greaterThanOrEqualTo(48));
        }
        _expectNoSmallText(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Filtrar'), findsNothing);
      });

      testWidgets('arrastar para baixo fecha', (tester) async {
        await open(tester);
        await tester.drag(find.byKey(const ValueKey('app-sheet-handle')), const Offset(0, 500));
        await tester.pumpAndSettle();
        expect(find.text('Filtrar'), findsNothing);
      });

      testWidgets('tocar no scrim fecha; não dispensável ignora Esc e scrim', (tester) async {
        await open(tester);
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        expect(find.text('Filtrar'), findsNothing);

        await open(tester, dismissible: false);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Filtrar'), findsOneWidget);
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        expect(find.text('Filtrar'), findsOneWidget);
      });

      testWidgets('conteúdo longo rola e o rodapé permanece visível', (tester) async {
        tester.view.physicalSize = const Size(400, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_host(
          (context) => AppSheet.show<void>(
            context,
            title: 'Lista',
            builder: (context) => Column(
              children: [for (var i = 0; i < 60; i++) SizedBox(height: 48, child: Text('item $i'))],
            ),
            actions: [AppButton(label: 'Concluir', onPressed: () {})],
          ),
          brightness: brightness,
        ));
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final footer = tester.getBottomLeft(find.widgetWithText(FilledButton, 'Concluir'));
        expect(footer.dy, lessThanOrEqualTo(700));
        await tester.drag(find.text('item 0'), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(FilledButton, 'Concluir'), findsOneWidget);
        expect(tester.getSize(find.byType(BottomSheet)).height, lessThanOrEqualTo(700 * 0.92 + 0.5));
      });

      testWidgets('com disableAnimations abre/fecha sem frames pendentes', (tester) async {
        await open(tester, reduced: true);
        expect(find.text('Filtrar'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        await tester.pump();
        expect(find.text('Filtrar'), findsNothing);
        expect(tester.binding.transientCallbackCount, 0);
      });
    });

    group('AppDialog (${brightness.name})', () {
      testWidgets('confirm retorna true ao confirmar e false ao voltar', (tester) async {
        bool? result;
        await tester.pumpWidget(_host(
          (context) async => result = await AppDialog.confirm(
            context,
            title: 'Cancelar pedido?',
            message: 'Você pode refazer depois.',
            confirmLabel: 'Cancelar pedido',
          ),
          brightness: brightness,
        ));
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        expect(find.text('Cancelar pedido?'), findsOneWidget);
        expect(find.text('Você pode refazer depois.'), findsOneWidget);
        _expectNoSmallText(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Cancelar pedido'));
        await tester.pumpAndSettle();
        expect(result, isTrue);

        result = null;
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, 'Voltar'));
        await tester.pumpAndSettle();
        expect(result, isFalse);

        result = null;
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Cancelar pedido?'), findsNothing);
        expect(result, isFalse);
      });

      testWidgets('destructive usa o botão destrutivo e botões lado a lado cabem', (tester) async {
        await tester.pumpWidget(_host(
          (context) => AppDialog.confirm(context, title: 'Excluir?', destructive: true, confirmLabel: 'Excluir'),
          brightness: brightness,
        ));
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        final buttons = tester.widgetList<AppButton>(find.byType(AppButton)).toList();
        expect(buttons.map((b) => b.variant), contains(AppButtonVariant.destructive));
        final back = tester.getRect(find.widgetWithText(OutlinedButton, 'Voltar'));
        final del = tester.getRect(find.widgetWithText(FilledButton, 'Excluir'));
        expect(back.top, del.top, reason: 'lado a lado');
        expect(back.height, greaterThanOrEqualTo(48));
      });

      testWidgets('escala alta empilha os botões sem overflow', (tester) async {
        await tester.pumpWidget(_host(
          (context) => AppDialog.confirm(context, title: 'Excluir este endereço?', confirmLabel: 'Excluir'),
          brightness: brightness,
          textScale: 2,
        ));
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        final back = tester.getRect(find.widgetWithText(OutlinedButton, 'Voltar'));
        final del = tester.getRect(find.widgetWithText(FilledButton, 'Excluir'));
        expect(del.top, lessThan(back.top), reason: 'primária no topo quando empilha');
        expect(tester.takeException(), isNull);
      });

      testWidgets('show com conteúdo, barrierDismissible=false e disableAnimations', (tester) async {
        await tester.pumpWidget(_host(
          (context) => AppDialog.show<void>(
            context,
            title: 'Aviso',
            content: const Text('corpo livre'),
            barrierDismissible: false,
            actions: [Builder(builder: (c) => AppButton(label: 'Entendi', onPressed: () => Navigator.of(c).pop()))],
          ),
          brightness: brightness,
          reduced: true,
        ));
        await tester.tap(find.text('abrir'));
        await tester.pump();
        await tester.pump();
        expect(find.text('corpo livre'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(find.text('Aviso'), findsOneWidget);
        await tester.tap(find.text('Entendi'));
        await tester.pumpAndSettle();
        expect(find.text('Aviso'), findsNothing);
        expect(tester.binding.transientCallbackCount, 0);
      });
    });

    group('AppSnackbar (${brightness.name})', () {
      testWidgets('mostra mensagem, ação e substitui a anterior', (tester) async {
        var undone = 0;
        await tester.pumpWidget(_host(
          (context) async {
            AppSnackbar.show(context, 'Primeira');
            AppSnackbar.show(
              context,
              'Pedido cancelado',
              kind: AppSnackKind.success,
              actionLabel: 'Desfazer',
              onAction: () => undone++,
            );
          },
          brightness: brightness,
        ));
        await tester.tap(find.text('abrir'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Pedido cancelado'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
        expect(find.text('Primeira'), findsNothing);
        _expectNoSmallText(tester);
        await tester.tap(find.text('Desfazer'));
        await tester.pump();
        expect(undone, 1);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      });

      testWidgets('contraste >= 4,5:1 em todos os tipos e semântica de região viva', (tester) async {
        final tk = brightness == Brightness.dark ? AppTokens.dark : AppTokens.light;
        for (final kind in AppSnackKind.values) {
          final bg = AppSnackbar.background(tk, kind);
          expect(AppTokens.contrast(bg, AppTokens.onColor(bg)), greaterThanOrEqualTo(4.5), reason: '$kind');
        }
        await tester.pumpWidget(_host(
          (context) async => AppSnackbar.show(context, 'Algo deu errado', kind: AppSnackKind.error),
          brightness: brightness,
        ));
        await tester.tap(find.text('abrir'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
        expect(
          tester.getSemantics(find.text('Algo deu errado')),
          containsSemantics(isLiveRegion: true),
        );
        await tester.pumpAndSettle(const Duration(seconds: 5));
      });
    });
  }
}

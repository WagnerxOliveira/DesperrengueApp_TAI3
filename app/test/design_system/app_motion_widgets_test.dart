import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/design_system/app_motion_widgets.dart';
import 'package:desperrengue_app/core/ui/design_system/tokens/app_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool reduced = false,
}) {
  return MaterialApp(
    theme: AppTheme.resolve(null, brightness),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: app!,
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
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

String _brl(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

Widget _count(double v) => AppCountText(value: v, format: _brl, style: AppType.figure);

/// Itens do tipo "pedido N" numa coluna; reconstrói sem recriar o scope.
Widget _items(int n, {Object? scope = 'lista-teste'}) => Column(
      children: [
        for (var i = 0; i < n; i++)
          AppStaggerItem(
            index: i,
            scope: scope,
            child: SizedBox(height: 40, child: Text('item $i')),
          ),
      ],
    );

bool _hasFade(WidgetTester tester, int index) => find
    .descendant(of: find.byType(AppStaggerItem).at(index), matching: find.byType(FadeTransition))
    .evaluate()
    .any((e) => (e.widget as FadeTransition).opacity.value < 1);

void main() {
  setUp(AppStaggerItem.reset);

  for (final brightness in Brightness.values) {
    group('AppCountText (${brightness.name})', () {
      testWidgets('1ª exibição mostra o valor final sem animar', (tester) async {
        await tester.pumpWidget(_host(_count(1234.5), brightness: brightness));
        expect(find.text('R\$ 1234,50'), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
        _expectNoSmallText(tester);
      });

      testWidgets('anima antigo→novo e termina com o texto exato', (tester) async {
        await tester.pumpWidget(_host(_count(100), brightness: brightness));
        await tester.pumpWidget(_host(_count(200), brightness: brightness));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final mid = tester.widget<Text>(find.textContaining('R\$')).data!;
        final v = double.parse(mid.substring(3).replaceAll(',', '.'));
        expect(v, inExclusiveRange(100, 200));
        await tester.pumpAndSettle();
        expect(find.text(_brl(200)), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
      });

      testWidgets('texto final == format(value) mesmo com ponto flutuante', (tester) async {
        String raw(double v) => v.toString();
        Widget w(double v) => AppCountText(value: v, format: raw);
        await tester.pumpWidget(_host(w(0.1), brightness: brightness));
        await tester.pumpWidget(_host(w(0.1 + 0.2), brightness: brightness));
        await tester.pumpAndSettle();
        expect(find.text(raw(0.1 + 0.2)), findsOneWidget);
      });

      testWidgets('usa algarismos tabulares e semântica só do valor final', (tester) async {
        await tester.pumpWidget(_host(_count(10), brightness: brightness));
        final style = tester.widget<Text>(find.text(_brl(10))).style!;
        expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
        expect(find.bySemanticsLabel(_brl(10)), findsOneWidget);
      });

      testWidgets('disableAnimations: troca instantânea e sem frames pendentes', (tester) async {
        await tester.pumpWidget(_host(_count(100), brightness: brightness, reduced: true));
        await tester.pumpWidget(_host(_count(200), brightness: brightness, reduced: true));
        await tester.pump();
        expect(find.text(_brl(200)), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
      });
    });

    group('AppStaggerItem / AppStagger (${brightness.name})', () {
      testWidgets('só os 6 primeiros animam (fade + 8 px) na 1ª exibição', (tester) async {
        await tester.pumpWidget(_host(_items(9), brightness: brightness));
        for (var i = 0; i < 6; i++) {
          expect(_hasFade(tester, i), isTrue, reason: 'item $i deve entrar animado');
        }
        for (var i = 6; i < 9; i++) {
          expect(
            find.descendant(of: find.byType(AppStaggerItem).at(i), matching: find.byType(FadeTransition)),
            findsNothing,
            reason: 'item $i não anima',
          );
        }
        // desloca 8 px no início (item 0).
        final top = tester.getTopLeft(find.text('item 0'));
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.getTopLeft(find.text('item 0')).dy, lessThan(top.dy + 8.01));
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.getTopLeft(find.text('item 0')).dy, closeTo(top.dy + 0, 8.01));
        for (var i = 0; i < 9; i++) {
          expect(find.text('item $i'), findsOneWidget);
        }
      });

      testWidgets('não repete ao reconstruir/recriar na mesma lista', (tester) async {
        await tester.pumpWidget(_host(_items(4), brightness: brightness));
        await tester.pumpAndSettle();
        // esvazia e recria (simula scroll/rebuild).
        await tester.pumpWidget(_host(const SizedBox(), brightness: brightness));
        await tester.pumpWidget(_host(_items(4), brightness: brightness));
        for (var i = 0; i < 4; i++) {
          expect(
            find.descendant(of: find.byType(AppStaggerItem).at(i), matching: find.byType(FadeTransition)),
            findsNothing,
            reason: 'item $i já animou',
          );
        }
        expect(tester.binding.transientCallbackCount, 0);
      });

      testWidgets('scope diferente anima de novo; reset() também', (tester) async {
        await tester.pumpWidget(_host(_items(3), brightness: brightness));
        await tester.pumpAndSettle();
        await tester.pumpWidget(_host(const SizedBox(), brightness: brightness));
        await tester.pumpWidget(_host(_items(3, scope: 'outra-lista'), brightness: brightness));
        expect(_hasFade(tester, 0), isTrue);
        await tester.pumpAndSettle();

        AppStaggerItem.reset('outra-lista');
        await tester.pumpWidget(_host(const SizedBox(), brightness: brightness));
        await tester.pumpWidget(_host(_items(3, scope: 'outra-lista'), brightness: brightness));
        expect(_hasFade(tester, 0), isTrue);
        await tester.pumpAndSettle();
      });

      testWidgets('escopo padrão = rota: nova tela anima, mesma tela não repete', (tester) async {
        await tester.pumpWidget(_host(_items(2, scope: null), brightness: brightness));
        expect(_hasFade(tester, 0), isTrue);
        await tester.pumpAndSettle();
        await tester.pumpWidget(_host(const SizedBox(), brightness: brightness));
        await tester.pumpWidget(_host(_items(2, scope: null), brightness: brightness));
        expect(_hasFade(tester, 0), isFalse);
      });

      testWidgets('o filho mantém o estado depois da entrada', (tester) async {
        final key = GlobalKey<_CounterState>();
        await tester.pumpWidget(_host(
          AppStaggerItem(index: 0, scope: 's', child: _Counter(key: key)),
          brightness: brightness,
        ));
        await tester.pumpAndSettle();
        key.currentState!.bump();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('n=1'), findsOneWidget);
      });

      testWidgets('AppStagger monta coluna com espaçamento', (tester) async {
        await tester.pumpWidget(_host(
          const AppStagger(spacing: 20, scope: 'col', children: [
            SizedBox(height: 30, child: Text('a')),
            SizedBox(height: 30, child: Text('b')),
            SizedBox(height: 30, child: Text('c')),
          ]),
          brightness: brightness,
        ));
        await tester.pumpAndSettle();
        final a = tester.getTopLeft(find.text('a')).dy;
        final b = tester.getTopLeft(find.text('b')).dy;
        final c = tester.getTopLeft(find.text('c')).dy;
        expect(b - a, 50);
        expect(c - b, 50);
        expect(find.byType(AppStaggerItem), findsNWidgets(3));
        _expectNoSmallText(tester);
      });

      testWidgets('disableAnimations: nada anima e não há timers pendentes', (tester) async {
        await tester.pumpWidget(_host(_items(8), brightness: brightness, reduced: true));
        expect(tester.binding.transientCallbackCount, 0);
        for (var i = 0; i < 8; i++) {
          expect(
            find.descendant(of: find.byType(AppStaggerItem).at(i), matching: find.byType(FadeTransition)),
            findsNothing,
          );
        }
        await tester.pumpAndSettle();
      });
    });
  }
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;
  void bump() => setState(() => n++);

  @override
  Widget build(BuildContext context) => Text('n=$n');
}

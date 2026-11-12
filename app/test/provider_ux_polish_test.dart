import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/features/provider/presentation/provider_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(theme: AppTheme.resolve(null, Brightness.dark), home: Scaffold(body: child));

void _size(WidgetTester t, double w, double h, {double scale = 1.0}) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1.0;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    t.view.reset();
    t.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

void main() {
  group('Simulador de ganho (Painel)', () {
    for (final w in [320.0, 360.0, 412.0]) {
      testWidgets('${w.toInt()} px com teclado aberto e fonte grande: sem overflow e resultado correto', (t) async {
        _size(t, w, 640, scale: 1.3);
        t.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(t.view.resetViewInsets);
        await t.pumpWidget(_host(const EarningsSimulatorSheet()));
        await t.pump();
        // mão de obra 250 → taxa 12% (30) → 220; peças 150 sem taxa → R$ 370,00
        expect(find.byKey(const ValueKey('smart-split-net-result')), findsOneWidget);
        expect(t.widget<Text>(find.byKey(const ValueKey('smart-split-net-result'))).data, contains('370,00'));
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('aceita milhar com vírgula (1.250,50) em vez de zerar o valor', (t) async {
      _size(t, 360, 780);
      await t.pumpWidget(_host(const EarningsSimulatorSheet()));
      await t.enterText(find.byKey(const ValueKey('smart-split-labor-input')), '1.000,00');
      await t.enterText(find.byKey(const ValueKey('smart-split-materials-input')), '1.250,50');
      await t.pump();
      // 1000 - 12% = 880 + 1250,50 = 2130,50
      expect(t.widget<Text>(find.byKey(const ValueKey('smart-split-net-result'))).data, contains('2.130,50'));
    });
  });

  group('Meta da semana', () {
    Future<void> open(WidgetTester t, void Function(double?) onResult) async {
      _size(t, 320, 640);
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.resolve(null, Brightness.dark),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => onResult(await showDialog<double>(context: context, builder: (_) => const WeeklyGoalDialog(initial: 2000))),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('abrir'));
      await t.pumpAndSettle();
    }

    testWidgets('valor inválido mostra o erro e mantém o diálogo aberto (não volta p/ R\$ 2.000 em silêncio)', (t) async {
      double? result = -1;
      await open(t, (v) => result = v);
      await t.enterText(find.byType(TextField), '50');
      await t.tap(find.text('Salvar meta'));
      await t.pump();
      expect(find.textContaining('a partir de R\$ 100'), findsOneWidget);
      expect(find.text('Definir meta da semana'), findsOneWidget);
      expect(result, -1);
      // digitar de novo limpa o erro
      await t.enterText(find.byType(TextField), '2.500,00');
      await t.pump();
      expect(find.textContaining('a partir de R\$ 100'), findsNothing);
      await t.tap(find.text('Salvar meta'));
      await t.pumpAndSettle();
      expect(result, 2500);
    });

    testWidgets('cancelar devolve null', (t) async {
      double? result = -1;
      await open(t, (v) => result = v);
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      expect(result, isNull);
    });
  });
}

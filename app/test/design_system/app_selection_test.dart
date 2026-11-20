import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/design_system/app_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool reduced = false,
  double textScale = 1,
  double? width = 360,
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
      body: Center(child: width == null ? child : SizedBox(width: width, child: child)),
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

enum _Mode { client, provider, admin }

class _SegHarness extends StatefulWidget {
  const _SegHarness({this.onChanged, this.expand = true, this.three = false});
  final ValueChanged<_Mode>? onChanged;
  final bool expand;
  final bool three;

  @override
  State<_SegHarness> createState() => _SegHarnessState();
}

class _SegHarnessState extends State<_SegHarness> {
  _Mode value = _Mode.client;

  @override
  Widget build(BuildContext context) {
    return AppSegmented<_Mode>(
      expand: widget.expand,
      segments: [
        const AppSegment(value: _Mode.client, label: 'Quero contratar', icon: Icons.search_rounded),
        const AppSegment(value: _Mode.provider, label: 'Quero trabalhar'),
        if (widget.three) const AppSegment(value: _Mode.admin, label: 'Administrar'),
      ],
      selected: value,
      onChanged: (v) {
        setState(() => value = v);
        widget.onChanged?.call(v);
      },
    );
  }
}

double _cursorLeft(WidgetTester tester) => tester
    .getTopLeft(find.descendant(of: find.byType(AnimatedAlign), matching: find.byType(FractionallySizedBox)))
    .dx;

void main() {
  for (final brightness in Brightness.values) {
    group('AppSegmented (${brightness.name})', () {
      testWidgets('toca troca a seleção; altura >= 56; alvos >= 48; fonte >= 12,5', (tester) async {
        final changes = <_Mode>[];
        await tester.pumpWidget(_host(_SegHarness(onChanged: changes.add), brightness: brightness));
        expect(tester.getSize(find.byType(AppSegmented<_Mode>)).height, greaterThanOrEqualTo(56));
        for (final label in ['Quero contratar', 'Quero trabalhar']) {
          final target = find.ancestor(of: find.text(label), matching: find.byType(ConstrainedBox)).first;
          expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
        }
        _expectNoSmallText(tester);

        await tester.tap(find.text('Quero trabalhar'));
        await tester.pumpAndSettle();
        expect(changes, [_Mode.provider]);

        // tocar de novo na mesma opção não dispara onChanged.
        await tester.tap(find.text('Quero trabalhar'));
        await tester.pumpAndSettle();
        expect(changes, [_Mode.provider]);
      });

      testWidgets('cursor desliza em 180 ms até a outra metade', (tester) async {
        await tester.pumpWidget(_host(const _SegHarness(), brightness: brightness));
        final start = _cursorLeft(tester);
        await tester.tap(find.text('Quero trabalhar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        final mid = _cursorLeft(tester);
        await tester.pumpAndSettle();
        final end = _cursorLeft(tester);
        expect(mid, greaterThan(start));
        expect(mid, lessThan(end));
        expect(end, greaterThan(start + 100));
      });

      testWidgets('semântica: opção selecionada marcada como selected', (tester) async {
        await tester.pumpWidget(_host(const _SegHarness(), brightness: brightness));
        expect(
          tester.getSemantics(find.bySemanticsLabel('Quero contratar')),
          containsSemantics(isSelected: true, isButton: true),
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel('Quero trabalhar')),
          containsSemantics(isSelected: false, isButton: true),
        );
      });

      testWidgets('setas ←/→ mudam a seleção e param nas pontas', (tester) async {
        final changes = <_Mode>[];
        await tester.pumpWidget(_host(_SegHarness(onChanged: changes.add, three: true), brightness: brightness));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab); // foca a 1ª opção
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(changes, [_Mode.provider, _Mode.admin]);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(changes.last, _Mode.provider);
      });

      testWidgets('escala 2x: rótulos quebram em 2 linhas sem overflow', (tester) async {
        await tester.pumpWidget(_host(const _SegHarness(), brightness: brightness, textScale: 2, width: 320));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final h = tester.getSize(find.text('Quero contratar')).height;
        expect(h, greaterThan(40), reason: 'rótulo quebrado em >= 2 linhas');
        final text = tester.widget<Text>(find.text('Quero contratar'));
        expect(text.overflow, isNull);
        expect(tester.getSize(find.byType(AppSegmented<_Mode>)).height, greaterThanOrEqualTo(56));
      });

      testWidgets('expand=false usa a largura do conteúdo', (tester) async {
        await tester.pumpWidget(_host(const _SegHarness(expand: false), brightness: brightness, width: null));
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(AppSegmented<_Mode>)).width, lessThan(800));
        expect(tester.takeException(), isNull);
      });

      testWidgets('disableAnimations: cursor salta sem timers pendentes', (tester) async {
        await tester.pumpWidget(_host(const _SegHarness(), brightness: brightness, reduced: true));
        final start = _cursorLeft(tester);
        await tester.tap(find.text('Quero trabalhar'));
        await tester.pump();
        await tester.pump();
        expect(_cursorLeft(tester), greaterThan(start + 100));
        expect(tester.binding.transientCallbackCount, 0);
      });
    });

    group('AppStepper (${brightness.name})', () {
      double fill(WidgetTester tester, int i) {
        final box = tester.renderObject<RenderFractionallySizedOverflowBox>(
          find.byKey(ValueKey('app-stepper-fill-$i')).last,
        );
        return box.widthFactor ?? 1;
      }

      testWidgets('semântica "Passo x de y" e preenchimento', (tester) async {
        await tester.pumpWidget(_host(const AppStepper(total: 4, current: 2), brightness: brightness));
        expect(find.bySemanticsLabel('Passo 2 de 4'), findsOneWidget);
        expect([for (var i = 0; i < 4; i++) fill(tester, i)], [1, 1, 0, 0]);
        // primeira exibição não anima
        expect(tester.binding.transientCallbackCount, 0);
      });

      testWidgets('avançar preenche em 220 ms', (tester) async {
        await tester.pumpWidget(_host(const AppStepper(total: 4, current: 2), brightness: brightness));
        await tester.pumpWidget(_host(const AppStepper(total: 4, current: 3), brightness: brightness));
        await tester.pump(const Duration(milliseconds: 110));
        expect(fill(tester, 2), inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
        expect(fill(tester, 2), 1);
        expect(find.bySemanticsLabel('Passo 3 de 4'), findsOneWidget);
      });

      testWidgets('animated=false e disableAnimations preenchem na hora', (tester) async {
        await tester.pumpWidget(_host(const AppStepper(total: 3, current: 1, animated: false), brightness: brightness));
        await tester.pumpWidget(_host(const AppStepper(total: 3, current: 2, animated: false), brightness: brightness));
        await tester.pump();
        expect(fill(tester, 1), 1);
        await tester.pumpWidget(_host(const AppStepper(total: 3, current: 3), brightness: brightness, reduced: true));
        await tester.pump();
        expect(fill(tester, 2), 1);
        expect(tester.binding.transientCallbackCount, 0);
      });
    });

    group('AppProgressRing (${brightness.name})', () {
      testWidgets('mostra o filho, semântica de valor e anima 250 ms', (tester) async {
        await tester.pumpWidget(_host(
          const AppProgressRing(value: 0.5, semanticLabel: 'Perfil completo', child: Text('50%')),
          brightness: brightness,
          width: null,
        ));
        expect(find.text('50%'), findsOneWidget);
        expect(tester.getSize(find.byType(AppProgressRing)), const Size(96, 96));
        expect(
          tester.getSemantics(find.bySemanticsLabel('Perfil completo')),
          containsSemantics(label: 'Perfil completo', value: '50%'),
        );
        expect(tester.binding.transientCallbackCount, 0, reason: 'sem animação na 1ª exibição');

        await tester.pumpWidget(_host(
          const AppProgressRing(value: 1, semanticLabel: 'Perfil completo', child: Text('100%')),
          brightness: brightness,
          width: null,
        ));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.binding.transientCallbackCount, greaterThan(0));
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
        expect(
          tester.getSemantics(find.bySemanticsLabel('Perfil completo')),
          containsSemantics(value: '100%'),
        );
      });

      testWidgets('valores fora de 0..1 são limitados; disableAnimations é instantâneo', (tester) async {
        await tester.pumpWidget(_host(const AppProgressRing(value: 2), brightness: brightness, reduced: true));
        expect(tester.getSemantics(find.bySemanticsLabel('Progresso')), containsSemantics(value: '100%'));
        await tester.pumpWidget(_host(const AppProgressRing(value: -1), brightness: brightness, reduced: true));
        await tester.pump();
        expect(tester.getSemantics(find.bySemanticsLabel('Progresso')), containsSemantics(value: '0%'));
        expect(tester.binding.transientCallbackCount, 0);
      });
    });
  }
}

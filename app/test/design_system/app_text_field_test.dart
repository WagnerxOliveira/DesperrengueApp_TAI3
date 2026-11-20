import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/design_system/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
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
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
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

class _ErrorHarness extends StatefulWidget {
  const _ErrorHarness({required this.notifier});
  final ValueNotifier<String?> notifier;

  @override
  State<_ErrorHarness> createState() => _ErrorHarnessState();
}

class _ErrorHarnessState extends State<_ErrorHarness> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.notifier,
      builder: (context, error, _) => AppTextField(label: 'E-mail', errorText: error),
    );
  }
}

void main() {
  for (final brightness in Brightness.values) {
    group('AppTextField (${brightness.name})', () {
      testWidgets('rótulo, dica, ajuda, altura >= 56 e fonte >= 12,5', (tester) async {
        await tester.pumpWidget(_host(
          const AppTextField(label: 'Nome', hint: 'Como você se chama', helper: 'Aparece no seu perfil'),
          brightness: brightness,
        ));
        expect(find.text('Nome'), findsOneWidget);
        expect(find.text('Aparece no seu perfil'), findsOneWidget);
        expect(tester.getSize(find.byType(TextField)).height, greaterThanOrEqualTo(56));
        _expectNoSmallText(tester);

        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        expect(find.text('Como você se chama'), findsOneWidget);
        _expectNoSmallText(tester);
      });

      testWidgets('erro mostra ícone + mensagem que quebra linhas', (tester) async {
        const msg = 'Informe um e-mail válido com arroba e domínio, por exemplo nome@dominio.com.br';
        await tester.pumpWidget(_host(
          const AppTextField(label: 'E-mail', errorText: msg),
          brightness: brightness,
          textScale: 2,
        ));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
        expect(find.text(msg), findsOneWidget);
        final text = tester.widget<Text>(find.text(msg));
        expect(text.overflow, isNull);
        expect(text.maxLines, isNull);
        expect(tester.takeException(), isNull);
        _expectNoSmallText(tester);
      });

      testWidgets('contador n/max atualiza ao digitar', (tester) async {
        await tester.pumpWidget(_host(
          const AppTextField(label: 'Descrição', maxLength: 20),
          brightness: brightness,
        ));
        expect(find.text('0/20'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'abcde');
        await tester.pump();
        expect(find.text('5/20'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'x' * 40);
        await tester.pump();
        expect(find.text('20/20'), findsOneWidget);
      });

      testWidgets('sucesso mostra o check; erro tem prioridade', (tester) async {
        await tester.pumpWidget(_host(const AppTextField(label: 'CPF', success: true), brightness: brightness));
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
        await tester.pumpWidget(_host(
          const AppTextField(label: 'CPF', success: true, errorText: 'CPF inválido'),
          brightness: brightness,
        ));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      });

      testWidgets('prefixo e sufixo respeitam alvo >= 48', (tester) async {
        await tester.pumpWidget(_host(
          AppTextField(
            label: 'Senha',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
            suffix: IconButton(onPressed: () {}, icon: const Icon(Icons.visibility_outlined)),
          ),
          brightness: brightness,
        ));
        expect(tester.getSize(find.byType(IconButton)).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(find.byType(TextField)).height, greaterThanOrEqualTo(56));
        final field = tester.widget<EditableText>(find.byType(EditableText));
        expect(field.obscureText, isTrue);
      });
    });
  }

  group('shake do erro', () {
    testWidgets('anima só quando o erro passa de nulo → não-nulo e termina sem timers', (tester) async {
      final notifier = ValueNotifier<String?>(null);
      await tester.pumpWidget(_host(_ErrorHarness(notifier: notifier)));
      final rest = tester.getTopLeft(find.byType(TextField));

      notifier.value = 'Obrigatório';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final moved = tester.getTopLeft(find.byType(TextField));
      expect((moved.dx - rest.dx).abs(), greaterThan(1));
      expect((moved.dx - rest.dx).abs(), lessThanOrEqualTo(6.01));

      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(TextField)), rest);
      expect(tester.binding.transientCallbackCount, 0);

      // erro → outro erro: sem novo shake.
      notifier.value = 'Outro erro';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.getTopLeft(find.byType(TextField)), rest);

      // limpa e volta a errar: shake de novo.
      notifier.value = null;
      await tester.pumpAndSettle();
      notifier.value = 'Obrigatório';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect((tester.getTopLeft(find.byType(TextField)).dx - rest.dx).abs(), greaterThan(1));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('sem shake com disableAnimations e sem timers pendentes', (tester) async {
      final notifier = ValueNotifier<String?>(null);
      await tester.pumpWidget(_host(_ErrorHarness(notifier: notifier), reduced: true));
      final rest = tester.getTopLeft(find.byType(TextField));
      notifier.value = 'Obrigatório';
      await tester.pump();
      expect(tester.getTopLeft(find.byType(TextField)), rest);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.getTopLeft(find.byType(TextField)), rest);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpAndSettle();
    });
  });
}

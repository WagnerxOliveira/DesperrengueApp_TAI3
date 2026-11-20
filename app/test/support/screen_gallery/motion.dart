import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'inspect.dart';

/// Medições de movimento (spec §3 / §6.5): duração de transições e escala de
/// toque. Tudo determinístico (relógio falso do `flutter_test`).

/// Executa [action] e conta quanto tempo (em passos de [step]) o framework
/// continua pedindo quadros. Útil para a duração de transições de página.
///
/// Retorna a duração até o primeiro quadro sem animação pendente (ou [max]).
Future<Duration> measureSettle(
  WidgetTester tester,
  Future<void> Function() action, {
  Duration max = const Duration(seconds: 2),
  Duration step = const Duration(milliseconds: 8),
}) async {
  await action();
  // 1º quadro inicia as animações.
  await tester.pump();
  var elapsed = Duration.zero;
  while (tester.binding.hasScheduledFrame && elapsed < max) {
    await tester.pump(step);
    elapsed += step;
  }
  return elapsed;
}

/// Resultado da medição de escala de toque.
class PressScaleResult {
  const PressScaleResult({
    required this.rest,
    required this.at120,
    required this.settledPressed,
    required this.afterRelease120,
    required this.afterRelease400,
  });

  /// Escala em repouso (normalmente 1.0).
  final double rest;

  /// Escala 120 ms após o toque descer.
  final double at120;

  /// Escala 400 ms após o toque descer (estado "pressionado" assentado).
  final double settledPressed;

  /// Escala 120 ms depois de soltar.
  final double afterRelease120;
  final double afterRelease400;

  /// A escala "pressionada" chegou ao valor final em ≤ 120 ms.
  bool get pressSettledIn120 => (at120 - settledPressed).abs() <= 0.006;

  /// Voltou ao repouso em ≤ 120 ms depois de soltar.
  bool get releaseSettledIn120 => (afterRelease120 - afterRelease400).abs() <= 0.006;

  /// Houve feedback de escala perceptível (contrato: 0.97).
  bool get hasScaleFeedback => settledPressed < rest - 0.005;

  @override
  String toString() =>
      'escala repouso=${rest.toStringAsFixed(3)} 120ms=${at120.toStringAsFixed(3)} '
      'pressionado=${settledPressed.toStringAsFixed(3)} solta120=${afterRelease120.toStringAsFixed(3)} '
      'solta400=${afterRelease400.toStringAsFixed(3)}';
}

/// Pressiona [target] e mede a escala global do widget ao longo do tempo.
Future<PressScaleResult> measurePressScale(WidgetTester tester, Finder target) async {
  final element = tester.element(target.first);
  final rest = globalScaleOf(element);
  final gesture = await tester.startGesture(tester.getCenter(target.first));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  final at120 = globalScaleOf(tester.element(target.first));
  await tester.pump(const Duration(milliseconds: 280));
  final pressed = globalScaleOf(tester.element(target.first));
  await gesture.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  final rel120 = globalScaleOf(tester.element(target.first));
  await tester.pump(const Duration(milliseconds: 280));
  final rel400 = globalScaleOf(tester.element(target.first));
  return PressScaleResult(
    rest: rest,
    at120: at120,
    settledPressed: pressed,
    afterRelease120: rel120,
    afterRelease400: rel400,
  );
}

/// Duração da transição ao empurrar uma rota nova do app sobre a tela atual.
///
/// [navigatorFinder] deve achar algo sob o `Navigator` (ex.: `find.byType(Scaffold)`).
/// A rota é uma `MaterialPageRoute` (como as 83 do app): o tema global decide a
/// transição via `pageTransitionsTheme`.
Future<({Duration push, Duration pop})> measurePageTransition(
  WidgetTester tester,
  Finder anchor,
) async {
  final context = tester.element(anchor.first);
  final navigator = Navigator.of(context);
  final push = await measureSettle(tester, () async {
    navigator.push<void>(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Center(child: Text('destino'))),
    ));
  });
  final pop = await measureSettle(tester, () async {
    navigator.pop();
  });
  return (push: push, pop: pop);
}

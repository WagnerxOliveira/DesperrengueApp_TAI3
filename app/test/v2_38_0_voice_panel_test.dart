import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/speech_service.dart';
import 'package:desperrengue_app/core/services/text_refine_service.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/features/client/presentation/request_wizard.dart';
import 'package:desperrengue_app/features/client/presentation/voice_dictation.dart';

/// Motor falso que também emite o NÍVEL do microfone (o do projeto ignora `onLevel`).
class _LevelSpeech implements SpeechEngine {
  bool listening = false;
  int stopCalls = 0;
  void Function(String words, bool isFinal)? _onResult;
  void Function(double level)? _onLevel;

  @override
  bool get isListening => listening;

  @override
  Future<bool> initialize({void Function(String status)? onStatus, void Function(String error)? onError}) async => true;

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    void Function(double level)? onLevel,
    String localeId = 'pt_BR',
  }) async {
    listening = true;
    _onResult = onResult;
    _onLevel = onLevel;
  }

  @override
  Future<void> stop() async {
    listening = false;
    stopCalls++;
  }

  void say(String words, {bool isFinal = false}) => _onResult?.call(words, isFinal);
  void level(double v) => _onLevel?.call(v);
}

class _NoRefine implements TextRefiner {
  const _NoRefine();
  @override
  Future<String> refine(String text) async => text;
}

const _profile = UserProfile(
  id: 'me',
  fullName: 'Maria Souza',
  phone: '35999999999',
  addressLine: 'Rua Padre José, 100 - Centro, Santa Rita do Sapucaí - MG',
  addressCity: 'Santa Rita do Sapucaí - MG',
  latitude: -22.25,
  longitude: -45.70,
  clientSetupDone: true,
);

Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(theme: AppTheme.resolve(null, brightness), home: child);

void main() {
  group('v2.38.0 · painel de voz', () {
    Future<(TextEditingController, _LevelSpeech)> open(
      WidgetTester t, {
      TextRefiner refiner = const _NoRefine(),
      String initial = '',
    }) async {
      final ctl = TextEditingController(text: initial);
      final fake = _LevelSpeech();
      addTearDown(ctl.dispose);
      await t.pumpWidget(_host(Scaffold(
        body: SingleChildScrollView(
          child: VoiceDictationPanel(textController: ctl, engine: fake, refiner: refiner),
        ),
      )));
      return (ctl, fake);
    }

    testWidgets('guia em 3 passos aberto de início; recolhe ao gravar e pode ser reaberto', (t) async {
      await open(t);
      expect(find.byKey(const ValueKey('voice-guide-steps')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('voice-mic')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('voice-guide-steps')), findsNothing, reason: 'divulgação progressiva');
      expect(find.text('Como usar a voz'), findsOneWidget, reason: 'o cabeçalho do guia continua acessível');

      await t.tap(find.byKey(const ValueKey('voice-mic'))); // para
      await t.pump();
      await t.tap(find.byKey(const ValueKey('voice-guide-toggle')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('voice-guide-steps')), findsOneWidget);
    });

    testWidgets('gravando: mostra timer e onda alimentada pelo volume real', (t) async {
      final (_, fake) = await open(t);
      await t.tap(find.byKey(const ValueKey('voice-mic')));
      await t.pump();
      for (final v in [0.1, 0.5, 0.9, 0.3]) {
        fake.level(v);
      }
      await t.pump(const Duration(milliseconds: 120));
      expect(find.byKey(const ValueKey('voice-wave')), findsOneWidget);
      expect(find.byKey(const ValueKey('voice-timer')), findsOneWidget);
      expect(find.textContaining('Gravando 0:0'), findsOneWidget);
      expect(find.text('Ouvindo… toque no botão para parar'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('voice-mic')));
      await t.pump();
      expect(find.byKey(const ValueKey('voice-wave')), findsNothing);
      expect(find.byKey(const ValueKey('voice-timer')), findsNothing);
    });

    testWidgets('histórico de volume é limitado (não cresce sem fim)', (t) async {
      final ctl = TextEditingController();
      addTearDown(ctl.dispose);
      final fake = _LevelSpeech();
      final c = VoiceDictationController(engine: fake, text: ctl);
      addTearDown(c.dispose);
      await c.start();
      for (var i = 0; i < 300; i++) {
        fake.level((i % 10) / 10);
      }
      fake.level(7); // fora da faixa é normalizado
      expect(c.levelHistory.length, VoiceDictationController.historyLength);
      expect(c.levelHistory.last, 1.0);
      await c.stop();
    });

    testWidgets('apagar o campo descarta a versão organizada (toggle some)', (t) async {
      final refiner = StructuredVoiceRefiner(
        remoteStructurer: (transcript, {String? categoryHint, List<String> photoNotes = const []}) async => null,
        grammarRefiner: LanguageToolRefiner(client: MockClient((_) async => http.Response('{"matches":[]}', 200))),
        categoryProvider: () => 'Eletricista',
      );
      final (ctl, fake) = await open(t, refiner: refiner);
      await t.tap(find.byKey(const ValueKey('voice-mic')));
      await t.pump();
      fake.say('o disjuntor do chuveiro lorenzetti 220v no banheiro ta desarmando desde ontem e quero atendimento amanha', isFinal: true);
      await t.tap(find.byKey(const ValueKey('voice-mic')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('voice-toggle-structured')), findsOneWidget);
      expect(find.text('Relato organizado pela IA'), findsOneWidget);

      ctl.clear(); // "Apagar tudo"
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('voice-toggle-structured')), findsNothing);
      expect(find.text('Relato organizado pela IA'), findsNothing);
      expect(ctl.text, isEmpty);
    });

    testWidgets('apagar tudo ENQUANTO grava: para a captação e parcial tardia não traz o texto de volta', (t) async {
      final (ctl, fake) = await open(t);
      await t.tap(find.byKey(const ValueKey('voice-mic')));
      await t.pump();
      fake.say('a torneira da cozinha esta vazando');
      expect(ctl.text, isNotEmpty);
      ctl.clear();
      await t.pump();
      expect(fake.listening, isFalse);
      expect(fake.stopCalls, 1);
      fake.say('a torneira da cozinha esta vazando muito'); // chegada tardia do motor
      await t.pump();
      expect(ctl.text, isEmpty);
      expect(find.text('Toque para falar'), findsOneWidget);
    });

    testWidgets('microfone indisponível: card de aviso com o motivo', (t) async {
      final ctl = TextEditingController();
      addTearDown(ctl.dispose);
      await t.pumpWidget(_host(Scaffold(
        body: SingleChildScrollView(
          child: VoiceDictationPanel(textController: ctl, engine: _DeniedSpeech(), refiner: const _NoRefine()),
        ),
      )));
      await t.tap(find.byKey(const ValueKey('voice-mic')));
      await t.pump();
      expect(find.byKey(const ValueKey('voice-unavailable')), findsOneWidget);
      expect(find.textContaining('Não foi possível usar o microfone'), findsOneWidget);
    });

    for (final dark in [false, true]) {
      testWidgets('sem overflow em 320x640 @1.5x e alvos ≥ 48dp (${dark ? 'escuro' : 'claro'}, gravando)', (t) async {
        t.view.physicalSize = const Size(480, 960);
        t.view.devicePixelRatio = 1.5;
        addTearDown(t.view.reset);
        final ctl = TextEditingController();
        addTearDown(ctl.dispose);
        final fake = _LevelSpeech();
        await t.pumpWidget(_host(
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: VoiceDictationPanel(textController: ctl, engine: fake, refiner: const _NoRefine()),
            ),
          ),
          brightness: dark ? Brightness.dark : Brightness.light,
        ));
        expect(t.takeException(), isNull);
        expect(t.getSize(find.byKey(const ValueKey('voice-mic'))).shortestSide, greaterThanOrEqualTo(48));
        expect(t.getSize(find.byKey(const ValueKey('voice-guide-toggle'))).height, greaterThanOrEqualTo(48));
        await t.ensureVisible(find.byKey(const ValueKey('voice-mic')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('voice-mic')));
        await t.pump();
        fake.level(0.6);
        await t.pump(const Duration(milliseconds: 200));
        expect(t.takeException(), isNull);
        await t.ensureVisible(find.byKey(const ValueKey('voice-mic')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('voice-mic')));
        await t.pump();
      });
    }
  });

  group('v2.38.0 · Apagar tudo no pedido', () {
    Future<void> openWizard(WidgetTester t) async {
      t.view.physicalSize = const Size(1080, 6000);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      await t.pumpWidget(_host(RequestWizardScreen(
        profile: _profile,
        category: 'Eletricista',
        speechEngine: _LevelSpeech(),
        textRefiner: const _NoRefine(),
        openRequestsCounter: () async => 0,
      )));
      await t.pump();
      await t.pump();
    }

    testWidgets('oculto com o campo vazio; aparece ao digitar; apaga e oferece Desfazer', (t) async {
      await openWizard(t);
      expect(find.byKey(const ValueKey('btn-clear-description')), findsNothing);

      await t.enterText(find.byKey(const ValueKey('description-field')), 'O disjuntor do chuveiro está desarmando.');
      await t.pump();
      expect(find.byKey(const ValueKey('btn-clear-description')), findsOneWidget);
      expect(find.text('Apagar tudo'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('btn-clear-description')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(t.widget<EditableText>(find.descendant(of: find.byKey(const ValueKey('description-field')), matching: find.byType(EditableText))).controller.text, isEmpty);
      expect(find.byKey(const ValueKey('btn-clear-description')), findsNothing);
      expect(find.text('Texto apagado.'), findsOneWidget);

      await t.tap(find.text('Desfazer'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(t.widget<EditableText>(find.descendant(of: find.byKey(const ValueKey('description-field')), matching: find.byType(EditableText))).controller.text,
          'O disjuntor do chuveiro está desarmando.');
      expect(find.byKey(const ValueKey('btn-clear-description')), findsOneWidget);
    });
  });
}

class _DeniedSpeech implements SpeechEngine {
  @override
  bool get isListening => false;

  @override
  Future<bool> initialize({void Function(String status)? onStatus, void Function(String error)? onError}) async => false;

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    void Function(double level)? onLevel,
    String localeId = 'pt_BR',
  }) async {}

  @override
  Future<void> stop() async {}
}

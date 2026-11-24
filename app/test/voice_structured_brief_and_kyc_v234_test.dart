import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/criminal_background_service.dart';
import 'package:desperrengue_app/core/services/speech_service.dart';
import 'package:desperrengue_app/core/services/text_refine_service.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/duotone_service_icons.dart';
import 'package:desperrengue_app/core/ui/kyc_human_feedback_translator.dart';
import 'package:desperrengue_app/core/utils/smart_transcript_formatter.dart';
import 'package:desperrengue_app/core/utils/structured_voice_brief.dart';
import 'package:desperrengue_app/features/client/presentation/client_setup_screen.dart';
import 'package:desperrengue_app/features/client/presentation/voice_dictation.dart';
import 'package:desperrengue_app/features/shared/presentation/smart_triage_widgets.dart';

class _FakeSpeech implements SpeechEngine {
  bool listening = false;
  late void Function(String words, bool isFinal) _onResult;

  @override
  bool get isListening => listening;

  @override
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async =>
      true;

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    void Function(double level)? onLevel,
    String localeId = 'pt_BR',
  }) async {
    _onResult = onResult;
    listening = true;
  }

  void say(String words, {bool isFinal = false}) {
    _onResult(words, isFinal);
  }

  @override
  Future<void> stop() async {
    listening = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('1. StructuredVoiceBriefEngine & Parser Reverso', () {
    test('corrige fonética técnica residencial PT-BR sem alterar o sentido', () {
      final fixed = StructuredVoiceBriefEngine.repairTechnicalSpeech(
        'o dijuntor do xuveiro lorenzete 220 volts ta desarmando e o cifao vaza',
      );
      expect(fixed, contains('disjuntor'));
      expect(fixed, contains('chuveiro'));
      expect(fixed, contains('Lorenzetti'));
      expect(fixed, contains('220V'));
      expect(fixed, contains('sifão'));
    });

    test('remove vícios de oralidade brasileira preservando 100% dos fatos técnicos', () {
      const spoken =
          'então, tipo assim, o ar condicionado da sala, né, tá meio que pingando água na parede, tá ligado, desde ontem';
      final brief = StructuredVoiceBriefEngine.structureLocally(
        spoken,
        currentCategory: 'Ar-condicionado',
      );
      expect(brief.problemSummary.toLowerCase(), isNot(contains('tipo assim')));
      expect(brief.problemSummary.toLowerCase(), isNot(contains('ligado')));
      expect(brief.problemSummary.toLowerCase(), isNot(contains('meio que')));
      expect(brief.problemSummary, isNot(contains(r'$1')));
      expect(brief.problemSummary.toLowerCase(), contains('ar-condicionado'));
      expect(brief.problemSummary.toLowerCase(), contains('pingando'));
      expect(brief.locationAndEquipment, contains('Ar-condicionado'));
      expect(brief.locationAndEquipment, contains('Sala'));
    });

    test('estrutura fala coloquial elétrica sem inventar dados ausentes', () {
      const spoken =
          'oi boa noite tudo bem olha o dijuntor do chuveiro Lorenzetti 220 volts no banheiro da suíte começou a desarmar ontem à noite e tá saindo cheiro de queimado eu já desliguei o disjuntor vocês conseguem vir amanhã de manhã';
      final brief = StructuredVoiceBriefEngine.structureLocally(
        spoken,
        currentCategory: 'Eletricista',
      );

      expect(brief.locationAndEquipment, isNotNull);
      expect(brief.locationAndEquipment!, contains('Chuveiro'));
      expect(brief.locationAndEquipment!, contains('Lorenzetti'));
      expect(brief.locationAndEquipment!, contains('220V'));
      expect(brief.locationAndEquipment!, contains('Suíte'));
      expect(brief.observedSymptoms, isNotEmpty);
      expect(brief.timelineAndContext, isNotNull);
      expect(brief.clientActionsOrNotes, isNotNull);
      expect(brief.clientActionsOrNotes!.toLowerCase(), contains('desliguei'));
      expect(brief.urgencyAndAvailability, isNotNull);
      expect(brief.safetyRisk, equals('attention'));

      final text = brief.toStructuredText(maxLength: 900);
      expect(text, contains('RESUMO:'));
      expect(text, contains('LOCAL E EQUIPAMENTO:'));
      expect(text, contains('SINTOMAS:'));
      expect(text, contains('HISTÓRICO:'));
      expect(text, contains('OBSERVAÇÕES:'));
      expect(text, contains('URGÊNCIA / HORÁRIO:'));

      // Parser reverso reconstrói fielmente sem vazar prefixo "RESUMO:" no título do pedido
      final reparsed = StructuredVoiceBrief.tryParseStructuredText(text);
      expect(reparsed, isNotNull);
      expect(reparsed!.locationAndEquipment, contains('Lorenzetti'));
      expect(reparsed.observedSymptoms, isNotEmpty);

      final headline = SmartOrderHeadlineFormatter.formatHeadline(
        text,
        category: 'Eletricista',
        maxChars: 48,
      );
      expect(headline.startsWith('RESUMO:'), isFalse);
    });

    test('mantém omissão limpa quando cliente não cita histórico nem marca', () {
      const spoken =
          'A torneira da cozinha está pingando sem parar e eu já fechei o registro.';
      final brief = StructuredVoiceBriefEngine.structureLocally(
        spoken,
        currentCategory: 'Encanador',
      );
      expect(brief.locationAndEquipment, contains('Torneira'));
      expect(brief.locationAndEquipment, contains('Cozinha'));
      expect(brief.clientActionsOrNotes, isNotNull);
      expect(brief.timelineAndContext, isNull);
    });

    test('detecta risco crítico para vazamento de gás ou faísca elétrica', () {
      final gasBrief = StructuredVoiceBriefEngine.structureLocally(
        'Estou sentindo cheiro forte de gás perto do fogão na cozinha agora.',
      );
      expect(gasBrief.safetyRisk, equals('critical'));

      final parsed = StructuredVoiceBrief.tryParseStructuredText(
        gasBrief.toStructuredText(),
      );
      expect(parsed?.safetyRisk, equals('critical'));
    });

    test('SmartTranscriptFormatter mantém comandos de pontuação e corrige termos técnicos', () {
      final out = SmartTranscriptFormatter.format(
        'o dijuntor 220 volts desarmou mas o ar condicionado funciona',
      );
      expect(out, contains('disjuntor'));
      expect(out, contains('220V'));
      expect(out, contains('ar-condicionado'));
    });
  });

  group('2. StructuredVoiceRefiner (IA Gratuita + LanguageTool + Fallback Local)', () {
    test('usa saída estruturada da camada remota gratuita quando disponível', () async {
      final refiner = StructuredVoiceRefiner(
        categoryProvider: () => 'Hidráulica',
        remoteStructurer: (
          transcript, {
          String? categoryHint,
          List<String> photoNotes = const [],
        }) async {
          return StructuredVoiceBrief.fromAiJson(
            const <String, dynamic>{
              'headline': 'Vazamento no sifão da pia da cozinha',
              'problem_summary': 'Sifão da pia da cozinha soltou e está vazando água no armário',
              'location_and_equipment': 'Pia · Sifão — Cozinha',
              'observed_symptoms': ['Água vazando ao abrir a torneira', 'Rosca do sifão frouxa'],
              'timeline_and_context': 'Começou hoje após o almoço',
              'client_actions_or_notes': 'Balde posicionado embaixo da pia',
              'urgency_and_availability': 'Para hoje à tarde',
              'suggested_category': 'Encanador',
              'safety_risk': 'attention',
            },
            rawTranscript: transcript,
            source: 'ai_groq',
          );
        },
      );

      final out = await refiner.refine(
        'oi gente a pia da cozinha ta vazando la no sifao que soltou depois do almoco',
      );
      expect(out, contains('RESUMO: Sifão da pia da cozinha soltou'));
      expect(out, contains('LOCAL E EQUIPAMENTO: Pia · Sifão — Cozinha'));
      expect(out, contains('URGÊNCIA / HORÁRIO: Para hoje à tarde'));
    });

    test('cai para LanguageTool gratuito + motor semântico local quando remoto falha', () async {
      final mockHttp = MockClient((req) async {
        expect(req.url.host, 'api.languagetool.org');
        return http.Response(
          jsonEncode({
            'matches': [
              {
                'offset': 2,
                'length': 3,
                'rule': {'category': {'id': 'TYPOS'}},
                'replacements': [{'value': 'não'}],
              },
            ],
          }),
          200,
        );
      });

      final refiner = StructuredVoiceRefiner(
        grammarRefiner: LanguageToolRefiner(client: mockHttp),
        remoteStructurer: (
          transcript, {
          String? categoryHint,
          List<String> photoNotes = const [],
        }) async =>
            null,
        categoryProvider: () => 'Ar-Condicionado',
      );

      final out = await refiner.refine(
        'o ar condicionado split do quarto nao gela e ta pingando agua desde ontem',
      );
      expect(out, contains('RESUMO:'));
      expect(out, contains('Ar-condicionado'));
      expect(out, contains('HISTÓRICO:'));
    });
  });

  group('3. Widgets: VoiceDictationPanel Alternância & StructuredClientBriefView', () {
    testWidgets('VoiceDictationPanel estrutura ao finalizar gravação e permite alternar versão original', (tester) async {
      final ctl = TextEditingController();
      addTearDown(ctl.dispose);
      final speech = _FakeSpeech();
      final fastStructuredRefiner = StructuredVoiceRefiner(
        remoteStructurer: (
          transcript, {
          String? categoryHint,
          List<String> photoNotes = const [],
        }) async =>
            null,
        grammarRefiner: LanguageToolRefiner(
          client: MockClient((_) async => http.Response('{"matches":[]}', 200)),
        ),
        categoryProvider: () => 'Eletricista',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.resolve(UserMode.client, Brightness.dark),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: VoiceDictationPanel(
                textController: ctl,
                maxLength: 900,
                engine: speech,
                refiner: fastStructuredRefiner,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('voice-mic')));
      await tester.pump();
      speech.say(
        'o disjuntor do chuveiro lorenzetti 220v no banheiro ta desarmando desde ontem e quero atendimento amanha',
        isFinal: true,
      );
      await tester.tap(find.byKey(const ValueKey('voice-mic')));
      await tester.pumpAndSettle();

      expect(ctl.text, contains('RESUMO:'));
      expect(ctl.text, contains('LOCAL E EQUIPAMENTO:'));
      final toggleBtn = find.byKey(const ValueKey('voice-toggle-structured'));
      expect(toggleBtn, findsOneWidget);
      expect(find.text('Ver fala original'), findsOneWidget);

      await tester.ensureVisible(toggleBtn);
      await tester.tap(toggleBtn);
      await tester.pump();
      expect(ctl.text, isNot(contains('RESUMO:')));
      expect(find.text('Usar versão estruturada'), findsOneWidget);
    });

    testWidgets('StructuredClientBriefView exibe blocos organizados para o profissional sem overflow', (tester) async {
      const structuredDesc =
          'RESUMO: Chuveiro Lorenzetti 220V desarmando o disjuntor na suíte.\n'
          'LOCAL E EQUIPAMENTO: Chuveiro · Lorenzetti · 220V — Suíte\n'
          'SINTOMAS: Desarma ao ligar no modo quente; Cheiro leve de aquecimento.\n'
          'HISTÓRICO: Começou ontem à noite.\n'
          'OBSERVAÇÕES: Disjuntor desligado por segurança.\n'
          'URGÊNCIA / HORÁRIO: Atendimento amanhã pela manhã.\n\n'
          'Foto 1: Quadro de disjuntores aberto com disjuntor de 32A';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.resolve(UserMode.provider, Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: StructuredClientBriefView(description: structuredDesc),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('structured-client-brief-view')), findsOneWidget);
      expect(find.text('Relato estruturado'), findsOneWidget);
      expect(find.text('Local e equipamento'), findsOneWidget);
      expect(find.text('Sintomas relatados'), findsOneWidget);
      expect(find.text('Quando começou / gatilho'), findsOneWidget);
      expect(find.text('Já feito / observações'), findsOneWidget);
      expect(find.text('Urgência / disponibilidade'), findsOneWidget);
      expect(find.text('Observações nas fotos'), findsOneWidget);
    });
  });

  group('4. ClientSetupScreen (Etapas 1 a 6) — Redesenhado e Responsivo', () {
    testWidgets('Etapas 1, 3, 4 e 6 renderizam com novo chrome sem overflow ou jargão em 360x780 Dark', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final profile = UserProfile.fromMap(<String, dynamic>{
        'id': 'u-redesign-234',
        'full_name': 'Wagner Oliveira',
        'is_client': true,
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.resolve(UserMode.client, Brightness.dark),
          home: ClientSetupScreen(
            profile: profile,
            initialStep: 0,
            targetMode: UserMode.client,
            customCriminalResultOverride: AuditedCriminalRecordResult(
              passed: true,
              protocolNumber: '2026.99887766',
              protocolMasked: '2026.***766',
              issuedDate: DateTime.utc(2026, 11, 20),
              validationCode: 'ABCD.1234.EFGH.5678',
              fileSha256Hex: 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
              holderNameMatched: true,
              cpfMatched: true,
              humanFeedbackMessage: 'Aprovado',
              fileBytes: Uint8List.fromList(utf8.encode('%PDF-1.4\n%%EOF')),
              fileExtension: 'pdf',
            ),
            customCameraCapture: ({required String slot}) async =>
                Uint8List.fromList(<int>[137, 80, 78, 71]),
            customSubmitter: ({
              required cpfRaw,
              required typedFullName,
              required phone,
              required addressLine,
              required addressCity,
              latitude,
              longitude,
              required livenessResult,
              required ocrResult,
            }) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('17%'), findsOneWidget);
      expect(find.byKey(const ValueKey('step0-welcome-hero-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('step0-personal-data-card')), findsOneWidget);

      for (final el in find.byType(Text).evaluate()) {
        final w = el.widget as Text;
        final txt = w.data ?? w.textSpan?.toPlainText() ?? '';
        expect(
          KycHumanFeedbackTranslator.containsBannedTechnicalJargon(txt),
          isFalse,
          reason: 'Jargão encontrado: "$txt"',
        );
      }
    });
  });
}

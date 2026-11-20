import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/active_liveness_engine.dart';
import 'package:desperrengue_app/core/services/criminal_background_service.dart';
import 'package:desperrengue_app/core/services/criminal_certificate_picker_and_extractor.dart';
import 'package:desperrengue_app/core/services/document_ocr_and_liveness_service.dart';
import 'package:desperrengue_app/core/services/face_detection_adapter.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/design_system/design_system.dart';
import 'package:desperrengue_app/core/ui/kyc_human_feedback_translator.dart';
import 'package:desperrengue_app/features/client/presentation/address_form.dart';
import 'package:desperrengue_app/features/client/presentation/client_setup_screen.dart';
import 'package:desperrengue_app/features/client/presentation/widgets/kyc_onboarding_chrome.dart';
import 'package:desperrengue_app/features/shared/presentation/criminal_background_check_step.dart';

typedef _ViewportCase = ({
  Size size,
  double textScale,
  Brightness brightness,
  UserMode mode,
  String label,
});

const List<_ViewportCase> _fullUxMatrix = <_ViewportCase>[
  (
    size: Size(320, 640),
    textScale: 1.0,
    brightness: Brightness.light,
    mode: UserMode.client,
    label: '320x640 @ 1.0x Light Cliente',
  ),
  (
    size: Size(320, 640),
    textScale: 1.5,
    brightness: Brightness.dark,
    mode: UserMode.provider,
    label: '320x640 @ 1.5x Dark Profissional',
  ),
  (
    size: Size(390, 844),
    textScale: 1.0,
    brightness: Brightness.dark,
    mode: UserMode.client,
    label: '390x844 @ 1.0x Dark Cliente',
  ),
  (
    size: Size(390, 844),
    textScale: 1.5,
    brightness: Brightness.light,
    mode: UserMode.provider,
    label: '390x844 @ 1.5x Light Profissional',
  ),
  (
    size: Size(1280, 800),
    textScale: 1.0,
    brightness: Brightness.light,
    mode: UserMode.provider,
    label: '1280x800 @ 1.0x Light Profissional',
  ),
  (
    size: Size(1280, 800),
    textScale: 1.5,
    brightness: Brightness.dark,
    mode: UserMode.client,
    label: '1280x800 @ 1.5x Dark Cliente',
  ),
];

Widget _buildResponsiveApp({
  required Widget home,
  required UserMode mode,
  required Brightness brightness,
  required double textScale,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    theme: AppTheme.resolve(mode, brightness),
    builder: (context, child) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: child!,
      );
    },
    home: home,
  );
}

void _assertZeroOverflowAndZeroJargon(WidgetTester tester, String contextLabel) {
  expect(
    tester.takeException(),
    isNull,
    reason: 'Nenhuma exceção/overflow permitida em $contextLabel',
  );
  for (final element in find.byType(Text).evaluate()) {
    final textWidget = element.widget as Text;
    final content =
        textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
    if (content.trim().isEmpty) continue;
    expect(
      KycHumanFeedbackTranslator.containsBannedTechnicalJargon(content),
      isFalse,
      reason: 'Jargão técnico proibido encontrado em $contextLabel: "$content"',
    );
  }
}

Uint8List _buildValidPfPdfBytes({
  String holderName = 'WAGNER OLIVEIRA CLAUDIANO',
  String cpf = '119.787.236-10',
  String protocol = '2026.0849201735',
  String issueDateBr = '15/11/2026',
  String validationCode = '9482.7163.5041.8829',
}) {
  final text =
      '%PDF-1.4\n'
      'MINISTERIO DA JUSTICA E SEGURANCA PUBLICA\n'
      'POLICIA FEDERAL - SISTEMA NACIONAL DE INFORMACOES CRIMINAIS - SINIC\n'
      'CERTIDAO DE ANTECEDENTES CRIMINAIS\n'
      'A Policia Federal CERTIFICA, após pesquisa no Sistema Nacional de Informacoes Criminais - SINIC, '
      'que ate a presente data NAO CONSTA condenação com transito em julgado em nome de '
      '$holderName, CPF $cpf.\n'
      'Observacoes: NADA CONSTA.\n'
      'CERTIDAO N: $protocol\n'
      'DATA DE EMISSAO: $issueDateBr\n'
      'CODIGO DE VALIDACAO: $validationCode\n'
      '%%EOF\n';
  return Uint8List.fromList(utf8.encode(text));
}

LiveFaceObservation _faceObservation({
  required int tsMs,
  required Rect box,
}) {
  return LiveFaceObservation(
    faceCount: 1,
    trackingId: 11,
    normalizedBox: box,
    leftEyeOpenProbability: 0.92,
    rightEyeOpenProbability: 0.91,
    headEulerAngleX: 0.5,
    headEulerAngleY: 0.4,
    headEulerAngleZ: 0.2,
    meanLuminance: 138.0,
    sharpness: 64.0,
    blueMonitorRatio: 0.04,
    textureMotionDelta: 0.55,
    timestampMs: tsMs,
    sourceEngine: 'test_v30_stream',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('1. v2.30.0 — Espelhamento Frontal, Trava de Lente e Ausência de Troca de Câmera', () {
    test('shouldMirrorFrontPreview: false no Mobile (sem double-flip) e true apenas na Web', () {
      expect(
        ActiveLivenessFullscreenModal.shouldMirrorFrontPreview(isWeb: false),
        isFalse,
      );
      expect(
        ActiveLivenessFullscreenModal.shouldMirrorFrontPreview(isWeb: true),
        isTrue,
      );
    });

    test('selectStrictFrontCamera escolhe somente câmera frontal e nunca cai para traseira', () {
      const back = CameraDescription(
        name: 'back_0',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      );
      const front = CameraDescription(
        name: 'front_1',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
      );

      expect(
        ActiveLivenessFullscreenModal.selectStrictFrontCamera([back, front]),
        equals(front),
      );
      expect(
        ActiveLivenessFullscreenModal.selectStrictFrontCamera([back]),
        isNull,
      );
    });

    for (final vp in _fullUxMatrix) {
      testWidgets(
        'ActiveLivenessFullscreenModal não exibe Icons.cameraswitch_rounded e renderiza sem overflow/jargão em ${vp.label}',
        (tester) async {
          tester.view.physicalSize = vp.size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final streamCtrl =
              StreamController<LiveFaceObservation>.broadcast(sync: true);
          addTearDown(streamCtrl.close);

          await tester.pumpWidget(
            _buildResponsiveApp(
              mode: vp.mode,
              brightness: vp.brightness,
              textScale: vp.textScale,
              disableAnimations: true,
              home: ActiveLivenessFullscreenModal(
                cpfDigits: '11978723610',
                forcedDirection: LivenessTurnDirection.left,
                testObservationStream: streamCtrl.stream,
              ),
            ),
          );
          await tester.pump();

          expect(find.byIcon(Icons.cameraswitch_rounded), findsNothing);
          expect(
            find.byKey(ActiveLivenessFullscreenModal.closeButtonKey),
            findsOneWidget,
          );
          expect(
            find.byKey(ActiveLivenessFullscreenModal.stepPillKey),
            findsOneWidget,
          );
          _assertZeroOverflowAndZeroJargon(tester, 'LivenessModal ${vp.label}');
        },
      );
    }
  });

  group('2. v2.30.0 — Instruções Direcionais Naturais de Centralização (Espelho)', () {
    test('orienta esquerda, direita, abaixe e levante conforme o deslocamento do rosto fora do oval', () {
      final engine = ActiveLivenessStateMachine(
        forcedDirection: LivenessTurnDirection.right,
      );

      // Rosto deslocado para a esquerda da tela -> pedir para mover à direita
      final toRight = engine.processObservation(
        _faceObservation(
          tsMs: 1000,
          box: const Rect.fromLTWH(0.05, 0.25, 0.36, 0.44),
        ),
      );
      expect(toRight.contourState, LivenessContourState.invalidRed);
      expect(toRight.instruction.toLowerCase(), contains('direita'));
      expect(
        KycHumanFeedbackTranslator.containsBannedTechnicalJargon(
          toRight.instruction,
        ),
        isFalse,
      );

      // Rosto deslocado para a direita da tela -> pedir para mover à esquerda
      final toLeft = engine.processObservation(
        _faceObservation(
          tsMs: 1100,
          box: const Rect.fromLTWH(0.58, 0.25, 0.36, 0.44),
        ),
      );
      expect(toLeft.contourState, LivenessContourState.invalidRed);
      expect(toLeft.instruction.toLowerCase(), contains('esquerda'));

      // Rosto muito alto na moldura -> pedir para abaixar um pouco o rosto
      final lowerFace = engine.processObservation(
        _faceObservation(
          tsMs: 1200,
          box: const Rect.fromLTWH(0.32, 0.02, 0.36, 0.40),
        ),
      );
      expect(lowerFace.contourState, LivenessContourState.invalidRed);
      expect(lowerFace.instruction.toLowerCase(), contains('abaixe'));

      // Rosto muito baixo na moldura -> pedir para levantar um pouco o rosto
      final raiseFace = engine.processObservation(
        _faceObservation(
          tsMs: 1300,
          box: const Rect.fromLTWH(0.32, 0.56, 0.36, 0.40),
        ),
      );
      expect(raiseFace.contourState, LivenessContourState.invalidRed);
      expect(raiseFace.instruction.toLowerCase(), contains('levante'));
    });
  });

  group('3. v2.30.0 — Redesign Editorial Porcelain das 6 Etapas (Cliente + Profissional, Claro + Escuro, 3 Viewports)', () {
    for (final vp in _fullUxMatrix) {
      testWidgets(
        'percorre todas as 6 etapas redesenhadas (Hero, 0 de 3 -> 3 de 3, CEP 00000-000, FaceId, Wireframes, OCR, PF) com 0 overflow e 0 jargão em ${vp.label}',
        (tester) async {
          tester.view.physicalSize = vp.size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final selfieBytes =
              DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
            variantSeed: 3,
          );
          final frontDocBytes =
              DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
            variantSeed: 3,
            rotateDegrees: 90,
          );
          final backDocBytes =
              DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
            variantSeed: 9,
          );
          final pdfBytes = _buildValidPfPdfBytes();
          final refNow = DateTime.utc(2026, 11, 18, 12);

          final criminalOverride =
              await CriminalBackgroundService.analyzeAndValidateCertificate(
            fileBytes: pdfBytes,
            fileName: 'certidao_pf.pdf',
            expectedFullName: 'Wagner Oliveira',
            expectedCpfRaw: '119.787.236-10',
            referenceNow: refNow,
          );
          expect(criminalOverride.passed, isTrue);

          bool submitted = false;

          await tester.pumpWidget(
            _buildResponsiveApp(
              mode: vp.mode,
              brightness: vp.brightness,
              textScale: vp.textScale,
              home: ClientSetupScreen(
                profile: UserProfile.fromMap(<String, dynamic>{
                  'id': 'v30-user-${vp.mode.wire}',
                  'full_name': 'Usuário',
                  'is_client': vp.mode == UserMode.client,
                  'is_provider': vp.mode == UserMode.provider,
                }),
                targetMode: vp.mode,
                customCriminalResultOverride: criminalOverride,
                customCameraCapture: ({required String slot}) async {
                  if (slot == 'selfie') return selfieBytes;
                  if (slot == 'front') return frontDocBytes;
                  return backDocBytes;
                },
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
                }) async {
                  submitted = true;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          _assertZeroOverflowAndZeroJargon(tester, 'Etapa 1 (${vp.label})');

          // --- ETAPA 1: Shell Editorial + Hero + Contador Vivo 0 de 3 -> 3 de 3 ---
          expect(find.byType(KycAmbientBackdrop), findsOneWidget);
          expect(find.byType(KycJourneyProgressHeader), findsOneWidget);
          expect(
            find.text(
              vp.mode == UserMode.provider ? 'Modo Profissional' : 'Modo Cliente',
            ),
            findsOneWidget,
          );
          expect(find.text('Seus dados'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('step0-welcome-hero-card')),
            findsOneWidget,
          );
          expect(find.text('Bem-vindo, você!'), findsOneWidget);
          expect(find.byType(AppAvatar), findsOneWidget);
          expect(find.text('1. Dados e endereço'), findsOneWidget);
          expect(find.text('2. Rosto e documento'), findsOneWidget);
          expect(find.text('3. Selo de segurança'), findsOneWidget);
          expect(find.text('Seus dados pessoais'), findsOneWidget);
          expect(find.text('0 de 3'), findsOneWidget);
          expect(find.text('Validade 6 meses'), findsOneWidget);

          // Preenche Nome -> 1 de 3
          await tester.enterText(
            find.byKey(const ValueKey('client-setup-name')),
            'Wagner Oliveira',
          );
          await tester.pump();
          expect(find.text('1 de 3'), findsOneWidget);

          // Preenche Telefone -> 2 de 3
          await tester.enterText(
            find.byKey(const ValueKey('client-setup-phone')),
            '35999887766',
          );
          await tester.pump();
          expect(find.text('2 de 3'), findsOneWidget);

          // Preenche CPF válido -> 3 de 3 · Tudo certo
          await tester.enterText(
            find.byKey(const ValueKey('client-setup-cpf')),
            '11978723610',
          );
          await tester.pump();
          expect(find.text('3 de 3 · Tudo certo'), findsOneWidget);
          expect(
            find.text('CPF válido e verificado com sucesso'),
            findsOneWidget,
          );

          // Avança para Etapa 2 (testando transição AnimatedSwitcher no meio e ao fim)
          await tester.tap(
            find.byKey(const ValueKey('client-setup-step0-continue')),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 90));
          expect(tester.takeException(), isNull);
          await tester.pumpAndSettle();
          _assertZeroOverflowAndZeroJargon(tester, 'Etapa 2 (${vp.label})');

          // --- ETAPA 2: Localização + Selo de Geo-Privacidade + Máscara CEP 00000-000 ---
          expect(find.text('Localização'), findsOneWidget);
          expect(find.byType(KycTrustMicroBadge), findsOneWidget);
          expect(
            find.text(
              vp.mode == UserMode.provider
                  ? 'Sua localização exata nunca fica pública no mapa'
                  : 'Endereço oculto até você aprovar o orçamento',
            ),
            findsOneWidget,
          );
          expect(find.byType(AddressForm), findsOneWidget);

          final addressFields = find.byType(TextField);
          await tester.enterText(addressFields.at(0), '37750000');
          await tester.pump();
          final cepField = tester.widget<TextField>(addressFields.at(0));
          expect(cepField.controller?.text, equals('37750-000'));

          await tester.enterText(addressFields.at(1), 'Rua Padre José Geraldi');
          await tester.enterText(addressFields.at(2), '203');
          await tester.enterText(addressFields.at(4), 'Centro');
          await tester.enterText(addressFields.at(5), 'Machado');
          await tester.enterText(addressFields.at(6), 'MG');
          await tester.pump();

          await tester.tap(
            find.byKey(const ValueKey('client-setup-step1-continue')),
          );
          await tester.pumpAndSettle();
          _assertZeroOverflowAndZeroJargon(tester, 'Etapa 3 (${vp.label})');

          // --- ETAPA 3: Prova de Vida Facial + KycFaceIdIllustration ---
          expect(find.text('Prova de vida'), findsOneWidget);
          expect(find.byType(KycFaceIdIllustration), findsOneWidget);
          expect(
            find.byKey(const ValueKey('liveness-prep-card')),
            findsOneWidget,
          );
          expect(
            find.text('Protegido pela LGPD · Válido por 6 meses'),
            findsOneWidget,
          );

          final startLiveness = find.byKey(const ValueKey('btn-start-liveness'));
          await tester.ensureVisible(startLiveness);
          await tester.tap(startLiveness);
          await tester.pumpAndSettle();
          _assertZeroOverflowAndZeroJargon(
            tester,
            'Etapa 3 Aprovada (${vp.label})',
          );
          expect(
            find.byKey(const ValueKey('liveness-approved-card')),
            findsOneWidget,
          );
          expect(find.text('Prova de Vida Homologada!'), findsOneWidget);

          await tester.tap(
            find.byKey(const ValueKey('client-setup-step2-continue')),
          );
          await tester.pumpAndSettle();
          _assertZeroOverflowAndZeroJargon(tester, 'Etapa 4 (${vp.label})');

          // --- ETAPA 4: Documento + KycDocumentCardWireframe (Frente e Verso) ---
          expect(find.text('Documento'), findsOneWidget);
          expect(find.text('Qual documento você vai usar?'), findsOneWidget);
          expect(find.byType(KycDocumentCardWireframe), findsNWidgets(2));
          expect(find.text('Abrir câmera'), findsNWidgets(2));

          final frontCard = find.byKey(const ValueKey('capture-doc-front'));
          await tester.ensureVisible(frontCard);
          await tester.tap(frontCard);
          await tester.pumpAndSettle();
          expect(find.text('Frente validada'), findsOneWidget);
          expect(find.byType(KycDocumentCardWireframe), findsOneWidget);

          final backCard = find.byKey(const ValueKey('capture-doc-back'));
          await tester.ensureVisible(backCard);
          await tester.tap(backCard);
          await tester.pumpAndSettle();
          _assertZeroOverflowAndZeroJargon(tester, 'Etapa 5 (${vp.label})');

          // --- ETAPA 5: DocumentOcrReviewStep Redesenhada ---
          expect(find.text('Conferência'), findsOneWidget);
          expect(find.byType(DocumentOcrReviewStep), findsOneWidget);
          expect(
            find.text('Leitura confirmada com sucesso'),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('ocr-review-confirmed-chip')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('ocr-thumbnails-strip')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('ocr-transcribed-card')),
            findsOneWidget,
          );
          expect(find.textContaining('***.787.236-**'), findsOneWidget);

          final toggleCpf = find.byKey(const ValueKey('toggle-cpf-reveal'));
          await tester.ensureVisible(toggleCpf);
          await tester.tap(toggleCpf);
          await tester.pump();
          expect(find.textContaining('119.787.236-10'), findsOneWidget);

          await tester.tap(
            find.byKey(const ValueKey('client-setup-step3-continue')),
          );
          await tester.pumpAndSettle();
          _assertZeroOverflowAndZeroJargon(tester, 'Etapa 6 (${vp.label})');

          // --- ETAPA 6: CriminalBackgroundCheckStep Redesenhada ---
          expect(find.text('Antecedentes'), findsOneWidget);
          expect(find.byType(CriminalBackgroundCheckStep), findsOneWidget);
          expect(
            find.text('Certidão de Antecedentes Criminais (Polícia Federal)'),
            findsOneWidget,
          );
          expect(find.byType(KycPorcelainSectionCard), findsNWidgets(2));
          expect(
            find.byKey(const ValueKey('criminal-check-approved-card')),
            findsOneWidget,
          );

          await tester.tap(
            find.byKey(const ValueKey('client-setup-step4-submit')),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(submitted, isTrue);
        },
      );
    }

    testWidgets(
      'CriminalBackgroundCheckStep redesenhada executa envio via Pasta Downloads, autopreenche e remove anexo com movimento reduzido (disableAnimations: true)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final pdfBytes = _buildValidPfPdfBytes();
        final refNow = DateTime.utc(2026, 11, 18, 12);
        AuditedCriminalRecordResult? latest;

        await tester.pumpWidget(
          _buildResponsiveApp(
            mode: UserMode.client,
            brightness: Brightness.light,
            textScale: 1.5,
            disableAnimations: true,
            home: Scaffold(
              body: KycAmbientBackdrop(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpace.s16),
                  child: CriminalBackgroundCheckStep(
                    expectedFullName: 'Wagner Oliveira Claudiano',
                    expectedCpfRaw: '119.787.236-10',
                    referenceNow: refNow,
                    customDownloadsPicker: () async => (
                      bytes: pdfBytes,
                      fileName: 'certidao_pf_v30.pdf',
                    ),
                    customCertificateExtractor: ({
                      required bytes,
                      required fileName,
                    }) async {
                      final text = CriminalBackgroundService
                          .extractReadableTextFromPdfOrBytes(bytes);
                      return CriminalCertificateExtractionResult(
                        extractedText: text,
                        fields: CriminalBackgroundService
                            .extractCertificateFieldsFromText(text),
                        source: 'pdf_text',
                      );
                    },
                    onValidated: (res) => latest = res,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        _assertZeroOverflowAndZeroJargon(
          tester,
          'CriminalStep reducedMotion 320x640 @ 1.5x',
        );

        expect(find.byType(KycStepHeroHeader), findsOneWidget);
        expect(find.byType(KycPorcelainSectionCard), findsNWidgets(2));

        final uploadBtn = find.byKey(
          const ValueKey('btn-upload-criminal-certificate'),
        );
        await tester.ensureVisible(uploadBtn);
        await tester.tap(uploadBtn);
        await tester.pumpAndSettle();

        final downloadsTile = find.byKey(
          const ValueKey('sheet-pick-criminal-downloads'),
        );
        await tester.ensureVisible(downloadsTile);
        await tester.tap(downloadsTile);
        await tester.pumpAndSettle();

        expect(latest?.passed, isTrue);
        expect(
          find.byKey(const ValueKey('criminal-attached-file-card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('criminal-check-approved-card')),
          findsOneWidget,
        );
        _assertZeroOverflowAndZeroJargon(
          tester,
          'CriminalStep attached 320x640 @ 1.5x',
        );
      },
    );
  });
}

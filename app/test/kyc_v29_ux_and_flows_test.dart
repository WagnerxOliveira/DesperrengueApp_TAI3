import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/active_liveness_engine.dart';
import 'package:desperrengue_app/core/services/criminal_background_service.dart';
import 'package:desperrengue_app/core/services/criminal_certificate_picker_and_extractor.dart';
import 'package:desperrengue_app/core/services/document_frame_alignment_engine.dart';
import 'package:desperrengue_app/core/services/document_ocr_and_liveness_service.dart';
import 'package:desperrengue_app/core/services/face_detection_adapter.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/design_system/design_system.dart';
import 'package:desperrengue_app/core/ui/kyc_human_feedback_translator.dart';
import 'package:desperrengue_app/features/client/presentation/client_setup_screen.dart';
import 'package:desperrengue_app/features/shared/presentation/criminal_background_check_step.dart';

typedef _ViewportSpec = ({
  Size size,
  double textScale,
  Brightness brightness,
  String label,
});

const List<_ViewportSpec> _uxMatrix = <_ViewportSpec>[
  (
    size: Size(320, 640),
    textScale: 1.0,
    brightness: Brightness.light,
    label: '320x640 @ 1.0x Light',
  ),
  (
    size: Size(320, 640),
    textScale: 1.5,
    brightness: Brightness.dark,
    label: '320x640 @ 1.5x Dark',
  ),
  (
    size: Size(390, 844),
    textScale: 1.0,
    brightness: Brightness.dark,
    label: '390x844 @ 1.0x Dark',
  ),
  (
    size: Size(390, 844),
    textScale: 1.5,
    brightness: Brightness.light,
    label: '390x844 @ 1.5x Light',
  ),
  (
    size: Size(1280, 800),
    textScale: 1.0,
    brightness: Brightness.light,
    label: '1280x800 @ 1.0x Light',
  ),
  (
    size: Size(1280, 800),
    textScale: 1.5,
    brightness: Brightness.dark,
    label: '1280x800 @ 1.5x Dark',
  ),
];

Widget _buildResponsiveApp({
  required Widget home,
  required Brightness brightness,
  required double textScale,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    theme: AppTheme.resolve(UserMode.client, brightness),
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

void _assertZeroBannedTechnicalJargon(WidgetTester tester) {
  for (final element in find.byType(Text).evaluate()) {
    final textWidget = element.widget as Text;
    final content =
        textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
    expect(
      KycHumanFeedbackTranslator.containsBannedTechnicalJargon(content),
      isFalse,
      reason: 'Texto visível na UI contém jargão técnico proibido: "$content"',
    );
  }
}

Uint8List _buildValidPfNothingOnRecordPdfBytes({
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

LiveFaceObservation _validFaceObservation({
  required int tsMs,
  int faceCount = 1,
}) {
  return LiveFaceObservation(
    faceCount: faceCount,
    trackingId: 7,
    normalizedBox: const Rect.fromLTWH(0.28, 0.22, 0.44, 0.50),
    leftEyeOpenProbability: 0.92,
    rightEyeOpenProbability: 0.91,
    headEulerAngleX: 1.0,
    headEulerAngleY: 0.5,
    headEulerAngleZ: 0.2,
    meanLuminance: 136.0,
    sharpness: 62.0,
    blueMonitorRatio: 0.04,
    textureMotionDelta: 0.65,
    timestampMs: tsMs,
    sourceEngine: 'test_live_stream',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('1. ClientSetupScreen v2.29.0 — Fluxo Completo de 6 Etapas (Responsividade + UX)', () {
    for (final vp in _uxMatrix) {
      testWidgets(
        'executa 6 etapas (Preparação Liveness -> Captura Doc sem OCR -> Tela Dedicada OCR -> Antecedentes PF) sem overflow/jargão em ${vp.label}',
        (tester) async {
          tester.view.physicalSize = vp.size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final selfieBytes =
              DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
            variantSeed: 1,
          );
          final frontDocBytes =
              DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
            variantSeed: 1,
            rotateDegrees: 90,
          );
          final backDocBytes =
              DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
            variantSeed: 2,
          );

          final criminalOverride =
              await CriminalBackgroundService.analyzeAndValidateCertificate(
            fileBytes: _buildValidPfNothingOnRecordPdfBytes(),
            fileName: 'certidao_pf.pdf',
            expectedFullName: 'Wagner Oliveira',
            expectedCpfRaw: '119.787.236-10',
            referenceNow: DateTime.utc(2026, 11, 18, 12),
          );
          expect(criminalOverride.passed, isTrue);

          int cameraCaptureCalls = 0;
          bool submitted = false;

          await tester.pumpWidget(
            _buildResponsiveApp(
              brightness: vp.brightness,
              textScale: vp.textScale,
              home: ClientSetupScreen(
                profile: UserProfile.fromMap(const <String, dynamic>{
                  'id': 'client-v29-e2e',
                  'full_name': 'Wagner Oliveira',
                  'phone': '35999887766',
                  'is_client': true,
                }),
                customCriminalResultOverride: criminalOverride,
                customCameraCapture: ({required String slot}) async {
                  cameraCaptureCalls++;
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
          expect(tester.takeException(), isNull);
          _assertZeroBannedTechnicalJargon(tester);

          // Etapa 1: Dados civis
          await tester.enterText(
            find.byKey(const ValueKey('client-setup-cpf')),
            '11978723610',
          );
          await tester.pump();
          await tester.tap(
            find.byKey(const ValueKey('client-setup-step0-continue')),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Etapa 2: Endereço
          final fields = find.byType(TextField);
          await tester.enterText(fields.at(1), 'Rua Padre José Geraldi');
          await tester.enterText(fields.at(2), '203');
          await tester.enterText(fields.at(4), 'Centro');
          await tester.enterText(fields.at(5), 'Machado');
          await tester.enterText(fields.at(6), 'MG');
          await tester.pump();
          await tester.tap(
            find.byKey(const ValueKey('client-setup-step1-continue')),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Etapa 3: Preparação ANTES de abrir a câmera (NÃO dispara câmera sozinha!)
          expect(cameraCaptureCalls, equals(0));
          expect(find.byType(ActiveLivenessFullscreenModal), findsNothing);
          expect(
            find.byKey(const ValueKey('liveness-prep-card')),
            findsOneWidget,
          );
          expect(find.text('Iniciar Prova de Vida'), findsOneWidget);
          expect(find.textContaining('Protegido pela LGPD'), findsOneWidget);
          _assertZeroBannedTechnicalJargon(tester);

          // Toca em Iniciar Prova de Vida -> aprova e mostra card de sucesso
          final startLivenessBtn =
              find.byKey(const ValueKey('btn-start-liveness'));
          await tester.ensureVisible(startLivenessBtn);
          await tester.tap(startLivenessBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(cameraCaptureCalls, equals(1));
          expect(
            find.byKey(const ValueKey('liveness-approved-card')),
            findsOneWidget,
          );
          expect(find.text('Prova de Vida Homologada!'), findsOneWidget);
          expect(find.text('Refazer Prova de Vida'), findsOneWidget);
          _assertZeroBannedTechnicalJargon(tester);

          // Avança para Etapa 4 (Somente captura Frente/Verso — SEM card OCR!)
          await tester.tap(
            find.byKey(const ValueKey('client-setup-step2-continue')),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Validação Oficial do Documento'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('ocr-transcribed-card')),
            findsNothing,
          );
          _assertZeroBannedTechnicalJargon(tester);

          // Captura Frente -> badge "Frente validada" e ainda sem card OCR nesta tela
          final frontCard = find.byKey(const ValueKey('capture-doc-front'));
          await tester.ensureVisible(frontCard);
          await tester.tap(frontCard);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Frente validada'), findsOneWidget);
          expect(find.text('Toque para refazer'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('ocr-transcribed-card')),
            findsNothing,
          );

          // Captura Verso -> executa OCR e avança automaticamente para Etapa 5 (DocumentOcrReviewStep)
          final backCard = find.byKey(const ValueKey('capture-doc-back'));
          await tester.ensureVisible(backCard);
          await tester.tap(backCard);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Etapa 5: Tela dedicada DocumentOcrReviewStep
          expect(find.byType(DocumentOcrReviewStep), findsOneWidget);
          expect(
            find.byKey(const ValueKey('ocr-review-confirmed-chip')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('ocr-transcribed-card')),
            findsOneWidget,
          );
          expect(find.text('WAGNER OLIVEIRA CLAUDIANO'), findsOneWidget);
          expect(find.textContaining('***.787.236-**'), findsOneWidget);
          expect(find.textContaining('119.787.236-10'), findsNothing);
          _assertZeroBannedTechnicalJargon(tester);

          // Toggle CPF (revela e oculta)
          final toggleCpf = find.byKey(const ValueKey('toggle-cpf-reveal'));
          await tester.ensureVisible(toggleCpf);
          await tester.tap(toggleCpf);
          await tester.pump();
          expect(find.textContaining('119.787.236-10'), findsOneWidget);
          await tester.tap(toggleCpf);
          await tester.pump();
          expect(find.textContaining('***.787.236-**'), findsOneWidget);

          // Botão "Refazer fotos" volta à Etapa 4 (com "Frente validada" e "Verso validado")
          final retakeBtn = find.byKey(const ValueKey('btn-ocr-retake-photos'));
          await tester.ensureVisible(retakeBtn);
          await tester.tap(retakeBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(DocumentOcrReviewStep), findsNothing);
          expect(find.text('Frente validada'), findsOneWidget);
          expect(find.text('Verso validado'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('ocr-transcribed-card')),
            findsNothing,
          );

          // Botão do rodapé "Ler e Conferir Dados do Documento" volta direto à Etapa 5
          await tester.tap(
            find.byKey(const ValueKey('client-setup-step3-read-ocr')),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(DocumentOcrReviewStep), findsOneWidget);

          // Avança para Etapa 6 (Antecedentes Criminais PF)
          await tester.tap(
            find.byKey(const ValueKey('client-setup-step3-continue')),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(CriminalBackgroundCheckStep), findsOneWidget);
          expect(
            find.byKey(const ValueKey('btn-camera-criminal-certificate')),
            findsNothing,
          );
          expect(find.text('Fotografar Certidão'), findsNothing);
          _assertZeroBannedTechnicalJargon(tester);

          // Conclui jornada
          await tester.tap(
            find.byKey(const ValueKey('client-setup-step4-submit')),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(submitted, isTrue);
        },
      );
    }
  });

  group('2. Câmera Fullscreen de Prova de Vida (Vermelho -> Verde) em 3 Viewports', () {
    for (final vp in _uxMatrix) {
      testWidgets(
        'ActiveLivenessFullscreenModal transita contorno vermelho -> verde sem overflow/jargão em ${vp.label}',
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
              brightness: vp.brightness,
              textScale: vp.textScale,
              disableAnimations: true,
              home: ActiveLivenessFullscreenModal(
                cpfDigits: '11978723610',
                forcedDirection: LivenessTurnDirection.right,
                testObservationStream: streamCtrl.stream,
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);

          ActiveLivenessOvalPainter readPainter() {
            final paint = tester.widget<CustomPaint>(
              find.descendant(
                of: find.byKey(ActiveLivenessFullscreenModal.ovalOverlayKey),
                matching: find.byType(CustomPaint),
              ),
            );
            return paint.painter! as ActiveLivenessOvalPainter;
          }

          expect(readPainter().contourColor, AppTokens.dark.danger);
          _assertZeroBannedTechnicalJargon(tester);

          // Frame com rosto centralizado válido -> contorno fica verde
          streamCtrl.add(_validFaceObservation(tsMs: 1000));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(readPainter().contourColor, AppTokens.dark.success);
          _assertZeroBannedTechnicalJargon(tester);
        },
      );
    }
  });

  group('3. Scanner Fullscreen de Documento (Vermelho Bloqueado -> Verde Habilitado)', () {
    for (final vp in _uxMatrix) {
      testWidgets(
        'DocumentGuidedScannerModal bloqueia no vermelho e libera no verde sem overflow/jargão em ${vp.label}',
        (tester) async {
          tester.view.physicalSize = vp.size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final streamCtrl =
              StreamController<DocumentFrameAssessment>.broadcast(sync: true);
          addTearDown(streamCtrl.close);

          await tester.pumpWidget(
            _buildResponsiveApp(
              brightness: vp.brightness,
              textScale: vp.textScale,
              home: DocumentGuidedScannerModal(
                isFront: true,
                documentType: OfficialDocumentType.cnh,
                autoCaptureEnabled: false,
                testAssessmentStream: streamCtrl.stream,
                testInitialAssessment: const DocumentFrameAssessment(
                  status: DocumentFrameStatus.noDocument,
                  humanHint: 'Enquadre a frente do documento dentro da moldura',
                  edgeAlignmentScore: 0.12,
                  interiorExteriorContrast: 8.0,
                  laplacianSharpness: 40.0,
                  glareRatioPct: 1.0,
                  meanLuminance: 130.0,
                  contentDensityScore: 0.10,
                  edgesDetectedCount: 0,
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('scanner-frame-red')),
            findsOneWidget,
          );
          final captureBtnBefore = tester.widget<AppButton>(
            find.byKey(const ValueKey('btn-capture-guided-document')),
          );
          expect(captureBtnBefore.onPressed, isNull);
          _assertZeroBannedTechnicalJargon(tester);

          // 3 quadros estáveis alinhados -> verde + botão habilitado
          for (int i = 0; i < 3; i++) {
            streamCtrl.add(DocumentFrameAssessment.aligned());
            await tester.pump();
          }
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('scanner-frame-green')),
            findsOneWidget,
          );
          final captureBtnAfter = tester.widget<AppButton>(
            find.byKey(const ValueKey('btn-capture-guided-document')),
          );
          expect(captureBtnAfter.onPressed, isNotNull);
          _assertZeroBannedTechnicalJargon(tester);
        },
      );
    }
  });

  group('4. Etapa 6 — Certidão PF (Sheet Downloads/Galeria/Câmera + Autopreenchimento + Remover)', () {
    for (final vp in _uxMatrix) {
      testWidgets(
        'sem botão solto "Fotografar Certidão", sheet com 3 fontes, autopreenche e remove anexo em ${vp.label}',
        (tester) async {
          tester.view.physicalSize = vp.size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final refNow = DateTime.utc(2026, 11, 18, 12);
          final pdfBytes = _buildValidPfNothingOnRecordPdfBytes();
          final results = <AuditedCriminalRecordResult?>[];

          await tester.pumpWidget(
            _buildResponsiveApp(
              brightness: vp.brightness,
              textScale: vp.textScale,
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpace.s16),
                  child: CriminalBackgroundCheckStep(
                    expectedFullName: 'Wagner Oliveira Claudiano',
                    expectedCpfRaw: '119.787.236-10',
                    referenceNow: refNow,
                    customDownloadsPicker: () async => (
                      bytes: pdfBytes,
                      fileName: 'certidao_pf_downloads.pdf',
                    ),
                    customGalleryPicker: () async => null,
                    customCameraPicker: () async => null,
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
                    onValidated: results.add,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Sem botão solto "Fotografar Certidão"
          expect(
            find.byKey(const ValueKey('btn-camera-criminal-certificate')),
            findsNothing,
          );
          expect(find.text('Fotografar Certidão'), findsNothing);
          _assertZeroBannedTechnicalJargon(tester);

          // Abre sheet com Downloads / Galeria / Câmera
          final uploadBtn =
              find.byKey(const ValueKey('btn-upload-criminal-certificate'));
          await tester.ensureVisible(uploadBtn);
          await tester.tap(uploadBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(
            find.byKey(const ValueKey('sheet-pick-criminal-downloads')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('sheet-pick-criminal-gallery')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('sheet-pick-criminal-camera')),
            findsOneWidget,
          );
          expect(find.text('Recomendado'), findsOneWidget);
          _assertZeroBannedTechnicalJargon(tester);

          // Seleciona Downloads -> anexa, autopreenche e aprova
          final downloadsOption =
              find.byKey(const ValueKey('sheet-pick-criminal-downloads'));
          await tester.ensureVisible(downloadsOption);
          await tester.pumpAndSettle();
          await tester.tap(downloadsOption);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(
            find.byKey(const ValueKey('criminal-attached-file-card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('criminal-check-approved-card')),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('input-criminal-protocol')), findsNothing);
          expect(find.byKey(const ValueKey('input-criminal-validation-code')), findsNothing);
          expect(find.text('PF-***1735'), findsOneWidget);
          expect(results.isNotEmpty && results.last?.passed == true, isTrue);
          expect(results.last?.protocolNumber, equals('2026.0849201735'));
          expect(results.last?.validationCode, equals('9482.7163.5041.8829'));
          _assertZeroBannedTechnicalJargon(tester);

          // Botão Remover anexo (>= 48x48) limpa arquivo, campos e notifica onValidated(null)
          final removeBtn =
              find.byKey(const ValueKey('btn-remove-criminal-certificate'));
          await tester.ensureVisible(removeBtn);
          await tester.pumpAndSettle();
          final removeSize = tester.getSize(removeBtn);
          expect(removeSize.width, greaterThanOrEqualTo(48.0));
          expect(removeSize.height, greaterThanOrEqualTo(48.0));

          await tester.tap(removeBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(
            find.byKey(const ValueKey('criminal-attached-file-card')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('criminal-check-approved-card')),
            findsNothing,
          );
          expect(results.last, isNull);
          _assertZeroBannedTechnicalJargon(tester);
        },
      );
    }
  });
}

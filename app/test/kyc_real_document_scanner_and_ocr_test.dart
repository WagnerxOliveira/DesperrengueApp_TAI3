import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:desperrengue_app/core/services/document_frame_alignment_engine.dart';
import 'package:desperrengue_app/core/services/document_ocr_and_liveness_service.dart';
import 'package:desperrengue_app/core/services/document_real_ocr_engine.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/kyc_human_feedback_translator.dart';
import 'package:desperrengue_app/features/client/presentation/document_guided_scanner_modal.dart';
import 'package:desperrengue_app/features/client/presentation/document_ocr_review_step.dart';

/// Constrói um quadro sintético de câmera (`240x180`) simulando uma mesa escura
/// com um cartão de documento impresso (frente ou verso) posicionado no retângulo ROI
/// horizontal (`left=6%, top=22%, width=88%, height=56%`).
Uint8List _buildSyntheticCameraFrame({
  bool hasDocument = true,
  bool isBackSide = false,
  bool outOfBounds = false,
  bool tooFar = false,
  bool blurry = false,
  bool excessiveGlare = false,
  bool blankPaper = false,
  bool darkLighting = false,
  bool brightLighting = false,
}) {
  const int w = 240;
  const int h = 180;
  final img.Image canvas = img.Image(width: w, height: h);

  // Mesa uniforme (escura em modo darkLighting, madeira média no normal)
  final int tableBase = darkLighting ? 14 : 68;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final int tableLum = tableBase + ((x + y) % 5);
      canvas.setPixelRgb(x, y, tableLum, tableLum - 3, tableLum - 5);
    }
  }

  if (!hasDocument) {
    return Uint8List.fromList(img.encodePng(canvas));
  }

  // Coordenadas do ROI horizontal: x=[14..225], y=[40..140]
  int dx0 = 14;
  int dy0 = 40;
  int dx1 = 225;
  int dy1 = 140;

  if (outOfBounds) {
    // Cartão deslocado para a esquerda/topo, cortado fora da moldura
    dx0 = 0;
    dy0 = 8;
    dx1 = 190;
    dy1 = 115;
  } else if (tooFar) {
    // Cartão pequeno no centro do retângulo (~38% da área do ROI)
    dx0 = 76;
    dy0 = 66;
    dx1 = 164;
    dy1 = 114;
  }

  final int baseBg = darkLighting
      ? 36
      : (brightLighting ? 242 : 204);

  for (int y = dy0; y < dy1; y++) {
    for (int x = dx0; x < dx1; x++) {
      if (excessiveGlare && x >= dx0 + 35 && x <= dx0 + 135 && y >= dy0 + 18 && y <= dy0 + 70) {
        canvas.setPixelRgb(x, y, 255, 255, 255);
        continue;
      }

      if (blankPaper) {
        final int paper = 198 + ((x + y) % 3);
        canvas.setPixelRgb(x, y, paper, paper, paper);
        continue;
      }

      if (brightLighting) {
        // Documento superexposto (lavado de luz: luminância média ~238 > 228, sem pixels > 248)
        final bool washedMark = ((x - dx0) % 7 < 2) && ((y - dy0) % 9 < 3);
        final int v = washedMark ? 222 : 242;
        canvas.setPixelRgb(x, y, v, v, v);
        continue;
      }

      if (blurry) {
        // Gradiente suave de baixa frequência (tem variação de cor mas Laplaciano baixo)
        final double relX = (x - dx0) / (dx1 - dx0);
        final double relY = (y - dy0) / (dy1 - dy0);
        final int smooth = (115 + (relX * 55) + (relY * 25)).round().clamp(60, 210);
        canvas.setPixelRgb(x, y, smooth, smooth - 6, smooth - 10);
        continue;
      }

      final double rx = (x - dx0) / (dx1 - dx0);
      final double ry = (y - dy0) / (dy1 - dy0);

      if (!isBackSide) {
        // Frente: faixa verde/topo + foto 3x4 à esquerda + linhas impressas à direita
        if (ry < 0.14) {
          final int headerLum = ((x % 4) < 2) ? (baseBg - 90) : (baseBg - 40);
          final int v = headerLum.clamp(12, 245);
          canvas.setPixelRgb(x, y, (v * 0.7).round(), v, (v * 0.8).round());
        } else if (rx >= 0.06 && rx <= 0.32 && ry >= 0.22 && ry <= 0.78) {
          // Foto 3x4 texturizada
          final int faceTex =
              (((x * 7 + y * 11) % 2 == 0) ? (baseBg - 110) : (baseBg - 55))
                  .clamp(15, 240);
          canvas.setPixelRgb(x, y, faceTex, (faceTex * 0.82).round(), (faceTex * 0.70).round());
        } else if (rx >= 0.38 && rx <= 0.94 && ry >= 0.22 && ry <= 0.86) {
          // Linhas de texto impressas de alto contraste
          final bool isTextRow = ((y - dy0) % 9) < 3;
          final bool isGlyph = ((x - dx0) % 4) < 2;
          final int ink = (isTextRow && isGlyph) ? (baseBg - 135) : baseBg;
          final int v = ink.clamp(10, 245);
          canvas.setPixelRgb(x, y, v, v, v);
        } else {
          final int v = baseBg.clamp(10, 245);
          canvas.setPixelRgb(x, y, v, v, (v - 6).clamp(10, 245));
        }
      } else {
        // Verso: QR Code denso à direita + faixa MRZ inferior
        final bool isQr = rx >= 0.56 && rx <= 0.92 && ry >= 0.14 && ry <= 0.66;
        final bool isMrz = rx >= 0.06 && rx <= 0.94 && ry >= 0.72 && ry <= 0.92;
        if (isQr) {
          final bool darkModule =
              ((((x - dx0) ~/ 3) + ((y - dy0) ~/ 3)) % 2 == 0) ^ (((x * y) % 5) == 0);
          final int v = (darkModule ? (baseBg - 160) : baseBg).clamp(10, 245);
          canvas.setPixelRgb(x, y, v, v, v);
        } else if (isMrz) {
          final bool bar = (((x - dx0) % 3) == 0) && (((y - dy0) % 5) < 3);
          final int v = (bar ? (baseBg - 145) : baseBg).clamp(10, 245);
          canvas.setPixelRgb(x, y, v, v, v);
        } else {
          final bool subText = rx < 0.50 && ((y - dy0) % 11) < 3 && ((x - dx0) % 3) < 2;
          final int v = (subText ? (baseBg - 120) : baseBg).clamp(10, 245);
          canvas.setPixelRgb(x, y, v, v, v);
        }
      }
    }
  }

  return Uint8List.fromList(img.encodePng(canvas));
}

AuditedDocumentOcrResult _sampleAuditedOcrResult() {
  return AuditedDocumentOcrResult(
    documentType: OfficialDocumentType.cnh,
    extractedFullName: 'MARIA CLARA MENDES SILVA',
    extractedCpfDigits: '52998224725',
    extractedCpfFormatted: '529.982.247-25',
    extractedCpfMasked: '***.982.247-**',
    cpfHash: DocumentOcrAndLivenessService.computeCpfHash('52998224725'),
    extractedDocumentNumber: '04829173654',
    extractedDocumentNumberMasked: '***-3654',
    extractedBirthDate: DateTime.utc(1992, 6, 18),
    extractedBirthDateFormatted: '18/06/1992',
    extractedIssuingAuthority: 'DETRAN/MG',
    frontPerceptualHash64: 0x123456789ABCDEF0,
    backPerceptualHash64: 0x0FEDCBA987654321,
    frontBackHammingDistance: 28,
    frontBackMadScore: 42.5,
    detectedRotationDegrees: 0,
    laplacianSharpnessScore: 284.0,
    specularGlareRatioPct: 1.4,
    ocrConfidenceScore: 96.5,
    faceMatchCosineSimilarity: 0.932,
    nameCrossCheckSimilarity: 1.0,
    mrzOrQrChecksumValid: true,
    officialHeaderDetected: true,
    isAuthenticAndCrossChecked: true,
    forensicVerificationSeal: 'DSP-OCR-SHA256-9A8B7C6D5E4F3A2B1C0D',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. DocumentFrameAlignmentEngine & DocumentAlignmentTracker', () {
    test('Rejeita mesa vazia / parede uniforme como noDocument (VERMELHO)', () {
      final emptyDesk = _buildSyntheticCameraFrame(hasDocument: false);
      final assessment = DocumentFrameAlignmentEngine.evaluateFrameBytes(
        frameBytes: emptyDesk,
        isFront: true,
      );
      expect(assessment.isValid, isFalse);
      expect(assessment.status, equals(DocumentFrameStatus.noDocument));
      expect(
        KycHumanFeedbackTranslator.containsBannedTechnicalJargon(assessment.humanHint),
        isFalse,
      );
    });

    test('Rejeita documento cortado fora das margens como outOfBounds (VERMELHO)', () {
      final cutDoc = _buildSyntheticCameraFrame(outOfBounds: true);
      final assessment = DocumentFrameAlignmentEngine.evaluateFrameBytes(
        frameBytes: cutDoc,
        isFront: true,
      );
      expect(assessment.isValid, isFalse);
      expect(assessment.status, equals(DocumentFrameStatus.outOfBounds));
    });

    test('Rejeita documento muito distante como tooFar (VERMELHO)', () {
      final farDoc = _buildSyntheticCameraFrame(tooFar: true);
      final assessment = DocumentFrameAlignmentEngine.evaluateFrameBytes(
        frameBytes: farDoc,
        isFront: true,
      );
      expect(assessment.isValid, isFalse);
      expect(assessment.status, equals(DocumentFrameStatus.tooFar));
    });

    test('Rejeita documento borrado (Laplaciano < 115) como blurry (VERMELHO)', () {
      final blurryDoc = _buildSyntheticCameraFrame(blurry: true);
      final assessment = DocumentFrameAlignmentEngine.evaluateFrameBytes(
        frameBytes: blurryDoc,
        isFront: true,
      );
      expect(assessment.isValid, isFalse);
      expect(assessment.status, equals(DocumentFrameStatus.blurry));
      expect(assessment.laplacianSharpness, lessThan(115.0));
    });

    test('Rejeita reflexo especular > 7.5% como excessiveGlare (VERMELHO)', () {
      final glareDoc = _buildSyntheticCameraFrame(excessiveGlare: true);
      final assessment = DocumentFrameAlignmentEngine.evaluateFrameBytes(
        frameBytes: glareDoc,
        isFront: true,
      );
      expect(assessment.isValid, isFalse);
      expect(assessment.status, equals(DocumentFrameStatus.excessiveGlare));
      expect(assessment.glareRatioPct, greaterThan(7.5));
    });

    test('Rejeita iluminação escura (< 55) ou estourada (> 228) como poorLighting (VERMELHO)', () {
      final darkDoc = _buildSyntheticCameraFrame(darkLighting: true);
      final brightDoc = _buildSyntheticCameraFrame(brightLighting: true);

      final darkEval = DocumentFrameAlignmentEngine.evaluateFrameBytes(
        frameBytes: darkDoc,
        isFront: true,
      );
      expect(darkEval.isValid, isFalse);
      expect(darkEval.status, equals(DocumentFrameStatus.poorLighting));

      final brightEval = DocumentFrameAlignmentEngine.evaluateFrameBytes(
        frameBytes: brightDoc,
        isFront: true,
      );
      expect(brightEval.isValid, isFalse);
      expect(brightEval.status, equals(DocumentFrameStatus.poorLighting));
    });

    test('Rejeita papel em branco sem conteúdo impresso como blankOrLowDetail (VERMELHO)', () {
      final blank = _buildSyntheticCameraFrame(blankPaper: true);
      final assessment = DocumentFrameAlignmentEngine.evaluateFrameBytes(
        frameBytes: blank,
        isFront: true,
      );
      expect(assessment.isValid, isFalse);
      expect(assessment.status, equals(DocumentFrameStatus.blankOrLowDetail));
    });

    test('Bloqueia apresentar a Frente de novo no lugar do Verso (duplicateOfFront — VERMELHO) e aprova Verso real', () {
      final frontFull = _buildSyntheticCameraFrame(isBackSide: false);
      final backFull = _buildSyntheticCameraFrame(isBackSide: true);
      final frontCropped = DocumentOcrAndLivenessService.cropDocumentToGuidedFrameNamed(
        fullCameraFrameBytes: frontFull,
      );

      // Frente bem enquadrada -> válida
      final frontEval = DocumentFrameAlignmentEngine.evaluateFrameBytes(
        frameBytes: frontFull,
        isFront: true,
      );
      expect(frontEval.isValid, isTrue);
      expect(frontEval.status, equals(DocumentFrameStatus.aligned));
      expect(frontEval.edgesDetectedCount, equals(4));

      // Mostrar a Frente de novo na captura do Verso -> duplicateOfFront!
      final duplicateBackEval = DocumentFrameAlignmentEngine.evaluateFrameBytes(
        frameBytes: frontFull,
        isFront: false,
        referenceFrontBytes: frontCropped,
      );
      expect(duplicateBackEval.isValid, isFalse);
      expect(duplicateBackEval.status, equals(DocumentFrameStatus.duplicateOfFront));
      expect(
        duplicateBackEval.humanHint,
        equals('Este lado parece ser a frente. Vire o documento para o verso.'),
      );

      // Mostrar o Verso real -> aprovado!
      final realBackEval = DocumentFrameAlignmentEngine.evaluateFrameBytes(
        frameBytes: backFull,
        isFront: false,
        referenceFrontBytes: frontCropped,
      );
      expect(realBackEval.isValid, isTrue);
      expect(realBackEval.status, equals(DocumentFrameStatus.aligned));
    });

    test('DocumentAlignmentTracker exige 3 frames consecutivos válidos para VERDE, 5 para auto-captura e reseta no 1º inválido', () {
      final tracker = DocumentAlignmentTracker();
      final validFrame = DocumentFrameAssessment.aligned();
      const invalidFrame = DocumentFrameAssessment(
        status: DocumentFrameStatus.blurry,
        humanHint: 'Imagem desfocada.',
        edgeAlignmentScore: 0.9,
        interiorExteriorContrast: 40.0,
        laplacianSharpness: 45.0,
        glareRatioPct: 1.0,
        meanLuminance: 140.0,
        contentDensityScore: 0.5,
        edgesDetectedCount: 4,
      );

      expect(tracker.push(validFrame).isAlignedAndReady, isFalse); // 1
      expect(tracker.push(validFrame).isAlignedAndReady, isFalse); // 2
      final snap3 = tracker.push(validFrame); // 3 -> VERDE!
      expect(snap3.isAlignedAndReady, isTrue);
      expect(snap3.readyForAutoCapture, isFalse);

      // Qualquer quadro inválido reseta imediatamente para 0 (VERMELHO)
      final snapReset = tracker.push(invalidFrame);
      expect(snapReset.consecutiveValidFrames, equals(0));
      expect(snapReset.isAlignedAndReady, isFalse);

      // 5 quadros válidos seguidos -> readyForAutoCapture == true
      for (int i = 0; i < 4; i++) {
        expect(tracker.push(validFrame).readyForAutoCapture, isFalse);
      }
      final snap5 = tracker.push(validFrame);
      expect(snap5.isAlignedAndReady, isTrue);
      expect(snap5.readyForAutoCapture, isTrue);
      expect(snap5.autoCaptureProgress, equals(1.0));
    });
  });

  group('2. BrazilianDocumentOcrParser & Motor Real de OCR / Liveness', () {
    test('Extrai campos completos de CNH Clássica e CNH 2022+ (incluindo RENACH, Cód. Segurança e QR SERPRO)', () {
      const cnhClassicaFront = '''
REPÚBLICA FEDERATIVA DO BRASIL
MINISTÉRIO DA INFRAESTRUTURA
CARTEIRA NACIONAL DE HABILITAÇÃO
NOME
MARIA CLARA MENDES SILVA
DOC. IDENTIDADE / ORG. EMISSOR / UF
MG-18.432.190 PCMG
CPF
529.982.247-25
DATA NASCIMENTO
18/06/1992
Nº REGISTRO
04829173654
DETRAN/MG
''';
      const cnhClassicaBack = '''
OBSERVAÇÕES
EXERCE ATIVIDADE REMUNERADA
RENACH: MG837261549
CÓD. SEGURANÇA: 94827163504
''';

      final parsedClassic = BrazilianDocumentOcrParser.parse(
        frontText: cnhClassicaFront,
        backText: cnhClassicaBack,
        expectedDocumentType: OfficialDocumentType.cnh,
        qrPayloads: const <String>['https://vio.serpro.gov.br/cnh/v1/abc'],
      );
      expect(parsedClassic.detectedDocumentType, equals(OfficialDocumentType.cnh));
      expect(parsedClassic.officialHeaderDetected, isTrue);
      expect(parsedClassic.hasRequiredIdentityFields, isTrue);
      expect(parsedClassic.fullName, equals('MARIA CLARA MENDES SILVA'));
      expect(parsedClassic.cpfDigits, equals('52998224725'));
      expect(parsedClassic.documentNumber, equals('04829173654'));
      expect(parsedClassic.birthDate, equals(DateTime.utc(1992, 6, 18)));
      expect(parsedClassic.issuingAuthority, equals('DETRAN/MG'));
      expect(parsedClassic.renach, equals('MG837261549'));
      expect(parsedClassic.cnhSecurityCode11, equals('94827163504'));
      expect(parsedClassic.qrCodeDetected, isTrue);
      expect(parsedClassic.securityCodesIntegrityOk, isTrue);

      const cnh2022Front = '''
REPÚBLICA FEDERATIVA DO BRASIL
SENATRAN - CARTEIRA NACIONAL DE HABILITAÇÃO
2 e 1 NOME E SOBRENOME
JOÃO PEDRO ALMEIDA COSTA
3 DATA, LOCAL E UF DE NASCIMENTO
04/11/1989 SÃO PAULO SP
4a DATA EMISSÃO 10/01/2024
4b VALIDADE 10/01/2034
4d CPF
111.444.777-35
5 Nº REGISTRO
09182736455
DETRAN/SP
''';
      final parsed2022 = BrazilianDocumentOcrParser.parse(
        frontText: cnh2022Front,
        backText: 'RENACH SP123456789',
        expectedDocumentType: OfficialDocumentType.cnh,
      );
      expect(parsed2022.hasRequiredIdentityFields, isTrue);
      expect(parsed2022.fullName, equals('JOÃO PEDRO ALMEIDA COSTA'));
      expect(parsed2022.cpfDigits, equals('11144477735'));
      expect(parsed2022.documentNumber, equals('09182736455'));
      expect(parsed2022.birthDate, equals(DateTime.utc(1989, 11, 4)));
      expect(parsed2022.renach, equals('SP123456789'));
    });

    test('Extrai e valida CIN com MRZ ICAO 9303 TD1 (IDBRA...), RG Estadual e Comprovante CPF', () {
      // Constrói MRZ TD1 3x30 matematicamente válido
      const docNum = '529982247';
      final docDv = DocumentOcrAndLivenessService.computeIcaoMrzCheckDigit(docNum);
      final l1 = 'IDBRA$docNum$docDv<<<<<<<<<<<<<<<';
      const birth = '920618';
      final birthDv = DocumentOcrAndLivenessService.computeIcaoMrzCheckDigit(birth);
      const expiry = '340618';
      final expiryDv = DocumentOcrAndLivenessService.computeIcaoMrzCheckDigit(expiry);
      final l2Prefix = '$birth${birthDv}F$expiry${expiryDv}BRA<<<<<<<<<<<';
      final comp = l1.substring(5, 30) +
          l2Prefix.substring(0, 7) +
          l2Prefix.substring(8, 15) +
          l2Prefix.substring(18, 29);
      final compDv = DocumentOcrAndLivenessService.computeIcaoMrzCheckDigit(comp);
      final l2 = '$l2Prefix$compDv';
      const l3 = 'SILVA<<MARIA<CLARA<MENDES<<<<<';

      final parsedCin = BrazilianDocumentOcrParser.parse(
        frontText: '''
REPÚBLICA FEDERATIVA DO BRASIL
CARTEIRA DE IDENTIDADE NACIONAL
CPF: 529.982.247-25
ÓRGÃO EXPEDIDOR: SSP/MG
''',
        backText: '$l1\n$l2\n$l3',
        expectedDocumentType: OfficialDocumentType.cin,
      );
      expect(parsedCin.detectedDocumentType, equals(OfficialDocumentType.cin));
      expect(parsedCin.mrzChecksumValid, isTrue);
      expect(parsedCin.fullName, equals('MARIA CLARA MENDES SILVA'));
      expect(parsedCin.cpfDigits, equals('52998224725'));
      expect(parsedCin.birthDate, equals(DateTime.utc(1992, 6, 18)));
      expect(parsedCin.issuingAuthority, equals('SSP/MG'));

      final parsedRg = BrazilianDocumentOcrParser.parse(
        frontText: '''
REPÚBLICA FEDERATIVA DO BRASIL
SECRETARIA DE SEGURANÇA PÚBLICA
CARTEIRA DE IDENTIDADE
REGISTRO GERAL: 44.123.987-9
NOME: CARLOS HENRIQUE NOGUEIRA
DATA DE NASCIMENTO: 22/08/1987
CPF: 529.982.247-25
SSP/SP
''',
        backText: '',
        expectedDocumentType: OfficialDocumentType.rg,
      );
      expect(parsedRg.detectedDocumentType, equals(OfficialDocumentType.rg));
      expect(parsedRg.hasRequiredIdentityFields, isTrue);
      expect(parsedRg.fullName, equals('CARLOS HENRIQUE NOGUEIRA'));
      expect(parsedRg.documentNumber, equals('44.123.987-9'));
      expect(parsedRg.securityCodesIntegrityOk, isTrue);

      final parsedCpfDoc = BrazilianDocumentOcrParser.parse(
        frontText: '''
MINISTÉRIO DA FAZENDA
RECEITA FEDERAL DO BRASIL
COMPROVANTE DE INSCRIÇÃO NO CPF
CPF: 529.982.247-25
NOME: ANA BEATRIZ FERREIRA LIMA
DATA DE NASCIMENTO: 09/02/1995
''',
        backText: '',
        expectedDocumentType: OfficialDocumentType.cpf,
      );
      expect(parsedCpfDoc.detectedDocumentType, equals(OfficialDocumentType.cpf));
      expect(parsedCpfDoc.hasRequiredIdentityFields, isTrue);
      expect(parsedCpfDoc.fullName, equals('ANA BEATRIZ FERREIRA LIMA'));
      expect(parsedCpfDoc.cpfDigits, equals('52998224725'));
      expect(parsedCpfDoc.securityCodesIntegrityOk, isTrue);
    });

    test('Rejeita honestamente documento ilegível (ZERO fabricação de dados e ZERO Easter egg 11978723610)', () async {
      final unreadable = BrazilianDocumentOcrParser.parse(
        frontText: 'abc 123 texto borrado sem dados',
        backText: '',
        expectedDocumentType: OfficialDocumentType.cnh,
      );
      expect(unreadable.hasRequiredIdentityFields, isFalse);
      expect(unreadable.fullName, isNull);
      expect(unreadable.cpfDigits, isNull);

      final sharpFront = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 11,
      );
      final sharpBack = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 29,
      );

      // Mesmo usando o CPF 119.787.236-10 / Wagner Oliveira, o caminho real JAMAIS fabrica nome/CPF!
      Object? caught;
      try {
        await DocumentOcrAndLivenessService.runRealDocumentOcrAndForensics(
          frontImageBytes: sharpFront,
          backImageBytes: sharpBack,
          documentType: OfficialDocumentType.cnh,
          typedFullName: 'Wagner Oliveira',
          typedCpfRaw: '119.787.236-10',
          rawOcrFrontTextOverride: '',
          rawOcrBackTextOverride: '',
          allowSupabaseEdgeFallback: false,
        );
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<StateError>());
      expect(caught.toString(), contains('ERR_OCR_UNREADABLE_DOCUMENT'));
      final humanMsg = KycHumanFeedbackTranslator.translateError(caught);
      expect(humanMsg, isNotEmpty);
      expect(KycHumanFeedbackTranslator.containsBannedTechnicalJargon(humanMsg), isFalse);
    });

    test('verifyActiveLivenessSync com requireRealBiometricTelemetry: true exige telemetria real e calcula score dinâmico [80..99.5]', () {
      final selfie = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 7,
      );

      expect(
        () => DocumentOcrAndLivenessService.verifyActiveLivenessSync(
          selfieBytes: selfie,
          cpfDigits: '52998224725',
          requireRealBiometricTelemetry: true,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('ERR_MISSING_REAL_BIOMETRIC_TELEMETRY'),
          ),
        ),
      );

      final lowAmplitude = DocumentOcrAndLivenessService.verifyActiveLivenessSync(
        selfieBytes: selfie,
        cpfDigits: '52998224725',
        requireRealBiometricTelemetry: true,
        earTimeline: const <double>[0.25, 0.18, 0.25],
        poseTimeline: const <({double yawDeg, double pitchDeg})>[
          (yawDeg: 0.0, pitchDeg: 0.0),
          (yawDeg: 18.2, pitchDeg: 2.0),
          (yawDeg: 2.0, pitchDeg: 1.0),
        ],
      );

      final highAmplitude = DocumentOcrAndLivenessService.verifyActiveLivenessSync(
        selfieBytes: selfie,
        cpfDigits: '52998224725',
        requireRealBiometricTelemetry: true,
        earTimeline: const <double>[0.33, 0.12, 0.34],
        poseTimeline: const <({double yawDeg, double pitchDeg})>[
          (yawDeg: 0.0, pitchDeg: 0.0),
          (yawDeg: 28.5, pitchDeg: 1.0),
          (yawDeg: 1.0, pitchDeg: 0.5),
        ],
      );

      expect(lowAmplitude.livenessScore, inInclusiveRange(80.0, 99.5));
      expect(highAmplitude.livenessScore, inInclusiveRange(80.0, 99.5));
      expect(highAmplitude.livenessScore, greaterThan(lowAmplitude.livenessScore));
    });
  });

  group('3. DocumentGuidedScannerModal — Contorno Vermelho->Verde e Bloqueio de Captura', () {
    testWidgets('Botão começa bloqueado no VERMELHO, libera após 3 frames válidos (VERDE), volta ao VERMELHO se inválido e recorta ROI na captura', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = StreamController<DocumentFrameAssessment>();
      addTearDown(controller.close);

      final sampleFrame = _buildSyntheticCameraFrame(isBackSide: false);
      Uint8List? returnedBytes;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.resolve(null, Brightness.dark),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    key: const ValueKey('open-scanner'),
                    onPressed: () async {
                      returnedBytes = await Navigator.of(context).push<Uint8List>(
                        MaterialPageRoute<Uint8List>(
                          builder: (_) => DocumentGuidedScannerModal(
                            isFront: true,
                            documentType: OfficialDocumentType.cnh,
                            testAssessmentStream: controller.stream,
                            autoCaptureEnabled: false,
                            testCaptureOverride: () async => sampleFrame,
                          ),
                        ),
                      );
                    },
                    child: const Text('Abrir'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open-scanner')));
      await tester.pumpAndSettle();

      // Estado inicial: VERMELHO e botão de captura DESABILITADO
      expect(find.byKey(const ValueKey('scanner-frame-red')), findsOneWidget);
      FilledButton captureBtn() => tester.widget<FilledButton>(
            find.descendant(
              of: find.byKey(const ValueKey('btn-capture-guided-document')),
              matching: find.byType(FilledButton),
            ),
          );
      expect(captureBtn().onPressed, isNull);

      // 2 frames válidos ainda NÃO liberam (exige 3 consecutivos)
      controller.add(DocumentFrameAssessment.aligned());
      await tester.pump();
      controller.add(DocumentFrameAssessment.aligned());
      await tester.pump();
      expect(find.byKey(const ValueKey('scanner-frame-red')), findsOneWidget);
      expect(captureBtn().onPressed, isNull);

      // 3º frame consecutivo válido -> VERDE + mensagem + botão HABILITADO!
      controller.add(DocumentFrameAssessment.aligned());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('scanner-frame-green')), findsOneWidget);
      expect(find.text('Documento enquadrado! Pronto para capturar'), findsOneWidget);
      expect(captureBtn().onPressed, isNotNull);

      // Se chegar 1 frame inválido (ex.: verso igual à frente) -> volta imediatamente ao VERMELHO e bloqueia!
      controller.add(
        const DocumentFrameAssessment(
          status: DocumentFrameStatus.duplicateOfFront,
          humanHint: 'Este lado parece ser a frente. Vire o documento para o verso.',
          edgeAlignmentScore: 0.92,
          interiorExteriorContrast: 44.0,
          laplacianSharpness: 240.0,
          glareRatioPct: 1.0,
          meanLuminance: 145.0,
          contentDensityScore: 0.7,
          edgesDetectedCount: 4,
          isDuplicateOfFront: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('scanner-frame-red')), findsOneWidget);
      expect(
        find.text('Este lado parece ser a frente. Vire o documento para o verso.'),
        findsOneWidget,
      );
      expect(captureBtn().onPressed, isNull);

      // Enquadra novamente (3 frames válidos) -> VERDE -> toca no botão e retorna recorte ROI
      controller.add(DocumentFrameAssessment.aligned());
      controller.add(DocumentFrameAssessment.aligned());
      controller.add(DocumentFrameAssessment.aligned());
      await tester.pumpAndSettle();
      expect(captureBtn().onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('btn-capture-guided-document')));
      await tester.pumpAndSettle();

      expect(returnedBytes, isNotNull);
      expect(returnedBytes!.isNotEmpty, isTrue);
      final decodedCrop = img.decodeImage(returnedBytes!);
      expect(decodedCrop, isNotNull);
      // Recorte horizontal é estritamente menor que o frame original 240x180
      expect(decodedCrop!.width, lessThan(240));
      expect(decodedCrop.height, lessThan(180));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tecla Esc fecha o modal com segurança no desktop/Web', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = StreamController<DocumentFrameAssessment>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.resolve(null, Brightness.dark),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                key: const ValueKey('open-scanner-esc'),
                onPressed: () {
                  Navigator.of(context).push<Uint8List>(
                    MaterialPageRoute<Uint8List>(
                      builder: (_) => DocumentGuidedScannerModal(
                        isFront: false,
                        documentType: OfficialDocumentType.cin,
                        testAssessmentStream: controller.stream,
                      ),
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open-scanner-esc')));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentGuidedScannerModal), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(DocumentGuidedScannerModal), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('4. DocumentOcrReviewStep — Responsividade 320/390/1280 @ 1.0x e 1.5x (Claro/Escuro)', () {
    final frontBytes = _buildSyntheticCameraFrame(isBackSide: false);
    final backBytes = _buildSyntheticCameraFrame(isBackSide: true);
    final ocr = _sampleAuditedOcrResult();

    final viewports = <Size>[
      const Size(320, 640),
      const Size(390, 844),
      const Size(1280, 800),
    ];

    for (final size in viewports) {
      for (final scale in <double>[1.0, 1.5]) {
        for (final brightness in <Brightness>[Brightness.light, Brightness.dark]) {
          testWidgets(
            'Renderiza sem overflow e sem jargão em ${size.width.toInt()}x${size.height.toInt()} @ ${scale}x (${brightness.name})',
            (tester) async {
              await tester.binding.setSurfaceSize(size);
              addTearDown(() => tester.binding.setSurfaceSize(null));

              bool retakeCalled = false;
              bool confirmCalled = false;

              await tester.pumpWidget(
                MaterialApp(
                  theme: AppTheme.resolve(null, brightness),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: DocumentOcrReviewStep(
                        ocrResult: ocr,
                        typedName: 'Maria Clara Mendes',
                        frontImageBytes: frontBytes,
                        backImageBytes: backBytes,
                        onRetakePhotos: () => retakeCalled = true,
                        onConfirm: () => confirmCalled = true,
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);

              expect(find.byKey(const ValueKey('ocr-review-confirmed-chip')), findsOneWidget);
              expect(find.text('Leitura Confirmada'), findsOneWidget);
              expect(find.byKey(const ValueKey('ocr-transcribed-card')), findsOneWidget);
              expect(find.text('MARIA CLARA MENDES SILVA'), findsOneWidget);
              expect(find.textContaining('***.982.247-**'), findsOneWidget);
              expect(find.textContaining('529.982.247-25'), findsNothing);

              // Alvo do toggle CPF >= 48x48 e alterna máscara LGPD
              final toggleFinder = find.byKey(const ValueKey('toggle-cpf-reveal'));
              final toggleSize = tester.getSize(toggleFinder);
              expect(toggleSize.width, greaterThanOrEqualTo(48.0));
              expect(toggleSize.height, greaterThanOrEqualTo(48.0));

              await tester.ensureVisible(toggleFinder);
              await tester.tap(toggleFinder);
              await tester.pump();
              expect(find.textContaining('529.982.247-25'), findsOneWidget);

              // Testa botão Refazer fotos
              final retakeFinder = find.byKey(const ValueKey('btn-ocr-retake-photos'));
              await tester.ensureVisible(retakeFinder);
              await tester.tap(retakeFinder);
              await tester.pump();
              expect(retakeCalled, isTrue);

              // Testa botão Confirmar
              final confirmFinder = find.byKey(const ValueKey('btn-ocr-review-confirm'));
              await tester.ensureVisible(confirmFinder);
              await tester.tap(confirmFinder);
              await tester.pump();
              expect(confirmCalled, isTrue);

              // Verifica ZERO jargão técnico em todos os textos renderizados
              for (final element in find.byType(Text).evaluate()) {
                final textWidget = element.widget as Text;
                final content =
                    textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
                expect(
                  KycHumanFeedbackTranslator.containsBannedTechnicalJargon(content),
                  isFalse,
                  reason: 'Texto visível não pode conter jargão técnico: "$content"',
                );
              }
            },
          );
        }
      }
    }
  });
}

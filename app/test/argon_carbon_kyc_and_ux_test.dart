import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/security/kyc_session_anti_swap_guard.dart';
import 'package:desperrengue_app/core/security/perceptual_hash_guard.dart';
import 'package:desperrengue_app/core/services/document_ocr_and_liveness_service.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/kyc_human_feedback_translator.dart';
import 'package:desperrengue_app/features/client/presentation/client_setup_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Frente 4.1 — Validadores Matemáticos e Fiscais Determinísticos (Vol. I)', () {
    test('CPF Módulo 11 aprova CPFs reais e rejeita todos os repdigits e DVs adulterados', () {
      expect(DocumentOcrAndLivenessService.isValidCpfMod11('52998224725'), isTrue);
      expect(DocumentOcrAndLivenessService.isValidCpfMod11('119.787.236-10'), isTrue);
      expect(DocumentOcrAndLivenessService.isValidCpfMod11('52998224724'), isFalse);
      expect(DocumentOcrAndLivenessService.isValidCpfMod11('12345678900'), isFalse);

      for (int d = 0; d <= 9; d++) {
        final rep = '$d' * 11;
        expect(
          DocumentOcrAndLivenessService.isValidCpfMod11(rep),
          isFalse,
          reason: 'Repdigit $rep deve ser rejeitado pelo Módulo 11',
        );
      }
    });

    test('MRZ ICAO Doc 9303 Módulo 10 (pesos 7-3-1) valida TD1 (3x30) e TD3 (2x44)', () {
      expect(DocumentOcrAndLivenessService.computeIcaoMrzCheckDigit('AB2134<<<'), equals(5));
      expect(DocumentOcrAndLivenessService.computeIcaoMrzCheckDigit('900101'), equals(1));
      expect(DocumentOcrAndLivenessService.computeIcaoMrzCheckDigit('301231'), equals(6));
      expect(DocumentOcrAndLivenessService.computeIcaoMrzCheckDigit('INVALID*'), equals(-1));

      // Constrói MRZ TD1 (3x30) matematicamente válido
      const String docNum = '123456789';
      final int docDv = DocumentOcrAndLivenessService.computeIcaoMrzCheckDigit(docNum);
      final String l1 = 'IDBRA$docNum$docDv<<<<<<<<<<<<<<<';
      expect(l1.length, equals(30));

      const String birth = '880514';
      final int birthDv = DocumentOcrAndLivenessService.computeIcaoMrzCheckDigit(birth);
      const String expiry = '320514';
      final int expiryDv = DocumentOcrAndLivenessService.computeIcaoMrzCheckDigit(expiry);
      final String l2Prefix = '$birth${birthDv}M$expiry${expiryDv}BRA<<<<<<<<<<<';
      final String composite =
          l1.substring(5, 30) + l2Prefix.substring(0, 7) + l2Prefix.substring(8, 15) + l2Prefix.substring(18, 29);
      final int compDv = DocumentOcrAndLivenessService.computeIcaoMrzCheckDigit(composite);
      final String l2 = '$l2Prefix$compDv';
      const String l3 = 'CLAUDIANO<<WAGNER<OLIVEIRA<<<<';

      expect(DocumentOcrAndLivenessService.validateIcaoMrzLines(<String>[l1, l2, l3]), isTrue);

      // Adultera 1 dígito da data de nascimento na linha 2 -> deve reprovar
      final String tamperedL2 = '880515${l2.substring(6)}';
      expect(DocumentOcrAndLivenessService.validateIcaoMrzLines(<String>[l1, tamperedL2, l3]), isFalse);

      // Constrói MRZ TD3 (2x44 - Passaporte) válido com DV opcional (pos 42) e DV composto final (pos 43)
      const String passDoc = 'BR9876543';
      final int passDocDv = DocumentOcrAndLivenessService.computeIcaoMrzCheckDigit(passDoc);
      const String td3L1 = 'P<BRACLAUDIANO<<WAGNER<OLIVEIRA<<<<<<<<<<<<<';
      final String td3L2WithoutComp =
          '$passDoc${passDocDv}BRA$birth${birthDv}M$expiry$expiryDv<<<<<<<<<<<<<<0';
      final String td3CompositeSource =
          '${td3L2WithoutComp.substring(0, 10)}${td3L2WithoutComp.substring(13, 20)}${td3L2WithoutComp.substring(21, 43)}';
      final int td3CompDv =
          DocumentOcrAndLivenessService.computeIcaoMrzCheckDigit(td3CompositeSource);
      final String td3L2 = '$td3L2WithoutComp$td3CompDv';
      expect(td3L1.length, equals(44));
      expect(td3L2.length, equals(44));
      expect(DocumentOcrAndLivenessService.validateIcaoMrzLines(<String>[td3L1, td3L2]), isTrue);

      // Adultera o DV composto final l2[43] do TD3 -> deve reprovar
      final String tamperedTd3L2 = '$td3L2WithoutComp${(td3CompDv + 1) % 10}';
      expect(
        DocumentOcrAndLivenessService.validateIcaoMrzLines(<String>[td3L1, tamperedTd3L2]),
        isFalse,
      );
    });

    test('Validador de CNH: RENACH (^[A-Z]{2}\\d{9}\$) e Código de Segurança de 11 dígitos', () {
      expect(DocumentOcrAndLivenessService.isValidCnhRenach('MG123456789'), isTrue);
      expect(DocumentOcrAndLivenessService.isValidCnhRenach('SP987654321'), isTrue);
      expect(DocumentOcrAndLivenessService.isValidCnhRenach('XX123456789'), isFalse);
      expect(DocumentOcrAndLivenessService.isValidCnhRenach('MG111111111'), isFalse);
      expect(DocumentOcrAndLivenessService.isValidCnhRenach('12345678901'), isFalse);

      expect(DocumentOcrAndLivenessService.isValidCnhSecurityCode11('94827163504'), isTrue);
      expect(DocumentOcrAndLivenessService.isValidCnhSecurityCode11('00000000000'), isFalse);
      expect(DocumentOcrAndLivenessService.isValidCnhSecurityCode11('1234567890'), isFalse);
    });

    test('computeCivilNameCompatibility aprova nome parcial em nome completo civil (100%) e bloqueia impostores', () {
      final double simPartial = DocumentOcrAndLivenessService.computeCivilNameCompatibility(
        'Wagner Oliveira',
        'WAGNER OLIVEIRA CLAUDIANO',
      );
      expect(simPartial, equals(1.0));

      final double simAccents = DocumentOcrAndLivenessService.computeCivilNameCompatibility(
        'João da Silva Gonçalves',
        'JOAO GONCALVES DA SILVA',
      );
      expect(simAccents, greaterThanOrEqualTo(0.85));

      final double simImpostor = DocumentOcrAndLivenessService.computeCivilNameCompatibility(
        'Carlos Eduardo Pereira',
        'WAGNER OLIVEIRA CLAUDIANO',
      );
      expect(simImpostor, lessThan(0.50));

      // Bloqueia ataque assimétrico de sobrenomes fabricados no cadastro vs documento curto
      final double simAsymmetricAttack =
          DocumentOcrAndLivenessService.computeCivilNameCompatibility(
        'Wagner Pereira Santos Ferreira Silva',
        'WAGNER SILVA',
      );
      expect(simAsymmetricAttack, lessThan(0.80));
    });

    test('Chave de Acesso NF-e 44 dígitos (Módulo 11) + Conferência Aritmética Smart Split', () {
      // Monta os 43 primeiros dígitos com CNPJ válido (11.222.333/0001-81 -> 11222333000181)
      const String cnpj = '11222333000181';
      expect(DocumentOcrAndLivenessService.isValidCnpjMod11(cnpj), isTrue);

      const String base43 = '312604${cnpj}55001000012345101234567';
      expect(base43.length, equals(43));

      // Calcula DV Mod 11 oficial SEFAZ
      int weight = 2;
      int sum = 0;
      for (int i = 42; i >= 0; i--) {
        sum += (base43.codeUnitAt(i) - 48) * weight;
        weight = weight == 9 ? 2 : weight + 1;
      }
      final int rem = sum % 11;
      final int dv = (rem == 0 || rem == 1) ? 0 : (11 - rem);
      final String validKey44 = '$base43$dv';

      expect(DocumentOcrAndLivenessService.isValidNfeAccessKey44Mod11(validKey44), isTrue);
      final String tamperedKey44 = '$base43${(dv + 1) % 10}';
      expect(DocumentOcrAndLivenessService.isValidNfeAccessKey44Mod11(tamperedKey44), isFalse);

      // Conferência aritmética de materiais consumíveis (aprovada)
      final approvedAudit = DocumentOcrAndLivenessService.verifySmartSplitInvoiceArithmetic(
        accessKey44: validKey44,
        expectedIssuerCnpj: cnpj,
        items: const <SmartSplitInvoiceLineItem>[
          SmartSplitInvoiceLineItem(description: 'Cabo Flexível 2.5mm 100m', totalCents: 14500),
          SmartSplitInvoiceLineItem(description: 'Disjuntor Bipolar DIN 32A', totalCents: 4500),
        ],
        declaredMaterialsCents: 19000,
      );
      expect(approvedAudit.isValid, isTrue);
      expect(approvedAudit.approvedConsumablesCents, equals(19000));
      expect(approvedAudit.rejectedCapitalToolsCents, equals(0));

      // Tentativa de incluir ferramenta de uso permanente (Furadeira) no reembolso de insumos -> bloqueada
      final toolAudit = DocumentOcrAndLivenessService.verifySmartSplitInvoiceArithmetic(
        accessKey44: validKey44,
        expectedIssuerCnpj: cnpj,
        items: const <SmartSplitInvoiceLineItem>[
          SmartSplitInvoiceLineItem(description: 'Cabo Flexível 2.5mm', totalCents: 14500),
          SmartSplitInvoiceLineItem(description: 'Furadeira de Impacto Profissional', totalCents: 35000),
        ],
        declaredMaterialsCents: 49500,
      );
      expect(toolAudit.isValid, isFalse);
      expect(toolAudit.rejectionCode, equals('ERR_CAPITAL_TOOLS_NOT_REIMBURSABLE'));
    });
  });

  group('Frente 4.2 — Grounding 2D ([0..1000]), 4 Rotações Canônicas e Óptica Tier-0', () {
    test('NormalizedBox2D converte coordenadas [0..1000] com padding 4% e aplica 4 rotações canônicas', () {
      const box = NormalizedBox2D(
        ymin: 200,
        xmin: 100,
        ymax: 700,
        xmax: 900,
        confidence: 0.96,
      );
      expect(box.isValid, isTrue);

      final rect = box.toPixelCrop(imageWidth: 1000, imageHeight: 500, padRatio: 0.04);
      expect(rect.left, equals(68)); // 100 - (800 * 0.04) = 68
      expect(rect.top, equals(90)); // 100 - (250 * 0.04) = 90
      expect(rect.width, equals(864));
      expect(rect.height, equals(270));

      final rot90 = box.transformToCanonicalOrientation(90);
      expect(rot90.isValid, isTrue);
      expect(rot90.ymin, equals(100));
      expect(rot90.xmin, equals(300));
      expect(rot90.ymax, equals(900));
      expect(rot90.xmax, equals(800));
      final roundTrip = rot90.transformToCanonicalOrientation(270);
      expect(roundTrip.ymin, equals(box.ymin));
      expect(roundTrip.xmin, equals(box.xmin));
      expect(roundTrip.ymax, equals(box.ymax));
      expect(roundTrip.xmax, equals(box.xmax));

      final rectCanvas = img.Image(width: 200, height: 120);
      for (int y = 0; y < 120; y++) {
        for (int x = 0; x < 200; x++) {
          rectCanvas.setPixelRgb(x, y, (x + y) % 255, (x * 2) % 255, (y * 2) % 255);
        }
      }
      final sampleBytes = Uint8List.fromList(img.encodePng(rectCanvas));

      for (final angle in <int>[0, 90, 180, 270]) {
        final cropped = box.cropAndRotateCanonical(
          imageBytes: sampleBytes,
          canonicalRotationDeg: angle,
        );
        final decoded = img.decodeImage(cropped);
        expect(decoded, isNotNull);
        if (angle == 0 || angle == 180) {
          expect(decoded!.width, greaterThan(decoded.height));
        } else {
          expect(decoded!.height, greaterThan(decoded.width));
        }
      }
    });

    test('Core ROI Inset 12% + dHash + MAD bloqueia Frente == Verso na mesma mesa e aprova Frente != Verso reais na mesma mesa', () async {
      // Constrói duas imagens onde os 12% externos (mesa de madeira) são 100% idênticos,
      // mas o interior (Frente vs Verso do documento) possui estrutura diferente.
      Uint8List buildDocumentOnSameDesk({required bool isBackSide}) {
        final canvas = img.Image(width: 240, height: 160);
        for (int y = 0; y < 160; y++) {
          for (int x = 0; x < 240; x++) {
            final bool isDeskBorder = x < 30 || x >= 210 || y < 20 || y >= 140;
            if (isDeskBorder) {
              // Textura idêntica da mesa nas bordas
              final int wood = 120 + ((x * 7 + y * 13) % 45);
              canvas.setPixelRgb(x, y, wood, wood - 20, wood - 40);
            } else if (!isBackSide) {
              // Frente: foto 3x4 escura à esquerda + linhas horizontais à direita
              final bool portrait = x >= 45 && x <= 95 && y >= 38 && y <= 118;
              final int lum = portrait
                  ? 45 + ((x + y) % 25)
                  : ((y % 14 < 4) ? 55 : 225);
              canvas.setPixelRgb(x, y, lum, lum, lum);
            } else {
              // Verso: QR Code quadriculado à direita + faixa MRZ inferior
              final bool qrZone = x >= 135 && x <= 195 && y >= 34 && y <= 94;
              final bool mrzZone = y >= 106 && y <= 132;
              final int lum = qrZone
                  ? ((((x ~/ 5) + (y ~/ 5)) % 2 == 0) ? 25 : 240)
                  : (mrzZone ? ((x % 6 < 3) ? 35 : 230) : 210);
              canvas.setPixelRgb(x, y, lum, lum, lum);
            }
          }
        }
        return Uint8List.fromList(img.encodePng(canvas));
      }

      final frontOnDesk = buildDocumentOnSameDesk(isBackSide: false);
      final backOnDesk = buildDocumentOnSameDesk(isBackSide: true);

      // 1) Mesma face (Frente == Frente) na mesma mesa -> BLOQUEADO
      final duplicateCheck =
          await PerceptualHashGuard.evaluateDocumentFrontBackDistinctionInIsolate(
        frontOnDesk,
        frontOnDesk,
      );
      expect(duplicateCheck.isDuplicate, isTrue);
      expect(duplicateCheck.dHashHammingDistance, equals(0));

      // 2) Frente e Verso distintos sobre a mesma mesa -> APROVADO sem falso positivo!
      final distinctCheck =
          await PerceptualHashGuard.evaluateDocumentFrontBackDistinctionInIsolate(
        frontOnDesk,
        backOnDesk,
      );
      expect(distinctCheck.isDuplicate, isFalse);
      expect(distinctCheck.dHashHammingDistance, greaterThan(4));
      expect(distinctCheck.mad64x64, greaterThanOrEqualTo(6.5));
    });

    test('Bloqueia ataque de Replay em Tela/Monitor (blueMonitorRatio) na moldura oval', () {
      final monitorFrame =
          DocumentOcrAndLivenessService.createSyntheticMonitorScreenBytes();
      final analysis = DocumentOcrAndLivenessService.evaluateLiveOvalFrameInput(
        imageBytes: monitorFrame,
      );
      expect(analysis.hasRealHumanFace, isFalse);
      expect(analysis.blueMonitorRatio, greaterThan(0.28));
    });
  });

  group('Frente 4.3 — Vínculo de Sessão Anti-Swap (180s), Bloqueio de Galeria e Câmera Virtual', () {
    test('Congela Selfie Canônica, calcula requestHash determinístico e bloqueia swap/replay/galeria/OBS', () {
      final t0 = DateTime.utc(2026, 11, 12, 12, 0, 0);
      final selfieA = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(variantSeed: 1);
      final selfieB = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(variantSeed: 2);
      final frontDoc = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(variantSeed: 3);
      final backDoc = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(variantSeed: 4);

      // 1. Emissão do ticket com fallback controlado homologation_or_pwa_limited
      final issued = KycSessionAntiSwapGuard.issueSession(
        userId: 'user-argon-001',
        serverSessionNonce: 'nonce_1234567890abcdef',
        nowUtc: t0,
      );
      expect(issued.deviceIntegrity.isHomologationFallback, isTrue);
      expect(issued.deviceIntegrity.isAllowedForKyc, isTrue);

      // 2. Bloqueia tentativa de injeção de selfie via galeria
      expect(
        () => KycSessionAntiSwapGuard.freezeCanonicalSelfie(
          ticket: issued,
          selfieBytes: selfieA,
          origin: CaptureOrigin.galleryOrFileBlocked,
          nowUtc: t0.add(const Duration(seconds: 10)),
        ),
        throwsA(
          predicate((e) => e.toString().contains('ERR_GALLERY_UPLOAD_BLOCKED')),
        ),
      );

      // 3. Bloqueia tentativa de congelar liveness após a janela estrita de 90s (t_liveness - t0 > 90s)
      expect(
        () => KycSessionAntiSwapGuard.freezeCanonicalSelfie(
          ticket: issued,
          selfieBytes: selfieA,
          origin: CaptureOrigin.liveCameraOnly,
          nowUtc: t0.add(const Duration(seconds: 95)),
        ),
        throwsA(
          predicate((e) => e.toString().contains('ERR_SESSION_EXPIRED_OR_SWAP')),
        ),
      );

      // 3b. Congela Selfie Canônica ao vivo dentro de 90s e valida que sensor legítimo ('Jacobson') não é bloqueado por word-boundary
      final frozen = KycSessionAntiSwapGuard.freezeCanonicalSelfie(
        ticket: issued,
        selfieBytes: selfieA,
        origin: CaptureOrigin.liveCameraOnly,
        detectedCameraLabels: const <String>['Jacobson Optical Sensor Front 12MP'],
        nowUtc: t0.add(const Duration(seconds: 12)),
      );
      expect(frozen.hasFrozenSelfie, isTrue);

      // 4. Bloqueia câmera virtual (OBS Virtual Camera / VCam / ManyCam)
      expect(
        () => KycSessionAntiSwapGuard.bindDocumentCapturesAndComputeRequestHash(
          ticket: frozen,
          frontDocBytes: frontDoc,
          backDocBytes: backDoc,
          detectedCameraLabels: const <String>['OBS Virtual Camera'],
          nowUtc: t0.add(const Duration(seconds: 40)),
        ),
        throwsA(
          predicate((e) => e.toString().contains('ERR_VIRTUAL_CAMERA_DETECTED')),
        ),
      );

      // 5. Bloqueia expiração de TTL (> 180s após emissão/liveness)
      expect(
        () => KycSessionAntiSwapGuard.bindDocumentCapturesAndComputeRequestHash(
          ticket: frozen,
          frontDocBytes: frontDoc,
          backDocBytes: backDoc,
          nowUtc: t0.add(const Duration(seconds: 185)),
        ),
        throwsA(
          predicate((e) => e.toString().contains('ERR_SESSION_EXPIRED_OR_SWAP')),
        ),
      );

      // 6. Vincula documentos dentro da janela de 180s e sela requestHash SHA-256 + wire codes canônicos
      final bound = KycSessionAntiSwapGuard.bindDocumentCapturesAndComputeRequestHash(
        ticket: frozen,
        frontDocBytes: frontDoc,
        backDocBytes: backDoc,
        nowUtc: t0.add(const Duration(seconds: 45)),
      );
      expect(bound.isFullyBound, isTrue);
      expect(bound.requestHash, isNotNull);
      expect(bound.requestHash!.length, equals(64));
      final auditPayload = bound.toAuditHeadersAndPayload();
      expect(auditPayload['attestation_verdict'], equals('WEB_LIMITED_ALCADA'));
      expect(auditPayload['capture_source'], equals('LIVE_CAMERA'));

      // 7. Verifica integridade com a mesma selfie (OK) e bloqueia tentativa de swap por selfieB
      KycSessionAntiSwapGuard.verifyBoundTicketIntegrity(
        ticket: bound,
        presentedSelfieBytes: selfieA,
        nowUtc: t0.add(const Duration(seconds: 50)),
      );
      expect(
        () => KycSessionAntiSwapGuard.verifyBoundTicketIntegrity(
          ticket: bound,
          presentedSelfieBytes: selfieB,
          nowUtc: t0.add(const Duration(seconds: 50)),
        ),
        throwsA(
          predicate((e) => e.toString().contains('ERR_CANONICAL_SELFIE_SWAP_DETECTED')),
        ),
      );
    });

    test('Degradação Elegante (Graceful Degradation) de kyc-argon-vision-gate quando Edge Function falha', () async {
      final selfie = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(variantSeed: 1);
      final front = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(variantSeed: 1);
      final back = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(variantSeed: 2);
      final liveness = DocumentOcrAndLivenessService.verifyActiveLivenessSync(
        selfieBytes: selfie,
        cpfDigits: '11978723610',
      );

      final degradedResult =
          await DocumentOcrAndLivenessService.invokeArgonVisionGateWithGracefulDegradation(
        frontImageBytes: front,
        backImageBytes: back,
        documentType: OfficialDocumentType.cnh,
        typedFullName: 'Wagner Oliveira',
        typedCpfRaw: '119.787.236-10',
        livenessFaceEmbedding128: liveness.faceEmbedding128,
        edgeFunctionInvoker: (_) async {
          throw Exception('Simulated network timeout in Edge Function');
        },
      );

      expect(degradedResult.degradedGracefullyToLocal, isTrue);
      expect(degradedResult.usedTier1EdgeFunction, isFalse);
      expect(degradedResult.isApproved, isTrue);
      expect(degradedResult.localResult, isNotNull);

      // Cenário Tier-1 conectado (ready_for_serpro_and_carbon: true)
      Map<String, dynamic>? capturedRequestPayload;
      final tier1Approved =
          await DocumentOcrAndLivenessService.invokeArgonVisionGateWithGracefulDegradation(
        frontImageBytes: front,
        backImageBytes: back,
        documentType: OfficialDocumentType.cnh,
        typedFullName: 'Wagner Oliveira',
        typedCpfRaw: '119.787.236-10',
        livenessFaceEmbedding128: liveness.faceEmbedding128,
        edgeFunctionInvoker: (payload) async {
          capturedRequestPayload = payload;
          return <String, dynamic>{
            'mode': 'kyc_document',
            'ready_for_serpro_and_carbon': true,
            'name_compatibility_score': 1.0,
            'cpf_masked': '***.787.236-**',
          };
        },
      );
      expect(capturedRequestPayload, isNotNull);
      expect(capturedRequestPayload!['mode'], equals('kyc_document'));
      expect(capturedRequestPayload!['frontBase64'], isA<String>());
      expect(capturedRequestPayload!['backBase64'], isA<String>());
      expect(capturedRequestPayload!['typedCpf'], equals('11978723610'));
      expect(capturedRequestPayload!['typedFullName'], equals('Wagner Oliveira'));
      expect(tier1Approved.isApproved, isTrue);
      expect(tier1Approved.decision, equals('APPROVED'));
      expect(tier1Approved.usedTier1EdgeFunction, isTrue);
      expect(tier1Approved.degradedGracefullyToLocal, isFalse);

      // Cenário Tier-1 rejeitado (ready_for_serpro_and_carbon: false)
      final tier1Rejected =
          await DocumentOcrAndLivenessService.invokeArgonVisionGateWithGracefulDegradation(
        frontImageBytes: front,
        backImageBytes: back,
        documentType: OfficialDocumentType.cnh,
        typedFullName: 'Wagner Oliveira',
        typedCpfRaw: '119.787.236-10',
        edgeFunctionInvoker: (_) async {
          return <String, dynamic>{
            'mode': 'kyc_document',
            'ready_for_serpro_and_carbon': false,
            'dossier': <String, dynamic>{
              'user_friendly_retake_guidance':
                  'Havia um pequeno reflexo de luz sobre a foto do documento.',
            },
          };
        },
      );
      expect(tier1Rejected.isApproved, isFalse);
      expect(tier1Rejected.decision, equals('REJECTED'));
      expect(tier1Rejected.usedTier1EdgeFunction, isTrue);
      expect(tier1Rejected.degradedGracefullyToLocal, isFalse);
      expect(
        tier1Rejected.errorCode,
        contains('Havia um pequeno reflexo de luz'),
      );
    });
  });

  group('Frente 4.4 — Zero Jargão Técnico e Viewports Compactos (320x568 e 360x640)', () {
    test('KycHumanFeedbackTranslator elimina 100% de siglas técnicas e códigos ERR_ em todos os cenários', () {
      const rawInputs = <String>[
        'Bad state: ERR_EXCESSIVE_GLARE: Reflexo especular de 14.2% na ROI.',
        'Bad state: ERR_BLURRY_DOCUMENT_IMAGE: Variância Laplaciana 42.0 < 110.0 no Tier-0.',
        'Bad state: ERR_DUPLICATE_FRONT_BACK_PHOTO: dHash Hamming = 0 e MAD = 1.2 na ROI.',
        'Bad state: ERR_NO_HUMAN_FACE_IN_OVAL: Filtro YCbCr e blueMonitorRatio reprovaram.',
        'Bad state: ERR_LIVENESS_BLINK_NOT_DETECTED: EAR mínimo 0.28 sem piscada.',
        'Bad state: ERR_LIVENESS_YAW_NOT_DETECTED: Yaw máximo 3.1 graus.',
        'Bad state: ERR_INVALID_MRZ_OR_QR: Checksum ICAO 9303 ou VIO ASN.1 inválido.',
        'Bad state: ERR_INVALID_TYPED_CPF_MOD11: Falha no Módulo 11.',
        'Bad state: ERR_VIRTUAL_CAMERA_DETECTED: OBS VirtualCam detectada.',
        'Bad state: ERR_SESSION_EXPIRED_OR_SWAP: Nonce expirado no Tier-1 mTLS.',
        'Diagnóstico SHAP: penalidade em dHash, pHash, Laplaciano, Mod 11, MRZ, ICAO e SERPRO.',
      ];

      for (final raw in rawInputs) {
        final human = KycHumanFeedbackTranslator.translateError(raw);
        expect(human, isNotEmpty);
        expect(
          KycHumanFeedbackTranslator.containsBannedTechnicalJargon(human),
          isFalse,
          reason: 'A mensagem traduzida "$human" jamais pode conter jargão técnico (input: "$raw")',
        );
      }

      final shapTranslated = KycHumanFeedbackTranslator.translateShapFactors(<String>[
        'glare_ratio_high',
        'laplacian_blur_tier0',
        'dhash_mad_duplicate',
        'liveness_ear_low',
        'liveness_yaw_low',
        'mrz_icao_checksum',
        'mtls_serpro_homologation',
      ]);
      expect(shapTranslated.length, equals(7));
      for (final item in shapTranslated) {
        expect(KycHumanFeedbackTranslator.containsBannedTechnicalJargon(item), isFalse);
      }

      expect(
        KycHumanFeedbackTranslator.formatCpfQuietLuxury('11978723610', masked: true),
        equals('***.787.236-**'),
      );

      // Garante que palavras legítimas em português ("envio", "camada", "aproximada", "clarear")
      // não causam falso positivo na detecção de jargão por word-boundary
      expect(
        KycHumanFeedbackTranslator.containsBannedTechnicalJargon(
          'O envio da foto na camada aproximada ajuda a clarear a imagem.',
        ),
        isFalse,
      );
    });

    for (final viewport in <Size>[const Size(320, 568), const Size(360, 640)]) {
      testWidgets(
        'ClientSetupScreen executa fluxo completo em viewport compacto ${viewport.width.toInt()}x${viewport.height.toInt()} (com teclado aberto) com ZERO RenderFlex overflow e ZERO jargão técnico',
        (tester) async {
          await tester.binding.setSurfaceSize(viewport);
          addTearDown(() => tester.binding.setSurfaceSize(null));

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

          bool completedSubmission = false;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.resolve(null, Brightness.dark),
              builder: (context, child) {
                // Simula abertura de teclado virtual (viewInsets.bottom = 180)
                final mq = MediaQuery.of(context);
                return MediaQuery(
                  data: mq.copyWith(
                    viewInsets: const EdgeInsets.only(bottom: 180),
                  ),
                  child: child!,
                );
              },
              home: ClientSetupScreen(
                profile: UserProfile.fromMap(const <String, dynamic>{
                  'id': 'client-compact-viewport',
                  'full_name': 'Wagner Oliveira',
                  'phone': '35999887766',
                  'is_client': true,
                }),
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
                  completedSubmission = true;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Passo 1: Digita CPF válido e verifica ausência de jargão técnico na tela
          await tester.enterText(
            find.byKey(const ValueKey('client-setup-cpf')),
            '11978723610',
          );
          await tester.pump();
          expect(find.text('CPF válido e verificado com sucesso'), findsOneWidget);

          await tester.tap(find.byKey(const ValueKey('client-setup-step0-continue')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Passo 2: Preenche endereço
          final fields = find.byType(TextField);
          await tester.enterText(fields.at(1), 'Rua Padre José Geraldi');
          await tester.enterText(fields.at(2), '203');
          await tester.enterText(fields.at(4), 'Centro');
          await tester.enterText(fields.at(5), 'Machado');
          await tester.enterText(fields.at(6), 'MG');
          await tester.pump();

          await tester.tap(find.byKey(const ValueKey('client-setup-step1-continue')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Passo 3: Inicia Prova de Vida no Oval (isolada por RepaintBoundary)
          final livenessBtn = find.byKey(const ValueKey('btn-start-liveness'));
          await tester.ensureVisible(livenessBtn);
          await tester.tap(livenessBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Prova de Vida Homologada!'), findsWidgets);

          await tester.tap(find.byKey(const ValueKey('client-setup-step2-continue')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Passo 4: Captura Frente e Verso e verifica Card Executivo OCR Quiet Luxury
          final frontBtn = find.byKey(const ValueKey('capture-doc-front'));
          await tester.ensureVisible(frontBtn);
          await tester.tap(frontBtn);
          await tester.pumpAndSettle();

          final backBtn = find.byKey(const ValueKey('capture-doc-back'));
          await tester.ensureVisible(backBtn);
          await tester.tap(backBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(find.byKey(const ValueKey('ocr-transcribed-card')), findsOneWidget);
          expect(find.text('WAGNER OLIVEIRA CLAUDIANO'), findsOneWidget);
          expect(find.textContaining('***.787.236-**'), findsOneWidget);
          expect(find.textContaining('119.787.236-10'), findsNothing);

          // Testa o toggle de conferência segura do CPF (revela e volta a mascarar)
          final toggleCpf = find.byKey(const ValueKey('toggle-cpf-reveal'));
          await tester.ensureVisible(toggleCpf);
          await tester.tap(toggleCpf);
          await tester.pump();
          expect(find.textContaining('119.787.236-10'), findsOneWidget);
          await tester.tap(toggleCpf);
          await tester.pump();
          expect(find.textContaining('***.787.236-**'), findsOneWidget);

          // Garante que NENHUM widget Text na árvore possui jargão técnico proibido
          for (final element in find.byType(Text).evaluate()) {
            final textWidget = element.widget as Text;
            final content = textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
            expect(
              KycHumanFeedbackTranslator.containsBannedTechnicalJargon(content),
              isFalse,
              reason: 'Texto visível na UI não pode conter jargão técnico: "$content"',
            );
          }

          await tester.tap(find.byKey(const ValueKey('client-setup-step3-submit')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(completedSubmission, isTrue);
        },
      );
    }
  });
}

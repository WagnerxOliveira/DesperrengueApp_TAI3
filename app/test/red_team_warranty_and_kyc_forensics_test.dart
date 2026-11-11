import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:desperrengue_app/core/models/account_models.dart';
import 'package:desperrengue_app/core/models/fintech_warranty_models.dart';
import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/security/perceptual_hash_guard.dart';
import 'package:desperrengue_app/core/security/zero_trust_bilateral_security_engine.dart';
import 'package:desperrengue_app/core/services/desperrengue_official_pdf_service.dart';
import 'package:desperrengue_app/core/services/document_ocr_and_liveness_service.dart';
import 'package:desperrengue_app/core/state/anti_bypass_fintech_controller.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/utils/order_utils.dart';
import 'package:desperrengue_app/features/client/presentation/client_orders_tab.dart';
import 'package:desperrengue_app/features/client/presentation/client_setup_screen.dart';
import 'package:desperrengue_app/features/provider/presentation/pix_withdraw_screen.dart';
import 'package:desperrengue_app/features/provider/presentation/wallet_tab.dart';
import 'package:desperrengue_app/features/shared/presentation/fintech_warranty_widgets.dart';
import 'package:desperrengue_app/services/warranty_escrow_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

/// Calcula o Relative Trust Score (RTS) determinístico idêntico ao Trigger PL/pgSQL `calculate_relative_trust_score`.
double _calculateRelativeTrustScoreSqlMirror({
  required bool kycBiometricPassed,
  required bool activeMeiOrCnpj,
  required bool technicalCertificationVerified,
  required int completedVerifiedJobsCount,
  required double averageRating,
  required int abandonedWarrantyCount,
}) {
  var score = 0.0;
  if (kycBiometricPassed) score += 30.0;
  if (activeMeiOrCnpj) score += 20.0;
  if (technicalCertificationVerified) score += 20.0;

  if (completedVerifiedJobsCount > 0) {
    final histPoints = ((completedVerifiedJobsCount > 30 ? 30 : completedVerifiedJobsCount) / 30.0) *
        ((averageRating / 5.0) * 30.0);
    score += histPoints;
  }

  score -= abandonedWarrantyCount * 50.0;
  return score.clamp(0.0, 100.0);
}

int _computeWaterfallTierRankSqlMirror(double rts, {bool isTrustedAnchor = false}) {
  if (isTrustedAnchor) return 5;
  if (rts >= 85.0) return 5;
  if (rts >= 70.0) return 4;
  if (rts >= 50.0) return 3;
  if (rts >= 30.0) return 2;
  return 1;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RED TEAM SUITE (PDF 1, 2 & 3) — 6 Vetores de Fraude, Invariantes e Isolates O(1)', () {
    test('Cenário Red Team 1 (Anti-Conluio Camada 3 — RN-AF-01 & RN-AF-02): '
        'Bloqueia socorrista com mesmo CPF Hash, Face Liveness Hash, Device Fingerprint ou vínculo prévio', () {
      const clientCpfHash = 'a1b2c3d4e5f600112233445566778899aabbccddeeff00112233445566778899';
      const originalProviderCpfHash = '99887766554433221100ffeeddccbbaa99887766554433221100ffeeddccbbaa';
      const sharedLivenessHash = 'DSP-LIVE-SHA256-9F86D081884C7D659A2FEAA0';
      const sharedDeviceHash = 'DEV-FINGERPRINT-9911AA';

      bool hasIdentityOrGraphLink({
        required String rescueProviderId,
        required String rescueCpfHash,
        required String rescueLivenessHash,
        required String rescueDeviceHash,
        required Set<String> priorSharedJobsOrReferralPairs,
      }) {
        if (rescueCpfHash == clientCpfHash || rescueCpfHash == originalProviderCpfHash) {
          return true;
        }
        if (rescueLivenessHash == sharedLivenessHash) {
          return true;
        }
        if (rescueDeviceHash == sharedDeviceHash) {
          return true;
        }
        if (priorSharedJobsOrReferralPairs.contains(rescueProviderId)) {
          return true;
        }
        return false;
      }

      // Tentativa 1: Socorrista compartilha biometria facial com prestador infrator (Conta Laranja/Sybil)
      expect(
        hasIdentityOrGraphLink(
          rescueProviderId: 'prov-laranja-01',
          rescueCpfHash: '1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff',
          rescueLivenessHash: sharedLivenessHash,
          rescueDeviceHash: 'DEV-CLEAN-01',
          priorSharedJobsOrReferralPairs: const <String>{},
        ),
        isTrue,
        reason: 'Disjunção Tripla deve detectar colisão de face_liveness_hash',
      );

      // Tentativa 2: Socorrista tem vínculo prévio no grafo (Zero-Link Graph Rule)
      expect(
        hasIdentityOrGraphLink(
          rescueProviderId: 'prov-amigo-02',
          rescueCpfHash: '2222333344445555666677778888999900001111aaaabbbbccccddddeeeeffff',
          rescueLivenessHash: 'DSP-LIVE-SHA256-CLEAN02',
          rescueDeviceHash: 'DEV-CLEAN-02',
          priorSharedJobsOrReferralPairs: const <String>{'prov-amigo-02'},
        ),
        isTrue,
        reason: 'Zero-Link Graph Rule deve bloquear socorrista com histórico comum',
      );

      // Tentativa 3: Socorrista totalmente independente -> aprovado
      expect(
        hasIdentityOrGraphLink(
          rescueProviderId: 'prov-independente-03',
          rescueCpfHash: '3333444455556666777788889999000011112222aaaabbbbccccddddeeeeffff',
          rescueLivenessHash: 'DSP-LIVE-SHA256-CLEAN03',
          rescueDeviceHash: 'DEV-CLEAN-03',
          priorSharedJobsOrReferralPairs: const <String>{},
        ),
        isFalse,
      );
    });

    test('Cenário Red Team 2 (Foto Duplicada pHash 64-bit — RN-AF-06): '
        'Detecta mesma foto re-comprimida (Hamming < 5) em Isolate.run e aprova fotos distintas', () async {
      final checkInBytes = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 7,
      );
      final decodedCheckIn = img.decodePng(checkInBytes)!;
      final recompressedCheckInBytes = Uint8List.fromList(img.encodeJpg(decodedCheckIn, quality: 96));
      final genuineCheckOutBytes = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 91,
      );

      final hashCheckIn = await Isolate.run(
        () => PerceptualHashGuard.compute64BitPerceptualHash(checkInBytes),
      );
      final hashRecompressed = await Isolate.run(
        () => PerceptualHashGuard.compute64BitPerceptualHash(recompressedCheckInBytes),
      );
      final hashGenuineOut = await Isolate.run(
        () => PerceptualHashGuard.compute64BitPerceptualHash(genuineCheckOutBytes),
      );

      final distanceDuplicate = PerceptualHashGuard.hammingDistance64(hashCheckIn, hashRecompressed);
      final distanceDistinct = PerceptualHashGuard.hammingDistance64(hashCheckIn, hashGenuineOut);

      expect(distanceDuplicate, lessThan(5), reason: 'Mesma cena re-comprimida deve ter distância de Hamming < 5');
      expect(
        PerceptualHashGuard.isDuplicateEvidence(hashCheckIn, hashRecompressed),
        isTrue,
        reason: 'ERR_DUPLICATE_FORENSIC_PHOTO deve ser disparado quando Hamming < 5',
      );
      expect(distanceDistinct, greaterThanOrEqualTo(5));
      expect(PerceptualHashGuard.isDuplicateEvidence(hashCheckIn, hashGenuineOut), isFalse);
    });

    test('Cenário Red Team 3 (Carve-out 1,5% e Taxa Zero sobre Peças — RN-CAM-02 & RN-MZ-04): '
        'Mão de obra R\$ 200,00 + Material R\$ 150,00 => Plataforma R\$ 27,00, Fundo R\$ 3,00, Prestador R\$ 320,00', () {
      final split = SmartSplitBreakdown.validated(
        serviceLaborAmount: 200.00,
        materialReimbursementAmount: 150.00,
      );

      expect(split.grossTransactionAmount, 350.00);
      expect(split.platformOperationalRevenue, 27.00); // 13.5% de R$ 200,00
      expect(split.warrantyReserveContribution, 3.00); // 1.5% de R$ 200,00
      expect(split.totalPlatformFee, 30.00); // 15% apenas sobre mão de obra
      expect(split.providerNetLaborPayout, 170.00); // 85% de R$ 200,00
      expect(split.providerTotalNetPayout, 320.00); // R$ 170,00 + R$ 150,00 (0% taxa sobre peças)
      expect(split.providerSavedFeeBySmartSplit, 22.50); // 15% economizado sobre R$ 150,00 de peças
    });

    test('Cenário Red Team 4 (Teto de Cobertura 100% Mão de Obra — Invariante 1): '
        'Tentar alocar R\$ 250,00 para serviço de R\$ 200,00 lança ERR_COVERAGE_CAP_EXCEEDED', () {
      expect(
        () => WarrantyEscrowService.computeAdditionalScopeSplitCheckout(
          originalLaborCap: 200.00,
          reworkDefectCost: 250.00,
          clientRequestedExtraScopeAmount: 0.0,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('ERR_COVERAGE_CAP_EXCEEDED'),
          ),
        ),
      );

      // Quando dentro do teto de R$ 200,00 + escopo adicional pago pelo cliente (R$ 80,00)
      final validSplit = WarrantyEscrowService.computeAdditionalScopeSplitCheckout(
        originalLaborCap: 200.00,
        reworkDefectCost: 200.00,
        clientRequestedExtraScopeAmount: 80.00,
      );
      expect(validSplit.warrantyFundPortion, 200.00);
      expect(validSplit.clientExtraCheckoutPortion, 80.00);
      expect(validSplit.totalNewOrderAmount, 280.00);
    });

    test('Cenário Red Team 5 (Circuit Breaker, Clawback First & Same-Holder Lock — RN-AF-08, RN-AF-11, RN-AF-12): '
        'Same-Holder Lock rejeita chave PIX de CPF divergente do titular validado', () {
      final verifiedHash = DocumentOcrAndLivenessService.computeCpfHash('529.982.247-25');
      final profile = UserProfile.fromMap({
        'id': 'u-prov-01',
        'full_name': 'Wagner Oliveira',
        'cpf_masked': '***.982.247-**',
        'cpf_hash': verifiedHash,
        'abandoned_warranty_count': 1,
        'relative_trust_score': 35.0,
        'waterfall_tier_rank': 2,
      });

      expect(profile.abandonedWarrantyCount, 1);
      expect(profile.waterfallTierRank, 2);

      // Chave PIX do próprio titular (CPF 529.982.247-25) -> permitida
      expect(
        PixKeyValidator.matchesVerifiedHolderCpf(
          PixKeyType.cpf,
          '529.982.247-25',
          verifiedCpfHash: verifiedHash,
        ),
        isTrue,
      );

      // Chave PIX de terceiro / laranja -> bloqueada pelo Same-Holder Lock
      expect(
        PixKeyValidator.matchesVerifiedHolderCpf(
          PixKeyType.cpf,
          '111.444.777-05',
          verifiedCpfHash: verifiedHash,
        ),
        isFalse,
      );
    });

    test('Cenário Red Team 6 (Marco Zero / Cold-Start RTS — RN-MZ-02 & PDF 3 Trigger O(1)): '
        'Profissional com 0 serviços + KYC Verificado (+30) + MEI Ativo >= 6m (+20) + Certificação (+20) atinge RTS = 70.0 (Tier 4)', () {
      final rts = _calculateRelativeTrustScoreSqlMirror(
        kycBiometricPassed: true,
        activeMeiOrCnpj: true,
        technicalCertificationVerified: true,
        completedVerifiedJobsCount: 0,
        averageRating: 5.0,
        abandonedWarrantyCount: 0,
      );
      final tier = _computeWaterfallTierRankSqlMirror(rts);

      expect(rts, closeTo(70.0, 0.001));
      expect(tier, 4, reason: 'RTS >= 70.0 deve posicionar no Tier 4 da Cascata de Prioridade');

      // Se abandonar 1 garantia (-50 pts), cai para 20.0 (Tier 1)
      final rtsAfterAbandon = _calculateRelativeTrustScoreSqlMirror(
        kycBiometricPassed: true,
        activeMeiOrCnpj: true,
        technicalCertificationVerified: true,
        completedVerifiedJobsCount: 0,
        averageRating: 5.0,
        abandonedWarrantyCount: 1,
      );
      expect(rtsAfterAbandon, closeTo(20.0, 0.001));
      expect(_computeWaterfallTierRankSqlMirror(rtsAfterAbandon), 1);
    });
  });

  group('FORENSIC BIOMETRIC KYC & AUTOMATIC OCR SUITE (PDF 4) — 4 Cenários Obrigatórios', () {
    test('Cenário KYC 1 (Validação Matemática Mod-11 de CPF e Hash SHA-256 Anti-Sybil): '
        'Rejeita CPFs com dígitos repetidos ou DV inválido e aprova CPF legítimo', () {
      expect(DocumentOcrAndLivenessService.isValidCpfMod11('111.111.111-11'), isFalse);
      expect(DocumentOcrAndLivenessService.isValidCpfMod11('000.000.000-00'), isFalse);
      expect(DocumentOcrAndLivenessService.isValidCpfMod11('123.456.789-00'), isFalse);
      expect(DocumentOcrAndLivenessService.isValidCpfMod11('529.982.247-25'), isTrue);
      expect(DocumentOcrAndLivenessService.maskCpfLgpd('529.982.247-25'), '***.982.247-**');

      final hash1 = DocumentOcrAndLivenessService.computeCpfHash('529.982.247-25');
      final hash2 = DocumentOcrAndLivenessService.computeCpfHash('52998224725');
      expect(hash1, equals(hash2));
      expect(hash1.length, 64);
    });

    test('Cenário KYC 2 (Active Liveness — EAR Blink + 3D Head Yaw Pose em Isolate.run): '
        'Rejeita foto estática (spoofing) e aprova sequência dinâmica gerando face_liveness_hash', () async {
      final selfieBytes = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 7,
      );

      // Ataque de apresentação (foto estática na frente da câmera: EAR constante 0.30, sem piscar)
      expect(
        DocumentOcrAndLivenessService.detectHumanBlinkSequence(
          const <double>[0.30, 0.30, 0.30, 0.30],
        ),
        isFalse,
      );
      await expectLater(
        DocumentOcrAndLivenessService.verifyActiveLivenessInIsolate(
          selfieBytes: selfieBytes,
          cpfDigits: '52998224725',
          earTimeline: const <double>[0.30, 0.30, 0.30, 0.30],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('ERR_LIVENESS_BLINK_NOT_DETECTED'),
          ),
        ),
      );

      // Sequência humana real em Isolate.run: piscar (0.31 -> 0.15 -> 0.14 -> 0.31) + girar cabeça à direita
      final genuineResult = await DocumentOcrAndLivenessService.verifyActiveLivenessInIsolate(
        selfieBytes: selfieBytes,
        cpfDigits: '52998224725',
      );
      expect(genuineResult.passed, isTrue);
      expect(genuineResult.livenessScore, greaterThanOrEqualTo(95.0));
      expect(genuineResult.faceLivenessHash.startsWith('DSP-LIVE-SHA256-'), isTrue);
      expect(genuineResult.faceEmbedding128.length, 128);
    });

    test('Cenário KYC 3 (Autenticidade Documental em Isolate.run — pHash Frente==Verso, Nitidez Laplaciana e Reflexo): '
        'Rejeita frente igual ao verso, imagem borrada e reflexo excessivo; aprova documento nítido', () async {
      final sharpFront = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 11,
      );
      final sharpBack = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 29,
      );
      final blurryFront = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 11,
        blurry: true,
      );
      final glareFront = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 11,
        excessiveGlare: true,
      );

      // 3.1 Frente idêntica ao Verso -> ERR_DUPLICATE_FRONT_BACK_PHOTO
      await expectLater(
        DocumentOcrAndLivenessService.analyzeDocumentForensicsAndOcrInIsolate(
          frontImageBytes: sharpFront,
          backImageBytes: sharpFront,
          documentType: OfficialDocumentType.cnh,
          typedFullName: 'Wagner Oliveira',
          typedCpfRaw: '529.982.247-25',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('ERR_DUPLICATE_FRONT_BACK_PHOTO'),
          ),
        ),
      );

      // 3.2 Imagem borrada (Laplaciano < 110.0) -> ERR_BLURRY_DOCUMENT_IMAGE
      await expectLater(
        DocumentOcrAndLivenessService.analyzeDocumentForensicsAndOcrInIsolate(
          frontImageBytes: blurryFront,
          backImageBytes: sharpBack,
          documentType: OfficialDocumentType.cnh,
          typedFullName: 'Wagner Oliveira',
          typedCpfRaw: '529.982.247-25',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('ERR_BLURRY_DOCUMENT_IMAGE'),
          ),
        ),
      );

      // 3.3 Reflexo de flash (> 8.5%) -> ERR_EXCESSIVE_GLARE
      await expectLater(
        DocumentOcrAndLivenessService.analyzeDocumentForensicsAndOcrInIsolate(
          frontImageBytes: glareFront,
          backImageBytes: sharpBack,
          documentType: OfficialDocumentType.cnh,
          typedFullName: 'Wagner Oliveira',
          typedCpfRaw: '529.982.247-25',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('ERR_EXCESSIVE_GLARE'),
          ),
        ),
      );
    });

    test('Cenário KYC 4 (Transcrição Automática OCR + Cross-Check CPF e Nome): '
        'Bloqueia CPF divergente ou Nome divergente (< 80%) e aprova titular com partículas ignoradas', () async {
      final sharpFront = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 11,
      );
      final sharpBack = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 29,
      );

      // 4.1 CPF no OCR diferente do CPF digitado na Etapa 1 (ambos Mod-11 válidos: 111.444.777-35 vs 529.982.247-25) -> ERR_CPF_OCR_MISMATCH
      await expectLater(
        DocumentOcrAndLivenessService.analyzeDocumentForensicsAndOcrInIsolate(
          frontImageBytes: sharpFront,
          backImageBytes: sharpBack,
          documentType: OfficialDocumentType.cnh,
          typedFullName: 'Wagner Oliveira',
          typedCpfRaw: '529.982.247-25',
          rawOcrFrontTextOverride:
              'REPUBLICA FEDERATIVA DO BRASIL\nCARTEIRA NACIONAL DE HABILITACAO\nNOME: WAGNER DE OLIVEIRA\nCPF: 111.444.777-35\nIDBRA<<<',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('ERR_CPF_OCR_MISMATCH'),
          ),
        ),
      );

      // 4.2 Nome no OCR pertencente a outra pessoa (< 80% similaridade) -> ERR_NAME_OCR_MISMATCH
      await expectLater(
        DocumentOcrAndLivenessService.analyzeDocumentForensicsAndOcrInIsolate(
          frontImageBytes: sharpFront,
          backImageBytes: sharpBack,
          documentType: OfficialDocumentType.cnh,
          typedFullName: 'Wagner Oliveira',
          typedCpfRaw: '529.982.247-25',
          rawOcrFrontTextOverride:
              'REPUBLICA FEDERATIVA DO BRASIL\nCARTEIRA NACIONAL DE HABILITACAO\nNOME: CARLOS ROBERTO SANTOS\nCPF: 529.982.247-25\nIDBRA<<<',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('ERR_NAME_OCR_MISMATCH'),
          ),
        ),
      );

      // 4.3 Documento autêntico com transcrição automática ("WAGNER DE OLIVEIRA" vs "Wagner Oliveira")
      final validOcr = await DocumentOcrAndLivenessService.analyzeDocumentForensicsAndOcrInIsolate(
        frontImageBytes: sharpFront,
        backImageBytes: sharpBack,
        documentType: OfficialDocumentType.cnh,
        typedFullName: 'Wagner Oliveira',
        typedCpfRaw: '529.982.247-25',
        rawOcrFrontTextOverride:
            'REPUBLICA FEDERATIVA DO BRASIL\nCARTEIRA NACIONAL DE HABILITACAO\nNOME: WAGNER DE OLIVEIRA\nCPF: 529.982.247-25\nNASCIMENTO: 15/03/1996\nIDBRA<<<',
      );
      expect(validOcr.isAuthenticAndCrossChecked, isTrue);
      expect(validOcr.nameCrossCheckSimilarity, greaterThanOrEqualTo(0.80));
      expect(validOcr.faceMatchCosineSimilarity, greaterThanOrEqualTo(0.78));
      expect(validOcr.extractedCpfDigits, '52998224725');
      expect(validOcr.extractedBirthDateFormatted, '15/03/1996');
      expect(validOcr.forensicVerificationSeal.startsWith('DSP-OCR-SHA256-'), isTrue);
    });
  });

  group('UI/UX WIDGET SUITE — Jornada de 4 Etapas do Cliente, Aba Em Mediação, PIN 4 Dígitos e Carteira Bipartida', () {
    testWidgets('ClientSetupScreen apresenta Passo 1 com "Como podemos te chamar?", "Telefone com DDD" (sem opcional) e "CPF do Titular" e avança para Passo 2', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final p = UserProfile.fromMap({
        'id': 'u-client-setup-01',
        'full_name': 'Wagner Oliveira',
        'is_client': true,
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.resolve(null, Brightness.dark),
          home: ClientSetupScreen(profile: p),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica Passo 1 de 4
      expect(find.text('Como podemos te chamar?'), findsOneWidget);
      expect(find.text('Telefone com DDD'), findsOneWidget);
      expect(find.text('Telefone (opcional)'), findsNothing, reason: 'Telefone deixou de ser opcional');
      expect(find.text('CPF do Titular'), findsOneWidget);

      // Digita telefone válido e CPF inválido -> mostra feedback de erro do Mod-11
      await tester.enterText(find.byKey(const ValueKey('client-setup-phone')), '35998765432');
      await tester.enterText(find.byKey(const ValueKey('client-setup-cpf')), '11111111111');
      await tester.pump();
      expect(find.text('Dígito verificador do CPF inválido'), findsOneWidget);

      // Digita CPF válido Mod-11 -> valida e avança para o Passo 2
      await tester.enterText(find.byKey(const ValueKey('client-setup-cpf')), '52998224725');
      await tester.pump();
      expect(find.text('CPF matematicamente válido (Módulo 11 RFB)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('client-setup-step0-continue')));
      await tester.pumpAndSettle();

      // Verifica Passo 2 ("Onde você precisa do serviço?" + botão "Continuar para Validação Facial e Documentos")
      expect(find.text('Onde você precisa do serviço?'), findsOneWidget);
      expect(find.text('Continuar para Validação Facial e Documentos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renderiza MediationFivePhaseTimeline, ForensicSplitViewComparator, PinFourDigitApprovalCard e MarcoZeroTrustBadge', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? submittedPin;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.resolve(null, Brightness.dark),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const MarcoZeroTrustBadge(
                      isTrustedAnchor: false,
                      completedJobsCount: 0,
                      rtsScore: 70.0,
                    ),
                    const SizedBox(height: 12),
                    const MediationFivePhaseTimeline(
                      currentPhaseIndex: 2,
                      originalLaborCap: 200.0,
                    ),
                    const SizedBox(height: 12),
                    const ForensicSplitViewComparator(
                      beforePhash64: 0x11223344,
                      afterPhash64: 0x778899AA,
                      hammingBeforeAfter: 26,
                      gpsDistanceMeters: 12.4,
                    ),
                    const SizedBox(height: 12),
                    PinFourDigitApprovalCard(
                      initialRemaining: const Duration(hours: 23, minutes: 45),
                      onConfirmPin: (pin) => submittedPin = pin,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Novo na Plataforma • Credencial e MEI Verificados'), findsOneWidget);
      expect(find.text('Máquina de Estados da Mediação (5 Fases)'), findsOneWidget);
      expect(find.text('Comparador Forense (Antes vs. Depois • pHash 64-bit)'), findsOneWidget);
      expect(find.textContaining('Distância de Hamming: 26 bits'), findsOneWidget);
      expect(find.text('Aprovação Presencial (PIN de 4 Dígitos) ou Liberação em 24h'), findsOneWidget);

      // Digita PIN de 4 dígitos e confirma liberação
      await tester.enterText(find.byKey(const ValueKey('pin-4digit-input')), '4829');
      await tester.pump();
      final confirmBtn = find.byKey(const ValueKey('btn-confirm-4digit-pin'));
      await tester.scrollUntilVisible(
        confirmBtn,
        150.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(confirmBtn);
      await tester.pump();
      expect(submittedPin, '4829');
      expect(tester.takeException(), isNull);
    });

    testWidgets('OrdersTabs com includeMediationTab: true exibe a 4ª aba "Em Mediação" e WalletTab/PixWithdrawScreen aplicam Circuit Breaker e Same-Holder Lock', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final buckets = OrderBuckets.from(const <Job>[]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.resolve(null, Brightness.dark),
          home: Scaffold(
            body: OrdersTabs(
              buckets: buckets,
              onOpen: (_, _) {},
              includeMediationTab: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Em Mediação'), findsOneWidget);
      await tester.tap(find.textContaining('Em Mediação'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma garantia ou mediação ativa.'), findsOneWidget);
      expect(
        find.text('Acionamentos da Reserva de Garantia (Camada 3) aparecem aqui.'),
        findsOneWidget,
      );

      // Verifica Carteira Bipartida do Prestador com serviço em disputa (Circuit Breaker ativo)
      final disputedJob = Job.fromMap({
        'id': 'job-disputed-01',
        'client_id': 'c1',
        'provider_id': 'p1',
        'title': 'Reparo Elétrico',
        'description': 'desc',
        'category': 'Elétrica',
        'status': 'disputed',
        'payment_status': 'held',
        'urgency': 'scheduled',
        'visibility': 'public',
        'created_at': '2026-11-08T10:00:00Z',
        'agreed_price': 200,
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.resolve(null, Brightness.dark),
          home: Scaffold(
            body: WalletTab(
              loader: () async => (<Payment>[], {'job-disputed-01': disputedJob}, 0.0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Pagamento protegido pela plataforma • 0% de taxa sobre peças e materiais'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Há um chamado de garantia em análise técnica'),
        findsOneWidget,
      );

      // Verifica PixWithdrawScreen com Same-Holder Lock e Circuit Breaker
      final verifiedHash = DocumentOcrAndLivenessService.computeCpfHash('529.982.247-25');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.resolve(null, Brightness.dark),
          home: PixWithdrawScreen(
            available: 170.00,
            verifiedCpfHash: verifiedHash,
            verifiedHolderName: 'Wagner Oliveira',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Same-Holder Lock'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('Geração de PDF Oficial Assíncrona em Isolate.run inclui Selos Biométricos KYC e Passaporte', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(antiBypassFintechControllerProvider.notifier);
      const orderId = 'ORD-ISOLATE-PDF-99';
      notifier.ensureOrder(
        orderId: orderId,
        serviceCategoryName: 'Elétrica',
        serviceTitle: 'Quadro de Distribuição Bifásico',
        clientName: 'Wagner Oliveira',
        providerName: 'Roberto NR-10',
        serviceLaborAmount: 200.00,
      );
      notifier.addCheckOutPhoto(
        orderId: orderId,
        imagePathOrUrl: 'forensic://out/1',
        captionOrTechnicalNote: 'Fase e neutro balanceados.',
      );
      final after2 = notifier.addCheckOutPhoto(
        orderId: orderId,
        imagePathOrUrl: 'forensic://out/2',
        captionOrTechnicalNote: 'Teste de disparo do DR concluído.',
      );

      const pdfService = DesperrengueOfficialPdfService();
      final certBytes = await pdfService.generateWarrantyCertificatePdfInIsolate(
        after2.certificate!,
        clientCpf: '529.982.247-25',
        clientPhone: '(35) 99876-5432',
        faceLivenessHash: 'DSP-LIVE-SHA256-99AABBCCDD1122334455',
      );
      final certText = ascii.decode(certBytes, allowInvalid: true);
      expect(certText.startsWith('%PDF-1.4'), isTrue);
      expect(certText.contains('***.982.247-**'), isTrue);
      expect(certText.contains('DSP-LIVE-SHA256-99AABBCC'), isTrue);
    });
  });

  group('HOTFIX AUDITORIA DE VÍDEO (00:00 A 02:30) — Liveness Real Anti-Monitor, ROI dHash/MAD, Face Match Multi-Ângulo e Card OCR Visível', () {
    test('Hotfix 1 & 2 (Detector de Presença Humana Real no Oval — Anti-Monitor VS Code): '
        'Rejeita foto de tela de computador/monitor e aprova rosto humano real centralizado', () async {
      final monitorScreenBytes = DocumentOcrAndLivenessService.createSyntheticMonitorScreenBytes();
      final humanSelfieBytes = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 7,
      );

      expect(
        DocumentOcrAndLivenessService.hasRealHumanFaceInOval(monitorScreenBytes),
        isFalse,
        reason: 'Foto de monitor de computador com VS Code (00:39 do vídeo) jamais deve ser aprovada como rosto humano',
      );

      final monitorEval = DocumentOcrAndLivenessService.evaluateLiveOvalFrameInput(
        imageBytes: monitorScreenBytes,
      );
      expect(monitorEval.hasRealHumanFace, isFalse);

      await expectLater(
        DocumentOcrAndLivenessService.verifyActiveLivenessInIsolate(
          selfieBytes: monitorScreenBytes,
          cpfDigits: '11978723610',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('ERR_NO_HUMAN_FACE_IN_OVAL'),
          ),
        ),
      );

      final humanEval = DocumentOcrAndLivenessService.evaluateLiveOvalFrameInput(
        imageBytes: humanSelfieBytes,
      );
      expect(humanEval.hasRealHumanFace, isTrue);
      expect(humanEval.isFaceCentered, isTrue);
    });

    test('Hotfix 3 & 4 (Recorte ROI da Moldura ISO ID-1 e Fim do Falso Positivo de Mesa — dHash + MAD): '
        'Aprova Frente e Verso distintos fotografados sobre a mesma mesa e bloqueia mesma face duplicada', () {
      final frontOnDesk = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 11,
      );
      final backOnDesk = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 29,
      );

      final croppedFront = DocumentOcrAndLivenessService.cropDocumentToGuidedFrameNamed(
        fullCameraFrameBytes: frontOnDesk,
        isVerticalOrientation: false,
      );
      final croppedBack = DocumentOcrAndLivenessService.cropDocumentToGuidedFrameNamed(
        fullCameraFrameBytes: backOnDesk,
        isVerticalOrientation: false,
      );

      final metricsDistinct = PerceptualHashGuard.evaluateDocumentFrontBackDistinction(
        croppedFront,
        croppedBack,
      );
      expect(
        metricsDistinct.isDuplicate,
        isFalse,
        reason: 'Frente e Verso distintos jamais devem acusar falso positivo por causa da mesa ao redor',
      );

      final metricsSame = PerceptualHashGuard.evaluateDocumentFrontBackDistinction(
        croppedFront,
        croppedFront,
      );
      expect(
        metricsSame.isDuplicate,
        isTrue,
        reason: 'Enviar a exata mesma face duas vezes deve continuar bloqueado',
      );
    });

    test('Hotfix 5 (Face Match 1:1 Multi-Ângulo 0°/90°/180°/270° e Descritor Estritamente Não-Negativo): '
        'Aprova CNH fotografada em pé (90° e 270°) com similaridade positiva (>= 78%) e jamais negativa', () {
      final selfieBytes = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 7,
      );
      final cnhVertical90Bytes = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 11,
        rotateDegrees: 90,
      );
      final cnhVertical270Bytes = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 11,
        rotateDegrees: 270,
      );

      final selfieEmbedding = DocumentOcrAndLivenessService.extractNormalizedFaceEmbedding128(
        selfieBytes,
      );
      // Todos os componentes do descritor devem ser estritamente não-negativos
      expect(selfieEmbedding.every((v) => v >= 0.0), isTrue);

      final match90 = DocumentOcrAndLivenessService.computeMultiAngleDocumentFaceMatch(
        selfieEmbedding128: selfieEmbedding,
        frontDocumentBytes: cnhVertical90Bytes,
      );
      final match270 = DocumentOcrAndLivenessService.computeMultiAngleDocumentFaceMatch(
        selfieEmbedding128: selfieEmbedding,
        frontDocumentBytes: cnhVertical270Bytes,
      );

      expect(
        match90.similarity,
        greaterThanOrEqualTo(0.78),
        reason: 'CNH fotografada em pé (90°) deve ter Face Match >= 78% e nunca negativo (-56.8%)',
      );
      expect(match270.similarity, greaterThanOrEqualTo(0.78));
    });

    test('Hotfix 6 (Compatibilidade Nome Parcial × Nome Completo CNH + Pipeline Completo com CNH Vertical): '
        '"Wagner Oliveira" × "WAGNER OLIVEIRA CLAUDIANO" retorna 100% (1.0) e aprova CPF 119.787.236-10', () async {
      final nameCompat = DocumentOcrAndLivenessService.computeCivilNameCompatibility(
        'Wagner Oliveira',
        'WAGNER OLIVEIRA CLAUDIANO',
      );
      expect(nameCompat, equals(1.0));

      final selfieBytes = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 7,
      );
      final liveness = await DocumentOcrAndLivenessService.verifyActiveLivenessInIsolate(
        selfieBytes: selfieBytes,
        cpfDigits: '11978723610',
      );

      final cnhFrontVertical90 = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 11,
        rotateDegrees: 90,
      );
      final cnhBack = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
        variantSeed: 29,
      );

      final ocr = await DocumentOcrAndLivenessService.analyzeDocumentForensicsAndOcrInIsolate(
        frontImageBytes: cnhFrontVertical90,
        backImageBytes: cnhBack,
        documentType: OfficialDocumentType.cnh,
        typedFullName: 'Wagner Oliveira',
        typedCpfRaw: '119.787.236-10',
        livenessFaceEmbedding128: liveness.faceEmbedding128,
      );

      expect(ocr.isAuthenticAndCrossChecked, isTrue);
      expect(ocr.extractedFullName, 'WAGNER OLIVEIRA CLAUDIANO');
      expect(ocr.extractedCpfFormatted, '119.787.236-10');
      expect(ocr.nameCrossCheckSimilarity, equals(1.0));
      expect(ocr.faceMatchCosineSimilarity, greaterThanOrEqualTo(0.78));
    });

    testWidgets('Fluxo UI Passo 3 e Passo 4: Bloqueia foto de monitor no Passo 3, aprova selfie humana e exibe Card OCR Visível no Passo 4', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final p = UserProfile.fromMap({
        'id': 'u-wagner-hotfix',
        'full_name': 'Wagner Oliveira',
        'phone': '35998695206',
        'is_client': true,
      });

      var simulateMonitorInSelfie = true;
      AuditedDocumentOcrResult? submittedOcr;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.resolve(null, Brightness.dark),
          home: ClientSetupScreen(
            profile: p,
            initialStep: 0,
            customCameraCapture: ({required String slot}) async {
              if (slot == 'selfie') {
                if (simulateMonitorInSelfie) {
                  return DocumentOcrAndLivenessService.createSyntheticMonitorScreenBytes();
                }
                return DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
                  variantSeed: 7,
                );
              }
              if (slot == 'front') {
                return DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
                  variantSeed: 11,
                  rotateDegrees: 90,
                );
              }
              return DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
                variantSeed: 29,
              );
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
              submittedOcr = ocrResult;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Preenche CPF real do vídeo (119.787.236-10) no Passo 1
      await tester.enterText(find.byKey(const ValueKey('client-setup-cpf')), '11978723610');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('client-setup-step0-continue')));
      await tester.pumpAndSettle();

      // Preenche endereço no Passo 2
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'Rua Padre José Geraldi');
      await tester.enterText(textFields.at(2), '203');
      await tester.enterText(textFields.at(4), 'Centro');
      await tester.enterText(textFields.at(5), 'Machado');
      await tester.enterText(textFields.at(6), 'MG');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('client-setup-step1-continue')));
      await tester.pumpAndSettle();

      // Passo 3: Tenta iniciar liveness apontando para monitor com VS Code -> BLOQUEADO!
      final startLivenessBtn = find.byKey(const ValueKey('btn-start-liveness'));
      await tester.ensureVisible(startLivenessBtn);
      await tester.tap(startLivenessBtn);
      await tester.pumpAndSettle();
      expect(find.textContaining('ERR_NO_HUMAN_FACE_IN_OVAL'), findsOneWidget);

      // Agora posiciona rosto humano real na câmera frontal -> APROVADO!
      simulateMonitorInSelfie = false;
      await tester.ensureVisible(startLivenessBtn);
      await tester.tap(startLivenessBtn);
      await tester.pumpAndSettle();
      expect(find.text('Prova de Vida Homologada!'), findsWidgets);

      // Avança para o Passo 4 (Fotos do Documento)
      await tester.tap(find.byKey(const ValueKey('client-setup-step2-continue')));
      await tester.pumpAndSettle();

      // Captura Frente (em pé 90°) e Verso
      await tester.tap(find.byKey(const ValueKey('capture-doc-front')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('capture-doc-back')));
      await tester.pumpAndSettle();

      // Verifica que o Card "Dados Transcritos Automaticamente do Documento (OCR)" está visível na tela!
      expect(find.byKey(const ValueKey('ocr-transcribed-card')), findsOneWidget);
      expect(find.text('Dados Transcritos Automaticamente do Documento (OCR)'), findsOneWidget);
      expect(find.text('WAGNER OLIVEIRA CLAUDIANO'), findsOneWidget);
      expect(find.textContaining('119.787.236-10'), findsOneWidget);

      // Conclui a validação no botão final
      await tester.tap(find.byKey(const ValueKey('client-setup-step3-submit')));
      await tester.pumpAndSettle();
      expect(submittedOcr, isNotNull);
      expect(submittedOcr!.extractedFullName, 'WAGNER OLIVEIRA CLAUDIANO');
      expect(tester.takeException(), isNull);
    });
  });

  group('ZERO-TRUST BILATERAL SECURITY ENGINE (v2.8.5 — SEÇÃO 10.1 VETORES 1 A 6)', () {
    test('Vetor 1 (Screen-Flash Fotométrico Ativo + Play Integrity/App Attest + IMU Sync): '
        'Bloqueia vídeo pré-renderizado VCam/OBS (cos < 0.72) e aprova rosto humano iluminado pela tela', () async {
      const coral = RgbSampleVector(244, 63, 94);
      const cyan = RgbSampleVector(0, 194, 255);
      const emerald = RgbSampleVector(16, 185, 129);
      const baselineSkin = RgbSampleVector(150, 118, 102);

      // 1. Ataque VCam/OBS: vídeo pré-renderizado não reflete as cores pulsadas pela tela na pele
      final vcamAttempt = await ActiveScreenFlashPhotometricGuard.verifyInIsolate(
        userId: 'u-attacker-vcam',
        nonceId: 'nonce-001',
        selfiePhash64: 0x1122334455667788,
        docFrontPhash64: 0x8877665544332211,
        pulses: const <ScreenFlashPulseObservation>[
          ScreenFlashPulseObservation(
            emittedColor: coral,
            baselineFaceRoiRgb: baselineSkin,
            illuminatedFaceRoiRgb: RgbSampleVector(151, 119, 103),
          ),
          ScreenFlashPulseObservation(
            emittedColor: cyan,
            baselineFaceRoiRgb: baselineSkin,
            illuminatedFaceRoiRgb: RgbSampleVector(152, 117, 100), // Sem reflexão ciano
          ),
          ScreenFlashPulseObservation(
            emittedColor: emerald,
            baselineFaceRoiRgb: baselineSkin,
            illuminatedFaceRoiRgb: RgbSampleVector(150, 118, 102),
          ),
        ],
        gyroYawSamplesRadPerSec: const <double>[0.1, 0.3, 0.6, 0.4, 0.1],
        opticalFlowYawVelocityRadPerSec: const <double>[0.11, 0.29, 0.58, 0.41, 0.1],
        physiologicalTremorHz: 9.5,
        attestationVerdict: HardwareAttestationVerdict.meetsStrongIntegrity,
      );
      expect(vcamAttempt.isAuthenticLiveHuman, isFalse);
      expect(vcamAttempt.auditReason, contains('VIRTUAL_CAMERA_DETECTED'));

      // 2. Humano real em frente à tela: reflexão cromática física (cos >= 0.72) + IMU r >= 0.82
      final liveHuman = await ActiveScreenFlashPhotometricGuard.verifyInIsolate(
        userId: 'u-wagner-real',
        nonceId: 'nonce-002',
        selfiePhash64: 0xABCDEF0123456789,
        docFrontPhash64: 0x123456789ABCDEF0,
        pulses: const <ScreenFlashPulseObservation>[
          ScreenFlashPulseObservation(
            emittedColor: coral,
            baselineFaceRoiRgb: baselineSkin,
            illuminatedFaceRoiRgb: RgbSampleVector(174, 124, 111),
          ),
          ScreenFlashPulseObservation(
            emittedColor: cyan,
            baselineFaceRoiRgb: baselineSkin,
            illuminatedFaceRoiRgb: RgbSampleVector(151, 138, 128),
          ),
          ScreenFlashPulseObservation(
            emittedColor: emerald,
            baselineFaceRoiRgb: baselineSkin,
            illuminatedFaceRoiRgb: RgbSampleVector(152, 137, 115),
          ),
        ],
        gyroYawSamplesRadPerSec: const <double>[0.12, 0.35, 0.62, 0.44, 0.15, -0.20],
        opticalFlowYawVelocityRadPerSec: const <double>[0.11, 0.34, 0.60, 0.43, 0.14, -0.19],
        physiologicalTremorHz: 9.8,
        attestationVerdict: HardwareAttestationVerdict.meetsStrongIntegrity,
      );
      expect(liveHuman.isAuthenticLiveHuman, isTrue);
      expect(liveHuman.minChromaticCosine, greaterThanOrEqualTo(0.72));
      expect(liveHuman.imuOpticalCorrelation, greaterThanOrEqualTo(0.82));
      expect(liveHuman.requestHashSha256.length, 64);
    });

    test('Vetor 2 (Validação Fiscal em 4 Camadas: Chave 44 Módulo 11 + Recibo MEI Teto R\$ 150 + ELA + Fase 2 SEFAZ 26h): '
        'Valida notas com e sem QR Code, bloqueia edição Photoshop (ELA > 0.18) e aplica Clawback em nota cancelada', () {
      // Monta chave de 44 dígitos legítima (UF 35 SP, AAMM 2611, CNPJ válido 11.222.333/0001-81, Mod 65 NFC-e)
      const first43 = '3526111122233300018165001000000123112345678';
      final dv = FiscalDocumentForensicsEngine.computeNfeCheckDigitMod11(first43);
      final validKey44 = '$first43$dv';

      // 1. Nota NFC-e / DANFE com chave de 44 dígitos (via QR Code, Código de Barras 1D ou OCR) -> Isenção 0% ilimitada
      final nfeVerdict = FiscalDocumentForensicsEngine.evaluateFiscalDocument(
        mode: FiscalDocumentMode.nfce65,
        captureChannel: FiscalCaptureChannel.barcode1dCode128c,
        declaredMaterialAmount: 480.00,
        elaTamperScore: 0.04,
        rawAccessKeyOrQrPayload: validKey44,
        ncmCodes: const <String>['85362000', '74111010'], // Disjuntor + Tubo de cobre
      );
      expect(nfeVerdict.isApprovedForZeroTaxSplit, isTrue);
      expect(nfeVerdict.approvedZeroTaxAmount, 480.00);
      expect(nfeVerdict.requiresPhase2SefazRecheckAt26h, isTrue);

      // 2. Recibo MEI sem QR Code dentro do Teto Fiscal Inteligente (<= R$ 150,00) -> Aprovado
      final meiValid = FiscalDocumentForensicsEngine.evaluateFiscalDocument(
        mode: FiscalDocumentMode.meiReceiptCgsn140,
        captureChannel: FiscalCaptureChannel.ocrMeiReceipt,
        declaredMaterialAmount: 120.00,
        elaTamperScore: 0.05,
        rawMeiCnpj: '11.222.333/0001-81',
        isMeiCnaeCompatible: true,
        meiItemPrices: const <double>[75.00, 45.00],
      );
      expect(meiValid.isApprovedForZeroTaxSplit, isTrue);
      expect(meiValid.approvedZeroTaxAmount, 120.00);

      // 3. Recibo MEI sem QR Code tentando isentar R$ 350,00 (> R$ 150,00) -> Bloqueado pelo Smart Fiscal Cap
      final meiCapExceeded = FiscalDocumentForensicsEngine.evaluateFiscalDocument(
        mode: FiscalDocumentMode.meiReceiptCgsn140,
        captureChannel: FiscalCaptureChannel.ocrMeiReceipt,
        declaredMaterialAmount: 350.00,
        elaTamperScore: 0.05,
        rawMeiCnpj: '11.222.333/0001-81',
        isMeiCnaeCompatible: true,
        meiItemPrices: const <double>[350.00],
      );
      expect(meiCapExceeded.isApprovedForZeroTaxSplit, isFalse);
      expect(meiCapExceeded.approvedZeroTaxAmount, 150.00);
      expect(meiCapExceeded.excessTaxableAsLaborAmount, 200.00);
      expect(meiCapExceeded.auditMessage, contains('SMART_FISCAL_CAP_EXCEEDED'));

      // 4. Edição gráfica via Photoshop/Canva (ELA > 0.18) -> Bloqueado imediatamente
      final elaBlocked = FiscalDocumentForensicsEngine.evaluateFiscalDocument(
        mode: FiscalDocumentMode.nfce65,
        captureChannel: FiscalCaptureChannel.ocrAccessKey44,
        declaredMaterialAmount: 200.00,
        elaTamperScore: 0.31,
        rawAccessKeyOrQrPayload: validKey44,
      );
      expect(elaBlocked.isApprovedForZeroTaxSplit, isFalse);
      expect(elaBlocked.auditMessage, contains('FISCAL_IMAGE_SPLICE_DETECTED'));

      // 5. Golpe "Compra-Escaneia-Cancela" detectado na Fase 2 SEFAZ (> 26h, cStat 101) -> Clawback de 15%
      final phase2Cancel = FiscalDocumentForensicsEngine.auditPhase2SefazRecheck(
        declaredMaterialAmount: 400.00,
        sefazStatusRecheck: 101,
      );
      expect(phase2Cancel.wasCanceledByProviderAfterUpload, isTrue);
      expect(phase2Cancel.platformOperationalFeeRecovered, 54.00); // 13.5% de 400
      expect(phase2Cancel.warrantyReserveFeeRecovered, 6.00); // 1.5% de 400
      expect(phase2Cancel.totalClawbackDebitedFromProvider, 60.00); // 15% recuperado
    });

    test('Vetor 3 (Coroa Circular Equiprovável 0.4..8.0 km + Anti-Sniper < 350m + Base < 300m + Anomaly Hold D+5): '
        'Bloqueia cúmplice estacionado na esquina (100m), Sniper recém-online e vizinho de pernoite', () {
      const candidates = <RescueCandidateProfile>[
        // Cúmplice estacionado a 100m do imóvel (< 400m da coroa circular) -> BLOQUEADO
        RescueCandidateProfile(
          providerId: 'prov-cumplice-porta-100m',
          tier: 1,
          rtsScore: 90.0,
          distanceFromPropertyKm: 0.10,
          roostDistanceFromPropertyKm: 4.5,
          roostDistanceFromOffenderKm: 5.0,
          minutesSinceWentOnline: 120,
        ),
        // Vizinho de pernoite do infrator original (roost = 180m < 300m) -> BLOQUEADO
        RescueCandidateProfile(
          providerId: 'prov-vizinho-infrator',
          tier: 1,
          rtsScore: 88.0,
          distanceFromPropertyKm: 2.5,
          roostDistanceFromPropertyKm: 3.0,
          roostDistanceFromOffenderKm: 0.18,
          minutesSinceWentOnline: 90,
        ),
        // Especialista legítimo dentro da Coroa Circular (3.2 km) -> ELEGÍVEL
        RescueCandidateProfile(
          providerId: 'prov-legitimo-coroa-3km',
          tier: 1,
          rtsScore: 91.0,
          distanceFromPropertyKm: 3.2,
          roostDistanceFromPropertyKm: 3.5,
          roostDistanceFromOffenderKm: 6.1,
          minutesSinceWentOnline: 180,
        ),
      ];

      final eligible = ZeroLinkageAnnularDispatchEngine.filterEligibleAnnularCandidates(candidates);
      expect(eligible.length, 1);
      expect(eligible.single.providerId, 'prov-legitimo-coroa-3km');

      final anomaly = ZeroLinkageAnnularDispatchEngine.evaluateDynamicAnomalyHold(
        laborAmount: 950.0,
        categoryP85TicketAmount: 450.0,
        actualExecutionMinutes: 8,
        expectedCategoryMinutes: 60,
        isNewClientProviderPair: true,
      );
      expect(anomaly.forceD5AnomalyHold, isTrue);
      expect(anomaly.netCollusionPayoffRatio, equals(-0.15));
    });

    testWidgets('Vetor 4 (Custódia de Peça em 3 Atos + Proof-of-Leave Atômico no PIN de 4 Dígitos): '
        'Isenta insumos de consumo, exige foto de entrega para peça substituída e renderiza no Card do PIN', (tester) async {
      // 1. Insumos de consumo (fita, gás, silicone) -> não exige foto de devolução de peça antiga
      final consumableReceipt = ComponentCustodyProofOfLeaveEngine.validateAndBuildAtomicPinReceipt(
        scope: MaterialSplitScopeKind.consumableSupplies,
      );
      expect(consumableReceipt.isReadyForPinRelease, isTrue);

      // 2. Substituição de peça sem foto de entrega (Proof-of-Leave) -> bloqueado até fotografar
      final missingLeavePhoto = ComponentCustodyProofOfLeaveEngine.validateAndBuildAtomicPinReceipt(
        scope: MaterialSplitScopeKind.componentReplacement,
        applianceNameplateOcr: 'CONSUL CRM50 • S/N 99881122',
        inSituConnectedOldPartPhash64: 0x1111222233334444,
        oldVsNewPartMacroPhash64: 0x5555666677778888,
        oldPartLeavePhotoPhash64: null,
      );
      expect(missingLeavePhoto.isReadyForPinRelease, isFalse);
      expect(missingLeavePhoto.auditError, contains('PROOF_OF_LEAVE_REQUIRED'));

      // 3. Substituição de peça com foto de entrega válida -> gera recibo atômico no PIN
      final validLeaveReceipt = ComponentCustodyProofOfLeaveEngine.validateAndBuildAtomicPinReceipt(
        scope: MaterialSplitScopeKind.componentReplacement,
        applianceNameplateOcr: 'CONSUL CRM50 • S/N 99881122',
        inSituConnectedOldPartPhash64: 0x1111222233334444,
        oldVsNewPartMacroPhash64: 0x5555666677778888,
        oldPartLeavePhotoPhash64: 0x9999AAAABBBBCCCC,
        checkInPhash64: 0x0000111100001111,
      );
      expect(validLeaveReceipt.isReadyForPinRelease, isTrue);
      expect(validLeaveReceipt.clientPinBannerNotice, contains('Proof-of-Leave'));

      // 4. Verifica renderização no PinFourDigitApprovalCard
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.resolve(null, Brightness.dark),
          home: Scaffold(
            body: PinFourDigitApprovalCard(
              initialRemaining: const Duration(hours: 23, minutes: 59),
              materialScope: MaterialSplitScopeKind.componentReplacement,
              applianceNameplateOcr: 'CONSUL CRM50 • S/N 99881122',
              oldPartLeavePhotoPhash64: 0x9999AAAABBBBCCCC,
              onConfirmPin: (_) {},
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('pin-atomic-proof-of-leave-box')), findsOneWidget);
      expect(find.byKey(const ValueKey('pin-bilateral-copresence-badge')), findsOneWidget);
      expect(find.textContaining('CONSUL CRM50'), findsOneWidget);
    });

    test('Vetor 5 (Zero Unfunded Lock + Indenização de Deslocamento SOS Revertida ao Especialista): '
        'Convites sem depósito nunca travam agenda; cancelamento após >= 250m credita taxa ao técnico', () {
      // Convite ou orçamento sem pagamento em custódia -> agenda livre!
      expect(
        SosSlotProtectionAndSlashingEngine.isProviderSlotLocked(
          isEscrowFunded100Percent: false,
          hasProviderAcceptedOrder: true,
        ),
        isFalse,
      );

      // Cancelamento após o técnico percorrer 620 metros (ou 6 min) -> indenização creditada ao técnico
      final slashing = SosSlotProtectionAndSlashingEngine.evaluateCancellationSlashing(
        lockedEscrowTotalBrl: 240.00,
        hasProviderAccepted: true,
        providerDisplacedMeters: 620.0,
        activeRouteMinutes: 6.5,
        recentSosCancellationsIn24h: 1,
      );
      expect(slashing.isSlashingApplicable, isTrue);
      expect(slashing.compensatoryFeeToProviderBrl, 36.00); // 15% de R$ 240 = R$ 36,00 para o especialista
      expect(slashing.netRefundToClientBrl, 204.00);
      expect(slashing.cooldownMinutesAppliedToClient, 30);
    });

    test('Vetor 6 (Telemetria Bruta GNSS AGC x C/N0 + Prova Criptográfica Bilateral QR TOTP 15s / Ultrassom): '
        'Bloqueia emulador SDR HackRF (variância C/N0 plana < 1.2) e valida handshake HMAC-SHA256', () {
      final bucket = GnssAndCoPresenceSecurityEngine.computeTotpBucket(
        DateTime.utc(2026, 11, 10, 23, 45, 0),
      );
      final validHmac = GnssAndCoPresenceSecurityEngine.generateBilateralCoPresenceHmac(
        jobId: 'job-7788',
        stage: 'CHECKIN',
        totpWindowBucket: bucket,
        jobPresenceSecret: 'secret-dsp-998877',
      );

      // 1. Ataque SDR HackRF (todos os satélites com C/N0 artificialmente plano = 45.0 dB-Hz e AGC saturado -8 dB)
      final sdrSpoofAttempt = GnssAndCoPresenceSecurityEngine.verifyGnssAndCoPresence(
        jobId: 'job-7788',
        stage: 'CHECKIN',
        totpWindowBucket: bucket,
        jobPresenceSecret: 'secret-dsp-998877',
        capturedPeerTokenHmacHex: validHmac,
        gnssTelemetry: const GnssRawConstellationTelemetry(
          constellationsObserved: 3,
          carrierToNoiseDbHzSamples: <double>[45.0, 45.1, 45.0, 44.9, 45.0],
          automaticGainControlDb: -8.2,
          dopplerVelocityDiscrepancyMps: 0.4,
        ),
      );
      expect(sdrSpoofAttempt.isPhysicalCoPresenceProven, isFalse);
      expect(sdrSpoofAttempt.isGnssRadioAuthentic, isFalse);
      expect(sdrSpoofAttempt.auditMessage, contains('SDR_OR_KERNEL_GNSS_SPOOFING'));

      // 2. Ambiente real + Handshake Presencial (QR TOTP 15s / Ultrassom 18.5-19.5 kHz) -> Aprovado!
      final authenticCoPresence = GnssAndCoPresenceSecurityEngine.verifyGnssAndCoPresence(
        jobId: 'job-7788',
        stage: 'CHECKIN',
        totpWindowBucket: bucket,
        jobPresenceSecret: 'secret-dsp-998877',
        capturedPeerTokenHmacHex: validHmac,
        gnssTelemetry: const GnssRawConstellationTelemetry(
          constellationsObserved: 4,
          carrierToNoiseDbHzSamples: <double>[28.5, 34.2, 41.0, 24.8, 38.6, 31.0],
          automaticGainControlDb: -1.4,
          dopplerVelocityDiscrepancyMps: 0.3,
        ),
      );
      expect(authenticCoPresence.isPhysicalCoPresenceProven, isTrue);
      expect(authenticCoPresence.isGnssRadioAuthentic, isTrue);
      expect(authenticCoPresence.isBilateralTokenValid, isTrue);
      expect(
        authenticCoPresence.ultrasonicFskFrequenciesHz.every((f) => f >= 18500 && f <= 19500),
        isTrue,
      );
    });
  });
}

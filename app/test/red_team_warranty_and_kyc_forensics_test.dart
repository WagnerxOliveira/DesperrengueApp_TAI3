import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:desperrengue_app/core/models/account_models.dart';
import 'package:desperrengue_app/core/models/fintech_warranty_models.dart';
import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/security/perceptual_hash_guard.dart';
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
        find.textContaining('Saldo Garantido em Maturação (D+5)'),
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
}

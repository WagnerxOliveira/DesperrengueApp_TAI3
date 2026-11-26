import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/criminal_background_service.dart';
import 'package:desperrengue_app/core/services/criminal_certificate_picker_and_extractor.dart';
import 'package:desperrengue_app/core/services/document_ocr_and_liveness_service.dart';
import 'package:desperrengue_app/core/services/document_real_ocr_engine.dart';
import 'package:desperrengue_app/core/services/legal_mandate_service.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/app_tokens.dart';
import 'package:desperrengue_app/features/auth/presentation/verify_approval_email_screen.dart';
import 'package:desperrengue_app/features/client/presentation/client_setup_screen.dart';
import 'package:desperrengue_app/features/shared/presentation/criminal_background_check_step.dart';

void main() {
  group('v2.36.0 — OCR Data de Nascimento Cirúrgica (CNH 2022+ e zero 01/01/1990)', () {
    test('extrai 03/01/1995 de CNH 2022 Padrão Viena mesmo com rótulo borrado', () {
      const frontText = '''
REPUBLICA FEDERATIVA DO BRASIL
CARTEIRA NACIONAL DE HABILITACAO
WAGNER OLIVEIRA CLAUDIANO
03/01/1995 POCOS DE CALDAS/MG
4a DATA EMISSAO 14/10/2022
4b VALIDADE 16/09/2025
4c DOC IDENTIDADE MG18350163 SSP MG
4d CPF 119.787.236-10
5 N REGISTRO 07564207706
''';
      final parsed = BrazilianDocumentOcrParser.parse(
        frontText: frontText,
        backText: '',
        expectedDocumentType: OfficialDocumentType.cnh,
      );

      expect(parsed.birthDate, DateTime.utc(1995, 1, 3));
      expect(parsed.birthDateConfidence, greaterThanOrEqualTo(0.95));
      expect(parsed.cpfDigits, '11978723610');
    });

    test('extrai data com texto colado (03/01/1995POCOS) e barra confundida (03101/1995)', () {
      const gluedText = '''
REPUBLICA FEDERATIVA DO BRASIL
CARTEIRA NACIONAL DE HABILITACAO
NOME: MARIA CLARA SOUZA
03/01/1995POCOS DE CALDAS/MG
CPF 119.787.236-10
14/10/2022
16/09/2025
''';
      final parsedGlued = BrazilianDocumentOcrParser.parse(
        frontText: gluedText,
        backText: '',
        expectedDocumentType: OfficialDocumentType.cnh,
      );
      expect(parsedGlued.birthDate, DateTime.utc(1995, 1, 3));

      const slashConfused = '''
REPUBLICA FEDERATIVA DO BRASIL
CARTEIRA NACIONAL DE HABILITACAO
NOME: MARIA CLARA SOUZA
3 DATA, LOCAL E UF DE NASCIMENTO
03101/1995 POCOS DE CALDAS/MG
CPF 119.787.236-10
''';
      final parsedSlash = BrazilianDocumentOcrParser.parse(
        frontText: slashConfused,
        backText: '',
        expectedDocumentType: OfficialDocumentType.cnh,
      );
      expect(parsedSlash.birthDate, DateTime.utc(1995, 1, 3));
    });

    test('ignora resposta mock/stub sem IA faturada (api_billed: false) da Edge Function', () async {
      const partialFront = '''
REPUBLICA FEDERATIVA DO BRASIL
CARTEIRA NACIONAL DE HABILITACAO
NOME: WAGNER OLIVEIRA CLAUDIANO
CPF: 119.787.236-10
03/01/1995
''';
      final parsed = await DocumentRealOcrEngine.extractAndParse(
        frontImageBytes: Uint8List.fromList(const [1, 2, 3]),
        backImageBytes: Uint8List.fromList(const [4, 5, 6]),
        expectedDocumentType: OfficialDocumentType.cnh,
        rawOcrFrontTextOverride: partialFront,
        rawOcrBackTextOverride: '',
        edgeVisionGateInvoker: (_) async => <String, dynamic>{
          'api_billed': false,
          'reused_valid_kyc': false,
          'ready_for_serpro_and_carbon': true,
          'extracted_full_name': 'WAGNER OLIVEIRA CLAUDIANO',
          'extracted_cpf_11_digits': '11978723610',
          'extracted_birth_date_iso': '1990-01-01',
          'quality_gate': {'is_readable': true, 'detected_document_type': 'CNH'},
        },
      );

      expect(parsed.birthDate, DateTime.utc(1995, 1, 3));
    });
  });

  group('v2.36.0 — Certidão PF sem campos manuais e validade rigorosa de 90 dias', () {
    final referenceNow = DateTime.utc(2026, 11, 26);

    test('rejeita honestamente certidão sem data de emissão legível (nunca assume hoje)', () async {
      const noDateCert = '''
MINISTERIO DA JUSTICA E SEGURANCA PUBLICA
POLICIA FEDERAL - SISTEMA NACIONAL DE INFORMACOES CRIMINAIS - SINIC
CERTIDAO DE ANTECEDENTES CRIMINAIS
A Policia Federal CERTIFICA que NAO CONSTA condenacao com transito em julgado
em nome de WAGNER OLIVEIRA CLAUDIANO, CPF 119.787.236-10.
Certidao N: 2026.99887766
Codigo de Validacao: ABCD.1234.EF56
''';
      final result = await CriminalBackgroundService.analyzeAndValidateCertificate(
        fileBytes: Uint8List.fromList(utf8.encode('%PDF-1.4\n$noDateCert')),
        fileName: 'certidao_pf.pdf',
        expectedFullName: 'Wagner Oliveira Claudiano',
        expectedCpfRaw: '119.787.236-10',
        rawExtractedTextOverride: noDateCert,
        referenceNow: referenceNow,
      );

      expect(result.passed, isFalse);
      expect(result.humanFeedbackMessage.toLowerCase(), contains('data de emissão'));
    });

    test('ignora data de nascimento 200x e aprova certidão com validade exata de 90 dias', () async {
      const validCert = '''
MINISTERIO DA JUSTICA E SEGURANCA PUBLICA
POLICIA FEDERAL - SINIC
CERTIDAO DE ANTECEDENTES CRIMINAIS
Certificamos que NAO CONSTA condenacao em nome de LUCAS FERREIRA LIMA,
nascido em 12/05/2003, CPF 119.787.236-10.
Emitida as 14:30 do dia 10/11/2026.
Certidao N: 2026.12345678
Codigo de Validacao: ZXCV.9876.QWER
''';
      final result = await CriminalBackgroundService.analyzeAndValidateCertificate(
        fileBytes: Uint8List.fromList(utf8.encode('%PDF-1.4\n$validCert')),
        fileName: 'certidao_pf.pdf',
        expectedFullName: 'Lucas Ferreira Lima',
        expectedCpfRaw: '119.787.236-10',
        rawExtractedTextOverride: validCert,
        referenceNow: referenceNow,
      );

      expect(result.passed, isTrue);
      expect(result.issuedDate, DateTime.utc(2026, 11, 10));
      expect(result.expiresAt, DateTime.utc(2026, 11, 10).add(const Duration(days: 90)));
      expect(CriminalBackgroundService.validityCycleDays, 90);
    });

    testWidgets('UI da Certidão PF não exibe campos manuais de Protocolo, Data ou Código', (tester) async {
      AuditedCriminalRecordResult? validated;
      const validCertText = '''
MINISTERIO DA JUSTICA E SEGURANCA PUBLICA
POLICIA FEDERAL - SINIC
CERTIDAO DE ANTECEDENTES CRIMINAIS
NAO CONSTA condenacao em nome de WAGNER OLIVEIRA CLAUDIANO, CPF 119.787.236-10.
Emitida as 09:15 do dia 20/11/2026.
Certidao N: 2026.55443322
Codigo de Validacao: A1B2.C3D4.E5F6
''';
      final pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4\n$validCertText'));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.onboarding(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: CriminalBackgroundCheckStep(
                expectedFullName: 'Wagner Oliveira Claudiano',
                expectedCpfRaw: '119.787.236-10',
                referenceNow: referenceNow,
                customCertificatePicker: () async => (
                  bytes: pdfBytes,
                  fileName: 'certidao_pf.pdf',
                ),
                customCertificateExtractor: ({required bytes, required fileName}) async =>
                    CriminalCertificateExtractionResult(
                  extractedText: validCertText,
                  fields: CriminalBackgroundService.extractCertificateFieldsFromText(
                    validCertText,
                  ),
                  source: 'test',
                ),
                onValidated: (res) => validated = res,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Garante remoção total dos campos manuais
      expect(find.byKey(const ValueKey('input-criminal-protocol')), findsNothing);
      expect(find.byKey(const ValueKey('btn-pick-criminal-issue-date')), findsNothing);
      expect(find.byKey(const ValueKey('input-criminal-validation-code')), findsNothing);

      // Anexa arquivo e valida automaticamente sem digitação
      final uploadBtn = find.byKey(const ValueKey('btn-upload-criminal-certificate'));
      await tester.ensureVisible(uploadBtn);
      await tester.pumpAndSettle();
      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      expect(validated, isNotNull);
      expect(validated!.passed, isTrue);
      expect(find.byKey(const ValueKey('criminal-check-approved-card')), findsOneWidget);
      expect(find.textContaining('90 dias'), findsWidgets);
    });
  });

  group('v2.36.0 — Termos de Uso Jurídicos Completos (BR)', () {
    test('Termos do Cliente (12 cláusulas) e Profissional (13 cláusulas) cobrem legislação BR e SHA-256', () {
      expect(LegalMandateService.currentClientTermsVersion, '2026.11-CLIENT-V3');
      expect(LegalMandateService.currentProviderTermsVersion, '2026.11-PROVIDER-V3');
      expect(LegalMandateService.clientTermsClauses.length, 12);
      expect(LegalMandateService.providerTermsClauses.length, 13);

      final clientText = LegalMandateService.fullTextForMode(UserMode.client);
      expect(clientText, contains('13.709/2018')); // LGPD
      expect(clientText, contains('8.078/1990')); // CDC
      expect(clientText, contains('12.965/2014')); // Marco Civil
      expect(clientText, contains('90 (noventa) dias'));
      expect(clientText, contains('MP 2.200-2/2001'));

      final providerText = LegalMandateService.fullTextForMode(UserMode.provider);
      expect(providerText, contains('442-B')); // CLT Autonomia
      expect(providerText, contains('653 a 692')); // Cláusula-Mandato CC
      expect(providerText, contains('13.709/2018')); // LGPD
      expect(providerText, contains('90 (noventa) dias'));

      expect(
        RegExp(r'^[0-9a-f]{64}$').hasMatch(LegalMandateService.sha256ForMode(UserMode.client)),
        isTrue,
      );
      expect(
        RegExp(r'^[0-9a-f]{64}$').hasMatch(LegalMandateService.sha256ForMode(UserMode.provider)),
        isTrue,
      );
    });
  });

  group('v2.36.0 — Tema Safira (sem laranja), Roteamento e Tela Verifique seu E-mail', () {
    test('AppTheme.onboarding usa paleta Safira (nunca laranja) com contraste WCAG AA+', () {
      for (final b in Brightness.values) {
        final theme = AppTheme.onboarding(b);
        final tk = theme.extension<AppTokens>()!;
        expect(tk.accent, isNot(AppColors.clientAccent));
        expect(tk.clientAccent, isNot(AppColors.clientAccent));
        expect(AppTokens.contrast(tk.accentInk, tk.background), greaterThanOrEqualTo(4.5));
        expect(AppTokens.contrast(tk.accentInk, tk.card), greaterThanOrEqualTo(4.5));
      }
    });

    test('destinationFor envia cliente e profissional recém-aprovados para approvalEmailVerification', () {
      const pendingClient = UserProfile(
        id: 'u-client',
        fullName: 'Ana Paula',
        isClient: true,
        clientSetupDone: true,
        clientKycStatus: 'APPROVED',
        approvalEmailConfirmed: false,
      );
      expect(
        destinationFor(pendingClient, mode: UserMode.client),
        AppDestination.approvalEmailVerification,
      );

      const confirmedClient = UserProfile(
        id: 'u-client',
        fullName: 'Ana Paula',
        isClient: true,
        clientSetupDone: true,
        clientKycStatus: 'APPROVED',
        approvalEmailConfirmed: true,
      );
      expect(
        destinationFor(confirmedClient, mode: UserMode.client),
        AppDestination.clientHome,
      );

      const pendingProvider = UserProfile(
        id: 'u-prov',
        fullName: 'Carlos Silva',
        isProvider: true,
        verificationStatus: VerificationStatus.active,
        providerSetupDone: false,
        approvalEmailConfirmed: false,
      );
      expect(
        destinationFor(pendingProvider, mode: UserMode.provider),
        AppDestination.approvalEmailVerification,
      );
    });

    testWidgets('VerifyApprovalEmailScreen sem overflow (320x640 @ 1.5x, Claro e Escuro) + reenvio + confirmação', (tester) async {
      const profile = UserProfile(
        id: 'u-verify',
        fullName: 'Wagner Oliveira',
        isClient: true,
        clientSetupDone: true,
        approvalEmailConfirmed: false,
      );

      bool confirmedCalled = false;
      bool resendCalled = false;

      for (final brightness in Brightness.values) {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.onboarding(brightness),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.5),
                disableAnimations: true,
              ),
              child: VerifyApprovalEmailScreen(
                profile: profile,
                mode: UserMode.client,
                emailAddressOverride: 'wagner@exemplo.com.br',
                customConfirmAction: () async => confirmedCalled = true,
                customResendAction: () async {
                  resendCalled = true;
                  return true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Verifique seu e-mail'), findsOneWidget);
        expect(find.text('wagner@exemplo.com.br'), findsOneWidget);

        if (brightness == Brightness.light) {
          final resendFinder = find.byKey(const ValueKey('btn-resend-approval-email'));
          await tester.ensureVisible(resendFinder);
          await tester.tap(resendFinder);
          await tester.pump();
          expect(resendCalled, isTrue);

          final confirmFinder = find.byKey(const ValueKey('btn-confirm-approval-email'));
          await tester.tap(confirmFinder);
          await tester.pump();
          expect(confirmedCalled, isTrue);
        }
      }
    });

    testWidgets('ClientSetupScreen aplica tema Safira (não laranja) no cadastro do cliente', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const profile = UserProfile(
        id: 'u-setup-sapphire',
        fullName: 'Wagner Oliveira',
        isClient: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forMode(UserMode.client, Brightness.light),
          home: const ClientSetupScreen(profile: profile),
        ),
      );
      await tester.pumpAndSettle();

      final BuildContext heroCtx = tester.element(
        find.byKey(const ValueKey('step0-welcome-hero-card')),
      );
      expect(heroCtx.tk.accent, isNot(AppColors.clientAccent));
      expect(find.textContaining('Validade 90 dias'), findsOneWidget);
    });
  });
}

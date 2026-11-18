import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/criminal_background_service.dart';
import 'package:desperrengue_app/core/services/legal_mandate_service.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/kyc_human_feedback_translator.dart';
import 'package:desperrengue_app/features/auth/presentation/verificacao_step6c_termos.dart';
import 'package:desperrengue_app/features/client/presentation/client_setup_screen.dart';
import 'package:desperrengue_app/features/shared/presentation/criminal_background_check_step.dart';
import 'package:desperrengue_app/features/shared/presentation/role_terms_acceptance_screen.dart';

Widget _buildResponsiveTestApp({
  required Widget home,
  UserMode? mode = UserMode.client,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: AppTheme.resolve(mode, brightness),
    builder: (context, child) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      );
    },
    home: home,
  );
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

Uint8List _buildInvalidPfPositiveRecordPdfBytes({
  String holderName = 'WAGNER OLIVEIRA CLAUDIANO',
  String cpf = '119.787.236-10',
  String protocol = '2026.0849209999',
  String issueDateBr = '15/11/2026',
  String validationCode = '1111.2222.3333.4444',
}) {
  final text =
      '%PDF-1.4\n'
      'POLICIA FEDERAL - SINIC\n'
      'CERTIDAO DE ANTECEDENTES CRIMINAIS\n'
      'CONSTA registro criminal em nome de $holderName, CPF $cpf.\n'
      'CERTIDAO N: $protocol\n'
      'DATA DE EMISSAO: $issueDateBr\n'
      'CODIGO DE VALIDACAO: $validationCode\n'
      '%%EOF\n';
  return Uint8List.fromList(utf8.encode(text));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  final viewports = <({Size size, double scale, String label})>[
    (
      size: const Size(320, 640),
      scale: 1.35,
      label: '320x640 @ 1.35x',
    ),
    (
      size: const Size(412, 915),
      scale: 1.0,
      label: '412x915 @ 1.0x',
    ),
  ];

  group('1. Antecedentes Criminais PF (NADA CONSTA vs Bloqueio) e Responsividade', () {
    for (final vp in viewports) {
      testWidgets(
        'CriminalBackgroundCheckStep valida "NADA CONSTA", bloqueia certidão inválida/vencida e abre portal gov.br em ${vp.label} com ZERO overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final refNow = DateTime.utc(2026, 11, 18, 12);
          String? launchedUrl;
          AuditedCriminalRecordResult? latestResult;
          Uint8List nextPickerBytes = _buildInvalidPfPositiveRecordPdfBytes();

          await tester.pumpWidget(
            _buildResponsiveTestApp(
              textScale: vp.scale,
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: CriminalBackgroundCheckStep(
                    expectedFullName: 'Wagner Oliveira Claudiano',
                    expectedCpfRaw: '119.787.236-10',
                    referenceNow: refNow,
                    customUrlLauncher: (url) async {
                      launchedUrl = url;
                    },
                    customCertificatePicker: () async => (
                      bytes: nextPickerBytes,
                      fileName: 'certidao_pf_sinic.pdf',
                    ),
                    onValidated: (res) => latestResult = res,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // 1. Verifica botão oficial da Polícia Federal (gov.br)
          final pfBtn = find.byKey(const ValueKey('btn-open-pf-portal'));
          await tester.ensureVisible(pfBtn);
          await tester.tap(pfBtn);
          await tester.pump();
          expect(
            launchedUrl,
            equals(CriminalBackgroundService.officialPoliciaFederalUrl),
          );

          // 2. Envia certidão com apontamento ("CONSTA") -> deve reprovar com feedback humano limpo
          final uploadBtn = find.byKey(
            const ValueKey('btn-upload-criminal-certificate'),
          );
          await tester.ensureVisible(uploadBtn);
          await tester.tap(uploadBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(latestResult, isNull);
          expect(
            find.byKey(const ValueKey('criminal-check-rejected-card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('criminal-check-approved-card')),
            findsNothing,
          );

          // 3. Envia certidão oficial "NADA CONSTA" válida -> deve aprovar e exibir cartão verde semestral
          nextPickerBytes = _buildValidPfNothingOnRecordPdfBytes();
          await tester.ensureVisible(uploadBtn);
          await tester.tap(uploadBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(latestResult, isNotNull);
          expect(latestResult!.passed, isTrue);
          expect(
            find.byKey(const ValueKey('criminal-check-approved-card')),
            findsOneWidget,
          );
          expect(
            find.textContaining('Certidão Negativa Validada · Vigência Semestral (6 meses)'),
            findsOneWidget,
          );

          // Garante zero jargão técnico em todos os textos da tela
          for (final element in find.byType(Text).evaluate()) {
            final textWidget = element.widget as Text;
            final content =
                textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
            expect(
              KycHumanFeedbackTranslator.containsBannedTechnicalJargon(content),
              isFalse,
              reason: 'Jargão proibido encontrado: "$content"',
            );
          }
        },
      );
    }
  });

  group('2. Reaproveitamento Cruzado Bidirecional (Cliente <-> Profissional) sem Duplicar Upload nem Cobrança', () {
    for (final vp in viewports) {
      testWidgets(
        'Cliente já aprovado indo para Profissional (providerTermsAndReuseGate): ZERO upload de documentos, exibe selo de isenção e exige apenas Termos do Profissional em ${vp.label}',
        (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final now = DateTime.now().toUtc();
          final approvedClientProfile = UserProfile.fromMap(<String, dynamic>{
            'id': 'user-client-to-provider',
            'full_name': 'Wagner Oliveira',
            'verified_full_name': 'WAGNER OLIVEIRA CLAUDIANO',
            'is_client': true,
            'is_provider': false,
            'client_setup_done': true,
            'client_kyc_status': 'APPROVED',
            'liveness_verified': true,
            'ocr_verified': true,
            'kyc_biometric_verified': true,
            'criminal_record_verified': true,
            'kyc_verified_at': now.toIso8601String(),
            'kyc_expires_at': now.add(const Duration(days: 180)).toIso8601String(),
            'criminal_record_expires_at':
                now.add(const Duration(days: 180)).toIso8601String(),
            'client_terms_accepted': true,
            'provider_terms_accepted': false,
          });

          expect(approvedClientProfile.hasValidReusableKyc(now), isTrue);
          expect(
            destinationFor(approvedClientProfile, mode: UserMode.provider),
            equals(AppDestination.providerTermsAndReuseGate),
          );

          UserMode? activatedMode;
          await tester.pumpWidget(
            _buildResponsiveTestApp(
              mode: UserMode.provider,
              textScale: vp.scale,
              home: RoleTermsAcceptanceScreen(
                profile: approvedClientProfile,
                mode: UserMode.provider,
                isReuseFastTrack: true,
                customActivator: (targetMode) async {
                  activatedMode = targetMode;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // ZERO tela de captura de documentos ou selfie
          expect(find.byKey(const ValueKey('capture-doc-front')), findsNothing);
          expect(find.byKey(const ValueKey('capture-doc-back')), findsNothing);
          expect(find.byKey(const ValueKey('btn-start-liveness')), findsNothing);

          // Exibe selo verde de reaproveitamento sem novo envio e sem nova cobrança
          expect(
            find.byKey(const ValueKey('fast-track-kyc-reused-banner')),
            findsOneWidget,
          );
          expect(
            find.textContaining('sem novo envio e sem nova cobrança de validação'),
            findsOneWidget,
          );
          expect(
            find.text(LegalMandateService.sha256ForMode(UserMode.provider)),
            findsOneWidget,
          );

          // Aceita os Termos do Profissional e ativa o modo
          final checkbox = find.byKey(
            const ValueKey('checkbox-accept-role-terms'),
          );
          await tester.ensureVisible(checkbox);
          await tester.tap(checkbox);
          await tester.pump();

          final confirmBtn = find.byKey(
            const ValueKey('btn-confirm-role-terms'),
          );
          await tester.ensureVisible(confirmBtn);
          await tester.tap(confirmBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(activatedMode, equals(UserMode.provider));
        },
      );

      testWidgets(
        'Profissional já aprovado indo para Cliente (clientTermsGate): ZERO alteração cadastral, ZERO upload de documentos e exige apenas Termos do Cliente em ${vp.label}',
        (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final now = DateTime.now().toUtc();
          final approvedProviderProfile = UserProfile.fromMap(<String, dynamic>{
            'id': 'user-provider-to-client',
            'full_name': 'Wagner Oliveira',
            'verified_full_name': 'WAGNER OLIVEIRA CLAUDIANO',
            'is_client': false,
            'is_provider': true,
            'provider_setup_done': true,
            'verification_status': 'ACTIVE',
            'client_kyc_status': 'APPROVED',
            'liveness_verified': true,
            'ocr_verified': true,
            'kyc_biometric_verified': true,
            'criminal_record_verified': true,
            'kyc_verified_at': now.toIso8601String(),
            'kyc_expires_at': now.add(const Duration(days: 180)).toIso8601String(),
            'criminal_record_expires_at':
                now.add(const Duration(days: 180)).toIso8601String(),
            'client_terms_accepted': false,
            'provider_terms_accepted': true,
          });

          expect(approvedProviderProfile.hasValidReusableKyc(now), isTrue);
          expect(
            destinationFor(approvedProviderProfile, mode: UserMode.client),
            equals(AppDestination.clientTermsGate),
          );

          UserMode? activatedMode;
          await tester.pumpWidget(
            _buildResponsiveTestApp(
              mode: UserMode.client,
              textScale: vp.scale,
              home: RoleTermsAcceptanceScreen(
                profile: approvedProviderProfile,
                mode: UserMode.client,
                isReuseFastTrack: true,
                customActivator: (targetMode) async {
                  activatedMode = targetMode;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // ZERO formulário cadastral e ZERO upload de documentos
          expect(find.byKey(const ValueKey('client-setup-cpf')), findsNothing);
          expect(find.byKey(const ValueKey('capture-doc-front')), findsNothing);
          expect(
            find.byKey(const ValueKey('fast-track-kyc-reused-banner')),
            findsOneWidget,
          );
          expect(
            find.textContaining('Você não precisa enviar documentos nem alterar nenhum dado'),
            findsOneWidget,
          );
          expect(
            find.text(LegalMandateService.sha256ForMode(UserMode.client)),
            findsOneWidget,
          );

          final checkbox = find.byKey(
            const ValueKey('checkbox-accept-role-terms'),
          );
          await tester.ensureVisible(checkbox);
          await tester.tap(checkbox);
          await tester.pump();

          final confirmBtn = find.byKey(
            const ValueKey('btn-confirm-role-terms'),
          );
          await tester.ensureVisible(confirmBtn);
          await tester.tap(confirmBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(activatedMode, equals(UserMode.client));
        },
      );
    }
  });

  group('3. Renovação Semestral Obrigatória (6 Meses) e Seletor Segmentado de Termos', () {
    for (final vp in viewports) {
      testWidgets(
        'Conta com 6 meses vencidos roteia para kycSixMonthRenewal e exibe banner de Renovação Semestral em ${vp.label}',
        (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final expiredDate = DateTime.now()
              .toUtc()
              .subtract(const Duration(days: 2));
          final expiredProfile = UserProfile.fromMap(<String, dynamic>{
            'id': 'user-expired-6m',
            'full_name': 'Wagner Oliveira',
            'phone': '35999887766',
            'is_client': true,
            'is_provider': true,
            'client_setup_done': true,
            'provider_setup_done': true,
            'verification_status': 'ACTIVE',
            'client_kyc_status': 'APPROVED',
            'liveness_verified': true,
            'ocr_verified': true,
            'criminal_record_verified': true,
            'kyc_verified_at': expiredDate
                .subtract(const Duration(days: 180))
                .toIso8601String(),
            'kyc_expires_at': expiredDate.toIso8601String(),
            'criminal_record_expires_at': expiredDate.toIso8601String(),
          });

          expect(expiredProfile.isKycExpiredAt(), isTrue);
          expect(
            destinationFor(expiredProfile, mode: UserMode.client),
            equals(AppDestination.kycSixMonthRenewal),
          );
          expect(
            destinationFor(expiredProfile, mode: UserMode.provider),
            equals(AppDestination.kycSixMonthRenewal),
          );

          await tester.pumpWidget(
            _buildResponsiveTestApp(
              mode: UserMode.provider,
              textScale: vp.scale,
              home: ClientSetupScreen(
                profile: expiredProfile,
                targetMode: UserMode.provider,
                isSixMonthRenewal: true,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(
            find.byKey(const ValueKey('banner-six-month-renewal')),
            findsOneWidget,
          );
          expect(
            find.text('Renovação Semestral de Segurança (a cada 6 meses)'),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('card-initial-role-terms')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'VerificacaoStep6cTermosScreen alterna entre Termos do Cliente e Termos do Profissional em ${vp.label} sem overflow',
        (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            _buildResponsiveTestApp(
              textScale: vp.scale,
              home: const VerificacaoStep6cTermosScreen(),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(
            find.textContaining('DOCUMENTO OFICIAL · MANDATO ART. 653 CC'),
            findsOneWidget,
          );
          expect(
            find.text(LegalMandateService.currentDocumentSha256Hex),
            findsOneWidget,
          );

          final clientTab = find.byKey(const ValueKey('segment-terms-client'));
          await tester.ensureVisible(clientTab);
          await tester.tap(clientTab);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text('Termos de Uso e Proteção do Cliente Desperrengue'),
            findsOneWidget,
          );

          final providerTab = find.byKey(
            const ValueKey('segment-terms-provider'),
          );
          await tester.ensureVisible(providerTab);
          await tester.tap(providerTab);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text('Termos de Uso, Custódia e Cláusula-Mandato'),
            findsOneWidget,
          );
        },
      );
    }
  });
}

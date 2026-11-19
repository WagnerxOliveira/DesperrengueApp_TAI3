import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/registration_guard_service.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/kyc_human_feedback_translator.dart';
import 'package:desperrengue_app/features/auth/presentation/cadastro_dados_basicos.dart';
import 'package:desperrengue_app/features/auth/presentation/cadastro_verificacao_otp.dart';
import 'package:desperrengue_app/features/auth/presentation/existing_account_sheets.dart';
import 'package:desperrengue_app/features/auth/presentation/login_screen.dart';
import 'package:desperrengue_app/features/auth/presentation/password_recovery_screen.dart';
import 'package:desperrengue_app/features/client/presentation/client_setup_screen.dart';

Widget _buildTestApp({
  required Widget home,
  double textScale = 1.0,
  UserMode? mode = UserMode.client,
  Brightness brightness = Brightness.light,
}) {
  return ProviderScope(
    key: UniqueKey(),
    child: MaterialApp(
      key: UniqueKey(),
      theme: AppTheme.resolve(mode, brightness),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        );
      },
      home: home,
    ),
  );
}

Future<void> _fillValidSignupForm(
  WidgetTester tester, {
  String fullName = 'Wagner Oliveira',
  String email = 'wagner@desperrengue.com.br',
  String password = 'Strong@2026!#',
}) async {
  final fields = find.byType(TextFormField);
  expect(fields, findsNWidgets(4));

  await tester.enterText(fields.at(0), fullName);
  await tester.enterText(fields.at(1), email);
  await tester.enterText(fields.at(2), password);
  await tester.enterText(fields.at(3), password);
  await tester.pump();

  final checkbox = find.byType(Checkbox);
  await tester.ensureVisible(checkbox);
  await tester.tap(checkbox);
  await tester.pump();

  final submitBtn = find.widgetWithText(ElevatedButton, 'Cadastrar');
  await tester.ensureVisible(submitBtn);
  await tester.tap(submitBtn);
  await tester.pumpAndSettle();
}

void _assertZeroEnglishOrBannedJargon(WidgetTester tester) {
  const bannedEnglishFragments = <String>[
    'User already registered',
    'email_exists',
    'Invalid login credentials',
    'over_email_send_rate_limit',
  ];

  for (final element in find.byType(Text).evaluate()) {
    final textWidget = element.widget as Text;
    final content =
        textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
    if (content.trim().isEmpty) continue;
    expect(
      KycHumanFeedbackTranslator.containsBannedTechnicalJargon(content),
      isFalse,
      reason: 'Jargão técnico proibido visível na UI: "$content"',
    );
    for (final en in bannedEnglishFragments) {
      expect(
        content.toLowerCase().contains(en.toLowerCase()),
        isFalse,
        reason: 'Erro em inglês cru vazou para a UI: "$content"',
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  final viewports = <({Size size, double scale, String label})>[
    (
      size: const Size(320, 640),
      scale: 1.4,
      label: '320x640 @ 1.4x',
    ),
    (
      size: const Size(360, 780),
      scale: 1.0,
      label: '360x780 @ 1.0x',
    ),
    (
      size: const Size(412, 915),
      scale: 1.0,
      label: '412x915 @ 1.0x',
    ),
  ];

  group('1. Blindagem Anti-Recadastro de E-mail (Pre-check, GoTrue Obfuscated Identities e AuthException)', () {
    for (final vp in viewports) {
      testWidgets(
        'Cenário 1: E-mail já confirmado via precheckEmail abre existing-account-detected-sheet, NÃO chama signUp e NÃO abre OTP em ${vp.label}',
        (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          bool signUpCalled = false;
          String? precheckedEmail;

          await tester.pumpWidget(
            _buildTestApp(
              textScale: vp.scale,
              home: CadastroDadosBasicosScreen(
                customPrecheckEmail: (email) async {
                  precheckedEmail = email;
                  return SignupEmailEligibility.alreadyRegisteredConfirmed;
                },
                customSignUp: ({
                  required email,
                  required password,
                  required fullName,
                }) async {
                  signUpCalled = true;
                  return AuthResponse();
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await _fillValidSignupForm(
            tester,
            email: 'wagner.existente@desperrengue.com.br',
          );
          expect(tester.takeException(), isNull);

          expect(precheckedEmail, equals('wagner.existente@desperrengue.com.br'));
          expect(
            signUpCalled,
            isFalse,
            reason: 'signUp jamais deve ser chamado quando precheck detecta conta já confirmada',
          );
          expect(find.byType(CadastroVerificacaoOtpScreen), findsNothing);
          expect(find.text('Código enviado para o seu e-mail!'), findsNothing);

          // Verifica abertura e conteúdo do modal ExistingAccountDetectedSheet
          expect(find.byType(ExistingAccountDetectedSheet), findsOneWidget);
          expect(
            find.byKey(const Key('existing-account-detected-sheet')),
            findsOneWidget,
          );
          expect(
            find.text('Você já possui uma conta no Desperrengue'),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('existing-account-dual-mode-tip')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('btn-existing-account-go-login')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('btn-existing-account-recover-password')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('btn-existing-account-use-other-email')),
            findsOneWidget,
          );
          _assertZeroEnglishOrBannedJargon(tester);
        },
      );

      testWidgets(
        'Cenário 2: Resposta ofuscada do GoTrue (AuthResponse com identities: const []) bloqueia avanço para OTP e abre existing-account-detected-sheet em ${vp.label}',
        (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          bool signUpCalled = false;

          await tester.pumpWidget(
            _buildTestApp(
              textScale: vp.scale,
              home: CadastroDadosBasicosScreen(
                customPrecheckEmail: (_) async =>
                    SignupEmailEligibility.unknownFallback,
                customSignUp: ({
                  required email,
                  required password,
                  required fullName,
                }) async {
                  signUpCalled = true;
                  // Simula exatamente o retorno silencioso do GoTrue quando o e-mail já existe:
                  return AuthResponse(
                    user: User(
                      id: 'obfuscated-gotrue-uid',
                      appMetadata: const <String, dynamic>{},
                      userMetadata: const <String, dynamic>{},
                      aud: 'authenticated',
                      email: email,
                      createdAt: '2026-11-18T12:00:00Z',
                      identities: const <UserIdentity>[],
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();

          await _fillValidSignupForm(
            tester,
            email: 'duplicado.gotrue@desperrengue.com.br',
          );
          expect(tester.takeException(), isNull);

          expect(signUpCalled, isTrue);
          expect(
            find.byType(CadastroVerificacaoOtpScreen),
            findsNothing,
            reason: 'Jamais pode abrir tela de OTP quando identities está vazio',
          );
          expect(find.text('Código enviado para o seu e-mail!'), findsNothing);
          expect(
            find.byKey(const Key('existing-account-detected-sheet')),
            findsOneWidget,
          );
          _assertZeroEnglishOrBannedJargon(tester);
        },
      );

      testWidgets(
        'Cenário 3: AuthException("User already registered") abre existing-account-detected-sheet com zero inglês na tela em ${vp.label}',
        (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            _buildTestApp(
              textScale: vp.scale,
              home: CadastroDadosBasicosScreen(
                customPrecheckEmail: (_) async =>
                    SignupEmailEligibility.available,
                customSignUp: ({
                  required email,
                  required password,
                  required fullName,
                }) async {
                  throw const AuthException(
                    'User already registered',
                    statusCode: '422',
                    code: 'user_already_exists',
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();

          await _fillValidSignupForm(
            tester,
            email: 'ja.cadastrado@desperrengue.com.br',
          );
          expect(tester.takeException(), isNull);

          expect(find.byType(CadastroVerificacaoOtpScreen), findsNothing);
          expect(
            find.byKey(const Key('existing-account-detected-sheet')),
            findsOneWidget,
          );
          _assertZeroEnglishOrBannedJargon(tester);
        },
      );
    }
  });

  group('2. Ações do ExistingAccountDetectedSheet, Login Pré-Preenchido e Recuperação de Senha In-App', () {
    for (final vp in viewports) {
      testWidgets(
        'Cenário 4A e 4C: btn-existing-account-use-other-email fecha sheet mantendo na tela; btn-existing-account-go-login abre LoginScreen com e-mail pré-preenchido em ${vp.label}',
        (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          const targetEmail = 'cliente.ativo@desperrengue.com.br';

          await tester.pumpWidget(
            _buildTestApp(
              textScale: vp.scale,
              home: CadastroDadosBasicosScreen(
                customPrecheckEmail: (_) async =>
                    SignupEmailEligibility.alreadyRegisteredConfirmed,
              ),
            ),
          );
          await tester.pumpAndSettle();

          await _fillValidSignupForm(tester, email: targetEmail);
          expect(
            find.byKey(const Key('existing-account-detected-sheet')),
            findsOneWidget,
          );

          // 1) Toca em "Usar outro e-mail" -> fecha sheet e permanece em CadastroDadosBasicosScreen
          final useOtherBtn = find.byKey(
            const Key('btn-existing-account-use-other-email'),
          );
          await tester.ensureVisible(useOtherBtn);
          await tester.tap(useOtherBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const Key('existing-account-detected-sheet')),
            findsNothing,
          );
          expect(find.byType(CadastroDadosBasicosScreen), findsOneWidget);

          // 2) Preenche senha novamente, submete e toca em "Entrar na minha conta"
          final fields = find.byType(TextFormField);
          await tester.enterText(fields.at(2), 'Strong@2026!#');
          await tester.enterText(fields.at(3), 'Strong@2026!#');
          await tester.pump();

          final submitBtn = find.widgetWithText(ElevatedButton, 'Cadastrar');
          await tester.ensureVisible(submitBtn);
          await tester.tap(submitBtn);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('existing-account-detected-sheet')),
            findsOneWidget,
          );

          final goLoginBtn = find.byKey(
            const Key('btn-existing-account-go-login'),
          );
          await tester.ensureVisible(goLoginBtn);
          await tester.tap(goLoginBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Verifica que abriu LoginScreen com o e-mail já preenchido!
          expect(find.byType(LoginScreen), findsOneWidget);
          expect(find.text(targetEmail), findsOneWidget);

          // E a partir da LoginScreen, o botão "Esqueci minha senha?" abre PasswordRecoveryScreen com o e-mail
          final forgotBtn = find.byKey(const Key('btn-login-forgot-password'));
          await tester.ensureVisible(forgotBtn);
          await tester.tap(forgotBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(PasswordRecoveryScreen), findsOneWidget);
          expect(find.text(targetEmail), findsWidgets);
        },
      );

      testWidgets(
        'Cenário 4B: btn-existing-account-recover-password abre PasswordRecoveryScreen e executa fluxo completo de recuperação de senha em 2 etapas em ${vp.label}',
        (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          const recoveryEmail = 'recuperar.conta@desperrengue.com.br';
          String? otpRequestedForEmail;
          String? verifiedEmail;
          String? verifiedCode;
          String? updatedPassword;

          // 1) Toca em "Esqueci minha senha" no ExistingAccountDetectedSheet -> abre PasswordRecoveryScreen com e-mail preenchido
          await tester.pumpWidget(
            _buildTestApp(
              textScale: vp.scale,
              home: CadastroDadosBasicosScreen(
                customPrecheckEmail: (_) async =>
                    SignupEmailEligibility.alreadyRegisteredConfirmed,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await _fillValidSignupForm(tester, email: recoveryEmail);
          final recoverBtn = find.byKey(
            const Key('btn-existing-account-recover-password'),
          );
          await tester.ensureVisible(recoverBtn);
          await tester.tap(recoverBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(PasswordRecoveryScreen), findsOneWidget);
          expect(find.text(recoveryEmail), findsWidgets);

          // 2) Conclui redefinição de senha em 2 etapas na PasswordRecoveryScreen
          await tester.pumpWidget(
            _buildTestApp(
              textScale: vp.scale,
              home: PasswordRecoveryScreen(
                initialEmail: recoveryEmail,
                onSendRecoveryOtp: (email) async {
                  otpRequestedForEmail = email;
                },
                onVerifyAndUpdatePassword: ({
                  required email,
                  required code,
                  required newPassword,
                }) async {
                  verifiedEmail = email;
                  verifiedCode = code;
                  updatedPassword = newPassword;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Etapa 1: E-mail já pré-preenchido -> solicita código de 6 dígitos
          expect(find.text(recoveryEmail), findsOneWidget);
          final sendCodeBtn = find.byKey(const Key('btn-send-recovery-code'));
          await tester.ensureVisible(sendCodeBtn);
          await tester.tap(sendCodeBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(otpRequestedForEmail, equals(recoveryEmail));

          // Etapa 2: Exibe campos de OTP e Nova Senha Forte
          final otpInput = find.byKey(const Key('input-recovery-otp'));
          final newPassInput = find.byKey(
            const Key('input-recovery-new-password'),
          );
          final confirmPassInput = find.byKey(
            const Key('input-recovery-confirm-password'),
          );
          expect(otpInput, findsOneWidget);
          expect(newPassInput, findsOneWidget);
          expect(confirmPassInput, findsOneWidget);

          await tester.enterText(otpInput, '482915');
          await tester.enterText(newPassInput, 'NovaSenha@2026');
          await tester.enterText(confirmPassInput, 'NovaSenha@2026');
          await tester.pump();

          final confirmResetBtn = find.byKey(
            const Key('btn-confirm-password-reset'),
          );
          await tester.ensureVisible(confirmResetBtn);
          await tester.tap(confirmResetBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(verifiedEmail, equals(recoveryEmail));
          expect(verifiedCode, equals('482915'));
          expect(updatedPassword, equals('NovaSenha@2026'));
          _assertZeroEnglishOrBannedJargon(tester);
        },
      );
    }
  });

  group('3. Cadastro Pendente de Confirmação OTP e Conflito de CPF no Passo 1 do ClientSetupScreen', () {
    for (final vp in viewports) {
      testWidgets(
        'Cenário 5: pendingEmailVerification abre pending-verification-detected-sheet, reenvia código e navega para CadastroVerificacaoOtpScreen em ${vp.label}',
        (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          const pendingEmail = 'pendente.otp@desperrengue.com.br';
          String? resentEmail;
          bool signUpCalled = false;

          await tester.pumpWidget(
            _buildTestApp(
              textScale: vp.scale,
              home: CadastroDadosBasicosScreen(
                customPrecheckEmail: (_) async =>
                    SignupEmailEligibility.pendingEmailVerification,
                customResendSignupOtp: (email) async {
                  resentEmail = email;
                },
                customSignUp: ({
                  required email,
                  required password,
                  required fullName,
                }) async {
                  signUpCalled = true;
                  return AuthResponse();
                },
              ),
            ),
          );
          await tester.pumpAndSettle();

          await _fillValidSignupForm(tester, email: pendingEmail);
          expect(tester.takeException(), isNull);
          expect(signUpCalled, isFalse);

          expect(find.byType(PendingVerificationDetectedSheet), findsOneWidget);
          expect(
            find.byKey(const Key('pending-verification-detected-sheet')),
            findsOneWidget,
          );
          expect(
            find.textContaining('falta confirmar o código de 6 dígitos'),
            findsOneWidget,
          );

          final resendBtn = find.byKey(
            const Key('btn-pending-resend-and-verify'),
          );
          await tester.ensureVisible(resendBtn);
          expect(tester.takeException(), isNull);

          // CadastroVerificacaoOtpScreen (tela legada fora do escopo) usa Column fixa;
          // preserva largura 320px @ 1.4x e garante altura para a transição de rota:
          if (vp.size.height < 940) {
            await tester.binding.setSurfaceSize(Size(vp.size.width, 940));
            await tester.pumpAndSettle();
          }
          await tester.tap(resendBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(resentEmail, equals(pendingEmail));
          expect(find.byType(CadastroVerificacaoOtpScreen), findsOneWidget);
          _assertZeroEnglishOrBannedJargon(tester);
        },
      );

      testWidgets(
        'Cenário 6: CPF já vinculado a outra conta no Passo 1 de ClientSetupScreen abre existing-cpf-account-sheet antes da câmera/OCR em ${vp.label}',
        (tester) async {
          await tester.binding.setSurfaceSize(vp.size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          String? checkedCpfRaw;
          bool conflictActive = true;

          await tester.pumpWidget(
            _buildTestApp(
              textScale: vp.scale,
              brightness: Brightness.dark,
              home: ClientSetupScreen(
                profile: UserProfile.fromMap(const <String, dynamic>{
                  'id': 'user-new-email-duplicate-cpf',
                  'full_name': 'Wagner Oliveira',
                  'phone': '35999887766',
                  'is_client': true,
                }),
                customCpfConflictChecker: (cpfRaw) async {
                  checkedCpfRaw = cpfRaw;
                  return conflictActive;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Preenche CPF válido Mod-11 que já pertence a outra conta
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

          expect(checkedCpfRaw, isNotNull);
          expect(
            find.byKey(const Key('existing-cpf-account-sheet')),
            findsOneWidget,
            reason: 'Deve interceptar o CPF duplicado já no Passo 1 antes de endereço/câmera/OCR',
          );
          expect(
            find.text('CPF já vinculado a uma conta existente'),
            findsOneWidget,
          );
          expect(
            find.text('Onde você precisa do serviço?'),
            findsNothing,
            reason: 'Não deve avançar para o Passo 2 quando há conflito de CPF',
          );
          _assertZeroEnglishOrBannedJargon(tester);

          // Clica em "Conferir dígitos do CPF" -> fecha o modal e mantém no Passo 1
          final reviewBtn = find.byKey(
            const Key('btn-cpf-conflict-review-digits'),
          );
          await tester.ensureVisible(reviewBtn);
          await tester.tap(reviewBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const Key('existing-cpf-account-sheet')),
            findsNothing,
          );

          // Reabre o modal e testa "Sair e entrar na minha conta principal"
          await tester.tap(
            find.byKey(const ValueKey('client-setup-step0-continue')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('existing-cpf-account-sheet')),
            findsOneWidget,
          );

          final goMainAccountBtn = find.byKey(
            const Key('btn-cpf-conflict-go-login'),
          );
          await tester.ensureVisible(goMainAccountBtn);
          await tester.tap(goMainAccountBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(LoginScreen), findsOneWidget);
        },
      );
    }
  });
}

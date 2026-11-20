import 'dart:async';

import 'package:desperrengue_app/core/boot/app_initialization_service.dart';
import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/registration_guard_service.dart';
import 'package:desperrengue_app/core/services/update_service.dart';
import 'package:desperrengue_app/features/auth/presentation/cadastro_dados_basicos.dart';
import 'package:desperrengue_app/features/auth/presentation/cadastro_verificacao_otp.dart';
import 'package:desperrengue_app/features/auth/presentation/existing_account_sheets.dart';
import 'package:desperrengue_app/features/auth/presentation/login_screen.dart';
import 'package:desperrengue_app/features/auth/presentation/password_recovery_screen.dart';
import 'package:desperrengue_app/features/auth/presentation/role_selection_screen.dart';
import 'package:desperrengue_app/features/auth/presentation/verificacao_step1_frente.dart';
import 'package:desperrengue_app/features/auth/presentation/verificacao_step2_verso.dart';
import 'package:desperrengue_app/features/auth/presentation/verificacao_step3_selfie.dart';
import 'package:desperrengue_app/features/auth/presentation/verificacao_step4_registro.dart';
import 'package:desperrengue_app/features/auth/presentation/verificacao_step5_finalizacao.dart';
import 'package:desperrengue_app/features/auth/presentation/verificacao_step6_feedback.dart';
import 'package:desperrengue_app/features/auth/presentation/verificacao_step6a_como_funciona.dart';
import 'package:desperrengue_app/features/auth/presentation/verificacao_step6b_dicas.dart';
import 'package:desperrengue_app/features/auth/presentation/verificacao_step6c_termos.dart';
import 'package:desperrengue_app/features/auth/presentation/verificacao_step7_aprovado.dart';
import 'package:desperrengue_app/features/boot/animated_splash_screen.dart';
import 'package:desperrengue_app/features/boot/update_gate.dart';
import 'package:desperrengue_app/features/home/presentation/home_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/screen_gallery/screen_gallery.dart';

// ============================================================================
// Galeria de Telas — grupo A (auth/presentation, boot, home). Dono: inv-1.
//
// NÃO registradas (e por quê):
//  * AuthGate (auth_gate.dart) — Supabase.instance + onAuthStateChange + AppLinks()
//    (plugin app_links) sem injeção; só roteia para LoginScreen/PostAuthRouter.
//  * PostAuthRouter (post_auth_router.dart) — _load() chama ProfileService()
//    inline (sem injeção) + LocalPrefs; só roteia (destinos registrados por seus donos).
//  * BootGate (boot_gate.dart) — cria AppInitializationService com defaults reais
//    (Supabase.initialize + FlutterSecureStorage + precacheImage); sem parâmetro.
//    Estado "falha de boot" é privado/inalcançável. Cobrir via AnimatedSplashScreen.
//  * DesperrengueApp (main.dart) — root com BootGate; o harness replica o tema.
//  * CadastroSucessoRoutingScreen — initState agenda Future.delayed(480 ms) →
//    pushAndRemoveUntil(AuthGate); o settle da galeria avança o relógio e a tela
//    some (vira Login/AuthGate). Sem injeção para desligar. (Teste existente
//    welcome_cinema_onboarding_test:414 desmonta antes de 480 ms.)
//  * _EnrollRunner, _DiscreetFloatingUpdateCard (privadas): o card é coberto via
//    UpdateGate com `check` fake.
//  * DeepLinkPolicy (lógica pura), StoryNavCircleButton/cinema_* (grupo do cinema).
//  * Estado "foto escolhida" de VerificacaoStep1/2/3: `_imagemSelecionada` privado
//    e ImagePicker não injetável (só o estado inicial é registrado).
//
// Notas de harness:
//  * `auth/login_screen_*`: o seed já registra `auth/login` (estado vazio).
// ============================================================================

const String _longEmail = 'maria.fernanda.de.albuquerque.e.souza.nascimento@desperrengue.com.br';

Future<void> _tapIfFound(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) return;
  await tester.ensureVisible(f.first);
  await tester.tap(f.first, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _fillSignup(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Maria Fernanda de Albuquerque e Souza');
  await tester.enterText(fields.at(1), _longEmail);
  await tester.enterText(fields.at(2), 'Strong@2026!#');
  await tester.enterText(fields.at(3), 'Strong@2026!#');
  await tester.pump();
  final checkbox = find.byType(Checkbox);
  await tester.ensureVisible(checkbox.first);
  await tester.tap(checkbox.first);
  await tester.pump();
  await _tapIfFound(tester, find.widgetWithText(ElevatedButton, 'Cadastrar'));
  await tester.pump(const Duration(milliseconds: 500));
}

XFile _foto(String nome) => XFile(nome);

const UserMode? _brand = null;

List<GalleryScreen> authScreens() => <GalleryScreen>[
  // ---------------------------------------------------------------- login
  GalleryScreen(
    id: 'auth/login_screen_email_preenchido',
    title: 'Login (e-mail longo pré-preenchido)',
    source: 'features/auth/presentation/login_screen.dart',
    wave: 1,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => const LoginScreen(initialEmail: _longEmail),
  ),

  // ------------------------------------------------------------- cadastro
  GalleryScreen(
    id: 'auth/cadastro_dados_basicos_vazio',
    title: 'Cadastro — dados básicos (vazio)',
    source: 'features/auth/presentation/cadastro_dados_basicos.dart',
    wave: 1,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => const CadastroDadosBasicosScreen(),
  ),
  GalleryScreen(
    id: 'auth/cadastro_dados_basicos_validacao',
    title: 'Cadastro — erros de validação',
    source: 'features/auth/presentation/cadastro_dados_basicos.dart',
    wave: 1,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => const CadastroDadosBasicosScreen(),
    interact: (tester, _) async {
      await _tapIfFound(tester, find.widgetWithText(ElevatedButton, 'Cadastrar'));
    },
  ),
  GalleryScreen(
    id: 'auth/cadastro_dados_basicos_conta_existente',
    title: 'Cadastro — e-mail já cadastrado (sheet aberto)',
    source: 'features/auth/presentation/cadastro_dados_basicos.dart',
    wave: 1,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => CadastroDadosBasicosScreen(
      customPrecheckEmail: (_) async => SignupEmailEligibility.alreadyRegisteredConfirmed,
      customSignUp: ({required email, required password, required fullName}) async => AuthResponse(),
      customResendSignupOtp: (_) async {},
    ),
    interact: (tester, _) => _fillSignup(tester),
  ),
  GalleryScreen(
    id: 'auth/cadastro_verificacao_otp',
    title: 'Cadastro — código por e-mail (OTP)',
    source: 'features/auth/presentation/cadastro_verificacao_otp.dart',
    wave: 1,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => const CadastroVerificacaoOtpScreen(email: _longEmail),
  ),

  // ------------------------------------------------------------- recuperar
  GalleryScreen(
    id: 'auth/password_recovery_etapa1',
    title: 'Recuperar senha — pedir código',
    source: 'features/auth/presentation/password_recovery_screen.dart',
    wave: 1,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => PasswordRecoveryScreen(
      onSendRecoveryOtp: (_) async {},
      onVerifyAndUpdatePassword: ({required email, required code, required newPassword}) async {},
    ),
  ),
  GalleryScreen(
    id: 'auth/password_recovery_etapa2',
    title: 'Recuperar senha — código + nova senha',
    source: 'features/auth/presentation/password_recovery_screen.dart',
    wave: 1,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => PasswordRecoveryScreen(
      initialEmail: _longEmail,
      onSendRecoveryOtp: (_) async {},
      onVerifyAndUpdatePassword: ({required email, required code, required newPassword}) async {},
    ),
    interact: (tester, _) async {
      await _tapIfFound(tester, find.byKey(const Key('btn-send-recovery-code')));
    },
  ),

  // ----------------------------------------------- sheets conta existente
  GalleryScreen(
    id: 'auth/existing_account_detected_sheet',
    title: 'Sheet — conta já existe',
    source: 'features/auth/presentation/existing_account_sheets.dart',
    wave: 1,
    owner: 'auth_ui',
    kind: GalleryKind.sheet,
    modes: const <UserMode?>{_brand},
    builder: (_, _) => const ExistingAccountDetectedSheet(email: _longEmail),
  ),
  GalleryScreen(
    id: 'auth/pending_verification_detected_sheet',
    title: 'Sheet — cadastro pendente de verificação',
    source: 'features/auth/presentation/existing_account_sheets.dart',
    wave: 1,
    owner: 'auth_ui',
    kind: GalleryKind.sheet,
    modes: const <UserMode?>{_brand},
    builder: (_, _) => const PendingVerificationDetectedSheet(email: _longEmail),
  ),
  GalleryScreen(
    id: 'auth/existing_cpf_account_sheet',
    title: 'Sheet — CPF já vinculado a outra conta',
    source: 'features/auth/presentation/existing_account_sheets.dart',
    wave: 1,
    owner: 'auth_ui',
    kind: GalleryKind.sheet,
    modes: const <UserMode?>{UserMode.client},
    builder: (_, _) => const ExistingCpfAccountSheet(cpfMasked: '***.456.789-**'),
  ),

  // ----------------------------------------------------- escolha de perfil
  GalleryScreen(
    id: 'auth/role_selection_primeiro_acesso',
    title: 'Escolha de perfil — primeiro acesso',
    source: 'features/auth/presentation/role_selection_screen.dart',
    wave: 1,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => RoleSelectionScreen(profile: SampleData.firstAccessProfile()),
  ),
  GalleryScreen(
    id: 'auth/role_selection_ambos_perfis',
    title: 'Escolha de perfil — cliente + profissional ativos (nome longo)',
    source: 'features/auth/presentation/role_selection_screen.dart',
    wave: 1,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => RoleSelectionScreen(
      profile: UserProfile(
        id: SampleData.clientId,
        fullName: SampleData.longName,
        isClient: true,
        isProvider: true,
        clientSetupDone: true,
        providerSetupDone: true,
        lastMode: UserMode.client,
        verificationStatus: VerificationStatus.active,
      ),
    ),
  ),
  GalleryScreen(
    id: 'auth/role_selection_profissional_em_analise',
    title: 'Escolha de perfil — profissional em análise',
    source: 'features/auth/presentation/role_selection_screen.dart',
    wave: 1,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => RoleSelectionScreen(
      profile: UserProfile(
        id: SampleData.clientId,
        fullName: 'Ana Paula Souza',
        isClient: true,
        isProvider: true,
        clientSetupDone: true,
        providerSetupDone: true,
        verificationStatus: VerificationStatus.pending,
      ),
    ),
  ),

  // -------------------------------------------------------------- KYC
  GalleryScreen(
    id: 'auth/verificacao_step1_frente',
    title: 'KYC 1 — frente do documento',
    source: 'features/auth/presentation/verificacao_step1_frente.dart',
    wave: 2,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    note: 'sem chamador em lib/ (legado); só estado inicial (picker não injetável)',
    builder: (_, _) => const VerificacaoStep1FrenteScreen(),
  ),
  GalleryScreen(
    id: 'auth/verificacao_step2_verso',
    title: 'KYC 2 — verso do documento',
    source: 'features/auth/presentation/verificacao_step2_verso.dart',
    wave: 2,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => VerificacaoStep2VersoScreen(frenteDocumento: _foto('frente.jpg')),
  ),
  GalleryScreen(
    id: 'auth/verificacao_step3_selfie',
    title: 'KYC 3 — selfie',
    source: 'features/auth/presentation/verificacao_step3_selfie.dart',
    wave: 2,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) =>
        VerificacaoStep3SelfieScreen(frenteDocumento: _foto('frente.jpg'), versoDocumento: _foto('verso.jpg')),
  ),
  GalleryScreen(
    id: 'auth/verificacao_step4_registro_vazio',
    title: 'KYC 4 — registro profissional (vazio)',
    source: 'features/auth/presentation/verificacao_step4_registro.dart',
    wave: 2,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => VerificacaoStep4RegistroScreen(
      frenteDocumento: _foto('frente.jpg'),
      versoDocumento: _foto('verso.jpg'),
      selfie: _foto('selfie.jpg'),
    ),
  ),
  GalleryScreen(
    id: 'auth/verificacao_step4_registro_validacao',
    title: 'KYC 4 — registro profissional (erro ao continuar)',
    source: 'features/auth/presentation/verificacao_step4_registro.dart',
    wave: 2,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => VerificacaoStep4RegistroScreen(
      frenteDocumento: _foto('frente.jpg'),
      versoDocumento: _foto('verso.jpg'),
      selfie: _foto('selfie.jpg'),
    ),
    interact: (tester, _) async {
      await _tapIfFound(tester, find.byType(ElevatedButton));
    },
  ),
  GalleryScreen(
    id: 'auth/verificacao_step5_finalizacao',
    title: 'KYC 5 — revisão e envio',
    source: 'features/auth/presentation/verificacao_step5_finalizacao.dart',
    wave: 2,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => VerificacaoStep5FinalizacaoScreen(
      frenteDocumento: _foto('frente.jpg'),
      versoDocumento: _foto('verso.jpg'),
      selfie: _foto('selfie.jpg'),
      tipoRegistro: 'CREA',
      numeroRegistro: '5069841234-SP',
    ),
  ),
  GalleryScreen(
    id: 'auth/verificacao_step6a_como_funciona',
    title: 'KYC — como funciona',
    source: 'features/auth/presentation/verificacao_step6a_como_funciona.dart',
    wave: 0,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => const VerificacaoStep6aComoFuncionaScreen(),
  ),
  GalleryScreen(
    id: 'auth/verificacao_step6b_dicas',
    title: 'KYC — dicas',
    source: 'features/auth/presentation/verificacao_step6b_dicas.dart',
    wave: 0,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => const VerificacaoStep6bDicasScreen(),
  ),
  GalleryScreen(
    id: 'auth/verificacao_step6c_termos_profissional',
    title: 'Termos e mandato legal — profissional',
    source: 'features/auth/presentation/verificacao_step6c_termos.dart',
    wave: 1,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => const VerificacaoStep6cTermosScreen(initialMode: UserMode.provider),
  ),
  GalleryScreen(
    id: 'auth/verificacao_step6c_termos_cliente',
    title: 'Termos e mandato legal — cliente',
    source: 'features/auth/presentation/verificacao_step6c_termos.dart',
    wave: 1,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => const VerificacaoStep6cTermosScreen(initialMode: UserMode.client),
  ),
  GalleryScreen(
    id: 'auth/verificacao_step6_feedback',
    title: 'KYC — em análise',
    source: 'features/auth/presentation/verificacao_step6_feedback.dart',
    wave: 2,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    note: 'Timer.periodic 8 s (poll) — a galeria desmonta ao final',
    builder: (_, _) => const VerificacaoStep6FeedbackScreen(),
  ),
  GalleryScreen(
    id: 'auth/verificacao_step7_aprovado',
    title: 'KYC — aprovado',
    source: 'features/auth/presentation/verificacao_step7_aprovado.dart',
    wave: 1,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => const VerificacaoStep7AprovadoScreen(nomeProfissional: 'Maria Fernanda'),
  ),
  GalleryScreen(
    id: 'auth/verificacao_step7_aprovado_nome_longo',
    title: 'KYC — aprovado (nome muito longo)',
    source: 'features/auth/presentation/verificacao_step7_aprovado.dart',
    wave: 1,
    owner: 'auth_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) =>
        const VerificacaoStep7AprovadoScreen(nomeProfissional: 'Maria Fernanda de Albuquerque e Souza Nascimento'),
  ),

  // -------------------------------------------------------------- boot/home
  GalleryScreen(
    id: 'boot/animated_splash_screen_animando',
    title: 'Splash animada (símbolo desenhando)',
    source: 'features/boot/animated_splash_screen.dart',
    wave: 1,
    owner: 'shared_ui',
    modes: const <UserMode?>{_brand},
    animatesForever: true,
    note: 'init pendente (Completer) — nunca chama onFinished',
    builder: (_, _) => AnimatedSplashScreen(init: Completer<BootResult>().future, onFinished: (_) {}),
  ),
  GalleryScreen(
    id: 'boot/animated_splash_screen_lenta',
    title: 'Splash animada (init lento: aviso após 3,2 s)',
    source: 'features/boot/animated_splash_screen.dart',
    wave: 1,
    owner: 'shared_ui',
    modes: const <UserMode?>{_brand},
    animatesForever: true,
    builder: (_, _) => AnimatedSplashScreen(init: Completer<BootResult>().future, onFinished: (_) {}),
    interact: (tester, _) async {
      for (var i = 0; i < 35; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    },
  ),
  GalleryScreen(
    id: 'boot/update_gate_com_atualizacao',
    title: 'Aviso de nova versão (UpdateGate)',
    source: 'features/boot/update_gate.dart',
    wave: 3,
    owner: 'shared_ui',
    modes: const <UserMode?>{_brand},
    note: 'UpdateGate com check fake; Timers desmontados ao final',
    builder: (_, _) => UpdateGate(
      initialDelay: const Duration(milliseconds: 50),
      interval: const Duration(hours: 1),
      check: () async => const UpdateInfo(
        build: 5,
        version: '2.28.0',
        apkUrl: 'https://exemplo.invalid/desperrengue.apk',
        sizeBytes: 64471667,
        notes:
            'Novo design system, navegação mais fluida, correções de pagamento e notificações '
            'mais claras para clientes e profissionais.',
      ),
      openUrl: (_) async {},
      child: const Scaffold(body: Center(child: Text('Conteúdo do app'))),
    ),
    interact: (tester, _) async {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
    },
  ),
  GalleryScreen(
    id: 'home/home_admin_screen',
    title: 'Painel do administrador (placeholder)',
    source: 'features/home/presentation/home_screens.dart',
    wave: 0,
    owner: 'shared_ui',
    modes: const <UserMode?>{_brand},
    builder: (_, _) => const HomeAdminScreen(),
  ),
];

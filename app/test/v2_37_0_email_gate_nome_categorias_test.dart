import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/profile_service.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/utils/format.dart';
import 'package:desperrengue_app/core/utils/person_name_formatter.dart';
import 'package:desperrengue_app/features/auth/presentation/account_activated_welcome_screen.dart';
import 'package:desperrengue_app/features/auth/presentation/verify_approval_email_screen.dart';

Widget _host(
  Widget child, {
  Brightness brightness = Brightness.light,
  Size size = const Size(320, 640),
  double textScale = 1.5,
  bool disableAnimations = false,
}) =>
    MaterialApp(
      theme: AppTheme.onboarding(brightness),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: child,
      ),
    );

void _viewport(WidgetTester t, Size size) {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

const UserProfile _pendingClient = UserProfile(
  id: 'u-v237-client',
  fullName: 'WAGNEROLIVEIRA',
  isClient: true,
  clientSetupDone: true,
  clientKycStatus: 'APPROVED',
  approvalEmailConfirmed: false,
);

void main() {
  group('v2.37.0 — Nome humano (sem "WAGNEROLIVEIRA" colado)', () {
    test('separa nomes colados e corrige a caixa', () {
      expect(PersonNameFormatter.humanize('WAGNEROLIVEIRA'), 'Wagner Oliveira');
      expect(PersonNameFormatter.humanize('wagneroliveira'), 'Wagner Oliveira');
      expect(PersonNameFormatter.humanize('WagnerOliveira'), 'Wagner Oliveira');
      expect(PersonNameFormatter.humanize('WAGNEROLIVEIRACLAUDIANO'),
          'Wagner Oliveira Claudiano');
      expect(PersonNameFormatter.humanize('MARIASILVA'), 'Maria Silva');
    });

    test('nome do documento em MAIÚSCULAS vira Título, com conectivos em minúsculas', () {
      expect(PersonNameFormatter.humanize('WAGNER OLIVEIRA CLAUDIANO'),
          'Wagner Oliveira Claudiano');
      expect(PersonNameFormatter.humanize('MARIA DA SILVA E SOUZA'),
          'Maria da Silva e Souza');
      expect(PersonNameFormatter.humanize('JOÃO DOS SANTOS'), 'João dos Santos');
      expect(PersonNameFormatter.humanize('ANA-CLARA D\'ÁVILA'), 'Ana-Clara D\'Ávila');
    });

    test('preserva nomes bem escritos e nomes curtos legítimos', () {
      expect(PersonNameFormatter.humanize('Wagner Oliveira'), 'Wagner Oliveira');
      expect(PersonNameFormatter.humanize('Maria da Silva'), 'Maria da Silva');
      expect(PersonNameFormatter.humanize('McDonald'), 'McDonald');
      expect(PersonNameFormatter.humanize('Marina'), 'Marina');
      expect(PersonNameFormatter.humanize('Joana Lima'), 'Joana Lima');
      expect(PersonNameFormatter.humanize('   '), '');
    });

    test('primeiro nome e e-mail', () {
      expect(PersonNameFormatter.firstName('WAGNEROLIVEIRA'), 'Wagner');
      expect(PersonNameFormatter.firstName('JOSÉ DA SILVA'), 'José');
      expect(PersonNameFormatter.fromEmail('wagneroliveira9819@gmail.com'),
          'Wagner Oliveira');
      expect(PersonNameFormatter.fromEmail('maria.souza@x.com'), 'Maria Souza');
      expect(PersonNameFormatter.fromEmail('sem-arroba'), isNull);
    });

    test('UserProfile e firstName() usam o nome humano em toda a interface', () {
      final colado = UserProfile.fromMap(<String, dynamic>{
        'id': 'u1',
        'full_name': 'WAGNEROLIVEIRA',
      });
      expect(colado.displayName, 'Wagner Oliveira');
      expect(colado.firstName, 'Wagner');

      final verificado = UserProfile.fromMap(<String, dynamic>{
        'id': 'u2',
        'full_name': 'wagner',
        'verified_full_name': 'WAGNER OLIVEIRA CLAUDIANO',
      });
      expect(verificado.displayName, 'Wagner Oliveira Claudiano');
      expect(verificado.firstName, 'Wagner');
      // O nome civil oficial (termos/documentos) continua exatamente como no documento.
      expect(verificado.officialCivilName, 'WAGNER OLIVEIRA CLAUDIANO');

      final email = UserProfile.fromMap(<String, dynamic>{
        'id': 'u3',
        'full_name': 'wagneroliveira9819@gmail.com',
      });
      expect(email.firstName, 'Wagner');

      expect(firstName('CARLOS EDUARDO PEREIRA'), 'Carlos');
    });
  });

  group('v2.37.0 — Portão de ativação: nenhuma tela do app antes do e-mail', () {
    test('conta aprovada aguardando o e-mail vai SEMPRE para a verificação', () {
      expect(_pendingClient.requiresApprovalEmailGate, isTrue);
      for (final mode in <UserMode?>[null, UserMode.client, UserMode.provider]) {
        expect(
          destinationFor(_pendingClient, mode: mode),
          AppDestination.approvalEmailVerification,
          reason: 'mode=$mode',
        );
      }
      expect(
        destinationFor(_pendingClient, forceSelection: true),
        AppDestination.approvalEmailVerification,
      );

      const pendingProvider = UserProfile(
        id: 'u-v237-prov',
        fullName: 'Carlos Silva',
        isProvider: true,
        verificationStatus: VerificationStatus.active,
        approvalEmailConfirmed: false,
      );
      for (final mode in <UserMode?>[null, UserMode.client, UserMode.provider]) {
        expect(
          destinationFor(pendingProvider, mode: mode),
          AppDestination.approvalEmailVerification,
        );
      }
    });

    test('depois de confirmar pelo e-mail a conta segue o fluxo normal', () {
      const confirmed = UserProfile(
        id: 'u-v237-ok',
        fullName: 'Ana Paula',
        isClient: true,
        clientSetupDone: true,
        clientKycStatus: 'APPROVED',
        approvalEmailConfirmed: true,
      );
      expect(confirmed.requiresApprovalEmailGate, isFalse);
      expect(destinationFor(confirmed, mode: UserMode.client), AppDestination.clientHome);
    });

    test('perfis legados (sem a coluna) e o administrador nunca ficam presos', () {
      final legacy = UserProfile.fromMap(<String, dynamic>{
        'id': 'old',
        'full_name': 'Antigo',
        'is_client': true,
        'client_setup_done': true,
      });
      expect(legacy.approvalEmailConfirmed, isTrue);
      expect(legacy.requiresApprovalEmailGate, isFalse);

      const admin = UserProfile(
        id: 'adm',
        fullName: 'Admin',
        isAdmin: true,
        isClient: true,
        approvalEmailConfirmed: false,
      );
      expect(destinationFor(admin), AppDestination.adminHome);
    });

    test('ProfileService não expõe mais nenhum método que confirme a conta pelo app', () {
      // A confirmação só existe no servidor (token do e-mail). O app só consulta.
      expect(ApprovalEmailSendOutcome.values, contains(ApprovalEmailSendOutcome.cooldown));
      expect(ProfileService.new, isNotNull);
    });
  });

  group('v2.37.0 — Tela "Verifique seu e-mail" (sem atalho para entrar)', () {
    testWidgets('não tem botão que libera a conta; verificar sem confirmação mantém bloqueado', (tester) async {
      _viewport(tester, const Size(360, 780));
      var opened = 0;
      var checks = 0;
      await tester.pumpWidget(_host(
        VerifyApprovalEmailScreen(
          profile: _pendingClient,
          mode: UserMode.client,
          emailAddressOverride: 'wagner@exemplo.com.br',
          pollInterval: null,
          customGateCheck: () async {
            checks++;
            return false;
          },
          onGateOpened: () => opened++,
        ),
        size: const Size(360, 780),
        textScale: 1.0,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Verifique seu e-mail'), findsOneWidget);
      expect(find.byKey(const ValueKey('btn-confirm-approval-email')), findsNothing);
      expect(find.textContaining('Já validei meu e-mail'), findsNothing);
      expect(find.textContaining('Confirmar e Ativar Minha Conta'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('btn-check-approval-email')));
      await tester.pumpAndSettle();
      expect(checks, 1);
      expect(opened, 0, reason: 'o app não pode liberar a conta sem a confirmação do servidor');
      expect(find.byKey(const ValueKey('verify-email-info')), findsOneWidget);
      expect(find.textContaining('Ainda não identificamos a confirmação'), findsOneWidget);
    });

    testWidgets('libera SOMENTE quando o servidor confirma (botão e verificação automática)', (tester) async {
      _viewport(tester, const Size(360, 780));
      var confirmedOnServer = false;
      var opened = 0;
      await tester.pumpWidget(_host(
        VerifyApprovalEmailScreen(
          profile: _pendingClient,
          mode: UserMode.client,
          pollInterval: const Duration(milliseconds: 200),
          customGateCheck: () async => confirmedOnServer,
          onGateOpened: () => opened++,
        ),
        size: const Size(360, 780),
        textScale: 1.0,
      ));
      await tester.pump(const Duration(milliseconds: 650));
      expect(opened, 0);

      confirmedOnServer = true; // usuário tocou no botão do e-mail
      await tester.pump(const Duration(milliseconds: 450));
      expect(opened, 1, reason: 'a verificação automática detecta a confirmação');

      await tester.pump(const Duration(milliseconds: 800));
      expect(opened, 1, reason: 'abre uma única vez');
    });

    testWidgets('reenvio: sucesso, "acabamos de enviar" (cooldown do servidor) e falha', (tester) async {
      _viewport(tester, const Size(360, 780));
      var outcome = ApprovalEmailSendOutcome.cooldown;
      var calls = 0;
      await tester.pumpWidget(_host(
        VerifyApprovalEmailScreen(
          profile: _pendingClient,
          mode: UserMode.client,
          pollInterval: null,
          customGateCheck: () async => false,
          customResendAction: () async {
            calls++;
            return outcome;
          },
        ),
        size: const Size(360, 780),
        textScale: 1.0,
      ));
      await tester.pumpAndSettle();

      final resend = find.byKey(const ValueKey('btn-resend-approval-email'));
      await tester.ensureVisible(resend);
      await tester.tap(resend);
      await tester.pump();
      await tester.pump();
      expect(calls, 1);
      expect(find.textContaining('Acabamos de enviar o e-mail'), findsOneWidget);
      expect(find.textContaining('Reenviar e-mail em'), findsOneWidget);

      // desmonta para cancelar o timer do cooldown
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final brightness in Brightness.values) {
      testWidgets('sem overflow em 320x640 @ 1.5x (${brightness.name})', (tester) async {
        _viewport(tester, const Size(320, 640));
        await tester.pumpWidget(_host(
          VerifyApprovalEmailScreen(
            profile: _pendingClient,
            mode: UserMode.provider,
            emailAddressOverride: 'um-endereco-de-email-bem-longo.para-teste@exemplo.com.br',
            pollInterval: null,
            customGateCheck: () async => false,
          ),
          brightness: brightness,
          disableAnimations: true,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('btn-check-approval-email')), findsOneWidget);
      });
    }
  });

  group('v2.37.0 — Tela de boas-vindas pós-ativação', () {
    testWidgets('coreografia completa: título, benefícios e CTA que entra no app', (tester) async {
      _viewport(tester, const Size(390, 844));
      var continued = 0;
      await tester.pumpWidget(_host(
        AccountActivatedWelcomeScreen(
          profile: _pendingClient,
          mode: UserMode.client,
          onContinue: () => continued++,
        ),
        size: const Size(390, 844),
        textScale: 1.0,
      ));

      // t=0: o selo ainda está se desenhando; o texto ainda não apareceu.
      expect(find.byKey(const ValueKey('activation-emblem')), findsOneWidget);
      final early = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(const ValueKey('activation-greeting')),
          matching: find.byType(Opacity),
        ).first,
      );
      expect(early.opacity, 0.0);

      // CTA ainda bloqueado (invisível) no início
      await tester.tap(find.byKey(const ValueKey('btn-activation-welcome-continue')), warnIfMissed: false);
      await tester.pump();
      expect(continued, 0);

      await tester.pump(const Duration(milliseconds: 4200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('Boas-vindas, Wagner!'), findsOneWidget);
      expect(find.text('Conta ativada'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(ValueKey('activation-benefit-$i')), findsOneWidget);
      }
      expect(find.text('Garantia de 90 dias'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('btn-activation-welcome-continue')));
      await tester.pump();
      expect(continued, 1);
    });

    testWidgets('profissional: copy própria e CTA "Configurar meu perfil"', (tester) async {
      _viewport(tester, const Size(390, 844));
      const provider = UserProfile(
        id: 'u-prov',
        fullName: 'CARLOS EDUARDO',
        isProvider: true,
        verificationStatus: VerificationStatus.active,
      );
      await tester.pumpWidget(_host(
        AccountActivatedWelcomeScreen(
          profile: provider,
          mode: UserMode.provider,
          onContinue: () {},
        ),
        size: const Size(390, 844),
        textScale: 1.0,
        disableAnimations: true,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Boas-vindas, Carlos!'), findsOneWidget);
      expect(find.text('Configurar meu perfil'), findsOneWidget);
      expect(find.text('Repasse seguro'), findsOneWidget);
    });

    testWidgets('movimento reduzido: estado final imediato, CTA já utilizável', (tester) async {
      _viewport(tester, const Size(390, 844));
      var continued = 0;
      await tester.pumpWidget(_host(
        AccountActivatedWelcomeScreen(
          profile: _pendingClient,
          mode: UserMode.client,
          onContinue: () => continued++,
        ),
        size: const Size(390, 844),
        textScale: 1.0,
        disableAnimations: true,
      ));
      await tester.pump();
      expect(find.text('Boas-vindas, Wagner!'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('btn-activation-welcome-continue')));
      await tester.pump();
      expect(continued, 1);
    });

    final viewports = <(Size, double, Brightness)>[
      (const Size(320, 640), 1.5, Brightness.light),
      (const Size(320, 568), 1.5, Brightness.dark),
      (const Size(412, 915), 1.0, Brightness.dark),
      (const Size(1280, 800), 1.0, Brightness.light),
    ];
    for (final (size, scale, brightness) in viewports) {
      testWidgets('sem overflow em ${size.width.toInt()}x${size.height.toInt()} @ ${scale}x ${brightness.name}', (tester) async {
        _viewport(tester, size);
        await tester.pumpWidget(_host(
          AccountActivatedWelcomeScreen(
            profile: _pendingClient,
            mode: UserMode.client,
            onContinue: () {},
          ),
          size: size,
          textScale: scale,
          brightness: brightness,
        ));
        // percorre a animação inteira em vários instantes: nenhum overflow em nenhum frame
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 420));
          expect(tester.takeException(), isNull);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}

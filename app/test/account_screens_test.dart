import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:desperrengue_app/core/models/account_models.dart';
import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/features/provider/presentation/pix_withdraw_screen.dart';
import 'package:desperrengue_app/features/shared/presentation/delete_account_screen.dart';

/// Telas de saque Pix e exclusão de conta: validações locais e a trava de UX.
/// (A regra financeira em si é do servidor: coberta por `offboarding_showcase_smoke.sql`
/// e pelo teste E2E da Edge Function.) Nada aqui chega à rede.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: 'https://teste.supabase.co',
      publishableKey: 'chave-de-teste',
      authOptions: FlutterAuthClientOptions(localStorage: const EmptyLocalStorage(), autoRefreshToken: false),
    );
  });

  Widget host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
        theme: AppTheme.resolve(null, b),
        home: child,
      );

  group('PixWithdrawScreen', () {
    Future<void> open(WidgetTester t, {double available = 150.5}) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      await t.pumpWidget(host(PixWithdrawScreen(available: available)));
      await t.pump();
    }

    testWidgets('mostra o saldo e sugere sacar tudo', (t) async {
      await open(t);
      expect(find.text('R\$ 150,50'), findsOneWidget);
      expect(find.text('150,50'), findsOneWidget, reason: 'campo preenchido com o saldo');
      expect(find.text('Transferir via Pix'), findsNWidgets(2), reason: 'título + botão');
    });

    testWidgets('chave inválida é recusada antes de chamar o servidor', (t) async {
      await open(t);
      await t.enterText(find.widgetWithText(TextField, 'Chave Pix (CPF)'), '123.456.789-00');
      await t.tap(find.byType(CheckboxListTile));
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Transferir via Pix'));
      await t.pump();
      expect(find.textContaining('Chave Pix inválida'), findsOneWidget);
    });

    testWidgets('exige a declaração de titularidade', (t) async {
      await open(t);
      await t.enterText(find.widgetWithText(TextField, 'Chave Pix (CPF)'), '529.982.247-25');
      await t.tap(find.widgetWithText(FilledButton, 'Transferir via Pix'));
      await t.pump();
      expect(find.textContaining('titularidade'), findsWidgets);
      expect(find.text('Confirme que a chave Pix é de sua titularidade.'), findsOneWidget);
    });

    testWidgets('valor acima do saldo é recusado', (t) async {
      await open(t, available: 50);
      await t.enterText(find.widgetWithText(TextField, 'Valor (R\$)'), '80,00');
      await t.enterText(find.widgetWithText(TextField, 'Chave Pix (CPF)'), '529.982.247-25');
      await t.tap(find.byType(CheckboxListTile));
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Transferir via Pix'));
      await t.pump();
      expect(find.text('O valor é maior que o seu saldo disponível.'), findsOneWidget);
    });

    testWidgets('troca o rótulo do campo ao mudar o tipo de chave', (t) async {
      await open(t);
      await t.tap(find.text('E-mail'));
      await t.pump();
      expect(find.widgetWithText(TextField, 'Chave Pix (E-mail)'), findsOneWidget);
    });

    testWidgets('renderiza no tema escuro', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      await t.pumpWidget(host(const PixWithdrawScreen(available: 10), b: Brightness.dark));
      await t.pump();
      expect(t.takeException(), isNull);
    });
  });

  group('DeleteAccountScreen', () {
    testWidgets('o botão só habilita depois de digitar EXCLUIR (case-insensitive)', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      await t.pumpWidget(host(const DeleteAccountScreen()));
      await t.pump();

      FilledButton button() => t.widget<FilledButton>(find.byType(FilledButton));
      expect(button().onPressed, isNull);

      await t.enterText(find.byType(TextField), 'excluir');
      await t.pump();
      expect(button().onPressed, isNotNull);

      await t.enterText(find.byType(TextField), 'excluir ');
      await t.pump();
      expect(button().onPressed, isNotNull, reason: 'espaços nas pontas são ignorados');

      await t.enterText(find.byType(TextField), 'exclui');
      await t.pump();
      expect(button().onPressed, isNull);
    });

    testWidgets('explica o que acontece (dossiê e retenção legal); quem tem um perfil só não vê escolha', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      await t.pumpWidget(host(const DeleteAccountScreen(), b: Brightness.dark));
      await t.pump();
      expect(find.textContaining('Dossiê de Despedida'), findsOneWidget);
      expect(find.textContaining('registros financeiros exigidos por lei'), findsOneWidget);
      expect(find.text('Esta ação é permanente e não pode ser desfeita.'), findsOneWidget);
      expect(find.byKey(const Key('scope-all')), findsNothing);
      expect(find.text('Excluir minha conta'), findsOneWidget);
    });
  });

  group('DeleteAccountScreen — escopo (Cliente / Profissional / as duas)', () {
    const both = UserProfile(id: 'u', fullName: 'Ana', isClient: true, isProvider: true, clientSetupDone: true, providerSetupDone: true);
    const onlyClient = UserProfile(id: 'u', fullName: 'Ana', isClient: true, clientSetupDone: true);

    Future<
        ({
          List<DeletionScope> statusCalls,
          List<DeletionScope> deleteCalls,
          List<(DeletionResult, UserMode)> after,
        })> open(
      WidgetTester t, {
      required UserProfile? p,
      bool asProvider = false,
      DeletionStatus? status,
      DeletionResult? result,
      Brightness b = Brightness.light,
    }) async {
      t.view.physicalSize = const Size(1080, 8000);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      final statusCalls = <DeletionScope>[];
      final deleteCalls = <DeletionScope>[];
      final after = <(DeletionResult, UserMode)>[];
      await t.pumpWidget(host(
        DeleteAccountScreen(
          asProvider: asProvider,
          email: 'ana@exemplo.com',
          profileLoader: () async => p,
          statusLoader: (s) async {
            statusCalls.add(s);
            return status ?? const DeletionStatus(available: 0, held: 0, activeJobs: 0, blockers: []);
          },
          deleter: (s) async {
            deleteCalls.add(s);
            return result ?? DeletionResult(scope: s, accountRemoved: s == DeletionScope.all);
          },
          afterDeletion: (_, r, from) async => after.add((r, from)),
        ),
        b: b,
      ));
      await t.pump();
      await t.pump();
      return (statusCalls: statusCalls, deleteCalls: deleteCalls, after: after);
    }

    Future<void> confirmAndTap(WidgetTester t, String button) async {
      await t.enterText(find.byType(TextField), 'EXCLUIR');
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, button));
      await t.pump();
      await t.pump();
      await t.pump();
    }

    testWidgets('dois perfis: mostra as duas opções, padrão = só a conta atual (Cliente)', (t) async {
      await open(t, p: both);
      expect(find.text('O que você quer excluir?'), findsOneWidget);
      expect(find.text('Só minha conta de Cliente'), findsOneWidget);
      expect(find.text('As duas contas (Cliente e Profissional)'), findsOneWidget);
      expect(find.text('Excluir conta de Cliente'), findsOneWidget);
      expect(find.textContaining('só da conta de Cliente'), findsOneWidget);
      expect(find.textContaining('permanece intacta'), findsOneWidget);
    });

    testWidgets('no painel do Profissional o padrão é a conta de Profissional', (t) async {
      await open(t, p: both, asProvider: true);
      expect(find.text('Só minha conta de Profissional'), findsOneWidget);
      expect(find.text('Excluir conta de Profissional'), findsOneWidget);
    });

    testWidgets('escolher "as duas" troca texto do botão e do PDF', (t) async {
      await open(t, p: both);
      await t.tap(find.byKey(const Key('scope-all')));
      await t.pump();
      expect(find.text('Excluir as duas contas'), findsOneWidget);
      expect(find.textContaining('DUAS contas excluídas'), findsOneWidget);
      expect(find.textContaining('permanece intacta'), findsNothing);
    });

    testWidgets('só a conta atual: consulta e exclui com scope=client (não toca no outro perfil)', (t) async {
      final r = await open(t, p: both);
      await confirmAndTap(t, 'Excluir conta de Cliente');
      expect(r.statusCalls, [DeletionScope.client]);
      expect(r.deleteCalls, [DeletionScope.client]);
      expect(r.after.single.$1.accountRemoved, isFalse);
      expect(r.after.single.$2, UserMode.client);
    });

    testWidgets('profissional exclui só a sua: scope=provider', (t) async {
      final r = await open(t, p: both, asProvider: true);
      await confirmAndTap(t, 'Excluir conta de Profissional');
      expect(r.deleteCalls, [DeletionScope.provider]);
    });

    testWidgets('as duas contas: scope=all e a conta inteira sai', (t) async {
      final r = await open(t, p: both);
      await t.tap(find.byKey(const Key('scope-all')));
      await t.pump();
      await confirmAndTap(t, 'Excluir as duas contas');
      expect(r.statusCalls, [DeletionScope.all]);
      expect(r.deleteCalls, [DeletionScope.all]);
      expect(r.after.single.$1.accountRemoved, isTrue);
    });

    testWidgets('quem só tem Cliente: sem escolha e scope=all (sempre válido no servidor)', (t) async {
      final r = await open(t, p: onlyClient);
      expect(find.byKey(const Key('scope-current')), findsNothing);
      await confirmAndTap(t, 'Excluir minha conta');
      expect(r.deleteCalls, [DeletionScope.all]);
    });

    testWidgets('saldo no escopo escolhido bloqueia e oferece o Pix (nada é excluído)', (t) async {
      final r = await open(t, p: both, status: const DeletionStatus(available: 80, held: 0, activeJobs: 0, blockers: ['balance']));
      await confirmAndTap(t, 'Excluir conta de Cliente');
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Transferir via Pix'), findsOneWidget);
      expect(r.deleteCalls, isEmpty);
    });

    testWidgets('serviço em andamento bloqueia com a mensagem do escopo (Profissional)', (t) async {
      final r = await open(t, p: both, asProvider: true, status: const DeletionStatus(available: 0, held: 50, activeJobs: 1, blockers: ['escrow', 'active_jobs']));
      await confirmAndTap(t, 'Excluir conta de Profissional');
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Ainda há pendências'), findsOneWidget);
      expect(find.textContaining('a conta de Profissional'), findsWidgets);
      expect(r.deleteCalls, isEmpty);
    });

    testWidgets('layout no tema escuro sem estouro', (t) async {
      await open(t, p: both, b: Brightness.dark);
      expect(t.takeException(), isNull);
    });

    test('DeletionScope / DeletionResult (contrato com a Edge Function)', () {
      expect(DeletionScope.parse('client'), DeletionScope.client);
      expect(DeletionScope.parse('provider').wire, 'provider');
      expect(DeletionScope.parse('lixo'), DeletionScope.all);
      final parcial = DeletionResult.fromMap({'deleted': true, 'scope': 'client', 'account_removed': false});
      expect(parcial.scope, DeletionScope.client);
      expect(parcial.accountRemoved, isFalse);
      final total = DeletionResult.fromMap({'deleted': true, 'scope': 'all', 'account_removed': true});
      expect(total.accountRemoved, isTrue);
      // Resposta sem corpo: assume o escopo pedido; só "all" remove a conta.
      expect(DeletionResult.fromMap(const {}, fallback: DeletionScope.provider).accountRemoved, isFalse);
      expect(DeletionResult.fromMap(const {}, fallback: DeletionScope.all).accountRemoved, isTrue);
    });
  });
}

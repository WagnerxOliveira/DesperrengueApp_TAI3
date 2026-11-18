import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/welcome_cinema_tracker.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/features/auth/presentation/cadastro_sucesso_routing.dart';
import 'package:desperrengue_app/features/auth/presentation/desperrengue_welcome_cinema_screen.dart';
import 'package:desperrengue_app/features/auth/presentation/role_selection_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

UserProfile _makeProfile({
  String id = 'user-ana-01',
  String fullName = 'Ana Oliveira',
  bool isClient = false,
  bool isProvider = false,
  bool isAdmin = false,
  bool clientSetupDone = false,
  bool providerSetupDone = false,
}) {
  return UserProfile(
    id: id,
    fullName: fullName,
    isClient: isClient,
    isProvider: isProvider,
    isAdmin: isAdmin,
    clientSetupDone: clientSetupDone,
    providerSetupDone: providerSetupDone,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    WelcomeCinemaTracker.resetMemoryStateForTesting();
  });

  group('WelcomeCinemaTracker — Governança de Exibição Pós-Cadastro', () {
    test(
      'dispara true para conta recém-criada armada via OTP e para 1º login OAuth recente',
      () async {
        final freshOtpUser = _makeProfile(id: 'uid-otp-1');
        await WelcomeCinemaTracker.armForFreshRegistration('uid-otp-1');

        final showForOtp =
            await WelcomeCinemaTracker.shouldShowBeforeRoleSelection(
              profile: freshOtpUser,
            );
        expect(showForOtp, isTrue);

        WelcomeCinemaTracker.resetMemoryStateForTesting();
        SharedPreferences.setMockInitialValues(<String, Object>{});

        final now = DateTime.utc(2026, 11, 18, 18, 0, 0);
        final oauthUser = _makeProfile(id: 'uid-oauth-1');
        final showForOAuth =
            await WelcomeCinemaTracker.shouldShowBeforeRoleSelection(
              profile: oauthUser,
              authCreatedAt: now.subtract(const Duration(minutes: 2)),
              referenceNow: now,
            );
        expect(showForOAuth, isTrue);
      },
    );

    test(
      'após markCompleted(uid), nunca repete para o mesmo uid, mas dispara para outro usuário novo (uid2)',
      () async {
        final now = DateTime.utc(2026, 11, 18, 18, 0, 0);
        final user1 = _makeProfile(id: 'uid-1', fullName: 'Ana');
        final user2 = _makeProfile(id: 'uid-2', fullName: 'Bruno');

        await WelcomeCinemaTracker.armForFreshRegistration('uid-1');
        expect(
          await WelcomeCinemaTracker.shouldShowBeforeRoleSelection(
            profile: user1,
            authCreatedAt: now.subtract(const Duration(minutes: 1)),
            referenceNow: now,
          ),
          isTrue,
        );

        await WelcomeCinemaTracker.markCompleted('uid-1');

        expect(
          await WelcomeCinemaTracker.shouldShowBeforeRoleSelection(
            profile: user1,
            authCreatedAt: now.subtract(const Duration(minutes: 1)),
            referenceNow: now,
          ),
          isFalse,
        );

        await WelcomeCinemaTracker.armForFreshRegistration('uid-2');
        expect(
          await WelcomeCinemaTracker.shouldShowBeforeRoleSelection(
            profile: user2,
            authCreatedAt: now,
            referenceNow: now,
          ),
          isTrue,
        );
      },
    );

    test(
      'retorna false para quem já tem perfil (isClient, isProvider, isAdmin), em forceSelection: true ou conta antiga sem arm',
      () async {
        final now = DateTime.utc(2026, 11, 18, 18, 0, 0);
        await WelcomeCinemaTracker.armForFreshRegistration();

        expect(
          await WelcomeCinemaTracker.shouldShowBeforeRoleSelection(
            profile: _makeProfile(id: 'u-client', isClient: true),
            authCreatedAt: now,
            referenceNow: now,
          ),
          isFalse,
        );

        expect(
          await WelcomeCinemaTracker.shouldShowBeforeRoleSelection(
            profile: _makeProfile(id: 'u-provider', isProvider: true),
            authCreatedAt: now,
            referenceNow: now,
          ),
          isFalse,
        );

        expect(
          await WelcomeCinemaTracker.shouldShowBeforeRoleSelection(
            profile: _makeProfile(id: 'u-admin', isAdmin: true),
            authCreatedAt: now,
            referenceNow: now,
          ),
          isFalse,
        );

        expect(
          await WelcomeCinemaTracker.shouldShowBeforeRoleSelection(
            profile: _makeProfile(id: 'u-force'),
            authCreatedAt: now,
            forceSelection: true,
            referenceNow: now,
          ),
          isFalse,
        );

        WelcomeCinemaTracker.resetMemoryStateForTesting();
        SharedPreferences.setMockInitialValues(<String, Object>{});

        expect(
          await WelcomeCinemaTracker.shouldShowBeforeRoleSelection(
            profile: _makeProfile(id: 'u-legacy'),
            authCreatedAt: now.subtract(const Duration(hours: 3)),
            referenceNow: now,
          ),
          isFalse,
        );
      },
    );

    test(
      'isLikelyFreshAuthInMemory protege contra flash claro no PostAuthRouter em signup OTP e OAuth recente',
      () async {
        final now = DateTime.utc(2026, 11, 18, 18, 0, 0);
        expect(WelcomeCinemaTracker.isLikelyFreshAuthInMemory(), isFalse);

        await WelcomeCinemaTracker.armForFreshRegistration('uid-fresh-otp');
        expect(
          WelcomeCinemaTracker.isLikelyFreshAuthInMemory(
            userId: 'uid-fresh-otp',
          ),
          isTrue,
        );

        await WelcomeCinemaTracker.markCompleted('uid-fresh-otp');
        expect(
          WelcomeCinemaTracker.isLikelyFreshAuthInMemory(
            userId: 'uid-fresh-otp',
            authCreatedAt: now.subtract(const Duration(minutes: 1)),
            referenceNow: now,
          ),
          isFalse,
        );

        WelcomeCinemaTracker.resetMemoryStateForTesting();
        expect(
          WelcomeCinemaTracker.isLikelyFreshAuthInMemory(
            userId: 'uid-fresh-oauth',
            authCreatedAt: now.subtract(const Duration(minutes: 4)),
            referenceNow: now,
          ),
          isTrue,
        );
        expect(
          WelcomeCinemaTracker.isLikelyFreshAuthInMemory(
            userId: 'uid-old-oauth',
            authCreatedAt: now.subtract(const Duration(hours: 2)),
            referenceNow: now,
          ),
          isFalse,
        );
      },
    );

    testWidgets(
      'CadastroSucessoRoutingScreen em ThemeMode.light mantém fundo Azul-Noite (#0F172A), selo esmeralda e arma WelcomeCinemaTracker',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.resolve(null, Brightness.light),
            themeMode: ThemeMode.light,
            home: const CadastroSucessoRoutingScreen(),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('cadastro-sucesso-emerald-seal')),
          findsOneWidget,
        );
        expect(find.text('Cadastro confirmado!'), findsOneWidget);

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor, const Color(0xFF0F172A));
        expect(WelcomeCinemaTracker.isLikelyFreshAuthInMemory(), isTrue);

        // Desmonta antes do timer de 450ms disparar navegação para AuthGate
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });

  group('DesperrengueWelcomeCinemaScreen — Coreografia Contínua de 4 Atos', () {
    testWidgets(
      'progride ininterruptamente pelos 4 Atos e dispara onCompleted exatamente ao final',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);

        var completedCount = 0;
        const duration = Duration(milliseconds: 4000);

        await tester.pumpWidget(
          MaterialApp(
            home: DesperrengueWelcomeCinemaScreen(
              userFirstName: 'Ana',
              totalDuration: duration,
              onCompleted: () => completedCount++,
            ),
          ),
        );
        await tester.pump();

        // Ato I (0.00 - 0.25): O que o Desperrengue faz
        expect(find.byKey(const Key('cinema-act-1-mission')), findsOneWidget);
        expect(
          find.byKey(const Key('welcome-cinema-progress-bar')),
          findsOneWidget,
        );
        expect(completedCount, 0);

        // Avança para o Ato II (0.25 - 0.50): Para quem é a plataforma
        await tester.pump(const Duration(milliseconds: 1300));
        expect(find.byKey(const Key('cinema-act-2-audience')), findsOneWidget);
        expect(completedCount, 0);

        // Avança para o Ato III (0.50 - 0.75): Lado do Cliente
        await tester.pump(const Duration(milliseconds: 1000));
        expect(find.byKey(const Key('cinema-act-3-client')), findsOneWidget);
        expect(completedCount, 0);

        // Avança para o Ato IV (0.75 - 1.00): Lado do Profissional
        await tester.pump(const Duration(milliseconds: 1000));
        expect(find.byKey(const Key('cinema-act-4-provider')), findsOneWidget);
        expect(completedCount, 0);

        // Conclui 100% da linha do tempo e dispara onCompleted automaticamente
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pump();
        expect(completedCount, 1);
      },
    );

    testWidgets(
      'modo pós-cadastro (isReplay: false) bloqueia saída via PopScope e oculta botão fechar; isReplay: true permite fechar',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);

        var completed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: DesperrengueWelcomeCinemaScreen(
              userFirstName: 'Ana',
              isReplay: false,
              onCompleted: () => completed = true,
            ),
          ),
        );
        await tester.pump();

        final popScope = tester.widget<PopScope>(find.byType(PopScope).first);
        expect(popScope.canPop, isFalse);
        expect(
          find.byKey(const Key('btn-close-replay-cinema')),
          findsNothing,
        );
        expect(completed, isFalse);

        // Agora em modo Replay (isReplay: true)
        var replayClosed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: DesperrengueWelcomeCinemaScreen(
              userFirstName: 'Ana',
              isReplay: true,
              onCompleted: () => replayClosed = true,
            ),
          ),
        );
        await tester.pump();

        final closeFinder = find.byKey(const Key('btn-close-replay-cinema'));
        expect(closeFinder, findsOneWidget);
        await tester.tap(closeFinder);
        await tester.pump();
        expect(replayClosed, isTrue);
      },
    );

    testWidgets(
      'segurar o dedo (longPress) exibe cinema-paused-badge, pausa a linha do tempo e retoma ao soltar',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);

        var completed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: DesperrengueWelcomeCinemaScreen(
              userFirstName: 'Ana',
              totalDuration: const Duration(milliseconds: 4000),
              onCompleted: () => completed = true,
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(const Key('cinema-paused-badge')), findsNothing);

        final center = tester.getCenter(
          find.byType(DesperrengueWelcomeCinemaScreen),
        );
        final gesture = await tester.startGesture(center);
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));

        expect(find.byKey(const Key('cinema-paused-badge')), findsOneWidget);

        // Mesmo esperando 5 segundos com o dedo pressionado, não avança para o fim
        await tester.pump(const Duration(seconds: 5));
        expect(completed, isFalse);
        expect(find.byKey(const Key('cinema-act-1-mission')), findsOneWidget);

        // Ao soltar o dedo, remove o selo de pausa e retoma a animação até concluir
        await gesture.up();
        await tester.pump();
        expect(find.byKey(const Key('cinema-paused-badge')), findsNothing);

        await tester.pump(const Duration(milliseconds: 4200));
        await tester.pump();
        expect(completed, isTrue);
      },
    );

    testWidgets(
      'transição contínua DesperrengueWelcomeCinemaScreen -> RoleSelectionScreen + botão btn-replay-welcome-cinema',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);

        final anaProfile = _makeProfile(id: 'ana-1', fullName: 'Ana');
        await WelcomeCinemaTracker.armForFreshRegistration('ana-1');

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.resolve(null, Brightness.light),
            home: _PostSignupCinemaHarness(
              profile: anaProfile,
              cinemaDuration: const Duration(milliseconds: 2000),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byType(DesperrengueWelcomeCinemaScreen),
          findsOneWidget,
        );
        expect(find.byType(RoleSelectionScreen), findsNothing);

        // Avança até concluir o Ato IV
        await tester.pump(const Duration(milliseconds: 2100));
        await tester.pump(const Duration(milliseconds: 500));

        // Verifica que abriu a tela de escolha de perfil intacta
        expect(find.byType(RoleSelectionScreen), findsOneWidget);
        expect(find.text('Olá, Ana'), findsOneWidget);
        expect(
          find.text('Como você deseja usar o Desperrengue hoje?'),
          findsOneWidget,
        );
        expect(find.text('Preciso de um serviço'), findsOneWidget);
        expect(find.text('Quero trabalhar'), findsOneWidget);

        // Tracker marcou como concluído
        expect(
          await WelcomeCinemaTracker.shouldShowBeforeRoleSelection(
            profile: anaProfile,
          ),
          isFalse,
        );

        // Botão "Como funciona" permite rever a apresentação a qualquer momento
        final replayBtn = find.byKey(const Key('btn-replay-welcome-cinema'));
        expect(replayBtn, findsOneWidget);
        await tester.tap(replayBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));

        expect(
          find.byType(DesperrengueWelcomeCinemaScreen),
          findsOneWidget,
        );
        final closeReplayBtn = find.byKey(
          const Key('btn-close-replay-cinema'),
        );
        expect(closeReplayBtn, findsOneWidget);

        await tester.tap(closeReplayBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(RoleSelectionScreen), findsOneWidget);
      },
    );

    testWidgets(
      'ZERO RenderFlex overflow nos 4 atos em 320x640 @ textScale 1.4x, 360x780, 412x915 e 1080x2400',
      (tester) async {
        const viewports = <(Size, double, double)>[
          (Size(320, 640), 1.0, 1.4),
          (Size(360, 780), 1.0, 1.15),
          (Size(412, 915), 1.0, 1.0),
          (Size(1080, 2400), 2.75, 1.0),
        ];

        addTearDown(tester.view.reset);

        for (final (size, dpr, textScale) in viewports) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = dpr;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.resolve(null, Brightness.light),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: DesperrengueWelcomeCinemaScreen(
                key: ValueKey('cinema-${size.width}x${size.height}'),
                userFirstName: 'Wagner',
                totalDuration: const Duration(milliseconds: 4000),
                isReplay: true,
                onCompleted: () {},
              ),
            ),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Ato I sem overflow em $size @ ${textScale}x',
          );

          // Ato II
          await tester.pump(const Duration(milliseconds: 1200));
          expect(
            tester.takeException(),
            isNull,
            reason: 'Ato II sem overflow em $size @ ${textScale}x',
          );

          // Ato III
          await tester.pump(const Duration(milliseconds: 1000));
          expect(
            tester.takeException(),
            isNull,
            reason: 'Ato III sem overflow em $size @ ${textScale}x',
          );

          // Ato IV
          await tester.pump(const Duration(milliseconds: 1000));
          expect(
            tester.takeException(),
            isNull,
            reason: 'Ato IV sem overflow em $size @ ${textScale}x',
          );

          // Verifica também RoleSelectionScreen na mesma resolução e textScale
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.resolve(null, Brightness.light),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: RoleSelectionScreen(
                profile: _makeProfile(fullName: 'Ana'),
              ),
            ),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'RoleSelectionScreen sem overflow em $size @ ${textScale}x',
          );
        }
      },
    );
  });
}

class _PostSignupCinemaHarness extends StatefulWidget {
  const _PostSignupCinemaHarness({
    required this.profile,
    required this.cinemaDuration,
  });

  final UserProfile profile;
  final Duration cinemaDuration;

  @override
  State<_PostSignupCinemaHarness> createState() =>
      _PostSignupCinemaHarnessState();
}

class _PostSignupCinemaHarnessState extends State<_PostSignupCinemaHarness> {
  bool _showCinema = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _showCinema
          ? DesperrengueWelcomeCinemaScreen(
              key: const ValueKey('post-signup-welcome-cinema'),
              userFirstName: widget.profile.firstName,
              totalDuration: widget.cinemaDuration,
              onCompleted: () async {
                await WelcomeCinemaTracker.markCompleted(widget.profile.id);
                if (mounted) {
                  setState(() => _showCinema = false);
                }
              },
            )
          : RoleSelectionScreen(
              key: const ValueKey('post-signup-role-selection'),
              profile: widget.profile,
            ),
    );
  }
}

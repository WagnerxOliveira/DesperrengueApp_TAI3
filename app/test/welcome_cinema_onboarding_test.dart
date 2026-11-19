import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/welcome_cinema_tracker.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/desperrengue_brand_logo.dart';
import 'package:desperrengue_app/features/auth/presentation/cadastro_sucesso_routing.dart';
import 'package:desperrengue_app/features/auth/presentation/desperrengue_welcome_cinema_screen.dart';
import 'package:desperrengue_app/features/auth/presentation/role_selection_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<Key> _kSixStoryKeys = <Key>[
  Key('cinema-act-1-mission'),
  Key('cinema-story-2-client-voice'),
  Key('cinema-act-3-client'),
  Key('cinema-story-4-passport'),
  Key('cinema-act-4-provider'),
  Key('cinema-act-2-audience'),
];

void _expectActiveStory(int activeIndex) {
  for (var i = 0; i < _kSixStoryKeys.length; i++) {
    expect(
      find.byKey(_kSixStoryKeys[i]),
      i == activeIndex ? findsOneWidget : findsNothing,
      reason:
          'Esperava apenas Story ${activeIndex + 1} (${_kSixStoryKeys[activeIndex]}) ativo, mas falhou no índice $i',
    );
  }
}

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

  group(
    'WelcomeCinemaTracker — Governança de Exibição Pós-Cadastro (v3 / v2.24.0)',
    () {
      test('chaves de persistência v3 configuradas para os 6 Stories v2.24.0', () {
        expect(WelcomeCinemaTracker.keyPrefixSeen, 'welcome_cinema_v3_seen_');
        expect(
          WelcomeCinemaTracker.keyPendingUid,
          'welcome_cinema_v3_pending_uid',
        );
      });

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

          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('welcome_cinema_v3_seen_uid-1'), '1');

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
        'CadastroSucessoRoutingScreen em ThemeMode.light mantém fundo Azul-Noite (#0F172A), selo esmeralda, monograma DesperrengueBrandLogo e arma WelcomeCinemaTracker',
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
          expect(find.byType(DesperrengueBrandLogo), findsOneWidget);

          final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
          expect(scaffold.backgroundColor, const Color(0xFF0F172A));
          expect(WelcomeCinemaTracker.isLikelyFreshAuthInMemory(), isTrue);

          // Desmonta antes do timer de 480ms disparar navegação para AuthGate
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 520));
        },
      );
    },
  );

  group(
    'DesperrengueWelcomeCinemaScreen — Tempo Confortável de Leitura & 6 Stories do Plano de Negócios',
    () {
      testWidgets(
        'duração padrão de 51000ms (8,5s por Story): após 5s continua confortavelmente no Story 1 e só avança para o Story 2 após 8,5s',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 2.75;
          addTearDown(tester.view.reset);

          var completedCount = 0;

          await tester.pumpWidget(
            MaterialApp(
              home: DesperrengueWelcomeCinemaScreen(
                userFirstName: 'Ana',
                onCompleted: () => completedCount++,
              ),
            ),
          );
          await tester.pump();

          final screen = tester.widget<DesperrengueWelcomeCinemaScreen>(
            find.byType(DesperrengueWelcomeCinemaScreen),
          );
          expect(screen.totalDuration, const Duration(milliseconds: 51000));
          expect(DesperrengueWelcomeCinemaScreen.storyCount, 6);

          _expectActiveStory(0);
          expect(find.text('1 de 6'), findsOneWidget);

          // Após 5 segundos inteiros, o usuário ainda está confortavelmente lendo o Story 1
          await tester.pump(const Duration(seconds: 5));
          _expectActiveStory(0);
          expect(find.text('1 de 6'), findsOneWidget);
          expect(completedCount, 0);

          // Após 8 segundos (8000ms < 8500ms), ainda está no Story 1
          await tester.pump(const Duration(seconds: 3));
          _expectActiveStory(0);

          // Ao completar 8,5 segundos (8600ms total), avança automaticamente para o Story 2
          await tester.pump(const Duration(milliseconds: 600));
          _expectActiveStory(1);
          expect(find.text('2 de 6'), findsOneWidget);
          expect(completedCount, 0);
        },
      );

      testWidgets(
        'progride automaticamente pelos 6 Stories (6000ms = 1000ms por Story), exibindo cada funcionalidade do Plano de Negócios e disparando onCompleted ao final',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 2.75;
          addTearDown(tester.view.reset);

          var completedCount = 0;
          const duration = Duration(milliseconds: 6000);

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

          // Story 1 (0ms - 1000ms): 33 Especialidades + SOS < 60s
          _expectActiveStory(0);
          expect(
            find.byKey(const Key('welcome-cinema-progress-bar')),
            findsOneWidget,
          );
          expect(
            find.textContaining('33 ESPECIALIDADES'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Emergência SOS · Resposta < 60s'),
            findsOneWidget,
          );
          expect(
            find.text('Sua casa resolvida por especialistas verificados.'),
            findsOneWidget,
          );
          expect(completedCount, 0);

          // Story 2 (1000ms - 2000ms): Pedido por Voz + Endereço Oculto + 3 Propostas
          await tester.pump(const Duration(milliseconds: 1100));
          _expectActiveStory(1);
          expect(
            find.textContaining('Chuveiro desarmando o disjuntor...'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Rua e número ocultos até você contratar'),
            findsOneWidget,
          );
          expect(
            find.text('Peça falando por voz e compare até 3 propostas.'),
            findsOneWidget,
          );
          expect(completedCount, 0);

          // Story 3 (2000ms - 3000ms): Mapa ao Vivo + 0% Peças NF-e + PIN 4 dígitos + 90 dias
          await tester.pump(const Duration(milliseconds: 1000));
          _expectActiveStory(2);
          expect(
            find.textContaining('Chegada acompanhada no mapa'),
            findsOneWidget,
          );
          expect(
            find.textContaining('0% de taxa sobre peças com NF-e'),
            findsOneWidget,
          );
          expect(find.text('4'), findsWidgets);
          expect(find.text('8'), findsWidgets);
          expect(find.text('2'), findsWidgets);
          expect(find.text('9'), findsWidgets);
          expect(find.textContaining('90 dias de garantia'), findsWidgets);
          expect(completedCount, 0);

          // Story 4 (3000ms - 4000ms): Prontuário Oficial da Casa ABNT 96 / 100
          await tester.pump(const Duration(milliseconds: 1000));
          _expectActiveStory(3);
          expect(find.text('96 / 100'), findsOneWidget);
          expect(
            find.textContaining('PDF Oficial ABNT NBR 5674 · SHA-256'),
            findsOneWidget,
          );
          expect(
            find.text('Prontuário Oficial da Casa em padrão ABNT.'),
            findsOneWidget,
          );
          expect(completedCount, 0);

          // Story 5 (4000ms - 5000ms): Modo Profissional (Zero Moedas + Valor Reservado + PIX + Diamante)
          await tester.pump(const Duration(milliseconds: 1000));
          _expectActiveStory(4);
          expect(
            find.textContaining('Zero compra de moedas para orçar'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Valor 100% reservado antes de sair de casa'),
            findsOneWidget,
          );
          expect(find.textContaining('Saque Rápido no PIX'), findsOneWidget);
          expect(find.textContaining('Diamante (5,0 ★)'), findsOneWidget);
          expect(completedCount, 0);

          // Story 6 (5000ms - 6000ms): 1 Conta · 2 Mundos + Biometria + Polícia Federal
          await tester.pump(const Duration(milliseconds: 1000));
          _expectActiveStory(5);
          expect(find.text('1 Conta · 2 Perfis'), findsOneWidget);
          expect(find.text('Biometria Facial 3D'), findsOneWidget);
          expect(find.text('Certidão Polícia Federal'), findsOneWidget);
          expect(
            find.text('Contrate hoje. Trabalhe quando quiser.'),
            findsOneWidget,
          );
          expect(completedCount, 0);

          // Conclui 100% do Story 6 e dispara onCompleted automaticamente
          await tester.pump(const Duration(milliseconds: 1000));
          await tester.pump();
          expect(completedCount, 1);
        },
      );
    },
  );

  group(
    'DesperrengueWelcomeCinemaScreen — Navegação Interativa Estilo Instagram Stories & WhatsApp Status',
    () {
      testWidgets(
        'toque na direita (story-tap-zone-next) caminha instantaneamente Story 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> conclui (onCompleted)',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 2.75;
          addTearDown(tester.view.reset);

          var completedCount = 0;

          await tester.pumpWidget(
            MaterialApp(
              home: DesperrengueWelcomeCinemaScreen(
                userFirstName: 'Ana',
                onCompleted: () => completedCount++,
              ),
            ),
          );
          await tester.pump();

          final nextZone = find.byKey(const Key('story-tap-zone-next'));
          expect(nextZone, findsOneWidget);

          for (var expectedStory = 0; expectedStory < 6; expectedStory++) {
            _expectActiveStory(expectedStory);
            expect(find.text('${expectedStory + 1} de 6'), findsOneWidget);
            expect(completedCount, 0);

            await tester.tap(nextZone);
            await tester.pump();
          }

          expect(completedCount, 1);
        },
      );

      testWidgets(
        'toque na esquerda (story-tap-zone-prev) volta instantaneamente Story 3 -> Story 2 -> Story 1 e reinicia Story 1 sem erro',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 2.75;
          addTearDown(tester.view.reset);

          var completedCount = 0;

          await tester.pumpWidget(
            MaterialApp(
              home: DesperrengueWelcomeCinemaScreen(
                userFirstName: 'Ana',
                onCompleted: () => completedCount++,
              ),
            ),
          );
          await tester.pump();

          final nextZone = find.byKey(const Key('story-tap-zone-next'));
          final prevZone = find.byKey(const Key('story-tap-zone-prev'));

          // Avança até o Story 3 (índice 2)
          await tester.tap(nextZone);
          await tester.pump();
          await tester.tap(nextZone);
          await tester.pump();
          _expectActiveStory(2);
          expect(find.text('3 de 6'), findsOneWidget);

          // Volta para o Story 2 (índice 1)
          await tester.tap(prevZone);
          await tester.pump();
          _expectActiveStory(1);
          expect(find.text('2 de 6'), findsOneWidget);

          // Volta para o Story 1 (índice 0)
          await tester.tap(prevZone);
          await tester.pump();
          _expectActiveStory(0);
          expect(find.text('1 de 6'), findsOneWidget);

          // Tocar na esquerda já no Story 1 reinicia o Story 1 e permanece nele
          await tester.tap(prevZone);
          await tester.pump();
          _expectActiveStory(0);
          expect(completedCount, 0);
        },
      );

      testWidgets(
        'deslize horizontal (tester.fling e tester.drag para esquerda e direita) avança e volta entre os Stories',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 2.75;
          addTearDown(tester.view.reset);

          var completedCount = 0;

          await tester.pumpWidget(
            MaterialApp(
              home: DesperrengueWelcomeCinemaScreen(
                userFirstName: 'Ana',
                onCompleted: () => completedCount++,
              ),
            ),
          );
          await tester.pump();

          final screenFinder = find.byType(DesperrengueWelcomeCinemaScreen);
          _expectActiveStory(0);

          // Fling para a esquerda -> avança do Story 1 para o Story 2
          await tester.fling(screenFinder, const Offset(-320, 0), 1200);
          await tester.pump();
          _expectActiveStory(1);

          // Drag para a esquerda -> avança do Story 2 para o Story 3
          await tester.drag(screenFinder, const Offset(-140, 0));
          await tester.pump();
          _expectActiveStory(2);

          // Fling para a direita -> volta do Story 3 para o Story 2
          await tester.fling(screenFinder, const Offset(320, 0), 1200);
          await tester.pump();
          _expectActiveStory(1);

          // Drag para a direita -> volta do Story 2 para o Story 1
          await tester.drag(screenFinder, const Offset(140, 0));
          await tester.pump();
          _expectActiveStory(0);
          expect(completedCount, 0);
        },
      );

      testWidgets(
        'botões inferiores explícitos (btn-story-next e btn-story-prev) caminham para frente/trás e concluem no último Story (Começar agora →)',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 2.75;
          addTearDown(tester.view.reset);

          var completedCount = 0;

          await tester.pumpWidget(
            MaterialApp(
              home: DesperrengueWelcomeCinemaScreen(
                userFirstName: 'Ana',
                onCompleted: () => completedCount++,
              ),
            ),
          );
          await tester.pump();

          final nextBtn = find.byKey(const Key('btn-story-next'));
          final prevBtn = find.byKey(const Key('btn-story-prev'));

          _expectActiveStory(0);
          expect(find.text('Próximo'), findsOneWidget);

          // Avança Story 1 -> Story 2 -> Story 3 via btn-story-next
          await tester.tap(nextBtn);
          await tester.pump();
          _expectActiveStory(1);

          await tester.tap(nextBtn);
          await tester.pump();
          _expectActiveStory(2);

          // Volta Story 3 -> Story 2 via btn-story-prev
          await tester.tap(prevBtn);
          await tester.pump();
          _expectActiveStory(1);

          // Avança até o Story 6 (índice 5)
          for (var i = 1; i < 5; i++) {
            await tester.tap(nextBtn);
            await tester.pump();
          }
          _expectActiveStory(5);
          expect(find.text('Começar agora →'), findsOneWidget);
          expect(completedCount, 0);

          // Tocar em "Começar agora →" no Story 6 conclui a apresentação
          await tester.tap(nextBtn);
          await tester.pump();
          expect(completedCount, 1);
        },
      );

      testWidgets(
        'toque direto nas 6 barras de capítulo do topo (cinema-chapter-tap-0..5) salta diretamente para qualquer Story',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 2.75;
          addTearDown(tester.view.reset);

          var completedCount = 0;

          await tester.pumpWidget(
            MaterialApp(
              home: DesperrengueWelcomeCinemaScreen(
                userFirstName: 'Ana',
                onCompleted: () => completedCount++,
              ),
            ),
          );
          await tester.pump();

          for (var i = 0; i < 6; i++) {
            expect(find.byKey(Key('cinema-chapter-tap-$i')), findsOneWidget);
          }

          const jumpOrder = <int>[3, 5, 1, 4, 0, 2, 5];
          for (final targetStory in jumpOrder) {
            await tester.tap(find.byKey(Key('cinema-chapter-tap-$targetStory')));
            await tester.pump();
            _expectActiveStory(targetStory);
            expect(find.text('${targetStory + 1} de 6'), findsOneWidget);
          }
          expect(completedCount, 0);
        },
      );

      testWidgets(
        'segurar o dedo (longPress) exibe cinema-paused-badge, congela o avanço mesmo após 15s e retoma ao soltar',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 2.75;
          addTearDown(tester.view.reset);

          var completed = false;
          await tester.pumpWidget(
            MaterialApp(
              home: DesperrengueWelcomeCinemaScreen(
                userFirstName: 'Ana',
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
          await tester.pump(
            kLongPressTimeout + const Duration(milliseconds: 100),
          );

          expect(find.byKey(const Key('cinema-paused-badge')), findsOneWidget);
          expect(find.text('Pausado para leitura'), findsOneWidget);
          expect(find.text('Solte para retomar'), findsOneWidget);

          // Mesmo segurando o dedo por 15 segundos (muito além dos 8,5s do Story 1), continua congelado no Story 1
          await tester.pump(const Duration(seconds: 15));
          expect(completed, isFalse);
          _expectActiveStory(0);

          // Ao soltar o dedo, remove o selo de pausa e retoma a linha do tempo normalmente
          await gesture.up();
          await tester.pump();
          expect(find.byKey(const Key('cinema-paused-badge')), findsNothing);

          // Avança os ~8,5s restantes do Story 1 e entra no Story 2
          await tester.pump(const Duration(milliseconds: 8500));
          _expectActiveStory(1);
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
                cinemaDuration: const Duration(milliseconds: 3000),
              ),
            ),
          );
          await tester.pump();

          expect(
            find.byType(DesperrengueWelcomeCinemaScreen),
            findsOneWidget,
          );
          expect(find.byType(RoleSelectionScreen), findsNothing);

          // Avança até concluir os 6 Stories
          await tester.pump(const Duration(milliseconds: 3100));
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

          // Tracker marcou como concluído (v3)
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
    },
  );

  group(
    'DesperrengueWelcomeCinemaScreen — Matriz Exaustiva de Responsividade nos 6 Stories',
    () {
      testWidgets(
        'varre todos os 6 Stories em múltiplos pontos de animação (10%, 50%, 90% de cada Story) nos 4 viewports (320x640 @ 1.4x, 360x780, 412x915 e 1080x2400) com ZERO RenderFlex overflow e zero exceções',
        (tester) async {
          const viewports = <(Size, double, double)>[
            (Size(320, 640), 1.0, 1.4),
            (Size(360, 780), 1.0, 1.15),
            (Size(412, 915), 1.0, 1.0),
            (Size(1080, 2400), 2.75, 1.0),
          ];

          const localFractions = <double>[0.10, 0.50, 0.90];
          const perStoryMs = 1000;
          const totalMs = perStoryMs * 6;

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
                  key: ValueKey('cinema-sweep-${size.width}x${size.height}'),
                  userFirstName: 'Wagner',
                  totalDuration: const Duration(milliseconds: totalMs),
                  isReplay: true,
                  onCompleted: () {},
                ),
              ),
            );
            await tester.pump();

            var elapsedMs = 0;
            for (var storyIndex = 0; storyIndex < 6; storyIndex++) {
              for (final localFraction in localFractions) {
                final targetMs =
                    (storyIndex * perStoryMs) +
                    (localFraction * perStoryMs).round();
                final deltaMs = targetMs - elapsedMs;
                if (deltaMs > 0) {
                  await tester.pump(Duration(milliseconds: deltaMs));
                  elapsedMs = targetMs;
                }

                expect(
                  tester.takeException(),
                  isNull,
                  reason:
                      'Zero RenderFlex overflow no Story ${storyIndex + 1} (${(localFraction * 100).round()}%) na resolução $size @ ${textScale}x',
                );

                _expectActiveStory(storyIndex);
              }
            }

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
              reason:
                  'RoleSelectionScreen sem overflow em $size @ ${textScale}x',
            );
            await tester.pump(const Duration(milliseconds: 450));
            expect(
              tester.takeException(),
              isNull,
              reason:
                  'RoleSelectionScreen pós-entrada sem overflow em $size @ ${textScale}x',
            );
          }
        },
      );
    },
  );
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

import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/welcome_cinema_tracker.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/app_tokens.dart';
import 'package:desperrengue_app/core/ui/category_brand_emblem.dart';
import 'package:desperrengue_app/core/ui/desperrengue_brand_logo.dart';
import 'package:desperrengue_app/core/ui/serene_route_transitions.dart';
import 'package:desperrengue_app/features/auth/presentation/cadastro_sucesso_routing.dart';
import 'package:desperrengue_app/features/auth/presentation/desperrengue_welcome_cinema_screen.dart';
import 'package:desperrengue_app/features/auth/presentation/role_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<Key> _kCanonicalStoryKeys = <Key>[
  Key('cinema-story-1'),
  Key('cinema-story-2'),
  Key('cinema-story-3'),
  Key('cinema-story-4'),
  Key('cinema-story-5'),
  Key('cinema-story-6'),
];

const List<Key> _kSemanticStoryKeys = <Key>[
  Key('cinema-act-1-mission'),
  Key('cinema-story-2-client-voice'),
  Key('cinema-act-3-client'),
  Key('cinema-story-4-passport'),
  Key('cinema-act-4-provider'),
  Key('cinema-act-2-audience'),
];

const List<String> _kExpectedStoryTitles = <String>[
  'Sua casa resolvida sem dor de cabeça',
  'Privacidade total antes de contratar',
  'Seu dinheiro 100% protegido sempre',
  'Sua casa mais valorizada',
  'Justo para quem trabalha',
  'Uma conta, dois caminhos',
];

const List<String> _kBannedTechnicalJargon = <String>[
  'De Casteljau',
  'SHA-256',
  'OCR',
  'ABNT',
  'NBR 5410',
  'NBR 5674',
  'PMOC',
  'WSS',
  'PBKDF2',
  'Escrow',
  'Smart Split',
];

void _expectActiveStory(int activeIndex) {
  for (var i = 0; i < _kCanonicalStoryKeys.length; i++) {
    expect(
      find.byKey(_kCanonicalStoryKeys[i]),
      i == activeIndex ? findsOneWidget : findsNothing,
      reason:
          'Esperava apenas Story ${activeIndex + 1} (${_kCanonicalStoryKeys[activeIndex]}) ativo, mas falhou no índice $i',
    );
    expect(
      find.byKey(_kSemanticStoryKeys[i]),
      i == activeIndex ? findsOneWidget : findsNothing,
      reason:
          'Esperava wrapper semântico ${_kSemanticStoryKeys[activeIndex]} ativo apenas no índice $activeIndex (falhou em $i)',
    );
  }
}

List<String> _collectAllVisibleTexts(WidgetTester tester) {
  final texts = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget as Text;
    final content = widget.data ?? widget.textSpan?.toPlainText() ?? '';
    if (content.trim().isNotEmpty) {
      texts.add(content.trim());
    }
  }
  for (final element in find.byType(RichText).evaluate()) {
    final widget = element.widget as RichText;
    final content = widget.text.toPlainText().trim();
    if (content.isNotEmpty) {
      texts.add(content);
    }
  }
  return texts;
}

void _assertZeroBannedJargonInCurrentStory(
  WidgetTester tester, {
  required int storyIndex,
}) {
  final allTexts = _collectAllVisibleTexts(tester);
  for (final text in allTexts) {
    final normalized = text.toUpperCase();
    for (final banned in _kBannedTechnicalJargon) {
      final needle = banned.toUpperCase();
      final isShortAcronym = needle.length <= 4 && !needle.contains(' ');
      final matched = isShortAcronym
          ? RegExp('\\b${RegExp.escape(needle)}\\b').hasMatch(normalized)
          : normalized.contains(needle);
      expect(
        matched,
        isFalse,
        reason:
            'Story ${storyIndex + 1} expôs jargão técnico proibido "$banned" no texto: "$text"',
      );
    }
  }
}

void _expectMinTouchTarget(
  WidgetTester tester,
  Finder finder, {
  double minWidth = 44.0,
  double minHeight = 44.0,
  required String label,
}) {
  expect(finder, findsOneWidget, reason: 'Controle "$label" deve estar visível');
  final size = tester.getSize(finder);
  expect(
    size.width,
    greaterThanOrEqualTo(minWidth),
    reason: 'Largura de toque de "$label" (${size.width}) deve ser >= ${minWidth}dp',
  );
  expect(
    size.height,
    greaterThanOrEqualTo(minHeight),
    reason: 'Altura de toque de "$label" (${size.height}) deve ser >= ${minHeight}dp',
  );
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
    '1. WelcomeCinemaTracker (v4 / v2.25.0) — Governança Pós-Cadastro e Ponte Escura',
    () {
      test('chaves de persistência v4 configuradas para a vitrine 120Hz v2.25.0', () {
        expect(WelcomeCinemaTracker.keyPrefixSeen, 'welcome_cinema_v4_seen_');
        expect(
          WelcomeCinemaTracker.keyPendingUid,
          'welcome_cinema_v4_pending_uid',
        );
      });

      test(
        'dispara true para conta recém-criada armada via OTP e para 1º login OAuth recente',
        () async {
          final freshOtpUser = _makeProfile(id: 'uid-otp-1');
          await WelcomeCinemaTracker.armForFreshRegistration('uid-otp-1');

          final prefsAfterArm = await SharedPreferences.getInstance();
          expect(
            prefsAfterArm.getString('welcome_cinema_v4_pending_uid'),
            'uid-otp-1',
          );

          final showForOtp =
              await WelcomeCinemaTracker.shouldShowBeforeRoleSelection(
                profile: freshOtpUser,
              );
          expect(showForOtp, isTrue);

          WelcomeCinemaTracker.resetMemoryStateForTesting();
          SharedPreferences.setMockInitialValues(<String, Object>{});

          final now = DateTime.utc(2026, 11, 19, 14, 0, 0);
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
        'após markCompleted(uid), limpa pending_uid, grava welcome_cinema_v4_seen_<uid> e isola entre usuários distintos',
        () async {
          final now = DateTime.utc(2026, 11, 19, 14, 0, 0);
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
          expect(prefs.getString('welcome_cinema_v4_seen_uid-1'), '1');
          expect(prefs.getString('welcome_cinema_v4_pending_uid'), isNull);

          // Mesmo recarregando do disco (cold restart), nunca repete para uid-1
          WelcomeCinemaTracker.resetMemoryStateForTesting();
          expect(
            await WelcomeCinemaTracker.shouldShowBeforeRoleSelection(
              profile: user1,
              authCreatedAt: now.subtract(const Duration(minutes: 1)),
              referenceNow: now,
            ),
            isFalse,
          );

          // Outro usuário recém-cadastrado no mesmo aparelho recebe normalmente
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
          final now = DateTime.utc(2026, 11, 19, 14, 0, 0);
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
          final now = DateTime.utc(2026, 11, 19, 14, 0, 0);
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
        'CadastroSucessoRoutingScreen em ThemeMode.light mantém ponte Azul-Noite (#0F172A), selo esmeralda, DesperrengueBrandLogo e arma WelcomeCinemaTracker',
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
    '2. Ritmo Sereno de 10,5s por Story (63000ms default) & Progressão Completa dos 6 Stories',
    () {
      testWidgets(
        'duração padrão de 63000ms (10,5s por Story): permanece tranquilo no Story 1 em 5s e em 10s, avança ao Story 2 após 10,5s e conclui ao final do Story 6',
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
          expect(screen.totalDuration, const Duration(milliseconds: 63000));
          expect(DesperrengueWelcomeCinemaScreen.storyCount, 6);

          _expectActiveStory(0);
          expect(find.text('1 de 6'), findsOneWidget);

          // Em 5s: leitura calma no Story 1 (já em Ato 3 de Repouso Sereno)
          await tester.pump(const Duration(seconds: 5));
          _expectActiveStory(0);
          expect(find.text('1 de 6'), findsOneWidget);
          expect(completedCount, 0);

          // Em 10s (10000ms < 10500ms): ainda permanece sereno no Story 1
          await tester.pump(const Duration(seconds: 5));
          _expectActiveStory(0);
          expect(find.text('1 de 6'), findsOneWidget);
          expect(completedCount, 0);

          // Em 10,6s (10600ms > 10500ms): avança automaticamente para o Story 2
          await tester.pump(const Duration(milliseconds: 600));
          _expectActiveStory(1);
          expect(find.text('2 de 6'), findsOneWidget);
          expect(completedCount, 0);

          // Avança pelos Stories 2 -> 3 -> 4 -> 5 -> 6 no ritmo padrão de 10,5s
          for (var expectedStory = 2; expectedStory < 6; expectedStory++) {
            await tester.pump(const Duration(milliseconds: 10500));
            _expectActiveStory(expectedStory);
            expect(find.text('${expectedStory + 1} de 6'), findsOneWidget);
            expect(completedCount, 0);
          }

          // Conclui os últimos ~10,4s do Story 6 e dispara onCompleted exatamente 1 vez
          await tester.pump(const Duration(milliseconds: 10500));
          await tester.pump();
          expect(completedCount, 1);
        },
      );

      testWidgets(
        'progride pelos 6 Stories exibindo foco único (1 Tag + 1 Título <= 7 palavras + 1 Subtítulo + 1 Hero Card) e micro-demonstrações serenas',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 2.75;
          addTearDown(tester.view.reset);

          var completedCount = 0;
          const duration = Duration(milliseconds: 12000); // 2000ms por Story

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

          // Story 1 (0ms..2000ms): Casa Resolvida Sem Dor de Cabeça (busca preenchida + 3 CategoryBrandEmblem)
          await tester.pump(const Duration(milliseconds: 1500)); // t = 1500ms
          _expectActiveStory(0);
          expect(
            find.byKey(const Key('welcome-cinema-progress-bar')),
            findsOneWidget,
          );
          expect(find.text('BEM-VINDO(A), ANA'), findsOneWidget);
          expect(
            find.text('Sua casa resolvida sem dor de cabeça'),
            findsOneWidget,
          );
          expect(
            find.text('Trocar resistência do chuveiro'),
            findsOneWidget,
          );
          expect(find.byType(CategoryBrandEmblem), findsNWidgets(3));
          expect(find.text('Elétrica'), findsOneWidget);
          expect(find.text('Encanador'), findsOneWidget);
          expect(find.text('Ar-condicionado'), findsOneWidget);
          expect(
            find.text('Atendimento rápido na sua região'),
            findsOneWidget,
          );
          expect(find.byType(WelcomeStoryHeroCard), findsOneWidget);

          // Story 2 (2000ms..4000ms): cruza fronteira em 2100ms e avança micro-coreografia até 3600ms
          await tester.pump(const Duration(milliseconds: 600)); // t = 2100ms (monta Story 2)
          _expectActiveStory(1);
          await tester.pump(const Duration(milliseconds: 1500)); // t = 3600ms (Ato 3 repouso)
          _expectActiveStory(1);
          expect(find.text('SEGURANÇA DA SUA CASA'), findsOneWidget);
          expect(
            find.text('Privacidade total antes de contratar'),
            findsOneWidget,
          );
          expect(find.text('🔒 Rua e número protegidos'), findsOneWidget);
          expect(find.text('Ricardo M.'), findsOneWidget);
          expect(find.text('Carlos A.'), findsOneWidget);
          expect(find.text('André S.'), findsOneWidget);
          expect(find.byType(WelcomeStoryHeroCard), findsOneWidget);

          // Story 3 (4000ms..6000ms): cofre + código 4·8·2·9 + 90 dias
          await tester.pump(const Duration(milliseconds: 500)); // t = 4100ms (monta Story 3)
          _expectActiveStory(2);
          await tester.pump(const Duration(milliseconds: 1500)); // t = 5600ms (Ato 3 repouso)
          _expectActiveStory(2);
          expect(find.text('PAGAMENTO PROTEGIDO'), findsOneWidget);
          expect(
            find.text('Seu dinheiro 100% protegido sempre'),
            findsOneWidget,
          );
          expect(
            find.text('R\$ 180,00 · Guardado com segurança'),
            findsOneWidget,
          );
          expect(
            find.text('✓ Serviço aprovado · 90 dias de garantia'),
            findsOneWidget,
          );
          for (final digit in const ['4', '8', '2', '9']) {
            expect(find.text(digit), findsWidgets);
          }
          expect(find.byType(WelcomeStoryHeroCard), findsOneWidget);

          // Story 4 (6000ms..8000ms): Saúde do Imóvel 96% · Em dia + PDF
          await tester.pump(const Duration(milliseconds: 500)); // t = 6100ms (monta Story 4)
          _expectActiveStory(3);
          await tester.pump(const Duration(milliseconds: 1500)); // t = 7600ms (Ato 3 repouso)
          _expectActiveStory(3);
          expect(find.text('HISTÓRICO INTELIGENTE'), findsOneWidget);
          expect(find.text('Sua casa mais valorizada'), findsOneWidget);
          expect(find.text('Saúde do Imóvel'), findsOneWidget);
          expect(find.text('96% · Em dia'), findsOneWidget);
          expect(find.text('Revisão Elétrica'), findsOneWidget);
          expect(find.text('Climatização'), findsOneWidget);
          expect(find.text('Comprovante em PDF'), findsNWidgets(2));
          expect(find.byType(WelcomeStoryHeroCard), findsOneWidget);

          // Story 5 (8000ms..10000ms): R$ 0,00 + Valor garantido + ★ 5,0
          await tester.pump(const Duration(milliseconds: 500)); // t = 8100ms (monta Story 5)
          _expectActiveStory(4);
          await tester.pump(const Duration(milliseconds: 1500)); // t = 9600ms (Ato 3 repouso)
          _expectActiveStory(4);
          expect(find.text('MODO PROFISSIONAL'), findsOneWidget);
          expect(find.text('Justo para quem trabalha'), findsOneWidget);
          expect(find.text('Custo para orçar: R\$ 0,00'), findsOneWidget);
          expect(
            find.text('Valor do cliente já garantido antes de sair'),
            findsOneWidget,
          );
          expect(find.text('★ 5,0 · Profissional Destaque'), findsOneWidget);
          expect(find.byType(WelcomeStoryHeroCard), findsOneWidget);

          // Story 6 (10000ms..12000ms): Modo Cliente + Modo Profissional + Identidade Verificada
          await tester.pump(const Duration(milliseconds: 500)); // t = 10100ms (monta Story 6)
          _expectActiveStory(5);
          await tester.pump(const Duration(milliseconds: 1500)); // t = 11600ms (Ato 3 repouso)
          _expectActiveStory(5);
          expect(find.text('LIBERDADE EM 1 TOQUE'), findsOneWidget);
          expect(find.text('Uma conta, dois caminhos'), findsOneWidget);
          expect(find.text('Modo Cliente'), findsOneWidget);
          expect(find.text('Modo Profissional'), findsOneWidget);
          expect(find.text('Identidade Verificada'), findsOneWidget);
          expect(find.text('1 conta · 2 perfis'), findsOneWidget);
          expect(find.text('Começar agora'), findsOneWidget);
          expect(find.byType(WelcomeStoryHeroCard), findsOneWidget);
          expect(completedCount, 0);

          // Conclui 100% do Story 6 (12000ms)
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump();
          expect(completedCount, 1);
        },
      );
    },
  );

  group(
    '3. Anti-Jank 120 FPS — Isolamento Estrito de Rebuild do WelcomeStoryHeroCard',
    () {
      testWidgets(
        'onActiveHeroBuild comprova buildCount == 1 estrito durante pump(3s) único E durante 190 frames contínuos de 16ms enquanto a barra de progresso corre',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 2.75;
          addTearDown(tester.view.reset);

          final heroBuildsByStory = <int, int>{};

          // Sub-caso A: pump único de 3 segundos (especificação obrigatória FASE 4)
          await tester.pumpWidget(
            MaterialApp(
              home: DesperrengueWelcomeCinemaScreen(
                key: const ValueKey('cinema-anti-jank-single-pump'),
                userFirstName: 'Ana',
                onActiveHeroBuild: (storyIndex) {
                  heroBuildsByStory[storyIndex] =
                      (heroBuildsByStory[storyIndex] ?? 0) + 1;
                },
                onCompleted: () {},
              ),
            ),
          );
          await tester.pump();

          expect(
            heroBuildsByStory[0],
            equals(1),
            reason: 'Montagem inicial do WelcomeStoryHeroCard ativo deve registrar 1 build',
          );

          await tester.pump(const Duration(seconds: 3));
          expect(
            heroBuildsByStory[0],
            equals(1),
            reason:
                'Zero rebuild do WelcomeStoryHeroCard após pump(3s) enquanto _storyProgressController anima!',
          );

          // Sub-caso B: 190 frames reais de ~16ms (> 3,0s) + avanço até 9s (Ato 3 de Repouso)
          heroBuildsByStory.clear();
          await tester.pumpWidget(
            MaterialApp(
              home: DesperrengueWelcomeCinemaScreen(
                key: const ValueKey('cinema-anti-jank-190-frames'),
                userFirstName: 'Wagner',
                onActiveHeroBuild: (storyIndex) {
                  heroBuildsByStory[storyIndex] =
                      (heroBuildsByStory[storyIndex] ?? 0) + 1;
                },
                onCompleted: () {},
              ),
            ),
          );
          await tester.pump();
          expect(heroBuildsByStory[0], equals(1));

          for (var frame = 0; frame < 190; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(
            heroBuildsByStory[0],
            equals(1),
            reason:
                'Mesmo após 190 ticks de vsync (~3,04s) da barra superior e micro-coreografia, WelcomeStoryHeroCard.build permanece estritamente em 1!',
          );

          // Permanece em repouso absoluto até 9s sem nenhum rebuild extra
          await tester.pump(const Duration(seconds: 5));
          expect(heroBuildsByStory[0], equals(1));

          // Verifica presença de RepaintBoundary isolando a barra de progresso e o card herói
          expect(
            find.ancestor(
              of: find.byKey(const Key('welcome-cinema-progress-bar')),
              matching: find.byType(RepaintBoundary),
            ),
            findsWidgets,
          );
          expect(
            find.descendant(
              of: find.byType(WelcomeStoryHeroCard),
              matching: find.byType(RepaintBoundary),
            ),
            findsWidgets,
          );
        },
      );
    },
  );

  group(
    '4. Motor de Gestos Listener de Latência Zero, Controles e Alvos >= 44x44dp',
    () {
      testWidgets(
        'zonas de toque 32% esquerda e 68% direita (por Key e por coordenadas na fronteira 32%/68%) voltam, reiniciam no Story 1, avançam e concluem no Story 6',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
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

          final prevZone = find.byKey(const Key('story-tap-zone-prev'));
          final nextZone = find.byKey(const Key('story-tap-zone-next'));
          expect(prevZone, findsOneWidget);
          expect(nextZone, findsOneWidget);

          final prevRect = tester.getRect(prevZone);
          final nextRect = tester.getRect(nextZone);
          final totalStageWidth = prevRect.width + nextRect.width;
          expect(
            prevRect.width / totalStageWidth,
            closeTo(0.32, 0.01),
            reason: 'Zona esquerda deve ocupar 32% da largura do palco',
          );
          expect(
            nextRect.width / totalStageWidth,
            closeTo(0.68, 0.01),
            reason: 'Zona direita deve ocupar 68% da largura do palco',
          );

          // Toque por coordenada em 34% da largura (>= 32% -> zona direita) avança Story 1 -> Story 2
          final stageTopLeft = prevRect.topLeft;
          final stageCenterY = prevRect.center.dy;
          await tester.tapAt(
            Offset(stageTopLeft.dx + totalStageWidth * 0.34, stageCenterY),
          );
          await tester.pump();
          _expectActiveStory(1);
          expect(find.text('2 de 6'), findsOneWidget);

          // Avança Story 2 -> Story 3 tocando em story-tap-zone-next
          await tester.tap(nextZone);
          await tester.pump();
          _expectActiveStory(2);

          // Toque por coordenada em 30% da largura (< 32% -> zona esquerda) volta Story 3 -> Story 2
          await tester.tapAt(
            Offset(stageTopLeft.dx + totalStageWidth * 0.30, stageCenterY),
          );
          await tester.pump();
          _expectActiveStory(1);

          // Volta Story 2 -> Story 1 via story-tap-zone-prev
          await tester.tap(prevZone);
          await tester.pump();
          _expectActiveStory(0);

          // Avança 4s no Story 1 e toca na zona esquerda: reinicia Story 1 (não sai nem quebra)
          await tester.pump(const Duration(seconds: 4));
          await tester.tap(prevZone);
          await tester.pump();
          _expectActiveStory(0);
          expect(completedCount, 0);
          // Como reiniciou do zero, após 8s ainda está no Story 1 (< 10,5s)
          await tester.pump(const Duration(seconds: 8));
          _expectActiveStory(0);

          // Caminha pelos 6 Stories via zona direita até concluir no Story 6
          for (var expectedStory = 0; expectedStory < 6; expectedStory++) {
            _expectActiveStory(expectedStory);
            expect(completedCount, 0);
            await tester.tap(nextZone);
            await tester.pump();
          }
          expect(completedCount, 1);
        },
      );

      testWidgets(
        'swipe horizontal com física de mola (fling e drag para esquerda e direita) transiciona suavemente entre Stories',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
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

          Future<void> pumpSpringSettle() async {
            for (var i = 0; i < 16; i++) {
              await tester.pump(const Duration(milliseconds: 50));
            }
          }

          final pageViewFinder = find.byType(PageView);
          _expectActiveStory(0);

          // Fling esquerda -> Story 1 para Story 2
          await tester.fling(pageViewFinder, const Offset(-260, 0), 1200);
          await pumpSpringSettle();
          _expectActiveStory(1);

          // Swipe humano (timedDrag) esquerda -> Story 2 para Story 3
          await tester.timedDrag(
            pageViewFinder,
            const Offset(-140, 0),
            const Duration(milliseconds: 180),
          );
          await pumpSpringSettle();
          _expectActiveStory(2);

          // Drag estático além do ponto médio esquerda -> Story 3 para Story 4
          await tester.drag(pageViewFinder, const Offset(-230, 0));
          await pumpSpringSettle();
          _expectActiveStory(3);

          // Fling direita -> Story 4 para Story 3
          await tester.fling(pageViewFinder, const Offset(260, 0), 1200);
          await pumpSpringSettle();
          _expectActiveStory(2);

          // Swipe humano (timedDrag) direita -> Story 3 para Story 2
          await tester.timedDrag(
            pageViewFinder,
            const Offset(140, 0),
            const Duration(milliseconds: 180),
          );
          await pumpSpringSettle();
          _expectActiveStory(1);

          // Drag estático além do ponto médio direita -> Story 2 para Story 1
          await tester.drag(pageViewFinder, const Offset(230, 0));
          await pumpSpringSettle();
          _expectActiveStory(0);
          expect(completedCount, 0);
        },
      );

      testWidgets(
        '6 barras de segmento (cinema-chapter-tap-0..5) possuem altura de toque >= 44dp e saltam diretamente para qualquer Story',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
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
            final barFinder = find.byKey(Key('cinema-chapter-tap-$i'));
            expect(barFinder, findsOneWidget);
            final barSize = tester.getSize(barFinder);
            expect(
              barSize.height,
              greaterThanOrEqualTo(44.0),
              reason:
                  'Barra de capítulo $i deve ter altura útil de toque >= 44dp (encontrado: ${barSize.height})',
            );
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
        'todos os botões (Pular, Fechar em replay, Voltar, Próximo / Começar agora e Rever apresentação) respeitam >= 44x44dp e funcionam ponta a ponta',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          // 1) Modo pós-cadastro (isReplay: false): PopScope bloqueado + botão Pular >= 44x44dp + Voltar / Próximo / Começar agora
          var skippedOrCompleted = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: DesperrengueWelcomeCinemaScreen(
                key: const ValueKey('cinema-controls-fresh'),
                userFirstName: 'Ana',
                isReplay: false,
                onCompleted: () => skippedOrCompleted++,
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

          final skipBtn = find.byKey(const Key('btn-skip-welcome-cinema'));
          expect(find.text('Pular'), findsOneWidget);
          _expectMinTouchTarget(
            tester,
            skipBtn,
            label: 'btn-skip-welcome-cinema (Pular)',
          );

          final nextBtn = find.byKey(const Key('btn-story-next'));
          final prevBtn = find.byKey(const Key('btn-story-prev'));
          expect(find.text('Próximo'), findsOneWidget);
          _expectMinTouchTarget(
            tester,
            nextBtn,
            label: 'btn-story-next (Próximo)',
          );

          // No Story 1, Voltar fica invisível e com IgnorePointer ativo
          final prevIgnoreOnStory1 = tester.widget<IgnorePointer>(
            find
                .ancestor(
                  of: prevBtn,
                  matching: find.byType(IgnorePointer),
                )
                .first,
          );
          expect(prevIgnoreOnStory1.ignoring, isTrue);

          // Avança ao Story 2 -> botão Voltar passa a ficar interativo e >= 44x44dp
          await tester.tap(nextBtn);
          await tester.pump();
          _expectActiveStory(1);
          expect(find.text('Voltar'), findsOneWidget);
          _expectMinTouchTarget(
            tester,
            prevBtn,
            label: 'btn-story-prev (Voltar)',
          );

          // Toca em Voltar -> retorna ao Story 1
          await tester.tap(prevBtn);
          await tester.pump();
          _expectActiveStory(0);

          // Toca em Pular -> conclui imediatamente
          await tester.tap(skipBtn);
          await tester.pump();
          expect(skippedOrCompleted, 1);

          // 2) Testa botão Começar agora no Story 6 (>= 44x44dp)
          var finishedViaPrimaryCta = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: DesperrengueWelcomeCinemaScreen(
                key: const ValueKey('cinema-controls-cta'),
                userFirstName: 'Ana',
                onCompleted: () => finishedViaPrimaryCta++,
              ),
            ),
          );
          await tester.pump();
          await tester.tap(find.byKey(const Key('cinema-chapter-tap-5')));
          await tester.pump();
          _expectActiveStory(5);
          expect(find.text('Começar agora'), findsOneWidget);
          _expectMinTouchTarget(
            tester,
            find.byKey(const Key('btn-story-next')),
            label: 'btn-story-next (Começar agora)',
          );
          await tester.tap(find.byKey(const Key('btn-story-next')));
          await tester.pump();
          expect(finishedViaPrimaryCta, 1);

          // 3) Transição pós-cadastro -> RoleSelectionScreen -> botão "Rever apresentação" (>= 44x44dp) -> Fechar em replay (>= 44x44dp)
          final anaProfile = _makeProfile(id: 'ana-replay-1', fullName: 'Ana');
          await WelcomeCinemaTracker.armForFreshRegistration('ana-replay-1');

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

          await tester.pump(const Duration(milliseconds: 3100));
          await tester.pump(const Duration(milliseconds: 450));

          expect(find.byType(RoleSelectionScreen), findsOneWidget);
          expect(find.text('Olá, Ana'), findsOneWidget);
          expect(
            await WelcomeCinemaTracker.shouldShowBeforeRoleSelection(
              profile: anaProfile,
            ),
            isFalse,
          );

          final replayBtn = find.byKey(const Key('btn-replay-welcome-cinema'));
          expect(find.text('Rever apresentação'), findsOneWidget);
          _expectMinTouchTarget(
            tester,
            replayBtn,
            label: 'btn-replay-welcome-cinema (Rever apresentação)',
          );

          await tester.tap(replayBtn);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 420));

          expect(
            find.byType(DesperrengueWelcomeCinemaScreen),
            findsOneWidget,
          );
          final closeReplayBtn = find.byKey(
            const Key('btn-close-replay-cinema'),
          );
          expect(find.text('Fechar'), findsOneWidget);
          _expectMinTouchTarget(
            tester,
            closeReplayBtn,
            label: 'btn-close-replay-cinema (Fechar)',
          );

          await tester.tap(closeReplayBtn);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.byType(RoleSelectionScreen), findsOneWidget);
        },
      );

      testWidgets(
        'Hold-to-Pause de Latência Zero: segurar por 3s+ congela no milissegundo exato, exibe cinema-paused-badge (Pausado) e retoma ao soltar SEM avançar acidentalmente de página',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
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

          // Avança 2,0s no Story 1 (restam 8,5s dos 10,5s do Story 1)
          await tester.pump(const Duration(seconds: 2));
          _expectActiveStory(0);

          // Segura o dedo na metade direita do palco (onde um toque rápido avançaria de página!)
          final nextZoneCenter = tester.getCenter(
            find.byKey(const Key('story-tap-zone-next')),
          );
          final gesture = await tester.startGesture(nextZoneCenter);

          // Após 250ms (>= 220ms do Timer), selo "Pausado" aparece suavemente
          await tester.pump(const Duration(milliseconds: 250));
          expect(find.byKey(const Key('cinema-paused-badge')), findsOneWidget);
          expect(find.text('Pausado'), findsOneWidget);

          // Mantém pressionado por 3s (e depois mais 10s = 13s totais > 10,5s): continua congelado no Story 1!
          await tester.pump(const Duration(seconds: 3));
          _expectActiveStory(0);
          expect(completed, isFalse);

          await tester.pump(const Duration(seconds: 10));
          _expectActiveStory(0);
          expect(completed, isFalse);

          // Solta o dedo -> remove cinema-paused-badge e NÃO salta acidentalmente para o Story 2!
          await gesture.up();
          await tester.pump();
          expect(find.byKey(const Key('cinema-paused-badge')), findsNothing);
          _expectActiveStory(0);
          expect(find.text('1 de 6'), findsOneWidget);

          // Comprova retomada do ponto exato (2,0s): após +8,0s (= 10,0s < 10,5s) continua no Story 1
          await tester.pump(const Duration(seconds: 8));
          _expectActiveStory(0);

          // Após +600ms (= 10,6s > 10,5s), avança naturalmente para o Story 2
          await tester.pump(const Duration(milliseconds: 600));
          _expectActiveStory(1);
          expect(find.text('2 de 6'), findsOneWidget);
        },
      );
    },
  );

  group(
    '5. Acessibilidade (disableAnimations: true), Anti-Jargão, Densidade e Respiro >= 38%',
    () {
      testWidgets(
        'MediaQuery(disableAnimations: true) renderiza estado final de repouso nos 6 Stories sem falhas e sem timers pendentes',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          var completed = false;
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: DesperrengueWelcomeCinemaScreen(
                userFirstName: 'Ana',
                onCompleted: () => completed = true,
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);

          // No frame 0 com disableAnimations: true, cada Story já exibe seu estado final 1.0
          final expectedRestingSnippets = <String>[
            'Trocar resistência do chuveiro',
            '🔒 Rua e número protegidos',
            '✓ Serviço aprovado · 90 dias de garantia',
            '96% · Em dia',
            '★ 5,0 · Profissional Destaque',
            'Identidade Verificada',
          ];

          for (var i = 0; i < 6; i++) {
            await tester.tap(find.byKey(Key('cinema-chapter-tap-$i')));
            await tester.pump();
            expect(tester.takeException(), isNull);
            _expectActiveStory(i);
            expect(find.text(expectedRestingSnippets[i]), findsOneWidget);
          }

          expect(completed, isFalse);
          await tester.tap(find.byKey(const Key('btn-story-next')));
          await tester.pump();
          expect(completed, isTrue);

          // Desmonta sem deixar timers pendentes
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'auditoria automática nos 6 Stories: zero jargão técnico proibido, título <= 7 palavras, zero FittedBox, contraste WCAG AA >= 4.5:1 e >= 38% espaço negativo',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              home: DesperrengueWelcomeCinemaScreen(
                userFirstName: 'Wagner',
                onCompleted: () {},
              ),
            ),
          );
          await tester.pump();

          const darkSurfaceRef = Color(0xFF131B29);

          for (var storyIndex = 0; storyIndex < 6; storyIndex++) {
            await tester.tap(
              find.byKey(Key('cinema-chapter-tap-$storyIndex')),
            );
            await tester.pump();

            // Varre jargão tanto no início (Ato 1/2) quanto no repouso (Ato 3)
            _assertZeroBannedJargonInCurrentStory(
              tester,
              storyIndex: storyIndex,
            );
            await tester.pump(const Duration(milliseconds: 3500));
            _assertZeroBannedJargonInCurrentStory(
              tester,
              storyIndex: storyIndex,
            );

            // Título curto <= 7 palavras
            final title = _kExpectedStoryTitles[storyIndex];
            expect(find.text(title), findsOneWidget);
            final wordCount = title
                .trim()
                .split(RegExp(r'\s+'))
                .where((w) => w.isNotEmpty)
                .length;
            expect(
              wordCount,
              lessThanOrEqualTo(7),
              reason:
                  'Título do Story ${storyIndex + 1} ("$title") excedeu 7 palavras ($wordCount)',
            );

            // Estritamente 1 Card Herói visível e zero FittedBox esmagando tipografia
            expect(find.byType(WelcomeStoryHeroCard), findsOneWidget);
            expect(
              find.descendant(
                of: find.byType(DesperrengueWelcomeCinemaScreen),
                matching: find.byType(FittedBox),
              ),
              findsNothing,
              reason: 'Story ${storyIndex + 1} não pode usar FittedBox',
            );

            // Espaço de respiro >= 38% (Spacer proporcional acima e abaixo + área livre da viewport >= 38%)
            expect(
              find.descendant(
                of: find.byKey(_kCanonicalStoryKeys[storyIndex]),
                matching: find.byType(Spacer),
              ),
              findsAtLeastNWidgets(2),
              reason:
                  'Story ${storyIndex + 1} deve usar Spacer proporcional acima e abaixo do bloco focal',
            );
            final screenArea = 390.0 * 844.0;
            final titleRect = tester.getRect(find.text(title));
            final heroRect = tester.getRect(
              find.byType(WelcomeStoryHeroCard),
            );
            final occupiedCardAndCopyArea =
                (titleRect.width * titleRect.height) +
                (heroRect.width * heroRect.height) +
                (350.0 * 80.0); // tag + subtítulo + barra visual fina
            final freeAreaRatio =
                1.0 - (occupiedCardAndCopyArea / screenArea).clamp(0.0, 1.0);
            expect(
              freeAreaRatio,
              greaterThanOrEqualTo(0.38),
              reason:
                  'Story ${storyIndex + 1} precisa preservar >= 38% de espaço negativo respirável (livre: ${(freeAreaRatio * 100).toStringAsFixed(1)}%)',
            );

            // Contraste WCAG AA >= 4.5:1 nos textos principais do Story
            final titleWidget = tester.widget<Text>(find.text(title));
            expect(
              AppTokens.contrast(titleWidget.style!.color!, darkSurfaceRef),
              greaterThanOrEqualTo(4.5),
            );
          }
        },
      );
    },
  );

  group(
    '6. Matriz Extrema de Responsividade nos 6 Stories (Ato 1, Ato 2 e Ato 3) + RoleSelectionScreen',
    () {
      const extremeViewports = <({Size size, double scale, String label})>[
        (
          size: Size(320, 640),
          scale: 1.35,
          label: '320x640 @ textScaler 1.35',
        ),
        (
          size: Size(320, 640),
          scale: 1.40,
          label: '320x640 @ textScaler 1.40',
        ),
        (
          size: Size(360, 780),
          scale: 1.0,
          label: '360x780 @ textScaler 1.0',
        ),
        (
          size: Size(390, 844),
          scale: 1.0,
          label: '390x844 @ textScaler 1.0',
        ),
        (
          size: Size(412, 915),
          scale: 1.30,
          label: '412x915 @ textScaler 1.30',
        ),
      ];

      for (final vp in extremeViewports) {
        testWidgets(
          'zero RenderFlex overflow nos 6 Stories (Ato 1 entrada, Ato 2 micro-demo e Ato 3 repouso) + RoleSelectionScreen em ${vp.label}',
          (tester) async {
            tester.view.physicalSize = vp.size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.resolve(null, Brightness.light),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(vp.scale),
                  ),
                  child: child!,
                ),
                home: DesperrengueWelcomeCinemaScreen(
                  key: ValueKey('cinema-extreme-${vp.label}'),
                  userFirstName: 'Wagner',
                  isReplay: false,
                  onCompleted: () {},
                ),
              ),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);

            // Testa cada um dos 6 Stories nos 3 Atos:
            // - Ato 1 (0,30s): entrada sedosa em cascata
            // - Ato 2 (1,65s): micro-demonstração em andamento
            // - Ato 3 (4,20s): repouso sereno absoluto
            for (var storyIndex = 0; storyIndex < 6; storyIndex++) {
              await tester.tap(
                find.byKey(Key('cinema-chapter-tap-$storyIndex')),
              );
              await tester.pump();
              expect(
                tester.takeException(),
                isNull,
                reason: 'Zero overflow ao abrir Story ${storyIndex + 1} em ${vp.label}',
              );

              // Ato 1 (300ms)
              await tester.pump(const Duration(milliseconds: 300));
              expect(
                tester.takeException(),
                isNull,
                reason: 'Zero overflow no Ato 1 do Story ${storyIndex + 1} em ${vp.label}',
              );
              _expectActiveStory(storyIndex);

              // Ato 2 (1650ms acumulados)
              await tester.pump(const Duration(milliseconds: 1350));
              expect(
                tester.takeException(),
                isNull,
                reason: 'Zero overflow no Ato 2 do Story ${storyIndex + 1} em ${vp.label}',
              );
              _expectActiveStory(storyIndex);

              // Ato 3 de Repouso Sereno (4200ms acumulados > 3100ms)
              await tester.pump(const Duration(milliseconds: 2550));
              expect(
                tester.takeException(),
                isNull,
                reason: 'Zero overflow no Ato 3 de Repouso do Story ${storyIndex + 1} em ${vp.label}',
              );
              _expectActiveStory(storyIndex);
            }

            // Verifica também Hold-to-Pause badge na mesma resolução extrema (ex: 320x640 @ 1.40x)
            final gesture = await tester.startGesture(
              tester.getCenter(find.byType(PageView)),
            );
            await tester.pump(const Duration(milliseconds: 260));
            expect(tester.takeException(), isNull);
            expect(find.byKey(const Key('cinema-paused-badge')), findsOneWidget);
            await gesture.up();
            await tester.pump();
            expect(tester.takeException(), isNull);

            // Verifica RoleSelectionScreen + transição SereneAuthPageRoute do botão Rever apresentação
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.resolve(null, Brightness.light),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(vp.scale),
                  ),
                  child: child!,
                ),
                home: RoleSelectionScreen(
                  profile: _makeProfile(fullName: 'Wagner Oliveira'),
                ),
              ),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);
            await tester.pump(const Duration(milliseconds: 450));
            expect(tester.takeException(), isNull);

            final replayBtn = find.byKey(const Key('btn-replay-welcome-cinema'));
            _expectMinTouchTarget(
              tester,
              replayBtn,
              label: 'btn-replay-welcome-cinema em ${vp.label}',
            );

            await tester.tap(replayBtn);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 190));
            expect(tester.takeException(), isNull);
            await tester.pump(const Duration(milliseconds: 250));
            expect(tester.takeException(), isNull);
            expect(
              find.byType(DesperrengueWelcomeCinemaScreen),
              findsOneWidget,
            );
          },
        );
      }
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
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return ColoredBox(
      color: const Color(0xFF0F172A),
      child: AnimatedSwitcher(
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 380),
        reverseDuration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) =>
            SereneAuthPageRoute.buildSwitcherTransition(
              context: context,
              animation: animation,
              child: child,
            ),
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
      ),
    );
  }
}

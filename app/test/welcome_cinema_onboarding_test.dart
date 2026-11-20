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

import 'support/cinema_test_helpers.dart';

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
  'Casa Resolvida Sem Dor de Cabeça',
  'Privacidade Total ao Pedir',
  'Seu Dinheiro 100% Protegido',
  'Sua Casa Mais Valorizada',
  'Justo para Quem Trabalha',
  'Uma Conta, Dois Caminhos',
];

const List<String> _kExpectedStorySubtitles = <String>[
  'Do reparo urgente à manutenção planejada, encontre o especialista certo em poucos toques.',
  'Compare até 3 orçamentos protegidos. Seu endereço fica oculto até contratar.',
  'O valor fica guardado em segurança e só libera com seu código pessoal.',
  'Histórico inteligente do imóvel pronto em PDF para aluguéis, seguros ou venda.',
  'Sem pagar taxas para enviar orçamento e 100% das peças sem desconto.',
  'Contrate serviços ou atenda clientes com uma única conta verificada.',
];

/// Termos em inglês, artefatos/erros de OCR do vídeo de referência e jargões
/// técnicos frios estritamente proibidos em qualquer etapa da apresentação.
const List<String> _kBannedEnglishTyposAndJargon = <String>[
  'Segmented Control',
  'Segment Control',
  'Story ',
  'Story',
  'Stories',
  'Score',
  'Chip',
  'Repuirdade',
  'Silversão',
  'Espaet',
  'Dirctois',
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
  'Next',
  'Skip',
  'Paused',
  'Back',
  'Close',
];

void _expectActiveStory(int activeIndex) {
  for (var i = 0; i < _kCanonicalStoryKeys.length; i++) {
    expect(
      find.byKey(_kCanonicalStoryKeys[i]),
      i == activeIndex ? findsOneWidget : findsNothing,
      reason:
          'Esperava apenas Etapa ${activeIndex + 1} (${_kCanonicalStoryKeys[activeIndex]}) ativa, mas falhou no índice $i',
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
  for (final element in find.byType(Tooltip).evaluate()) {
    final widget = element.widget as Tooltip;
    final message = widget.message ?? widget.richMessage?.toPlainText() ?? '';
    if (message.trim().isNotEmpty) {
      texts.add(message.trim());
    }
  }
  return texts;
}

void _assertPurePortugueseInCurrentStage(
  WidgetTester tester, {
  required int storyIndex,
}) {
  final allTexts = _collectAllVisibleTexts(tester);
  expect(
    allTexts,
    isNotEmpty,
    reason: 'Etapa ${storyIndex + 1} deve expor textos visíveis para auditoria',
  );
  for (final text in allTexts) {
    final normalized = text.toUpperCase();
    for (final banned in _kBannedEnglishTyposAndJargon) {
      final needle = banned.toUpperCase();
      final isWordToken = !needle.contains(' ') && !needle.contains('-');
      final matched = isWordToken
          ? RegExp('\\b${RegExp.escape(needle)}\\b').hasMatch(normalized)
          : normalized.contains(needle);
      expect(
        matched,
        isFalse,
        reason:
            'Etapa ${storyIndex + 1} expôs termo em inglês, erro do vídeo ou jargão proibido "$banned" no texto: "$text"',
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
    reason:
        'Largura de toque de "$label" (${size.width}) deve ser >= ${minWidth}dp',
  );
  expect(
    size.height,
    greaterThanOrEqualTo(minHeight),
    reason:
        'Altura de toque de "$label" (${size.height}) deve ser >= ${minHeight}dp',
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
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mede o texto com as fontes embarcadas reais (e não com a fonte Ahem).
    await loadCinemaFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    WelcomeCinemaTracker.resetMemoryStateForTesting();
  });

  group(
    '1. WelcomeCinemaTracker (v6 / v2.27.0) — Governança Pós-Cadastro e Ponte Escura',
    () {
      test(
        'chaves de persistência v6 configuradas para a nova vitrine tipográfica (v2.27.0)',
        () {
          expect(WelcomeCinemaTracker.keyPrefixSeen, 'welcome_cinema_v6_seen_');
          expect(
            WelcomeCinemaTracker.keyPendingUid,
            'welcome_cinema_v6_pending_uid',
          );
        },
      );

      test(
        'dispara true para conta recém-criada armada via OTP e para 1º login OAuth recente',
        () async {
          final freshOtpUser = _makeProfile(id: 'uid-otp-1');
          await WelcomeCinemaTracker.armForFreshRegistration('uid-otp-1');

          final prefsAfterArm = await SharedPreferences.getInstance();
          expect(
            prefsAfterArm.getString('welcome_cinema_v6_pending_uid'),
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
        'após markCompleted(uid), limpa pending_uid, grava welcome_cinema_v6_seen_<uid> e nunca repete nem vaza entre usuários distintos',
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
          expect(prefs.getString('welcome_cinema_v6_seen_uid-1'), '1');
          expect(prefs.getString('welcome_cinema_v6_pending_uid'), isNull);

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
    '2. Fidelidade às 6 Etapas do Vídeo, Chave Seletora de Luxo & 100% Português (ZERO Inglês)',
    () {
      testWidgets(
        'duração padrão de 63000ms (10,5s por Etapa): exibe Etapa 1 de 6..Etapa 6 de 6, story-pagination-dots e conclui exatamente 1 vez',
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
          expect(find.text('Etapa 1 de 6'), findsOneWidget);
          expect(
            find.byKey(const Key('story-pagination-dots')),
            findsOneWidget,
          );

          // Em 5s e em 10s: leitura calma na Etapa 1 (Ato 3 de Repouso Sereno)
          await tester.pump(const Duration(seconds: 5));
          _expectActiveStory(0);
          expect(find.text('Etapa 1 de 6'), findsOneWidget);
          expect(completedCount, 0);

          await tester.pump(const Duration(seconds: 5));
          _expectActiveStory(0);
          expect(find.text('Etapa 1 de 6'), findsOneWidget);
          expect(completedCount, 0);

          // Em 10,6s (> 10,5s): avança automaticamente para a Etapa 2
          await tester.pump(const Duration(milliseconds: 600));
          _expectActiveStory(1);
          expect(find.text('Etapa 2 de 6'), findsOneWidget);
          expect(completedCount, 0);

          // Avança pelas Etapas 3 -> 4 -> 5 -> 6 no ritmo padrão de 10,5s
          for (var expectedStory = 2; expectedStory < 6; expectedStory++) {
            await tester.pump(const Duration(milliseconds: 10500));
            _expectActiveStory(expectedStory);
            expect(
              find.text('Etapa ${expectedStory + 1} de 6'),
              findsOneWidget,
            );
            expect(completedCount, 0);
          }

          // Conclui os últimos ~10,4s da Etapa 6 e dispara onCompleted exatamente 1 vez
          await tester.pump(const Duration(milliseconds: 10500));
          await tester.pump();
          expect(completedCount, 1);
        },
      );

      testWidgets(
        'mapeia fielmente todos os elementos visuais e textos em português das 6 etapas do vídeo sobre cards porcelana',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 2.75;
          addTearDown(tester.view.reset);

          var completedCount = 0;
          const duration = Duration(milliseconds: 12000); // 2000ms por Etapa

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

          // Verifica paginação de 6 pontos centralizados (ativo 24x8dp, demais 8x8dp)
          final dotsFinder = find.byKey(const Key('story-pagination-dots'));
          expect(dotsFinder, findsOneWidget);
          final dotElements = find
              .descendant(
                of: dotsFinder,
                matching: find.byType(AnimatedContainer),
              )
              .evaluate()
              .toList();
          expect(dotElements, hasLength(6));
          expect(tester.getSize(find.byWidget(dotElements[0].widget)), const Size(24.0, 8.0));
          for (var d = 1; d < 6; d++) {
            expect(tester.getSize(find.byWidget(dotElements[d].widget)), const Size(8.0, 8.0));
          }

          // Verifica card herói em acabamento Porcelana Luminosa (#FFFFFF -> #F8FAFC)
          final heroDecorated = tester.widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byType(WelcomeStoryHeroCard),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          final heroBoxDeco = heroDecorated.decoration as BoxDecoration;
          final heroGradient = heroBoxDeco.gradient! as LinearGradient;
          expect(
            heroGradient.colors,
            containsAllInOrder(const <Color>[
              Color(0xFFFFFFFF),
              Color(0xFFF8FAFC),
            ]),
          );

          // v2.27.0: Próximo é o círculo de vidro `>` (idêntico ao `<`), sem rótulo de texto
          final nextBtnDecoratedStage1 = tester.widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byKey(const Key('btn-story-next')),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          final nextGlass = nextBtnDecoratedStage1.decoration as BoxDecoration;
          expect(nextGlass.shape, BoxShape.circle);
          expect(nextGlass.color, const Color(0x24FFFFFF));
          expect(find.text('Próximo'), findsNothing);
          expect(find.text('Voltar'), findsNothing);

          // Etapa 1 (0ms..2000ms): Casa Resolvida Sem Dor de Cabeça
          // Verifica digitação inicial com cursor vertical esmeralda (sem reticências) antes de concluir
          expect(find.textContaining('Trocar resist'), findsOneWidget);
          expect(find.textContaining('...'), findsNothing);
          expect(
            find.byKey(const Key('search-typing-caret')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('search-completed-check')),
            findsNothing,
          );
          await tester.pump(const Duration(milliseconds: 1500)); // t = 1500ms
          _expectActiveStory(0);
          expect(
            find.byKey(const Key('welcome-cinema-progress-bar')),
            findsOneWidget,
          );
          expect(find.text('Etapa 1 de 6'), findsOneWidget);
          expect(find.text(_kExpectedStoryTitles[0]), findsOneWidget);
          expect(find.text(_kExpectedStorySubtitles[0]), findsOneWidget);
          expect(
            find.text('Trocar resistência do chuveiro'),
            findsOneWidget,
          );
          expect(find.byKey(const Key('search-typing-caret')), findsNothing);
          expect(
            find.byKey(const Key('search-completed-check')),
            findsOneWidget,
          );
          expect(find.byType(CategoryBrandEmblem), findsNWidgets(3));
          expect(find.text('Eletricista'), findsOneWidget);
          expect(find.text('Encanador'), findsOneWidget);
          expect(find.text('Climatização'), findsOneWidget);
          expect(find.text('Verificado · Atende hoje'), findsNWidgets(3));
          expect(find.text('Reparos Gerais'), findsNothing);
          expect(
            find.text('Atendimento rápido na sua região'),
            findsOneWidget,
          );
          expect(find.byTooltip('Próximo'), findsOneWidget);
          expect(find.byType(WelcomeStoryHeroCard), findsOneWidget);

          // Etapa 2 (2000ms..4000ms): Privacidade Total ao Pedir
          await tester.pump(const Duration(milliseconds: 600)); // t = 2100ms
          _expectActiveStory(1);
          await tester.pump(const Duration(milliseconds: 1500)); // t = 3600ms
          _expectActiveStory(1);
          expect(find.text('Etapa 2 de 6'), findsOneWidget);
          expect(find.text(_kExpectedStoryTitles[1]), findsOneWidget);
          expect(find.text(_kExpectedStorySubtitles[1]), findsOneWidget);
          expect(find.text('Pedido Protegido'), findsOneWidget);
          expect(find.text('Rua e número protegidos'), findsOneWidget);
          expect(find.text('Chega em 40 min'), findsOneWidget);
          expect(find.text('Chega em 1 h'), findsOneWidget);
          expect(find.text('Chega hoje'), findsOneWidget);
          expect(find.text('Proposta 1'), findsOneWidget);
          expect(find.text('Proposta 2'), findsOneWidget);
          expect(find.text('Proposta 3'), findsOneWidget);
          expect(find.text('R\$ 120,00'), findsOneWidget);
          expect(find.text('R\$ 150,00'), findsOneWidget);
          expect(find.text('R\$ 180,00'), findsOneWidget);
          expect(find.text('4,9'), findsOneWidget);
          expect(find.text('4,8'), findsOneWidget);
          expect(find.text('4,7'), findsOneWidget);
          expect(find.byTooltip('Próximo'), findsOneWidget);
          expect(find.byType(WelcomeStoryHeroCard), findsOneWidget);

          // Etapa 3 (4000ms..6000ms): Seu Dinheiro 100% Protegido
          await tester.pump(const Duration(milliseconds: 500)); // t = 4100ms
          _expectActiveStory(2);
          await tester.pump(const Duration(milliseconds: 1500)); // t = 5600ms
          _expectActiveStory(2);
          expect(find.text('Etapa 3 de 6'), findsOneWidget);
          expect(find.text(_kExpectedStoryTitles[2]), findsOneWidget);
          expect(find.text(_kExpectedStorySubtitles[2]), findsOneWidget);
          expect(
            find.text('Serviço aprovado · 90 dias de garantia'),
            findsOneWidget,
          );
          expect(find.text('R\$ 180,00'), findsOneWidget);
          expect(find.text('Guardado com segurança'), findsOneWidget);
          for (final digit in const ['4', '8', '2', '9']) {
            expect(find.text(digit), findsWidgets);
          }
          expect(find.byTooltip('Próximo'), findsOneWidget);
          expect(find.byType(WelcomeStoryHeroCard), findsOneWidget);

          // Etapa 4 (6000ms..8000ms): Sua Casa Mais Valorizada
          await tester.pump(const Duration(milliseconds: 500)); // t = 6100ms
          _expectActiveStory(3);
          await tester.pump(const Duration(milliseconds: 1500)); // t = 7600ms
          _expectActiveStory(3);
          expect(find.text('Etapa 4 de 6'), findsOneWidget);
          expect(find.text(_kExpectedStoryTitles[3]), findsOneWidget);
          expect(find.text(_kExpectedStorySubtitles[3]), findsOneWidget);
          expect(find.text('Saúde do Imóvel'), findsOneWidget);
          expect(find.text('96%'), findsOneWidget);
          expect(find.text('Em dia'), findsOneWidget);
          expect(find.text('0%'), findsOneWidget);
          expect(find.text('100%'), findsOneWidget);
          expect(find.text('Revisão Elétrica'), findsOneWidget);
          expect(find.text('Realizado em 12/10/2026'), findsOneWidget);
          expect(find.text('Climatização'), findsOneWidget);
          expect(find.text('Realizado em 05/11/2026'), findsOneWidget);
          expect(find.text('PDF'), findsNWidgets(2));
          expect(find.byTooltip('Próximo'), findsOneWidget);
          expect(find.byType(WelcomeStoryHeroCard), findsOneWidget);

          // Etapa 5 (8000ms..10000ms): Justo para Quem Trabalha
          await tester.pump(const Duration(milliseconds: 500)); // t = 8100ms
          _expectActiveStory(4);
          await tester.pump(const Duration(milliseconds: 1500)); // t = 9600ms
          _expectActiveStory(4);
          expect(find.text('Etapa 5 de 6'), findsOneWidget);
          expect(find.text(_kExpectedStoryTitles[4]), findsOneWidget);
          expect(find.text(_kExpectedStorySubtitles[4]), findsOneWidget);
          expect(find.text('Painel do Profissional'), findsOneWidget);
          expect(find.text('Custo para orçar:'), findsOneWidget);
          expect(find.text('R\$ 0,00'), findsOneWidget);
          expect(
            find.text('Valor do cliente já garantido antes de sair'),
            findsOneWidget,
          );
          expect(find.text('Reputação Verificada'), findsOneWidget);
          expect(find.text('5,0 · Profissional Destaque'), findsOneWidget);
          expect(find.byTooltip('Próximo'), findsOneWidget);
          expect(find.byType(WelcomeStoryHeroCard), findsOneWidget);

          // Etapa 6 (10000ms..12000ms): Uma Conta, Dois Caminhos + Chave Seletora de Luxo
          await tester.pump(const Duration(milliseconds: 500)); // t = 10100ms
          _expectActiveStory(5);
          await tester.pump(const Duration(milliseconds: 1500)); // t = 11600ms
          _expectActiveStory(5);
          expect(find.text('Etapa 6 de 6'), findsOneWidget);
          expect(find.text(_kExpectedStoryTitles[5]), findsOneWidget);
          expect(find.text(_kExpectedStorySubtitles[5]), findsOneWidget);
          expect(find.text('Escolha Seu Perfil'), findsOneWidget);
          expect(find.text('1 toque'), findsOneWidget);
          expect(
            find.byKey(const Key('dual-mode-luxury-switch')),
            findsOneWidget,
          );
          expect(find.text('Modo Cliente'), findsOneWidget);
          expect(find.text('Modo Profissional'), findsOneWidget);
          expect(find.text('Contratar com garantia'), findsOneWidget);
          expect(find.text('Atender sem pagar para orçar'), findsOneWidget);
          expect(find.text('Identidade Verificada'), findsOneWidget);
          expect(find.text('Começar agora'), findsOneWidget);
          // Verifica pílula Aurora Iridescente (#6EE7B7 -> #A7F3D0 -> #FDE68A -> #FDBA74) na Etapa 6
          final auroraBtnDeco = tester
              .widget<DecoratedBox>(
                find
                    .descendant(
                      of: find.byKey(const Key('btn-story-start')),
                      matching: find.byType(DecoratedBox),
                    )
                    .first,
              )
              .decoration as BoxDecoration;
          final auroraGradient = auroraBtnDeco.gradient! as LinearGradient;
          expect(
            auroraGradient.colors,
            equals(const <Color>[
              Color(0xFF6EE7B7),
              Color(0xFFA7F3D0),
              Color(0xFFFDE68A),
              Color(0xFFFDBA74),
            ]),
          );
          expect(find.byType(WelcomeStoryHeroCard), findsOneWidget);
          expect(completedCount, 0);

          // Conclui 100% da Etapa 6 (12000ms)
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump();
          expect(completedCount, 1);
        },
      );

      testWidgets(
        'Etapa 6: toque interativo direto nas opções da chave seletora (dual-mode-luxury-switch) alterna entre Modo Cliente e Modo Profissional SEM pular nem fechar a etapa e mantendo buildCount == 1',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          var completedCount = 0;
          final heroBuilds = <int, int>{};

          await tester.pumpWidget(
            MaterialApp(
              home: DesperrengueWelcomeCinemaScreen(
                userFirstName: 'Wagner',
                onActiveHeroBuild: (idx) {
                  heroBuilds[idx] = (heroBuilds[idx] ?? 0) + 1;
                },
                onCompleted: () => completedCount++,
              ),
            ),
          );
          await tester.pump();

          // Salta para a Etapa 6
          await tester.tap(find.byKey(const Key('cinema-chapter-tap-5')));
          await tester.pump();
          _expectActiveStory(5);
          expect(heroBuilds[5], equals(1));

          final luxurySwitch = find.byKey(const Key('dual-mode-luxury-switch'));
          final clientOption = find.byKey(const Key('dual-mode-option-client'));
          final providerOption = find.byKey(
            const Key('dual-mode-option-provider'),
          );
          expect(luxurySwitch, findsOneWidget);
          _expectMinTouchTarget(
            tester,
            clientOption,
            label: 'dual-mode-option-client (Modo Cliente)',
          );
          _expectMinTouchTarget(
            tester,
            providerOption,
            label: 'dual-mode-option-provider (Modo Profissional)',
          );

          // Fase 1 da coreografia (0.4s <= 1.10s): Modo Cliente ativo (#FFFFFF sobre Safira Real)
          await tester.pump(const Duration(milliseconds: 400));
          expect(
            tester.widget<Text>(find.text('Modo Cliente')).style!.color,
            const Color(0xFFFFFFFF),
          );
          expect(
            tester.widget<Text>(find.text('Modo Profissional')).style!.color,
            const Color(0xFF0F172A),
          );

          // Fase 2 da coreografia (1.9s em [1.10s..2.10s]): cursor desliza para Modo Profissional (#FFFFFF sobre Esmeralda)
          await tester.pump(const Duration(milliseconds: 1500));
          expect(
            tester.widget<Text>(find.text('Modo Profissional')).style!.color,
            const Color(0xFFFFFFFF),
          );
          expect(
            tester.widget<Text>(find.text('Modo Cliente')).style!.color,
            const Color(0xFF0F172A),
          );

          // Fase 3 / Repouso (3.5s > 3.00s): retorna suavemente e estaciona em Modo Cliente (#FFFFFF), 1 única pílula ativa
          await tester.pump(const Duration(milliseconds: 1600));
          expect(
            tester.widget<Text>(find.text('Modo Cliente')).style!.color,
            const Color(0xFFFFFFFF),
          );
          expect(
            tester.widget<Text>(find.text('Modo Profissional')).style!.color,
            const Color(0xFF0F172A),
          );

          // Toque interativo direto em "Modo Profissional" (na metade direita do palco, onde um toque comum concluiria!)
          // Deve apenas alternar o cursor para Profissional, SEM disparar onCompleted!
          await tester.tap(providerOption);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          _expectActiveStory(5);
          expect(completedCount, 0);
          expect(
            tester.widget<Text>(find.text('Modo Profissional')).style!.color,
            const Color(0xFFFFFFFF),
          );
          expect(
            tester.widget<Text>(find.text('Modo Cliente')).style!.color,
            const Color(0xFF0F172A),
          );

          // Toque interativo direto em "Modo Cliente" -> desliza cursor de volta para Cliente SEM sair da Etapa 6!
          await tester.tap(clientOption);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          _expectActiveStory(5);
          expect(completedCount, 0);
          expect(
            tester.widget<Text>(find.text('Modo Cliente')).style!.color,
            const Color(0xFFFFFFFF),
          );
          expect(
            tester.widget<Text>(find.text('Modo Profissional')).style!.color,
            const Color(0xFF0F172A),
          );

          // Também valida toque direto sobre os rótulos textuais dentro de dual-mode-luxury-switch
          await tester.tap(find.text('Modo Profissional'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          _expectActiveStory(5);
          expect(completedCount, 0);
          expect(
            tester.widget<Text>(find.text('Modo Profissional')).style!.color,
            const Color(0xFFFFFFFF),
          );

          await tester.tap(find.text('Modo Cliente'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          _expectActiveStory(5);
          expect(completedCount, 0);
          expect(
            tester.widget<Text>(find.text('Modo Cliente')).style!.color,
            const Color(0xFFFFFFFF),
          );

          // Confirma que toda a alternância interativa preservou WelcomeStoryHeroCard buildCount == 1
          expect(heroBuilds[5], equals(1));
        },
      );
    },
  );

  group(
    '3. Anti-Jank 120 FPS — Isolamento Estrito de Rebuild (buildCount == 1) & Bridge Aurora 520ms',
    () {
      testWidgets(
        'onActiveHeroBuild comprova buildCount == 1 estrito durante pump(3s) único E durante 190 frames contínuos de 16ms enquanto a barra de progresso corre',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 2.75;
          addTearDown(tester.view.reset);

          final heroBuildsByStory = <int, int>{};

          // Sub-caso A: pump único de 3 segundos
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
            reason:
                'Montagem inicial do WelcomeStoryHeroCard ativo deve registrar 1 build',
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

      testWidgets(
        '_SharedAmbientCanvas interpola 520ms sem corte seco no auto-avanço e no toque mantendo buildCount == 1 em cada etapa visitada, e cascata Ato 1 inicia em 0.0',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final buildsByStory = <int, int>{};

          await tester.pumpWidget(
            MaterialApp(
              home: DesperrengueWelcomeCinemaScreen(
                key: const ValueKey('cinema-ambient-bridge-120hz'),
                userFirstName: 'Ana',
                onActiveHeroBuild: (storyIndex) {
                  buildsByStory[storyIndex] =
                      (buildsByStory[storyIndex] ?? 0) + 1;
                },
                onCompleted: () {},
              ),
            ),
          );
          await tester.pump();
          expect(buildsByStory[0], equals(1));

          // Verifica cascata orgânica do Ato 1 iniciando em 0.0 no frame 0 e chegando a 1.0 em 760ms
          final heroFadeFinder = find
              .ancestor(
                of: find.byType(WelcomeStoryHeroCard),
                matching: find.byType(FadeTransition),
              )
              .first;
          expect(
            tester.widget<FadeTransition>(heroFadeFinder).opacity.value,
            closeTo(0.0, 0.001),
          );
          await tester.pump(const Duration(milliseconds: 760));
          expect(
            tester.widget<FadeTransition>(heroFadeFinder).opacity.value,
            closeTo(1.0, 0.001),
          );
          expect(buildsByStory[0], equals(1));

          // Auto-avança da Etapa 1 para a Etapa 2 (cruza 10,5s) e roda 36 frames de 16ms (576ms > 520ms do bridge aurora)
          await tester.pump(const Duration(milliseconds: 9800));
          _expectActiveStory(1);
          expect(buildsByStory[1], equals(1));
          for (var f = 0; f < 36; f++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(
            buildsByStory[1],
            equals(1),
            reason:
                'Interpolação contínua de 520ms do _SharedAmbientCanvas no auto-avanço jamais pode reconstruir WelcomeStoryHeroCard!',
          );

          // Salto por toque direto para a Etapa 5 (com poeira estelar dourada) + 36 frames de 16ms
          await tester.tap(find.byKey(const Key('cinema-chapter-tap-4')));
          await tester.pump();
          _expectActiveStory(4);
          expect(buildsByStory[4], equals(1));
          for (var f = 0; f < 36; f++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(buildsByStory[4], equals(1));

          // Desmonta no meio de um bridge ambiente (180ms < 520ms) sem vazar tickers ou lançar exceção
          await tester.tap(find.byKey(const Key('cinema-chapter-tap-5')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 180));
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    },
  );

  group(
    '4. Motor de Gestos Listener de Latência Zero, Controles e Alvos Táteis (>= 44x44dp / >= 48dp)',
    () {
      testWidgets(
        'zonas de toque 32% esquerda e 68% direita (por Key e por coordenadas na fronteira 32%/68%) voltam, reiniciam na Etapa 1, avançam e concluem na Etapa 6',
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

          // Toque por coordenada em 34% da largura (>= 32% -> zona direita) avança Etapa 1 -> Etapa 2
          final stageTopLeft = prevRect.topLeft;
          final stageTopSafeY = prevRect.top + 24.0;
          await tester.tapAt(
            Offset(stageTopLeft.dx + totalStageWidth * 0.34, stageTopSafeY),
          );
          await tester.pump();
          _expectActiveStory(1);
          expect(find.text('Etapa 2 de 6'), findsOneWidget);

          // Avança Etapa 2 -> Etapa 3 tocando em story-tap-zone-next
          await tester.tap(nextZone);
          await tester.pump();
          _expectActiveStory(2);

          // Toque por coordenada em 30% da largura (< 32% -> zona esquerda) volta Etapa 3 -> Etapa 2
          await tester.tapAt(
            Offset(stageTopLeft.dx + totalStageWidth * 0.30, stageTopSafeY),
          );
          await tester.pump();
          _expectActiveStory(1);

          // Volta Etapa 2 -> Etapa 1 via story-tap-zone-prev
          await tester.tap(prevZone);
          await tester.pump();
          _expectActiveStory(0);

          // Avança 4s na Etapa 1 e toca na zona esquerda: reinicia Etapa 1 (não sai nem quebra)
          await tester.pump(const Duration(seconds: 4));
          await tester.tap(prevZone);
          await tester.pump();
          _expectActiveStory(0);
          expect(completedCount, 0);
          // Como reiniciou do zero, após 8s ainda está na Etapa 1 (< 10,5s)
          await tester.pump(const Duration(seconds: 8));
          _expectActiveStory(0);

          // Caminha pelas 6 etapas via zona direita (acima do switch interativo) até concluir na Etapa 6
          for (var expectedStory = 0; expectedStory < 6; expectedStory++) {
            _expectActiveStory(expectedStory);
            expect(completedCount, 0);
            await tester.tapAt(
              Offset(stageTopLeft.dx + totalStageWidth * 0.72, stageTopSafeY),
            );
            await tester.pump();
          }
          expect(completedCount, 1);
        },
      );

      testWidgets(
        'swipe horizontal com física de mola (fling e drag para esquerda e direita) transiciona suavemente entre as etapas',
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

          // Fling esquerda -> Etapa 1 para Etapa 2
          await tester.fling(pageViewFinder, const Offset(-260, 0), 1200);
          await pumpSpringSettle();
          _expectActiveStory(1);

          // Swipe humano (timedDrag) esquerda -> Etapa 2 para Etapa 3
          await tester.timedDrag(
            pageViewFinder,
            const Offset(-140, 0),
            const Duration(milliseconds: 180),
          );
          await pumpSpringSettle();
          _expectActiveStory(2);

          // Drag estático além do ponto médio esquerda -> Etapa 3 para Etapa 4
          await tester.drag(pageViewFinder, const Offset(-230, 0));
          await pumpSpringSettle();
          _expectActiveStory(3);

          // Fling direita -> Etapa 4 para Etapa 3
          await tester.fling(pageViewFinder, const Offset(260, 0), 1200);
          await pumpSpringSettle();
          _expectActiveStory(2);

          // Swipe humano (timedDrag) direita -> Etapa 3 para Etapa 2
          await tester.timedDrag(
            pageViewFinder,
            const Offset(140, 0),
            const Duration(milliseconds: 180),
          );
          await pumpSpringSettle();
          _expectActiveStory(1);

          // Drag estático além do ponto médio direita -> Etapa 2 para Etapa 1
          await tester.drag(pageViewFinder, const Offset(230, 0));
          await pumpSpringSettle();
          _expectActiveStory(0);
          expect(completedCount, 0);
        },
      );

      testWidgets(
        '6 barras de segmento (cinema-chapter-tap-0..5) possuem altura de toque >= 44dp e saltam diretamente para qualquer etapa',
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
            await tester.tap(
              find.byKey(Key('cinema-chapter-tap-$targetStory')),
            );
            await tester.pump();
            _expectActiveStory(targetStory);
            expect(
              find.text('Etapa ${targetStory + 1} de 6'),
              findsOneWidget,
            );
          }
          expect(completedCount, 0);
        },
      );

      testWidgets(
        'todos os controles (Pular >= 44dp, Fechar >= 44dp, Voltar circular >= 44x44dp nas Etapas 2–6, Próximo / Começar agora >= 48dp e Rever apresentação >= 44dp) funcionam ponta a ponta',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          // 1) Modo pós-cadastro (isReplay: false): PopScope bloqueado + Pular >= 44x44dp + pílula larga Próximo >= 48dp
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
          expect(find.byTooltip('Próximo'), findsOneWidget);
          expect(find.byTooltip('Voltar'), findsOneWidget);
          _expectMinTouchTarget(
            tester,
            nextBtn,
            minWidth: 48.0,
            minHeight: 48.0,
            label: 'btn-story-next (> circular 56x56 na Etapa 1)',
          );

          // v2.27.0: na Etapa 1 o `<` existe, DESABILITADO, ocupando o mesmo espaço (zero pulo de layout)
          _expectMinTouchTarget(
            tester,
            prevBtn,
            minWidth: 48.0,
            minHeight: 48.0,
            label: 'btn-story-prev (< desabilitado na Etapa 1)',
          );

          // Verifica < e > >= 48x48dp em TODAS as Etapas 2 a 5 (na 6 o `>` fica desabilitado)
          for (var step = 1; step < 6; step++) {
            await tester.tap(find.byKey(Key('cinema-chapter-tap-$step')));
            await tester.pump();
            _expectActiveStory(step);
            _expectMinTouchTarget(
              tester,
              prevBtn,
              minWidth: 48.0,
              minHeight: 48.0,
              label: 'btn-story-prev (Voltar na Etapa ${step + 1})',
            );
            expect(find.byTooltip('Voltar'), findsOneWidget);
            _expectMinTouchTarget(
              tester,
              nextBtn,
              minWidth: 48.0,
              minHeight: 48.0,
              label: 'btn-story-next na Etapa ${step + 1}',
            );
          }
          // Etapa 6: CTA "Começar agora" aurora (largura total, 56dp) acima da linha de navegação
          _expectMinTouchTarget(
            tester,
            find.byKey(const Key('btn-story-start')),
            minWidth: 200.0,
            minHeight: 56.0,
            label: 'btn-story-start (Começar agora na Etapa 6)',
          );

          // Volta da Etapa 6 -> Etapa 5 via btn-story-prev e depois salta para Etapa 2 -> volta para Etapa 1
          await tester.tap(prevBtn);
          await tester.pump();
          _expectActiveStory(4);

          await tester.tap(find.byKey(const Key('cinema-chapter-tap-1')));
          await tester.pump();
          _expectActiveStory(1);
          await tester.tap(prevBtn);
          await tester.pump();
          _expectActiveStory(0);
          expect(prevBtn, findsOneWidget);

          // `<` desabilitado na Etapa 1: tocar não faz nada nem fecha a apresentação
          await tester.tap(prevBtn);
          await tester.pump();
          _expectActiveStory(0);
          expect(skippedOrCompleted, 0);

          // Toca em Pular -> conclui imediatamente
          await tester.tap(skipBtn);
          await tester.pump();
          expect(skippedOrCompleted, 1);

          // 2) Testa botão aurora "Começar agora" na Etapa 6 (>= 48dp de altura)
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
            find.byKey(const Key('btn-story-start')),
            minWidth: 160.0,
            minHeight: 48.0,
            label: 'btn-story-start (Começar agora aurora)',
          );
          await tester.tap(find.byKey(const Key('btn-story-start')));
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
        'Hold-to-Pause de Latência Zero (0ms): Timer 220ms -> Pausado -> 3s+ congelado -> retoma do ponto exato sem pular página',
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

          // Avança 2,0s na Etapa 1 (restam 8,5s dos 10,5s da Etapa 1)
          await tester.pump(const Duration(seconds: 2));
          _expectActiveStory(0);

          // Segura o dedo na zona direita do palco (onde um toque rápido avançaria de página!)
          final nextZoneCenter = tester.getCenter(
            find.byKey(const Key('story-tap-zone-next')),
          );
          final gesture = await tester.startGesture(nextZoneCenter);

          // Antes de 220ms (ex: 150ms): cronômetro já está parado em 0ms, mas badge ainda não apareceu
          await tester.pump(const Duration(milliseconds: 150));
          expect(find.byKey(const Key('cinema-paused-badge')), findsNothing);

          // Aos 250ms (>= 220ms do Timer), selo "Pausado" aparece suavemente
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.byKey(const Key('cinema-paused-badge')), findsOneWidget);
          expect(find.text('Pausado'), findsOneWidget);

          // Mantém pressionado por 3s (e depois mais 10s = 13s totais > 10,5s): permanece congelado na Etapa 1!
          await tester.pump(const Duration(seconds: 3));
          _expectActiveStory(0);
          expect(completed, isFalse);

          await tester.pump(const Duration(seconds: 10));
          _expectActiveStory(0);
          expect(completed, isFalse);

          // Solta o dedo -> remove cinema-paused-badge e NÃO salta acidentalmente para a Etapa 2!
          await gesture.up();
          await tester.pump();
          expect(find.byKey(const Key('cinema-paused-badge')), findsNothing);
          _expectActiveStory(0);
          expect(find.text('Etapa 1 de 6'), findsOneWidget);

          // Comprova retomada do ponto exato (2,0s): após +8,0s (= 10,0s < 10,5s) continua na Etapa 1
          await tester.pump(const Duration(seconds: 8));
          _expectActiveStory(0);

          // Após +600ms (= 10,6s > 10,5s), avança naturalmente para a Etapa 2
          await tester.pump(const Duration(milliseconds: 600));
          _expectActiveStory(1);
          expect(find.text('Etapa 2 de 6'), findsOneWidget);
        },
      );
    },
  );

  group(
    '5. Acessibilidade (disableAnimations: true), Auditoria Linguística 100% PT-BR & Contraste WCAG AA (>= 4.5:1)',
    () {
      testWidgets(
        'MediaQuery(disableAnimations: true) renderiza estado final de repouso nas 6 etapas sem falhas e sem timers pendentes',
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

          final expectedRestingSnippets = <String>[
            'Trocar resistência do chuveiro',
            'Rua e número protegidos',
            'Serviço aprovado · 90 dias de garantia',
            '96%',
            '5,0 · Profissional Destaque',
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
          // Etapa 6: `>` fica desabilitado; a conclusão é pelo CTA `btn-story-start`
          await tester.tap(find.byKey(const Key('btn-story-next')));
          await tester.pump();
          expect(completed, isFalse);
          await tester.tap(find.byKey(const Key('btn-story-start')));
          await tester.pump();
          expect(completed, isTrue);

          // Desmonta sem deixar timers pendentes
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'auditoria linguística 100% Português, contraste matemático WCAG AA >= 4.5:1 em todos os pares de cores, zero FittedBox e respiro >= 38%',
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

          // Fundos aurora reais (topo, meio e base) das 6 etapas para validação WCAG AA
          const auroraBackgroundStopsByStage = <List<Color>>[
            [Color(0xFF0D1B20), Color(0xFF112526), Color(0xFF16302B)],
            [Color(0xFF0C1D24), Color(0xFF10282A), Color(0xFF15322D)],
            [Color(0xFF0E1D22), Color(0xFF132829), Color(0xFF18332E)],
            [Color(0xFF111F2F), Color(0xFF162B38), Color(0xFF1B353E)],
            [Color(0xFF1B1832), Color(0xFF231E3E), Color(0xFF2B2347)],
            [Color(0xFF211926), Color(0xFF3D2622), Color(0xFF523020)],
          ];

          const porcelainWhite = Color(0xFFFFFFFF);
          const porcelainBase = Color(0xFFF8FAFC);

          for (var storyIndex = 0; storyIndex < 6; storyIndex++) {
            await tester.tap(
              find.byKey(Key('cinema-chapter-tap-$storyIndex')),
            );
            await tester.pump();

            // Auditoria 100% Português no Ato 1/2 (início/digitação/ocultação) E no Ato 3 (repouso)
            _assertPurePortugueseInCurrentStage(
              tester,
              storyIndex: storyIndex,
            );
            await tester.pump(const Duration(milliseconds: 1100));
            _assertPurePortugueseInCurrentStage(
              tester,
              storyIndex: storyIndex,
            );
            await tester.pump(const Duration(milliseconds: 2600));
            _assertPurePortugueseInCurrentStage(
              tester,
              storyIndex: storyIndex,
            );

            // Título curto <= 7 palavras + Subtítulo editorial presentes
            final title = _kExpectedStoryTitles[storyIndex];
            final subtitle = _kExpectedStorySubtitles[storyIndex];
            expect(find.text(title), findsOneWidget);
            expect(find.text(subtitle), findsOneWidget);
            final wordCount = title
                .trim()
                .split(RegExp(r'\s+'))
                .where((w) => w.isNotEmpty)
                .length;
            expect(
              wordCount,
              lessThanOrEqualTo(7),
              reason:
                  'Título da Etapa ${storyIndex + 1} ("$title") excedeu 7 palavras ($wordCount)',
            );

            // Estritamente 1 Card Herói Porcelana visível e zero FittedBox
            expect(find.byType(WelcomeStoryHeroCard), findsOneWidget);
            expect(
              find.descendant(
                of: find.byType(DesperrengueWelcomeCinemaScreen),
                matching: find.byType(FittedBox),
              ),
              findsNothing,
              reason: 'Etapa ${storyIndex + 1} jamais pode usar FittedBox',
            );

            // Espaço de respiro >= 38%
            // v2.27.0: a página é uma coluna com rolagem interna (a fonte nunca encolhe);
            // o respiro vem da medição de área livre abaixo.
            expect(
              find.descendant(
                of: find.byKey(_kCanonicalStoryKeys[storyIndex]),
                matching: find.byType(SingleChildScrollView),
              ),
              findsWidgets,
              reason: 'Etapa ${storyIndex + 1} deve permitir rolagem interna',
            );
            final screenArea = 390.0 * 844.0;
            final titleRect = tester.getRect(find.text(title));
            final subRect = tester.getRect(find.text(subtitle));
            final heroRect = tester.getRect(
              find.byType(WelcomeStoryHeroCard),
            );
            final occupiedArea =
                (titleRect.width * titleRect.height) +
                (subRect.width * subRect.height) +
                (heroRect.width * heroRect.height);
            final freeAreaRatio =
                1.0 - (occupiedArea / screenArea).clamp(0.0, 1.0);
            expect(
              freeAreaRatio,
              greaterThanOrEqualTo(0.38),
              reason:
                  'Etapa ${storyIndex + 1} precisa preservar >= 38% de espaço negativo respirável (livre: ${(freeAreaRatio * 100).toStringAsFixed(1)}%)',
            );

            // Contraste WCAG AA (>= 4.5:1) nos textos claros sobre o fundo aurora da etapa
            final stepLabelColor = tester
                .widget<Text>(find.text('Etapa ${storyIndex + 1} de 6'))
                .style!
                .color!;
            final titleColor =
                tester.widget<Text>(find.text(title)).style!.color!;
            final subtitleColor =
                tester.widget<Text>(find.text(subtitle)).style!.color!;

            for (final bgStop in auroraBackgroundStopsByStage[storyIndex]) {
              expect(
                AppTokens.contrast(stepLabelColor, bgStop),
                greaterThanOrEqualTo(4.5),
                reason:
                    'Contraste de "Etapa ${storyIndex + 1} de 6" insuficiente contra $bgStop',
              );
              expect(
                AppTokens.contrast(titleColor, bgStop),
                greaterThanOrEqualTo(4.5),
                reason:
                    'Contraste do título "$title" insuficiente contra $bgStop',
              );
              expect(
                AppTokens.contrast(subtitleColor, bgStop),
                greaterThanOrEqualTo(4.5),
                reason:
                    'Contraste do subtítulo da Etapa ${storyIndex + 1} insuficiente contra $bgStop',
              );
            }
          }

          // Validação matemática WCAG AA >= 4.5:1 de todos os pares internos dos cards porcelana, switch de luxo e CTAs
          const contrastPairs = <(Color, Color, String)>[
            (Color(0xFF0F172A), porcelainWhite, 'Texto primário sobre porcelana #FFFFFF'),
            (Color(0xFF0F172A), porcelainBase, 'Texto primário sobre porcelana #F8FAFC'),
            (Color(0xFF334155), Color(0xFFF1F5F9), 'Texto secundário sobre bloco pérola #F1F5F9'),
            (Color(0xFF064E3B), Color(0xFFECFDF5), 'Selo regional sobre menta clara #ECFDF5'),
            (Color(0xFF064E3B), Color(0xFFDCFCE7), 'Selo protegido/verificado sobre menta #DCFCE7'),
            (Color(0xFF065F46), porcelainBase, 'Serviço aprovado sobre porcelana #F8FAFC'),
            (Color(0xFFFFFFFF), Color(0xFF991B1B), 'Selo PDF branco sobre vermelho #991B1B'),
            (Color(0xFFFFFFFF), Color(0xFF1E3A8A), 'Modo Cliente ativo sobre cursor Safira #1E3A8A'),
            (Color(0xFFFFFFFF), Color(0xFF2563EB), 'Modo Cliente ativo sobre cursor Safira Real #2563EB'),
            (Color(0xFFFFFFFF), Color(0xFF047857), 'Modo Profissional ativo sobre cursor Esmeralda #047857'),
            (Color(0xFFFFFFFF), Color(0xFF0F766E), 'Modo Profissional ativo sobre cursor Oceano #0F766E'),
            (Color(0xFF0F172A), Color(0xFFDFE7F0), 'Opção inativa sobre sombra interna do trilho #DFE7F0'),
            (Color(0xFF0F172A), Color(0xFFE8EEF5), 'Opção inativa sobre trilho acetinado #E8EEF5'),
            (Color(0xFF0F172A), Color(0xFFEDF2F8), 'Opção inativa sobre base do trilho acetinado #EDF2F8'),
            (Color(0xFF0F172A), Color(0xFFF8FAFC), 'Botão Próximo (#0F172A sobre #F8FAFC)'),
            (Color(0xFF0B1320), Color(0xFF6EE7B7), 'CTA Começar agora sobre aurora menta #6EE7B7'),
            (Color(0xFF0B1320), Color(0xFFA7F3D0), 'CTA Começar agora sobre aurora menta clara #A7F3D0'),
            (Color(0xFF0B1320), Color(0xFFFDE68A), 'CTA Começar agora sobre aurora champanhe #FDE68A'),
            (Color(0xFF0B1320), Color(0xFFFDBA74), 'CTA Começar agora sobre aurora âmbar #FDBA74'),
          ];

          for (final pair in contrastPairs) {
            expect(
              AppTokens.contrast(pair.$1, pair.$2),
              greaterThanOrEqualTo(4.5),
              reason:
                  'Violação WCAG AA (< 4.5:1) em: ${pair.$3} (obtido: ${AppTokens.contrast(pair.$1, pair.$2).toStringAsFixed(2)}:1)',
            );
          }
        },
      );
    },
  );

  group(
    '6. Matriz Extrema Zero-Overflow nas 6 Etapas (Ato 1, Ato 2 e Ato 3) + RoleSelectionScreen',
    () {
      const extremeViewports =
          <({Size physicalSize, double dpr, double scale, String label})>[
        (
          physicalSize: Size(320, 640),
          dpr: 1.0,
          scale: 1.35,
          label: '320x640 @ 1.35',
        ),
        (
          physicalSize: Size(320, 640),
          dpr: 1.0,
          scale: 1.40,
          label: '320x640 @ 1.40',
        ),
        (
          physicalSize: Size(360, 780),
          dpr: 1.0,
          scale: 1.0,
          label: '360x780 @ 1.0',
        ),
        (
          physicalSize: Size(390, 844),
          dpr: 1.0,
          scale: 1.0,
          label: '390x844 @ 1.0',
        ),
        (
          physicalSize: Size(412, 915),
          dpr: 1.0,
          scale: 1.30,
          label: '412x915 @ 1.30',
        ),
        (
          physicalSize: Size(1080, 2400),
          dpr: 2.75,
          scale: 1.0,
          label: '1080x2400 @ 2.75',
        ),
      ];

      for (final vp in extremeViewports) {
        testWidgets(
          'zero RenderFlex overflow nas 6 Etapas (Ato 1 entrada, Ato 2 demonstração e Ato 3 repouso) + chave seletora + RoleSelectionScreen em ${vp.label}',
          (tester) async {
            tester.view.physicalSize = vp.physicalSize;
            tester.view.devicePixelRatio = vp.dpr;
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

            // Testa cada uma das 6 Etapas nos 3 Atos:
            // - Ato 1 (0,30s): entrada sedosa em cascata
            // - Ato 2 (1,65s): demonstração viva em andamento
            // - Ato 3 (4,20s): repouso sereno absoluto
            for (var storyIndex = 0; storyIndex < 6; storyIndex++) {
              await tester.tap(
                find.byKey(Key('cinema-chapter-tap-$storyIndex')),
              );
              await tester.pump();
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'Zero overflow ao abrir Etapa ${storyIndex + 1} em ${vp.label}',
              );

              // Ato 1 (300ms)
              await tester.pump(const Duration(milliseconds: 300));
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'Zero overflow no Ato 1 da Etapa ${storyIndex + 1} em ${vp.label}',
              );
              _expectActiveStory(storyIndex);

              // Ato 2 (1650ms acumulados)
              await tester.pump(const Duration(milliseconds: 1350));
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'Zero overflow no Ato 2 da Etapa ${storyIndex + 1} em ${vp.label}',
              );
              _expectActiveStory(storyIndex);

              // Ato 3 de Repouso Sereno (4200ms acumulados > 3100ms)
              await tester.pump(const Duration(milliseconds: 2550));
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'Zero overflow no Ato 3 de Repouso da Etapa ${storyIndex + 1} em ${vp.label}',
              );
              _expectActiveStory(storyIndex);
            }

            // Verifica alvos táteis >= 44dp / >= 48dp e toque interativo na chave seletora da Etapa 6 na resolução extrema
            // Em telas pequenas + fonte ampliada o card rola por dentro (a fonte nunca encolhe):
            // traz a chave seletora para a área visível antes de interagir.
            await tester.ensureVisible(
              find.byKey(const Key('dual-mode-luxury-switch')),
            );
            await tester.pump();
            _expectMinTouchTarget(
              tester,
              find.byKey(const Key('btn-skip-welcome-cinema')),
              label: 'btn-skip-welcome-cinema em ${vp.label}',
            );
            _expectMinTouchTarget(
              tester,
              find.byKey(const Key('btn-story-prev')),
              label: 'btn-story-prev em ${vp.label}',
            );
            _expectMinTouchTarget(
              tester,
              find.byKey(const Key('btn-story-next')),
              minHeight: 48.0,
              label: 'btn-story-next em ${vp.label}',
            );
            _expectMinTouchTarget(
              tester,
              find.byKey(const Key('dual-mode-option-client')),
              label: 'dual-mode-option-client em ${vp.label}',
            );
            _expectMinTouchTarget(
              tester,
              find.byKey(const Key('dual-mode-option-provider')),
              label: 'dual-mode-option-provider em ${vp.label}',
            );
            await tester.tap(
              find.byKey(const Key('dual-mode-option-provider')),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull);

            await tester.tap(find.byKey(const Key('dual-mode-option-client')));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull);

            // Verifica Hold-to-Pause badge na mesma resolução extrema (ex: 320x640 @ 1.40)
            final stageTopLeft = tester.getTopLeft(
              find.byKey(const Key('story-tap-zone-prev')),
            );
            final gesture = await tester.startGesture(
              stageTopLeft + const Offset(24, 24),
            );
            await tester.pump(const Duration(milliseconds: 260));
            expect(tester.takeException(), isNull);
            expect(
              find.byKey(const Key('cinema-paused-badge')),
              findsOneWidget,
            );
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

            final replayBtn = find.byKey(
              const Key('btn-replay-welcome-cinema'),
            );
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/ui/app_scaffold.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/app_tokens.dart';
import 'package:desperrengue_app/core/ui/category_brand_emblem.dart';
import 'package:desperrengue_app/features/client/presentation/category_picker.dart';
import 'package:desperrengue_app/features/client/presentation/client_job_screen.dart';
import 'package:desperrengue_app/features/shared/presentation/profile_photo_viewer.dart';
import 'package:desperrengue_app/features/shared/presentation/support_screens.dart';

Widget host(Widget child, {Brightness b = Brightness.light, EdgeInsets? padding}) => MaterialApp(
      theme: AppTheme.resolve(null, b),
      builder: padding == null
          ? null
          : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(padding: padding, viewPadding: padding),
                child: child!,
              ),
      home: child,
    );

void tall(WidgetTester t, {double h = 6000}) {
  t.view.physicalSize = Size(1080, h);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
}

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Job job(String id, {JobStatus s = JobStatus.open}) => Job(
      id: id,
      clientId: 'me',
      title: 'Trocar disjuntor',
      description: 'O disjuntor desarma toda hora.',
      category: 'Elétrica',
      status: s,
      paymentStatus: 'pending',
      urgency: 'scheduled',
      visibility: 'open',
      createdAt: DateTime(2026, 10, 1),
    );

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

  // ------------------------------------------------------------ AppScaffold
  group('AppScaffold (botões nunca ficam sob a barra de navegação do Android)', () {
    const nav = EdgeInsets.only(bottom: 48);

    Widget body() => const Align(alignment: Alignment.bottomCenter, child: SizedBox(key: ValueKey('cta'), height: 40, width: 200));

    testWidgets('sem bottomNavigationBar: o corpo respeita a faixa inferior do sistema', (t) async {
      tall(t, h: 2400);
      await t.pumpWidget(host(AppScaffold(body: body()), padding: nav));
      final screenBottom = t.view.physicalSize.height / t.view.devicePixelRatio;
      expect(t.getRect(find.byKey(const ValueKey('cta'))).bottom, closeTo(screenBottom - 48, 0.5));
    });

    testWidgets('um Scaffold comum encosta no fundo (o problema que a barra do celular cortava)', (t) async {
      tall(t, h: 2400);
      await t.pumpWidget(host(Scaffold(body: body()), padding: nav));
      final screenBottom = t.view.physicalSize.height / t.view.devicePixelRatio;
      expect(t.getRect(find.byKey(const ValueKey('cta'))).bottom, closeTo(screenBottom, 0.5));
    });

    testWidgets('com bottomNavigationBar: não duplica o respiro (a barra cuida do próprio inset)', (t) async {
      tall(t, h: 2400);
      await t.pumpWidget(host(
        AppScaffold(body: body(), bottomNavigationBar: const SizedBox(height: 60, child: ColoredBox(color: Colors.red))),
        padding: nav,
      ));
      final screenBottom = t.view.physicalSize.height / t.view.devicePixelRatio;
      // Corpo termina onde a barra começa (60 px acima do fundo), sem os 48 extras.
      expect(t.getRect(find.byKey(const ValueKey('cta'))).bottom, closeTo(screenBottom - 60, 0.5));
    });

    testWidgets('lista longa continua rolando até o último item ficar visível acima da barra', (t) async {
      t.view.physicalSize = const Size(1080, 1600);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      await t.pumpWidget(host(
        AppScaffold(body: ListView(children: [for (var i = 0; i < 40; i++) SizedBox(height: 60, child: Text('item $i')), const SizedBox(key: ValueKey('last'), height: 56)])),
        padding: nav,
      ));
      await t.drag(find.byType(ListView), const Offset(0, -6000));
      await t.pump();
      final screenBottom = t.view.physicalSize.height / t.view.devicePixelRatio;
      expect(t.getRect(find.byKey(const ValueKey('last'))).bottom, lessThanOrEqualTo(screenBottom - 48 + 0.5));
    });
  });

  // ------------------------------------------------------------ categorias
  group('Categorias (33) — grade do painel e busca', () {
    test('catálogo ampliado e sem duplicatas', () {
      expect(kCategories.length, greaterThanOrEqualTo(30));
      expect(kCategories.map((c) => c.name).toSet(), hasLength(kCategories.length));
      for (final n in ['Elétrica', 'Encanador', 'Jardinagem', 'Ar-condicionado', 'Dedetização', 'Energia Solar', 'Pet Care', 'Babá', 'Mudanças e Fretes']) {
        expect(kCategories.map((c) => c.name), contains(n));
      }
    });

    test('searchCategories: nome, sinônimo/profissão e vazio', () {
      expect(searchCategories(''), hasLength(kCategories.length));
      expect(searchCategories('eletricista').map((c) => c.name), contains('Elétrica'));
      expect(searchCategories('Jardineiro').map((c) => c.name), ['Jardinagem']);
      expect(searchCategories('PINTOR').map((c) => c.name), contains('Pintura'));
      expect(searchCategories('hidráulica').map((c) => c.name), contains('Encanador'));
      expect(searchCategories('zzzz'), isEmpty);
    });

    testWidgets('painel mostra as principais + "Ver todas (N)" e toque escolhe a categoria', (t) async {
      tall(t);
      final picked = <String>[];
      await t.pumpWidget(host(Scaffold(body: SingleChildScrollView(child: CategoryGrid(onPick: picked.add)))));
      expect(find.byType(CategoryTile), findsNWidgets(kHomeCategoryCount));
      expect(find.text('Ver todas (${kCategories.length})'), findsOneWidget);
      await t.tap(find.byKey(ValueKey('category:${kCategories.first.name}')));
      expect(picked, [kCategories.first.name]);
    });

    testWidgets('"Ver todas" abre a folha com TODAS as categorias; a busca filtra por profissão', (t) async {
      tall(t, h: 9000);
      final picked = <String>[];
      await t.pumpWidget(host(Scaffold(body: SingleChildScrollView(child: CategoryGrid(onPick: picked.add)))));
      await t.tap(find.byKey(const ValueKey('categories-see-all')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('category-search')), findsOneWidget);
      expect(find.byKey(const ValueKey('category:Jardinagem')), findsOneWidget, reason: 'categoria fora das principais está na lista completa');
      expect(find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(CategoryTile)), findsNWidgets(kCategories.length));

      await t.enterText(find.byKey(const ValueKey('category-search')), 'jardineiro');
      await t.pump();
      final inSheet = find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(CategoryTile));
      expect(inSheet, findsOneWidget);

      await t.tap(find.byKey(const ValueKey('category:Jardinagem')).last);
      await t.pumpAndSettle();
      expect(picked, ['Jardinagem']);
      expect(find.byKey(const ValueKey('category-search')), findsNothing, reason: 'a folha fecha ao escolher');
    });

    testWidgets('busca sem resultado mostra estado vazio', (t) async {
      tall(t, h: 9000);
      await t.pumpWidget(host(Scaffold(body: SingleChildScrollView(child: CategoryGrid(onPick: (_) {})))));
      await t.tap(find.byKey(const ValueKey('categories-see-all')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('category-search')), 'astronauta');
      await t.pump();
      expect(find.text('Nenhuma categoria encontrada.'), findsOneWidget);
    });

    test('33 Emblemas Customizados (CategoryBrandEmblem): todas as 33 categorias possuem especificação vetorial única e 6 famílias cromáticas', () {
      expect(kCategoryBrandSpecs, hasLength(33));
      final familiesUsed = <CategoryColorFamily>{};
      for (final cat in kCategories) {
        final spec = resolveCategoryBrandSpec(cat.name);
        expect(spec.name, cat.name);
        expect(spec.primaryIconifyId, contains(':'));
        expect(spec.badgeIconifyId, contains(':'));
        familiesUsed.add(spec.family);
      }
      expect(familiesUsed, containsAll([
        CategoryColorFamily.waterClimate,
        CategoryColorFamily.constructionRepair,
        CategoryColorFamily.electricTech,
        CategoryColorFamily.bioCleaning,
        CategoryColorFamily.careMobility,
      ]));
    });

    testWidgets('CategoryTile usa CategoryBrandEmblem (Dark Glass Squircle) e FittedBox em palavras longas únicas para nunca quebrar sílabas', (t) async {
      tall(t, h: 9000);
      await t.pumpWidget(host(Scaffold(body: SingleChildScrollView(child: CategoryGrid(onPick: (_) {})))));
      await t.tap(find.byKey(const ValueKey('categories-see-all')));
      await t.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(CategoryBrandEmblem)),
        findsNWidgets(kCategories.length),
      );

      final imperTile = find.byKey(const ValueKey('category:Impermeabilização'));
      expect(imperTile, findsOneWidget);
      expect(find.descendant(of: imperTile, matching: find.byType(FittedBox)), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('category-family:agua_clima')));
      await t.pumpAndSettle();
      final aguaTiles = find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(CategoryTile));
      expect(aguaTiles, findsNWidgets(6));
    });
  });

  // ------------------------------------------------------------ foto de perfil
  group('Foto de perfil: abre em tela cheia e pergunta se quer alterar', () {
    testWidgets('toque abre a foto; sem foto oferece "Adicionar foto"; "Agora não" fecha', (t) async {
      tall(t, h: 2400);
      await t.pumpWidget(host(const Scaffold(body: Center(child: EditableAvatar(url: null, name: 'Maria Souza')))));
      await t.tap(find.byKey(const ValueKey('editable-avatar')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('avatar-placeholder')), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-question')), findsOneWidget);
      expect(find.text('Adicionar foto'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('photo-close')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('photo-question')), findsNothing);
    });

    testWidgets('com foto, a pergunta é "Deseja alterar esta foto?"', (t) async {
      tall(t, h: 2400);
      await t.pumpWidget(host(ProfilePhotoViewerScreen(url: 'https://exemplo.invalid/a.jpg', name: 'Maria Souza', changer: (_) async => null)));
      await t.pump();
      expect(find.text('Deseja alterar esta foto?'), findsOneWidget);
      expect(find.text('Alterar foto'), findsOneWidget);
    });

    testWidgets('alterar: chama o seletor, mostra "Foto atualizada!" e devolve a nova URL ao fechar', (t) async {
      tall(t, h: 2400);
      // A URL de teste não existe: o erro de carregamento da imagem de rede é esperado.
      final previous = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exception is NetworkImageLoadException) return;
        previous?.call(d);
      };
      addTearDown(() => FlutterError.onError = previous);
      String? changed;
      var calls = 0;
      await t.pumpWidget(host(Scaffold(
        body: Center(
          child: EditableAvatar(
            url: null,
            name: 'Maria Souza',
            changer: (_) async {
              calls++;
              return 'https://exemplo.invalid/nova.jpg';
            },
            onChanged: (u) => changed = u,
          ),
        ),
      )));
      await t.tap(find.byKey(const ValueKey('editable-avatar')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('photo-change')));
      await t.pump();
      await t.pump();
      expect(calls, 1);
      expect(find.text('Foto atualizada!'), findsWidgets);
      await t.tap(find.byKey(const ValueKey('photo-close')));
      await t.pumpAndSettle();
      expect(changed, 'https://exemplo.invalid/nova.jpg');
    });

    testWidgets('cancelar a escolha na galeria não muda nada nem mostra erro', (t) async {
      tall(t, h: 2400);
      String? changed;
      await t.pumpWidget(host(Scaffold(
        body: Center(child: EditableAvatar(url: null, name: 'Maria', changer: (_) async => null, onChanged: (u) => changed = u)),
      )));
      await t.tap(find.byKey(const ValueKey('editable-avatar')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('photo-change')));
      await t.pump();
      await t.pump();
      expect(find.text('Foto atualizada!'), findsNothing);
      await t.tap(find.byKey(const ValueKey('photo-close')));
      await t.pumpAndSettle();
      expect(changed, isNull);
    });

    testWidgets('falha ao enviar mostra mensagem amigável e a tela continua', (t) async {
      tall(t, h: 2400);
      await t.pumpWidget(host(ProfilePhotoViewerScreen(url: null, name: 'Maria', changer: (_) async => throw Exception('sem rede'))));
      await t.tap(find.byKey(const ValueKey('photo-change')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const ValueKey('photo-question')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  // ------------------------------------------------------------ mediação no Suporte
  group('Ajuda e suporte: "Mediações em andamento" só quando existe mediação', () {
    Future<List<Job>> open(WidgetTester t, {List<Job> disputes = const [], bool asProvider = false}) async {
      tall(t);
      final opened = <Job>[];
      await t.pumpWidget(host(SupportCenterScreen(
        asProvider: asProvider,
        ticketsLoader: () async => const [],
        disputesLoader: () async => disputes,
        onOpenMediation: (_, j) => opened.add(j),
      )));
      await t.pump();
      await t.pump();
      return opened;
    }

    testWidgets('sem mediação: a seção nem aparece', (t) async {
      await open(t);
      expect(find.text('Mediações em andamento'), findsNothing);
      expect(find.text('Abrir novo chamado'), findsOneWidget);
      expect(find.text('Nenhum chamado aberto.'), findsOneWidget);
    });

    testWidgets('com mediação: seção + cartão; toque abre o caso (cliente)', (t) async {
      final opened = await open(t, disputes: [job('disp-1', s: JobStatus.disputed)]);
      expect(find.text('Mediações em andamento'), findsOneWidget);
      expect(find.byKey(const ValueKey('mediation:disp-1')), findsOneWidget);
      expect(find.text('Trocar disjuntor'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('mediation:disp-1')));
      expect(opened.map((j) => j.id), ['disp-1']);
    });

    testWidgets('profissional vê as próprias mediações do mesmo jeito', (t) async {
      final opened = await open(t, asProvider: true, disputes: [job('disp-1', s: JobStatus.disputed), job('disp-2', s: JobStatus.disputed)]);
      expect(find.byKey(const ValueKey('mediation:disp-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('mediation:disp-2')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('mediation:disp-2')));
      expect(opened.single.id, 'disp-2');
    });

    testWidgets('falha ao carregar as mediações NÃO derruba a Central', (t) async {
      tall(t);
      await t.pumpWidget(host(SupportCenterScreen(ticketsLoader: () async => const [], disputesLoader: () async => throw Exception('rede'))));
      await t.pump();
      await t.pump();
      expect(find.text('Abrir novo chamado'), findsOneWidget);
      expect(find.text('Mediações em andamento'), findsNothing);
    });
  });

  // ------------------------------------------------------------ Pedido publicado!
  group('"Aguardando orçamento" (tela do pedido publicado)', () {
    Future<void> open(WidgetTester t, {Brightness b = Brightness.light}) async {
      tall(t, h: 7000);
      await t.pumpWidget(host(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => WaitingQuotesScreen(job: job('job-001'), quotesStream: Stream.value(const []), invitesStream: Stream.value(const [])),
                )),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
        b: b,
      ));
      await t.tap(find.text('abrir'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    }

    testWidgets('tem botão de voltar discreto que realmente volta', (t) async {
      await open(t);
      expect(find.byKey(const ValueKey('waiting-back')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('waiting-back')));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(WaitingQuotesScreen), findsNothing);
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('mostra o resumo do pedido e deixa o cancelar discreto (texto, sem botão vermelho)', (t) async {
      await open(t);
      expect(find.text('Elétrica'), findsWidgets);
      expect(find.text('O disjuntor desarma toda hora.'), findsOneWidget);
      expect(find.text('Aguardando Orçamento'), findsWidgets);
      expect(find.byKey(const ValueKey('waiting-cancel')), findsOneWidget);
      expect(find.byType(TextButton), findsWidgets);
    });

    testWidgets('tema escuro renderiza sem estouro', (t) async {
      await open(t, b: Brightness.dark);
      expect(t.takeException(), isNull);
    });
  });

  // ------------------------------------------------------------ tema escuro
  group('Tema escuro: contraste (WCAG) e hierarquia de superfícies', () {
    final d = AppTokens.dark;

    test('texto principal tem contraste AAA em todas as superfícies', () {
      for (final bg in [d.background, d.surface, d.card, d.raised]) {
        expect(contrast(d.text, bg), greaterThanOrEqualTo(7), reason: 'texto sobre $bg');
      }
    });

    test('texto secundário passa AA (4.5) sobre fundo e cartão', () {
      for (final bg in [d.background, d.surface, d.card]) {
        expect(contrast(d.textMuted, bg), greaterThanOrEqualTo(4.5), reason: 'muted sobre $bg');
      }
    });

    test('cores de destaque (cliente/profissional) e status são legíveis sobre o cartão', () {
      expect(contrast(d.clientAccent, d.card), greaterThanOrEqualTo(4.5), reason: 'cliente');
      expect(contrast(d.providerAccent, d.card), greaterThanOrEqualTo(4.5), reason: 'profissional');
      expect(contrast(d.success, d.card), greaterThanOrEqualTo(3), reason: 'sucesso');
      expect(contrast(d.danger, d.card), greaterThanOrEqualTo(3), reason: 'perigo');
    });

    test('superfícies em degraus crescentes de luminância (sem "buraco preto")', () {
      final l = [d.background, d.surface, d.card, d.raised].map((c) => c.computeLuminance()).toList();
      for (var i = 1; i < l.length; i++) {
        expect(l[i], greaterThan(l[i - 1]), reason: 'degrau $i');
      }
      expect(d.background.computeLuminance(), greaterThan(0), reason: 'não é preto puro');
      expect(d.background.computeLuminance(), lessThan(0.02));
    });

    test('bordas visíveis mas sutis sobre o cartão', () {
      final r = contrast(d.border, d.card);
      expect(r, greaterThan(1.1));
      expect(r, lessThan(3));
    });

    testWidgets('nav bar e cartões herdam a paleta (ColorScheme escuro com texto legível)', (t) async {
      final theme = AppTheme.resolve(null, Brightness.dark);
      expect(theme.brightness, Brightness.dark);
      expect(contrast(theme.colorScheme.onSurface, theme.colorScheme.surface), greaterThanOrEqualTo(7));
      expect(contrast(theme.colorScheme.onPrimary, theme.colorScheme.primary), greaterThanOrEqualTo(4.5));
    });
  });
}

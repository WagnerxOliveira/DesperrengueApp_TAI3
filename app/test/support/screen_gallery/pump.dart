import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'fonts.dart';
import 'viewports.dart';

/// Tipo de superfície registrada na galeria.
enum GalleryKind {
  /// Tela inteira (traz o próprio `Scaffold`).
  screen,

  /// Bottom sheet / diálogo (a galeria o abre sobre um scaffold vazio).
  sheet,

  /// Widget de nível de tela sem Scaffold (a galeria o coloca num Scaffold).
  widget,
}

/// Uma tela registrada na galeria (ver `ui_gallery/gallery_registry.dart`).
class GalleryScreen {
  const GalleryScreen({
    required this.id,
    required this.title,
    required this.source,
    required this.wave,
    required this.owner,
    required this.builder,
    this.kind = GalleryKind.screen,
    this.modes = const <UserMode?>{null},
    this.overrides,
    this.interact,
    this.animatesForever = false,
    this.skipRules = const <String>{},
    this.note,
  });

  /// Identificador estável (`client/carteira_cliente`): chave do ratchet.
  final String id;
  final String title;

  /// Caminho em `lib/` (para relatório).
  final String source;

  /// Onda de migração (0–6, spec §5).
  final int wave;

  /// Dono sugerido (`auth_ui`, `client_core_ui`, …).
  final String owner;
  final GalleryKind kind;

  /// Modos em que a tela existe: `{UserMode.client}`, `{UserMode.provider}`,
  /// ambos, ou `{null}` (tema da marca: login/KYC).
  final Set<UserMode?> modes;

  /// Constrói a tela (já recebe o [GalleryVariant] para dados dependentes).
  final Widget Function(BuildContext context, GalleryVariant variant) builder;

  /// Overrides de provider por variante (fakes).
  final List<Override> Function(GalleryVariant variant)? overrides;

  /// Ação após o 1º quadro (abrir sheet, digitar, rolar…).
  final Future<void> Function(WidgetTester tester, GalleryVariant variant)? interact;

  /// `true` se há animação infinita legítima (não usar `pumpAndSettle`).
  final bool animatesForever;

  /// Regras não aplicáveis (ex.: `{'tabular'}` numa tela sem números).
  final Set<String> skipRules;

  /// Por que está/estará como está (exceção documentada).
  final String? note;

  @override
  String toString() => id;
}

/// Erros capturados durante um cenário.
class CapturedErrors {
  final List<FlutterErrorDetails> all = <FlutterErrorDetails>[];

  Iterable<FlutterErrorDetails> get overflows => all.where((d) => d.exceptionAsString().contains('overflowed'));

  Iterable<FlutterErrorDetails> get others => all.where((d) => !d.exceptionAsString().contains('overflowed'));

  /// Mensagem curta de cada overflow (`A RenderFlex overflowed by 12 pixels on the right.`).
  List<String> overflowSummaries() => <String>{for (final d in overflows) _summarize(d)}.toList();

  static String _summarize(FlutterErrorDetails d) {
    final s = d.exceptionAsString();
    final m = RegExp(r'overflowed by ([\d.]+) pixels on the (\w+)').firstMatch(s);
    final where = RegExp(r'relevant error-causing widget was:\s*\n\s*(.+?)\s+(?:file:|\n)').firstMatch(s);
    final loc = RegExp(r'file:///.*?/lib/([^\s:]+:\d+)').firstMatch(s);
    return '${m == null ? s.split('\n').first : 'estouro de ${m.group(1)}px à ${m.group(2)}'}'
        '${where == null ? '' : ' em ${where.group(1)}'}'
        '${loc == null ? '' : ' (${loc.group(1)})'}';
  }
}

/// Resultado de montar uma tela numa [GalleryVariant].
class GalleryRun {
  GalleryRun._(this.tester, this.screen, this.variant, this.errors, this.root);

  final WidgetTester tester;
  final GalleryScreen screen;
  final GalleryVariant variant;
  final CapturedErrors errors;

  /// Finder do conteúdo da tela (sob o `Navigator`).
  final Finder root;

  /// Elemento raiz da árvore da tela.
  Element get rootElement => tester.element(root.first);
}

/// Monta [screen] em [variant], captura TODOS os erros do framework (não só o
/// 1º) e entrega o [GalleryRun] ao [body]. Ao final desmonta a árvore e avança
/// o relógio para que não restem timers pendentes.
///
/// Uso:
/// ```dart
/// testWidgets('x', (tester) async {
///   await withGalleryRun(tester, screen, variant, (run) async {
///     expect(run.errors.overflows, isEmpty);
///   });
/// });
/// ```
Future<T> withGalleryRun<T>(
  WidgetTester tester,
  GalleryScreen screen,
  GalleryVariant variant,
  Future<T> Function(GalleryRun run) body, {
  Duration settleFor = const Duration(milliseconds: 900),
  bool settle = true,
}) async {
  await loadGalleryFonts();
  tester.view.physicalSize = Size(
    variant.viewport.size.width * variant.viewport.dpr,
    variant.viewport.size.height * variant.viewport.dpr,
  );
  tester.view.devicePixelRatio = variant.viewport.dpr;

  final semantics = tester.ensureSemantics();
  final errors = CapturedErrors();
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.all.add(details);
  };
  final presentError = FlutterError.presentError;
  FlutterError.presentError = (_) {}; // silencioso: o relatório sai no teste
  try {
    await tester.pumpWidget(_GalleryApp(screen: screen, variant: variant));
    await tester.pump();
    if (screen.kind == GalleryKind.sheet) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    if (screen.interact != null) {
      await screen.interact!(tester, variant);
    }
    if (settle) await _settle(tester, screen, settleFor);
    final run = GalleryRun._(tester, screen, variant, errors, find.byKey(_galleryContentKey));
    final result = await body(run);
    return result;
  } finally {
    // Desmonta e deixa timers curtos vencerem (evita "Timer is still pending").
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
    FlutterError.onError = previous;
    FlutterError.presentError = presentError;
    semantics.dispose();
    tester.view.reset();
  }
}

Future<void> _settle(WidgetTester tester, GalleryScreen screen, Duration d) async {
  if (screen.animatesForever) {
    // Avança em passos de 100 ms (sem pumpAndSettle: animação infinita legítima).
    final steps = (d.inMilliseconds / 100).ceil();
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return;
  }
  try {
    await tester.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, d);
  } catch (_) {
    // Não assentou no prazo (animação longa/loop): segue com o que há na tela.
    await tester.pump();
  }
}

const Key _galleryContentKey = ValueKey<String>('gallery-content');

/// App-casca idêntico ao `DesperrengueApp` quanto a tema, locale e política de
/// escala de fonte, mas sem BootGate/UpdateGate/Supabase.
class _GalleryApp extends StatelessWidget {
  const _GalleryApp({required this.screen, required this.variant});

  final GalleryScreen screen;
  final GalleryVariant variant;

  @override
  Widget build(BuildContext context) {
    final overrides = screen.overrides?.call(variant) ?? const <Override>[];
    final light = AppTheme.resolve(variant.mode, Brightness.light);
    final dark = AppTheme.resolve(variant.mode, Brightness.dark);
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: light,
        darkTheme: dark,
        themeMode: variant.isDark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) {
          // Mesma política do app: respeita o sistema, com teto de 1.5×.
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(variant.scale.clamp(1.0, 1.5)),
              disableAnimations: variant.disableAnimations,
            ),
            child: child!,
          );
        },
        home: KeyedSubtree(
          key: _galleryContentKey,
          child: _Host(screen: screen, variant: variant),
        ),
      ),
    );
  }
}

class _Host extends StatefulWidget {
  const _Host({required this.screen, required this.variant});

  final GalleryScreen screen;
  final GalleryVariant variant;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.screen;
    switch (s.kind) {
      case GalleryKind.screen:
        return s.builder(context, widget.variant);
      case GalleryKind.widget:
        return Scaffold(body: SafeArea(child: s.builder(context, widget.variant)));
      case GalleryKind.sheet:
        if (!_opened) {
          _opened = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (ctx) => s.builder(ctx, widget.variant),
            );
          });
        }
        return const Scaffold(body: SizedBox.expand());
    }
  }
}

/// Valor de `kIsWeb` em testes é sempre falso; a "Web" é simulada por viewport.
bool get galleryIsWebRuntime => kIsWeb;

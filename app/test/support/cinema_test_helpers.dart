import 'package:desperrengue_app/features/auth/presentation/desperrengue_welcome_cinema_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Utilitários compartilhados dos testes da apresentação pós-cadastro (v2.27.0).

const List<String> kCinemaAllowedFontFamilies = <String>[
  'PlusJakartaSans',
  'Inter',
];

/// Viewport da matriz de escala de fonte (seção 3, item 4 do contrato v2.27.0).
typedef CinemaViewport = ({
  Size size,
  double dpr,
  double scale,
  String label,
});

const List<CinemaViewport> kCinemaMatrix = <CinemaViewport>[
  (size: Size(320, 640), dpr: 1.0, scale: 1.0, label: '320x640 @ 1.0'),
  (size: Size(320, 640), dpr: 1.0, scale: 1.35, label: '320x640 @ 1.35'),
  (size: Size(320, 640), dpr: 1.0, scale: 1.5, label: '320x640 @ 1.5'),
  (size: Size(360, 780), dpr: 1.0, scale: 1.0, label: '360x780 @ 1.0'),
  (size: Size(390, 844), dpr: 1.0, scale: 1.0, label: '390x844 @ 1.0'),
  (size: Size(412, 915), dpr: 1.0, scale: 1.3, label: '412x915 @ 1.3'),
  (size: Size(1080, 2400), dpr: 2.75, scale: 1.0, label: '1080x2400 @ 2.75'),
  (size: Size(1280, 800), dpr: 1.0, scale: 1.0, label: 'web 1280x800'),
  (size: Size(1920, 1080), dpr: 1.0, scale: 1.0, label: 'web 1920x1080'),
];

bool _fontsLoaded = false;

/// Carrega as fontes embarcadas (Plus Jakarta Sans / Inter) no motor de teste,
/// para que a medição de texto seja realista (sem cair na fonte Ahem).
Future<void> loadCinemaFonts() async {
  if (_fontsLoaded) return;
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }

  await load('PlusJakartaSans', const <String>[
    'PlusJakartaSans-Bold.ttf',
    'PlusJakartaSans-ExtraBold.ttf',
  ]);
  await load('Inter', const <String>[
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]);
  _fontsLoaded = true;
}

/// Monta a apresentação com viewport/escala de fonte controlados.
Future<void> pumpCinema(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double dpr = 1.0,
  double textScale = 1.0,
  Key? key,
  String userFirstName = 'Ana',
  Duration? totalDuration,
  bool isReplay = false,
  ValueChanged<int>? onActiveHeroBuild,
  VoidCallback? onCompleted,
  bool disableAnimations = false,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: DesperrengueWelcomeCinemaScreen(
        key: key,
        userFirstName: userFirstName,
        totalDuration: totalDuration ?? const Duration(milliseconds: 63000),
        isReplay: isReplay,
        onActiveHeroBuild: onActiveHeroBuild,
        onCompleted: onCompleted ?? () {},
      ),
    ),
  );
  await tester.pump();
}

/// Texto renderizado com estilo efetivo resolvido (DefaultTextStyle + style).
class CinemaTextInfo {
  CinemaTextInfo({
    required this.content,
    required this.style,
    required this.fontSize,
    required this.renderedFontSize,
    required this.element,
  });

  final String content;
  final TextStyle style;

  /// `fontSize` declarado (antes do `TextScaler`).
  final double fontSize;

  /// `fontSize` após aplicar o `TextScaler` efetivo.
  final double renderedFontSize;
  final Element element;

  String? get family => style.fontFamily;

  bool get isTabular => (style.fontFeatures ?? const <FontFeature>[]).any(
    (f) => f.feature == 'tnum' && f.value == 1,
  );

  @override
  String toString() =>
      '"$content" (${family ?? 'sem família'} ${fontSize.toStringAsFixed(1)}sp w${style.fontWeight?.value ?? 400})';
}

/// Coleta todos os `Text` visíveis (não-offstage) da apresentação, com o estilo
/// efetivo. Ícones (`Icon`) não entram: são `RichText` direto, não `Text`.
List<CinemaTextInfo> collectCinemaTexts(WidgetTester tester) {
  final out = <CinemaTextInfo>[];
  final root = find.byType(DesperrengueWelcomeCinemaScreen);
  for (final element
      in find.descendant(of: root, matching: find.byType(Text)).evaluate()) {
    final widget = element.widget as Text;
    final content = widget.data ?? widget.textSpan?.toPlainText() ?? '';
    if (content.trim().isEmpty) continue;
    final base = DefaultTextStyle.of(element).style;
    final style = base.merge(widget.style);
    final fontSize = style.fontSize ?? 14.0;
    final scaler = widget.textScaler ?? MediaQuery.textScalerOf(element);
    out.add(
      CinemaTextInfo(
        content: content,
        style: style,
        fontSize: fontSize,
        renderedFontSize: scaler.scale(fontSize),
        element: element,
      ),
    );
  }
  return out;
}

/// Seleciona a etapa [index] (0..5) pelos segmentos de capítulo.
Future<void> goToStory(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(Key('cinema-chapter-tap-$index')));
  await tester.pump();
}

/// Deixa a coreografia da etapa chegar ao repouso (Ato 3).
Future<void> settleStory(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump(const Duration(milliseconds: 2400));
  await tester.pump(const Duration(milliseconds: 1000));
}

/// `true` se [v] pertence à escala de 4 pt (4, 8, 12, 16, 20, 24, 32...).
///
/// Valores < 4 dp são insets ópticos de hairline (bordas de 1/1.5/2 px, cursor
/// do switch, anéis de foco) e não contam como "padding de layout".
bool onFourPointScale(double v) {
  if (v < 4.0) return true;
  final r = v % 4.0;
  return r.abs() < 0.001 || (4.0 - r).abs() < 0.001;
}

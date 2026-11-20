import 'package:flutter/widgets.dart';

/// Catálogo de movimento (§3.1). Princípio: a animação serve à compreensão e à
/// sensação de velocidade; nunca atrasa o usuário. Tudo respeita
/// `MediaQuery.disableAnimationsOf` (estado final imediato) — use [AppMotion.d]
/// para resolver a duração efetiva.
abstract final class AppMotion {
  // Toque: escala 0,97 por mola, <= 120 ms.
  static const Duration tap = Duration(milliseconds: 100);
  static const Duration tapRelease = Duration(milliseconds: 140);
  static const double tapScale = 0.97;
  static const Curve tapCurve = Curves.easeOutCubic;

  // Troca de estado (habilitado↔loading, aba↔aba).
  static const Duration fade = Duration(milliseconds: 140);
  static const Duration fadeShort = Duration(milliseconds: 120);
  static const Curve fadeCurve = Curves.easeOut;

  /// Troca de aba dos shells (cross-fade).
  static const Duration tabSwitch = Duration(milliseconds: 150);

  // Páginas: fade-through + 8 px.
  static const Duration page = Duration(milliseconds: 200);
  static const Duration pageReverse = Duration(milliseconds: 160);
  static const double pageOffset = 8;
  static const double fullscreenModalOffset = 16;
  static const Curve pageCurve = Curves.easeOutCubic;
  static const Curve pageReverseCurve = Curves.easeInCubic;

  // Sheets e diálogos (sobe 24 px + fade, scrim 0→54%).
  static const Duration sheet = Duration(milliseconds: 220);
  static const Duration sheetReverse = Duration(milliseconds: 180);
  static const double sheetOffset = 24;
  static const Curve sheetCurve = Curves.easeOutQuart;
  static const Curve sheetReverseCurve = Curves.easeInCubic;
  static const double scrimOpacity = 0.54;

  /// `AnimationStyle` padrão de TODO sheet/diálogo do app.
  static const AnimationStyle sheetStyle = AnimationStyle(
    duration: sheet,
    reverseDuration: sheetReverse,
    curve: sheetCurve,
    reverseCurve: sheetReverseCurve,
  );

  // Entrada escalonada: 160 ms por item, atraso 24 ms, máx. 6, só na 1ª vez.
  static const Duration stagger = Duration(milliseconds: 160);
  static const Duration staggerDelay = Duration(milliseconds: 24);
  static const int staggerMax = 6;
  static const Curve staggerCurve = Curves.easeOutQuart;

  // Valores numéricos animam antigo→novo.
  static const Duration count = Duration(milliseconds: 250);
  static const Curve countCurve = Curves.easeOutCubic;

  // Sucesso: 400–600 ms (mola).
  static const Duration success = Duration(milliseconds: 500);

  // Esqueletos: shimmer 1,2 s só durante carregamento; skeleton→conteúdo 140 ms.
  static const Duration skeleton = Duration(milliseconds: 1200);
  static const Duration skeletonToContent = Duration(milliseconds: 140);

  // Campos: borda/rótulo 120 ms; erro com shake de 6 px / 160 ms.
  static const Duration field = Duration(milliseconds: 120);
  static const Duration shake = Duration(milliseconds: 160);
  static const double shakeOffset = 6;

  // Progresso de passos (barra preenche).
  static const Duration progress = Duration(milliseconds: 220);

  // Chat: entrada de mensagem (slide 8 px + fade 140 ms).
  static const Duration message = Duration(milliseconds: 140);

  /// Duração efetiva: zero quando o sistema pede menos movimento.
  static Duration d(BuildContext context, Duration base) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : base;

  /// `true` quando o movimento deve ser suprimido (prefers-reduced-motion).
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

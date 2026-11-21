import 'package:flutter/material.dart';

/// Design Tokens SEMÂNTICOS (ADR-0014).
///
/// Regra do projeto: as Views NUNCA usam cor literal (`Colors.black`,
/// `Color(0xFF...)`) para superfície, texto, borda ou estado. Elas leem o token
/// (`context.tk.text`, `context.tk.card`...) e o tema (claro/escuro) decide o valor.
/// Sem `if (isDark)` espalhado pelas telas.
///
/// Escuro (Material 3 + WCAG):
///  * fundo-base grafite azulado #0E1218 (nunca preto puro: reduz o efeito "halation");
///  * SEM sombra: profundidade por **elevação tonal** ([tonal] clareia a
///    superfície com uma camada branca proporcional ao nível);
///  * cores vibrantes passam por [desaturate] (menos saturação, mais luz) para não
///    cansar a vista e manter contraste ≥ 4,5:1 (texto) / 3:1 (ícones) — verificado
///    em `test/app_tokens_test.dart`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.card,
    required this.raised,
    required this.text,
    required this.textMuted,
    required this.border,
    required this.brand,
    required this.providerAccent,
    required this.clientAccent,
    required this.success,
    required this.successSoft,
    required this.successInk,
    required this.warning,
    required this.warningSoft,
    required this.warningInk,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.security,
    required this.securitySoft,
    required this.providerSoft,
    required this.clientSoft,
    required this.star,
    required this.shadow,
    required this.accent,
    required this.accentInk,
    required this.onAccent,
    required this.accentSoft,
    required this.clientAccentInk,
    required this.providerAccentInk,
    required this.dangerInk,
    required this.surfaceInset,
    required this.scrim,
    required this.skeletonBase,
    required this.skeletonHighlight,
  });

  final Brightness brightness;

  /// Fundo da tela (claro: branco · escuro: grafite azulado #0E1218).
  final Color background;

  /// Fundo secundário / faixas (claro: cinza-azulado · escuro: +1 nível tonal).
  final Color surface;

  /// Cartões e listas (claro: branco · escuro: +1 nível tonal).
  final Color card;

  /// Modais, bottom sheets, menus (claro: branco · escuro: +4 níveis tonais).
  final Color raised;

  final Color text;
  final Color textMuted;
  final Color border;

  final Color brand;
  final Color providerAccent;
  final Color clientAccent;

  final Color success;
  final Color successSoft;
  final Color successInk;
  final Color warning;
  final Color warningSoft;
  final Color warningInk;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;
  final Color security;
  final Color securitySoft;
  final Color providerSoft;
  final Color clientSoft;
  final Color star;

  /// Cor de sombra. No escuro é transparente: sombra some sobre o fundo escuro.
  final Color shadow;
  /// Acento do MODO ativo (cliente = laranja, profissional = azul, sem modo =
  /// marca). Use para PREENCHIMENTO (botões, barras, indicadores).
  final Color accent;

  /// Acento para TEXTO/ÍCONE/LINK (>= 4,5:1 sobre ackground, card,
  /// surface e ccentSoft, claro e escuro). Nunca use ccent como texto.
  final Color accentInk;

  /// Cor legível SOBRE ccent (rótulo de botão primário).
  final Color onAccent;

  /// Tinta suave do acento (fundos de chip/ícone/seleção).
  final Color accentSoft;

  /// Tinta de texto do acento cliente (laranja escurecido no claro).
  final Color clientAccentInk;

  /// Tinta de texto do acento profissional.
  final Color providerAccentInk;

  /// Texto de erro/risco real (>= 4,5:1 sobre ackground, card e dangerSoft).
  final Color dangerInk;

  /// Superfície rebaixada (campos, trilhos, áreas "afundadas").
  final Color surfaceInset;

  /// Película sob sheets/diálogos (opacidade já embutida).
  final Color scrim;

  /// Esqueleto de carregamento: base e brilho do shimmer.
  final Color skeletonBase;
  final Color skeletonHighlight;

  bool get isDark => brightness == Brightness.dark;

  /// Sombras de cartão: só existem no claro (no escuro a elevação é tonal).
  List<BoxShadow> cardShadow({double blur = 12, double dy = 4}) => isDark
      ? const []
      : [BoxShadow(color: shadow, blurRadius: blur, offset: Offset(0, dy))];
  /// Sombras de 2 camadas (mbient difusa + key direcional) — só no claro;
  /// nunca preto puro (tinta slate). No escuro a elevação é TONAL: use
  /// [surfaceAt]; aqui devolve lista vazia. [level]: 1 (cartão) · 2 (hero/
  /// flutuante) · 3 (sheet/menu).
  List<BoxShadow> elevation(int level) {
    if (isDark || level <= 0) return const [];
    return switch (level) {
      1 => const [
          BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x0F0F172A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      2 => const [
          BoxShadow(color: Color(0x0F0F172A), blurRadius: 4, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x1A0F172A), blurRadius: 24, offset: Offset(0, 10)),
        ],
      _ => const [
          BoxShadow(color: Color(0x140F172A), blurRadius: 6, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x290F172A), blurRadius: 40, offset: Offset(0, 16)),
        ],
    };
  }

  /// Superfície na elevação [dp]: clara = [card]; escura = degraus arquitetônicos
  /// neutros Obsidian Atelier (sem acinzentado leitoso).
  Color surfaceAt(int dp) {
    if (!isDark) return card;
    if (dp <= 0) return surface;
    if (dp == 1) return card;
    return raised;
  }

  /// Variante dos tokens para um acento específico (cliente/profissional).
  /// [onAccent] é recalculado (contraste máximo).
  AppTokens forAccent({required Color accent, required Color accentInk, required Color accentSoft}) =>
      AppTokens(
        brightness: brightness,
        background: background,
        surface: surface,
        card: card,
        raised: raised,
        text: text,
        textMuted: textMuted,
        border: border,
        brand: brand,
        providerAccent: providerAccent,
        clientAccent: clientAccent,
        success: success,
        successSoft: successSoft,
        successInk: successInk,
        warning: warning,
        warningSoft: warningSoft,
        warningInk: warningInk,
        danger: danger,
        dangerSoft: dangerSoft,
        info: info,
        infoSoft: infoSoft,
        security: security,
        securitySoft: securitySoft,
        providerSoft: providerSoft,
        clientSoft: clientSoft,
        star: star,
        shadow: shadow,
        accent: accent,
        accentInk: accentInk,
        onAccent: onColor(accent),
        accentSoft: accentSoft,
        clientAccentInk: clientAccentInk,
        providerAccentInk: providerAccentInk,
        dangerInk: dangerInk,
        surfaceInset: surfaceInset,
        scrim: scrim,
        skeletonBase: skeletonBase,
        skeletonHighlight: skeletonHighlight,
      );

  // ---------------------------------------------------------------- valores
  // Claro: "Alabaster Porcelain" — branco porcelana quente, divisórias sutis e alto contraste.
  static const AppTokens light = AppTokens(
    brightness: Brightness.light,
    background: Color(0xFFFAFBFD),
    surface: Color(0xFFF2F4F8),
    card: Color(0xFFFFFFFF),
    raised: Color(0xFFFFFFFF),
    text: Color(0xFF111827),
    textMuted: Color(0xFF58606E), // >= 5.7:1 sobre `surface` e `background`
    border: Color(0xFFE6EAF0),
    brand: Color(0xFF003366),
    providerAccent: Color(0xFF1B3A78),
    clientAccent: Color(0xFFEF6514),
    success: Color(0xFF127E50),
    successSoft: Color(0xFFECFDF5),
    successInk: Color(0xFF0E6440),
    warning: Color(0xFFB87B00),
    warningSoft: Color(0xFFFEF6DC),
    warningInk: Color(0xFF7A4A0A),
    danger: Color(0xFFC0262D),
    dangerSoft: Color(0xFFFDE8EA),
    info: Color(0xFF1D6FE0),
    infoSoft: Color(0xFFE6F0FC),
    security: Color(0xFF1D7A82),
    securitySoft: Color(0xFFE1F4F4),
    providerSoft: Color(0xFFE8F0FC),
    clientSoft: Color(0xFFFFEFE6),
    star: Color(0xFF9E6500),
    shadow: Color(0x0A0F172A),
    accent: Color(0xFF003366),
    accentInk: Color(0xFF003366),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFE6F0FC),
    clientAccentInk: Color(0xFFA83E06),
    providerAccentInk: Color(0xFF1B3A78),
    dangerInk: Color(0xFFA11D23),
    surfaceInset: Color(0xFFEEF1F6),
    scrim: Color(0x8A0F172A),
    skeletonBase: Color(0xFFE8ECF2),
    skeletonHighlight: Color(0xFFF6F8FB),
  );

  /// Escuro: "Obsidian Atelier" — neutros arquitetônicos profundos + bordas hairline.
  static final AppTokens dark = _buildDark();

  static AppTokens _buildDark() {
    // Paleta "Obsidian Atelier": base obsidiana profunda (#090A0D), superfícies neutras
    // sem azul-cinza lavado, acento âmbar-coral refinado e tintas translúcidas limpas
    // (eliminando tons marrom-lama e blocos verde-musgo chapados). Contraste WCAG AA+/AAA.
    const base = Color(0xFF090A0D);
    return AppTokens(
      brightness: Brightness.dark,
      background: base,
      surface: const Color(0xFF111318),
      card: const Color(0xFF161920),
      raised: const Color(0xFF1D212B),
      text: const Color(0xFFF5F7FA), // branco porcelana suave (zero halation)
      textMuted: const Color(0xFF9AA3B2),
      border: const Color(0xFF262B36),
      brand: const Color(0xFF7DB2FF),
      providerAccent: const Color(0xFF78ACFF),
      clientAccent: const Color(0xFFFF7A38),
      success: const Color(0xFF22C58B),
      successSoft: const Color(0xFF0F241D),
      successInk: const Color(0xFF5CE0AE),
      warning: const Color(0xFFF5B942),
      warningSoft: const Color(0xFF261F10),
      warningInk: const Color(0xFFF7CA6B),
      danger: const Color(0xFFF87171),
      dangerSoft: const Color(0xFF2A1418),
      info: const Color(0xFF60A5FA),
      infoSoft: const Color(0xFF121E30),
      security: const Color(0xFF38BDC8),
      securitySoft: const Color(0xFF102428),
      providerSoft: const Color(0xFF131E33),
      clientSoft: const Color(0xFF241914),
      star: const Color(0xFFF4C650),
      shadow: const Color(0x00000000),
      accent: const Color(0xFF7DB2FF),
      accentInk: const Color(0xFF7DB2FF),
      onAccent: const Color(0xFF111827),
      accentSoft: const Color(0xFF121E30),
      clientAccentInk: const Color(0xFFFF945C),
      providerAccentInk: const Color(0xFF85B6FF),
      dangerInk: const Color(0xFFFCA5A5),
      surfaceInset: const Color(0xFF0D0F14),
      scrim: const Color(0xB8000000),
      skeletonBase: const Color(0xFF202531),
      skeletonHighlight: const Color(0xFF2C3344),
    );
  }
  /// Elevação tonal (Material 3): sobrepõe branco à superfície com opacidade
  /// proporcional ao nível em dp (1dp≈5% · 2dp≈7% · 4dp≈9% · 8dp≈12% · 16dp≈15%).
  static Color tonal(Color surface, int dp) {
    const table = {0: 0.0, 1: 0.05, 2: 0.07, 3: 0.08, 4: 0.09, 6: 0.11, 8: 0.12, 12: 0.14, 16: 0.15, 24: 0.16};
    final a = table[dp] ?? 0.12;
    return Color.alphaBlend(Colors.white.withValues(alpha: a), surface);
  }

  /// Anti-"halation": reduz a saturação e clareia a cor vibrante para o fundo
  /// escuro (HSL). Mantém o matiz, então a identidade da marca é preservada.
  static Color desaturate(Color c, {double saturation = 0.78, double lightnessFloor = 0.66}) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withSaturation((hsl.saturation * saturation).clamp(0.0, 1.0))
        .withLightness(hsl.lightness < lightnessFloor ? lightnessFloor : hsl.lightness)
        .toColor();
  }

  /// Cor legível (texto/ícone) sobre [bg]: branco ou ink, o que tiver mais contraste.
  static Color onColor(Color bg) {
    const dark = Color(0xFF111827);
    return contrast(bg, Colors.white) >= contrast(bg, dark) ? Colors.white : dark;
  }

  /// Razão de contraste WCAG 2.x entre duas cores (1 a 21).
  static double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Tinge um ícone/SVG com o token (equivalente a `ColorFilter.mode(srcIn)`).
  ColorFilter tint(Color color) => ColorFilter.mode(color, BlendMode.srcIn);

  @override
  AppTokens copyWith({Brightness? brightness}) => brightness == Brightness.dark ? dark : (brightness == Brightness.light ? light : this);

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: l(background, other.background),
      surface: l(surface, other.surface),
      card: l(card, other.card),
      raised: l(raised, other.raised),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      border: l(border, other.border),
      brand: l(brand, other.brand),
      providerAccent: l(providerAccent, other.providerAccent),
      clientAccent: l(clientAccent, other.clientAccent),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      successInk: l(successInk, other.successInk),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      warningInk: l(warningInk, other.warningInk),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      info: l(info, other.info),
      infoSoft: l(infoSoft, other.infoSoft),
      security: l(security, other.security),
      securitySoft: l(securitySoft, other.securitySoft),
      providerSoft: l(providerSoft, other.providerSoft),
      clientSoft: l(clientSoft, other.clientSoft),
      star: l(star, other.star),
      shadow: l(shadow, other.shadow),
      accent: l(accent, other.accent),
      accentInk: l(accentInk, other.accentInk),
      onAccent: l(onAccent, other.onAccent),
      accentSoft: l(accentSoft, other.accentSoft),
      clientAccentInk: l(clientAccentInk, other.clientAccentInk),
      providerAccentInk: l(providerAccentInk, other.providerAccentInk),
      dangerInk: l(dangerInk, other.dangerInk),
      surfaceInset: l(surfaceInset, other.surfaceInset),
      scrim: l(scrim, other.scrim),
      skeletonBase: l(skeletonBase, other.skeletonBase),
      skeletonHighlight: l(skeletonHighlight, other.skeletonHighlight),
    );
  }
}

/// `context.tk.text`, `context.tk.card`... (cai no tema claro se não houver extensão,
/// o que mantém widgets de teste sem tema funcionando).
extension TokensOnContext on BuildContext {
  AppTokens get tk => Theme.of(this).extension<AppTokens>() ?? AppTokens.light;
}

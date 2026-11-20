import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import 'app_tokens.dart';
import 'design_system/app_navigation.dart';
import 'design_system/tokens/app_space.dart';
import 'design_system/tokens/app_type.dart';

/// Constantes de MARCA (a análise dos protótipos mostrou 4 azuis e 3 laranjas
/// diferentes; aqui há UM por modo).
///
/// ATENÇÃO: para superfície, texto, borda e estados use os tokens semânticos
/// (context.tk.*, ver [AppTokens]) — eles mudam com o tema claro/escuro.
/// As constantes abaixo servem a contextos sem BuildContext (ícone do app,
/// splash, seed de tema) e a elementos que são iguais nos dois temas.
class AppColors {
  AppColors._();

  // Marca / login
  static const navy = Color(0xFF003366);

  // Modo cliente (protótipos da pasta `cliente`): laranja
  static const clientAccent = Color(0xFFF26B0F);
  static const clientSoft = Color(0xFFFDE8D8);
  static const clientInk = Color(0xFF0B2A55);

  // Modo profissional (protótipos da pasta `profissional`): azul
  static const providerAccent = Color(0xFF1B3A78);
  static const providerSoft = Color(0xFFE6EEFB);
  static const providerBright = Color(0xFF5B8DE0);

  // Semânticas
  static const success = Color(0xFF2FB67C);
  static const successSoft = Color(0xFFE3F6EC);
  static const successInk = Color(0xFF0B5B3A);
  static const warning = Color(0xFFE5C566);
  static const warningSoft = Color(0xFFFDEFC0);
  static const warningInk = Color(0xFF7A4A0A);
  static const danger = Color(0xFFC0262D);
  static const dangerSoft = Color(0xFFFADADD);
  static const info = Color(0xFF1D6FE0);
  static const infoSoft = Color(0xFFDCEBFA);
  static const security = Color(0xFF2A7F86);
  static const securitySoft = Color(0xFFD6EFEF);

  // Neutros
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE5E7EB);
  static const surface = Color(0xFFF4F6FA);
  static const star = Color(0xFFF5B400);
}

extension UserModeStyle on UserMode {
  Color get accent => this == UserMode.client ? AppColors.clientAccent : AppColors.providerAccent;
  Color get soft => this == UserMode.client ? AppColors.clientSoft : AppColors.providerSoft;
  String get label => this == UserMode.client ? 'Cliente' : 'Profissional';
}

class AppTheme {
  AppTheme._();

  static final Map<(UserMode?, Brightness), ThemeData> _cache = {};

  /// Tema pronto para o MaterialApp (com cache: montar ThemeData é caro e o
  /// MaterialApp reconstrói a cada troca de modo/tema).
  static ThemeData resolve(UserMode? mode, Brightness brightness) =>
      _cache.putIfAbsent((mode, brightness), () => mode == null ? brand(brightness) : forMode(mode, brightness));

  /// Tema padrão (login, seleção de modo, KYC): azul da marca.
  static ThemeData brand([Brightness brightness = Brightness.light]) =>
      _build(AppColors.navy, brightness, null);

  /// Tema aplicado dentro de cada modo.
  static ThemeData forMode(UserMode mode, [Brightness brightness = Brightness.light]) =>
      _build(mode.accent, brightness, mode);

  /// Mapa M3 → [AppType]. `Text` sem estilo (bodyMedium) já sai em Inter 15/22;
  /// títulos em Plus Jakarta Sans.
  static TextTheme textTheme(AppTokens tk) => TextTheme(
        displayLarge: AppType.displayL,
        displayMedium: AppType.display,
        displaySmall: AppType.headline,
        headlineLarge: AppType.headline,
        headlineMedium: AppType.title,
        headlineSmall: AppType.titleSm,
        titleLarge: AppType.title,
        titleMedium: AppType.titleSm,
        titleSmall: AppType.bodyStrong,
        bodyLarge: AppType.body,
        bodyMedium: AppType.body,
        bodySmall: AppType.bodySm,
        labelLarge: AppType.button,
        labelMedium: AppType.caption.copyWith(fontWeight: FontWeight.w600),
        labelSmall: AppType.overline,
      ).apply(bodyColor: tk.text, displayColor: tk.text);

  static ThemeData _build(Color lightAccent, Brightness brightness, UserMode? mode) {
    final base = brightness == Brightness.dark ? AppTokens.dark : AppTokens.light;
    // No escuro o acento vem do token (dessaturado), nunca da constante.
    final accent = !base.isDark
        ? lightAccent
        : switch (mode) {
            UserMode.client => base.clientAccent,
            UserMode.provider => base.providerAccent,
            null => base.brand,
          };
    // Tinta de TEXTO do acento (>= 4,5:1): no claro, versão escurecida.
    final accentInk = !base.isDark
        ? switch (mode) {
            UserMode.client => base.clientAccentInk,
            UserMode.provider => base.providerAccentInk,
            null => base.brand,
          }
        : accent;
    final accentSoft = switch (mode) {
      UserMode.client => base.clientSoft,
      UserMode.provider => base.providerSoft,
      null => base.infoSoft,
    };
    final tk = base.forAccent(accent: accent, accentInk: accentInk, accentSoft: accentSoft);
    final onAccent = tk.onAccent;
    final scheme = ColorScheme.fromSeed(
      seedColor: lightAccent,
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      surface: tk.background,
      onSurface: tk.text,
      error: tk.danger,
      outline: tk.border,
      surfaceContainerHighest: tk.surface,
      // Elevação tonal: o M3 mistura este tom nas superfícies elevadas.
      surfaceTint: tk.isDark ? Colors.white : Colors.transparent,
    );
    final texts = textTheme(tk);
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppGeometry.buttonRadius));
    final fieldBorderColor = tk.isDark ? tk.border : const Color(0xFFD0D5DD);
    OutlineInputBorder fieldBorder(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
          borderSide: BorderSide(color: c, width: w),
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [tk],
      // Tipografia GLOBAL: qualquer Text sem estilo já sai em Inter/Jakarta.
      fontFamily: AppFonts.inter,
      fontFamilyFallback: AppFonts.fallback,
      textTheme: texts,
      primaryTextTheme: texts,
      pageTransitionsTheme: AppPageTransitions.theme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      scaffoldBackgroundColor: tk.background,
      canvasColor: tk.background,
      cardColor: tk.card,
      dividerColor: tk.border,
      hoverColor: tk.accent.withValues(alpha: 0.04),
      focusColor: tk.accent.withValues(alpha: 0.12),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: tk.accentInk,
        selectionColor: tk.accent.withValues(alpha: 0.28),
        selectionHandleColor: tk.accentInk,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tk.background,
        foregroundColor: tk.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppType.title.copyWith(color: tk.text),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tk.isDark ? tk.surface : tk.background,
        indicatorColor: tk.accentSoft,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? tk.accentInk : tk.textMuted, size: 25),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => AppType.caption.copyWith(
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
            color: s.contains(WidgetState.selected) ? tk.text : tk.textMuted,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: AppType.bodyStrong,
        unselectedLabelStyle: AppType.bodyStrong,
        labelColor: tk.accentInk,
        unselectedLabelColor: tk.textMuted,
        indicatorColor: tk.accent,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: tk.isDark ? tk.raised : tk.border,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.16),
        valueIndicatorColor: accent,
        valueIndicatorTextStyle: AppType.bodyStrong.copyWith(color: onAccent),
        trackHeight: 5,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: tk.isDark ? tk.raised : tk.border,
        circularTrackColor: tk.isDark ? tk.raised : tk.border,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tk.raised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: tk.raised,
        modalBarrierColor: tk.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppGeometry.sheetRadius)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tk.raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppGeometry.cardRadius)),
        titleTextStyle: AppType.title.copyWith(color: tk.text),
        contentTextStyle: AppType.body.copyWith(color: tk.text),
      ),
      cardTheme: CardThemeData(color: tk.card, surfaceTintColor: Colors.transparent, elevation: 0),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          minimumSize: const Size.fromHeight(AppGeometry.buttonHeight),
          shape: buttonShape,
          textStyle: AppType.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tk.accentInk,
          minimumSize: const Size.fromHeight(AppGeometry.buttonHeightCompact + 2),
          side: BorderSide(color: tk.accentInk, width: 1.5),
          shape: buttonShape,
          textStyle: AppType.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tk.accentInk,
          minimumSize: const Size(AppGeometry.minTarget, AppGeometry.minTarget),
          textStyle: AppType.bodyStrong,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size.square(AppGeometry.minTarget)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tk.isDark ? tk.surface : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s16),
        labelStyle: AppType.body.copyWith(color: tk.textMuted),
        floatingLabelStyle: AppType.bodySm.copyWith(color: tk.accentInk, fontWeight: FontWeight.w600),
        hintStyle: AppType.body.copyWith(color: tk.textMuted),
        helperStyle: AppType.caption.copyWith(color: tk.textMuted),
        errorStyle: AppType.caption.copyWith(color: tk.dangerInk, fontWeight: FontWeight.w600),
        helperMaxLines: 3,
        errorMaxLines: 3,
        border: fieldBorder(fieldBorderColor),
        enabledBorder: fieldBorder(fieldBorderColor),
        focusedBorder: fieldBorder(tk.accentInk, 1.8),
        errorBorder: fieldBorder(tk.danger, 1.5),
        focusedErrorBorder: fieldBorder(tk.danger, 2),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: tk.border),
        selectedColor: accent,
        labelStyle: AppType.bodySm.copyWith(color: tk.text, fontWeight: FontWeight.w600),
        secondaryLabelStyle: AppType.bodySm.copyWith(color: onAccent, fontWeight: FontWeight.w600),
        checkmarkColor: onAccent,
      ),
      dividerTheme: DividerThemeData(color: tk.border, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: tk.textMuted,
        textColor: tk.text,
        titleTextStyle: AppType.bodyStrong.copyWith(color: tk.text),
        subtitleTextStyle: AppType.bodySm.copyWith(color: tk.textMuted),
        minVerticalPadding: AppSpace.s8,
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: AppType.bodySm.copyWith(color: tk.background),
        decoration: BoxDecoration(color: tk.text, borderRadius: BorderRadius.circular(8)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tk.raised,
        surfaceTintColor: Colors.transparent,
        textStyle: AppType.body.copyWith(color: tk.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppGeometry.itemRadius)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? onAccent : tk.textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : tk.surface),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tk.text,
        contentTextStyle: AppType.bodySm.copyWith(color: tk.background),
        actionTextColor: tk.isDark ? tk.background : tk.accentSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppGeometry.fieldRadius)),
      ),
    );
  }
}

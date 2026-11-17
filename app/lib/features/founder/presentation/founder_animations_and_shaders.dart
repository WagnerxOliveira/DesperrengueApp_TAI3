import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../../core/services/instant_image_cache_engine.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/utils/money.dart';

bool _isAnimationTestEnv() {
  final name = WidgetsBinding.instance.runtimeType.toString();
  return name.contains('TestWidgetsFlutterBinding') ||
      name.contains('AutomatedTestWidgetsFlutterBinding') ||
      name.contains('LiveTestWidgetsFlutterBinding');
}

/// Sistema Visual **Luxo Silencioso Executivo** (`v2.16.0` — Regra `85% · 10% · 5%`).
///
/// Inspirado em Nubank Ultravioleta, Apple Card/Wallet, Uber Black e Stripe Dashboard:
/// - **85% Neutro Profundo**: Grafite Obsidiana `#0B0E13`, cartões `#141922` com raio `20px`,
///   espaçamento amplo e borda finíssima `1px` branca a `7%` de opacidade (`#12FFFFFF`);
/// - **10% Ouro Champagne Acetinado (`#E5C158` / `#F3D77D`)**: reservado ao botão principal,
///   aba selecionada, brasão oficial e destaque principal de lucro;
/// - **5% Semântico Estrito**:
///   - Verde Esmeralda (`#22C55E`): lucro positivo, PIX confirmado e contas 100% conferidas;
///   - Âmbar Quente (`#F59E0B`): serviço em andamento ou documento aguardando análise;
///   - Vermelho Coral (`#EF4444`): **estritamente proibido** em estado saudável — exclusivo
///     para prejuízo real, disputa aberta, tentativa de invasão bloqueada ou emergência.
@immutable
class FounderSovereignTokens {
  const FounderSovereignTokens._();

  static const Color obsidianBackground = Color(0xFF0B0E13);
  static const Color obsidianSurface = Color(0xFF10151E);
  static const Color obsidianCard = Color(0xFF141922);
  static const Color obsidianRaised = Color(0xFF1B2230);
  static const Color crispBorder = Color(0x16FFFFFF);
  static const Color crispBorderStrong = Color(0x26FFFFFF);

  static const Color primaryInk = Color(0xFFF5F7FA);
  static const Color secondaryInk = Color(0xFFD0D8E5);
  static const Color mutedInk = Color(0xFF8E9BB0);

  static const Color imperialGold = Color(0xFFE5C158);
  static const Color imperialGoldBright = Color(0xFFF3D77D);
  static const Color imperialGoldSoft = Color(0xFF282110);
  static const Color gold24k = Color(0xFFD4AF37);

  static const Color cyberCyan = Color(0xFF5BA8FF);
  static const Color cyberCyanSoft = Color(0xFF122136);

  static const Color solvencyEmerald = Color(0xFF22C55E);
  static const Color solvencyEmeraldSoft = Color(0xFF0F291E);

  static const Color crimsonAlert = Color(0xFFEF4444);
  static const Color crimsonAlertSoft = Color(0xFF2E1418);

  static const Color royalIndigo = Color(0xFF818CF8);
  static const Color warmAmber = Color(0xFFF59E0B);
  static const Color warmAmberSoft = Color(0xFF2B200E);

  static const LinearGradient imperialGoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[imperialGoldBright, imperialGold],
  );

  static const LinearGradient cyberEmeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[cyberCyan, solvencyEmerald],
  );

  static const LinearGradient topSpecularGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: <double>[0.0, 0.18, 1.0],
    colors: <Color>[
      Color(0x0AFFFFFF),
      Color(0x02FFFFFF),
      Color(0x00FFFFFF),
    ],
  );

  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// Tipografia humana, moderna e limpa para títulos e cabeçalhos (nunca monoespaçada).
  static TextStyle titleStyle({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w700,
    Color color = primaryInk,
    double letterSpacing = -0.30,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: 1.24,
    );
  }

  /// Estilo descansado e legível para subtítulos e explicações em português claro.
  static TextStyle subtitleStyle({
    double fontSize = 12.5,
    FontWeight fontWeight = FontWeight.w500,
    Color color = mutedInk,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.1,
      height: 1.44,
    );
  }

  /// Rótulo curto superior discreto (ex.: "SEU LUCRO LÍQUIDO (HOJE)").
  static TextStyle eyebrowStyle({
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w700,
    Color color = mutedInk,
    double letterSpacing = 0.65,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: 1.2,
    );
  }

  /// Exclusivo para valores em R$, contadores numéricos, datas/horários e códigos de 6 dígitos.
  static TextStyle monoMetric({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w800,
    Color color = primaryInk,
    double letterSpacing = -0.45,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: tabularFigures,
      height: 1.14,
    );
  }

  static double safeTopInset(BuildContext context) {
    final mq = MediaQuery.of(context);
    return math.max(mq.padding.top, mq.viewPadding.top);
  }

  static double safeBottomInset(BuildContext context) {
    final mq = MediaQuery.of(context);
    return math.max(mq.padding.bottom, mq.viewPadding.bottom);
  }

  /// Espaço inferior à prova de Android 15/16/17 Edge-to-Edge (barra de 3 botões `48dp`,
  /// barra gestual `24dp` e teclado virtual `viewInsets.bottom`).
  static double modalBottomSafeSpace(
    BuildContext context, {
    double extraWhenKeyboardClosed = 16.0,
    double extraWhenKeyboardOpen = 12.0,
  }) {
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    if (kb > 0) {
      return kb + extraWhenKeyboardOpen;
    }
    return math.max(mq.padding.bottom, mq.viewPadding.bottom) +
        extraWhenKeyboardClosed;
  }

  static ThemeData buildTheme() {
    final base = AppTheme.resolve(null, Brightness.dark);
    return base.copyWith(
      scaffoldBackgroundColor: obsidianBackground,
      canvasColor: obsidianBackground,
      cardColor: obsidianCard,
      dividerColor: crispBorder,
      extensions: <ThemeExtension<dynamic>>[AppTokens.dark],
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: imperialGold,
        onPrimary: const Color(0xFF0B0E13),
        secondary: cyberCyan,
        surface: obsidianBackground,
        onSurface: primaryInk,
        error: crimsonAlert,
        outline: crispBorder,
      ),
    );
  }
}

/// Cartão executivo *Luxo Silencioso* (`#141922`, raio `20px`, padding `20px`, borda `6%` branca)
/// sem barrinhas coloridas competitivas por padrão e com física tátil suave quando clicável.
class FounderGlassCard extends StatefulWidget {
  const FounderGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 20,
    this.backgroundColor = FounderSovereignTokens.obsidianCard,
    this.borderColor,
    this.accentTopBarColor,
    this.showTopAccentBar = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final Color backgroundColor;
  final Color? borderColor;
  final Color? accentTopBarColor;
  final bool showTopAccentBar;
  final VoidCallback? onTap;

  @override
  State<FounderGlassCard> createState() => _FounderGlassCardState();
}

class _FounderGlassCardState extends State<FounderGlassCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = widget.borderColor ??
        (_hovered
            ? FounderSovereignTokens.imperialGold.withValues(alpha: 0.38)
            : FounderSovereignTokens.crispBorder);
    final radius = BorderRadius.circular(widget.borderRadius);

    Widget content = AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: const Cubic(0.22, 1.0, 0.36, 1.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: widget.margin,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: radius,
          border: Border.all(color: effectiveBorder, width: 1.0),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x36000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: FounderSovereignTokens.topSpecularGradient,
                    ),
                  ),
                ),
              ),
              if (widget.showTopAccentBar && widget.accentTopBarColor != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 2.0,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            widget.accentTopBarColor!.withValues(alpha: 0.85),
                            widget.accentTopBarColor!.withValues(alpha: 0.08),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: widget.padding,
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onHighlightChanged: (v) {
            if (_pressed != v) setState(() => _pressed = v);
          },
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap!();
          },
          child: content,
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: content,
    );
  }
}

/// Ponto luminoso orgânico de conexão em tempo real (`7px`) com halo respiratório suave.
/// Em ambiente `flutter test`, mantém renderização determinística sem loop infinito.
class LiveBreathingPulseDot extends StatefulWidget {
  const LiveBreathingPulseDot({
    super.key,
    required this.color,
    this.size = 7.0,
    this.animate = true,
  });

  final Color color;
  final double size;
  final bool animate;

  @override
  State<LiveBreathingPulseDot> createState() => _LiveBreathingPulseDotState();
}

class _LiveBreathingPulseDotState extends State<LiveBreathingPulseDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (widget.animate && !_isAnimationTestEnv()) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2100),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    if (c == null) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: widget.color.withValues(alpha: 0.45),
              blurRadius: 6,
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final t = Curves.easeInOutSine.transform(c.value);
        return SizedBox(
          width: widget.size * 2.1,
          height: widget.size * 2.1,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: widget.size * (1.15 + 0.85 * t),
                height: widget.size * (1.15 + 0.85 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.26 * (1.0 - 0.55 * t)),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Seletor segmentado deslizante estilo Apple Card / Stripe com pílula animada a 120 FPS.
class AnimatedSlidingPillSwitch extends StatelessWidget {
  const AnimatedSlidingPillSwitch({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.icons,
    this.precisionIcons,
  });

  final List<String> labels;
  final List<IconData>? icons;
  final List<FounderIconGlyph>? precisionIcons;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final count = labels.length;
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FounderSovereignTokens.crispBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segWidth = constraints.maxWidth / count;
          final clampedIdx = selectedIndex.clamp(0, count - 1);
          return Stack(
            children: <Widget>[
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: const Cubic(0.22, 1.0, 0.36, 1.0),
                left: clampedIdx * segWidth,
                top: 0,
                bottom: 0,
                width: segWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: FounderSovereignTokens.obsidianRaised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: FounderSovereignTokens.imperialGold
                          .withValues(alpha: 0.45),
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: List<Widget>.generate(count, (idx) {
                  final active = clampedIdx == idx;
                  final precisionGlyph = (precisionIcons != null &&
                          idx < precisionIcons!.length)
                      ? precisionIcons![idx]
                      : null;
                  final icon =
                      (icons != null && idx < icons!.length) ? icons![idx] : null;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onChanged(idx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            if (precisionGlyph != null) ...<Widget>[
                              FounderPrecisionIcon(
                                precisionGlyph,
                                size: 15.5,
                                isActive: active,
                                color: active
                                    ? FounderSovereignTokens.imperialGoldBright
                                    : FounderSovereignTokens.mutedInk,
                                accentColor: active
                                    ? FounderSovereignTokens.gold24k
                                    : FounderSovereignTokens.mutedInk,
                              ),
                              const SizedBox(width: 6),
                            ] else if (icon != null) ...<Widget>[
                              Icon(
                                icon,
                                size: 15,
                                color: active
                                    ? FounderSovereignTokens.imperialGoldBright
                                    : FounderSovereignTokens.mutedInk,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                labels[idx],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: active
                                      ? FounderSovereignTokens.primaryInk
                                      : FounderSovereignTokens.mutedInk,
                                  fontSize: 12.5,
                                  fontWeight:
                                      active ? FontWeight.w700 : FontWeight.w500,
                                  letterSpacing: -0.15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Orquestrador de entrada escalonada (120 FPS) com curvas quínticas
/// `Cubic(0.22, 1.0, 0.36, 1.0)` e suporte a física `SpringSimulation`.
class StaggeredEntranceOrchestrator extends StatefulWidget {
  const StaggeredEntranceOrchestrator({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 520),
    this.useSpringPhysics = false,
  });

  final Widget Function(BuildContext context, Animation<double> masterAnimation)
      builder;
  final Duration duration;
  final bool useSpringPhysics;

  static const List<Interval> canonicalIntervals = <Interval>[
    Interval(0.00, 0.45, curve: Cubic(0.22, 1.0, 0.36, 1.0)),
    Interval(0.10, 0.65, curve: Cubic(0.22, 1.0, 0.36, 1.0)),
    Interval(0.22, 0.85, curve: Cubic(0.22, 1.0, 0.36, 1.0)),
    Interval(0.32, 1.00, curve: Cubic(0.22, 1.0, 0.36, 1.0)),
  ];

  static Animation<double> intervalForStage(
    Animation<double> master,
    int stageIndex,
  ) {
    final idx = stageIndex.clamp(0, canonicalIntervals.length - 1);
    return CurvedAnimation(
      parent: master,
      curve: canonicalIntervals[idx],
    );
  }

  static double evaluateDampedSpring(
    double t, {
    double mass = 1.0,
    double stiffness = 180.0,
    double damping = 22.0,
  }) {
    final clamped = t.clamp(0.0, 1.0);
    final sim = SpringSimulation(
      SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
      0.0,
      1.0,
      0.0,
    );
    return sim.x(clamped * 0.65).clamp(0.0, 1.08);
  }

  @override
  State<StaggeredEntranceOrchestrator> createState() =>
      _StaggeredEntranceOrchestratorState();
}

class _StaggeredEntranceOrchestratorState
    extends State<StaggeredEntranceOrchestrator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    if (widget.useSpringPhysics) {
      final spring = SpringSimulation(
        const SpringDescription(mass: 1.0, stiffness: 185.0, damping: 23.0),
        0.0,
        1.0,
        0.0,
      );
      _controller.animateWith(spring);
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _controller);
  }
}

/// Item de revelação coreografada combinando `FadeTransition` + translação vertical
/// suave (`12px`) + `ScaleTransition(0.985 -> 1.0)`.
class StaggeredRevealItem extends StatelessWidget {
  const StaggeredRevealItem({
    super.key,
    required this.animation,
    required this.child,
    this.stageIndex = 0,
    this.verticalOffsetPx = 12.0,
    this.initialScale = 0.985,
  });

  final Animation<double> animation;
  final Widget child;
  final int stageIndex;
  final double verticalOffsetPx;
  final double initialScale;

  @override
  Widget build(BuildContext context) {
    final curved = StaggeredEntranceOrchestrator.intervalForStage(
      animation,
      stageIndex,
    );
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, staticChild) {
        final v = curved.value.clamp(0.0, 1.0);
        final dy = (1.0 - v) * verticalOffsetPx;
        final scale = initialScale + (1.0 - initialScale) * v;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: staticChild,
            ),
          ),
        );
      },
    );
  }
}

/// Wrapper de privacidade instantânea (`ClipRect` + `BackdropFilter` `sigma 16x16`)
/// acionado pelo botão de olho no topo ou pela tecla `Space`.
class FounderPrivacyBlurWrap extends StatelessWidget {
  const FounderPrivacyBlurWrap({
    super.key,
    required this.privacyBlurActive,
    required this.child,
    this.borderRadius = 8,
  });

  final bool privacyBlurActive;
  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!privacyBlurActive) return child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[
          child,
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: FounderSovereignTokens.obsidianBackground
                      .withValues(alpha: 0.38),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Odômetro financeiro em centavos inteiros (`Money.formatBrl`) com interpolação real
/// (`oldCents -> newCents`) a 120 FPS, algarismos tabulares (`tabularFigures`) e opção
/// de moeda executiva em hierarquia dupla (`R$` e `,00` a `65%` de brilho e escala menor).
class AnimatedMoneyOdometer extends StatefulWidget {
  const AnimatedMoneyOdometer({
    super.key,
    required this.cents,
    this.privacyBlurActive = false,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 340),
    this.maxLines = 1,
    this.splitCurrencyParts = false,
  });

  final int cents;
  final bool privacyBlurActive;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;
  final int maxLines;
  final bool splitCurrencyParts;

  @override
  State<AnimatedMoneyOdometer> createState() => _AnimatedMoneyOdometerState();
}

class _AnimatedMoneyOdometerState extends State<AnimatedMoneyOdometer> {
  late int _fromCents = widget.cents;

  @override
  void didUpdateWidget(covariant AnimatedMoneyOdometer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cents != widget.cents) {
      _fromCents = oldWidget.cents;
    }
  }

  Widget _buildFormattedText(int currentCents, TextStyle effectiveStyle) {
    if (widget.privacyBlurActive) {
      return Text(
        '${widget.prefix}R\$ •••••${widget.suffix}',
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
        style: effectiveStyle,
      );
    }
    final rawBrl = Money.formatBrl(currentCents);
    if (!widget.splitCurrencyParts) {
      return Text(
        '${widget.prefix}$rawBrl${widget.suffix}',
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
        style: effectiveStyle,
      );
    }

    // Separa símbolo ("R$ " / "-R$ "), inteiro ("1.480") e centavos (",80") mantendo um único Text.rich
    final baseFontSize = effectiveStyle.fontSize ?? 28;
    final baseColor = effectiveStyle.color ?? FounderSovereignTokens.primaryInk;
    final mutedPartStyle = effectiveStyle.copyWith(
      fontSize: (baseFontSize * 0.62).clamp(12.0, 26.0),
      fontWeight: FontWeight.w700,
      color: baseColor.withValues(alpha: 0.66),
    );

    final commaIdx = rawBrl.lastIndexOf(',');
    final rsIdx = rawBrl.indexOf('R\$');
    if (commaIdx > 0 && rsIdx >= 0) {
      final currencyHead = rawBrl.substring(0, rsIdx + 2);
      final middleWithSpace = rawBrl.substring(rsIdx + 2, commaIdx);
      final centsTail = rawBrl.substring(commaIdx);
      return Text.rich(
        TextSpan(
          children: <InlineSpan>[
            if (widget.prefix.isNotEmpty)
              TextSpan(text: widget.prefix, style: mutedPartStyle),
            TextSpan(text: '$currencyHead ', style: mutedPartStyle),
            TextSpan(text: middleWithSpace.trimLeft(), style: effectiveStyle),
            TextSpan(text: centsTail, style: mutedPartStyle),
            if (widget.suffix.isNotEmpty)
              TextSpan(text: widget.suffix, style: mutedPartStyle),
          ],
        ),
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text(
      '${widget.prefix}$rawBrl${widget.suffix}',
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
      style: effectiveStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = (widget.style ??
            FounderSovereignTokens.monoMetric(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ))
        .copyWith(fontFeatures: FounderSovereignTokens.tabularFigures);

    final odometer = TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _fromCents.toDouble(),
        end: widget.cents.toDouble(),
      ),
      duration: widget.duration,
      curve: const Cubic(0.22, 1.0, 0.36, 1.0),
      builder: (context, animatedValue, _) {
        return _buildFormattedText(animatedValue.round(), effectiveStyle);
      },
    );

    if (!widget.privacyBlurActive) {
      return odometer;
    }

    return ClipRect(
      child: Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[
          Opacity(
            opacity: 0.85,
            child: odometer,
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                alignment: Alignment.centerLeft,
                color: FounderSovereignTokens.obsidianCard
                    .withValues(alpha: 0.52),
                child: Text(
                  '${widget.prefix}R\$ •••••${widget.suffix}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: effectiveStyle.copyWith(
                    color: FounderSovereignTokens.mutedInk,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Imagem Ultra-HD com calibração exata de DPR (`ResizeImage.resizeIfNeeded`),
/// `FilterQuality.high`, `isAntiAlias: true`, `gaplessPlayback: true` e hit L1
/// em `0 ms` via `InstantImageCacheEngine.instance.peekMemoryBytes`.
class FounderUltraHdImage extends StatefulWidget {
  const FounderUltraHdImage({
    super.key,
    required this.imageUrl,
    this.logicalWidth = 56,
    this.logicalHeight = 56,
    this.borderRadius = 12,
    this.fallbackLabel = 'DESP',
  });

  final String? imageUrl;
  final double logicalWidth;
  final double logicalHeight;
  final double borderRadius;
  final String fallbackLabel;

  @override
  State<FounderUltraHdImage> createState() => _FounderUltraHdImageState();
}

class _FounderUltraHdImageState extends State<FounderUltraHdImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _resolveBytes();
  }

  @override
  void didUpdateWidget(covariant FounderUltraHdImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolveBytes();
    }
  }

  void _resolveBytes() {
    final raw = widget.imageUrl?.trim() ?? '';
    if (raw.isEmpty) {
      _bytes = null;
      return;
    }
    final engine = InstantImageCacheEngine.instance;
    final syncHit = engine.peekMemoryBytes(raw);
    if (syncHit != null &&
        InstantImageCacheEngine.looksLikeValidEncodedImage(syncHit)) {
      _bytes = syncHit;
      return;
    }
    _bytes = null;
    engine.getOrFetchUrlBytes(raw).then((fetched) {
      if (!mounted || fetched == null) return;
      if (InstantImageCacheEngine.looksLikeValidEncodedImage(fetched)) {
        setState(() => _bytes = fetched);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.5);
    final cacheWidth = (widget.logicalWidth * dpr).round().clamp(32, 2048);
    final cacheHeight = (widget.logicalHeight * dpr).round().clamp(32, 2048);
    final radius = BorderRadius.circular(widget.borderRadius);

    final memBytes = _bytes;
    if (memBytes != null) {
      final provider = ResizeImage.resizeIfNeeded(
        cacheWidth,
        cacheHeight,
        MemoryImage(memBytes),
      );
      return ClipRRect(
        borderRadius: radius,
        child: Image(
          image: provider,
          width: widget.logicalWidth,
          height: widget.logicalHeight,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _buildVectorFallback(radius),
        ),
      );
    }

    return _buildVectorFallback(radius);
  }

  Widget _buildVectorFallback(BorderRadius radius) {
    final trimmed = widget.fallbackLabel.trim();
    final initials = trimmed.isEmpty
        ? 'W'
        : trimmed.substring(0, math.min(2, trimmed.length)).toUpperCase();

    return Container(
      width: widget.logicalWidth,
      height: widget.logicalHeight,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF1D2432),
            Color(0xFF10151F),
          ],
        ),
        border: Border.all(
          color: FounderSovereignTokens.imperialGold.withValues(alpha: 0.35),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        maxLines: 1,
        style: TextStyle(
          fontSize: (math.min(widget.logicalWidth, widget.logicalHeight) * 0.36)
              .clamp(11.0, 18.0),
          fontWeight: FontWeight.w800,
          color: FounderSovereignTokens.imperialGoldBright,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Brasão vetorial oficial (`CustomPainter` + `RepaintBoundary`) do **Desperrengue CEO** a 120 FPS.
class FounderSovereignCrest extends StatelessWidget {
  const FounderSovereignCrest({
    super.key,
    this.size = 44,
    this.isSovereignCeo = true,
  });

  final double size;
  final bool isSovereignCeo;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _FounderSovereignCrestPainter(
            isSovereignCeo: isSovereignCeo,
          ),
        ),
      ),
    );
  }
}

class _FounderSovereignCrestPainter extends CustomPainter {
  const _FounderSovereignCrestPainter({required this.isSovereignCeo});

  final bool isSovereignCeo;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final minSide = math.min(w, h);
    final center = Offset(w / 2, h / 2);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(minSide * 0.02),
      Radius.circular(minSide * 0.26),
    );

    final bgPaint = Paint()
      ..isAntiAlias = true
      ..shader = RadialGradient(
        center: const Alignment(-0.06, -0.08),
        radius: 0.78,
        colors: isSovereignCeo
            ? const <Color>[
                Color(0xFF261E0D),
                Color(0xFF0E131C),
                Color(0xFF07090E),
              ]
            : const <Color>[
                Color(0xFF102830),
                Color(0xFF0C1018),
                Color(0xFF05070B),
              ],
        stops: const <double>[0.0, 0.56, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, bgPaint);

    final borderPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = (minSide * 0.032).clamp(1.0, 2.2)
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isSovereignCeo
            ? const <Color>[
                Color(0xFFF3D77D),
                Color(0xFFE5C158),
                Color(0xFF8C6A22),
              ]
            : const <Color>[
                Color(0xFF67E8F9),
                Color(0xFF52B7C0),
                Color(0xFF0E7490),
              ],
      ).createShader(rect);
    canvas.drawRRect(rrect, borderPaint);

    final haloRadius = minSide * 0.42;
    final haloPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = (minSide * 0.014).clamp(0.6, 1.4)
      ..color = (isSovereignCeo
              ? FounderSovereignTokens.imperialGoldBright
              : FounderSovereignTokens.cyberCyan)
          .withValues(alpha: 0.22);
    canvas.drawCircle(center, haloRadius, haloPaint);

    final boxSize = minSide * 0.58;
    final left = center.dx - boxSize / 2;
    final top = center.dy - boxSize / 2;

    canvas.save();
    canvas.translate(left, top);

    double px(double nx) => (nx + 0.012) * boxSize;
    double py(double ny) => (ny + 0.084) * boxSize;

    final strokeMain = boxSize * 0.130;
    final strokeCheck = boxSize * 0.122;

    final dHousePath = Path()
      ..moveTo(px(0.21), py(0.595))
      ..lineTo(px(0.21), py(0.84))
      ..quadraticBezierTo(px(0.21), py(0.91), px(0.28), py(0.91))
      ..lineTo(px(0.49), py(0.91))
      ..arcToPoint(
        Offset(px(0.7375), py(0.3125)),
        radius: Radius.circular(boxSize * 0.35),
        largeArc: false,
        clockwise: false,
      )
      ..lineTo(px(0.555), py(0.130))
      ..quadraticBezierTo(px(0.490), py(0.065), px(0.425), py(0.130))
      ..lineTo(px(0.105), py(0.450));

    final dPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeMain
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isSovereignCeo
            ? const <Color>[
                Color(0xFFFFFBEB),
                Color(0xFFF3D77D),
                Color(0xFFE5C158),
                Color(0xFFC89B32),
              ]
            : const <Color>[
                Color(0xFFECFEFF),
                Color(0xFF67E8F9),
                Color(0xFF52B7C0),
                Color(0xFF0891B2),
              ],
        stops: const <double>[0.0, 0.28, 0.72, 1.0],
      ).createShader(Offset.zero & Size.square(boxSize));
    canvas.drawPath(dHousePath, dPaint);

    final dCx = px(0.490);
    final dCy = py(-0.094);
    final dSpan = boxSize * 0.088;
    final pTop = Offset(dCx, dCy - dSpan);
    final pRight = Offset(dCx + dSpan, dCy);
    final pBottom = Offset(dCx, dCy + dSpan);
    final pLeft = Offset(dCx - dSpan, dCy);
    final pMid = Offset(dCx, dCy);

    void drawFacet(Offset a, Offset b, Color color) {
      final p = Path()
        ..moveTo(pMid.dx, pMid.dy)
        ..lineTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..close();
      canvas.drawPath(
        p,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.fill
          ..color = color,
      );
    }

    if (isSovereignCeo) {
      drawFacet(pLeft, pTop, const Color(0xFFFFFBEB));
      drawFacet(pTop, pRight, const Color(0xFFF3D77D));
      drawFacet(pBottom, pLeft, const Color(0xFFE5C158));
      drawFacet(pRight, pBottom, const Color(0xFFB78826));
    } else {
      drawFacet(pLeft, pTop, const Color(0xFFECFEFF));
      drawFacet(pTop, pRight, const Color(0xFF67E8F9));
      drawFacet(pBottom, pLeft, const Color(0xFF3CCB8C));
      drawFacet(pRight, pBottom, const Color(0xFF0E7490));
    }

    final checkPath = Path()
      ..moveTo(px(0.380), py(0.555))
      ..lineTo(px(0.470), py(0.645))
      ..lineTo(px(0.625), py(0.455));

    final checkPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeCheck
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: isSovereignCeo
            ? const <Color>[
                Color(0xFF16A34A),
                Color(0xFF22C55E),
                Color(0xFF86EFAC),
                Color(0xFFECFDF5),
              ]
            : const <Color>[
                Color(0xFFD97706),
                Color(0xFFF59E0B),
                Color(0xFFFDE047),
                Color(0xFFFFFBEB),
              ],
        stops: const <double>[0.0, 0.35, 0.75, 1.0],
      ).createShader(
        Rect.fromLTRB(px(0.35), py(0.44), px(0.65), py(0.66)),
      );
    canvas.drawPath(checkPath, checkPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FounderSovereignCrestPainter oldDelegate) {
    return oldDelegate.isSovereignCeo != isSovereignCeo;
  }
}


// ============================================================================
// SISTEMA UNIFICADO DE ICONOGRAFIA VETORIAL DE PRECISÃO (`FounderPrecisionIcon`)
// Geometria óptica em 3 camadas (Vidro Duotone 14% + Traço 1.72px + Acento 24k)
// ============================================================================

enum FounderIconGlyph {
  // 1. Abas de Navegação Executiva
  navHome,
  navFinance,
  navOrders,
  navPeople,
  navAccount,

  // 2. Tesouraria, Receita, Split & Simulação
  moneySplitSankey,
  profitJCurve,
  monteCarloCone,
  pixDiamond,
  walletVault,
  expenseReceipt,

  // 3. Impostos, Notas Fiscais & Contabilidade
  taxBankDas,
  nfeBarcode,
  accountingPackPdf,

  // 4. Calendário & Tempo
  calendarExec,
  clockSla,
  upcomingEvent,

  // 5. Cartografia, Radar & HUD de Mapa
  radarPulse,
  mapPinLuxury,
  moonDarkMap,
  sunLightMap,
  compassRose,
  zoomPlus,
  zoomMinus,
  gpsTarget,
  fullscreenExpand,
  fullscreenExit,

  // 6. Mediações, Segurança, Cofre & OTA
  mediationBalance,
  shieldVerified,
  vaultLock,
  vaultOpen,
  masterKey,
  biometricId,
  eyeOpen,
  eyeClosed,
  mailEnvelope,
  mailDispatched,
  clipboardOtp,
  otaDirectUpdate,
  duressEmergencyShield,
  screenCaptureShield,

  // 7. Pessoas, Perfis & Avaliações
  userClient,
  userProvider,
  dualModeVenn,
  starRating,

  // 8. Alertas & Ações Rápidas
  warningTriangle,
  checkValid,
  ringPending,
  sparkBolt,
  copilotAiStar,
  sendVector,
  refreshArc,
  closeCross,
  signOutDoor,
  trashDelete,
  searchGlass,
  chevronLeft,
  chevronRight,
  chevronDown,
  chevronUp,
  arrowBack,
}

/// Ícone vetorial executivo desenhado matematicamente no grid canônico `24×24`
/// com calibração óptica de traço não-linear (`1.28px` em `14px` até `1.85px` em `26px`),
/// preenchimento de vidro duotone (`13%–17%`) e micro-acento especular 24k Gold / Semântico.
class FounderPrecisionIcon extends StatelessWidget {
  const FounderPrecisionIcon(
    this.glyph, {
    super.key,
    this.size = 18.0,
    this.color,
    this.accentColor,
    this.strokeWidth,
    this.isActive = false,
    this.duotoneAlpha,
  });

  final FounderIconGlyph glyph;
  final double size;
  final Color? color;
  final Color? accentColor;
  final double? strokeWidth;
  final bool isActive;
  final double? duotoneAlpha;

  @override
  Widget build(BuildContext context) {
    final primary = color ??
        IconTheme.of(context).color ??
        FounderSovereignTokens.primaryInk;
    final accent = accentColor ?? _defaultAccentFor(glyph, primary, isActive);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FounderPrecisionIconPainter(
          glyph: glyph,
          primaryColor: primary,
          accentColor: accent,
          strokeWidth: strokeWidth,
          isActive: isActive,
          duotoneAlpha: duotoneAlpha,
        ),
      ),
    );
  }

  static Color _defaultAccentFor(
    FounderIconGlyph g,
    Color primary,
    bool isActive,
  ) {
    if (isActive) return FounderSovereignTokens.imperialGoldBright;
    return switch (g) {
      FounderIconGlyph.profitJCurve ||
      FounderIconGlyph.pixDiamond ||
      FounderIconGlyph.shieldVerified ||
      FounderIconGlyph.mailDispatched ||
      FounderIconGlyph.checkValid =>
        FounderSovereignTokens.solvencyEmerald,
      FounderIconGlyph.taxBankDas ||
      FounderIconGlyph.clockSla ||
      FounderIconGlyph.upcomingEvent ||
      FounderIconGlyph.mediationBalance ||
      FounderIconGlyph.warningTriangle =>
        FounderSovereignTokens.warmAmber,
      FounderIconGlyph.duressEmergencyShield ||
      FounderIconGlyph.trashDelete =>
        FounderSovereignTokens.crimsonAlert,
      FounderIconGlyph.monteCarloCone ||
      FounderIconGlyph.radarPulse ||
      FounderIconGlyph.gpsTarget =>
        FounderSovereignTokens.cyberCyan,
      _ => primary == FounderSovereignTokens.mutedInk
          ? FounderSovereignTokens.secondaryInk
          : FounderSovereignTokens.imperialGoldBright,
    };
  }
}

/// Emblema arquitetônico discreto (*Obsidian Squircle* sem bordas pesadas) para
/// ancorar títulos principais de cartões e folhas executivas.
class FounderPrecisionBadge extends StatelessWidget {
  const FounderPrecisionBadge(
    this.glyph, {
    super.key,
    this.boxSize = 36.0,
    this.iconSize = 18.0,
    this.tintColor,
    this.accentColor,
    this.isActive = true,
  });

  final FounderIconGlyph glyph;
  final double boxSize;
  final double iconSize;
  final Color? tintColor;
  final Color? accentColor;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final tint = tintColor ?? FounderSovereignTokens.imperialGoldBright;
    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(boxSize * 0.30),
        border: Border.all(
          color: tint.withValues(alpha: 0.22),
        ),
      ),
      alignment: Alignment.center,
      child: FounderPrecisionIcon(
        glyph,
        size: iconSize,
        color: tint,
        accentColor: accentColor ?? tint,
        isActive: isActive,
      ),
    );
  }
}

class _FounderPrecisionIconPainter extends CustomPainter {
  const _FounderPrecisionIconPainter({
    required this.glyph,
    required this.primaryColor,
    required this.accentColor,
    required this.isActive,
    this.strokeWidth,
    this.duotoneAlpha,
  });

  final FounderIconGlyph glyph;
  final Color primaryColor;
  final Color accentColor;
  final bool isActive;
  final double? strokeWidth;
  final double? duotoneAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    final minSide = math.min(size.width, size.height);
    if (minSide <= 0) return;

    final scale = minSide / 24.0;
    final dx = (size.width - minSide) * 0.5;
    final dy = (size.height - minSide) * 0.5;

    final nominal = strokeWidth ?? (isActive ? 1.82 : 1.68);
    final opticalPx =
        (nominal * math.pow(minSide / 24.0, 0.82)).clamp(1.22, 2.35);
    final sw = opticalPx / scale;

    final glassAlpha = duotoneAlpha ?? (isActive ? 0.18 : 0.13);
    final duoPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..color = accentColor.withValues(alpha: glassAlpha);

    final mainStroke = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = primaryColor;

    final accentStroke = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accentColor;

    final accentFill = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..color = accentColor;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    RRect rr(double l, double t, double r, double b, double rad) =>
        RRect.fromRectAndRadius(Rect.fromLTRB(l, t, r, b), Radius.circular(rad));

    switch (glyph) {
      case FounderIconGlyph.navHome:
        final body = Path()
          ..moveTo(5.2, 10.2)
          ..lineTo(12.0, 4.4)
          ..lineTo(18.8, 10.2)
          ..lineTo(18.8, 18.2)
          ..quadraticBezierTo(18.8, 20.0, 17.0, 20.0)
          ..lineTo(7.0, 20.0)
          ..quadraticBezierTo(5.2, 20.0, 5.2, 18.2)
          ..close();
        canvas.drawPath(body, duoPaint);
        final roof = Path()
          ..moveTo(3.6, 11.2)
          ..lineTo(12.0, 4.0)
          ..lineTo(20.4, 11.2);
        canvas.drawPath(roof, mainStroke);
        final walls = Path()
          ..moveTo(5.6, 10.0)
          ..lineTo(5.6, 18.2)
          ..quadraticBezierTo(5.6, 20.0, 7.4, 20.0)
          ..lineTo(16.6, 20.0)
          ..quadraticBezierTo(18.4, 20.0, 18.4, 18.2)
          ..lineTo(18.4, 10.0);
        canvas.drawPath(walls, mainStroke);
        canvas.drawLine(
          const Offset(12.0, 13.4),
          const Offset(12.0, 17.0),
          accentStroke,
        );

      case FounderIconGlyph.navFinance:
      case FounderIconGlyph.walletVault:
        final card = rr(3.5, 6.2, 20.5, 19.2, 2.8);
        canvas.drawRRect(card, duoPaint);
        final topFlap = Path()
          ..moveTo(5.8, 6.2)
          ..lineTo(5.8, 5.0)
          ..quadraticBezierTo(5.8, 3.8, 7.2, 3.8)
          ..lineTo(17.2, 3.8);
        canvas.drawPath(topFlap, mainStroke);
        canvas.drawRRect(card, mainStroke);
        canvas.drawRRect(rr(15.0, 10.7, 20.8, 14.7, 1.8), accentStroke);
        canvas.drawCircle(const Offset(17.4, 12.7), 1.0, accentFill);

      case FounderIconGlyph.navOrders:
        final board = rr(5.0, 5.0, 19.0, 20.4, 2.5);
        canvas.drawRRect(board, duoPaint);
        canvas.drawRRect(board, mainStroke);
        canvas.drawRRect(
          rr(9.0, 3.2, 15.0, 6.2, 1.3),
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.fill
            ..color = FounderSovereignTokens.obsidianCard,
        );
        canvas.drawRRect(rr(9.0, 3.2, 15.0, 6.2, 1.3), accentStroke);
        canvas.drawLine(
          const Offset(8.4, 10.6),
          const Offset(15.6, 10.6),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(8.4, 14.2),
          const Offset(12.8, 14.2),
          mainStroke,
        );
        final chk = Path()
          ..moveTo(13.8, 15.6)
          ..lineTo(15.1, 16.9)
          ..lineTo(17.4, 14.2);
        canvas.drawPath(chk, accentStroke);

      case FounderIconGlyph.navPeople:
        canvas.drawCircle(const Offset(9.4, 8.6), 3.0, duoPaint);
        canvas.drawCircle(const Offset(9.4, 8.6), 3.0, mainStroke);
        final shoulders = Path()
          ..moveTo(4.0, 19.2)
          ..cubicTo(4.0, 15.2, 14.8, 15.2, 14.8, 19.2);
        canvas.drawPath(shoulders, mainStroke);
        canvas.drawCircle(const Offset(16.2, 9.2), 2.2, accentStroke);
        final sideShoulder = Path()
          ..moveTo(15.6, 15.4)
          ..cubicTo(18.2, 15.7, 20.2, 17.0, 20.2, 19.2);
        canvas.drawPath(sideShoulder, accentStroke);

      case FounderIconGlyph.navAccount:
        canvas.drawCircle(const Offset(12.0, 12.0), 8.8, duoPaint);
        canvas.drawCircle(const Offset(12.0, 12.0), 8.8, mainStroke);
        canvas.drawCircle(const Offset(12.0, 9.6), 2.6, mainStroke);
        final bust = Path()
          ..moveTo(7.3, 18.0)
          ..cubicTo(8.2, 14.8, 15.8, 14.8, 16.7, 18.0);
        canvas.drawPath(bust, mainStroke);
        final gem = Path()
          ..moveTo(18.2, 4.4)
          ..lineTo(19.5, 5.7)
          ..lineTo(18.2, 7.0)
          ..lineTo(16.9, 5.7)
          ..close();
        canvas.drawPath(gem, accentFill);

      case FounderIconGlyph.moneySplitSankey:
        canvas.drawCircle(const Offset(4.8, 12.0), 2.2, duoPaint);
        final up = Path()
          ..moveTo(7.0, 12.0)
          ..cubicTo(11.2, 12.0, 11.8, 7.0, 17.2, 7.0);
        final down = Path()
          ..moveTo(7.0, 12.0)
          ..cubicTo(11.2, 12.0, 11.8, 17.0, 17.2, 17.0);
        canvas.drawPath(up, accentStroke);
        canvas.drawPath(down, mainStroke);
        canvas.drawCircle(const Offset(4.8, 12.0), 2.1, mainStroke);
        canvas.drawCircle(const Offset(19.0, 7.0), 1.9, accentFill);
        canvas.drawCircle(const Offset(19.0, 17.0), 1.9, mainStroke);

      case FounderIconGlyph.profitJCurve:
        final area = Path()
          ..moveTo(3.8, 18.5)
          ..quadraticBezierTo(9.2, 18.0, 12.6, 12.6)
          ..quadraticBezierTo(15.6, 7.8, 19.8, 6.2)
          ..lineTo(19.8, 18.5)
          ..close();
        canvas.drawPath(area, duoPaint);
        final curve = Path()
          ..moveTo(3.8, 17.8)
          ..quadraticBezierTo(9.2, 17.4, 12.6, 12.2)
          ..quadraticBezierTo(15.6, 7.6, 19.8, 6.0);
        canvas.drawPath(curve, mainStroke);
        final head = Path()
          ..moveTo(16.2, 5.8)
          ..lineTo(20.0, 5.8)
          ..lineTo(20.0, 9.6);
        canvas.drawPath(head, accentStroke);

      case FounderIconGlyph.monteCarloCone:
        final cone = Path()
          ..moveTo(4.0, 15.5)
          ..lineTo(20.0, 5.8)
          ..lineTo(20.0, 18.2)
          ..close();
        canvas.drawPath(cone, duoPaint);
        canvas.drawLine(
          const Offset(4.0, 15.5),
          const Offset(20.0, 5.8),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(4.0, 15.5),
          const Offset(20.0, 18.2),
          mainStroke,
        );
        final median = Path()
          ..moveTo(4.0, 15.5)
          ..quadraticBezierTo(12.0, 13.2, 19.8, 11.6);
        canvas.drawPath(median, accentStroke);
        canvas.drawCircle(const Offset(19.8, 11.6), 1.5, accentFill);

      case FounderIconGlyph.pixDiamond:
        canvas.save();
        canvas.translate(12.0, 12.0);
        canvas.rotate(math.pi / 4);
        final d = rr(-6.2, -6.2, 6.2, 6.2, 2.1);
        canvas.drawRRect(d, duoPaint);
        canvas.drawRRect(d, mainStroke);
        canvas.restore();
        final beam = Path()
          ..moveTo(8.5, 10.2)
          ..lineTo(10.8, 12.0)
          ..lineTo(8.5, 13.8)
          ..moveTo(15.5, 10.2)
          ..lineTo(13.2, 12.0)
          ..lineTo(15.5, 13.8);
        canvas.drawPath(beam, accentStroke);

      case FounderIconGlyph.expenseReceipt:
        final doc = rr(4.0, 5.2, 20.0, 18.8, 2.5);
        canvas.drawRRect(doc, duoPaint);
        canvas.drawRRect(doc, mainStroke);
        canvas.drawLine(
          const Offset(4.2, 9.4),
          const Offset(19.8, 9.4),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(8.0, 14.2),
          const Offset(12.4, 14.2),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(16.2, 12.5),
          const Offset(16.2, 15.9),
          accentStroke,
        );
        canvas.drawLine(
          const Offset(14.5, 14.2),
          const Offset(17.9, 14.2),
          accentStroke,
        );

      case FounderIconGlyph.taxBankDas:
        final roofTri = Path()
          ..moveTo(3.8, 9.2)
          ..lineTo(12.0, 4.0)
          ..lineTo(20.2, 9.2)
          ..close();
        canvas.drawPath(roofTri, duoPaint);
        canvas.drawPath(roofTri, mainStroke);
        canvas.drawLine(
          const Offset(4.0, 19.6),
          const Offset(20.0, 19.6),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(7.2, 9.6),
          const Offset(7.2, 19.2),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(12.0, 9.6),
          const Offset(12.0, 19.2),
          accentStroke,
        );
        canvas.drawLine(
          const Offset(16.8, 9.6),
          const Offset(16.8, 19.2),
          mainStroke,
        );

      case FounderIconGlyph.nfeBarcode:
        final sheet = rr(4.5, 3.8, 19.5, 20.2, 2.4);
        canvas.drawRRect(sheet, duoPaint);
        canvas.drawRRect(sheet, mainStroke);
        canvas.drawLine(
          const Offset(8.2, 12.2),
          const Offset(8.2, 16.8),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(11.4, 11.2),
          const Offset(11.4, 16.8),
          accentStroke,
        );
        canvas.drawLine(
          const Offset(14.8, 12.2),
          const Offset(14.8, 16.8),
          mainStroke,
        );
        final miniChk = Path()
          ..moveTo(13.8, 7.6)
          ..lineTo(15.0, 8.8)
          ..lineTo(17.2, 6.5);
        canvas.drawPath(miniChk, accentStroke);

      case FounderIconGlyph.accountingPackPdf:
        final page = Path()
          ..moveTo(5.5, 3.6)
          ..lineTo(14.2, 3.6)
          ..lineTo(18.6, 8.0)
          ..lineTo(18.6, 20.4)
          ..lineTo(5.5, 20.4)
          ..close();
        canvas.drawPath(page, duoPaint);
        canvas.drawPath(page, mainStroke);
        final fold = Path()
          ..moveTo(14.0, 3.8)
          ..lineTo(14.0, 8.2)
          ..lineTo(18.4, 8.2);
        canvas.drawPath(fold, accentStroke);
        canvas.drawLine(
          const Offset(8.6, 12.4),
          const Offset(15.4, 12.4),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(8.6, 15.8),
          const Offset(13.4, 15.8),
          accentStroke,
        );

      case FounderIconGlyph.calendarExec:
        final cal = rr(3.6, 5.4, 20.4, 20.4, 2.8);
        canvas.drawRRect(cal, duoPaint);
        canvas.drawRRect(cal, mainStroke);
        canvas.drawLine(
          const Offset(3.8, 9.8),
          const Offset(20.2, 9.8),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(8.2, 3.4),
          const Offset(8.2, 6.6),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(15.8, 3.4),
          const Offset(15.8, 6.6),
          mainStroke,
        );
        canvas.drawCircle(const Offset(8.8, 13.6), 1.0, mainStroke);
        canvas.drawCircle(const Offset(12.0, 13.6), 1.0, mainStroke);
        canvas.drawCircle(const Offset(15.4, 15.6), 1.6, accentFill);

      case FounderIconGlyph.clockSla:
        canvas.drawCircle(const Offset(12.0, 12.6), 8.2, duoPaint);
        canvas.drawCircle(const Offset(12.0, 12.6), 8.2, mainStroke);
        canvas.drawLine(
          const Offset(9.8, 2.8),
          const Offset(14.2, 2.8),
          mainStroke,
        );
        final hands = Path()
          ..moveTo(12.0, 8.2)
          ..lineTo(12.0, 12.6)
          ..lineTo(15.4, 14.6);
        canvas.drawPath(hands, accentStroke);

      case FounderIconGlyph.upcomingEvent:
        canvas.drawCircle(const Offset(12.0, 12.0), 8.6, duoPaint);
        canvas.drawCircle(const Offset(12.0, 12.0), 8.6, mainStroke);
        final arr = Path()
          ..moveTo(8.5, 12.0)
          ..lineTo(15.2, 12.0)
          ..moveTo(12.6, 9.2)
          ..lineTo(15.5, 12.0)
          ..lineTo(12.6, 14.8);
        canvas.drawPath(arr, accentStroke);

      case FounderIconGlyph.radarPulse:
        canvas.drawCircle(const Offset(12.0, 12.0), 5.0, duoPaint);
        canvas.drawCircle(const Offset(12.0, 12.0), 8.8, mainStroke);
        canvas.drawCircle(
          const Offset(12.0, 12.0),
          4.6,
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw * 0.85
            ..color = primaryColor.withValues(alpha: 0.65),
        );
        canvas.drawLine(
          const Offset(12.0, 12.0),
          const Offset(18.0, 6.0),
          accentStroke,
        );
        canvas.drawCircle(const Offset(15.4, 8.6), 1.6, accentFill);

      case FounderIconGlyph.mapPinLuxury:
        final pin = Path()
          ..moveTo(12.0, 20.8)
          ..cubicTo(12.0, 20.8, 18.4, 14.8, 18.4, 9.8)
          ..arcToPoint(
            const Offset(5.6, 9.8),
            radius: const Radius.circular(6.4),
            largeArc: true,
            clockwise: false,
          )
          ..cubicTo(5.6, 14.8, 12.0, 20.8, 12.0, 20.8)
          ..close();
        canvas.drawPath(pin, duoPaint);
        canvas.drawPath(pin, mainStroke);
        canvas.drawCircle(const Offset(12.0, 9.8), 2.3, accentFill);

      case FounderIconGlyph.moonDarkMap:
        final moon = Path()
          ..moveTo(19.2, 14.6)
          ..arcToPoint(
            const Offset(9.4, 4.8),
            radius: const Radius.circular(7.8),
            largeArc: false,
            clockwise: true,
          )
          ..arcToPoint(
            const Offset(19.2, 14.6),
            radius: const Radius.circular(8.2),
            largeArc: true,
            clockwise: false,
          )
          ..close();
        canvas.drawPath(moon, duoPaint);
        canvas.drawPath(moon, mainStroke);

      case FounderIconGlyph.sunLightMap:
        canvas.drawCircle(const Offset(12.0, 12.0), 4.2, duoPaint);
        canvas.drawCircle(const Offset(12.0, 12.0), 4.2, accentStroke);
        for (var i = 0; i < 8; i++) {
          final a = (math.pi / 4) * i;
          canvas.drawLine(
            Offset(12.0 + math.cos(a) * 6.6, 12.0 + math.sin(a) * 6.6),
            Offset(12.0 + math.cos(a) * 8.8, 12.0 + math.sin(a) * 8.8),
            mainStroke,
          );
        }

      case FounderIconGlyph.compassRose:
        canvas.drawCircle(const Offset(12.0, 12.0), 8.8, duoPaint);
        canvas.drawCircle(const Offset(12.0, 12.0), 8.8, mainStroke);
        final needle = Path()
          ..moveTo(15.6, 8.4)
          ..lineTo(13.4, 13.4)
          ..lineTo(8.4, 15.6)
          ..lineTo(10.6, 10.6)
          ..close();
        canvas.drawPath(needle, accentStroke);

      case FounderIconGlyph.zoomPlus:
        canvas.drawLine(
          const Offset(12.0, 5.5),
          const Offset(12.0, 18.5),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(5.5, 12.0),
          const Offset(18.5, 12.0),
          mainStroke,
        );

      case FounderIconGlyph.zoomMinus:
        canvas.drawLine(
          const Offset(5.5, 12.0),
          const Offset(18.5, 12.0),
          mainStroke,
        );

      case FounderIconGlyph.gpsTarget:
        canvas.drawCircle(const Offset(12.0, 12.0), 6.2, duoPaint);
        canvas.drawCircle(const Offset(12.0, 12.0), 6.2, mainStroke);
        canvas.drawCircle(const Offset(12.0, 12.0), 2.0, accentFill);
        canvas.drawLine(
          const Offset(12.0, 3.0),
          const Offset(12.0, 5.6),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(12.0, 18.4),
          const Offset(12.0, 21.0),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(3.0, 12.0),
          const Offset(5.6, 12.0),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(18.4, 12.0),
          const Offset(21.0, 12.0),
          mainStroke,
        );

      case FounderIconGlyph.fullscreenExpand:
        final corners = Path()
          ..moveTo(4.2, 9.0)
          ..lineTo(4.2, 4.2)
          ..lineTo(9.0, 4.2)
          ..moveTo(15.0, 4.2)
          ..lineTo(19.8, 4.2)
          ..lineTo(19.8, 9.0)
          ..moveTo(19.8, 15.0)
          ..lineTo(19.8, 19.8)
          ..lineTo(15.0, 19.8)
          ..moveTo(9.0, 19.8)
          ..lineTo(4.2, 19.8)
          ..lineTo(4.2, 15.0);
        canvas.drawPath(corners, mainStroke);

      case FounderIconGlyph.fullscreenExit:
        final inward = Path()
          ..moveTo(4.2, 9.0)
          ..lineTo(9.0, 9.0)
          ..lineTo(9.0, 4.2)
          ..moveTo(19.8, 9.0)
          ..lineTo(15.0, 9.0)
          ..lineTo(15.0, 4.2)
          ..moveTo(19.8, 15.0)
          ..lineTo(15.0, 15.0)
          ..lineTo(15.0, 19.8)
          ..moveTo(4.2, 15.0)
          ..lineTo(9.0, 15.0)
          ..lineTo(9.0, 19.8);
        canvas.drawPath(inward, mainStroke);

      case FounderIconGlyph.mediationBalance:
        canvas.drawLine(
          const Offset(12.0, 4.4),
          const Offset(12.0, 19.6),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(8.2, 19.6),
          const Offset(15.8, 19.6),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(4.8, 8.0),
          const Offset(19.2, 8.0),
          accentStroke,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: const Offset(6.8, 13.6),
            width: 5.2,
            height: 4.0,
          ),
          0,
          math.pi,
          true,
          duoPaint,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: const Offset(6.8, 13.6),
            width: 5.2,
            height: 4.0,
          ),
          0,
          math.pi,
          false,
          mainStroke,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: const Offset(17.2, 13.6),
            width: 5.2,
            height: 4.0,
          ),
          0,
          math.pi,
          true,
          duoPaint,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: const Offset(17.2, 13.6),
            width: 5.2,
            height: 4.0,
          ),
          0,
          math.pi,
          false,
          mainStroke,
        );

      case FounderIconGlyph.shieldVerified:
        final shield = Path()
          ..moveTo(12.0, 3.4)
          ..lineTo(19.0, 6.2)
          ..lineTo(19.0, 11.6)
          ..cubicTo(19.0, 16.0, 15.8, 19.3, 12.0, 20.8)
          ..cubicTo(8.2, 19.3, 5.0, 16.0, 5.0, 11.6)
          ..lineTo(5.0, 6.2)
          ..close();
        canvas.drawPath(shield, duoPaint);
        canvas.drawPath(shield, mainStroke);
        final vChk = Path()
          ..moveTo(9.0, 12.0)
          ..lineTo(11.1, 14.1)
          ..lineTo(15.2, 9.8);
        canvas.drawPath(vChk, accentStroke);

      case FounderIconGlyph.vaultLock:
        final lockBody = rr(5.5, 10.6, 18.5, 20.2, 2.7);
        canvas.drawRRect(lockBody, duoPaint);
        canvas.drawRRect(lockBody, mainStroke);
        final shackle = Path()
          ..moveTo(8.2, 10.6)
          ..lineTo(8.2, 7.6)
          ..arcToPoint(
            const Offset(15.8, 7.6),
            radius: const Radius.circular(3.8),
            largeArc: false,
            clockwise: true,
          )
          ..lineTo(15.8, 10.6);
        canvas.drawPath(shackle, mainStroke);
        canvas.drawLine(
          const Offset(12.0, 14.0),
          const Offset(12.0, 16.8),
          accentStroke,
        );

      case FounderIconGlyph.vaultOpen:
        final openBody = rr(5.5, 10.6, 18.5, 20.2, 2.7);
        canvas.drawRRect(openBody, duoPaint);
        canvas.drawRRect(openBody, mainStroke);
        final openShackle = Path()
          ..moveTo(8.2, 10.6)
          ..lineTo(8.2, 7.2)
          ..arcToPoint(
            const Offset(15.8, 6.4),
            radius: const Radius.circular(3.8),
            largeArc: false,
            clockwise: true,
          );
        canvas.drawPath(openShackle, accentStroke);
        canvas.drawLine(
          const Offset(12.0, 14.0),
          const Offset(12.0, 16.8),
          accentStroke,
        );

      case FounderIconGlyph.masterKey:
        canvas.drawCircle(const Offset(8.2, 12.0), 4.0, duoPaint);
        canvas.drawCircle(const Offset(8.2, 12.0), 4.0, mainStroke);
        canvas.drawCircle(const Offset(8.2, 12.0), 1.1, accentFill);
        canvas.drawLine(
          const Offset(12.2, 12.0),
          const Offset(20.4, 12.0),
          accentStroke,
        );
        canvas.drawLine(
          const Offset(17.2, 12.0),
          const Offset(17.2, 15.0),
          accentStroke,
        );
        canvas.drawLine(
          const Offset(19.8, 12.0),
          const Offset(19.8, 14.2),
          accentStroke,
        );

      case FounderIconGlyph.biometricId:
        final focus = Path()
          ..moveTo(4.5, 8.2)
          ..lineTo(4.5, 5.2)
          ..lineTo(7.5, 5.2)
          ..moveTo(16.5, 5.2)
          ..lineTo(19.5, 5.2)
          ..lineTo(19.5, 8.2)
          ..moveTo(19.5, 15.8)
          ..lineTo(19.5, 18.8)
          ..lineTo(16.5, 18.8)
          ..moveTo(7.5, 18.8)
          ..lineTo(4.5, 18.8)
          ..lineTo(4.5, 15.8);
        canvas.drawPath(focus, mainStroke);
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12.0, 12.5), radius: 3.6),
          math.pi * 1.15,
          math.pi * 0.7,
          false,
          accentStroke,
        );
        canvas.drawLine(
          const Offset(12.0, 11.0),
          const Offset(12.0, 15.2),
          accentStroke,
        );

      case FounderIconGlyph.eyeOpen:
        final eye = Path()
          ..moveTo(3.2, 12.0)
          ..cubicTo(6.2, 6.6, 17.8, 6.6, 20.8, 12.0)
          ..cubicTo(17.8, 17.4, 6.2, 17.4, 3.2, 12.0)
          ..close();
        canvas.drawPath(eye, duoPaint);
        canvas.drawPath(eye, mainStroke);
        canvas.drawCircle(const Offset(12.0, 12.0), 2.5, accentStroke);

      case FounderIconGlyph.eyeClosed:
        final eyeC = Path()
          ..moveTo(3.4, 12.0)
          ..cubicTo(6.4, 6.8, 17.6, 6.8, 20.6, 12.0)
          ..cubicTo(17.6, 17.2, 6.4, 17.2, 3.4, 12.0);
        canvas.drawPath(eyeC, mainStroke);
        canvas.drawLine(
          const Offset(4.8, 19.2),
          const Offset(19.2, 4.8),
          accentStroke,
        );

      case FounderIconGlyph.mailEnvelope:
        final env = rr(3.5, 5.6, 20.5, 18.4, 2.5);
        canvas.drawRRect(env, duoPaint);
        canvas.drawRRect(env, mainStroke);
        final flap = Path()
          ..moveTo(4.2, 7.0)
          ..lineTo(12.0, 12.6)
          ..lineTo(19.8, 7.0);
        canvas.drawPath(flap, accentStroke);

      case FounderIconGlyph.mailDispatched:
        final envD = rr(3.2, 5.6, 19.2, 17.8, 2.4);
        canvas.drawRRect(envD, duoPaint);
        canvas.drawRRect(envD, mainStroke);
        final flapD = Path()
          ..moveTo(4.0, 6.8)
          ..lineTo(11.2, 12.0)
          ..lineTo(18.4, 6.8);
        canvas.drawPath(flapD, mainStroke);
        final okD = Path()
          ..moveTo(15.4, 17.8)
          ..lineTo(17.2, 19.6)
          ..lineTo(20.6, 15.8);
        canvas.drawPath(okD, accentStroke);

      case FounderIconGlyph.clipboardOtp:
        final clip = rr(5.5, 5.0, 18.5, 20.2, 2.4);
        canvas.drawRRect(clip, duoPaint);
        canvas.drawRRect(clip, mainStroke);
        canvas.drawRRect(rr(9.2, 3.2, 14.8, 6.0, 1.2), accentStroke);
        final pasteArr = Path()
          ..moveTo(12.0, 9.6)
          ..lineTo(12.0, 15.8)
          ..moveTo(9.5, 13.4)
          ..lineTo(12.0, 16.0)
          ..lineTo(14.5, 13.4);
        canvas.drawPath(pasteArr, accentStroke);

      case FounderIconGlyph.otaDirectUpdate:
        canvas.drawCircle(const Offset(12.0, 11.5), 7.2, duoPaint);
        final tray = Path()
          ..moveTo(5.0, 16.2)
          ..lineTo(5.0, 18.0)
          ..quadraticBezierTo(5.0, 19.8, 6.8, 19.8)
          ..lineTo(17.2, 19.8)
          ..quadraticBezierTo(19.0, 19.8, 19.0, 18.0)
          ..lineTo(19.0, 16.2);
        canvas.drawPath(tray, mainStroke);
        final dlArr = Path()
          ..moveTo(12.0, 4.2)
          ..lineTo(12.0, 14.6)
          ..moveTo(8.4, 11.2)
          ..lineTo(12.0, 14.8)
          ..lineTo(15.6, 11.2);
        canvas.drawPath(dlArr, accentStroke);

      case FounderIconGlyph.duressEmergencyShield:
        final eShield = Path()
          ..moveTo(12.0, 3.4)
          ..lineTo(19.0, 6.2)
          ..lineTo(19.0, 11.6)
          ..cubicTo(19.0, 16.0, 15.8, 19.3, 12.0, 20.8)
          ..cubicTo(8.2, 19.3, 5.0, 16.0, 5.0, 11.6)
          ..lineTo(5.0, 6.2)
          ..close();
        canvas.drawPath(eShield, duoPaint);
        canvas.drawPath(eShield, mainStroke);
        canvas.drawLine(
          const Offset(12.0, 8.4),
          const Offset(12.0, 12.8),
          accentStroke,
        );
        canvas.drawCircle(const Offset(12.0, 15.6), 1.1, accentFill);

      case FounderIconGlyph.screenCaptureShield:
        final scr = rr(4.5, 4.5, 19.5, 19.5, 3.0);
        canvas.drawRRect(scr, duoPaint);
        canvas.drawRRect(scr, mainStroke);
        canvas.drawCircle(const Offset(12.0, 12.0), 2.8, accentStroke);

      case FounderIconGlyph.userClient:
        canvas.drawCircle(const Offset(12.0, 8.6), 3.4, duoPaint);
        canvas.drawCircle(const Offset(12.0, 8.6), 3.4, mainStroke);
        final uArc = Path()
          ..moveTo(5.2, 19.4)
          ..cubicTo(5.2, 15.0, 18.8, 15.0, 18.8, 19.4);
        canvas.drawPath(uArc, mainStroke);

      case FounderIconGlyph.userProvider:
        canvas.drawCircle(const Offset(10.6, 8.6), 3.2, duoPaint);
        canvas.drawCircle(const Offset(10.6, 8.6), 3.2, mainStroke);
        final pArc = Path()
          ..moveTo(4.4, 19.4)
          ..cubicTo(4.4, 15.2, 16.8, 15.2, 16.8, 19.4);
        canvas.drawPath(pArc, mainStroke);
        final badgeChk = Path()
          ..moveTo(16.0, 11.6)
          ..lineTo(17.5, 13.1)
          ..lineTo(20.2, 10.2);
        canvas.drawPath(badgeChk, accentStroke);

      case FounderIconGlyph.dualModeVenn:
        canvas.drawCircle(const Offset(9.4, 12.0), 5.6, duoPaint);
        canvas.drawCircle(const Offset(14.6, 12.0), 5.6, duoPaint);
        canvas.drawCircle(const Offset(9.4, 12.0), 5.6, mainStroke);
        canvas.drawCircle(const Offset(14.6, 12.0), 5.6, accentStroke);

      case FounderIconGlyph.starRating:
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final r = i.isEven ? 8.6 : 4.0;
          final a = -math.pi / 2 + (math.pi / 5) * i;
          final pt = Offset(12.0 + math.cos(a) * r, 12.2 + math.sin(a) * r);
          if (i == 0) {
            star.moveTo(pt.dx, pt.dy);
          } else {
            star.lineTo(pt.dx, pt.dy);
          }
        }
        star.close();
        canvas.drawPath(star, duoPaint);
        canvas.drawPath(star, accentStroke);

      case FounderIconGlyph.warningTriangle:
        final tri = Path()
          ..moveTo(12.0, 4.2)
          ..lineTo(20.2, 18.8)
          ..lineTo(3.8, 18.8)
          ..close();
        canvas.drawPath(tri, duoPaint);
        canvas.drawPath(tri, mainStroke);
        canvas.drawLine(
          const Offset(12.0, 10.0),
          const Offset(12.0, 14.0),
          accentStroke,
        );
        canvas.drawCircle(const Offset(12.0, 16.5), 1.0, accentFill);

      case FounderIconGlyph.checkValid:
        canvas.drawCircle(const Offset(12.0, 12.0), 8.6, duoPaint);
        canvas.drawCircle(const Offset(12.0, 12.0), 8.6, mainStroke);
        final ok = Path()
          ..moveTo(8.4, 12.2)
          ..lineTo(10.9, 14.7)
          ..lineTo(15.8, 9.6);
        canvas.drawPath(ok, accentStroke);

      case FounderIconGlyph.ringPending:
        canvas.drawCircle(
          const Offset(12.0, 12.0),
          7.6,
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw * 0.85
            ..color = primaryColor.withValues(alpha: 0.42),
        );

      case FounderIconGlyph.sparkBolt:
        final bolt = Path()
          ..moveTo(13.2, 3.5)
          ..lineTo(5.8, 13.2)
          ..lineTo(11.6, 13.2)
          ..lineTo(10.8, 20.5)
          ..lineTo(18.2, 10.8)
          ..lineTo(12.4, 10.8)
          ..close();
        canvas.drawPath(bolt, duoPaint);
        canvas.drawPath(bolt, accentStroke);

      case FounderIconGlyph.copilotAiStar:
        final spk = Path()
          ..moveTo(12.0, 3.6)
          ..quadraticBezierTo(12.6, 11.4, 20.4, 12.0)
          ..quadraticBezierTo(12.6, 12.6, 12.0, 20.4)
          ..quadraticBezierTo(11.4, 12.6, 3.6, 12.0)
          ..quadraticBezierTo(11.4, 11.4, 12.0, 3.6)
          ..close();
        canvas.drawPath(spk, duoPaint);
        canvas.drawPath(spk, accentStroke);
        canvas.drawCircle(const Offset(18.2, 6.0), 1.2, accentFill);

      case FounderIconGlyph.sendVector:
        final plane = Path()
          ..moveTo(3.8, 11.4)
          ..lineTo(20.0, 4.6)
          ..lineTo(13.6, 20.0)
          ..lineTo(11.0, 13.4)
          ..close();
        canvas.drawPath(plane, duoPaint);
        canvas.drawPath(plane, mainStroke);
        canvas.drawLine(
          const Offset(11.0, 13.4),
          const Offset(19.6, 4.9),
          accentStroke,
        );

      case FounderIconGlyph.refreshArc:
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12.0, 12.0), radius: 7.4),
          -math.pi * 0.78,
          math.pi * 1.52,
          false,
          mainStroke,
        );
        final rHead = Path()
          ..moveTo(15.8, 4.6)
          ..lineTo(19.2, 5.4)
          ..lineTo(18.2, 8.8);
        canvas.drawPath(rHead, accentStroke);

      case FounderIconGlyph.closeCross:
        canvas.drawLine(
          const Offset(6.8, 6.8),
          const Offset(17.2, 17.2),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(17.2, 6.8),
          const Offset(6.8, 17.2),
          mainStroke,
        );

      case FounderIconGlyph.signOutDoor:
        final door = Path()
          ..moveTo(13.5, 4.5)
          ..lineTo(6.8, 4.5)
          ..quadraticBezierTo(5.0, 4.5, 5.0, 6.3)
          ..lineTo(5.0, 17.7)
          ..quadraticBezierTo(5.0, 19.5, 6.8, 19.5)
          ..lineTo(13.5, 19.5);
        canvas.drawPath(door, mainStroke);
        final outArr = Path()
          ..moveTo(10.2, 12.0)
          ..lineTo(19.6, 12.0)
          ..moveTo(16.4, 8.8)
          ..lineTo(19.8, 12.0)
          ..lineTo(16.4, 15.2);
        canvas.drawPath(outArr, accentStroke);

      case FounderIconGlyph.trashDelete:
        final bin = rr(6.8, 7.6, 17.2, 19.8, 2.0);
        canvas.drawRRect(bin, duoPaint);
        canvas.drawRRect(bin, mainStroke);
        canvas.drawLine(
          const Offset(4.8, 7.6),
          const Offset(19.2, 7.6),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(9.6, 4.8),
          const Offset(14.4, 4.8),
          mainStroke,
        );
        canvas.drawLine(
          const Offset(10.4, 11.0),
          const Offset(10.4, 16.4),
          accentStroke,
        );
        canvas.drawLine(
          const Offset(13.6, 11.0),
          const Offset(13.6, 16.4),
          accentStroke,
        );

      case FounderIconGlyph.searchGlass:
        canvas.drawCircle(const Offset(10.8, 10.8), 6.0, duoPaint);
        canvas.drawCircle(const Offset(10.8, 10.8), 6.0, mainStroke);
        canvas.drawLine(
          const Offset(15.2, 15.2),
          const Offset(19.8, 19.8),
          accentStroke,
        );

      case FounderIconGlyph.chevronLeft:
        final p = Path()
          ..moveTo(14.6, 6.4)
          ..lineTo(9.0, 12.0)
          ..lineTo(14.6, 17.6);
        canvas.drawPath(p, mainStroke);

      case FounderIconGlyph.chevronRight:
        final p = Path()
          ..moveTo(9.4, 6.4)
          ..lineTo(15.0, 12.0)
          ..lineTo(9.4, 17.6);
        canvas.drawPath(p, mainStroke);

      case FounderIconGlyph.chevronDown:
        final p = Path()
          ..moveTo(6.4, 9.6)
          ..lineTo(12.0, 15.2)
          ..lineTo(17.6, 9.6);
        canvas.drawPath(p, mainStroke);

      case FounderIconGlyph.chevronUp:
        final p = Path()
          ..moveTo(6.4, 14.4)
          ..lineTo(12.0, 8.8)
          ..lineTo(17.6, 14.4);
        canvas.drawPath(p, mainStroke);

      case FounderIconGlyph.arrowBack:
        final p = Path()
          ..moveTo(19.2, 12.0)
          ..lineTo(5.2, 12.0)
          ..moveTo(10.8, 6.4)
          ..lineTo(5.0, 12.0)
          ..lineTo(10.8, 17.6);
        canvas.drawPath(p, mainStroke);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FounderPrecisionIconPainter oldDelegate) {
    return oldDelegate.glyph != glyph ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isActive != isActive ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.duotoneAlpha != duotoneAlpha;
  }
}

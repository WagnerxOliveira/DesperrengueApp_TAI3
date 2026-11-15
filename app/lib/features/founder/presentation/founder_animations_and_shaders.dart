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
  });

  final List<String> labels;
  final List<IconData>? icons;
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
                            if (icon != null) ...<Widget>[
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
    double py(double ny) => (ny + 0.068) * boxSize;

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

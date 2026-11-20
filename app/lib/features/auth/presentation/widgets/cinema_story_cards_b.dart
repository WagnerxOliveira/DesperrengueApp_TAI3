import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/typography/cinema_type_scale.dart';
import 'cinema_card_parts.dart';
import 'cinema_motion.dart';

// =============================================================================
// ETAPA 4 — SAÚDE DO IMÓVEL 96% (SEMICÍRCULO RAIO >= 96) + HISTÓRICO PDF
// =============================================================================

class CinemaStory4Card extends StatelessWidget {
  const CinemaStory4Card({super.key, required this.act});

  final Animation<double> act;

  static const double gaugeHeight = 152;
  static const double gaugeBottomBand = 28;
  static const double gaugeStroke = 14;

  static const List<(String, String)> history = <(String, String)>[
    ('Revisão Elétrica', 'Realizado em 12/10/2026'),
    ('Climatização', 'Realizado em 05/11/2026'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Saúde do Imóvel', style: CinemaType.cardTitle),
        const SizedBox(height: CinemaSpace.s12),
        SizedBox(
          height: gaugeHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _PropertyHealthSemiArchPainter(
                      act: act,
                      strokeWidth: gaugeStroke,
                      bottomBand: gaugeBottomBand,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: gaugeBottomBand,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: act,
                        builder: (context, _) {
                          final arcProgress = actProgress(act, 0.22, 0.80);
                          final displayedPercent =
                              (72 + (24 * arcProgress).round()).clamp(0, 96);
                          return Text(
                            '$displayedPercent%',
                            style: CinemaType.figure,
                          );
                        },
                      ),
                      Text(
                        'Em dia',
                        style: CinemaType.caption.copyWith(
                          color: const Color(0xFF065F46),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Positioned(
                left: CinemaSpace.s4,
                bottom: 0,
                child: Text('0%', style: CinemaType.rowMeta),
              ),
              const Positioned(
                right: CinemaSpace.s4,
                bottom: 0,
                child: Text('100%', style: CinemaType.rowMeta),
              ),
            ],
          ),
        ),
        const SizedBox(height: CinemaSpace.s16),
        CinemaGroupedList(
          children: List<Widget>.generate(history.length, (i) {
            final start = 0.44 + (i * 0.14);
            return ActFx(
              act: act,
              effects: cascadeEffects(
                start,
                start + 0.25,
                dy: 8,
                fadeFrom: 0.3,
              ),
              child: CinemaListRow(
                child: Row(
                  children: [
                    const CinemaIconTile(
                      icon: Icons.verified_rounded,
                      color: Color(0xFF059669),
                    ),
                    const SizedBox(width: CinemaSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(history[i].$1, style: CinemaType.rowTitle),
                          Text(
                            history[i].$2,
                            style: CinemaType.tabular(CinemaType.rowMeta),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: CinemaSpace.s8),
                    const _PdfBadge(),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _PdfBadge extends StatelessWidget {
  const _PdfBadge();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: CinemaGeometry.pdfBadgeWidth,
        minHeight: CinemaGeometry.pdfBadgeHeight,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFF991B1B),
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CinemaSpace.s4,
            vertical: 1,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              'PDF',
              style: CinemaType.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PropertyHealthSemiArchPainter extends CustomPainter {
  _PropertyHealthSemiArchPainter({
    required this.act,
    required this.strokeWidth,
    required this.bottomBand,
  }) : super(repaint: act);

  final Animation<double> act;
  final double strokeWidth;
  final double bottomBand;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(
      (size.width / 2) - (strokeWidth / 2) - 4.0,
      size.height - bottomBand - (strokeWidth / 2) - 4.0,
    );
    if (radius <= 8.0) return;

    final center = Offset(size.width / 2, size.height - bottomBand);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE2E8F0);
    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);

    final progress = (0.96 * actProgress(act, 0.22, 0.80)).clamp(0.0, 1.0);
    if (progress <= 0.001) return;

    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFF34D399), Color(0xFF10B981), Color(0xFF059669)],
      ).createShader(rect);
    canvas.drawArc(rect, math.pi, math.pi * progress, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant _PropertyHealthSemiArchPainter oldDelegate) {
    return oldDelegate.act != act ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.bottomBand != bottomBand;
  }
}

// =============================================================================
// ETAPA 5 — PAINEL DO PROFISSIONAL: R$ 0,00 (36) + REPUTAÇÃO VERIFICADA
// =============================================================================

class CinemaStory5Card extends StatelessWidget {
  const CinemaStory5Card({super.key, required this.act});

  final Animation<double> act;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Painel do Profissional', style: CinemaType.cardTitle),
        const SizedBox(height: CinemaSpace.s12),
        ActFx(
          act: act,
          effects: cascadeEffects(0.14, 0.40, dy: 10, scaleFrom: 0.97),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(CinemaGeometry.itemRadius),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(CinemaSpace.s20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('Custo para orçar:', style: CinemaType.rowMeta),
                      Text('R\$ 0,00', style: CinemaType.figureXl),
                      SizedBox(height: CinemaSpace.s4),
                      Text(
                        'Valor do cliente já garantido antes de sair',
                        style: CinemaType.rowMeta,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: CinemaSpace.s8,
                  right: CinemaSpace.s8,
                  child: IgnorePointer(
                    child: CinemaLottie(
                      asset: CinemaLottieAssets.sparkleSoft,
                      act: act,
                      size: 56,
                      begin: 0.40,
                      end: 0.90,
                      curve: Curves.linear,
                      fallbackIcon: Icons.auto_awesome_rounded,
                      fallbackColor: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: CinemaSpace.s16),
        Text(
          'Reputação Verificada',
          style: CinemaType.rowTitle.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: CinemaSpace.s8),
        SizedBox(
          height: CinemaGeometry.progressBarHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CinemaGeometry.pillRadius),
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFFE2E8F0)),
              child: AnimatedBuilder(
                animation: act,
                builder: (context, _) {
                  final barProgress = actProgress(act, 0.26, 0.82);
                  final fillFactor = (0.36 + (0.64 * barProgress)).clamp(
                    0.0,
                    1.0,
                  );
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fillFactor,
                      heightFactor: 1.0,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [CinemaColors.emerald, Color(0xFF0D9488)],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: CinemaSpace.s12),
        Wrap(
          spacing: CinemaSpace.s12,
          runSpacing: CinemaSpace.s4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(5, (i) {
                final start = 0.44 + (i * 0.06);
                return ActFx(
                  act: act,
                  effects: cascadeEffects(
                    start,
                    start + 0.14,
                    dy: 0,
                    scaleFrom: 0.4,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 22,
                    color: CinemaColors.amber,
                  ),
                );
              }),
            ),
            const Text(
              '5,0 · Profissional Destaque',
              style: CinemaType.rowTitle,
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// ETAPA 6 — CHAVE SELETORA DUPLA (ALTURA 64) + 2 CARTÕES DE RESUMO EMPILHADOS
// =============================================================================

class CinemaStory6Card extends StatefulWidget {
  const CinemaStory6Card({
    super.key,
    required this.act,
    required this.onInteractivePointerDown,
  });

  final Animation<double> act;
  final ValueChanged<int> onInteractivePointerDown;

  @override
  State<CinemaStory6Card> createState() => _CinemaStory6CardState();
}

class _CinemaStory6CardState extends State<CinemaStory6Card>
    with SingleTickerProviderStateMixin {
  int? _manualSelectedMode; // null = segue coreografia; 0 = Cliente; 1 = Profissional
  late final AnimationController _manualSwitchController;
  final ValueNotifier<double> _cursor = ValueNotifier<double>(0.0);
  double _manualFrom = 0.0;
  double _manualTo = 1.0;

  @override
  void initState() {
    super.initState();
    _manualSwitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(_syncCursor);
    widget.act.addListener(_syncCursor);
    _cursor.value = _currentCursorPosition().clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(covariant CinemaStory6Card oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.act != widget.act) {
      oldWidget.act.removeListener(_syncCursor);
      widget.act.addListener(_syncCursor);
      _syncCursor();
    }
  }

  @override
  void dispose() {
    widget.act.removeListener(_syncCursor);
    _manualSwitchController.removeListener(_syncCursor);
    _manualSwitchController.dispose();
    _cursor.dispose();
    super.dispose();
  }

  // O cursor da chave e os cartões de resumo ouvem só este notificador: a
  // coluna da etapa é montada uma única vez (sem recriar efeitos por quadro).
  void _syncCursor() {
    final next = _currentCursorPosition().clamp(0.0, 1.0);
    if (next != _cursor.value) {
      _cursor.value = next;
    }
  }

  double _autoChoreographedPosition(double t) {
    // 0.0s–1.10s (0.00..0.355): Modo Cliente (0.0)
    // 1.10s–2.10s (0.355..0.677): desliza com mola suave para Modo Profissional (1.0)
    // 2.20s–3.00s (0.710..0.968): retorna suavemente estacionando em Modo Cliente (0.0)
    if (t <= 0.355) return 0.0;
    if (t < 0.710) {
      return Curves.easeOutQuart.transform(
        ((t - 0.355) / (0.580 - 0.355)).clamp(0.0, 1.0),
      );
    }
    final backToClient = Curves.easeOutQuart.transform(
      ((t - 0.710) / (0.968 - 0.710)).clamp(0.0, 1.0),
    );
    return (1.0 - backToClient).clamp(0.0, 1.0);
  }

  double _currentCursorPosition() {
    if (_manualSelectedMode == null) {
      return _autoChoreographedPosition(widget.act.value);
    }
    final curved = Curves.easeOutQuart.transform(
      _manualSwitchController.value.clamp(0.0, 1.0),
    );
    return _manualFrom + ((_manualTo - _manualFrom) * curved);
  }

  void _handleSelectMode(int targetMode) {
    final currentPos = _currentCursorPosition();
    final targetPos = targetMode == 0 ? 0.0 : 1.0;
    HapticFeedback.selectionClick();
    _manualSelectedMode = targetMode;
    _manualFrom = currentPos;
    _manualTo = targetPos;
    if (MediaQuery.disableAnimationsOf(context)) {
      _manualSwitchController.value = 1.0;
    } else {
      _manualSwitchController.forward(from: 0.0);
    }
    _syncCursor();
  }

  @override
  Widget build(BuildContext context) {
    final act = widget.act;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: CinemaSpace.s8,
          runSpacing: CinemaSpace.s8,
          children: [
            const Text('Escolha Seu Perfil', style: CinemaType.cardTitle),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2F6),
                borderRadius: BorderRadius.circular(CinemaGeometry.pillRadius),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CinemaSpace.s12,
                  vertical: CinemaSpace.s4,
                ),
                child: Text(
                  '1 toque',
                  style: CinemaType.caption.copyWith(
                    color: CinemaColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: CinemaSpace.s16),
        ValueListenableBuilder<double>(
          valueListenable: _cursor,
          builder: (context, cursorPos, _) => _DualModeSwitch(
            key: const Key('dual-mode-luxury-switch'),
            cursorPosition: cursorPos,
            onInteractivePointerDown: widget.onInteractivePointerDown,
            onSelectMode: _handleSelectMode,
          ),
        ),
        const SizedBox(height: CinemaSpace.s16),
        ActFx(
          act: act,
          effects: cascadeEffects(0.30, 0.54, dy: 10, fadeFrom: 0.3),
          child: ValueListenableBuilder<double>(
            valueListenable: _cursor,
            builder: (context, cursorPos, _) => _ModeSummaryCard(
              icon: Icons.shield_outlined,
              accent: const Color(0xFF1E3A8A),
              title: 'Contratar com garantia',
              active: cursorPos < 0.5,
            ),
          ),
        ),
        const SizedBox(height: CinemaSpace.s8),
        ActFx(
          act: act,
          effects: cascadeEffects(0.38, 0.62, dy: 10, fadeFrom: 0.3),
          child: ValueListenableBuilder<double>(
            valueListenable: _cursor,
            builder: (context, cursorPos, _) => _ModeSummaryCard(
              icon: Icons.bolt_rounded,
              accent: CinemaColors.emeraldDeep,
              title: 'Atender sem pagar para orçar',
              active: cursorPos >= 0.5,
            ),
          ),
        ),
        const SizedBox(height: CinemaSpace.s16),
        ActFx(
          act: act,
          effects: cascadeEffects(0.50, 0.76, dy: 8, scaleFrom: 0.96),
          child: const Center(
            child: CinemaSealPill(
              icon: Icons.check_circle_rounded,
              label: 'Identidade Verificada',
              background: Color(0xFFDCFCE7),
              border: Color(0xFF86EFAC),
              iconColor: CinemaColors.emeraldDeep,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeSummaryCard extends StatelessWidget {
  const _ModeSummaryCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.active,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedContainer(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: active
            ? Color.alphaBlend(accent.withValues(alpha: 0.08), Colors.white)
            : CinemaColors.porcelain,
        borderRadius: BorderRadius.circular(CinemaGeometry.itemRadius),
        border: Border.all(
          color: active ? accent : const Color(0xFFE2E8F0),
          width: active ? 1.5 : 1.0,
        ),
      ),
      child: CinemaListRow(
        child: Row(
          children: [
            CinemaIconTile(icon: icon, color: accent),
            const SizedBox(width: CinemaSpace.s12),
            Expanded(
              child: Text(
                title,
                style: CinemaType.rowTitle.copyWith(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            AnimatedOpacity(
              duration: reduce
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              opacity: active ? 1.0 : 0.0,
              child: Icon(Icons.check_circle_rounded, size: 22, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chave Seletora Dupla Esculpida (`Modo Cliente` <-> `Modo Profissional`):
/// trilho acetinado de altura mínima 64 + 1 único cursor pílula lapidado.
/// Rótulos quebram em 2 linhas (ou empilham ícone sobre texto) sem elipse.
class _DualModeSwitch extends StatelessWidget {
  const _DualModeSwitch({
    super.key,
    required this.cursorPosition,
    required this.onInteractivePointerDown,
    required this.onSelectMode,
  });

  final double cursorPosition;
  final ValueChanged<int> onInteractivePointerDown;
  final ValueChanged<int> onSelectMode;

  Widget _option({
    required Key key,
    required int mode,
    required IconData icon,
    required String label,
    required bool active,
    required Color inactiveIconColor,
    required bool vertical,
  }) {
    final textColor = active ? const Color(0xFFFFFFFF) : CinemaColors.ink;
    final iconColor = active ? const Color(0xFFFFFFFF) : inactiveIconColor;
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: CinemaType.rowTitle.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
    );
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelectMode(mode),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: CinemaGeometry.switchHeight - 8,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CinemaSpace.s8,
            vertical: CinemaSpace.s4,
          ),
          child: Center(
            child: vertical
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 22, color: iconColor),
                      const SizedBox(height: CinemaSpace.s4),
                      text,
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 22, color: iconColor),
                      const SizedBox(width: CinemaSpace.s8),
                      Flexible(child: text),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = cursorPosition.clamp(0.0, 1.0);
    final isClientActive = pos < 0.5;
    final isProviderActive = pos >= 0.5;

    final thumbStart = Color.lerp(
      const Color(0xFF1E3A8A),
      const Color(0xFF047857),
      pos,
    )!;
    final thumbEnd = Color.lerp(
      const Color(0xFF2563EB),
      const Color(0xFF0F766E),
      pos,
    )!;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => onInteractivePointerDown(event.pointer),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CinemaGeometry.heroRadius - 4),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDFE7F0), Color(0xFFE8EEF5), Color(0xFFEDF2F8)],
            stops: [0.0, 0.24, 1.0],
          ),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CinemaSpace.s4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final optionWidth = constraints.maxWidth / 2;
              final vertical =
                  cinemaTextScale(context) >= 1.2 || optionWidth < 150;
              return Stack(
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment((pos * 2.0) - 1.0, 0.0),
                      child: FractionallySizedBox(
                        widthFactor: 0.50,
                        heightFactor: 1.0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              CinemaGeometry.itemRadius + 4,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [thumbStart, thumbEnd],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.30),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: thumbEnd.withValues(alpha: 0.28),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                              BoxShadow(
                                color: CinemaColors.ink.withValues(alpha: 0.16),
                                blurRadius: 4,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              CinemaGeometry.itemRadius + 4,
                            ),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                height: 12,
                                width: double.infinity,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.24),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _option(
                            key: const Key('dual-mode-option-client'),
                            mode: 0,
                            icon: Icons.home_rounded,
                            label: 'Modo Cliente',
                            active: isClientActive,
                            inactiveIconColor: const Color(0xFF1E3A8A),
                            vertical: vertical,
                          ),
                        ),
                        Expanded(
                          child: _option(
                            key: const Key('dual-mode-option-provider'),
                            mode: 1,
                            icon: Icons.handyman_rounded,
                            label: 'Modo Profissional',
                            active: isProviderActive,
                            inactiveIconColor: CinemaColors.emeraldDeep,
                            vertical: vertical,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

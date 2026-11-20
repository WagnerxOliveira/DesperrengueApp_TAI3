import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/ui/category_brand_emblem.dart';
import '../../../../core/ui/typography/cinema_type_scale.dart';
import 'cinema_card_parts.dart';
import 'cinema_motion.dart';

// =============================================================================
// ETAPA 1 — BUSCA 56 px + LISTA VERTICAL DE 3 ITENS VERIFICADOS + SELO REGIONAL
// =============================================================================

class CinemaStory1Card extends StatelessWidget {
  const CinemaStory1Card({super.key, required this.act});

  final Animation<double> act;

  static const String fullQuery = 'Trocar resistência do chuveiro';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SearchField(act: act, fullQuery: fullQuery),
        const SizedBox(height: CinemaSpace.s16),
        _SpecialtyList(act: act),
        const SizedBox(height: CinemaSpace.s16),
        ActFx(
          act: act,
          effects: cascadeEffects(0.62, 0.90, dy: 8),
          child: const Center(
            child: CinemaSealPill(
              icon: Icons.check_circle_rounded,
              label: 'Atendimento rápido na sua região',
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.act, required this.fullQuery});

  final Animation<double> act;
  final String fullQuery;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: act,
      builder: (context, _) {
        // 0.8s..1.8s de 3.10s -> [0.258 .. 0.581]
        final raw = ((act.value - 0.258) / (0.581 - 0.258)).clamp(0.0, 1.0);
        final progress = Curves.easeOutCubic.transform(raw);
        const minChars = 13; // "Trocar resist"
        final visibleCount =
            (minChars + ((fullQuery.length - minChars) * progress).round())
                .clamp(minChars, fullQuery.length);
        final isFinished = visibleCount >= fullQuery.length;
        final visibleText = fullQuery.substring(0, visibleCount);

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(CinemaGeometry.itemRadius),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFF6EE7B7),
                CinemaColors.emerald,
                progress,
              )!,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: CinemaColors.emerald.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: CinemaGeometry.inputHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CinemaSpace.s16,
                vertical: CinemaSpace.s8,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 24,
                    color: CinemaColors.emeraldDeep,
                  ),
                  const SizedBox(width: CinemaSpace.s12),
                  if (isFinished) ...[
                    Expanded(
                      child: Text(visibleText, style: CinemaType.inputText),
                    ),
                    const SizedBox(width: CinemaSpace.s8),
                    const Icon(
                      Icons.check_circle_rounded,
                      key: Key('search-completed-check'),
                      size: 24,
                      color: CinemaColors.emerald,
                    ),
                  ] else ...[
                    Flexible(
                      child: Text(visibleText, style: CinemaType.inputText),
                    ),
                    const SizedBox(width: 2),
                    const DecoratedBox(
                      key: Key('search-typing-caret'),
                      decoration: BoxDecoration(
                        color: CinemaColors.emerald,
                        borderRadius: BorderRadius.all(Radius.circular(1)),
                      ),
                      child: SizedBox(width: 2, height: 15),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SpecialtyList extends StatelessWidget {
  const _SpecialtyList({required this.act});

  final Animation<double> act;

  static const List<(String, String)> _items = <(String, String)>[
    ('Eletricista', 'Elétrica'),
    ('Encanador', 'Encanador'),
    ('Climatização', 'Ar-condicionado'),
  ];

  @override
  Widget build(BuildContext context) {
    return CinemaGroupedList(
      children: List<Widget>.generate(_items.length, (i) {
        final start = 0.36 + (i * 0.075);
        return ActFx(
          act: act,
          effects: cascadeEffects(start, start + 0.24, dy: 8, fadeFrom: 0.3),
          child: CinemaListRow(
            child: Row(
              children: [
                CategoryBrandEmblem(
                  categoryName: _items[i].$2,
                  size: CinemaGeometry.iconTileSize,
                  showCornerBadge: false,
                ),
                const SizedBox(width: CinemaSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_items[i].$1, style: CinemaType.rowTitle),
                      const Text(
                        'Verificado · Atende hoje',
                        style: CinemaType.rowMeta,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: CinemaSpace.s8),
                CinemaLottie(
                  asset: CinemaLottieAssets.checkBurst,
                  act: act,
                  size: 32,
                  begin: start + 0.04,
                  end: start + 0.30,
                  fallbackIcon: Icons.check_circle_rounded,
                  fallbackColor: CinemaColors.emerald,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// =============================================================================
// ETAPA 2 — PEDIDO PROTEGIDO: FAIXA DE PRIVACIDADE + 3 PROPOSTAS EM 2 LINHAS
// =============================================================================

class CinemaStory2Card extends StatelessWidget {
  const CinemaStory2Card({super.key, required this.act});

  final Animation<double> act;

  static const List<(String, String, String, String)> proposals =
      <(String, String, String, String)>[
        ('Proposta 1', 'R\$ 120,00', '4,9', 'Chega em 40 min'),
        ('Proposta 2', 'R\$ 150,00', '4,8', 'Chega em 1 h'),
        ('Proposta 3', 'R\$ 180,00', '4,7', 'Chega hoje'),
      ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Pedido Protegido', style: CinemaType.cardTitle),
        const SizedBox(height: CinemaSpace.s12),
        _PrivacyStrip(act: act),
        const SizedBox(height: CinemaSpace.s16),
        for (var i = 0; i < proposals.length; i++) ...[
          if (i > 0) const SizedBox(height: CinemaSpace.s8),
          ActFx(
            act: act,
            effects: cascadeEffects(
              0.30 + (i * 0.08),
              0.54 + (i * 0.08),
              dy: 10,
              fadeFrom: 0.2,
            ),
            child: _ProposalItem(act: act, index: i),
          ),
        ],
      ],
    );
  }
}

class _PrivacyStrip extends StatelessWidget {
  const _PrivacyStrip({required this.act});

  final Animation<double> act;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: act,
      builder: (context, _) {
        // 0.85s..1.75s de 3.10s -> [0.274 .. 0.565]
        final shieldProgress = actProgress(act, 0.274, 0.565);
        final shielded = shieldProgress >= 0.45;
        final bg = Color.lerp(
          const Color(0xFFF1F5F9),
          const Color(0xFFDCFCE7),
          shieldProgress,
        )!;
        final border = Color.lerp(
          const Color(0xFFCBD5E1),
          const Color(0xFF86EFAC),
          shieldProgress,
        )!;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(CinemaGeometry.itemRadius),
            border: Border.all(color: border, width: 1.2),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: CinemaGeometry.privacyStripHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CinemaSpace.s16,
                vertical: CinemaSpace.s8,
              ),
              child: Row(
                children: [
                  CinemaLottie(
                    asset: CinemaLottieAssets.lockClose,
                    act: act,
                    size: 32,
                    begin: 0.274,
                    end: 0.565,
                    fallbackIcon: Icons.lock_rounded,
                    fallbackColor: CinemaColors.emeraldDeep,
                  ),
                  const SizedBox(width: CinemaSpace.s12),
                  Expanded(
                    child: Text(
                      shielded
                          ? 'Rua e número protegidos'
                          : 'Ocultando rua e número...',
                      style: CinemaType.rowTitle.copyWith(
                        color: shielded
                            ? CinemaColors.emeraldInk
                            : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProposalItem extends StatelessWidget {
  const _ProposalItem({required this.act, required this.index});

  final Animation<double> act;
  final int index;

  @override
  Widget build(BuildContext context) {
    final data = CinemaStory2Card.proposals[index];
    final isBest = index == 0;

    return AnimatedBuilder(
      animation: act,
      builder: (context, _) {
        // Destaque da Proposta 1 aos ~2.1s (0.65 .. 0.89 de 3.10s)
        final highlight = isBest ? actProgress(act, 0.65, 0.89) : 0.0;
        final selected = highlight > 0.5;

        final leading = SizedBox(
          width: 24,
          height: 24,
          child: isBest
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: (1.0 - highlight).clamp(0.0, 1.0),
                      child: const Icon(
                        Icons.radio_button_unchecked_rounded,
                        size: 24,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    CinemaLottie(
                      asset: CinemaLottieAssets.checkBurst,
                      act: act,
                      size: 24,
                      begin: 0.65,
                      end: 0.95,
                      fallbackIcon: Icons.check_circle_rounded,
                      fallbackColor: CinemaColors.emerald,
                    ),
                  ],
                )
              : const Icon(
                  Icons.radio_button_unchecked_rounded,
                  size: 24,
                  color: Color(0xFF94A3B8),
                ),
        );

        final title = Wrap(
          spacing: CinemaSpace.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(data.$1, style: CinemaType.rowTitle),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: CinemaColors.amber,
                ),
                const SizedBox(width: 2),
                Text(
                  data.$3,
                  style: CinemaType.tabular(
                    CinemaType.rowMeta.copyWith(
                      fontWeight: FontWeight.w600,
                      color: CinemaColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

        final priceStyle = CinemaType.figureSm.copyWith(
          color: selected ? CinemaColors.emeraldInk : CinemaColors.ink,
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(
              Colors.white,
              CinemaColors.emeraldMist,
              highlight,
            ),
            borderRadius: BorderRadius.circular(CinemaGeometry.itemRadius),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFFE2E8F0),
                CinemaColors.emerald,
                highlight,
              )!,
              width: selected ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: CinemaColors.ink.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CinemaListRow(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    cinemaTextScale(context) >= 1.25 ||
                    constraints.maxWidth < 240;
                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    title,
                    Text(data.$4, style: CinemaType.rowMeta),
                    if (stacked) ...[
                      const SizedBox(height: CinemaSpace.s4),
                      Text(data.$2, style: priceStyle),
                    ],
                  ],
                );
                return Row(
                  children: [
                    leading,
                    const SizedBox(width: CinemaSpace.s8),
                    Expanded(child: details),
                    if (!stacked) ...[
                      const SizedBox(width: CinemaSpace.s8),
                      Text(data.$2, style: priceStyle),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// ETAPA 3 — COFRE 3D (+20%) COM TRAVA LOTTIE, VALOR, PIN 52×52
// =============================================================================

class CinemaStory3Card extends StatelessWidget {
  const CinemaStory3Card({super.key, required this.act});

  final Animation<double> act;

  static const List<String> pinDigits = <String>['4', '8', '2', '9'];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActFx(
          act: act,
          effects: cascadeEffects(0.40, 0.80, dy: 0, fadeFrom: 0.28),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 22,
                color: Color(0xFF059669),
              ),
              const SizedBox(width: CinemaSpace.s8),
              Expanded(
                child: Text(
                  'Serviço aprovado · 90 dias de garantia',
                  style: CinemaType.rowTitle.copyWith(
                    color: const Color(0xFF065F46),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: CinemaSpace.s16),
        _VaultStage(act: act),
        const SizedBox(height: CinemaSpace.s16),
        ActFx(
          act: act,
          effects: cascadeEffects(0.46, 0.76, dy: 8, scaleFrom: 0.94),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'R\$ 180,00',
                textAlign: TextAlign.center,
                style: CinemaType.figure,
              ),
              Text(
                'Guardado com segurança',
                textAlign: TextAlign.center,
                style: CinemaType.rowMeta,
              ),
            ],
          ),
        ),
        const SizedBox(height: CinemaSpace.s16),
        _PinRow(act: act),
      ],
    );
  }
}

class _VaultStage extends StatelessWidget {
  const _VaultStage({required this.act});

  final Animation<double> act;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5F0),
        borderRadius: BorderRadius.circular(CinemaGeometry.itemRadius),
        border: Border.all(color: const Color(0xFFCFE8DE)),
      ),
      child: SizedBox(
        height: 120,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: act,
                  builder: (context, _) => CustomPaint(
                    painter: _ProtectedEscrowVaultArtPainter(
                      lockProgress: actProgress(act, 0.20, 0.85),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: CinemaSpace.s8,
              right: CinemaSpace.s8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.86),
                  border: Border.all(color: const Color(0xFFCFE8DE)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(CinemaSpace.s4),
                  child: CinemaLottie(
                    asset: CinemaLottieAssets.lockClose,
                    act: act,
                    size: 32,
                    begin: 0.22,
                    end: 0.62,
                    fallbackIcon: Icons.lock_rounded,
                    fallbackColor: CinemaColors.emeraldDeep,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: CinemaLottie(
                    asset: CinemaLottieAssets.sparkleSoft,
                    act: act,
                    size: 120,
                    begin: 0.55,
                    end: 0.95,
                    curve: Curves.linear,
                    fallbackIcon: Icons.auto_awesome_rounded,
                    fallbackColor: Colors.transparent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinRow extends StatelessWidget {
  const _PinRow({required this.act});

  final Animation<double> act;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F6),
        borderRadius: BorderRadius.circular(CinemaGeometry.heroRadius - 4),
        border: Border.all(color: const Color(0xFFD8E1EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CinemaSpace.s12),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: CinemaSpace.s8,
          runSpacing: CinemaSpace.s8,
          children: List<Widget>.generate(CinemaStory3Card.pinDigits.length, (
            i,
          ) {
            return _PinCell(act: act, index: i);
          }),
        ),
      ),
    );
  }
}

class _PinCell extends StatelessWidget {
  const _PinCell({required this.act, required this.index});

  final Animation<double> act;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isFinalConfirmed = index == CinemaStory3Card.pinDigits.length - 1;
    // 1.0s..2.4s -> [0.323 .. 0.774]
    final threshold = 0.33 + (index * 0.115);

    return AnimatedBuilder(
      animation: act,
      builder: (context, _) {
        final lit = actProgress(act, threshold, threshold + 0.11);
        final isLit = lit >= 0.45;
        return SizedBox(
          width: CinemaGeometry.pinCellSize,
          height: CinemaGeometry.pinCellSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CinemaGeometry.itemRadius),
              color: isFinalConfirmed
                  ? Color.lerp(Colors.white, const Color(0xFFDCFCE7), lit)
                  : Colors.white,
              border: Border.all(
                color: isFinalConfirmed
                    ? Color.lerp(
                        const Color(0xFFCBD5E1),
                        CinemaColors.emerald,
                        lit,
                      )!
                    : const Color(0xFFD8E1EB),
                width: isFinalConfirmed ? 2.0 : 1.0,
              ),
            ),
            child: Center(
              child: Text(
                isLit ? CinemaStory3Card.pinDigits[index] : '•',
                style: CinemaType.figureSm.copyWith(
                  color: isFinalConfirmed && isLit
                      ? CinemaColors.emeraldInk
                      : CinemaColors.ink,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Ilustração Vetorial 3D de Cofre Metálico Escovado + Cartão Safira com Chip
/// Dourado sobre palco menta-pérola.
class _ProtectedEscrowVaultArtPainter extends CustomPainter {
  const _ProtectedEscrowVaultArtPainter({required this.lockProgress});

  final double lockProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 220.0, size.height / 96.0);
    canvas.save();
    canvas.translate(
      (size.width - (220.0 * s)) / 2.0,
      (size.height - (96.0 * s)) / 2.0,
    );
    canvas.scale(s, s);

    // Sombra macia de contato no palco menta-pérola
    canvas.drawOval(
      const Rect.fromLTWH(34, 72, 152, 14),
      Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.12),
    );

    // 1) COFRE METÁLICO TITÂNIO ESCOVADO 3D (ESQUERDA/CENTRO)
    final sideDepth = RRect.fromRectAndRadius(
      const Rect.fromLTWH(46, 16, 16, 58),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      sideDepth,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF64748B), Color(0xFF334155)],
        ).createShader(const Rect.fromLTWH(46, 16, 16, 58)),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(56, 72, 12, 5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF1E293B),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(102, 72, 12, 5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF1E293B),
    );

    const vaultRect = Rect.fromLTWH(53, 14, 68, 60);
    final vaultRRect = RRect.fromRectAndRadius(
      vaultRect,
      const Radius.circular(8),
    );
    canvas.drawRRect(
      vaultRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F5F9), Color(0xFFCBD5E1), Color(0xFF94A3B8)],
          stops: [0.0, 0.52, 1.0],
        ).createShader(vaultRect),
    );
    canvas.drawRRect(
      vaultRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF64748B),
    );

    const doorRect = Rect.fromLTWH(60, 21, 54, 46);
    final doorRRect = RRect.fromRectAndRadius(
      doorRect,
      const Radius.circular(5),
    );
    canvas.drawRRect(
      doorRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE2E8F0), Color(0xFF94A3B8)],
        ).createShader(doorRect),
    );
    canvas.drawRRect(
      doorRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFF475569),
    );

    for (final hy in const [27.0, 53.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(57, hy, 5, 8),
          const Radius.circular(1.5),
        ),
        Paint()..color = const Color(0xFF334155),
      );
    }

    // Volante circular central da trava do cofre (gira suavemente até travar)
    const dialCenter = Offset(87, 44);
    canvas.drawCircle(
      dialCenter,
      12.5,
      Paint()..color = const Color(0xFF1E293B),
    );
    canvas.drawCircle(
      dialCenter,
      10.2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = Color.lerp(
          const Color(0xFF94A3B8),
          const Color(0xFF34D399),
          lockProgress,
        )!,
    );

    final angleBase = lockProgress * (math.pi * 0.25);
    final spokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF8FAFC);
    for (var k = 0; k < 4; k++) {
      final a = angleBase + (k * math.pi / 2);
      canvas.drawLine(
        dialCenter,
        Offset(
          dialCenter.dx + math.cos(a) * 7.2,
          dialCenter.dy + math.sin(a) * 7.2,
        ),
        spokePaint,
      );
    }
    canvas.drawCircle(
      dialCenter,
      3.0,
      Paint()..color = const Color(0xFFE2E8F0),
    );

    // 2) CARTÃO SAFIRA PROTEGIDO COM CHIP DOURADO (SOBREPOSTO À DIREITA)
    const cardRect = Rect.fromLTWH(105, 24, 74, 48);
    final cardRRect = RRect.fromRectAndRadius(
      cardRect,
      const Radius.circular(8),
    );

    canvas.drawRRect(
      cardRRect.shift(const Offset(-3, 4)),
      Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.24),
    );

    canvas.drawRRect(
      cardRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(cardRect),
    );

    canvas.save();
    canvas.clipRRect(cardRRect);
    final sheen = Path()
      ..moveTo(118, 24)
      ..lineTo(148, 24)
      ..lineTo(130, 72)
      ..lineTo(105, 72)
      ..close();
    canvas.drawPath(
      sheen,
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );
    canvas.restore();

    canvas.drawRRect(
      cardRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFF93C5FD).withValues(alpha: 0.65),
    );

    const chipRect = Rect.fromLTWH(114, 37, 15, 11);
    final chipRRect = RRect.fromRectAndRadius(
      chipRect,
      const Radius.circular(2.5),
    );
    canvas.drawRRect(
      chipRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
        ).createShader(chipRect),
    );
    canvas.drawLine(
      const Offset(114, 42.5),
      const Offset(129, 42.5),
      Paint()
        ..strokeWidth = 0.8
        ..color = const Color(0xFFB45309),
    );

    for (var d = 0; d < 4; d++) {
      canvas.drawCircle(
        Offset(116.0 + (d * 5.0), 59.0),
        1.3,
        Paint()..color = const Color(0xFFDBEAFE),
      );
    }
    canvas.drawCircle(
      const Offset(166, 58),
      6.5,
      Paint()..color = const Color(0xFF10B981),
    );
    final check = Path()
      ..moveTo(163.2, 58.0)
      ..lineTo(165.3, 60.1)
      ..lineTo(169.2, 56.0);
    canvas.drawPath(
      check,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ProtectedEscrowVaultArtPainter oldDelegate) {
    return oldDelegate.lockProgress != lockProgress;
  }
}

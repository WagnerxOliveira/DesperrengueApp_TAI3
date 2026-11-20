import 'package:flutter/material.dart';

import '../../../../core/ui/typography/cinema_type_scale.dart';

/// Escala de texto efetiva do sistema (já limitada a 1.0–1.5 no palco).
double cinemaTextScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(10.0) / 10.0;

/// Tile de ícone 40×40 (raio 12) com fundo suave do próprio tom do ícone.
class CinemaIconTile extends StatelessWidget {
  const CinemaIconTile({
    super.key,
    required this.icon,
    required this.color,
    this.iconSize = 22,
    this.child,
  });

  final IconData icon;
  final Color color;
  final double iconSize;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: CinemaGeometry.iconTileSize,
      height: CinemaGeometry.iconTileSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(CinemaGeometry.iconTileRadius),
        ),
        child: Center(
          child: child ?? Icon(icon, size: iconSize, color: color),
        ),
      ),
    );
  }
}

/// Linha de lista: altura mínima 56, padding 16/12, conteúdo livre.
class CinemaListRow extends StatelessWidget {
  const CinemaListRow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: CinemaGeometry.itemMinHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CinemaSpace.s16,
          vertical: CinemaSpace.s12,
        ),
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    );
  }
}

/// Contêiner de lista agrupada (raio 16, borda suave, divisor interno 1 px).
class CinemaGroupedList extends StatelessWidget {
  const CinemaGroupedList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          const SizedBox(
            height: 1,
            child: ColoredBox(color: CinemaColors.divider),
          ),
        );
      }
      rows.add(children[i]);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CinemaGeometry.itemRadius),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: CinemaColors.ink.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CinemaGeometry.itemRadius - 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    );
  }
}

/// Selo/pílula informativa (ícone vetorial + texto que quebra em 2 linhas).
class CinemaSealPill extends StatelessWidget {
  const CinemaSealPill({
    super.key,
    required this.icon,
    required this.label,
    this.background = CinemaColors.emeraldMist,
    this.border = CinemaColors.emeraldRing,
    this.foreground = CinemaColors.emeraldInk,
    this.iconColor = const Color(0xFF059669),
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color border;
  final Color foreground;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(CinemaGeometry.itemRadius),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CinemaSpace.s16,
          vertical: CinemaSpace.s8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: CinemaSpace.s8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: CinemaType.rowMeta.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

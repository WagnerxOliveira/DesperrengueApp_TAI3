import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:desperrengue_app/core/ui/design_system/design_system.dart';

/// Fundo editorial Porcelain / Obsidian com aura radial dupla no topo e rodapé
/// da jornada de cadastro.
///
/// Mantém base neutra (`tk.background`) com gradientes radiais translúcidos em
/// [RepaintBoundary] (zero recomposição por frame), preservando contraste
/// WCAG 2.2 AA em temas claro e escuro, tanto no Modo Cliente quanto Profissional.
class KycAmbientBackdrop extends StatelessWidget {
  const KycAmbientBackdrop({
    super.key,
    required this.child,
    this.isProviderMode = false,
  });

  final Widget child;
  final bool isProviderMode;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final auraColor = isProviderMode ? tk.providerAccent : tk.accent;
    final counterAura = isProviderMode ? tk.clientAccent : tk.brand;
    final peakAlpha = tk.isDark ? 0.11 : 0.06;
    final counterAlpha = tk.isDark ? 0.06 : 0.03;

    return ColoredBox(
      color: tk.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(-0.15, -1.08),
                            radius: 1.08,
                            colors: [
                              auraColor.withValues(alpha: peakAlpha),
                              auraColor.withValues(alpha: peakAlpha * 0.32),
                              auraColor.withValues(alpha: 0),
                            ],
                            stops: const [0.0, 0.44, 1.0],
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0.85, 1.05),
                            radius: 0.95,
                            colors: [
                              counterAura.withValues(alpha: counterAlpha),
                              counterAura.withValues(alpha: 0),
                            ],
                            stops: const [0.0, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Cabeçalho de progresso luminoso (Stepped Progress Dock) das 6 etapas.
///
/// Exibe selo do modo ativo, contador tabular com tempo estimado, trilho
/// segmentado com estágio ativo destacado, indicador da etapa atual e percentual.
class KycJourneyProgressHeader extends StatelessWidget {
  const KycJourneyProgressHeader({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepName,
    required this.estimatedRemaining,
    required this.isProviderMode,
  });

  final int currentStep;
  final int totalSteps;
  final String stepName;
  final String estimatedRemaining;
  final bool isProviderMode;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    final reduced = AppMotion.reduced(context);

    final safeTotal = totalSteps < 1 ? 1 : totalSteps;
    final safeStep = currentStep.clamp(1, safeTotal);
    final percent = ((safeStep / safeTotal) * 100).round();

    final modeLabel = isProviderMode ? 'Modo Profissional' : 'Modo Cliente';
    final modeIcon = isProviderMode
        ? Icons.handyman_outlined
        : Icons.person_outline_rounded;
    final modeFg = isProviderMode ? tk.providerAccentInk : tk.clientAccentInk;
    final modeBg = isProviderMode ? tk.providerSoft : tk.clientSoft;
    final fillColor = isProviderMode ? tk.providerAccent : tk.accent;
    final inkColor = isProviderMode ? tk.providerAccentInk : tk.accentInk;
    final trackColor = tk.isDark ? tk.border : tk.surfaceInset;

    final remainingTrimmed = estimatedRemaining.trim();
    final stepCounterLabel = remainingTrimmed.isEmpty
        ? 'Etapa $safeStep de $safeTotal'
        : 'Etapa $safeStep de $safeTotal · $remainingTrimmed';

    final modeChip = AppStatusChip(
      modeLabel,
      icon: modeIcon,
      color: modeFg,
      background: modeBg,
    );

    final counterText = Text(
      stepCounterLabel,
      style: AppType.tabular(AppType.bodySm).copyWith(
        color: tk.textMuted,
        fontWeight: FontWeight.w600,
      ),
    );

    final useWrap = layout.isCompact || layout.isLargeText;
    final hasStepName = stepName.trim().isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tk.isDark
            ? tk.surface.withValues(alpha: 0.92)
            : tk.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tk.border.withValues(alpha: tk.isDark ? 0.85 : 0.95),
        ),
        boxShadow: tk.isDark ? const [] : tk.elevation(1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12,
          vertical: AppSpace.s4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (useWrap)
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s2,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    modeChip,
                    counterText,
                  ],
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(fit: FlexFit.loose, child: modeChip),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        stepCounterLabel,
                        textAlign: TextAlign.end,
                        style: AppType.tabular(AppType.bodySm).copyWith(
                          color: tk.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpace.s4 + 2),
            Semantics(
              label: 'Progresso da configuração: etapa $safeStep de $safeTotal',
              value: '$percent por cento',
              excludeSemantics: true,
              child: Row(
                children: [
                  for (var i = 0; i < safeTotal; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpace.s4),
                    Expanded(
                      child: _ProgressSegment(
                        filled: i < safeStep,
                        isCurrent: i == safeStep - 1,
                        fillColor: fillColor,
                        trackColor: trackColor,
                        reduced: reduced,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasStepName) ...[
              const SizedBox(height: AppSpace.s4),
              Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: inkColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Text(
                      stepName,
                      style: AppType.bodySm.copyWith(
                        color: tk.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Text(
                    '$percent%',
                    style: AppType.tabular(AppType.bodySm).copyWith(
                      color: inkColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressSegment extends StatelessWidget {
  const _ProgressSegment({
    required this.filled,
    required this.isCurrent,
    required this.fillColor,
    required this.trackColor,
    required this.reduced,
  });

  final bool filled;
  final bool isCurrent;
  final Color fillColor;
  final Color trackColor;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppGeometry.pillRadius);
    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: radius,
      ),
      child: const SizedBox.expand(),
    );

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: isCurrent ? 5.5 : 4.5,
        color: trackColor,
        alignment: Alignment.centerLeft,
        child: reduced
            ? FractionallySizedBox(
                widthFactor: filled ? 1.0 : 0.0,
                heightFactor: 1.0,
                child: bar,
              )
            : AnimatedFractionallySizedBox(
                duration: AppMotion.d(context, AppMotion.progress),
                curve: AppMotion.pageCurve,
                widthFactor: filled ? 1.0 : 0.0,
                heightFactor: 1.0,
                alignment: Alignment.centerLeft,
                child: bar,
              ),
      ),
    );
  }
}

/// Bloco editorial no topo de cada etapa com emblema estilizado compacto,
/// título de destaque em Plus Jakarta Sans, subtítulo objetivo e micro-selo
/// de confiança opcional.
class KycStepHeroHeader extends StatelessWidget {
  const KycStepHeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.leadingEmblem,
    this.trustBadgeText,
    this.trustBadgeIcon,
    this.isDisplayTitle = false,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final Widget? leadingEmblem;
  final String? trustBadgeText;
  final IconData? trustBadgeIcon;
  final bool isDisplayTitle;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;

    final iconSquircle = icon == null
        ? null
        : ExcludeSemantics(
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tk.accentSoft,
                    Color.lerp(tk.accentSoft, tk.card, 0.35)!,
                  ],
                ),
                border: Border.all(
                  color: tk.accentInk.withValues(alpha: tk.isDark ? 0.34 : 0.20),
                ),
              ),
              child: Center(
                child: Icon(icon, size: 21, color: tk.accentInk),
              ),
            ),
          );

    final titleStyle =
        (isDisplayTitle ? AppType.display : AppType.headline).copyWith(
      color: tk.text,
    );

    final badgeText = trustBadgeText?.trim() ?? '';
    final useInlineHeader =
        leadingEmblem == null && iconSquircle != null && !layout.isLargeText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leadingEmblem != null) ...[
          leadingEmblem!,
          const SizedBox(height: AppSpace.s8),
          Semantics(
            header: true,
            child: Text(title, style: titleStyle),
          ),
        ] else if (useInlineHeader) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              iconSquircle,
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: titleStyle),
                ),
              ),
            ],
          ),
        ] else ...[
          if (iconSquircle != null) ...[
            iconSquircle,
            const SizedBox(height: AppSpace.s8),
          ],
          Semantics(
            header: true,
            child: Text(title, style: titleStyle),
          ),
        ],
        const SizedBox(height: AppSpace.s4),
        Text(
          subtitle,
          style: AppType.bodySm.copyWith(color: tk.textMuted),
        ),
        if (badgeText.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s8),
          KycTrustMicroBadge(
            text: badgeText,
            icon: trustBadgeIcon ?? Icons.lock_outline_rounded,
          ),
        ],
      ],
    );
  }
}

/// Pílula limpa para selos contextuais de privacidade e proteção de dados (LGPD),
/// garantindo contraste >= 4,5:1 em qualquer [AppTone] nos temas claro e escuro.
class KycTrustMicroBadge extends StatelessWidget {
  const KycTrustMicroBadge({
    super.key,
    required this.text,
    this.icon = Icons.lock_outline_rounded,
    this.tone = AppTone.success,
  });

  final String text;
  final IconData icon;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final (bg, fg) = tone.resolve(tk);
    final subtleBg = tk.isDark ? tk.surface : bg;
    final subtleBorder = fg.withValues(alpha: tk.isDark ? 0.28 : 0.20);
    final labelColor = tk.isDark ? tk.text : fg;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: subtleBg,
        borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
        border: Border.all(color: subtleBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12,
          vertical: AppSpace.s8 - 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: AppSpace.s8),
            Flexible(
              child: Text(
                text,
                style: AppType.bodySm.copyWith(
                  color: labelColor,
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

/// Cartão de seção Porcelain elevado (`radius: 24`, `padding: AppSpace.cardLarge`)
/// com cabeçalho estruturado, chip de progresso dinâmico opcional e divisória sutil.
class KycPorcelainSectionCard extends StatelessWidget {
  const KycPorcelainSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.statusChipLabel,
    this.statusTone = AppTone.neutral,
    this.icon,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final String? statusChipLabel;
  final AppTone statusTone;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    final chipLabel = statusChipLabel?.trim() ?? '';
    final hasChip = chipLabel.isNotEmpty;
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;

    final leadingIcon = icon == null
        ? null
        : ExcludeSemantics(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tk.accentSoft,
                    Color.lerp(tk.accentSoft, tk.card, 0.35)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
                border: Border.all(
                  color: tk.accentInk.withValues(alpha: tk.isDark ? 0.28 : 0.16),
                ),
              ),
              child: Icon(icon, size: 19, color: tk.accentInk),
            ),
          );

    final statusChip = hasChip
        ? AppStatusChip(chipLabel, tone: statusTone)
        : null;

    final hasTopBar = leadingIcon != null || statusChip != null;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppType.titleSm.copyWith(color: tk.text),
          ),
        ),
        if (hasSubtitle) ...[
          const SizedBox(height: AppSpace.s2),
          Text(
            subtitle!,
            style: AppType.bodySm.copyWith(color: tk.textMuted),
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : layout.width;
        final singleRowHeader = effectiveWidth >= 480 && !layout.isLargeText;
        final inlineLeadingOnly = !singleRowHeader &&
            statusChip == null &&
            leadingIcon != null &&
            !layout.isLargeText;
        final cardPadding = singleRowHeader
            ? const EdgeInsets.symmetric(
                horizontal: AppSpace.cardLarge,
                vertical: AppSpace.s16,
              )
            : EdgeInsets.symmetric(
                horizontal:
                    effectiveWidth < 390 ? AppSpace.card : AppSpace.cardLarge,
                vertical: AppSpace.s12,
              );

        return AppCard(
          variant: AppCardVariant.elevated,
          radius: 22,
          padding: cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (singleRowHeader)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (leadingIcon != null) ...[
                      leadingIcon,
                      const SizedBox(width: AppSpace.s12),
                    ],
                    Expanded(child: titleBlock),
                    if (statusChip != null) ...[
                      const SizedBox(width: AppSpace.s12),
                      Flexible(fit: FlexFit.loose, child: statusChip),
                    ],
                  ],
                )
              else if (inlineLeadingOnly)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leadingIcon,
                    const SizedBox(width: AppSpace.s12),
                    Expanded(child: titleBlock),
                  ],
                )
              else ...[
                if (hasTopBar) ...[
                  if (layout.isCompact || layout.isLargeText)
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: AppSpace.s8,
                        runSpacing: AppSpace.s8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ?leadingIcon,
                          ?statusChip,
                        ],
                      ),
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ?leadingIcon,
                        const Spacer(),
                        if (statusChip != null)
                          Flexible(fit: FlexFit.loose, child: statusChip),
                      ],
                    ),
                  const SizedBox(height: AppSpace.s8),
                ],
                // Em cartões estreitos (< 480dp), título e subtítulo ocupam SEMPRE
                // 100% da largura interna (elimina quebra no meio da palavra).
                titleBlock,
              ],
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: singleRowHeader ? AppSpace.s16 : AppSpace.s12,
                ),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: tk.border.withValues(alpha: tk.isDark ? 0.70 : 0.85),
                ),
              ),
              child,
            ],
          ),
        );
      },
    );
  }
}

/// Ilustração vetorial minimalista inspirada em verificação facial biométrica,
/// isolada em [RepaintBoundary] e adaptada automaticamente a claro/escuro via `context.tk`.
class KycFaceIdIllustration extends StatelessWidget {
  const KycFaceIdIllustration({
    super.key,
    this.size = 108,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _FaceIdIllustrationPainter(
              accent: tk.accent,
              accentInk: tk.accentInk,
              accentSoft: tk.accentSoft,
              border: tk.border,
              surface: tk.card,
              isDark: tk.isDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _FaceIdIllustrationPainter extends CustomPainter {
  const _FaceIdIllustrationPainter({
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.border,
    required this.surface,
    required this.isDark,
  });

  final Color accent;
  final Color accentInk;
  final Color accentSoft;
  final Color border;
  final Color surface;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;

    // Ondas radiais sutis externas
    final outerWave = Paint()
      ..color = accent.withValues(alpha: isDark ? 0.12 : 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, r, outerWave);

    final midWave = Paint()
      ..color = accentSoft.withValues(alpha: isDark ? 0.85 : 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, r * 0.80, midWave);

    final innerWaveStroke = Paint()
      ..color = accent.withValues(alpha: isDark ? 0.30 : 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, r * 0.80, innerWaveStroke);

    // Moldura oval central luminosa
    final ovalRect = Rect.fromCenter(
      center: center,
      width: r * 0.96,
      height: r * 1.18,
    );
    final ovalFill = Paint()
      ..color = surface
      ..style = PaintingStyle.fill;
    canvas.drawOval(ovalRect, ovalFill);

    final ovalStroke = Paint()
      ..color = accentInk.withValues(alpha: isDark ? 0.65 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawOval(ovalRect, ovalStroke);

    // Cantoneiras de enquadramento (estilo Face ID)
    final bracketPaint = Paint()
      ..color = accentInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = (r * 0.055).clamp(2.0, 3.2)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final box = Rect.fromCenter(
      center: center,
      width: r * 1.32,
      height: r * 1.32,
    );
    final arm = r * 0.24;
    final cr = r * 0.14;

    void drawCorner(Offset corner, double dx, double dy) {
      final path = Path()
        ..moveTo(corner.dx + dx * arm, corner.dy)
        ..lineTo(corner.dx + dx * cr, corner.dy)
        ..quadraticBezierTo(corner.dx, corner.dy, corner.dx, corner.dy + dy * cr)
        ..lineTo(corner.dx, corner.dy + dy * arm);
      canvas.drawPath(path, bracketPaint);
    }

    drawCorner(box.topLeft, 1, 1);
    drawCorner(box.topRight, -1, 1);
    drawCorner(box.bottomLeft, 1, -1);
    drawCorner(box.bottomRight, -1, -1);

    // Traços faciais minimalistas dentro do oval
    final faceStroke = Paint()
      ..color = accentInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = (r * 0.055).clamp(2.0, 3.0)
      ..strokeCap = StrokeCap.round;

    final eyeY = center.dy - r * 0.12;
    final eyeDx = r * 0.19;
    final eyeLen = r * 0.12;
    canvas.drawLine(
      Offset(center.dx - eyeDx, eyeY - eyeLen * 0.5),
      Offset(center.dx - eyeDx, eyeY + eyeLen * 0.5),
      faceStroke,
    );
    canvas.drawLine(
      Offset(center.dx + eyeDx, eyeY - eyeLen * 0.5),
      Offset(center.dx + eyeDx, eyeY + eyeLen * 0.5),
      faceStroke,
    );

    // Ponte nasal estilizada
    final nosePath = Path()
      ..moveTo(center.dx, center.dy - r * 0.14)
      ..lineTo(center.dx, center.dy + r * 0.05)
      ..quadraticBezierTo(
        center.dx,
        center.dy + r * 0.10,
        center.dx - r * 0.07,
        center.dy + r * 0.10,
      );
    canvas.drawPath(nosePath, faceStroke);

    // Sorriso suave
    final smileRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + r * 0.10),
      width: r * 0.42,
      height: r * 0.32,
    );
    canvas.drawArc(smileRect, math.pi * 0.20, math.pi * 0.60, false, faceStroke);
  }

  @override
  bool shouldRepaint(_FaceIdIllustrationPainter old) =>
      old.accent != accent ||
      old.accentInk != accentInk ||
      old.accentSoft != accentSoft ||
      old.border != border ||
      old.surface != surface ||
      old.isDark != isDark;
}

/// Ilustração vetorial limpa de cartão de documento oficial (proporção ISO ID-1)
/// em [CustomPainter] isolado em [RepaintBoundary], com variantes de frente e verso.
class KycDocumentCardWireframe extends StatelessWidget {
  const KycDocumentCardWireframe({
    super.key,
    required this.isFront,
    this.height = 104,
  });

  final bool isFront;
  final double height;

  static const double _isoAspectRatio = 1.586;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: height,
            maxWidth: height * _isoAspectRatio,
          ),
          child: AspectRatio(
            aspectRatio: _isoAspectRatio,
            child: CustomPaint(
              painter: _DocumentCardWireframePainter(
                isFront: isFront,
                cardBg: tk.surfaceAt(1),
                insetBg: tk.isDark ? tk.surface : tk.surfaceInset,
                accentSoft: tk.accentSoft,
                accentInk: tk.accentInk,
                border: tk.border,
                textMuted: tk.textMuted,
                isDark: tk.isDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentCardWireframePainter extends CustomPainter {
  const _DocumentCardWireframePainter({
    required this.isFront,
    required this.cardBg,
    required this.insetBg,
    required this.accentSoft,
    required this.accentInk,
    required this.border,
    required this.textMuted,
    required this.isDark,
  });

  final bool isFront;
  final Color cardBg;
  final Color insetBg;
  final Color accentSoft;
  final Color accentInk;
  final Color border;
  final Color textMuted;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = (h * 0.12).clamp(8.0, 14.0);
    final cardRect = Rect.fromLTWH(0.75, 0.75, w - 1.5, h - 1.5);
    final cardRRect = RRect.fromRectAndRadius(cardRect, Radius.circular(r));

    // Corpo do cartão
    canvas.drawRRect(cardRRect, Paint()..color = cardBg);
    canvas.drawRRect(
      cardRRect,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Recorta elementos internos no raio do cartão
    canvas.save();
    canvas.clipRRect(cardRRect);

    // Faixa superior do cabeçalho oficial
    final headerH = h * 0.22;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, headerH),
      Paint()..color = accentSoft,
    );
    final headerBarPaint = Paint()
      ..color = accentInk.withValues(alpha: isDark ? 0.70 : 0.55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, headerH * 0.36, w * 0.44, headerH * 0.28),
        Radius.circular(headerH * 0.14),
      ),
      headerBarPaint,
    );

    if (isFront) {
      _paintFrontBody(canvas, w, h, headerH);
    } else {
      _paintBackBody(canvas, w, h, headerH);
    }

    canvas.restore();
  }

  void _paintFrontBody(Canvas canvas, double w, double h, double headerH) {
    final padX = w * 0.08;
    final bodyTop = headerH + h * 0.11;
    final photoW = w * 0.25;
    final photoH = h * 0.52;
    final photoRect = Rect.fromLTWH(padX, bodyTop, photoW, photoH);
    final photoRRect = RRect.fromRectAndRadius(photoRect, const Radius.circular(6));

    // Retângulo 3x4 da foto
    canvas.drawRRect(photoRRect, Paint()..color = insetBg);
    canvas.drawRRect(
      photoRRect,
      Paint()
        ..color = accentInk.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Silhueta minimalista dentro da foto 3x4
    final silhouettePaint = Paint()
      ..color = accentInk.withValues(alpha: isDark ? 0.65 : 0.48);
    final headCenter = Offset(photoRect.center.dx, photoRect.top + photoH * 0.35);
    canvas.drawCircle(headCenter, photoW * 0.21, silhouettePaint);

    final shoulders = RRect.fromRectAndCorners(
      Rect.fromCenter(
        center: Offset(photoRect.center.dx, photoRect.bottom - photoH * 0.15),
        width: photoW * 0.68,
        height: photoH * 0.30,
      ),
      topLeft: Radius.circular(photoW * 0.34),
      topRight: Radius.circular(photoW * 0.34),
    );
    canvas.drawRRect(shoulders, silhouettePaint);

    // Linhas de nome e dados à direita
    final linesLeft = photoRect.right + w * 0.08;
    final linesW = w - linesLeft - padX;
    final strongLine = Paint()
      ..color = textMuted.withValues(alpha: isDark ? 0.55 : 0.42);
    final softLine = Paint()
      ..color = border.withValues(alpha: isDark ? 0.95 : 1.0);

    final barH = (h * 0.075).clamp(5.0, 9.0);
    final gap = h * 0.07;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(linesLeft, bodyTop + h * 0.03, linesW * 0.92, barH),
        Radius.circular(barH / 2),
      ),
      strongLine,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(linesLeft, bodyTop + h * 0.03 + barH + gap, linesW * 0.70, barH * 0.85),
        Radius.circular(barH / 2),
      ),
      softLine,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(linesLeft, bodyTop + h * 0.03 + (barH + gap) * 2, linesW * 0.82, barH * 0.85),
        Radius.circular(barH / 2),
      ),
      softLine,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(linesLeft, bodyTop + h * 0.03 + (barH + gap) * 3, linesW * 0.50, barH * 0.85),
        Radius.circular(barH / 2),
      ),
      softLine,
    );
  }

  void _paintBackBody(Canvas canvas, double w, double h, double headerH) {
    final padX = w * 0.08;
    final bodyTop = headerH + h * 0.09;

    // Grade estilizada de QR Code à direita
    final qrSize = h * 0.36;
    final qrRect = Rect.fromLTWH(w - padX - qrSize, bodyTop, qrSize, qrSize);
    canvas.drawRRect(
      RRect.fromRectAndRadius(qrRect, const Radius.circular(5)),
      Paint()..color = accentSoft,
    );

    const grid = 5;
    final cell = (qrSize - 6) / grid;
    final qrPaint = Paint()..color = accentInk.withValues(alpha: isDark ? 0.80 : 0.72);
    const pattern = <List<int>>[
      [1, 1, 0, 1, 1],
      [1, 0, 1, 0, 1],
      [0, 1, 1, 1, 0],
      [1, 0, 1, 0, 1],
      [1, 1, 0, 1, 0],
    ];
    for (var row = 0; row < grid; row++) {
      for (var col = 0; col < grid; col++) {
        if (pattern[row][col] == 1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                qrRect.left + 3 + col * cell + 0.5,
                qrRect.top + 3 + row * cell + 0.5,
                cell - 1.2,
                cell - 1.2,
              ),
              const Radius.circular(1.2),
            ),
            qrPaint,
          );
        }
      }
    }

    // Linhas discretas de informações à esquerda do QR
    final leftW = qrRect.left - padX - w * 0.07;
    final barH = (h * 0.07).clamp(4.5, 8.0);
    final softLine = Paint()..color = border;
    for (var i = 0; i < 3; i++) {
      final factor = i == 0 ? 0.90 : (i == 1 ? 0.68 : 0.78);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(padX, bodyTop + i * (barH + h * 0.065), leftW * factor, barH),
          Radius.circular(barH / 2),
        ),
        softLine,
      );
    }

    // Faixa inferior de código de leitura
    final stripTop = h * 0.74;
    final stripPaint = Paint()
      ..color = textMuted.withValues(alpha: isDark ? 0.45 : 0.34);
    final codeH = (h * 0.055).clamp(3.5, 6.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(padX, stripTop, w - padX * 2, codeH),
        Radius.circular(codeH / 2),
      ),
      stripPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(padX, stripTop + codeH + h * 0.05, (w - padX * 2) * 0.84, codeH),
        Radius.circular(codeH / 2),
      ),
      stripPaint,
    );
  }

  @override
  bool shouldRepaint(_DocumentCardWireframePainter old) =>
      old.isFront != isFront ||
      old.cardBg != cardBg ||
      old.insetBg != insetBg ||
      old.accentSoft != accentSoft ||
      old.accentInk != accentInk ||
      old.border != border ||
      old.textMuted != textMuted ||
      old.isDark != isDark;
}

/// Linha numerada com medalhão circular de acento, instrução objetiva e conector
/// vertical opcional entre etapas sequenciais.
class KycNumberedStepRow extends StatelessWidget {
  const KycNumberedStepRow({
    super.key,
    required this.stepNumber,
    required this.description,
    this.title,
    this.icon,
    this.showConnector = false,
  });

  final String stepNumber;
  final String? title;
  final String description;
  final IconData? icon;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final hasTitle = title != null && title!.trim().isNotEmpty;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tk.accentSoft,
                        Color.lerp(tk.accentSoft, tk.card, 0.30)!,
                      ],
                    ),
                    border: Border.all(
                      color: tk.accentInk.withValues(alpha: tk.isDark ? 0.34 : 0.22),
                    ),
                  ),
                  child: Center(
                    child: icon != null
                        ? Icon(icon, size: 15, color: tk.accentInk)
                        : Text(
                            stepNumber,
                            style: AppType.tabular(AppType.bodySm).copyWith(
                              color: tk.accentInk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                if (showConnector)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
                      child: Container(
                        width: 1.5,
                        color: tk.border.withValues(alpha: tk.isDark ? 0.80 : 0.90),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: showConnector ? AppSpace.s12 : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasTitle) ...[
                    Text(
                      title!,
                      style: AppType.bodyStrong.copyWith(color: tk.text),
                    ),
                    const SizedBox(height: AppSpace.s2),
                  ],
                  Text(
                    description,
                    style: AppType.bodySm.copyWith(color: tk.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:desperrengue_app/core/ui/design_system/design_system.dart';

/// Fundo editorial Porcelain com aura radial suave no topo da jornada de cadastro.
///
/// Mantém base neutra (`tk.background`) com gradiente radial translúcido em
/// [RepaintBoundary], preservando contraste WCAG 2.2 AA em temas claro e escuro,
/// tanto no Modo Cliente quanto no Modo Profissional.
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
    final peakAlpha = tk.isDark ? 0.14 : 0.07;

    return ColoredBox(
      color: tk.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -1.05),
                        radius: 1.15,
                        colors: [
                          auraColor.withValues(alpha: peakAlpha),
                          auraColor.withValues(alpha: peakAlpha * 0.35),
                          auraColor.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
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

/// Cabeçalho de progresso unificado das etapas da jornada de configuração.
///
/// Exibe selo discreto do modo ativo, contador tabular com estimativa de tempo,
/// barra segmentada animada respeitando `AppMotion.reduced` e o nome limpo da
/// etapa atual. Reflui automaticamente em `Wrap` em viewports compactos ou com
/// escala tipográfica aumentada.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (useWrap)
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
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
        const SizedBox(height: AppSpace.s12),
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
                    fillColor: fillColor,
                    trackColor: trackColor,
                    reduced: reduced,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (stepName.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpace.s8),
          Text(
            stepName,
            style: AppType.bodySm.copyWith(
              color: tk.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _ProgressSegment extends StatelessWidget {
  const _ProgressSegment({
    required this.filled,
    required this.fillColor,
    required this.trackColor,
    required this.reduced,
  });

  final bool filled;
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
        height: 6,
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

/// Bloco editorial no topo de cada etapa com emblema estilizado ou customizado,
/// título de destaque, subtítulo acolhedor e micro-selo de confiança opcional.
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
    final emblem = leadingEmblem ??
        (icon == null
            ? null
            : ExcludeSemantics(
                child: Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tk.accentSoft.withValues(alpha: tk.isDark ? 0.55 : 0.65),
                    border: Border.all(
                      color: tk.accentInk.withValues(alpha: tk.isDark ? 0.28 : 0.16),
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tk.accentSoft,
                      border: Border.all(
                        color: tk.accentInk.withValues(alpha: tk.isDark ? 0.22 : 0.12),
                      ),
                    ),
                    child: Center(
                      child: Icon(icon, size: 24, color: tk.accentInk),
                    ),
                  ),
                ),
              ));

    final titleStyle =
        (isDisplayTitle ? AppType.display : AppType.headline).copyWith(
      color: tk.text,
    );

    final badgeText = trustBadgeText?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (emblem != null) ...[
          emblem,
          const SizedBox(height: AppSpace.s16),
        ],
        Semantics(
          header: true,
          child: Text(title, style: titleStyle),
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          subtitle,
          style: AppType.bodySm.copyWith(color: tk.textMuted),
        ),
        if (badgeText.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s12),
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
        border: Border.all(
          color: fg.withValues(alpha: tk.isDark ? 0.26 : 0.16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12,
          vertical: AppSpace.s4 + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: AppSpace.s8 - 2),
            Flexible(
              child: Text(
                text,
                style: AppType.bodySm.copyWith(
                  color: fg,
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
    final stackHeader = layout.isCompact || layout.isLargeText;

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
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpace.s2),
          Text(
            subtitle!,
            style: AppType.bodySm.copyWith(color: tk.textMuted),
          ),
        ],
      ],
    );

    final leadingIcon = icon == null
        ? null
        : ExcludeSemantics(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tk.accentSoft,
                borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
              ),
              child: Icon(icon, size: 20, color: tk.accentInk),
            ),
          );

    final statusChip = hasChip
        ? AppStatusChip(chipLabel, tone: statusTone)
        : null;

    return AppCard(
      variant: AppCardVariant.elevated,
      radius: 24,
      padding: const EdgeInsets.all(AppSpace.cardLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (stackHeader) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leadingIcon != null) ...[
                  leadingIcon,
                  const SizedBox(width: AppSpace.s12),
                ],
                Expanded(child: titleBlock),
              ],
            ),
            if (statusChip != null) ...[
              const SizedBox(height: AppSpace.s8),
              statusChip,
            ],
          ] else
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
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s16),
            child: Divider(
              height: 1,
              thickness: 1,
              color: tk.border.withValues(alpha: tk.isDark ? 0.75 : 0.85),
            ),
          ),
          child,
        ],
      ),
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

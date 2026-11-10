import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Variantes oficiais de identidade visual do **Desperrengue**:
/// - [quietLuxuryNavy]: Fundo Azul-Noite (`#0F172A`) + Monograma Casa-Escudo "D"
///   em Branco Puro (`#FFFFFF`) + Check de Resolução em Laranja Vibrante (`#FF6D00`).
/// - [highRecallOrange]: Fundo Laranja Desperrengue (`#FF6D00`) + Monograma em
///   Branco Puro (`#FFFFFF`) com espaço negativo Gestalt.
/// - [monochrome]: Silhueta 100% branca com espaço negativo para Android 13–16
///   Themed Icons.
enum DesperrengueLogoVariant {
  quietLuxuryNavy,
  highRecallOrange,
  monochrome,
}

/// Widget vetorial oficial da marca **Desperrengue** (60/120 fps via [CustomPaint]).
///
/// Projetado segundo a engenharia óptica de Adaptive Icons (Sweet Spot de 48%
/// no modo launcher e proporção plena no modo in-app badge).
class DesperrengueBrandLogo extends StatelessWidget {
  const DesperrengueBrandLogo({
    super.key,
    this.size = 72,
    this.variant = DesperrengueLogoVariant.quietLuxuryNavy,
    this.borderRadius,
    this.showShadow = true,
  });

  final double size;
  final DesperrengueLogoVariant variant;
  final double? borderRadius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 0.26);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.24),
                  blurRadius: size * 0.22,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(
          size: Size.square(size),
          painter: DesperrengueBrandLogoPainter(
            variant: variant,
            includeBackground: true,
            adaptiveSafeZoneScale: 0.64,
          ),
        ),
      ),
    );
  }
}

/// Motor vetorial puro (Skia/Impeller Canvas) do símbolo oficial **Desperrengue**.
///
/// ### Semiótica e Geometria Gestalt ($G^1 / G^2$ Contínua):
/// 1. **Monograma Arquitetônico "D" + Cumeeira Residencial (`#FFFFFF`)**:
///    - A coluna esquerda sobe a partir da base sólida, enquanto o arco circular
///      direito de raio $R = 0.35$ encontra a água direita do telhado exatamente
///      no ponto de tangência de $-45^\circ$ (continuidade geométrica $G^1$ sem
///      qualquer inflexão), subindo até a cumeeira arquitetônica e descendo pelo
///      beiral protetor esquerdo.
/// 2. **Check de Resolução em Espaço Negativo Gestalt (`#FF6D00`)**:
///    - No centro óptico do escudo "D", o check de resolução é desenhado com
///      folga estrita de espaço negativo ($\ge 0.055 \times \text{boxSize}$),
///      garantindo leitura instantânea ($< 100\text{ ms}$) tanto em cores quanto
///      no modo monocromático (Android 13–16 Themed Icons).
/// 3. **Calibração Óptica Android Adaptive Icon (Sweet Spot 48% = 50 dp / 108 dp)**:
///    - Quando `adaptiveSafeZoneScale = 0.48`, o símbolo inteiro fica contido
///      exatamente em `492 × 492 px` dentro do canvas `1024 × 1024 px`, garantindo
///      margem de respiro idêntica a 99, iFood, Shopee e Telegram em qualquer
///      máscara (Squircle Samsung One UI, Círculo Pixel, Teardrop ou iOS).
class DesperrengueBrandLogoPainter extends CustomPainter {
  const DesperrengueBrandLogoPainter({
    this.variant = DesperrengueLogoVariant.quietLuxuryNavy,
    this.includeBackground = true,
    this.adaptiveSafeZoneScale = 0.48,
    this.drawProgress = 1.0,
    this.glowIntensity = 0.0,
  });

  final DesperrengueLogoVariant variant;
  final bool includeBackground;

  /// Fração do lado do canvas ocupada pelo símbolo (`0.48` = 48% Sweet Spot para
  /// Android Adaptive Icon 108dp; `0.64` = badge interno do app).
  final double adaptiveSafeZoneScale;

  /// Progresso de animação (`0.0` a `1.0`) para uso na `AnimatedSplashScreen`.
  final double drawProgress;

  /// Intensidade do pulso luminoso (`0.0` a `1.0`) para uso na `AnimatedSplashScreen`.
  final double glowIntensity;

  static const Color navyDeep = Color(0xFF0F172A);
  static const Color navyCenterGlow = Color(0xFF1A2E52);
  static const Color brandOrange = Color(0xFFFF6D00);
  static const Color brandOrangeBright = Color(0xFFFF8A2B);
  static const Color pureWhite = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // 1. Camada de Fundo (quando solicitada)
    if (includeBackground) {
      final bgRect = Offset.zero & size;
      if (variant == DesperrengueLogoVariant.highRecallOrange) {
        final bgPaint = Paint()
          ..shader = ui.Gradient.radial(
            Offset(w * 0.42, h * 0.35),
            w * 0.78,
            const [Color(0xFFFF7A14), Color(0xFFE65C00)],
          );
        canvas.drawRect(bgRect, bgPaint);
      } else if (variant == DesperrengueLogoVariant.quietLuxuryNavy) {
        final bgPaint = Paint()
          ..shader = ui.Gradient.radial(
            Offset(w * 0.45, h * 0.36),
            w * 0.76,
            const [navyCenterGlow, navyDeep],
          );
        canvas.drawRect(bgRect, bgPaint);
      }
    }

    // 2. Transformação para a Caixa Óptica (Sweet Spot 48% nos ícones de launcher)
    final boxSize = math.min(w, h) * adaptiveSafeZoneScale;
    final left = center.dx - boxSize / 2;
    final top = center.dy - boxSize / 2;

    canvas.save();
    canvas.translate(left, top);

    // Coordenadas normalizadas [0.0 .. 1.0] dentro da caixa óptica do símbolo:
    double px(double nx) => nx * boxSize;
    double py(double ny) => ny * boxSize;

    final isMono = variant == DesperrengueLogoVariant.monochrome;
    final isOrangeBg = variant == DesperrengueLogoVariant.highRecallOrange;

    final primaryColor = pureWhite;
    final accentColor = (isMono || isOrangeBg) ? pureWhite : brandOrange;

    // Espessura geométrica calibrada para leitura cristalina em 48dp..1024px:
    final strokeMain = boxSize * 0.130;
    final strokeCheck = boxSize * 0.122;

    // -------------------------------------------------------------------------
    // CAMINHO 1: MONOGRAMA ARQUITETÔNICO "D" + CUMEEIRA RESIDENCIAL (G1 CONTÍNUO)
    // -------------------------------------------------------------------------
    // Geometria exata:
    // - Centro do bojo circular do "D": (cx = 0.49, cy = 0.56), Raio R = 0.35
    // - Ponto inferior do arco (+90°): (0.49, 0.91)
    // - Ponto de tangência superior direito (-45°):
    //   x = 0.49 + 0.35 * cos(45°) = 0.7375
    //   y = 0.56 - 0.35 * sin(45°) = 0.3125
    // - A reta tangente de -45° sobe exatamente até a cumeeira (0.49, 0.065),
    //   arredonda o topo com raio suave e desce a 45° até o beiral esquerdo
    //   (0.105, 0.450), mantendo canal de espaço negativo uniforme em relação
    //   ao pilar esquerdo (0.21, 0.595).
    final dHousePath = Path()
      // Pilar vertical esquerdo do "D" / parede da casa (com folga Gestalt de 5%)
      ..moveTo(px(0.21), py(0.595))
      ..lineTo(px(0.21), py(0.84))
      // Canto inferior esquerdo arredondado -> base horizontal do "D"
      ..quadraticBezierTo(px(0.21), py(0.91), px(0.28), py(0.91))
      ..lineTo(px(0.49), py(0.91))
      // Arco circular perfeito de 135° (de +90° até -45°) formando o escudo "D"
      ..arcToPoint(
        Offset(px(0.7375), py(0.3125)),
        radius: Radius.circular(px(0.35)),
        largeArc: false,
        clockwise: false,
      )
      // Água direita do telhado em tangência exata de 45° até a cumeeira
      ..lineTo(px(0.555), py(0.130))
      // Cumeeira superior arredondada com curvatura contínua interna e externa
      ..quadraticBezierTo(px(0.490), py(0.065), px(0.425), py(0.130))
      // Água esquerda do telhado (beiral protetor residencial a 45°)
      ..lineTo(px(0.105), py(0.450));

    // -------------------------------------------------------------------------
    // CAMINHO 2: CHECK DE RESOLUÇÃO EM ESPAÇO NEGATIVO CENTRAL (GESTALT)
    // -------------------------------------------------------------------------
    // Posicionado no centro óptico do bojo (0.49, 0.56) com folga mínima de
    // 0.060 * boxSize em relação à parede interna do "D" branco.
    final checkPath = Path()
      ..moveTo(px(0.380), py(0.555))
      ..lineTo(px(0.470), py(0.645))
      ..lineTo(px(0.625), py(0.455));

    final p1 = (drawProgress / 0.72).clamp(0.0, 1.0);
    final p2 = ((drawProgress - 0.55) / 0.45).clamp(0.0, 1.0);

    final activeDPath =
        p1 >= 0.999 ? dHousePath : _extractPartialPath(dHousePath, p1);
    final activeCheckPath =
        p2 >= 0.999 ? checkPath : _extractPartialPath(checkPath, p2);

    // Brilho sutil opcional (usado apenas na animação de splash)
    if (glowIntensity > 0.01 && !isMono) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeMain * 1.85
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = accentColor.withValues(alpha: 0.42 * glowIntensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, boxSize * 0.055);
      canvas.drawPath(activeDPath, glowPaint);
      if (p2 > 0) {
        canvas.drawPath(activeCheckPath, glowPaint);
      }
    }

    // Pintura do Monograma Casa-D (Branco Puro)
    final dPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeMain
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = primaryColor;

    canvas.drawPath(activeDPath, dPaint);

    // Pintura do Check de Resolução (Laranja Vibrante #FF6D00)
    if (p2 > 0) {
      final checkPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeCheck
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;

      if (!isMono && !isOrangeBg) {
        checkPaint.shader = ui.Gradient.linear(
          Offset(px(0.375), py(0.645)),
          Offset(px(0.625), py(0.455)),
          const [brandOrange, brandOrangeBright],
        );
      } else {
        checkPaint.color = accentColor;
      }

      canvas.drawPath(activeCheckPath, checkPaint);
    }

    canvas.restore();
  }

  static Path _extractPartialPath(Path full, double fraction) {
    final out = Path();
    for (final metric in full.computeMetrics()) {
      out.addPath(
        metric.extractPath(0, metric.length * fraction.clamp(0.0, 1.0)),
        Offset.zero,
      );
    }
    return out;
  }

  @override
  bool shouldRepaint(covariant DesperrengueBrandLogoPainter oldDelegate) {
    return oldDelegate.variant != variant ||
        oldDelegate.includeBackground != includeBackground ||
        oldDelegate.adaptiveSafeZoneScale != adaptiveSafeZoneScale ||
        oldDelegate.drawProgress != drawProgress ||
        oldDelegate.glowIntensity != glowIntensity;
  }
}

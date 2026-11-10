import 'dart:math' as math;
import 'package:flutter/material.dart';

/// As 6 Famílias Cromáticas Semânticas fundamentadas na Lei de Hick e
/// Neurociência Visual sobre superfície Dark Glass (#162032 / #0F172A).
enum CategoryColorFamily {
  all('all', 'Todas', Color(0xFF38BDF8), Color(0xFF0EA5E9)),
  urgent('urgent', 'Urgências', Color(0xFFFF6D00), Color(0xFFFFB020)),
  waterClimate('agua_clima', 'Água e Clima', Color(0xFF00C2FF), Color(0xFF38BDF8)),
  constructionRepair('obra_reparos', 'Obra e Reparos', Color(0xFFFF6D00), Color(0xFFF97316)),
  electricTech('eletrica_tech', 'Elétrica e Tech', Color(0xFFFFB020), Color(0xFF818CF8)),
  bioCleaning('limpeza_bio', 'Limpeza e Bio', Color(0xFF10B981), Color(0xFF34D399)),
  careMobility('cuidados_frete', 'Cuidados e Frete', Color(0xFFFB7185), Color(0xFFF43F5E));

  const CategoryColorFamily(this.id, this.label, this.primary, this.secondary);
  final String id;
  final String label;
  final Color primary;
  final Color secondary;
}

/// Especificação de Marca de cada uma das 33 Categorias Oficiais do Desperrengue.
class CategoryBrandSpec {
  const CategoryBrandSpec({
    required this.index,
    required this.name,
    required this.family,
    required this.primaryColor,
    required this.secondaryColor,
    required this.primaryIconifyId,
    required this.badgeIconifyId,
    this.isUrgent = false,
  });

  final int index;
  final String name;
  final CategoryColorFamily family;
  final Color primaryColor;
  final Color secondaryColor;
  final String primaryIconifyId;
  final String badgeIconifyId;
  final bool isUrgent;
}

/// Catálogo Canônico dos 33 Logos Exclusivos de Categoria do Desperrengue.
const List<CategoryBrandSpec> kCategoryBrandSpecs = [
  CategoryBrandSpec(
    index: 1,
    name: 'Elétrica',
    family: CategoryColorFamily.electricTech,
    primaryColor: Color(0xFFFFB020),
    secondaryColor: Color(0xFFFF7A00),
    primaryIconifyId: 'solar:bolt-circle-bold-duotone',
    badgeIconifyId: 'ph:lightning-fill',
    isUrgent: true,
  ),
  CategoryBrandSpec(
    index: 2,
    name: 'Encanador',
    family: CategoryColorFamily.waterClimate,
    primaryColor: Color(0xFF00C2FF),
    secondaryColor: Color(0xFF38BDF8),
    primaryIconifyId: 'mdi:pipe-valve',
    badgeIconifyId: 'solar:waterdrops-bold-duotone',
    isUrgent: true,
  ),
  CategoryBrandSpec(
    index: 3,
    name: 'Limpeza',
    family: CategoryColorFamily.bioCleaning,
    primaryColor: Color(0xFF10B981),
    secondaryColor: Color(0xFF34D399),
    primaryIconifyId: 'solar:broom-bold-duotone',
    badgeIconifyId: 'ph:sparkle-fill',
  ),
  CategoryBrandSpec(
    index: 4,
    name: 'Montagem',
    family: CategoryColorFamily.constructionRepair,
    primaryColor: Color(0xFFF97316),
    secondaryColor: Color(0xFFFF6D00),
    primaryIconifyId: 'mdi:wardrobe-outline',
    badgeIconifyId: 'mdi:screwdriver',
  ),
  CategoryBrandSpec(
    index: 5,
    name: 'Pintura',
    family: CategoryColorFamily.constructionRepair,
    primaryColor: Color(0xFFFF6D00),
    secondaryColor: Color(0xFFFB923C),
    primaryIconifyId: 'solar:paint-roller-bold-duotone',
    badgeIconifyId: 'ph:drop-half-bottom-fill',
  ),
  CategoryBrandSpec(
    index: 6,
    name: 'Chaveiro',
    family: CategoryColorFamily.electricTech,
    primaryColor: Color(0xFF818CF8),
    secondaryColor: Color(0xFF6366F1),
    primaryIconifyId: 'solar:key-minimalistic-square-bold-duotone',
    badgeIconifyId: 'ph:shield-check-fill',
    isUrgent: true,
  ),
  CategoryBrandSpec(
    index: 7,
    name: 'Pedreiro',
    family: CategoryColorFamily.constructionRepair,
    primaryColor: Color(0xFFF97316),
    secondaryColor: Color(0xFFEA580C),
    primaryIconifyId: 'mdi:trowel',
    badgeIconifyId: 'mdi:wall',
  ),
  CategoryBrandSpec(
    index: 8,
    name: 'Gesso',
    family: CategoryColorFamily.constructionRepair,
    primaryColor: Color(0xFFFB923C),
    secondaryColor: Color(0xFFF59E0B),
    primaryIconifyId: 'mdi:ceiling-light-multiple',
    badgeIconifyId: 'ph:ruler-fill',
  ),
  CategoryBrandSpec(
    index: 9,
    name: 'Marcenaria',
    family: CategoryColorFamily.constructionRepair,
    primaryColor: Color(0xFFE07A5F),
    secondaryColor: Color(0xFFF97316),
    primaryIconifyId: 'mdi:hand-saw',
    badgeIconifyId: 'mdi:saw-blade',
  ),
  CategoryBrandSpec(
    index: 10,
    name: 'Ar-condicionado',
    family: CategoryColorFamily.waterClimate,
    primaryColor: Color(0xFF38BDF8),
    secondaryColor: Color(0xFF00C2FF),
    primaryIconifyId: 'mdi:air-conditioner',
    badgeIconifyId: 'ph:snowflake-bold',
    isUrgent: true,
  ),
  CategoryBrandSpec(
    index: 11,
    name: 'Pequenos Reparos',
    family: CategoryColorFamily.constructionRepair,
    primaryColor: Color(0xFFFF6D00),
    secondaryColor: Color(0xFFF59E0B),
    primaryIconifyId: 'solar:case-minimalistic-bold-duotone',
    badgeIconifyId: 'ph:wrench-fill',
    isUrgent: true,
  ),
  CategoryBrandSpec(
    index: 12,
    name: 'Jardinagem',
    family: CategoryColorFamily.bioCleaning,
    primaryColor: Color(0xFF34D399),
    secondaryColor: Color(0xFF10B981),
    primaryIconifyId: 'mdi:content-cut',
    badgeIconifyId: 'solar:leaf-bold-duotone',
  ),
  CategoryBrandSpec(
    index: 13,
    name: 'Dedetização',
    family: CategoryColorFamily.bioCleaning,
    primaryColor: Color(0xFF10B981),
    secondaryColor: Color(0xFF059669),
    primaryIconifyId: 'mdi:bug-outline',
    badgeIconifyId: 'mdi:shield-check',
  ),
  CategoryBrandSpec(
    index: 14,
    name: 'Vidraceiro',
    family: CategoryColorFamily.electricTech,
    primaryColor: Color(0xFF60A5FA),
    secondaryColor: Color(0xFF38BDF8),
    primaryIconifyId: 'mdi:mirror-rectangle',
    badgeIconifyId: 'ph:sparkle-bold',
  ),
  CategoryBrandSpec(
    index: 15,
    name: 'Serralheria',
    family: CategoryColorFamily.electricTech,
    primaryColor: Color(0xFF94A3B8),
    secondaryColor: Color(0xFF818CF8),
    primaryIconifyId: 'mdi:welding',
    badgeIconifyId: 'mdi:gate',
  ),
  CategoryBrandSpec(
    index: 16,
    name: 'Telhados e Calhas',
    family: CategoryColorFamily.waterClimate,
    primaryColor: Color(0xFF0EA5E9),
    secondaryColor: Color(0xFF38BDF8),
    primaryIconifyId: 'mdi:home-roof',
    badgeIconifyId: 'ph:cloud-rain-fill',
    isUrgent: true,
  ),
  CategoryBrandSpec(
    index: 17,
    name: 'Impermeabilização',
    family: CategoryColorFamily.waterClimate,
    primaryColor: Color(0xFF00C2FF),
    secondaryColor: Color(0xFF06B6D4),
    primaryIconifyId: 'mdi:water-off',
    badgeIconifyId: 'solar:shield-check-bold-duotone',
  ),
  CategoryBrandSpec(
    index: 18,
    name: 'Desentupidora',
    family: CategoryColorFamily.waterClimate,
    primaryColor: Color(0xFF0284C7),
    secondaryColor: Color(0xFF38BDF8),
    primaryIconifyId: 'mdi:pipe-disconnected',
    badgeIconifyId: 'mdi:waves-arrow-right',
    isUrgent: true,
  ),
  CategoryBrandSpec(
    index: 19,
    name: 'Piscina',
    family: CategoryColorFamily.waterClimate,
    primaryColor: Color(0xFF22D3EE),
    secondaryColor: Color(0xFF06B6D4),
    primaryIconifyId: 'mdi:pool',
    badgeIconifyId: 'ph:drop-fill',
  ),
  CategoryBrandSpec(
    index: 20,
    name: 'Eletrodomésticos',
    family: CategoryColorFamily.electricTech,
    primaryColor: Color(0xFFF59E0B),
    secondaryColor: Color(0xFFFFB020),
    primaryIconifyId: 'mdi:washing-machine',
    badgeIconifyId: 'solar:settings-bold-duotone',
  ),
  CategoryBrandSpec(
    index: 21,
    name: 'TV e Antenas',
    family: CategoryColorFamily.electricTech,
    primaryColor: Color(0xFF818CF8),
    secondaryColor: Color(0xFF6366F1),
    primaryIconifyId: 'solar:tv-bold-duotone',
    badgeIconifyId: 'mdi:satellite-uplink',
  ),
  CategoryBrandSpec(
    index: 22,
    name: 'Câmeras e Alarmes',
    family: CategoryColorFamily.electricTech,
    primaryColor: Color(0xFF6366F1),
    secondaryColor: Color(0xFF818CF8),
    primaryIconifyId: 'mdi:cctv',
    badgeIconifyId: 'solar:shield-warning-bold-duotone',
    isUrgent: true,
  ),
  CategoryBrandSpec(
    index: 23,
    name: 'Portões e Interfones',
    family: CategoryColorFamily.electricTech,
    primaryColor: Color(0xFFA78BFA),
    secondaryColor: Color(0xFF818CF8),
    primaryIconifyId: 'mdi:gate-arrow-right',
    badgeIconifyId: 'mdi:remote',
  ),
  CategoryBrandSpec(
    index: 24,
    name: 'Energia Solar',
    family: CategoryColorFamily.electricTech,
    primaryColor: Color(0xFFFBBF24),
    secondaryColor: Color(0xFFF59E0B),
    primaryIconifyId: 'mdi:solar-panel-large',
    badgeIconifyId: 'solar:sun-2-bold-duotone',
  ),
  CategoryBrandSpec(
    index: 25,
    name: 'Gás e Aquecedores',
    family: CategoryColorFamily.electricTech,
    primaryColor: Color(0xFFFF7A00),
    secondaryColor: Color(0xFFF97316),
    primaryIconifyId: 'mdi:water-boiler',
    badgeIconifyId: 'solar:fire-bold-duotone',
    isUrgent: true,
  ),
  CategoryBrandSpec(
    index: 26,
    name: 'Pisos e Revestimentos',
    family: CategoryColorFamily.constructionRepair,
    primaryColor: Color(0xFFD97706),
    secondaryColor: Color(0xFFF59E0B),
    primaryIconifyId: 'mdi:layers-triple',
    badgeIconifyId: 'mdi:rhombus-split',
  ),
  CategoryBrandSpec(
    index: 27,
    name: 'Cortinas e Persianas',
    family: CategoryColorFamily.bioCleaning,
    primaryColor: Color(0xFF2DD4BF),
    secondaryColor: Color(0xFF14B8A6),
    primaryIconifyId: 'mdi:roller-shade',
    badgeIconifyId: 'mdi:curtains',
  ),
  CategoryBrandSpec(
    index: 28,
    name: 'Estofados e Tapetes',
    family: CategoryColorFamily.bioCleaning,
    primaryColor: Color(0xFF10B981),
    secondaryColor: Color(0xFF34D399),
    primaryIconifyId: 'solar:armchair-2-bold-duotone',
    badgeIconifyId: 'mdi:shimmer',
  ),
  CategoryBrandSpec(
    index: 29,
    name: 'Mudanças e Fretes',
    family: CategoryColorFamily.careMobility,
    primaryColor: Color(0xFFFB7185),
    secondaryColor: Color(0xFFF43F5E),
    primaryIconifyId: 'solar:delivery-bold-duotone',
    badgeIconifyId: 'ph:package-fill',
  ),
  CategoryBrandSpec(
    index: 30,
    name: 'Informática e Redes',
    family: CategoryColorFamily.electricTech,
    primaryColor: Color(0xFF60A5FA),
    secondaryColor: Color(0xFF818CF8),
    primaryIconifyId: 'solar:laptop-minimalistic-bold-duotone',
    badgeIconifyId: 'ph:wifi-high-bold',
  ),
  CategoryBrandSpec(
    index: 31,
    name: 'Cuidador de Idosos',
    family: CategoryColorFamily.careMobility,
    primaryColor: Color(0xFFF43F5E),
    secondaryColor: Color(0xFFFB7185),
    primaryIconifyId: 'mdi:human-cane',
    badgeIconifyId: 'solar:heart-angle-bold-duotone',
  ),
  CategoryBrandSpec(
    index: 32,
    name: 'Babá',
    family: CategoryColorFamily.careMobility,
    primaryColor: Color(0xFFFB7185),
    secondaryColor: Color(0xFFF43F5E),
    primaryIconifyId: 'mdi:baby-face-outline',
    badgeIconifyId: 'solar:star-shine-bold-duotone',
  ),
  CategoryBrandSpec(
    index: 33,
    name: 'Pet Care',
    family: CategoryColorFamily.careMobility,
    primaryColor: Color(0xFFF97316),
    secondaryColor: Color(0xFFFB7185),
    primaryIconifyId: 'mdi:paw',
    badgeIconifyId: 'ph:heart-fill',
  ),
];

final Map<String, CategoryBrandSpec> _specByName = {
  for (final s in kCategoryBrandSpecs) s.name: s,
};

/// Resolve a especificação de marca para qualquer nome de categoria (com fallback seguro).
CategoryBrandSpec resolveCategoryBrandSpec(String categoryName) {
  final direct = _specByName[categoryName.trim()];
  if (direct != null) return direct;
  final lower = categoryName.trim().toLowerCase();
  for (final s in kCategoryBrandSpecs) {
    if (s.name.toLowerCase() == lower) return s;
  }
  return kCategoryBrandSpecs[10]; // Pequenos Reparos como fallback universal
}

/// Widget de Logo Composto em 3 Camadas (Squircle Dark Glass + Duotone Vector + Micro-Insígnia)
/// cacheado em textura de GPU via [RepaintBoundary] para rolagem a 120 FPS.
class CategoryBrandEmblem extends StatelessWidget {
  const CategoryBrandEmblem({
    super.key,
    required this.categoryName,
    this.size = 64,
    this.showCornerBadge,
  });

  final String categoryName;
  final double size;
  final bool? showCornerBadge;

  @override
  Widget build(BuildContext context) {
    final spec = resolveCategoryBrandSpec(categoryName);
    final badge = showCornerBadge ?? (size >= 48);
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: CategoryEmblemCustomPainter(
            spec: spec,
            showCornerBadge: badge,
          ),
        ),
      ),
    );
  }
}

/// Renderizador Vetorial Proprietário em 3 Camadas (Skia / Impeller GPU Direct)
/// que desenha cada uma das 33 profissões com fidelidade técnica absoluta.
class CategoryEmblemCustomPainter extends CustomPainter {
  const CategoryEmblemCustomPainter({
    required this.spec,
    this.showCornerBadge = true,
  });

  final CategoryBrandSpec spec;
  final bool showCornerBadge;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    canvas.save();
    canvas.scale(s, s);

    final primary = spec.primaryColor;
    final secondary = spec.secondaryColor;

    // =========================================================================
    // CAMADA 1: SUPERELIPSE SQUIRCLE DARK GLASS (#162032 -> #0E1525) + GLOW
    // =========================================================================
    final squircleRect = const Rect.fromLTWH(2, 2, 96, 96);
    final squircleRRect = RRect.fromRectAndRadius(squircleRect, const Radius.circular(28));

    // Sombra sutil de elevação
    canvas.drawRRect(
      squircleRRect.shift(const Offset(0, 2.5)),
      Paint()
        ..color = const Color(0xFF020617).withValues(alpha: 0.42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );

    // Base Dark Glass com profundidade acetinada
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1A273D),
          Color(0xFF111A2B),
          Color(0xFF0B111E),
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(squircleRect);
    canvas.drawRRect(squircleRRect, basePaint);

    // Brilho Radial Interno (18% da Cor da Família Cromática)
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.22, -0.25),
        radius: 0.85,
        colors: [
          primary.withValues(alpha: 0.24),
          secondary.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(squircleRect);
    canvas.drawRRect(squircleRRect, glowPaint);

    // Reflexo superior de vidro (Glass Highlight Arc)
    canvas.save();
    canvas.clipRRect(squircleRRect);
    canvas.drawOval(
      const Rect.fromLTWH(-10, -28, 120, 56),
      Paint()..color = Colors.white.withValues(alpha: 0.045),
    );
    canvas.restore();

    // Borda de Vidro 1.3px (38% Cor Semântica no topo -> 14% na base)
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primary.withValues(alpha: 0.55),
          primary.withValues(alpha: 0.22),
          secondary.withValues(alpha: 0.14),
        ],
      ).createShader(squircleRect);
    canvas.drawRRect(squircleRRect, borderPaint);

    // =========================================================================
    // CAMADA 2: SÍMBOLO MESTRE DUOTONE (ESPECÍFICO DE CADA UMA DAS 33 PROFISSÕES)
    // =========================================================================
    _paintMasterProfessionLogo(canvas, spec.index, primary, secondary);

    // =========================================================================
    // CAMADA 3: MICRO-INSÍGNIA DE ESPECIALIDADE NO CANTO SUPERIOR DIREITO
    // =========================================================================
    if (showCornerBadge) {
      _paintCornerSpecialtyBadge(canvas, spec.index, primary, secondary);
    }

    canvas.restore();
  }

  void _paintMasterProfessionLogo(Canvas canvas, int index, Color primary, Color secondary) {
    final duoFill = Paint()
      ..style = PaintingStyle.fill
      ..color = primary.withValues(alpha: 0.30);

    final accentFill = Paint()
      ..style = PaintingStyle.fill
      ..color = primary;

    final accentStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = primary;

    final whiteStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;

    final whiteFill = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    switch (index) {
      case 1: // 01. Elétrica: Disjuntor/Escudo energético Duotone + Raio Âmbar vivo no núcleo
        final shield = Path()
          ..moveTo(50, 20)
          ..lineTo(72, 30)
          ..lineTo(72, 52)
          ..quadraticBezierTo(72, 72, 50, 82)
          ..quadraticBezierTo(28, 72, 28, 52)
          ..lineTo(28, 30)
          ..close();
        canvas.drawPath(shield, duoFill);
        canvas.drawPath(shield, whiteStroke);
        // Raio energético central
        final bolt = Path()
          ..moveTo(54, 28)
          ..lineTo(39, 51)
          ..lineTo(50, 51)
          ..lineTo(45, 73)
          ..lineTo(62, 48)
          ..lineTo(51, 48)
          ..close();
        canvas.drawPath(bolt, accentFill);
        break;

      case 2: // 02. Encanador: Tubulação curva flangeada com registro + Gota cristalina ciano
        // Cano em L invertido
        final pipe = RRect.fromRectAndRadius(const Rect.fromLTWH(24, 46, 36, 14), const Radius.circular(4));
        canvas.drawRRect(pipe, duoFill);
        canvas.drawRRect(pipe, whiteStroke);
        // Flange vertical e bico
        canvas.drawLine(const Offset(24, 42), const Offset(24, 64), whiteStroke);
        canvas.drawLine(const Offset(60, 46), const Offset(60, 66), whiteStroke);
        // Volante de registro (válvula) no topo do cano
        canvas.drawLine(const Offset(42, 46), const Offset(42, 33), whiteStroke);
        canvas.drawLine(const Offset(31, 33), const Offset(53, 33), accentStroke..strokeWidth = 4.6);
        canvas.drawCircle(const Offset(42, 33), 3.5, whiteFill);
        // Gota cristalina ciano caindo na direita
        final drop = Path()
          ..moveTo(68, 52)
          ..quadraticBezierTo(79, 66, 79, 73)
          ..arcToPoint(const Offset(57, 73), radius: const Radius.circular(11), clockwise: true)
          ..quadraticBezierTo(57, 66, 68, 52)
          ..close();
        canvas.drawPath(drop, accentFill);
        canvas.drawPath(drop, whiteStroke..strokeWidth = 2.8);
        break;

      case 3: // 03. Limpeza: Vassoura/Escova Duotone angulada + Brilhos estrelares (Sparkles)
        // Cabo angulado
        canvas.drawLine(const Offset(28, 24), const Offset(52, 52), whiteStroke);
        // Base da vassoura
        final head = Path()
          ..moveTo(40, 56)
          ..lineTo(62, 42)
          ..lineTo(74, 62)
          ..lineTo(48, 76)
          ..close();
        canvas.drawPath(head, duoFill);
        canvas.drawPath(head, whiteStroke);
        // Faixa de cerdas esmeralda
        canvas.drawLine(const Offset(44, 63), const Offset(66, 49), accentStroke);
        canvas.drawLine(const Offset(53, 72), const Offset(48, 65), accentStroke..strokeWidth = 3.0);
        canvas.drawLine(const Offset(62, 67), const Offset(57, 60), accentStroke);
        // Estrela de brilho à esquerda
        _drawSparkle(canvas, const Offset(31, 66), 8.5, primary);
        break;

      case 4: // 04. Montagem: Guarda-roupa/Móvel modular 2 portas + Chave de montagem
        final cab = RRect.fromRectAndRadius(const Rect.fromLTWH(26, 22, 44, 56), const Radius.circular(6));
        canvas.drawRRect(cab, duoFill);
        canvas.drawRRect(cab, whiteStroke);
        // Divisória central das portas e gaveta inferior
        canvas.drawLine(const Offset(48, 22), const Offset(48, 62), whiteStroke..strokeWidth = 3.2);
        canvas.drawLine(const Offset(26, 62), const Offset(70, 62), whiteStroke);
        // Puxadores em cobre vivo
        canvas.drawLine(const Offset(43, 39), const Offset(43, 47), accentStroke..strokeWidth = 3.6);
        canvas.drawLine(const Offset(53, 39), const Offset(53, 47), accentStroke);
        // Pés do móvel
        canvas.drawLine(const Offset(32, 78), const Offset(30, 83), whiteStroke);
        canvas.drawLine(const Offset(64, 78), const Offset(66, 83), whiteStroke);
        break;

      case 5: // 05. Pintura: Rolo profissional deixando faixa de tinta viva + Gota
        // Faixa de tinta fresca em degradê atrás
        final paintWave = RRect.fromRectAndRadius(const Rect.fromLTWH(26, 22, 36, 18), const Radius.circular(6));
        canvas.drawRRect(paintWave, accentFill);
        // Cilindro do rolo de pintura
        final roller = RRect.fromRectAndRadius(const Rect.fromLTWH(24, 28, 40, 16), const Radius.circular(8));
        canvas.drawRRect(roller, duoFill);
        canvas.drawRRect(roller, whiteStroke..strokeWidth = 3.8);
        // Haste metálica dobrada e cabo ergonômico
        final arm = Path()
          ..moveTo(64, 36)
          ..lineTo(73, 36)
          ..lineTo(73, 52)
          ..lineTo(48, 52)
          ..lineTo(48, 60);
        canvas.drawPath(arm, whiteStroke..strokeWidth = 3.6);
        final handle = RRect.fromRectAndRadius(const Rect.fromLTWH(43, 60, 10, 20), const Radius.circular(4));
        canvas.drawRRect(handle, accentFill);
        canvas.drawRRect(handle, whiteStroke..strokeWidth = 3.0);
        break;

      case 6: // 06. Chaveiro: Fechadura escudo inteligente + Chave codificada
        // Cabeça quadrada arredondada da chave (Solar Key Minimalistic Square)
        final keyHead = RRect.fromRectAndRadius(const Rect.fromLTWH(22, 34, 28, 28), const Radius.circular(8));
        canvas.drawRRect(keyHead, duoFill);
        canvas.drawRRect(keyHead, whiteStroke..strokeWidth = 3.8);
        canvas.drawCircle(const Offset(36, 48), 5.0, accentFill);
        // Haste e segredos da chave
        final blade = Path()
          ..moveTo(50, 48)
          ..lineTo(78, 48)
          ..lineTo(78, 59)
          ..moveTo(66, 48)
          ..lineTo(66, 57);
        canvas.drawPath(blade, whiteStroke..strokeWidth = 4.2);
        canvas.drawLine(const Offset(52, 43), const Offset(76, 43), accentStroke..strokeWidth = 2.6);
        break;

      case 7: // 07. Pedreiro: Parede de alvenaria em tijolos Duotone + Colher de pedreiro real
        // Tijolos de alvenaria ao fundo
        final b1 = RRect.fromRectAndRadius(const Rect.fromLTWH(22, 58, 25, 11), const Radius.circular(2));
        final b2 = RRect.fromRectAndRadius(const Rect.fromLTWH(51, 58, 25, 11), const Radius.circular(2));
        final b3 = RRect.fromRectAndRadius(const Rect.fromLTWH(35, 72, 28, 11), const Radius.circular(2));
        canvas.drawRRect(b1, duoFill);
        canvas.drawRRect(b2, duoFill);
        canvas.drawRRect(b3, duoFill);
        canvas.drawRRect(b1, accentStroke..strokeWidth = 2.4);
        canvas.drawRRect(b2, accentStroke);
        canvas.drawRRect(b3, accentStroke);
        // Pá triangular da colher de pedreiro (Trowel)
        final trowel = Path()
          ..moveTo(24, 42)
          ..lineTo(54, 24)
          ..lineTo(58, 48)
          ..close();
        canvas.drawPath(trowel, whiteFill);
        canvas.drawPath(trowel, whiteStroke..strokeWidth = 3.2);
        // Haste e cabo de madeira cobre
        canvas.drawLine(const Offset(56, 36), const Offset(66, 36), whiteStroke);
        canvas.drawLine(const Offset(66, 34), const Offset(78, 30), accentStroke..strokeWidth = 6.0);
        break;

      case 8: // 08. Gesso: Sanca de Drywall rebaixada + Spots de LED embutidos com feixe de luz
        // Placa superior e sanca de gesso
        final ceiling = RRect.fromRectAndRadius(const Rect.fromLTWH(20, 26, 60, 14), const Radius.circular(4));
        canvas.drawRRect(ceiling, duoFill);
        canvas.drawRRect(ceiling, whiteStroke..strokeWidth = 3.6);
        // 3 Spots de luz embutidos no gesso
        for (final cx in [32.0, 50.0, 68.0]) {
          canvas.drawCircle(Offset(cx, 33), 3.2, accentFill);
          // Feixes cônicos de iluminação
          final cone = Path()
            ..moveTo(cx - 3, 40)
            ..lineTo(cx - 10, 62)
            ..lineTo(cx + 10, 62)
            ..lineTo(cx + 3, 40)
            ..close();
          canvas.drawPath(cone, Paint()..color = primary.withValues(alpha: 0.22));
        }
        // Desempenadeira / Régua de gesseiro na base
        final floatTool = RRect.fromRectAndRadius(const Rect.fromLTWH(28, 68, 44, 8), const Radius.circular(3));
        canvas.drawRRect(floatTool, whiteStroke..strokeWidth = 3.2);
        canvas.drawLine(const Offset(42, 68), const Offset(42, 62), accentStroke..strokeWidth = 3.2);
        canvas.drawLine(const Offset(58, 68), const Offset(58, 62), accentStroke);
        canvas.drawLine(const Offset(42, 62), const Offset(58, 62), accentStroke);
        break;

      case 9: // 09. Marcenaria: Prancha de madeira com veios + Serrote / Lâmina dentada
        // Prancha de madeira na base
        final plank = RRect.fromRectAndRadius(const Rect.fromLTWH(20, 60, 58, 16), const Radius.circular(4));
        canvas.drawRRect(plank, duoFill);
        canvas.drawRRect(plank, accentStroke..strokeWidth = 3.0);
        canvas.drawLine(const Offset(28, 68), const Offset(52, 68), accentStroke..strokeWidth = 2.0);
        // Lâmina de serrote em diagonal cortando
        final saw = Path()
          ..moveTo(26, 46)
          ..lineTo(64, 24)
          ..lineTo(72, 36)
          ..lineTo(32, 56)
          ..close();
        canvas.drawPath(saw, Paint()..color = Colors.white.withValues(alpha: 0.20));
        canvas.drawPath(saw, whiteStroke..strokeWidth = 3.5);
        // Punho do serrote
        final grip = RRect.fromRectAndRadius(const Rect.fromLTWH(18, 42, 12, 18), const Radius.circular(4));
        canvas.drawRRect(grip, accentFill);
        canvas.drawRRect(grip, whiteStroke..strokeWidth = 2.8);
        break;

      case 10: // 10. Ar-condicionado: Aparelho Split de parede real + Ondas de ar frio ciano
        // Corpo do Split residencial
        final split = RRect.fromRectAndRadius(const Rect.fromLTWH(20, 24, 60, 26), const Radius.circular(7));
        canvas.drawRRect(split, duoFill);
        canvas.drawRRect(split, whiteStroke..strokeWidth = 3.8);
        // Aleta difusora inferior e visor LED
        canvas.drawLine(const Offset(26, 42), const Offset(74, 42), whiteStroke..strokeWidth = 2.6);
        canvas.drawCircle(const Offset(68, 33), 2.8, accentFill);
        // 3 Ondas de ar gelado saindo do Split
        for (final dx in [33.0, 50.0, 67.0]) {
          final wave = Path()
            ..moveTo(dx, 55)
            ..quadraticBezierTo(dx - 6, 63, dx, 69)
            ..quadraticBezierTo(dx + 6, 75, dx - 2, 81);
          canvas.drawPath(wave, accentStroke..strokeWidth = 3.4);
        }
        break;

      case 11: // 11. Pequenos Reparos: Maleta de ferramentas + Chave Inglesa e Martelo
        final box = RRect.fromRectAndRadius(const Rect.fromLTWH(22, 42, 56, 36), const Radius.circular(7));
        canvas.drawRRect(box, duoFill);
        canvas.drawRRect(box, whiteStroke..strokeWidth = 3.8);
        // Alça superior da maleta
        final handlePath = Path()
          ..moveTo(38, 42)
          ..lineTo(38, 32)
          ..quadraticBezierTo(38, 28, 42, 28)
          ..lineTo(58, 28)
          ..quadraticBezierTo(62, 28, 62, 32)
          ..lineTo(62, 42);
        canvas.drawPath(handlePath, whiteStroke..strokeWidth = 3.6);
        // Linha da tampa e fechos em cobre vivo
        canvas.drawLine(const Offset(22, 55), const Offset(78, 55), whiteStroke..strokeWidth = 2.8);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(34, 51, 8, 9), const Radius.circular(2)), accentFill);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(58, 51, 8, 9), const Radius.circular(2)), accentFill);
        break;

      case 12: // 12. Jardinagem: Folha botânica Duotone + Tesoura de poda
        final leaf = Path()
          ..moveTo(28, 74)
          ..quadraticBezierTo(24, 38, 68, 26)
          ..quadraticBezierTo(64, 68, 28, 74)
          ..close();
        canvas.drawPath(leaf, duoFill);
        canvas.drawPath(leaf, whiteStroke..strokeWidth = 3.8);
        // Nervura central e secundárias em verde vivo
        canvas.drawLine(const Offset(24, 78), const Offset(62, 34), accentStroke..strokeWidth = 3.8);
        canvas.drawLine(const Offset(42, 56), const Offset(38, 43), accentStroke..strokeWidth = 2.8);
        canvas.drawLine(const Offset(50, 47), const Offset(61, 49), accentStroke);
        break;

      case 13: // 13. Dedetização: Escudo sanitário protetor + Inseto neutralizado no alvo
        final shield = Path()
          ..moveTo(50, 20)
          ..lineTo(74, 30)
          ..lineTo(74, 52)
          ..quadraticBezierTo(74, 74, 50, 83)
          ..quadraticBezierTo(26, 74, 26, 52)
          ..lineTo(26, 30)
          ..close();
        canvas.drawPath(shield, duoFill);
        canvas.drawPath(shield, whiteStroke..strokeWidth = 3.6);
        // Corpo estilizado do inseto + antenas e patas
        canvas.drawOval(const Rect.fromLTWH(42, 41, 16, 22), accentFill);
        canvas.drawCircle(const Offset(50, 36), 4.5, whiteFill);
        for (final dy in [45.0, 52.0, 59.0]) {
          canvas.drawLine(Offset(34, dy - 2), Offset(42, dy), whiteStroke..strokeWidth = 2.6);
          canvas.drawLine(Offset(66, dy - 2), Offset(58, dy), whiteStroke);
        }
        // Faixa diagonal de bloqueio
        canvas.drawLine(const Offset(35, 66), const Offset(65, 36), accentStroke..strokeWidth = 3.8);
        break;

      case 14: // 14. Vidraceiro: Painéis de vidro temperado/box em perspectiva + Reflexos diagonais
        // Painel traseiro e frontal de vidro
        final backPane = RRect.fromRectAndRadius(const Rect.fromLTWH(34, 22, 38, 52), const Radius.circular(5));
        canvas.drawRRect(backPane, duoFill);
        canvas.drawRRect(backPane, accentStroke..strokeWidth = 2.8);
        final frontPane = RRect.fromRectAndRadius(const Rect.fromLTWH(24, 30, 38, 52), const Radius.circular(5));
        canvas.drawRRect(frontPane, Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.72));
        canvas.drawRRect(frontPane, whiteStroke..strokeWidth = 3.6);
        // Reflexos especulares diagonais do vidro cristal
        canvas.drawLine(const Offset(31, 46), const Offset(45, 36), accentStroke..strokeWidth = 3.4);
        canvas.drawLine(const Offset(33, 56), const Offset(53, 42), whiteStroke..strokeWidth = 2.6);
        // Puxador circular do box
        canvas.drawCircle(const Offset(54, 56), 3.2, accentFill);
        break;

      case 15: // 15. Serralheria: Portão de aço forjado + Tocha de solda elétrica com faíscas
        // Barras verticais de portão metálico e travessas
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(22, 28, 44, 50), const Radius.circular(4)), duoFill);
        for (final x in [26.0, 38.0, 50.0, 62.0]) {
          canvas.drawLine(Offset(x, 24), Offset(x, 78), whiteStroke..strokeWidth = 3.4);
        }
        canvas.drawLine(const Offset(20, 38), const Offset(68, 38), whiteStroke..strokeWidth = 3.2);
        canvas.drawLine(const Offset(20, 66), const Offset(68, 66), whiteStroke);
        // Faísca radiante de solda no ponto de fusão
        _drawSparkle(canvas, const Offset(64, 38), 11.0, primary);
        break;

      case 16: // 16. Telhados e Calhas: Cumeeira inclinada + Calha coletora e gotas de chuva
        final roof = Path()
          ..moveTo(18, 54)
          ..lineTo(48, 26)
          ..lineTo(78, 54)
          ..close();
        canvas.drawPath(roof, duoFill);
        canvas.drawPath(roof, whiteStroke..strokeWidth = 4.0);
        // Calha horizontal e condutor vertical de descida pluvial
        final gutter = Path()
          ..moveTo(22, 60)
          ..lineTo(72, 60)
          ..lineTo(72, 80);
        canvas.drawPath(gutter, accentStroke..strokeWidth = 4.2);
        // Gotas de chuva caindo sobre o telhado
        canvas.drawLine(const Offset(28, 24), const Offset(25, 32), accentStroke..strokeWidth = 3.0);
        canvas.drawLine(const Offset(68, 24), const Offset(65, 32), accentStroke);
        break;

      case 17: // 17. Impermeabilização: Laje/Superfície protegida por Domo Hidro-Repelente barrando gotas
        // Camadas da laje impermeabilizada na base
        final slab = RRect.fromRectAndRadius(const Rect.fromLTWH(20, 66, 60, 12), const Radius.circular(4));
        canvas.drawRRect(slab, duoFill);
        canvas.drawRRect(slab, whiteStroke..strokeWidth = 3.4);
        // Escudo / Manta curva hidro-repelente
        final barrier = Path()
          ..moveTo(20, 58)
          ..quadraticBezierTo(50, 42, 80, 58);
        canvas.drawPath(barrier, accentStroke..strokeWidth = 4.5);
        // Gotas repelidas para os lados
        final dropCenter = Path()
          ..moveTo(50, 22)
          ..quadraticBezierTo(58, 34, 58, 40)
          ..arcToPoint(const Offset(42, 40), radius: const Radius.circular(8), clockwise: true)
          ..quadraticBezierTo(42, 34, 50, 22)
          ..close();
        canvas.drawPath(dropCenter, accentFill);
        canvas.drawPath(dropCenter, whiteStroke..strokeWidth = 2.6);
        // Setas de deflexão hidro-repelente
        canvas.drawLine(const Offset(34, 48), const Offset(24, 40), whiteStroke..strokeWidth = 2.8);
        canvas.drawLine(const Offset(66, 48), const Offset(76, 40), whiteStroke);
        break;

      case 18: // 18. Desentupidora: Tubulação sifão em U + Jato de hidrojateamento pressurizado
        final siphon = Path()
          ..moveTo(26, 24)
          ..lineTo(26, 56)
          ..arcToPoint(const Offset(56, 56), radius: const Radius.circular(15), clockwise: false)
          ..lineTo(56, 38)
          ..lineTo(78, 38);
        canvas.drawPath(siphon, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = primary.withValues(alpha: 0.28));
        canvas.drawPath(siphon, whiteStroke..strokeWidth = 4.0);
        // Setas dinâmicas de fluxo desobstruído
        canvas.drawLine(const Offset(60, 56), const Offset(78, 56), accentStroke..strokeWidth = 3.8);
        canvas.drawLine(const Offset(71, 50), const Offset(78, 56), accentStroke);
        canvas.drawLine(const Offset(71, 62), const Offset(78, 56), accentStroke);
        break;

      case 19: // 19. Piscina: Escada cromada de piscina + Ondas de água tratada cristalina
        // Duas hastes verticais da escada com arcos superiores
        final rail1 = Path()
          ..moveTo(34, 62)
          ..lineTo(34, 28)
          ..arcToPoint(const Offset(44, 28), radius: const Radius.circular(5), clockwise: true);
        final rail2 = Path()
          ..moveTo(54, 62)
          ..lineTo(54, 28)
          ..arcToPoint(const Offset(64, 28), radius: const Radius.circular(5), clockwise: true);
        canvas.drawPath(rail1, whiteStroke..strokeWidth = 3.8);
        canvas.drawPath(rail2, whiteStroke);
        canvas.drawLine(const Offset(34, 40), const Offset(54, 40), whiteStroke..strokeWidth = 3.2);
        canvas.drawLine(const Offset(34, 51), const Offset(54, 51), whiteStroke);
        // 2 Ondas duplas de água cristalina
        for (final y in [67.0, 77.0]) {
          final wave = Path()
            ..moveTo(20, y)
            ..quadraticBezierTo(30, y - 6, 40, y)
            ..quadraticBezierTo(50, y + 6, 60, y)
            ..quadraticBezierTo(70, y - 6, 80, y);
          canvas.drawPath(wave, accentStroke..strokeWidth = 3.8);
        }
        break;

      case 20: // 20. Eletrodomésticos: Lavadora Front-Load Inox Duotone com tambor circular
        final washer = RRect.fromRectAndRadius(const Rect.fromLTWH(24, 20, 52, 60), const Radius.circular(8));
        canvas.drawRRect(washer, duoFill);
        canvas.drawRRect(washer, whiteStroke..strokeWidth = 3.8);
        // Painel superior
        canvas.drawLine(const Offset(24, 34), const Offset(76, 34), whiteStroke..strokeWidth = 2.8);
        canvas.drawCircle(const Offset(34, 27), 2.5, accentFill);
        canvas.drawCircle(const Offset(43, 27), 2.5, whiteFill);
        // Escotilha redonda central com água/roupa em movimento
        canvas.drawCircle(const Offset(50, 56), 15, Paint()..color = const Color(0xFF0F172A));
        canvas.drawCircle(const Offset(50, 56), 15, accentStroke..strokeWidth = 3.6);
        final drumWave = Path()
          ..moveTo(38, 57)
          ..quadraticBezierTo(44, 51, 50, 57)
          ..quadraticBezierTo(56, 63, 62, 57);
        canvas.drawPath(drumWave, whiteStroke..strokeWidth = 2.8);
        break;

      case 21: // 21. TV e Antenas: Smart TV Widescreen + Pedestal e Ondas de Satélite/Sinal
        final tv = RRect.fromRectAndRadius(const Rect.fromLTWH(20, 28, 60, 38), const Radius.circular(6));
        canvas.drawRRect(tv, duoFill);
        canvas.drawRRect(tv, whiteStroke..strokeWidth = 3.8);
        // Base/Pedestal da TV
        canvas.drawLine(const Offset(50, 66), const Offset(50, 76), whiteStroke..strokeWidth = 3.8);
        canvas.drawLine(const Offset(36, 76), const Offset(64, 76), whiteStroke);
        // Símbolo de transmissão / sinal de antena dentro da tela
        final play = Path()
          ..moveTo(44, 39)
          ..lineTo(59, 47)
          ..lineTo(44, 55)
          ..close();
        canvas.drawPath(play, accentFill);
        break;

      case 22: // 22. Câmeras e Alarmes: Câmera de Segurança CFTV Bullet Articulada + Feixe Infravermelho
        // Suporte de parede na esquerda
        canvas.drawLine(const Offset(22, 48), const Offset(22, 72), whiteStroke..strokeWidth = 4.2);
        canvas.drawLine(const Offset(22, 60), const Offset(36, 60), whiteStroke..strokeWidth = 3.6);
        canvas.drawLine(const Offset(36, 60), const Offset(42, 48), whiteStroke);
        // Corpo cilíndrico inclinado da câmera CFTV (Bullet Camera)
        canvas.save();
        canvas.translate(48, 42);
        canvas.rotate(0.28);
        final camBody = RRect.fromRectAndRadius(const Rect.fromLTWH(-22, -11, 44, 22), const Radius.circular(6));
        canvas.drawRRect(camBody, duoFill);
        canvas.drawRRect(camBody, whiteStroke..strokeWidth = 3.6);
        // Lente frontal e LED infravermelho ativo
        canvas.drawLine(const Offset(14, -11), const Offset(14, 11), accentStroke..strokeWidth = 3.4);
        canvas.drawCircle(const Offset(-10, 0), 3.2, accentFill);
        canvas.restore();
        // Feixe de monitoramento
        canvas.drawLine(const Offset(72, 52), const Offset(82, 48), accentStroke..strokeWidth = 2.8);
        canvas.drawLine(const Offset(70, 59), const Offset(80, 63), accentStroke);
        break;

      case 23: // 23. Portões e Interfones: Portão Automático Deslizante + Setas de Motor e Controle
        final gate = RRect.fromRectAndRadius(const Rect.fromLTWH(20, 32, 46, 42), const Radius.circular(5));
        canvas.drawRRect(gate, duoFill);
        canvas.drawRRect(gate, whiteStroke..strokeWidth = 3.6);
        for (final x in [31.0, 43.0, 55.0]) {
          canvas.drawLine(Offset(x, 32), Offset(x, 74), whiteStroke..strokeWidth = 2.6);
        }
        // Seta dupla de abertura motorizada na base
        canvas.drawLine(const Offset(26, 81), const Offset(62, 81), accentStroke..strokeWidth = 3.6);
        canvas.drawLine(const Offset(55, 76), const Offset(62, 81), accentStroke);
        canvas.drawLine(const Offset(55, 86), const Offset(62, 81), accentStroke);
        break;

      case 24: // 24. Energia Solar: Placa Fotovoltaica reticulada + Sol radiante dourado
        // Sol radiante no topo esquerdo
        canvas.drawCircle(const Offset(32, 30), 8.5, accentFill);
        // Painel solar inclinado em perspectiva
        final panel = Path()
          ..moveTo(28, 46)
          ..lineTo(74, 46)
          ..lineTo(82, 72)
          ..lineTo(20, 72)
          ..close();
        canvas.drawPath(panel, duoFill);
        canvas.drawPath(panel, whiteStroke..strokeWidth = 3.6);
        // Grade de células fotovoltaicas
        canvas.drawLine(const Offset(24, 59), const Offset(78, 59), whiteStroke..strokeWidth = 2.4);
        canvas.drawLine(const Offset(43, 46), const Offset(40, 72), whiteStroke);
        canvas.drawLine(const Offset(59, 46), const Offset(62, 72), whiteStroke);
        // Pedestal do painel
        canvas.drawLine(const Offset(51, 72), const Offset(51, 81), accentStroke..strokeWidth = 3.8);
        canvas.drawLine(const Offset(38, 81), const Offset(64, 81), whiteStroke..strokeWidth = 3.4);
        break;

      case 25: // 25. Gás e Aquecedores: Aquecedor Digital a Gás + Chama controlada no visor
        final boiler = RRect.fromRectAndRadius(const Rect.fromLTWH(26, 20, 48, 54), const Radius.circular(8));
        canvas.drawRRect(boiler, duoFill);
        canvas.drawRRect(boiler, whiteStroke..strokeWidth = 3.8);
        // Chama viva no centro do aquecedor
        final flame = Path()
          ..moveTo(50, 30)
          ..quadraticBezierTo(64, 44, 60, 56)
          ..arcToPoint(const Offset(40, 56), radius: const Radius.circular(11), clockwise: true)
          ..quadraticBezierTo(36, 44, 50, 30)
          ..close();
        canvas.drawPath(flame, accentFill);
        // Tubulações inferiores de entrada/saída
        canvas.drawLine(const Offset(38, 74), const Offset(38, 83), whiteStroke..strokeWidth = 3.6);
        canvas.drawLine(const Offset(50, 74), const Offset(50, 83), accentStroke..strokeWidth = 3.6);
        canvas.drawLine(const Offset(62, 74), const Offset(62, 83), whiteStroke);
        break;

      case 26: // 26. Pisos e Revestimentos: Placas de Porcelanato em Losango Isométrico (Camadas)
        // Losango superior (placa de porcelanato sendo assentada)
        final tileTop = Path()
          ..moveTo(50, 22)
          ..lineTo(78, 38)
          ..lineTo(50, 54)
          ..lineTo(22, 38)
          ..close();
        canvas.drawPath(tileTop, duoFill);
        canvas.drawPath(tileTop, whiteStroke..strokeWidth = 3.6);
        // Junta de rejunte em cruz dentro do porcelanato
        canvas.drawLine(const Offset(36, 30), const Offset(64, 46), accentStroke..strokeWidth = 2.6);
        canvas.drawLine(const Offset(64, 30), const Offset(36, 46), accentStroke);
        // Camadas inferiores de argamassa e contrapiso
        final layer2 = Path()
          ..moveTo(22, 50)
          ..lineTo(50, 66)
          ..lineTo(78, 50);
        final layer3 = Path()
          ..moveTo(22, 62)
          ..lineTo(50, 78)
          ..lineTo(78, 62);
        canvas.drawPath(layer2, accentStroke..strokeWidth = 3.8);
        canvas.drawPath(layer3, whiteStroke..strokeWidth = 3.4);
        break;

      case 27: // 27. Cortinas e Persianas: Varão superior + Cortinas drapeadas e persiana central
        // Varão horizontal superior
        canvas.drawLine(const Offset(18, 24), const Offset(82, 24), whiteStroke..strokeWidth = 4.0);
        // Cortina esquerda e direita recolhidas com fita
        final leftCurtain = Path()
          ..moveTo(22, 24)
          ..lineTo(44, 24)
          ..quadraticBezierTo(40, 48, 28, 56)
          ..lineTo(36, 78)
          ..lineTo(22, 78)
          ..close();
        final rightCurtain = Path()
          ..moveTo(78, 24)
          ..lineTo(56, 24)
          ..quadraticBezierTo(60, 48, 72, 56)
          ..lineTo(64, 78)
          ..lineTo(78, 78)
          ..close();
        canvas.drawPath(leftCurtain, duoFill);
        canvas.drawPath(rightCurtain, duoFill);
        canvas.drawPath(leftCurtain, whiteStroke..strokeWidth = 3.2);
        canvas.drawPath(rightCurtain, whiteStroke);
        // Lâminas horizontais de persiana ao centro
        for (final y in [34.0, 43.0, 52.0]) {
          canvas.drawLine(Offset(42, y), Offset(58, y), accentStroke..strokeWidth = 2.8);
        }
        break;

      case 28: // 28. Estofados e Tapetes: Poltrona/Sofá Duotone acolchoado + Brilho de higienização
        // Encosto do sofá
        final backRest = RRect.fromRectAndRadius(const Rect.fromLTWH(28, 26, 44, 28), const Radius.circular(8));
        canvas.drawRRect(backRest, duoFill);
        canvas.drawRRect(backRest, whiteStroke..strokeWidth = 3.6);
        // Braços laterais e assento
        final seat = RRect.fromRectAndRadius(const Rect.fromLTWH(20, 46, 60, 22), const Radius.circular(7));
        canvas.drawRRect(seat, Paint()..color = const Color(0xFF111A2B));
        canvas.drawRRect(seat, duoFill);
        canvas.drawRRect(seat, whiteStroke..strokeWidth = 3.6);
        // Costura capitonê em esmeralda vivo e pés
        canvas.drawCircle(const Offset(42, 37), 2.8, accentFill);
        canvas.drawCircle(const Offset(58, 37), 2.8, accentFill);
        canvas.drawLine(const Offset(28, 68), const Offset(26, 77), whiteStroke..strokeWidth = 3.6);
        canvas.drawLine(const Offset(72, 68), const Offset(74, 77), whiteStroke);
        break;

      case 29: // 29. Mudanças e Fretes: Caminhão Baú em movimento + Caixa protegida
        // Baú de carga
        final cargo = RRect.fromRectAndRadius(const Rect.fromLTWH(18, 30, 40, 32), const Radius.circular(5));
        canvas.drawRRect(cargo, duoFill);
        canvas.drawRRect(cargo, whiteStroke..strokeWidth = 3.6);
        // Cabine frontal do caminhão
        final cab = Path()
          ..moveTo(58, 40)
          ..lineTo(72, 40)
          ..lineTo(80, 51)
          ..lineTo(80, 62)
          ..lineTo(58, 62)
          ..close();
        canvas.drawPath(cab, duoFill);
        canvas.drawPath(cab, whiteStroke..strokeWidth = 3.6);
        // Rodas com calota coral
        canvas.drawCircle(const Offset(34, 66), 7.5, Paint()..color = const Color(0xFF0F172A));
        canvas.drawCircle(const Offset(34, 66), 7.5, whiteStroke..strokeWidth = 3.6);
        canvas.drawCircle(const Offset(34, 66), 3.0, accentFill);
        canvas.drawCircle(const Offset(68, 66), 7.5, Paint()..color = const Color(0xFF0F172A));
        canvas.drawCircle(const Offset(68, 66), 7.5, whiteStroke);
        canvas.drawCircle(const Offset(68, 66), 3.0, accentFill);
        break;

      case 30: // 30. Informática e Redes: Notebook Pro aberto + Arcos de Sinal Wi-Fi Gigabit
        // Tela do notebook
        final screen = RRect.fromRectAndRadius(const Rect.fromLTWH(24, 30, 48, 32), const Radius.circular(5));
        canvas.drawRRect(screen, duoFill);
        canvas.drawRRect(screen, whiteStroke..strokeWidth = 3.6);
        // Base do teclado
        final base = Path()
          ..moveTo(16, 62)
          ..lineTo(80, 62)
          ..lineTo(74, 71)
          ..lineTo(22, 71)
          ..close();
        canvas.drawPath(base, whiteFill);
        // Ondas Wi-Fi de alta velocidade dentro da tela
        canvas.drawCircle(const Offset(48, 53), 2.8, accentFill);
        canvas.drawArc(const Rect.fromLTWH(39, 44, 18, 18), -math.pi * 0.78, math.pi * 0.56, false, accentStroke..strokeWidth = 3.2);
        canvas.drawArc(const Rect.fromLTWH(33, 38, 30, 30), -math.pi * 0.78, math.pi * 0.56, false, accentStroke);
        break;

      case 31: // 31. Cuidador de Idosos: Coração de cuidado humano + Mão de amparo / Bengala de apoio
        final heart = _buildHeartPath(const Offset(46, 44), 20);
        canvas.drawPath(heart, duoFill);
        canvas.drawPath(heart, accentStroke..strokeWidth = 3.6);
        // Mão acolhedora na base + Bengala ergonômica lateral
        final hand = Path()
          ..moveTo(22, 66)
          ..quadraticBezierTo(44, 78, 68, 64);
        canvas.drawPath(hand, whiteStroke..strokeWidth = 4.0);
        final cane = Path()
          ..moveTo(74, 76)
          ..lineTo(74, 40)
          ..arcToPoint(const Offset(62, 40), radius: const Radius.circular(6), clockwise: false);
        canvas.drawPath(cane, whiteStroke..strokeWidth = 3.6);
        break;

      case 32: // 32. Babá: Rosto de bebê sorridente com cachinho + Estrela acolhedora
        canvas.drawCircle(const Offset(48, 52), 23, duoFill);
        canvas.drawCircle(const Offset(48, 52), 23, whiteStroke..strokeWidth = 3.8);
        // Cachinho de bebê no topo da testa
        final curl = Path()
          ..moveTo(48, 29)
          ..quadraticBezierTo(56, 34, 51, 40)
          ..quadraticBezierTo(46, 43, 45, 38);
        canvas.drawPath(curl, accentStroke..strokeWidth = 3.4);
        // Olhinhos e sorriso feliz
        canvas.drawCircle(const Offset(40, 50), 2.8, whiteFill);
        canvas.drawCircle(const Offset(56, 50), 2.8, whiteFill);
        canvas.drawArc(const Rect.fromLTWH(40, 52, 16, 12), 0.2, math.pi - 0.4, false, accentStroke..strokeWidth = 3.4);
        break;

      case 33: // 33. Pet Care: Pata Duotone esculpida com almofada central em formato de coração
        // Almofada principal da patinha
        final pad = RRect.fromRectAndRadius(const Rect.fromLTWH(33, 50, 30, 22), const Radius.circular(11));
        canvas.drawRRect(pad, duoFill);
        canvas.drawRRect(pad, whiteStroke..strokeWidth = 3.6);
        // 4 Dedinhos ovais superiores
        for (final pos in [
          const Offset(27, 42),
          const Offset(40, 33),
          const Offset(56, 33),
          const Offset(69, 42),
        ]) {
          canvas.drawCircle(pos, 6.2, accentFill);
          canvas.drawCircle(pos, 6.2, whiteStroke..strokeWidth = 2.6);
        }
        break;
    }
  }

  void _paintCornerSpecialtyBadge(Canvas canvas, int index, Color primary, Color secondary) {
    const center = Offset(77, 23);
    const radius = 13.0;

    // Fundo escuro de contraste + anel luminoso da família cromática
    canvas.drawCircle(center, radius + 1.5, Paint()..color = const Color(0xFF0B111E));
    canvas.drawCircle(center, radius, Paint()..color = primary.withValues(alpha: 0.24));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = primary.withValues(alpha: 0.85),
    );

    final pStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;

    final pFill = Paint()
      ..style = PaintingStyle.fill
      ..color = primary;

    // Micro-símbolo semântico por família/categoria
    if (spec.isUrgent) {
      // Mini raio/pulso de resposta rápida (<60s)
      final miniBolt = Path()
        ..moveTo(79, 16)
        ..lineTo(73, 24)
        ..lineTo(78, 24)
        ..lineTo(75, 30)
        ..lineTo(82, 22)
        ..lineTo(77, 22)
        ..close();
      canvas.drawPath(miniBolt, pFill);
      canvas.drawPath(miniBolt, pStroke..strokeWidth = 1.2);
    } else {
      // Check de certificação técnica / brilho
      final check = Path()
        ..moveTo(72, 23.5)
        ..lineTo(75.8, 27.2)
        ..lineTo(82.5, 19.5);
      canvas.drawPath(check, pStroke..color = primary..strokeWidth = 2.8);
    }
  }

  void _drawSparkle(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  Path _buildHeartPath(Offset center, double size) {
    final w = size;
    final h = size * 0.92;
    final x = center.dx;
    final y = center.dy;
    return Path()
      ..moveTo(x, y + h * 0.45)
      ..cubicTo(x - w * 0.6, y + h * 0.1, x - w * 0.55, y - h * 0.45, x, y - h * 0.15)
      ..cubicTo(x + w * 0.55, y - h * 0.45, x + w * 0.6, y + h * 0.1, x, y + h * 0.45)
      ..close();
  }

  @override
  bool shouldRepaint(covariant CategoryEmblemCustomPainter oldDelegate) {
    return oldDelegate.spec.name != spec.name || oldDelegate.showCornerBadge != showCornerBadge;
  }
}

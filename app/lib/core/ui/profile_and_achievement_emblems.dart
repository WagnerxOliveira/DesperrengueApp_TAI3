import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/achievements.dart';

/// Especificação de Ícones Duotone do Menu de Perfil (Cliente e Profissional).
enum ProfileMenuIconKind {
  // Menu do Cliente (8 itens)
  clientPassport(
    'client_passport',
    'Prontuário da Casa',
    'solar:home-smile-angle-bold-duotone',
    Color(0xFFF59E0B),
    Color(0xFFFBBF24),
  ),
  clientAddress(
    'client_address',
    'Meu endereço',
    'solar:map-point-wave-bold-duotone',
    Color(0xFF38BDF8),
    Color(0xFF0EA5E9),
  ),
  clientWallet(
    'client_wallet',
    'Minha carteira',
    'solar:wallet-money-bold-duotone',
    Color(0xFF10B981),
    Color(0xFF34D399),
  ),
  clientHistory(
    'client_history',
    'Histórico de serviços',
    'solar:clipboard-check-bold-duotone',
    Color(0xFF60A5FA),
    Color(0xFF3B82F6),
  ),
  clientAchievements(
    'client_achievements',
    'Minhas conquistas',
    'solar:cup-star-bold-duotone',
    Color(0xFFFBBF24),
    Color(0xFFF59E0B),
  ),
  clientSupport(
    'client_support',
    'Ajuda e suporte',
    'solar:headphones-round-sound-bold-duotone',
    Color(0xFF818CF8),
    Color(0xFF6366F1),
  ),
  clientAppearance(
    'client_appearance',
    'Aparência',
    'solar:moon-stars-bold-duotone',
    Color(0xFFA78BFA),
    Color(0xFF8B5CF6),
  ),
  deleteAccount(
    'delete_account',
    'Excluir conta',
    'solar:trash-bin-minimalistic-bold-duotone',
    Color(0xFFF43F5E),
    Color(0xFFFB7185),
  ),

  // Menu do Profissional (9 itens + troca de modo)
  providerEditProfile(
    'provider_edit_profile',
    'Editar perfil',
    'solar:user-id-bold-duotone',
    Color(0xFF38BDF8),
    Color(0xFF0EA5E9),
  ),
  providerPortfolio(
    'provider_portfolio',
    'Meu portfólio',
    'solar:gallery-star-bold-duotone',
    Color(0xFFFF6D00),
    Color(0xFFFFB020),
  ),
  providerHistory(
    'provider_history',
    'Histórico de Serviços Prestados',
    'solar:checklist-minimalistic-bold-duotone',
    Color(0xFF60A5FA),
    Color(0xFF38BDF8),
  ),
  providerCertificates(
    'provider_certificates',
    'Meus certificados',
    'solar:diploma-verified-bold-duotone',
    Color(0xFF10B981),
    Color(0xFF34D399),
  ),
  providerReviews(
    'provider_reviews',
    'Minhas avaliações',
    'solar:star-shine-bold-duotone',
    Color(0xFFFBBF24),
    Color(0xFFF59E0B),
  ),
  providerAchievements(
    'provider_achievements',
    'Minhas conquistas',
    'solar:cup-first-bold-duotone',
    Color(0xFFF59E0B),
    Color(0xFFFBBF24),
  ),
  providerSupport(
    'provider_support',
    'Ajuda e suporte',
    'solar:chat-round-call-bold-duotone',
    Color(0xFF818CF8),
    Color(0xFF6366F1),
  ),
  providerAppearance(
    'provider_appearance',
    'Aparência',
    'solar:pallete-2-bold-duotone',
    Color(0xFFA78BFA),
    Color(0xFF8B5CF6),
  ),
  switchToClientMode(
    'switch_to_client_mode',
    'Ir para o modo Cliente',
    'solar:home-angle-bold-duotone',
    Color(0xFF38BDF8),
    Color(0xFF10B981),
  ),
  switchToProviderMode(
    'switch_to_provider_mode',
    'Ir para o modo Profissional',
    'solar:case-minimalistic-bold-duotone',
    Color(0xFFFF6D00),
    Color(0xFF38BDF8),
  );

  const ProfileMenuIconKind(
    this.id,
    this.label,
    this.iconifyId,
    this.primaryColor,
    this.secondaryColor,
  );

  final String id;
  final String label;
  final String iconifyId;
  final Color primaryColor;
  final Color secondaryColor;
}

/// Especificação Vetorial e Cromática de cada Trilha de Conquista (Cliente + Profissional).
class AchievementTrackVisualSpec {
  const AchievementTrackVisualSpec({
    required this.code,
    required this.name,
    required this.baseIconifyId,
    required this.evolvedIconifyId,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isClient,
  });

  final String code;
  final String name;
  final String baseIconifyId;
  final String evolvedIconifyId;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isClient;
}

/// Catálogo Visual Canônico das 6 Trilhas de Conquistas do Cliente e 9 do Profissional.
const List<AchievementTrackVisualSpec> kAchievementTrackVisualSpecs = [
  // ======================== 6 TRILHAS DO CLIENTE ========================
  AchievementTrackVisualSpec(
    code: 'firstOrder',
    name: '1º Pedido Realizado',
    baseIconifyId: 'solar:rocket-2-bold-duotone',
    evolvedIconifyId: 'solar:planet-3-bold-duotone',
    primaryColor: Color(0xFFFF6D00),
    secondaryColor: Color(0xFFF59E0B),
    isClient: true,
  ),
  AchievementTrackVisualSpec(
    code: 'verifiedClient',
    name: 'Cliente Verificado',
    baseIconifyId: 'solar:shield-user-bold-duotone',
    evolvedIconifyId: 'solar:verified-check-bold-duotone',
    primaryColor: Color(0xFF10B981),
    secondaryColor: Color(0xFF34D399),
    isClient: true,
  ),
  AchievementTrackVisualSpec(
    code: 'collaborativeReviewer',
    name: 'Avaliador Colaborativo',
    baseIconifyId: 'solar:chat-square-like-bold-duotone',
    evolvedIconifyId: 'solar:medal-star-circle-bold-duotone',
    primaryColor: Color(0xFF06B6D4),
    secondaryColor: Color(0xFF3B82F6),
    isClient: true,
  ),
  AchievementTrackVisualSpec(
    code: 'homeMaster',
    name: 'Mestre do Lar',
    baseIconifyId: 'solar:buildings-3-bold-duotone',
    evolvedIconifyId: 'ph:sparkle-fill',
    primaryColor: Color(0xFFF97316),
    secondaryColor: Color(0xFF8B5CF6),
    isClient: true,
  ),
  AchievementTrackVisualSpec(
    code: 'secureWallet',
    name: 'Pagamento 100% Seguro',
    baseIconifyId: 'solar:safe-square-bold-duotone',
    evolvedIconifyId: 'solar:shield-keyhole-bold-duotone',
    primaryColor: Color(0xFF10B981),
    secondaryColor: Color(0xFFEAB308),
    isClient: true,
  ),
  AchievementTrackVisualSpec(
    code: 'loyalClient',
    name: 'Cliente Fidelidade',
    baseIconifyId: 'solar:crown-minimalistic-bold-duotone',
    evolvedIconifyId: 'solar:crown-star-bold-duotone',
    primaryColor: Color(0xFFF59E0B),
    secondaryColor: Color(0xFFF43F5E),
    isClient: true,
  ),

  // ======================== 9 TRILHAS DO PROFISSIONAL ========================
  AchievementTrackVisualSpec(
    code: 'services',
    name: 'Serviços concluídos',
    baseIconifyId: 'solar:settings-minimalistic-bold-duotone',
    evolvedIconifyId: 'mdi:shield-wrench',
    primaryColor: Color(0xFF38BDF8),
    secondaryColor: Color(0xFFF59E0B),
    isClient: false,
  ),
  AchievementTrackVisualSpec(
    code: 'five_star',
    name: 'Avaliações 5 estrelas',
    baseIconifyId: 'solar:star-bold-duotone',
    evolvedIconifyId: 'solar:stars-line-bold-duotone',
    primaryColor: Color(0xFFFACC15),
    secondaryColor: Color(0xFFF59E0B),
    isClient: false,
  ),
  AchievementTrackVisualSpec(
    code: 'punctual',
    name: 'Pontualidade',
    baseIconifyId: 'solar:stopwatch-play-bold-duotone',
    evolvedIconifyId: 'mdi:clock-fast',
    primaryColor: Color(0xFF00C2FF),
    secondaryColor: Color(0xFF6366F1),
    isClient: false,
  ),
  AchievementTrackVisualSpec(
    code: 'tidy',
    name: 'Organização',
    baseIconifyId: 'solar:case-round-minimalistic-bold-duotone',
    evolvedIconifyId: 'ph:sparkle-fill',
    primaryColor: Color(0xFF10B981),
    secondaryColor: Color(0xFF14B8A6),
    isClient: false,
  ),
  AchievementTrackVisualSpec(
    code: 'fair_price',
    name: 'Preço justo',
    baseIconifyId: 'mdi:handshake-outline',
    evolvedIconifyId: 'solar:verified-check-bold-duotone',
    primaryColor: Color(0xFF22C55E),
    secondaryColor: Color(0xFFEAB308),
    isClient: false,
  ),
  AchievementTrackVisualSpec(
    code: 'skilled',
    name: 'Qualidade do trabalho',
    baseIconifyId: 'ph:diamond-duotone',
    evolvedIconifyId: 'solar:medal-ribbons-star-bold-duotone',
    primaryColor: Color(0xFFA855F7),
    secondaryColor: Color(0xFFEC4899),
    isClient: false,
  ),
  AchievementTrackVisualSpec(
    code: 'courteous',
    name: 'Cortesia',
    baseIconifyId: 'solar:hand-heart-bold-duotone',
    evolvedIconifyId: 'solar:hearts-bold-duotone',
    primaryColor: Color(0xFFFB7185),
    secondaryColor: Color(0xFFE11D48),
    isClient: false,
  ),
  AchievementTrackVisualSpec(
    code: 'emergency',
    name: 'Emergências',
    baseIconifyId: 'solar:danger-circle-bold-duotone',
    evolvedIconifyId: 'mdi:alarm-light',
    primaryColor: Color(0xFFFF6D00),
    secondaryColor: Color(0xFFEF4444),
    isClient: false,
  ),
  AchievementTrackVisualSpec(
    code: 'repeat_clients',
    name: 'Clientes recorrentes',
    baseIconifyId: 'solar:users-group-two-rounded-bold-duotone',
    evolvedIconifyId: 'ph:arrows-clockwise-bold',
    primaryColor: Color(0xFF3B82F6),
    secondaryColor: Color(0xFFFBBF24),
    isClient: false,
  ),
];

AchievementTrackVisualSpec resolveAchievementTrackSpec(String code) {
  for (final s in kAchievementTrackVisualSpecs) {
    if (s.code == code) return s;
  }
  return kAchievementTrackVisualSpecs.first;
}

/// Emblema Dark Glass Squircle (`42x42 dp`, raio `13 dp`) para os Menus de Perfil
/// (Cliente e Profissional). Substitui os círculos monocromáticos chapados por
/// ícones Duotone exclusivos com semântica cromática imediata.
class ProfileMenuEmblem extends StatelessWidget {
  const ProfileMenuEmblem({
    super.key,
    required this.kind,
    this.size = 42,
  });

  final ProfileMenuIconKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ProfileMenuEmblemPainter(kind: kind),
        ),
      ),
    );
  }
}

class _ProfileMenuEmblemPainter extends CustomPainter {
  const _ProfileMenuEmblemPainter({required this.kind});

  final ProfileMenuIconKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(30 * s));

    // Camada 1: Dark Glass Squircle (#1A273D -> #0F172A) + Glow Semântico 18%
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1B283E),
          Color(0xFF111A2B),
          Color(0xFF0C1322),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, bgPaint);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.1),
        radius: 0.72,
        colors: [
          kind.primaryColor.withValues(alpha: 0.24),
          kind.secondaryColor.withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, glowPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * s
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          kind.primaryColor.withValues(alpha: 0.58),
          kind.secondaryColor.withValues(alpha: 0.16),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect.deflate(1.5 * s), borderPaint);

    // Camada 2: Vetor Duotone Exclusivo de cada Item de Menu
    final fillDuo = Paint()
      ..style = PaintingStyle.fill
      ..color = kind.primaryColor.withValues(alpha: 0.30);
    final accentFill = Paint()
      ..style = PaintingStyle.fill
      ..color = kind.primaryColor;
    final accentStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = kind.primaryColor;
    final whiteStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFF8FAFC);

    switch (kind) {
      case ProfileMenuIconKind.clientPassport:
        // Escudo-Documento Predial com telhado + selo de certificação ABNT
        final doc = RRect.fromRectAndRadius(Rect.fromLTWH(26 * s, 22 * s, 44 * s, 56 * s), Radius.circular(7 * s));
        canvas.drawRRect(doc, fillDuo);
        canvas.drawRRect(doc, whiteStroke);
        // Pequeno telhado dentro do documento
        final roof = Path()
          ..moveTo(35 * s, 44 * s)
          ..lineTo(48 * s, 33 * s)
          ..lineTo(61 * s, 44 * s);
        canvas.drawPath(roof, accentStroke);
        canvas.drawLine(Offset(36 * s, 54 * s), Offset(56 * s, 54 * s), whiteStroke..strokeWidth = 4.2 * s);
        canvas.drawLine(Offset(36 * s, 64 * s), Offset(50 * s, 64 * s), accentStroke..strokeWidth = 4.2 * s);
        // Selo verificado no canto inferior direito
        canvas.drawCircle(Offset(68 * s, 66 * s), 13 * s, Paint()..color = const Color(0xFF111A2B));
        canvas.drawCircle(Offset(68 * s, 66 * s), 11 * s, accentFill);
        final chk = Path()
          ..moveTo(63 * s, 66 * s)
          ..lineTo(67 * s, 70 * s)
          ..lineTo(74 * s, 62 * s);
        canvas.drawPath(chk, whiteStroke..strokeWidth = 3.8 * s);
        break;

      case ProfileMenuIconKind.clientAddress:
        // Mapa dobrado em perspectiva + Pino Geodésico Ciano
        final mapBase = Path()
          ..moveTo(22 * s, 58 * s)
          ..lineTo(38 * s, 52 * s)
          ..lineTo(60 * s, 58 * s)
          ..lineTo(78 * s, 50 * s)
          ..lineTo(78 * s, 76 * s)
          ..lineTo(60 * s, 82 * s)
          ..lineTo(38 * s, 76 * s)
          ..lineTo(22 * s, 82 * s)
          ..close();
        canvas.drawPath(mapBase, fillDuo);
        canvas.drawPath(mapBase, accentStroke..strokeWidth = 4.0 * s);
        // Pino superior
        final pin = Path()
          ..moveTo(50 * s, 64 * s)
          ..cubicTo(34 * s, 50 * s, 32 * s, 38 * s, 32 * s, 33 * s)
          ..arcToPoint(Offset(68 * s, 33 * s), radius: Radius.circular(18 * s))
          ..cubicTo(68 * s, 38 * s, 66 * s, 50 * s, 50 * s, 64 * s)
          ..close();
        canvas.drawPath(pin, Paint()..color = const Color(0xFF111A2B));
        canvas.drawPath(pin, fillDuo);
        canvas.drawPath(pin, whiteStroke..strokeWidth = 5.0 * s);
        canvas.drawCircle(Offset(50 * s, 34 * s), 6.5 * s, accentFill);
        break;

      case ProfileMenuIconKind.clientWallet:
        // Carteira Digital com Fecho Esmeralda PIX
        final body = RRect.fromRectAndRadius(Rect.fromLTWH(22 * s, 30 * s, 56 * s, 44 * s), Radius.circular(9 * s));
        canvas.drawRRect(body, fillDuo);
        canvas.drawRRect(body, whiteStroke);
        // Aba superior de nota/cartão
        final card = Path()
          ..moveTo(28 * s, 30 * s)
          ..lineTo(64 * s, 21 * s)
          ..lineTo(70 * s, 30 * s);
        canvas.drawPath(card, accentStroke);
        // Fecho lateral direito com ponto luminoso
        final clasp = RRect.fromRectAndRadius(Rect.fromLTWH(58 * s, 44 * s, 22 * s, 16 * s), Radius.circular(5 * s));
        canvas.drawRRect(clasp, Paint()..color = const Color(0xFF111A2B));
        canvas.drawRRect(clasp, accentFill);
        canvas.drawCircle(Offset(66 * s, 52 * s), 3.5 * s, Paint()..color = Colors.white);
        break;

      case ProfileMenuIconKind.clientHistory:
      case ProfileMenuIconKind.providerHistory:
        // Prancheta de Ordens Verificadas por Etapa
        final board = RRect.fromRectAndRadius(Rect.fromLTWH(25 * s, 26 * s, 50 * s, 54 * s), Radius.circular(8 * s));
        canvas.drawRRect(board, fillDuo);
        canvas.drawRRect(board, whiteStroke);
        final clipTop = RRect.fromRectAndRadius(Rect.fromLTWH(38 * s, 19 * s, 24 * s, 12 * s), Radius.circular(4 * s));
        canvas.drawRRect(clipTop, accentFill);
        // Linhas de checklist auditadas
        for (final y in [43.0, 56.0, 68.0]) {
          canvas.drawCircle(Offset(35 * s, y * s), 3.2 * s, accentFill);
          canvas.drawLine(Offset(44 * s, y * s), Offset(65 * s, y * s), whiteStroke..strokeWidth = 4.2 * s);
        }
        break;

      case ProfileMenuIconKind.clientAchievements:
      case ProfileMenuIconKind.providerAchievements:
        // Taça de Campeão Facetada com Estrela Central Dourada
        final cup = Path()
          ..moveTo(32 * s, 24 * s)
          ..lineTo(68 * s, 24 * s)
          ..lineTo(64 * s, 48 * s)
          ..arcToPoint(Offset(36 * s, 48 * s), radius: Radius.circular(14 * s))
          ..close();
        canvas.drawPath(cup, fillDuo);
        canvas.drawPath(cup, whiteStroke);
        // Alças laterais
        canvas.drawArc(Rect.fromLTWH(20 * s, 27 * s, 16 * s, 18 * s), math.pi * 0.5, math.pi, false, accentStroke);
        canvas.drawArc(Rect.fromLTWH(64 * s, 27 * s, 16 * s, 18 * s), -math.pi * 0.5, math.pi, false, accentStroke);
        // Haste e pedestal
        canvas.drawLine(Offset(50 * s, 58 * s), Offset(50 * s, 74 * s), whiteStroke);
        canvas.drawLine(Offset(34 * s, 76 * s), Offset(66 * s, 76 * s), accentStroke..strokeWidth = 6 * s);
        // Estrela central
        canvas.drawCircle(Offset(50 * s, 38 * s), 5.5 * s, accentFill);
        break;

      case ProfileMenuIconKind.clientSupport:
      case ProfileMenuIconKind.providerSupport:
        // Headset de Atendimento Prioritário + Ondas de Voz
        canvas.drawArc(Rect.fromLTWH(24 * s, 24 * s, 52 * s, 50 * s), math.pi, math.pi, false, whiteStroke);
        final leftPad = RRect.fromRectAndRadius(Rect.fromLTWH(20 * s, 46 * s, 14 * s, 22 * s), Radius.circular(6 * s));
        final rightPad = RRect.fromRectAndRadius(Rect.fromLTWH(66 * s, 46 * s, 14 * s, 22 * s), Radius.circular(6 * s));
        canvas.drawRRect(leftPad, accentFill);
        canvas.drawRRect(rightPad, accentFill);
        // Microfone curvo até o centro
        final mic = Path()
          ..moveTo(73 * s, 68 * s)
          ..quadraticBezierTo(72 * s, 79 * s, 52 * s, 79 * s);
        canvas.drawPath(mic, whiteStroke..strokeWidth = 4.4 * s);
        canvas.drawCircle(Offset(48 * s, 79 * s), 4.5 * s, accentFill);
        break;

      case ProfileMenuIconKind.clientAppearance:
      case ProfileMenuIconKind.providerAppearance:
        // Lua Crescente + Estrelas Brilhantes Duotone
        final moon = Path()
          ..addArc(Rect.fromCircle(center: Offset(48 * s, 52 * s), radius: 24 * s), 0.3, math.pi * 1.45);
        canvas.drawCircle(Offset(48 * s, 52 * s), 22 * s, fillDuo);
        canvas.drawCircle(Offset(58 * s, 42 * s), 18 * s, Paint()..color = const Color(0xFF131D31));
        canvas.drawPath(moon, whiteStroke);
        // Estrelas douradas/violetas
        canvas.drawCircle(Offset(68 * s, 30 * s), 4.5 * s, accentFill);
        canvas.drawCircle(Offset(76 * s, 46 * s), 3.0 * s, Paint()..color = Colors.white);
        break;

      case ProfileMenuIconKind.deleteAccount:
        // Lixeira Minimalista em Coral de Alerta Semântico
        final bin = RRect.fromRectAndRadius(Rect.fromLTWH(30 * s, 34 * s, 40 * s, 44 * s), Radius.circular(7 * s));
        canvas.drawRRect(bin, fillDuo);
        canvas.drawRRect(bin, whiteStroke);
        canvas.drawLine(Offset(24 * s, 32 * s), Offset(76 * s, 32 * s), accentStroke..strokeWidth = 5.5 * s);
        canvas.drawLine(Offset(41 * s, 23 * s), Offset(59 * s, 23 * s), whiteStroke);
        canvas.drawLine(Offset(43 * s, 45 * s), Offset(43 * s, 66 * s), accentStroke..strokeWidth = 4.5 * s);
        canvas.drawLine(Offset(57 * s, 45 * s), Offset(57 * s, 66 * s), accentStroke..strokeWidth = 4.5 * s);
        break;

      case ProfileMenuIconKind.providerEditProfile:
        // Crachá de Especialista + Caneta de Edição
        final card = RRect.fromRectAndRadius(Rect.fromLTWH(22 * s, 26 * s, 48 * s, 50 * s), Radius.circular(8 * s));
        canvas.drawRRect(card, fillDuo);
        canvas.drawRRect(card, whiteStroke);
        canvas.drawCircle(Offset(46 * s, 43 * s), 8 * s, accentFill);
        canvas.drawArc(Rect.fromLTWH(34 * s, 54 * s, 24 * s, 16 * s), math.pi, math.pi, false, whiteStroke..strokeWidth = 4.2 * s);
        // Caneta diagonal no canto inferior direito
        canvas.drawLine(Offset(62 * s, 72 * s), Offset(78 * s, 56 * s), accentStroke..strokeWidth = 6.5 * s);
        canvas.drawLine(Offset(62 * s, 72 * s), Offset(78 * s, 56 * s), whiteStroke..strokeWidth = 2.5 * s);
        break;

      case ProfileMenuIconKind.providerPortfolio:
        // Moldura de Galeria em Vitrine + Paisagem Técnica + Estrela
        final frame = RRect.fromRectAndRadius(Rect.fromLTWH(22 * s, 25 * s, 56 * s, 50 * s), Radius.circular(9 * s));
        canvas.drawRRect(frame, fillDuo);
        canvas.drawRRect(frame, whiteStroke);
        final mountain = Path()
          ..moveTo(26 * s, 68 * s)
          ..lineTo(43 * s, 48 * s)
          ..lineTo(56 * s, 60 * s)
          ..lineTo(66 * s, 50 * s)
          ..lineTo(74 * s, 68 * s);
        canvas.drawPath(mountain, accentStroke..strokeWidth = 4.8 * s);
        canvas.drawCircle(Offset(62 * s, 38 * s), 5.5 * s, accentFill);
        break;

      case ProfileMenuIconKind.providerCertificates:
        // Diploma/Certificado Técnico Oficial com Selo e Fita Esmeralda
        final cert = RRect.fromRectAndRadius(Rect.fromLTWH(22 * s, 24 * s, 56 * s, 44 * s), Radius.circular(7 * s));
        canvas.drawRRect(cert, fillDuo);
        canvas.drawRRect(cert, whiteStroke);
        canvas.drawLine(Offset(32 * s, 36 * s), Offset(56 * s, 36 * s), whiteStroke..strokeWidth = 4.2 * s);
        canvas.drawLine(Offset(32 * s, 48 * s), Offset(48 * s, 48 * s), accentStroke..strokeWidth = 4.2 * s);
        // Medalhão de certificação à direita
        canvas.drawCircle(Offset(64 * s, 58 * s), 11 * s, accentFill);
        canvas.drawLine(Offset(60 * s, 67 * s), Offset(57 * s, 80 * s), accentStroke..strokeWidth = 4.5 * s);
        canvas.drawLine(Offset(68 * s, 67 * s), Offset(71 * s, 80 * s), accentStroke..strokeWidth = 4.5 * s);
        canvas.drawCircle(Offset(64 * s, 58 * s), 5 * s, Paint()..color = Colors.white);
        break;

      case ProfileMenuIconKind.providerReviews:
        // Balão de Diálogo + Estrela de Reputação Brilhante
        final bubble = RRect.fromRectAndRadius(Rect.fromLTWH(22 * s, 24 * s, 56 * s, 44 * s), Radius.circular(11 * s));
        canvas.drawRRect(bubble, fillDuo);
        canvas.drawRRect(bubble, whiteStroke);
        _drawStar(canvas, Offset(50 * s, 46 * s), 14 * s, 6.5 * s, 5, accentFill);
        _drawStar(
          canvas,
          Offset(50 * s, 46 * s),
          14 * s,
          6.5 * s,
          5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8 * s
            ..color = Colors.white,
        );
        break;

      case ProfileMenuIconKind.switchToClientMode:
        // Casa Acolhedora do Cliente + Setas de Troca
        final house = Path()
          ..moveTo(24 * s, 48 * s)
          ..lineTo(50 * s, 25 * s)
          ..lineTo(76 * s, 48 * s);
        canvas.drawPath(house, accentStroke..strokeWidth = 5.5 * s);
        final walls = RRect.fromRectAndRadius(Rect.fromLTWH(31 * s, 46 * s, 38 * s, 30 * s), Radius.circular(5 * s));
        canvas.drawRRect(walls, fillDuo);
        canvas.drawRRect(walls, whiteStroke);
        break;

      case ProfileMenuIconKind.switchToProviderMode:
        // Maleta Técnica do Especialista
        final bag = RRect.fromRectAndRadius(Rect.fromLTWH(24 * s, 36 * s, 52 * s, 40 * s), Radius.circular(8 * s));
        canvas.drawRRect(bag, fillDuo);
        canvas.drawRRect(bag, whiteStroke);
        canvas.drawArc(Rect.fromLTWH(38 * s, 24 * s, 24 * s, 20 * s), math.pi, math.pi, false, accentStroke);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ProfileMenuEmblemPainter oldDelegate) => oldDelegate.kind != kind;
}

/// Motor Gráfico Nativo de Forja de Medalhas (`AchievementMedalForge`).
///
/// Implementa os dois estados psicológicos de alto padrão de mercado:
/// 1. **ESTADO BLOQUEADO (`locked: true`)**: Padrão *Cinza Claro Prateado / Titânio Jateado*
///    (`#CBD5E1` sobre `#1E293B` com aro `#94A3B8` e micro-cápsula de cadeado `#E2E8F0`),
///    permitindo enxergar com nitidez cristalina o desenho do troféu e despertando o
///    **Efeito Zeigarnik** (desejo imediato de acender a medalha).
/// 2. **ESTADO DESBLOQUEADO (`locked: false`)**: A medalha acende na paleta viva da trilha
///    e evolui geometricamente em 5 patamares (`Bronze` -> `Prata Viva` -> `Ouro com Louros`
///    -> `Platina Octogonal` -> `Diamante Coroado Mestre`).
class AchievementMedalForge extends StatelessWidget {
  const AchievementMedalForge({
    super.key,
    required this.trackCode,
    required this.tier,
    this.level = 1,
    this.size = 64,
    this.locked = false,
  });

  final String trackCode;
  final AchievementTier tier;
  final int level;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _AchievementMedalForgePainter(
            spec: resolveAchievementTrackSpec(trackCode),
            tier: tier,
            level: level,
            locked: locked,
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

class _AchievementMedalForgePainter extends CustomPainter {
  const _AchievementMedalForgePainter({
    required this.spec,
    required this.tier,
    required this.level,
    required this.locked,
    required this.isDark,
  });

  final AchievementTrackVisualSpec spec;
  final AchievementTier tier;
  final int level;
  final bool locked;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    final center = Offset(50 * s, 50 * s);
    final outerRadius = 45 * s;
    final innerRadius = 35 * s;

    if (locked) {
      _paintLockedSilverState(canvas, size, s, center, outerRadius, innerRadius);
    } else {
      _paintUnlockedVibrantState(canvas, size, s, center, outerRadius, innerRadius);
    }
  }

  /// ESTADO 1: CONQUISTA BLOQUEADA — PADRÃO CINZA CLARO PRATEADO (#CBD5E1)
  void _paintLockedSilverState(
    Canvas canvas,
    Size size,
    double s,
    Offset center,
    double outerRadius,
    double innerRadius,
  ) {
    final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);

    // Corpo externo em Prata Acetinada / Ardósia Clara
    final rimPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF475569), Color(0xFF273449), Color(0xFF1E293B)]
            : const [Color(0xFFF1F5F9), Color(0xFFCBD5E1), Color(0xFF94A3B8)],
      ).createShader(outerRect);

    if (tier == AchievementTier.platinum || tier == AchievementTier.diamond) {
      final oct = _regularPolygonPath(center, outerRadius, 8, rotation: math.pi / 8);
      canvas.drawPath(oct, rimPaint);
      canvas.drawPath(
        oct,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 * s
          ..color = isDark ? const Color(0xFF94A3B8).withValues(alpha: 0.55) : const Color(0xFF64748B).withValues(alpha: 0.45),
      );
    } else {
      canvas.drawCircle(center, outerRadius, rimPaint);
      canvas.drawCircle(
        center,
        outerRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 * s
          ..color = isDark ? const Color(0xFF94A3B8).withValues(alpha: 0.55) : const Color(0xFF64748B).withValues(alpha: 0.45),
      );
    }

    // Face interna com contraste limpo para destacar o glifo Cinza Claro (#CBD5E1)
    final facePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.25),
        radius: 0.95,
        colors: isDark
            ? const [Color(0xFF334155), Color(0xFF1E293B)]
            : const [Color(0xFFFFFFFF), Color(0xFFE2E8F0)],
      ).createShader(innerRect);
    canvas.drawCircle(center, innerRadius, facePaint);

    // Anel interno prateado nítido
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * s
        ..color = isDark ? const Color(0xFFCBD5E1).withValues(alpha: 0.38) : const Color(0xFF94A3B8).withValues(alpha: 0.60),
    );

    // Desenho do Ícone Interno em Cinza Claro Prateado de Alta Nitidez (#CBD5E1 / #E2E8F0)
    final silverStroke = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);
    final silverFill = isDark
        ? const Color(0xFF94A3B8).withValues(alpha: 0.28)
        : const Color(0xFF94A3B8).withValues(alpha: 0.30);
    final silverAccent = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569);

    _paintTrackSymbol(
      canvas,
      s,
      strokeColor: silverStroke,
      fillColor: silverFill,
      accentColor: silverAccent,
    );

    // Micro-Cápsula de Cadeado no canto inferior direito (80, 80)
    final lockCenter = Offset(78 * s, 78 * s);
    canvas.drawCircle(
      lockCenter,
      14.5 * s,
      Paint()..color = isDark ? const Color(0xFF0F172A) : Colors.white,
    );
    canvas.drawCircle(
      lockCenter,
      12.5 * s,
      Paint()..color = isDark ? const Color(0xFF334155) : const Color(0xFF64748B),
    );
    canvas.drawCircle(
      lockCenter,
      12.5 * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 * s
        ..color = isDark ? const Color(0xFFCBD5E1) : Colors.white,
    );
    // Desenho do cadeado nítido (#E2E8F0)
    final lockColor = isDark ? const Color(0xFFE2E8F0) : Colors.white;
    final lockBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(78 * s, 80.5 * s), width: 10.5 * s, height: 8.5 * s),
      Radius.circular(2.2 * s),
    );
    canvas.drawRRect(lockBody, Paint()..color = lockColor);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(78 * s, 76.0 * s), width: 6.8 * s, height: 7.2 * s),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * s
        ..color = lockColor,
    );
  }

  /// ESTADO 2: CONQUISTA DESBLOQUEADA — COLORIDA VIVA + EVOLUÇÃO METÁLICA
  void _paintUnlockedVibrantState(
    Canvas canvas,
    Size size,
    double s,
    Offset center,
    double outerRadius,
    double innerRadius,
  ) {
    final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);

    // Paleta evolutiva do aro metálico combinada com a cor viva da conquista
    final (Color rimTop, Color rimMid, Color rimBot) = switch (tier) {
      AchievementTier.bronze => (const Color(0xFFFFD29D), spec.primaryColor, const Color(0xFF9A4E1C)),
      AchievementTier.silver => (const Color(0xFFF8FAFC), spec.primaryColor, const Color(0xFF475569)),
      AchievementTier.gold => (const Color(0xFFFEF08A), const Color(0xFFF59E0B), const Color(0xFFB45309)),
      AchievementTier.platinum => (const Color(0xFFE0E7FF), spec.primaryColor, const Color(0xFF4338CA)),
      AchievementTier.diamond => (const Color(0xFFFFFBEB), spec.primaryColor, spec.secondaryColor),
    };

    // Halo Luminoso Exterior (Glow de Recompensa)
    canvas.drawCircle(
      center,
      outerRadius + 4 * s,
      Paint()
        ..color = spec.primaryColor.withValues(alpha: isDark ? 0.32 : 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * s),
    );

    final rimPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [rimTop, rimMid, rimBot],
      ).createShader(outerRect);

    // Moldura Evolutiva por Nível (Círculo -> Duplo Anel -> Louros -> Octógono -> Coroa Diamante)
    if (tier == AchievementTier.platinum || tier == AchievementTier.diamond) {
      final oct = _regularPolygonPath(center, outerRadius, 8, rotation: math.pi / 8);
      canvas.drawPath(oct, rimPaint);
      canvas.drawPath(
        oct,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8 * s
          ..color = Colors.white.withValues(alpha: 0.85),
      );
    } else {
      canvas.drawCircle(center, outerRadius, rimPaint);
      canvas.drawCircle(
        center,
        outerRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 * s
          ..color = Colors.white.withValues(alpha: 0.80),
      );
    }

    // Núcleo escuro/vítreo profundo com brilho radial vivo da cor da conquista
    final facePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.15),
        radius: 0.90,
        colors: [
          Color.lerp(const Color(0xFF1E293B), spec.primaryColor, 0.38)!,
          const Color(0xFF0F172A),
        ],
      ).createShader(innerRect);
    canvas.drawCircle(center, innerRadius, facePaint);

    // Reflexo vítreo superior (Top Specular Arc)
    final glossPath = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(50 * s, 45 * s), radius: innerRadius * 0.92),
        math.pi * 1.12,
        math.pi * 0.76,
      );
    canvas.drawPath(
      glossPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * s
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    // Anel interno luminoso
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * s
        ..color = rimTop.withValues(alpha: 0.85),
    );

    // Louros Dourados nos níveis Ouro / Platina / Diamante
    if (tier.index >= AchievementTier.gold.index) {
      final laurelPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * s
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFEF08A).withValues(alpha: 0.85);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: (outerRadius + innerRadius) * 0.5),
        math.pi * 0.68,
        math.pi * 0.45,
        false,
        laurelPaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: (outerRadius + innerRadius) * 0.5),
        -math.pi * 0.13,
        math.pi * 0.45,
        false,
        laurelPaint,
      );
    }

    // Desenho do Ícone Interno em Cores Vivas + Branco Puro
    _paintTrackSymbol(
      canvas,
      s,
      strokeColor: Colors.white,
      fillColor: spec.primaryColor.withValues(alpha: 0.42),
      accentColor: Color.lerp(spec.primaryColor, Colors.white, 0.22)!,
    );

    // Estrelas Evolutivas de Nível na Base da Medalha (1 a 5 estrelas conforme o tier)
    final starCount = tier.index + 1;
    for (int i = 0; i < starCount; i++) {
      final angle = math.pi * 0.5 + (i - (starCount - 1) / 2.0) * 0.24;
      final r = (outerRadius + innerRadius) * 0.5;
      final pos = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
      canvas.drawCircle(pos, 2.8 * s, Paint()..color = const Color(0xFFFEF08A));
    }

    // Coroa Superior no nível Diamante ou Selo de Check Luminoso no canto inferior direito
    if (tier == AchievementTier.diamond) {
      final crown = Path()
        ..moveTo(38 * s, 14 * s)
        ..lineTo(42 * s, 6 * s)
        ..lineTo(50 * s, 12 * s)
        ..lineTo(58 * s, 5 * s)
        ..lineTo(62 * s, 14 * s)
        ..close();
      canvas.drawPath(crown, Paint()..color = const Color(0xFFFBBF24));
      canvas.drawPath(
        crown,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * s
          ..color = Colors.white,
      );
    }

    // Selo de Conquista Ativa (Check Verde/Dourado Brilhante no canto inferior direito)
    final badgeCenter = Offset(78 * s, 78 * s);
    canvas.drawCircle(badgeCenter, 13.5 * s, Paint()..color = const Color(0xFF0F172A));
    canvas.drawCircle(badgeCenter, 11.5 * s, Paint()..color = spec.primaryColor);
    canvas.drawCircle(
      badgeCenter,
      11.5 * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 * s
        ..color = Colors.white,
    );
    final check = Path()
      ..moveTo(73.2 * s, 78.2 * s)
      ..lineTo(76.8 * s, 81.8 * s)
      ..lineTo(83.2 * s, 74.5 * s);
    canvas.drawPath(
      check,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
  }

  /// Desenha o Símbolo Vetorial Exclusivo de cada uma das 15 Trilhas (6 Cliente + 9 Profissional),
  /// com evolução geométrica adicional nos níveis avançados (Ouro, Platina e Diamante).
  void _paintTrackSymbol(
    Canvas canvas,
    double s, {
    required Color strokeColor,
    required Color fillColor,
    required Color accentColor,
  }) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = strokeColor;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor;
    final accent = Paint()
      ..style = PaintingStyle.fill
      ..color = accentColor;
    final accentLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accentColor;

    final isHighTier = tier.index >= AchievementTier.gold.index || level >= 3;

    switch (spec.code) {
      case 'firstOrder':
        // Foguete de Ignição -> Foguete em Órbita Planetária nos níveis superiores
        if (isHighTier) {
          canvas.drawArc(
            Rect.fromCenter(center: Offset(50 * s, 52 * s), width: 46 * s, height: 18 * s),
            -0.3,
            math.pi * 1.2,
            false,
            accentLine,
          );
        }
        final rocket = Path()
          ..moveTo(50 * s, 26 * s)
          ..quadraticBezierTo(63 * s, 38 * s, 60 * s, 58 * s)
          ..lineTo(40 * s, 58 * s)
          ..quadraticBezierTo(37 * s, 38 * s, 50 * s, 26 * s)
          ..close();
        canvas.drawPath(rocket, fill);
        canvas.drawPath(rocket, stroke);
        canvas.drawCircle(Offset(50 * s, 43 * s), 4.5 * s, accent);
        // Aletas e chama propulsora
        canvas.drawLine(Offset(40 * s, 52 * s), Offset(33 * s, 60 * s), stroke);
        canvas.drawLine(Offset(60 * s, 52 * s), Offset(67 * s, 60 * s), stroke);
        final flame = Path()
          ..moveTo(45 * s, 59 * s)
          ..lineTo(50 * s, 70 * s)
          ..lineTo(55 * s, 59 * s);
        canvas.drawPath(flame, accentLine);
        break;

      case 'verifiedClient':
        // Escudo Biométrico com Rosto/Identidade Oficial
        final shield = Path()
          ..moveTo(50 * s, 25 * s)
          ..lineTo(69 * s, 32 * s)
          ..lineTo(69 * s, 49 * s)
          ..cubicTo(69 * s, 61 * s, 50 * s, 71 * s, 50 * s, 71 * s)
          ..cubicTo(50 * s, 71 * s, 31 * s, 61 * s, 31 * s, 49 * s)
          ..lineTo(31 * s, 32 * s)
          ..close();
        canvas.drawPath(shield, fill);
        canvas.drawPath(shield, stroke);
        canvas.drawCircle(Offset(50 * s, 43 * s), 5.5 * s, accent);
        canvas.drawArc(Rect.fromLTWH(40 * s, 50 * s, 20 * s, 14 * s), math.pi, math.pi, false, stroke);
        break;

      case 'collaborativeReviewer':
        // Balão de Diálogo Comunitário com Estrela Lapidada
        final chat = RRect.fromRectAndRadius(Rect.fromLTWH(30 * s, 29 * s, 40 * s, 32 * s), Radius.circular(8 * s));
        canvas.drawRRect(chat, fill);
        canvas.drawRRect(chat, stroke);
        _drawStar(canvas, Offset(50 * s, 45 * s), 10.5 * s, 4.8 * s, 5, accent);
        if (isHighTier) {
          canvas.drawCircle(Offset(35 * s, 28 * s), 3.0 * s, accent);
          canvas.drawCircle(Offset(66 * s, 28 * s), 3.0 * s, accent);
        }
        break;

      case 'homeMaster':
        // Mansão / Arquitetura Multicategorias com Cômodos Iluminados (distinto do Passaporte)
        final mainTower = Rect.fromLTWH(38 * s, 34 * s, 24 * s, 34 * s);
        final leftWing = Rect.fromLTWH(27 * s, 46 * s, 11 * s, 22 * s);
        final rightWing = Rect.fromLTWH(62 * s, 46 * s, 11 * s, 22 * s);
        canvas.drawRect(mainTower, fill);
        canvas.drawRect(leftWing, fill);
        canvas.drawRect(rightWing, fill);
        canvas.drawRect(mainTower, stroke);
        canvas.drawRect(leftWing, stroke);
        canvas.drawRect(rightWing, stroke);
        final roof = Path()
          ..moveTo(35 * s, 34 * s)
          ..lineTo(50 * s, 23 * s)
          ..lineTo(65 * s, 34 * s);
        canvas.drawPath(roof, accentLine);
        // Janelas acesas
        canvas.drawRect(Rect.fromLTWH(44 * s, 40 * s, 5 * s, 5 * s), accent);
        canvas.drawRect(Rect.fromLTWH(51 * s, 40 * s, 5 * s, 5 * s), accent);
        canvas.drawRect(Rect.fromLTWH(47 * s, 54 * s, 6 * s, 14 * s), accent);
        break;

      case 'secureWallet':
        // Cofre Forte / Escudo com Fechadura PIX Dourada
        final safe = RRect.fromRectAndRadius(Rect.fromLTWH(31 * s, 29 * s, 38 * s, 38 * s), Radius.circular(8 * s));
        canvas.drawRRect(safe, fill);
        canvas.drawRRect(safe, stroke);
        canvas.drawCircle(Offset(50 * s, 48 * s), 9 * s, accentLine);
        canvas.drawCircle(Offset(50 * s, 48 * s), 3.5 * s, accent);
        canvas.drawLine(Offset(50 * s, 36 * s), Offset(50 * s, 41 * s), stroke);
        canvas.drawLine(Offset(50 * s, 55 * s), Offset(50 * s, 60 * s), stroke);
        canvas.drawLine(Offset(38 * s, 48 * s), Offset(43 * s, 48 * s), stroke);
        canvas.drawLine(Offset(57 * s, 48 * s), Offset(62 * s, 48 * s), stroke);
        break;

      case 'loyalClient':
        // Coroa Real VIP com Joias Facetadas
        final crown = Path()
          ..moveTo(30 * s, 62 * s)
          ..lineTo(27 * s, 38 * s)
          ..lineTo(40 * s, 48 * s)
          ..lineTo(50 * s, 31 * s)
          ..lineTo(60 * s, 48 * s)
          ..lineTo(73 * s, 38 * s)
          ..lineTo(70 * s, 62 * s)
          ..close();
        canvas.drawPath(crown, fill);
        canvas.drawPath(crown, stroke);
        canvas.drawCircle(Offset(50 * s, 28 * s), 3.5 * s, accent);
        canvas.drawCircle(Offset(27 * s, 35 * s), 3.0 * s, accent);
        canvas.drawCircle(Offset(73 * s, 35 * s), 3.0 * s, accent);
        break;

      case 'services':
        // Engrenagem de Precisão + Chave Técnica (e Escudo nos níveis superiores)
        canvas.drawCircle(Offset(50 * s, 50 * s), 16 * s, fill);
        canvas.drawCircle(Offset(50 * s, 50 * s), 15 * s, stroke);
        for (int i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            Offset((50 + 15 * math.cos(a)) * s, (50 + 15 * math.sin(a)) * s),
            Offset((50 + 21 * math.cos(a)) * s, (50 + 21 * math.sin(a)) * s),
            stroke,
          );
        }
        // Chave inglesa técnica no centro
        canvas.drawLine(Offset(42 * s, 58 * s), Offset(58 * s, 42 * s), accentLine..strokeWidth = 4.8 * s);
        canvas.drawCircle(Offset(50 * s, 50 * s), 5.5 * s, accent);
        break;

      case 'five_star':
        // Estrela 3D Facetada (com Raios de Brilho nos níveis superiores)
        final starFill = Path();
        _addStarPath(starFill, Offset(50 * s, 49 * s), 21 * s, 9.5 * s, 5);
        canvas.drawPath(starFill, fill);
        canvas.drawPath(starFill, stroke);
        _drawStar(canvas, Offset(50 * s, 49 * s), 10 * s, 4.5 * s, 5, accent);
        if (isHighTier) {
          canvas.drawCircle(Offset(31 * s, 32 * s), 2.8 * s, accent);
          canvas.drawCircle(Offset(69 * s, 32 * s), 2.8 * s, accent);
        }
        break;

      case 'punctual':
        // Cronógrafo Suíço de Precisão
        canvas.drawCircle(Offset(50 * s, 52 * s), 19 * s, fill);
        canvas.drawCircle(Offset(50 * s, 52 * s), 19 * s, stroke);
        canvas.drawLine(Offset(44 * s, 27 * s), Offset(56 * s, 27 * s), stroke);
        canvas.drawLine(Offset(50 * s, 27 * s), Offset(50 * s, 33 * s), stroke);
        canvas.drawLine(Offset(64 * s, 35 * s), Offset(69 * s, 30 * s), accentLine);
        // Ponteiros de alta precisão
        canvas.drawLine(Offset(50 * s, 52 * s), Offset(50 * s, 40 * s), stroke);
        canvas.drawLine(Offset(50 * s, 52 * s), Offset(60 * s, 52 * s), accentLine);
        canvas.drawCircle(Offset(50 * s, 52 * s), 3.2 * s, accent);
        break;

      case 'tidy':
        // Maleta Técnica Impecável + Estrela de Brilho (sem vassoura!)
        final cRect = RRect.fromRectAndRadius(Rect.fromLTWH(29 * s, 37 * s, 42 * s, 31 * s), Radius.circular(7 * s));
        canvas.drawRRect(cRect, fill);
        canvas.drawRRect(cRect, stroke);
        canvas.drawArc(Rect.fromLTWH(41 * s, 27 * s, 18 * s, 16 * s), math.pi, math.pi, false, stroke);
        // Check de organização + brilho
        final chk = Path()
          ..moveTo(42 * s, 53 * s)
          ..lineTo(48 * s, 59 * s)
          ..lineTo(59 * s, 46 * s);
        canvas.drawPath(chk, accentLine..strokeWidth = 4.4 * s);
        break;

      case 'fair_price':
        // Balança de Equilíbrio & Escudo de Transparência
        canvas.drawLine(Offset(50 * s, 28 * s), Offset(50 * s, 68 * s), stroke);
        canvas.drawLine(Offset(38 * s, 68 * s), Offset(62 * s, 68 * s), stroke);
        canvas.drawLine(Offset(30 * s, 38 * s), Offset(70 * s, 38 * s), accentLine);
        // Pratos da balança equilibrados
        canvas.drawArc(Rect.fromLTWH(25 * s, 46 * s, 16 * s, 10 * s), 0, math.pi, true, fill);
        canvas.drawArc(Rect.fromLTWH(25 * s, 46 * s, 16 * s, 10 * s), 0, math.pi, true, stroke);
        canvas.drawArc(Rect.fromLTWH(59 * s, 46 * s, 16 * s, 10 * s), 0, math.pi, true, fill);
        canvas.drawArc(Rect.fromLTWH(59 * s, 46 * s, 16 * s, 10 * s), 0, math.pi, true, stroke);
        canvas.drawCircle(Offset(50 * s, 32 * s), 4.0 * s, accent);
        break;

      case 'skilled':
        // Diamante Lapidado de Engenharia (sem repetir fita de certificado!)
        final diamond = Path()
          ..moveTo(37 * s, 31 * s)
          ..lineTo(63 * s, 31 * s)
          ..lineTo(73 * s, 44 * s)
          ..lineTo(50 * s, 70 * s)
          ..lineTo(27 * s, 44 * s)
          ..close();
        canvas.drawPath(diamond, fill);
        canvas.drawPath(diamond, stroke);
        canvas.drawLine(Offset(27 * s, 44 * s), Offset(73 * s, 44 * s), accentLine..strokeWidth = 3.0 * s);
        canvas.drawLine(Offset(37 * s, 31 * s), Offset(50 * s, 70 * s), stroke..strokeWidth = 2.6 * s);
        canvas.drawLine(Offset(63 * s, 31 * s), Offset(50 * s, 70 * s), stroke..strokeWidth = 2.6 * s);
        break;

      case 'courteous':
        // Coração sobre Mão Acolhedora / Insígnia de Hospitalidade (sem carinha infantil!)
        final heart = Path()
          ..moveTo(50 * s, 56 * s)
          ..cubicTo(32 * s, 44 * s, 33 * s, 29 * s, 43 * s, 29 * s)
          ..cubicTo(47 * s, 29 * s, 50 * s, 33 * s, 50 * s, 35 * s)
          ..cubicTo(50 * s, 33 * s, 53 * s, 29 * s, 57 * s, 29 * s)
          ..cubicTo(67 * s, 29 * s, 68 * s, 44 * s, 50 * s, 56 * s)
          ..close();
        canvas.drawPath(heart, fill);
        canvas.drawPath(heart, stroke);
        // Arco acolhedor inferior (mãos em concha)
        canvas.drawArc(
          Rect.fromLTWH(28 * s, 42 * s, 44 * s, 26 * s),
          0.15,
          math.pi - 0.30,
          false,
          accentLine..strokeWidth = 4.2 * s,
        );
        break;

      case 'emergency':
        // Giroflex / Sirene de Resgate Rápido SOS (distinto do raio da categoria Elétrica!)
        final dome = Path()
          ..moveTo(35 * s, 60 * s)
          ..lineTo(38 * s, 38 * s)
          ..arcToPoint(Offset(62 * s, 38 * s), radius: Radius.circular(12 * s))
          ..lineTo(65 * s, 60 * s)
          ..close();
        canvas.drawPath(dome, fill);
        canvas.drawPath(dome, stroke);
        canvas.drawLine(Offset(30 * s, 62 * s), Offset(70 * s, 62 * s), accentLine..strokeWidth = 5.0 * s);
        // Feixes luminosos de emergência
        canvas.drawLine(Offset(50 * s, 21 * s), Offset(50 * s, 26 * s), accentLine..strokeWidth = 3.5 * s);
        canvas.drawLine(Offset(29 * s, 30 * s), Offset(34 * s, 34 * s), accentLine..strokeWidth = 3.5 * s);
        canvas.drawLine(Offset(71 * s, 30 * s), Offset(66 * s, 34 * s), accentLine..strokeWidth = 3.5 * s);
        canvas.drawCircle(Offset(50 * s, 48 * s), 4.8 * s, accent);
        break;

      case 'repeat_clients':
      default:
        // Dois Usuários Conectados + Arco de Recorrência e Estrela
        canvas.drawCircle(Offset(41 * s, 40 * s), 6.5 * s, fill);
        canvas.drawCircle(Offset(41 * s, 40 * s), 6.5 * s, stroke);
        canvas.drawArc(Rect.fromLTWH(29 * s, 50 * s, 24 * s, 16 * s), math.pi, math.pi, false, stroke);

        canvas.drawCircle(Offset(59 * s, 40 * s), 5.8 * s, accent);
        canvas.drawArc(Rect.fromLTWH(49 * s, 51 * s, 20 * s, 14 * s), math.pi, math.pi, false, accentLine);
        // Estrela superior de fidelidade
        canvas.drawCircle(Offset(50 * s, 28 * s), 3.2 * s, accent);
        break;
    }
  }

  Path _regularPolygonPath(Offset center, double radius, int sides, {double rotation = 0}) {
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final a = rotation + (i * 2 * math.pi / sides);
      final pt = Offset(center.dx + radius * math.cos(a), center.dy + radius * math.sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _AchievementMedalForgePainter oldDelegate) =>
      oldDelegate.spec.code != spec.code ||
      oldDelegate.tier != tier ||
      oldDelegate.level != level ||
      oldDelegate.locked != locked ||
      oldDelegate.isDark != isDark;
}

void _drawStar(Canvas canvas, Offset center, double outerR, double innerR, int points, Paint paint) {
  final path = Path();
  _addStarPath(path, center, outerR, innerR, points);
  canvas.drawPath(path, paint);
}

void _addStarPath(Path path, Offset center, double outerR, double innerR, int points) {
  final step = math.pi / points;
  for (int i = 0; i < points * 2; i++) {
    final r = i.isEven ? outerR : innerR;
    final a = (i * step) - math.pi / 2;
    final pt = Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
    if (i == 0) {
      path.moveTo(pt.dx, pt.dy);
    } else {
      path.lineTo(pt.dx, pt.dy);
    }
  }
  path.close();
}

/// Micro-Emblema Duotone (`32x32 dp`) usado no cabeçalho de cada trilha de conquistas.
class AchievementTrackHeaderEmblem extends StatelessWidget {
  const AchievementTrackHeaderEmblem({
    super.key,
    required this.trackCode,
    this.size = 32,
  });

  final String trackCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AchievementMedalForge(
      trackCode: trackCode,
      tier: AchievementTier.gold,
      level: 3,
      size: size,
      locked: false,
    );
  }
}


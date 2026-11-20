import 'package:flutter/material.dart';

import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';

/// Tela informativa 6a: Como funciona a plataforma.
/// Design de alta fidelidade 100% nativo e imutável de alta performance.
/// Focado em reduzir a ansiedade do usuário com gestão de expectativas (48h).
class VerificacaoStep6aComoFuncionaScreen extends StatelessWidget {
  const VerificacaoStep6aComoFuncionaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;

    return AppScaffold(
      backgroundColor: tk.background,
      appBar: AppAppBar(
        title: 'Como funciona',
        leading: AppIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Voltar',
          size: 20,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            layout.margin,
            AppSpace.s20,
            layout.margin,
            AppSpace.s32,
          ),
          child: AppStagger(
            spacing: AppSpace.s24,
            children: [
              // 1. Banner de Expectativa (Informativo e funcional)
              _buildTopAnnouncement(context),
              // 2. Hero Section: Ilustração Premium Nativa
              Center(child: _buildPremiumNativeIllustration(context)),
              // 3. Timeline de Proposta de Valor
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTimelineItem(
                    context,
                    icon: Icons.search_rounded,
                    iconBg: tk.info,
                    title: 'Fique visível',
                    description:
                        'Seu perfil aparece nas buscas de clientes da sua região sempre que você estiver online e disponível.',
                    isLast: false,
                  ),
                  _buildTimelineItem(
                    context,
                    icon: Icons.chat_bubble_outline_rounded,
                    iconBg: tk.accent,
                    title: 'Negocie direto',
                    description:
                        'Receba pedidos de orçamento, converse pelo chat exclusivo do aplicativo e feche o serviço sem burocracia.',
                    isLast: false,
                  ),
                  _buildTimelineItem(
                    context,
                    icon: Icons.shield_outlined,
                    iconBg: tk.success,
                    title: 'Receba com segurança',
                    description:
                        'O pagamento do cliente é garantido pela plataforma. Mais segurança para você, sem riscos de calotes.',
                    isLast: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Banner superior sobre a validação e expectativa de aprovação.
  Widget _buildTopAnnouncement(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      variant: AppCardVariant.tonal,
      borderColor: tk.border,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.s8),
            decoration: BoxDecoration(
              color: tk.card,
              shape: BoxShape.circle,
              boxShadow: tk.elevation(1),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              color: tk.accentInk,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpace.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Validação em andamento (até 48h)',
                  style: AppType.bodyStrong.copyWith(color: tk.accentInk),
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  'Após a análise e validação dos seus documentos, o seu painel será liberado para edição do perfil. Veja como conectaremos você aos clientes:',
                  style: AppType.bodySm.copyWith(color: tk.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Ilustração em Flutter Nativo.
  Widget _buildPremiumNativeIllustration(BuildContext context) {
    final tk = context.tk;
    return SizedBox(
      width: 200,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 20,
            left: 20,
            child: _buildParticle(context, isCross: true),
          ),
          Positioned(
            bottom: 40,
            left: 10,
            child: _buildParticle(context, isCross: false),
          ),
          Positioned(
            top: 60,
            right: 10,
            child: _buildParticle(context, isCross: false),
          ),
          Positioned(
            bottom: 60,
            right: 30,
            child: _buildParticle(context, isCross: true),
          ),
          // O Smartphone
          Container(
            width: 120,
            height: 210,
            decoration: BoxDecoration(
              color: tk.card,
              borderRadius: BorderRadius.circular(AppGeometry.cardRadius + 4),
              border: Border.all(color: tk.accentInk, width: 2.5),
              boxShadow: tk.elevation(2),
            ),
            child: Column(
              children: [
                const SizedBox(height: AppSpace.s12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tk.accentInk.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 100,
                  height: 140,
                  decoration: BoxDecoration(
                    color: tk.surface,
                    borderRadius: BorderRadius.circular(AppSpace.s8),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpace.s12),
                      decoration: BoxDecoration(
                        color: tk.card,
                        shape: BoxShape.circle,
                        boxShadow: tk.elevation(1),
                      ),
                      child: Icon(
                        Icons.handshake_rounded,
                        size: 36,
                        color: tk.accentInk,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tk.accentInk.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Cria as pequenas partículas decorativas (cruzes ou círculos) ao redor do telefone.
  Widget _buildParticle(BuildContext context, {required bool isCross}) {
    final tk = context.tk;
    return isCross
        ? Icon(Icons.add_rounded, size: 16, color: tk.info)
        : Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: tk.success,
              shape: BoxShape.circle,
            ),
          );
  }

  /// Constrói cada item da timeline garantindo conectividade perfeita da linha.
  Widget _buildTimelineItem(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required String title,
    required String description,
    required bool isLast,
  }) {
    final tk = context.tk;
    final onIconBg = AppTokens.onColor(iconBg);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: tk.background, width: 3),
                  boxShadow: tk.elevation(1),
                ),
                child: Icon(icon, color: onIconBg, size: 22),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: tk.border,
                    margin: const EdgeInsets.symmetric(vertical: AppSpace.s4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpace.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpace.s12),
                Text(title, style: AppType.titleSm.copyWith(color: tk.text)),
                const SizedBox(height: AppSpace.s4),
                Text(
                  description,
                  style: AppType.bodySm.copyWith(color: tk.textMuted),
                ),
                if (!isLast) const SizedBox(height: AppSpace.s24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

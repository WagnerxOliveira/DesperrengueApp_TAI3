import 'package:flutter/material.dart';

import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';

/// Tela informativa 6b: Dicas para um bom perfil.
/// Design focado em "Insights" valiosos, utilizando a psicologia das cores
/// para categorizar e facilitar a leitura do usuário durante a espera de análise.
class VerificacaoStep6bDicasScreen extends StatelessWidget {
  const VerificacaoStep6bDicasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;

    return AppScaffold(
      backgroundColor: tk.surface,
      appBar: AppAppBar(
        title: 'Dicas para um bom perfil',
        backgroundColor: tk.background,
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
            spacing: AppSpace.s16,
            children: [
              // 1. Banner Explicativo (Top Announcement) - Justifica a trava de edição
              _buildTopAnnouncement(context),
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s8),
                child: Text(
                  'COMO SE DESTACAR NA PLATAFORMA',
                  style: AppType.overline.copyWith(color: tk.accentInk),
                ),
              ),
              // Cartão 1: A Foto (Azul)
              _buildTipCard(
                context,
                accentColor: tk.info,
                iconBg: tk.infoSoft,
                iconColor: tk.isDark ? tk.info : tk.accentInk,
                icon: Icons.camera_alt_rounded,
                title: 'A foto é o seu cartão de visitas',
                description:
                    'Use uma foto clara, de rosto, sorrindo e em um ambiente bem iluminado. Evite óculos escuros, bonés ou fotos informais demais.',
              ),
              // Cartão 2: A Biografia (Âmbar)
              _buildTipCard(
                context,
                accentColor: tk.warning,
                iconBg: tk.warningSoft,
                iconColor: tk.warningInk,
                icon: Icons.edit_note_rounded,
                title: 'Venda o seu peixe',
                description:
                    'Explique suas especialidades, certificações e tempo de experiência de forma simples e direta. Transmita confiança!',
              ),
              // Cartão 3: O Portfólio (Verde)
              _buildTipCard(
                context,
                accentColor: tk.success,
                iconBg: tk.successSoft,
                iconColor: tk.successInk,
                icon: Icons.photo_library_rounded,
                title: 'Mostre o que você sabe fazer',
                description:
                    'Tire fotos do "antes e depois" dos seus melhores serviços e adicione na sua galeria. Clientes compram resultados visíveis.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Constrói o banner explicativo no topo sobre o andamento e expectativa de aprovação.
  Widget _buildTopAnnouncement(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      variant: AppCardVariant.tonal,
      color: tk.accentSoft,
      borderColor: tk.accentInk.withValues(alpha: 0.2),
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
              Icons.hourglass_top_rounded,
              color: tk.accentInk,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Análise em andamento (até 48h)',
                  style: AppType.bodyStrong.copyWith(color: tk.accentInk),
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  'Assim que seus documentos forem validados, a edição do seu perfil será liberada. Até lá, prepare-se com estas dicas para garantir máxima visibilidade na plataforma.',
                  style: AppType.bodySm.copyWith(color: tk.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói os cartões de dicas com a borda lateral colorida e ícone.
  Widget _buildTipCard(
    BuildContext context, {
    required Color accentColor,
    required Color iconBg,
    required Color iconColor,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final tk = context.tk;
    return AppCard(
      variant: AppCardVariant.elevated,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppGeometry.cardRadius),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accentColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.cardLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpace.s8),
                            decoration: BoxDecoration(
                              color: iconBg,
                              borderRadius: BorderRadius.circular(
                                AppGeometry.iconTileRadius,
                              ),
                            ),
                            child: Icon(icon, color: iconColor, size: 22),
                          ),
                          const SizedBox(width: AppSpace.s12),
                          Expanded(
                            child: Text(
                              title,
                              style: AppType.titleSm.copyWith(color: tk.text),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.s12),
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
        ),
      ),
    );
  }
}

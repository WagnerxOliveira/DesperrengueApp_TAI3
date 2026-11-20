import 'package:flutter/material.dart';

import '../../../core/services/profile_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import 'auth_gate.dart';

/// Tela 7: Celebração de Aprovação (Fim do Onboarding de Verificação)
/// Destino do Deep-Link do e-mail de aprovação.
/// Não possui AppBar com seta de voltar para evitar que o usuário retorne ao estado "Em Análise".
class VerificacaoStep7AprovadoScreen extends StatefulWidget {
  /// Primeiro nome do profissional (vem do perfil no servidor, via PostAuthRouter).
  final String nomeProfissional;

  const VerificacaoStep7AprovadoScreen({
    super.key,
    this.nomeProfissional = 'Profissional',
  });

  @override
  State<VerificacaoStep7AprovadoScreen> createState() =>
      _VerificacaoStep7AprovadoScreenState();
}

class _VerificacaoStep7AprovadoScreenState
    extends State<VerificacaoStep7AprovadoScreen> {
  bool _isActivating = false;

  /// Ativa a conta no servidor (RPC idempotente) e devolve ao AuthGate, que
  /// abrirá o painel do profissional. Funciona mesmo que o e-mail demore:
  /// o deep link apenas reabre o app, a autorização vem da sessão + status.
  Future<void> _ativarConta() async {
    setState(() => _isActivating = true);
    final navigator = Navigator.of(context);

    try {
      await ProfileService().activateProvider();
      navigator.pushAndRemoveUntil(
        AppRoute<void>(builder: (_) => const AuthGate()),
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          'Não foi possível ativar a conta. Tente novamente.',
          kind: AppSnackKind.error,
        );
        setState(() => _isActivating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;

    return AppScaffold(
      backgroundColor: tk.background,
      bottomNavigationBar: AppBottomBar(
        child: AppButton(
          label: 'Configurar Meu Perfil',
          trailingArrow: true,
          loading: _isActivating,
          onPressed: _ativarConta,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            layout.margin,
            AppSpace.s48,
            layout.margin,
            AppSpace.s32,
          ),
          child: AppStagger(
            spacing: AppSpace.s24,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Hero Section (Ilustração de Sucesso Nativa)
              _buildCelebrationHero(context),
              // 2. Copywriting (Mensagem de Impacto)
              Column(
                children: [
                  const AppStatusChip(
                    'Perfil verificado',
                    tone: AppTone.success,
                    icon: Icons.verified_rounded,
                  ),
                  const SizedBox(height: AppSpace.s12),
                  Text(
                    'Tudo pronto, ${widget.nomeProfissional}!',
                    textAlign: TextAlign.center,
                    style: AppType.display.copyWith(color: tk.accentInk),
                  ),
                  const SizedBox(height: AppSpace.s12),
                  Text(
                    'A sua conta foi verificada com sucesso pela nossa equipe. Você acaba de se tornar um parceiro oficial do Desperrengue.',
                    textAlign: TextAlign.center,
                    style: AppType.body.copyWith(color: tk.textMuted),
                  ),
                ],
              ),
              // 3. A Caixa de Direcionamento (Próximo Passo)
              _buildNextStepCard(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Constrói a ilustração do Escudo de Verificação com confetes sutis
  Widget _buildCelebrationHero(BuildContext context) {
    final tk = context.tk;
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 10,
            left: 40,
            child: _buildParticle(Icons.star_rounded, tk.warningInk, 16),
          ),
          Positioned(
            top: 30,
            right: 30,
            child: _buildParticle(Icons.circle, tk.accentInk, 8),
          ),
          Positioned(
            bottom: 50,
            left: 10,
            child: _buildParticle(Icons.square_rounded, tk.accentInk, 10),
          ),
          Positioned(
            bottom: 20,
            right: 40,
            child: _buildParticle(Icons.star_rounded, tk.warningInk, 20),
          ),
          Positioned(
            top: 80,
            left: 10,
            child: _buildParticle(Icons.circle, tk.successInk, 6),
          ),
          Positioned(
            bottom: 80,
            right: 10,
            child: _buildParticle(Icons.square_rounded, tk.warningInk, 8),
          ),
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: tk.surface,
              shape: BoxShape.circle,
              boxShadow: tk.elevation(2),
            ),
            child: Icon(
              Icons.shield_outlined,
              size: 80,
              color: tk.accentInk,
            ),
          ),
          Positioned(
            bottom: 25,
            right: 25,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: tk.successInk,
                shape: BoxShape.circle,
                border: Border.all(color: tk.background, width: 4),
                boxShadow: tk.elevation(1),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 32,
                color: AppTokens.onColor(tk.successInk),
                weight: 800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Gera pequenas formas geométricas decorativas
  Widget _buildParticle(IconData icon, Color color, double size) {
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: 0.5,
        child: Icon(icon, color: color, size: size),
      ),
    );
  }

  /// Cartão de instrução para o próximo passo (Configuração do perfil)
  Widget _buildNextStepCard(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      variant: AppCardVariant.tonal,
      borderColor: tk.border,
      padding: const EdgeInsets.all(AppSpace.cardLarge),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.s12),
            decoration: BoxDecoration(
              color: tk.card,
              borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
              boxShadow: tk.elevation(1),
            ),
            child: Icon(
              Icons.handyman_rounded,
              color: tk.accentInk,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpace.s16),
          Expanded(
            child: Text(
              'Para começar a aparecer nas buscas e receber pedidos, precisamos configurar os detalhes do seu perfil profissional.',
              style: AppType.bodySm.copyWith(
                fontWeight: FontWeight.w500,
                color: tk.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

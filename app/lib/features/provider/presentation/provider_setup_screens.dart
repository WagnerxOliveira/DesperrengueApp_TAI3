import 'package:flutter/material.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/widgets.dart';
import 'provider_profile_screens.dart';

/// Cadastro inicial do PROFISSIONAL (após o KYC ser ativado):
/// 1) perfil (foto, bio, especialidades, preços) 2) portfólio 3) conclusão.
/// Substitui os 4 arquivos `profile_setup` que estavam vazios.
class ProviderSetupFlow extends StatefulWidget {
  const ProviderSetupFlow({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<ProviderSetupFlow> createState() => _ProviderSetupFlowState();
}

class _ProviderSetupFlowState extends State<ProviderSetupFlow> {
  int _step = 0;
  bool _saving = false;

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await ProfileService().completeSetup(UserMode.provider);
      AppSession.instance.refreshProfile();
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    switch (_step) {
      case 0:
        return EditProviderProfileScreen(setupMode: true, onDone: () => setState(() => _step = 1));
      case 1:
        return PortfolioScreen(setupMode: true, onDone: () => setState(() => _step = 2));
      default:
        return AppScaffold(
          appBar: const AppAppBar(automaticallyImplyLeading: false, titleWidget: BrandLogo()),
          body: ListView(
            padding: EdgeInsets.symmetric(horizontal: context.layout.margin, vertical: AppSpace.s24),
            children: [
              const AppStepper(total: 3, current: 3),
              const SizedBox(height: AppSpace.s24),
              Center(
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: tk.successSoft,
                  child: Icon(Icons.rocket_launch_rounded, size: 50, color: tk.successInk),
                ),
              ),
              const SizedBox(height: AppSpace.s20),
              Text(
                'Tudo pronto, ${widget.profile.firstName}!',
                textAlign: TextAlign.center,
                style: AppType.display.copyWith(color: tk.text),
              ),
              const SizedBox(height: AppSpace.s12),
              Text(
                'Seu perfil está no ar. Agora você recebe solicitações de clientes da sua região e pode enviar orçamentos.',
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: tk.textMuted),
              ),
              const SizedBox(height: AppSpace.s24),
              const InfoBanner(
                'Você pode editar foto, bio, especialidades e portfólio quando quiser, em Perfil.',
                tone: BannerTone.info,
              ),
              const SizedBox(height: AppSpace.s12),
              const InfoBanner(
                'Também pode usar o app como cliente a qualquer momento: basta trocar de modo na tela inicial.',
                tone: BannerTone.promo,
                icon: Icons.swap_horiz_rounded,
              ),
            ],
          ),
          bottomNavigationBar: AppBottomBar(
            child: AppButton(
              label: 'Ir para o meu painel',
              trailingArrow: true,
              loading: _saving,
              onPressed: _finish,
            ),
          ),
        );
    }
  }
}

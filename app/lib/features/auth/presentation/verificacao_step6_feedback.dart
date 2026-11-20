import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import 'auth_gate.dart';
import 'verificacao_step6a_como_funciona.dart';
import 'verificacao_step6b_dicas.dart';
import 'verificacao_step6c_termos.dart';

/// Tela 6: Feedback de Envio de Documentos e Espera de KYC (Em Análise).
/// Atua como uma barreira de segurança e central educativa para o prestador.
///
/// Consulta o status no servidor a cada [_pollInterval] e também sob demanda
/// (botão). Assim que o status deixa de ser PENDING, devolve o controle ao
/// [AuthGate], que abre a tela correta (aprovado ou reenvio, se rejeitado).
class VerificacaoStep6FeedbackScreen extends StatefulWidget {
  const VerificacaoStep6FeedbackScreen({super.key});

  @override
  State<VerificacaoStep6FeedbackScreen> createState() =>
      _VerificacaoStep6FeedbackScreenState();
}

class _VerificacaoStep6FeedbackScreenState
    extends State<VerificacaoStep6FeedbackScreen> {
  static const Duration _pollInterval = Duration(seconds: 8);

  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_pollInterval, (_) => _checkStatus(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus({bool silent = false}) async {
    if (_checking) return;
    setState(() => _checking = true);

    try {
      final profile = await ProfileService().fetchCurrent();
      if (!mounted) return;

      if (profile != null &&
          profile.verificationStatus != VerificationStatus.pending) {
        _timer?.cancel();
        Navigator.pushAndRemoveUntil(
          context,
          AppRoute<void>(builder: (context) => const AuthGate()),
          (route) => false,
        );
        return;
      }

      if (!silent) {
        _showInfo(
          'Seu perfil ainda está em análise. Avisaremos por e-mail assim que for aprovado (até 48 horas úteis).',
        );
      }
    } catch (_) {
      if (!silent) {
        _showInfo('Não foi possível consultar o status. Verifique a conexão.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showInfo(String message) {
    AppSnackbar.show(context, message, kind: AppSnackKind.info);
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    await ProfileService().signOut();
    navigator.pushAndRemoveUntil(
      AppRoute<void>(builder: (context) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;

    return AppScaffold(
      backgroundColor: tk.background,
      appBar: AppAppBar(
        title: 'Desperrengue',
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s8),
            child: Text(
              'Validação de Perfil',
              style: AppType.bodySm.copyWith(
                color: tk.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomBar(
        secondary: AppButton(
          label: 'Sair da conta',
          variant: AppButtonVariant.tertiary,
          onPressed: _signOut,
        ),
        child: AppButton(
          label: 'Verificar status agora',
          icon: Icons.refresh_rounded,
          loading: _checking,
          onPressed: () => _checkStatus(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            layout.margin,
            AppSpace.s24,
            layout.margin,
            AppSpace.s24,
          ),
          child: AppStagger(
            spacing: AppSpace.s16,
            children: [
              Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: tk.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.folder_shared_rounded,
                      size: 48,
                      color: tk.accentInk,
                    ),
                  ),
                  const SizedBox(height: AppSpace.s20),
                  const AppStatusChip(
                    'Em análise · até 48h úteis',
                    tone: AppTone.info,
                    icon: Icons.schedule_rounded,
                  ),
                  const SizedBox(height: AppSpace.s12),
                  Text(
                    'Documentação em Análise',
                    textAlign: TextAlign.center,
                    style: AppType.headline.copyWith(color: tk.text),
                  ),
                  const SizedBox(height: AppSpace.s8),
                  Text(
                    'A nossa equipa está a rever as suas informações. Receberá uma notificação assim que o seu perfil for aprovado (até 48 horas úteis).',
                    textAlign: TextAlign.center,
                    style: AppType.bodySm.copyWith(color: tk.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s8),
              AppCard(
                variant: AppCardVariant.outlined,
                padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
                child: Column(
                  children: [
                    AppListTile(
                      leadingIcon: Icons.play_circle_outline_rounded,
                      title: 'Como funciona a plataforma',
                      showChevron: true,
                      onTap: () => _openInfoScreen(
                        const VerificacaoStep6aComoFuncionaScreen(),
                      ),
                    ),
                    Divider(height: 1, color: tk.border),
                    AppListTile(
                      leadingIcon: Icons.lightbulb_outline_rounded,
                      title: 'Dicas para um bom perfil',
                      showChevron: true,
                      onTap: () => _openInfoScreen(
                        const VerificacaoStep6bDicasScreen(),
                      ),
                    ),
                    Divider(height: 1, color: tk.border),
                    AppListTile(
                      leadingIcon: Icons.description_outlined,
                      title: 'Leia os nossos Termos de Prestação de Serviços',
                      showChevron: true,
                      onTap: () => _openInfoScreen(
                        const VerificacaoStep6cTermosScreen(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openInfoScreen(Widget targetScreen) {
    Navigator.push(
      context,
      AppRoute<void>(builder: (context) => targetScreen),
    );
  }
}

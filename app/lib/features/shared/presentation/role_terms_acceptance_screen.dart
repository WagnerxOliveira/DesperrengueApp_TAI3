import 'package:flutter/material.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/legal_mandate_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/widgets.dart';

/// Tela de aceite de Termos de Uso específicos por perfil (**Cliente** ou **Profissional**)
/// com ativação rápida (Fast-Track) que reaproveita a Identidade Biométrica, o Documento
/// Oficial e a Certidão de Antecedentes Criminais já aprovados dentro da janela de 6 meses,
/// sem pedir novo envio de documentos e sem gerar nova cobrança de verificação.
class RoleTermsAcceptanceScreen extends StatefulWidget {
  const RoleTermsAcceptanceScreen({
    super.key,
    required this.profile,
    required this.mode,
    this.isReuseFastTrack = true,
    @visibleForTesting this.customActivator,
  });

  final UserProfile profile;
  final UserMode mode;
  final bool isReuseFastTrack;
  final Future<void> Function(UserMode targetMode)? customActivator;

  @override
  State<RoleTermsAcceptanceScreen> createState() =>
      _RoleTermsAcceptanceScreenState();
}

class _RoleTermsAcceptanceScreenState extends State<RoleTermsAcceptanceScreen> {
  bool _accepted = false;
  bool _submitting = false;
  String? _error;

  static String _formatDateBr(DateTime? dt) {
    final target = dt ?? DateTime.now().add(const Duration(days: 90));
    final d = target.day.toString().padLeft(2, '0');
    final m = target.month.toString().padLeft(2, '0');
    final y = target.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  void _backToPreviousMode() {
    if (!widget.isReuseFastTrack) {
      Navigator.of(context).maybePop(false);
      return;
    }
    final previousMode = widget.mode == UserMode.client
        ? UserMode.provider
        : UserMode.client;
    AppSession.instance.choose(previousMode);
  }

  Future<void> _confirmAndActivate() async {
    if (!_accepted || _submitting) return;

    if (!widget.isReuseFastTrack) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (widget.customActivator != null) {
        await widget.customActivator!(widget.mode);
      } else {
        await ProfileService().activateRoleReusingValidKyc(widget.mode);
      }
      AppSession.instance.choose(widget.mode);
      AppSession.instance.refreshProfile();
    } catch (e) {
      if (!mounted) return;
      final msg = friendlyError(e);
      setState(() => _error = msg);
      AppSnackbar.show(context, msg, kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.onboarding(Theme.of(context).brightness),
      child: Builder(builder: (themedCtx) => _buildScaffold(themedCtx)),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    final isClientTarget = widget.mode == UserMode.client;
    final clauses = LegalMandateService.clausesForMode(widget.mode);
    final version = LegalMandateService.versionForMode(widget.mode);
    final sha256Hex = LegalMandateService.sha256ForMode(widget.mode);
    final validUntilStr = _formatDateBr(widget.profile.effectiveKycExpiresAt);

    final headingTitle = isClientTarget
        ? 'Termos de Uso e Proteção do Cliente Desperrengue'
        : 'Termos de Parceria e Cláusula-Mandato do Profissional Desperrengue';

    final fastTrackBadgeTitle = isClientTarget
        ? 'Identidade, Biometria e Antecedentes já aprovados (válidos até $validUntilStr)'
        : 'Seus documentos, biometria facial e antecedentes já estão aprovados até $validUntilStr — sem novo envio e sem nova cobrança de validação';

    final fastTrackBadgeBody = isClientTarget
        ? 'Você não precisa enviar documentos nem alterar nenhum dado. Basta confirmar os Termos de Uso do Cliente abaixo para começar.'
        : 'Aproveitamos 100% da sua validação como Cliente. Nenhum novo documento ou foto será solicitado — aceite os Termos do Profissional para configurar suas especialidades.';

    final confirmButtonLabel = !widget.isReuseFastTrack
        ? 'Confirmar Leitura e Aceitar Termos'
        : (isClientTarget
              ? 'Aceitar Termos e Entrar como Cliente'
              : 'Aceitar Termos e Configurar Perfil Profissional');

    return AppScaffold(
      backgroundColor: tk.background,
      appBar: AppAppBar(
        title: isClientTarget
            ? 'Ativar Modo Cliente'
            : 'Ativar Modo Profissional',
        leading: AppIconButton(
          key: const ValueKey('btn-back-previous-mode'),
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Voltar ao modo anterior',
          size: 20,
          onPressed: _backToPreviousMode,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          layout.margin,
          AppSpace.s12,
          layout.margin,
          AppSpace.s24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isReuseFastTrack) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  label: 'Voltar ao modo anterior',
                  icon: Icons.swap_horiz_rounded,
                  variant: AppButtonVariant.tertiary,
                  expand: false,
                  onPressed: _backToPreviousMode,
                ),
              ),
              const SizedBox(height: AppSpace.s8),
              AppCard(
                key: const ValueKey('fast-track-kyc-reused-banner'),
                variant: AppCardVariant.tonal,
                color: tk.successSoft,
                borderColor: tk.success,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          color: tk.successInk,
                          size: 26,
                        ),
                        const SizedBox(width: AppSpace.s12),
                        Expanded(
                          child: Text(
                            fastTrackBadgeTitle,
                            style: AppType.bodyStrong.copyWith(
                              color: tk.successInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s8),
                    Text(
                      fastTrackBadgeBody,
                      style: AppType.bodySm.copyWith(color: tk.successInk),
                    ),
                    const SizedBox(height: AppSpace.s12),
                    const Wrap(
                      spacing: AppSpace.s8,
                      runSpacing: AppSpace.s8,
                      children: [
                        AppStatusChip(
                          'Zero Reenvio de Documentos',
                          tone: AppTone.success,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                        AppStatusChip(
                          'Zero Nova Cobrança de Validação',
                          tone: AppTone.success,
                          icon: Icons.savings_outlined,
                        ),
                        AppStatusChip(
                          'Vigência Oficial de 90 Dias',
                          tone: AppTone.info,
                          icon: Icons.shield_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s20),
            ],
            Text(
              headingTitle,
              style: AppType.headline.copyWith(color: tk.text),
            ),
            const SizedBox(height: AppSpace.s8),
            Text(
              'Versão vigente: $version · Titular: ${widget.profile.officialCivilName} · LGPD, CDC e Ciclo 90 dias',
              style: AppType.caption.copyWith(color: tk.textMuted),
            ),
            const SizedBox(height: AppSpace.s16),
            for (final clause in clauses)
              AppCard(
                margin: const EdgeInsets.only(bottom: AppSpace.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clause.title,
                      style: AppType.titleSm.copyWith(color: tk.text),
                    ),
                    const SizedBox(height: AppSpace.s8),
                    Text(
                      clause.body,
                      style: AppType.bodySm.copyWith(
                        color: tk.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            AppCard(
              variant: AppCardVariant.tonal,
              borderColor: tk.border,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selo Digital de Integridade Contratual (SHA-256)',
                    style: AppType.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tk.text,
                    ),
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    sha256Hex,
                    style: AppType.tabular(AppType.caption).copyWith(
                      color: tk.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.s16),
              InfoBanner(_error!, tone: BannerTone.danger),
            ],
            const SizedBox(height: AppSpace.s16),
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('checkbox-accept-role-terms'),
                borderRadius: BorderRadius.circular(AppGeometry.cardRadius),
                onTap: () => setState(() => _accepted = !_accepted),
                child: AnimatedContainer(
                  duration: AppMotion.d(context, AppMotion.fade),
                  padding: const EdgeInsets.all(AppSpace.s12),
                  decoration: BoxDecoration(
                    color: _accepted ? tk.successSoft : tk.card,
                    borderRadius: BorderRadius.circular(AppGeometry.cardRadius),
                    border: Border.all(
                      color: _accepted ? tk.success : tk.border,
                      width: _accepted ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _accepted,
                        activeColor: tk.success,
                        checkColor: AppTokens.onColor(tk.success),
                        onChanged: (v) =>
                            setState(() => _accepted = v ?? false),
                      ),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpace.s8),
                          child: Text(
                            isClientTarget
                                ? 'Li e concordo integralmente com os Termos de Uso e Proteção do Cliente Desperrengue (incluindo LGPD, Custódia Protegida, PIN de 4 dígitos, Garantia de 90 dias, Política Anticontorno e Renovação de Segurança a cada 90 dias).'
                                : 'Li e concordo integralmente com os Termos de Parceria e Cláusula-Mandato do Profissional Desperrengue (incluindo Autonomia Art. 442-B CLT, Mandato Art. 653 CC, 0% de taxa sobre peças com NF-e, LGPD, Garantia de 90 dias e Renovação de Segurança a cada 90 dias).',
                            style: AppType.bodySm.copyWith(
                              fontWeight: _accepted
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: tk.text,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomBar(
        child: AppButton(
          key: const ValueKey('btn-confirm-role-terms'),
          label: confirmButtonLabel,
          loading: _submitting,
          trailingArrow: true,
          onPressed: (_accepted && !_submitting) ? _confirmAndActivate : null,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/legal_mandate_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/app_tokens.dart';
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
    final target = dt ?? DateTime.now().add(const Duration(days: 180));
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
      showSnack(context, msg, error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
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
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('btn-back-previous-mode'),
          tooltip: 'Voltar ao modo anterior',
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _backToPreviousMode,
        ),
        title: Text(
          isClientTarget ? 'Ativar Modo Cliente' : 'Ativar Modo Profissional',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          if (widget.isReuseFastTrack)
            TextButton(
              onPressed: _backToPreviousMode,
              child: const Text('Voltar ao modo anterior'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isReuseFastTrack) ...[
              Container(
                key: const ValueKey('fast-track-kyc-reused-banner'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tk.successSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tk.success, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          color: tk.success,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            fastTrackBadgeTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              color: tk.successInk,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fastTrackBadgeBody,
                      style: TextStyle(
                        fontSize: 13,
                        color: tk.successInk,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        StatusChip(
                          'Zero Reenvio de Documentos',
                          color: tk.success,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                        StatusChip(
                          'Zero Nova Cobrança de Validação',
                          color: tk.success,
                          icon: Icons.savings_outlined,
                        ),
                        StatusChip(
                          'Vigência de 6 Meses Ativa',
                          color: tk.security,
                          icon: Icons.shield_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            Text(
              headingTitle,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Versão vigente: $version · Titular: ${widget.profile.officialCivilName}',
              style: TextStyle(fontSize: 12.5, color: tk.textMuted),
            ),
            const SizedBox(height: 16),
            for (final clause in clauses)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clause.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        clause.body,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: tk.textMuted,
                          height: 1.48,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tk.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tk.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selo Digital de Integridade Contratual (SHA-256)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: tk.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sha256Hex,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: tk.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              InfoBanner(_error!, tone: BannerTone.danger),
            ],
            const SizedBox(height: 16),
            InkWell(
              key: const ValueKey('checkbox-accept-role-terms'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _accepted = !_accepted),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accepted ? tk.successSoft : tk.card,
                  borderRadius: BorderRadius.circular(14),
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
                      onChanged: (v) => setState(() => _accepted = v ?? false),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          isClientTarget
                              ? 'Li e concordo com os Termos de Uso e Proteção do Cliente Desperrengue (incluindo Custódia Protegida, PIN de 4 dígitos, Garantia de 90 dias e Renovação Semestral de Segurança).'
                              : 'Li e concordo com os Termos de Parceria e Cláusula-Mandato do Profissional Desperrengue (incluindo Mandato Art. 653 CC, 0% de taxa sobre peças com NF-e, Garantia de 90 dias e Renovação Semestral de Segurança).',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _accepted
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: tk.text,
                            height: 1.38,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomBar(
        child: PrimaryButton(
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

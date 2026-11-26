import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/widgets.dart';
import '../../client/presentation/widgets/kyc_onboarding_chrome.dart';
import 'auth_gate.dart';

/// Tela pós-cadastro **"Verifique seu e-mail"** exibida tanto para **Clientes**
/// quanto para **Profissionais** assim que a conta é aprovada na auditoria
/// biométrica/documental.
///
/// - Envia / reenvia o e-mail real de aprovação via Resend (`enviar-email-aprovacao`);
/// - Suporta ativação automática pelo link `desperrengue://onboarding/ativar` no e-mail
///   OU confirmação direta pelo botão principal (`confirm_account_approval_email`);
/// - Estilizada com a paleta **Safira Real & Porcelana** (`AppTheme.onboarding`),
///   tipografia responsiva (`Plus Jakarta Sans` + `Inter`) e zero overflow.
class VerifyApprovalEmailScreen extends StatefulWidget {
  const VerifyApprovalEmailScreen({
    super.key,
    required this.profile,
    required this.mode,
    this.emailAddressOverride,
    this.autoTriggerInitialSend = false,
    @visibleForTesting this.customConfirmAction,
    @visibleForTesting this.customResendAction,
    @visibleForTesting this.customSignOutAction,
  });

  final UserProfile profile;
  final UserMode mode;
  final String? emailAddressOverride;
  final bool autoTriggerInitialSend;
  final Future<void> Function()? customConfirmAction;
  final Future<bool> Function()? customResendAction;
  final Future<void> Function()? customSignOutAction;

  @override
  State<VerifyApprovalEmailScreen> createState() =>
      _VerifyApprovalEmailScreenState();
}

class _VerifyApprovalEmailScreenState extends State<VerifyApprovalEmailScreen>
    with SingleTickerProviderStateMixin {
  static const int _resendCooldownSec = 45;

  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  bool _confirming = false;
  bool _resending = false;
  bool _resentSuccess = false;
  int _cooldownSeconds = 0;
  String? _error;
  Timer? _cooldownTimer;

  String get _resolvedEmail {
    final override = widget.emailAddressOverride?.trim() ?? '';
    if (override.isNotEmpty) return override;
    final fromProfile = widget.profile.emailAddressIfPresent?.trim() ?? '';
    if (fromProfile.isNotEmpty) return fromProfile;
    try {
      final authEmail = Supabase.instance.client.auth.currentUser?.email?.trim() ?? '';
      if (authEmail.isNotEmpty) return authEmail;
    } catch (_) {}
    return 'seu e-mail cadastrado';
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoTriggerInitialSend &&
        widget.profile.approvalEmailSentAt == null) {
      unawaited(_resendEmail(silentInitial: true));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 1.0;
    } else if (_pulseCtrl.status == AnimationStatus.dismissed) {
      _pulseCtrl.forward();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = _resendCooldownSec);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds -= 1);
      }
    });
  }

  Future<void> _confirmEmailAndEnter() async {
    if (_confirming) return;
    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      if (widget.customConfirmAction != null) {
        await widget.customConfirmAction!();
      } else {
        await ProfileService().confirmAccountApprovalEmail();
        AppSession.instance.refreshProfile();
      }
    } catch (e) {
      if (!mounted) return;
      final msg = friendlyError(e);
      setState(() => _error = msg);
      AppSnackbar.show(context, msg, kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _resendEmail({bool silentInitial = false}) async {
    if (_resending || _cooldownSeconds > 0) return;
    setState(() {
      _resending = true;
      if (!silentInitial) _error = null;
    });
    try {
      final bool sent = widget.customResendAction != null
          ? await widget.customResendAction!()
          : await ProfileService().sendApprovalEmail(targetMode: widget.mode);
      if (!mounted) return;
      if (sent) {
        setState(() => _resentSuccess = true);
        _startCooldown();
        if (!silentInitial) {
          AppSnackbar.show(
            context,
            'E-mail de aprovação reenviado! Confira sua caixa de entrada e a pasta de spam.',
            kind: AppSnackKind.success,
          );
        }
      } else if (!silentInitial) {
        setState(
          () => _error =
              'Não foi possível reenviar agora. Tente novamente em instantes ou toque em "Já validei meu e-mail".',
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (!silentInitial) {
        setState(() => _error = friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _signOut() async {
    if (widget.customSignOutAction != null) {
      await widget.customSignOutAction!();
      return;
    }
    final navigator = Navigator.of(context);
    await ProfileService().signOut();
    navigator.pushAndRemoveUntil(
      AppRoute<void>(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Theme(
      data: AppTheme.onboarding(brightness),
      child: Builder(
        builder: (themedContext) => _buildScaffold(themedContext),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    final bool isProvider = widget.mode == UserMode.provider;
    final String firstName = widget.profile.firstName == 'você'
        ? ''
        : widget.profile.firstName;
    final String greetingPrefix = firstName.isEmpty ? '' : '$firstName, ';
    final String roleLabel = isProvider ? 'Profissional' : 'Cliente';
    final String validUntilStr = _formatExpiryDate(
      widget.profile.effectiveKycExpiresAt,
    );

    return AppScaffold(
      backgroundColor: tk.background,
      appBar: AppAppBar(
        titleWidget: const BrandLogo(),
        actions: [
          AppButton(
            key: const ValueKey('btn-verify-email-sign-out'),
            label: 'Sair',
            variant: AppButtonVariant.tertiary,
            expand: false,
            compact: true,
            onPressed: _signOut,
          ),
        ],
      ),
      body: KycAmbientBackdrop(
        isProviderMode: false,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              layout.margin,
              AppSpace.s16,
              layout.margin,
              AppSpace.s24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppGeometry.maxColumnWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Cartão Hero Editorial de Aprovação + E-mail
                    AppCard(
                      key: const ValueKey('verify-approval-email-hero'),
                      variant: AppCardVariant.elevated,
                      radius: AppGeometry.heroRadius,
                      borderColor: tk.accentInk.withValues(
                        alpha: tk.isDark ? 0.36 : 0.22,
                      ),
                      padding: const EdgeInsets.all(AppSpace.cardLarge),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _AnimatedMailApprovalEmblem(
                            pulse: _pulseCtrl,
                          ),
                          const SizedBox(height: AppSpace.s20),
                          Wrap(
                            spacing: AppSpace.s8,
                            runSpacing: AppSpace.s8,
                            alignment: WrapAlignment.center,
                            children: [
                              AppStatusChip(
                                'Conta $roleLabel Aprovada',
                                key: const ValueKey('chip-account-approved'),
                                tone: AppTone.success,
                                icon: Icons.verified_rounded,
                              ),
                              AppStatusChip(
                                'Validade 90 dias',
                                tone: AppTone.info,
                                icon: Icons.shield_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.s16),
                          Semantics(
                            header: true,
                            child: Text(
                              'Verifique seu e-mail',
                              textAlign: TextAlign.center,
                              style: AppType.display.copyWith(color: tk.text),
                            ),
                          ),
                          const SizedBox(height: AppSpace.s8),
                          Text(
                            isProvider
                                ? '${greetingPrefix}sua identidade e certidão foram aprovadas! Enviamos um e-mail oficial de aprovação para você confirmar e ativar sua conta de Profissional.'
                                : '${greetingPrefix}sua identidade e certidão foram aprovadas! Enviamos um e-mail oficial de aprovação para você validar e liberar o uso completo do aplicativo.',
                            textAlign: TextAlign.center,
                            style: AppType.body.copyWith(
                              color: tk.textMuted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: AppSpace.s20),
                          // Pílula de destaque com o e-mail de destino
                          Container(
                            key: const ValueKey('verify-email-address-pill'),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.s16,
                              vertical: AppSpace.s12,
                            ),
                            decoration: BoxDecoration(
                              color: tk.accentSoft,
                              borderRadius: BorderRadius.circular(
                                AppGeometry.fieldRadius,
                              ),
                              border: Border.all(
                                color: tk.accentInk.withValues(
                                  alpha: tk.isDark ? 0.35 : 0.24,
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.mark_email_unread_outlined,
                                  size: 20,
                                  color: tk.accentInk,
                                ),
                                const SizedBox(width: AppSpace.s12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'E-mail de aprovação enviado para',
                                        style: AppType.caption.copyWith(
                                          color: tk.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpace.s2),
                                      Text(
                                        _resolvedEmail,
                                        style: AppType.bodyStrong.copyWith(
                                          color: tk.accentInk,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.s16),

                    // 2. Guia rápido de 3 passos (Zero atrito cognitivo)
                    KycPorcelainSectionCard(
                      title: 'Como ativar em 10 segundos',
                      subtitle:
                          'Validação válida até $validUntilStr · Avisaremos por e-mail antes do vencimento de 90 dias.',
                      icon: Icons.mark_email_read_outlined,
                      statusChipLabel: _resentSuccess ? 'Reenviado' : 'Pronto',
                      statusTone:
                          _resentSuccess ? AppTone.success : AppTone.info,
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          KycNumberedStepRow(
                            stepNumber: '1',
                            icon: Icons.inbox_outlined,
                            title: 'Abra sua caixa de entrada',
                            description:
                                'Procure o e-mail oficial da Desperrengue ("Sua conta foi aprovada"). Se não aparecer em 1 minuto, verifique Spam ou Promoções.',
                            showConnector: true,
                          ),
                          KycNumberedStepRow(
                            stepNumber: '2',
                            icon: Icons.touch_app_outlined,
                            title: 'Toque no botão do e-mail',
                            description:
                                'Clique em "Confirmar e Ativar Conta" no e-mail para validar seu endereço automaticamente.',
                            showConnector: true,
                          ),
                          KycNumberedStepRow(
                            stepNumber: '3',
                            icon: Icons.rocket_launch_outlined,
                            title: 'Volte ao app e aproveite',
                            description:
                                'Se já abriu o e-mail em outro dispositivo, toque no botão principal abaixo para liberar seu acesso agora.',
                          ),
                        ],
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: AppSpace.s16),
                      InfoBanner(_error!, tone: BannerTone.danger),
                    ],

                    const SizedBox(height: AppSpace.s16),

                    // 3. Reenvio com cooldown de 45s
                    AppButton(
                      key: const ValueKey('btn-resend-approval-email'),
                      label: _cooldownSeconds > 0
                          ? 'Reenviar e-mail em ${_cooldownSeconds}s'
                          : 'Reenviar e-mail de aprovação',
                      icon: Icons.send_outlined,
                      variant: AppButtonVariant.secondary,
                      loading: _resending,
                      onPressed: (_resending || _cooldownSeconds > 0)
                          ? null
                          : _resendEmail,
                    ),
                    const SizedBox(height: AppSpace.s12),
                    Text(
                      'Protegemos sua conta com confirmação de e-mail e renovação de segurança a cada 90 dias.',
                      textAlign: TextAlign.center,
                      style: AppType.caption.copyWith(color: tk.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomBar(
        child: AppButton(
          key: const ValueKey('btn-confirm-approval-email'),
          label: isProvider
              ? 'Já validei meu e-mail — Configurar perfil'
              : 'Já validei meu e-mail — Entrar no app',
          trailingArrow: true,
          loading: _confirming,
          onPressed: _confirming ? null : _confirmEmailAndEnter,
        ),
      ),
    );
  }

  static String _formatExpiryDate(DateTime? dt) {
    final target = dt ?? DateTime.now().add(const Duration(days: 90));
    final d = target.day.toString().padLeft(2, '0');
    final m = target.month.toString().padLeft(2, '0');
    final y = target.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }
}

class _AnimatedMailApprovalEmblem extends StatelessWidget {
  const _AnimatedMailApprovalEmblem({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final double glowAlpha =
            (tk.isDark ? 0.16 : 0.12) + (pulse.value * 0.08);
        return SizedBox(
          width: 108,
          height: 108,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      tk.accent.withValues(alpha: glowAlpha),
                      tk.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tk.accentSoft,
                  border: Border.all(
                    color: tk.accentInk.withValues(
                      alpha: tk.isDark ? 0.45 : 0.25,
                    ),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.mark_email_read_rounded,
                  size: 36,
                  color: tk.accentInk,
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tk.success,
                    border: Border.all(color: tk.card, width: 2.5),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppTokens.onColor(tk.success),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

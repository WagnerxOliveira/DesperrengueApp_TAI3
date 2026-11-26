import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/storage/local_prefs.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/widgets.dart';
import '../../client/presentation/widgets/kyc_onboarding_chrome.dart';
import 'auth_gate.dart';

/// Tela **"Verifique seu e-mail"** — portão de ativação de contas novas
/// (**Cliente** e **Profissional**).
///
/// REGRA DE SEGURANÇA: o app NÃO libera a conta por conta própria. A conta só abre
/// quando o usuário toca em **"Confirmar e Ativar Minha Conta"** dentro do e-mail
/// oficial (token único de 256 bits, validado no servidor). Esta tela:
///  * envia/reenvia o e-mail (com reserva atômica anti-duplicidade no servidor);
///  * consulta o servidor a cada poucos segundos, ao voltar do e-mail (retomada do
///    app) e ao tocar em "Já confirmei no e-mail — Verificar";
///  * ao detectar a confirmação, pede ao roteador que recarregue o perfil: ele
///    mostra a tela de boas-vindas (`AccountActivatedWelcomeScreen`) e entra no app.
class VerifyApprovalEmailScreen extends StatefulWidget {
  const VerifyApprovalEmailScreen({
    super.key,
    required this.profile,
    required this.mode,
    this.emailAddressOverride,
    this.autoTriggerInitialSend = false,
    this.pollInterval = const Duration(seconds: 4),
    @visibleForTesting this.customGateCheck,
    @visibleForTesting this.customResendAction,
    @visibleForTesting this.customSignOutAction,
    @visibleForTesting this.onGateOpened,
  });

  final UserProfile profile;
  final UserMode mode;
  final String? emailAddressOverride;
  final bool autoTriggerInitialSend;

  /// Intervalo da verificação automática (null desliga, útil em testes).
  final Duration? pollInterval;

  /// Substitui a consulta ao servidor: `true` = conta liberada pelo e-mail.
  final Future<bool> Function()? customGateCheck;
  final Future<ApprovalEmailSendOutcome> Function()? customResendAction;
  final Future<void> Function()? customSignOutAction;

  /// Chamado quando o portão abre (padrão: recarregar o perfil no roteador).
  final VoidCallback? onGateOpened;

  @override
  State<VerifyApprovalEmailScreen> createState() =>
      _VerifyApprovalEmailScreenState();
}

class _VerifyApprovalEmailScreenState extends State<VerifyApprovalEmailScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const int _resendCooldownSec = 45;

  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  bool _checking = false;
  bool _polling = false;
  bool _resending = false;
  bool _resentSuccess = false;
  bool _gateOpened = false;
  int _cooldownSeconds = 0;
  String? _error;
  String? _info;
  Timer? _cooldownTimer;
  Timer? _pollTimer;

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
    WidgetsBinding.instance.addObserver(this);
    // Garante a tela de boas-vindas depois da ativação, mesmo se o app for fechado
    // enquanto o usuário abre o e-mail.
    if (widget.profile.id.isNotEmpty) {
      unawaited(
        LocalPrefs.markActivationWelcomePending(widget.profile.id, widget.mode),
      );
    }
    final interval = widget.pollInterval;
    if (interval != null) {
      _pollTimer = Timer.periodic(interval, (_) => _checkGate(silent: true));
    }
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Usuário voltou do e-mail para o app: confere na hora, sem esperar o próximo ciclo.
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkGate(silent: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
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

  /// Pergunta ao servidor se o botão do e-mail já foi tocado. NUNCA altera dados.
  Future<void> _checkGate({bool silent = false}) async {
    if (_gateOpened) return;
    // Verificação automática nunca atropela outra em andamento; o toque do usuário
    // sempre executa (e mostra o carregamento no botão).
    if (silent ? (_polling || _checking) : _checking) return;
    if (silent) {
      _polling = true;
    } else {
      setState(() {
        _checking = true;
        _error = null;
        _info = null;
      });
    }
    var open = false;
    try {
      open = widget.customGateCheck != null
          ? await widget.customGateCheck!()
          : await ProfileService().isApprovalGateOpen();
    } catch (_) {
      open = false;
    }
    _polling = false;
    if (!mounted) return;
    if (!silent) setState(() => _checking = false);
    if (open) {
      if (_gateOpened) return;
      _gateOpened = true;
      _pollTimer?.cancel();
      if (widget.onGateOpened != null) {
        widget.onGateOpened!();
      } else {
        AppSession.instance.refreshProfile();
      }
      return;
    }
    if (!silent) {
      setState(
        () => _info =
            'Ainda não identificamos a confirmação. Abra o e-mail e toque em "Confirmar e Ativar Minha Conta".',
      );
    }
  }

  Future<void> _resendEmail({bool silentInitial = false}) async {
    if (_resending || _cooldownSeconds > 0) return;
    setState(() {
      _resending = true;
      if (!silentInitial) {
        _error = null;
        _info = null;
      }
    });
    try {
      final outcome = widget.customResendAction != null
          ? await widget.customResendAction!()
          : await ProfileService().sendApprovalEmail(targetMode: widget.mode);
      if (!mounted) return;
      switch (outcome) {
        case ApprovalEmailSendOutcome.sent:
          setState(() => _resentSuccess = true);
          _startCooldown();
          if (!silentInitial) {
            AppSnackbar.show(
              context,
              'E-mail reenviado! Confira a caixa de entrada e a pasta de spam.',
              kind: AppSnackKind.success,
            );
          }
        case ApprovalEmailSendOutcome.cooldown:
          setState(() => _resentSuccess = true);
          _startCooldown();
          if (!silentInitial) {
            setState(
              () => _info =
                  'Acabamos de enviar o e-mail. Confira a caixa de entrada e o spam — pode levar até 1 minuto.',
            );
          }
        case ApprovalEmailSendOutcome.alreadyConfirmed:
          unawaited(_checkGate(silent: true));
        case ApprovalEmailSendOutcome.failed:
          if (!silentInitial) {
            setState(
              () => _error =
                  'Não foi possível reenviar agora. Verifique a conexão e tente novamente.',
            );
          }
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
    final String firstName =
        widget.profile.firstName == 'você' ? '' : widget.profile.firstName;
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
                          _AnimatedMailApprovalEmblem(pulse: _pulseCtrl),
                          const SizedBox(height: AppSpace.s20),
                          Wrap(
                            spacing: AppSpace.s8,
                            runSpacing: AppSpace.s8,
                            alignment: WrapAlignment.center,
                            children: [
                              AppStatusChip(
                                'Conta $roleLabel aprovada',
                                key: const ValueKey('chip-account-approved'),
                                tone: AppTone.success,
                                icon: Icons.verified_rounded,
                              ),
                              const AppStatusChip(
                                'Falta 1 passo',
                                tone: AppTone.info,
                                icon: Icons.mark_email_unread_outlined,
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
                            '${greetingPrefix}sua identidade e sua certidão foram aprovadas! Enviamos um e-mail oficial para você. '
                            'Sua conta só é liberada depois que você tocar em “Confirmar e Ativar Minha Conta” dentro dele.',
                            textAlign: TextAlign.center,
                            style: AppType.body.copyWith(
                              color: tk.textMuted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: AppSpace.s20),
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
                                        'E-mail enviado para',
                                        style: AppType.bodySm.copyWith(
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
                          const SizedBox(height: AppSpace.s12),
                          Row(
                            key: const ValueKey('verify-email-waiting-row'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.hourglass_top_rounded,
                                  size: 18,
                                  color: tk.textMuted,
                                ),
                              ),
                              const SizedBox(width: AppSpace.s8),
                              Flexible(
                                child: Text(
                                  'Aguardando sua confirmação. Verificamos automaticamente — assim que você tocar no botão do e-mail, liberamos seu acesso.',
                                  textAlign: TextAlign.center,
                                  style: AppType.bodySm.copyWith(
                                    color: tk.textMuted,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.s16),
                    KycPorcelainSectionCard(
                      title: 'Como ativar em 10 segundos',
                      subtitle:
                          'Validação de segurança válida até $validUntilStr (renovação a cada 90 dias).',
                      icon: Icons.mark_email_read_outlined,
                      statusChipLabel:
                          _resentSuccess ? 'E-mail enviado' : 'Pronto',
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
                                'Procure o e-mail da Desperrengue. Se não aparecer em 1 minuto, confira Spam ou Promoções.',
                            showConnector: true,
                          ),
                          KycNumberedStepRow(
                            stepNumber: '2',
                            icon: Icons.touch_app_outlined,
                            title: 'Toque em “Confirmar e Ativar Minha Conta”',
                            description:
                                'É esse toque que libera sua conta. Sem ele, o aplicativo continua bloqueado.',
                            showConnector: true,
                          ),
                          KycNumberedStepRow(
                            stepNumber: '3',
                            icon: Icons.rocket_launch_outlined,
                            title: 'Volte ao app',
                            description:
                                'Detectamos a confirmação sozinhos e você entra com uma mensagem de boas-vindas.',
                          ),
                        ],
                      ),
                    ),
                    if (_info != null) ...[
                      const SizedBox(height: AppSpace.s16),
                      InfoBanner(
                        _info!,
                        key: const ValueKey('verify-email-info'),
                        tone: BannerTone.info,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: AppSpace.s16),
                      InfoBanner(_error!, tone: BannerTone.danger),
                    ],
                    const SizedBox(height: AppSpace.s16),
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
                      'Por segurança, só o botão do e-mail ativa sua conta. O link é pessoal, vale por 72 horas e só pode ser usado uma vez.',
                      textAlign: TextAlign.center,
                      style: AppType.bodySm.copyWith(color: tk.textMuted),
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
          key: const ValueKey('btn-check-approval-email'),
          label: 'Já confirmei no e-mail — Verificar',
          icon: Icons.mark_email_read_outlined,
          loading: _checking,
          onPressed: _checking ? null : () => _checkGate(),
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
                  Icons.mark_email_unread_rounded,
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

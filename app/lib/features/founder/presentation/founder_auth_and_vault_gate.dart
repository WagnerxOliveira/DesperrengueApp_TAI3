/// Porta de Entrada Exclusiva do `Desperrengue CEO` — Design *Luxo Silencioso Executivo*.
///
/// Regras de Segurança e Ergonomia:
/// - **Zero Cross-App OAuth**: nenhum botão abre navegador externo ou redireciona ao app público.
/// - **Zero campos pré-preenchidos**: todos os campos iniciam 100% vazios (`''`).
/// - **Teto Físico de 64 Caracteres + Senha Forte**: entre 12 e 64 caracteres, maiúscula,
///   minúscula, número e símbolo especial, sem nomes próprios ou sequências simples.
/// - **Acesso Único**: exclusivo para `wagneroliveira2395@gmail.com`.
/// - **Zero Poluição Visual**: linguagem 100% clara e humana, sem jargões técnicos e sem
///   teclado duplicado competindo com o teclado nativo do celular.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/analytics/founder_dashboard_models.dart';
import '../data/founder_cockpit_repository.dart';
import '../domain/ceo_smart_otp_formatter.dart';
import '../domain/ceo_strong_password_policy.dart';
import '../domain/founder_deep_link_policy.dart';
import 'founder_animations_and_shaders.dart';

enum CeoSovereignAuthStage {
  stageInspectingSovereignState,
  stageBootstrapRequestEmail,
  stageBootstrapVerifyOtp,
  stageBootstrapCreateMasterPassword,
  stageDailyLoginCredentials,
  stageDailyLoginVerifyOtp,
  stagePasswordResetFromDeepLink,
}

class FounderAuthAndVaultGate extends StatefulWidget {
  const FounderAuthAndVaultGate({
    super.key,
    required this.repository,
    required this.onVaultUnlocked,
    this.pendingResetGrant,
    this.onResetGrantConsumed,
    this.lockReasonBanner,
  });

  final FounderCockpitRepository repository;
  final Future<void> Function(FounderStepUpSession session) onVaultUnlocked;
  final FounderResetLinkGrant? pendingResetGrant;
  final VoidCallback? onResetGrantConsumed;
  final String? lockReasonBanner;

  @override
  State<FounderAuthAndVaultGate> createState() =>
      _FounderAuthAndVaultGateState();
}

class _FounderAuthAndVaultGateState extends State<FounderAuthAndVaultGate>
    with WidgetsBindingObserver {
  // Todos os controladores iniciam estritamente vazios (Zero pre-filled fields!)
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  Timer? _countdownTimer;

  CeoSovereignAuthStage _stage =
      CeoSovereignAuthStage.stageInspectingSovereignState;
  bool _busy = false;
  bool _obscurePrimaryPassword = true;
  bool _obscureConfirmPassword = true;

  CeoOtpChallengeTicket? _activeOtpTicket;
  String? _enrollmentTicketHex;

  int _otpCooldownRemainingSec = 0;
  DateTime? _vaultLockedUntilUtc;
  int _vaultLockRemainingSec = 0;
  int? _remainingOtpAttempts;

  String? _errorBanner;
  String? _infoBanner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _infoBanner = widget.lockReasonBanner;
    _ensureCountdownTicker();

    if (widget.pendingResetGrant != null) {
      _stage = CeoSovereignAuthStage.stagePasswordResetFromDeepLink;
    } else {
      unawaited(_inspectInitialSovereignState());
    }
  }

  @override
  void didUpdateWidget(covariant FounderAuthAndVaultGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextGrant = widget.pendingResetGrant;
    if (nextGrant != null &&
        nextGrant.linkId != oldWidget.pendingResetGrant?.linkId) {
      _wipePasswordBuffers(triggerRebuild: false);
      _otpController.clear();
      setState(() {
        _errorBanner = null;
        _infoBanner =
            'Link confirmado! Escolha abaixo sua nova senha exclusiva.';
        _stage = CeoSovereignAuthStage.stagePasswordResetFromDeepLink;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _wipePasswordBuffers();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _wipePasswordBuffers(triggerRebuild: false);
    _emailController.clear();
    _otpController.clear();
    _otpFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _wipePasswordBuffers({bool triggerRebuild = true}) {
    _passwordController.clear();
    _confirmPasswordController.clear();
    if (triggerRebuild && mounted) {
      setState(() {});
    }
  }

  void _ensureCountdownTicker() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      var changed = false;
      if (_otpCooldownRemainingSec > 0) {
        _otpCooldownRemainingSec--;
        changed = true;
      }
      if (_vaultLockedUntilUtc != null) {
        final rem = _vaultLockedUntilUtc!
            .difference(DateTime.now().toUtc())
            .inSeconds;
        final clamped = rem > 0 ? rem : 0;
        if (clamped != _vaultLockRemainingSec) {
          _vaultLockRemainingSec = clamped;
          if (clamped == 0) _vaultLockedUntilUtc = null;
          changed = true;
        }
      }
      if (changed) setState(() {});
    });
  }

  void _applyLockedUntil(DateTime? utc) {
    if (utc == null) return;
    final rem = utc.difference(DateTime.now().toUtc()).inSeconds;
    if (rem > 0) {
      _vaultLockedUntilUtc = utc;
      _vaultLockRemainingSec = rem;
    }
  }

  Future<void> _inspectInitialSovereignState() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _errorBanner = null;
    });

    try {
      final gate = await widget.repository.inspectSovereignGate();
      if (!mounted) return;
      if (widget.pendingResetGrant != null) {
        setState(() {
          _busy = false;
          _stage = CeoSovereignAuthStage.stagePasswordResetFromDeepLink;
        });
        return;
      }

      _applyLockedUntil(gate.lockedUntilUtc);

      final expectedPurpose = gate.passwordConfigured
          ? 'LOGIN_2FA'
          : 'INITIAL_PASSWORD_SETUP';
      final restoredTicket = await widget.repository.loadValidPendingOtpTicket(
        expectedPurpose: expectedPurpose,
      );
      if (!mounted) return;

      if (restoredTicket != null) {
        setState(() {
          _busy = false;
          _activeOtpTicket = restoredTicket;
          _infoBanner =
              'Seu código ainda está valendo. Digite ou cole os 6 números enviados ao seu e-mail.';
          _stage = gate.passwordConfigured
              ? CeoSovereignAuthStage.stageDailyLoginVerifyOtp
              : CeoSovereignAuthStage.stageBootstrapVerifyOtp;
        });
        return;
      }

      setState(() {
        _busy = false;
        _stage = gate.passwordConfigured
            ? CeoSovereignAuthStage.stageDailyLoginCredentials
            : CeoSovereignAuthStage.stageBootstrapRequestEmail;
      });
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner = e.userMessagePt;
        _stage = CeoSovereignAuthStage.stageDailyLoginCredentials;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = CeoSovereignAuthStage.stageDailyLoginCredentials;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // PRIMEIRO ACESSO (CRIAÇÃO INICIAL DA SENHA EXCLUSIVA)
  // ---------------------------------------------------------------------------

  Future<void> _handleBootstrapSendOtp({bool isResend = false}) async {
    if (_busy || _otpCooldownRemainingSec > 0) return;
    final rawTyped = _emailController.text.trim().toLowerCase();
    final typedEmail = (isResend && rawTyped.isEmpty)
        ? kMonocraticCeoEmail
        : rawTyped;
    if (typedEmail.isEmpty) {
      setState(() {
        _errorBanner =
            'Digite seu e-mail ($kMonocraticCeoEmail) para receber o código de 6 números.';
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _busy = true;
      _errorBanner = null;
      _infoBanner = null;
    });

    try {
      final ticket = await widget.repository.requestInitialBootstrapOtp(
        email: typedEmail,
      );
      if (!mounted) return;
      _otpController.clear();
      setState(() {
        _busy = false;
        _activeOtpTicket = ticket;
        _otpCooldownRemainingSec = ticket.nextCooldownSeconds;
        _remainingOtpAttempts = null;
        _infoBanner = isResend
            ? 'Enviamos um novo código para $kMonocraticCeoEmail. Use o e-mail mais recente.'
            : 'Enviamos o código de 6 números para $kMonocraticCeoEmail.';
        _stage = CeoSovereignAuthStage.stageBootstrapVerifyOtp;
      });
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      if (e.errorCode == 'ERR_VAULT_ALREADY_SEALED') {
        setState(() {
          _busy = false;
          _infoBanner = e.userMessagePt;
          _stage = CeoSovereignAuthStage.stageDailyLoginCredentials;
        });
        return;
      }
      if (e.retryAfterSeconds != null) {
        _otpCooldownRemainingSec = e.retryAfterSeconds!;
      }
      setState(() {
        _busy = false;
        _errorBanner = e.userMessagePt;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner = e.toString();
      });
    }
  }

  Future<void> _handleBootstrapVerifyOtp() async {
    final ticket = _activeOtpTicket;
    final digits =
        CeoSmartOtpExtractor.extractBestSixDigits(_otpController.text);
    if (_busy || ticket == null) return;
    if (digits.length != 6) {
      setState(() {
        _errorBanner =
            'Digite os 6 números enviados para $kMonocraticCeoEmail.';
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _busy = true;
      _errorBanner = null;
    });
    _otpController.clear();

    try {
      final enrollmentTicket =
          await widget.repository.verifyInitialBootstrapOtp(
        challengeId: ticket.challengeId,
        sixDigitCode: digits,
      );
      if (!mounted) return;
      _wipePasswordBuffers(triggerRebuild: false);
      setState(() {
        _busy = false;
        _activeOtpTicket = null;
        _enrollmentTicketHex = enrollmentTicket;
        _infoBanner =
            'Código confirmado! Crie agora sua senha exclusiva de acesso.';
        _stage = CeoSovereignAuthStage.stageBootstrapCreateMasterPassword;
      });
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _remainingOtpAttempts = e.remainingAttempts;
        _errorBanner = e.userMessagePt;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner = e.toString();
      });
    }
  }

  Future<void> _handleCreateInitialMasterPassword() async {
    final ticketHex = _enrollmentTicketHex;
    final pw = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    if (_busy || ticketHex == null) return;

    final evaluation = CeoStrongPasswordPolicy.evaluate(pw);
    if (!evaluation.isApproved) {
      setState(() {
        _errorBanner = evaluation.primaryRejectionMessagePt;
      });
      return;
    }
    if (pw != confirm) {
      setState(() {
        _errorBanner = 'As duas senhas digitadas precisam ser iguais.';
      });
      return;
    }

    HapticFeedback.heavyImpact();
    _wipePasswordBuffers(triggerRebuild: false);
    setState(() {
      _busy = true;
      _errorBanner = null;
    });

    try {
      final session = await widget.repository.createInitialMasterPassword(
        enrollmentTicketHex: ticketHex,
        masterPassword: pw,
      );
      if (!mounted) return;
      _enrollmentTicketHex = null;
      await widget.onVaultUnlocked(session);
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner = e.userMessagePt;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner = e.toString();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // ENTRADA DO DIA A DIA (SENHA + CÓDIGO RÁPIDO DE 6 DÍGITOS NO E-MAIL)
  // ---------------------------------------------------------------------------

  Future<void> _handleDailyLoginStep1() async {
    if (_busy || _vaultLockRemainingSec > 0) return;
    final typedEmail = _emailController.text.trim().toLowerCase();
    final typedPassword = _passwordController.text;

    if (typedEmail.isEmpty || typedPassword.isEmpty) {
      setState(() {
        _errorBanner = 'Preencha seu e-mail e sua senha para continuar.';
      });
      return;
    }

    HapticFeedback.mediumImpact();
    _wipePasswordBuffers(triggerRebuild: false);
    setState(() {
      _busy = true;
      _errorBanner = null;
      _infoBanner = null;
    });

    try {
      final ticket =
          await widget.repository.verifyMasterPasswordAndRequestLoginOtp(
        email: typedEmail,
        masterPassword: typedPassword,
      );
      if (!mounted) return;
      _otpController.clear();
      setState(() {
        _busy = false;
        _activeOtpTicket = ticket;
        _otpCooldownRemainingSec = ticket.nextCooldownSeconds;
        _remainingOtpAttempts = null;
        _infoBanner =
            'Senha correta! Enviamos o código de 6 números para $kMonocraticCeoEmail.';
        _stage = CeoSovereignAuthStage.stageDailyLoginVerifyOtp;
      });
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      if (e.errorCode == 'ERR_MASTER_PASSWORD_NOT_CONFIGURED') {
        setState(() {
          _busy = false;
          _infoBanner =
              'Você ainda não criou sua senha. Confirme seu e-mail abaixo para criar agora.';
          _stage = CeoSovereignAuthStage.stageBootstrapRequestEmail;
        });
        return;
      }
      _applyLockedUntil(e.lockedUntilUtc);
      if (e.retryAfterSeconds != null) {
        _otpCooldownRemainingSec = e.retryAfterSeconds!;
      }
      setState(() {
        _busy = false;
        _errorBanner = e.userMessagePt;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner = e.toString();
      });
    }
  }

  Future<void> _handleResendLoginOtp() async {
    final prev = _activeOtpTicket;
    if (_busy || prev == null || _otpCooldownRemainingSec > 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      _busy = true;
      _errorBanner = null;
    });

    try {
      final fresh = await widget.repository.resendLoginTwoFactorOtp(
        previousChallengeId: prev.challengeId,
      );
      if (!mounted) return;
      _otpController.clear();
      setState(() {
        _busy = false;
        _activeOtpTicket = fresh;
        _otpCooldownRemainingSec = fresh.nextCooldownSeconds;
        _infoBanner =
            'Enviamos um novo código para $kMonocraticCeoEmail. Use o último e-mail recebido.';
      });
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      if (e.retryAfterSeconds != null) {
        _otpCooldownRemainingSec = e.retryAfterSeconds!;
      }
      setState(() {
        _busy = false;
        _errorBanner = e.userMessagePt;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner = e.toString();
      });
    }
  }

  Future<void> _handleDailyLoginVerifyOtp() async {
    final ticket = _activeOtpTicket;
    final digits =
        CeoSmartOtpExtractor.extractBestSixDigits(_otpController.text);
    if (_busy || ticket == null) return;
    if (digits.length != 6) {
      setState(() {
        _errorBanner =
            'Digite os 6 números enviados para $kMonocraticCeoEmail.';
      });
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _busy = true;
      _errorBanner = null;
    });
    _otpController.clear();

    try {
      final session = await widget.repository.completeLoginTwoFactor(
        challengeId: ticket.challengeId,
        sixDigitCode: digits,
      );
      if (!mounted) return;
      _activeOtpTicket = null;
      await widget.onVaultUnlocked(session);
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _remainingOtpAttempts = e.remainingAttempts;
        _errorBanner = e.userMessagePt;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner = e.toString();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // TROCA DE SENHA PELO LINK EXCLUSIVO DO E-MAIL
  // ---------------------------------------------------------------------------

  Future<void> _handleCommitPasswordResetFromDeepLink() async {
    final grant = widget.pendingResetGrant;
    final pw = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    if (_busy || grant == null) return;

    final evaluation = CeoStrongPasswordPolicy.evaluate(pw);
    if (!evaluation.isApproved) {
      setState(() {
        _errorBanner = evaluation.primaryRejectionMessagePt;
      });
      return;
    }
    if (pw != confirm) {
      setState(() {
        _errorBanner = 'As duas senhas digitadas precisam ser iguais.';
      });
      return;
    }

    HapticFeedback.heavyImpact();
    _wipePasswordBuffers(triggerRebuild: false);
    setState(() {
      _busy = true;
      _errorBanner = null;
    });

    try {
      await widget.repository.commitPasswordResetFromDeepLink(
        linkId: grant.linkId,
        grantTokenHex: grant.grantTokenHex,
        newMasterPassword: pw,
      );
      if (!mounted) return;
      widget.onResetGrantConsumed?.call();
      _emailController.clear();
      _otpController.clear();
      setState(() {
        _busy = false;
        _activeOtpTicket = null;
        _infoBanner =
            'Nova senha salva com sucesso! Entre agora usando sua senha nova.';
        _stage = CeoSovereignAuthStage.stageDailyLoginCredentials;
      });
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      if (e.errorCode.contains('RESET_LINK')) {
        widget.onResetGrantConsumed?.call();
      }
      setState(() {
        _busy = false;
        _errorBanner = e.userMessagePt;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner = e.toString();
      });
    }
  }

  Future<void> _handlePasteOtpFromClipboard() async {
    if (_busy) return;
    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = clip?.text ?? '';
      final extracted =
          CeoSmartOtpExtractor.extractSixDigitClusterOrNull(raw) ??
              CeoSmartOtpExtractor.extractBestSixDigits(raw);
      if (!mounted) return;
      if (extracted.isEmpty) {
        setState(() {
          _errorBanner =
              'Não encontramos nenhum número copiado. Copie o código do e-mail primeiro.';
        });
        return;
      }
      HapticFeedback.lightImpact();
      _otpController.text = extracted;
      _otpController.selection =
          TextSelection.collapsed(offset: extracted.length);
      setState(() {
        _errorBanner = null;
      });
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // INTERFACE LIMPA — LUXO SILENCIOSO EXECUTIVO
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey<String>('founder-sovereign-auth-gate-scaffold'),
      backgroundColor: FounderSovereignTokens.obsidianBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildCleanBrandHero(),
                  const SizedBox(height: 22),
                  FounderGlassCard(
                    padding: const EdgeInsets.all(22),
                    showTopAccentBar: true,
                    accentTopBarColor: FounderSovereignTokens.imperialGold,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (_infoBanner != null) ...<Widget>[
                          _buildBanner(
                            message: _infoBanner!,
                            borderColor: FounderSovereignTokens.solvencyEmerald
                                .withValues(alpha: 0.45),
                            bgColor: FounderSovereignTokens.solvencyEmeraldSoft,
                            icon: Icons.check_circle_outline_rounded,
                            iconColor: FounderSovereignTokens.solvencyEmerald,
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (_errorBanner != null) ...<Widget>[
                          _buildBanner(
                            message: _errorBanner!,
                            borderColor: FounderSovereignTokens.crimsonAlert
                                .withValues(alpha: 0.55),
                            bgColor: FounderSovereignTokens.crimsonAlertSoft,
                            icon: Icons.error_outline_rounded,
                            iconColor: FounderSovereignTokens.crimsonAlert,
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (_vaultLockRemainingSec > 0) ...<Widget>[
                          _buildBanner(
                            message:
                                'Por segurança, aguarde ${_vaultLockRemainingSec}s para tentar novamente.',
                            borderColor: FounderSovereignTokens.warmAmber
                                .withValues(alpha: 0.5),
                            bgColor: FounderSovereignTokens.warmAmber
                                .withValues(alpha: 0.12),
                            icon: Icons.timer_outlined,
                            iconColor: FounderSovereignTokens.warmAmber,
                          ),
                          const SizedBox(height: 14),
                        ],
                        _buildCurrentStageContent(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCleanBrandHero() {
    return Column(
      children: <Widget>[
        const FounderSovereignCrest(size: 58),
        const SizedBox(height: 12),
        Text(
          'Desperrengue CEO',
          textAlign: TextAlign.center,
          style: FounderSovereignTokens.titleStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Painel exclusivo da direção',
          textAlign: TextAlign.center,
          style: FounderSovereignTokens.subtitleStyle(
            fontSize: 13,
            color: FounderSovereignTokens.mutedInk,
          ),
        ),
      ],
    );
  }

  Widget _buildBanner({
    required String message,
    required Color borderColor,
    required Color bgColor,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: FounderSovereignTokens.primaryInk,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStageContent() {
    switch (_stage) {
      case CeoSovereignAuthStage.stageInspectingSovereignState:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: <Widget>[
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Preparando seu acesso seguro…',
                textAlign: TextAlign.center,
                style: FounderSovereignTokens.subtitleStyle(fontSize: 13),
              ),
            ],
          ),
        );

      case CeoSovereignAuthStage.stageBootstrapRequestEmail:
        return _buildBootstrapRequestEmailView();

      case CeoSovereignAuthStage.stageBootstrapVerifyOtp:
        return _buildSixDigitOtpView(
          stepBadge: 'Primeiro acesso · Passo 1 de 2',
          headline: 'Digite o código de 6 números',
          subtitle:
              'Enviamos um código para $kMonocraticCeoEmail. Digite abaixo ou toque em "Colar código".',
          submitButtonKey: const ValueKey<String>(
            'ceo-bootstrap-verify-otp-btn',
          ),
          submitLabel: 'Confirmar código',
          onSubmit: _handleBootstrapVerifyOtp,
          onResend: () => _handleBootstrapSendOtp(isResend: true),
          onBack: () {
            _otpController.clear();
            unawaited(widget.repository.clearPendingOtpTicket());
            setState(() {
              _errorBanner = null;
              _activeOtpTicket = null;
              _stage = CeoSovereignAuthStage.stageBootstrapRequestEmail;
            });
          },
        );

      case CeoSovereignAuthStage.stageBootstrapCreateMasterPassword:
        return _buildCreateOrResetPasswordView(
          stepBadge: 'Primeiro acesso · Passo 2 de 2',
          headline: 'Crie sua senha exclusiva',
          subtitle:
              'Você usará esta senha sempre que abrir o Desperrengue CEO.',
          newPasswordFieldKey: const ValueKey<String>(
            'ceo-create-password-input',
          ),
          confirmPasswordFieldKey: const ValueKey<String>(
            'ceo-confirm-password-input',
          ),
          submitButtonKey: const ValueKey<String>(
            'ceo-save-initial-password-btn',
          ),
          submitLabel: 'Salvar senha e entrar',
          onSubmit: _handleCreateInitialMasterPassword,
        );

      case CeoSovereignAuthStage.stageDailyLoginCredentials:
        return _buildDailyLoginCredentialsView();

      case CeoSovereignAuthStage.stageDailyLoginVerifyOtp:
        return _buildSixDigitOtpView(
          stepBadge: 'Confirmação de entrada',
          headline: 'Digite o código de 6 números',
          subtitle:
              'Acabamos de enviar o código para $kMonocraticCeoEmail para confirmar sua entrada.',
          submitButtonKey: const ValueKey<String>('ceo-login-verify-otp-btn'),
          submitLabel: 'Confirmar e entrar no painel',
          onSubmit: _handleDailyLoginVerifyOtp,
          onResend: _handleResendLoginOtp,
          onBack: () {
            _otpController.clear();
            _wipePasswordBuffers(triggerRebuild: false);
            unawaited(widget.repository.clearPendingOtpTicket());
            setState(() {
              _errorBanner = null;
              _activeOtpTicket = null;
              _stage = CeoSovereignAuthStage.stageDailyLoginCredentials;
            });
          },
        );

      case CeoSovereignAuthStage.stagePasswordResetFromDeepLink:
        return _buildCreateOrResetPasswordView(
          stepBadge: 'Troca de senha autorizada',
          headline: 'Escolha sua nova senha',
          subtitle:
              'Depois de salvar, você usará esta nova senha para entrar no painel.',
          newPasswordFieldKey: const ValueKey<String>(
            'ceo-reset-new-password-input',
          ),
          confirmPasswordFieldKey: const ValueKey<String>(
            'ceo-reset-confirm-password-input',
          ),
          submitButtonKey: const ValueKey<String>(
            'ceo-reset-commit-password-btn',
          ),
          submitLabel: 'Salvar nova senha',
          onSubmit: _handleCommitPasswordResetFromDeepLink,
          onCancel: () {
            _wipePasswordBuffers(triggerRebuild: false);
            widget.onResetGrantConsumed?.call();
            unawaited(_inspectInitialSovereignState());
          },
        );
    }
  }

  Widget _buildBootstrapRequestEmailView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _StepEyebrow('Primeiro acesso'),
        const SizedBox(height: 8),
        Text(
          'Vamos criar sua senha',
          style: FounderSovereignTokens.titleStyle(fontSize: 19),
        ),
        const SizedBox(height: 6),
        Text(
          'Confirme seu e-mail abaixo. Vamos enviar um código rápido de 6 números para liberar a criação da sua senha.',
          style: FounderSovereignTokens.subtitleStyle(fontSize: 13),
        ),
        const SizedBox(height: 18),
        _buildSovereignEmailField(
          fieldKey: const ValueKey<String>('ceo-bootstrap-email-input'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey<String>('ceo-bootstrap-send-otp-btn'),
          onPressed: (_busy || _otpCooldownRemainingSec > 0)
              ? null
              : () => _handleBootstrapSendOtp(),
          style: FilledButton.styleFrom(
            backgroundColor: FounderSovereignTokens.imperialGold,
            foregroundColor: const Color(0xFF0B0E14),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0B0E14),
                  ),
                )
              : Text(
                  _otpCooldownRemainingSec > 0
                      ? 'Aguarde ${_otpCooldownRemainingSec}s'
                      : 'Enviar código de 6 números',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _busy
              ? null
              : () {
                  setState(() {
                    _errorBanner = null;
                    _stage = CeoSovereignAuthStage.stageDailyLoginCredentials;
                  });
                },
          child: const Text(
            'Já criei minha senha — ir para entrada',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyLoginCredentialsView() {
    final charCount = _passwordController.text.runes.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _StepEyebrow('Acesso exclusivo'),
        const SizedBox(height: 8),
        Text(
          'Bem-vindo, Wagner',
          style: FounderSovereignTokens.titleStyle(fontSize: 19),
        ),
        const SizedBox(height: 6),
        Text(
          'Informe seu e-mail e sua senha para receber o código rápido de entrada.',
          style: FounderSovereignTokens.subtitleStyle(fontSize: 13),
        ),
        const SizedBox(height: 18),
        _buildSovereignEmailField(
          fieldKey: const ValueKey<String>('ceo-login-email-input'),
        ),
        const SizedBox(height: 14),
        _SovereignPasswordField(
          fieldKey: const ValueKey<String>('ceo-login-password-input'),
          controller: _passwordController,
          labelText: 'Sua senha de acesso',
          obscureText: _obscurePrimaryPassword,
          onToggleObscure: () => setState(
            () => _obscurePrimaryPassword = !_obscurePrimaryPassword,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _handleDailyLoginStep1(),
        ),
        if (charCount > 0) ...<Widget>[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$charCount / ${CeoStrongPasswordPolicy.maxLength}',
              key: const ValueKey<String>('ceo-login-password-char-counter'),
              style: FounderSovereignTokens.monoMetric(
                fontSize: 11,
                color: FounderSovereignTokens.mutedInk,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton(
          key: const ValueKey<String>('ceo-login-submit-btn'),
          onPressed: (_busy || _vaultLockRemainingSec > 0)
              ? null
              : _handleDailyLoginStep1,
          style: FilledButton.styleFrom(
            backgroundColor: FounderSovereignTokens.imperialGold,
            foregroundColor: const Color(0xFF0B0E14),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0B0E14),
                  ),
                )
              : const Text(
                  'Continuar',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
        ),
      ],
    );
  }

  Widget _buildCreateOrResetPasswordView({
    required String stepBadge,
    required String headline,
    required String subtitle,
    required Key newPasswordFieldKey,
    required Key confirmPasswordFieldKey,
    required Key submitButtonKey,
    required String submitLabel,
    required VoidCallback onSubmit,
    VoidCallback? onCancel,
  }) {
    final pw = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    final evaluation = CeoStrongPasswordPolicy.evaluate(pw);
    final passwordsMatch = pw.isNotEmpty && pw == confirm;
    final canSubmit = !_busy && evaluation.isApproved && passwordsMatch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StepEyebrow(stepBadge),
        const SizedBox(height: 8),
        Text(
          headline,
          style: FounderSovereignTokens.titleStyle(fontSize: 19),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: FounderSovereignTokens.subtitleStyle(fontSize: 13),
        ),
        const SizedBox(height: 18),
        _SovereignPasswordField(
          fieldKey: newPasswordFieldKey,
          controller: _passwordController,
          labelText: 'Sua senha (12 a 64 caracteres)',
          obscureText: _obscurePrimaryPassword,
          onToggleObscure: () => setState(
            () => _obscurePrimaryPassword = !_obscurePrimaryPassword,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                evaluation.tierLabelPt,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: evaluation.isApproved
                      ? FounderSovereignTokens.solvencyEmerald
                      : FounderSovereignTokens.mutedInk,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${evaluation.charCount} / ${CeoStrongPasswordPolicy.maxLength}',
              key: const ValueKey<String>('ceo-password-char-counter'),
              style: FounderSovereignTokens.monoMetric(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: evaluation.lengthInRange
                    ? FounderSovereignTokens.solvencyEmerald
                    : FounderSovereignTokens.mutedInk,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: evaluation.normalizedProgress,
            backgroundColor: FounderSovereignTokens.obsidianSurface,
            color: evaluation.isApproved
                ? FounderSovereignTokens.solvencyEmerald
                : FounderSovereignTokens.imperialGold,
          ),
        ),
        const SizedBox(height: 14),
        _SovereignPasswordField(
          fieldKey: confirmPasswordFieldKey,
          controller: _confirmPasswordController,
          labelText: 'Repita a senha para confirmar',
          obscureText: _obscureConfirmPassword,
          onToggleObscure: () => setState(
            () => _obscureConfirmPassword = !_obscureConfirmPassword,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (canSubmit) onSubmit();
          },
        ),
        const SizedBox(height: 14),
        _PasswordRequirementsChecklist(
          evaluation: evaluation,
          passwordsMatch: passwordsMatch,
          hasConfirmationInput: confirm.isNotEmpty,
        ),
        const SizedBox(height: 18),
        FilledButton(
          key: submitButtonKey,
          onPressed: canSubmit ? onSubmit : null,
          style: FilledButton.styleFrom(
            backgroundColor: FounderSovereignTokens.imperialGold,
            foregroundColor: const Color(0xFF0B0E14),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0B0E14),
                  ),
                )
              : Text(
                  submitLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        if (onCancel != null) ...<Widget>[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : onCancel,
            child: const Text('Cancelar'),
          ),
        ],
      ],
    );
  }

  Widget _buildSixDigitOtpView({
    required String stepBadge,
    required String headline,
    required String subtitle,
    required Key submitButtonKey,
    required String submitLabel,
    required VoidCallback onSubmit,
    required VoidCallback onResend,
    required VoidCallback onBack,
  }) {
    final digits =
        CeoSmartOtpExtractor.extractBestSixDigits(_otpController.text);
    final activeRef = _activeOtpTicket?.challengeRef;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StepEyebrow(stepBadge),
        const SizedBox(height: 8),
        Text(
          headline,
          style: FounderSovereignTokens.titleStyle(fontSize: 19),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: FounderSovereignTokens.subtitleStyle(fontSize: 13),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            if (activeRef != null && activeRef.isNotEmpty)
              Container(
                key: const ValueKey<String>('ceo-otp-protocol-ref-badge'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: FounderSovereignTokens.obsidianSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: FounderSovereignTokens.crispBorder),
                ),
                child: Text(
                  'Vale por 10 min · #$activeRef',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: FounderSovereignTokens.mutedInk,
                  ),
                ),
              ),
            OutlinedButton.icon(
              key: const ValueKey<String>('ceo-otp-paste-btn'),
              onPressed: _busy ? null : _handlePasteOtpFromClipboard,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                side: BorderSide(
                  color: FounderSovereignTokens.imperialGold
                      .withValues(alpha: 0.45),
                ),
              ),
              icon: const Icon(
                Icons.content_paste_go_rounded,
                size: 15,
                color: FounderSovereignTokens.imperialGoldBright,
              ),
              label: const Text(
                'Colar código',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
              ),
            ),
          ],
        ),
        if (_remainingOtpAttempts != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Você ainda tem $_remainingOtpAttempts tentativas para este código.',
            style: const TextStyle(
              color: FounderSovereignTokens.warmAmber,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 16),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _otpFocusNode.requestFocus(),
          child: _SixDigitOpticalDisplay(digits: digits),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey<String>('ceo-otp-code-input'),
          controller: _otpController,
          focusNode: _otpFocusNode,
          keyboardType: TextInputType.number,
          autofillHints: const <String>[AutofillHints.oneTimeCode],
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          inputFormatters: const <TextInputFormatter>[
            CeoSmartSixDigitOtpInputFormatter(),
          ],
          style: FounderSovereignTokens.monoMetric(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
            color: FounderSovereignTokens.primaryInk,
          ),
          decoration: InputDecoration(
            labelText: 'Toque aqui para digitar ou colar os 6 números',
            counterText: '',
            isDense: true,
            filled: true,
            fillColor: FounderSovereignTokens.obsidianSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (!_busy &&
                CeoSmartOtpExtractor.extractBestSixDigits(_otpController.text)
                        .length ==
                    6) {
              onSubmit();
            }
          },
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: submitButtonKey,
          onPressed: (_busy || digits.length != 6) ? null : onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: FounderSovereignTokens.imperialGold,
            foregroundColor: const Color(0xFF0B0E14),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0B0E14),
                  ),
                )
              : Text(
                  submitLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: <Widget>[
            TextButton(
              onPressed: _busy ? null : onBack,
              child: const Text('Voltar'),
            ),
            TextButton(
              key: const ValueKey<String>('ceo-otp-resend-btn'),
              onPressed:
                  (_busy || _otpCooldownRemainingSec > 0) ? null : onResend,
              child: Text(
                _otpCooldownRemainingSec > 0
                    ? 'Enviar novo código em ${_otpCooldownRemainingSec}s'
                    : 'Não chegou? Enviar novo código',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSovereignEmailField({required Key fieldKey}) {
    return TextField(
      key: fieldKey,
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      maxLength: 120,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.deny(RegExp(r'\s')),
        LengthLimitingTextInputFormatter(120),
      ],
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: FounderSovereignTokens.primaryInk,
      ),
      decoration: InputDecoration(
        labelText: 'Seu e-mail de acesso',
        hintText: 'Digite seu e-mail',
        counterText: '',
        prefixIcon: const Icon(
          Icons.mail_outline_rounded,
          size: 19,
          color: FounderSovereignTokens.mutedInk,
        ),
        filled: true,
        fillColor: FounderSovereignTokens.obsidianSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }
}

class _StepEyebrow extends StatelessWidget {
  const _StepEyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: FounderSovereignTokens.eyebrowStyle(
        fontSize: 11,
        color: FounderSovereignTokens.imperialGoldBright,
      ),
    );
  }
}

class _SovereignPasswordField extends StatelessWidget {
  const _SovereignPasswordField({
    required this.fieldKey,
    required this.controller,
    required this.labelText,
    required this.obscureText,
    required this.onToggleObscure,
    required this.onChanged,
    this.onSubmitted,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String labelText;
  final bool obscureText;
  final VoidCallback onToggleObscure;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      obscureText: obscureText,
      maxLength: CeoStrongPasswordPolicy.maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      keyboardType: TextInputType.visiblePassword,
      contextMenuBuilder: obscureText
          ? (_, _) => const SizedBox.shrink()
          : (ctx, editableState) =>
              AdaptiveTextSelectionToolbar.editableText(
                editableTextState: editableState,
              ),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.deny(RegExp(r'[\s\x00-\x1F\x7F]')),
        LengthLimitingTextInputFormatter(CeoStrongPasswordPolicy.maxLength),
      ],
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        color: FounderSovereignTokens.primaryInk,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        counterText: '',
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          size: 19,
          color: FounderSovereignTokens.mutedInk,
        ),
        suffixIcon: IconButton(
          tooltip: obscureText ? 'Mostrar senha' : 'Esconder senha',
          onPressed: onToggleObscure,
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 19,
            color: FounderSovereignTokens.mutedInk,
          ),
        ),
        filled: true,
        fillColor: FounderSovereignTokens.obsidianSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

class _PasswordRequirementsChecklist extends StatelessWidget {
  const _PasswordRequirementsChecklist({
    required this.evaluation,
    required this.passwordsMatch,
    required this.hasConfirmationInput,
  });

  final CeoPasswordEvaluation evaluation;
  final bool passwordsMatch;
  final bool hasConfirmationInput;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FounderSovereignTokens.crispBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _RuleRow(
            satisfied: evaluation.lengthInRange,
            label: 'Entre 12 e 64 caracteres',
          ),
          _RuleRow(
            satisfied: evaluation.hasUppercase && evaluation.hasLowercase,
            label: 'Letra maiúscula e letra minúscula',
          ),
          _RuleRow(
            satisfied: evaluation.hasDigit,
            label: 'Pelo menos um número (0 a 9)',
          ),
          _RuleRow(
            satisfied: evaluation.hasSpecialSymbol,
            label: 'Um símbolo especial (ex: ! @ # \$ % & *)',
          ),
          _RuleRow(
            satisfied: evaluation.antiPatternApproved &&
                evaluation.charCount >= CeoStrongPasswordPolicy.minLength,
            label: 'Sem seu nome ou sequências fáceis (1234, abcd)',
          ),
          _RuleRow(
            satisfied: passwordsMatch,
            label: hasConfirmationInput && !passwordsMatch
                ? 'As duas senhas ainda estão diferentes'
                : 'As duas senhas conferem',
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.satisfied, required this.label});

  final bool satisfied;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Icon(
            satisfied
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: satisfied
                ? FounderSovereignTokens.solvencyEmerald
                : FounderSovereignTokens.mutedInk,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: satisfied
                    ? FounderSovereignTokens.primaryInk
                    : FounderSovereignTokens.mutedInk,
                fontSize: 12.5,
                fontWeight: satisfied ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SixDigitOpticalDisplay extends StatelessWidget {
  const _SixDigitOpticalDisplay({required this.digits});

  final String digits;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List<Widget>.generate(6, (index) {
        final filled = index < digits.length;
        final active = index == digits.length;
        final char = filled ? digits[index] : '';
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 7),
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  width: active ? 1.8 : 1.0,
                  color: filled
                      ? FounderSovereignTokens.solvencyEmerald
                      : active
                          ? FounderSovereignTokens.imperialGoldBright
                          : FounderSovereignTokens.crispBorder,
                ),
              ),
              child: Text(
                char,
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: FounderSovereignTokens.primaryInk,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

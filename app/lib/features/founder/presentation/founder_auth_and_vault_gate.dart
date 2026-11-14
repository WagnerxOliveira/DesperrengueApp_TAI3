/// Barreira Soberana de Identidade Monocrática, Criação de Senha Mestra Forte,
/// Login 2FA em 2 Etapas (Senha Mestra AES-256 + Código de 6 Dígitos no E-mail)
/// e Redefinição Segura via Deep-Link Efêmero do `Desperrengue CEO`.
///
/// Regras de Segurança Extrema:
/// - **Zero Cross-App OAuth**: nenhum botão abre navegador externo ou `signInWithOAuth`,
///   eliminando 100% qualquer possibilidade de redirecionamento ao APK do Marketplace.
/// - **Zero campos pré-preenchidos**: todos os controladores iniciam 100% vazios (`''`).
/// - **Teto Físico Estrito de 64 Caracteres + Política Matemática de Senha Forte**:
///   `12 <= len <= 64`, `LengthLimitingTextInputFormatter(64)`, maiúscula, minúscula,
///   número, símbolo especial, entropia de Shannon >= 60 bits e bloqueio de nomes/sequências.
/// - **Exclusividade Monocrática**: apenas `wagneroliveira2395@gmail.com` é aceito.
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
            'Link exclusivo de troca validado! Crie abaixo sua nova Senha Mestra Forte.';
        _stage = CeoSovereignAuthStage.stagePasswordResetFromDeepLink;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Limpa imediatamente qualquer senha digitada na RAM ao sair da tela,
      // preservando apenas o challengeId caso Wagner esteja abrindo o Gmail para ler os 6 dígitos!
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
              'Código ativo restaurado (Protocolo #${restoredTicket.challengeRef}). Digite ou cole os 6 dígitos enviados para $kMonocraticCeoEmail.';
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
  // CERIMÔNIA DE PRIMEIRO ACESSO (CRIAÇÃO INICIAL DA SENHA MESTRA FORTE)
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
            'Digite seu e-mail soberano ($kMonocraticCeoEmail) para receber o código de 6 dígitos.';
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
            ? 'Novo código enviado (Protocolo #${ticket.challengeRef}). Utilize o e-mail mais recente enviado para $kMonocraticCeoEmail.'
            : 'Código enviado (Protocolo #${ticket.challengeRef}). Confira sua caixa de entrada em $kMonocraticCeoEmail.';
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
            'Informe exatamente os 6 dígitos enviados para $kMonocraticCeoEmail.';
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
            'Identidade confirmada! Crie agora sua Senha Mestra Forte de Administrador CEO.';
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
        _errorBanner =
            'A confirmação da Senha Mestra precisa ser idêntica à senha criada.';
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
  // LOGIN DIÁRIO EM 2 ETAPAS (SENHA MESTRA FORTE + CÓDIGO DE 6 DÍGITOS NO E-MAIL)
  // ---------------------------------------------------------------------------

  Future<void> _handleDailyLoginStep1() async {
    if (_busy || _vaultLockRemainingSec > 0) return;
    final typedEmail = _emailController.text.trim().toLowerCase();
    final typedPassword = _passwordController.text;

    if (typedEmail.isEmpty || typedPassword.isEmpty) {
      setState(() {
        _errorBanner =
            'Digite seu e-mail soberano ($kMonocraticCeoEmail) e sua Senha Mestra CEO.';
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
            'Senha Mestra validada! Enviamos o código (Protocolo #${ticket.challengeRef}) para $kMonocraticCeoEmail.';
        _stage = CeoSovereignAuthStage.stageDailyLoginVerifyOtp;
      });
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      if (e.errorCode == 'ERR_MASTER_PASSWORD_NOT_CONFIGURED') {
        setState(() {
          _busy = false;
          _infoBanner =
              'Você ainda não possui Senha Mestra cadastrada. Valide seu e-mail para criá-la agora.';
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
            'Novo código enviado (Protocolo #${fresh.challengeRef}). Utilize o e-mail mais recente em $kMonocraticCeoEmail.';
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
            'Informe exatamente os 6 dígitos enviados para $kMonocraticCeoEmail.';
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
  // REDEFINIÇÃO DE SENHA MESTRA VIA DEEP-LINK EFÊMERO DO 2º E-MAIL
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
        _errorBanner =
            'A confirmação da nova Senha Mestra precisa ser idêntica à senha criada.';
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
            'Nova Senha Mestra gravada em AES-256! Todas as sessões anteriores foram encerradas. Valide agora sua entrada com a nova senha e o código de 6 dígitos.';
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

  void _appendOtpDigitFromPad(int digit) {
    final current =
        CeoSmartOtpExtractor.extractBestSixDigits(_otpController.text);
    if (current.length >= 6 || _busy) return;
    HapticFeedback.selectionClick();
    final next = '$current$digit';
    _otpController.text = next;
    _otpController.selection = TextSelection.collapsed(offset: next.length);
    setState(() {});
  }

  void _backspaceOtpFromPad() {
    final current =
        CeoSmartOtpExtractor.extractBestSixDigits(_otpController.text);
    if (current.isEmpty || _busy) return;
    HapticFeedback.selectionClick();
    final next = current.substring(0, current.length - 1);
    _otpController.text = next;
    _otpController.selection = TextSelection.collapsed(offset: next.length);
    setState(() {});
  }

  Future<void> _handlePasteOtpFromClipboard() async {
    if (_busy) return;
    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = clip?.text ?? '';
      final extracted = CeoSmartOtpExtractor.extractSixDigitClusterOrNull(raw) ??
          CeoSmartOtpExtractor.extractBestSixDigits(raw);
      if (!mounted) return;
      if (extracted.isEmpty) {
        setState(() {
          _errorBanner =
              'Nenhum código numérico encontrado na área de transferência.';
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
  // CONSTRUÇÃO VISUAL OBSIDIAN & OURO 24K (ZERO OVERFLOW DE 320PX A 4K)
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey<String>('founder-sovereign-auth-gate-scaffold'),
      backgroundColor: FounderSovereignTokens.obsidianBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 492),
              child: FounderGlassCard(
                padding: const EdgeInsets.all(20),
                accentTopBarColor: FounderSovereignTokens.imperialGold,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildSovereignBrandHeader(),
                    const SizedBox(height: 16),
                    if (_infoBanner != null) ...<Widget>[
                      _buildBanner(
                        message: _infoBanner!,
                        borderColor: FounderSovereignTokens.solvencyEmerald,
                        bgColor: FounderSovereignTokens.solvencyEmerald
                            .withValues(alpha: 0.12),
                        icon: Icons.verified_user_rounded,
                        iconColor: FounderSovereignTokens.solvencyEmerald,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_errorBanner != null) ...<Widget>[
                      _buildBanner(
                        message: _errorBanner!,
                        borderColor: FounderSovereignTokens.crimsonAlert,
                        bgColor: FounderSovereignTokens.crimsonAlertSoft,
                        icon: Icons.gpp_bad_rounded,
                        iconColor: FounderSovereignTokens.crimsonAlert,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_vaultLockRemainingSec > 0) ...<Widget>[
                      _buildBanner(
                        message:
                            'Defesa ativa: aguarde ${_vaultLockRemainingSec}s antes de tentar novamente.',
                        borderColor: FounderSovereignTokens.warmAmber,
                        bgColor: FounderSovereignTokens.warmAmber
                            .withValues(alpha: 0.14),
                        icon: Icons.timer_rounded,
                        iconColor: FounderSovereignTokens.warmAmber,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildCurrentStageContent(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSovereignBrandHeader() {
    return Row(
      children: <Widget>[
        const FounderSovereignCrest(size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Desperrengue CEO',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: FounderSovereignTokens.primaryInk,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'COFRE MONOCRÁTICO · ACESSO EXCLUSIVO DO CEO',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
              ),
            ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: FounderSovereignTokens.primaryInk,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
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
              const CircularProgressIndicator(
                color: FounderSovereignTokens.imperialGoldBright,
              ),
              const SizedBox(height: 14),
              Text(
                'Verificando integridade criptográfica do Cofre Soberano…',
                textAlign: TextAlign.center,
                style: FounderSovereignTokens.monoMetric(
                  fontSize: 12,
                  color: FounderSovereignTokens.mutedInk,
                ),
              ),
            ],
          ),
        );

      case CeoSovereignAuthStage.stageBootstrapRequestEmail:
        return _buildBootstrapRequestEmailView();

      case CeoSovereignAuthStage.stageBootstrapVerifyOtp:
        return _buildSixDigitOtpView(
          badgeLabel: 'PRIMEIRO ACESSO · ETAPA 1 DE 2',
          headline: 'Valide os 6 Dígitos do Seu E-mail',
          subtitle:
              'Enviamos um código exclusivo de 6 dígitos para $kMonocraticCeoEmail. Digite ou cole os 6 dígitos abaixo para liberar a criação da sua Senha Mestra Forte:',
          submitButtonKey: const ValueKey<String>(
            'ceo-bootstrap-verify-otp-btn',
          ),
          submitLabel: 'Confirmar Código e Criar Senha Mestra',
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
          badgeLabel: 'PRIMEIRO ACESSO · ETAPA 2 DE 2',
          headline: 'Crie Sua Senha Mestra Forte CEO',
          subtitle:
              'Sua senha é exclusiva deste aplicativo, protegida em custódia dividida (PBKDF2 210k + HMAC-SHA512 25k + AES-256) e jamais compartilhada com o Marketplace.',
          newPasswordFieldKey: const ValueKey<String>(
            'ceo-create-password-input',
          ),
          confirmPasswordFieldKey: const ValueKey<String>(
            'ceo-confirm-password-input',
          ),
          submitButtonKey: const ValueKey<String>(
            'ceo-save-initial-password-btn',
          ),
          submitLabel: 'Selar Minha Senha Mestra em AES-256 & Entrar',
          onSubmit: _handleCreateInitialMasterPassword,
        );

      case CeoSovereignAuthStage.stageDailyLoginCredentials:
        return _buildDailyLoginCredentialsView();

      case CeoSovereignAuthStage.stageDailyLoginVerifyOtp:
        return _buildSixDigitOtpView(
          badgeLabel: 'VERIFICAÇÃO 2FA DE ENTRADA · ETAPA 2 DE 2',
          headline: 'Código de 6 Dígitos Enviado ao Seu E-mail',
          subtitle:
              'Sua Senha Mestra foi provada! Digite ou cole agora os 6 dígitos enviados exclusivamente para $kMonocraticCeoEmail para abrir a Sala de Guerra:',
          submitButtonKey: const ValueKey<String>('ceo-login-verify-otp-btn'),
          submitLabel: 'Validar 6 Dígitos e Abrir Desperrengue CEO',
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
          badgeLabel: 'REDEFINIÇÃO AUTORIZADA POR E-MAIL · USO ÚNICO (10 MIN)',
          headline: 'Definir Nova Senha de Administrador CEO',
          subtitle:
              'Ao salvar a nova Senha Mestra Forte em AES-256, todas as sessões anteriores serão encerradas e você validará sua entrada com a senha nova + código de 6 dígitos.',
          newPasswordFieldKey: const ValueKey<String>(
            'ceo-reset-new-password-input',
          ),
          confirmPasswordFieldKey: const ValueKey<String>(
            'ceo-reset-confirm-password-input',
          ),
          submitButtonKey: const ValueKey<String>(
            'ceo-reset-commit-password-btn',
          ),
          submitLabel: 'Salvar Nova Senha Mestra & Ir para Login',
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
        _StagePillBadge('PRIMEIRO ACESSO SOBERANO · SEM SENHA CADASTRADA'),
        const SizedBox(height: 10),
        const Text(
          'Inicialize Sua Senha de Administrador CEO',
          style: TextStyle(
            color: FounderSovereignTokens.primaryInk,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Nenhuma Senha Mestra foi criada ainda neste Cofre Soberano. Confirme abaixo seu e-mail exclusivo para receber o código de 6 dígitos e criar sua própria senha forte:',
          style: TextStyle(
            color: FounderSovereignTokens.mutedInk,
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        _buildSovereignEmailField(
          fieldKey: const ValueKey<String>('ceo-bootstrap-email-input'),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const ValueKey<String>('ceo-bootstrap-send-otp-btn'),
          onPressed: (_busy || _otpCooldownRemainingSec > 0)
              ? null
              : () => _handleBootstrapSendOtp(),
          style: FilledButton.styleFrom(
            backgroundColor: FounderSovereignTokens.imperialGold,
            foregroundColor: const Color(0xFF0B0F17),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0B0F17),
                  ),
                )
              : const Icon(Icons.mark_email_unread_rounded, size: 18),
          label: Text(
            _otpCooldownRemainingSec > 0
                ? 'Aguarde ${_otpCooldownRemainingSec}s'
                : 'Enviar Código de 6 Dígitos para Criar Minha Senha',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
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
            'Já criei minha Senha Mestra — ir para tela de Login',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
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
        _StagePillBadge('ENTRADA SOBERANA EM 2 FATORES · ETAPA 1 DE 2'),
        const SizedBox(height: 10),
        const Text(
          'Autenticação Exclusiva do CEO',
          style: TextStyle(
            color: FounderSovereignTokens.primaryInk,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Informe seu e-mail soberano e sua Senha Mestra Forte (máx. 64 caracteres). Após validar sua senha, enviaremos o código de 6 dígitos para o seu e-mail:',
          style: TextStyle(
            color: FounderSovereignTokens.mutedInk,
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        _buildSovereignEmailField(
          fieldKey: const ValueKey<String>('ceo-login-email-input'),
        ),
        const SizedBox(height: 12),
        _SovereignPasswordField(
          fieldKey: const ValueKey<String>('ceo-login-password-input'),
          controller: _passwordController,
          labelText: 'Senha Mestra de Administrador CEO',
          obscureText: _obscurePrimaryPassword,
          onToggleObscure: () => setState(
            () => _obscurePrimaryPassword = !_obscurePrimaryPassword,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _handleDailyLoginStep1(),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$charCount / ${CeoStrongPasswordPolicy.maxLength} caracteres',
            key: const ValueKey<String>('ceo-login-password-char-counter'),
            style: FounderSovereignTokens.monoMetric(
              fontSize: 11,
              color: charCount >= CeoStrongPasswordPolicy.maxLength
                  ? FounderSovereignTokens.imperialGoldBright
                  : FounderSovereignTokens.mutedInk,
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const ValueKey<String>('ceo-login-submit-btn'),
          onPressed: (_busy || _vaultLockRemainingSec > 0)
              ? null
              : _handleDailyLoginStep1,
          style: FilledButton.styleFrom(
            backgroundColor: FounderSovereignTokens.imperialGold,
            foregroundColor: const Color(0xFF0B0F17),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0B0F17),
                  ),
                )
              : const Icon(Icons.shield_rounded, size: 18),
          label: const Text(
            'Validar Senha & Receber Código de 6 Dígitos',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateOrResetPasswordView({
    required String badgeLabel,
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
        _StagePillBadge(badgeLabel),
        const SizedBox(height: 10),
        Text(
          headline,
          style: const TextStyle(
            color: FounderSovereignTokens.primaryInk,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: FounderSovereignTokens.mutedInk,
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        _SovereignPasswordField(
          fieldKey: newPasswordFieldKey,
          controller: _passwordController,
          labelText: 'Nova Senha Mestra (12 a 64 caracteres)',
          obscureText: _obscurePrimaryPassword,
          onToggleObscure: () => setState(
            () => _obscurePrimaryPassword = !_obscurePrimaryPassword,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                evaluation.tierLabelPt,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: evaluation.isApproved
                      ? FounderSovereignTokens.solvencyEmerald
                      : FounderSovereignTokens.imperialGoldBright,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${evaluation.charCount} / ${CeoStrongPasswordPolicy.maxLength}',
              key: const ValueKey<String>('ceo-password-char-counter'),
              style: FounderSovereignTokens.monoMetric(
                fontSize: 11,
                fontWeight: FontWeight.w800,
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
            minHeight: 6,
            value: evaluation.normalizedProgress,
            backgroundColor: FounderSovereignTokens.obsidianSurface,
            color: evaluation.isApproved
                ? FounderSovereignTokens.solvencyEmerald
                : FounderSovereignTokens.imperialGold,
          ),
        ),
        const SizedBox(height: 12),
        _SovereignPasswordField(
          fieldKey: confirmPasswordFieldKey,
          controller: _confirmPasswordController,
          labelText: 'Confirmar Senha Mestra',
          obscureText: _obscureConfirmPassword,
          onToggleObscure: () => setState(
            () => _obscureConfirmPassword = !_obscureConfirmPassword,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (canSubmit) onSubmit();
          },
        ),
        const SizedBox(height: 12),
        _PasswordRequirementsChecklist(
          evaluation: evaluation,
          passwordsMatch: passwordsMatch,
          hasConfirmationInput: confirm.isNotEmpty,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: submitButtonKey,
          onPressed: canSubmit ? onSubmit : null,
          style: FilledButton.styleFrom(
            backgroundColor: FounderSovereignTokens.imperialGold,
            foregroundColor: const Color(0xFF0B0F17),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0B0F17),
                  ),
                )
              : const Icon(Icons.enhanced_encryption_rounded, size: 18),
          label: Text(
            submitLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        if (onCancel != null) ...<Widget>[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : onCancel,
            child: const Text('Cancelar redefinição'),
          ),
        ],
      ],
    );
  }

  Widget _buildSixDigitOtpView({
    required String badgeLabel,
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
        _StagePillBadge(badgeLabel),
        const SizedBox(height: 10),
        Text(
          headline,
          style: const TextStyle(
            color: FounderSovereignTokens.primaryInk,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: FounderSovereignTokens.mutedInk,
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: <Widget>[
            if (activeRef != null && activeRef.isNotEmpty)
              Container(
                key: const ValueKey<String>('ceo-otp-protocol-ref-badge'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: FounderSovereignTokens.solvencyEmerald
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: FounderSovereignTokens.solvencyEmerald
                        .withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  'PROTOCOLO #$activeRef · VÁLIDO POR 10 MIN',
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: FounderSovereignTokens.solvencyEmerald,
                  ),
                ),
              ),
            OutlinedButton.icon(
              key: const ValueKey<String>('ceo-otp-paste-btn'),
              onPressed: _busy ? null : _handlePasteOtpFromClipboard,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                side: BorderSide(
                  color: FounderSovereignTokens.imperialGold
                      .withValues(alpha: 0.55),
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
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
              ),
            ),
          ],
        ),
        if (_remainingOtpAttempts != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'Tentativas restantes neste código: $_remainingOtpAttempts',
            style: const TextStyle(
              color: FounderSovereignTokens.warmAmber,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _otpFocusNode.requestFocus(),
          child: _SixDigitOpticalDisplay(digits: digits),
        ),
        const SizedBox(height: 10),
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
            labelText: 'Digite ou cole os 6 dígitos',
            counterText: '',
            isDense: true,
            filled: true,
            fillColor: FounderSovereignTokens.obsidianSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
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
        const SizedBox(height: 12),
        FilledButton.icon(
          key: submitButtonKey,
          onPressed: (_busy || digits.length != 6) ? null : onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: FounderSovereignTokens.imperialGold,
            foregroundColor: const Color(0xFF0B0F17),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0B0F17),
                  ),
                )
              : const Icon(Icons.lock_open_rounded, size: 18),
          label: Text(
            submitLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 6),
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
                    ? 'Reenviar em ${_otpCooldownRemainingSec}s'
                    : 'Reenviar código de 6 dígitos',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _CompactNumericPad(
          enabled: !_busy,
          onDigit: _appendOtpDigitFromPad,
          onBackspace: _backspaceOtpFromPad,
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
      style: FounderSovereignTokens.monoMetric(
        fontSize: 13.5,
        color: FounderSovereignTokens.primaryInk,
      ),
      decoration: InputDecoration(
        labelText: 'E-mail Soberano do CEO',
        hintText: 'Digite seu e-mail autorizado',
        counterText: '',
        prefixIcon: const Icon(
          Icons.alternate_email_rounded,
          size: 18,
          color: FounderSovereignTokens.imperialGoldBright,
        ),
        filled: true,
        fillColor: FounderSovereignTokens.obsidianSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }
}

class _StagePillBadge extends StatelessWidget {
  const _StagePillBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: FounderSovereignTokens.imperialGold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: FounderSovereignTokens.imperialGold.withValues(alpha: 0.48),
          ),
        ),
        child: Text(
          text,
          style: FounderSovereignTokens.monoMetric(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: FounderSovereignTokens.imperialGoldBright,
          ),
        ),
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
      style: FounderSovereignTokens.monoMetric(
        fontSize: 14,
        color: FounderSovereignTokens.primaryInk,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        counterText: '',
        prefixIcon: const Icon(
          Icons.key_rounded,
          size: 18,
          color: FounderSovereignTokens.imperialGoldBright,
        ),
        suffixIcon: IconButton(
          tooltip: obscureText ? 'Revelar caracteres' : 'Ocultar caracteres',
          onPressed: onToggleObscure,
          icon: Icon(
            obscureText
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            size: 18,
            color: FounderSovereignTokens.mutedInk,
          ),
        ),
        filled: true,
        fillColor: FounderSovereignTokens.obsidianSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FounderSovereignTokens.crispBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _RuleRow(
            satisfied: evaluation.lengthInRange,
            label: 'Entre 12 e 64 caracteres (teto rígido de 64)',
          ),
          _RuleRow(
            satisfied: evaluation.hasUppercase,
            label: 'Pelo menos 1 letra maiúscula (A–Z)',
          ),
          _RuleRow(
            satisfied: evaluation.hasLowercase,
            label: 'Pelo menos 1 letra minúscula (a–z)',
          ),
          _RuleRow(
            satisfied: evaluation.hasDigit,
            label: 'Pelo menos 1 número (0–9)',
          ),
          _RuleRow(
            satisfied: evaluation.hasSpecialSymbol,
            label: 'Pelo menos 1 caractere especial (!@#\$%&*-_+=?)',
          ),
          _RuleRow(
            satisfied: evaluation.antiPatternApproved &&
                evaluation.charCount >= CeoStrongPasswordPolicy.minLength,
            label: 'Alta entropia (≥ 60 bits), sem nomes ou sequências',
          ),
          _RuleRow(
            satisfied: passwordsMatch,
            label: hasConfirmationInput && !passwordsMatch
                ? 'Confirmação divergente da senha digitada'
                : 'Confirmação idêntica à Senha Mestra',
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
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: <Widget>[
          Icon(
            satisfied
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 15,
            color: satisfied
                ? FounderSovereignTokens.solvencyEmerald
                : FounderSovereignTokens.mutedInk,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: satisfied
                    ? FounderSovereignTokens.primaryInk
                    : FounderSovereignTokens.mutedInk,
                fontSize: 11.5,
                fontWeight: satisfied ? FontWeight.w700 : FontWeight.w500,
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
            padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  width: active ? 1.6 : 1.0,
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
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CompactNumericPad extends StatelessWidget {
  const _CompactNumericPad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const rows = <List<int?>>[
      <int?>[1, 2, 3],
      <int?>[4, 5, 6],
      <int?>[7, 8, 9],
      <int?>[null, 0, -1],
    ];
    return Column(
      children: <Widget>[
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: <Widget>[
                for (var i = 0; i < row.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                      child: _buildCell(row[i]),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCell(int? value) {
    if (value == null) return const SizedBox(height: 40);
    if (value == -1) {
      return OutlinedButton(
        key: const ValueKey<String>('ceo-otp-backspace-btn'),
        onPressed: enabled ? onBackspace : null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: EdgeInsets.zero,
        ),
        child: const Icon(Icons.backspace_outlined, size: 17),
      );
    }
    return OutlinedButton(
      key: ValueKey<String>('ceo-otp-digit-$value'),
      onPressed: enabled ? () => onDigit(value) : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: EdgeInsets.zero,
      ),
      child: Text(
        '$value',
        style: FounderSovereignTokens.monoMetric(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: FounderSovereignTokens.primaryInk,
        ),
      ),
    );
  }
}

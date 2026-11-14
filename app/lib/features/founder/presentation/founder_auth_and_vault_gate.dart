import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/analytics/founder_dashboard_models.dart';
import '../data/founder_cockpit_repository.dart';
import 'founder_animations_and_shaders.dart';

enum _VaultGateStage {
  checkingStatus,
  primaryAuth,
  emailOtpChallenge,
  pinCreate,
  pinConfirm,
  pinUnlock,
}

/// Barreira Criptográfica Monocrática em 3 Camadas do `Desperrengue CEO`.
///
/// Regras de Segurança Extrema:
/// - **Zero campos pré-preenchidos**: todos os controladores e células de dígitos
///   iniciam 100% vazios (`''`) e são zerados ao ir para segundo plano ou desmontar.
/// - **Exclusividade absoluta**: somente `wagneroliveira2395@gmail.com` avança.
/// - **Teclado Vetorial Tátil Próprio (`SovereignPinPad`)**: os dígitos do PIN jamais
///   trafegam por teclados IME de terceiros, contando ainda com embaralhamento CSPRNG
///   opcional contra observação lateral (*anti-shoulder-surfing*).
class FounderAuthAndVaultGate extends StatefulWidget {
  const FounderAuthAndVaultGate({
    super.key,
    required this.repository,
    required this.onVaultUnlocked,
    this.initialPinResetFlow = false,
    this.lockReasonBanner,
  });

  final FounderCockpitRepository repository;
  final Future<void> Function(FounderStepUpSession session) onVaultUnlocked;
  final bool initialPinResetFlow;
  final String? lockReasonBanner;

  @override
  State<FounderAuthAndVaultGate> createState() =>
      _FounderAuthAndVaultGateState();
}

class _FounderAuthAndVaultGateState extends State<FounderAuthAndVaultGate>
    with WidgetsBindingObserver {
  // Controladores 100% vazios por design (jamais pré-preenchidos!)
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _primaryOtpController = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();

  StreamSubscription<String?>? _authSub;
  Timer? _countdownTimer;

  _VaultGateStage _stage = _VaultGateStage.checkingStatus;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _usePasswordlessPrimaryAuth = false;
  bool _primaryOtpSent = false;
  bool _scrambleKeypad = false;
  List<int> _keypadDigits = const <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 0];

  String _otpPurpose = 'INITIAL_PIN_SETUP';
  CeoOtpChallengeTicket? _activeOtpTicket;
  String? _enrollmentTicketHex;

  String _otpBuffer = '';
  String _pinDraftFirst = '';
  String _pinBuffer = '';

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
    _authSub = widget.repository.authEmailChanges.listen((email) {
      if (!mounted) return;
      if (email != null && email.isNotEmpty && _stage == _VaultGateStage.primaryAuth) {
        unawaited(_evaluateAuthAndVaultState());
      }
    });
    unawaited(_evaluateAuthAndVaultState());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _wipeSensitiveBuffers();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _countdownTimer?.cancel();
    _wipeSensitiveBuffers(triggerRebuild: false);
    _emailController.dispose();
    _passwordController.dispose();
    _primaryOtpController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _wipeSensitiveBuffers({bool triggerRebuild = true}) {
    _passwordController.clear();
    _primaryOtpController.clear();
    _otpBuffer = '';
    _pinDraftFirst = '';
    _pinBuffer = '';
    if (triggerRebuild && mounted) {
      setState(() {});
    }
  }

  void _toggleScrambleKeypad() {
    HapticFeedback.selectionClick();
    setState(() {
      _scrambleKeypad = !_scrambleKeypad;
      _reshuffleDigitsIfNeeded();
    });
  }

  void _reshuffleDigitsIfNeeded() {
    if (!_scrambleKeypad) {
      _keypadDigits = const <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 0];
      return;
    }
    final rng = math.Random.secure();
    final list = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    for (var i = list.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
    _keypadDigits = List<int>.unmodifiable(list);
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

  Future<void> _evaluateAuthAndVaultState() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _errorBanner = null;
    });

    final email = widget.repository.authenticatedEmail;
    if (email == null || email.isEmpty) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = _VaultGateStage.primaryAuth;
      });
      return;
    }

    try {
      final status = await widget.repository.fetchVaultStatus();
      if (!mounted) return;

      if (status.lockedUntil != null &&
          status.lockedUntil!.isAfter(DateTime.now().toUtc())) {
        _vaultLockedUntilUtc = status.lockedUntil;
        _vaultLockRemainingSec = status.lockedUntil!
            .difference(DateTime.now().toUtc())
            .inSeconds
            .clamp(1, 86400);
        _ensureCountdownTicker();
      }

      if (widget.initialPinResetFlow) {
        _enterOtpChallengeStage('PIN_RESET', autoSend: false);
        return;
      }

      if (status.requiresEmailOtp) {
        _enterOtpChallengeStage(status.requiredOtpPurpose, autoSend: false);
        return;
      }

      setState(() {
        _busy = false;
        _pinBuffer = '';
        _reshuffleDigitsIfNeeded();
        _stage = _VaultGateStage.pinUnlock;
      });
      _keyboardFocusNode.requestFocus();
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner = e.userMessagePt;
        _stage = _VaultGateStage.primaryAuth;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner =
            'Não foi possível validar o estado do Cofre Soberano. Verifique sua conexão.';
        _stage = _VaultGateStage.primaryAuth;
      });
    }
  }

  void _enterOtpChallengeStage(String purpose, {required bool autoSend}) {
    setState(() {
      _busy = false;
      _otpPurpose = purpose;
      _activeOtpTicket = null;
      _otpBuffer = '';
      _remainingOtpAttempts = null;
      _errorBanner = null;
      _infoBanner = null;
      _reshuffleDigitsIfNeeded();
      _stage = _VaultGateStage.emailOtpChallenge;
    });
    _keyboardFocusNode.requestFocus();
    if (autoSend) {
      unawaited(_sendSixDigitSecurityCode());
    }
  }

  // ---------------------------------------------------------------------------
  // AÇÕES DA CAMADA 1 (IDENTIDADE PRIMÁRIA)
  // ---------------------------------------------------------------------------

  Future<void> _submitEmailPasswordLogin() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _busy = true;
      _errorBanner = null;
      _infoBanner = null;
    });
    try {
      HapticFeedback.selectionClick();
      await widget.repository.signInWithEmailPassword(
        email: email,
        password: password,
      );
      _passwordController.clear();
      await _evaluateAuthAndVaultState();
    } on CeoVaultSecurityException catch (e) {
      _passwordController.clear();
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _busy = false;
        _errorBanner = e.userMessagePt;
      });
    } catch (_) {
      _passwordController.clear();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner = 'Falha ao autenticar credenciais primárias.';
      });
    }
  }

  Future<void> _submitGoogleOAuth() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorBanner = null;
      _infoBanner = null;
    });
    try {
      HapticFeedback.selectionClick();
      await widget.repository.signInWithGoogleOAuth();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _infoBanner =
            'Conclua a seleção da conta soberana no Google para retornar ao Cofre CEO.';
      });
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner = e.userMessagePt;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner = 'Não foi possível iniciar a autenticação Google.';
      });
    }
  }

  Future<void> _sendPasswordlessPrimaryCode() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorBanner = 'Digite seu e-mail soberano para receber o código.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _errorBanner = null;
    });
    try {
      await widget.repository.sendPrimaryEmailSignInOtp(email: email);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _primaryOtpSent = true;
        _infoBanner =
            'Código de sessão enviado para $kMaskedMonocraticCeoEmail.';
      });
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner = e.userMessagePt;
      });
    }
  }

  Future<void> _verifyPasswordlessPrimaryCode() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    final code = _primaryOtpController.text.trim();
    if (code.length < 6) {
      setState(() {
        _errorBanner = 'Informe o código recebido no e-mail.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _errorBanner = null;
    });
    try {
      await widget.repository.verifyPrimaryEmailSignInOtp(
        email: email,
        code: code,
      );
      _primaryOtpController.clear();
      await _evaluateAuthAndVaultState();
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner = e.userMessagePt;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // AÇÕES DA CAMADA 2 (CÓDIGO DE 6 DÍGITOS EXCLUSIVO `ceo-sovereign-auth`)
  // ---------------------------------------------------------------------------

  Future<void> _sendSixDigitSecurityCode() async {
    if (_busy || _otpCooldownRemainingSec > 0) return;
    setState(() {
      _busy = true;
      _errorBanner = null;
      _infoBanner = null;
    });
    try {
      HapticFeedback.selectionClick();
      final ticket = await widget.repository.requestEmailSecurityOtp(
        purpose: _otpPurpose,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _activeOtpTicket = ticket;
        _otpBuffer = '';
        _remainingOtpAttempts = 5;
        _otpCooldownRemainingSec = ticket.nextCooldownSeconds;
        _infoBanner =
            'Código de 6 dígitos enviado exclusivamente para ${ticket.maskedDestination}.';
      });
      _ensureCountdownTicker();
      _keyboardFocusNode.requestFocus();
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _busy = false;
        _errorBanner = e.userMessagePt;
        if (e.retryAfterSeconds != null && e.retryAfterSeconds! > 0) {
          _otpCooldownRemainingSec = e.retryAfterSeconds!;
          _ensureCountdownTicker();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner =
            'Erro de rede ao solicitar o código de 6 dígitos. Tente novamente.';
      });
    }
  }

  Future<void> _pasteOtpFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text ?? '';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 6) {
      HapticFeedback.selectionClick();
      setState(() {
        _otpBuffer = digits.substring(0, 6);
        _errorBanner = null;
      });
      if (_activeOtpTicket != null) {
        await _verifySixDigitSecurityCode();
      }
    }
  }

  Future<void> _verifySixDigitSecurityCode() async {
    if (_busy) return;
    final ticket = _activeOtpTicket;
    if (ticket == null) {
      setState(() {
        _errorBanner =
            'Toque primeiro em "Enviar Código de 6 Dígitos" para receber seu código no e-mail.';
      });
      return;
    }
    if (_otpBuffer.length != 6) return;

    setState(() {
      _busy = true;
      _errorBanner = null;
    });
    try {
      final result = await widget.repository.verifyEmailSecurityOtp(
        challengeId: ticket.challengeId,
        sixDigitCode: _otpBuffer,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _otpBuffer = '';

      if (result.purpose == 'NEW_DEVICE_BIND' && result.pinAlreadyConfigured) {
        setState(() {
          _busy = false;
          _pinBuffer = '';
          _infoBanner =
              'Dispositivo vinculado com sucesso! Digite seu PIN pessoal para abrir o Cofre.';
          _reshuffleDigitsIfNeeded();
          _stage = _VaultGateStage.pinUnlock;
        });
        return;
      }

      setState(() {
        _busy = false;
        _enrollmentTicketHex = result.enrollmentTicketHex;
        _pinDraftFirst = '';
        _pinBuffer = '';
        _infoBanner =
            'Identidade confirmada por código de 6 dígitos. Crie agora seu PIN pessoal.';
        _reshuffleDigitsIfNeeded();
        _stage = _VaultGateStage.pinCreate;
      });
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _busy = false;
        _otpBuffer = '';
        _remainingOtpAttempts = e.remainingAttempts;
        _errorBanner = e.userMessagePt;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // AÇÕES DA CAMADA 3 (CRIAÇÃO, CONFIRMAÇÃO E DESBLOQUEIO DO PIN `SHA-256`)
  // ---------------------------------------------------------------------------

  void _onDigitPressed(int digit) {
    if (_busy) return;
    if (_stage == _VaultGateStage.pinUnlock && _vaultLockRemainingSec > 0) {
      return;
    }
    HapticFeedback.lightImpact();

    if (_stage == _VaultGateStage.emailOtpChallenge) {
      if (_otpBuffer.length >= 6) return;
      setState(() {
        _otpBuffer = '$_otpBuffer$digit';
        _errorBanner = null;
      });
      if (_otpBuffer.length == 6 && _activeOtpTicket != null) {
        unawaited(_verifySixDigitSecurityCode());
      }
      return;
    }

    if (_stage == _VaultGateStage.pinCreate ||
        _stage == _VaultGateStage.pinConfirm ||
        _stage == _VaultGateStage.pinUnlock) {
      if (_pinBuffer.length >= 6) return;
      setState(() {
        _pinBuffer = '$_pinBuffer$digit';
        _errorBanner = null;
      });
      if (_pinBuffer.length == 6) {
        if (_stage == _VaultGateStage.pinCreate) {
          _advanceFromPinCreateToConfirm();
        } else if (_stage == _VaultGateStage.pinConfirm) {
          unawaited(_submitNewPersonalPin());
        } else if (_stage == _VaultGateStage.pinUnlock) {
          unawaited(_submitUnlockPersonalPin());
        }
      }
    }
  }

  void _onBackspacePressed() {
    if (_busy) return;
    HapticFeedback.selectionClick();
    if (_stage == _VaultGateStage.emailOtpChallenge && _otpBuffer.isNotEmpty) {
      setState(() {
        _otpBuffer = _otpBuffer.substring(0, _otpBuffer.length - 1);
      });
    } else if (_pinBuffer.isNotEmpty) {
      setState(() {
        _pinBuffer = _pinBuffer.substring(0, _pinBuffer.length - 1);
      });
    }
  }

  void _advanceFromPinCreateToConfirm() {
    final weakness = CeoPinCryptoEngine.validatePinStrength(_pinBuffer);
    if (weakness != null) {
      HapticFeedback.heavyImpact();
      setState(() {
        _pinBuffer = '';
        _errorBanner = weakness;
      });
      return;
    }
    setState(() {
      _pinDraftFirst = _pinBuffer;
      _pinBuffer = '';
      _errorBanner = null;
      _infoBanner = null;
      _reshuffleDigitsIfNeeded();
      _stage = _VaultGateStage.pinConfirm;
    });
  }

  Future<void> _submitNewPersonalPin() async {
    if (_busy) return;
    if (_pinBuffer != _pinDraftFirst) {
      HapticFeedback.heavyImpact();
      setState(() {
        _pinDraftFirst = '';
        _pinBuffer = '';
        _errorBanner =
            'Os dois PINs digitados não coincidem. Escolha novamente seu PIN de 6 dígitos.';
        _reshuffleDigitsIfNeeded();
        _stage = _VaultGateStage.pinCreate;
      });
      return;
    }

    final ticket = _enrollmentTicketHex;
    if (ticket == null || ticket.isEmpty) {
      _enterOtpChallengeStage(_otpPurpose, autoSend: false);
      return;
    }

    final chosenPin = _pinBuffer;
    setState(() {
      _busy = true;
      _pinDraftFirst = '';
      _pinBuffer = '';
      _errorBanner = null;
    });

    try {
      final session = await widget.repository.registerPersonalPin(
        enrollmentTicketHex: ticket,
        personalPin: chosenPin,
      );
      _enrollmentTicketHex = null;
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await widget.onVaultUnlocked(session);
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _busy = false;
        _errorBanner = e.userMessagePt;
        _stage = _VaultGateStage.pinCreate;
      });
    }
  }

  Future<void> _submitUnlockPersonalPin() async {
    if (_busy || _vaultLockRemainingSec > 0) return;
    final candidatePin = _pinBuffer;
    setState(() {
      _busy = true;
      _pinBuffer = '';
      _errorBanner = null;
    });

    try {
      final session = await widget.repository.unlockWithPersonalPin(
        personalPin: candidatePin,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await widget.onVaultUnlocked(session);
    } on CeoVaultSecurityException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _busy = false;
        _reshuffleDigitsIfNeeded();
        _errorBanner = e.userMessagePt;
        if (e.lockedUntilUtc != null) {
          _vaultLockedUntilUtc = e.lockedUntilUtc;
          _vaultLockRemainingSec = e.lockedUntilUtc!
              .difference(DateTime.now().toUtc())
              .inSeconds
              .clamp(1, 86400);
          _ensureCountdownTicker();
        }
      });
      if (e.errorCode.contains('UNTRUSTED_DEVICE') ||
          e.errorCode.contains('PIN_NOT_CONFIGURED')) {
        _enterOtpChallengeStage(
          e.errorCode.contains('PIN_NOT_CONFIGURED')
              ? 'INITIAL_PIN_SETUP'
              : 'NEW_DEVICE_BIND',
          autoSend: false,
        );
      }
    }
  }

  KeyEventResult _handleHardwareKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_stage != _VaultGateStage.emailOtpChallenge &&
        _stage != _VaultGateStage.pinCreate &&
        _stage != _VaultGateStage.pinConfirm &&
        _stage != _VaultGateStage.pinUnlock) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _onBackspacePressed();
      return KeyEventResult.handled;
    }
    final label = event.character ?? event.logicalKey.keyLabel;
    if (label.length == 1) {
      final code = label.codeUnitAt(0);
      if (code >= 48 && code <= 57) {
        _onDigitPressed(code - 48);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey<String>('founder-stepup-vault-gate'),
      backgroundColor: FounderSovereignTokens.obsidianBackground,
      body: Focus(
        focusNode: _keyboardFocusNode,
        onKeyEvent: _handleHardwareKey,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _buildActiveStageCard(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveStageCard(BuildContext context) {
    switch (_stage) {
      case _VaultGateStage.checkingStatus:
        return _buildCheckingCard();
      case _VaultGateStage.primaryAuth:
        return _buildPrimaryAuthCard();
      case _VaultGateStage.emailOtpChallenge:
        return _buildEmailOtpChallengeCard();
      case _VaultGateStage.pinCreate:
      case _VaultGateStage.pinConfirm:
        return _buildPinEnrollmentCard();
      case _VaultGateStage.pinUnlock:
        return _buildPinUnlockCard();
    }
  }

  Widget _buildCheckingCard() {
    return FounderGlassCard(
      accentTopBarColor: FounderSovereignTokens.imperialGoldBright,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const FounderSovereignCrest(size: 56),
          const SizedBox(height: 18),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: FounderSovereignTokens.imperialGoldBright,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Verificando Assinatura do Cofre Soberano…',
            textAlign: TextAlign.center,
            style: FounderSovereignTokens.monoMetric(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: FounderSovereignTokens.mutedInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge({
    required String title,
    required String subtitle,
    String pillText = 'TITULARIDADE EXCLUSIVA · MONOCRÁTICA',
  }) {
    return Column(
      children: <Widget>[
        const FounderSovereignCrest(size: 54),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: FounderSovereignTokens.imperialGoldSoft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: FounderSovereignTokens.imperialGold.withValues(alpha: 0.65),
            ),
          ),
          child: Text(
            pillText,
            textAlign: TextAlign.center,
            style: FounderSovereignTokens.monoMetric(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: FounderSovereignTokens.imperialGoldBright,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: FounderSovereignTokens.monoMetric(
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: FounderSovereignTokens.mutedInk,
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildBanners() {
    return Column(
      children: <Widget>[
        if (_infoBanner != null) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: FounderSovereignTokens.cyberCyanSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: FounderSovereignTokens.cyberCyan.withValues(alpha: 0.55),
              ),
            ),
            child: Text(
              _infoBanner!,
              style: const TextStyle(
                color: FounderSovereignTokens.primaryInk,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
        if (_errorBanner != null) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            key: const ValueKey<String>('vault-error-banner'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: FounderSovereignTokens.crimsonAlertSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FounderSovereignTokens.crimsonAlert),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.gpp_bad_rounded,
                    size: 16,
                    color: FounderSovereignTokens.crimsonAlert,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorBanner!,
                    style: const TextStyle(
                      color: FounderSovereignTokens.crimsonAlert,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPrimaryAuthCard() {
    return FounderGlassCard(
      accentTopBarColor: FounderSovereignTokens.imperialGoldBright,
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeaderBadge(
            title: 'Desperrengue CEO',
            subtitle:
                'Autentique sua identidade soberana para iniciar a verificação criptográfica em 3 camadas.',
          ),
          _buildBanners(),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            key: const ValueKey<String>('ceo-google-oauth-btn'),
            onPressed: _busy ? null : _submitGoogleOAuth,
            style: OutlinedButton.styleFrom(
              foregroundColor: FounderSovereignTokens.primaryInk,
              backgroundColor: FounderSovereignTokens.obsidianSurface,
              side: const BorderSide(color: FounderSovereignTokens.crispBorder),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            icon: const Icon(
              Icons.verified_user_rounded,
              size: 18,
              color: FounderSovereignTokens.imperialGoldBright,
            ),
            label: const Text(
              'Autenticar Conta Google Soberana',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              const Expanded(
                child: Divider(color: FounderSovereignTokens.crispBorder),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'OU CREDENCIAL DIRETA',
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: FounderSovereignTokens.mutedInk,
                  ),
                ),
              ),
              const Expanded(
                child: Divider(color: FounderSovereignTokens.crispBorder),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey<String>('ceo-auth-email-input'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            style: const TextStyle(
              color: FounderSovereignTokens.primaryInk,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              labelText: 'E-mail Soberano do Titular',
              hintText: 'Digite seu e-mail autorizado',
              prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18),
              filled: true,
              fillColor: FounderSovereignTokens.obsidianSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!_usePasswordlessPrimaryAuth) ...<Widget>[
            TextField(
              key: const ValueKey<String>('ceo-auth-password-input'),
              controller: _passwordController,
              obscureText: _obscurePassword,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              onSubmitted: (_) => _submitEmailPasswordLogin(),
              style: const TextStyle(
                color: FounderSovereignTokens.primaryInk,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                labelText: 'Senha da Conta',
                prefixIcon: const Icon(Icons.key_rounded, size: 18),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 18,
                  ),
                ),
                filled: true,
                fillColor: FounderSovereignTokens.obsidianSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey<String>('ceo-auth-submit-btn'),
              onPressed: _busy ? null : _submitEmailPasswordLogin,
              style: FilledButton.styleFrom(
                backgroundColor: FounderSovereignTokens.imperialGold,
                foregroundColor: const Color(0xFF111827),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF111827),
                      ),
                    )
                  : const Icon(Icons.shield_rounded, size: 18),
              label: const Text(
                'Validar Identidade Soberana',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ] else ...<Widget>[
            if (_primaryOtpSent) ...<Widget>[
              TextField(
                key: const ValueKey<String>('ceo-primary-otp-input'),
                controller: _primaryOtpController,
                keyboardType: TextInputType.number,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                style: FounderSovereignTokens.monoMetric(fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Código Recebido no E-mail',
                  prefixIcon: const Icon(Icons.mark_email_read_rounded, size: 18),
                  filled: true,
                  fillColor: FounderSovereignTokens.obsidianSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : (_primaryOtpSent
                      ? _verifyPasswordlessPrimaryCode
                      : _sendPasswordlessPrimaryCode),
              style: FilledButton.styleFrom(
                backgroundColor: FounderSovereignTokens.imperialGold,
                foregroundColor: const Color(0xFF111827),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: const Icon(Icons.mail_lock_rounded, size: 18),
              label: Text(
                _primaryOtpSent
                    ? 'Confirmar Código de E-mail'
                    : 'Enviar Código de Sessão ao E-mail',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _usePasswordlessPrimaryAuth = !_usePasswordlessPrimaryAuth;
                      _primaryOtpSent = false;
                      _errorBanner = null;
                    });
                  },
            child: Text(
              _usePasswordlessPrimaryAuth
                  ? 'Voltar para entrada com senha'
                  : 'Minha conta usa Google / Entrar com código no e-mail',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FounderSovereignTokens.cyberCyan,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailOtpChallengeCard() {
    final purposeSubtitle = _otpPurpose == 'PIN_RESET'
        ? 'Redefinição segura do seu PIN pessoal: valide o código de 6 dígitos enviado exclusivamente ao seu e-mail.'
        : _otpPurpose == 'NEW_DEVICE_BIND'
            ? 'Novo dispositivo detectado: valide o código de 6 dígitos enviado ao seu e-mail antes de usar seu PIN.'
            : 'Primeiro acesso soberano: valide o código de 6 dígitos no seu e-mail para criar seu próprio PIN pessoal.';

    return FounderGlassCard(
      accentTopBarColor: FounderSovereignTokens.cyberCyan,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildHeaderBadge(
            pillText: 'CAMADA 2/3 · VERIFICAÇÃO DE E-MAIL TLS',
            title: 'Código de 6 Dígitos',
            subtitle: purposeSubtitle,
          ),
          _buildBanners(),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: <Widget>[
              FilledButton.tonalIcon(
                key: const ValueKey<String>('ceo-send-otp-6d-btn'),
                onPressed: (_busy || _otpCooldownRemainingSec > 0)
                    ? null
                    : _sendSixDigitSecurityCode,
                style: FilledButton.styleFrom(
                  backgroundColor: FounderSovereignTokens.imperialGoldSoft,
                  foregroundColor: FounderSovereignTokens.imperialGoldBright,
                  minimumSize: const Size(0, 38),
                ),
                icon: const Icon(Icons.forward_to_inbox_rounded, size: 16),
                label: Text(
                  _otpCooldownRemainingSec > 0
                      ? 'Reenviar em ${_otpCooldownRemainingSec}s'
                      : (_activeOtpTicket == null
                          ? 'Enviar Código de 6 Dígitos'
                          : 'Reenviar Novo Código'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('ceo-paste-otp-btn'),
                onPressed: _busy ? null : _pasteOtpFromClipboard,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  foregroundColor: FounderSovereignTokens.primaryInk,
                  side: const BorderSide(
                    color: FounderSovereignTokens.crispBorder,
                  ),
                ),
                icon: const Icon(Icons.content_paste_rounded, size: 15),
                label: const Text(
                  'Colar',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (_remainingOtpAttempts != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Tentativas restantes neste código: $_remainingOtpAttempts/5',
              style: FounderSovereignTokens.monoMetric(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: FounderSovereignTokens.mutedInk,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _SixOpticalCellsDisplay(
            keyPrefix: 'ceo-otp-cell',
            value: _otpBuffer,
            maskDigits: false,
            accentColor: FounderSovereignTokens.cyberCyan,
          ),
          const SizedBox(height: 16),
          _SovereignPinPad(
            digits: _keypadDigits,
            scrambled: _scrambleKeypad,
            busy: _busy,
            onDigit: _onDigitPressed,
            onBackspace: _onBackspacePressed,
            onToggleScramble: _toggleScrambleKeypad,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              if (_otpPurpose == 'PIN_RESET')
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() {
                            _otpBuffer = '';
                            _errorBanner = null;
                            _stage = _VaultGateStage.pinUnlock;
                          });
                        },
                  child: const Text(
                    'Cancelar redefinição',
                    style: TextStyle(fontSize: 12),
                  ),
                )
              else
                const SizedBox.shrink(),
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        await widget.repository.signOutAndLock();
                        if (!mounted) return;
                        setState(() {
                          _stage = _VaultGateStage.primaryAuth;
                        });
                      },
                icon: const Icon(Icons.logout_rounded, size: 15),
                label: const Text(
                  'Encerrar sessão',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPinEnrollmentCard() {
    final isConfirm = _stage == _VaultGateStage.pinConfirm;
    return FounderGlassCard(
      accentTopBarColor: FounderSovereignTokens.imperialGoldBright,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildHeaderBadge(
            pillText: isConfirm
                ? 'CAMADA 3/3 · CONFIRMAÇÃO SHA-256'
                : 'CAMADA 3/3 · CRIAÇÃO DO PIN PESSOAL',
            title: isConfirm
                ? 'Confirme seu PIN Pessoal'
                : 'Crie seu PIN Pessoal',
            subtitle: isConfirm
                ? 'Digite novamente os mesmos 6 dígitos para selar seu PIN com criptografia SHA-256.'
                : 'Escolha 6 dígitos exclusivos de seu conhecimento (sem sequências como 123456 ou repetições).',
          ),
          _buildBanners(),
          const SizedBox(height: 18),
          _SixOpticalCellsDisplay(
            keyPrefix: 'ceo-pin-create-cell',
            value: _pinBuffer,
            maskDigits: true,
            accentColor: FounderSovereignTokens.imperialGoldBright,
          ),
          const SizedBox(height: 18),
          _SovereignPinPad(
            digits: _keypadDigits,
            scrambled: _scrambleKeypad,
            busy: _busy,
            onDigit: _onDigitPressed,
            onBackspace: _onBackspacePressed,
            onToggleScramble: _toggleScrambleKeypad,
          ),
          if (isConfirm) ...<Widget>[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _pinDraftFirst = '';
                        _pinBuffer = '';
                        _errorBanner = null;
                        _stage = _VaultGateStage.pinCreate;
                      });
                    },
              child: const Text(
                'Escolher outro PIN',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPinUnlockCard() {
    final isLocked = _vaultLockRemainingSec > 0;
    return FounderGlassCard(
      accentTopBarColor: isLocked
          ? FounderSovereignTokens.crimsonAlert
          : FounderSovereignTokens.imperialGoldBright,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildHeaderBadge(
            pillText: 'COFRE SOBERANO PROTEGIDO · SHA-256',
            title: isLocked
                ? 'Cofre em Bloqueio Cautelar'
                : 'Digite seu PIN Pessoal',
            subtitle: isLocked
                ? 'Aguarde ${_vaultLockRemainingSec}s para uma nova tentativa ou redefina via código de 6 dígitos no e-mail.'
                : 'Acesso exclusivo de Wagner ($kMaskedMonocraticCeoEmail). Nenhum dígito vem preenchido.',
          ),
          _buildBanners(),
          const SizedBox(height: 18),
          _SixOpticalCellsDisplay(
            keyPrefix: 'ceo-pin-unlock-cell',
            value: _pinBuffer,
            maskDigits: true,
            accentColor: isLocked
                ? FounderSovereignTokens.crimsonAlert
                : FounderSovereignTokens.imperialGoldBright,
          ),
          const SizedBox(height: 18),
          _SovereignPinPad(
            digits: _keypadDigits,
            scrambled: _scrambleKeypad,
            busy: _busy || isLocked,
            onDigit: _onDigitPressed,
            onBackspace: _onBackspacePressed,
            onToggleScramble: _toggleScrambleKeypad,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: <Widget>[
              TextButton.icon(
                key: const ValueKey<String>('ceo-reset-pin-btn'),
                onPressed: _busy
                    ? null
                    : () => _enterOtpChallengeStage('PIN_RESET', autoSend: false),
                icon: const Icon(Icons.lock_reset_rounded, size: 16),
                label: const Text(
                  'Redefinir PIN (6 dígitos e-mail)',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
              TextButton.icon(
                key: const ValueKey<String>('ceo-signout-btn'),
                onPressed: _busy
                    ? null
                    : () async {
                        await widget.repository.signOutAndLock();
                        if (!mounted) return;
                        setState(() {
                          _stage = _VaultGateStage.primaryAuth;
                        });
                      },
                icon: const Icon(Icons.logout_rounded, size: 15),
                label: const Text(
                  'Sair',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SixOpticalCellsDisplay extends StatelessWidget {
  const _SixOpticalCellsDisplay({
    required this.keyPrefix,
    required this.value,
    required this.maskDigits,
    required this.accentColor,
  });

  final String keyPrefix;
  final String value;
  final bool maskDigits;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            ((constraints.maxWidth - 5 * 8) / 6).clamp(36.0, 50.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(6, (index) {
            final hasChar = index < value.length;
            final isFocusedCell = index == value.length;
            return Container(
              key: ValueKey<String>('$keyPrefix-$index'),
              width: cellWidth,
              height: 50,
              margin: EdgeInsets.only(right: index < 5 ? 8 : 0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hasChar
                    ? accentColor.withValues(alpha: 0.14)
                    : FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasChar
                      ? accentColor
                      : isFocusedCell
                          ? accentColor.withValues(alpha: 0.55)
                          : FounderSovereignTokens.crispBorder,
                  width: hasChar || isFocusedCell ? 1.5 : 1.0,
                ),
              ),
              child: hasChar
                  ? (maskDigits
                      ? Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor,
                          ),
                        )
                      : Text(
                          value[index],
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ))
                  : const SizedBox.shrink(),
            );
          }),
        );
      },
    );
  }
}

/// Teclado vetorial tátil isolado do sistema operacional (proteção contra IME Keyloggers
/// e embaralhamento CSPRNG opcional contra observação de ombro).
class _SovereignPinPad extends StatelessWidget {
  const _SovereignPinPad({
    required this.digits,
    required this.scrambled,
    required this.busy,
    required this.onDigit,
    required this.onBackspace,
    required this.onToggleScramble,
  });

  final List<int> digits;
  final bool scrambled;
  final bool busy;
  final void Function(int digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onToggleScramble;

  @override
  Widget build(BuildContext context) {
    Widget buildDigitButton(int d) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Material(
            color: FounderSovereignTokens.obsidianSurface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: ValueKey<String>('sovereign-pad-digit-$d'),
              borderRadius: BorderRadius.circular(14),
              onTap: busy ? null : () => onDigit(d),
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: FounderSovereignTokens.crispBorder),
                ),
                child: Text(
                  '$d',
                  style: FounderSovereignTokens.monoMetric(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: busy
                        ? FounderSovereignTokens.mutedInk
                        : FounderSovereignTokens.primaryInk,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            buildDigitButton(digits[0]),
            buildDigitButton(digits[1]),
            buildDigitButton(digits[2]),
          ],
        ),
        Row(
          children: <Widget>[
            buildDigitButton(digits[3]),
            buildDigitButton(digits[4]),
            buildDigitButton(digits[5]),
          ],
        ),
        Row(
          children: <Widget>[
            buildDigitButton(digits[6]),
            buildDigitButton(digits[7]),
            buildDigitButton(digits[8]),
          ],
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Material(
                  color: scrambled
                      ? FounderSovereignTokens.imperialGoldSoft
                      : FounderSovereignTokens.obsidianSurface,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: const ValueKey<String>('sovereign-pad-scramble-btn'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: busy ? null : onToggleScramble,
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: scrambled
                              ? FounderSovereignTokens.imperialGold
                              : FounderSovereignTokens.crispBorder,
                        ),
                      ),
                      child: Tooltip(
                        message: 'Embaralhar posição dos dígitos',
                        child: Icon(
                          Icons.shuffle_rounded,
                          size: 20,
                          color: scrambled
                              ? FounderSovereignTokens.imperialGoldBright
                              : FounderSovereignTokens.mutedInk,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            buildDigitButton(digits[9]),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Material(
                  color: FounderSovereignTokens.obsidianSurface,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: const ValueKey<String>('sovereign-pad-backspace-btn'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: busy ? null : onBackspace,
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: FounderSovereignTokens.crispBorder,
                        ),
                      ),
                      child: const Icon(
                        Icons.backspace_outlined,
                        size: 20,
                        color: FounderSovereignTokens.mutedInk,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

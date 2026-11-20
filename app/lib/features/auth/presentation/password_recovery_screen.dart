import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/registration_guard_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/desperrengue_brand_logo.dart';
import 'auth_gate.dart';
import 'login_screen.dart';

/// Tela de recuperação de senha in-app em 2 etapas:
/// 1. Solicitação do código de 6 dígitos (OTP recovery) para o e-mail da conta.
/// 2. Confirmação do código de 6 dígitos + definição de nova senha forte (12–16 caracteres).
class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({
    super.key,
    this.initialEmail = '',
    @visibleForTesting this.onSendRecoveryOtp,
    @visibleForTesting this.onVerifyAndUpdatePassword,
  });

  final String initialEmail;

  @visibleForTesting
  final Future<void> Function(String email)? onSendRecoveryOtp;

  @visibleForTesting
  final Future<void> Function({
    required String email,
    required String code,
    required String newPassword,
  })? onVerifyAndUpdatePassword;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _feedbackMessage;
  bool _isErrorFeedback = false;

  String? _emailError;
  String? _otpError;
  String? _newPasswordError;
  String? _confirmPasswordError;

  static final RegExp _strongPasswordRegex = RegExp(
    r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[\W_])[A-Za-z\d\W_]{12,16}$',
  );

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail.trim().isNotEmpty) {
      _emailController.text = widget.initialEmail.trim();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.clear();
    _otpController.dispose();
    _newPasswordController.clear();
    _newPasswordController.dispose();
    _confirmPasswordController.clear();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isSupabaseInitialized() {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _validateStep1() {
    final trimmed = _emailController.text.trim();
    String? err;
    if (trimmed.isEmpty) {
      err = 'Por favor, informe o seu e-mail.';
    } else if (!trimmed.contains('@') || !trimmed.contains('.')) {
      err = 'Introduza um e-mail válido (ex: nome@dominio.com).';
    }
    setState(() => _emailError = err);
    return err == null;
  }

  bool _validateStep2() {
    final cleanCode = _otpController.text.trim();
    final pass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    String? otpErr;
    if (cleanCode.length != 6) {
      otpErr = 'Digite o código de 6 dígitos enviado para o seu e-mail.';
    }

    String? passErr;
    if (pass.isEmpty) {
      passErr = 'A nova senha é obrigatória.';
    } else if (!_strongPasswordRegex.hasMatch(pass)) {
      passErr =
          'Deve ter entre 12 e 16 caracteres (letras, números e símbolos).';
    }

    String? confirmErr;
    if (confirm != pass) {
      confirmErr = 'As senhas não coincidem.';
    }

    setState(() {
      _otpError = otpErr;
      _newPasswordError = passErr;
      _confirmPasswordError = confirmErr;
    });
    return otpErr == null && passErr == null && confirmErr == null;
  }

  Future<void> _enviarCodigoRecuperacao() async {
    if (!_validateStep1()) {
      return;
    }

    final email = _emailController.text.trim();
    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
      _isErrorFeedback = false;
    });

    try {
      if (widget.onSendRecoveryOtp != null) {
        await widget.onSendRecoveryOtp!(email);
      } else {
        await Supabase.instance.client.auth.resetPasswordForEmail(email);
      }

      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _isLoading = false;
        _isErrorFeedback = false;
        _feedbackMessage =
            'Se o e-mail estiver cadastrado, enviamos um código de 6 dígitos para sua caixa de entrada.';
      });
    } catch (e) {
      if (!mounted) return;
      final msg = RegistrationGuardService.translateAuthErrorPtBr(e);
      setState(() {
        _isLoading = false;
        _isErrorFeedback = true;
        _feedbackMessage = msg;
      });
      AppSnackbar.show(context, msg, kind: AppSnackKind.error);
    }
  }

  Future<void> _confirmarCodigoERedefinirSenha() async {
    if (!_validateStep2()) {
      return;
    }

    final email = _emailController.text.trim();
    final code = _otpController.text.trim();
    final newPassword = _newPasswordController.text;

    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
      _isErrorFeedback = false;
    });

    try {
      if (widget.onVerifyAndUpdatePassword != null) {
        await widget.onVerifyAndUpdatePassword!(
          email: email,
          code: code,
          newPassword: newPassword,
        );
      } else {
        await Supabase.instance.client.auth.verifyOTP(
          email: email,
          token: code,
          type: OtpType.recovery,
        );
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
      }

      // Limpeza imediata das credenciais em memória RAM
      _otpController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Senha redefinida com sucesso!',
        kind: AppSnackKind.success,
      );

      final Widget targetScreen = _isSupabaseInitialized()
          ? const AuthGate()
          : LoginScreen(initialEmail: email);

      Navigator.of(context).pushAndRemoveUntil(
        AppRoute<void>(builder: (_) => targetScreen),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = RegistrationGuardService.translateAuthErrorPtBr(e);
      setState(() {
        _isLoading = false;
        _isErrorFeedback = true;
        _feedbackMessage = msg;
      });
      AppSnackbar.show(context, msg, kind: AppSnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;

    return AppScaffold(
      backgroundColor: tk.background,
      appBar: AppAppBar(
        title: 'Recuperar senha',
        leading: AppIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Voltar',
          size: 20,
          onPressed: _isLoading ? null : () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            layout.margin,
            AppSpace.s12,
            layout.margin,
            AppSpace.s32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppStepper(total: 2, current: _codeSent ? 2 : 1),
              const SizedBox(height: AppSpace.s24),
              const Center(child: DesperrengueBrandLogo(size: 64)),
              const SizedBox(height: AppSpace.s16),
              Text(
                _codeSent
                    ? 'Digite o código e sua nova senha'
                    : 'Esqueceu sua senha?',
                textAlign: TextAlign.center,
                style: AppType.headline.copyWith(color: tk.accentInk),
              ),
              const SizedBox(height: AppSpace.s8),
              Text(
                _codeSent
                    ? 'Enviamos um código de 6 dígitos para ${_emailController.text.trim()}. Insira o código abaixo e escolha sua nova senha.'
                    : 'Informe o e-mail da sua conta Desperrengue para receber um código de segurança de 6 dígitos.',
                textAlign: TextAlign.center,
                style: AppType.bodySm.copyWith(color: tk.textMuted),
              ),
              const SizedBox(height: AppSpace.s24),
              if (_feedbackMessage != null) ...[
                AppCard(
                  key: const Key('password-recovery-feedback-banner'),
                  variant: AppCardVariant.tonal,
                  color: _isErrorFeedback ? tk.dangerSoft : tk.infoSoft,
                  borderColor: _isErrorFeedback
                      ? tk.danger.withValues(alpha: 0.35)
                      : tk.info.withValues(alpha: 0.35),
                  margin: const EdgeInsets.only(bottom: AppSpace.s20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _isErrorFeedback
                            ? Icons.error_outline_rounded
                            : Icons.mark_email_read_outlined,
                        color: _isErrorFeedback ? tk.dangerInk : tk.accentInk,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpace.s12),
                      Expanded(
                        child: Text(
                          _feedbackMessage!,
                          style: AppType.bodySm.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _isErrorFeedback
                                ? tk.dangerInk
                                : tk.accentInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              AnimatedSwitcher(
                duration: AppMotion.d(context, AppMotion.page),
                switchInCurve: AppMotion.pageCurve,
                switchOutCurve: AppMotion.pageReverseCurve,
                transitionBuilder: (child, animation) =>
                    AppRoute.buildSwitcherTransition(
                      context: context,
                      animation: animation,
                      child: child,
                    ),
                child: !_codeSent
                    ? _buildStep1RequestCode()
                    : _buildStep2VerifyAndReset(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1RequestCode() {
    return Column(
      key: const ValueKey('recovery-step-1'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          key: const Key('input-recovery-email'),
          controller: _emailController,
          label: 'E-mail da conta',
          hint: 'Digite seu e-mail cadastrado',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          enabled: !_isLoading,
          errorText: _emailError,
          onChanged: (_) {
            if (_emailError != null) setState(() => _emailError = null);
          },
          onSubmitted: (_) {
            if (!_isLoading) _enviarCodigoRecuperacao();
          },
        ),
        const SizedBox(height: AppSpace.s24),
        AppButton(
          key: const Key('btn-send-recovery-code'),
          label: 'Enviar código de 6 dígitos',
          loading: _isLoading,
          onPressed: _enviarCodigoRecuperacao,
        ),
      ],
    );
  }

  Widget _buildStep2VerifyAndReset() {
    final tk = context.tk;
    return Column(
      key: const ValueKey('recovery-step-2'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          key: const Key('input-recovery-otp'),
          controller: _otpController,
          label: 'Código de 6 dígitos',
          hint: '000000',
          prefixIcon: Icons.pin_outlined,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          enabled: !_isLoading,
          errorText: _otpError,
          onChanged: (_) {
            if (_otpError != null) setState(() => _otpError = null);
          },
        ),
        const SizedBox(height: AppSpace.s16),
        AppTextField(
          key: const Key('input-recovery-new-password'),
          controller: _newPasswordController,
          label: 'Nova Senha',
          hint: 'Crie sua nova senha',
          helper:
              'Conter de 12 a 16 caracteres. Use letras, caracteres especiais e números.',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: !_isNewPasswordVisible,
          textInputAction: TextInputAction.next,
          maxLength: 16,
          enabled: !_isLoading,
          errorText: _newPasswordError,
          onChanged: (_) {
            if (_newPasswordError != null) {
              setState(() => _newPasswordError = null);
            }
          },
          suffix: AppIconButton(
            icon: _isNewPasswordVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            tooltip: _isNewPasswordVisible ? 'Ocultar senha' : 'Mostrar senha',
            color: tk.textMuted,
            onPressed: () =>
                setState(() => _isNewPasswordVisible = !_isNewPasswordVisible),
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        AppTextField(
          key: const Key('input-recovery-confirm-password'),
          controller: _confirmPasswordController,
          label: 'Confirmação da Nova Senha',
          hint: 'Repita sua nova senha',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: !_isConfirmPasswordVisible,
          textInputAction: TextInputAction.done,
          maxLength: 16,
          enabled: !_isLoading,
          errorText: _confirmPasswordError,
          onChanged: (_) {
            if (_confirmPasswordError != null) {
              setState(() => _confirmPasswordError = null);
            }
          },
          onSubmitted: (_) {
            if (!_isLoading) _confirmarCodigoERedefinirSenha();
          },
          suffix: AppIconButton(
            icon: _isConfirmPasswordVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            tooltip: _isConfirmPasswordVisible
                ? 'Ocultar confirmação'
                : 'Mostrar confirmação',
            color: tk.textMuted,
            onPressed: () => setState(
              () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        AppButton(
          key: const Key('btn-confirm-password-reset'),
          label: 'Redefinir senha e entrar',
          loading: _isLoading,
          onPressed: _confirmarCodigoERedefinirSenha,
        ),
        const SizedBox(height: AppSpace.s12),
        AppButton(
          key: const Key('btn-recovery-change-email'),
          label: 'Alterar e-mail ou reenviar código',
          variant: AppButtonVariant.tertiary,
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _codeSent = false;
                    _feedbackMessage = null;
                    _otpError = null;
                    _newPasswordError = null;
                    _confirmPasswordError = null;
                  });
                },
        ),
      ],
    );
  }
}

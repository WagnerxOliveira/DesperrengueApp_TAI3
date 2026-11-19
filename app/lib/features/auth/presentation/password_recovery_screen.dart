import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/registration_guard_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/desperrengue_brand_logo.dart';
import '../../../core/ui/light_island.dart';
import '../../../core/ui/serene_route_transitions.dart';
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
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

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

  static const Color _primaryBlue = Color(0xFF003366);
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

  Future<void> _enviarCodigoRecuperacao() async {
    if (!(_emailFormKey.currentState?.validate() ?? false)) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _confirmarCodigoERedefinirSenha() async {
    if (!(_resetFormKey.currentState?.validate() ?? false)) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Senha redefinida com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      final Widget targetScreen = _isSupabaseInitialized()
          ? const AuthGate()
          : LoginScreen(initialEmail: email);

      Navigator.of(context).pushAndRemoveUntil(
        SereneAuthPageRoute<void>(builder: (_) => targetScreen),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LightIsland(
      child: AppScaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
            onPressed: _isLoading ? null : () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            'Recuperar senha',
            style: TextStyle(
              color: _primaryBlue,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: DesperrengueBrandLogo(size: 64)),
                const SizedBox(height: 14),
                Text(
                  _codeSent
                      ? 'Digite o código e sua nova senha'
                      : 'Esqueceu sua senha?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _primaryBlue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _codeSent
                      ? 'Enviamos um código de 6 dígitos para ${_emailController.text.trim()}. Insira o código abaixo e escolha sua nova senha.'
                      : 'Informe o e-mail da sua conta Desperrengue para receber um código de segurança de 6 dígitos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                if (_feedbackMessage != null) ...[
                  Container(
                    key: const Key('password-recovery-feedback-banner'),
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isErrorFeedback
                          ? Colors.red.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isErrorFeedback
                            ? Colors.red.shade200
                            : Colors.blue.shade200,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _isErrorFeedback
                              ? Icons.error_outline_rounded
                              : Icons.mark_email_read_outlined,
                          color: _isErrorFeedback
                              ? Colors.red.shade700
                              : _primaryBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _feedbackMessage!,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _isErrorFeedback
                                  ? Colors.red.shade900
                                  : _primaryBlue,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!_codeSent) _buildStep1RequestCode() else _buildStep2VerifyAndReset(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1RequestCode() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'E-mail da conta',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('input-recovery-email'),
            controller: _emailController,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            decoration: _buildInputDecoration(
              'Digite seu e-mail cadastrado',
              Icons.mail_outline,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Por favor, informe o seu e-mail.';
              }
              final trimmed = value.trim();
              if (!trimmed.contains('@') || !trimmed.contains('.')) {
                return 'Introduza um e-mail válido (ex: nome@dominio.com).';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            key: const Key('btn-send-recovery-code'),
            onPressed: _isLoading ? null : _enviarCodigoRecuperacao,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size(44, 48),
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Enviar código de 6 dígitos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2VerifyAndReset() {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Código de 6 dígitos',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('input-recovery-otp'),
            controller: _otpController,
            enabled: !_isLoading,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _buildInputDecoration(
              '000000',
              Icons.pin_outlined,
            ).copyWith(counterText: ''),
            validator: (value) {
              final clean = (value ?? '').trim();
              if (clean.length != 6) {
                return 'Digite o código de 6 dígitos enviado para o seu e-mail.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Nova Senha',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('input-recovery-new-password'),
            controller: _newPasswordController,
            enabled: !_isLoading,
            obscureText: !_isNewPasswordVisible,
            maxLength: 16,
            decoration: _buildInputDecoration(
              'Crie sua nova senha',
              Icons.lock_outline,
            ).copyWith(
              counterText: '',
              suffixIcon: IconButton(
                icon: Icon(
                  _isNewPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _isNewPasswordVisible = !_isNewPasswordVisible;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'A nova senha é obrigatória.';
              }
              if (!_strongPasswordRegex.hasMatch(value)) {
                return 'Deve ter entre 12 e 16 caracteres (letras, números e símbolos).';
              }
              return null;
            },
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6.0, bottom: 16.0),
            child: Text(
              'Conter de 12 a 16 caracteres. Use letras, caracteres especiais e números.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          const Text(
            'Confirmação da Nova Senha',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('input-recovery-confirm-password'),
            controller: _confirmPasswordController,
            enabled: !_isLoading,
            obscureText: !_isConfirmPasswordVisible,
            maxLength: 16,
            decoration: _buildInputDecoration(
              'Repita sua nova senha',
              Icons.lock_outline,
            ).copyWith(
              counterText: '',
              suffixIcon: IconButton(
                icon: Icon(
                  _isConfirmPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value != _newPasswordController.text) {
                return 'As senhas não coincidem.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            key: const Key('btn-confirm-password-reset'),
            onPressed: _isLoading ? null : _confirmarCodigoERedefinirSenha,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size(44, 48),
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Redefinir senha e entrar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          TextButton(
            key: const Key('btn-recovery-change-email'),
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 48),
            ),
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      _codeSent = false;
                      _feedbackMessage = null;
                    });
                  },
            child: const Text(
              'Alterar e-mail ou reenviar código',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}

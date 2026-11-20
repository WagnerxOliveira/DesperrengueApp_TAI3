import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/env.dart';
import '../../../core/services/registration_guard_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/desperrengue_brand_logo.dart';
import 'cadastro_verificacao_otp.dart';
import 'existing_account_sheets.dart';
import 'login_screen.dart';
import 'password_recovery_screen.dart';
import 'verificacao_step6c_termos.dart';

class CadastroDadosBasicosScreen extends StatefulWidget {
  const CadastroDadosBasicosScreen({
    super.key,
    @visibleForTesting this.customPrecheckEmail,
    @visibleForTesting this.customSignUp,
    @visibleForTesting this.customResendSignupOtp,
  });

  @visibleForTesting
  final Future<SignupEmailEligibility> Function(String email)?
  customPrecheckEmail;

  @visibleForTesting
  final Future<AuthResponse> Function({
    required String email,
    required String password,
    required String fullName,
  })?
  customSignUp;

  @visibleForTesting
  final Future<void> Function(String email)? customResendSignupOtp;

  @override
  State<CadastroDadosBasicosScreen> createState() =>
      _CadastroDadosBasicosScreenState();
}

class _CadastroDadosBasicosScreenState
    extends State<CadastroDadosBasicosScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  final _emailFocusNode = FocusNode();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _termosAceites = false;
  bool _isLoading = false;

  String? _nomeError;
  String? _emailError;
  String? _senhaError;
  String? _confirmarSenhaError;

  // Chave vem de --dart-define=ABSTRACT_API_KEY (nunca versionada). Vazia = desativado.
  final String _abstractApiKey = Env.abstractApiKey;

  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );
  static final RegExp _strongPasswordRegex = RegExp(
    r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[\W_])[A-Za-z\d\W_]{12,16}$',
  );

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _emailFocusNode.dispose();
    _senhaController.clear();
    _senhaController.dispose();
    _confirmarSenhaController.clear();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  bool _validarCampos() {
    final nome = _nomeController.text.trim();
    final email = _emailController.text;
    final senha = _senhaController.text;
    final confirmar = _confirmarSenhaController.text;

    String? nomeErr;
    if (nome.length < 3) {
      nomeErr = 'O nome deve ter pelo menos 3 caracteres.';
    } else if (nome.length > 50) {
      nomeErr = 'O nome não pode exceder 50 caracteres.';
    }

    String? emailErr;
    if (email.isEmpty) {
      emailErr = 'E-mail é obrigatório.';
    } else if (!_emailRegex.hasMatch(email.trim())) {
      emailErr = 'Introduza um e-mail válido (ex: nome@dominio.com).';
    }

    String? senhaErr;
    if (senha.isEmpty) {
      senhaErr = 'Senha é obrigatória.';
    } else if (!_strongPasswordRegex.hasMatch(senha)) {
      senhaErr =
          'Deve ter entre 12 e 16 caracteres (letras, números e símbolos).';
    }

    String? confirmarErr;
    if (confirmar != senha) {
      confirmarErr = 'As senhas não coincidem.';
    }

    setState(() {
      _nomeError = nomeErr;
      _emailError = emailErr;
      _senhaError = senhaErr;
      _confirmarSenhaError = confirmarErr;
    });
    return nomeErr == null &&
        emailErr == null &&
        senhaErr == null &&
        confirmarErr == null;
  }

  Future<bool> _validarEmailRealAPI(String email) async {
    if (_abstractApiKey.isEmpty) {
      return true;
    }

    try {
      final url = Uri.parse(
        'https://emailvalidation.abstractapi.com/v1/?api_key=$_abstractApiKey&email=$email',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['deliverability'] == 'UNDELIVERABLE') {
          return false;
        }
        return true;
      }
      return true;
    } catch (e) {
      return true;
    }
  }

  Future<void> _abrirModalContaExistente(String emailDigitado) async {
    if (!mounted) return;
    _senhaController.clear();
    _confirmarSenhaController.clear();
    setState(() {
      _isLoading = false;
    });

    final action = await ExistingAccountDetectedSheet.show(
      context,
      email: emailDigitado,
    );

    if (!mounted || action == null) return;
    switch (action) {
      case ExistingAccountSheetAction.goToLogin:
        Navigator.of(context).pushAndRemoveUntil(
          AppRoute<void>(
            builder: (_) => LoginScreen(initialEmail: emailDigitado),
          ),
          (_) => false,
        );
        break;
      case ExistingAccountSheetAction.recoverPassword:
        Navigator.of(context).push(
          AppRoute<void>(
            builder: (_) => PasswordRecoveryScreen(initialEmail: emailDigitado),
          ),
        );
        break;
      case ExistingAccountSheetAction.useOtherEmail:
        _emailFocusNode.requestFocus();
        break;
    }
  }

  Future<void> _abrirModalVerificacaoPendente(String emailDigitado) async {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    final action = await PendingVerificationDetectedSheet.show(
      context,
      email: emailDigitado,
    );

    if (!mounted || action != PendingVerificationSheetAction.resendAndVerify) {
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      if (widget.customResendSignupOtp != null) {
        await widget.customResendSignupOtp!(emailDigitado);
      } else {
        await Supabase.instance.client.auth.resend(
          type: OtpType.signup,
          email: emailDigitado,
        );
      }
    } catch (_) {
      // Mesmo se o GoTrue aplicar cooldown de segundos no reenvio,
      // levamos o usuário para a tela de confirmação do código já enviado.
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    if (!mounted) return;
    _senhaController.clear();
    _confirmarSenhaController.clear();
    AppSnackbar.show(
      context,
      'Código enviado para o seu e-mail!',
      kind: AppSnackKind.success,
    );
    Navigator.push(
      context,
      AppRoute<void>(
        builder: (context) =>
            CadastroVerificacaoOtpScreen(email: emailDigitado),
      ),
    );
  }

  Future<void> _processarCadastro() async {
    if (!_validarCampos()) {
      return;
    }

    if (!_termosAceites) {
      AppSnackbar.show(
        context,
        'Por favor, aceite os Termos de Uso para continuar.',
        kind: AppSnackKind.error,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final emailDigitado = _emailController.text.trim();

    try {
      final emailExiste = await _validarEmailRealAPI(emailDigitado);

      if (!emailExiste) {
        if (mounted) {
          AppSnackbar.show(
            context,
            'Este e-mail não existe. Introduza um e-mail verdadeiro.',
            kind: AppSnackKind.error,
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 1. Pre-check de elegibilidade antes de disparar signUp (evita o falso OTP)
      SignupEmailEligibility eligibility =
          SignupEmailEligibility.unknownFallback;
      try {
        eligibility = widget.customPrecheckEmail != null
            ? await widget.customPrecheckEmail!(emailDigitado)
            : await RegistrationGuardService().precheckEmail(emailDigitado);
      } catch (_) {
        eligibility = SignupEmailEligibility.unknownFallback;
      }

      if (eligibility == SignupEmailEligibility.alreadyRegisteredConfirmed) {
        await _abrirModalContaExistente(emailDigitado);
        return;
      }

      if (eligibility == SignupEmailEligibility.pendingEmailVerification) {
        await _abrirModalVerificacaoPendente(emailDigitado);
        return;
      }

      if (eligibility == SignupEmailEligibility.rateLimited) {
        if (mounted) {
          AppSnackbar.show(
            context,
            'Muitas tentativas seguidas. Aguarde alguns minutos antes de tentar novamente.',
            kind: AppSnackKind.error,
          );
        }
        return;
      }

      // 2. Executa signUp capturando AuthResponse para inspecionar GoTrue identities
      final AuthResponse res = widget.customSignUp != null
          ? await widget.customSignUp!(
              email: emailDigitado,
              password: _senhaController.text,
              fullName: _nomeController.text.trim(),
            )
          : await Supabase.instance.client.auth.signUp(
              email: emailDigitado,
              password: _senhaController.text,
              data: {'full_name': _nomeController.text.trim()},
            );

      // 3. CHECAGEM CRÍTICA GOTRUE:
      // Quando email confirmations estão ativas no Supabase, o GoTrue retorna
      // HTTP 200 com user.identities == [] para contas já existentes e NÃO envia OTP!
      if (RegistrationGuardService.isObfuscatedDuplicateSignUpResponse(res)) {
        await _abrirModalContaExistente(emailDigitado);
        return;
      }

      if (mounted) {
        _senhaController.clear();
        _confirmarSenhaController.clear();
        AppSnackbar.show(
          context,
          'Código enviado para o seu e-mail!',
          kind: AppSnackKind.success,
        );

        Navigator.push(
          context,
          AppRoute<void>(
            builder: (context) =>
                CadastroVerificacaoOtpScreen(email: emailDigitado),
          ),
        );
      }
    } catch (e) {
      if (RegistrationGuardService.isDuplicateAccountException(e)) {
        await _abrirModalContaExistente(emailDigitado);
        return;
      }
      if (mounted) {
        final msg = RegistrationGuardService.translateAuthErrorPtBr(e);
        AppSnackbar.show(context, msg, kind: AppSnackKind.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildFieldError(BuildContext context, String? error) {
    if (error == null) return const SizedBox.shrink();
    final tk = context.tk;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpace.s8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: tk.dangerInk,
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: Text(
                error,
                style: AppType.bodySm.copyWith(color: tk.dangerInk),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    final reduced = AppMotion.reduced(context);

    return AppScaffold(
      backgroundColor: tk.background,
      appBar: AppAppBar(
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
            AppSpace.s8,
            layout.margin,
            AppSpace.s32,
          ),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: DesperrengueBrandLogo(size: 64)),
                  const SizedBox(height: AppSpace.s12),
                  Text(
                    'Desperrengue',
                    style: AppType.displayL.copyWith(color: tk.accentInk),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    'Crie sua conta',
                    style: AppType.body.copyWith(color: tk.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.s24),
                  Text(
                    'Nome Completo',
                    style: AppType.bodyStrong.copyWith(color: tk.text),
                  ),
                  const SizedBox(height: AppSpace.s8),
                  TextFormField(
                    controller: _nomeController,
                    enabled: !_isLoading,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    style: AppType.body.copyWith(color: tk.text),
                    cursorColor: tk.accentInk,
                    onChanged: (_) {
                      if (_nomeError != null) setState(() => _nomeError = null);
                    },
                    decoration: _buildInputDecoration(
                      context,
                      'Digite seu nome completo',
                      Icons.person_outline_rounded,
                      hasError: _nomeError != null,
                    ),
                  ),
                  _buildFieldError(context, _nomeError),
                  const SizedBox(height: AppSpace.s16),
                  Text(
                    'E-mail',
                    style: AppType.bodyStrong.copyWith(color: tk.text),
                  ),
                  const SizedBox(height: AppSpace.s8),
                  TextFormField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    style: AppType.body.copyWith(color: tk.text),
                    cursorColor: tk.accentInk,
                    onChanged: (_) {
                      if (_emailError != null) {
                        setState(() => _emailError = null);
                      }
                    },
                    decoration: _buildInputDecoration(
                      context,
                      'Digite seu e-mail',
                      Icons.mail_outline_rounded,
                      hasError: _emailError != null,
                    ),
                  ),
                  _buildFieldError(context, _emailError),
                  const SizedBox(height: AppSpace.s16),
                  Text(
                    'Senha',
                    style: AppType.bodyStrong.copyWith(color: tk.text),
                  ),
                  const SizedBox(height: AppSpace.s8),
                  TextFormField(
                    controller: _senhaController,
                    enabled: !_isLoading,
                    obscureText: !_isPasswordVisible,
                    maxLength: 16,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    style: AppType.body.copyWith(color: tk.text),
                    cursorColor: tk.accentInk,
                    onChanged: (_) {
                      if (_senhaError != null) {
                        setState(() => _senhaError = null);
                      }
                    },
                    decoration:
                        _buildInputDecoration(
                          context,
                          'Crie sua senha',
                          Icons.lock_outline_rounded,
                          hasError: _senhaError != null,
                        ).copyWith(
                          counterText: '',
                          suffixIcon: AppIconButton(
                            icon: _isPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            tooltip: _isPasswordVisible
                                ? 'Ocultar senha'
                                : 'Mostrar senha',
                            color: tk.textMuted,
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                  ),
                  _buildFieldError(context, _senhaError),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpace.s8,
                      bottom: AppSpace.s16,
                    ),
                    child: Text(
                      'Conter de 12 a 16 caracteres. Use letras, caracteres especiais e números.',
                      style: AppType.caption.copyWith(color: tk.textMuted),
                    ),
                  ),
                  Text(
                    'Confirmação de Senha',
                    style: AppType.bodyStrong.copyWith(color: tk.text),
                  ),
                  const SizedBox(height: AppSpace.s8),
                  TextFormField(
                    controller: _confirmarSenhaController,
                    enabled: !_isLoading,
                    obscureText: !_isConfirmPasswordVisible,
                    maxLength: 16,
                    textInputAction: TextInputAction.done,
                    style: AppType.body.copyWith(color: tk.text),
                    cursorColor: tk.accentInk,
                    onChanged: (_) {
                      if (_confirmarSenhaError != null) {
                        setState(() => _confirmarSenhaError = null);
                      }
                    },
                    decoration:
                        _buildInputDecoration(
                          context,
                          'Repita sua senha',
                          Icons.lock_outline_rounded,
                          hasError: _confirmarSenhaError != null,
                        ).copyWith(
                          counterText: '',
                          suffixIcon: AppIconButton(
                            icon: _isConfirmPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            tooltip: _isConfirmPasswordVisible
                                ? 'Ocultar confirmação'
                                : 'Mostrar confirmação',
                            color: tk.textMuted,
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible =
                                    !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                        ),
                  ),
                  _buildFieldError(context, _confirmarSenhaError),
                  const SizedBox(height: AppSpace.s24),
                  AppCard(
                    variant: AppCardVariant.tonal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s12,
                      vertical: AppSpace.s8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _termosAceites,
                          activeColor: tk.accent,
                          checkColor: tk.onAccent,
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  setState(() {
                                    _termosAceites = value ?? false;
                                  });
                                },
                        ),
                        const SizedBox(width: AppSpace.s4),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppSpace.s8),
                            onTap: () {
                              Navigator.push(
                                context,
                                AppRoute<void>(
                                  builder: (_) =>
                                      const VerificacaoStep6cTermosScreen(),
                                ),
                              );
                            },
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: AppGeometry.minTarget,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpace.s8,
                                  ),
                                  child: Text.rich(
                                    TextSpan(
                                      style: AppType.bodySm.copyWith(
                                        color: tk.text,
                                      ),
                                      children: [
                                        const TextSpan(
                                          text: 'Li e concordo com os ',
                                        ),
                                        TextSpan(
                                          text: 'Termos de Uso e Mandato Legal',
                                          style: AppType.bodySm.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: tk.accentInk,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                        const TextSpan(text: ' e '),
                                        TextSpan(
                                          text: 'Política de Privacidade',
                                          style: AppType.bodySm.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: tk.accentInk,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.s24),
                  AppPressScale(
                    enabled: !_isLoading,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _processarCadastro,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tk.accent,
                        foregroundColor: tk.onAccent,
                        disabledBackgroundColor: _isLoading
                            ? tk.accent
                            : tk.surfaceInset,
                        disabledForegroundColor: _isLoading
                            ? tk.onAccent
                            : tk.textMuted,
                        splashFactory:
                            reduced ? NoSplash.splashFactory : null,
                        minimumSize: const Size(
                          double.infinity,
                          AppGeometry.buttonHeight,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s20,
                          vertical: AppSpace.s16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppGeometry.buttonRadius,
                          ),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? AppProgressRing(
                              value: 0.72,
                              size: 20,
                              strokeWidth: 2.4,
                              color: tk.onAccent,
                              semanticLabel: 'Cadastrando',
                            )
                          : Text(
                              'Cadastrar',
                              textAlign: TextAlign.center,
                              style: AppType.button.copyWith(
                                color: tk.onAccent,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s20),
                  Center(
                    child: AppPressable(
                      onTap: _isLoading ? null : () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(
                        AppGeometry.fieldRadius,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: AppGeometry.minTarget,
                          minHeight: AppGeometry.minTarget,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s12,
                            vertical: AppSpace.s8,
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: Text.rich(
                              TextSpan(
                                text: 'Já tem uma conta? ',
                                style: AppType.body.copyWith(
                                  color: tk.textMuted,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Faça Login',
                                    style: AppType.bodyStrong.copyWith(
                                      color: tk.accentInk,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
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

  InputDecoration _buildInputDecoration(
    BuildContext context,
    String hint,
    IconData icon, {
    bool hasError = false,
  }) {
    final tk = context.tk;
    final radius = BorderRadius.circular(AppGeometry.fieldRadius);
    final borderColor = hasError ? tk.dangerInk : tk.border;
    final focusColor = hasError ? tk.dangerInk : tk.accentInk;
    return InputDecoration(
      hintText: hint,
      hintStyle: AppType.body.copyWith(color: tk.textMuted),
      prefixIcon: Icon(
        icon,
        color: hasError ? tk.dangerInk : tk.textMuted,
        size: 22,
      ),
      filled: true,
      fillColor: tk.isDark ? tk.surface : tk.surfaceInset,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: AppSpace.s16,
      ),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: borderColor, width: hasError ? 2 : 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: borderColor, width: hasError ? 2 : 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: focusColor, width: 2),
      ),
    );
  }
}

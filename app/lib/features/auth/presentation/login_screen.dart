import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/registration_guard_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/desperrengue_brand_logo.dart';
import 'auth_gate.dart';
import 'cadastro_dados_basicos.dart';
import 'cadastro_verificacao_otp.dart';
import 'password_recovery_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // ===========================================================================
  // VARIÁVEIS DE ESTADO
  // ===========================================================================
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;

  // ===========================================================================
  // CICLO DE VIDA
  // (O deep link do e-mail de aprovação agora é tratado no AuthGate.)
  // ===========================================================================
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
    _passwordController.clear(); // Limpeza de RAM por segurança
    _passwordController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // LÓGICA DE NEGÓCIO (AUTENTICAÇÃO REAL)
  // ===========================================================================

  /// Depois de autenticar, o AuthGate consulta o perfil no servidor e decide a
  /// tela (escolha de papel, KYC, home...). Nunca mais "todo login -> escolha de papel".
  void _irParaRaiz() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      AppRoute<void>(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  bool _validarFormulario() {
    final email = _emailController.text.trim();
    final senha = _passwordController.text;

    String? emailErr;
    if (email.isEmpty) {
      emailErr = 'Por favor, insira o seu e-mail.';
    } else if (!email.contains('@') || !email.contains('.')) {
      emailErr = 'Insira um e-mail válido.';
    }

    String? senhaErr;
    if (senha.isEmpty) {
      senhaErr = 'Por favor, insira a sua senha.';
    }

    setState(() {
      _emailError = emailErr;
      _passwordError = senhaErr;
    });
    return emailErr == null && senhaErr == null;
  }

  Future<void> _entrarComEmail() async {
    if (!_validarFormulario()) return;

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      _irParaRaiz();
    } on AuthException catch (e) {
      if (mounted) {
        final rawLower = '${e.code ?? ''} ${e.message}'.toLowerCase();
        final isUnconfirmed =
            rawLower.contains('email not confirmed') ||
            rawLower.contains('email_not_confirmed');
        final msg = RegistrationGuardService.translateAuthErrorPtBr(e);
        final typedEmail = _emailController.text.trim();
        AppSnackbar.show(
          context,
          msg,
          kind: AppSnackKind.error,
          actionLabel: isUnconfirmed && typedEmail.isNotEmpty
              ? 'Confirmar código'
              : null,
          onAction: isUnconfirmed && typedEmail.isNotEmpty
              ? () {
                  Navigator.of(context).push(
                    AppRoute<void>(
                      builder: (_) =>
                          CadastroVerificacaoOtpScreen(email: typedEmail),
                    ),
                  );
                }
              : null,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          RegistrationGuardService.translateAuthErrorPtBr(e),
          kind: AppSnackKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _entrarComGoogle() async {
    setState(() => _isLoading = true);

    try {
      // Abre o navegador/seletor de contas. O login só termina quando o Google
      // devolve o usuário por deep link: nesse momento o Supabase cria a sessão
      // e o AuthGate (que escuta onAuthStateChange) troca a tela sozinho.
      final bool abriuTelaDeLogin = await Supabase.instance.client.auth
          .signInWithOAuth(
            OAuthProvider.google,
            authScreenLaunchMode: LaunchMode.platformDefault,
            redirectTo: 'br.com.desperrengue.app://login-callback',
            queryParams: {'prompt': 'select_account'},
          );

      if (!abriuTelaDeLogin) {
        throw 'Não foi possível iniciar o login com o Google.';
      }
    } on AuthException catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          RegistrationGuardService.translateAuthErrorPtBr(e),
          kind: AppSnackKind.error,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          RegistrationGuardService.translateAuthErrorPtBr(e),
          kind: AppSnackKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================================
  // INTERFACE VISUAL (BUILD)
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    final canPop = Navigator.of(context).canPop();

    return AppScaffold(
      backgroundColor: tk.background,
      appBar: AppAppBar(
        automaticallyImplyLeading: false,
        leading: canPop
            ? AppIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: 'Voltar',
                size: 20,
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).maybePop(),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            layout.margin,
            AppSpace.s12,
            layout.margin,
            AppSpace.s32,
          ),
          child: AutofillGroup(
            child: AppStagger(
              spacing: AppSpace.s16,
              children: [
                Column(
                  children: [
                    const DesperrengueBrandLogo(size: 72),
                    const SizedBox(height: AppSpace.s16),
                    Text(
                      'Desperrengue',
                      style: AppType.displayL.copyWith(color: tk.accentInk),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpace.s4),
                    Text(
                      'Acesse sua conta',
                      style: AppType.body.copyWith(color: tk.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s8),
                AppTextField(
                  controller: _emailController,
                  label: 'E-mail',
                  hint: 'voce@exemplo.com',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  enabled: !_isLoading,
                  errorText: _emailError,
                  onChanged: (_) {
                    if (_emailError != null) {
                      setState(() => _emailError = null);
                    }
                  },
                ),
                AppTextField(
                  controller: _passwordController,
                  label: 'Senha',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: !_isPasswordVisible,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  enabled: !_isLoading,
                  errorText: _passwordError,
                  onChanged: (_) {
                    if (_passwordError != null) {
                      setState(() => _passwordError = null);
                    }
                  },
                  onSubmitted: (_) {
                    if (!_isLoading) _entrarComEmail();
                  },
                  suffix: AppIconButton(
                    icon: _isPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    tooltip: _isPasswordVisible
                        ? 'Ocultar senha'
                        : 'Mostrar senha',
                    color: tk.textMuted,
                    onPressed: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                    key: const Key('btn-login-forgot-password'),
                    label: 'Esqueci minha senha?',
                    variant: AppButtonVariant.tertiary,
                    expand: false,
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              AppRoute<void>(
                                builder: (_) => PasswordRecoveryScreen(
                                  initialEmail: _emailController.text.trim(),
                                ),
                              ),
                            );
                          },
                  ),
                ),
                AppButton(
                  label: 'Entrar',
                  loading: _isLoading,
                  onPressed: _entrarComEmail,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: tk.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s16,
                        ),
                        child: Text(
                          'ou',
                          style: AppType.bodySm.copyWith(color: tk.textMuted),
                        ),
                      ),
                      Expanded(child: Divider(color: tk.border)),
                    ],
                  ),
                ),
                AppButton(
                  label: 'Continuar com Google',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.g_mobiledata_rounded,
                  onPressed: _isLoading ? null : _entrarComGoogle,
                ),
                AppPressScale(
                  enabled: !_isLoading,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : () {},
                    icon: Icon(
                      Icons.apple,
                      size: 24,
                      color: tk.background,
                    ),
                    label: Text(
                      'Continuar com Apple',
                      textAlign: TextAlign.center,
                      style: AppType.button.copyWith(color: tk.background),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: tk.text,
                      foregroundColor: tk.background,
                      minimumSize: const Size(
                        double.infinity,
                        AppGeometry.buttonHeight,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppGeometry.buttonRadius,
                        ),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s8),
                Center(
                  child: AppPressable(
                    onTap: _isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              AppRoute<void>(
                                builder: (context) =>
                                    const CadastroDadosBasicosScreen(),
                              ),
                            );
                          },
                    borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
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
                              text: 'Não tem conta? ',
                              style: AppType.body.copyWith(color: tk.textMuted),
                              children: [
                                TextSpan(
                                  text: 'Cadastre-se',
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
    );
  }
}

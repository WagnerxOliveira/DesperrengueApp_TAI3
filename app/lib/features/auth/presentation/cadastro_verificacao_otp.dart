import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/legal_mandate_service.dart';
import '../../../core/services/welcome_cinema_tracker.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import 'cadastro_sucesso_routing.dart';

class CadastroVerificacaoOtpScreen extends StatefulWidget {
  final String email;
  const CadastroVerificacaoOtpScreen({super.key, required this.email});

  @override
  State<CadastroVerificacaoOtpScreen> createState() =>
      _CadastroVerificacaoOtpScreenState();
}

class _CadastroVerificacaoOtpScreenState
    extends State<CadastroVerificacaoOtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String? _otpError;

  // ===========================================================================
  // ESTADOS DO CRONÔMETRO PROGRESSIVO (EXPONENTIAL BACKOFF)
  // ===========================================================================
  Timer? _timer;
  int _segundosRestantes = 0;
  int _tentativasReenvio = 0;
  bool _isResending = false;

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.clear();
    _otpController.dispose();
    super.dispose();
  }

  /// Lógica de Reenvio Progressivo com a sequência exata (20s, 45s, 120s, 2m, 15m)
  void _iniciarCronometro() {
    _tentativasReenvio++;

    int tempoBase = 20; // 1ª tentativa: 20 segundos

    if (_tentativasReenvio == 2) {
      tempoBase = 45; // 2ª tentativa: 45 segundos
    } else if (_tentativasReenvio == 3) {
      tempoBase = 120; // 3ª tentativa: 120 segundos
    } else if (_tentativasReenvio == 4) {
      tempoBase = 120; // 4ª tentativa: 2 minutos (120s)
    } else if (_tentativasReenvio >= 5) {
      tempoBase = 900; // 5ª tentativa em diante: 15 minutos (900s)
    }

    setState(() {
      _segundosRestantes = tempoBase;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_segundosRestantes > 0) {
        setState(() {
          _segundosRestantes--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  /// Comunicação com o Servidor para Reenviar OTP
  Future<void> _reenviarCodigo() async {
    setState(() => _isResending = true);

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      _iniciarCronometro(); // Dispara o bloqueio de tempo

      if (mounted) {
        AppSnackbar.show(
          context,
          'Novo código solicitado ao servidor!',
          kind: AppSnackKind.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          'Aguarde um momento antes de pedir um novo código (Limite de Servidor).',
          kind: AppSnackKind.warning,
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verificarCodigo() async {
    final token = _otpController.text.trim();

    if (token.length != 6) {
      setState(() => _otpError = 'O código deve ter exatamente 6 dígitos.');
      AppSnackbar.show(
        context,
        'O código deve ter exatamente 6 dígitos.',
        kind: AppSnackKind.error,
      );
      return;
    }

    setState(() {
      _otpError = null;
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: token,
        type: OtpType.signup,
      );

      await WelcomeCinemaTracker.armForFreshRegistration(
        Supabase.instance.client.auth.currentUser?.id,
      );

      unawaited(
        LegalMandateService.recordAcceptanceIfAuthenticated(
          roleScope: 'CLIENT',
        ),
      );

      if (mounted) {
        AppSnackbar.show(
          context,
          'E-mail verificado com sucesso!',
          kind: AppSnackKind.success,
        );

        Navigator.pushReplacement(
          context,
          AppRoute<void>(
            builder: (context) => const CadastroSucessoRoutingScreen(),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          'Erro: ${e.message}',
          kind: AppSnackKind.error,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          'Código inválido ou expirado.',
          kind: AppSnackKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Função auxiliar para formatar os segundos em M:SS (ex: 15:00) quando passa de 60s
  String _formatarTempoRestante(int segundosTotais) {
    if (segundosTotais < 60) return '$segundosTotais segundos';

    final int minutos = segundosTotais ~/ 60;
    final int segundos = segundosTotais % 60;
    final String segundosFormatados = segundos.toString().padLeft(2, '0');

    return '$minutos:$segundosFormatados minutos';
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;

    return AppScaffold(
      backgroundColor: tk.background,
      appBar: AppAppBar(
        leading: AppIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Voltar',
          size: 20,
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                layout.margin,
                AppSpace.s16,
                layout.margin,
                AppSpace.s32,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - AppSpace.s48)
                      .clamp(0.0, double.infinity),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: tk.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.mark_email_read_outlined,
                          color: tk.accentInk,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s20),
                    Text(
                      'Verifique seu e-mail',
                      style: AppType.display.copyWith(color: tk.accentInk),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpace.s12),
                    Text(
                      'Digite o código de 6 dígitos\nenviado para ${widget.email}',
                      textAlign: TextAlign.center,
                      style: AppType.body.copyWith(color: tk.textMuted),
                    ),
                    const SizedBox(height: AppSpace.s32),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      enabled: !_isLoading,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: AppType.figure.copyWith(
                        letterSpacing: 12,
                        color: tk.text,
                      ),
                      cursorColor: tk.accentInk,
                      onChanged: (_) {
                        if (_otpError != null) setState(() => _otpError = null);
                      },
                      onSubmitted: (_) {
                        if (!_isLoading) _verificarCodigo();
                      },
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '000000',
                        hintStyle: AppType.figure.copyWith(
                          letterSpacing: 12,
                          color: tk.textMuted,
                        ),
                        filled: true,
                        fillColor: tk.isDark ? tk.surface : tk.surfaceInset,
                        errorText: _otpError,
                        errorMaxLines: 2,
                        errorStyle: AppType.bodySm.copyWith(
                          color: tk.dangerInk,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s16,
                          vertical: AppSpace.s16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppGeometry.fieldRadius,
                          ),
                          borderSide: BorderSide(color: tk.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppGeometry.fieldRadius,
                          ),
                          borderSide: BorderSide(color: tk.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppGeometry.fieldRadius,
                          ),
                          borderSide: BorderSide(color: tk.accentInk, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppGeometry.fieldRadius,
                          ),
                          borderSide: BorderSide(color: tk.dangerInk, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s24),
                    AppButton(
                      label: 'Confirmar Código',
                      loading: _isLoading,
                      onPressed: _verificarCodigo,
                    ),
                    const SizedBox(height: AppSpace.s20),
                    // =========================================================
                    // INTERFACE DO BOTÃO DE REENVIO INTELIGENTE
                    // =========================================================
                    Center(
                      child: _segundosRestantes > 0
                          ? Text(
                              'Aguarde ${_formatarTempoRestante(_segundosRestantes)} para reenviar.',
                              textAlign: TextAlign.center,
                              style: AppType.tabular(AppType.bodyStrong)
                                  .copyWith(color: tk.textMuted),
                            )
                          : AppButton(
                              label: 'Não recebeu o código? Reenviar',
                              variant: AppButtonVariant.tertiary,
                              expand: false,
                              loading: _isResending,
                              onPressed: _isResending ? null : _reenviarCodigo,
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

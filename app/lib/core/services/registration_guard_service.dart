import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../ui/kyc_human_feedback_translator.dart';

/// Resultado determinístico e sem PII da pré-checagem de elegibilidade de e-mail.
enum SignupEmailEligibility {
  available,
  alreadyRegisteredConfirmed,
  pendingEmailVerification,
  rateLimited,
  unknownFallback,
}

/// Escudo de segurança e experiência humana para fluxos de criação de conta,
/// login e recuperação de senha (100% Web-safe, zero `dart:io`, zero vazamento de PII).
///
/// Resolve na raiz:
///  1. O retorno silencioso/ofuscado do Supabase GoTrue (`enable_confirmations = true`),
///     onde `signUp` para um e-mail já confirmado devolve HTTP 200 com
///     `user.identities == []` e não dispara e-mail OTP.
///  2. A pré-checagem com piso temporal constante (`signup-eligibility-guard`)
///     capaz de distinguir conta confirmada, verificação pendente e rate-limit.
///  3. A tradução integral de exceções técnicas/em inglês do GoTrue para
///     orientações claras, educadas e acionáveis em português brasileiro.
class RegistrationGuardService {
  const RegistrationGuardService([SupabaseClient? client]) : _client = client;

  final SupabaseClient? _client;

  static final String _sessionClientNonce = _generateSessionNonce();

  static String _generateSessionNonce() {
    final Random rng = _createSafeRandom();
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < 16; i++) {
      sb.write(rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static Random _createSafeRandom() {
    try {
      return Random.secure();
    } catch (_) {
      return Random();
    }
  }

  /// Pré-checagem segura via Edge Function `signup-eligibility-guard` (timeout curto 4s;
  /// se offline/erro de rede, retorna `SignupEmailEligibility.unknownFallback` para não
  /// travar o cadastro legítimo e delegar à checagem determinística de `AuthResponse`).
  Future<SignupEmailEligibility> precheckEmail(String email) async {
    final String normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      return SignupEmailEligibility.available;
    }

    final SupabaseClient client;
    try {
      client = _client ?? Supabase.instance.client;
    } catch (_) {
      return SignupEmailEligibility.unknownFallback;
    }

    try {
      final FunctionResponse res = await client.functions
          .invoke(
            'signup-eligibility-guard',
            body: <String, dynamic>{
              'email': normalized,
              'client_nonce': _sessionClientNonce,
            },
          )
          .timeout(const Duration(seconds: 4));

      return _parseEligibilityPayload(res.status, res.data);
    } on FunctionException catch (e) {
      if (e.status == 429) {
        return SignupEmailEligibility.rateLimited;
      }
      return _parseEligibilityPayload(e.status, e.details);
    } on TimeoutException {
      return SignupEmailEligibility.unknownFallback;
    } catch (_) {
      return SignupEmailEligibility.unknownFallback;
    }
  }

  static SignupEmailEligibility _parseEligibilityPayload(
    int httpStatus,
    Object? rawPayload,
  ) {
    if (httpStatus == 429) {
      return SignupEmailEligibility.rateLimited;
    }
    if (httpStatus < 200 || httpStatus >= 300) {
      return SignupEmailEligibility.unknownFallback;
    }

    Map<String, dynamic>? map;
    if (rawPayload is Map) {
      map = Map<String, dynamic>.from(rawPayload);
    } else if (rawPayload is String && rawPayload.trim().isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(rawPayload);
        if (decoded is Map) {
          map = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return SignupEmailEligibility.unknownFallback;
      }
    }

    final String status = (map?['status'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    switch (status) {
      case 'AVAILABLE':
        return SignupEmailEligibility.available;
      case 'ALREADY_REGISTERED_CONFIRMED':
        return SignupEmailEligibility.alreadyRegisteredConfirmed;
      case 'PENDING_EMAIL_VERIFICATION':
        return SignupEmailEligibility.pendingEmailVerification;
      case 'RATE_LIMITED':
        return SignupEmailEligibility.rateLimited;
      default:
        return SignupEmailEligibility.unknownFallback;
    }
  }

  /// Detecta o retorno ofuscado de conta já existente do Supabase GoTrue:
  /// `res.user == null || (res.user!.identities != null && res.user!.identities!.isEmpty)`.
  static bool isObfuscatedDuplicateSignUpResponse(AuthResponse response) {
    final User? user = response.user;
    return user == null ||
        (user.identities != null && user.identities!.isEmpty);
  }

  /// Detecta se uma exceção de `signUp`/`resend` indica e-mail já cadastrado.
  static bool isDuplicateAccountException(Object error) {
    if (isRateLimitException(error)) return false;

    final String code = _extractErrorCodeLower(error);
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        code == 'identity_already_exists') {
      return true;
    }

    final String text = _extractSearchableTextLower(error);
    return text.contains('user already registered') ||
        text.contains('user_already_registered') ||
        text.contains('user_already_exists') ||
        text.contains('email_exists') ||
        text.contains('identity_already_exists') ||
        text.contains('already been registered') ||
        text.contains('already registered') ||
        text.contains('email address is already') ||
        text.contains('e-mail já está cadastrado') ||
        text.contains('e-mail ja esta cadastrado') ||
        text.contains('já possui uma conta') ||
        text.contains('ja possui uma conta');
  }

  /// Detecta se uma exceção indica limite de tentativas/tempo (rate limit).
  static bool isRateLimitException(Object error) {
    if (error is AuthException && error.statusCode?.trim() == '429') {
      return true;
    }
    if (error is FunctionException && error.status == 429) {
      return true;
    }

    final String code = _extractErrorCodeLower(error);
    if (code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        code == 'over_sms_send_rate_limit' ||
        code == 'rate_limit' ||
        code == 'too_many_requests') {
      return true;
    }

    final String text = _extractSearchableTextLower(error);
    return text.contains('over_email_send_rate_limit') ||
        text.contains('over_request_rate_limit') ||
        text.contains('over_sms_send_rate_limit') ||
        text.contains('email rate limit exceeded') ||
        text.contains('rate limit') ||
        text.contains('rate_limit') ||
        text.contains('too many requests') ||
        text.contains('you can only request this after') ||
        text.contains('you can only request this once every') ||
        text.contains('err_signup_guard_rate_limited') ||
        text.contains('statuscode: 429') ||
        text.contains('status: 429');
  }

  /// Traduz qualquer erro de autenticação (`AuthException`, rede, rate-limit, senha fraca,
  /// código OTP inválido/expirado) para português humano claro, educado e sem inglês/jargão.
  static String translateAuthErrorPtBr(Object error) {
    if (isDuplicateAccountException(error)) {
      return 'Este e-mail já está cadastrado no Desperrengue. Entre na sua conta existente ou toque em "Esqueci minha senha" para recuperar o acesso.';
    }

    if (isRateLimitException(error)) {
      return 'Muitas tentativas seguidas por segurança. Aguarde alguns minutos antes de solicitar um novo código ou tentar novamente.';
    }

    final String code = _extractErrorCodeLower(error);
    final String text = _extractSearchableTextLower(error);

    if (code == 'email_not_confirmed' || text.contains('email not confirmed')) {
      return 'Seu e-mail ainda não foi confirmado. Digite o código de 6 dígitos enviado para sua caixa de entrada para ativar sua conta.';
    }

    if (code == 'invalid_credentials' ||
        text.contains('invalid login credentials') ||
        text.contains('invalid email or password') ||
        text.contains('wrong password')) {
      return 'E-mail ou senha incorretos. Confira os dados digitados ou toque em "Esqueci minha senha" para redefinir.';
    }

    if (code == 'otp_expired' ||
        code == 'otp_disabled' ||
        code == 'flow_state_expired' ||
        text.contains('token has expired') ||
        text.contains('expired or is invalid') ||
        text.contains('token is invalid') ||
        text.contains('invalid otp') ||
        text.contains('otp_expired')) {
      return 'O código de 6 dígitos está incorreto ou expirou. Solicite um novo código e digite os números mais recentes enviados ao seu e-mail.';
    }

    if (code == 'same_password' ||
        text.contains('different from the old password') ||
        text.contains('same_password')) {
      return 'A nova senha precisa ser diferente da senha anterior. Escolha uma combinação inédita para proteger sua conta.';
    }

    if (code == 'weak_password' ||
        text.contains('password should be at least') ||
        text.contains('password is known to be weak') ||
        text.contains('weak_password')) {
      return 'A senha informada é muito simples. Crie uma senha forte com letras, números e símbolos.';
    }

    if (code == 'email_address_invalid' ||
        code == 'email_address_not_authorized' ||
        code == 'validation_failed' ||
        text.contains('unable to validate email address') ||
        text.contains('invalid email') ||
        text.contains('email_address_invalid')) {
      return 'Não conseguimos validar este endereço de e-mail. Confira se ele foi digitado corretamente.';
    }

    if (text.contains('err_duplicate_cpf_identity')) {
      return 'Identificamos que este CPF já possui cadastro no Desperrengue. Para sua segurança, entre na sua conta principal — ela já libera tanto o modo Cliente quanto o modo Profissional.';
    }

    if (code == 'access_denied' ||
        text.contains('popup_closed') ||
        text.contains('sign_in_canceled') ||
        text.contains('cancelled') ||
        text.contains('canceled')) {
      return 'Acesso externo cancelado. Você pode tentar novamente ou entrar com seu e-mail e senha.';
    }

    if (code == 'session_not_found' ||
        code == 'refresh_token_not_found' ||
        code == 'bad_jwt' ||
        text.contains('err_unauthenticated') ||
        text.contains('jwt expired')) {
      return 'Sua sessão expirou por segurança. Entre novamente na sua conta para continuar.';
    }

    if (error is TimeoutException ||
        text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('timeoutexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection refused') ||
        text.contains('connection closed') ||
        text.contains('xmlhttprequest error') ||
        text.contains('networkerror') ||
        text.contains('handshakeexception')) {
      return 'Sem conexão estável com a internet no momento. Verifique seu sinal de Wi-Fi ou dados móveis e tente novamente.';
    }

    if (error is AuthException) {
      final String candidate = error.message.trim();
      if (candidate.isNotEmpty &&
          !_looksLikeRawEnglishOrTechnicalMessage(candidate) &&
          !KycHumanFeedbackTranslator.containsBannedTechnicalJargon(candidate)) {
        return candidate;
      }
    }

    return 'Não foi possível concluir sua solicitação agora. Confira os dados informados e tente novamente em instantes.';
  }

  static String _extractErrorCodeLower(Object error) {
    if (error is AuthException) {
      return (error.code ?? '').trim().toLowerCase();
    }
    if (error is PostgrestException) {
      return (error.code ?? '').trim().toLowerCase();
    }
    return '';
  }

  static String _extractSearchableTextLower(Object error) {
    if (error is AuthException) {
      return '${error.code ?? ''} ${error.statusCode ?? ''} ${error.message}'
          .toLowerCase();
    }
    if (error is PostgrestException) {
      return '${error.code ?? ''} ${error.message} ${error.details ?? ''}'
          .toLowerCase();
    }
    if (error is FunctionException) {
      return 'status: ${error.status} ${error.reasonPhrase ?? ''} ${error.details ?? ''}'
          .toLowerCase();
    }
    return error.toString().toLowerCase();
  }

  static final RegExp _rawEnglishOrTechRe = RegExp(
    r'\b(?:user|already|registered|invalid|error|failed|failure|exception|'
    r'token|expired|password|email|status|request|limit|supabase|gotrue|'
    r'http|null|unexpected|forbidden|unauthorized|not\s+found|unable\s+to|'
    r'missing|bad\s+state)\b',
    caseSensitive: false,
  );

  static bool _looksLikeRawEnglishOrTechnicalMessage(String text) {
    return _rawEnglishOrTechRe.hasMatch(text);
  }
}

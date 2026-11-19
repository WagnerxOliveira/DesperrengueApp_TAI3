import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:desperrengue_app/core/services/profile_service.dart';
import 'package:desperrengue_app/core/services/registration_guard_service.dart';
import 'package:desperrengue_app/core/ui/kyc_human_feedback_translator.dart';

typedef _MockHttpHandler = Future<http.Response> Function(
  _CapturedRequest request,
);

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.url,
    required this.headers,
    required this.bodyBytes,
  });

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final List<int> bodyBytes;

  String get body => utf8.decode(bodyBytes);
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._handler);

  final _MockHttpHandler _handler;
  final List<_CapturedRequest> capturedRequests = <_CapturedRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    final captured = _CapturedRequest(
      method: request.method,
      url: request.url,
      headers: Map<String, String>.from(request.headers),
      bodyBytes: bytes,
    );
    capturedRequests.add(captured);

    final response = await _handler(captured);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}

User _buildTestUser({List<UserIdentity>? identities}) {
  return User(
    id: '11111111-2222-4333-8444-555555555555',
    appMetadata: const <String, dynamic>{'provider': 'email'},
    userMetadata: const <String, dynamic>{'full_name': 'Maria Silva'},
    aud: 'authenticated',
    email: 'maria@exemplo.com.br',
    createdAt: '2026-11-18T20:00:00.000Z',
    identities: identities,
  );
}

UserIdentity _buildEmailIdentity() {
  return const UserIdentity(
    id: 'id-email-1',
    userId: '11111111-2222-4333-8444-555555555555',
    identityData: <String, dynamic>{'email': 'maria@exemplo.com.br'},
    identityId: '22222222-3333-4444-8555-666666666666',
    provider: 'email',
    createdAt: '2026-11-18T20:00:00.000Z',
    lastSignInAt: '2026-11-18T20:00:00.000Z',
  );
}

void main() {
  group('1. Detecção determinística do retorno ofuscado do Supabase GoTrue', () {
    test('detecta AuthResponse com user == null como conta duplicada/inválida', () {
      final response = AuthResponse(user: null, session: null);
      expect(
        RegistrationGuardService.isObfuscatedDuplicateSignUpResponse(response),
        isTrue,
      );
    });

    test(
      'detecta AuthResponse ofuscado com identities vazia ([]) retornado pelo GoTrue para e-mail já confirmado',
      () {
        final response = AuthResponse(
          user: _buildTestUser(identities: const <UserIdentity>[]),
          session: null,
        );
        expect(
          RegistrationGuardService.isObfuscatedDuplicateSignUpResponse(
            response,
          ),
          isTrue,
        );
      },
    );

    test('aceita AuthResponse legítimo quando identities contém identidade criada', () {
      final response = AuthResponse(
        user: _buildTestUser(identities: <UserIdentity>[_buildEmailIdentity()]),
        session: null,
      );
      expect(
        RegistrationGuardService.isObfuscatedDuplicateSignUpResponse(response),
        isFalse,
      );
    });

    test('não bloqueia mock mínimo com identities == null', () {
      final response = AuthResponse(
        user: _buildTestUser(identities: null),
        session: null,
      );
      expect(
        RegistrationGuardService.isObfuscatedDuplicateSignUpResponse(response),
        isFalse,
      );
    });
  });

  group('2. Classificação de exceções de conta duplicada vs rate-limit', () {
    test('identifica todas as variantes GoTrue de conta já cadastrada', () {
      final duplicateErrors = <Object>[
        const AuthException('User already registered'),
        const AuthApiException(
          'User already registered',
          statusCode: '422',
          code: 'user_already_exists',
        ),
        const AuthApiException(
          'A user with this email address has already been registered',
          statusCode: '422',
          code: 'email_exists',
        ),
        const AuthApiException(
          'Identity is already linked to a user',
          statusCode: '422',
          code: 'identity_already_exists',
        ),
        Exception('USER_ALREADY_REGISTERED'),
      ];

      for (final err in duplicateErrors) {
        expect(
          RegistrationGuardService.isDuplicateAccountException(err),
          isTrue,
          reason: 'Deve detectar duplicidade para: $err',
        );
        expect(
          RegistrationGuardService.isRateLimitException(err),
          isFalse,
          reason: 'Não deve confundir duplicidade com rate-limit: $err',
        );
      }
    });

    test('identifica variantes de rate-limit (GoTrue 429, Edge 429 e SQL guard)', () {
      final rateLimitErrors = <Object>[
        const AuthApiException(
          'Email rate limit exceeded',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
        const AuthApiException(
          'Request rate limit reached',
          statusCode: '429',
          code: 'over_request_rate_limit',
        ),
        const AuthException(
          'For security purposes, you can only request this after 45 seconds.',
          statusCode: '429',
        ),
        const FunctionException(
          status: 429,
          details: <String, dynamic>{'status': 'RATE_LIMITED'},
          reasonPhrase: 'Too Many Requests',
        ),
        const PostgrestException(
          message:
              'ERR_SIGNUP_GUARD_RATE_LIMITED: Limite temporário atingido.',
          code: 'P0001',
        ),
      ];

      for (final err in rateLimitErrors) {
        expect(
          RegistrationGuardService.isRateLimitException(err),
          isTrue,
          reason: 'Deve detectar rate-limit para: $err',
        );
        expect(
          RegistrationGuardService.isDuplicateAccountException(err),
          isFalse,
          reason: 'Não deve classificar rate-limit como conta duplicada: $err',
        );
      }
    });

    test('não classifica credenciais incorretas ou erro de rede como duplicidade', () {
      expect(
        RegistrationGuardService.isDuplicateAccountException(
          const AuthException('Invalid login credentials'),
        ),
        isFalse,
      );
      expect(
        RegistrationGuardService.isDuplicateAccountException(
          Exception('SocketException: Failed host lookup'),
        ),
        isFalse,
      );
    });
  });

  group('3. Tradução 100% em português humano e zero jargão técnico', () {
    test('traduz todos os cenários de AuthException/rede sem inglês nem ERR_', () {
      final samples = <Object>[
        const AuthException('User already registered'),
        const AuthApiException(
          'Email exists',
          statusCode: '422',
          code: 'email_exists',
        ),
        const AuthApiException(
          'Email rate limit exceeded',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
        const AuthApiException(
          'Email not confirmed',
          statusCode: '400',
          code: 'email_not_confirmed',
        ),
        const AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
        const AuthApiException(
          'Token has expired or is invalid',
          statusCode: '403',
          code: 'otp_expired',
        ),
        const AuthApiException(
          'New password should be different from the old password.',
          statusCode: '422',
          code: 'same_password',
        ),
        const AuthApiException(
          'Password should be at least 8 characters.',
          statusCode: '422',
          code: 'weak_password',
        ),
        const AuthApiException(
          'Unable to validate email address: invalid format',
          statusCode: '422',
          code: 'email_address_invalid',
        ),
        const PostgrestException(
          message:
              'ERR_DUPLICATE_CPF_IDENTITY: Este CPF já está vinculado a outra conta.',
          code: '23505',
        ),
        Exception('SocketException: Failed host lookup: supabase.co'),
        const AuthException('Unexpected internal upstream GoTrue failure 502'),
      ];

      final forbiddenEnglishLeaks = <String>[
        'User already registered',
        'Email rate limit',
        'Email not confirmed',
        'Invalid login credentials',
        'Token has expired',
        'different from the old password',
        'Unable to validate',
        'SocketException',
        'GoTrue',
      ];

      for (final err in samples) {
        final msg = RegistrationGuardService.translateAuthErrorPtBr(err);
        expect(msg, isNotEmpty);
        expect(
          KycHumanFeedbackTranslator.containsBannedTechnicalJargon(msg),
          isFalse,
          reason: 'Vazou jargão técnico em: $msg',
        );
        for (final english in forbiddenEnglishLeaks) {
          expect(
            msg.toLowerCase().contains(english.toLowerCase()),
            isFalse,
            reason: 'Vazou inglês "$english" na mensagem: $msg',
          );
        }
      }
    });

    test('KycHumanFeedbackTranslator cobre ERR_DUPLICATE_CPF_IDENTITY, ERR_SIGNUP_GUARD_RATE_LIMITED e EMAIL_EXISTS', () {
      final cpfMsg = KycHumanFeedbackTranslator.translateError(
        'ERR_DUPLICATE_CPF_IDENTITY: Este CPF já está vinculado a outra conta ativa.',
      );
      expect(cpfMsg, contains('CPF já possui cadastro'));
      expect(
        KycHumanFeedbackTranslator.containsBannedTechnicalJargon(cpfMsg),
        isFalse,
      );

      final rateMsg = KycHumanFeedbackTranslator.translateError(
        'ERR_SIGNUP_GUARD_RATE_LIMITED: Limite atingido.',
      );
      expect(rateMsg, contains('Aguarde alguns minutos'));
      expect(
        KycHumanFeedbackTranslator.containsBannedTechnicalJargon(rateMsg),
        isFalse,
      );

      for (final token in <String>[
        'USER_ALREADY_REGISTERED',
        'User already registered',
        'EMAIL_EXISTS',
      ]) {
        final emailMsg = KycHumanFeedbackTranslator.translateError(token);
        expect(emailMsg, contains('e-mail já possui uma conta ativa'));
        expect(
          KycHumanFeedbackTranslator.containsBannedTechnicalJargon(emailMsg),
          isFalse,
        );
      }
    });
  });

  group('4. Pré-checagem via Edge Function signup-eligibility-guard', () {
    test('degrada com segurança para unknownFallback quando Supabase.instance não foi inicializado', () async {
      const guard = RegistrationGuardService();
      final res = await guard.precheckEmail('cliente@desperrengue.com.br');
      expect(res, SignupEmailEligibility.unknownFallback);
    });

    test('e-mail vazio ou sem @ retorna available localmente sem requisição HTTP', () async {
      final fakeHttp = _FakeHttpClient(
        (_) async => http.Response('{"status":"AVAILABLE"}', 200),
      );
      final client = SupabaseClient(
        'http://localhost:54321',
        'anon-test-key',
        httpClient: fakeHttp,
      );
      final guard = RegistrationGuardService(client);

      expect(await guard.precheckEmail('   '), SignupEmailEligibility.available);
      expect(
        await guard.precheckEmail('invalido-sem-arroba'),
        SignupEmailEligibility.available,
      );
      expect(fakeHttp.capturedRequests, isEmpty);
    });

    test('mapeia AVAILABLE, ALREADY_REGISTERED_CONFIRMED, PENDING_EMAIL_VERIFICATION e HTTP 429 RATE_LIMITED', () async {
      late int nextStatus;
      late Map<String, dynamic> nextBody;

      final fakeHttp = _FakeHttpClient((req) async {
        return http.Response(
          jsonEncode(nextBody),
          nextStatus,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      });
      final client = SupabaseClient(
        'http://localhost:54321',
        'anon-test-key',
        httpClient: fakeHttp,
      );
      final guard = RegistrationGuardService(client);

      nextStatus = 200;
      nextBody = <String, dynamic>{'status': 'AVAILABLE'};
      expect(
        await guard.precheckEmail('  NOVO.CLIENTE@Exemplo.COM  '),
        SignupEmailEligibility.available,
      );

      final sentPayload =
          jsonDecode(fakeHttp.capturedRequests.single.body)
              as Map<String, dynamic>;
      expect(sentPayload['email'], 'novo.cliente@exemplo.com');
      expect((sentPayload['client_nonce'] as String).length, greaterThanOrEqualTo(16));

      nextStatus = 200;
      nextBody = <String, dynamic>{'status': 'ALREADY_REGISTERED_CONFIRMED'};
      expect(
        await guard.precheckEmail('ativo@exemplo.com'),
        SignupEmailEligibility.alreadyRegisteredConfirmed,
      );

      nextStatus = 200;
      nextBody = <String, dynamic>{'status': 'PENDING_EMAIL_VERIFICATION'};
      expect(
        await guard.precheckEmail('pendente@exemplo.com'),
        SignupEmailEligibility.pendingEmailVerification,
      );

      nextStatus = 429;
      nextBody = <String, dynamic>{'status': 'RATE_LIMITED'};
      expect(
        await guard.precheckEmail('abuso@exemplo.com'),
        SignupEmailEligibility.rateLimited,
      );
    });

    test('retorna unknownFallback em erro 503 ou falha de rede para não travar cadastro offline', () async {
      final failingHttp = _FakeHttpClient((_) async {
        throw Exception('Network unreachable');
      });
      final client = SupabaseClient(
        'http://localhost:54321',
        'anon-test-key',
        httpClient: failingHttp,
      );
      final guard = RegistrationGuardService(client);

      expect(
        await guard.precheckEmail('legitimo@exemplo.com'),
        SignupEmailEligibility.unknownFallback,
      );
    });
  });

  group('5. ProfileService.checkCpfRegistrationConflict (Passo 1 Anti-Sybil)', () {
    test('retorna false sem quebrar quando Supabase.instance não foi inicializado em testes de widget', () async {
      final conflict = await ProfileService().checkCpfRegistrationConflict(
        '119.787.236-10',
      );
      expect(conflict, isFalse);
    });

    test('envia apenas dígitos para RPC check_cpf_registration_conflict e respeita conflict true/false', () async {
      late int nextStatus;
      late Map<String, dynamic> nextBody;

      final fakeHttp = _FakeHttpClient((req) async {
        return http.Response(
          jsonEncode(nextBody),
          nextStatus,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      });
      final client = SupabaseClient(
        'http://localhost:54321',
        'anon-test-key',
        httpClient: fakeHttp,
      );
      final service = ProfileService(client);

      nextStatus = 200;
      nextBody = <String, dynamic>{'valid_cpf': true, 'conflict': true};
      expect(
        await service.checkCpfRegistrationConflict('119.787.236-10'),
        isTrue,
      );

      final req = fakeHttp.capturedRequests.single;
      expect(req.url.path, endsWith('/rpc/check_cpf_registration_conflict'));
      final rpcBody = jsonDecode(req.body) as Map<String, dynamic>;
      expect(rpcBody['p_cpf_raw'], '11978723610');

      nextStatus = 200;
      nextBody = <String, dynamic>{'valid_cpf': true, 'conflict': false};
      expect(
        await service.checkCpfRegistrationConflict('119.787.236-10'),
        isFalse,
      );
    });

    test('propaga (rethrow) ERR_SIGNUP_GUARD_RATE_LIMITED quando limite de tentativas é excedido', () async {
      final fakeHttp = _FakeHttpClient((_) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'code': 'P0001',
            'message':
                'ERR_SIGNUP_GUARD_RATE_LIMITED: Limite temporário de verificações de segurança atingido.',
            'details': null,
            'hint': null,
          }),
          400,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      });
      final client = SupabaseClient(
        'http://localhost:54321',
        'anon-test-key',
        httpClient: fakeHttp,
      );
      final service = ProfileService(client);

      await expectLater(
        () => service.checkCpfRegistrationConflict('119.787.236-10'),
        throwsA(
          predicate<Object>(
            (e) => e.toString().contains('ERR_SIGNUP_GUARD_RATE_LIMITED'),
          ),
        ),
      );
    });
  });
}

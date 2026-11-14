import 'package:desperrengue_app/core/analytics/founder_dashboard_models.dart';
import 'package:desperrengue_app/features/founder/data/founder_cockpit_repository.dart';
import 'package:desperrengue_app/features/founder/domain/ceo_smart_otp_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubVaultGateway implements CeoBackendGateway {
  _StubVaultGateway(this.nextResponse);

  final Map<String, dynamic> nextResponse;

  @override
  Stream<String?> get authEmailChanges => const Stream<String?>.empty();

  @override
  String? get currentUserEmail => 'wagneroliveira2395@gmail.com';

  @override
  String? get currentUserId => '86c017d2-a157-43be-96f1-8e88bdf1a475';

  @override
  Future<Map<String, dynamic>> callRpc(
    String functionName,
    Map<String, dynamic> params,
  ) async =>
      const <String, dynamic>{};

  @override
  Future<void> hydrateSovereignSession({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<Map<String, dynamic>> invokeVaultAuthority(
    Map<String, dynamic> body,
  ) async =>
      nextResponse;

  @override
  Future<void> reportIntrusionCanary({
    required String canaryCode,
    required Map<String, dynamic> meta,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void Function()> subscribeWarRoomLive({
    required void Function(CeoLiveEventItem event) onLiveEvent,
    required void Function(CeoRealtimeConnectionStatus status) onStatusChanged,
  }) async =>
      () {};
}

void main() {
  group('CeoSmartOtpExtractor & CeoSmartSixDigitOtpInputFormatter', () {
    test('extrai 686415 exatamente do layout quebrado no mobile (686 41\\n5 e &nbsp;)', () {
      expect(CeoSmartOtpExtractor.extractBestSixDigits('686415'), '686415');
      expect(CeoSmartOtpExtractor.extractBestSixDigits('686\u00A0415'), '686415');
      expect(CeoSmartOtpExtractor.extractBestSixDigits('686  41\n5'), '686415');
      expect(CeoSmartOtpExtractor.extractBestSixDigits('686-415'), '686415');
    });

    test('ignora digitos vizinhos do texto do e-mail ao colar bloco inteiro', () {
      const copiedEmailBody = '''
Olá, Wagner. Digite os 6 dígitos abaixo no aplicativo Desperrengue CEO:

686  41
5

Validade estrita de 5 minutos · Uso único
''';
      expect(
        CeoSmartOtpExtractor.extractBestSixDigits(copiedEmailBody),
        '686415',
      );

      const copiedSubject =
          '[Desperrengue CEO] Código 270462 · Primeiro Acesso (#80ED)';
      expect(
        CeoSmartOtpExtractor.extractBestSixDigits(copiedSubject),
        '270462',
      );
    });

    test('formatter aceita colagem com &nbsp; e quebra de linha sem truncar o 6º digito', () {
      const formatter = CeoSmartSixDigitOtpInputFormatter();

      final resNbsp = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '686\u00A0415'),
      );
      expect(resNbsp.text, '686415');

      final resWrapped = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '  686 41\n5  '),
      );
      expect(resWrapped.text, '686415');

      // Mesmo se ja havia 2 digitos parciais no campo, colar os 6 digitos substitui pelo codigo completo!
      final resOverPartial = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '12',
          selection: TextSelection.collapsed(offset: 2),
        ),
        const TextEditingValue(
          text: '12686 41\n5',
          selection: TextSelection.collapsed(offset: 10),
        ),
      );
      expect(resOverPartial.text, '686415');
    });

    test('formatter preserva digitacao manual progressiva e bloqueia 7º digito avulso', () {
      const formatter = CeoSmartSixDigitOtpInputFormatter();
      var state = TextEditingValue.empty;

      for (final ch in <String>['6', '8', '6', '4', '1', '5']) {
        final nextText = '${state.text}$ch';
        state = formatter.formatEditUpdate(
          state,
          TextEditingValue(
            text: nextText,
            selection: TextSelection.collapsed(offset: nextText.length),
          ),
        );
      }
      expect(state.text, '686415');

      final seventh = formatter.formatEditUpdate(
        state,
        const TextEditingValue(
          text: '6864159',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(seventh.text, '686415');
    });
  });

  group('Persistencia de Ticket Pendente & Diagnostico de Codigo Substituido', () {
    test('persiste e restaura CeoOtpChallengeTicket valido ao alternar para o Gmail', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repo = FounderCockpitRepository(
        gateway: _StubVaultGateway(const <String, dynamic>{'ok': true}),
      );

      final ticket = CeoOtpChallengeTicket(
        challengeId: '80ed1da7-b51e-4d23-9e85-1c2be751c55d',
        maskedDestination: 'wagneroliveira2395@gmail.com',
        expiresAtUtc: DateTime.now().toUtc().add(const Duration(minutes: 9)),
        nextCooldownSeconds: 30,
        purpose: 'INITIAL_PASSWORD_SETUP',
      );
      expect(ticket.challengeRef, '80ED');

      await repo.savePendingOtpTicket(ticket);
      final restored = await repo.loadValidPendingOtpTicket(
        expectedPurpose: 'INITIAL_PASSWORD_SETUP',
      );
      expect(restored, isNotNull);
      expect(restored!.challengeId, ticket.challengeId);
      expect(restored.challengeRef, '80ED');

      await repo.clearPendingOtpTicket();
      final afterClear = await repo.loadValidPendingOtpTicket(
        expectedPurpose: 'INITIAL_PASSWORD_SETUP',
      );
      expect(afterClear, isNull);
      repo.dispose();
    });

    test('traduz ERR_OTP_SUPERSEDED_BY_NEWER_EMAIL informando o Protocolo mais recente', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repo = FounderCockpitRepository(
        gateway: _StubVaultGateway(const <String, dynamic>{
          'ok': false,
          'error_code': 'ERR_OTP_SUPERSEDED_BY_NEWER_EMAIL',
          'latest_challenge_ref': '80ED',
        }),
      );

      await expectLater(
        () => repo.verifyInitialBootstrapOtp(
          challengeId: 'a3ebe2d0-6f11-4bcf-bab1-7604a53e4aaa',
          sixDigitCode: '686 41\n5',
        ),
        throwsA(
          isA<CeoVaultSecurityException>()
              .having(
                (e) => e.errorCode,
                'errorCode',
                'ERR_OTP_SUPERSEDED_BY_NEWER_EMAIL',
              )
              .having((e) => e.latestChallengeRef, 'latestChallengeRef', '80ED')
              .having(
                (e) => e.userMessagePt,
                'userMessagePt',
                contains('Protocolo #80ED'),
              ),
        ),
      );
      repo.dispose();
    });
  });
}

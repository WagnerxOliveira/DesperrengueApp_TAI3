import 'package:desperrengue_app/core/security/zero_trust_bilateral_security_engine.dart';
import 'package:desperrengue_app/core/utils/app_failure.dart';
import 'package:desperrengue_app/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money (centavos inteiros)', () {
    test('toCents tolera ruído binário e arredonda meio centavo para cima', () {
      expect(Money.toCents(0.1 + 0.2), 30); // 0.30000000000000004
      expect(Money.toCents(1.005), 101);
      expect(Money.toCents(19.99), 1999);
      expect(Money.toCents(-1.005), -101);
      expect(Money.toCents(double.nan), 0);
      expect(Money.toCents(double.infinity), 0);
    });

    test('percentOfCents é exato em inteiros', () {
      expect(Money.percentOfCents(10000, 1350), 1350); // 13,5% de 100,00
      expect(Money.percentOfCents(10001, 1350), 1350); // 1350,135 → 1350
      expect(Money.percentOfCents(1, 5000), 1); // 0,5 centavo sobe
      expect(Money.percentOfCents(0, 1500), 0);
    });

    test('allocate nunca perde nem cria centavo', () {
      for (final total in [0, 1, 2, 99, 100, 1000, 33333, 100001]) {
        for (final w in [
          [1, 1, 1],
          [70, 30],
          [1, 2, 3, 4],
          [0, 0],
          [5],
        ]) {
          final parts = Money.allocate(total, w);
          expect(parts.fold<int>(0, (a, b) => a + b), total, reason: '$total / $w');
          expect(parts.every((p) => p >= 0), isTrue);
        }
      }
      expect(Money.allocate(100, [1, 1, 1]), [34, 33, 33]);
    });

    test('formatBrl', () {
      expect(Money.formatBrl(0), 'R\$ 0,00');
      expect(Money.formatBrl(5), 'R\$ 0,05');
      expect(Money.formatBrl(123456), 'R\$ 1.234,56');
      expect(Money.formatBrl(-100000), '-R\$ 1.000,00');
    });
  });

  group('Smart Split / SOS em centavos', () {
    test('clawback Fase 2 = 13,5% + 1,5% = 15% exato para qualquer valor', () {
      for (final cents in [1, 7, 333, 9999, 15000, 123457]) {
        final amount = cents / 100.0;
        final r = FiscalDocumentForensicsEngine.auditPhase2SefazRecheck(
          declaredMaterialAmount: amount,
          sefazStatusRecheck: 101,
        );
        final op = Money.toCents(r.platformOperationalFeeRecovered);
        final res = Money.toCents(r.warrantyReserveFeeRecovered);
        final total = Money.toCents(r.totalClawbackDebitedFromProvider);
        expect(op + res, total, reason: 'soma dos centavos $cents');
        expect(op, Money.percentOfCents(cents, 1350));
        expect(res, Money.percentOfCents(cents, 150));
      }
    });

    test('SOS: taxa + estorno == escrow sempre (sem centavo fantasma)', () {
      for (final cents in [100, 999, 5001, 16667, 33333, 100000, 123457]) {
        final escrow = cents / 100.0;
        final v = SosSlotProtectionAndSlashingEngine.evaluateCancellationSlashing(
          lockedEscrowTotalBrl: escrow,
          hasProviderAccepted: true,
          providerDisplacedMeters: 400,
          activeRouteMinutes: 6,
        );
        final fee = Money.toCents(v.compensatoryFeeToProviderBrl);
        final refund = Money.toCents(v.netRefundToClientBrl);
        expect(fee + refund, cents, reason: 'escrow=$escrow');
        expect(fee, inInclusiveRange(2500, 4500).or(equals(cents)));
      }
    });
  });

  group('AppFailure / humanizeError', () {
    test('nunca vaza SQL, stack, constraint ou PII', () {
      final samples = <Object>[
        'PostgrestException(message: duplicate key value violates unique constraint "profiles_cpf_key", code: 23505, details: Key (cpf)=(12345678909) already exists., hint: null)',
        'PostgrestException(message: relation "public.secret_table" does not exist, code: 42P01, details: , hint: )',
        'Exception: INSERT INTO jobs (client_id) VALUES (...) failed',
        'AuthApiException(message: Invalid login credentials, statusCode: 400, code: invalid_credentials)',
        '_TypeError: type \'Null\' is not a subtype of type \'String\'\n#0 main (package:desperrengue_app/main.dart:1:1)',
        'ClientException: Failed host lookup: \'abc.supabase.co\' (OS Error: ...) uri=https://abc.supabase.co/rest/v1/jobs',
        'Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.abc123abc123',
        'Exception: Contato fulano@example.com 11 98765-4321 CPF 123.456.789-09',
      ];
      for (final s in samples) {
        final m = humanizeError(s);
        expect(m, isNot(contains('constraint')), reason: s.toString());
        expect(m.toLowerCase(), isNot(contains('relation')), reason: s.toString());
        expect(m, isNot(contains('INSERT')), reason: s.toString());
        expect(m, isNot(contains('#0')), reason: s.toString());
        expect(m, isNot(contains('package:')), reason: s.toString());
        expect(m, isNot(contains('supabase.co')), reason: s.toString());
        expect(m, isNot(contains('eyJ')), reason: s.toString());
        expect(m, isNot(contains('@')), reason: s.toString());
        expect(m, isNot(contains('12345678909')), reason: s.toString());
        expect(m, isNot(contains('98765')), reason: s.toString());
        expect(m, isNotEmpty);
      }
    });

    test('classifica rede, timeout, auth e conflito', () {
      expect(AppFailure.from('SocketException: Failed host lookup').kind, AppFailureKind.network);
      expect(AppFailure.from('TimeoutException after 0:00:10').kind, AppFailureKind.timeout);
      expect(AppFailure.from('AuthApiException(message: Invalid login credentials)').message,
          'E-mail ou senha incorretos.');
      expect(AppFailure.from('PostgrestException(message: x, code: 23505)').kind, AppFailureKind.conflict);
      expect(AppFailure.from('PostgrestException(message: x, code: 42501)').kind, AppFailureKind.forbidden);
      expect(AppFailure.from('Sessão expirada.').kind, AppFailureKind.unauthenticated);
      expect(AppFailure.from('SocketException').isRetryable, isTrue);
      expect(AppFailure.from('PostgrestException(message: x, code: 23505)').isRetryable, isFalse);
    });

    test('mantém códigos de negócio com texto humano (compatível com friendlyError)', () {
      expect(humanizeError('PostgrestException(message: QUOTE_LIMIT_REACHED, code: P0001)'),
          'Esta demanda já recebeu 3 orçamentos.');
      expect(humanizeError('PostgrestException(message: PIN_INVALID:2, code: P0001)'),
          'PIN incorreto. Restam 2 tentativa(s).');
      expect(humanizeError('PostgrestException(message: PIN_INVALID, code: P0001)'), 'PIN incorreto.');
      expect(humanizeError('PostgrestException(message: PIN_LOCKED, code: P0001)'),
          'Muitas tentativas. Use "Tive um problema".');
    });

    test('mensagem pt-BR curta levantada por RAISE EXCEPTION do banco passa', () {
      expect(
        humanizeError('PostgrestException(message: Saldo insuficiente para saque., code: P0001, details: , hint: )'),
        'Saldo insuficiente para saque.',
      );
      expect(humanizeError(Exception('Informe o CEP')), 'Informe o CEP');
    });

    test('Result.guard converte exceção em Err humano', () async {
      final r = await Result.guard<int>(() async => throw 'SocketException: boom');
      expect(r.isFailure, isTrue);
      expect(r.failureOrNull!.kind, AppFailureKind.network);
      final ok = await Result.guard<int>(() async => 7);
      expect(ok.valueOrNull, 7);
      expect(ok.map((v) => v + 1).valueOrNull, 8);
      expect(ok.when(ok: (v) => 'ok$v', fail: (f) => f.message), 'ok7');
    });

    test('redactForLog mascara PII e segredos', () {
      final s = redactForLog(
        'user a@b.com cpf 123.456.789-09 tel (11) 98765-4321 pos -21.785412, -46.561789 Bearer abc.def.ghi',
      );
      expect(s, isNot(contains('a@b.com')));
      expect(s, isNot(contains('123.456.789-09')));
      expect(s, isNot(contains('98765')));
      expect(s, isNot(contains('21.785412')));
      expect(s, isNot(contains('abc.def.ghi')));
    });
  });
}

extension on Matcher {
  Matcher or(Matcher other) => anyOf(this, other);
}

import 'package:desperrengue_app/core/utils/address_privacy.dart';
import 'package:desperrengue_app/core/utils/off_thread.dart';
import 'package:flutter_test/flutter_test.dart';

int _square(int x) => x * x;

void main() {
  group('AddressPrivacy.coarseArea (LGPD, 2ª camada)', () {
    test('remove rua, número, apto e CEP; mantém bairro/cidade/UF', () {
      expect(
        AddressPrivacy.coarseArea('Rua das Flores, 123 - Apto 402 - Centro - Poços de Caldas - MG'),
        'Centro - Poços de Caldas - MG',
      );
      expect(AddressPrivacy.coarseArea('Av. Brasil, 1450 — Centro'), 'Centro');
      expect(
        AddressPrivacy.coarseArea('Alameda dos Anjos 55, Jardim Europa, São Paulo, SP, 01310-100'),
        'Jardim Europa - São Paulo - SP',
      );
    });

    test('não vaza nenhum token sensível', () {
      final out = AddressPrivacy.coarseArea(
        'Travessa Sol 9 / Bloco B / perto da padaria / Vila Nova / Campinas / sp',
      );
      expect(out, 'Vila Nova - Campinas - SP');
      for (final bad in ['Travessa', '9', 'Bloco', 'padaria']) {
        expect(out, isNot(contains(bad)));
      }
    });

    test('formato já seguro é preservado como veio', () {
      expect(AddressPrivacy.coarseArea('Country Club • Poços de Caldas - MG'), 'Country Club • Poços de Caldas - MG');
      expect(AddressPrivacy.coarseArea('Centro'), 'Centro');
    });

    test('vazio, nulo ou só dado sensível cai no fallback', () {
      expect(AddressPrivacy.coarseArea(null), 'Local protegido');
      expect(AddressPrivacy.coarseArea('   '), 'Local protegido');
      expect(AddressPrivacy.coarseArea('Rua A, 10', fallback: 'Local Verificado'), 'Local Verificado');
    });
  });

  group('AddressPrivacy.maskForThirdParty (texto enviado a corretor externo)', () {
    test('mascara e-mail, números e "Rua ..." preservando o comprimento', () {
      const t =
          'Moro na Rua das Flores 123, apto 45. Fale com ana@mail.com ou 11 98765-4321, CPF 123.456.789-09 e CEP 37701-000.';
      final m = AddressPrivacy.maskForThirdParty(t);
      expect(m.length, t.length);
      for (final bad in ['Flores', '123', 'ana@mail.com', '98765', '123.456.789-09', '37701']) {
        expect(m, isNot(contains(bad)), reason: bad);
      }
      expect(m, contains('Moro na'));
      expect(m, contains('Fale com'));
    });

    test('texto sem PII passa intacto', () {
      const t = 'O chuveiro eletrico nao esquenta e disjuntor desarma';
      expect(AddressPrivacy.maskForThirdParty(t), t);
    });
  });

  group('runOffMainThread', () {
    test('executa a tarefa e devolve o resultado (isolate ou inline)', () async {
      expect(await runOffMainThread(() => _square(12)), 144);
      expect(await runOffMainThread(() async => 'ok'), 'ok');
    });

    test('propaga exceções da tarefa', () async {
      await expectLater(
        runOffMainThread<int>(() => throw StateError('falhou')),
        throwsA(anything),
      );
    });
  });
}

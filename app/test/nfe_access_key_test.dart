import 'package:desperrengue_app/core/utils/nfe_access_key.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta uma chave de 44 dígitos válida (calcula o DV módulo 11).
String buildKey({
  String uf = '31',
  String aamm = '2611',
  String cnpj = '11222333000181',
  String model = '65',
  String serie = '001',
  String nnf = '000001234',
  String tpEmis = '1',
  String cnf = '12345678',
}) {
  final body = '$uf$aamm$cnpj$model$serie$nnf$tpEmis$cnf';
  assert(body.length == 43);
  return '$body${NfeAccessKey.checkDigit(body)}';
}

void main() {
  final good = buildKey();

  group('NfeAccessKey.validate', () {
    test('1 NFC-e válida: extrai UF, CNPJ, modelo, série e número', () {
      final r = NfeAccessKey.validate(good);
      expect(r.valid, isTrue);
      final i = r.info!;
      expect(i.uf, 'MG');
      expect(i.ufCode, 31);
      expect(i.year, 2026);
      expect(i.month, 11);
      expect(i.emitterCnpj, '11222333000181');
      expect(i.formattedCnpj, '11.222.333/0001-81');
      expect(i.isNfce, isTrue);
      expect(i.documentMode, 'NFCE_65');
      expect(i.series, 1);
      expect(i.number, 1234);
      expect(i.label, 'NFC-e nº 1234 • série 1');
    });

    test('2 NF-e (modelo 55) válida', () {
      final r = NfeAccessKey.validate(buildKey(model: '55', uf: '35'));
      expect(r.valid, isTrue);
      expect(r.info!.documentMode, 'NFE_55');
      expect(r.info!.uf, 'SP');
      expect(r.info!.label, startsWith('NF-e'));
    });

    test('3 com máscara (espaços, pontos e traços) continua válida', () {
      expect(NfeAccessKey.validate(NfeAccessKey.mask(good)).valid, isTrue);
      expect(NfeAccessKey.validate('${good.substring(0, 22)}-${good.substring(22)}').valid, isTrue);
    });

    test('4 vazia', () {
      expect(NfeAccessKey.validate('  ').error, NfeKeyError.empty);
    });

    test('5 curta e 6 longa demais', () {
      expect(NfeAccessKey.validate(good.substring(0, 43)).error, NfeKeyError.length);
      expect(NfeAccessKey.validate('${good}1').valid, isFalse);
    });

    test('7 dígito verificador errado', () {
      final wrongDv = ((int.parse(good[43]) + 1) % 10).toString();
      final r = NfeAccessKey.validate('${good.substring(0, 43)}$wrongDv');
      expect(r.error, NfeKeyError.checkDigit);
      expect(r.message, contains('último número'));
    });

    test('8 UF inexistente', () {
      final r = NfeAccessKey.validate(buildKey(uf: '99'));
      expect(r.error, NfeKeyError.invalidUf);
    });

    test('9 mês de emissão inválido (13)', () {
      expect(NfeAccessKey.validate(buildKey(aamm: '2613')).error, NfeKeyError.invalidDate);
    });

    test('10 CNPJ do emitente com dígito errado', () {
      expect(NfeAccessKey.validate(buildKey(cnpj: '11222333000182')).error, NfeKeyError.invalidCnpj);
      expect(NfeAccessKey.validate(buildKey(cnpj: '11111111111111')).error, NfeKeyError.invalidCnpj);
    });

    test('11 modelo não suportado (57)', () {
      expect(NfeAccessKey.validate(buildKey(model: '57')).error, NfeKeyError.unsupportedModel);
    });

    test('12 tipo de emissão inválido (3)', () {
      expect(NfeAccessKey.validate(buildKey(tpEmis: '3')).error, NfeKeyError.invalidEmission);
    });

    test('13 contingência (tpEmis 9) é aceita, como no servidor', () {
      expect(NfeAccessKey.validate(buildKey(tpEmis: '9')).valid, isTrue);
    });

    test('14 toda mensagem de erro é pt-BR humana (sem jargão técnico)', () {
      for (final e in NfeKeyError.values) {
        final msg = NfeKeyResult.error(e).message!;
        expect(msg, isNotEmpty);
        expect(msg.toLowerCase(), isNot(contains('mod11')));
        expect(msg, isNot(contains('_')));
      }
    });
  });

  group('NfeAccessKey.extract / mask / cnpj', () {
    test('URL do QR Code da NFC-e (p=chave|2|1|1|hash)', () {
      final e = NfeAccessKey.extract('https://www.sefaz.mg.gov.br/nfce/consulta?p=$good|2|1|1|ABCDEF');
      expect(e.digits, good);
      expect(e.fromQrUrl, isTrue);
    });

    test('parâmetro chNFe', () {
      final e = NfeAccessKey.extract('https://portal.example/nfe?chNFe=$good&x=1');
      expect(e.digits, good);
      expect(e.fromQrUrl, isTrue);
    });

    test('chave digitada não é QR', () {
      expect(NfeAccessKey.extract(NfeAccessKey.mask(good)).fromQrUrl, isFalse);
    });

    test('máscara agrupa de 4 em 4 e corta em 44', () {
      final m = NfeAccessKey.mask('${good}999');
      expect(m.replaceAll(' ', ''), good);
      expect(m.split(' ').length, 11);
      expect(m.split(' ').every((g) => g.length == 4), isTrue);
    });

    test('CNPJ: válidos e inválidos conhecidos', () {
      expect(NfeAccessKey.isValidCnpj('11.222.333/0001-81'), isTrue);
      expect(NfeAccessKey.isValidCnpj('00000000000191'), isTrue);
      expect(NfeAccessKey.isValidCnpj('12345678000195'), isTrue);
      expect(NfeAccessKey.isValidCnpj('12345678000196'), isFalse);
      expect(NfeAccessKey.isValidCnpj('123'), isFalse);
    });
  });
}

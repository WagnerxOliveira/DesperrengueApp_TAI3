/// Validação LOCAL (pura, sem rede) da chave de acesso de NF-e/NFC-e (44 dígitos).
///
/// Layout: cUF(2) AAMM(4) CNPJ(14) modelo(2) série(3) nNF(9) tpEmis(1) cNF(8) cDV(1).
/// É a mesma regra do servidor (`validate_nfe_access_key_mod11`): serve para dar retorno
/// imediato ao profissional. Isto NÃO prova que a nota existe na SEFAZ — só a estrutura.
library;

/// Siglas por código IBGE de UF.
const Map<int, String> kNfeUfByIbge = {
  11: 'RO', 12: 'AC', 13: 'AM', 14: 'RR', 15: 'PA', 16: 'AP', 17: 'TO',
  21: 'MA', 22: 'PI', 23: 'CE', 24: 'RN', 25: 'PB', 26: 'PE', 27: 'AL', 28: 'SE', 29: 'BA',
  31: 'MG', 32: 'ES', 33: 'RJ', 35: 'SP',
  41: 'PR', 42: 'SC', 43: 'RS',
  50: 'MS', 51: 'MT', 52: 'GO', 53: 'DF',
};

enum NfeKeyError { empty, length, invalidUf, invalidDate, invalidCnpj, unsupportedModel, invalidEmission, checkDigit }

class NfeKeyInfo {
  const NfeKeyInfo({
    required this.key,
    required this.ufCode,
    required this.uf,
    required this.year,
    required this.month,
    required this.emitterCnpj,
    required this.model,
    required this.series,
    required this.number,
    required this.emissionType,
  });

  final String key;
  final int ufCode;
  final String uf;
  final int year;
  final int month;
  final String emitterCnpj;

  /// 55 (NF-e) ou 65 (NFC-e).
  final int model;
  final int series;
  final int number;
  final int emissionType;

  bool get isNfce => model == 65;

  /// `NFCE_65` / `NFE_55` (valores aceitos pelo servidor).
  String get documentMode => isNfce ? 'NFCE_65' : 'NFE_55';

  /// `12.345.678/0001-95`.
  String get formattedCnpj =>
      '${emitterCnpj.substring(0, 2)}.${emitterCnpj.substring(2, 5)}.${emitterCnpj.substring(5, 8)}/${emitterCnpj.substring(8, 12)}-${emitterCnpj.substring(12)}';

  /// `NFC-e nº 123 • série 1`.
  String get label => '${isNfce ? 'NFC-e' : 'NF-e'} nº $number • série $series';
}

class NfeKeyResult {
  const NfeKeyResult.ok(NfeKeyInfo this.info) : error = null;
  const NfeKeyResult.error(NfeKeyError this.error) : info = null;

  final NfeKeyInfo? info;
  final NfeKeyError? error;

  bool get valid => info != null;

  /// Mensagem humana (pt-BR) para o campo.
  String? get message => switch (error) {
        null => null,
        NfeKeyError.empty => 'Informe a chave de acesso da nota.',
        NfeKeyError.length => 'A chave de acesso tem 44 números. Confira se faltou ou sobrou algum.',
        NfeKeyError.invalidUf => 'Esta chave tem um estado (UF) que não existe. Confira os 2 primeiros números.',
        NfeKeyError.invalidDate => 'A data de emissão desta chave não é válida. Confira os números 3 a 6.',
        NfeKeyError.invalidCnpj => 'O CNPJ de quem emitiu a nota não confere. Confira os números 7 a 20.',
        NfeKeyError.unsupportedModel => 'Só aceitamos nota fiscal (modelo 55) ou cupom fiscal eletrônico (modelo 65).',
        NfeKeyError.invalidEmission => 'O tipo de emissão desta chave não é válido.',
        NfeKeyError.checkDigit => 'O último número da chave não confere. Alguma digitação está errada.',
      };
}

/// Chave extraída de um texto colado/lido do QR Code, com a origem.
class NfeKeyExtraction {
  const NfeKeyExtraction(this.digits, {required this.fromQrUrl});
  final String digits;
  final bool fromQrUrl;
}

class NfeAccessKey {
  const NfeAccessKey._();

  static String digitsOnly(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

  /// Aceita: chave pura, com espaços/pontos/traços, ou a URL do QR Code da NFC-e
  /// (`...?p=<44 dígitos>|2|1|1|<hash>` ou `...chNFe=<44 dígitos>`).
  static NfeKeyExtraction extract(String raw) {
    final text = raw.trim();
    final uri = Uri.tryParse(text);
    if (uri != null && uri.hasQuery) {
      for (final name in const ['p', 'chNFe', 'chave', 'chnfe']) {
        final v = uri.queryParameters[name];
        if (v == null) continue;
        final first = digitsOnly(v.split('|').first);
        if (first.length == 44) return NfeKeyExtraction(first, fromQrUrl: true);
      }
    }
    final all = digitsOnly(text);
    if (all.length == 44) return NfeKeyExtraction(all, fromQrUrl: false);
    final run = RegExp(r'(?<!\d)\d{44}(?!\d)').firstMatch(text);
    if (run != null) return NfeKeyExtraction(run.group(0)!, fromQrUrl: text.contains('://'));
    return NfeKeyExtraction(all, fromQrUrl: false);
  }

  /// `1234 5678 ...` (grupos de 4) — só para exibição/digitação.
  static String mask(String raw) {
    final d = digitsOnly(raw);
    final cut = d.length > 44 ? d.substring(0, 44) : d;
    final b = StringBuffer();
    for (var i = 0; i < cut.length; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(cut[i]);
    }
    return b.toString();
  }

  static NfeKeyResult validate(String raw) {
    final key = extract(raw).digits;
    if (key.isEmpty) return const NfeKeyResult.error(NfeKeyError.empty);
    if (key.length != 44) return const NfeKeyResult.error(NfeKeyError.length);

    final uf = int.parse(key.substring(0, 2));
    final ufSigla = kNfeUfByIbge[uf];
    if (ufSigla == null) return const NfeKeyResult.error(NfeKeyError.invalidUf);

    final yy = int.parse(key.substring(2, 4));
    final mm = int.parse(key.substring(4, 6));
    if (mm < 1 || mm > 12) return const NfeKeyResult.error(NfeKeyError.invalidDate);

    final cnpj = key.substring(6, 20);
    if (!isValidCnpj(cnpj)) return const NfeKeyResult.error(NfeKeyError.invalidCnpj);

    final model = int.parse(key.substring(20, 22));
    if (model != 55 && model != 65) return const NfeKeyResult.error(NfeKeyError.unsupportedModel);

    final tpEmis = int.parse(key.substring(34, 35));
    if (tpEmis != 1 && tpEmis != 9) return const NfeKeyResult.error(NfeKeyError.invalidEmission);

    if (int.parse(key.substring(43)) != checkDigit(key.substring(0, 43))) {
      return const NfeKeyResult.error(NfeKeyError.checkDigit);
    }

    return NfeKeyResult.ok(NfeKeyInfo(
      key: key,
      ufCode: uf,
      uf: ufSigla,
      year: 2000 + yy,
      month: mm,
      emitterCnpj: cnpj,
      model: model,
      series: int.parse(key.substring(22, 25)),
      number: int.parse(key.substring(25, 34)),
      emissionType: tpEmis,
    ));
  }

  /// Dígito verificador módulo 11 (pesos 2..9 da direita p/ esquerda) dos 43 primeiros dígitos.
  static int checkDigit(String first43) {
    var sum = 0;
    var weight = 2;
    for (var i = first43.length - 1; i >= 0; i--) {
      sum += int.parse(first43[i]) * weight;
      weight = weight == 9 ? 2 : weight + 1;
    }
    final rem = sum % 11;
    return rem < 2 ? 0 : 11 - rem;
  }

  /// CNPJ de 14 dígitos com os dois dígitos verificadores (módulo 11).
  static bool isValidCnpj(String raw) {
    final c = digitsOnly(raw);
    if (c.length != 14 || RegExp(r'^(\d)\1{13}$').hasMatch(c)) return false;
    int dv(String base) {
      const w12 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
      const w13 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
      final w = base.length == 12 ? w12 : w13;
      var s = 0;
      for (var i = 0; i < base.length; i++) {
        s += int.parse(base[i]) * w[i];
      }
      final r = s % 11;
      return r < 2 ? 0 : 11 - r;
    }

    final d1 = dv(c.substring(0, 12));
    final d2 = dv(c.substring(0, 12) + d1.toString());
    return c.substring(12) == '$d1$d2';
  }
}

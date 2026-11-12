/// Dinheiro em centavos inteiros (BRL).
///
/// `double` não representa 0,1 + 0,2 exatamente: somas/percentuais em `double`
/// geram centavos fantasmas e divergência entre cliente, PDF e banco. Todo
/// cálculo financeiro novo deve acontecer em [int] centavos e só virar `double`
/// (via [Money.fromCents]) na borda de exibição/serialização legada.
///
/// Arredondamento: meio centavo sobe (half-up, afastando de zero), igual ao
/// `numeric round()` do Postgres.
library;

class Money {
  const Money._();

  /// `num` em reais → centavos. Tolera ruído binário (1.005 → 101).
  /// NaN/∞ viram 0 (nunca propagam lixo para o razão).
  static int toCents(num brl) {
    final v = brl.toDouble();
    if (v.isNaN || v.isInfinite) return 0;
    final scaled = v * 100;
    // 1e-9 relativo cobre 1.005*100 = 100.49999999999999.
    final eps = scaled.abs() * 1e-12 + 1e-9;
    return (scaled >= 0 ? scaled + eps : scaled - eps).round();
  }

  /// Centavos → reais (somente para exibição/legado).
  static double fromCents(int cents) => cents / 100.0;

  /// [basisPoints] (1 bp = 0,01%) de [cents], meio centavo para cima.
  /// Ex.: 13,5% = 1350 bp.
  static int percentOfCents(int cents, int basisPoints) {
    final product = cents * basisPoints;
    final neg = product < 0;
    final abs = neg ? -product : product;
    final r = (abs + 5000) ~/ 10000;
    return neg ? -r : r;
  }

  /// Alíquota fracionária [rate] (ex.: 0,135) de [cents], meio centavo para cima.
  ///
  /// A alíquota vira partes-por-milhão inteiras (`round(rate * 1e6)`), então
  /// 0,135 → 135000 ppm é exata e todo o cálculo seguinte é em inteiros.
  static int rateOfCents(int cents, double rate) {
    if (rate.isNaN || rate.isInfinite || rate <= 0) return 0;
    final ppm = (rate * 1000000).round();
    final product = cents * ppm;
    final neg = product < 0;
    final abs = neg ? -product : product;
    final r = (abs + 500000) ~/ 1000000;
    return neg ? -r : r;
  }

  /// Divide [totalCents] proporcionalmente a [weights] sem perder centavo
  /// (método do maior resto). A soma do resultado é SEMPRE [totalCents].
  static List<int> allocate(int totalCents, List<int> weights) {
    if (weights.isEmpty) return const <int>[];
    final sumW = weights.fold<int>(0, (a, b) => a + (b < 0 ? 0 : b));
    if (sumW <= 0) {
      final base = totalCents ~/ weights.length;
      var rest = totalCents - base * weights.length;
      return List<int>.generate(weights.length, (i) => base + (rest-- > 0 ? 1 : 0));
    }
    final out = List<int>.filled(weights.length, 0);
    final rema = List<int>.filled(weights.length, 0);
    var given = 0;
    for (var i = 0; i < weights.length; i++) {
      final w = weights[i] < 0 ? 0 : weights[i];
      out[i] = (totalCents * w) ~/ sumW;
      rema[i] = (totalCents * w) % sumW;
      given += out[i];
    }
    var left = totalCents - given;
    final order = List<int>.generate(weights.length, (i) => i)
      ..sort((a, b) => rema[b] != rema[a] ? rema[b].compareTo(rema[a]) : a.compareTo(b));
    for (var k = 0; left > 0; k = (k + 1) % order.length, left--) {
      out[order[k]]++;
    }
    return out;
  }

  /// `R$ 1.234,56` (sem depender de `intl`, funciona em isolates/testes).
  static String formatBrl(int cents) {
    final neg = cents < 0;
    final abs = neg ? -cents : cents;
    final reais = (abs ~/ 100).toString();
    final cc = (abs % 100).toString().padLeft(2, '0');
    final buf = StringBuffer();
    for (var i = 0; i < reais.length; i++) {
      if (i > 0 && (reais.length - i) % 3 == 0) buf.write('.');
      buf.write(reais[i]);
    }
    return '${neg ? '-' : ''}R\$ $buf,$cc';
  }
}

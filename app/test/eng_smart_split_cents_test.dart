import 'dart:math' as math;

import 'package:desperrengue_app/core/models/fintech_warranty_models.dart';
import 'package:desperrengue_app/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

int _c(double v) => Money.toCents(v);

void main() {
  group('SmartSplitBreakdown em centavos (propriedades)', () {
    test('valores de referência (R\$ 180,00 de mão de obra + R\$ 65,00 de peças)', () {
      final s = SmartSplitBreakdown.validated(serviceLaborAmount: 180, materialReimbursementAmount: 65);
      expect(s.grossTransactionAmount, 245.00);
      expect(s.platformOperationalRevenue, 24.30);
      expect(s.warrantyReserveContribution, 2.70);
      expect(s.totalPlatformFee, 27.00);
      expect(s.providerNetLaborPayout, 153.00);
      expect(s.providerTotalNetPayout, 218.00);
      expect(s.providerSavedFeeBySmartSplit, 9.75);
      expect(s.effectiveFeePercentageOnGross, 11.02);
      expect(s.maxWarrantyCoverageCap, 180.00);
    });

    test('INVARIANTE: taxa + repasse == mão de obra e repasse total + taxa == bruto (milhares de casos, centavos ímpares)', () {
      final rnd = math.Random(2026);
      final samples = <(int, int)>[
        for (var i = 1; i <= 400; i++) (i, 0), // 0,01 … 4,00
        for (var i = 0; i < 4000; i++) (rnd.nextInt(2000000) + 1, rnd.nextInt(500000)),
        (1, 1), (3, 7), (33, 33), (99999999, 1), (100, 15), (101, 55), (999, 999),
      ];
      for (final (labor, mat) in samples) {
        final s = SmartSplitBreakdown(
          serviceLaborAmount: labor / 100.0,
          materialReimbursementAmount: mat / 100.0,
        );
        final fee = _c(s.totalPlatformFee);
        final op = _c(s.platformOperationalRevenue);
        final reserve = _c(s.warrantyReserveContribution);
        final net = _c(s.providerNetLaborPayout);
        expect(op + reserve, fee, reason: 'op+reserva==taxa ($labor)');
        expect(fee + net, labor, reason: 'taxa+repasse==mão de obra ($labor)');
        expect(_c(s.providerTotalNetPayout) + fee, labor + mat, reason: 'repasse total+taxa==bruto ($labor/$mat)');
        expect(_c(s.grossTransactionAmount), labor + mat);
        expect(net, greaterThanOrEqualTo(0));
        expect(s.totalPlatformFeeCents, fee);
        expect(s.providerNetLaborPayoutCents, net);
      }
    });

    test('equivale à fórmula anterior (13,5% + 1,5%) com no máximo 1 centavo de diferença', () {
      final rnd = math.Random(7);
      for (var i = 0; i < 3000; i++) {
        final labor = (rnd.nextInt(5000000) + 1) / 100.0;
        final s = SmartSplitBreakdown(serviceLaborAmount: labor, materialReimbursementAmount: 0);
        final oldOp = double.parse((labor * 0.135).toStringAsFixed(2));
        expect((_c(s.platformOperationalRevenue) - _c(oldOp)).abs(), lessThanOrEqualTo(1), reason: '$labor');
      }
    });

    test('0,5 centavo sobe (half-up) de forma determinística', () {
      // 0,10 * 13,5% = 0,0135 -> 1 centavo. 0,30: operacional 4,05c -> 4c; reserva 0,45c -> 0c (cada\n      // parcela arredonda separado, como sempre foi; a taxa é a SOMA das parcelas já arredondadas).
      final a = SmartSplitBreakdown(serviceLaborAmount: 0.10, materialReimbursementAmount: 0);
      expect(a.platformOperationalRevenue, 0.01);
      final b = SmartSplitBreakdown.validated(serviceLaborAmount: 0.30, materialReimbursementAmount: 0);
      expect(b.platformOperationalRevenue, 0.04);
      expect(b.warrantyReserveContribution, 0.0);
      expect(b.totalPlatformFee, 0.04);
      expect(b.providerNetLaborPayout, 0.26);
    });

    test('mão de obra zero: sem divisão por zero na alíquota efetiva', () {
      final s = SmartSplitBreakdown(serviceLaborAmount: 0, materialReimbursementAmount: 0);
      expect(s.effectiveFeePercentageOnGross, 0.0);
      expect(s.totalPlatformFee, 0.0);
    });

    test('roundCurrency tolera ruído binário (1.005 -> 1.01) e rejeita NaN/Infinity', () {
      expect(SecurityAndLgpdGuard.roundCurrency(1.005), 1.01);
      expect(SecurityAndLgpdGuard.roundCurrency(0.1 + 0.2), 0.30);
      expect(() => SecurityAndLgpdGuard.roundCurrency(double.nan), throwsArgumentError);
      expect(() => SecurityAndLgpdGuard.roundCurrency(double.infinity), throwsArgumentError);
    });

    test('toMap/fromMap preserva valores; totais do passaporte somam em centavos', () {
      final s = SmartSplitBreakdown.validated(serviceLaborAmount: 33.33, materialReimbursementAmount: 0.07);
      final back = SmartSplitBreakdown.fromJson(s.toJson());
      expect(back, s);
      expect(back.totalPlatformFee, s.totalPlatformFee);
    });
  });
}

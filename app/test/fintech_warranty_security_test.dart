import 'dart:convert';

import 'package:desperrengue_app/core/models/fintech_warranty_models.dart';
import 'package:desperrengue_app/core/services/app_version_and_update_service.dart';
import 'package:desperrengue_app/core/services/desperrengue_official_pdf_service.dart';
import 'package:desperrengue_app/core/state/anti_bypass_fintech_controller.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/features/shared/presentation/fintech_warranty_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('1. Teste Matemático do Split Inteligente (Carteira A + Carteira B 0%)', () {
    test('Mão de Obra = R\$ 100,00 e Material = R\$ 150,00 produz valores exatos de centavos', () {
      final split = SmartSplitBreakdown.validated(
        serviceLaborAmount: 100.00,
        materialReimbursementAmount: 150.00,
      );

      expect(split.grossTransactionAmount, 250.00);
      expect(split.platformOperationalRevenue, 13.50);
      expect(split.warrantyReserveContribution, 1.50);
      expect(split.totalPlatformFee, 15.00);
      expect(split.providerNetLaborPayout, 85.00);
      expect(split.providerTotalNetPayout, 235.00);
      expect(split.providerSavedFeeBySmartSplit, 22.50);
      expect(split.maxWarrantyCoverageCap, 100.00);
      expect(split.effectiveFeePercentageOnGross, 6.00);

      // Roundtrip JSON e igualdade estrutural
      final decoded = SmartSplitBreakdown.fromJson(split.toJson());
      expect(decoded, equals(split));
      expect(decoded.hashCode, equals(split.hashCode));
    });

    test('Blindagem Anti-Tampering bloqueia valores negativos, NaN, Infinity e alíquotas adulteradas', () {
      expect(
        () => SmartSplitBreakdown.validated(
          serviceLaborAmount: -10.0,
          materialReimbursementAmount: 50.0,
        ),
        throwsArgumentError,
      );
      expect(
        () => SmartSplitBreakdown.validated(
          serviceLaborAmount: double.nan,
          materialReimbursementAmount: 50.0,
        ),
        throwsArgumentError,
      );
      expect(
        () => SmartSplitBreakdown.validated(
          serviceLaborAmount: 100.0,
          materialReimbursementAmount: double.infinity,
        ),
        throwsArgumentError,
      );
      expect(
        () => SmartSplitBreakdown.validated(
          serviceLaborAmount: 100.0,
          materialReimbursementAmount: 50.0,
          totalPlatformTakeRate: 0.15,
          operationalTakeRate: 0.10,
          warrantyReserveTakeRate: 0.01,
        ),
        throwsArgumentError,
      );
    });
  });

  group('2. Teste das 3 Camadas da Garantia, Teto Cap e Fundo de Reserva (1,5%)', () {
    test('Transição entre Camadas 1, 2 e 3 respeita maxWarrantyCoverageCap e registra Clawback', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(antiBypassFintechControllerProvider.notifier);
      const orderId = 'ORD-TEST-3LAYERS';

      notifier.ensureOrder(
        orderId: orderId,
        serviceCategoryName: 'Elétrica',
        serviceTitle: 'Troca de Disjuntor Geral',
        providerId: 'prov-infrator-77',
        providerName: 'Técnico Original',
        serviceLaborAmount: 200.00,
      );

      // Camada 1: Retorno gratuito obrigatório (Art. 20 CDC) com trava de agenda
      final claimL1 = notifier.triggerWarrantyLayer(
        orderId: orderId,
        layer: WarrantyResolutionLayer.layer1ProviderFreeReturn,
        claimReason: 'Disjuntor voltou a desarmar.',
        hoursSinceCompletion: 72.0,
      );
      expect(claimL1.currentLayer, WarrantyResolutionLayer.layer1ProviderFreeReturn);
      expect(claimL1.status, WarrantyClaimStatus.providerAssignedForReturn);
      expect(claimL1.isOriginalProviderScheduleLocked, isTrue);
      expect(claimL1.reserveFundAllocatedAmount, 0.0);
      expect(claimL1.clawbackDebitedFromOffender, 0.0);

      // Camada 2: Retenção preventiva da Carteira A no Escrow (<48h)
      final claimL2 = notifier.triggerWarrantyLayer(
        orderId: orderId,
        layer: WarrantyResolutionLayer.layer2EscrowHoldRetention,
        claimReason: 'Defeito precoce em 12h.',
        hoursSinceCompletion: 12.0,
      );
      expect(claimL2.currentLayer, WarrantyResolutionLayer.layer2EscrowHoldRetention);
      expect(claimL2.status, WarrantyClaimStatus.escrowRetained);
      expect(claimL2.isEscrowWalletARetained, isTrue);
      expect(claimL2.reserveFundAllocatedAmount, 0.0);

      // Camada 3: Acionamento do Fundo de Reserva (1,5%) com tentativa de valor acima do Cap (R$ 500 > R$ 200)
      final balanceBeforeL3 = container.read(antiBypassFintechControllerProvider).reserveFundBalance;
      final claimL3 = notifier.triggerWarrantyLayer(
        orderId: orderId,
        layer: WarrantyResolutionLayer.layer3ReserveFundRescue,
        claimReason: 'Prestador original recusou retorno.',
        hoursSinceCompletion: 96.0,
        requestedRescueAmount: 500.00, // Acima do teto de R$ 200,00!
        rescueProviderId: 'prov-socorrista-01',
      );

      expect(claimL3.currentLayer, WarrantyResolutionLayer.layer3ReserveFundRescue);
      expect(claimL3.status, WarrantyClaimStatus.rescueProviderDispatched);
      expect(claimL3.maxWarrantyCoverageCap, 200.00);
      expect(
        claimL3.reserveFundAllocatedAmount,
        200.00,
        reason: 'Nunca deve ultrapassar 100% da mão de obra original (Cap)',
      );
      expect(claimL3.clawbackDebitedFromOffender, 200.00);
      expect(claimL3.rescueProviderId, 'prov-socorrista-01');

      final stateAfterL3 = container.read(antiBypassFintechControllerProvider);
      expect(stateAfterL3.reserveFundBalance, closeTo(balanceBeforeL3 - 200.00, 0.001));
      expect(stateAfterL3.providerClawbackLedger['prov-infrator-77'], 200.00);

      // Roundtrip JSON do ticket de garantia
      final decodedTicket = WarrantyClaimTicket.fromJson(claimL3.toJson());
      expect(decodedTicket, equals(claimL3));
    });
  });

  group('3. Teste da Cadeia Forense, Geração de PDF Oficial e Segurança LGPD', () {
    test('Mascaramento de PII (CPF, CNPJ, telefone, nome) e sanitização contra XSS', () {
      expect(SecurityAndLgpdGuard.maskCpfOrCnpj('123.456.789-01'), '***.456.789-**');
      expect(SecurityAndLgpdGuard.maskCpfOrCnpj('12.345.678/0001-99'), '**.345.678/0001-**');
      expect(SecurityAndLgpdGuard.maskPhone('(34) 99876-1234'), '(**) *****-1234');
      expect(SecurityAndLgpdGuard.maskClientName('Wagner Oliveira'), 'Wagner O.');

      final dirty = '<script>alert("xss")</script>Disjuntor 32A onclick=steal() <b>OK</b>';
      final sanitized = SecurityAndLgpdGuard.sanitizeInput(dirty);
      expect(sanitized.contains('<script>'), isFalse);
      expect(sanitized.contains('onclick='), isFalse);
      expect(sanitized, 'Disjuntor 32A steal() OK');
    });

    test('Certificado exige mínimo de 2 fotos Check-in e 2 fotos Check-out e gera PDF válido', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(antiBypassFintechControllerProvider.notifier);
      const orderId = 'ORD-CERT-PDF-01';

      final initial = notifier.ensureOrder(
        orderId: orderId,
        serviceCategoryName: 'Hidráulica',
        serviceTitle: 'Reparo de Registro Geral',
        clientName: 'Wagner Oliveira',
        providerName: 'Marcos Hidráulica',
        serviceLaborAmount: 160.00,
      );

      // Possui 2 fotos de Check-in mas 0 de Check-out -> deve falhar ao emitir antes do Check-out
      expect(initial.checkInBeforePhotos.length, 2);
      expect(initial.checkOutAfterPhotos.length, 0);
      expect(() => notifier.issueCertificate(orderId), throwsStateError);

      // Adiciona 1ª foto de Check-out -> ainda incompleto (1/2)
      final after1 = notifier.addCheckOutPhoto(
        orderId: orderId,
        imagePathOrUrl: 'forensic://checkout/1',
        captionOrTechnicalNote: 'Registro trocado sem vazamento.',
      );
      expect(after1.certificate, isNull);

      // Adiciona 2ª foto de Check-out -> emite automaticamente o Certificado Digital de Garantia!
      final after2 = notifier.addCheckOutPhoto(
        orderId: orderId,
        imagePathOrUrl: 'forensic://checkout/2',
        captionOrTechnicalNote: 'Acabamento instalado e local limpo.',
      );
      final cert = after2.certificate;
      expect(cert, isNotNull);
      expect(cert!.hasCompleteForensicChain, isTrue);
      expect(cert.isValidAndActive, isTrue);
      expect(cert.goldenLegalClauses.length, 3);
      expect(cert.maskedClientName, 'Wagner O.');

      // Valida geração do PDF Oficial (%PDF-1.4) do Certificado e do Passaporte do Imóvel
      const pdfService = DesperrengueOfficialPdfService();
      final certPdfBytes = pdfService.generateWarrantyCertificatePdf(
        cert,
        clientCpf: '123.456.789-00',
        clientPhone: '34991234567',
      );
      final certPdfText = ascii.decode(certPdfBytes, allowInvalid: true);
      expect(certPdfText.startsWith('%PDF-1.4'), isTrue);
      expect(certPdfText.contains(cert.certificateCode), isTrue);
      expect(certPdfText.contains('***.456.789-**'), isTrue);
      expect(certPdfText.contains('*****-4567'), isTrue);

      final passport = container.read(antiBypassFintechControllerProvider).propertyPassport;
      expect(passport.entries.any((e) => e.orderId == orderId), isTrue);
      final passportPdfBytes = pdfService.generatePropertyPassportPdf(passport);
      final passportPdfText = ascii.decode(passportPdfBytes, allowInvalid: true);
      expect(passportPdfText.startsWith('%PDF-1.4'), isTrue);
      expect(passportPdfText.contains(passport.passportId), isTrue);
    });
  });

  group('4. Teste de Widgets, Responsividade (360px/480px) e Botão Atualizar App', () {
    testWidgets('Renderiza SmartSplitTransparencyCard, ForensicCheckInOutCard, PropertyPassportView e AppQuickUpdateButton em Light e Dark Mode sem overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dossier = FintechLedgerStore.instance.ensureOrder(
        orderId: 'ORD-WIDGET-360',
        serviceLaborAmount: 100.00,
      );
      final passport = FintechLedgerStore.instance.state.propertyPassport;

      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.resolve(null, brightness),
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const AppQuickUpdateButton(compact: true, reloadWebOnTap: false),
                      const SizedBox(height: 8),
                      const AppQuickUpdateButton(compact: false, reloadWebOnTap: false),
                      const SizedBox(height: 12),
                      SmartSplitTransparencyCard(dossier: dossier),
                      const SizedBox(height: 12),
                      ForensicCheckInOutCard(dossier: dossier),
                      const SizedBox(height: 12),
                      PropertyPassportView(passport: passport, compact: true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('0% DE TAXA SOBRE PEÇAS'), findsOneWidget);
        expect(find.textContaining('Atualizar'), findsWidgets);
        expect(find.text('Prontuário da Casa (Passaporte do Imóvel)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}

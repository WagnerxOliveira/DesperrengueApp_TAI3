import 'package:flutter/material.dart';

import '../../../core/models/fintech_warranty_models.dart';
import '../../../core/services/desperrengue_official_pdf_service.dart';
import '../../../core/state/anti_bypass_fintech_controller.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/utils/format.dart';

/// Card de Transparência do Split Inteligente (Carteira A: Mão de Obra vs Carteira B: Peças 0%).
class SmartSplitTransparencyCard extends StatelessWidget {
  const SmartSplitTransparencyCard({
    super.key,
    required this.dossier,
    this.isProviderView = false,
    this.onAddMaterialReceipt,
    this.onToggleMaterialApproval,
  });

  final OrderFintechDossierState dossier;
  final bool isProviderView;
  final VoidCallback? onAddMaterialReceipt;
  final ValueChanged<String>? onToggleMaterialApproval;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final split = dossier.splitBreakdown;
    final accent = isProviderView ? tk.providerAccent : tk.clientAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tk.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.account_balance_rounded, size: 20, color: accent),
              Text(
                'Split Inteligente Anti-Bypass (Escrow BaaS)',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: tk.text,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tk.successSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: tk.success.withValues(alpha: 0.45)),
                ),
                child: Text(
                  '0% DE TAXA SOBRE PEÇAS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: tk.successInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Carteira A vs Carteira B
          Row(
            children: [
              Expanded(
                child: _WalletMiniBox(
                  title: 'Carteira A • Mão de Obra',
                  amount: brl(split.serviceLaborAmount),
                  subtitle: '13,5% Op. + 1,5% Fundo Garantia',
                  accentColor: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WalletMiniBox(
                  title: 'Carteira B • Peças (NFC-e)',
                  amount: brl(split.materialReimbursementAmount),
                  subtitle: 'Reembolso 100% (Taxa Zero)',
                  accentColor: tk.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tk.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _SplitRow(
                  label: 'Total Bruto Protegido (M + P)',
                  value: brl(split.grossTransactionAmount),
                  bold: true,
                ),
                const SizedBox(height: 4),
                _SplitRow(
                  label: 'Caixa Operacional Plataforma (13,5% s/ M)',
                  value: brl(split.platformOperationalRevenue),
                ),
                const SizedBox(height: 4),
                _SplitRow(
                  label: 'Aporte Fundo de Reserva de Garantia (1,5% s/ M)',
                  value: brl(split.warrantyReserveContribution),
                  valueColor: tk.successInk,
                ),
                const Divider(height: 16),
                _SplitRow(
                  label: 'Repasse Líquido Total ao Prestador',
                  value: brl(split.providerTotalNetPayout),
                  bold: true,
                  valueColor: accent,
                ),
                const SizedBox(height: 4),
                _SplitRow(
                  label: 'Economia Real do Prestador (0% nas peças)',
                  value: '+ ${brl(split.providerSavedFeeBySmartSplit)}',
                  valueColor: tk.successInk,
                  bold: true,
                ),
                const SizedBox(height: 4),
                _SplitRow(
                  label: 'Teto Máx. Cobertura do Fundo (Cap 100% M)',
                  value: brl(split.maxWarrantyCoverageCap),
                ),
              ],
            ),
          ),
          if (dossier.reimbursedMaterials.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Cupons Fiscais de Peças (Carteira B)',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                color: tk.text,
              ),
            ),
            const SizedBox(height: 6),
            for (final item in dossier.reimbursedMaterials)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tk.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.isApprovedByClient
                        ? tk.success.withValues(alpha: 0.45)
                        : tk.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.isApprovedByClient
                          ? Icons.verified_rounded
                          : Icons.receipt_long_rounded,
                      size: 20,
                      color: item.isApprovedByClient ? tk.success : tk.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.materialDescription,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: tk.text,
                            ),
                          ),
                          Text(
                            '${item.storeName} • ${item.fiscalReceiptNumber}',
                            style: TextStyle(fontSize: 11.5, color: tk.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          brl(item.receiptTotalAmount),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            color: tk.text,
                          ),
                        ),
                        if (onToggleMaterialApproval != null)
                          InkWell(
                            onTap: () => onToggleMaterialApproval!(item.id),
                            child: Text(
                              item.isApprovedByClient ? 'Aprovado ✓' : 'Aprovar cupom',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: item.isApprovedByClient ? tk.successInk : accent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
          if (onAddMaterialReceipt != null) ...[
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: onAddMaterialReceipt,
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: const Text('Anexar Cupom Fiscal de Peça (0% Taxa)'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WalletMiniBox extends StatelessWidget {
  const _WalletMiniBox({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.accentColor,
  });

  final String title;
  final String amount;
  final String subtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: tk.isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: tk.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: tk.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: bold ? tk.text : tk.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: valueColor ?? tk.text,
            ),
          ),
        ),
      ],
    );
  }
}

/// Card de Cadeia Forense de Check-in ("Antes") e Check-out ("Depois") + Emissão de Certificado PDF.
class ForensicCheckInOutCard extends StatelessWidget {
  const ForensicCheckInOutCard({
    super.key,
    required this.dossier,
    this.isProviderView = false,
    this.onAddCheckInPhoto,
    this.onAddCheckOutPhoto,
    this.onOpenThreeLayerWarranty,
  });

  final OrderFintechDossierState dossier;
  final bool isProviderView;
  final VoidCallback? onAddCheckInPhoto;
  final VoidCallback? onAddCheckOutPhoto;
  final VoidCallback? onOpenThreeLayerWarranty;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final cert = dossier.certificate;
    final beforeCount = dossier.checkInBeforePhotos.length;
    final afterCount = dossier.checkOutAfterPhotos.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tk.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: tk.infoSoft,
                child: Icon(Icons.verified_user_rounded, size: 20, color: tk.info),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auditoria Forense Antes/Depois & Garantia CDC',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: tk.text,
                      ),
                    ),
                    Text(
                      'Mínimo 2 fotos Antes + 2 fotos Depois com GPS e Hash SHA',
                      style: TextStyle(fontSize: 12, color: tk.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ForensicStagePill(
                  title: 'Check-in (Antes)',
                  countText: '$beforeCount/2+ fotos',
                  completed: beforeCount >= 2,
                  onAdd: onAddCheckInPhoto,
                  buttonLabel: '+ Foto Antes',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ForensicStagePill(
                  title: 'Check-out (Depois)',
                  countText: '$afterCount/2+ fotos',
                  completed: afterCount >= 2,
                  onAdd: onAddCheckOutPhoto,
                  buttonLabel: '+ Foto Depois',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Lista resumida de hashes forenses
          for (final p in [
            ...dossier.checkInBeforePhotos.take(2),
            ...dossier.checkOutAfterPhotos.take(2),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    p.isGpsVerifiedAtAddress
                        ? Icons.gps_fixed_rounded
                        : Icons.gps_not_fixed_rounded,
                    size: 14,
                    color: tk.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${p.stage.label}: ${p.captionOrTechnicalNote}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: tk.text),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    p.integrityHash.substring(0, 14),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: tk.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          if (cert != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tk.successSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tk.success.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.workspace_premium_rounded, color: tk.successInk),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Certificado Emitido: ${cert.certificateCode}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            color: tk.successInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vigência Legal: ${cert.warrantyDurationDays} dias (${cert.remainingDays} restantes) • Titular LGPD: ${cert.maskedClientName}',
                    style: TextStyle(fontSize: 12, color: tk.successInk),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => const DesperrengueOfficialPdfService()
                          .showCertificatePreviewDialog(context, cert),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: const Text('Abrir Certificado Digital em PDF'),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tk.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: tk.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Conclua as 2 fotos de Check-out ("Depois") para emitir automaticamente o Certificado Digital de Garantia em PDF.',
                      style: TextStyle(fontSize: 12, color: tk.textMuted, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          if (onOpenThreeLayerWarranty != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenThreeLayerWarranty,
                icon: const Icon(Icons.shield_rounded, size: 18),
                label: const Text('Central de Garantia em 3 Camadas (CDC + Fundo 1,5%)'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ForensicStagePill extends StatelessWidget {
  const _ForensicStagePill({
    required this.title,
    required this.countText,
    required this.completed,
    this.onAdd,
    required this.buttonLabel,
  });

  final String title;
  final String countText;
  final bool completed;
  final VoidCallback? onAdd;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final color = completed ? tk.success : tk.warningInk;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: completed ? tk.successSoft : tk.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: completed ? tk.success.withValues(alpha: 0.45) : tk.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                completed ? Icons.check_circle_rounded : Icons.camera_alt_outlined,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: tk.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            countText,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: completed ? tk.successInk : tk.textMuted,
            ),
          ),
          if (onAdd != null) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onAdd,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// BottomSheet / Painel Interativo da Arquitetura de 3 Camadas da Garantia + Livro-Razão do Fundo 1,5%.
class WarrantyThreeLayerResolutionSheet extends StatefulWidget {
  const WarrantyThreeLayerResolutionSheet({
    super.key,
    required this.orderId,
  });

  final String orderId;

  static Future<void> show(BuildContext context, {required String orderId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WarrantyThreeLayerResolutionSheet(orderId: orderId),
    );
  }

  @override
  State<WarrantyThreeLayerResolutionSheet> createState() =>
      _WarrantyThreeLayerResolutionSheetState();
}

class _WarrantyThreeLayerResolutionSheetState
    extends State<WarrantyThreeLayerResolutionSheet> {
  final _reasonCtrl = TextEditingController(
    text: 'Reincidência técnica no mesmo ponto registrado nas fotos de Check-in.',
  );

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _triggerLayer(WarrantyResolutionLayer layer) {
    FintechLedgerStore.instance.triggerWarrantyLayer(
      orderId: widget.orderId,
      layer: layer,
      claimReason: _reasonCtrl.text,
      hoursSinceCompletion: layer == WarrantyResolutionLayer.layer2EscrowHoldRetention
          ? 12.0
          : 72.0,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final global = FintechLedgerStore.instance.state;
    final dossier = FintechLedgerStore.instance.ensureOrder(orderId: widget.orderId);
    final activeClaim = dossier.activeClaimTicket;
    final split = dossier.splitBreakdown;
    final offenderClawback =
        global.providerClawbackLedger[dossier.providerId] ?? 0.0;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: tk.securitySoft,
                  child: Icon(Icons.shield_rounded, color: tk.security),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Garantia Blindada em 3 Camadas',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: tk.text,
                        ),
                      ),
                      Text(
                        'Fundo de Reserva 1,5% Ativo: ${brl(global.reserveFundBalance)} • Cap Pedido: ${brl(split.maxWarrantyCoverageCap)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: tk.successInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (activeClaim != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tk.warningSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tk.warningInk.withValues(alpha: 0.45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Atual: ${activeClaim.status.label}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: tk.warningInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeClaim.auditTrailNote,
                      style: TextStyle(fontSize: 12.5, height: 1.35, color: tk.text),
                    ),
                    if (activeClaim.clawbackDebitedFromOffender > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Clawback lançado no prestador infrator: ${brl(offenderClawback)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: tk.danger,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            for (final layer in WarrantyResolutionLayer.values)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: activeClaim?.currentLayer == layer
                      ? tk.infoSoft
                      : tk.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: activeClaim?.currentLayer == layer
                        ? tk.info
                        : tk.border,
                    width: activeClaim?.currentLayer == layer ? 1.8 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tk.card,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        layer.shortBadge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: tk.brand,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      layer.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: tk.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      layer.description,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: tk.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _triggerLayer(layer),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(
                          activeClaim?.currentLayer == layer
                              ? 'Camada Ativa ✓'
                              : 'Acionar ${layer.shortBadge.split('•').first.trim()}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Visão compacta e painel do Passaporte de Manutenção do Imóvel ("Prontuário da Casa").
class PropertyPassportView extends StatelessWidget {
  const PropertyPassportView({
    super.key,
    required this.passport,
    this.compact = false,
    this.onOpenWizardStep,
  });

  final PropertyMaintenancePassport passport;
  final bool compact;
  final ValueChanged<int>? onOpenWizardStep;

  void _openWizard(BuildContext context, {int initialStep = 0}) {
    if (onOpenWizardStep != null) {
      onOpenWizardStep!(initialStep);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PropertyPassportWizardScreen(initialStep: initialStep),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final hasEntries = passport.entries.isNotEmpty;
    final score = passport.inspectionReadinessScore;
    final hasAddress = passport.propertyAddress.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tk.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: tk.clientSoft,
                child: Icon(Icons.home_work_rounded, color: tk.clientAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prontuário da Casa (Passaporte do Imóvel)',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                        color: tk.text,
                      ),
                    ),
                    Text(
                      'Score de Vistoria: $score/100 • ${passport.activeWarrantiesCount} garantia(s) ativa(s)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: score >= 60 ? tk.successInk : tk.clientAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tk.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tk.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasAddress ? Icons.verified_rounded : Icons.home_outlined,
                      size: 18,
                      color: hasAddress ? tk.success : tk.clientAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasAddress
                            ? '${passport.propertyNickname} • ${passport.propertyType}'
                            : 'Imóvel aguardando configuração inicial pelo proprietário',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: tk.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  hasAddress
                      ? passport.propertyAddress
                      : 'Configure os dados reais do seu imóvel na Etapa 1 para vincular o endereço e os sistemas prediais auditados (ABNT NBR 5674).',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: hasAddress ? tk.text : tk.textMuted,
                  ),
                ),
                if (passport.isConfiguredByClient || passport.inspectedSystems.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Finalidade: ${passport.passportPurpose} • ${passport.inspectedSystems.length} sistema(s) ABNT verificado(s)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: tk.clientAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _WalletMiniBox(
                  title: 'Total Investido',
                  amount: brl(passport.totalInvestedAmount),
                  subtitle: '${passport.entries.length} serviços auditados',
                  accentColor: tk.clientAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WalletMiniBox(
                  title: 'Peças c/ Nota (0%)',
                  amount: brl(passport.totalMaterialsInvested),
                  subtitle: 'Mão de obra: ${brl(passport.totalLaborInvested)}',
                  accentColor: tk.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasEntries)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tk.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tk.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: tk.clientAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '100% Baseado nos Seus Dados Reais (Zero Dados Fictícios)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: tk.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'O Passaporte do seu imóvel inicia zerado (R\$ 0,00). Ele é preenchido exclusivamente quando você registra uma manutenção real realizada no imóvel ou quando finaliza um serviço pelo aplicativo com o seu PIN de segurança.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: tk.textMuted,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _openWizard(context, initialStep: 0),
                        icon: const Icon(Icons.add_home_work_rounded, size: 18),
                        label: const Text('Configurar Imóvel e Registrar 1ª Manutenção Real'),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            for (final entry in (compact ? passport.entries.take(2) : passport.entries))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tk.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tk.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      entry.isWarrantyActive
                          ? Icons.verified_rounded
                          : Icons.history_rounded,
                      size: 18,
                      color: entry.isWarrantyActive ? tk.success : tk.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.serviceCategoryName} • ${entry.serviceTitle}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: tk.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${entry.providerName} • Cert: ${entry.certificateCode}',
                            style: TextStyle(fontSize: 11.5, color: tk.textMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Mão de Obra: ${brl(entry.laborAmount)} • Peças: ${brl(entry.materialAmount)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: tk.clientAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          brl(entry.totalInvested),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: tk.text,
                          ),
                        ),
                        if (!compact && entry.id.startsWith('pm-client-'))
                          InkWell(
                            onTap: () => FintechLedgerStore.instance
                                .removeClientMaintenanceEntry(entry.id),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Remover',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: tk.danger,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => const DesperrengueOfficialPdfService()
                  .showPassportPreviewDialog(context, passport),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('Exportar Prontuário da Casa em PDF (Vistoria/Seguradora)'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tela dedicada para o Passaporte Oficial de Manutenção do Imóvel ("Prontuário da Casa")
/// com animação rápida de entrada, guia executivo de utilidade real (ABNT NBR 5674 / Lei 8.245/91)
/// e jornada guiada de 3 etapas até a conclusão efetiva.
class PropertyPassportScreen extends StatefulWidget {
  const PropertyPassportScreen({
    super.key,
    this.initialOwnerName,
    this.initialAddress,
  });

  final String? initialOwnerName;
  final String? initialAddress;

  @override
  State<PropertyPassportScreen> createState() => _PropertyPassportScreenState();
}

class _PropertyPassportScreenState extends State<PropertyPassportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FintechLedgerStore.instance.syncPassportOwnerAndAddress(
        ownerName: widget.initialOwnerName,
        propertyAddress: widget.initialAddress,
      );
    });
  }

  void _openWizard({int initialStep = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PropertyPassportWizardScreen(
          initialStep: initialStep,
          initialOwnerName: widget.initialOwnerName,
          initialAddress: widget.initialAddress,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppScaffold(
      appBar: AppBar(title: const Text('Prontuário da Casa')),
      body: ValueListenableBuilder(
        valueListenable: FintechLedgerStore.instance,
        builder: (context, _, _) {
          final passport = FintechLedgerStore.instance.state.propertyPassport;
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            builder: (context, animValue, child) {
              return Opacity(
                opacity: animValue.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1.0 - animValue) * 18),
                  child: child,
                ),
              );
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // 1. Banner Hero com Selo ABNT NBR 5674
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        tk.clientAccent.withValues(alpha: tk.isDark ? 0.24 : 0.14),
                        tk.info.withValues(alpha: tk.isDark ? 0.18 : 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: tk.clientAccent.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tk.card,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 14,
                              color: tk.clientAccent,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'PADRÃO ABNT NBR 5674 • LEI DO INQUILINATO 8.245/91',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: tk.clientAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Passaporte Oficial de Manutenção do Imóvel',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: tk.text,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Documento técnico auditado com os dados e valores reais informados por você ou gerados nos seus pedidos concluídos via PIN.',
                        style: TextStyle(
                          color: tk.textMuted,
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openWizard(initialStep: 0),
                          icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                          label: Text(
                            passport.isConfiguredByClient
                                ? 'Gerenciar Imóvel ou Registrar Nova Manutenção'
                                : 'Iniciar Configuração do Passaporte (3 Passos)',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Explicação Executiva: Qual a utilidade prática para o cliente?
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tk.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: tk.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb_rounded, size: 20, color: tk.clientAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Para que serve o Passaporte do Imóvel?',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15.5,
                                color: tk.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const _PassportBenefitRow(
                        icon: Icons.key_rounded,
                        title: '1. Vistoria de Imobiliária e Entrega de Chaves',
                        description:
                            'Comprova revisões elétricas, hidráulicas e pintura feitas por você (Lei 8.245/91), evitando cobranças indevidas na saída do imóvel.',
                      ),
                      const SizedBox(height: 10),
                      const _PassportBenefitRow(
                        icon: Icons.health_and_safety_rounded,
                        title: '2. Comprovação Preventiva para Seguradoras',
                        description:
                            'Atesta a manutenção preventiva exigida pela norma ABNT NBR 5674 (Quadro DR/DPS, telhado, tubulações) para proteção de cobertura.',
                      ),
                      const SizedBox(height: 10),
                      const _PassportBenefitRow(
                        icon: Icons.trending_up_rounded,
                        title: '3. Valorização Patrimonial e Garantias CDC',
                        description:
                            'Organiza o histórico real investido em mão de obra e peças com nota (0% taxa), preservando garantias legais (Art. 20 e 26 do CDC).',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. O que o Usuário Cliente precisa fazer (Passo a Passo Interativo)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tk.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: tk.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.checklist_rtl_rounded, size: 20, color: tk.info),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Como funciona (O que você precisa fazer)',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15.5,
                                color: tk.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _PassportActionStepTile(
                        stepNumber: '1',
                        title: 'Identificar e Vistoriar seu Imóvel',
                        subtitle:
                            'Confirme seu endereço real, o tipo de imóvel, a finalidade e assinale os sistemas prediais verificados.',
                        isDone: passport.isConfiguredByClient,
                        buttonLabel: 'Abrir Etapa 1',
                        onTap: () => _openWizard(initialStep: 0),
                      ),
                      const SizedBox(height: 8),
                      _PassportActionStepTile(
                        stepNumber: '2',
                        title: 'Registrar Manutenções e Valores Reais',
                        subtitle:
                            'Insira os serviços realizados com os valores exatos pagos por você (ou conclua chamados pelo app via PIN).',
                        isDone: passport.entries.isNotEmpty,
                        buttonLabel: 'Abrir Etapa 2',
                        onTap: () => _openWizard(initialStep: 1),
                      ),
                      const SizedBox(height: 8),
                      _PassportActionStepTile(
                        stepNumber: '3',
                        title: 'Emitir o Passaporte Oficial em PDF',
                        subtitle:
                            'Gere o documento homologado com Hash SHA-256 pronto para imobiliárias, seguradoras ou compradores.',
                        isDone: passport.isConfiguredByClient && passport.entries.isNotEmpty,
                        buttonLabel: 'Ver Conclusão / PDF',
                        onTap: () => _openWizard(initialStep: 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Painel em Tempo Real do Passaporte do Imóvel
                PropertyPassportView(
                  passport: passport,
                  onOpenWizardStep: (step) => _openWizard(initialStep: step),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PassportBenefitRow extends StatelessWidget {
  const _PassportBenefitRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: tk.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: tk.clientAccent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: tk.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: tk.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PassportActionStepTile extends StatelessWidget {
  const _PassportActionStepTile({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.isDone,
    required this.buttonLabel,
    required this.onTap,
  });

  final String stepNumber;
  final String title;
  final String subtitle;
  final bool isDone;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDone ? tk.successSoft : tk.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDone ? tk.success.withValues(alpha: 0.45) : tk.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: isDone ? tk.success : tk.clientAccent,
              child: isDone
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : Text(
                      stepNumber,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: tk.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: tk.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    buttonLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: isDone ? tk.successInk : tk.clientAccent,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDone ? tk.successInk : tk.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Jornada Interativa de 3 Etapas para Configuração do Imóvel, Registro de Manutenção Real
/// pelo Usuário Cliente e Emissão/Conclusão Efetiva do Passaporte Oficial (ABNT NBR 5674).
class PropertyPassportWizardScreen extends StatefulWidget {
  const PropertyPassportWizardScreen({
    super.key,
    this.initialStep = 0,
    this.initialOwnerName,
    this.initialAddress,
  });

  final int initialStep;
  final String? initialOwnerName;
  final String? initialAddress;

  @override
  State<PropertyPassportWizardScreen> createState() =>
      _PropertyPassportWizardScreenState();
}

class _PropertyPassportWizardScreenState
    extends State<PropertyPassportWizardScreen> {
  static const List<String> _propertyTypes = <String>[
    'Casa Residencial',
    'Apartamento',
    'Imóvel Comercial',
    'Condomínio',
  ];

  static const List<String> _passportPurposes = <String>[
    'Vistoria de Imobiliária / Entrega de Chaves',
    'Comprovação Preventiva para Seguradora',
    'Valorização Patrimonial na Venda',
    'Controle Preventivo ABNT NBR 5674',
  ];

  static const List<String> _abntSystems = <String>[
    'Quadro Elétrico (DR / DPS / Disjuntores)',
    'Rede Hidráulica, Registros e Vedações',
    'Telhado, Calhas e Impermeabilização',
    'Pintura, Revestimentos e Esquadrias',
    'Climatização, Gás e Exaustão',
  ];

  static const List<String> _serviceCategories = <String>[
    'Elétrica',
    'Hidráulica / Encanador',
    'Pintura',
    'Alvenaria / Reforma',
    'Ar-condicionado',
    'Telhado / Calhas',
    'Marcenaria / Montagem',
    'Desentupimento',
  ];

  static const Map<String, List<String>> _categoryQuickSuggestions =
      <String, List<String>>{
    'Elétrica': <String>[
      'Revisão do Quadro de Distribuição (QDC) e Disjuntor DR',
      'Substituição de Tomadas 20A e Interruptores',
      'Instalação de Chuveiro Elétrico e Aterramento',
    ],
    'Hidráulica / Encanador': <String>[
      'Correção de Vazamento em Registro e Troca de Vedação',
      'Substituição de Sifão, Engate Flexível e Válvula de Descarga',
      'Limpeza e Revisão de Caixa d\'Água e Boia',
    ],
    'Pintura': <String>[
      'Pintura Acrílica Completa para Vistoria de Entrega de Chaves',
      'Tratamento de Trincas, Massa Corrida e Repintura de Paredes',
      'Pintura Impermeabilizante de Fachada / Muro Externo',
    ],
    'Alvenaria / Reforma': <String>[
      'Assentamento de Porcelanato e Rejunte Impermeável',
      'Reparo de Reboco e Impermeabilização de Rodapé',
    ],
    'Ar-condicionado': <String>[
      'Higienização Técnica e Recarga de Gás Split Inverter',
      'Manutenção Preventiva de Dreno e Serpentina',
    ],
    'Telhado / Calhas': <String>[
      'Limpeza de Calhas, Rufos e Substituição de Telhas',
      'Aplicação de Manta Asfáltica contra Infiltração',
    ],
    'Marcenaria / Montagem': <String>[
      'Regulagem de Dobradiças, Corrediças e Portas de Armários',
      'Montagem e Fixação Estrutural de Móveis Planejados',
    ],
    'Desentupimento': <String>[
      'Desobstrução e Hidrojateamento de Caixa de Gordura e Ralos',
      'Limpeza Preventiva de Tubulação de Esgoto Primário',
    ],
  };

  late int _currentStep;
  late final TextEditingController _ownerCtrl;
  late final TextEditingController _nicknameCtrl;
  late final TextEditingController _addressCtrl;
  late String _selectedPropertyType;
  late String _selectedPurpose;
  late Set<String> _selectedSystems;

  String _selectedCategory = _serviceCategories.first;
  late final TextEditingController _serviceTitleCtrl;
  late final TextEditingController _providerNameCtrl;
  late final TextEditingController _laborAmountCtrl;
  late final TextEditingController _materialAmountCtrl;
  int _selectedWarrantyDays = 90;
  String? _stepError;
  PropertyMaintenanceEntry? _lastCreatedEntry;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep.clamp(0, 2);
    final passport = FintechLedgerStore.instance.state.propertyPassport;
    final defaultOwner = passport.ownerName.trim().isNotEmpty
        ? passport.ownerName.trim()
        : (widget.initialOwnerName?.trim() ?? '');
    final defaultAddress = passport.propertyAddress.trim().isNotEmpty
        ? passport.propertyAddress.trim()
        : (widget.initialAddress?.trim() ?? '');

    _ownerCtrl = TextEditingController(text: defaultOwner);
    _nicknameCtrl = TextEditingController(
      text: passport.propertyNickname.trim().isNotEmpty
          ? passport.propertyNickname.trim()
          : 'Residência Principal',
    );
    _addressCtrl = TextEditingController(text: defaultAddress);
    _selectedPropertyType = _propertyTypes.contains(passport.propertyType)
        ? passport.propertyType
        : _propertyTypes.first;
    _selectedPurpose = _passportPurposes.contains(passport.passportPurpose)
        ? passport.passportPurpose
        : _passportPurposes.first;
    _selectedSystems = Set<String>.from(passport.inspectedSystems);

    _serviceTitleCtrl = TextEditingController();
    _providerNameCtrl = TextEditingController();
    _laborAmountCtrl = TextEditingController();
    _materialAmountCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _ownerCtrl.dispose();
    _nicknameCtrl.dispose();
    _addressCtrl.dispose();
    _serviceTitleCtrl.dispose();
    _providerNameCtrl.dispose();
    _laborAmountCtrl.dispose();
    _materialAmountCtrl.dispose();
    super.dispose();
  }

  double _parseCurrencyInput(String raw) {
    final cleaned = raw
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  double get _previewLaborAmount => _parseCurrencyInput(_laborAmountCtrl.text);
  double get _previewMaterialAmount =>
      _parseCurrencyInput(_materialAmountCtrl.text);
  double get _previewTotalAmount =>
      _previewLaborAmount + _previewMaterialAmount;

  bool _saveStep1Configuration({bool advanceToStep2 = true}) {
    final address = _addressCtrl.text.trim();
    if (address.length < 5) {
      setState(() {
        _stepError =
            'Informe o endereço real do imóvel (mínimo 5 caracteres) para vincular ao Passaporte.';
      });
      return false;
    }

    FintechLedgerStore.instance.configurePropertyPassport(
      ownerName: _ownerCtrl.text.trim(),
      propertyNickname: _nicknameCtrl.text.trim(),
      propertyAddress: address,
      propertyType: _selectedPropertyType,
      passportPurpose: _selectedPurpose,
      inspectedSystems: _selectedSystems.toList(growable: false),
    );

    setState(() {
      _stepError = null;
      if (advanceToStep2) {
        _currentStep = 1;
      }
    });
    return true;
  }

  void _submitStep2MaintenanceEntry() {
    if (!_saveStep1Configuration(advanceToStep2: false)) {
      setState(() => _currentStep = 0);
      return;
    }

    final title = _serviceTitleCtrl.text.trim();
    final provider = _providerNameCtrl.text.trim();
    final labor = _previewLaborAmount;
    final material = _previewMaterialAmount;

    if (title.length < 4) {
      setState(() {
        _stepError =
            'Descreva o serviço realizado no imóvel (ex.: Revisão elétrica, Pintura de sala, etc.).';
      });
      return;
    }
    if (provider.length < 2) {
      setState(() {
        _stepError =
            'Informe o nome do profissional ou empresa que realizou o serviço.';
      });
      return;
    }
    if (labor <= 0 && material <= 0) {
      setState(() {
        _stepError =
            'Informe o valor real pago em Mão de Obra e/ou Peças (maior que R\$ 0,00).';
      });
      return;
    }

    final created = FintechLedgerStore.instance.registerClientMaintenanceEntry(
      serviceCategoryName: _selectedCategory,
      serviceTitle: title,
      providerName: provider,
      laborAmount: labor,
      materialAmount: material,
      warrantyDurationDays: _selectedWarrantyDays,
      propertyAddress: _addressCtrl.text.trim(),
      ownerName: _ownerCtrl.text.trim(),
    );

    setState(() {
      _stepError = null;
      _lastCreatedEntry = created;
      _currentStep = 2;
    });
  }

  void _resetStep2ForNewEntry() {
    setState(() {
      _serviceTitleCtrl.clear();
      _providerNameCtrl.clear();
      _laborAmountCtrl.clear();
      _materialAmountCtrl.clear();
      _stepError = null;
      _currentStep = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppScaffold(
      appBar: AppBar(
        title: Text(
          _currentStep == 0
              ? 'Etapa 1 de 3 • Identificar Imóvel'
              : _currentStep == 1
                  ? 'Etapa 2 de 3 • Registrar Manutenção'
                  : 'Etapa 3 de 3 • Passaporte Homologado',
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: FintechLedgerStore.instance,
        builder: (context, _, _) {
          final passport = FintechLedgerStore.instance.state.propertyPassport;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // Barra de Progresso Interativa das 3 Etapas
              Row(
                children: [
                  _WizardProgressPill(
                    stepIndex: 0,
                    currentStep: _currentStep,
                    label: '1. Imóvel & ABNT',
                    onTap: () => setState(() {
                      _stepError = null;
                      _currentStep = 0;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _WizardProgressPill(
                    stepIndex: 1,
                    currentStep: _currentStep,
                    label: '2. Serviço Real',
                    onTap: () => setState(() {
                      _stepError = null;
                      _currentStep = 1;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _WizardProgressPill(
                    stepIndex: 2,
                    currentStep: _currentStep,
                    label: '3. Conclusão PDF',
                    onTap: () => setState(() {
                      _stepError = null;
                      _currentStep = 2;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_stepError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tk.warningSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: tk.warningInk.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: tk.warningInk),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _stepError!,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: tk.warningInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                child: _currentStep == 0
                    ? _buildStep1PropertySetup(context, tk)
                    : _currentStep == 1
                        ? _buildStep2MaintenanceForm(context, tk)
                        : _buildStep3EffectiveCompletion(context, tk, passport),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStep1PropertySetup(BuildContext context, AppTokens tk) {
    return Container(
      key: const ValueKey<String>('passport-step-1'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tk.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Etapa 1: Identificação e Vistoria do Imóvel',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: tk.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Confirme os dados reais do seu imóvel e marque os sistemas prediais que já passaram por verificação preventiva (ABNT NBR 5674).',
            style: TextStyle(fontSize: 12.5, height: 1.35, color: tk.textMuted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nicknameCtrl,
            decoration: const InputDecoration(
              labelText: 'Identificação do Imóvel',
              hintText: 'Ex.: Residência Principal, Apartamento Centro',
              prefixIcon: Icon(Icons.home_work_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ownerCtrl,
            decoration: const InputDecoration(
              labelText: 'Nome do Proprietário / Locatário Responsável',
              hintText: 'Seu nome completo',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(
              labelText: 'Endereço Completo do Imóvel',
              hintText: 'Rua, número, bairro e cidade',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Tipo do Imóvel',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: tk.text,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in _propertyTypes)
                ChoiceChip(
                  label: Text(type),
                  selected: _selectedPropertyType == type,
                  onSelected: (_) =>
                      setState(() => _selectedPropertyType = type),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Finalidade Principal do Passaporte',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: tk.text,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final purpose in _passportPurposes)
                ChoiceChip(
                  label: Text(purpose),
                  selected: _selectedPurpose == purpose,
                  onSelected: (_) =>
                      setState(() => _selectedPurpose = purpose),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Checklist de Sistemas Prediais Verificados (ABNT NBR 5674)',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: tk.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cada sistema verificado eleva o Score de Vistoria Técnica do imóvel.',
            style: TextStyle(fontSize: 11.5, color: tk.textMuted),
          ),
          const SizedBox(height: 8),
          for (final system in _abntSystems)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  if (_selectedSystems.contains(system)) {
                    _selectedSystems.remove(system);
                  } else {
                    _selectedSystems.add(system);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _selectedSystems.contains(system),
                      visualDensity: VisualDensity.compact,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedSystems.add(system);
                          } else {
                            _selectedSystems.remove(system);
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        system,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: tk.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _saveStep1Configuration(advanceToStep2: true),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Salvar Imóvel e Avançar para Etapa 2'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2MaintenanceForm(BuildContext context, AppTokens tk) {
    final suggestions =
        _categoryQuickSuggestions[_selectedCategory] ?? const <String>[];

    return Container(
      key: const ValueKey<String>('passport-step-2'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tk.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Etapa 2: Registrar Manutenção Realizada no Imóvel',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: tk.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Informe os valores reais pagos por você na manutenção. O sistema gera o Certificado com Hash SHA-256 e atualiza o Total Investido do imóvel.',
            style: TextStyle(fontSize: 12.5, height: 1.35, color: tk.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            'Categoria do Serviço Realizado',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: tk.text,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cat in _serviceCategories)
                ChoiceChip(
                  label: Text(cat),
                  selected: _selectedCategory == cat,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                ),
            ],
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Sugestões rápidas de preenchimento (toque se desejar):',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: tk.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            for (final suggestion in suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() {
                      _serviceTitleCtrl.text = suggestion;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: tk.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tk.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_fix_high_rounded,
                          size: 15,
                          color: tk.clientAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            suggestion,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: tk.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _serviceTitleCtrl,
            decoration: const InputDecoration(
              labelText: 'Descrição do Serviço Realizado',
              hintText: 'Ex.: Substituição de Disjuntor DR e revisão do quadro',
              prefixIcon: Icon(Icons.build_circle_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _providerNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Profissional ou Empresa Executora',
              hintText: 'Nome do técnico ou empresa contratada',
              prefixIcon: Icon(Icons.engineering_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _laborAmountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Mão de Obra (R\$)',
                    hintText: 'Ex.: 180,00',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _materialAmountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Peças c/ Nota (R\$)',
                    hintText: 'Ex.: 95,00',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tk.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tk.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total Real desta Manutenção:',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: tk.text,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  brl(_previewTotalAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: tk.clientAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Prazo de Garantia do Serviço',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: tk.text,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('90 dias (Legal CDC)'),
                selected: _selectedWarrantyDays == 90,
                onSelected: (_) => setState(() => _selectedWarrantyDays = 90),
              ),
              ChoiceChip(
                label: const Text('180 dias (Semestral)'),
                selected: _selectedWarrantyDays == 180,
                onSelected: (_) => setState(() => _selectedWarrantyDays = 180),
              ),
              ChoiceChip(
                label: const Text('365 dias (1 Ano ABNT)'),
                selected: _selectedWarrantyDays == 365,
                onSelected: (_) => setState(() => _selectedWarrantyDays = 365),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitStep2MaintenanceEntry,
              icon: const Icon(Icons.verified_rounded, size: 18),
              label: const Text('Homologar Registro Real e Concluir Passaporte'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3EffectiveCompletion(
    BuildContext context,
    AppTokens tk,
    PropertyMaintenancePassport passport,
  ) {
    final latestEntry = _lastCreatedEntry ??
        (passport.entries.isNotEmpty ? passport.entries.first : null);

    return Container(
      key: const ValueKey<String>('passport-step-3'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tk.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tk.success.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.85, end: 1.0),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tk.successSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: tk.success,
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Passaporte Oficial Homologado!',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16.5,
                            color: tk.successInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${passport.passportId} • Score Atualizado: ${passport.inspectionReadinessScore}/100',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: tk.successInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Resumo Oficial Auditado do Seu Imóvel',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: tk.text,
            ),
          ),
          const SizedBox(height: 8),
          _SplitRow(
            label: 'Imóvel / Tipo',
            value: '${passport.propertyNickname} (${passport.propertyType})',
            bold: true,
          ),
          const SizedBox(height: 4),
          _SplitRow(
            label: 'Finalidade Oficial',
            value: passport.passportPurpose,
          ),
          const SizedBox(height: 4),
          _SplitRow(
            label: 'Total Real Investido',
            value: brl(passport.totalInvestedAmount),
            bold: true,
            valueColor: tk.clientAccent,
          ),
          const SizedBox(height: 4),
          _SplitRow(
            label: 'Mão de Obra / Peças c/ Nota',
            value:
                '${brl(passport.totalLaborInvested)} / ${brl(passport.totalMaterialsInvested)}',
          ),
          const SizedBox(height: 4),
          _SplitRow(
            label: 'Intervenções / Garantias Ativas',
            value:
                '${passport.entries.length} registro(s) • ${passport.activeWarrantiesCount} garantia(s)',
          ),
          if (latestEntry != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tk.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tk.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Último Certificado Emitido: ${latestEntry.certificateCode}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      color: tk.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${latestEntry.serviceCategoryName} • ${latestEntry.serviceTitle}',
                    style: TextStyle(fontSize: 12, color: tk.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hash Forense SHA-256: ${latestEntry.forensicHash}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tk.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => const DesperrengueOfficialPdfService()
                  .showPassportPreviewDialog(context, passport),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text(
                'Visualizar e Exportar Passaporte Oficial em PDF',
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _resetStep2ForNewEntry,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('Registrar Outra Manutenção Real'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('Concluir e Voltar ao Prontuário da Casa'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardProgressPill extends StatelessWidget {
  const _WizardProgressPill({
    required this.stepIndex,
    required this.currentStep,
    required this.label,
    required this.onTap,
  });

  final int stepIndex;
  final int currentStep;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final isActive = stepIndex == currentStep;
    final isCompleted = stepIndex < currentStep;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isActive
                ? tk.clientSoft
                : isCompleted
                    ? tk.successSoft
                    : tk.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? tk.clientAccent
                  : isCompleted
                      ? tk.success
                      : tk.border,
              width: isActive ? 1.6 : 1.0,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: isActive
                  ? tk.clientAccent
                  : isCompleted
                      ? tk.successInk
                      : tk.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

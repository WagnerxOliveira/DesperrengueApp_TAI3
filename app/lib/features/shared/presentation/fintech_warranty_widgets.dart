import 'package:flutter/material.dart';

import '../../../core/models/fintech_warranty_models.dart';
import '../../../core/services/desperrengue_official_pdf_service.dart';
import '../../../core/state/anti_bypass_fintech_controller.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/utils/format.dart';
import 'live_location_map.dart';

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
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: valueColor ?? tk.text,
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

/// Visão compacta e tela completa do Passaporte de Manutenção do Imóvel ("Prontuário da Casa").
class PropertyPassportView extends StatelessWidget {
  const PropertyPassportView({
    super.key,
    required this.passport,
    this.compact = false,
  });

  final PropertyMaintenancePassport passport;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
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
                      'Score de Vistoria: ${passport.inspectionReadinessScore}/100 • ${passport.activeWarrantiesCount} garantia(s) ativa(s)',
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
          const SizedBox(height: 12),
          if (passport.propertyAddress.trim().isNotEmpty) ...[
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => LiveLocationMapSheet.show(
                context,
                addressLine: passport.propertyAddress,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tk.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tk.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.place_rounded, size: 18, color: tk.clientAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            passport.propertyAddress,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: tk.text),
                          ),
                          Text(
                            'Toque para ver o endereço no mapa',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tk.clientAccent),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.map_outlined, size: 18, color: tk.clientAccent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
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
          for (final entry in (compact ? passport.entries.take(2) : passport.entries))
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tk.surface,
                borderRadius: BorderRadius.circular(12),
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    brl(entry.totalInvested),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: tk.text,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
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

/// Tela dedicada para o Passaporte de Manutenção do Imóvel ("Prontuário da Casa") acessível pelo Perfil do Cliente.
class PropertyPassportScreen extends StatelessWidget {
  const PropertyPassportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppScaffold(
      appBar: AppBar(title: const Text('Prontuário da Casa')),
      body: ValueListenableBuilder(
        valueListenable: FintechLedgerStore.instance,
        builder: (context, _, _) {
          final passport = FintechLedgerStore.instance.state.propertyPassport;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Text(
                'Passaporte Oficial de Manutenção do Imóvel',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: tk.brand,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Histórico criptograficamente auditado do seu imóvel para valorização patrimonial, entrega de chaves em imobiliárias e comprovação preventiva para seguradoras.',
                style: TextStyle(color: tk.textMuted, height: 1.4),
              ),
              const SizedBox(height: 16),
              PropertyPassportView(passport: passport),
            ],
          );
        },
      ),
    );
  }
}

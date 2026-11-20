import 'package:flutter/material.dart';

import '../../../core/models/fintech_warranty_models.dart';
import '../../../core/security/zero_trust_bilateral_security_engine.dart';
import '../../../core/services/desperrengue_official_pdf_service.dart';
import '../../../core/state/anti_bypass_fintech_controller.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
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
    final accentInk = isProviderView ? tk.providerAccentInk : tk.clientAccentInk;
    final stackBoxes = context.layout.isLargeText;

    final walletA = _WalletMiniBox(
      title: 'Carteira A • Mão de Obra',
      amount: split.serviceLaborAmount,
      subtitle: '13,5% Op. + 1,5% Fundo Garantia',
      accentColor: accent,
      accentInk: accentInk,
    );
    final walletB = _WalletMiniBox(
      title: 'Carteira B • Peças (NFC-e)',
      amount: split.materialReimbursementAmount,
      subtitle: 'Reembolso 100% (Taxa Zero)',
      accentColor: tk.success,
      accentInk: tk.successInk,
    );

    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.account_balance_rounded, size: 20, color: accentInk),
              Text(
                'Split Inteligente Anti-Bypass (Escrow BaaS)',
                style: AppType.titleSm.copyWith(color: tk.text),
              ),
              const AppStatusChip(
                '0% DE TAXA SOBRE PEÇAS',
                tone: AppTone.success,
                icon: Icons.verified_user_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          // Carteira A vs Carteira B
          if (stackBoxes) ...[
            walletA,
            const SizedBox(height: AppSpace.s8),
            walletB,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: walletA),
                const SizedBox(width: AppSpace.s12),
                Expanded(child: walletB),
              ],
            ),
          const SizedBox(height: AppSpace.s12),
          AppCard(
            variant: AppCardVariant.tonal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s12,
              vertical: AppSpace.s8,
            ),
            radius: AppGeometry.fieldRadius,
            child: Column(
              children: [
                _SplitRow(
                  label: 'Total Bruto Protegido (M + P)',
                  value: brl(split.grossTransactionAmount),
                  bold: true,
                ),
                _SplitRow(
                  label: 'Caixa Operacional Plataforma (13,5% s/ M)',
                  value: brl(split.platformOperationalRevenue),
                ),
                _SplitRow(
                  label: 'Aporte Fundo de Reserva de Garantia (1,5% s/ M)',
                  value: brl(split.warrantyReserveContribution),
                  valueColor: tk.successInk,
                ),
                const Divider(height: AppSpace.s16),
                _SplitRow(
                  label: 'Repasse Líquido Total ao Prestador',
                  value: brl(split.providerTotalNetPayout),
                  bold: true,
                  valueColor: accentInk,
                ),
                _SplitRow(
                  label: 'Economia Real do Prestador (0% nas peças)',
                  value: '+ ${brl(split.providerSavedFeeBySmartSplit)}',
                  valueColor: tk.successInk,
                  bold: true,
                ),
                _SplitRow(
                  label: 'Teto Máx. Cobertura do Fundo (Cap 100% M)',
                  value: brl(split.maxWarrantyCoverageCap),
                ),
              ],
            ),
          ),
          if (dossier.reimbursedMaterials.isEmpty) ...[
            const SizedBox(height: AppSpace.s12),
            AppCard(
              key: const ValueKey('smart-split-empty-materials'),
              variant: AppCardVariant.tonal,
              borderColor: tk.border,
              padding: const EdgeInsets.all(AppSpace.s12),
              radius: AppGeometry.fieldRadius,
              child: Row(
                children: [
                  Icon(Icons.receipt_long_rounded, size: 20, color: tk.textMuted),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Text(
                      'Nenhuma nota de material registrada ainda',
                      style: AppType.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tk.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpace.s16),
            AppSection(
              title: 'Cupons Fiscais de Peças (Carteira B)',
              spacing: AppSpace.s8,
              child: Column(
                children: [
                  for (final item in dossier.reimbursedMaterials)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s8),
                      child: AppCard(
                        variant: AppCardVariant.tonal,
                        borderColor: item.isApprovedByClient
                            ? tk.success.withValues(alpha: 0.45)
                            : tk.border,
                        padding: const EdgeInsets.all(AppSpace.s12),
                        radius: AppGeometry.fieldRadius,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              item.isApprovedByClient
                                  ? Icons.verified_rounded
                                  : Icons.receipt_long_rounded,
                              size: 20,
                              color: item.isApprovedByClient
                                  ? tk.successInk
                                  : tk.textMuted,
                            ),
                            const SizedBox(width: AppSpace.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.materialDescription,
                                    style: AppType.bodyStrong.copyWith(color: tk.text),
                                  ),
                                  Text(
                                    '${item.storeName} • ${item.fiscalReceiptNumber}',
                                    style: AppType.caption.copyWith(color: tk.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpace.s8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                AppPrice(
                                  value: item.receiptTotalAmount,
                                  size: AppPriceSize.sm,
                                  color: tk.text,
                                ),
                                if (onToggleMaterialApproval != null) ...[
                                  const SizedBox(height: AppSpace.s4),
                                  AppPressable(
                                    onTap: () => onToggleMaterialApproval!(item.id),
                                    borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                                    semanticLabel: item.isApprovedByClient
                                        ? 'Cupom aprovado'
                                        : 'Aprovar cupom',
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: AppGeometry.minTarget,
                                        minWidth: AppGeometry.minTarget,
                                      ),
                                      child: Center(
                                        child: item.isApprovedByClient
                                            ? const AppStatusChip(
                                                'Aprovado',
                                                tone: AppTone.success,
                                                icon: Icons.check_rounded,
                                              )
                                            : AppStatusChip(
                                                'Aprovar cupom',
                                                tone: AppTone.accent,
                                                color: accentInk,
                                                background: accent.withValues(alpha: 0.12),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (onAddMaterialReceipt != null) ...[
            const SizedBox(height: AppSpace.s8),
            AppButton(
              label: 'Anexar Cupom Fiscal de Peça (0% Taxa)',
              variant: AppButtonVariant.secondary,
              compact: true,
              icon: Icons.receipt_long_rounded,
              onPressed: onAddMaterialReceipt,
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
    required this.accentInk,
  });

  final String title;
  final double amount;
  final String subtitle;
  final Color accentColor;
  final Color accentInk;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      variant: AppCardVariant.outlined,
      color: accentColor.withValues(alpha: tk.isDark ? 0.16 : 0.08),
      borderColor: accentColor.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(AppSpace.s12),
      radius: AppGeometry.fieldRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            style: AppType.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: tk.textMuted,
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          AppPrice(
            value: amount,
            size: AppPriceSize.sm,
            color: tk.text,
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            subtitle,
            maxLines: 2,
            style: AppType.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: accentInk,
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
    final stack = context.layout.isLargeText;
    return AppInfoRow(
      label: label,
      strong: bold,
      valueWidget: Text(
        value,
        textAlign: stack ? TextAlign.start : TextAlign.end,
        style: AppType.tabular(bold ? AppType.bodyStrong : AppType.bodySm).copyWith(
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: valueColor ?? tk.text,
        ),
      ),
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
    final stackPills = context.layout.isLargeText;

    final checkInPill = _ForensicStagePill(
      title: 'Check-in (Antes)',
      countText: '$beforeCount/2+ fotos',
      completed: beforeCount >= 2,
      onAdd: onAddCheckInPhoto,
      buttonLabel: '+ Foto Antes',
    );
    final checkOutPill = _ForensicStagePill(
      title: 'Check-out (Depois)',
      countText: '$afterCount/2+ fotos',
      completed: afterCount >= 2,
      onAdd: onAddCheckOutPhoto,
      buttonLabel: '+ Foto Depois',
    );

    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: tk.infoSoft,
                child: Icon(Icons.verified_user_rounded, size: 20, color: tk.info),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auditoria Forense Antes/Depois & Garantia CDC',
                      style: AppType.titleSm.copyWith(color: tk.text),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    Text(
                      'Mínimo 2 fotos Antes + 2 fotos Depois com GPS e Hash SHA',
                      style: AppType.bodySm.copyWith(color: tk.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          if (stackPills) ...[
            checkInPill,
            const SizedBox(height: AppSpace.s8),
            checkOutPill,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: checkInPill),
                const SizedBox(width: AppSpace.s12),
                Expanded(child: checkOutPill),
              ],
            ),
          const SizedBox(height: AppSpace.s12),
          // Lista resumida de hashes forenses
          for (final p in [
            ...dossier.checkInBeforePhotos.take(2),
            ...dossier.checkOutAfterPhotos.take(2),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s2),
                    child: Icon(
                      p.isGpsVerifiedAtAddress
                          ? Icons.gps_fixed_rounded
                          : Icons.gps_not_fixed_rounded,
                      size: 16,
                      color: tk.successInk,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p.stage.label}: ${p.captionOrTechnicalNote}',
                          maxLines: 2,
                          style: AppType.bodySm.copyWith(color: tk.text),
                        ),
                        Text(
                          p.integrityHash.substring(0, 14),
                          style: AppType.tabular(AppType.caption).copyWith(
                            fontWeight: FontWeight.w600,
                            color: tk.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpace.s8),
          if (cert != null)
            AppCard(
              variant: AppCardVariant.outlined,
              color: tk.successSoft,
              borderColor: tk.success.withValues(alpha: 0.5),
              padding: const EdgeInsets.all(AppSpace.s12),
              radius: AppGeometry.fieldRadius,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.workspace_premium_rounded, color: tk.successInk),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(
                        child: Text(
                          'Certificado Emitido: ${cert.certificateCode}',
                          style: AppType.titleSm.copyWith(color: tk.successInk),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    'Vigência Legal: ${cert.warrantyDurationDays} dias (${cert.remainingDays} restantes) • Titular LGPD: ${cert.maskedClientName}',
                    style: AppType.bodySm.copyWith(color: tk.successInk),
                  ),
                  const SizedBox(height: AppSpace.s12),
                  AppButton(
                    label: 'Abrir Certificado Digital em PDF',
                    icon: Icons.picture_as_pdf_rounded,
                    compact: true,
                    onPressed: () => const DesperrengueOfficialPdfService()
                        .showCertificatePreviewDialog(context, cert),
                  ),
                ],
              ),
            )
          else
            AppCard(
              variant: AppCardVariant.tonal,
              padding: const EdgeInsets.all(AppSpace.s12),
              radius: AppGeometry.fieldRadius,
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 20, color: tk.textMuted),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Text(
                      'Conclua as 2 fotos de Check-out ("Depois") para emitir automaticamente o Certificado Digital de Garantia em PDF.',
                      style: AppType.bodySm.copyWith(color: tk.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          if (onOpenThreeLayerWarranty != null) ...[
            const SizedBox(height: AppSpace.s12),
            AppButton(
              label: 'Central de Garantia em 3 Camadas (CDC + Fundo 1,5%)',
              variant: AppButtonVariant.secondary,
              compact: true,
              icon: Icons.shield_rounded,
              onPressed: onOpenThreeLayerWarranty,
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
    final color = completed ? tk.successInk : tk.warningInk;
    return AppCard(
      variant: AppCardVariant.outlined,
      color: completed ? tk.successSoft : tk.surface,
      borderColor: completed ? tk.success.withValues(alpha: 0.45) : tk.border,
      padding: const EdgeInsets.all(AppSpace.s12),
      radius: AppGeometry.fieldRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                completed ? Icons.check_circle_rounded : Icons.camera_alt_outlined,
                size: 18,
                color: color,
              ),
              const SizedBox(width: AppSpace.s4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  style: AppType.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tk.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            countText,
            style: AppType.tabular(AppType.bodyStrong).copyWith(
              color: completed ? tk.successInk : tk.textMuted,
            ),
          ),
          if (onAdd != null) ...[
            const SizedBox(height: AppSpace.s4),
            AppButton(
              label: buttonLabel,
              variant: AppButtonVariant.tertiary,
              compact: true,
              onPressed: onAdd,
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
    this.embeddedInSheet = false,
  });

  final String orderId;
  final bool embeddedInSheet;

  static Future<void> show(BuildContext context, {required String orderId}) {
    return AppSheet.show<void>(
      context,
      title: 'Garantia Blindada em 3 Camadas',
      maxHeightFactor: 0.88,
      builder: (_) => WarrantyThreeLayerResolutionSheet(
        orderId: orderId,
        embeddedInSheet: true,
      ),
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

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: tk.securitySoft,
              child: Icon(Icons.shield_rounded, color: tk.security),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.embeddedInSheet)
                    Text(
                      'Garantia Blindada em 3 Camadas',
                      style: AppType.title.copyWith(color: tk.text),
                    ),
                  Text(
                    'Fundo de Reserva 1,5% Ativo: ${brl(global.reserveFundBalance)} • Cap Pedido: ${brl(split.maxWarrantyCoverageCap)}',
                    style: AppType.tabular(AppType.bodySm).copyWith(
                      fontWeight: FontWeight.w600,
                      color: tk.successInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s12),
        if (activeClaim != null) ...[
          AppCard(
            variant: AppCardVariant.outlined,
            color: tk.warningSoft,
            borderColor: tk.warningInk.withValues(alpha: 0.45),
            padding: const EdgeInsets.all(AppSpace.s12),
            radius: AppGeometry.fieldRadius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Atual: ${activeClaim.status.label}',
                  style: AppType.titleSm.copyWith(color: tk.warningInk),
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  activeClaim.auditTrailNote,
                  style: AppType.bodySm.copyWith(color: tk.text),
                ),
                if (activeClaim.clawbackDebitedFromOffender > 0) ...[
                  const SizedBox(height: AppSpace.s8),
                  Text(
                    'Clawback lançado no prestador infrator: ${brl(offenderClawback)}',
                    style: AppType.tabular(AppType.bodySm).copyWith(
                      fontWeight: FontWeight.w700,
                      color: tk.dangerInk,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s12),
        ],
        for (final layer in WarrantyResolutionLayer.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s12),
            child: AppCard(
              variant: AppCardVariant.outlined,
              color: activeClaim?.currentLayer == layer ? tk.infoSoft : tk.surface,
              borderColor:
                  activeClaim?.currentLayer == layer ? tk.info : tk.border,
              padding: const EdgeInsets.all(AppSpace.s16),
              radius: AppGeometry.itemRadius,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppStatusChip(
                    layer.shortBadge,
                    tone: activeClaim?.currentLayer == layer
                        ? AppTone.info
                        : AppTone.neutral,
                  ),
                  const SizedBox(height: AppSpace.s8),
                  Text(
                    layer.title,
                    style: AppType.titleSm.copyWith(color: tk.text),
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    layer.description,
                    style: AppType.bodySm.copyWith(color: tk.textMuted),
                  ),
                  const SizedBox(height: AppSpace.s12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton(
                      label: activeClaim?.currentLayer == layer
                          ? 'Camada Ativa'
                          : 'Acionar ${layer.shortBadge.split('•').first.trim()}',
                      variant: activeClaim?.currentLayer == layer
                          ? AppButtonVariant.primary
                          : AppButtonVariant.secondary,
                      compact: true,
                      expand: false,
                      icon: activeClaim?.currentLayer == layer
                          ? Icons.check_circle_rounded
                          : Icons.play_arrow_rounded,
                      onPressed: () => _triggerLayer(layer),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    if (widget.embeddedInSheet) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s12),
        child: content,
      );
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s20,
            AppSpace.s4,
            AppSpace.s20,
            AppSpace.s24,
          ),
          child: content,
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
      AppRoute<void>(
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
    final stackBoxes = context.layout.isLargeText;

    final totalBox = _WalletMiniBox(
      title: 'Total Investido',
      amount: passport.totalInvestedAmount,
      subtitle: '${passport.entries.length} serviços auditados',
      accentColor: tk.clientAccent,
      accentInk: tk.clientAccentInk,
    );
    final materialsBox = _WalletMiniBox(
      title: 'Peças c/ Nota (0%)',
      amount: passport.totalMaterialsInvested,
      subtitle: 'Mão de obra: ${brl(passport.totalLaborInvested)}',
      accentColor: tk.info,
      accentInk: tk.isDark ? tk.info : tk.providerAccentInk,
    );

    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: tk.clientSoft,
                child: Icon(Icons.home_work_rounded, color: tk.clientAccentInk),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prontuário da Casa (Passaporte do Imóvel)',
                      style: AppType.titleSm.copyWith(color: tk.text),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    Text(
                      'Score de Vistoria: $score/100 • ${passport.activeWarrantiesCount} garantia(s) ativa(s)',
                      style: AppType.tabular(AppType.bodySm).copyWith(
                        fontWeight: FontWeight.w600,
                        color: score >= 60 ? tk.successInk : tk.clientAccentInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          AppCard(
            variant: AppCardVariant.tonal,
            borderColor: tk.border,
            padding: const EdgeInsets.all(AppSpace.s12),
            radius: AppGeometry.fieldRadius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasAddress ? Icons.verified_rounded : Icons.home_outlined,
                      size: 18,
                      color: hasAddress ? tk.successInk : tk.clientAccentInk,
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text(
                        hasAddress
                            ? '${passport.propertyNickname} • ${passport.propertyType}'
                            : 'Imóvel aguardando configuração inicial pelo proprietário',
                        style: AppType.bodyStrong.copyWith(color: tk.text),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  hasAddress
                      ? passport.propertyAddress
                      : 'Configure os dados reais do seu imóvel na Etapa 1 para vincular o endereço e os sistemas prediais auditados (ABNT NBR 5674).',
                  style: AppType.bodySm.copyWith(
                    color: hasAddress ? tk.text : tk.textMuted,
                  ),
                ),
                if (passport.isConfiguredByClient || passport.inspectedSystems.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s8),
                  Text(
                    'Finalidade: ${passport.passportPurpose} • ${passport.inspectedSystems.length} sistema(s) ABNT verificado(s)',
                    style: AppType.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tk.clientAccentInk,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          if (stackBoxes) ...[
            totalBox,
            const SizedBox(height: AppSpace.s8),
            materialsBox,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: totalBox),
                const SizedBox(width: AppSpace.s12),
                Expanded(child: materialsBox),
              ],
            ),
          const SizedBox(height: AppSpace.s12),
          if (!hasEntries)
            AppCard(
              variant: AppCardVariant.tonal,
              borderColor: tk.border,
              padding: const EdgeInsets.all(AppSpace.s16),
              radius: AppGeometry.fieldRadius,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: tk.clientAccentInk),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(
                        child: Text(
                          '100% Baseado nos Seus Dados Reais (Zero Dados Fictícios)',
                          style: AppType.bodyStrong.copyWith(color: tk.text),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s8),
                  Text(
                    'O Passaporte do seu imóvel inicia zerado (R\$ 0,00). Ele é preenchido exclusivamente quando você registra uma manutenção real realizada no imóvel ou quando finaliza um serviço pelo aplicativo com o seu PIN de segurança.',
                    style: AppType.bodySm.copyWith(color: tk.textMuted),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: AppSpace.s12),
                    AppButton(
                      label: 'Configurar Imóvel e Registrar 1ª Manutenção Real',
                      variant: AppButtonVariant.secondary,
                      compact: true,
                      icon: Icons.add_home_work_rounded,
                      onPressed: () => _openWizard(context, initialStep: 0),
                    ),
                  ],
                ],
              ),
            )
          else
            for (final entry in (compact ? passport.entries.take(2) : passport.entries))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s8),
                child: AppCard(
                  variant: AppCardVariant.tonal,
                  borderColor: tk.border,
                  padding: const EdgeInsets.all(AppSpace.s12),
                  radius: AppGeometry.fieldRadius,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.s2),
                        child: Icon(
                          entry.isWarrantyActive
                              ? Icons.verified_rounded
                              : Icons.history_rounded,
                          size: 18,
                          color: entry.isWarrantyActive ? tk.successInk : tk.textMuted,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.serviceCategoryName} • ${entry.serviceTitle}',
                              style: AppType.bodyStrong.copyWith(color: tk.text),
                            ),
                            const SizedBox(height: AppSpace.s2),
                            Text(
                              '${entry.providerName} • Cert: ${entry.certificateCode}',
                              style: AppType.caption.copyWith(color: tk.textMuted),
                            ),
                            const SizedBox(height: AppSpace.s2),
                            Text(
                              'Mão de Obra: ${brl(entry.laborAmount)} • Peças: ${brl(entry.materialAmount)}',
                              style: AppType.tabular(AppType.caption).copyWith(
                                fontWeight: FontWeight.w600,
                                color: tk.clientAccentInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpace.s8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AppPrice(
                            value: entry.totalInvested,
                            size: AppPriceSize.sm,
                            color: tk.text,
                          ),
                          if (!compact && entry.id.startsWith('pm-client-'))
                            AppPressable(
                              onTap: () => FintechLedgerStore.instance
                                  .removeClientMaintenanceEntry(entry.id),
                              borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
                              semanticLabel: 'Remover registro de manutenção',
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: AppGeometry.minTarget,
                                  minHeight: AppGeometry.minTarget,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'Remover',
                                    style: AppType.caption.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: tk.dangerInk,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: AppSpace.s12),
          AppButton(
            label: 'Exportar Prontuário da Casa em PDF (Vistoria/Seguradora)',
            icon: Icons.picture_as_pdf_rounded,
            compact: true,
            onPressed: () => const DesperrengueOfficialPdfService()
                .showPassportPreviewDialog(context, passport),
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
      AppRoute<void>(
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
    final reduced = AppMotion.reduced(context);
    final margin = context.layout.margin;

    return AppScaffold(
      appBar: const AppAppBar(title: 'Prontuário da Casa'),
      body: ValueListenableBuilder(
        valueListenable: FintechLedgerStore.instance,
        builder: (context, _, _) {
          final passport = FintechLedgerStore.instance.state.propertyPassport;
          final list = ListView(
            padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s32),
            children: [
              // 1. Banner Hero com Selo ABNT NBR 5674
              AppCard(
                variant: AppCardVariant.hero,
                borderColor: tk.clientAccent.withValues(alpha: 0.45),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppStatusChip(
                      'PADRÃO ABNT NBR 5674 • LEI DO INQUILINATO 8.245/91',
                      tone: AppTone.accent,
                      icon: Icons.verified_user_rounded,
                      color: tk.clientAccentInk,
                      background: tk.clientSoft,
                    ),
                    const SizedBox(height: AppSpace.s12),
                    Text(
                      'Passaporte Oficial de Manutenção do Imóvel',
                      style: AppType.headline.copyWith(color: tk.text),
                    ),
                    const SizedBox(height: AppSpace.s8),
                    Text(
                      'Documento técnico auditado com os dados e valores reais informados por você ou gerados nos seus pedidos concluídos via PIN.',
                      style: AppType.bodySm.copyWith(color: tk.textMuted),
                    ),
                    const SizedBox(height: AppSpace.s16),
                    AppButton(
                      label: passport.isConfiguredByClient
                          ? 'Gerenciar Imóvel ou Registrar Nova Manutenção'
                          : 'Iniciar Configuração do Passaporte (3 Passos)',
                      icon: Icons.rocket_launch_rounded,
                      onPressed: () => _openWizard(initialStep: 0),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s16),

              // 2. Explicação Executiva: Qual a utilidade prática para o cliente?
              AppCard(
                variant: AppCardVariant.outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_rounded, size: 20, color: tk.clientAccentInk),
                        const SizedBox(width: AppSpace.s8),
                        Expanded(
                          child: Text(
                            'Para que serve o Passaporte do Imóvel?',
                            style: AppType.titleSm.copyWith(color: tk.text),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s12),
                    const _PassportBenefitRow(
                      icon: Icons.key_rounded,
                      title: '1. Vistoria de Imobiliária e Entrega de Chaves',
                      description:
                          'Comprova revisões elétricas, hidráulicas e pintura feitas por você (Lei 8.245/91), evitando cobranças indevidas na saída do imóvel.',
                    ),
                    const SizedBox(height: AppSpace.s12),
                    const _PassportBenefitRow(
                      icon: Icons.health_and_safety_rounded,
                      title: '2. Comprovação Preventiva para Seguradoras',
                      description:
                          'Atesta a manutenção preventiva exigida pela norma ABNT NBR 5674 (Quadro DR/DPS, telhado, tubulações) para proteção de cobertura.',
                    ),
                    const SizedBox(height: AppSpace.s12),
                    const _PassportBenefitRow(
                      icon: Icons.trending_up_rounded,
                      title: '3. Valorização Patrimonial e Garantias CDC',
                      description:
                          'Organiza o histórico real investido em mão de obra e peças com nota (0% taxa), preservando garantias legais (Art. 20 e 26 do CDC).',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s16),

              // 3. O que o Usuário Cliente precisa fazer (Passo a Passo Interativo)
              AppCard(
                variant: AppCardVariant.outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist_rtl_rounded, size: 20, color: tk.info),
                        const SizedBox(width: AppSpace.s8),
                        Expanded(
                          child: Text(
                            'Como funciona (O que você precisa fazer)',
                            style: AppType.titleSm.copyWith(color: tk.text),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s12),
                    _PassportActionStepTile(
                      stepNumber: '1',
                      title: 'Identificar e Vistoriar seu Imóvel',
                      subtitle:
                          'Confirme seu endereço real, o tipo de imóvel, a finalidade e assinale os sistemas prediais verificados.',
                      isDone: passport.isConfiguredByClient,
                      buttonLabel: 'Abrir Etapa 1',
                      onTap: () => _openWizard(initialStep: 0),
                    ),
                    const SizedBox(height: AppSpace.s8),
                    _PassportActionStepTile(
                      stepNumber: '2',
                      title: 'Registrar Manutenções e Valores Reais',
                      subtitle:
                          'Insira os serviços realizados com os valores exatos pagos por você (ou conclua chamados pelo app via PIN).',
                      isDone: passport.entries.isNotEmpty,
                      buttonLabel: 'Abrir Etapa 2',
                      onTap: () => _openWizard(initialStep: 1),
                    ),
                    const SizedBox(height: AppSpace.s8),
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
              const SizedBox(height: AppSpace.s16),

              // 4. Painel em Tempo Real do Passaporte do Imóvel
              PropertyPassportView(
                passport: passport,
                onOpenWizardStep: (step) => _openWizard(initialStep: step),
              ),
            ],
          );

          if (reduced) return list;
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: AppMotion.page,
            curve: AppMotion.pageCurve,
            builder: (context, animValue, child) {
              return Opacity(
                opacity: animValue.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1.0 - animValue) * AppMotion.pageOffset),
                  child: child,
                ),
              );
            },
            child: list,
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
          width: AppGeometry.iconTileSize,
          height: AppGeometry.iconTileSize,
          decoration: BoxDecoration(
            color: tk.surface,
            borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
          ),
          child: Icon(icon, size: 20, color: tk.clientAccentInk),
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppType.bodyStrong.copyWith(color: tk.text),
              ),
              const SizedBox(height: AppSpace.s2),
              Text(
                description,
                style: AppType.bodySm.copyWith(color: tk.textMuted),
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
    final badgeBg = isDone ? tk.success : tk.clientAccent;
    final badgeFg = AppTokens.onColor(badgeBg);
    return AppCard(
      variant: AppCardVariant.outlined,
      color: isDone ? tk.successSoft : tk.surface,
      borderColor: isDone ? tk.success.withValues(alpha: 0.45) : tk.border,
      padding: const EdgeInsets.all(AppSpace.s12),
      radius: AppGeometry.fieldRadius,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: badgeBg,
            child: isDone
                ? Icon(Icons.check_rounded, size: 18, color: badgeFg)
                : Text(
                    stepNumber,
                    style: AppType.tabular(AppType.caption).copyWith(
                      fontWeight: FontWeight.w700,
                      color: badgeFg,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppType.bodyStrong.copyWith(color: tk.text),
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  subtitle,
                  style: AppType.bodySm.copyWith(color: tk.textMuted),
                ),
                const SizedBox(height: AppSpace.s8),
                Text(
                  buttonLabel,
                  style: AppType.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDone ? tk.successInk : tk.clientAccentInk,
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
    final margin = context.layout.margin;
    return AppScaffold(
      appBar: AppAppBar(
        title: _currentStep == 0
            ? 'Etapa 1 de 3 • Identificar Imóvel'
            : _currentStep == 1
                ? 'Etapa 2 de 3 • Registrar Manutenção'
                : 'Etapa 3 de 3 • Passaporte Homologado',
      ),
      body: ValueListenableBuilder(
        valueListenable: FintechLedgerStore.instance,
        builder: (context, _, _) {
          final passport = FintechLedgerStore.instance.state.propertyPassport;
          return ListView(
            padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s32),
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
                  const SizedBox(width: AppSpace.s8),
                  _WizardProgressPill(
                    stepIndex: 1,
                    currentStep: _currentStep,
                    label: '2. Serviço Real',
                    onTap: () => setState(() {
                      _stepError = null;
                      _currentStep = 1;
                    }),
                  ),
                  const SizedBox(width: AppSpace.s8),
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
              const SizedBox(height: AppSpace.s16),
              if (_stepError != null) ...[
                AppCard(
                  variant: AppCardVariant.outlined,
                  color: tk.warningSoft,
                  borderColor: tk.warningInk.withValues(alpha: 0.45),
                  padding: const EdgeInsets.all(AppSpace.s12),
                  radius: AppGeometry.fieldRadius,
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: tk.warningInk),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(
                        child: Text(
                          _stepError!,
                          style: AppType.bodySm.copyWith(
                            fontWeight: FontWeight.w600,
                            color: tk.warningInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s12),
              ],
              AnimatedSwitcher(
                duration: AppMotion.d(context, AppMotion.page),
                switchInCurve: AppMotion.pageCurve,
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
    return AppCard(
      key: const ValueKey<String>('passport-step-1'),
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Etapa 1: Identificação e Vistoria do Imóvel',
            style: AppType.title.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            'Confirme os dados reais do seu imóvel e marque os sistemas prediais que já passaram por verificação preventiva (ABNT NBR 5674).',
            style: AppType.bodySm.copyWith(color: tk.textMuted),
          ),
          const SizedBox(height: AppSpace.s16),
          AppTextField(
            controller: _nicknameCtrl,
            label: 'Imóvel',
            hint: 'Casa ou apê',
            helper: 'Identificação (ex.: Residência Principal, Apto Centro)',
            prefixIcon: Icons.home_work_outlined,
          ),
          const SizedBox(height: AppSpace.s12),
          AppTextField(
            controller: _ownerCtrl,
            label: 'Responsável',
            hint: 'Seu nome',
            helper: 'Proprietário ou locatário responsável',
            prefixIcon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: AppSpace.s12),
          AppTextField(
            controller: _addressCtrl,
            label: 'Endereço',
            hint: 'Rua e número',
            helper: 'Rua, número, bairro e cidade do imóvel',
            prefixIcon: Icons.place_outlined,
          ),
          const SizedBox(height: AppSpace.s16),
          Text(
            'Tipo do Imóvel',
            style: AppType.bodyStrong.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s8),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
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
          const SizedBox(height: AppSpace.s16),
          Text(
            'Finalidade Principal do Passaporte',
            style: AppType.bodyStrong.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s8),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
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
          const SizedBox(height: AppSpace.s16),
          Text(
            'Checklist de Sistemas Prediais Verificados (ABNT NBR 5674)',
            style: AppType.bodyStrong.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            'Cada sistema verificado eleva o Score de Vistoria Técnica do imóvel.',
            style: AppType.caption.copyWith(color: tk.textMuted),
          ),
          const SizedBox(height: AppSpace.s8),
          for (final system in _abntSystems)
            AppPressable(
              borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
              onTap: () {
                setState(() {
                  if (_selectedSystems.contains(system)) {
                    _selectedSystems.remove(system);
                  } else {
                    _selectedSystems.add(system);
                  }
                });
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppGeometry.minTarget),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _selectedSystems.contains(system),
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
                      const SizedBox(width: AppSpace.s4),
                      Expanded(
                        child: Text(
                          system,
                          style: AppType.bodySm.copyWith(
                            fontWeight: FontWeight.w600,
                            color: tk.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpace.s16),
          AppButton(
            label: 'Salvar Imóvel e Avançar para Etapa 2',
            trailingArrow: true,
            onPressed: () => _saveStep1Configuration(advanceToStep2: true),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2MaintenanceForm(BuildContext context, AppTokens tk) {
    final suggestions =
        _categoryQuickSuggestions[_selectedCategory] ?? const <String>[];
    final stackMoney = context.layout.isLargeText;

    final laborField = AppTextField(
      controller: _laborAmountCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      label: 'Mão de Obra (R\$)',
      hint: 'Ex.: 180,00',
      prefixIcon: Icons.payments_outlined,
    );
    final materialField = AppTextField(
      controller: _materialAmountCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      label: 'Peças c/ Nota (R\$)',
      hint: 'Ex.: 95,00',
      prefixIcon: Icons.receipt_long_outlined,
    );

    return AppCard(
      key: const ValueKey<String>('passport-step-2'),
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Etapa 2: Registrar Manutenção Realizada no Imóvel',
            style: AppType.title.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            'Informe os valores reais pagos por você na manutenção. O sistema gera o Certificado com Hash SHA-256 e atualiza o Total Investido do imóvel.',
            style: AppType.bodySm.copyWith(color: tk.textMuted),
          ),
          const SizedBox(height: AppSpace.s16),
          Text(
            'Categoria do Serviço Realizado',
            style: AppType.bodyStrong.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s8),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
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
            const SizedBox(height: AppSpace.s12),
            Text(
              'Sugestões rápidas de preenchimento (toque se desejar):',
              style: AppType.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: tk.textMuted,
              ),
            ),
            const SizedBox(height: AppSpace.s8),
            for (final suggestion in suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s8),
                child: AppCard(
                  variant: AppCardVariant.tonal,
                  borderColor: tk.border,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s12,
                    vertical: AppSpace.s12,
                  ),
                  radius: AppGeometry.iconTileRadius,
                  onTap: () {
                    setState(() {
                      _serviceTitleCtrl.text = suggestion;
                    });
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_fix_high_rounded,
                        size: 18,
                        color: tk.clientAccentInk,
                      ),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(
                        child: Text(
                          suggestion,
                          style: AppType.bodySm.copyWith(
                            fontWeight: FontWeight.w600,
                            color: tk.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: AppSpace.s12),
          AppTextField(
            controller: _serviceTitleCtrl,
            label: 'Descrição do Serviço Realizado',
            hint: 'Ex.: Substituição de Disjuntor DR e revisão do quadro',
            prefixIcon: Icons.build_circle_outlined,
          ),
          const SizedBox(height: AppSpace.s12),
          AppTextField(
            controller: _providerNameCtrl,
            label: 'Profissional ou Empresa Executora',
            hint: 'Nome do técnico ou empresa contratada',
            prefixIcon: Icons.engineering_outlined,
          ),
          const SizedBox(height: AppSpace.s12),
          if (stackMoney) ...[
            laborField,
            const SizedBox(height: AppSpace.s12),
            materialField,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: laborField),
                const SizedBox(width: AppSpace.s12),
                Expanded(child: materialField),
              ],
            ),
          const SizedBox(height: AppSpace.s12),
          AppCard(
            variant: AppCardVariant.tonal,
            borderColor: tk.border,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s12,
              vertical: AppSpace.s4,
            ),
            radius: AppGeometry.fieldRadius,
            child: AppInfoRow(
              label: 'Total Real desta Manutenção:',
              strong: true,
              valueWidget: AppPrice(
                value: _previewTotalAmount,
                size: AppPriceSize.sm,
                color: tk.clientAccentInk,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          Text(
            'Prazo de Garantia do Serviço',
            style: AppType.bodyStrong.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s8),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
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
          const SizedBox(height: AppSpace.s16),
          AppButton(
            label: 'Homologar Registro Real e Concluir Passaporte',
            icon: Icons.verified_rounded,
            onPressed: _submitStep2MaintenanceEntry,
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
    final reduced = AppMotion.reduced(context);

    final badgeHeader = AppCard(
      variant: AppCardVariant.tonal,
      color: tk.successSoft,
      padding: const EdgeInsets.all(AppSpace.s16),
      radius: AppGeometry.itemRadius,
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: tk.success,
            child: Icon(
              Icons.workspace_premium_rounded,
              color: AppTokens.onColor(tk.success),
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Passaporte Oficial Homologado!',
                  style: AppType.titleSm.copyWith(color: tk.successInk),
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  'ID: ${passport.passportId} • Score Atualizado: ${passport.inspectionReadinessScore}/100',
                  style: AppType.tabular(AppType.caption).copyWith(
                    fontWeight: FontWeight.w700,
                    color: tk.successInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return AppCard(
      key: const ValueKey<String>('passport-step-3'),
      variant: AppCardVariant.outlined,
      borderColor: tk.success.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reduced)
            badgeHeader
          else
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.92, end: 1.0),
              duration: AppMotion.success,
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: badgeHeader,
            ),
          const SizedBox(height: AppSpace.s16),
          Text(
            'Resumo Oficial Auditado do Seu Imóvel',
            style: AppType.titleSm.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s8),
          _SplitRow(
            label: 'Imóvel / Tipo',
            value: '${passport.propertyNickname} (${passport.propertyType})',
            bold: true,
          ),
          _SplitRow(
            label: 'Finalidade Oficial',
            value: passport.passportPurpose,
          ),
          _SplitRow(
            label: 'Total Real Investido',
            value: brl(passport.totalInvestedAmount),
            bold: true,
            valueColor: tk.clientAccentInk,
          ),
          _SplitRow(
            label: 'Mão de Obra / Peças c/ Nota',
            value:
                '${brl(passport.totalLaborInvested)} / ${brl(passport.totalMaterialsInvested)}',
          ),
          _SplitRow(
            label: 'Intervenções / Garantias Ativas',
            value:
                '${passport.entries.length} registro(s) • ${passport.activeWarrantiesCount} garantia(s)',
          ),
          if (latestEntry != null) ...[
            const SizedBox(height: AppSpace.s12),
            AppCard(
              variant: AppCardVariant.tonal,
              borderColor: tk.border,
              padding: const EdgeInsets.all(AppSpace.s12),
              radius: AppGeometry.fieldRadius,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Último Certificado Emitido: ${latestEntry.certificateCode}',
                    style: AppType.bodyStrong.copyWith(color: tk.text),
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    '${latestEntry.serviceCategoryName} • ${latestEntry.serviceTitle}',
                    style: AppType.bodySm.copyWith(color: tk.text),
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    'Hash Forense SHA-256: ${latestEntry.forensicHash}',
                    style: AppType.tabular(AppType.caption).copyWith(
                      fontWeight: FontWeight.w600,
                      color: tk.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpace.s16),
          AppButton(
            label: 'Visualizar e Exportar Passaporte Oficial em PDF',
            icon: Icons.picture_as_pdf_rounded,
            onPressed: () => const DesperrengueOfficialPdfService()
                .showPassportPreviewDialog(context, passport),
          ),
          const SizedBox(height: AppSpace.s8),
          AppButton(
            label: 'Registrar Outra Manutenção Real',
            variant: AppButtonVariant.secondary,
            icon: Icons.add_circle_outline_rounded,
            onPressed: _resetStep2ForNewEntry,
          ),
          const SizedBox(height: AppSpace.s8),
          AppButton(
            label: 'Concluir e Voltar ao Prontuário da Casa',
            variant: AppButtonVariant.tertiary,
            icon: Icons.check_circle_outline_rounded,
            onPressed: () => Navigator.of(context).pop(),
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
      child: AppPressable(
        borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppGeometry.minTarget),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpace.s8,
              horizontal: AppSpace.s8,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? tk.clientSoft
                  : isCompleted
                      ? tk.successSoft
                      : tk.card,
              borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
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
              maxLines: 2,
              style: AppType.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: isActive
                    ? tk.clientAccentInk
                    : isCompleted
                        ? tk.successInk
                        : tk.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ============================================================================
// COMPONENTES DE GOVERNANÇA DE GARANTIA EM 3 CAMADAS, MEDIAÇÃO E MARCO ZERO
// (PDF 1, PDF 2 E PDF 3)
// ============================================================================

/// Stepper Vertical Interativo das 5 Fases da Mediação e Acionamento da Garantia (`PDF 1 Seção 6` e `PDF 2 Seção 5.1`),
/// incluindo o Card de Bloqueio de Seleção Manual (`RN-AF-01`).
class MediationFivePhaseTimeline extends StatelessWidget {
  const MediationFivePhaseTimeline({
    super.key,
    this.currentPhaseIndex = 2,
    this.originalLaborCap = 280.0,
    this.onRequestAdditionalScopeSplit,
  });

  /// Índice de 0 a 4 representando a fase atual da máquina de estados.
  final int currentPhaseIndex;
  final double originalLaborCap;
  final VoidCallback? onRequestAdditionalScopeSplit;

  static const List<({String code, String title, String subtitle})> phases = [
    (
      code: 'PHASE_1_OPENED_AND_FROZEN',
      title: 'Fase 1: Abertura e Congelamento Preventivo (Circuit Breaker)',
      subtitle:
          'O repasse em maturação (D+5) é congelado instantaneamente para proteger o saldo da garantia.',
    ),
    (
      code: 'PHASE_2_FORENSIC_TRIAGE',
      title: 'Fase 2: Triagem Forense Automatizada (GPS + pHash 64-bit)',
      subtitle:
          'Conferência criptográfica das fotos de Antes, Depois e Evidência do Defeito no imóvel.',
    ),
    (
      code: 'PHASE_3_ORIGINAL_PROVIDER_SLA_6H',
      title: 'Fase 3: Direito de Reparo pelo Prestador Original (SLA 6h)',
      subtitle:
          'O profissional original possui 6 horas para agendar o retorno técnico sem custo adicional.',
    ),
    (
      code: 'PHASE_4_WARRANTY_FUND_RESCUE_DISPATCH',
      title: 'Fase 4: Despacho Cego de Resgate (Fundo de Garantia Camada 3)',
      subtitle:
          'Alocação algorítmica em cascata (5 Níveis + Grafo Zero-Link) coberta até 100% da mão de obra.',
    ),
    (
      code: 'PHASE_5_SETTLED_AND_CERTIFIED',
      title: 'Fase 5: Liquidação Contábil, Clawback e Certificação',
      subtitle:
          'Baixa do Fundo de Garantia, compensação de Clawback e atualização do Prontuário da Casa.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      key: const ValueKey('mediation-five-phase-timeline'),
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel_rounded, color: tk.clientAccentInk),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  'Máquina de Estados da Mediação (5 Fases)',
                  style: AppType.titleSm.copyWith(color: tk.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          for (int i = 0; i < phases.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    i < currentPhaseIndex
                        ? Icons.check_circle_rounded
                        : (i == currentPhaseIndex
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded),
                    size: 20,
                    color: i <= currentPhaseIndex ? tk.successInk : tk.textMuted,
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          phases[i].title,
                          style: (i == currentPhaseIndex
                                  ? AppType.bodyStrong
                                  : AppType.bodySm)
                              .copyWith(
                            fontWeight: i == currentPhaseIndex
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: tk.text,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s2),
                        Text(
                          phases[i].subtitle,
                          style: AppType.bodySm.copyWith(color: tk.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: AppSpace.s20),
          // Card de Bloqueio de Seleção Manual (RN-AF-01)
          AppCard(
            key: const ValueKey('blind-dispatch-lock-card'),
            variant: AppCardVariant.tonal,
            borderColor: tk.border,
            padding: const EdgeInsets.all(AppSpace.s12),
            radius: AppGeometry.fieldRadius,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_person_rounded, color: tk.clientAccentInk, size: 20),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Text(
                    'Alocação Algorítmica Cega (RN-AF-01): Em chamados cobertos pelo Fundo de Garantia (Camada 3), o profissional socorrista é designado automaticamente pela plataforma entre especialistas verificados sem vínculo prévio (Teto: ${brl(originalLaborCap)}).',
                    style: AppType.bodySm.copyWith(color: tk.text),
                  ),
                ),
              ],
            ),
          ),
          if (onRequestAdditionalScopeSplit != null) ...[
            const SizedBox(height: AppSpace.s12),
            AppButton(
              key: const ValueKey('btn-open-additional-scope-split'),
              label: 'Incluir Serviço Adicional Fora do Escopo (Split)',
              variant: AppButtonVariant.secondary,
              compact: true,
              icon: Icons.call_split_rounded,
              onPressed: onRequestAdditionalScopeSplit,
            ),
          ],
        ],
      ),
    );
  }
}

/// Comparador Visual Lado a Lado (`ForensicSplitViewComparator` — `PDF 2 Seção 5.1` e `PDF 3 Seção 4.2`)
/// isolado em `RepaintBoundary` para manter 120 FPS constantes.
class ForensicSplitViewComparator extends StatelessWidget {
  const ForensicSplitViewComparator({
    super.key,
    required this.beforePhash64,
    required this.afterPhash64,
    this.defectPhash64,
    required this.hammingBeforeAfter,
    this.gpsDistanceMeters = 12.0,
  });

  final int beforePhash64;
  final int afterPhash64;
  final int? defectPhash64;
  final int hammingBeforeAfter;
  final double gpsDistanceMeters;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final bool integrityOk = hammingBeforeAfter >= 5 && gpsDistanceMeters <= 150.0;
    final stackFrames = context.layout.isLargeText;

    final beforeTile = _ForensicFrameTile(
      label: 'Check-in (Antes)',
      pHashHex: '0x${beforePhash64.toUnsigned(64).toRadixString(16).toUpperCase()}',
      icon: Icons.camera_front_rounded,
    );
    final afterTile = _ForensicFrameTile(
      label: 'Check-out (Depois)',
      pHashHex: '0x${afterPhash64.toUnsigned(64).toRadixString(16).toUpperCase()}',
      icon: Icons.camera_rear_rounded,
    );

    return RepaintBoundary(
      child: AppCard(
        key: const ValueKey('forensic-split-view-comparator'),
        variant: AppCardVariant.outlined,
        borderColor: integrityOk ? tk.success : tk.danger,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  integrityOk ? Icons.verified_rounded : Icons.warning_rounded,
                  color: integrityOk ? tk.successInk : tk.dangerInk,
                ),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: Text(
                    'Comparador Forense (Antes vs. Depois • pHash 64-bit)',
                    style: AppType.titleSm.copyWith(color: tk.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s12),
            if (stackFrames) ...[
              beforeTile,
              const SizedBox(height: AppSpace.s8),
              afterTile,
            ] else
              Row(
                children: [
                  Expanded(child: beforeTile),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(child: afterTile),
                ],
              ),
            const SizedBox(height: AppSpace.s12),
            Text(
              'Distância de Hamming: $hammingBeforeAfter bits (Mínimo exigido: >= 5) • Geofence GPS: ${gpsDistanceMeters.toStringAsFixed(1)}m (<= 150m)',
              style: AppType.tabular(AppType.bodySm).copyWith(
                fontWeight: FontWeight.w600,
                color: integrityOk ? tk.successInk : tk.dangerInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForensicFrameTile extends StatelessWidget {
  const _ForensicFrameTile({
    required this.label,
    required this.pHashHex,
    required this.icon,
  });

  final String label;
  final String pHashHex;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      variant: AppCardVariant.tonal,
      borderColor: tk.border,
      padding: const EdgeInsets.all(AppSpace.s12),
      radius: AppGeometry.fieldRadius,
      child: Column(
        children: [
          Icon(icon, size: 28, color: tk.clientAccentInk),
          const SizedBox(height: AppSpace.s8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppType.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: tk.text,
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            pHashHex,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: AppType.tabular(AppType.caption).copyWith(
              color: tk.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal de Conclusão por PIN de 4 Dígitos (`RN-AF-05`) e Contador Regressivo de 24h
/// de Liberação Automática (`RN-AF-04`) isolado via `ValueListenableBuilder<Duration>`.
class PinFourDigitApprovalCard extends StatefulWidget {
  const PinFourDigitApprovalCard({
    super.key,
    required this.initialRemaining,
    required this.onConfirmPin,
    this.materialScope = MaterialSplitScopeKind.none,
    this.applianceNameplateOcr,
    this.oldPartLeavePhotoPhash64,
    this.oldPartDisposalAuthorizedByClient = false,
    this.isCoPresenceVerified = true,
  });

  final Duration initialRemaining;
  final ValueChanged<String> onConfirmPin;
  final MaterialSplitScopeKind materialScope;
  final String? applianceNameplateOcr;
  final int? oldPartLeavePhotoPhash64;
  final bool oldPartDisposalAuthorizedByClient;
  final bool isCoPresenceVerified;

  @override
  State<PinFourDigitApprovalCard> createState() => _PinFourDigitApprovalCardState();
}

class _PinFourDigitApprovalCardState extends State<PinFourDigitApprovalCard> {
  late final ValueNotifier<Duration> _remainingNotifier =
      ValueNotifier<Duration>(widget.initialRemaining);
  final TextEditingController _pinCtrl = TextEditingController();
  String? _pinError;

  @override
  void dispose() {
    _remainingNotifier.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _submitPin() {
    final pin = _pinCtrl.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _pinError = 'Digite exatamente os 4 dígitos do código PIN.');
      return;
    }
    setState(() => _pinError = null);
    widget.onConfirmPin(pin);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      key: const ValueKey('pin-four-digit-approval-card'),
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aprovação Presencial (PIN de 4 Dígitos) ou Liberação em 24h',
            style: AppType.titleSm.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s12),
          AppCard(
            key: const ValueKey('pin-bilateral-copresence-badge'),
            variant: AppCardVariant.outlined,
            color: widget.isCoPresenceVerified ? tk.successSoft : tk.warningSoft,
            borderColor: widget.isCoPresenceVerified
                ? tk.success.withValues(alpha: 0.45)
                : tk.warningInk.withValues(alpha: 0.45),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s12,
              vertical: AppSpace.s8,
            ),
            radius: AppGeometry.iconTileRadius,
            child: Row(
              children: [
                Icon(
                  widget.isCoPresenceVerified
                      ? Icons.spatial_audio_off_rounded
                      : Icons.warning_amber_rounded,
                  size: 18,
                  color: widget.isCoPresenceVerified ? tk.successInk : tk.warningInk,
                ),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: Text(
                    widget.isCoPresenceVerified
                        ? 'Co-Presença Física Confirmada (QR TOTP 15s / Token Ultrassônico + GNSS AGC)'
                        : 'Aguardando Handshake Presencial de Co-Presença com o aparelho do cliente',
                    style: AppType.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color:
                          widget.isCoPresenceVerified ? tk.successInk : tk.warningInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.materialScope == MaterialSplitScopeKind.componentReplacement) ...[
            const SizedBox(height: AppSpace.s12),
            AppCard(
              key: const ValueKey('pin-atomic-proof-of-leave-box'),
              variant: AppCardVariant.tonal,
              borderColor: tk.clientAccent.withValues(alpha: 0.45),
              padding: const EdgeInsets.all(AppSpace.s12),
              radius: AppGeometry.fieldRadius,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        size: 18,
                        color: tk.clientAccentInk,
                      ),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(
                        child: Text(
                          'Custódia da Peça Substituída (Proof-of-Leave)',
                          style: AppType.bodyStrong.copyWith(color: tk.text),
                        ),
                      ),
                    ],
                  ),
                  if ((widget.applianceNameplateOcr ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s4),
                    Text(
                      'Equipamento: ${widget.applianceNameplateOcr} • Entrega Auditada',
                      style: AppType.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tk.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    widget.oldPartDisposalAuthorizedByClient
                        ? 'Confira o reparo concluído. Ao informar o PIN ao profissional, você confirma a conclusão do serviço e a autorização de descarte da peça antiga.'
                        : 'Confira sua peça substituída na foto de entrega (Proof-of-Leave). Ao informar o PIN ao profissional, você confirma a conclusão do serviço e o recebimento da peça antiga.',
                    style: AppType.bodySm.copyWith(color: tk.text),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpace.s12),
          Text(
            'Contagem Regressiva de Proteção',
            style: AppType.titleSm.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s4),
          ValueListenableBuilder<Duration>(
            valueListenable: _remainingNotifier,
            builder: (context, dur, _) {
              final hours = dur.inHours.toString().padLeft(2, '0');
              final mins = (dur.inMinutes % 60).toString().padLeft(2, '0');
              return Text(
                'Liberação Automática (Auto-Release RN-AF-04) em: ${hours}h ${mins}m caso não haja contestação.',
                style: AppType.tabular(AppType.bodySm).copyWith(
                  fontWeight: FontWeight.w600,
                  color: tk.clientAccentInk,
                ),
              );
            },
          ),
          const SizedBox(height: AppSpace.s12),
          AppTextField(
            key: const ValueKey('pin-4digit-input'),
            controller: _pinCtrl,
            maxLength: 4,
            keyboardType: TextInputType.number,
            label: 'Código PIN do Cliente (4 dígitos)',
            hint: '0000',
            errorText: _pinError,
          ),
          const SizedBox(height: AppSpace.s12),
          AppButton(
            key: const ValueKey('btn-confirm-4digit-pin'),
            label: 'Confirmar Conclusão com PIN',
            icon: Icons.lock_open_rounded,
            onPressed: _submitPin,
          ),
        ],
      ),
    );
  }
}

/// Selo Oficial do Marco Zero (`RN-MZ-01` e `RN-MZ-02`) para Profissionais Âncora
/// e Novos Especialistas com Credencial e MEI Verificados (`RTS >= 70`).
class MarcoZeroTrustBadge extends StatelessWidget {
  const MarcoZeroTrustBadge({
    super.key,
    required this.isTrustedAnchor,
    required this.completedJobsCount,
    required this.rtsScore,
  });

  final bool isTrustedAnchor;
  final int completedJobsCount;
  final double rtsScore;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    String? label;
    if (isTrustedAnchor) {
      label = 'Especialista Fundador Verificado';
    } else if (completedJobsCount == 0 && rtsScore >= 70.0) {
      label = 'Novo na Plataforma • Credencial e MEI Verificados';
    }
    if (label == null) return const SizedBox.shrink();

    return Container(
      key: const ValueKey('marco-zero-trust-badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s4 + 2,
      ),
      decoration: BoxDecoration(
        color: tk.successSoft,
        borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
        border: Border.all(color: tk.success.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 16, color: tk.successInk),
          const SizedBox(width: AppSpace.s8),
          Flexible(
            child: Text(
              '$label (RTS ${rtsScore.toStringAsFixed(0)}/100)',
              style: AppType.tabular(AppType.caption).copyWith(
                fontWeight: FontWeight.w700,
                color: tk.successInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/analytics/founder_dashboard_models.dart';
import '../../../core/utils/money.dart';
import '../data/founder_cockpit_repository.dart';
import 'founder_animations_and_shaders.dart';

/// Cartão de Tesouraria Bivalente (`SANDBOX_PRE_CNPJ` vs `PRODUCTION_SLU`) na Aba 1 (`Financeiro`).
///
/// Regras de Excelência Executiva (`Quiet Luxury 85/10/5`):
/// - Zero jargão técnico cru na interface (linguagem humana e cristalina).
/// - Zero campo de digitação de chave PIX: destino 100% travado ao CPF do titular único.
/// - Respeita 100% `privacyBlurActive` (`R$ •••••`) e `safeBottomModalInset` em modais.
class FounderBivalentTreasuryCard extends StatefulWidget {
  const FounderBivalentTreasuryCard({
    super.key,
    required this.repository,
    required this.treasuryState,
    this.privacyBlurActive = false,
  });

  final FounderCockpitRepository repository;
  final CeoBivalentTreasuryState treasuryState;
  final bool privacyBlurActive;

  @override
  State<FounderBivalentTreasuryCard> createState() =>
      _FounderBivalentTreasuryCardState();
}

class _FounderBivalentTreasuryCardState
    extends State<FounderBivalentTreasuryCard> {
  bool _showCeilingFormula = false;
  bool _showMonthlyRoutine = false;
  Map<String, dynamic>? _lastReceipt;

  String _fmt(int cents) =>
      widget.privacyBlurActive ? 'R\$ •••••' : Money.formatBrl(cents);

  Future<void> _openWithdrawModal() async {
    HapticFeedback.selectionClick();
    final receipt = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LockedProfitWithdrawalSheet(
        repository: widget.repository,
        treasuryState: widget.treasuryState,
      ),
    );
    if (receipt != null && mounted) {
      setState(() => _lastReceipt = receipt);
    }
  }

  Future<void> _openBufferConfigModal() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TreasuryBufferConfigSheet(
        repository: widget.repository,
        currentSafetyBufferCents: widget.treasuryState.safetyBufferCents,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.treasuryState;
    final isProd = t.isProductionSlu;
    final canWithdraw = t.withdrawableProfitCents > 0 && !t.isDuressFrozen;

    final modeBadgeColor = isProd
        ? FounderSovereignTokens.solvencyEmerald
        : FounderSovereignTokens.imperialGoldBright;

    return FounderGlassCard(
      key: const ValueKey<String>('ceo-bivalent-treasury-card'),
      accentTopBarColor: modeBadgeColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FounderPrecisionBadge(
                    FounderIconGlyph.pixDiamond,
                    boxSize: 34,
                    iconSize: 16.5,
                    tintColor: modeBadgeColor,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Retirada segura e proteção do caixa',
                      style: FounderSovereignTokens.titleStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              Container(
                key: const ValueKey<String>('ceo-treasury-mode-pill'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: modeBadgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: modeBadgeColor.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  isProd
                      ? 'Empresa ativa · Produção'
                      : 'Homologação Pré-CNPJ · Custo R\$ 0',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: modeBadgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final ceilingBox = Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: FounderSovereignTokens.obsidianSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: canWithdraw
                        ? FounderSovereignTokens.solvencyEmerald
                            .withValues(alpha: 0.45)
                        : FounderSovereignTokens.crispBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Liberado para sua retirada hoje',
                      style: TextStyle(
                        color: FounderSovereignTokens.secondaryInk,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedMoneyOdometer(
                      cents: t.withdrawableProfitCents,
                      privacyBlurActive: widget.privacyBlurActive,
                      style: FounderSovereignTokens.monoMetric(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: canWithdraw
                            ? FounderSovereignTokens.solvencyEmerald
                            : FounderSovereignTokens.primaryInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Após descontar profissionais (85%), garantia (1,5%), imposto (6%) e colchão (${_fmt(t.safetyBufferCents)})',
                      style: const TextStyle(
                        color: FounderSovereignTokens.mutedInk,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );

              final destBox = Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: FounderSovereignTokens.obsidianSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: FounderSovereignTokens.imperialGold
                        .withValues(alpha: 0.32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const FounderPrecisionIcon(
                          FounderIconGlyph.vaultLock,
                          size: 14,
                          color: FounderSovereignTokens.imperialGoldBright,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t.beneficiaryFullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FounderSovereignTokens.imperialGoldBright,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.bankDisplayLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FounderSovereignTokens.primaryInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sem digitação de chave PIX · Destino travado no banco',
                      style: TextStyle(
                        color: FounderSovereignTokens.solvencyEmerald,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );

              if (c.maxWidth < 330) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ceilingBox,
                    const SizedBox(height: 10),
                    destBox,
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: ceilingBox),
                    const SizedBox(width: 10),
                    Expanded(child: destBox),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                key: const ValueKey<String>('ceo-open-withdraw-sheet-btn'),
                onPressed: _openWithdrawModal,
                style: FilledButton.styleFrom(
                  backgroundColor: FounderSovereignTokens.imperialGold,
                  foregroundColor: const Color(0xFF0B0E14),
                  minimumSize: const Size(0, 38),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const FounderPrecisionIcon(
                  FounderIconGlyph.pixDiamond,
                  size: 15.5,
                  color: Color(0xFF0B0E14),
                  accentColor: Color(0xFF0B0E14),
                  duotoneAlpha: 0.0,
                ),
                label: Text(
                  isProd
                      ? 'Transferir lucro p/ minha conta'
                      : 'Simular retirada (Pré-CNPJ)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('ceo-open-buffer-sheet-btn'),
                onPressed: _openBufferConfigModal,
                style: OutlinedButton.styleFrom(
                  foregroundColor: FounderSovereignTokens.secondaryInk,
                  side: const BorderSide(
                    color: FounderSovereignTokens.crispBorder,
                  ),
                  minimumSize: const Size(0, 38),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const FounderPrecisionIcon(
                  FounderIconGlyph.shieldVerified,
                  size: 15,
                  color: FounderSovereignTokens.secondaryInk,
                ),
                label: const Text(
                  'Colchão de segurança',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (_lastReceipt != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              key: const ValueKey<String>('ceo-last-distribution-receipt-box'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.solvencyEmeraldSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: FounderSovereignTokens.solvencyEmerald
                      .withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Comprovante emitido · ${_fmt((_lastReceipt!['amount_cents'] as num?)?.toInt() ?? 0)}',
                    style: const TextStyle(
                      color: FounderSovereignTokens.solvencyEmerald,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Favorecido: ${_lastReceipt!['beneficiary_name'] ?? 'Wagner Oliveira'} · Protocolo: ${_lastReceipt!['transfer_reference'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 10.5,
                      color: FounderSovereignTokens.primaryInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: <Widget>[
              InkWell(
                key: const ValueKey<String>('ceo-toggle-ceiling-formula-btn'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(
                  () => _showCeilingFormula = !_showCeilingFormula,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          _showCeilingFormula
                              ? 'Ocultar cálculo do teto seguro'
                              : 'Ver cálculo do teto seguro',
                          style: const TextStyle(
                            color: FounderSovereignTokens.imperialGoldBright,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      FounderPrecisionIcon(
                        _showCeilingFormula
                            ? FounderIconGlyph.chevronUp
                            : FounderIconGlyph.chevronDown,
                        size: 14,
                        color: FounderSovereignTokens.imperialGoldBright,
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                key: const ValueKey<String>('ceo-toggle-monthly-routine-btn'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(
                  () => _showMonthlyRoutine = !_showMonthlyRoutine,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          _showMonthlyRoutine
                              ? 'Ocultar rotina mensal (dias 1, 5 e 20)'
                              : 'Rotina mensal (dias 1, 5 e 20)',
                          style: const TextStyle(
                            color: FounderSovereignTokens.secondaryInk,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      FounderPrecisionIcon(
                        _showMonthlyRoutine
                            ? FounderIconGlyph.chevronUp
                            : FounderIconGlyph.chevronDown,
                        size: 14,
                        color: FounderSovereignTokens.secondaryInk,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_showCeilingFormula) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FounderSovereignTokens.crispBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _FormulaLine(
                    label: 'Custódia intocável (85% profs + carteiras + 1,5% garantia)',
                    value: _fmt(t.untouchableCustodyTotalCents),
                    color: FounderSovereignTokens.secondaryInk,
                  ),
                  const Divider(
                    height: 14,
                    color: FounderSovereignTokens.crispBorder,
                  ),
                  _FormulaLine(
                    label: '(+) Comissão acumulada da plataforma (13,5%)',
                    value: _fmt(t.cumulativePlatformRevenue135Cents),
                    color: FounderSovereignTokens.imperialGoldBright,
                  ),
                  _FormulaLine(
                    label: '(-) Imposto Simples Nacional provisionado (6%)',
                    value: _fmt(t.das6PctUnpaidProvisionCents + t.das6PctPaidCents),
                    color: FounderSovereignTokens.warmAmber,
                  ),
                  _FormulaLine(
                    label: '(-) Contas pagas e agendadas da empresa',
                    value: _fmt(
                      t.corporateExpensesPaidCents +
                          t.corporateExpensesScheduledCents,
                    ),
                    color: FounderSovereignTokens.mutedInk,
                  ),
                  _FormulaLine(
                    label: '(-) Retiradas já realizadas neste modo',
                    value: _fmt(t.priorDistributionsCents),
                    color: FounderSovereignTokens.mutedInk,
                  ),
                  _FormulaLine(
                    label: '(-) Colchão mínimo de segurança',
                    value: _fmt(t.safetyBufferCents),
                    color: FounderSovereignTokens.mutedInk,
                  ),
                  const Divider(
                    height: 14,
                    color: FounderSovereignTokens.crispBorder,
                  ),
                  _FormulaLine(
                    label: '(=) Teto seguro liberado para retirada',
                    value: _fmt(t.withdrawableProfitCents),
                    color: FounderSovereignTokens.solvencyEmerald,
                    bold: true,
                  ),
                ],
              ),
            ),
          ],
          if (_showMonthlyRoutine) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FounderSovereignTokens.crispBorder),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '• Dia 1 do mês: baixar o Relatório para o Contador (PDF + Planilha CSV) e enviar à contabilidade.',
                    style: TextStyle(
                      color: FounderSovereignTokens.primaryInk,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• Dia 5 do mês: transferir seu lucro líquido (isento de IR) respeitando o teto seguro.',
                    style: TextStyle(
                      color: FounderSovereignTokens.primaryInk,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• Dia 20 útil: quitar a guia do Simples Nacional (6% sobre a comissão de 13,5%) com o saldo já separado.',
                    style: TextStyle(
                      color: FounderSovereignTokens.primaryInk,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FormulaLine extends StatelessWidget {
  const _FormulaLine({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: bold
                    ? FounderSovereignTokens.primaryInk
                    : FounderSovereignTokens.secondaryInk,
                fontSize: 11.5,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: FounderSovereignTokens.monoMetric(
              fontSize: bold ? 12.5 : 11.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedProfitWithdrawalSheet extends StatefulWidget {
  const _LockedProfitWithdrawalSheet({
    required this.repository,
    required this.treasuryState,
  });

  final FounderCockpitRepository repository;
  final CeoBivalentTreasuryState treasuryState;

  @override
  State<_LockedProfitWithdrawalSheet> createState() =>
      _LockedProfitWithdrawalSheetState();
}

class _LockedProfitWithdrawalSheetState
    extends State<_LockedProfitWithdrawalSheet> {
  final TextEditingController _amountCtrl = TextEditingController();
  String _kind = 'PROFIT_DISTRIBUTION';
  bool _submitting = false;
  String? _errorMsg;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  int _parseBrlToCents(String raw) {
    final cleaned = raw
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    final val = double.tryParse(cleaned);
    if (val == null || val <= 0) return 0;
    return (val * 100).round();
  }

  void _fillPercent(double ratio) {
    final ceiling = widget.treasuryState.withdrawableProfitCents;
    if (ceiling <= 0) return;
    final target = math.max(1, (ceiling * ratio).round());
    final reais = (target / 100.0).toStringAsFixed(2).replaceAll('.', ',');
    setState(() {
      _amountCtrl.text = reais;
      _errorMsg = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final cents = _parseBrlToCents(_amountCtrl.text);
    if (cents <= 0) {
      setState(() => _errorMsg = 'Informe um valor válido em reais.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMsg = null;
    });
    try {
      final res = await widget.repository.requestProfitDistribution(
        requestedCents: cents,
        distributionKind: _kind,
      );
      if (!mounted) return;
      Navigator.of(context).pop(res);
    } on CeoVaultSecurityException catch (e) {
      if (mounted) setState(() => _errorMsg = e.userMessagePt);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMsg = 'Não foi possível concluir a operação agora.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.treasuryState;
    final bottomInset = math.max(
          FounderSovereignTokens.safeBottomInset(context),
          MediaQuery.viewInsetsOf(context).bottom,
        ) +
        14.0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: FounderSovereignTokens.obsidianCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: FounderSovereignTokens.crispBorder),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 14, 8),
            child: Row(
              children: <Widget>[
                const FounderPrecisionIcon(
                  FounderIconGlyph.pixDiamond,
                  size: 18,
                  color: FounderSovereignTokens.imperialGoldBright,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.isProductionSlu
                        ? 'Transferência para sua conta'
                        : 'Simulação Pré-CNPJ (Custo R\$ 0)',
                    style: FounderSovereignTokens.titleStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const FounderPrecisionIcon(
                    FounderIconGlyph.closeCross,
                    size: 17,
                    color: FounderSovereignTokens.mutedInk,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FounderSovereignTokens.obsidianSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: FounderSovereignTokens.crispBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Destino travado: ${t.beneficiaryFullName}',
                          style: const TextStyle(
                            color: FounderSovereignTokens.imperialGoldBright,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Teto liberado agora: ${Money.formatBrl(t.withdrawableProfitCents)}',
                          style: FounderSovereignTokens.monoMetric(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: FounderSovereignTokens.solvencyEmerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: <Widget>[
                      ChoiceChip(
                        label: const Text('Lucro líquido (isento IR)'),
                        selected: _kind == 'PROFIT_DISTRIBUTION',
                        onSelected: (_) =>
                            setState(() => _kind = 'PROFIT_DISTRIBUTION'),
                      ),
                      ChoiceChip(
                        label: const Text('Pró-labore mensal'),
                        selected: _kind == 'PRO_LABORE',
                        onSelected: (_) => setState(() => _kind = 'PRO_LABORE'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (t.withdrawableProfitCents > 0) ...<Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: <Widget>[
                        ActionChip(
                          label: const Text('25% do teto'),
                          onPressed: () => _fillPercent(0.25),
                        ),
                        ActionChip(
                          label: const Text('50% do teto'),
                          onPressed: () => _fillPercent(0.50),
                        ),
                        ActionChip(
                          label: const Text('100% do teto'),
                          onPressed: () => _fillPercent(1.0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    key: const ValueKey<String>('ceo-withdraw-amount-input'),
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: FounderSovereignTokens.monoMetric(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: FounderSovereignTokens.primaryInk,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Valor da retirada (R\$)',
                      hintText: '0,00',
                      filled: true,
                      fillColor: FounderSovereignTokens.obsidianSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (_errorMsg != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      _errorMsg!,
                      style: const TextStyle(
                        color: FounderSovereignTokens.crimsonAlert,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 10, 20, bottomInset),
            decoration: const BoxDecoration(
              color: FounderSovereignTokens.obsidianCard,
              border: Border(
                top: BorderSide(color: FounderSovereignTokens.crispBorder),
              ),
            ),
            child: FilledButton(
              key: const ValueKey<String>('ceo-confirm-withdraw-btn'),
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: FounderSovereignTokens.imperialGold,
                foregroundColor: const Color(0xFF0B0E14),
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _submitting
                    ? 'Validando teto seguro…'
                    : (t.isProductionSlu
                        ? 'Confirmar transferência'
                        : 'Confirmar simulação Pré-CNPJ'),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TreasuryBufferConfigSheet extends StatefulWidget {
  const _TreasuryBufferConfigSheet({
    required this.repository,
    required this.currentSafetyBufferCents,
  });

  final FounderCockpitRepository repository;
  final int currentSafetyBufferCents;

  @override
  State<_TreasuryBufferConfigSheet> createState() =>
      _TreasuryBufferConfigSheetState();
}

class _TreasuryBufferConfigSheetState
    extends State<_TreasuryBufferConfigSheet> {
  final TextEditingController _bufferCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _bufferCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePresetOrTyped([int? presetCents]) async {
    if (_saving) return;
    int targetCents;
    if (presetCents != null) {
      targetCents = presetCents;
    } else {
      final raw = _bufferCtrl.text
          .replaceAll('R\$', '')
          .replaceAll(' ', '')
          .replaceAll('.', '')
          .replaceAll(',', '.')
          .trim();
      final val = double.tryParse(raw);
      if (val == null || val < 0) {
        setState(() => _error = 'Informe um valor igual ou maior que zero.');
        return;
      }
      targetCents = (val * 100).round();
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.configureTreasuryParameters(
        safetyBufferCents: targetCents,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível salvar o colchão agora.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = math.max(
          FounderSovereignTokens.safeBottomInset(context),
          MediaQuery.viewInsetsOf(context).bottom,
        ) +
        14.0;
    return Container(
      decoration: const BoxDecoration(
        color: FounderSovereignTokens.obsidianCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: FounderSovereignTokens.crispBorder),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Colchão mínimo de segurança no caixa',
            style: FounderSovereignTokens.titleStyle(fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Atual: ${Money.formatBrl(widget.currentSafetyBufferCents)}. Esse valor permanece sempre protegido na conta da empresa antes de qualquer retirada.',
            style: FounderSovereignTokens.subtitleStyle(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ActionChip(
                label: const Text('R\$ 0 (Teste)'),
                onPressed: _saving ? null : () => _savePresetOrTyped(0),
              ),
              ActionChip(
                label: const Text('R\$ 300'),
                onPressed: _saving ? null : () => _savePresetOrTyped(30000),
              ),
              ActionChip(
                label: const Text('R\$ 500'),
                onPressed: _saving ? null : () => _savePresetOrTyped(50000),
              ),
              ActionChip(
                label: const Text('R\$ 1.000'),
                onPressed: _saving ? null : () => _savePresetOrTyped(100000),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bufferCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: FounderSovereignTokens.monoMetric(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: FounderSovereignTokens.primaryInk,
            ),
            decoration: InputDecoration(
              labelText: 'Outro valor de reserva mínima (R\$)',
              hintText: '300,00',
              filled: true,
              fillColor: FounderSovereignTokens.obsidianSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: FounderSovereignTokens.crimsonAlert,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _saving ? null : () => _savePresetOrTyped(),
            style: FilledButton.styleFrom(
              backgroundColor: FounderSovereignTokens.imperialGold,
              foregroundColor: const Color(0xFF0B0E14),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(_saving ? 'Salvando…' : 'Salvar colchão de segurança'),
          ),
        ],
      ),
    );
  }
}

/// Semáforo dos 4 Critérios Objetivos do "Sinal Verde" para Abrir o CNPJ (SLU em Poços de Caldas - MG)
/// + Roteiro Operacional `D-30 -> D+0` na Aba 4 (`Conta`).
class FounderSluGoLiveSemaphoreCard extends StatefulWidget {
  const FounderSluGoLiveSemaphoreCard({
    super.key,
    required this.repository,
    required this.semaphore,
    this.privacyBlurActive = false,
  });

  final FounderCockpitRepository repository;
  final CeoSluGoLiveSemaphore semaphore;
  final bool privacyBlurActive;

  @override
  State<FounderSluGoLiveSemaphoreCard> createState() =>
      _FounderSluGoLiveSemaphoreCardState();
}

class _FounderSluGoLiveSemaphoreCardState
    extends State<FounderSluGoLiveSemaphoreCard> {
  bool _showRoadmap = false;

  String _fmt(int cents) =>
      widget.privacyBlurActive ? 'R\$ •••••' : Money.formatBrl(cents);

  Future<void> _openReserveModal() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TakeoffReserveUpdateSheet(
        repository: widget.repository,
        currentSavedCents: widget.semaphore.takeoffReserveSavedCents,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.semaphore;
    final green = s.allFourCriteriaGreen;
    final headerAccent = green
        ? FounderSovereignTokens.solvencyEmerald
        : FounderSovereignTokens.imperialGoldBright;

    return FounderGlassCard(
      key: const ValueKey<String>('ceo-slu-go-live-semaphore-card'),
      accentTopBarColor: headerAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FounderPrecisionBadge(
                    green
                        ? FounderIconGlyph.checkValid
                        : FounderIconGlyph.taxBankDas,
                    boxSize: 34,
                    iconSize: 16.5,
                    tintColor: headerAccent,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Sinal Verde para abrir o CNPJ (Poços de Caldas)',
                      style: FounderSovereignTokens.titleStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: headerAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: headerAccent.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  green
                      ? '4/4 prontos · Abrir SLU'
                      : '${s.criteriaGreenCount}/4 critérios prontos',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: headerAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            green
                ? 'Todos os 4 critérios objetivos foram atingidos. Você já pode iniciar o protocolo societário (D-30) sem desperdício mensal.'
                : 'Enquanto os 4 critérios abaixo não estiverem verdes ao mesmo tempo, você opera 100% em homologação gratuita a custo R\$ 0.',
            style: FounderSovereignTokens.subtitleStyle(),
          ),
          const SizedBox(height: 12),
          _CriterionRow(
            ok: s.criterion1Stability7dOk,
            title: '1. Estabilidade técnica por 7 dias seguidos',
            subtitle:
                '${s.zeroDriftDaysElapsed} de ${s.zeroDriftTargetDays} dias com desvio de R\$ 0,00 · ${s.sandboxPayoutsTestedCount} retirada(s) testada(s)',
          ),
          const SizedBox(height: 8),
          _CriterionRow(
            ok: s.criterion2P0P1ZeroedOk,
            title: '2. Segurança, versões OTA e conciliação 100%',
            subtitle: s.criterion2P0P1ZeroedOk
                ? 'Atualização monotônica, cadeia de auditoria e saldos verificados'
                : 'Verificação pendente de conciliação ou integridade',
          ),
          const SizedBox(height: 8),
          _CriterionRow(
            ok: s.criterion3PocosLiquidityOk,
            title: '3. Liquidez de rua em Poços de Caldas - MG',
            subtitle:
                '${s.pocosProvidersTotalCount} pré-cadastrado(s) (${s.pocosProvidersActiveCount} ativo(s)) · Meta: 15 a ${s.pocosProvidersIdealTarget} profissionais',
          ),
          const SizedBox(height: 8),
          _CriterionRow(
            ok: s.criterion4TakeoffReserveOk,
            title: '4. Reserva dedicada de decolagem separada',
            subtitle:
                'Guardado: ${_fmt(s.takeoffReserveSavedCents)} de ${_fmt(s.takeoffReserveTargetCents)} (mín. ${_fmt(s.takeoffReserveMinCents)} p/ JUCEMG + e-CNPJ A1)',
            trailing: TextButton(
              key: const ValueKey<String>('ceo-update-takeoff-reserve-btn'),
              onPressed: _openReserveModal,
              style: TextButton.styleFrom(
                foregroundColor: FounderSovereignTokens.imperialGoldBright,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 30),
              ),
              child: const Text(
                'Atualizar',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: FounderSovereignTokens.obsidianSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FounderSovereignTokens.crispBorder),
            ),
            child: Row(
              children: <Widget>[
                const FounderPrecisionIcon(
                  FounderIconGlyph.shieldVerified,
                  size: 15,
                  color: FounderSovereignTokens.solvencyEmerald,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Termo de Mandato Legal (Art. 653 CC) assinado no Desperrengue: '
                    '${s.legalMandateAcceptedUsersCount} conta(s) (${s.legalMandateProvidersCount} profissional/is)',
                    style: const TextStyle(
                      color: FounderSovereignTokens.secondaryInk,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            key: const ValueKey<String>('ceo-toggle-slu-roadmap-btn'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _showRoadmap = !_showRoadmap),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      _showRoadmap
                          ? 'Ocultar cronograma D-30 até a estreia (D+0)'
                          : 'Ver cronograma exato de abertura (D-30 até D+0)',
                      style: const TextStyle(
                        color: FounderSovereignTokens.imperialGoldBright,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  FounderPrecisionIcon(
                    _showRoadmap
                        ? FounderIconGlyph.chevronUp
                        : FounderIconGlyph.chevronDown,
                    size: 14,
                    color: FounderSovereignTokens.imperialGoldBright,
                  ),
                ],
              ),
            ),
          ),
          if (_showRoadmap) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FounderSovereignTokens.obsidianSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FounderSovereignTokens.crispBorder),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _RoadmapStepLine(
                    badge: 'HOJE · R\$ 0',
                    text:
                        'Operação 100% em homologação gratuita (Asaas Sandbox + Efí Homologação sem CNPJ).',
                  ),
                  SizedBox(height: 8),
                  _RoadmapStepLine(
                    badge: 'D-30',
                    text:
                        'Sinal Verde 4/4 atingido: enviar minuta pronta da SLU (CNAE 6319-4/00 Anexo III 6%) ao contador para protocolo na JUCEMG.',
                  ),
                  SizedBox(height: 8),
                  _RoadmapStepLine(
                    badge: 'D-15',
                    text:
                        'CNPJ emitido: emitir e-CNPJ A1 por videoconferência, optar pelo Simples Nacional e credenciar NFS-e em Poços de Caldas.',
                  ),
                  SizedBox(height: 8),
                  _RoadmapStepLine(
                    badge: 'D-12',
                    text:
                        'Abrir Conta PJ gratuita Banco Inter Empresas + aprovar conta PJ de produção no Asaas com Webhook Anti-Coação.',
                  ),
                  SizedBox(height: 8),
                  _RoadmapStepLine(
                    badge: 'D-5',
                    text:
                        'Subir chaves de produção nas Edge Functions, executar o comando único de destravamento da SLU e fazer teste real de R\$ 20.',
                  ),
                  SizedBox(height: 8),
                  _RoadmapStepLine(
                    badge: 'D+0',
                    text:
                        'Lançamento comercial em Poços de Caldas com split real 85% / 13,5% / 1,5%.',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CriterionRow extends StatelessWidget {
  const _CriterionRow({
    required this.ok,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final bool ok;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = ok
        ? FounderSovereignTokens.solvencyEmerald
        : FounderSovereignTokens.warmAmber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FounderSovereignTokens.obsidianSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ok
              ? FounderSovereignTokens.solvencyEmerald.withValues(alpha: 0.4)
              : FounderSovereignTokens.crispBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: FounderPrecisionIcon(
              ok ? FounderIconGlyph.checkValid : FounderIconGlyph.ringPending,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: FounderSovereignTokens.primaryInk,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: FounderSovereignTokens.mutedInk,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _RoadmapStepLine extends StatelessWidget {
  const _RoadmapStepLine({required this.badge, required this.text});

  final String badge;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: FounderSovereignTokens.imperialGoldSoft,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badge,
            style: FounderSovereignTokens.monoMetric(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: FounderSovereignTokens.imperialGoldBright,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: FounderSovereignTokens.primaryInk,
              fontSize: 11.5,
              height: 1.38,
            ),
          ),
        ),
      ],
    );
  }
}

class _TakeoffReserveUpdateSheet extends StatefulWidget {
  const _TakeoffReserveUpdateSheet({
    required this.repository,
    required this.currentSavedCents,
  });

  final FounderCockpitRepository repository;
  final int currentSavedCents;

  @override
  State<_TakeoffReserveUpdateSheet> createState() =>
      _TakeoffReserveUpdateSheetState();
}

class _TakeoffReserveUpdateSheetState
    extends State<_TakeoffReserveUpdateSheet> {
  final TextEditingController _reserveCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reserveCtrl.dispose();
    super.dispose();
  }

  Future<void> _save([int? presetCents]) async {
    if (_saving) return;
    int cents;
    if (presetCents != null) {
      cents = presetCents;
    } else {
      final raw = _reserveCtrl.text
          .replaceAll('R\$', '')
          .replaceAll(' ', '')
          .replaceAll('.', '')
          .replaceAll(',', '.')
          .trim();
      final val = double.tryParse(raw);
      if (val == null || val < 0) {
        setState(() => _error = 'Informe um valor válido.');
        return;
      }
      cents = (val * 100).round();
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.configureTreasuryParameters(
        takeoffReserveSavedCents: cents,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível atualizar a reserva agora.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = math.max(
          FounderSovereignTokens.safeBottomInset(context),
          MediaQuery.viewInsetsOf(context).bottom,
        ) +
        14.0;
    return Container(
      decoration: const BoxDecoration(
        color: FounderSovereignTokens.obsidianCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: FounderSovereignTokens.crispBorder),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Reserva dedicada para abrir a SLU',
            style: FounderSovereignTokens.titleStyle(fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Atual: ${Money.formatBrl(widget.currentSavedCents)}. Meta recomendada: R\$ 1.000 a R\$ 1.300 (JUCEMG + e-CNPJ A1 + 1º trimestre contábil).',
            style: FounderSovereignTokens.subtitleStyle(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ActionChip(
                label: const Text('R\$ 0'),
                onPressed: _saving ? null : () => _save(0),
              ),
              ActionChip(
                label: const Text('R\$ 500'),
                onPressed: _saving ? null : () => _save(50000),
              ),
              ActionChip(
                label: const Text('R\$ 1.000 (Mín.)'),
                onPressed: _saving ? null : () => _save(100000),
              ),
              ActionChip(
                label: const Text('R\$ 1.300 (Ideal)'),
                onPressed: _saving ? null : () => _save(130000),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reserveCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: FounderSovereignTokens.monoMetric(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: FounderSovereignTokens.primaryInk,
            ),
            decoration: InputDecoration(
              labelText: 'Valor reservado hoje (R\$)',
              hintText: '1300,00',
              filled: true,
              fillColor: FounderSovereignTokens.obsidianSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: FounderSovereignTokens.crimsonAlert,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _saving ? null : () => _save(),
            style: FilledButton.styleFrom(
              backgroundColor: FounderSovereignTokens.imperialGold,
              foregroundColor: const Color(0xFF0B0E14),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(_saving ? 'Salvando…' : 'Confirmar valor reservado'),
          ),
        ],
      ),
    );
  }
}

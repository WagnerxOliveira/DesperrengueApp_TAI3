import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/account_models.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';

/// Saque via Pix com Trava de Mesma Titularidade (`Same-Holder Lock` — `RN-AF-12`)
/// e Circuit Breaker Preventivo (`hasOpenDispute` — `RN-AF-08`).
class PixWithdrawScreen extends StatefulWidget {
  const PixWithdrawScreen({
    super.key,
    required this.available,
    this.verifiedCpfHash,
    this.verifiedHolderName,
    this.hasOpenDispute = false,
  });

  /// Saldo disponível mostrado ao abrir (o servidor revalida).
  final double available;

  /// Hash criptográfico SHA-256 do CPF homologado via KYC/OCR (`Same-Holder Lock`).
  final String? verifiedCpfHash;

  /// Nome civil homologado via OCR do documento oficial.
  final String? verifiedHolderName;

  /// Indica se há chamado de garantia / mediação aberta (`Circuit Breaker`).
  final bool hasOpenDispute;

  @override
  State<PixWithdrawScreen> createState() => _PixWithdrawScreenState();
}

class _PixWithdrawScreenState extends State<PixWithdrawScreen> {
  ProviderService? _providersOrNull;
  ProviderService get _providers => _providersOrNull ??= ProviderService();
  final _amount = TextEditingController();
  final _key = TextEditingController();
  PixKeyType _type = PixKeyType.cpf;
  bool _owner = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount.text = widget.available > 0
        ? widget.available.toStringAsFixed(2).replaceAll('.', ',')
        : '';
  }

  @override
  void dispose() {
    _amount.dispose();
    _key.dispose();
    super.dispose();
  }

  double? get _value => parseBrl(_amount.text);

  String? _validate() {
    if (widget.hasOpenDispute) {
      return 'Circuit Breaker Preventivo: Há um chamado de garantia em análise técnica. Aguarde a conclusão da mediação para sacar valores vinculados.';
    }
    final v = _value;
    if (v == null || v <= 0) return 'Informe um valor válido.';
    if (v > widget.available + 0.001) {
      return 'O valor é maior que o seu saldo disponível.';
    }
    if (!PixKeyValidator.isValid(_type, _key.text)) {
      return 'Chave Pix inválida para o tipo ${_type.label}.';
    }
    if (!PixKeyValidator.matchesVerifiedHolderCpf(
      _type,
      _key.text,
      verifiedCpfHash: widget.verifiedCpfHash,
    )) {
      return 'Trava de Mesma Titularidade (Same-Holder Lock): A chave Pix CPF informada não pertence ao titular do documento validado.';
    }
    if (!_owner) return 'Confirme que a chave Pix é de sua titularidade.';
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _providers.requestWithdrawal(
        amount: _value!,
        keyType: _type,
        key: _key.text,
        ownerConfirmed: _owner,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      AppSnackbar.show(
        context,
        'Pix de ${brl(_value)} solicitado com sucesso (simulado).',
        kind: AppSnackKind.success,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppScaffold(
      appBar: const AppAppBar(title: 'Transferir via Pix'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.layout.margin, AppSpace.s8, context.layout.margin, AppSpace.s24),
        children: [
          if (widget.hasOpenDispute)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpace.s16),
              child: InfoBanner(
                'Há um chamado de garantia em análise técnica. O valor deste serviço permanece protegido em custódia até a conclusão da mediação.',
                tone: BannerTone.warning,
              ),
            ),
          AppCard(
            variant: AppCardVariant.tonal,
            color: tk.providerSoft,
            borderColor: tk.providerAccentInk.withValues(alpha: 0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: AppGeometry.iconTileSize,
                      height: AppGeometry.iconTileSize,
                      decoration: BoxDecoration(
                        color: tk.card.withValues(alpha: tk.isDark ? 0.35 : 0.75),
                        borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: tk.accentInk,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saldo disponível',
                            style: AppType.bodySm.copyWith(color: tk.textMuted),
                          ),
                          const SizedBox(height: AppSpace.s2),
                          AppCountText(
                            value: widget.available,
                            format: brl,
                            style: AppType.headline.copyWith(color: tk.accentInk),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s12),
                const AppStatusChip(
                  'Pagamento seguro • Mesma titularidade',
                  tone: AppTone.success,
                  icon: Icons.verified_user_rounded,
                ),
              ],
            ),
          ),
          if (widget.verifiedHolderName != null &&
              widget.verifiedHolderName!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpace.s12),
            InfoBanner(
              'Titular Homologado (Same-Holder Lock): ${widget.verifiedHolderName}',
              tone: BannerTone.security,
            ),
          ],
          const SizedBox(height: AppSpace.s16),
          AppTextField(
            controller: _amount,
            label: 'Valor (R\$)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            suffix: TextButton(
              onPressed: () => setState(
                () => _amount.text =
                    widget.available.toStringAsFixed(2).replaceAll('.', ','),
              ),
              style: TextButton.styleFrom(foregroundColor: tk.accentInk),
              child: const Text('Tudo'),
            ),
          ),
          const SizedBox(height: AppSpace.s20),
          Text(
            'Tipo de chave',
            style: AppType.titleSm.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s8),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              for (final t in PixKeyType.values)
                ChoiceChip(
                  label: Text(t.label, style: AppType.bodySm),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          AppTextField(
            controller: _key,
            label: 'Chave Pix (${_type.label})',
            keyboardType: _type == PixKeyType.email
                ? TextInputType.emailAddress
                : TextInputType.text,
          ),
          const SizedBox(height: AppSpace.s8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _owner,
            onChanged: (v) => setState(() => _owner = v ?? false),
            title: Text(
              'Declaro que esta chave Pix é de minha titularidade.',
              style: AppType.bodySm.copyWith(color: tk.text),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s8),
              child: InfoBanner(_error!, tone: BannerTone.danger),
            ),
          const SizedBox(height: AppSpace.s12),
          const InfoBanner(
            'No MVP os repasses são simulados: o saldo é debitado, mas nenhum dinheiro real é movimentado. A chave não é armazenada por inteiro.',
            tone: BannerTone.security,
          ),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        footnote: 'Transferência protegida com verificação de titularidade',
        child: AppButton(
          label: 'Transferir via Pix',
          icon: Icons.pix_rounded,
          loading: _busy,
          onPressed: _busy ? null : _submit,
        ),
      ),
    );
  }
}

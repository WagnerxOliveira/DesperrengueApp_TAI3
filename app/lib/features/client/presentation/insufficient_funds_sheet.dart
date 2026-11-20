import 'package:flutter/material.dart';

import '../../../core/models/wallet_models.dart';
import '../../../core/ui/design_system/design_system.dart';
import 'adicionar_saldo_screen.dart';

/// Trava de saldo: aparece ANTES de criar o pedido quando `saldo < valor`.
/// Devolve `true` se o usuário completou a recarga (o chamador pode tentar de novo).
Future<bool> showInsufficientFundsSheet(
  BuildContext context, {
  required int requiredCents,
  required int availableCents,
}) async {
  final ok = await AppSheet.show<bool>(
    context,
    builder: (_) => InsufficientFundsBottomSheet(
      requiredCents: requiredCents,
      availableCents: availableCents,
    ),
  );
  return ok == true;
}

/// "Saldo insuficiente para este serviço": resumo lado a lado, tom tranquilizador e um
/// único CTA que já leva ao Adicionar Saldo com o valor que FALTA.
class InsufficientFundsBottomSheet extends StatelessWidget {
  const InsufficientFundsBottomSheet({
    super.key,
    required this.requiredCents,
    required this.availableCents,
  });

  final int requiredCents;
  final int availableCents;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final check = FundsCheck.evaluate(
      requiredCents: requiredCents,
      availableCents: availableCents,
    );
    final missing = check.missingCents;
    final stack = context.layout.isLargeText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s4, AppSpace.s4, AppSpace.s12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle, color: tk.warningSoft),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 32,
                color: tk.warningInk,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          Text(
            'Saldo insuficiente para este serviço',
            textAlign: TextAlign.center,
            style: AppType.headline.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s16),
          AppCard(
            variant: AppCardVariant.tonal,
            padding: const EdgeInsets.all(AppSpace.s16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (stack || constraints.maxWidth < 300) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppInfoRow(
                        label: 'Valor do serviço',
                        valueWidget: Text(
                          Money.brl(requiredCents),
                          style: AppType.tabular(AppType.bodyStrong).copyWith(color: tk.text),
                        ),
                      ),
                      Divider(height: AppSpace.s8, color: tk.border),
                      AppInfoRow(
                        label: 'Seu saldo',
                        valueWidget: Text(
                          Money.brl(availableCents),
                          style: AppType.tabular(AppType.bodyStrong).copyWith(color: tk.text),
                        ),
                      ),
                      Divider(height: AppSpace.s8, color: tk.border),
                      AppInfoRow(
                        label: 'Faltam',
                        strong: true,
                        valueWidget: Text(
                          Money.brl(missing),
                          style: AppType.tabular(AppType.figureSm).copyWith(color: tk.dangerInk),
                        ),
                      ),
                    ],
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _Figure(
                          label: 'Valor do serviço',
                          value: Money.brl(requiredCents),
                          color: tk.text,
                        ),
                      ),
                      _Divider(color: tk.border),
                      Expanded(
                        child: _Figure(
                          label: 'Seu saldo',
                          value: Money.brl(availableCents),
                          color: tk.text,
                        ),
                      ),
                      _Divider(color: tk.border),
                      Expanded(
                        child: _Figure(
                          label: 'Faltam',
                          value: Money.brl(missing),
                          color: tk.dangerInk,
                          highlight: true,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          AppCard(
            variant: AppCardVariant.tonal,
            color: tk.successSoft,
            borderColor: tk.success.withValues(alpha: 0.35),
            padding: const EdgeInsets.all(AppSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppStatusChip(
                  'Pagamento protegido',
                  tone: AppTone.success,
                  icon: Icons.verified_user_rounded,
                ),
                const SizedBox(height: AppSpace.s8),
                Text(
                  'No Desperrengue, o valor fica protegido em garantia e só é liberado ao profissional quando você aprovar o serviço com seu código.',
                  style: AppType.bodySm.copyWith(color: tk.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s20),
          AppButton(
            label: 'Adicionar ${Money.brl(missing)} agora  ➔',
            onPressed: () async {
              final topped = await Navigator.of(context).push<bool>(
                AppRoute(builder: (_) => AdicionarSaldoScreen(suggestedCents: missing)),
              );
              if (context.mounted) Navigator.of(context).pop(topped == true);
            },
          ),
          const SizedBox(height: AppSpace.s8),
          AppButton(
            label: 'Agora não',
            variant: AppButtonVariant.tertiary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppType.caption.copyWith(color: tk.textMuted),
        ),
        const SizedBox(height: AppSpace.s4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: AppType.tabular(highlight ? AppType.figureSm : AppType.titleSm).copyWith(
            color: color,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        margin: const EdgeInsets.symmetric(horizontal: AppSpace.s8, vertical: AppSpace.s4),
        color: color,
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/wallet_models.dart';
import '../../../core/state/wallet_providers.dart';
import '../../../core/ui/design_system/design_system.dart';
import 'insufficient_funds_sheet.dart';

/// Forma de pagamento = SALDO DA CARTEIRA. Mostra o saldo, o quanto sobra e, se não
/// bastar, avisa antes (a trava de verdade é o `INSUFFICIENT_FUNDS` do servidor).
class WalletPayCard extends ConsumerWidget {
  const WalletPayCard({super.key, required this.priceCents});

  final int priceCents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final wallet = ref.watch(walletProvider);
    final available = wallet.value?.availableCents;
    final check = available == null
        ? null
        : FundsCheck.evaluate(requiredCents: priceCents, availableCents: available);
    final ok = check?.sufficient ?? true;
    return AppCard(
      variant: AppCardVariant.tonal,
      color: ok ? tk.successSoft : tk.warningSoft,
      borderColor: (ok ? tk.success : tk.warning).withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    color: ok ? tk.successInk : tk.warningInk,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Flexible(
                    child: Text(
                      'Pagar com saldo da carteira',
                      style: AppType.titleSm.copyWith(color: tk.text),
                    ),
                  ),
                ],
              ),
              if (ok)
                const AppStatusChip(
                  'Pagamento protegido',
                  tone: AppTone.success,
                  icon: Icons.verified_user_rounded,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          if (available == null)
            const AppSkeletonText(lines: 3, lineHeight: 14)
          else ...[
            _Line('Saldo disponível', Money.brl(available)),
            _Line('Este serviço', '- ${Money.brl(priceCents)}'),
            Divider(height: AppSpace.s16, color: tk.border),
            _Line(
              ok ? 'Saldo depois' : 'Faltam',
              ok ? Money.brl(available - priceCents) : Money.brl(check!.missingCents),
              strong: true,
              color: ok ? tk.text : tk.dangerInk,
            ),
          ],
          const SizedBox(height: AppSpace.s8),
          Text(
            ok
                ? 'O valor fica protegido em garantia e só é liberado ao profissional quando você aprovar com seu código.'
                : 'Ao confirmar, você poderá adicionar o que falta por Pix e continuar.',
            style: AppType.caption.copyWith(color: tk.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.strong = false, this.color});

  final String label;
  final String value;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppInfoRow(
      label: label,
      strong: strong,
      valueWidget: Text(
        value,
        style: AppType.tabular(strong ? AppType.titleSm : AppType.bodySm).copyWith(
          fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
          color: color ?? tk.text,
        ),
      ),
    );
  }
}

/// Garante saldo ANTES de criar/pagar o pedido. Se faltar, abre a trava e, se o usuário
/// recarregar, confere de novo. `true` = pode seguir.
Future<bool> ensureFunds(BuildContext context, int requiredCents) async {
  final service = ProviderScope.containerOf(context).read(walletServiceProvider);
  final wallet = await service.wallet();
  final check = FundsCheck.evaluate(
    requiredCents: requiredCents,
    availableCents: wallet.availableCents,
  );
  if (check.sufficient) return true;
  if (!context.mounted) return false;
  final topped = await showInsufficientFundsSheet(
    context,
    requiredCents: requiredCents,
    availableCents: wallet.availableCents,
  );
  if (!topped) return false;
  final after = await service.wallet();
  return after.availableCents >= requiredCents;
}

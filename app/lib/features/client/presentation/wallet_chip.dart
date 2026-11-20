import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/wallet_models.dart';
import '../../../core/state/privacy_mode.dart';
import '../../../core/state/wallet_providers.dart';
import '../../../core/ui/design_system/design_system.dart';
import 'carteira_cliente_screen.dart';

/// Pílula do cabeçalho do cliente: saldo disponível (respeita o modo privacidade) e atalho
/// para a Carteira. Atualiza em tempo real.
class WalletChip extends ConsumerWidget {
  const WalletChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final cents = ref.watch(walletProvider).value?.availableCents;
    PrivacyMode.instance.ensureLoaded();
    return ValueListenableBuilder<bool>(
      valueListenable: PrivacyMode.instance.hidden,
      builder: (context, hidden, _) => Center(
        child: AppPressable(
          semanticLabel: 'Minha carteira',
          borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
          onTap: () => Navigator.of(context).push(
            AppRoute(builder: (_) => const CarteiraClienteScreen()),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppGeometry.minTarget),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s12,
                  vertical: AppSpace.s8,
                ),
                decoration: BoxDecoration(
                  color: tk.clientSoft,
                  borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                  border: Border.all(color: tk.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 18,
                      color: tk.clientAccentInk,
                    ),
                    const SizedBox(width: AppSpace.s8),
                    if (cents == null)
                      const AppSkeleton(width: 56, height: 14, radius: 6)
                    else if (hidden)
                      Text(
                        PrivacyMode.money(Money.brl(cents), hidden: true),
                        style: AppType.tabular(AppType.bodySm).copyWith(
                          fontWeight: FontWeight.w700,
                          color: tk.text,
                        ),
                      )
                    else
                      AppCountText(
                        value: cents / 100,
                        format: (v) => Money.brl((v * 100).round()),
                        style: AppType.bodySm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tk.text,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

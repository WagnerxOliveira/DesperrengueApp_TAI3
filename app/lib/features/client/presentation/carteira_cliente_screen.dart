import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/wallet_models.dart';
import '../../../core/state/privacy_mode.dart';
import '../../../core/state/wallet_providers.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/widgets.dart' show BannerTone, InfoBanner;
import '../../../core/utils/format.dart';
import 'adicionar_saldo_screen.dart';

/// Carteira do cliente: saldo disponível, valor protegido em custódia e extrato em tempo real.
class CarteiraClienteScreen extends ConsumerStatefulWidget {
  const CarteiraClienteScreen({super.key});

  @override
  ConsumerState<CarteiraClienteScreen> createState() => _CarteiraClienteScreenState();
}

class _CarteiraClienteScreenState extends ConsumerState<CarteiraClienteScreen> {
  @override
  void initState() {
    super.initState();
    PrivacyMode.instance.ensureLoaded();
  }

  void _explainEscrow() {
    AppSheet.show<void>(
      context,
      title: 'Valor protegido em custódia',
      builder: (ctx) {
        final tk = ctx.tk;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(shape: BoxShape.circle, color: tk.successSoft),
              child: Icon(Icons.verified_user_rounded, size: 30, color: tk.successInk),
            ),
            const SizedBox(height: AppSpace.s12),
            const AppStatusChip(
              'Pagamento protegido',
              tone: AppTone.success,
              icon: Icons.verified_user_rounded,
            ),
            const SizedBox(height: AppSpace.s12),
            Text(
              'É o dinheiro dos serviços em andamento. Ele fica guardado com segurança e só vai para o profissional quando o serviço termina e você confirma com seu código. Se o pedido for cancelado antes, o valor volta para o seu saldo.',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: tk.textMuted),
            ),
          ],
        );
      },
      actions: [
        Builder(
          builder: (ctx) => AppButton(
            label: 'Entendi',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final statement = ref.watch(statementProvider);
    final margin = context.layout.margin;
    return AppScaffold(
      appBar: const AppAppBar(title: 'Minha carteira'),
      body: ValueListenableBuilder<bool>(
        valueListenable: PrivacyMode.instance.hidden,
        builder: (context, hidden, _) => ListView(
          padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s32),
          children: [
            _HeroCard(
              wallet: wallet.value ?? ClientWallet.empty,
              loading: wallet.isLoading && !wallet.hasValue,
              hidden: hidden,
              onToggle: PrivacyMode.instance.toggle,
              onEscrow: _explainEscrow,
              onAdd: () => Navigator.of(context).push(
                AppRoute(builder: (_) => const AdicionarSaldoScreen()),
              ),
            ),
            if (wallet.hasError)
              const Padding(
                padding: EdgeInsets.only(top: AppSpace.s12),
                child: InfoBanner(
                  'Não foi possível atualizar o saldo agora.',
                  tone: BannerTone.warning,
                ),
              ),
            const SizedBox(height: AppSpace.section),
            AppSection(
              title: 'Extrato',
              child: AppSkeletonSwitcher(
                loading: statement.isLoading && !statement.hasValue,
                skeleton: const AppSkeletonList(
                  count: 4,
                  padding: EdgeInsets.zero,
                ),
                child: statement.when(
                  loading: () => const AppSkeletonList(
                    count: 4,
                    padding: EdgeInsets.zero,
                  ),
                  error: (_, _) => const AppErrorState(
                    message: 'Não foi possível carregar o extrato.',
                    padding: EdgeInsets.symmetric(vertical: AppSpace.s24),
                  ),
                  data: (items) => items.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.receipt_long_rounded,
                          title: 'Nenhuma movimentação ainda',
                          message: 'Recargas, reservas e estornos aparecem aqui.',
                          padding: EdgeInsets.symmetric(vertical: AppSpace.s24),
                        )
                      : AppCard(
                          variant: AppCardVariant.outlined,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s16,
                            vertical: AppSpace.s8,
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < items.length; i++) ...[
                                if (i > 0) Divider(height: 1, color: context.tk.border),
                                AppStaggerItem(
                                  index: i,
                                  scope: 'wallet-statement',
                                  child: EntryTile(entry: items[i], hidden: hidden),
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.wallet,
    required this.loading,
    required this.hidden,
    required this.onToggle,
    required this.onEscrow,
    required this.onAdd,
  });

  final ClientWallet wallet;
  final bool loading;
  final bool hidden;
  final VoidCallback onToggle;
  final VoidCallback onEscrow;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    String m(int c) => PrivacyMode.money(Money.brl(c), hidden: hidden);
    return AppCard(
      variant: AppCardVariant.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Saldo disponível',
                  style: AppType.bodySm.copyWith(color: tk.textMuted),
                ),
              ),
              AppIconButton(
                tooltip: hidden ? 'Mostrar valores' : 'Ocultar valores',
                onPressed: onToggle,
                color: tk.textMuted,
                icon: hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          AppSkeletonSwitcher(
            loading: loading,
            skeleton: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpace.s8),
              child: AppSkeleton(width: 190, height: 34, radius: 10),
            ),
            child: hidden
                ? Text(
                    m(wallet.availableCents),
                    style: AppType.figureXl.copyWith(color: tk.text),
                  )
                : AppCountText(
                    value: wallet.availableCents / 100,
                    format: (v) => Money.brl((v * 100).round()),
                    style: AppType.figureXl.copyWith(color: tk.text),
                  ),
          ),
          const SizedBox(height: AppSpace.s12),
          AppPressable(
            onTap: onEscrow,
            borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
            semanticLabel: 'Saiba mais sobre valor protegido em custódia',
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s12,
                vertical: AppSpace.s12,
              ),
              decoration: BoxDecoration(
                color: tk.successSoft,
                borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
                border: Border.all(color: tk.success.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user_rounded, size: 18, color: tk.successInk),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Text(
                      'Valor protegido em custódia: ${m(wallet.escrowCents)}',
                      style: AppType.tabular(AppType.caption).copyWith(
                        fontWeight: FontWeight.w600,
                        color: tk.successInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Icon(Icons.info_outline_rounded, size: 16, color: tk.successInk),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s20),
          AppButton(
            label: 'Adicionar saldo',
            icon: Icons.add_rounded,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

/// Linha do extrato com ícone semântico (recarga · retido · liberado · estorno).
class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry, required this.hidden});

  final WalletEntry entry;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final (IconData icon, Color iconColor, Color bgColor) = switch (entry.kind) {
      WalletEntryKind.topup => (Icons.add_circle_rounded, tk.successInk, tk.successSoft),
      WalletEntryKind.seed => (Icons.card_giftcard_rounded, tk.info, tk.infoSoft),
      WalletEntryKind.hold => (Icons.lock_rounded, tk.warningInk, tk.warningSoft),
      WalletEntryKind.release => (Icons.check_circle_rounded, tk.info, tk.infoSoft),
      WalletEntryKind.refund => (Icons.sync_rounded, tk.successInk, tk.successSoft),
    };
    final cents = entry.displayCents;
    final positive = entry.deltaAvailableCents > 0;
    final amount = entry.informational
        ? Money.brl(cents)
        : '${positive ? '+' : '-'} ${Money.brl(cents.abs())}';
    final amountColor = entry.informational
        ? tk.textMuted
        : (positive ? tk.successInk : tk.text);
    final stack = context.layout.isLargeText;
    final amountWidget = Column(
      crossAxisAlignment: stack ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          hidden ? 'R\$ •••••' : amount,
          style: AppType.tabular(AppType.bodyStrong).copyWith(
            fontWeight: FontWeight.w700,
            color: amountColor,
          ),
        ),
        if (entry.informational)
          Text(
            'Concluído',
            style: AppType.caption.copyWith(color: tk.textMuted),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppGeometry.iconTileSize,
            height: AppGeometry.iconTileSize,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: AppType.bodyStrong.copyWith(color: tk.text),
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  dateShort(entry.createdAt),
                  style: AppType.caption.copyWith(color: tk.textMuted),
                ),
                if (stack) ...[
                  const SizedBox(height: AppSpace.s4),
                  amountWidget,
                ],
              ],
            ),
          ),
          if (!stack) ...[
            const SizedBox(width: AppSpace.s12),
            amountWidget,
          ],
        ],
      ),
    );
  }
}

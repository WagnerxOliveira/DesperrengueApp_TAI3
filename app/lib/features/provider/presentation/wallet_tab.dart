import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/state/privacy_mode.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../shared/presentation/support_screens.dart';
import 'dossie_servico_profissional_screen.dart';
import 'pix_withdraw_screen.dart';
import 'provider_job_screen.dart';

/// Dados da carteira: pagamentos, serviços (por id) e total já sacado.
typedef WalletData = (List<Payment>, Map<String, Job>, double);

/// Carteira Bipartida do profissional (`PDF 2 Seção 5.3`):
/// - Saldo disponível para PIX Imediato
/// - Saldo Garantido em Maturação (D+5 / D+2 Âncora) e Custódia (Escrow)
/// - Circuit Breaker Preventivo (`RN-AF-08`) quando há mediação ativa
/// - Desempenho semanal e últimos serviços.
class WalletTab extends StatefulWidget {
  /// [loader] só é usado em testes (fake sem rede); em produção fica null.
  const WalletTab({super.key, this.loader});

  final Future<WalletData> Function()? loader;

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  ProviderService? _providersOrNull;
  ProviderService get _providers => _providersOrNull ??= ProviderService();
  JobService? _jobsOrNull;
  JobService get _jobs => _jobsOrNull ??= JobService();
  late Future<WalletData> _future = _load();

  bool get _hidden => PrivacyMode.instance.hidden.value;

  void _onPrivacy() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    PrivacyMode.instance.ensureLoaded();
    PrivacyMode.instance.hidden.addListener(_onPrivacy);
  }

  @override
  void dispose() {
    PrivacyMode.instance.hidden.removeListener(_onPrivacy);
    super.dispose();
  }

  Future<WalletData> _load() async {
    final custom = widget.loader;
    if (custom != null) return custom();
    final payments = await _providers.myPayments();
    final jobs = await _jobs.providerJobs();
    final withdrawn = await _providers.myWithdrawnTotal();
    return (payments, {for (final j in jobs) j.id: j}, withdrawn);
  }

  Future<void> _openPix(double available, {bool hasOpenDispute = false}) async {
    if (available <= 0) {
      AppSnackbar.show(context, 'Você não tem saldo disponível para transferir.');
      return;
    }
    final done = await Navigator.of(context).push<bool>(
      AppRoute(
        builder: (_) => PixWithdrawScreen(
          available: available,
          hasOpenDispute: hasOpenDispute,
        ),
      ),
    );
    if (done == true) _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  void _soon(String what) => AppSnackbar.show(
        context,
        '$what chega em breve. No MVP os repasses são simulados.',
      );

  void _openDossier(String jobId) {
    Navigator.of(context).push(
      AppRoute<void>(
        builder: (_) => DossieServicoProfissionalScreen(jobId: jobId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(bottom: false, child: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<WalletData>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(
              children: [
                AppErrorState(
                  message: 'Não foi possível carregar a carteira.',
                  onRetry: _refresh,
                ),
              ],
            );
          }
          final loading = !snap.hasData;
          final data = snap.data;
          final Widget content;
          if (data == null) {
            content = const SizedBox.shrink();
          } else {
            final (payments, jobs, withdrawn) = data;
            final w = ProviderService.summarize(payments, withdrawn: withdrawn);
            final upcoming = payments.where((p) => p.status == 'escrow').toList();
            final done = payments.where((p) => p.status == 'released').toList();
            final hasOpenDispute =
                jobs.values.any((j) => j.status == JobStatus.disputed);

            final heroStart = tk.isDark ? tk.providerSoft : tk.providerAccent;
            final heroEnd = tk.isDark ? tk.surfaceAt(4) : tk.brand;
            final heroFg = tk.isDark ? tk.text : AppTokens.onColor(heroStart);
            final heroMuted = tk.isDark ? tk.textMuted : heroFg.withValues(alpha: 0.84);
            final heroBadgeBg = tk.isDark
                ? tk.card.withValues(alpha: 0.6)
                : heroFg.withValues(alpha: 0.14);

            content = ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(margin, AppSpace.s16, margin, AppSpace.s24),
              children: [
                Text(
                  'Carteira',
                  style: AppType.display.copyWith(color: tk.text),
                ),
                const SizedBox(height: AppSpace.s16),
                if (hasOpenDispute)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpace.s12),
                    child: InfoBanner(
                      'Há um chamado de garantia em análise técnica. O valor deste serviço permanece protegido em custódia até a conclusão da mediação.',
                      tone: BannerTone.warning,
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(AppSpace.cardLarge),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppGeometry.heroRadius),
                    border: tk.isDark
                        ? Border.all(color: tk.providerAccent.withValues(alpha: 0.3))
                        : null,
                    boxShadow: tk.elevation(2),
                    gradient: LinearGradient(
                      colors: [heroStart, heroEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Saldo disponível',
                              style: AppType.bodySm.copyWith(color: heroMuted),
                            ),
                          ),
                          AppIconButton(
                            onPressed: PrivacyMode.instance.toggle,
                            tooltip: _hidden ? 'Mostrar valores' : 'Ocultar valores',
                            icon: _hidden
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: heroMuted,
                          ),
                        ],
                      ),
                      if (_hidden)
                        Text(
                          PrivacyMode.mask,
                          style: AppType.figureXl.copyWith(color: heroFg),
                        )
                      else
                        AppCountText(
                          value: w.available,
                          format: brl,
                          style: AppType.figureXl.copyWith(color: heroFg),
                        ),
                      const SizedBox(height: AppSpace.s8),
                      Text(
                        'Em custódia: ${_hidden ? '•••' : brl(w.held)}',
                        style: AppType.tabular(AppType.bodySm).copyWith(color: heroMuted),
                      ),
                      const SizedBox(height: AppSpace.s12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s12,
                          vertical: AppSpace.s8,
                        ),
                        decoration: BoxDecoration(
                          color: heroBadgeBg,
                          borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 16,
                              color: heroFg,
                            ),
                            const SizedBox(width: AppSpace.s8),
                            Expanded(
                              child: Text(
                                'Pagamento protegido pela plataforma • 0% de taxa sobre peças e materiais',
                                style: AppType.caption.copyWith(
                                  color: heroFg,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s16),
                Row(
                  children: [
                    Expanded(
                      child: _Shortcut(
                        icon: Icons.pix_rounded,
                        label: 'Pix',
                        onTap: () => _openPix(
                          w.available,
                          hasOpenDispute: hasOpenDispute,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: _Shortcut(
                        icon: Icons.receipt_long_rounded,
                        label: 'Extrato',
                        onTap: () => _soon('O extrato detalhado'),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: _Shortcut(
                        icon: Icons.account_balance_rounded,
                        label: 'Dados bancários',
                        onTap: () => _soon('O cadastro bancário'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.section),
                AppSection(
                  title: 'Próximos lançamentos',
                  child: upcoming.isEmpty
                      ? Text(
                          'Nenhum valor em custódia no momento.',
                          style: AppType.bodySm.copyWith(color: tk.textMuted),
                        )
                      : Column(
                          children: [
                            for (final p in upcoming)
                              Builder(
                                builder: (context) {
                                  final job = jobs[p.jobId];
                                  final disputed = job?.status == JobStatus.disputed;
                                  return AppCard(
                                    variant: AppCardVariant.outlined,
                                    margin: const EdgeInsets.only(bottom: AppSpace.s12),
                                    onTap: () => Navigator.of(context).push(
                                      AppRoute<void>(
                                        builder: (_) => ProviderJobScreen(jobId: p.jobId),
                                      ),
                                    ),
                                    color: disputed ? tk.warningSoft : tk.card,
                                    borderColor: disputed ? tk.warning : tk.border,
                                    child: Row(
                                      children: [
                                        Icon(
                                          disputed
                                              ? Icons.warning_amber_rounded
                                              : Icons.lock_clock_rounded,
                                          color: disputed
                                              ? tk.warningInk
                                              : tk.successInk,
                                        ),
                                        const SizedBox(width: AppSpace.s12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                job?.title ?? 'Serviço',
                                                maxLines: 2,
                                                style: AppType.bodyStrong.copyWith(color: tk.text),
                                              ),
                                              const SizedBox(height: AppSpace.s2),
                                              Text(
                                                disputed
                                                    ? 'Em mediação • Toque para abrir'
                                                    : 'Libera na conclusão (PIN do cliente)',
                                                style: AppType.caption.copyWith(color: tk.textMuted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: AppSpace.s8),
                                        Text(
                                          PrivacyMode.money(brl(p.netAmount), hidden: _hidden),
                                          style: AppType.tabular(AppType.bodyStrong).copyWith(
                                            color: disputed ? tk.warningInk : tk.successInk,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpace.s4),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 18,
                                          color: tk.textMuted,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: AppSpace.section),
                AppSection(
                  title: 'Desempenho da semana',
                  child: AppCard(
                    variant: AppCardVariant.elevated,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Você já faturou',
                                style: AppType.bodySm.copyWith(color: tk.textMuted),
                              ),
                              const SizedBox(height: AppSpace.s4),
                              if (_hidden)
                                Text(
                                  PrivacyMode.mask,
                                  style: AppType.figure.copyWith(color: tk.successInk),
                                )
                              else
                                AppCountText(
                                  value: w.week,
                                  format: brl,
                                  style: AppType.figure.copyWith(color: tk.successInk),
                                ),
                              const SizedBox(height: AppSpace.s4),
                              Text(
                                'nesta semana',
                                style: AppType.bodySm.copyWith(color: tk.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpace.s8),
                        _WeekBars(values: w.perDay),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.section),
                AppSection(
                  title: 'Últimos serviços realizados',
                  child: done.isEmpty
                      ? Text(
                          'Seus serviços concluídos aparecerão aqui.',
                          style: AppType.bodySm.copyWith(color: tk.textMuted),
                        )
                      : Column(
                          children: [
                            for (final p in done.take(10))
                              AppListTile(
                                padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                                onTap: () => _openDossier(p.jobId),
                                leadingIcon: Icons.check_rounded,
                                leadingColor: tk.successInk,
                                title: jobs[p.jobId]?.title ?? 'Serviço',
                                subtitle: dateShort(p.releasedAt ?? p.createdAt),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _hidden ? PrivacyMode.mask : '+ ${brl(p.netAmount)}',
                                      style: AppType.tabular(AppType.bodyStrong).copyWith(
                                        color: tk.successInk,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpace.s4),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: tk.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: AppSpace.s12),
                Center(
                  child: AppButton(
                    label: 'Problemas com seus repasses? Fale com a central.',
                    variant: AppButtonVariant.tertiary,
                    expand: false,
                    onPressed: () => Navigator.of(context).push(
                      AppRoute(
                        builder: (_) => const SupportCenterScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return AppSkeletonSwitcher(
            loading: loading,
            skeleton: const AppSkeletonList(count: 4),
            child: content,
          );
        },
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s8),
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: tk.providerSoft,
              child: Icon(icon, color: tk.accentInk),
            ),
            const SizedBox(height: AppSpace.s8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(fontWeight: FontWeight.w600, color: tk.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final max = values.fold<double>(0, (a, b) => b > a ? b : a);
    const labels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 7; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : AppSpace.s4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 12,
                  height: max == 0 ? 4 : (4 + 54 * (values[i] / max)),
                  decoration: BoxDecoration(
                    color: values[i] > 0 ? tk.accent : tk.border,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  labels[i],
                  style: AppType.caption.copyWith(color: tk.textMuted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

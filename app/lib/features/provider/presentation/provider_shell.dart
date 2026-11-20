import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/app_version_and_update_service.dart';
import '../../../core/services/instant_image_cache_engine.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/state/privacy_mode.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/job_labels.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../shared/presentation/achievement_widgets.dart';
import '../../shared/presentation/delete_account_screen.dart';
import '../../shared/presentation/geo_privacy_widgets.dart';
import '../../shared/presentation/notifications_screen.dart';
import '../../shared/presentation/profile_photo_viewer.dart';
import '../../shared/presentation/support_screens.dart';
import '../../shared/presentation/theme_picker.dart';
import 'provider_job_screen.dart';
import 'provider_portfolio_widgets.dart';
import 'provider_profile_screens.dart';
import 'wallet_tab.dart';

void openProviderJob(BuildContext context, String jobId) {
  Navigator.of(context).push(
    AppRoute(
      settings: const RouteSettings(name: 'provider_job'),
      builder: (_) => ProviderJobScreen(jobId: jobId),
    ),
  );
}

/// Dados do painel do profissional (exportado para injeção opcional em testes).
@visibleForTesting
class ProviderDashboardData {
  const ProviderDashboardData({
    required this.jobs,
    required this.invites,
    required this.quotes,
    required this.wallet,
    required this.row,
  });

  final List<Job> jobs;
  final List<({JobInvite invite, Job job})> invites;
  final List<({Quote quote, Job? job})> quotes;
  final WalletSummary wallet;
  final Map<String, dynamic>? row;
}

/// Casca do modo PROFISSIONAL: Painel / Oportunidades / Carteira / Perfil.
class ProviderShell extends StatefulWidget {
  const ProviderShell({
    super.key,
    required this.profile,
    this.dashboardLoader,
    this.walletLoader,
  });

  final UserProfile profile;

  /// Ganchos opcionais para testes (padrão `null`, zero impacto em produção).
  final Future<ProviderDashboardData> Function()? dashboardLoader;
  final Future<WalletData> Function()? walletLoader;

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: AppMotion.tabSwitch,
    value: 1.0,
  );

  @override
  void dispose() {
    _tabFade.dispose();
    super.dispose();
  }

  void _selectTab(int next) {
    if (next == _index) return;
    setState(() => _index = next);
    if (AppMotion.reduced(context)) {
      _tabFade.value = 1.0;
    } else {
      _tabFade
        ..duration = AppMotion.tabSwitch
        ..forward(from: 0.35);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final pages = [
      ProviderDashboardTab(
        profile: widget.profile,
        onSeeOpportunities: () => _selectTab(1),
        onSeeWallet: () => _selectTab(2),
        loader: widget.dashboardLoader,
      ),
      const OpportunitiesTab(),
      WalletTab(loader: widget.walletLoader),
      ProviderProfileTab(profile: widget.profile),
    ];
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selectTab(0);
      },
      child: AppScaffold(
        body: SafeArea(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _tabFade, curve: AppMotion.fadeCurve),
            child: IndexedStack(index: _index, children: pages),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _selectTab,
          animationDuration: AppMotion.d(context, const Duration(milliseconds: 180)),
          backgroundColor: tk.card,
          indicatorColor: tk.providerSoft,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: _NavSelectedIcon(Icons.dashboard_rounded),
              label: 'Painel',
            ),
            NavigationDestination(
              icon: Icon(Icons.travel_explore_outlined),
              selectedIcon: _NavSelectedIcon(Icons.travel_explore_rounded),
              label: 'Oportunidades',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: _NavSelectedIcon(Icons.account_balance_wallet_rounded),
              label: 'Carteira',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: _NavSelectedIcon(Icons.person_rounded),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

/// Micro-pop de 120 ms no ícone selecionado da barra de navegação.
class _NavSelectedIcon extends StatelessWidget {
  const _NavSelectedIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    if (reduced) return Icon(icon);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.86, end: 1.0),
      duration: AppMotion.fadeShort,
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Icon(icon),
    );
  }
}

// ===================================================================== painel

class ProviderDashboardTab extends StatefulWidget {
  const ProviderDashboardTab({
    super.key,
    required this.profile,
    required this.onSeeOpportunities,
    required this.onSeeWallet,
    this.loader,
  });

  final UserProfile profile;
  final VoidCallback onSeeOpportunities;
  final VoidCallback onSeeWallet;

  /// Gancho opcional para testes (padrão `null`, zero impacto em produção).
  final Future<ProviderDashboardData> Function()? loader;

  @override
  State<ProviderDashboardTab> createState() => _ProviderDashboardTabState();
}

class _ProviderDashboardTabState extends State<ProviderDashboardTab> {
  JobService? _jobsOrNull;
  JobService get _jobs => _jobsOrNull ??= JobService();
  ProviderService? _providersOrNull;
  ProviderService get _providers => _providersOrNull ??= ProviderService();
  late Future<ProviderDashboardData> _future = _load();
  Timer? _timer;
  bool? _online;
  double _weeklyGoal = 2000.0;

  @override
  void initState() {
    super.initState();
    PrivacyMode.instance.ensureLoaded();
    EagerImagePrefetcher.prefetchUrls([widget.profile.avatarUrl]);
    if (widget.loader == null) {
      _timer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (mounted) {
          setState(() {
            _future = _load();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<ProviderDashboardData> _load() async {
    final custom = widget.loader;
    if (custom != null) return custom();
    final r = await Future.wait<Object?>([
      _jobs.providerJobs(),
      _jobs.myLiveInvites(),
      _jobs.myPendingQuotes(),
      _providers.myPayments(),
      _providers.myProviderRow(),
      _providers.myWithdrawnTotal(),
    ]);
    final jobs = r[0] as List<Job>;
    final invites = r[1] as List<({JobInvite invite, Job job})>;
    final quotes = r[2] as List<({Quote quote, Job? job})>;
    EagerImagePrefetcher.prefetchJobs([
      ...jobs,
      ...invites.map((i) => i.job),
      ...quotes.map((q) => q.job).whereType<Job>(),
    ]);
    return ProviderDashboardData(
      jobs: jobs,
      invites: invites,
      quotes: quotes,
      wallet: ProviderService.summarize(r[3] as List<Payment>, withdrawn: r[5] as double),
      row: r[4] as Map<String, dynamic>?,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _toggleOnline(bool v) async {
    setState(() => _online = v);
    try {
      await _providers.saveProviderProfile(acceptingJobs: v);
    } catch (e) {
      if (mounted) {
        setState(() => _online = !v);
        AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
      }
    }
  }

  Future<void> _showSmartSplitCalculatorSheet(BuildContext context) => AppSheet.show<void>(
        context,
        builder: (_) => const EarningsSimulatorSheet(),
      );

  Future<void> _showWeeklyGoalDialog(BuildContext context) async {
    final ctrl = TextEditingController(text: _weeklyGoal.toStringAsFixed(0));
    String? error;
    final nextGoal = await AppDialog.show<double>(
      context,
      title: 'Definir meta da semana',
      content: StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          void submit() {
            final v = parseBrl(ctrl.text);
            if (v == null || v < 100) {
              setDialogState(() => error = 'Informe um valor a partir de R\$ 100.');
              return;
            }
            Navigator.pop(dialogCtx, v);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: ctrl,
                autofocus: !AppMotion.reduced(dialogCtx),
                label: 'Meta de ganhos na semana (R\$)',
                errorText: error,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  if (error != null) setDialogState(() => error = null);
                },
                onSubmitted: (_) => submit(),
              ),
              const SizedBox(height: AppSpace.s16),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancelar',
                      variant: AppButtonVariant.secondary,
                      compact: true,
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: AppButton(
                      label: 'Salvar meta',
                      compact: true,
                      onPressed: submit,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    ctrl.dispose();
    if (nextGoal != null && mounted) {
      setState(() => _weeklyGoal = nextGoal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<ProviderDashboardData>(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          final online = _online ?? (d?.row?['accepting_jobs'] != false);
          final radiusKm = (d?.row?['service_radius_km'] as num?)?.toInt() ?? 15;
          final active = d?.jobs
                  .where((j) =>
                      j.status == JobStatus.scheduled ||
                      j.status == JobStatus.inProgress ||
                      j.status == JobStatus.awaitingApproval ||
                      j.status == JobStatus.awaitingPayment ||
                      j.status == JobStatus.disputed)
                  .toList() ??
              const <Job>[];

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s24),
            children: [
              // ===============================================================
              // 1. HEADER LIMPO E HUMANO + PRIVACIDADE + NOTIFICAÇÕES
              // ===============================================================
              Row(
                children: [
                  AppIconButton(
                    tooltip: 'Voltar à seleção de perfil',
                    onPressed: AppSession.instance.switchMode,
                    icon: Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: tk.text,
                  ),
                  AppAvatar(url: widget.profile.avatarUrl, name: widget.profile.displayName, radius: 24, verified: true),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Olá, ${widget.profile.firstName}',
                          maxLines: 2,
                          style: AppType.headline.copyWith(color: tk.accentInk),
                        ),
                        Row(
                          children: [
                            Icon(Icons.verified_rounded, size: 15, color: tk.successInk),
                            const SizedBox(width: AppSpace.s4),
                            Flexible(
                              child: Text(
                                'Profissional verificado',
                                style: AppType.caption.copyWith(color: tk.textMuted, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: PrivacyMode.instance.hidden,
                    builder: (context, hidden, _) => AppIconButton(
                      key: const ValueKey('btn-toggle-privacy-mode'),
                      tooltip: hidden ? 'Mostrar valores' : 'Ocultar valores',
                      onPressed: PrivacyMode.instance.toggle,
                      icon: hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: tk.textMuted,
                    ),
                  ),
                  UnreadBell(onOpenJob: (c, id) => openProviderJob(c, id)),
                ],
              ),
              const SizedBox(height: AppSpace.s8),
              const Align(
                alignment: Alignment.centerRight,
                child: AppQuickUpdateButton(compact: true),
              ),
              const SizedBox(height: AppSpace.s8),

              // ===============================================================
              // 2. INTERRUPTOR ÚNICO DE DISPONIBILIDADE (COM MATERIAL EXPLÍCITO)
              // ===============================================================
              Material(
                color: online ? tk.successSoft.withValues(alpha: 0.45) : tk.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
                  side: BorderSide(color: online ? tk.success.withValues(alpha: 0.45) : tk.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s4),
                  value: online,
                  onChanged: _toggleOnline,
                  title: Text(
                    online ? 'Disponível para serviços' : 'Indisponível no momento',
                    style: AppType.bodyStrong.copyWith(color: tk.text),
                  ),
                  subtitle: Text(
                    online
                        ? 'Visível para clientes em até $radiusKm km de você.'
                        : 'Ative quando quiser receber novos chamados na sua região.',
                    style: AppType.caption.copyWith(color: tk.textMuted),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s16),

              if (snap.hasError)
                const InfoBanner('Não foi possível atualizar o painel. Puxe para tentar de novo.', tone: BannerTone.warning),
              if (d == null && !snap.hasError)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpace.s16),
                  child: Column(
                    children: [
                      AppSkeletonCard(height: 92),
                      SizedBox(height: AppSpace.s12),
                      AppSkeletonCard(height: 112),
                    ],
                  ),
                ),
              if (d != null) ...[
                // =============================================================
                // 3. RESUMO FINANCEIRO CLARO + META SEMANAL + SIMULADOR
                // =============================================================
                ValueListenableBuilder<bool>(
                  valueListenable: PrivacyMode.instance.hidden,
                  builder: (context, hidden, _) {
                    String m(double v) => PrivacyMode.money(brl(v), hidden: hidden);
                    final done = (d.row?['jobs_done'] as num?)?.toInt() ?? 0;
                    final rated = ((d.row?['rating_count'] as num?) ?? 0) > 0;
                    final ratingText = rated
                        ? ((d.row?['rating_avg'] as num).toDouble()).toStringAsFixed(1).replaceAll('.', ',')
                        : 'Novo';
                    final goalProgress = (_weeklyGoal <= 0 ? 0.0 : (d.wallet.week / _weeklyGoal)).clamp(0.0, 1.0);
                    final goalPct = (goalProgress * 100).round();

                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _Stat(
                                icon: Icons.account_balance_wallet_rounded,
                                label: 'Disponível para saque',
                                subtitle: 'Livre para transferir via PIX',
                                value: m(d.wallet.available),
                                onTap: widget.onSeeWallet,
                              ),
                            ),
                            const SizedBox(width: AppSpace.s12),
                            Expanded(
                              child: _Stat(
                                icon: Icons.schedule_send_rounded,
                                label: 'Valores a liberar',
                                subtitle: active.isNotEmpty
                                    ? '${active.length} serviço(s) em andamento'
                                    : 'Liberado após conclusão',
                                value: m(d.wallet.held),
                                onTap: widget.onSeeWallet,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.s12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _Stat(
                                icon: Icons.check_circle_rounded,
                                label: 'Serviços concluídos',
                                subtitle: 'Ver histórico completo',
                                value: '$done',
                                onTap: () => ProviderFullHistoryScreen.open(context),
                              ),
                            ),
                            const SizedBox(width: AppSpace.s12),
                            Expanded(
                              child: _Stat(
                                icon: Icons.star_rounded,
                                label: 'Sua avaliação',
                                subtitle: 'Ver avaliações e selos',
                                value: ratingText,
                                valueTrailingIcon: rated ? Icons.star_rounded : null,
                                onTap: () => Navigator.of(context).push(
                                  AppRoute(
                                    builder: (_) => MyReviewsScreen(profile: widget.profile),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.s12),
                        AppCard(
                          variant: AppCardVariant.elevated,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  AppProgressRing(
                                    value: goalProgress,
                                    size: 64,
                                    strokeWidth: 7,
                                    color: tk.success,
                                    semanticLabel: 'Meta da semana',
                                    child: Text(
                                      '$goalPct%',
                                      style: AppType.tabular(AppType.caption).copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: tk.accentInk,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpace.s12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Meta da semana',
                                          style: AppType.titleSm.copyWith(color: tk.text),
                                        ),
                                        const SizedBox(height: AppSpace.s2),
                                        Text(
                                          '${m(d.wallet.week)} de ${m(_weeklyGoal)}',
                                          style: AppType.tabular(AppType.bodyStrong).copyWith(color: tk.accentInk),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AppButton(
                                    key: const ValueKey('btn-edit-weekly-goal'),
                                    label: 'Ajustar',
                                    icon: Icons.tune_rounded,
                                    variant: AppButtonVariant.tertiary,
                                    expand: false,
                                    compact: true,
                                    onPressed: () => _showWeeklyGoalDialog(context),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpace.s12),
                              Text(
                                '0% de taxa sobre peças e materiais informados no orçamento',
                                style: AppType.caption.copyWith(fontWeight: FontWeight.w700, color: tk.successInk),
                              ),
                              const SizedBox(height: AppSpace.s12),
                              AppButton(
                                key: const ValueKey('btn-open-smart-split-calculator'),
                                variant: AppButtonVariant.secondary,
                                compact: true,
                                icon: Icons.calculate_outlined,
                                label: 'Simular ganho de orçamento',
                                onPressed: () => _showSmartSplitCalculatorSheet(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: AppSpace.section),

                // =============================================================
                // 4. OPERAÇÃO EM CAMPO: CHAMADOS, SERVIÇOS E ORÇAMENTOS
                // =============================================================
                if (d.invites.isNotEmpty) ...[
                  AppSection(
                    title: 'Solicitações diretas para você',
                    child: Column(
                      children: [
                        for (final i in d.invites) _InviteTile(job: i.job, invite: i.invite),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.section),
                ],
                if (active.isNotEmpty) ...[
                  AppSection(
                    title: 'Serviços em andamento',
                    child: Column(
                      children: [
                        for (final j in active) _JobTile(job: j, provider: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.section),
                ],
                if (d.quotes.isNotEmpty) ...[
                  AppSection(
                    title: 'Orçamentos aguardando o cliente',
                    child: Column(
                      children: [
                        for (final q in d.quotes)
                          if (q.job != null)
                            AppCard(
                              margin: const EdgeInsets.only(bottom: AppSpace.s12),
                              onTap: () => openProviderJob(context, q.job!.id),
                              child: Row(
                                children: [
                                  Icon(Icons.hourglass_top_rounded, color: tk.accentInk),
                                  const SizedBox(width: AppSpace.s12),
                                  Expanded(
                                    child: Text(
                                      q.job!.title,
                                      maxLines: 2,
                                      style: AppType.bodyStrong.copyWith(color: tk.text),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpace.s8),
                                  Text(
                                    brl(q.quote.price),
                                    style: AppType.tabular(AppType.titleSm).copyWith(color: tk.text),
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
                if (d.invites.isEmpty && active.isEmpty && d.quotes.isEmpty) ...[
                  const SizedBox(height: AppSpace.s12),
                  AppEmptyState(
                    icon: Icons.travel_explore_rounded,
                    title: 'Pronto para o próximo serviço',
                    message: 'Veja os pedidos abertos na sua região e envie seu orçamento gratuito.',
                    actionLabel: 'Buscar novos serviços',
                    onAction: widget.onSeeOpportunities,
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Simulador "quanto sobra no meu bolso": cuida dos próprios campos (sem vazar controladores)
/// e não estoura com teclado aberto nem em telas de 320 px.
@visibleForTesting
class EarningsSimulatorSheet extends StatefulWidget {
  const EarningsSimulatorSheet({super.key});

  @override
  State<EarningsSimulatorSheet> createState() => _EarningsSimulatorSheetState();
}

class _EarningsSimulatorSheetState extends State<EarningsSimulatorSheet> {
  final _labor = TextEditingController(text: '250');
  final _materials = TextEditingController(text: '150');

  @override
  void dispose() {
    _labor.dispose();
    _materials.dispose();
    super.dispose();
  }

  Widget _field(BuildContext context, Key key, TextEditingController c, String label) {
    final tk = context.tk;
    return TextField(
      key: key,
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppType.body.copyWith(color: tk.textMuted),
        floatingLabelStyle: AppType.caption.copyWith(color: tk.textMuted).apply(fontSizeFactor: 1 / 0.75),
        prefixText: 'R\$ ',
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _line(String label, String value, TextStyle style, TextStyle valueStyle) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: AppSpace.s8),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: valueStyle)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final labor = parseBrl(_labor.text) ?? 0.0;
    final materials = parseBrl(_materials.text) ?? 0.0;
    const feeRate = 0.15; // 13,5% intermediação + 1,5% reserva de garantia 90d = 85% líquido
    final platformFee = labor * feeRate;
    final netLabor = (labor - platformFee).clamp(0.0, double.infinity);
    final totalNet = netLabor + materials;
    final savedOnMaterials = materials * feeRate;

    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(AppSpace.s20, AppSpace.s4, AppSpace.s20, MediaQuery.viewInsetsOf(context).bottom + AppSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpace.s12),
                  decoration: BoxDecoration(
                    color: tk.providerSoft,
                    borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
                  ),
                  child: Icon(Icons.calculate_rounded, color: tk.accentInk),
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Simular ganho de orçamento', style: AppType.title.copyWith(color: tk.text)),
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        'Veja quanto sobra livre separando mão de obra e materiais (0% de taxa em peças)',
                        style: AppType.caption.copyWith(color: tk.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s16),
            LayoutBuilder(
              builder: (context, c) {
                final laborField = _field(context, const ValueKey('smart-split-labor-input'), _labor, 'Mão de obra');
                final materialsField = _field(context, const ValueKey('smart-split-materials-input'), _materials, 'Peças e materiais');
                if (c.maxWidth < 300 || context.layout.isLargeText) {
                  return Column(children: [laborField, const SizedBox(height: AppSpace.s12), materialsField]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: laborField), const SizedBox(width: AppSpace.s12), Expanded(child: materialsField)],
                );
              },
            ),
            const SizedBox(height: AppSpace.s16),
            AppCard(
              variant: AppCardVariant.tonal,
              borderColor: tk.accentInk.withValues(alpha: 0.3),
              child: Column(
                children: [
                  _line(
                    'Total do orçamento:',
                    brl(labor + materials),
                    AppType.bodySm.copyWith(color: tk.textMuted),
                    AppType.tabular(AppType.bodyStrong).copyWith(color: tk.text),
                  ),
                  const SizedBox(height: AppSpace.s8),
                  _line(
                    'Peças e materiais (sem taxa):',
                    '+ ${brl(materials)} (100% seu)',
                    AppType.bodySm.copyWith(color: tk.successInk, fontWeight: FontWeight.w600),
                    AppType.tabular(AppType.bodyStrong).copyWith(color: tk.successInk),
                  ),
                  const SizedBox(height: AppSpace.s8),
                  _line(
                    'Economia na taxa de peças:',
                    '+ ${brl(savedOnMaterials)}',
                    AppType.caption.copyWith(color: tk.accentInk, fontWeight: FontWeight.w600),
                    AppType.tabular(AppType.bodyStrong).copyWith(color: tk.accentInk),
                  ),
                  const Divider(height: AppSpace.s20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Você recebe livre no PIX:',
                          style: AppType.bodyStrong.copyWith(color: tk.text),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s8),
                      Flexible(
                        child: Text(
                          brl(totalNet),
                          key: const ValueKey('smart-split-net-result'),
                          textAlign: TextAlign.end,
                          style: AppType.figureSm.copyWith(color: tk.accentInk),
                        ),
                      ),
                    ],
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

/// Meta semanal: valida de verdade (antes, qualquer valor inválido virava R$ 2.000 em silêncio).
@visibleForTesting
class WeeklyGoalDialog extends StatefulWidget {
  const WeeklyGoalDialog({super.key, required this.initial});

  final double initial;

  @override
  State<WeeklyGoalDialog> createState() => _WeeklyGoalDialogState();
}

class _WeeklyGoalDialogState extends State<WeeklyGoalDialog> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initial.toStringAsFixed(0));
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final v = parseBrl(_ctrl.text);
    if (v == null || v < 100) {
      setState(() => _error = 'Informe um valor a partir de R\$ 100.');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final reduced = AppMotion.reduced(context);
    return AlertDialog(
      backgroundColor: tk.surfaceAt(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppGeometry.cardRadius)),
      title: Text('Definir meta da semana', style: AppType.title.copyWith(color: tk.text)),
      content: TextField(
        controller: _ctrl,
        autofocus: !reduced,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: 'Meta de ganhos na semana',
          labelStyle: AppType.body.copyWith(color: tk.textMuted),
          floatingLabelStyle: AppType.caption.copyWith(color: tk.textMuted).apply(fontSizeFactor: 1 / 0.75),
          prefixText: 'R\$ ',
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        AppButton(
          label: 'Cancelar',
          variant: AppButtonVariant.tertiary,
          expand: false,
          compact: true,
          onPressed: () => Navigator.pop(context),
        ),
        AppButton(
          label: 'Salvar meta',
          expand: false,
          compact: true,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    this.valueTrailingIcon,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final IconData? valueTrailingIcon;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      onTap: onTap,
      variant: AppCardVariant.tonal,
      color: tk.providerSoft,
      borderColor: tk.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tk.accentInk),
          const SizedBox(height: AppSpace.s8),
          Row(
            children: [
              Flexible(
                child: Text(
                  value,
                  style: AppType.figureSm.copyWith(color: tk.accentInk),
                ),
              ),
              if (valueTrailingIcon != null) ...[
                const SizedBox(width: AppSpace.s4),
                Icon(valueTrailingIcon, size: 18, color: tk.star),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          Text(label, style: AppType.caption.copyWith(color: tk.text, fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpace.s2),
            Text(subtitle!, maxLines: 2, style: AppType.caption.copyWith(color: tk.textMuted)),
          ],
        ],
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({required this.job, required this.invite});

  final Job job;
  final JobInvite invite;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final urgent = job.isEmergency;
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpace.s12),
      color: urgent ? tk.dangerSoft : tk.card,
      borderColor: urgent ? tk.danger.withValues(alpha: 0.5) : tk.border,
      onTap: () => openProviderJob(context, job.id),
      child: Row(
        children: [
          CategoryBrandEmblem(categoryName: job.category, size: 44, showCornerBadge: false),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  urgent ? 'Emergência: ${job.title}' : job.title,
                  maxLines: 2,
                  style: AppType.bodyStrong.copyWith(color: tk.text),
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  'Responder em ${clock(invite.remaining)}',
                  style: AppType.tabular(AppType.caption).copyWith(
                    color: urgent ? tk.dangerInk : tk.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: tk.textMuted),
        ],
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job, this.provider = false});

  final Job job;
  final bool provider;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpace.s12),
      onTap: () => openProviderJob(context, job.id),
      child: Row(
        children: [
          CategoryBrandEmblem(categoryName: job.category, size: 44, showCornerBadge: false),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.title,
                  maxLines: 2,
                  style: AppType.bodyStrong.copyWith(color: tk.text),
                ),
                const SizedBox(height: AppSpace.s4),
                JobStatusChip(job, provider: provider),
              ],
            ),
          ),
          if (job.agreedPrice != null) ...[
            const SizedBox(width: AppSpace.s8),
            Text(
              brl(job.agreedPrice),
              style: AppType.tabular(AppType.titleSm).copyWith(color: tk.text),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================== oportunidades

class OpportunitiesTab extends StatefulWidget {
  const OpportunitiesTab({super.key});

  @override
  State<OpportunitiesTab> createState() => _OpportunitiesTabState();
}

class _OpportunitiesTabState extends State<OpportunitiesTab> {
  final _jobs = JobService();
  late Future<(List<({JobInvite invite, Job job})>, List<Job>)> _future = _load();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() {
          _future = _load();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<(List<({JobInvite invite, Job job})>, List<Job>)> _load() async {
    final row = await ProviderService().myProviderRow();
    final specialties = ((row?['specialties'] as List?) ?? const []).cast<String>();
    final invites = await _jobs.myLiveInvites();
    final feed = await _jobs.openFeed(specialties: specialties);
    return (invites, feed);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<(List<({JobInvite invite, Job job})>, List<Job>)>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(
              children: [
                AppErrorState(
                  message: 'Não foi possível carregar as oportunidades.',
                  onRetry: _refresh,
                ),
              ],
            );
          }
          if (!snap.hasData) return const AppSkeletonList(count: 4);
          final (invites, feed) = snap.data!;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(margin, AppSpace.s12, margin, AppSpace.s24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Oportunidades',
                      style: AppType.display.copyWith(color: tk.text),
                    ),
                  ),
                  AppIconButton(
                    tooltip: 'Atualizar oportunidades',
                    onPressed: _refresh,
                    icon: Icons.refresh_rounded,
                    color: tk.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s4),
              Text(
                'Serviços próximos que combinam com suas especialidades.',
                style: AppType.bodySm.copyWith(color: tk.textMuted),
              ),
              const SizedBox(height: AppSpace.section),
              if (invites.isNotEmpty) ...[
                AppSection(
                  title: 'Solicitações diretas',
                  child: Column(
                    children: [
                      for (final i in invites) _InviteTile(job: i.job, invite: i.invite),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.section),
              ],
              AppSection(
                title: 'Pedidos abertos',
                child: feed.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Nenhum pedido aberto agora',
                        message: 'Mantenha-se online. Avisamos quando surgir algo na sua especialidade.',
                      )
                    : Column(
                        children: [
                          for (final j in feed)
                            AppCard(
                              margin: const EdgeInsets.only(bottom: AppSpace.s12),
                              onTap: () => openProviderJob(context, j.id),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CategoryBrandEmblem(categoryName: j.category, size: 44, showCornerBadge: false),
                                      const SizedBox(width: AppSpace.s12),
                                      Expanded(
                                        child: Text(
                                          j.title,
                                          maxLines: 2,
                                          style: AppType.titleSm.copyWith(color: tk.text),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpace.s12),
                                  Wrap(
                                    spacing: AppSpace.s8,
                                    runSpacing: AppSpace.s8,
                                    children: [
                                      AppStatusChip(j.category, tone: AppTone.accent),
                                      ProviderAreaLine(jobId: j.id),
                                      AppStatusChip(
                                        '${j.quoteCount}/3 orçamentos',
                                        tone: j.quoteCount >= 2 ? AppTone.warning : AppTone.info,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpace.s8),
                                  Text(
                                    'Publicado ${relativeTime(j.createdAt)}',
                                    style: AppType.caption.copyWith(color: tk.textMuted),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ====================================================================== perfil

class ProviderProfileTab extends StatefulWidget {
  const ProviderProfileTab({
    super.key,
    required this.profile,
    @visibleForTesting this.customPhotoPicker,
    @visibleForTesting this.customAvatarUploader,
  });

  final UserProfile profile;
  final StagedPhotoPicker? customPhotoPicker;
  final AvatarBinaryUploader? customAvatarUploader;

  @override
  State<ProviderProfileTab> createState() => _ProviderProfileTabState();
}

class _ProviderProfileTabState extends State<ProviderProfileTab> {
  late String? _avatarUrl = widget.profile.avatarUrl;

  bool get _hasPhoto => _avatarUrl != null && _avatarUrl!.trim().isNotEmpty;

  @override
  void didUpdateWidget(covariant ProviderProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.avatarUrl != widget.profile.avatarUrl) {
      _avatarUrl = widget.profile.avatarUrl;
    }
  }

  Future<void> _pickAndSavePhoto() async {
    final url = await pickPreviewAndSaveAvatar(
      context,
      userName: widget.profile.displayName,
      currentUrl: _avatarUrl,
      customPicker: widget.customPhotoPicker,
      customUploader: widget.customAvatarUploader,
    );
    if (url != null && mounted) {
      setState(() => _avatarUrl = url);
      AppSession.instance.refreshProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    final profile = widget.profile;
    EagerImagePrefetcher.prefetchUrls([_avatarUrl], context: context);
    Widget tile(ProfileMenuIconKind kind, String title, String subtitle, VoidCallback onTap) => AppListTile(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
          leading: ProfileMenuEmblem(kind: kind, size: 42),
          title: title,
          subtitle: subtitle,
          showChevron: true,
          onTap: onTap,
        );
    void push(Widget w) => Navigator.of(context).push(AppRoute(builder: (_) => w));
    final emailSubtitle = profile.emailAddressIfPresent;
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: margin, vertical: AppSpace.s20),
      children: [
        Text('Perfil', style: AppType.display.copyWith(color: tk.text)),
        const SizedBox(height: AppSpace.s20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EditableAvatar(
              url: _avatarUrl,
              name: profile.displayName,
              radius: 36,
              verified: true,
              customPicker: widget.customPhotoPicker,
              customUploader: widget.customAvatarUploader,
              onChanged: (url) {
                if (mounted) {
                  setState(() => _avatarUrl = url);
                  AppSession.instance.refreshProfile();
                }
              },
            ),
            const SizedBox(width: AppSpace.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    maxLines: 2,
                    style: AppType.headline.copyWith(color: tk.text),
                  ),
                  if (emailSubtitle != null) ...[
                    const SizedBox(height: AppSpace.s2),
                    Text(
                      emailSubtitle,
                      maxLines: 2,
                      style: AppType.caption.copyWith(color: tk.textMuted),
                    ),
                  ],
                  const SizedBox(height: AppSpace.s8),
                  const AppStatusChip('Profissional verificado', tone: AppTone.success, icon: Icons.verified_rounded),
                  const SizedBox(height: AppSpace.s12),
                  AppButton(
                    key: const Key('provider-profile-change-photo-btn'),
                    variant: AppButtonVariant.secondary,
                    compact: true,
                    expand: false,
                    onPressed: _pickAndSavePhoto,
                    icon: _hasPhoto ? Icons.photo_camera_rounded : Icons.add_a_photo_rounded,
                    label: _hasPhoto ? 'Alterar foto' : 'Adicionar foto de perfil',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s16),
        const AppQuickUpdateButton(compact: false),
        const SizedBox(height: AppSpace.s16),
        tile(ProfileMenuIconKind.providerEditProfile, 'Editar perfil', 'Foto, bio, especialidades e preços', () => push(const EditProviderProfileScreen())),
        tile(ProfileMenuIconKind.providerPortfolio, 'Meu portfólio', '3 últimos serviços + até 5 destaques do Histórico', () => push(const PortfolioScreen())),
        tile(ProfileMenuIconKind.providerHistory, 'Histórico de Serviços Prestados', 'Consulte todos os seus atendimentos por etapa', () => push(const ProviderFullHistoryScreen())),
        tile(ProfileMenuIconKind.providerCertificates, 'Meus certificados', 'Cofre de qualificações', () => push(const CertificatesScreen())),
        tile(ProfileMenuIconKind.providerReviews, 'Minhas avaliações', 'Nota, selos e respostas aos clientes', () => push(MyReviewsScreen(profile: profile))),
        tile(ProfileMenuIconKind.providerAchievements, 'Minhas conquistas', 'Troféus por serviços, avaliações e mais', () => push(AchievementsScreen(providerId: profile.id, providerName: profile.displayName, isOwner: true))),
        tile(ProfileMenuIconKind.providerSupport, 'Ajuda e suporte', 'Central e chamados', () => push(const SupportCenterScreen(asProvider: true))),
        AppearanceTile(accent: tk.providerAccent, soft: tk.providerSoft, kind: ProfileMenuIconKind.providerAppearance),
        tile(ProfileMenuIconKind.deleteAccount, 'Excluir conta', 'Receba seu dossiê e apague seus dados', () => push(const DeleteAccountScreen(asProvider: true))),
        const Divider(height: AppSpace.s32),
        InfoBanner(
          profile.isClient
              ? 'Você também usa o app como cliente. Troque de modo quando quiser.'
              : 'Precisa de um serviço em casa? Use o Desperrengue também como cliente.',
          tone: BannerTone.info,
          icon: Icons.swap_horiz_rounded,
        ),
        const SizedBox(height: AppSpace.s12),
        AppButton(
          label: profile.isClient ? 'Ir para o modo Cliente' : 'Preciso de um serviço (modo Cliente)',
          variant: AppButtonVariant.secondary,
          icon: Icons.home_rounded,
          onPressed: () => AppSession.instance.choose(UserMode.client),
        ),
        const SizedBox(height: AppSpace.s12),
        TextButton.icon(
          onPressed: () async {
            final ok = await AppDialog.confirm(
              context,
              title: 'Sair da conta?',
              message: 'Você precisará entrar novamente.',
              confirmLabel: 'Sair',
              destructive: true,
            );
            if (ok) await ProfileService().signOut();
          },
          icon: Icon(Icons.logout_rounded, color: tk.dangerInk),
          label: Text('Sair da conta', style: AppType.bodyStrong.copyWith(color: tk.dangerInk)),
        ),
      ],
    );
  }
}

import '../../../core/ui/app_scaffold.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/accurate_geo_routing_service.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/app_version_and_update_service.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/job_labels.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/state/privacy_mode.dart';
import '../../shared/presentation/achievement_widgets.dart';
import '../../shared/presentation/profile_photo_viewer.dart';
import '../../shared/presentation/delete_account_screen.dart';
import '../../shared/presentation/live_location_map.dart';
import '../../shared/presentation/showcase_widgets.dart';
import '../../shared/presentation/theme_picker.dart';
import '../../shared/presentation/notifications_screen.dart';
import '../../shared/presentation/support_screens.dart';
import 'provider_job_screen.dart';
import 'provider_portfolio_widgets.dart';
import 'provider_profile_screens.dart';
import 'wallet_tab.dart';
import '../../../core/ui/app_tokens.dart';

void openProviderJob(BuildContext context, String jobId) {
  Navigator.of(context).push(
    MaterialPageRoute(settings: const RouteSettings(name: 'provider_job'), builder: (_) => ProviderJobScreen(jobId: jobId)),
  );
}

/// Casca do modo PROFISSIONAL: Painel / Oportunidades / Carteira / Perfil.
class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ProviderDashboardTab(profile: widget.profile, onSeeOpportunities: () => setState(() => _index = 1), onSeeWallet: () => setState(() => _index = 2)),
      const OpportunitiesTab(),
      const WalletTab(),
      ProviderProfileTab(profile: widget.profile),
    ];
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _index = 0);
      },
      child: AppScaffold(
        body: SafeArea(child: IndexedStack(index: _index, children: pages)),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: context.tk.card,
          indicatorColor: context.tk.providerSoft,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Painel'),
            NavigationDestination(icon: Icon(Icons.travel_explore_outlined), selectedIcon: Icon(Icons.travel_explore_rounded), label: 'Oportunidades'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Carteira'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}

// ===================================================================== painel

class _DashData {
  _DashData({required this.jobs, required this.invites, required this.quotes, required this.wallet, required this.row});

  final List<Job> jobs;
  final List<({JobInvite invite, Job job})> invites;
  final List<({Quote quote, Job? job})> quotes;
  final WalletSummary wallet;
  final Map<String, dynamic>? row;
}

class ProviderDashboardTab extends StatefulWidget {
  const ProviderDashboardTab({super.key, required this.profile, required this.onSeeOpportunities, required this.onSeeWallet});

  final UserProfile profile;
  final VoidCallback onSeeOpportunities;
  final VoidCallback onSeeWallet;

  @override
  State<ProviderDashboardTab> createState() => _ProviderDashboardTabState();
}

class _ProviderDashboardTabState extends State<ProviderDashboardTab> {
  final _jobs = JobService();
  final _providers = ProviderService();
  late Future<_DashData> _future = _load();
  Timer? _timer;
  bool? _online;
  double _weeklyGoal = 2000.0;

  @override
  void initState() {
    super.initState();
    PrivacyMode.instance.ensureLoaded();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() { _future = _load(); });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<_DashData> _load() async {
    final r = await Future.wait([
      _jobs.providerJobs(),
      _jobs.myLiveInvites(),
      _jobs.myPendingQuotes(),
      _providers.myPayments(),
      _providers.myProviderRow(),
      _providers.myWithdrawnTotal(),
    ]);
    return _DashData(
      jobs: r[0] as List<Job>,
      invites: r[1] as List<({JobInvite invite, Job job})>,
      quotes: r[2] as List<({Quote quote, Job? job})>,
      wallet: ProviderService.summarize(r[3] as List<Payment>, withdrawn: r[5] as double),
      row: r[4] as Map<String, dynamic>?,
    );
  }

  Future<void> _refresh() async {
    setState(() { _future = _load(); });
    await _future;
  }

  Future<void> _toggleOnline(bool v) async {
    setState(() => _online = v);
    try {
      await _providers.saveProviderProfile(acceptingJobs: v);
    } catch (e) {
      if (mounted) {
        setState(() => _online = !v);
        showSnack(context, friendlyError(e), error: true);
      }
    }
  }

  ({int rts, String tierLabel, String settlementBadge, String nextMilestone, double progress}) _computeReputationMetrics(Map<String, dynamic>? row) {
    final rawRts = (row?['relative_trust_score'] as num?)?.toInt();
    final done = (row?['jobs_done'] as num?)?.toInt() ?? 0;
    final ratingAvg = (row?['rating_avg'] as num?)?.toDouble() ?? 5.0;
    final rts = (rawRts ?? (68 + (done * 4).clamp(0, 22) + ((ratingAvg - 4.0) * 10).round().clamp(0, 10))).clamp(50, 100);

    if (rts >= 85) {
      return (
        rts: rts,
        tierLabel: '1º Degrau • Prioridade Elite',
        settlementBadge: 'PIX Instantâneo D+0 ⚡',
        nextMilestone: 'Prioridade máxima ativa no radar SOS e liquidação imediata.',
        progress: (rts / 100.0).clamp(0.85, 1.0),
      );
    } else if (rts >= 75) {
      final missing = 85 - rts;
      return (
        rts: rts,
        tierLabel: '2º Degrau • Alta Confiança',
        settlementBadge: 'PIX Rápido D+2',
        nextMilestone: 'Faltam $missing pts de RTS para subir ao 1º Degrau e destravar PIX D+0.',
        progress: (rts / 85.0).clamp(0.5, 0.96),
      );
    } else if (rts >= 65) {
      final missing = 75 - rts;
      return (
        rts: rts,
        tierLabel: '3º Degrau • Verificado Ativo',
        settlementBadge: 'Maturação Padrão D+5',
        nextMilestone: 'Faltam $missing pts de RTS para subir ao 2º Degrau (PIX D+2).',
        progress: (rts / 75.0).clamp(0.4, 0.95),
      );
    } else {
      return (
        rts: rts,
        tierLabel: '4º Degrau • Marco Zero',
        settlementBadge: 'Proteção Inicial D+5',
        nextMilestone: 'Conclua atendimentos com PIN e fotos Antes/Depois para subir de degrau.',
        progress: (rts / 65.0).clamp(0.25, 0.9),
      );
    }
  }

  Future<void> _showSmartSplitCalculatorSheet(BuildContext context) async {
    final laborCtrl = TextEditingController(text: '250');
    final materialsCtrl = TextEditingController(text: '150');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final tk = ctx.tk;
            final labor = double.tryParse(laborCtrl.text.replaceAll(',', '.')) ?? 0.0;
            final materials = double.tryParse(materialsCtrl.text.replaceAll(',', '.')) ?? 0.0;
            const feeRate = 0.12;
            final platformFee = labor * feeRate;
            final netLabor = (labor - platformFee).clamp(0.0, double.infinity);
            final totalNet = netLabor + materials;
            final savedOnMaterials = materials * feeRate;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: tk.providerSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.calculate_rounded, color: tk.providerAccent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Simulador Rápido Smart Split',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: tk.text),
                              ),
                              Text(
                                'Mão de Obra vs. Peças/Materiais (0% de Taxa sobre Insumos)',
                                style: TextStyle(fontSize: 12, color: tk.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('smart-split-labor-input'),
                            controller: laborCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setModalState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Mão de Obra (R\$)',
                              prefixText: 'R\$ ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('smart-split-materials-input'),
                            controller: materialsCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setModalState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Peças c/ Nota (Taxa 0%)',
                              prefixText: 'R\$ ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: tk.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: tk.providerAccent.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total cobrado do Cliente:', style: TextStyle(color: tk.textMuted, fontSize: 13)),
                              Text(brl(labor + materials), style: TextStyle(fontWeight: FontWeight.w800, color: tk.text)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Reembolso de Peças (Taxa 0%):', style: TextStyle(color: tk.success, fontWeight: FontWeight.w700, fontSize: 13)),
                              Text('+ ${brl(materials)} (100% seu)', style: TextStyle(fontWeight: FontWeight.w900, color: tk.success)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Economia por isenção em peças:', style: TextStyle(color: tk.providerAccent, fontSize: 12.5, fontWeight: FontWeight.w700)),
                              Text('Você economiza ${brl(savedOnMaterials)}', style: TextStyle(color: tk.providerAccent, fontWeight: FontWeight.w900, fontSize: 12.5)),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Você Recebe Líquido (PIX):', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: tk.text)),
                              Text(
                                brl(totalNet),
                                key: const ValueKey('smart-split-net-result'),
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: tk.providerAccent),
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
          },
        );
      },
    );
  }

  Future<void> _showWeeklyGoalDialog(BuildContext context) async {
    final ctrl = TextEditingController(text: _weeklyGoal.toStringAsFixed(0));
    final nextGoal = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Definir Meta Semanal'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Meta de faturamento na semana (R\$)',
            prefixText: 'R\$ ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: Size.zero),
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              Navigator.pop(ctx, (v != null && v >= 100) ? v : 2000.0);
            },
            child: const Text('Salvar Meta'),
          ),
        ],
      ),
    );
    if (nextGoal != null && mounted) {
      setState(() => _weeklyGoal = nextGoal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_DashData>(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          final online = _online ?? (d?.row?['accepting_jobs'] != false);
          final radiusKm = (d?.row?['service_radius_km'] as num?)?.toInt() ?? 15;
          final active = d?.jobs.where((j) => j.status == JobStatus.scheduled || j.status == JobStatus.inProgress || j.status == JobStatus.awaitingApproval || j.status == JobStatus.awaitingPayment || j.status == JobStatus.disputed).toList() ?? const <Job>[];
          final rep = _computeReputationMetrics(d?.row);

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // ===============================================================
              // 1. HEADER EXECUTIVO + PRIVACIDADE + NOTIFICAÇÕES
              // ===============================================================
              Row(
                children: [
                  IconButton(
                    tooltip: 'Voltar à seleção de perfil',
                    visualDensity: VisualDensity.compact,
                    onPressed: AppSession.instance.switchMode,
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: tk.text),
                  ),
                  UserAvatar(url: widget.profile.avatarUrl, name: widget.profile.fullName, radius: 24, verified: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Olá, ${widget.profile.firstName}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: tk.providerAccent)),
                        Row(
                          children: [
                            Icon(Icons.circle, size: 10, color: online ? tk.success : tk.textMuted),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                online ? 'Online • Radar ${radiusKm}km ativo' : 'Offline • Radar pausado',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: tk.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: PrivacyMode.instance.hidden,
                    builder: (context, hidden, _) => IconButton(
                      key: const ValueKey('btn-toggle-privacy-mode'),
                      tooltip: hidden ? 'Mostrar valores' : 'Ocultar valores',
                      onPressed: PrivacyMode.instance.toggle,
                      icon: Icon(hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: tk.textMuted),
                    ),
                  ),
                  UnreadBell(onOpenJob: (c, id) => openProviderJob(c, id)),
                ],
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerRight,
                child: AppQuickUpdateButton(compact: true),
              ),
              const SizedBox(height: 6),

              // ===============================================================
              // 2. INTERRUPTOR TÁTIL DE DISPONIBILIDADE NO RADAR
              // ===============================================================
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: online ? tk.successSoft.withValues(alpha: 0.45) : tk.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: online ? tk.success.withValues(alpha: 0.45) : tk.border),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: online,
                  onChanged: _toggleOnline,
                  title: const Text('Disponível para novos serviços', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                  subtitle: Text(
                    online
                        ? 'Você está visível na cascata de despacho da sua região.'
                        : 'Desligue para pausar sem perder suas avaliações.',
                    style: TextStyle(fontSize: 12, color: tk.textMuted),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              if (snap.hasError) const InfoBanner('Não foi possível atualizar o painel. Puxe para tentar de novo.', tone: BannerTone.warning),
              if (d == null && !snap.hasError) const Padding(padding: EdgeInsets.all(40), child: LoadingView()),
              if (d != null) ...[
                // =============================================================
                // 3. CARD DE PRIORIDADE NA CASCATA (1º AO 5º DEGRAU + RTS + PIX)
                // =============================================================
                Container(
                  key: const ValueKey('provider-dashboard-rts-tier-card'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        tk.providerSoft,
                        tk.surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tk.providerAccent.withValues(alpha: 0.38)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: tk.providerAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.military_tech_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rep.tierLabel,
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: tk.text),
                                ),
                                Text(
                                  'Score de Confiança RTS: ${rep.rts}/100',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tk.providerAccent),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: tk.successSoft,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: tk.success.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              rep.settlementBadge,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: tk.success),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: rep.progress),
                        duration: const Duration(milliseconds: 550),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: val,
                            minHeight: 7,
                            backgroundColor: tk.border,
                            valueColor: AlwaysStoppedAnimation<Color>(tk.providerAccent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rep.nextMilestone,
                        style: TextStyle(fontSize: 12, color: tk.textMuted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // =============================================================
                // 4. COCKPIT FINANCEIRO BIPARTIDO + BARRA DE META SEMANAL
                // =============================================================
                ValueListenableBuilder<bool>(
                  valueListenable: PrivacyMode.instance.hidden,
                  builder: (context, hidden, _) {
                    String m(double v) => PrivacyMode.money(brl(v), hidden: hidden);
                    final done = (d.row?['jobs_done'] as num?)?.toInt() ?? 0;
                    final rated = ((d.row?['rating_count'] as num?) ?? 0) > 0;
                    final goalProgress = (_weeklyGoal <= 0 ? 0.0 : (d.wallet.week / _weeklyGoal)).clamp(0.0, 1.0);
                    final goalPct = (goalProgress * 100).round();

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _Stat(
                                icon: Icons.account_balance_wallet_rounded,
                                label: 'Saldo disponível',
                                subtitle: 'Livre para saque PIX',
                                value: m(d.wallet.available),
                                onTap: widget.onSeeWallet,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _Stat(
                                icon: Icons.shield_moon_rounded,
                                label: 'Em custódia',
                                subtitle: 'Sob Proteção Pós-Serviço',
                                value: m(d.wallet.held),
                                onTap: widget.onSeeWallet,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _Stat(
                                icon: Icons.payments_rounded,
                                label: 'Faturado na semana',
                                subtitle: '0% taxa sobre peças',
                                value: m(d.wallet.week),
                                onTap: widget.onSeeWallet,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _Stat(
                                icon: Icons.check_circle_rounded,
                                label: 'Serviços concluídos',
                                subtitle: rated
                                    ? 'Nota: ${((d.row?['rating_avg'] as num).toDouble()).toStringAsFixed(1).replaceAll('.', ',')} ★'
                                    : 'Sua nota: Novo',
                                value: '$done',
                                onTap: () => ProviderFullHistoryScreen.open(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
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
                                  Icon(Icons.flag_rounded, size: 18, color: tk.providerAccent),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Meta Semanal: ${m(d.wallet.week)} de ${m(_weeklyGoal)} ($goalPct%)',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: tk.text),
                                    ),
                                  ),
                                  TextButton.icon(
                                    key: const ValueKey('btn-edit-weekly-goal'),
                                    onPressed: () => _showWeeklyGoalDialog(context),
                                    icon: const Icon(Icons.tune_rounded, size: 15),
                                    label: const Text('Ajustar', style: TextStyle(fontSize: 12)),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: goalProgress,
                                  minHeight: 7,
                                  backgroundColor: tk.surface,
                                  valueColor: AlwaysStoppedAnimation<Color>(tk.success),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Sua nota: ${rated ? ((d.row?['rating_avg'] as num).toDouble()).toStringAsFixed(1).replaceAll('.', ',') : 'Novo'}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tk.textMuted),
                                  ),
                                  Text(
                                    'Isenção Smart Split: 0% taxa em materiais',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: tk.success),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                // =============================================================
                // 5. FERRAMENTAS RÁPIDAS DO PROFISSIONAL (SEM POLUIÇÃO VISUAL)
                // =============================================================
                const SectionTitle('Ferramentas Rápidas do Especialista'),
                Row(
                  children: [
                    Expanded(
                      child: _QuickToolTile(
                        key: const ValueKey('btn-open-smart-split-calculator'),
                        icon: Icons.calculate_rounded,
                        title: 'Simulador Smart Split',
                        subtitle: 'Cálculo líquido (0% peças)',
                        onTap: () => _showSmartSplitCalculatorSheet(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickToolTile(
                        key: const ValueKey('btn-quick-open-portfolio'),
                        icon: Icons.workspace_premium_rounded,
                        title: 'Meu Portfólio',
                        subtitle: '3 recentes + 5 destaques',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PortfolioScreen()),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _QuickToolTile(
                        key: const ValueKey('btn-quick-open-history'),
                        icon: Icons.history_edu_rounded,
                        title: 'Histórico Auditado',
                        subtitle: 'Concluídos, proteção e mais',
                        onTap: () => ProviderFullHistoryScreen.open(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickToolTile(
                        key: const ValueKey('btn-quick-open-opportunities'),
                        icon: Icons.radar_rounded,
                        title: 'Radar de Chamados',
                        subtitle: 'Orçar 100% gratuito',
                        onTap: widget.onSeeOpportunities,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                ShowcaseStrip(providerId: widget.profile.id, isOwner: true),
                if (d.invites.isNotEmpty) ...[
                  const SectionTitle('Solicitações diretas para você'),
                  for (final i in d.invites) _InviteTile(job: i.job, invite: i.invite),
                ],
                if (active.isNotEmpty) ...[
                  const SectionTitle('Serviços em andamento'),
                  for (final j in active) _JobTile(job: j, provider: true),
                ],
                if (d.quotes.isNotEmpty) ...[
                  const SectionTitle('Orçamentos aguardando o cliente'),
                  for (final q in d.quotes)
                    if (q.job != null)
                      AppCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        onTap: () => openProviderJob(context, q.job!.id),
                        child: Row(
                          children: [
                            Icon(Icons.hourglass_top_rounded, color: tk.providerAccent),
                            const SizedBox(width: 12),
                            Expanded(child: Text(q.job!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                            Text(brl(q.quote.price), style: const TextStyle(fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                ],
                if (d.invites.isEmpty && active.isEmpty && d.quotes.isEmpty) ...[
                  const SizedBox(height: 20),
                  EmptyView(
                    icon: Icons.travel_explore_rounded,
                    title: 'Pronto para o próximo serviço',
                    subtitle: 'Veja os pedidos abertos na sua região e envie seu orçamento gratuito.',
                    action: PrimaryButton(label: 'Buscar novos serviços', trailingArrow: true, onPressed: widget.onSeeOpportunities),
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

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: context.tk.providerSoft,
      borderColor: context.tk.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.tk.providerAccent),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: context.tk.providerAccent)),
          Text(label, style: TextStyle(color: context.tk.text, fontWeight: FontWeight.w700, fontSize: 12.5)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.tk.textMuted, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _QuickToolTile extends StatelessWidget {
  const _QuickToolTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Material(
      color: tk.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tk.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tk.providerSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: tk.providerAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: tk.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: tk.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    final urgent = job.isEmergency;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      color: urgent ? context.tk.dangerSoft : context.tk.card,
      borderColor: urgent ? context.tk.danger.withValues(alpha: 0.5) : context.tk.border,
      onTap: () => openProviderJob(context, job.id),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: categoryColor(job.category), child: Icon(urgent ? Icons.bolt_rounded : categoryIcon(job.category), color: AppColors.ink)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(urgent ? 'Emergência: ${job.title}' : job.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('Responder em ${clock(invite.remaining)}', style: TextStyle(color: urgent ? context.tk.danger : context.tk.textMuted, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
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
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => openProviderJob(context, job.id),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: categoryColor(job.category), child: Icon(categoryIcon(job.category), color: AppColors.ink)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                JobStatusChip(job, provider: provider),
              ],
            ),
          ),
          if (job.agreedPrice != null) Text(brl(job.agreedPrice), style: const TextStyle(fontWeight: FontWeight.w900)),
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
      if (mounted) setState(() { _future = _load(); });
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
    setState(() { _future = _load(); });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<(List<({JobInvite invite, Job job})>, List<Job>)>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ListView(children: [ErrorView(message: 'Não foi possível carregar as oportunidades.', onRetry: _refresh)]);
          if (!snap.hasData) return const LoadingView();
          final (invites, feed) = snap.data!;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const Text('Oportunidades', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Serviços próximos que combinam com suas especialidades.', style: TextStyle(color: context.tk.textMuted)),
              if (invites.isNotEmpty) ...[
                const SectionTitle('Solicitações diretas'),
                for (final i in invites) _InviteTile(job: i.job, invite: i.invite),
              ],
              const SectionTitle('Pedidos abertos'),
              if (feed.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: EmptyView(
                    icon: Icons.search_off_rounded,
                    title: 'Nenhum pedido aberto agora',
                    subtitle: 'Mantenha-se online. Avisamos quando surgir algo na sua especialidade.',
                  ),
                )
              else
                for (final j in feed)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    onTap: () => openProviderJob(context, j.id),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(backgroundColor: categoryColor(j.category), child: Icon(categoryIcon(j.category), color: AppColors.ink)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(j.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            StatusChip(j.category, color: context.tk.providerAccent),
                            if (j.addressSummary != null)
                              Builder(
                                builder: (context) {
                                  final privacy = AccurateGeoRoutingService.resolveProviderAddressView(
                                    fullAddressLine: j.addressSummary,
                                    addressSummary: j.addressSummary,
                                    scheduledDate: j.scheduledFor,
                                    status: j.status,
                                    isEmergency: j.isEmergency,
                                  );
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: privacy.isUnlocked
                                        ? () => LiveLocationMapSheet.show(
                                              context,
                                              addressLine: j.addressSummary!,
                                              summary: j.addressSummary,
                                            )
                                        : null,
                                    child: StatusChip(
                                      privacy.primaryTitle,
                                      color: privacy.isUnlocked ? context.tk.info : context.tk.warningInk,
                                      icon: privacy.isUnlocked ? Icons.place_rounded : Icons.radar_rounded,
                                    ),
                                  );
                                },
                              ),
                            StatusChip('${j.quoteCount}/3 orçamentos', color: j.quoteCount >= 2 ? context.tk.warningInk : context.tk.info),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Publicado ${relativeTime(j.createdAt)}', style: TextStyle(color: context.tk.textMuted, fontSize: 12.5)),
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

class ProviderProfileTab extends StatelessWidget {
  const ProviderProfileTab({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String title, String subtitle, VoidCallback onTap) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: context.tk.providerSoft, child: Icon(icon, color: context.tk.providerAccent)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Perfil', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        Row(
          children: [
            EditableAvatar(url: profile.avatarUrl, name: profile.fullName, radius: 36, verified: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  StatusChip('Profissional verificado', color: context.tk.success, icon: Icons.verified_rounded),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const AppQuickUpdateButton(compact: false),
        const SizedBox(height: 14),
        tile(Icons.edit_rounded, 'Editar perfil', 'Foto, bio, especialidades e preços', () => push(const EditProviderProfileScreen())),
        tile(Icons.photo_library_rounded, 'Meu portfólio', '3 últimos automáticos + até 5 destaques do Histórico', () => push(const PortfolioScreen())),
        tile(Icons.history_edu_rounded, 'Histórico de Serviços Prestados', 'Concluídos 100% pagos, Sob Proteção Pós-Serviço, Em Mediação e Cancelados', () => push(const ProviderFullHistoryScreen())),
        tile(Icons.workspace_premium_rounded, 'Meus certificados', 'Cofre de qualificações', () => push(const CertificatesScreen())),
        tile(Icons.reviews_rounded, 'Minhas avaliações', 'Nota, selos e respostas aos clientes', () => push(MyReviewsScreen(profile: profile))),
        tile(Icons.emoji_events_rounded, 'Minhas conquistas', 'Troféus por serviços, avaliações e mais', () => push(AchievementsScreen(providerId: profile.id, providerName: profile.fullName, isOwner: true))),
        tile(Icons.push_pin_rounded, 'Vitrine de cases', 'Fixe seus melhores serviços no topo', () => push(const CaseCurationScreen())),
        tile(Icons.support_agent_rounded, 'Ajuda e suporte', 'Central e chamados', () => push(const SupportCenterScreen(asProvider: true))),
        AppearanceTile(accent: context.tk.providerAccent, soft: context.tk.providerSoft),
        tile(Icons.delete_forever_rounded, 'Excluir conta', 'Receba seu dossiê e apague seus dados', () => push(const DeleteAccountScreen(asProvider: true))),
        const Divider(height: 32),
        InfoBanner(
          profile.isClient
              ? 'Você também usa o app como cliente. Troque de modo quando quiser.'
              : 'Precisa de um serviço em casa? Use o Desperrengue também como cliente.',
          tone: BannerTone.info,
          icon: Icons.swap_horiz_rounded,
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          label: profile.isClient ? 'Ir para o modo Cliente' : 'Preciso de um serviço (modo Cliente)',
          icon: Icons.home_repair_service_rounded,
          onPressed: () => AppSession.instance.choose(UserMode.client),
        ),
        const SizedBox(height: 10),
        TextButton.icon(onPressed: AppSession.instance.switchMode, icon: const Icon(Icons.apps_rounded), label: const Text('Trocar de modo')),
        TextButton.icon(
          onPressed: () async {
            final ok = await confirmDialog(context, title: 'Sair da conta?', message: 'Você precisará entrar novamente.', confirmLabel: 'Sair', destructive: true);
            if (ok) await ProfileService().signOut();
          },
          icon: Icon(Icons.logout_rounded, color: context.tk.danger),
          label: Text('Sair da conta', style: TextStyle(color: context.tk.danger)),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/app_version_and_update_service.dart';
import '../../../core/services/instant_image_cache_engine.dart';
import '../../../core/services/job_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../shared/presentation/notifications_screen.dart';
import 'category_picker.dart';
import 'client_job_screen.dart';
import 'client_orders_tab.dart';
import 'client_setup_screen.dart';
import 'provider_search_screen.dart';
import 'request_wizard.dart';
import 'wallet_chip.dart';

void openClientJob(BuildContext context, String jobId) {
  Navigator.of(context).push(AppRoute(builder: (_) => ClientJobScreen(jobId: jobId)));
}

/// Casca do modo CLIENTE: Início / Meus Pedidos / Perfil.
class ClientShell extends StatefulWidget {
  const ClientShell({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: AppMotion.tabSwitch,
    value: 1.0,
  );
  late final Animation<double> _tabOpacity = CurvedAnimation(
    parent: _tabFade,
    curve: AppMotion.fadeCurve,
  ).drive(Tween<double>(begin: 0.25, end: 1.0));

  @override
  void initState() {
    super.initState();
    EagerImagePrefetcher.prefetchUrls([widget.profile.avatarUrl]);
  }

  @override
  void didUpdateWidget(covariant ClientShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.avatarUrl != widget.profile.avatarUrl) {
      EagerImagePrefetcher.prefetchUrls([widget.profile.avatarUrl]);
    }
  }

  @override
  void dispose() {
    _tabFade.dispose();
    EagerImagePrefetcher.cancelPending();
    super.dispose();
  }

  void _selectTab(int i) {
    if (i == _index) return;
    if (i == 1) {
      JobService.notifyJobsChanged();
    }
    setState(() => _index = i);
    if (AppMotion.reduced(context)) {
      _tabFade.value = 1.0;
    } else {
      _tabFade.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final reduced = AppMotion.reduced(context);
    final pages = [
      ClientHomeTab(profile: widget.profile, onSeeOrders: () => _selectTab(1)),
      const ClientOrdersTab(),
      ClientProfileTab(profile: widget.profile),
    ];
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selectTab(0);
      },
      child: AppScaffold(
        body: SafeArea(
          child: reduced
              ? IndexedStack(index: _index, children: pages)
              : FadeTransition(
                  opacity: _tabOpacity,
                  child: IndexedStack(index: _index, children: pages),
                ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _selectTab,
          animationDuration: reduced ? Duration.zero : const Duration(milliseconds: 180),
          backgroundColor: tk.isDark ? tk.surface : tk.background,
          indicatorColor: tk.accentSoft,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: _ActiveNavIcon(icon: Icons.home_rounded, active: _index == 0),
              label: 'Início',
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: _ActiveNavIcon(icon: Icons.receipt_long_rounded, active: _index == 1),
              label: 'Meus Pedidos',
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: _ActiveNavIcon(icon: Icons.person_rounded, active: _index == 2),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

/// Micro-pop de 120 ms no ícone ativo da barra de navegação (respeita `AppMotion.reduced`).
class _ActiveNavIcon extends StatelessWidget {
  const _ActiveNavIcon({required this.icon, required this.active});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!active || AppMotion.reduced(context)) return Icon(icon);
    return TweenAnimationBuilder<double>(
      key: ValueKey('nav-pop-$icon'),
      tween: Tween<double>(begin: 0.86, end: 1.0),
      duration: AppMotion.fadeShort,
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Icon(icon),
    );
  }
}

class ClientHomeTab extends StatefulWidget {
  const ClientHomeTab({super.key, required this.profile, required this.onSeeOrders});

  final UserProfile profile;
  final VoidCallback onSeeOrders;

  @override
  State<ClientHomeTab> createState() => _ClientHomeTabState();
}

class _ClientHomeTabState extends State<ClientHomeTab> {
  final _search = TextEditingController();
  final _jobs = JobService();
  late final Stream<List<Job>> _myJobsStream = _jobs.streamMyJobs();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openSearch({String? category, String? query}) {
    Navigator.of(context).push(
      AppRoute(builder: (_) => ProviderSearchScreen(category: category, query: query, profile: widget.profile)),
    );
  }

  Future<void> _editAddress() async {
    await Navigator.of(context).push(
      AppRoute(builder: (_) => EditAddressScreen(currentLine: widget.profile.addressLine)),
    );
  }

  String get _addressLabel {
    final line = widget.profile.addressLine;
    if (line == null || line.isEmpty) return 'Adicionar endereço';
    final cut = line.split(' | ').first;
    return cut.length > 38 ? '${cut.substring(0, 38)}…' : cut;
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    final hasAddress = (widget.profile.addressLine ?? '').trim().isNotEmpty;
    return ListView(
      padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: BrandLogo(size: 20),
              ),
            ),
            const SizedBox(width: AppSpace.s4),
            const AppQuickUpdateButton(compact: true),
            const SizedBox(width: AppSpace.s8 - 2),
            const WalletChip(),
            const SizedBox(width: AppSpace.s4),
            UnreadBell(onOpenJob: (c, id) => openClientJob(c, id)),
          ],
        ),
        const SizedBox(height: AppSpace.s12),
        Text(
          'Olá, ${widget.profile.firstName}!',
          style: AppType.headline.copyWith(color: tk.text),
        ),
        const SizedBox(height: AppSpace.s4),
        Row(
          children: [
            Expanded(
              child: AppPressable(
                onTap: hasAddress ? null : _editAddress,
                borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
                isButton: !hasAddress,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.place_rounded, size: 18, color: tk.accentInk),
                      const SizedBox(width: AppSpace.s4),
                      Flexible(
                        child: Text(
                          _addressLabel,
                          style: AppType.bodySm.copyWith(fontWeight: FontWeight.w600, color: tk.text),
                        ),
                      ),
                      if (!hasAddress) ...[
                        const SizedBox(width: AppSpace.s4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: tk.accentInk,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (hasAddress)
              AppButton(
                label: 'Trocar',
                icon: Icons.edit_location_alt_outlined,
                variant: AppButtonVariant.tertiary,
                expand: false,
                compact: true,
                onPressed: _editAddress,
              ),
          ],
        ),
        const SizedBox(height: AppSpace.s16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: _search,
                hint: 'Do que você precisa hoje? (ex: eletricista)',
                prefixIcon: Icons.search_rounded,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => _openSearch(query: v),
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            SizedBox(
              width: AppGeometry.inputHeight,
              height: AppGeometry.inputHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tk.isDark ? tk.surface : tk.surfaceInset,
                  borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
                  border: Border.all(color: tk.border),
                ),
                child: Center(
                  child: AppIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: 'Filtrar busca',
                    color: tk.text,
                    onPressed: () => _openSearch(query: _search.text),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s20),
        StreamBuilder<List<Job>>(
          stream: _myJobsStream,
          builder: (context, snap) {
            if (snap.hasData) {
              EagerImagePrefetcher.prefetchJobs(snap.data!, context: context);
            }
            final active = (snap.data ?? const []).where((j) => j.status.isActive).toList();
            if (active.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                _ActiveJobCard(job: active.first, onTap: () => openClientJob(context, active.first.id)),
                if (active.length > 1)
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton(
                      label: 'Ver todos os pedidos em andamento (${active.length})',
                      variant: AppButtonVariant.tertiary,
                      expand: false,
                      compact: true,
                      onPressed: widget.onSeeOrders,
                    ),
                  ),
                const SizedBox(height: AppSpace.s16),
              ],
            );
          },
        ),
        _OpenJobBanner(
          onTap: () async {
            await Navigator.of(context).push(
              AppRoute(builder: (_) => RequestWizardScreen(profile: widget.profile)),
            );
            JobService.notifyJobsChanged();
          },
        ),
        const SizedBox(height: AppSpace.section),
        AppSection(
          title: 'Categorias',
          child: CategoryGrid(onPick: (name) => _openSearch(category: name)),
        ),
      ],
    );
  }
}

class _ActiveJobCard extends StatelessWidget {
  const _ActiveJobCard({required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

  (bool, String, String, String) get _copy {
    if (job.isEmergency && job.status == JobStatus.open) {
      return (true, 'Buscando profissional...', 'Aguardando alguém aceitar a sua emergência.', 'Ver radar');
    }
    return switch (job.status) {
      JobStatus.open => (
        false,
        'Aguardando orçamento',
        job.quoteCount > 0
            ? '${job.quoteCount} orçamento(s) recebido(s) para "${job.title}".'
            : 'Seu pedido "${job.title}" foi enviado.',
        job.quoteCount > 0 ? 'Ver orçamentos' : 'Acompanhar',
      ),
      JobStatus.awaitingPayment => (false, 'Orçamento aceito', 'Conclua o pagamento para reservar o profissional.', 'Pagar'),
      JobStatus.scheduled => (
        false,
        'Serviço agendado',
        job.scheduledFor != null ? '"${job.title}" — ${dateShort(job.scheduledFor!)}.' : '"${job.title}" está agendado.',
        'Ver detalhes',
      ),
      JobStatus.inProgress => (false, 'Serviço em andamento', '"${job.title}" está sendo atendido.', 'Acompanhar'),
      JobStatus.awaitingApproval => (false, 'Aguardando sua aprovação', 'Confirme o serviço "${job.title}".', 'Abrir'),
      JobStatus.disputed => (false, 'Em mediação', 'Nossa equipe está analisando "${job.title}".', 'Ver caso'),
      _ => (false, job.title, '', 'Abrir'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final (isUrgent, title, body, cta) = _copy;
    return AppCard(
      variant: AppCardVariant.elevated,
      color: tk.accentSoft,
      borderColor: tk.accent.withValues(alpha: 0.45),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: AppSpace.s4),
            child: _PulseDot(),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isUrgent) ...[
                      Icon(Icons.bolt_rounded, size: 18, color: tk.accentInk),
                      const SizedBox(width: AppSpace.s4),
                    ],
                    Expanded(
                      child: Text(title, style: AppType.titleSm.copyWith(color: tk.text)),
                    ),
                  ],
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s4),
                  Text(body, style: AppType.bodySm.copyWith(color: tk.text)),
                ],
                const SizedBox(height: AppSpace.s8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(cta, style: AppType.bodyStrong.copyWith(color: tk.accentInk)),
                    ),
                    const SizedBox(width: AppSpace.s4),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: tk.accentInk),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.success);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _c.value = 1.0;
    } else {
      _c.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: FadeTransition(
          opacity: Tween(begin: 0.45, end: 1.0).animate(
            CurvedAnimation(parent: _c, curve: AppMotion.fadeCurve),
          ),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: context.tk.accent, shape: BoxShape.circle),
          ),
        ),
      );
}

class _OpenJobBanner extends StatelessWidget {
  const _OpenJobBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      variant: AppCardVariant.hero,
      color: tk.accentSoft,
      borderColor: tk.accent.withValues(alpha: 0.28),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resolva seu "desperrengue"!',
                  style: AppType.title.copyWith(color: tk.text),
                ),
                const SizedBox(height: AppSpace.s8),
                Text(
                  'Descreva o problema e receba até 3 orçamentos de profissionais verificados.',
                  style: AppType.bodySm.copyWith(color: tk.text),
                ),
                const SizedBox(height: AppSpace.s12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s8),
                  decoration: BoxDecoration(
                    color: tk.accent,
                    borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Pedir orçamentos grátis',
                          style: AppType.bodyStrong.copyWith(color: tk.onAccent),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s4),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: tk.onAccent),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          ExcludeSemantics(
            child: Icon(Icons.home_repair_service_rounded, size: 56, color: tk.accentInk),
          ),
        ],
      ),
    );
  }
}

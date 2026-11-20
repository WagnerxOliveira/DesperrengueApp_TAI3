import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/app_version_and_update_service.dart';
import '../../../core/services/instant_image_cache_engine.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/state/unread_orders_badge_controller.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/job_labels.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/order_utils.dart';
import '../../auth/presentation/verificacao_step6c_termos.dart';
import '../../shared/presentation/achievement_widgets.dart';
import '../../shared/presentation/delete_account_screen.dart';
import '../../shared/presentation/fintech_warranty_widgets.dart';
import '../../shared/presentation/profile_photo_viewer.dart';
import '../../shared/presentation/support_screens.dart';
import '../../shared/presentation/theme_picker.dart';
import 'carteira_cliente_screen.dart';
import 'client_setup_screen.dart';
import 'detalhe_servico_cliente_screen.dart';
import 'historico_servicos_cliente_screen.dart';

/// Aba "Meus Pedidos": Em Andamento / Concluídos / Cancelados (e 4ª aba "Em Mediação" quando habilitada).
class ClientOrdersTab extends StatefulWidget {
  const ClientOrdersTab({
    super.key,
    @visibleForTesting this.jobsStream,
    @visibleForTesting this.onOpen,
    this.includeMediationTab = false,
  });

  /// Injetáveis nos testes (padrão: stream realtime do Supabase e o detalhe do pedido).
  final Stream<List<Job>>? jobsStream;
  final void Function(BuildContext context, Job job)? onOpen;
  final bool includeMediationTab;

  @override
  State<ClientOrdersTab> createState() => _ClientOrdersTabState();
}

class _ClientOrdersTabState extends State<ClientOrdersTab> {
  late final Stream<List<Job>> _stream =
      widget.jobsStream ?? JobService().streamMyJobs();

  @override
  void initState() {
    super.initState();
    unawaited(UnreadOrdersBadgeController.instance.ensureLoaded());
  }

  @override
  void dispose() {
    EagerImagePrefetcher.cancelPending();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(margin, AppSpace.s12, margin, AppSpace.s4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              header: true,
              child: Text(
                'Meus Pedidos',
                style: AppType.display.copyWith(color: tk.text),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Job>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return const AppErrorState(
                  message: 'Não foi possível carregar seus pedidos.',
                );
              }
              final loading = !snap.hasData;
              final jobs = snap.data ?? const <Job>[];
              if (!loading) {
                unawaited(UnreadOrdersBadgeController.instance.ensureLoaded());
                EagerImagePrefetcher.prefetchJobs(jobs, context: context);
              }
              return AppSkeletonSwitcher(
                loading: loading,
                skeleton: AppSkeletonList(
                  count: 4,
                  padding: EdgeInsets.symmetric(
                    horizontal: margin,
                    vertical: AppSpace.s16,
                  ),
                ),
                child: OrdersTabs(
                  buckets: OrderBuckets.from(jobs),
                  includeMediationTab: widget.includeMediationTab,
                  onOpen: widget.onOpen ??
                      (c, j) => openClientServiceDetail(c, j.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// As abas de status (com contagem reativa O(1) de não lidos) sobre pedidos já separados.
class OrdersTabs extends StatelessWidget {
  const OrdersTabs({
    super.key,
    required this.buckets,
    required this.onOpen,
    this.includeMediationTab = false,
  });

  final OrderBuckets buckets;
  final void Function(BuildContext context, Job job) onOpen;
  final bool includeMediationTab;

  @override
  Widget build(BuildContext context) {
    unawaited(UnreadOrdersBadgeController.instance.ensureLoaded());
    final tk = context.tk;
    final layout = context.layout;
    final tabs = [
      (
        OrderTab.inProgress,
        'Em Andamento',
        'Você não tem pedidos em andamento.',
        'Peça um orçamento na aba Início.',
      ),
      (
        OrderTab.completed,
        'Concluídos',
        'Nenhum serviço concluído ainda.',
        'Os serviços finalizados ficam guardados aqui.',
      ),
      (
        OrderTab.canceled,
        'Cancelados',
        'Nenhum pedido cancelado.',
        'Pedidos cancelados aparecem aqui com data e motivo.',
      ),
      if (includeMediationTab)
        (
          OrderTab.mediation,
          'Em Mediação',
          'Nenhuma garantia ou mediação ativa.',
          'Acionamentos da Reserva de Garantia (Camada 3) aparecem aqui.',
        ),
    ];
    final scrollable = layout.isCompact || layout.isLargeText;
    final tabBaseStyle = (includeMediationTab && !scrollable)
        ? AppType.caption
        : AppType.bodySm;
    return DefaultTabController(
      length: tabs.length,
      child: ListenableBuilder(
        listenable: UnreadOrdersBadgeController.instance,
        builder: (context, _) {
          return Column(
            children: [
              TabBar(
                isScrollable: scrollable,
                tabAlignment: scrollable ? TabAlignment.start : TabAlignment.fill,
                labelPadding: EdgeInsets.symmetric(
                  horizontal: scrollable ? AppSpace.s16 : AppSpace.s4,
                ),
                labelColor: tk.accentInk,
                unselectedLabelColor: tk.textMuted,
                indicatorColor: tk.accent,
                labelStyle: tabBaseStyle.copyWith(fontWeight: FontWeight.w700),
                unselectedLabelStyle: tabBaseStyle.copyWith(fontWeight: FontWeight.w500),
                tabs: [
                  for (final (tab, label, _, _) in tabs)
                    Builder(
                      builder: (context) {
                        final unreadCount = UnreadOrdersBadgeController.instance
                            .countUnread(tab, buckets.of(tab));
                        return Tab(
                          child: Badge(
                            key: ValueKey('orders-tab-badge-${tab.name}'),
                            isLabelVisible: unreadCount > 0,
                            label: Text(
                              '$unreadCount',
                              style: AppType.tabular(AppType.caption).copyWith(
                                fontWeight: FontWeight.w700,
                                color: tk.onAccent,
                              ),
                            ),
                            backgroundColor: tk.accent,
                            textColor: tk.onAccent,
                            offset: const Offset(10, -6),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final (tab, _, empty, hint) in tabs)
                      _List(
                        tab: tab,
                        jobs: buckets.of(tab),
                        empty: empty,
                        hint: hint,
                        onOpen: onOpen,
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

AppTone _toneForJob(Job job) {
  if (job.isEmergency && job.status == JobStatus.open) return AppTone.danger;
  return switch (job.status) {
    JobStatus.open => AppTone.info,
    JobStatus.awaitingPayment => AppTone.warning,
    JobStatus.scheduled => AppTone.info,
    JobStatus.inProgress => AppTone.success,
    JobStatus.awaitingApproval => AppTone.warning,
    JobStatus.completed => AppTone.success,
    JobStatus.canceled => AppTone.neutral,
    JobStatus.disputed => AppTone.danger,
  };
}

class _List extends StatelessWidget {
  const _List({
    required this.tab,
    required this.jobs,
    required this.empty,
    required this.hint,
    required this.onOpen,
  });

  final OrderTab tab;
  final List<Job> jobs;
  final String empty;
  final String hint;
  final void Function(BuildContext context, Job job) onOpen;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: empty,
        message: hint,
      );
    }
    final tk = context.tk;
    final layout = context.layout;
    return RefreshIndicator(
      onRefresh: () async => JobService.notifyJobsChanged(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: layout.margin,
          vertical: AppSpace.s16,
        ),
        itemCount: jobs.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.item),
        itemBuilder: (context, i) {
          final j = jobs[i];
          final isUnread = UnreadOrdersBadgeController.instance.isUnread(
            j,
            tab: tab,
          );
          final headline = SmartOrderHeadlineFormatter.formatHeadline(
            j.title,
            category: j.category,
            fallbackDescription: j.description,
          );
          final statusStyle = jobStatusStyle(context, j);
          final statusChip = AppStatusChip(
            statusStyle.label,
            tone: _toneForJob(j),
            icon: statusStyle.icon,
          );
          final stackPrice = layout.isLargeText || layout.isCompact;
          return AppStaggerItem(
            index: i,
            scope: 'client-orders-${tab.name}',
            child: AppHero(
              tag: 'order-card-${j.id}',
              child: Material(
                type: MaterialType.transparency,
                child: AppCard(
                  key: ValueKey('order-card-${j.id}'),
                  variant: AppCardVariant.elevated,
                  borderColor: isUnread
                      ? tk.accent.withValues(alpha: 0.52)
                      : tk.border,
                  onTap: () {
                    unawaited(
                      UnreadOrdersBadgeController.instance.markViewed(j, tab: tab),
                    );
                    onOpen(context, j);
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CategoryBrandEmblem(
                        categoryName: j.category,
                        size: 50,
                        showCornerBadge: false,
                      ),
                      const SizedBox(width: AppSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              headline,
                              maxLines: 2,
                              style: AppType.titleSm.copyWith(color: tk.text),
                            ),
                            const SizedBox(height: AppSpace.s4),
                            Row(
                              children: [
                                if (isUnread) ...[
                                  Container(
                                    key: ValueKey('order-unread-dot-${j.id}'),
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: tk.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpace.s8),
                                ],
                                Flexible(
                                  child: Text(
                                    '${j.code} • ${relativeTime(j.createdAt)}',
                                    style: AppType.caption.copyWith(color: tk.textMuted),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpace.s8),
                            if (stackPrice && j.agreedPrice != null)
                              Wrap(
                                spacing: AppSpace.s8,
                                runSpacing: AppSpace.s8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  statusChip,
                                  AppPrice(
                                    value: j.agreedPrice!,
                                    size: AppPriceSize.sm,
                                    color: tk.text,
                                  ),
                                ],
                              )
                            else
                              statusChip,
                          ],
                        ),
                      ),
                      if (!stackPrice && j.agreedPrice != null) ...[
                        const SizedBox(width: AppSpace.s8),
                        AppPrice(
                          value: j.agreedPrice!,
                          size: AppPriceSize.sm,
                          color: tk.text,
                        ),
                      ],
                      const SizedBox(width: AppSpace.s4),
                      Icon(Icons.chevron_right_rounded, color: tk.textMuted),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Aba "Perfil" do cliente.
class ClientProfileTab extends StatefulWidget {
  const ClientProfileTab({
    super.key,
    required this.profile,
    @visibleForTesting this.customPhotoPicker,
    @visibleForTesting this.customAvatarUploader,
  });

  final UserProfile profile;
  final StagedPhotoPicker? customPhotoPicker;
  final AvatarBinaryUploader? customAvatarUploader;

  @override
  State<ClientProfileTab> createState() => _ClientProfileTabState();
}

class _ClientProfileTabState extends State<ClientProfileTab> {
  late String? _avatarUrl = widget.profile.avatarUrl;

  bool get _hasPhoto => _avatarUrl != null && _avatarUrl!.trim().isNotEmpty;

  @override
  void didUpdateWidget(covariant ClientProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.avatarUrl != widget.profile.avatarUrl) {
      _avatarUrl = widget.profile.avatarUrl;
    }
  }

  Future<void> _pickAndSavePhoto() async {
    final url = await pickPreviewAndSaveAvatar(
      context,
      userName: widget.profile.officialCivilName,
      currentUrl: _avatarUrl,
      customPicker: widget.customPhotoPicker,
      customUploader: widget.customAvatarUploader,
    );
    if (url != null && mounted) {
      setState(() => _avatarUrl = url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    final profile = widget.profile;
    EagerImagePrefetcher.prefetchUrls([_avatarUrl], context: context);
    final emailSubtitle = profile.emailAddressIfPresent;
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: margin, vertical: AppSpace.s20),
      children: [
        Semantics(
          header: true,
          child: Text(
            'Perfil',
            style: AppType.display.copyWith(color: tk.text),
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        AppCard(
          variant: AppCardVariant.elevated,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EditableAvatar(
                url: _avatarUrl,
                name: profile.officialCivilName,
                radius: 36,
                customPicker: widget.customPhotoPicker,
                customUploader: widget.customAvatarUploader,
                onChanged: (url) {
                  if (mounted) setState(() => _avatarUrl = url);
                },
              ),
              const SizedBox(width: AppSpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.officialCivilName,
                      style: AppType.title.copyWith(color: tk.text),
                    ),
                    if (emailSubtitle != null) ...[
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        emailSubtitle,
                        style: AppType.caption.copyWith(color: tk.textMuted),
                      ),
                    ],
                    const SizedBox(height: AppSpace.s8),
                    Wrap(
                      spacing: AppSpace.s8,
                      runSpacing: AppSpace.s4,
                      children: [
                        const AppStatusChip('Cliente', tone: AppTone.accent),
                        if (profile.hasVerifiedCivilIdentity)
                          const AppStatusChip(
                            'Biometria & Documento Verificados',
                            tone: AppTone.success,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s12),
                    AppButton(
                      key: const Key('client-profile-change-photo-btn'),
                      onPressed: _pickAndSavePhoto,
                      variant: AppButtonVariant.secondary,
                      compact: true,
                      expand: false,
                      icon: _hasPhoto
                          ? Icons.photo_camera_rounded
                          : Icons.add_a_photo_rounded,
                      label: _hasPhoto ? 'Alterar foto' : 'Adicionar foto de perfil',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        const AppQuickUpdateButton(compact: false),
        const SizedBox(height: AppSpace.section),
        Semantics(
          header: true,
          child: Text('Sua conta', style: AppType.title.copyWith(color: tk.text)),
        ),
        const SizedBox(height: AppSpace.s8),
        _Tile(
          kind: ProfileMenuIconKind.clientPassport,
          title: 'Prontuário da Casa (Passaporte)',
          subtitle: 'Histórico auditado e PDF para vistoria/seguradora',
          onTap: () => Navigator.of(context).push(
            AppRoute(
              builder: (_) => PropertyPassportScreen(
                initialOwnerName: profile.officialCivilName,
                initialAddress:
                    (profile.addressLine ?? '').split(' | ').first,
              ),
            ),
          ),
        ),
        _Tile(
          kind: ProfileMenuIconKind.clientAddress,
          title: 'Meu endereço',
          subtitle: (profile.addressLine ?? 'Adicionar endereço')
              .split(' | ')
              .first,
          onTap: () => Navigator.of(context).push(
            AppRoute(
              builder: (_) =>
                  EditAddressScreen(currentLine: profile.addressLine),
            ),
          ),
        ),
        _Tile(
          kind: ProfileMenuIconKind.clientWallet,
          title: 'Minha carteira',
          subtitle: 'Saldo, valor em garantia e extrato',
          onTap: () => Navigator.of(context).push(
            AppRoute(builder: (_) => const CarteiraClienteScreen()),
          ),
        ),
        _Tile(
          kind: ProfileMenuIconKind.clientHistory,
          title: 'Histórico de serviços',
          subtitle: 'Reveja serviços concluídos, fotos e conversas',
          onTap: () => Navigator.of(context).push(
            AppRoute(
              builder: (_) => const HistoricoServicosClienteScreen(),
            ),
          ),
        ),
        _Tile(
          kind: ProfileMenuIconKind.clientAchievements,
          title: 'Minhas conquistas',
          subtitle: 'Troféus por pedidos, avaliações e mais',
          onTap: () => Navigator.of(context).push(
            AppRoute(
              builder: (_) => ClientAchievementsScreen(profile: profile),
            ),
          ),
        ),
        _Tile(
          kind: ProfileMenuIconKind.clientSupport,
          title: 'Ajuda e suporte',
          subtitle: 'Fale com a central e acompanhe seus chamados',
          onTap: () => Navigator.of(context).push(
            AppRoute(builder: (_) => const SupportCenterScreen()),
          ),
        ),
        _Tile(
          kind: ProfileMenuIconKind.clientPassport,
          title: 'Termos de Uso e Mandato Legal',
          subtitle: 'Contrato, custódia e cláusula-mandato oficial',
          onTap: () => Navigator.of(context).push(
            AppRoute(
              builder: (_) => const VerificacaoStep6cTermosScreen(),
            ),
          ),
        ),
        AppearanceTile(
          accent: tk.accentInk,
          soft: tk.accentSoft,
          kind: ProfileMenuIconKind.clientAppearance,
        ),
        _Tile(
          kind: ProfileMenuIconKind.deleteAccount,
          title: 'Excluir conta',
          subtitle: 'Receba seu dossiê e apague seus dados',
          onTap: () => Navigator.of(context).push(
            AppRoute(builder: (_) => const DeleteAccountScreen()),
          ),
        ),
        const SizedBox(height: AppSpace.section),
        InfoBanner(
          profile.isProvider
              ? 'Você também é profissional. Troque de modo quando quiser.'
              : 'Sabe fazer algum serviço? Cadastre-se como profissional e receba pedidos na sua região.',
          tone: BannerTone.promo,
          icon: Icons.swap_horiz_rounded,
        ),
        const SizedBox(height: AppSpace.s12),
        AppButton(
          label: profile.isProvider
              ? 'Ir para o modo Profissional'
              : 'Quero trabalhar como profissional',
          icon: Icons.engineering_rounded,
          variant: AppButtonVariant.secondary,
          onPressed: () => AppSession.instance.choose(UserMode.provider),
        ),
        const SizedBox(height: AppSpace.s12),
        TextButton.icon(
          onPressed: () async {
            final ok = await AppDialog.confirm(
              context,
              title: 'Sair da conta?',
              message:
                  'Você precisará entrar novamente para acessar seus pedidos.',
              confirmLabel: 'Sair',
              destructive: true,
            );
            if (ok) await ProfileService().signOut();
          },
          style: TextButton.styleFrom(
            minimumSize: const Size(AppGeometry.minTarget, AppGeometry.minTarget),
            foregroundColor: tk.dangerInk,
          ),
          icon: Icon(Icons.logout_rounded, color: tk.dangerInk),
          label: Text(
            'Sair da conta',
            style: AppType.bodyStrong.copyWith(color: tk.dangerInk),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final ProfileMenuIconKind kind;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      leading: ProfileMenuEmblem(kind: kind, size: 42),
      title: title,
      subtitle: subtitle,
      showChevron: true,
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
      onTap: onTap,
    );
  }
}

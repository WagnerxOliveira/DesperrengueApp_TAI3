import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/instant_image_cache_engine.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/state/provider_portfolio_controller.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart' show BannerTone, InfoBanner;
import '../../provider/presentation/provider_portfolio_widgets.dart';
import '../../shared/presentation/achievement_widgets.dart';
import '../../shared/presentation/review_widgets.dart';
import '../../shared/presentation/showcase_widgets.dart';
import 'request_wizard.dart';

/// Perfil público do profissional (protótipos 3, 4 e 5).
class ProviderPublicProfileScreen extends StatefulWidget {
  const ProviderPublicProfileScreen({
    super.key,
    required this.provider,
    this.category,
    required this.profile,
    this.hideCta = false,
  });

  final ProviderCard provider;
  final String? category;
  final UserProfile profile;

  /// Escondido quando o cliente já tem um pedido com este profissional.
  final bool hideCta;

  @override
  State<ProviderPublicProfileScreen> createState() => _ProviderPublicProfileScreenState();
}

class _ProviderPublicProfileScreenState extends State<ProviderPublicProfileScreen> {
  final _service = ProviderService();
  late final Future<List<PortfolioItem>> _portfolio;
  late final Future<List<PublicReview>> _reviews;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    EagerImagePrefetcher.prefetchUrls([widget.provider.avatarUrl]);
    _portfolio = _service.portfolio(widget.provider.id)
      ..then(
        (items) {
          EagerImagePrefetcher.prefetchPublicPaths(
            items.map((e) => e.imagePath),
            context: mounted ? context : null,
          );
        },
        onError: (_) {},
      );
    _reviews = _service.reviews(widget.provider.id, limit: 60)
      ..then(
        (items) {
          EagerImagePrefetcher.prefetchPublicPaths(
            items.expand((r) => r.photoPaths),
            context: mounted ? context : null,
          );
        },
        onError: (_) {},
      );
  }

  @override
  void didUpdateWidget(covariant ProviderPublicProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider.avatarUrl != widget.provider.avatarUrl) {
      EagerImagePrefetcher.prefetchUrls([widget.provider.avatarUrl]);
    }
  }

  /// O usuário está vendo o PRÓPRIO perfil profissional (visão do cliente).
  bool get _isSelf => widget.provider.id == widget.profile.id;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final p = widget.provider;
    final margin = context.layout.margin;
    final stack = context.layout.isLargeText;
    final headerBg = tk.clientAccent;
    final headerFg = AppTokens.onColor(headerBg);

    return AppScaffold(
      backgroundColor: tk.card,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: headerBg,
            foregroundColor: headerFg,
            flexibleSpace: FlexibleSpaceBar(
              background: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tk.clientAccent,
                      tk.clientAccent.withValues(alpha: tk.isDark ? 0.78 : 0.86),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: tk.card,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppGeometry.heroRadius),
                ),
              ),
              padding: EdgeInsets.fromLTRB(margin, AppSpace.s20, margin, AppSpace.s32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AppHero(
                        tag: 'provider-avatar-${p.id}',
                        child: AppAvatar(
                          url: p.avatarUrl,
                          name: p.fullName,
                          radius: 40,
                          verified: true,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.fullName,
                              style: AppType.headline.copyWith(color: tk.text),
                            ),
                            const SizedBox(height: AppSpace.s2),
                            Text(
                              p.title,
                              style: AppType.titleSm.copyWith(color: tk.clientAccentInk),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s20),
                  if (_isSelf) ...[
                    const InfoBanner(
                      'É assim que os clientes veem você. Só você enxerga este aviso.',
                      tone: BannerTone.promo,
                      icon: Icons.visibility_outlined,
                      title: 'Visão do cliente',
                    ),
                    const SizedBox(height: AppSpace.s16),
                  ],
                  AppCard(
                    variant: AppCardVariant.elevated,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s16,
                      vertical: AppSpace.s16,
                    ),
                    child: stack
                        ? Column(
                            children: [
                              _RatingSummaryBlock(provider: p),
                              Divider(height: AppSpace.s24, color: tk.border),
                              _JobsDoneSummaryBlock(provider: p),
                            ],
                          )
                        : IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(child: _RatingSummaryBlock(provider: p)),
                                VerticalDivider(
                                  width: AppSpace.s24,
                                  thickness: 1,
                                  color: tk.border,
                                ),
                                Expanded(child: _JobsDoneSummaryBlock(provider: p)),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: AppSpace.section),
                  AppSection(
                    title: 'Sobre o Profissional',
                    child: Text(
                      (p.bio != null && p.bio!.trim().isNotEmpty)
                          ? p.bio!
                          : 'Este profissional ainda não escreveu uma apresentação, mas teve a identidade e o registro verificados pela Desperrengue.',
                      style: AppType.body.copyWith(color: tk.text),
                    ),
                  ),
                  if (p.specialties.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.section),
                    AppSection(
                      title: 'Especialidades',
                      child: Wrap(
                        spacing: AppSpace.s8,
                        runSpacing: AppSpace.s8,
                        children: [
                          for (final s in p.specialties)
                            Chip(
                              label: Text(s, style: AppType.bodySm.copyWith(color: tk.text)),
                              avatar: Icon(categoryIcon(s), size: 16, color: tk.accentInk),
                            ),
                        ],
                      ),
                    ),
                  ],
                  // Vitrine de serviços verificados: Top 3 recentes (LIFO) + até 5 destaques escolhidos.
                  ShowcaseStrip(providerId: p.id),
                  ListenableBuilder(
                    listenable: ProviderPortfolioStore.instance,
                    builder: (context, _) {
                      final publicServices =
                          ProviderPortfolioStore.instance.state.publicPortfolioServices;
                      if (publicServices.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return const Padding(
                        padding: EdgeInsets.only(top: AppSpace.s16),
                        child: ProviderSmartPortfolioSection(
                          isOwner: false,
                          syncOnMount: false,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpace.section),
                  AppSection(
                    title: 'Portfólio',
                    child: FutureBuilder<List<PortfolioItem>>(
                      future: _portfolio,
                      builder: (context, snap) {
                        final loading = snap.connectionState != ConnectionState.done;
                        final items = snap.data ?? const <PortfolioItem>[];
                        return AppSkeletonSwitcher(
                          loading: loading,
                          skeleton: const SizedBox(
                            height: 130,
                            child: Row(
                              children: [
                                AppSkeleton(width: 130, height: 130, radius: AppGeometry.itemRadius),
                                SizedBox(width: AppSpace.s12),
                                AppSkeleton(width: 130, height: 130, radius: AppGeometry.itemRadius),
                              ],
                            ),
                          ),
                          child: items.isEmpty
                              ? Text(
                                  'Ainda sem trabalhos publicados.',
                                  style: AppType.body.copyWith(color: tk.textMuted),
                                )
                              : SizedBox(
                                  height: 130,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: items.length,
                                    separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s12),
                                    itemBuilder: (_, i) {
                                      final allPaths = items.map((e) => e.imagePath).toList();
                                      return AppPressable(
                                        borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
                                        semanticLabel: items[i].caption ?? 'Foto do portfólio',
                                        onTap: () => PortfolioFullScreenPhotoViewer.open(
                                          context,
                                          photos: allPaths,
                                          initialIndex: i,
                                          serviceTitle: items[i].caption ?? p.fullName,
                                          usePublicBucket: true,
                                        ),
                                        child: PublicImage(
                                          path: items[i].imagePath,
                                          width: 130,
                                          height: 130,
                                          radius: AppGeometry.itemRadius,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                  if (p.badges.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.section),
                    AppSection(
                      title: 'Selos conquistados',
                      child: BadgeWall(earned: p.badges),
                    ),
                  ],
                  const SizedBox(height: AppSpace.section),
                  AppSection(
                    title: 'Conquistas',
                    child: AchievementsSection(providerId: p.id, providerName: p.fullName),
                  ),
                  const SizedBox(height: AppSpace.section),
                  AppSection(
                    title: 'Avaliações de clientes',
                    child: FutureBuilder<List<PublicReview>>(
                      future: _reviews,
                      builder: (context, snap) {
                        final loading = snap.connectionState != ConnectionState.done;
                        final items = snap.data ?? const <PublicReview>[];
                        final photos = [for (final r in items) ...r.photoPaths];
                        return AppSkeletonSwitcher(
                          loading: loading,
                          skeleton: const AppSkeletonList(count: 2, padding: EdgeInsets.zero),
                          child: items.isEmpty
                              ? Text(
                                  'Ainda não há avaliações.',
                                  style: AppType.body.copyWith(color: tk.textMuted),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppSegmented<int>(
                                      segments: [
                                        AppSegment(
                                          value: 0,
                                          label: 'Avaliações (${items.length})',
                                        ),
                                        AppSegment(
                                          value: 1,
                                          label: 'Fotos de clientes (${photos.length})',
                                          icon: Icons.photo_library_outlined,
                                        ),
                                      ],
                                      selected: _tab,
                                      onChanged: (v) => setState(() => _tab = v),
                                    ),
                                    const SizedBox(height: AppSpace.s12),
                                    if (_tab == 0)
                                      for (final r in items) ReviewCard(review: r)
                                    else if (photos.isEmpty)
                                      Text(
                                        'Nenhum cliente enviou fotos ainda.',
                                        style: AppType.body.copyWith(color: tk.textMuted),
                                      )
                                    else
                                      GridView.count(
                                        crossAxisCount: context.layout.isCompact ? 2 : 3,
                                        mainAxisSpacing: AppSpace.s8,
                                        crossAxisSpacing: AppSpace.s8,
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        children: [
                                          for (final path in photos)
                                            Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                PublicImage(
                                                  path: path,
                                                  radius: AppGeometry.iconTileRadius,
                                                ),
                                                Positioned(
                                                  left: AppSpace.s4,
                                                  right: AppSpace.s4,
                                                  bottom: AppSpace.s4,
                                                  child: Align(
                                                    alignment: Alignment.bottomLeft,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: AppSpace.s8,
                                                        vertical: AppSpace.s2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: tk.successSoft,
                                                        borderRadius: BorderRadius.circular(
                                                          AppGeometry.pillRadius,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.verified_rounded,
                                                            size: 13,
                                                            color: tk.successInk,
                                                          ),
                                                          const SizedBox(width: AppSpace.s4),
                                                          Flexible(
                                                            child: Text(
                                                              'Verificado',
                                                              style: AppType.caption.copyWith(
                                                                fontWeight: FontWeight.w600,
                                                                color: tk.successInk,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                  ],
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isSelf
          ? const AppBottomBar(
              child: InfoBanner(
                'Você não pode solicitar serviços a si mesmo. Para editar este perfil, entre no modo profissional.',
                tone: BannerTone.info,
                icon: Icons.lock_outline_rounded,
                title: 'Este é o seu perfil profissional',
              ),
            )
          : widget.hideCta
              ? null
              : AppBottomBar(
                  child: stack
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppInfoRow(
                              label: 'Taxa de visita',
                              valueWidget: AppPrice(
                                value: p.visitFee,
                                size: AppPriceSize.sm,
                                color: tk.clientAccentInk,
                              ),
                            ),
                            const SizedBox(height: AppSpace.s8),
                            _RequestCtaButton(
                              provider: p,
                              profile: widget.profile,
                              category: widget.category,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Taxa de visita:',
                                  style: AppType.caption.copyWith(color: tk.textMuted),
                                ),
                                AppPrice(
                                  value: p.visitFee,
                                  size: AppPriceSize.sm,
                                  color: tk.clientAccentInk,
                                ),
                              ],
                            ),
                            const SizedBox(width: AppSpace.s16),
                            Expanded(
                              child: _RequestCtaButton(
                                provider: p,
                                profile: widget.profile,
                                category: widget.category,
                              ),
                            ),
                          ],
                        ),
                ),
    );
  }
}

class _RatingSummaryBlock extends StatelessWidget {
  const _RatingSummaryBlock({required this.provider});

  final ProviderCard provider;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          provider.ratingCount > 0
              ? provider.ratingAvg.toStringAsFixed(1).replaceAll('.', ',')
              : '—',
          style: AppType.figure.copyWith(color: tk.text),
        ),
        const SizedBox(height: AppSpace.s4),
        AppRating(value: provider.ratingAvg, size: 16),
        const SizedBox(height: AppSpace.s4),
        Text(
          '(${provider.ratingCount} avaliações)',
          textAlign: TextAlign.center,
          style: AppType.tabular(AppType.caption).copyWith(color: tk.textMuted),
        ),
      ],
    );
  }
}

class _JobsDoneSummaryBlock extends StatelessWidget {
  const _JobsDoneSummaryBlock({required this.provider});

  final ProviderCard provider;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_rounded, color: tk.clientAccentInk, size: 30),
        const SizedBox(height: AppSpace.s4),
        Text(
          '${provider.jobsDone} serviços',
          textAlign: TextAlign.center,
          style: AppType.tabular(AppType.titleSm).copyWith(color: tk.text),
        ),
        Text(
          'finalizados',
          textAlign: TextAlign.center,
          style: AppType.caption.copyWith(color: tk.textMuted),
        ),
      ],
    );
  }
}

class _RequestCtaButton extends StatelessWidget {
  const _RequestCtaButton({
    required this.provider,
    required this.profile,
    required this.category,
  });

  final ProviderCard provider;
  final UserProfile profile;
  final String? category;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Solicitar Serviço',
      trailingArrow: true,
      onPressed: provider.accepting
          ? () => Navigator.of(context).push(
                AppRoute(
                  builder: (_) => RequestWizardScreen(
                    profile: profile,
                    provider: provider,
                    category: category,
                  ),
                ),
              )
          : null,
    );
  }
}

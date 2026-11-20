import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/provider_filters.dart';
import '../../shared/presentation/review_widgets.dart';
import 'provider_public_profile_screen.dart';
import 'request_wizard.dart';

enum _Sort { nearest, rating, fee }

/// Carrega os profissionais (produção: [ProviderService.search]). Injetável nos testes.
typedef ProviderSearchLoader = Future<List<ProviderCard>> Function({String? category, String? query, required bool includeSelf});

/// Busca e listagem de profissionais (protótipo 2.jpg).
class ProviderSearchScreen extends StatefulWidget {
  const ProviderSearchScreen({
    super.key,
    this.category,
    this.query,
    required this.profile,
    this.onPick,
    this.pickTitle,
    this.excludeIds = const {},
    @visibleForTesting this.loader,
  });

  /// Modo "escolher": ao tocar num profissional, devolve a escolha (sem abrir o perfil).
  final Future<void> Function(ProviderCard)? onPick;
  final String? pickTitle;
  final Set<String> excludeIds;
  final String? category;
  final String? query;
  final UserProfile profile;
  final ProviderSearchLoader? loader;

  @override
  State<ProviderSearchScreen> createState() => _ProviderSearchScreenState();
}

class _ProviderSearchScreenState extends State<ProviderSearchScreen> {
  // Preguiçoso: só toca o Supabase quando não há `loader` injetado (testes).
  late final _service = ProviderService();
  late final TextEditingController _controller = TextEditingController(text: widget.query ?? widget.category ?? '');
  late Future<List<ProviderCard>> _future;
  _Sort _sort = _Sort.nearest;
  int _radiusIdx = kRadiusAllIndex;
  int? get _radiusKm => kRadiusSteps[_radiusIdx];
  String? _category;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _future = _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Categoria efetiva da busca: a escolhida na tela anterior ou a que o termo digitado
  /// representa (inclusive por sinônimo: "eletricista" → Elétrica).
  String? get _effectiveCategory => categoryNameForTerm(_controller.text) ?? _category;

  Future<List<ProviderCard>> _load() async {
    final term = _controller.text.trim();
    final matched = categoryNameForTerm(term);
    final category = matched ?? _category;
    final text = matched != null ? null : term;
    final search = widget.loader ?? _service.search;
    final list = await search(category: category, query: text, includeSelf: widget.onPick == null);
    return list.where((p) => !widget.excludeIds.contains(p.id)).toList();
  }

  void _refresh() => setState(() {
        _future = _load();
      });

  List<ProviderCard> _sorted(List<ProviderCard> list) {
    final l = [...list];
    switch (_sort) {
      case _Sort.nearest:
        l.sort((a, b) => (a.distanceKm ?? 9999).compareTo(b.distanceKm ?? 9999));
      case _Sort.rating:
        // Nota de ranqueamento (Média Bayesiana): evita que 1 serviço nota 5 passe 85 serviços nota 4,88.
        l.sort((a, b) => b.rankingValue.compareTo(a.rankingValue));
      case _Sort.fee:
        l.sort((a, b) => a.visitFee.compareTo(b.visitFee));
    }
    // O próprio perfil profissional (se houver) vem primeiro, identificado.
    l.sort((a, b) => (a.id == widget.profile.id ? 0 : 1).compareTo(b.id == widget.profile.id ? 0 : 1));
    return l;
  }

  void _openPublishWizard() {
    Navigator.of(context).push(
      AppRoute(builder: (_) => RequestWizardScreen(profile: widget.profile, category: _effectiveCategory)),
    );
  }

  Future<void> _onTapProvider(ProviderCard p) async {
    if (widget.onPick != null) {
      final ok = await AppDialog.confirm(
        context,
        title: 'Enviar para ${p.fullName}?',
        message: 'O mesmo pedido será enviado a este profissional. Você pode ter até 3 profissionais por pedido.',
        confirmLabel: 'Enviar pedido',
      );
      if (ok) {
        await widget.onPick!(p);
        if (mounted) Navigator.pop(context);
      }
      return;
    }
    Navigator.of(context).push(
      AppRoute(
        builder: (_) => ProviderPublicProfileScreen(provider: p, category: _effectiveCategory, profile: widget.profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    final title = _controller.text.trim().isEmpty ? 'Profissionais' : _controller.text.trim();
    final category = _effectiveCategory;
    return AppScaffold(
      appBar: AppAppBar(
        centerTitle: false,
        titleWidget: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          style: AppType.body.copyWith(color: tk.text),
          onSubmitted: (_) {
            _category = null;
            _refresh();
          },
          decoration: InputDecoration(
            hintText: 'Buscar profissional ou serviço',
            filled: true,
            fillColor: tk.isDark ? tk.surface : tk.surfaceInset,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppGeometry.fieldRadius), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppGeometry.fieldRadius), borderSide: BorderSide.none),
            suffixIcon: AppIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Limpar busca',
              onPressed: () {
                _controller.clear();
                _category = null;
                _refresh();
              },
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<ProviderCard>>(
        future: _future,
        builder: (context, snap) {
          final loading = snap.connectionState != ConnectionState.done;
          Widget content;
          if (loading) {
            content = const SizedBox.shrink();
          } else if (snap.hasError) {
            content = AppErrorState(message: 'Não foi possível buscar profissionais.', onRetry: _refresh);
          } else {
            final all = snap.data ?? const <ProviderCard>[];
            final list = _sorted(applyRadius(
              all,
              clientLat: widget.profile.latitude,
              clientLng: widget.profile.longitude,
              radiusKm: _radiusKm,
              clientCity: widget.profile.addressCity,
            ));
            content = ListView(
              padding: EdgeInsets.fromLTRB(layout.margin, AppSpace.s8, layout.margin, AppSpace.s24),
              children: [
                Text('Resultados para "$title"', style: AppType.headline.copyWith(color: tk.text)),
                const SizedBox(height: AppSpace.s12),
                RadiusSlider(index: _radiusIdx, onChanged: (i) => setState(() => _radiusIdx = i)),
                const SizedBox(height: AppSpace.s12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (s, label, icon) in const [
                        (_Sort.nearest, 'Mais próximos', Icons.near_me_rounded),
                        (_Sort.rating, 'Melhor avaliados', Icons.star_rounded),
                        (_Sort.fee, 'Menor taxa', Icons.payments_outlined),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpace.s8),
                          child: ChoiceChip(
                            avatar: Icon(
                              icon,
                              size: 16,
                              color: _sort == s ? tk.onAccent : tk.accentInk,
                            ),
                            label: Text(label),
                            selected: _sort == s,
                            onSelected: (_) => setState(() => _sort = s),
                            labelStyle: AppType.bodySm.copyWith(
                              color: _sort == s ? tk.onAccent : tk.text,
                              fontWeight: FontWeight.w600,
                            ),
                            showCheckmark: false,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s16),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.s24),
                    child: _radiusKm == null
                        ? const AppEmptyState(
                            icon: Icons.person_search_rounded,
                            title: 'Nenhum profissional encontrado',
                            message: 'Ainda estamos crescendo na sua região. Publique o pedido para receber orçamentos assim que alguém se cadastrar.',
                          )
                        : AppEmptyState(
                            icon: Icons.radar_rounded,
                            title: 'Ninguém em até ${radiusLabel(_radiusKm)}',
                            message: all.isEmpty
                                ? 'Ainda estamos crescendo na sua região. Publique o pedido para receber orçamentos assim que alguém se cadastrar.'
                                : 'Há ${all.length} ${all.length == 1 ? 'profissional' : 'profissionais'} fora desse raio. Amplie a busca para ver todos.',
                            actionLabel: all.isEmpty ? null : 'Ver toda a região',
                            onAction: all.isEmpty ? null : () => setState(() => _radiusIdx = kRadiusAllIndex),
                          ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s12),
                    child: Text(
                      '${list.length} ${list.length == 1 ? 'profissional' : 'profissionais'}'
                      '${category != null ? ' de $category' : ''} • ${radiusLabel(_radiusKm)}',
                      style: AppType.tabular(AppType.bodySm).copyWith(color: tk.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ),
                  _ProviderResultsGrid(
                    providers: list,
                    selfId: widget.profile.id,
                    columns: layout.gridColumns,
                    onTap: _onTapProvider,
                  ),
                ],
                const SizedBox(height: AppSpace.s12),
                if (widget.onPick == null) AreaPublishButton(categoryName: category, onPressed: _openPublishWizard),
              ],
            );
          }

          return AppSkeletonSwitcher(
            loading: loading,
            skeleton: AppSkeletonList(
              count: 5,
              padding: EdgeInsets.fromLTRB(layout.margin, AppSpace.s16, layout.margin, AppSpace.s24),
            ),
            child: content,
          );
        },
      ),
    );
  }
}

class _ProviderResultsGrid extends StatelessWidget {
  const _ProviderResultsGrid({
    required this.providers,
    required this.selfId,
    required this.columns,
    required this.onTap,
  });

  final List<ProviderCard> providers;
  final String selfId;
  final int columns;
  final ValueChanged<ProviderCard> onTap;

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return AppStagger(
        scope: 'provider-search-results',
        spacing: AppSpace.item,
        children: [
          for (final p in providers)
            _ProviderTile(
              provider: p,
              isSelf: p.id == selfId,
              onTap: () => onTap(p),
            ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final itemWidth = (c.maxWidth - AppSpace.s12 * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpace.s12,
          runSpacing: AppSpace.s12,
          children: [
            for (var i = 0; i < providers.length; i++)
              SizedBox(
                width: itemWidth,
                child: AppStaggerItem(
                  index: i,
                  scope: 'provider-search-results',
                  child: _ProviderTile(
                    provider: providers[i],
                    isSelf: providers[i].id == selfId,
                    onTap: () => onTap(providers[i]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Raio de alcance como **barra de arrastar** (mesmo padrão do "Raio de atendimento" do
/// profissional): arrasta de 1 km até 100 km; o último degrau é "Toda a região".
class RadiusSlider extends StatelessWidget {
  const RadiusSlider({super.key, required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final km = kRadiusSteps[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.radar_rounded, size: 18, color: tk.accentInk),
                const SizedBox(width: AppSpace.s8 - 2),
                Flexible(
                  child: Text(
                    'Raio de alcance',
                    style: AppType.bodyStrong.copyWith(color: tk.text),
                  ),
                ),
              ],
            ),
            Container(
              key: const ValueKey('radius-value'),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s4 + 1),
              decoration: BoxDecoration(
                color: tk.accentSoft,
                borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
              ),
              child: Text(
                radiusLabel(km),
                style: AppType.tabular(AppType.caption).copyWith(
                  fontWeight: FontWeight.w700,
                  color: tk.accentInk,
                ),
              ),
            ),
          ],
        ),
        Slider(
          key: const ValueKey('radius-slider'),
          value: index.toDouble(),
          min: 0,
          max: (kRadiusSteps.length - 1).toDouble(),
          divisions: kRadiusSteps.length - 1,
          label: radiusLabel(km),
          onChanged: (v) => onChanged(v.round()),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 km', style: AppType.tabular(AppType.caption).copyWith(color: tk.textMuted)),
              Text('Toda a região', style: AppType.caption.copyWith(color: tk.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Botão de publicação coletiva: o pedido vai SÓ para profissionais da especialidade escolhida.
class AreaPublishButton extends StatelessWidget {
  const AreaPublishButton({super.key, required this.categoryName, required this.onPressed});

  final String? categoryName;
  final VoidCallback onPressed;

  static const title = 'Publicar pedido para profissionais da área';

  String get subtitle => categoryName == null
      ? 'Não quer escolher da lista? Envie seu pedido apenas para profissionais com a especialidade certa disponíveis.'
      : 'Não quer escolher da lista? Envie seu pedido apenas para profissionais com a especialidade $categoryName disponíveis.';

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      variant: AppCardVariant.tonal,
      color: tk.accentSoft,
      borderColor: tk.accent.withValues(alpha: 0.45),
      onTap: onPressed,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: tk.accent,
            child: Icon(
              categoryName == null ? Icons.campaign_rounded : categoryIcon(categoryName!),
              color: tk.onAccent,
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.titleSm.copyWith(color: tk.text)),
                const SizedBox(height: AppSpace.s4),
                Text(subtitle, style: AppType.bodySm.copyWith(color: tk.text)),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Icon(Icons.arrow_forward_rounded, color: tk.accentInk),
        ],
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.provider, required this.onTap, this.isSelf = false});

  final ProviderCard provider;
  final VoidCallback onTap;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final p = provider;
    final cold = isNewOnPlatform(p);
    return AppCard(
      variant: AppCardVariant.elevated,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(url: p.avatarUrl, name: p.fullName, radius: 28, verified: true),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(p.fullName, style: AppType.titleSm.copyWith(color: tk.text)),
                    if (isSelf)
                      const AppStatusChip('Você', tone: AppTone.info, icon: Icons.person_pin_rounded),
                  ],
                ),
                const SizedBox(height: AppSpace.s2),
                Text(p.title, style: AppType.bodySm.copyWith(color: tk.textMuted)),
                const SizedBox(height: AppSpace.s8),
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (p.ratingCount > 0)
                      AppRating(value: p.ratingAvg, count: p.ratingCount, showValue: true, size: 16),
                    // Cold-start: 0 serviços concluídos NÃO esconde o profissional; ele ganha um selo.
                    if (cold)
                      const AppStatusChip('Novo na plataforma • Verificado', tone: AppTone.info, icon: Icons.verified_rounded)
                    else if (p.isSuper)
                      const AppStatusChip('Super Profissional', tone: AppTone.accent, icon: Icons.local_fire_department_rounded)
                    else
                      const AppStatusChip('Perfil Verificado', tone: AppTone.info, icon: Icons.verified_rounded),
                  ],
                ),
                if (p.badges.any((b) => b != ProviderBadge.superPro.code)) ...[
                  const SizedBox(height: AppSpace.s8),
                  BadgeChips([for (final b in p.badges) if (b != ProviderBadge.superPro.code) b], max: 2),
                ],
                const SizedBox(height: AppSpace.s8),
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Taxa de visita:', style: AppType.bodySm.copyWith(color: tk.textMuted)),
                    AppPrice(value: p.visitFee, size: AppPriceSize.sm),
                    if (p.distanceKm != null)
                      Text(
                        '• ${distanceLabel(p.distanceKm)}',
                        style: AppType.tabular(AppType.bodySm).copyWith(color: tk.textMuted),
                      ),
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

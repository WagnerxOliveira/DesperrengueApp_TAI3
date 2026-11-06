import '../../../core/ui/app_scaffold.dart';
import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
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
      MaterialPageRoute(builder: (_) => RequestWizardScreen(profile: widget.profile, category: _effectiveCategory)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _controller.text.trim().isEmpty ? 'Profissionais' : _controller.text.trim();
    final category = _effectiveCategory;
    return AppScaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            _category = null;
            _refresh();
          },
          decoration: InputDecoration(
            hintText: 'Buscar profissional ou serviço',
            filled: true,
            fillColor: context.tk.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            suffixIcon: IconButton(
              icon: const Icon(Icons.close_rounded),
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
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(message: 'Não foi possível buscar profissionais.', onRetry: _refresh);
          final all = snap.data ?? const <ProviderCard>[];
          final list = _sorted(applyRadius(
            all,
            clientLat: widget.profile.latitude,
            clientLng: widget.profile.longitude,
            radiusKm: _radiusKm,
            clientCity: widget.profile.addressCity,
          ));
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Text('Resultados para "$title"', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              RadiusSlider(index: _radiusIdx, onChanged: (i) => setState(() => _radiusIdx = i)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (s, label) in [(_Sort.nearest, 'Mais próximos 📍'), (_Sort.rating, 'Melhor avaliados ★'), (_Sort.fee, 'Menor taxa')])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _sort == s,
                          onSelected: (_) => setState(() => _sort = s),
                          labelStyle: TextStyle(color: _sort == s ? Theme.of(context).colorScheme.onPrimary : context.tk.text, fontWeight: FontWeight.w700),
                          showCheckmark: false,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: _radiusKm == null
                      ? const EmptyView(
                          icon: Icons.person_search_rounded,
                          title: 'Nenhum profissional encontrado',
                          subtitle: 'Ainda estamos crescendo na sua região. Publique o pedido para receber orçamentos assim que alguém se cadastrar.',
                        )
                      : EmptyView(
                          icon: Icons.radar_rounded,
                          title: 'Ninguém em até ${radiusLabel(_radiusKm)}',
                          subtitle: all.isEmpty
                              ? 'Ainda estamos crescendo na sua região. Publique o pedido para receber orçamentos assim que alguém se cadastrar.'
                              : 'Há ${all.length} ${all.length == 1 ? 'profissional' : 'profissionais'} fora desse raio. Amplie a busca para ver todos.',
                          action: all.isEmpty
                              ? null
                              : PrimaryButton(label: 'Ver toda a região', onPressed: () => setState(() => _radiusIdx = kRadiusAllIndex)),
                        ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${list.length} ${list.length == 1 ? 'profissional' : 'profissionais'}'
                    '${category != null ? ' de $category' : ''} • ${radiusLabel(_radiusKm)}',
                    style: TextStyle(color: context.tk.textMuted, fontWeight: FontWeight.w600),
                  ),
                ),
                for (final p in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ProviderTile(
                      provider: p,
                      isSelf: p.id == widget.profile.id,
                      onTap: () async {
                        if (widget.onPick != null) {
                          final ok = await confirmDialog(
                            context,
                            title: 'Enviar para ${p.fullName}?',
                            message: 'O mesmo pedido será enviado a este profissional. Você pode ter até 3 profissionais por pedido.',
                            confirmLabel: 'Enviar pedido',
                          );
                          if (ok) {
                            await widget.onPick!(p);
                            if (context.mounted) Navigator.pop(context);
                          }
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProviderPublicProfileScreen(provider: p, category: _effectiveCategory, profile: widget.profile),
                          ),
                        );
                      },
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              if (widget.onPick == null) AreaPublishButton(categoryName: category, onPressed: _openPublishWizard),
            ],
          );
        },
      ),
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
        Row(
          children: [
            Icon(Icons.radar_rounded, size: 18, color: tk.clientAccent),
            const SizedBox(width: 6),
            const Flexible(
              child: Text('Raio de alcance', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            const Spacer(),
            Container(
              key: const ValueKey('radius-value'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: tk.clientSoft, borderRadius: BorderRadius.circular(20)),
              child: Text(radiusLabel(km), style: TextStyle(fontWeight: FontWeight.w900, color: tk.clientAccent)),
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
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 km', style: TextStyle(fontSize: 11.5, color: tk.textMuted)),
              Text('Toda a região', style: TextStyle(fontSize: 11.5, color: tk.textMuted)),
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
    return Material(
      color: tk.clientSoft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tk.clientAccent.withValues(alpha: 0.55), width: 1.4),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: tk.clientAccent,
                child: Icon(categoryName == null ? Icons.campaign_rounded : categoryIcon(categoryName!), color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: tk.text, fontSize: 13, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, color: tk.clientAccent),
            ],
          ),
        ),
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
    final p = provider;
    final cold = isNewOnPlatform(p);
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(url: p.avatarUrl, name: p.fullName, radius: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
                    if (isSelf) ...[
                      const SizedBox(width: 8),
                      StatusChip('Você', color: context.tk.providerAccent, icon: Icons.person_pin_rounded),
                    ],
                  ],
                ),
                Text(p.title, style: TextStyle(color: context.tk.textMuted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (p.ratingCount > 0)
                      Text.rich(TextSpan(children: [
                        WidgetSpan(child: Icon(Icons.star_rounded, size: 16, color: context.tk.star)),
                        TextSpan(
                          text: ' ${p.ratingAvg.toStringAsFixed(1).replaceAll('.', ',')} (${p.ratingCount})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ])),
                    // Cold-start: 0 serviços concluídos NÃO esconde o profissional; ele ganha um selo.
                    if (cold)
                      StatusChip('Novo na plataforma • Verificado', color: context.tk.info, icon: Icons.verified_rounded)
                    else if (p.isSuper)
                      StatusChip('Super Profissional', color: context.tk.clientAccent, icon: Icons.local_fire_department_rounded)
                    else
                      StatusChip('Perfil Verificado', color: context.tk.info, icon: Icons.verified_rounded),
                  ],
                ),
                if (p.badges.any((b) => b != ProviderBadge.superPro.code)) ...[
                  const SizedBox(height: 6),
                  BadgeChips([for (final b in p.badges) if (b != ProviderBadge.superPro.code) b], max: 2),
                ],
                const SizedBox(height: 6),
                Text(
                  'Taxa de visita: ${brl(p.visitFee)}${p.distanceKm != null ? ' • ${distanceLabel(p.distanceKm)}' : ''}',
                  style: TextStyle(fontSize: 13, color: context.tk.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import '../../../core/ui/app_scaffold.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../../../core/models/client_dossier_models.dart';
import '../../../core/models/marketplace_models.dart';
import '../../../core/models/scheduling_models.dart' show DestinationPrecision;
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/instant_image_cache_engine.dart';
import '../../../core/services/scheduling_service.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/media_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/state/unread_orders_badge_controller.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/names.dart';
import '../../shared/presentation/chat_screen.dart';
import '../../shared/presentation/order_live_map_modal_screen.dart';
import 'client_job_screen.dart';
import 'provider_public_profile_screen.dart';

/// Carrega o dossiê do serviço (produção: RPC `client_job_dossier`).
typedef DossierLoader = Future<ClientDossier?> Function(String jobId);

/// Carrega o [Job] (necessário para abrir o chat arquivado).
typedef JobLoader = Future<Job?> Function(String jobId);

/// Desenha uma imagem privada do serviço (produção: [SignedImage]).
typedef EvidenceImageBuilder = Widget Function(BuildContext context, String path, BoxFit fit);

/// Orçamento recebido, já com o nome do profissional (para a lista "Orçamentos recebidos").
class DetailQuote {
  const DetailQuote({required this.providerName, required this.price, this.avatarUrl, this.message, this.status = 'pending'});

  final String providerName;
  final double price;
  final String? avatarUrl;
  final String? message;
  final String status;
}

/// Carrega os orçamentos recebidos do pedido (produção: `quotes` + nomes dos profissionais).
typedef QuotesLoader = Future<List<DetailQuote>> Function(String jobId);

/// Abre o detalhe de um pedido (em andamento, concluído, cancelado ou em mediação).
void openClientServiceDetail(BuildContext context, String jobId) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetalheServicoClienteScreen(jobId: jobId)));
}

/// Dossiê do pedido para o cliente, adaptado ao estado:
///  * **Em andamento**: status (Aguardando Orçamento / Agendado / Em Execução), orçamentos
///    recebidos, horário, localização com mapa, fotos e descrição;
///  * **Concluído**: quem fez, início/término, endereço, valor pago e a avaliação — só se o
///    cliente realmente avaliou (nunca estrelas vazias);
///  * **Cancelado**: pedido original, quando e por quê;
///  * **Em mediação**: quem contestou, motivo, bloqueio preventivo (Escrow) e linha do tempo.
class DetalheServicoClienteScreen extends StatefulWidget {
  const DetalheServicoClienteScreen({
    super.key,
    required this.jobId,
    @visibleForTesting this.dossierLoader,
    @visibleForTesting this.jobLoader,
    @visibleForTesting this.imageBuilder,
    @visibleForTesting this.quotesLoader,
    @visibleForTesting this.onOpenProvider,
    @visibleForTesting this.onSavePin,
    @visibleForTesting this.avatarHttpClient,
  });

  final String jobId;
  final DossierLoader? dossierLoader;
  final JobLoader? jobLoader;
  final EvidenceImageBuilder? imageBuilder;
  final QuotesLoader? quotesLoader;
  final Future<void> Function(DossierProvider provider)? onOpenProvider;

  /// Grava o pino confirmado pelo cliente (padrão: RPC set_job_location como client_pin).
  final Future<void> Function(String jobId, double lat, double lng)? onSavePin;

  /// Cliente HTTP opcional para testes determinísticos de hidratação a frio do avatar.
  final http.Client? avatarHttpClient;

  @override
  State<DetalheServicoClienteScreen> createState() => _DetalheServicoClienteScreenState();
}

class _DetalheServicoClienteScreenState extends State<DetalheServicoClienteScreen> {
  late Future<ClientDossier?> _future = _load();
  Future<List<DetailQuote>>? _quotesFuture;
  bool _openingChat = false;

  bool _refined = false;

  Future<ClientDossier?> _load() async {
    final d = await (widget.dossierLoader != null ? widget.dossierLoader!(widget.jobId) : JobService().clientJobDossier(widget.jobId));
    if (d != null) {
      unawaited(
        UnreadOrdersBadgeController.instance.markViewedByIdAndStatus(
          jobId: d.jobId,
          status: JobStatus.parse(d.status),
          providerId: d.provider?.id,
          price: d.amount > 0 ? d.amount : null,
        ),
      );
      if (widget.imageBuilder == null) {
        EagerImagePrefetcher.prefetchStoragePaths([
          ...d.photoPaths,
          ...d.requiredPhotos.map((e) => e.path),
        ]);
      }
      final avatarUrl = d.provider?.avatarUrl?.trim() ?? '';
      if (avatarUrl.isNotEmpty) {
        if (InstantImageCacheEngine.instance.peekMemoryBytes(avatarUrl) == null &&
            (widget.avatarHttpClient != null ||
                !WidgetsBinding.instance.runtimeType.toString().contains('Test'))) {
          try {
            await InstantImageCacheEngine.instance
                .getOrFetchUrlBytes(avatarUrl, client: widget.avatarHttpClient)
                .timeout(const Duration(milliseconds: 350), onTimeout: () => null);
          } catch (_) {}
        }
        EagerImagePrefetcher.prefetchUrls([avatarUrl], client: widget.avatarHttpClient);
      }
      if (widget.dossierLoader == null) {
        unawaited(_maybeRefine(d));
      }
    }
    return d;
  }

  /// O pino só pode ser ajustado enquanto o serviço ainda não começou.
  bool _pinEditable(ClientDossier d) => const {'open', 'awaiting_payment', 'scheduled'}.contains(d.status);

  /// Pedidos antigos que ficaram só com o centro da cidade ganham, sozinhos, o ponto da RUA
  /// (cascata de alta precisão). Só melhora; nunca troca um pino confirmado.
  Future<void> _maybeRefine(ClientDossier d) async {
    final line = d.addressLine ?? '';
    if (_refined || line.isEmpty || !_pinEditable(d) || d.geoSource == 'client_pin') return;
    final weak = !d.hasCoordinates || d.geoPrecision == DestinationPrecision.locality || d.geoPrecision == DestinationPrecision.street;
    if (!weak) return;
    _refined = true;
    final better = await refineGeocodedLocation(
      jobId: d.jobId,
      addressLine: line,
      summary: d.addressSummary,
      current: d.hasCoordinates ? d.geoPrecision : null,
    );
    if (better != null && mounted) _reload();
  }

  Future<List<DetailQuote>> _loadQuotes() async {
    if (widget.quotesLoader != null) {
      final loaded = await widget.quotesLoader!(widget.jobId);
      EagerImagePrefetcher.prefetchUrls(loaded.map((q) => q.avatarUrl));
      return loaded;
    }
    final quotes = await JobService().fetchQuotes(widget.jobId);
    final cards = await ProviderService().byIds(quotes.map((q) => q.providerId));
    final list = [
      for (final q in quotes)
        DetailQuote(
          providerName: friendlyName(cards[q.providerId]?.fullName, fallback: 'Profissional'),
          avatarUrl: cards[q.providerId]?.avatarUrl,
          price: q.price,
          message: q.message,
          status: q.status,
        ),
    ];
    EagerImagePrefetcher.prefetchUrls(list.map((q) => q.avatarUrl));
    return list;
  }

  void _reload() => setState(() {
        _future = _load();
        _quotesFuture = null;
      });

  Widget _image(BuildContext context, String path, BoxFit fit) =>
      widget.imageBuilder != null ? widget.imageBuilder!(context, path, fit) : SignedImage(path: path, fit: fit, radius: 0);

  /// Toque na foto: galeria fullscreen com swipe + zoom/pan (pinça).
  void _zoom(
    String path,
    String label, {
    List<String>? allPaths,
    List<String?>? allLabels,
    int initialIndex = 0,
  }) {
    final paths = allPaths ?? [path];
    final labels = allLabels ?? [label];
    FullscreenSwipePhotoGallery.show(
      context,
      items: [
        for (var i = 0; i < paths.length; i++)
          (
            path: paths[i],
            label: (i < labels.length ? labels[i] : null) ?? label,
          ),
      ],
      initialIndex: initialIndex,
      imageBuilder: widget.imageBuilder,
    );
  }

  Future<void> _openChat(ClientDossier d) async {
    final providerId = d.provider?.id;
    if (providerId == null || _openingChat) return;
    setState(() => _openingChat = true);
    try {
      final job = await (widget.jobLoader != null ? widget.jobLoader!(d.jobId) : JobService().fetchJob(d.jobId));
      if (!mounted) return;
      if (job == null) {
        showSnack(context, 'Não foi possível abrir a conversa deste serviço.', error: true);
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            job: job,
            providerId: providerId,
            peerName: friendlyName(d.provider?.name, fallback: 'Profissional'),
            peerAvatar: d.provider?.avatarUrl,
            readOnly: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: context.tk.surface,
      appBar: AppBar(title: const Text('Detalhe do serviço')),
      body: FutureBuilder<ClientDossier?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) {
            return ErrorView(message: 'Não foi possível carregar este serviço.', onRetry: _reload);
          }
          final d = snap.data;
          if (d == null) {
            return const EmptyView(
              icon: Icons.search_off_rounded,
              title: 'Serviço não encontrado',
              subtitle: 'Ele não existe ou não pertence à sua conta.',
            );
          }
          return _content(context, d);
        },
      ),
    );
  }

  ({String label, Color color, IconData icon}) _status(BuildContext context, ClientDossier d) {
    final tk = context.tk;
    switch (d.status) {
      case 'completed':
        return (label: 'Concluído', color: tk.success, icon: Icons.check_circle_outline);
      case 'canceled':
        return (label: 'Cancelado', color: tk.danger, icon: Icons.cancel_outlined);
      case 'disputed':
        return (label: 'Em mediação', color: tk.danger, icon: Icons.gavel_rounded);
      case 'scheduled':
        return (label: 'Agendado', color: tk.info, icon: Icons.event_available_rounded);
      case 'in_progress':
        return (label: 'Em Execução', color: tk.success, icon: Icons.play_circle_outline_rounded);
      case 'awaiting_approval':
        return (label: 'Aguardando aprovação', color: tk.warningInk, icon: Icons.fact_check_outlined);
      case 'awaiting_payment':
        return (label: 'Aguardando pagamento', color: tk.warningInk, icon: Icons.payments_outlined);
      default:
        return d.isEmergency
            ? (label: 'Buscando profissional', color: tk.danger, icon: Icons.bolt_rounded)
            : (label: 'Aguardando Orçamento', color: tk.info, icon: Icons.hourglass_top_rounded);
    }
  }

  Widget _content(BuildContext context, ClientDossier d) {
    return ListView(
      cacheExtent: 2400,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _header(context, d),
        if (d.isDisputed)
          ..._mediationSections(context, d)
        else if (d.isCanceled)
          ..._canceledSections(context, d)
        else if (d.isCompleted)
          ..._completedSections(context, d)
        else
          ..._activeSections(context, d),
      ],
    );
  }

  // ------------------------------------------------------------ blocos comuns

  Widget _header(BuildContext context, ClientDossier d) {
    final tk = context.tk;
    final s = _status(context, d);
    final headline = SmartOrderHeadlineFormatter.formatHeadline(
      d.title,
      category: d.category,
      fallbackDescription: d.description,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Andar 1: Pílula de Especialidade com CategoryBrandEmblem + StatusChip flexível (seguro em 320px)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                key: const ValueKey('detail-category-pill'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: tk.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: tk.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CategoryBrandEmblem(
                      categoryName: d.category.isEmpty ? 'Pequenos Reparos' : d.category,
                      size: 26,
                      showCornerBadge: false,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        d.category.isEmpty ? 'Dossiê do serviço' : 'Especialidade • ${d.category}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: tk.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(s.label, color: s.color, icon: s.icon),
            ],
          ),
          const SizedBox(height: 12),
          // Andar 2: Título semântico ocupando 100% da largura horizontal livre (fim da quebra vertical!)
          SizedBox(
            width: double.infinity,
            child: Text(
              headline,
              key: const ValueKey('detail-headline-title'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                height: 1.28,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: tk.border),
          const SizedBox(height: 10),
          ExecutiveMetaTile(
            key: const ValueKey('detail-meta-id'),
            icon: Icons.tag_rounded,
            secondaryIcon: Icons.qr_code_2_rounded,
            label: 'ID do serviço',
            value: d.code,
            copyable: true,
            copyMessage: 'ID ${d.code} copiado para a área de transferência',
          ),
          if (d.category.isNotEmpty)
            ExecutiveMetaTile(
              key: const ValueKey('detail-meta-category'),
              icon: Icons.handyman_outlined,
              secondaryIcon: Icons.verified_rounded,
              label: 'Categoria',
              value: d.category,
            ),
          if (d.createdAt != null)
            ExecutiveMetaTile(
              key: const ValueKey('detail-meta-created-at'),
              icon: Icons.add_task_rounded,
              secondaryIcon: Icons.schedule_rounded,
              label: 'Pedido criado em',
              value: dateLong(d.createdAt!),
            ),
        ],
      ),
    );
  }

  /// Horários: agendado, início e término reais.
  List<Widget> _times(BuildContext context, ClientDossier d) {
    final tk = context.tk;
    final rows = <Widget>[
      if (d.scheduledFor != null)
        ExecutiveMetaTile(
          icon: Icons.schedule_rounded,
          secondaryIcon: Icons.event_rounded,
          accentColor: tk.info,
          label: 'Agendado para',
          value: dateLong(d.scheduledFor!),
        ),
      if (d.startedAt != null)
        ExecutiveMetaTile(
          icon: Icons.play_circle_outline_rounded,
          secondaryIcon: Icons.bolt_rounded,
          accentColor: tk.clientAccent,
          label: 'Início do serviço',
          value: dateLong(d.startedAt!),
        ),
      if (d.isCompleted && d.finishedAt != null)
        ExecutiveMetaTile(
          icon: Icons.event_available_outlined,
          secondaryIcon: Icons.verified_rounded,
          accentColor: tk.success,
          label: 'Término do serviço',
          value: dateLong(d.finishedAt!),
        ),
    ];
    if (rows.isEmpty) return const [];
    return [const SectionTitle('Horário'), AppCard(child: Column(children: rows))];
  }

  Future<void> _defaultSavePin(String jobId, double lat, double lng) async {
    await SupabaseSchedulingBackend().setLocation(jobId, lat, lng, source: 'client_pin', precision: 'house');
  }

  Future<void> _openMap(ClientDossier d) async {
    final line = d.addressLine ?? d.addressSummary ?? '';
    if (line.isEmpty) {
      showSnack(context, 'Este pedido não tem endereço para mostrar no mapa.', error: true);
      return;
    }
    await OrderLiveMapModalScreen.show(
      context,
      addressLine: line,
      summary: d.addressSummary,
      latitude: d.latitude,
      longitude: d.longitude,
      precision: d.geoPrecision,
      pinConfirmed: d.geoSource == 'client_pin' || d.geoPrecision == DestinationPrecision.house,
      onAdjustPin: _pinEditable(d)
          ? (lat, lng) async {
              await (widget.onSavePin ?? _defaultSavePin)(d.jobId, lat, lng);
              if (mounted) _reload();
            }
          : null,
    );
  }

  List<Widget> _location(BuildContext context, ClientDossier d) {
    final line = d.addressLine ?? d.addressSummary ?? '';
    if (line.isEmpty) return const [];
    return [
      const SectionTitle('Localização'),
      InteractiveLocationPreviewCard(
        cardKey: const ValueKey('detail-location'),
        addressLine: line,
        summary: d.addressSummary,
        latitude: d.latitude,
        longitude: d.longitude,
        precision: d.geoPrecision,
        pinConfirmed: d.geoSource == 'client_pin',
        onTap: () => _openMap(d),
      ),
    ];
  }

  List<Widget> _description(BuildContext context, ClientDossier d) {
    final tk = context.tk;
    return [
      if (d.description.isNotEmpty) ...[
        const SectionTitle('O que você pediu'),
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DarkGlassDuotoneBadge(
                icon: Icons.description_outlined,
                secondaryIcon: Icons.auto_awesome_rounded,
                accentColor: tk.clientAccent,
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  d.description,
                  style: const TextStyle(height: 1.45, fontSize: 14.5),
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _requestPhotos(ClientDossier d) => [
        if (d.photoPaths.isNotEmpty) ...[
          const SectionTitle('Fotos do seu pedido'),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: d.photoPaths.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _Thumb(
                size: 96,
                counterBadge: '${i + 1}/${d.photoPaths.length}',
                onTap: () => _zoom(
                  d.photoPaths[i],
                  'Foto do pedido ${i + 1}/${d.photoPaths.length}',
                  allPaths: d.photoPaths,
                  allLabels: [
                    for (var idx = 0; idx < d.photoPaths.length; idx++) 'Foto do pedido ${idx + 1}/${d.photoPaths.length}',
                  ],
                  initialIndex: i,
                ),
                child: _image(context, d.photoPaths[i], BoxFit.cover),
              ),
            ),
          ),
        ],
      ];

  List<Widget> _serviceRecord(BuildContext context, ClientDossier d) {
    final photos = d.requiredPhotos;
    final video = d.videoPath;
    if (photos.isEmpty && video == null) return const [];
    final allPaths = photos.map((e) => e.path).toList();
    final allLabels = photos.map<String?>((e) => e.label).toList();
    return [
      const SectionTitle('Registro do serviço'),
      if (photos.isNotEmpty)
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: [
            for (var i = 0; i < photos.length; i++)
              _Thumb(
                label: photos[i].label,
                counterBadge: '${i + 1}/${photos.length}',
                onTap: () => _zoom(
                  photos[i].path,
                  photos[i].label,
                  allPaths: allPaths,
                  allLabels: allLabels,
                  initialIndex: i,
                ),
                child: _image(context, photos[i].path, BoxFit.cover),
              ),
          ],
        ),
      if (video != null) ...[
        const SizedBox(height: 12),
        _ServiceVideo(path: video),
      ],
    ];
  }

  List<Widget> _payment(BuildContext context, ClientDossier d, {String title = 'Pagamento', String amountLabel = 'Valor pago'}) {
    final tk = context.tk;
    return [
      SectionTitle(title),
      AppCard(
        child: Column(
          children: [
            ExecutiveMetaTile(
              icon: Icons.payments_outlined,
              secondaryIcon: Icons.shield_outlined,
              accentColor: tk.success,
              label: amountLabel,
              value: brl(d.amount),
              strong: true,
            ),
            ExecutiveMetaTile(
              icon: Icons.verified_outlined,
              secondaryIcon: Icons.lock_outline_rounded,
              accentColor: tk.security,
              label: 'Situação',
              value: _paymentLabel(d.paymentStatus),
            ),
          ],
        ),
      ),
    ];
  }

  Future<void> _openProviderProfile(DossierProvider p) async {
    if (widget.onOpenProvider != null) {
      await widget.onOpenProvider!(p);
      return;
    }
    try {
      final card = await ProviderService().byId(p.id);
      final profile = await ProfileService().fetchCurrent();
      if (!mounted) return;
      if (card == null || profile == null) {
        showSnack(context, 'O perfil deste profissional não está disponível.', error: true);
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProviderPublicProfileScreen(provider: card, profile: profile, hideCta: true)),
      );
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  /// Quem fez (ou fará) o serviço: nome, foto, nota e atalho para o perfil.
  List<Widget> _providerSection(BuildContext context, ClientDossier d, {String title = 'Profissional', bool chat = true}) {
    final tk = context.tk;
    final provider = d.provider;
    if (provider == null) return const [];
    final providerName = friendlyName(provider.name, fallback: 'Profissional');
    return [
      SectionTitle(title),
      AppCard(
        child: Column(
          children: [
            Row(
              children: [
                UserAvatar(
                  url: provider.avatarUrl,
                  name: providerName,
                  radius: 26,
                  verified: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        providerName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      if ((provider.title ?? '').isNotEmpty)
                        Text(provider.title!, style: TextStyle(color: tk.textMuted, fontSize: 13)),
                      if (provider.ratingAvg != null && provider.ratingCount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            RatingStars(value: provider.ratingAvg!, size: 15),
                            const SizedBox(width: 6),
                            Text(
                              '${provider.ratingAvg!.toStringAsFixed(1).replaceAll('.', ',')} (${provider.ratingCount})',
                              style: TextStyle(color: tk.textMuted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('provider-profile'),
                onPressed: () => _openProviderProfile(provider),
                icon: const Icon(Icons.person_search_rounded, size: 18),
                label: const Text('Ver perfil do profissional'),
              ),
            ),
          ],
        ),
      ),
      if (chat) ...[
        const SizedBox(height: 16),
        PrimaryButton(
          label: '💬 Ver conversa do serviço',
          onPressed: _openingChat ? null : () => _openChat(d),
        ),
      ],
    ];
  }

  // ------------------------------------------------------------- em andamento

  List<Widget> _activeSections(BuildContext context, ClientDossier d) {
    final showQuotes = d.status == 'open' || d.status == 'awaiting_payment';
    return [
      if (showQuotes) ...[
        const SectionTitle('Orçamentos recebidos'),
        _quotes(context, d),
      ],
      ..._times(context, d),
      ..._location(context, d),
      ..._description(context, d),
      ..._requestPhotos(d),
      ..._providerSection(context, d, title: 'Profissional contratado', chat: false),
      if (d.amount > 0) ..._payment(context, d, amountLabel: 'Valor combinado'),
      const SizedBox(height: 16),
      PrimaryButton(
        key: const ValueKey('follow-order'),
        label: d.status == 'open' ? 'Acompanhar pedido e orçamentos' : 'Acompanhar pedido',
        trailingArrow: true,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientJobScreen(jobId: d.jobId))),
      ),
    ];
  }

  Widget _quotes(BuildContext context, ClientDossier d) {
    final tk = context.tk;
    _quotesFuture ??= _loadQuotes();
    return FutureBuilder<List<DetailQuote>>(
      future: _quotesFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator()));
        }
        final quotes = (snap.data ?? const <DetailQuote>[]).where((q) => q.status != 'withdrawn' && q.status != 'rejected').toList();
        if (snap.hasError || quotes.isEmpty) {
          return AppCard(
            child: Row(
              children: [
                DarkGlassDuotoneBadge(
                  icon: Icons.hourglass_top_rounded,
                  secondaryIcon: Icons.auto_awesome_rounded,
                  accentColor: tk.info,
                  size: 38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    snap.hasError
                        ? 'Não foi possível carregar os orçamentos agora.'
                        : 'Nenhum orçamento ainda. Até 3 profissionais da região poderão responder; você será avisado.',
                    style: const TextStyle(height: 1.35),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final q in quotes)
              AppCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    UserAvatar(url: q.avatarUrl, name: q.providerName, radius: 22, verified: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.providerName, style: const TextStyle(fontWeight: FontWeight.w800)),
                          if ((q.message ?? '').isNotEmpty)
                            Text(q.message!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: tk.textMuted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Text(brl(q.price), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------- concluído

  List<Widget> _completedSections(BuildContext context, ClientDossier d) {
    return [
      ..._providerSection(context, d, title: 'Quem fez o serviço'),
      ..._times(context, d),
      ..._location(context, d),
      ..._description(context, d),
      ..._requestPhotos(d),
      ..._serviceRecord(context, d),
      ..._payment(context, d),
      if (d.report != null) ...[
        const SectionTitle('Relatório do profissional'),
        AppCard(child: Text(d.report!, style: const TextStyle(height: 1.4))),
      ],
      // Regra estrita: avaliação preenchida SÓ se o cliente avaliou. Sem avaliação: só o botão.
      if (d.hasReview) ...[
        const SectionTitle('Sua avaliação'),
        _ReviewCard(review: d.myReview!),
      ] else if (d.canReview) ...[
        const SizedBox(height: 16),
        PrimaryButton(
          key: const ValueKey('rate-provider'),
          label: '⭐ Avaliar profissional',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientJobScreen(jobId: d.jobId))),
        ),
      ],
    ];
  }

  // ---------------------------------------------------------------- cancelado

  List<Widget> _canceledSections(BuildContext context, ClientDossier d) {
    final tk = context.tk;
    final when = d.canceledAt ?? d.finishedAt;
    return [
      const SectionTitle('Cancelamento'),
      AppCard(
        color: tk.dangerSoft,
        borderColor: tk.danger.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExecutiveMetaTile(
              icon: Icons.event_busy_outlined,
              secondaryIcon: Icons.cancel_outlined,
              accentColor: tk.danger,
              label: 'Cancelado em',
              value: when == null ? 'Data não registrada' : dateLong(when),
            ),
            const SizedBox(height: 8),
            Text('Motivo do cancelamento', style: TextStyle(color: tk.textMuted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(d.cancelReason ?? 'Motivo não informado.', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
            if (d.paymentStatus == 'refunded') ...[
              const SizedBox(height: 8),
              ExecutiveMetaTile(
                icon: Icons.undo_rounded,
                secondaryIcon: Icons.verified_outlined,
                accentColor: tk.success,
                label: 'Reserva',
                value: 'Estornada',
              ),
            ],
          ],
        ),
      ),
      ..._description(context, d),
      ..._requestPhotos(d),
      ..._times(context, d),
      ..._location(context, d),
      ..._providerSection(context, d),
    ];
  }

  // ----------------------------------------------------------------- mediação

  List<Widget> _mediationSections(BuildContext context, ClientDossier d) {
    final tk = context.tk;
    final dispute = d.dispute;
    final statusLabel = switch (dispute?.status) {
      'resolved' => 'Resolvida',
      'in_review' => 'Em análise pela equipe',
      _ => 'Aguardando análise da equipe',
    };
    return [
      const SectionTitle('Contestação'),
      AppCard(
        color: tk.dangerSoft,
        borderColor: tk.danger.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExecutiveMetaTile(
              icon: Icons.flag_outlined,
              secondaryIcon: Icons.gavel_rounded,
              accentColor: tk.danger,
              label: 'Aberta por',
              value: dispute?.openedByLabel ?? 'Cliente',
            ),
            ExecutiveMetaTile(
              icon: Icons.report_gmailerrorred_rounded,
              secondaryIcon: Icons.info_outline_rounded,
              accentColor: tk.danger,
              label: 'Motivo',
              value: dispute?.reason ?? 'Motivo não informado',
            ),
            ExecutiveMetaTile(
              icon: Icons.hourglass_top_rounded,
              secondaryIcon: Icons.shield_outlined,
              accentColor: tk.warningInk,
              label: 'Situação',
              value: statusLabel,
            ),
            if (dispute?.description != null) ...[
              const SizedBox(height: 6),
              Text(dispute!.description!, style: const TextStyle(height: 1.4)),
            ],
          ],
        ),
      ),
      const SectionTitle('Bloqueio preventivo (Escrow)'),
      AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DarkGlassDuotoneBadge(
              icon: Icons.lock_rounded,
              secondaryIcon: Icons.verified_user_rounded,
              accentColor: tk.security,
              size: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.inEscrow ? '${brl(d.amount)} bloqueados em custódia' : _paymentLabel(d.paymentStatus),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    d.inEscrow
                        ? 'O dinheiro não é liberado a ninguém enquanto a equipe analisa o caso. Você não perde nada.'
                        : 'A plataforma preserva o pagamento até a decisão da mediação.',
                    style: TextStyle(color: tk.textMuted, height: 1.35, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SectionTitle('Linha do tempo da mediação'),
      _MediationTimeline(steps: d.mediationTimeline),
      ..._description(context, d),
      ..._requestPhotos(d),
      ..._times(context, d),
      ..._location(context, d),
      ..._providerSection(context, d),
    ];
  }
}

/// Linha do tempo vertical da mediação.
class _MediationTimeline extends StatelessWidget {
  const _MediationTimeline({required this.steps});

  final List<MediationStep> steps;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 26,
                    child: Column(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: steps[i].done ? tk.clientAccent : Colors.transparent,
                            border: Border.all(color: steps[i].done ? tk.clientAccent : tk.border, width: 2),
                          ),
                          child: steps[i].done ? const Icon(Icons.check_rounded, size: 11, color: Colors.white) : null,
                        ),
                        if (i < steps.length - 1) Expanded(child: Container(width: 2, color: tk.border)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].title,
                            style: TextStyle(fontWeight: FontWeight.w800, color: steps[i].done ? tk.text : tk.textMuted),
                          ),
                          if (steps[i].at != null) Text(dateLong(steps[i].at!), style: TextStyle(fontSize: 12, color: tk.textMuted)),
                          if ((steps[i].detail ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(steps[i].detail!, style: TextStyle(fontSize: 12.5, color: tk.textMuted, height: 1.3)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _paymentLabel(String s) => switch (s) {
      'escrow' => 'Em garantia',
      'released' => 'Pago ao profissional',
      'refunded' => 'Reembolsado',
      'pending' => 'Pendente',
      '' => '—',
      _ => s,
    };

/// Miniatura tocável (zoom) com rótulo opcional e badge contador (`1/4`).
class _Thumb extends StatelessWidget {
  const _Thumb({required this.child, required this.onTap, this.label, this.size, this.counterBadge});

  final Widget child;
  final VoidCallback onTap;
  final String? label;
  final double? size;
  final String? counterBadge;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: tk.card, child: child),
              if (counterBadge != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                    ),
                    child: Text(
                      counterBadge!,
                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              if (label != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    color: Colors.black54,
                    child: Text(
                      label!,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final DossierReview review;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RatingStars(value: review.rating.toDouble(), size: 22),
              const Spacer(),
              if (review.createdAt != null)
                Text(dateShort(review.createdAt!), style: TextStyle(color: context.tk.textMuted, fontSize: 12)),
            ],
          ),
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final t in review.tags) StatusChip(t, color: context.tk.clientAccent)],
            ),
          ],
          if (review.comment != null) ...[
            const SizedBox(height: 10),
            Text(review.comment!, style: const TextStyle(height: 1.4)),
          ],
        ],
      ),
    );
  }
}

/// Vídeo do serviço: só baixa quando o usuário toca em ▶ (economiza dados).
class _ServiceVideo extends StatefulWidget {
  const _ServiceVideo({required this.path});

  final String path;

  @override
  State<_ServiceVideo> createState() => _ServiceVideoState();
}

class _ServiceVideoState extends State<_ServiceVideo> {
  VideoPlayerController? _c;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await MediaService().signedUrl(widget.path);
      if (url == null) throw Exception('sem url');
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _c = c;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível carregar o vídeo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final c = _c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: c?.value.aspectRatio ?? 16 / 9,
        child: c == null
            ? Material(
                color: tk.card,
                child: InkWell(
                  onTap: _loading ? null : _start,
                  child: Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle_fill_rounded, size: 60, color: tk.clientAccent),
                              const SizedBox(height: 6),
                              Text(_error ?? 'Toque para assistir ao vídeo', style: TextStyle(color: tk.textMuted)),
                            ],
                          ),
                  ),
                ),
              )
            : GestureDetector(
                onTap: () => c.value.isPlaying ? c.pause() : c.play(),
                child: VideoPlayer(c),
              ),
      ),
    );
  }
}

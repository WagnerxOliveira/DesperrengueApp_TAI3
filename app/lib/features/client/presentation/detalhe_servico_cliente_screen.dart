import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../../../core/models/client_dossier_models.dart';
import '../../../core/models/marketplace_models.dart';
import '../../../core/models/scheduling_models.dart' show DestinationPrecision;
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/instant_image_cache_engine.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/media_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/services/scheduling_service.dart';
import '../../../core/state/unread_orders_badge_controller.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
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
  Navigator.of(context).push(AppRoute(builder: (_) => DetalheServicoClienteScreen(jobId: jobId)));
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

  @override
  void dispose() {
    EagerImagePrefetcher.cancelPending();
    super.dispose();
  }

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
        AppSnackbar.show(context, 'Não foi possível abrir a conversa deste serviço.', kind: AppSnackKind.error);
        return;
      }
      await Navigator.of(context).push(
        AppRoute(
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
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    return AppScaffold(
      backgroundColor: tk.surface,
      appBar: const AppAppBar(title: 'Detalhe do serviço'),
      body: FutureBuilder<ClientDossier?>(
        future: _future,
        builder: (context, snap) {
          final loading = snap.connectionState != ConnectionState.done;
          final Widget body;
          if (loading) {
            body = const SizedBox.shrink();
          } else if (snap.hasError) {
            body = AppErrorState(
              message: 'Não foi possível carregar este serviço.',
              retryLabel: 'Tentar novamente',
              onRetry: _reload,
            );
          } else if (snap.data == null) {
            body = const AppEmptyState(
              icon: Icons.search_off_rounded,
              title: 'Serviço não encontrado',
              message: 'Ele não existe ou não pertence à sua conta.',
            );
          } else {
            body = _content(context, snap.data!);
          }
          return AppSkeletonSwitcher(
            loading: loading,
            skeleton: AppSkeletonList(
              count: 4,
              padding: EdgeInsets.symmetric(horizontal: margin, vertical: AppSpace.s16),
            ),
            child: body,
          );
        },
      ),
    );
  }

  ({String label, AppTone tone, IconData icon}) _status(ClientDossier d) {
    switch (d.status) {
      case 'completed':
        return (label: 'Concluído', tone: AppTone.success, icon: Icons.check_circle_outline);
      case 'canceled':
        return (label: 'Cancelado', tone: AppTone.danger, icon: Icons.cancel_outlined);
      case 'disputed':
        return (label: 'Em mediação', tone: AppTone.danger, icon: Icons.gavel_rounded);
      case 'scheduled':
        return (label: 'Agendado', tone: AppTone.info, icon: Icons.event_available_rounded);
      case 'in_progress':
        return (label: 'Em Execução', tone: AppTone.success, icon: Icons.play_circle_outline_rounded);
      case 'awaiting_approval':
        return (label: 'Aguardando aprovação', tone: AppTone.warning, icon: Icons.fact_check_outlined);
      case 'awaiting_payment':
        return (label: 'Aguardando pagamento', tone: AppTone.warning, icon: Icons.payments_outlined);
      default:
        return d.isEmergency
            ? (label: 'Buscando profissional', tone: AppTone.danger, icon: Icons.bolt_rounded)
            : (label: 'Aguardando Orçamento', tone: AppTone.info, icon: Icons.hourglass_top_rounded);
    }
  }

  Widget _content(BuildContext context, ClientDossier d) {
    final margin = context.layout.margin;
    final sections = <Widget>[
      _header(context, d),
      if (d.isDisputed)
        ..._mediationSections(context, d)
      else if (d.isCanceled)
        ..._canceledSections(context, d)
      else if (d.isCompleted)
        ..._completedSections(context, d)
      else
        ..._activeSections(context, d),
    ];
    return ListView(
      cacheExtent: 2400,
      padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s32),
      children: [
        for (var i = 0; i < sections.length; i++)
          AppStaggerItem(
            index: i,
            scope: 'client-detail-${d.jobId}',
            child: sections[i],
          ),
      ],
    );
  }

  // ------------------------------------------------------------ blocos comuns

  Widget _header(BuildContext context, ClientDossier d) {
    final tk = context.tk;
    final s = _status(d);
    final headline = SmartOrderHeadlineFormatter.formatHeadline(
      d.title,
      category: d.category,
      fallbackDescription: d.description,
    );
    return AppHero(
      tag: 'order-card-${d.jobId}',
      child: Material(
        type: MaterialType.transparency,
        child: AppCard(
          variant: AppCardVariant.hero,
          padding: const EdgeInsets.all(AppSpace.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Andar 1: Pílula de Especialidade com CategoryBrandEmblem + AppStatusChip flexível (seguro em 320px)
              Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    key: const ValueKey('detail-category-pill'),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s4),
                    decoration: BoxDecoration(
                      color: tk.surface,
                      borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
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
                        const SizedBox(width: AppSpace.s8),
                        Flexible(
                          child: Text(
                            d.category.isEmpty ? 'Dossiê do serviço' : 'Especialidade • ${d.category}',
                            style: AppType.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: tk.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppStatusChip(s.label, tone: s.tone, icon: s.icon),
                ],
              ),
              const SizedBox(height: AppSpace.s12),
              // Andar 2: Título semântico ocupando 100% da largura horizontal livre (fim da quebra vertical!)
              SizedBox(
                width: double.infinity,
                child: Text(
                  headline,
                  key: const ValueKey('detail-headline-title'),
                  style: AppType.title.copyWith(color: tk.text),
                ),
              ),
              const SizedBox(height: AppSpace.s12),
              Divider(height: 1, color: tk.border),
              const SizedBox(height: AppSpace.s8),
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
        ),
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
          accentColor: tk.accentInk,
          label: 'Início do serviço',
          value: dateLong(d.startedAt!),
        ),
      if (d.isCompleted && d.finishedAt != null)
        ExecutiveMetaTile(
          icon: Icons.event_available_outlined,
          secondaryIcon: Icons.verified_rounded,
          accentColor: tk.successInk,
          label: 'Término do serviço',
          value: dateLong(d.finishedAt!),
        ),
    ];
    if (rows.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpace.section),
      AppSection(
        title: 'Horário',
        child: AppCard(variant: AppCardVariant.outlined, child: Column(children: rows)),
      ),
    ];
  }

  Future<void> _defaultSavePin(String jobId, double lat, double lng) async {
    await SupabaseSchedulingBackend().setLocation(jobId, lat, lng, source: 'client_pin', precision: 'house');
  }

  Future<void> _openMap(ClientDossier d) async {
    var line = d.addressLine ?? d.addressSummary ?? '';
    String? cep;
    String? referencePoint;
    double? exactLat = d.latitude;
    double? exactLng = d.longitude;

    if (exactLat == null || exactLng == null || d.addressLine == null) {
      try {
        final ownerLoc = await JobService().fetchOwnerExactLocation(d.jobId);
        if (ownerLoc != null) {
          if (ownerLoc.lat != null && ownerLoc.lng != null) {
            exactLat ??= ownerLoc.lat;
            exactLng ??= ownerLoc.lng;
          }
          final full = ownerLoc.fullStreetLine?.trim();
          if ((d.addressLine == null || d.addressLine!.trim().isEmpty) &&
              full != null &&
              full.isNotEmpty) {
            line = full;
          }
          cep = ownerLoc.cep;
          referencePoint = ownerLoc.reference;
        }
      } catch (_) {}
    }

    if (line.isEmpty) {
      if (!mounted) return;
      AppSnackbar.show(context, 'Este pedido não tem endereço para mostrar no mapa.', kind: AppSnackKind.error);
      return;
    }
    if (!mounted) return;
    await OrderLiveMapModalScreen.show(
      context,
      jobId: d.jobId,
      addressLine: line,
      summary: d.addressSummary,
      cep: cep,
      referencePoint: referencePoint,
      latitude: exactLat,
      longitude: exactLng,
      precision: d.geoPrecision,
      pinConfirmed: d.geoSource == 'client_pin' || d.geoPrecision == DestinationPrecision.house,
      orderStatus: d.status,
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
      const SizedBox(height: AppSpace.section),
      AppSection(
        title: 'Localização',
        child: InteractiveLocationPreviewCard(
          cardKey: const ValueKey('detail-location'),
          jobId: d.jobId,
          addressLine: line,
          summary: d.addressSummary,
          latitude: d.latitude,
          longitude: d.longitude,
          precision: d.geoPrecision,
          pinConfirmed: d.geoSource == 'client_pin',
          orderStatus: d.status,
          onTap: () => _openMap(d),
        ),
      ),
    ];
  }

  List<Widget> _description(BuildContext context, ClientDossier d) {
    final tk = context.tk;
    if (d.description.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpace.section),
      AppSection(
        title: 'O que você pediu',
        child: AppCard(
          variant: AppCardVariant.outlined,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DarkGlassDuotoneBadge(
                icon: Icons.description_outlined,
                secondaryIcon: Icons.auto_awesome_rounded,
                accentColor: tk.accentInk,
                size: 38,
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Text(
                  d.description,
                  style: AppType.body.copyWith(color: tk.text),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _requestPhotos(ClientDossier d) {
    if (d.photoPaths.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpace.section),
      AppSection(
        title: 'Fotos do seu pedido',
        child: SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: d.photoPaths.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s12),
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
      ),
    ];
  }

  List<Widget> _serviceRecord(BuildContext context, ClientDossier d) {
    final photos = d.requiredPhotos;
    final video = d.videoPath;
    if (photos.isEmpty && video == null) return const [];
    final allPaths = photos.map((e) => e.path).toList();
    final allLabels = photos.map<String?>((e) => e.label).toList();
    return [
      const SizedBox(height: AppSpace.section),
      AppSection(
        title: 'Registro do serviço',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (photos.isNotEmpty)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpace.s12,
                crossAxisSpacing: AppSpace.s12,
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
              const SizedBox(height: AppSpace.s12),
              _ServiceVideo(path: video),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _payment(BuildContext context, ClientDossier d, {String title = 'Pagamento', String amountLabel = 'Valor pago'}) {
    final tk = context.tk;
    return [
      const SizedBox(height: AppSpace.section),
      AppSection(
        title: title,
        child: AppCard(
          variant: AppCardVariant.outlined,
          child: Column(
            children: [
              AppInfoRow(
                label: amountLabel,
                icon: Icons.payments_outlined,
                valueWidget: AppPrice(
                  value: d.amount,
                  size: AppPriceSize.sm,
                  color: tk.text,
                ),
              ),
              Divider(height: 1, color: tk.border),
              AppInfoRow(
                label: 'Situação',
                icon: Icons.verified_outlined,
                value: _paymentLabel(d.paymentStatus),
                strong: true,
              ),
            ],
          ),
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
        AppSnackbar.show(context, 'O perfil deste profissional não está disponível.', kind: AppSnackKind.error);
        return;
      }
      await Navigator.of(context).push(
        AppRoute(builder: (_) => ProviderPublicProfileScreen(provider: card, profile: profile, hideCta: true)),
      );
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    }
  }

  /// Quem fez (ou fará) o serviço: nome, foto, nota e atalho para o perfil.
  List<Widget> _providerSection(BuildContext context, ClientDossier d, {String title = 'Profissional', bool chat = true}) {
    final tk = context.tk;
    final provider = d.provider;
    if (provider == null) return const [];
    final providerName = friendlyName(provider.name, fallback: 'Profissional');
    return [
      const SizedBox(height: AppSpace.section),
      AppSection(
        title: title,
        child: AppCard(
          variant: AppCardVariant.elevated,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppHero(
                    tag: 'provider-avatar-${provider.id}',
                    child: AppAvatar(
                      url: provider.avatarUrl,
                      name: providerName,
                      radius: 26,
                      verified: true,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          providerName,
                          style: AppType.titleSm.copyWith(color: tk.text),
                        ),
                        if ((provider.title ?? '').isNotEmpty)
                          Text(
                            provider.title!,
                            style: AppType.bodySm.copyWith(color: tk.textMuted),
                          ),
                        if (provider.ratingAvg != null && provider.ratingCount > 0) ...[
                          const SizedBox(height: AppSpace.s4),
                          AppRating(
                            value: provider.ratingAvg!,
                            count: provider.ratingCount,
                            showValue: true,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s12),
              AppButton(
                key: const ValueKey('provider-profile'),
                onPressed: () => _openProviderProfile(provider),
                variant: AppButtonVariant.tertiary,
                expand: false,
                icon: Icons.person_search_rounded,
                label: 'Ver perfil do profissional',
              ),
            ],
          ),
        ),
      ),
      if (chat) ...[
        const SizedBox(height: AppSpace.s16),
        AppButton(
          label: '💬 Ver conversa do serviço',
          loading: _openingChat,
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
        const SizedBox(height: AppSpace.section),
        AppSection(
          title: 'Orçamentos recebidos',
          child: _quotes(context, d),
        ),
      ],
      ..._times(context, d),
      ..._location(context, d),
      ..._description(context, d),
      ..._requestPhotos(d),
      ..._providerSection(context, d, title: 'Profissional contratado', chat: false),
      if (d.amount > 0) ..._payment(context, d, amountLabel: 'Valor combinado'),
      const SizedBox(height: AppSpace.s16),
      AppButton(
        key: const ValueKey('follow-order'),
        label: d.status == 'open' ? 'Acompanhar pedido e orçamentos' : 'Acompanhar pedido',
        trailingArrow: true,
        onPressed: () => Navigator.of(context).push(AppRoute(builder: (_) => ClientJobScreen(jobId: d.jobId))),
      ),
    ];
  }

  Widget _quotes(BuildContext context, ClientDossier d) {
    final tk = context.tk;
    final layout = context.layout;
    _quotesFuture ??= _loadQuotes();
    return FutureBuilder<List<DetailQuote>>(
      future: _quotesFuture,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final quotes = (snap.data ?? const <DetailQuote>[]).where((q) => q.status != 'withdrawn' && q.status != 'rejected').toList();
        final Widget content;
        if (loading) {
          content = const SizedBox.shrink();
        } else if (snap.hasError || quotes.isEmpty) {
          content = AppCard(
            variant: AppCardVariant.tonal,
            child: Row(
              children: [
                DarkGlassDuotoneBadge(
                  icon: Icons.hourglass_top_rounded,
                  secondaryIcon: Icons.auto_awesome_rounded,
                  accentColor: tk.info,
                  size: 38,
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Text(
                    snap.hasError
                        ? 'Não foi possível carregar os orçamentos agora.'
                        : 'Nenhum orçamento ainda. Até 3 profissionais da região poderão responder; você será avisado.',
                    style: AppType.bodySm.copyWith(color: tk.text),
                  ),
                ),
              ],
            ),
          );
        } else {
          final stackPrice = layout.isLargeText || layout.isCompact;
          content = Column(
            children: [
              for (final q in quotes)
                AppCard(
                  variant: AppCardVariant.elevated,
                  margin: const EdgeInsets.only(bottom: AppSpace.item),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppAvatar(url: q.avatarUrl, name: q.providerName, radius: 22, verified: true),
                      const SizedBox(width: AppSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              q.providerName,
                              style: AppType.titleSm.copyWith(color: tk.text),
                            ),
                            if ((q.message ?? '').isNotEmpty) ...[
                              const SizedBox(height: AppSpace.s2),
                              Text(
                                q.message!,
                                style: AppType.bodySm.copyWith(color: tk.textMuted),
                              ),
                            ],
                            if (stackPrice) ...[
                              const SizedBox(height: AppSpace.s8),
                              AppPrice(value: q.price, size: AppPriceSize.sm, color: tk.text),
                            ],
                          ],
                        ),
                      ),
                      if (!stackPrice) ...[
                        const SizedBox(width: AppSpace.s8),
                        AppPrice(value: q.price, size: AppPriceSize.sm, color: tk.text),
                      ],
                    ],
                  ),
                ),
            ],
          );
        }
        return AppSkeletonSwitcher(
          loading: loading,
          skeleton: const AppSkeletonList(count: 2, padding: EdgeInsets.zero),
          child: content,
        );
      },
    );
  }

  // ---------------------------------------------------------------- concluído

  List<Widget> _completedSections(BuildContext context, ClientDossier d) {
    final tk = context.tk;
    return [
      ..._providerSection(context, d, title: 'Quem fez o serviço'),
      ..._times(context, d),
      ..._location(context, d),
      ..._description(context, d),
      ..._requestPhotos(d),
      ..._serviceRecord(context, d),
      ..._payment(context, d),
      if (d.report != null) ...[
        const SizedBox(height: AppSpace.section),
        AppSection(
          title: 'Relatório do profissional',
          child: AppCard(
            variant: AppCardVariant.outlined,
            child: Text(d.report!, style: AppType.body.copyWith(color: tk.text)),
          ),
        ),
      ],
      // Regra estrita: avaliação preenchida SÓ se o cliente avaliou. Sem avaliação: só o botão.
      if (d.hasReview) ...[
        const SizedBox(height: AppSpace.section),
        AppSection(
          title: 'Sua avaliação',
          child: _ReviewCard(review: d.myReview!),
        ),
      ] else if (d.canReview) ...[
        const SizedBox(height: AppSpace.s16),
        AppButton(
          key: const ValueKey('rate-provider'),
          label: '⭐ Avaliar profissional',
          onPressed: () => Navigator.of(context).push(AppRoute(builder: (_) => ClientJobScreen(jobId: d.jobId))),
        ),
      ],
    ];
  }

  // ---------------------------------------------------------------- cancelado

  List<Widget> _canceledSections(BuildContext context, ClientDossier d) {
    final tk = context.tk;
    final when = d.canceledAt ?? d.finishedAt;
    return [
      const SizedBox(height: AppSpace.section),
      AppSection(
        title: 'Cancelamento',
        child: AppCard(
          variant: AppCardVariant.tonal,
          color: tk.dangerSoft,
          borderColor: tk.danger.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExecutiveMetaTile(
                icon: Icons.event_busy_outlined,
                secondaryIcon: Icons.cancel_outlined,
                accentColor: tk.dangerInk,
                label: 'Cancelado em',
                value: when == null ? 'Data não registrada' : dateLong(when),
              ),
              const SizedBox(height: AppSpace.s8),
              Text(
                'Motivo do cancelamento',
                style: AppType.bodySm.copyWith(color: tk.textMuted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpace.s4),
              Text(
                d.cancelReason ?? 'Motivo não informado.',
                style: AppType.bodyStrong.copyWith(color: tk.text),
              ),
              if (d.paymentStatus == 'refunded') ...[
                const SizedBox(height: AppSpace.s8),
                ExecutiveMetaTile(
                  icon: Icons.undo_rounded,
                  secondaryIcon: Icons.verified_outlined,
                  accentColor: tk.successInk,
                  label: 'Reserva',
                  value: 'Estornada',
                ),
              ],
            ],
          ),
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
      const SizedBox(height: AppSpace.section),
      AppSection(
        title: 'Contestação',
        child: AppCard(
          variant: AppCardVariant.tonal,
          color: tk.dangerSoft,
          borderColor: tk.danger.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExecutiveMetaTile(
                icon: Icons.flag_outlined,
                secondaryIcon: Icons.gavel_rounded,
                accentColor: tk.dangerInk,
                label: 'Aberta por',
                value: dispute?.openedByLabel ?? 'Cliente',
              ),
              ExecutiveMetaTile(
                icon: Icons.report_gmailerrorred_rounded,
                secondaryIcon: Icons.info_outline_rounded,
                accentColor: tk.dangerInk,
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
                const SizedBox(height: AppSpace.s8),
                Text(dispute!.description!, style: AppType.body.copyWith(color: tk.text)),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: AppSpace.section),
      AppSection(
        title: 'Bloqueio preventivo (Escrow)',
        child: AppCard(
          variant: AppCardVariant.outlined,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DarkGlassDuotoneBadge(
                icon: Icons.lock_rounded,
                secondaryIcon: Icons.verified_user_rounded,
                accentColor: tk.security,
                size: 38,
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.inEscrow ? '${brl(d.amount)} bloqueados em custódia' : _paymentLabel(d.paymentStatus),
                      style: AppType.tabular(AppType.titleSm).copyWith(color: tk.text),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    Text(
                      d.inEscrow
                          ? 'O dinheiro não é liberado a ninguém enquanto a equipe analisa o caso. Você não perde nada.'
                          : 'A plataforma preserva o pagamento até a decisão da mediação.',
                      style: AppType.bodySm.copyWith(color: tk.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: AppSpace.section),
      AppSection(
        title: 'Linha do tempo da mediação',
        child: _MediationTimeline(steps: d.mediationTimeline),
      ),
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
      variant: AppCardVariant.outlined,
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
                            color: steps[i].done ? tk.accent : null,
                            border: Border.all(color: steps[i].done ? tk.accent : tk.border, width: 2),
                          ),
                          child: steps[i].done ? Icon(Icons.check_rounded, size: 11, color: tk.onAccent) : null,
                        ),
                        if (i < steps.length - 1) Expanded(child: Container(width: 2, color: tk.border)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].title,
                            style: AppType.bodyStrong.copyWith(
                              color: steps[i].done ? tk.text : tk.textMuted,
                            ),
                          ),
                          if (steps[i].at != null)
                            Text(
                              dateLong(steps[i].at!),
                              style: AppType.caption.copyWith(color: tk.textMuted),
                            ),
                          if ((steps[i].detail ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpace.s2),
                              child: Text(
                                steps[i].detail!,
                                style: AppType.bodySm.copyWith(color: tk.textMuted),
                              ),
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
    final overlayBg = tk.scrim;
    final overlayFg = AppTokens.onColor(overlayBg);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: tk.card, child: child),
              if (counterBadge != null)
                Positioned(
                  top: AppSpace.s8,
                  right: AppSpace.s8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8, vertical: AppSpace.s2),
                    decoration: BoxDecoration(
                      color: overlayBg,
                      borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                      border: Border.all(color: overlayFg.withValues(alpha: 0.22)),
                    ),
                    child: Text(
                      counterBadge!,
                      style: AppType.tabular(AppType.caption).copyWith(
                        color: overlayFg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (label != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s4),
                    color: overlayBg,
                    child: Text(
                      label!,
                      style: AppType.caption.copyWith(
                        color: overlayFg,
                        fontWeight: FontWeight.w700,
                      ),
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
    final tk = context.tk;
    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppRating(value: review.rating.toDouble(), size: 22),
              if (review.createdAt != null)
                Text(
                  dateShort(review.createdAt!),
                  style: AppType.caption.copyWith(color: tk.textMuted),
                ),
            ],
          ),
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s12),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [for (final t in review.tags) AppStatusChip(t, tone: AppTone.accent)],
            ),
          ],
          if (review.comment != null) ...[
            const SizedBox(height: AppSpace.s12),
            Text(review.comment!, style: AppType.body.copyWith(color: tk.text)),
          ],
        ],
      ),
    );
  }
}

/// Vídeo do serviço: só baixa quando o usuário toca no play (economiza dados).
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
      borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
      child: AspectRatio(
        aspectRatio: c?.value.aspectRatio ?? 16 / 9,
        child: c == null
            ? Material(
                color: tk.card,
                child: InkWell(
                  onTap: _loading ? null : _start,
                  child: Center(
                    child: _loading
                        ? const AppLoading(message: 'Carregando vídeo...')
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle_fill_rounded, size: 60, color: tk.accentInk),
                              const SizedBox(height: AppSpace.s8),
                              Text(
                                _error ?? 'Toque para assistir ao vídeo',
                                style: AppType.bodySm.copyWith(color: tk.textMuted),
                              ),
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

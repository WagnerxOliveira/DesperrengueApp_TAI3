import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/models/wallet_models.dart';
import '../../../core/services/instant_image_cache_engine.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/services/real_time_route_and_traffic_service.dart';
import '../../../core/services/scheduling_service.dart';
import '../../../core/state/smart_triage_controller.dart';
import '../../../core/state/unread_orders_badge_controller.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../shared/presentation/order_live_map_modal_screen.dart';
import '../../shared/presentation/scheduled_service_screen.dart';
import '../../shared/presentation/smart_triage_widgets.dart';
import 'completion_screens.dart';
import 'insufficient_funds_sheet.dart';
import 'order_tracking_screen.dart';
import 'payment_widgets.dart';
import 'provider_public_profile_screen.dart';
import 'provider_search_screen.dart';

/// Acompanha UM pedido do cliente em tempo real e mostra a tela certa para
/// cada estado (aguardando orçamento, radar, pagamento, execução, conclusão).
class ClientJobScreen extends StatefulWidget {
  const ClientJobScreen({
    super.key,
    required this.jobId,
    this.jobStreamOverride,
  });

  final String jobId;

  /// Stream opcional para testes/galeria (evita instanciar [JobService] sem Supabase).
  final Stream<Job?>? jobStreamOverride;

  @override
  State<ClientJobScreen> createState() => _ClientJobScreenState();
}

class _ClientJobScreenState extends State<ClientJobScreen> {
  late final Stream<Job?> _stream =
      (widget.jobStreamOverride ?? JobService().streamJob(widget.jobId)).asBroadcastStream();
  JobStatus? _previous;

  void _maybeShowMatch(Job job) {
    final was = _previous;
    _previous = job.status;
    if (was == JobStatus.open && job.status == JobStatus.inProgress && job.isEmergency && job.providerId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final provider = await ProviderService().byId(job.providerId!);
        if (!mounted || provider == null) return;
        await _showMatchDialog(context, provider);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Job?>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return const AppScaffold(
            appBar: AppAppBar(),
            body: AppErrorState(message: 'Não foi possível carregar o pedido.'),
          );
        }
        if (!snap.hasData) {
          return snap.connectionState == ConnectionState.waiting
              ? const AppScaffold(
                  appBar: AppAppBar(),
                  body: AppSkeletonList(count: 4),
                )
              : const AppScaffold(
                  appBar: AppAppBar(),
                  body: AppErrorState(message: 'Pedido não encontrado.'),
                );
        }
        final job = snap.data!;
        _maybeShowMatch(job);
        switch (job.status) {
          case JobStatus.open:
            return job.isEmergency ? EmergencyRadarScreen(job: job) : WaitingQuotesScreen(job: job);
          case JobStatus.awaitingPayment:
            return PaymentScreen(job: job);
          case JobStatus.scheduled:
            return ScheduledServiceScreen(job: job, asProvider: false);
          case JobStatus.inProgress:
          case JobStatus.awaitingApproval:
          case JobStatus.disputed:
            return OrderTrackingScreen(job: job);
          case JobStatus.completed:
            return CompletionScreen(job: job);
          case JobStatus.canceled:
            return _CanceledView(job: job);
        }
      },
    );
  }
}

// ============================================================ aguardando orçamento

class WaitingQuotesScreen extends StatefulWidget {
  const WaitingQuotesScreen({
    super.key,
    required this.job,
    @visibleForTesting this.quotesStream,
    @visibleForTesting this.invitesStream,
  });

  final Job job;

  /// Injetáveis nos testes (padrão: Realtime do Supabase).
  final Stream<List<Quote>>? quotesStream;
  final Stream<List<JobInvite>>? invitesStream;

  @override
  State<WaitingQuotesScreen> createState() => _WaitingQuotesScreenState();
}

class _WaitingQuotesScreenState extends State<WaitingQuotesScreen> {
  late final _jobs = JobService();
  late final _providers = ProviderService();
  Timer? _tick;
  Map<String, ProviderCard> _cards = {};

  // Assinados UMA vez (o cronômetro redesenha a tela a cada segundo: recriar o stream a cada
  // build reabriria a conexão Realtime o tempo todo).
  late Stream<List<Quote>> _quotes = (widget.quotesStream ?? _jobs.streamQuotes(widget.job.id));
  late Stream<List<JobInvite>> _invites = (widget.invitesStream ?? _jobs.streamInvites(widget.job.id));

  @override
  void initState() {
    super.initState();
    unawaited(UnreadOrdersBadgeController.instance.markViewed(widget.job));
    EagerImagePrefetcher.prefetchJobs([widget.job]);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant WaitingQuotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quotesStream != widget.quotesStream || oldWidget.job.id != widget.job.id) {
      _quotes = widget.quotesStream ?? _jobs.streamQuotes(widget.job.id);
    }
    if (oldWidget.invitesStream != widget.invitesStream || oldWidget.job.id != widget.job.id) {
      _invites = widget.invitesStream ?? _jobs.streamInvites(widget.job.id);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    EagerImagePrefetcher.cancelPending();
    super.dispose();
  }

  Future<void> _loadCards(Iterable<String> ids) async {
    final missing = ids.where((i) => !_cards.containsKey(i)).toList();
    if (missing.isEmpty) return;
    try {
      final more = await _providers.byIds(missing);
      EagerImagePrefetcher.prefetchUrls(more.values.map((c) => c.avatarUrl));
      if (mounted) setState(() => _cards = {..._cards, ...more});
    } catch (_) {}
  }

  Future<void> _cancel() async {
    final ok = await AppDialog.confirm(
      context,
      title: 'Cancelar pedido?',
      message: 'Os orçamentos recebidos serão descartados. Você não paga nada.',
      confirmLabel: 'Cancelar pedido',
      cancelLabel: 'Manter',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _jobs.cancelJob(widget.job.id);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    }
  }

  Future<void> _addProvider(List<JobInvite> invites) async {
    final profile = await ProfileService().fetchCurrent();
    if (profile == null || !mounted) return;
    await Navigator.of(context).push(
      AppRoute(
        builder: (_) => ProviderSearchScreen(
          category: widget.job.category,
          profile: profile,
          pickTitle: 'Escolha mais um profissional',
          excludeIds: invites.map((i) => i.providerId).toSet(),
          onPick: (p) async {
            try {
              final n = await _jobs.invite(widget.job.id, [p.id]);
              if (!mounted) return;
              AppSnackbar.show(
                context,
                n > 0 ? 'Pedido enviado para ${p.fullName}!' : 'Não foi possível convidar este profissional.',
                kind: n > 0 ? AppSnackKind.success : AppSnackKind.error,
              );
            } catch (e) {
              if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
            }
          },
        ),
      ),
    );
  }

  Future<void> _openJobMapModal(BuildContext context) async {
    String line = widget.job.addressSummary ?? '';
    String? cep;
    String? referencePoint;
    double? exactLat = widget.job.latitude;
    double? exactLng = widget.job.longitude;

    try {
      final ownerLoc = await _jobs.fetchOwnerExactLocation(widget.job.id);
      if (ownerLoc != null) {
        if (ownerLoc.lat != null && ownerLoc.lng != null) {
          exactLat = ownerLoc.lat;
          exactLng = ownerLoc.lng;
        }
        final full = ownerLoc.fullStreetLine?.trim();
        if (full != null && full.isNotEmpty) {
          line = full;
        }
        cep = ownerLoc.cep;
        referencePoint = ownerLoc.reference;
      }
    } catch (_) {}

    if (line.isEmpty || line == widget.job.addressSummary) {
      try {
        final addr = await _jobs.jobAddress(widget.job.id);
        final full = (addr?['address_line'] as String?)?.trim();
        if (full != null && full.isNotEmpty) line = full;
        cep ??= (addr?['cep'] as String?)?.trim();
        referencePoint ??= (addr?['reference'] as String?)?.trim();
      } catch (_) {}
    }
    if (line.isEmpty) line = 'Poços de Caldas - MG';
    if (!context.mounted) return;
    await OrderLiveMapModalScreen.show(
      context,
      jobId: widget.job.id,
      addressLine: line,
      summary: widget.job.addressSummary,
      cep: cep,
      referencePoint: referencePoint,
      latitude: exactLat,
      longitude: exactLng,
      orderStatus: widget.job.status.name,
      onAdjustPin: (lat, lng) async {
        await SupabaseSchedulingBackend().setLocation(
          widget.job.id,
          lat,
          lng,
          source: 'client_pin',
          precision: 'house',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    final job = widget.job;
    return AppScaffold(
      appBar: AppAppBar(
        // Voltar discreto (seta fina) em vez do "minimizar": sempre volta para onde o cliente estava.
        leading: AppIconButton(
          key: const ValueKey('waiting-back'),
          icon: Icons.arrow_back_ios_new_rounded,
          size: 20,
          tooltip: 'Voltar',
          onPressed: () => Navigator.maybePop(context),
        ),
        titleWidget: const BrandLogo(),
      ),
      body: StreamBuilder<List<Quote>>(
        stream: _quotes,
        builder: (context, qsnap) {
          return StreamBuilder<List<JobInvite>>(
            stream: _invites,
            builder: (context, isnap) {
              final quotes = qsnap.data ?? const <Quote>[];
              final invites = isnap.data ?? const <JobInvite>[];
              _loadCards([...quotes.map((q) => q.providerId), ...invites.map((i) => i.providerId)]);
              final live = invites.where((i) => i.isLive).toList();
              final slotsLeft = (3 - invites.where((i) => i.status != 'declined' && i.status != 'expired' && i.status != 'withdrawn').length).clamp(0, 3);
              final pendingQuotes = quotes.where((q) => q.status == 'pending').toList();

              return ListView(
                cacheExtent: 2400,
                padding: EdgeInsets.fromLTRB(margin, AppSpace.s4, margin, AppSpace.s32),
                children: [
                  AppStaggerItem(
                    index: 0,
                    scope: 'waiting-quotes-${job.id}',
                    child: LiveSearchRadarHeader(
                      job: job,
                      live: live,
                      invites: invites,
                      cards: _cards,
                      quotes: pendingQuotes,
                      onOpenMap: () => _openJobMapModal(context),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s16),
                  AppStaggerItem(
                    index: 1,
                    scope: 'waiting-quotes-${job.id}',
                    child: OrderPublishStepper(quotes: pendingQuotes.length),
                  ),
                  const SizedBox(height: AppSpace.s16),
                  AppStaggerItem(
                    index: 2,
                    scope: 'waiting-quotes-${job.id}',
                    child: _OrderSummary(
                      job: job,
                      onOpenMap: () => _openJobMapModal(context),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s16),
                  AppStaggerItem(
                    index: 3,
                    scope: 'waiting-quotes-${job.id}',
                    child: _QuoteSlots(received: pendingQuotes.length),
                  ),
                  if (pendingQuotes.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s16),
                    const InfoBanner(
                      'Compare e aceite o melhor. O pagamento só acontece depois e fica retido até o serviço ser concluído.',
                      tone: BannerTone.security,
                    ),
                    const SizedBox(height: AppSpace.s16),
                    AppSection(
                      title: 'Propostas recebidas',
                      child: Column(
                        children: [
                          for (var i = 0; i < pendingQuotes.length; i++)
                            AppStaggerItem(
                              index: i,
                              scope: 'waiting-quote-list-${job.id}',
                              child: _QuoteCard(
                                quote: pendingQuotes[i],
                                provider: _cards[pendingQuotes[i].providerId],
                                job: job,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (job.isDirect && slotsLeft > 0 && job.status == JobStatus.open) ...[
                    const SizedBox(height: AppSpace.s8),
                    AppCard(
                      variant: AppCardVariant.tonal,
                      color: tk.accentSoft,
                      borderColor: tk.accent.withValues(alpha: 0.45),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.groups_rounded, color: tk.accentInk),
                              const SizedBox(width: AppSpace.s12),
                              Expanded(
                                child: Text(
                                  'Não quer esperar? Envie o mesmo pedido para mais profissionais e compare os preços.',
                                  style: AppType.bodyStrong.copyWith(color: tk.text),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.s12),
                          AppButton(
                            label: '+ Adicionar outro profissional (restam $slotsLeft)',
                            variant: AppButtonVariant.secondary,
                            onPressed: () => _addProvider(invites),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.s16),
                  Center(
                    child: TextButton.icon(
                      key: const ValueKey('waiting-cancel'),
                      onPressed: _cancel,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(AppGeometry.minTarget, AppGeometry.minTarget),
                        foregroundColor: tk.textMuted,
                      ),
                      icon: Icon(Icons.close_rounded, size: 18, color: tk.textMuted),
                      label: Text(
                        'Cancelar pedido',
                        style: AppType.bodyStrong.copyWith(color: tk.textMuted),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Header cartográfico vivo (`120 FPS` com `RepaintBoundary`) mostrando mapa estilizado
/// centrado no endereço do pedido + ondas concêntricas suaves de radar (`CustomPainter`),
/// pino da residência, contador de especialistas verificados notificados e toque direto
/// para abrir `OrderLiveMapModalScreen`.
class LiveSearchRadarHeader extends StatefulWidget {
  const LiveSearchRadarHeader({
    super.key,
    required this.job,
    required this.live,
    required this.invites,
    required this.cards,
    required this.quotes,
    required this.onOpenMap,
  });

  final Job job;
  final List<JobInvite> live;
  final List<JobInvite> invites;
  final Map<String, ProviderCard> cards;
  final List<Quote> quotes;
  final VoidCallback onOpenMap;

  @override
  State<LiveSearchRadarHeader> createState() => _LiveSearchRadarHeaderState();
}

class _LiveSearchRadarHeaderState extends State<LiveSearchRadarHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _radarCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  double _lat = -21.7878;
  double _lng = -46.5614;

  @override
  void initState() {
    super.initState();
    if (widget.job.latitude != null && widget.job.longitude != null) {
      _lat = widget.job.latitude!;
      _lng = widget.job.longitude!;
    }
    unawaited(_resolveCoords());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      if (_radarCtrl.isAnimating) _radarCtrl.stop();
      _radarCtrl.value = 0.35;
    } else if (!_radarCtrl.isAnimating) {
      _radarCtrl.repeat();
    }
  }

  Future<void> _resolveCoords() async {
    double? exactLat = widget.job.latitude;
    double? exactLng = widget.job.longitude;
    var addrLine = widget.job.addressSummary ?? '';

    if (exactLat == null || exactLng == null) {
      try {
        final ownerLoc = await JobService().fetchOwnerExactLocation(widget.job.id);
        if (ownerLoc != null) {
          if (ownerLoc.lat != null && ownerLoc.lng != null) {
            exactLat = ownerLoc.lat;
            exactLng = ownerLoc.lng;
            if (mounted) {
              setState(() {
                _lat = exactLat!;
                _lng = exactLng!;
              });
            }
          }
          final full = ownerLoc.fullStreetLine?.trim();
          if (full != null && full.isNotEmpty) {
            addrLine = full;
          }
        }
      } catch (_) {}
    }

    if (addrLine.isEmpty && exactLat != null && exactLng != null) return;
    try {
      final resolved = await RealTimeRouteAndTrafficService.instance.resolveExactAddress(
        addressLine: addrLine.isEmpty ? 'Poços de Caldas - MG' : addrLine,
        summary: widget.job.addressSummary,
        latitude: exactLat,
        longitude: exactLng,
      );
      if (!mounted) return;
      if (resolved.hasCoordinates) {
        setState(() {
          _lat = resolved.latitude!;
          _lng = resolved.longitude!;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final job = widget.job;
    final first = widget.live.isEmpty ? null : widget.live.first;
    final p = first == null ? null : widget.cards[first.providerId];
    final hasQuotes = widget.quotes.isNotEmpty;
    final title = hasQuotes
        ? '${widget.quotes.length} ${widget.quotes.length == 1 ? 'orçamento recebido' : 'orçamentos recebidos'}'
        : (job.isDirect ? (p == null ? 'Pedido enviado!' : 'Pedido enviado para ${p.fullName}!') : 'Pedido publicado!');
    final subtitle = hasQuotes
        ? 'Toque em "Ver orçamento" para comparar e escolher o profissional.'
        : job.isDirect
            ? (widget.invites.isNotEmpty && widget.live.isEmpty
                ? 'O prazo do convite terminou. Você pode cancelar e tentar outro profissional.'
                : 'Se o profissional não responder neste tempo, o convite expira automaticamente.')
            : 'Profissionais verificados da sua região já podem ver o pedido. Você recebe até 3 orçamentos e escolhe o melhor.';

    final notifiedCount = math.max(widget.invites.length, hasQuotes ? widget.quotes.length + 2 : 3);
    final centerPoint = LatLng(_lat, _lng);

    return Container(
      key: const ValueKey('waiting-hero'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppGeometry.heroRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tk.accentSoft,
            Color.alphaBlend(tk.accent.withValues(alpha: tk.isDark ? 0.12 : 0.06), tk.card),
          ],
        ),
        border: Border.all(color: tk.accent.withValues(alpha: 0.35)),
        boxShadow: tk.elevation(2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Topo Cartográfico Vivo com Radar 120 FPS isolado em RepaintBoundary
          GestureDetector(
            key: const ValueKey('waiting-open-live-map'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onOpenMap,
            child: SizedBox(
              height: 196,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: RepaintBoundary(
                      child: FlutterMap(
                        key: ValueKey('waiting-radar-map-${_lat.toStringAsFixed(4)}-${_lng.toStringAsFixed(4)}'),
                        options: MapOptions(
                          initialCenter: centerPoint,
                          initialZoom: 15.2,
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                        ),
                        children: [
                          buildSafeMapTileLayer(context),
                        ],
                      ),
                    ),
                  ),
                  // Vinheta executiva para leitura e contraste
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.92,
                        colors: [
                          tk.surface.withValues(alpha: tk.isDark ? 0.32 : 0.18),
                          tk.card.withValues(alpha: tk.isDark ? 0.88 : 0.82),
                        ],
                      ),
                    ),
                  ),
                  // Ondas concêntricas suaves em RepaintBoundary (120 FPS, zero jank)
                  if (first != null && job.isDirect)
                    Center(
                      child: CountdownRing(
                        remaining: first.remaining,
                        total: const Duration(hours: 2),
                        size: 150,
                        icon: Icons.hourglass_bottom_rounded,
                        caption: 'para responder',
                      ),
                    )
                  else
                    RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _radarCtrl,
                        builder: (context, child) => CustomPaint(
                          painter: _RadarConcentricPainter(
                            progress: _radarCtrl.value,
                            color: tk.accent,
                            secondaryColor: tk.success,
                          ),
                          child: child,
                        ),
                        child: Center(
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [tk.accent, tk.accent.withValues(alpha: 0.78)],
                              ),
                              boxShadow: tk.isDark
                                  ? const []
                                  : [
                                      BoxShadow(
                                        color: tk.accent.withValues(alpha: 0.45),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                              border: Border.all(color: tk.onAccent.withValues(alpha: 0.85), width: 2.5),
                            ),
                            child: Icon(
                              hasQuotes ? Icons.request_quote_rounded : Icons.home_work_rounded,
                              size: 32,
                              color: tk.onAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Badge superior: alcance regional e especialistas verificados
                  Positioned(
                    top: AppSpace.s12,
                    left: AppSpace.s12,
                    right: AppSpace.s12,
                    child: Wrap(
                      spacing: AppSpace.s8,
                      runSpacing: AppSpace.s8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          key: const ValueKey('live-radar-specialists-badge'),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s4),
                          decoration: BoxDecoration(
                            color: tk.surface.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                            border: Border.all(color: tk.accent.withValues(alpha: 0.40)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: tk.success,
                                ),
                              ),
                              const SizedBox(width: AppSpace.s8),
                              Flexible(
                                child: Text(
                                  '$notifiedCount especialistas verificados no alcance',
                                  style: AppType.caption.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: tk.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s4),
                          decoration: BoxDecoration(
                            color: tk.surface.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                            border: Border.all(color: tk.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.map_rounded, size: 14, color: tk.accentInk),
                              const SizedBox(width: AppSpace.s4),
                              Flexible(
                                child: Text(
                                  'Ver mapa e rota',
                                  style: AppType.caption.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: tk.accentInk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.s20, AppSpace.s16, AppSpace.s20, AppSpace.s20),
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppType.headline.copyWith(color: tk.text),
                ),
                const SizedBox(height: AppSpace.s8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: AppType.bodySm.copyWith(color: tk.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarConcentricPainter extends CustomPainter {
  const _RadarConcentricPainter({
    required this.progress,
    required this.color,
    required this.secondaryColor,
  });

  final double progress;
  final Color color;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = math.min(size.width, size.height) * 0.46;

    for (var i = 0; i < 3; i++) {
      final phase = (progress + (i / 3.0)) % 1.0;
      final radius = 24.0 + (maxRadius - 24.0) * phase;
      final alpha = (1.0 - phase).clamp(0.0, 1.0);

      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.14 * alpha);
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = (i.isEven ? color : secondaryColor).withValues(alpha: 0.42 * alpha);

      canvas.drawCircle(center, radius, fillPaint);
      canvas.drawCircle(center, radius, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarConcentricPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Linha do tempo executiva de 4 estágios com ícones *Duotone*:
/// `1. Pedido Publicado` -> `2. Especialistas Notificados` -> `3. Aguardando Propostas (X/3)` -> `4. Contratação Segura`.
class OrderPublishStepper extends StatelessWidget {
  const OrderPublishStepper({super.key, required this.quotes});

  final int quotes;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    final capped = quotes.clamp(0, 3);
    final steps = [
      (
        label: '1. Pedido Publicado',
        icon: Icons.check_circle_outline_rounded,
        done: true,
        active: false,
      ),
      (
        label: '2. Especialistas Notificados',
        icon: Icons.campaign_rounded,
        done: true,
        active: quotes == 0,
      ),
      (
        label: '3. Aguardando Propostas ($capped/3)',
        icon: Icons.request_quote_rounded,
        done: quotes > 0,
        active: true,
      ),
      (
        label: '4. Contratação Segura',
        icon: Icons.verified_user_outlined,
        done: false,
        active: false,
      ),
    ];

    Widget iconBadge(IconData icon, {required bool done, required bool active}) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: done
                ? [tk.accent, tk.accent.withValues(alpha: 0.8)]
                : active
                    ? [tk.accentSoft, tk.surface]
                    : [tk.surface, tk.card],
          ),
          border: Border.all(
            color: (done || active) ? tk.accent : tk.border,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: done ? tk.onAccent : (active ? tk.accentInk : tk.textMuted),
        ),
      );
    }

    return AppCard(
      key: const ValueKey('waiting-steps'),
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpace.s16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 460 && !layout.isLargeText;
          if (horizontal) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        iconBadge(steps[i].icon, done: steps[i].done, active: steps[i].active),
                        const SizedBox(height: AppSpace.s8),
                        Text(
                          steps[i].label,
                          textAlign: TextAlign.center,
                          style: AppType.caption.copyWith(
                            fontWeight: (steps[i].done || steps[i].active) ? FontWeight.w700 : FontWeight.w500,
                            color: (steps[i].done || steps[i].active) ? tk.text : tk.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < steps.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 17, left: AppSpace.s2, right: AppSpace.s2),
                      child: SizedBox(
                        width: 12,
                        child: Divider(
                          height: 2,
                          thickness: 2,
                          color: steps[i].done ? tk.accent : tk.border,
                        ),
                      ),
                    ),
                ],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    iconBadge(steps[i].icon, done: steps[i].done, active: steps[i].active),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(
                      child: Text(
                        steps[i].label,
                        style: AppType.bodySm.copyWith(
                          fontWeight: (steps[i].done || steps[i].active) ? FontWeight.w600 : FontWeight.w400,
                          color: (steps[i].done || steps[i].active) ? tk.text : tk.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                if (i < steps.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 17, top: AppSpace.s4, bottom: AppSpace.s4),
                    child: Container(
                      width: 2,
                      height: AppSpace.s12,
                      color: steps[i].done ? tk.accent : tk.border,
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Resumo do que foi pedido (categoria, título semântico, texto, quando, onde e fotos).
class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.job, required this.onOpenMap});

  final Job job;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final cleanHeadline = SmartOrderHeadlineFormatter.formatHeadline(
      job.title,
      category: job.category,
      fallbackDescription: job.description,
    );
    return AppCard(
      key: const ValueKey('waiting-summary'),
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryBrandEmblem(categoryName: job.category, size: 42, showCornerBadge: false),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.category, style: AppType.titleSm.copyWith(color: tk.text)),
                    Text(
                      '${job.code} • publicado ${relativeTime(job.createdAt)}',
                      style: AppType.caption.copyWith(color: tk.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          const AppStatusChip(
            'Aguardando Orçamento',
            tone: AppTone.info,
            icon: Icons.hourglass_top_rounded,
          ),
          const SizedBox(height: AppSpace.s12),
          Text(
            cleanHeadline,
            style: AppType.titleSm.copyWith(color: tk.text),
          ),
          if (job.description.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s8),
            Text(job.description, style: AppType.body.copyWith(color: tk.text)),
          ],
          if (job.photoPaths.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s12),
            SizedBox(
              height: 68,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: job.photoPaths.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s8),
                itemBuilder: (ctx, i) => GestureDetector(
                  onTap: () => FullscreenSwipePhotoGallery.show(
                    ctx,
                    items: [
                      for (var idx = 0; idx < job.photoPaths.length; idx++)
                        (path: job.photoPaths[idx], label: 'Foto ${idx + 1}'),
                    ],
                    initialIndex: i,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
                    child: SizedBox(
                      width: 68,
                      height: 68,
                      child: SignedImage(path: job.photoPaths[i], fit: BoxFit.cover, radius: AppGeometry.iconTileRadius),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.s12),
          Wrap(
            spacing: AppSpace.s12,
            runSpacing: AppSpace.s8,
            children: [
              if (job.scheduledFor != null) _Meta(icon: Icons.event_rounded, text: dateLong(job.scheduledFor!)),
              if ((job.addressSummary ?? '').isNotEmpty)
                _Meta(
                  icon: Icons.place_outlined,
                  text: job.addressSummary!,
                  onTap: onOpenMap,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final color = onTap != null ? tk.accentInk : tk.textMuted;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpace.s4),
        Flexible(
          child: Text(
            text,
            style: AppType.bodySm.copyWith(
              color: color,
              fontWeight: onTap != null ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: AppSpace.s4),
          Icon(Icons.map_outlined, size: 15, color: color),
        ],
      ],
    );
    if (onTap == null) return row;
    return AppPressable(
      borderRadius: BorderRadius.circular(AppSpace.s8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s4, horizontal: AppSpace.s4),
        child: row,
      ),
    );
  }
}

/// Estado de espera *Quiet Luxury* com 3 vagas visuais, ícone *Duotone*,
/// tempo médio estimado de resposta e selos de confiança (*Pagamento Protegido em Custódia*
/// e *0% de taxa sobre materiais*).
class _QuoteSlots extends StatelessWidget {
  const _QuoteSlots({required this.received});

  final int received;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    Widget slotTile(int i, {required bool wrapped}) {
      final filled = i < received;
      return Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
          color: filled ? tk.accentSoft : tk.surface,
          border: Border.all(
            color: filled ? tk.accent : tk.border,
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: wrapped ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              filled ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded,
              size: 16,
              color: filled ? tk.accentInk : tk.textMuted,
            ),
            const SizedBox(width: AppSpace.s4),
            Flexible(
              child: Text(
                filled ? 'Proposta ${i + 1}' : 'Vaga ${i + 1}',
                style: AppType.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: filled ? tk.accentInk : tk.textMuted,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      key: const ValueKey('waiting-slots'),
      variant: AppCardVariant.outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wrapSlots = layout.isLargeText || constraints.maxWidth < 340;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DarkGlassDuotoneBadge(
                    icon: received > 0 ? Icons.request_quote_rounded : Icons.radar_rounded,
                    secondaryIcon: Icons.verified_rounded,
                    accentColor: tk.accentInk,
                    size: 42,
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Orçamentos: $received de 3',
                          style: AppType.tabular(AppType.titleSm).copyWith(color: tk.text),
                        ),
                        const SizedBox(height: AppSpace.s2),
                        Text(
                          received == 0
                              ? 'Avisamos você assim que o primeiro chegar. Tempo médio: 5 a 15 min.'
                              : 'Você pode esperar mais propostas ou contratar agora.',
                          style: AppType.bodySm.copyWith(color: tk.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s12),
              if (wrapSlots)
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: [for (var i = 0; i < 3; i++) slotTile(i, wrapped: true)],
                )
              else
                Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i < 2 ? AppSpace.s8 : 0),
                          child: slotTile(i, wrapped: false),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: AppSpace.s12),
              Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                children: [
                  _TrustPill(
                    icon: Icons.shield_outlined,
                    label: 'Pagamento Protegido em Custódia',
                    color: tk.security,
                  ),
                  _TrustPill(
                    icon: Icons.receipt_long_outlined,
                    label: '0% de taxa sobre materiais',
                    color: tk.successInk,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s4),
      decoration: BoxDecoration(
        color: tk.surface,
        borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: AppSpace.s4),
          Flexible(
            child: Text(
              label,
              style: AppType.caption.copyWith(fontWeight: FontWeight.w600, color: tk.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote, required this.provider, required this.job});

  final Quote quote;
  final ProviderCard? provider;
  final Job job;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    final p = provider;
    return AppCard(
      variant: AppCardVariant.elevated,
      margin: const EdgeInsets.only(bottom: AppSpace.item),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = layout.isLargeText || constraints.maxWidth < 320;

          final priceBlock = Column(
            crossAxisAlignment: stack ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              AppPrice(value: quote.price, size: AppPriceSize.sm, color: tk.text),
              if (quote.estimatedHours != null)
                Text(
                  '~${quote.estimatedHours!.toStringAsFixed(quote.estimatedHours! % 1 == 0 ? 0 : 1)}h estimadas',
                  style: AppType.tabular(AppType.caption).copyWith(color: tk.textMuted),
                ),
            ],
          );

          final profileBtn = AppButton(
            label: 'Ver perfil',
            variant: AppButtonVariant.secondary,
            compact: true,
            onPressed: p == null
                ? null
                : () async {
                    final profile = await ProfileService().fetchCurrent();
                    if (profile == null || !context.mounted) return;
                    await Navigator.of(context).push(
                      AppRoute(
                        builder: (_) => ProviderPublicProfileScreen(provider: p, profile: profile, hideCta: true),
                      ),
                    );
                  },
          );

          final quoteBtn = AppButton(
            label: 'Ver orçamento',
            variant: AppButtonVariant.primary,
            compact: true,
            onPressed: () => Navigator.of(context).push(
              AppRoute(builder: (_) => QuoteReceivedScreen(job: job, quote: quote, provider: p)),
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppAvatar(url: p?.avatarUrl, name: p?.fullName ?? 'Profissional', radius: 24, verified: true),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p?.fullName ?? 'Profissional',
                          style: AppType.titleSm.copyWith(color: tk.text),
                        ),
                        if (p != null) ...[
                          const SizedBox(height: AppSpace.s2),
                          if (p.ratingCount > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, size: 15, color: tk.star),
                                const SizedBox(width: AppSpace.s4),
                                Flexible(
                                  child: Text(
                                    '${p.ratingAvg.toStringAsFixed(1).replaceAll('.', ',')} (${p.ratingCount}) • ${p.jobsDone} serviços',
                                    style: AppType.tabular(AppType.bodySm).copyWith(color: tk.textMuted),
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              'Novo na plataforma',
                              style: AppType.bodySm.copyWith(color: tk.textMuted),
                            ),
                        ],
                        if (stack) ...[
                          const SizedBox(height: AppSpace.s8),
                          priceBlock,
                        ],
                      ],
                    ),
                  ),
                  if (!stack) ...[
                    const SizedBox(width: AppSpace.s8),
                    Flexible(child: priceBlock),
                  ],
                ],
              ),
              if (quote.message != null && quote.message!.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s12),
                Text('"${quote.message}"', style: AppType.body.copyWith(color: tk.text)),
              ],
              const SizedBox(height: AppSpace.s12),
              if (stack)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    quoteBtn,
                    const SizedBox(height: AppSpace.s8),
                    profileBtn,
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: profileBtn),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(child: quoteBtn),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

/// "Orçamento Recebido" (protótipo 10.jpg): aceitar e pagar ou recusar.
class QuoteReceivedScreen extends StatefulWidget {
  const QuoteReceivedScreen({super.key, required this.job, required this.quote, required this.provider});

  final Job job;
  final Quote quote;
  final ProviderCard? provider;

  @override
  State<QuoteReceivedScreen> createState() => _QuoteReceivedScreenState();
}

class _QuoteReceivedScreenState extends State<QuoteReceivedScreen> {
  late final _jobs = JobService();
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await _jobs.acceptQuote(widget.quote.id);
      // O stream do pedido leva a tela de pagamento; fecha esta.
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final ok = await AppDialog.confirm(
      context,
      title: 'Recusar orçamento?',
      message: 'O profissional será avisado. Você pode aceitar outro orçamento ou convidar mais profissionais.',
      confirmLabel: 'Recusar',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await _jobs.rejectQuote(widget.quote.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    final margin = layout.margin;
    final p = widget.provider;
    final q = widget.quote;
    final avatar = AppAvatar(url: p?.avatarUrl, name: p?.fullName ?? '?', radius: 32, verified: true);
    final ratingBlock = (p != null && p.ratingCount > 0)
        ? Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s4,
            children: [
              AppRating(value: p.ratingAvg, size: 16),
              Text(
                '${p.ratingAvg.toStringAsFixed(1).replaceAll('.', ',')} (${p.ratingCount})',
                style: AppType.tabular(AppType.bodySm).copyWith(
                  fontWeight: FontWeight.w600,
                  color: tk.textMuted,
                ),
              ),
            ],
          )
        : null;
    final avatarHero = p != null ? AppHero(tag: 'provider-avatar-${p.id}', child: avatar) : avatar;
    return AppScaffold(
      appBar: const AppAppBar(title: 'Orçamento recebido'),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: margin, vertical: AppSpace.s16),
        children: [
          Semantics(
            header: true,
            child: Text(
              'Orçamento de ${p?.fullName ?? 'profissional'}',
              style: AppType.headline.copyWith(color: tk.text),
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          AppCard(
            variant: AppCardVariant.outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    avatarHero,
                    const SizedBox(width: AppSpace.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p?.fullName ?? 'Profissional',
                            style: AppType.title.copyWith(color: tk.text),
                          ),
                          if ((p?.title ?? '').isNotEmpty)
                            Text(
                              p!.title,
                              style: AppType.bodySm.copyWith(color: tk.textMuted),
                            ),
                          if (ratingBlock != null && !layout.isCompact && !layout.isLargeText) ...[
                            const SizedBox(height: AppSpace.s4),
                            ratingBlock,
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (ratingBlock != null && (layout.isCompact || layout.isLargeText)) ...[
                  const SizedBox(height: AppSpace.s12),
                  ratingBlock,
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          AppCard(
            variant: AppCardVariant.tonal,
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s24, horizontal: AppSpace.s16),
            child: Column(
              children: [
                Text(
                  'Valor do orçamento',
                  style: AppType.bodySm.copyWith(color: tk.textMuted),
                ),
                const SizedBox(height: AppSpace.s4),
                AppPrice(value: q.price, size: AppPriceSize.xl, color: tk.text),
                if (q.estimatedHours != null) ...[
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    'Previsão: ${q.estimatedHours!.toStringAsFixed(q.estimatedHours! % 1 == 0 ? 0 : 1)} h de serviço',
                    style: AppType.tabular(AppType.bodySm).copyWith(color: tk.textMuted),
                  ),
                ],
              ],
            ),
          ),
          if (q.message != null && q.message!.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s12),
            AppCard(
              variant: AppCardVariant.tonal,
              child: Text('"${q.message}"', style: AppType.body.copyWith(color: tk.text)),
            ),
          ],
          const SizedBox(height: AppSpace.s16),
          const InfoBanner(
            'O valor fica retido na Desperrengue e só é liberado ao profissional quando você informar o Código de Confirmação, ao final do serviço.',
            tone: BannerTone.security,
            title: 'Pagamento seguro',
          ),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        secondary: AppButton(
          label: 'Recusar orçamento',
          variant: AppButtonVariant.tertiary,
          onPressed: _busy ? null : _reject,
        ),
        child: AppButton(
          label: 'Aceitar e pagar ${brl(q.price)}',
          loading: _busy,
          onPressed: _accept,
        ),
      ),
    );
  }
}

// ==================================================================== pagamento

/// Checkout MOCK (protótipo 11.jpg). O estado do pedido muda por RPC.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.job});

  final Job job;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final _jobs = JobService();
  bool _busy = false;

  /// Trava de saldo: confere ANTES (sem saldo, abre a recarga) e o servidor confere de novo
  /// dentro da transação (INSUFFICIENT_FUNDS).
  Future<void> _pay() async {
    if (_busy) return;
    final cents = Money.fromReais(widget.job.agreedPrice ?? 0);
    setState(() => _busy = true);
    try {
      if (!await ensureFunds(context, cents)) return;
      try {
        await _jobs.payJob(widget.job.id, 'wallet', scheduledFor: widget.job.scheduledFor);
      } catch (e) {
        final low = InsufficientFunds.from(e);
        if (low == null || !mounted) rethrow;
        if (!await showInsufficientFundsSheet(context, requiredCents: low.requiredCents, availableCents: low.availableCents)) return;
        await _jobs.payJob(widget.job.id, 'wallet', scheduledFor: widget.job.scheduledFor);
      }
      if (mounted) {
        AppSnackbar.show(
          context,
          'Pagamento aprovado! O valor está protegido em garantia.',
          kind: AppSnackKind.success,
        );
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await AppDialog.confirm(
      context,
      title: 'Cancelar o pedido?',
      message: 'Você ainda não pagou nada. O profissional será avisado.',
      confirmLabel: 'Cancelar pedido',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _jobs.cancelJob(widget.job.id);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    final job = widget.job;
    final price = job.agreedPrice ?? 0;
    return AppScaffold(
      appBar: AppAppBar(
        leading: AppIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Voltar',
          onPressed: () => Navigator.maybePop(context),
        ),
        titleWidget: const BrandLogo(),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(margin, AppSpace.s4, margin, AppSpace.s24),
        children: [
          const AppStepper(total: 2, current: 2),
          const SizedBox(height: AppSpace.s16),
          Semantics(
            header: true,
            child: Text(
              'Forma de pagamento',
              style: AppType.headline.copyWith(color: tk.text),
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          AppCard(
            variant: AppCardVariant.tonal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppInfoRow(
                  label: 'Total a pagar',
                  valueWidget: AppPrice(value: price, size: AppPriceSize.lg, color: tk.text),
                ),
                Divider(height: 1, color: tk.border),
                const SizedBox(height: AppSpace.s8),
                Text(job.title, style: AppType.bodySm.copyWith(color: tk.textMuted)),
                if (job.scheduledFor != null) ...[
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    'Agendado para ${dateLong(job.scheduledFor!)}',
                    style: AppType.bodySm.copyWith(color: tk.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          WalletPayCard(priceCents: Money.fromReais(price)),
          const SizedBox(height: AppSpace.s16),
          const InfoBanner(
            'Pague agora para reservar. O dinheiro só vai para o profissional quando o serviço estiver concluído e você confirmar com o código.',
            tone: BannerTone.info,
            icon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: AppSpace.s12),
          Center(
            child: LinkButton(
              label: 'Cancelar pedido',
              onPressed: _busy ? null : _cancel,
              color: tk.textMuted,
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        child: AppButton(
          label: 'Confirmar e pagar ${brl(price)}',
          loading: _busy,
          onPressed: _pay,
        ),
      ),
    );
  }
}

// ==================================================================== emergência

/// Radar de matchmaking (emergência): aguarda o aceite em até 5 minutos.
class EmergencyRadarScreen extends StatefulWidget {
  const EmergencyRadarScreen({
    super.key,
    required this.job,
    this.invitesStreamOverride,
    this.initialProvider,
  });

  final Job job;
  final Stream<List<JobInvite>>? invitesStreamOverride;
  final ProviderCard? initialProvider;

  @override
  State<EmergencyRadarScreen> createState() => _EmergencyRadarScreenState();
}

class _EmergencyRadarScreenState extends State<EmergencyRadarScreen> {
  late final _jobs = JobService();
  late final Stream<List<JobInvite>> _invitesStream =
      widget.invitesStreamOverride ?? _jobs.streamInvites(widget.job.id);
  Timer? _tick;
  late ProviderCard? _provider = widget.initialProvider;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    if (_provider == null && widget.invitesStreamOverride == null) {
      unawaited(_loadProvider());
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    EagerImagePrefetcher.cancelPending();
    super.dispose();
  }

  Future<void> _loadProvider() async {
    try {
      final invites = await _jobs.invitesForJob(widget.job.id);
      if (invites.isEmpty) return;
      final p = await ProviderService().byId(invites.first.providerId);
      if (mounted) setState(() => _provider = p);
    } catch (_) {}
  }

  Future<void> _cancel() async {
    final ok = await AppDialog.confirm(
      context,
      title: 'Cancelar emergência?',
      message: 'A reserva de garantia será estornada.',
      confirmLabel: 'Cancelar pedido',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _jobs.cancelJob(widget.job.id);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    return StreamBuilder<List<JobInvite>>(
      stream: _invitesStream,
      builder: (context, snap) {
        final live = (snap.data ?? const <JobInvite>[]).where((i) => i.isLive).toList();
        final remaining = live.isEmpty ? Duration.zero : live.first.remaining;
        return AppScaffold(
          backgroundColor: tk.accentSoft,
          appBar: AppAppBar(
            backgroundColor: tk.accentSoft,
            leading: AppIconButton(
              icon: Icons.keyboard_arrow_down_rounded,
              size: 30,
              tooltip: 'Minimizar',
              onPressed: () => Navigator.maybePop(context),
            ),
            titleWidget: const BrandLogo(),
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s24),
            children: [
              Center(
                child: PulseRadar(
                  child: AppAvatar(url: _provider?.avatarUrl, name: _provider?.fullName ?? '?', radius: 44),
                ),
              ),
              const SizedBox(height: AppSpace.s8),
              Text(
                'Notificando ${_provider?.fullName ?? 'o profissional'}...',
                textAlign: TextAlign.center,
                style: AppType.headline.copyWith(color: tk.text),
              ),
              const SizedBox(height: AppSpace.s8),
              Text(
                'O profissional está analisando a sua emergência. Por favor, aguarde.',
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: tk.textMuted),
              ),
              const SizedBox(height: AppSpace.s16),
              Center(
                child: CountdownRing(remaining: remaining, total: const Duration(minutes: 5), size: 110, icon: null),
              ),
              Builder(builder: (context) {
                final triage = JobTriageStore.instance.resolveForJob(widget.job);
                if (!triage.hasEmergencyContainment) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s16),
                  child: EmergencyContainmentBanner(
                    guide: triage.containmentGuide!,
                    onToggleStep: (step) {
                      final updated = JobTriageStore.instance.toggleContainmentStepForJob(widget.job, step);
                      maybeProviderContainer(context)?.read(jobTriageRegistryProvider.notifier).saveForJob(widget.job.id, updated);
                      if (mounted) setState(() {});
                    },
                  ),
                );
              }),
              const SizedBox(height: AppSpace.s16),
              Text(
                'Pode sair do app se quiser, nós avisaremos assim que ele responder.',
                textAlign: TextAlign.center,
                style: AppType.bodySm.copyWith(color: tk.textMuted),
              ),
              const SizedBox(height: AppSpace.s8),
              Center(
                child: AppButton(
                  onPressed: () => Navigator.maybePop(context),
                  variant: AppButtonVariant.tertiary,
                  expand: false,
                  icon: Icons.home_rounded,
                  label: 'Minimizar e ir para o Início',
                ),
              ),
              const SizedBox(height: AppSpace.s8),
              AppButton(
                label: 'Cancelar pedido',
                variant: AppButtonVariant.secondary,
                onPressed: _cancel,
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _showMatchDialog(BuildContext context, ProviderCard provider) {
  return AppDialog.show<void>(
    context,
    title: 'Temos um Match!',
    content: Builder(
      builder: (ctx) {
        final tk = ctx.tk;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppStatusChip(
              'Confirmado!',
              tone: AppTone.success,
              icon: Icons.celebration_rounded,
            ),
            const SizedBox(height: AppSpace.s16),
            AppAvatar(url: provider.avatarUrl, name: provider.fullName, radius: 40, verified: true),
            const SizedBox(height: AppSpace.s8),
            Text(
              provider.fullName,
              textAlign: TextAlign.center,
              style: AppType.title.copyWith(color: tk.text),
            ),
            if (provider.title.isNotEmpty)
              Text(
                provider.title,
                textAlign: TextAlign.center,
                style: AppType.bodySm.copyWith(color: tk.textMuted),
              ),
            const SizedBox(height: AppSpace.s12),
            Text(
              '${firstName(provider.fullName)} aceitou o seu pedido de emergência! Ele já está se preparando e a caminho do seu endereço.',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: tk.text),
            ),
          ],
        );
      },
    ),
    actions: [
      Builder(
        builder: (ctx) => AppButton(
          label: 'Acompanhar profissional',
          trailingArrow: true,
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    ],
  );
}

class _CanceledView extends StatelessWidget {
  const _CanceledView({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final refunded = job.paymentStatus == 'refunded';
    return AppScaffold(
      appBar: AppAppBar(title: job.code),
      body: AppEmptyState(
        icon: Icons.cancel_outlined,
        title: 'Pedido cancelado',
        message: refunded
            ? 'A reserva foi estornada. Você pode fazer um novo pedido quando quiser.'
            : (job.isEmergency
                ? 'Ninguém aceitou a emergência a tempo. Tente outro profissional.'
                : 'Este pedido foi cancelado. Você pode fazer um novo pedido quando quiser.'),
        actionLabel: 'Voltar ao início',
        onAction: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
    );
  }
}

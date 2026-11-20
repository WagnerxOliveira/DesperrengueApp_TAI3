import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/geocode_models.dart';
import '../../../core/models/marketplace_models.dart';
import '../../../core/models/scheduling_models.dart';
import '../../../core/security/geo_privacy_policy_engine.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/precise_geocoder.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/services/scheduling_service.dart';
import '../../../core/state/smart_triage_controller.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart' show BrandLogo, friendlyError;
import '../../../core/utils/format.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/names.dart';
import 'chat_screen.dart';
import 'geo_privacy_widgets.dart';
import 'service_map_widgets.dart';
import 'smart_triage_widgets.dart';

/// Botão de teste "Simular dia/hora e GPS no local" (ignora a trava de horário e de distância).
///
/// Padrão: LIGADO só em debug/teste e DESLIGADO em build release (APK beta/produção). Para um
/// build de homologação específico use `--dart-define=CHECKIN_SANDBOX=true`. Em produção o servidor
/// também fica com `app_settings.checkin_sandbox = 'false'`, então mesmo que o botão apareça o
/// servidor recusa (`START_SANDBOX_OFF`).
bool shouldShowCheckinSandbox({required bool releaseMode, bool? envOverride}) =>
    envOverride ?? !releaseMode;

const bool _kCheckinSandboxEnvSet = bool.hasEnvironment('CHECKIN_SANDBOX');
const bool _kCheckinSandboxEnv = bool.fromEnvironment('CHECKIN_SANDBOX');
final bool kCheckinSandboxUi = shouldShowCheckinSandbox(
  releaseMode: kReleaseMode,
  envOverride: _kCheckinSandboxEnvSet ? _kCheckinSandboxEnv : null,
);

enum LocationAccess { granted, denied }

/// Dependências do pré-serviço (tudo que toca rede/GPS), substituíveis nos testes.
class SchedulingDeps {
  const SchedulingDeps({
    required this.backend,
    required this.requestLocation,
    required this.positions,
    required this.address,
    required this.clientCard,
    required this.peer,
    required this.geocode,
    this.location,
  });

  final SchedulingBackend backend;
  final Future<LocationAccess> Function() requestLocation;
  final Stream<GeoFix> Function() positions;
  final Future<Map<String, dynamic>?> Function(String jobId) address;
  final Future<Map<String, dynamic>?> Function(String jobId) clientCard;

  /// Nome/foto do profissional (visão do cliente).
  final Future<({String name, String? avatar})?> Function(String providerId)
      peer;

  /// Geocodificação feita no celular do CLIENTE; o servidor não consegue (403 em datacenter).
  final Future<GeocodeHit?> Function(String addressLine, String? summary)
      geocode;

  /// Localização protegida do PROFISSIONAL (servidor decide o que ele pode ver). Padrão: [ProviderLocationSource].
  final Future<ProviderLocationView?> Function(String jobId)? location;

  factory SchedulingDeps.live() {
    final jobs = JobService();
    return SchedulingDeps(
      backend: SupabaseSchedulingBackend(),
      requestLocation: () async {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        return perm == LocationPermission.denied ||
                perm == LocationPermission.deniedForever
            ? LocationAccess.denied
            : LocationAccess.granted;
      },
      positions: () => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
      ).map((p) => GeoFix(p.latitude, p.longitude, accuracyM: p.accuracy)),
      address: jobs.jobAddress,
      clientCard: jobs.clientCard,
      peer: (id) async {
        final p = await ProviderService().byId(id);
        return p == null
            ? null
            : (
                name: friendlyName(p.fullName, fallback: 'Profissional'),
                avatar: p.avatarUrl,
              );
      },
      geocode: (line, summary) =>
          PreciseGeocoder().geocode(line, summary: summary),
      location: (id) => ProviderLocationSource.load(id),
    );
  }
}

/// Pré-serviço AGENDADO (`JobStatus.scheduled`): cliente e profissional veem os detalhes, mas
/// **não existe cronômetro nem "Finalizar serviço"**. O profissional só consegue iniciar com a
/// DUPLA TRAVA: (1) horário (relógio do servidor, a partir de 15 min antes) e (2) estar a ≤ 100 m
/// do endereço (Haversine). O servidor revalida tudo em `start_job`; a UI só antecipa o resultado.
class ScheduledServiceScreen extends StatefulWidget {
  const ScheduledServiceScreen({
    super.key,
    required this.job,
    required this.asProvider,
    @visibleForTesting this.deps,
  });

  final Job job;
  final bool asProvider;
  final SchedulingDeps? deps;

  @override
  State<ScheduledServiceScreen> createState() => _ScheduledServiceScreenState();
}

class _ScheduledServiceScreenState extends State<ScheduledServiceScreen> {
  late final SchedulingDeps _deps = widget.deps ?? SchedulingDeps.live();
  late final ServerClock _clock = ServerClock(_deps.backend);
  final ValueNotifier<GeoFix?> _pos = ValueNotifier<GeoFix?>(null);
  StreamSubscription<GeoFix>? _posSub;
  Timer? _tick;

  /// Pulso de 1 s: só a contagem regressiva e o botão de iniciar escutam (não a tela toda).
  final ValueNotifier<int> _clockTick = ValueNotifier<int>(0);

  JobDestination? _dest;
  bool _destLoading = true;
  bool _permDenied = false;
  bool _starting = false;
  Map<String, dynamic>? _address;

  /// Visão de localização do PROFISSIONAL (null = ainda não confirmada: nada de endereço).
  ProviderLocationView? _locView;
  bool _locLoaded = false;
  bool _locRefreshing = false;
  DateTime _nextLocRefreshAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _peerName = '';
  String? _peerAvatar;

  Job get job => widget.job;

  @override
  void initState() {
    super.initState();
    // Reavalia a contagem regressiva a cada segundo (barato: só o checklist e o botão reconstroem).
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _maybeRefreshLocation();
      _clockTick.value++;
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _posSub?.cancel();
    _pos.dispose();
    _clockTick.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Relógio do servidor primeiro: sem ele a UI cairia no relógio do celular (adulterável).
    unawaited(
      _clock.sync().then((_) => mounted ? setState(() {}) : null).catchError((_) {}),
    );
    // O endereço vem primeiro: o cliente precisa dele para geocodificar o destino.
    if (widget.asProvider) await _loadProviderLocation();
    await _loadPeerAndAddress();
    await _loadDestination();
    if (widget.asProvider) await _startLocation();
  }

  /// Profissional: pergunta ao servidor o que ele pode ver (falha ⇒ continua protegido).
  Future<void> _loadProviderLocation() async {
    ProviderLocationView? v;
    try {
      final custom = _deps.location;
      v = await (custom != null
          ? custom(job.id)
          : ProviderLocationSource.load(job.id));
    } catch (_) {
      v = null;
    }
    if (!mounted) return;
    setState(() {
      _locView = v;
      _locLoaded = true;
      if (v != null && v.exactUnlocked) {
        // Só depois do desbloqueio o endereço exato passa a existir neste aparelho.
        _address = {
          'address_line': exactAddressLineOf(v),
          if ((v.reference ?? '').trim().isNotEmpty) 'reference': v.reference,
        };
      } else {
        _address = null;
        _dest = null;
      }
    });
  }

  /// No instante do desbloqueio (00h00 SP, relógio do servidor) rebusca e carrega o destino exato.
  void _maybeRefreshLocation() {
    if (!widget.asProvider ||
        _locRefreshing ||
        DateTime.now().isBefore(_nextLocRefreshAt)) {
      return;
    }
    final v = _locView;
    if (v == null || v.exactUnlocked) return;
    final at = v.unlockAt;
    if (at == null || _clock.now().isBefore(at)) return;
    _locRefreshing = true;
    _loadProviderLocation().then((_) async {
      if (mounted && (_locView?.exactUnlocked ?? false)) {
        await _loadDestination();
      }
    }).whenComplete(() {
      // Evita martelar o servidor se ele ainda não liberou (relógio do aparelho adiantado).
      _nextLocRefreshAt = DateTime.now().add(const Duration(seconds: 20));
      _locRefreshing = false;
    });
  }

  Future<void> _loadPeerAndAddress() async {
    try {
      // O profissional NUNCA lê `job_addresses` diretamente: o endereço vem da visão protegida.
      final a = widget.asProvider ? null : await _deps.address(job.id);
      String name;
      String? avatar;
      if (widget.asProvider) {
        final c = await _deps.clientCard(job.id);
        name = friendlyName(c?['full_name'] as String?);
        avatar = c?['avatar_url'] as String?;
      } else {
        final p =
            job.providerId == null ? null : await _deps.peer(job.providerId!);
        name = p?.name ?? 'Profissional';
        avatar = p?.avatar;
      }
      if (!mounted) return;
      setState(() {
        // Profissional: não sobrescreve o endereço liberado pela visão protegida.
        if (!widget.asProvider) _address = a;
        _peerName = name;
        _peerAvatar = avatar;
      });
    } catch (_) {}
  }

  Future<void> _loadDestination() async {
    // Profissional: coordenada exata só existe depois do desbloqueio.
    if (widget.asProvider && !(_locView?.exactUnlocked ?? false)) {
      if (mounted) setState(() => _destLoading = false);
      return;
    }
    try {
      var d = await _deps.backend.destination(job.id);
      final line = _address?['address_line'] as String?;
      if (d == null && !widget.asProvider && line != null) {
        // Sem ponto salvo: o app do CLIENTE geocodifica (Nominatim) e registra com a qualidade do
        // resultado. O servidor não confia no profissional para isso.
        final hit = await _deps.geocode(line, job.addressSummary);
        if (hit != null) {
          d = await _deps.backend.setLocation(
            job.id,
            hit.lat,
            hit.lng,
            source: 'client_geocode',
            precision: hit.precision.wire,
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _dest = d;
        _destLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _destLoading = false);
    }
  }

  Future<void> _startLocation() async {
    final access = await _deps.requestLocation();
    if (!mounted) return;
    if (access == LocationAccess.denied) {
      setState(() => _permDenied = true);
      return;
    }
    setState(() => _permDenied = false);
    await _posSub?.cancel();
    _posSub = _deps.positions().listen(
      (f) {
        _pos.value = f;
        if (mounted) setState(() {});
      },
      onError: (_) {},
    );
  }

  StartGate get _gate => evaluateStartGate(
        serverNow: _clock.now(),
        scheduledFor: job.scheduledFor,
        destination: _dest,
        position: _pos.value,
        permissionDenied: _permDenied,
      );

  Future<void> _start({bool simulate = false}) async {
    if (_starting) return;
    if (simulate) {
      final ok = await AppDialog.confirm(
        context,
        title: 'Modo de teste',
        message:
            'Isto ignora a data/hora e o GPS e inicia o serviço agora. Só existe em versões de teste do aplicativo.',
        confirmLabel: 'Simular e iniciar',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _starting = true);
    try {
      await _deps.backend
          .startJob(job.id, position: _pos.value, simulate: simulate);
      if (mounted) {
        AppSnackbar.show(
          context,
          'Serviço iniciado! O cronômetro começou.',
          kind: AppSnackKind.success,
        );
      }
      // O stream do pedido troca esta tela pela de execução; nada mais a fazer aqui.
    } on StartJobFailure catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.message, kind: AppSnackKind.error);
      // Servidor discordou da UI (relógio/destino/GPS): ressincroniza.
      unawaited(_clock.sync().catchError((_) {}));
      unawaited(_loadDestination());
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _openChat() async {
    final me = Supabase.instance.client.auth.currentUser?.id;
    final providerId = widget.asProvider ? me : job.providerId;
    if (providerId == null) return;
    await Navigator.of(context).push(
      AppRoute<void>(
        builder: (_) => ChatScreen(
          job: job,
          providerId: providerId,
          peerName: _peerName.isEmpty ? null : _peerName,
          peerAvatar: _peerAvatar,
        ),
      ),
    );
  }

  Future<void> _onAddressTap() async {
    final d = _dest;
    if (widget.asProvider) {
      final view = _locView;
      // Trava: sem confirmação do servidor ou antes do dia ⇒ só a região aproximada.
      if (view == null) return;
      if (!view.exactUnlocked) {
        await openProviderLocation(context, view);
        return;
      }
      final addressLabel = exactAddressLineOf(view);
      if (d == null) {
        await openProviderLocation(context, view);
        return;
      }
      await MapaRotaServicoModal.show(
        context,
        destination: d,
        addressLabel: addressLabel.isEmpty ? view.areaTitle : addressLabel,
        position: _pos,
      );
    } else if (widget.deps != null) {
      await _pickLocation();
    }
  }

  Future<void> _pickLocation() async {
    final line = (_address?['address_line'] as String?) ?? job.addressSummary;
    final ok = await LocationPickerSheet.show(
      context,
      initial: _dest,
      addressLine: line,
      onAddressResolved: (addr) {
        if (mounted) {
          setState(() {
            _address = {
              ...?_address,
              'address_line': addr.fullLine,
            };
          });
        }
      },
      onConfirm: (lat, lng) async {
        final d = await _deps.backend.setLocation(job.id, lat, lng);
        if (mounted) setState(() => _dest = d);
      },
    );
    if (ok == true && mounted) {
      AppSnackbar.show(
        context,
        'Local confirmado! O profissional será guiado até este ponto.',
        kind: AppSnackKind.success,
      );
    }
  }

  void _openPhotoDialog(String path) {
    AppDialog.show<void>(
      context,
      title: 'Foto do serviço',
      content: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
          child: InteractiveViewer(
            child: SignedImage(path: path, fit: BoxFit.contain, radius: 0),
          ),
        ),
      ),
      actions: [
        Builder(
          builder: (ctx) => AppButton(
            label: 'Fechar',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final price = job.agreedPrice ?? 0;
    final net = price - price * 0.15;
    final margin = context.layout.margin;
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
        padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s24),
        children: [
          // ---- cabeçalho: código, status e data/hora agendada
          AppCard(
            variant: AppCardVariant.tonal,
            color: tk.infoSoft,
            borderColor: tk.info.withValues(alpha: 0.45),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wrap (não Row): em telas estreitas/fontes grandes o código desce para a linha de baixo.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpace.s12,
                  runSpacing: AppSpace.s8,
                  children: [
                    const AppStatusChip(
                      'Serviço agendado',
                      tone: AppTone.info,
                      icon: Icons.event_available_rounded,
                    ),
                    Text(
                      job.code,
                      style: AppType.tabular(AppType.bodyStrong)
                          .copyWith(color: tk.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.s2),
                      child: Icon(Icons.calendar_month_rounded, color: tk.info),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text(
                        job.scheduledFor != null
                            ? 'Agendado para ${dateLong(job.scheduledFor!)}'
                            : 'Aguardando combinar o horário',
                        style: AppType.tabular(AppType.titleSm)
                            .copyWith(color: tk.text),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.item),
          // ---- custódia
          AppCard(
            variant: AppCardVariant.tonal,
            color: tk.successSoft,
            borderColor: tk.success.withValues(alpha: 0.65),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s2),
                  child: Icon(Icons.lock_rounded, color: tk.successInk),
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.asProvider
                            ? 'Pagamento retido e garantido: ${brl(price)}'
                            : 'Valor retido em custódia: ${brl(price)}',
                        style: AppType.tabular(AppType.titleSm)
                            .copyWith(color: tk.successInk),
                      ),
                      const SizedBox(height: AppSpace.s4),
                      Text(
                        widget.asProvider
                            ? 'Você recebe ${brl(net)} após a confirmação do cliente.'
                            : 'Só é liberado ao profissional quando você informar o código no fim do serviço.',
                        style: AppType.tabular(AppType.bodySm)
                            .copyWith(color: tk.successInk),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.item),
          // ---- pedido: título, descrição e fotos
          AppCard(
            variant: AppCardVariant.elevated,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.title,
                  style: AppType.titleSm.copyWith(color: tk.text),
                ),
                const SizedBox(height: AppSpace.s8),
                Text(
                  job.description.isEmpty
                      ? 'Sem descrição detalhada.'
                      : job.description,
                  style: AppType.body.copyWith(color: tk.textMuted),
                ),
                if (job.photoPaths.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s12),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: job.photoPaths.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpace.s8),
                      itemBuilder: (context, i) => AppPressable(
                        onTap: () => _openPhotoDialog(job.photoPaths[i]),
                        borderRadius: BorderRadius.circular(
                          AppGeometry.iconTileRadius,
                        ),
                        semanticLabel: 'Ampliar foto ${i + 1}',
                        child: SignedImage(
                          path: job.photoPaths[i],
                          width: 96,
                          height: 96,
                          radius: AppGeometry.iconTileRadius,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpace.item),
          // ---- endereço (com trava temporal de privacidade para o profissional e somente leitura para o cliente)
          if (widget.asProvider)
            (_locView == null)
                ? ProviderLocationPending(loading: !_locLoaded)
                : ProviderLocationPanel(
                    view: _locView!,
                    onOpenExactMap: _onAddressTap,
                  )
          else
            _AddressCard(
              line: (_address?['address_line'] as String?) ??
                  job.addressSummary ??
                  'Carregando endereço…',
              reference: _address?['reference'] as String?,
              asProvider: false,
              destination: _dest,
              loading: _destLoading,
              allowTestPin: widget.deps != null,
              onTap: _onAddressTap,
            ),
          const SizedBox(height: AppSpace.item),
          // A contagem regressiva muda a cada segundo: só estes blocos reconstroem (não a tela inteira).
          ValueListenableBuilder<int>(
            valueListenable: _clockTick,
            builder: (context, _, _) => RepaintBoundary(
              child: widget.asProvider
                  ? _Checklist(
                      gate: _gate,
                      scheduledFor: job.scheduledFor,
                      onEnableLocation: _startLocation,
                      addressLocked: !(_locView?.exactUnlocked ?? false),
                    )
                  : _ClientRules(gate: _gate, scheduledFor: job.scheduledFor),
            ),
          ),
          const SizedBox(height: AppSpace.item),
          AppButton(
            label: widget.asProvider
                ? 'Chat com o cliente'
                : 'Chat com o profissional',
            icon: Icons.chat_bubble_outline_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: _openChat,
          ),
          const SizedBox(height: AppSpace.item),
          ValueListenableBuilder(
            valueListenable: JobTriageStore.instance,
            builder: (context, _, _) {
              final triage = JobTriageStore.instance.resolveForJob(job);
              if (widget.asProvider) {
                return ProviderTriageBriefCard(result: triage);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (triage.hasEmergencyContainment) ...[
                    EmergencyContainmentBanner(
                      guide: triage.containmentGuide!,
                      onToggleStep: (step) {
                        final updated = JobTriageStore.instance
                            .toggleContainmentStepForJob(job, step);
                        maybeProviderContainer(context)
                            ?.read(jobTriageRegistryProvider.notifier)
                            .saveForJob(job.id, updated);
                      },
                    ),
                    const SizedBox(height: AppSpace.item),
                  ],
                  SmartTriageCard(
                    result: triage,
                    selectedCategory: job.category,
                    onToggleMaterial: (materialId) {
                      final updated = JobTriageStore.instance
                          .toggleMaterialForJob(job, materialId);
                      maybeProviderContainer(context)
                          ?.read(jobTriageRegistryProvider.notifier)
                          .saveForJob(job.id, updated);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: widget.asProvider
          ? AppBottomBar(
              footnote:
                  'O cronômetro só começa quando você iniciar o serviço no local e no horário.',
              secondary: kCheckinSandboxUi
                  ? AppButton(
                      label: 'Simular dia/hora e GPS no local',
                      icon: Icons.science_outlined,
                      variant: AppButtonVariant.tertiary,
                      compact: true,
                      onPressed: _starting ? null : () => _start(simulate: true),
                    )
                  : null,
              child: ValueListenableBuilder<int>(
                valueListenable: _clockTick,
                builder: (context, _, _) => AppButton(
                  label: 'Iniciar serviço (ativar cronômetro)',
                  icon: Icons.play_arrow_rounded,
                  loading: _starting,
                  onPressed: _gate.canStart ? () => _start() : null,
                ),
              ),
            )
          : null,
    );
  }
}

// ------------------------------------------------------------------------------ partes da tela

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.line,
    required this.reference,
    required this.asProvider,
    required this.destination,
    required this.loading,
    required this.onTap,
    this.allowTestPin = false,
  });

  final String line;
  final String? reference;
  final bool asProvider;
  final JobDestination? destination;
  final bool loading;
  final VoidCallback onTap;
  final bool allowTestPin;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final needsPin = allowTestPin &&
        !asProvider &&
        (destination == null || destination!.needsClientPin);
    final hint = needsPin
        ? 'Confirmar o local exato no mapa'
        : 'Endereço registrado para o atendimento';
    return AppCard(
      variant: AppCardVariant.elevated,
      onTap: needsPin ? onTap : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s2),
            child: Icon(
              Icons.place_rounded,
              color: asProvider ? tk.providerAccentInk : tk.clientAccentInk,
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line,
                  style: AppType.bodyStrong.copyWith(color: tk.text),
                ),
                if (reference != null && reference!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s4),
                    child: Text(
                      'Ref: $reference',
                      style: AppType.bodySm.copyWith(color: tk.textMuted),
                    ),
                  ),
                const SizedBox(height: AppSpace.s8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (needsPin) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.s2),
                        child: Icon(
                          Icons.edit_location_alt_outlined,
                          size: 16,
                          color: tk.warningInk,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s8),
                    ],
                    Expanded(
                      child: Text(
                        hint,
                        style: AppType.caption.copyWith(
                          fontWeight:
                              needsPin ? FontWeight.w700 : FontWeight.w500,
                          color: needsPin ? tk.warningInk : tk.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (needsPin) Icon(Icons.chevron_right_rounded, color: tk.textMuted),
        ],
      ),
    );
  }
}

/// Checklist de liberação do botão "Iniciar serviço" (as DUAS travas).
class _Checklist extends StatelessWidget {
  const _Checklist({
    required this.gate,
    required this.scheduledFor,
    required this.onEnableLocation,
    this.addressLocked = false,
  });

  /// Endereço ainda protegido: não há distância nem local exato para mostrar.
  final bool addressLocked;
  final StartGate gate;
  final DateTime? scheduledFor;
  final VoidCallback onEnableLocation;

  static String _countdown(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours >= 1) {
      return '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}min';
    }
    final m = d.inMinutes;
    return m >= 1
        ? '${m}min ${(d.inSeconds % 60).toString().padLeft(2, '0')}s'
        : '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final when = scheduledFor == null
        ? 'sem horário definido'
        : '${two(scheduledFor!.day)}/${two(scheduledFor!.month)} às ${hhmm(scheduledFor!)}';

    final (timeIcon, timeColor, timeText) = gate.timeOk
        ? (
            Icons.check_circle_rounded,
            tk.successInk,
            'Data e horário do agendamento ($when)',
          )
        : (
            Icons.hourglass_top_rounded,
            tk.warningInk,
            'Data e horário do agendamento ($when) — libera em ${_countdown(gate.untilOpen ?? Duration.zero)}',
          );

    final radius = gate.radiusM?.round();
    final dist = gate.distanceM;
    final (geoIcon, geoColor, geoText) = addressLocked
        ? (
            Icons.lock_clock_rounded,
            tk.info,
            'O local exato e a distância até o cliente são liberados às 00h00 do dia do serviço.',
          )
        : switch (gate.geo) {
            GeoGateState.ok => (
                Icons.check_circle_rounded,
                tk.successInk,
                'No local do cliente (distância atual: ${formatMeters(dist ?? 0)})',
              ),
            GeoGateState.tooFar => (
                Icons.place_outlined,
                tk.warningInk,
                'Chegue a menos de $radius m do cliente — distância atual: ${formatMeters(dist ?? 0)}',
              ),
            GeoGateState.noPosition => (
                Icons.gps_not_fixed_rounded,
                tk.warningInk,
                'Aguardando o sinal de GPS…',
              ),
            GeoGateState.lowAccuracy => (
                Icons.gps_not_fixed_rounded,
                tk.warningInk,
                'Sinal de GPS fraco. Vá para um local aberto.',
              ),
            GeoGateState.permissionDenied => (
                Icons.location_off_rounded,
                tk.dangerInk,
                'Localização desativada. Ative para liberar o início.',
              ),
            GeoGateState.noDestination => (
                Icons.search_rounded,
                tk.warningInk,
                'O cliente ainda não confirmou o local no mapa. Peça a ele pelo chat.',
              ),
            GeoGateState.imprecise => (
                Icons.edit_location_alt_outlined,
                tk.warningInk,
                'Endereço impreciso no mapa. Peça ao cliente para confirmar o local.',
              ),
          };

    Widget row(IconData icon, Color color, String text, {Widget? trailing}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Text(
                  text,
                  style: AppType.tabular(AppType.bodySm).copyWith(
                    fontWeight: FontWeight.w600,
                    color: color == tk.successInk ? tk.successInk : tk.text,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpace.s8),
                trailing,
              ],
            ],
          ),
        );

    return AppCard(
      variant: AppCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                gate.canStart
                    ? Icons.lock_open_rounded
                    : Icons.lock_outline_rounded,
                color: gate.canStart ? tk.successInk : tk.textMuted,
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  gate.canStart
                      ? 'Tudo certo para iniciar'
                      : 'Liberação para iniciar',
                  style: AppType.titleSm.copyWith(color: tk.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          row(timeIcon, timeColor, timeText),
          row(
            geoIcon,
            geoColor,
            geoText,
            trailing: gate.geo == GeoGateState.permissionDenied
                ? AppButton(
                    label: 'Ativar',
                    variant: AppButtonVariant.tertiary,
                    expand: false,
                    compact: true,
                    onPressed: onEnableLocation,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// Visão do cliente: explica as travas (sem controles de início) e mostra quando abre.
class _ClientRules extends StatelessWidget {
  const _ClientRules({required this.gate, required this.scheduledFor});

  final StartGate gate;
  final DateTime? scheduledFor;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final opens = gate.opensAt;
    return AppCard(
      variant: AppCardVariant.tonal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: tk.security),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  'Como o início é protegido',
                  style: AppType.titleSm.copyWith(color: tk.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            opens == null
                ? 'O profissional só inicia o serviço quando estiver no seu endereço.'
                : 'O profissional só consegue iniciar o serviço a partir de ${dateShort(opens)} e quando estiver no seu endereço (a menos de 100 m). '
                    'Até lá, não há cronômetro e o serviço não pode ser finalizado.',
            style: AppType.tabular(AppType.bodySm)
                .copyWith(color: tk.textMuted),
          ),
        ],
      ),
    );
  }
}

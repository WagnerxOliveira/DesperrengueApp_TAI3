import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/state/smart_triage_controller.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../shared/presentation/geo_privacy_widgets.dart';
import '../../shared/presentation/scheduled_service_screen.dart';
import '../../shared/presentation/smart_triage_widgets.dart';
import 'provider_execution_screens.dart';

/// Acompanha UM serviço do ponto de vista do profissional e mostra a tela
/// certa para cada estado (orçar, aguardar, executar, concluir).
class ProviderJobScreen extends StatelessWidget {
  const ProviderJobScreen({
    super.key,
    required this.jobId,
    this.stream,
    this.jobService,
    this.currentUserId,
  });

  final String jobId;

  /// Ganchos opcionais para testes (padrão `null`, zero impacto em produção).
  final Stream<Job?>? stream;
  final JobService? jobService;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final jobs = jobService ?? (stream == null ? JobService() : null);
    final me = currentUserId ?? Supabase.instance.client.auth.currentUser?.id;
    return StreamBuilder<Job?>(
      stream: stream ?? jobs!.streamJob(jobId),
      builder: (context, snap) {
        if (snap.hasError) {
          return const AppScaffold(
            appBar: AppAppBar(),
            body: AppErrorState(message: 'Não foi possível carregar o serviço.'),
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const AppScaffold(appBar: AppAppBar(), body: AppSkeletonList(count: 3));
        }
        final job = snap.data;
        if (job == null) {
          return const AppScaffold(
            appBar: AppAppBar(),
            body: AppEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Serviço indisponível',
              message: 'Este pedido foi cancelado ou contratado com outro profissional.',
            ),
          );
        }
        final mine = job.providerId == me;
        switch (job.status) {
          case JobStatus.open:
            return _OpenJobRouter(job: job, jobs: jobs ?? JobService(), currentUserId: me);
          case JobStatus.awaitingPayment:
            return mine
                ? ProviderWaitingPaymentScreen(job: job)
                : const ProviderUnavailableScreen('Este pedido foi contratado com outro profissional.');
          case JobStatus.scheduled:
            return mine
                ? ScheduledServiceScreen(job: job, asProvider: true)
                : const ProviderUnavailableScreen('Este pedido foi contratado com outro profissional.');
          case JobStatus.inProgress:
          case JobStatus.awaitingApproval:
            return mine
                ? ServiceExecutionScreen(job: job, myId: me)
                : const ProviderUnavailableScreen('Este pedido foi contratado com outro profissional.');
          case JobStatus.completed:
            return mine
                ? PaidSuccessScreen(job: job)
                : const ProviderUnavailableScreen('Este serviço foi concluído por outro profissional.');
          case JobStatus.disputed:
            return mine
                ? MediationScreen(job: job)
                : const ProviderUnavailableScreen('Este pedido está em mediação.');
          case JobStatus.canceled:
            return const ProviderUnavailableScreen('Este pedido foi cancelado pelo cliente.');
        }
      },
    );
  }
}

class _OpenJobRouter extends StatelessWidget {
  const _OpenJobRouter({required this.job, required this.jobs, this.currentUserId});

  final Job job;
  final JobService jobs;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final me = currentUserId ?? Supabase.instance.client.auth.currentUser?.id;
    return StreamBuilder<List<Quote>>(
      stream: jobs.streamQuotes(job.id),
      builder: (context, qsnap) {
        final mine = (qsnap.data ?? const <Quote>[]).where((q) => me != null && q.providerId == me).toList();
        if (mine.isNotEmpty) {
          final q = mine.first;
          if (q.status == 'rejected') {
            return const ProviderUnavailableScreen('O cliente recusou o seu orçamento. Que tal buscar novos serviços?');
          }
          return AwaitingResponseScreen(job: job, quote: q);
        }
        return StreamBuilder<List<JobInvite>>(
          stream: jobs.streamInvites(job.id),
          builder: (context, isnap) {
            final invite = (isnap.data ?? const <JobInvite>[]).where((i) => me != null && i.providerId == me).firstOrNull;
            if (job.isEmergency) return EmergencyDecisionScreen(job: job, invite: invite);
            return QuoteFormScreen(job: job, invite: invite);
          },
        );
      },
    );
  }
}

@visibleForTesting
class ProviderUnavailableScreen extends StatelessWidget {
  const ProviderUnavailableScreen(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => AppScaffold(
        appBar: const AppAppBar(titleWidget: BrandLogo()),
        body: AppEmptyState(
          icon: Icons.info_outline_rounded,
          title: 'Nada a fazer aqui',
          message: message,
          actionLabel: 'Voltar ao painel',
          onAction: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      );
}

/// Cartão do cliente (nome curto antes da contratação, completo depois).
/// Respeita a Trava Temporal de Privacidade: a região vem do servidor
/// (`fetchLocationForViewer`) e, enquanto o endereço não é liberado, não existe
/// rua/número nem atalho para mapa exato — apenas Bairro • Cidade-UF.
class ClientCardTile extends StatefulWidget {
  const ClientCardTile({super.key, required this.jobId});

  final String jobId;

  @override
  State<ClientCardTile> createState() => _ClientCardTileState();
}

class _ClientCardTileState extends State<ClientCardTile> {
  // Futuro criado UMA vez: antes era recriado a cada rebuild (a cada tecla digitada no orçamento).
  late Future<Map<String, dynamic>?> _card = JobService().clientCard(widget.jobId);

  @override
  void didUpdateWidget(covariant ClientCardTile old) {
    super.didUpdateWidget(old);
    if (old.jobId != widget.jobId) _card = JobService().clientCard(widget.jobId);
  }

  String get jobId => widget.jobId;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return FutureBuilder<Map<String, dynamic>?>(
      future: _card,
      builder: (context, snap) {
        final name = (snap.data?['full_name'] as String?) ?? 'Cliente';
        return Row(
          children: [
            AppAvatar(url: snap.data?['avatar_url'] as String?, name: name, radius: 24),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppType.titleSm.copyWith(color: tk.text)),
                  ProviderLocationBuilder(
                    jobId: jobId,
                    builder: (context, view, loading) {
                      final unlocked = isExactLocationUnlocked(view);
                      return InkWell(
                        borderRadius: BorderRadius.circular(AppSpace.s8),
                        onTap: unlocked ? () => openProviderLocation(context, view!) : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                unlocked ? Icons.place_outlined : Icons.radar_rounded,
                                size: 16,
                                color: unlocked ? tk.accentInk : tk.warningInk,
                              ),
                              const SizedBox(width: AppSpace.s4),
                              Flexible(
                                child: Text(
                                  unlocked ? (view!.fullStreetLine ?? protectedAreaTitle(view)) : protectedAreaTitle(view),
                                  maxLines: 2,
                                  style: AppType.caption.copyWith(
                                    color: unlocked ? tk.accentInk : tk.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (unlocked) ...[
                                const SizedBox(width: AppSpace.s4),
                                Icon(Icons.map_outlined, size: 15, color: tk.accentInk),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (snap.data?['client_id'] is String) _ClientReputationChip(snap.data!['client_id'] as String),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Nota média do cliente (avaliações dos profissionais anteriores), quando houver.
class _ClientReputationChip extends StatelessWidget {
  const _ClientReputationChip(this.clientId);

  final String clientId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({double avg, int count})?>(
      future: ProviderService().clientReputation(clientId),
      builder: (context, snap) {
        final r = snap.data;
        if (r == null || r.count == 0) {
          return const Padding(
            padding: EdgeInsets.only(top: AppSpace.s4),
            child: AppStatusChip('Cliente novo', tone: AppTone.info, icon: Icons.fiber_new_rounded),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: AppSpace.s4),
          child: AppStatusChip(
            '${r.avg.toStringAsFixed(1).replaceAll('.', ',')} • ${r.count} avaliações do cliente',
            tone: AppTone.warning,
            icon: Icons.star_rounded,
          ),
        );
      },
    );
  }
}

Widget evidenceCarousel(BuildContext context, Job job) {
  final tk = context.tk;
  if (job.photoPaths.isEmpty) {
    return Text('O cliente não anexou fotos.', style: AppType.bodySm.copyWith(color: tk.textMuted));
  }
  return SizedBox(
    height: 150,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: job.photoPaths.length,
      separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s12),
      itemBuilder: (context, i) => AppPressable(
        borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
        onTap: () => Navigator.of(context).push(
          AppRoute<void>(
            fullscreenModal: true,
            builder: (_) => AppScaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                title: const Text('Foto enviada pelo cliente'),
              ),
              body: InteractiveViewer(
                maxScale: 5,
                child: Center(child: SignedImage(path: job.photoPaths[i], fit: BoxFit.contain, radius: 0)),
              ),
            ),
          ),
        ),
        child: SignedImage(path: job.photoPaths[i], width: 150, height: 150, radius: AppGeometry.fieldRadius),
      ),
    ),
  );
}

// ================================================================ orçamento (16)

class QuoteFormScreen extends StatefulWidget {
  const QuoteFormScreen({super.key, required this.job, this.invite});

  final Job job;
  final JobInvite? invite;

  @override
  State<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _QuoteFormScreenState extends State<QuoteFormScreen> {
  final _jobs = JobService();
  final _price = TextEditingController();
  final _hours = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  static const _feePct = 15.0; // 13,5% intermediação + 1,5% reserva de garantia 90d = 85% líquido

  @override
  void dispose() {
    _price.dispose();
    _hours.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _value => parseBrl(_price.text);

  bool get _inviteDead {
    if (!widget.job.isDirect) return false;
    final i = widget.invite;
    return i == null || !i.isLive;
  }

  Future<void> _send() async {
    final v = _value;
    if (v == null || v <= 0) {
      AppSnackbar.show(context, 'Informe o valor do orçamento.', kind: AppSnackKind.error);
      return;
    }
    setState(() => _busy = true);
    try {
      await _jobs.sendQuote(jobId: widget.job.id, price: v, message: _note.text, estimatedHours: parseBrl(_hours.text));
      // O stream de orçamentos troca esta tela pela de "Aguardando resposta".
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    final ok = await AppDialog.confirm(
      context,
      title: 'Recusar solicitação?',
      message: 'O cliente será avisado para tentar outro profissional.',
      confirmLabel: 'Recusar',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _jobs.declineInvite(widget.job.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    final job = widget.job;
    final v = _value ?? 0;
    final net = v - v * _feePct / 100;
    final full = job.quoteCount >= 3;
    final blocked = _inviteDead || full;
    return AppScaffold(
      appBar: const AppAppBar(title: 'Detalhes do chamado'),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s24),
        children: [
          if (widget.invite != null && widget.invite!.isLive)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s12),
              child: _InviteCountdown(invite: widget.invite!),
            ),
          if (_inviteDead) const InfoBanner('Este convite expirou ou não está mais disponível.', tone: BannerTone.warning),
          if (full && !_inviteDead) const InfoBanner('Este pedido já recebeu 3 orçamentos.', tone: BannerTone.warning),
          AppSection(
            title: 'Evidências enviadas pelo cliente',
            child: evidenceCarousel(context, job),
          ),
          const SizedBox(height: AppSpace.section),
          AppSection(
            title: 'Relato do cliente',
            child: AppCard(
              variant: AppCardVariant.tonal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClientCardTile(jobId: job.id),
                  const SizedBox(height: AppSpace.s12),
                  StructuredClientBriefView(description: job.description),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          ProviderLocationBuilder(
            jobId: job.id,
            builder: (context, view, loading) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (view == null)
                    ProviderLocationPending(loading: loading)
                  else
                    ProviderLocationPanel(view: view),
                  const SizedBox(height: AppSpace.s12),
                  Wrap(
                    spacing: AppSpace.s8,
                    runSpacing: AppSpace.s8,
                    children: [
                      AppStatusChip(job.category, tone: AppTone.accent),
                      if (job.scheduledFor != null)
                        AppStatusChip(dateShort(job.scheduledFor!), tone: AppTone.info, icon: Icons.calendar_month_rounded),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpace.s16),
          ValueListenableBuilder(
            valueListenable: JobTriageStore.instance,
            builder: (context, _, _) => ProviderTriageBriefCard(
              result: JobTriageStore.instance.resolveForJob(job),
            ),
          ),
          const SizedBox(height: AppSpace.s20),
          Text('Qual o seu orçamento para resolver isso?', style: AppType.headline.copyWith(color: tk.text)),
          const SizedBox(height: AppSpace.s12),
          TextField(
            controller: _price,
            enabled: !blocked,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppType.figure.copyWith(color: tk.text),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(prefixText: 'R\$ ', hintText: '150,00'),
          ),
          if (v > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s8),
              child: Text(
                'Comissão da plataforma (${_feePct.toStringAsFixed(0)}%): ${brl(v * _feePct / 100)} • Você recebe ${brl(net)}',
                textAlign: TextAlign.center,
                style: AppType.tabular(AppType.bodySm).copyWith(color: tk.textMuted),
              ),
            ),
          const SizedBox(height: AppSpace.s16),
          AppTextField(
            controller: _hours,
            enabled: !blocked,
            label: 'Tempo estimado em horas (opcional)',
            hint: 'Ex: 2',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpace.s16),
          Text('Observações (opcional)', style: AppType.titleSm.copyWith(color: tk.text)),
          const SizedBox(height: AppSpace.s8),
          AppTextField(
            controller: _note,
            enabled: !blocked,
            maxLines: 3,
            maxLength: 500,
            hint: 'Ex: Preço inclui a troca da peça, não inclui quebrar azulejo.',
          ),
          if (widget.invite != null && widget.invite!.isLive)
            Center(
              child: AppButton(
                label: 'Recusar solicitação',
                variant: AppButtonVariant.tertiary,
                expand: false,
                onPressed: _decline,
              ),
            ),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        child: AppButton(
          label: 'Enviar orçamento',
          trailingArrow: true,
          loading: _busy,
          onPressed: blocked ? null : _send,
        ),
      ),
    );
  }
}

class _InviteCountdown extends StatefulWidget {
  const _InviteCountdown({required this.invite});

  final JobInvite invite;

  @override
  State<_InviteCountdown> createState() => _InviteCountdownState();
}

class _InviteCountdownState extends State<_InviteCountdown> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InfoBanner(
        'Responda em ${clock(widget.invite.remaining)}. Depois disso o convite expira.',
        tone: BannerTone.info,
        icon: Icons.timer_outlined,
        title: 'Solicitação direta',
      );
}

// ============================================================ aguardando (17)

class AwaitingResponseScreen extends StatefulWidget {
  const AwaitingResponseScreen({super.key, required this.job, required this.quote});

  final Job job;
  final Quote quote;

  @override
  State<AwaitingResponseScreen> createState() => _AwaitingResponseScreenState();
}

class _AwaitingResponseScreenState extends State<AwaitingResponseScreen> {
  final _jobs = JobService();
  Timer? _t;
  JobInvite? _invite;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _jobs.invitesForJob(widget.job.id).then((l) {
      if (mounted && l.isNotEmpty) setState(() => _invite = l.first);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    final ok = await AppDialog.confirm(
      context,
      title: 'Cancelar proposta?',
      message: 'O cliente não verá mais o seu orçamento.',
      confirmLabel: 'Cancelar proposta',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _jobs.withdrawQuote(widget.job.id);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final inv = _invite;
    return AppScaffold(
      appBar: AppAppBar(
        leading: AppIconButton(
          icon: Icons.close_rounded,
          tooltip: 'Fechar',
          onPressed: () => Navigator.maybePop(context),
        ),
        title: 'Aguardando resposta',
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: context.layout.margin, vertical: AppSpace.s24),
        children: [
          const SizedBox(height: AppSpace.s8),
          Center(child: Icon(Icons.send_rounded, size: 64, color: tk.accentInk)),
          const SizedBox(height: AppSpace.s16),
          Text(
            'Orçamento de ${brl(widget.quote.price)} enviado!',
            textAlign: TextAlign.center,
            style: AppType.tabular(AppType.display).copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s12),
          Text(
            'Assim que o cliente aceitar, o valor fica retido na plataforma e você poderá ir até o local. Avisaremos por notificação.',
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: tk.textMuted),
          ),
          const SizedBox(height: AppSpace.s24),
          if (inv != null)
            Center(
              child: RepaintBoundary(
                child: CountdownRing(
                  remaining: inv.expiresAt.difference(DateTime.now()),
                  total: const Duration(hours: 2),
                  caption: 'prazo do convite',
                  icon: Icons.hourglass_bottom_rounded,
                ),
              ),
            )
          else
            const AppLoading(message: 'Aguardando retorno do cliente...'),
          const SizedBox(height: AppSpace.s20),
          Center(
            child: LinkButton(label: 'Cancelar proposta', onPressed: _cancel, color: tk.dangerInk),
          ),
        ],
      ),
    );
  }
}

// ================================================================ emergência

class EmergencyDecisionScreen extends StatefulWidget {
  const EmergencyDecisionScreen({super.key, required this.job, this.invite});

  final Job job;
  final JobInvite? invite;

  @override
  State<EmergencyDecisionScreen> createState() => _EmergencyDecisionScreenState();
}

class _EmergencyDecisionScreenState extends State<EmergencyDecisionScreen> {
  final _jobs = JobService();
  bool _busy = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await _jobs.acceptEmergency(widget.job.id);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    final ok = await AppDialog.confirm(
      context,
      title: 'Recusar emergência?',
      message: 'O cliente será avisado e a reserva dele estornada.',
      confirmLabel: 'Recusar',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _jobs.declineInvite(widget.job.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    final job = widget.job;
    final live = widget.invite?.isLive ?? false;
    return AppScaffold(
      appBar: const AppAppBar(title: 'Emergência'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s24),
        children: [
          Center(
            child: RepaintBoundary(
              child: CountdownRing(
                remaining: widget.invite?.remaining ?? Duration.zero,
                total: const Duration(minutes: 5),
                size: 140,
                caption: 'para aceitar',
                icon: Icons.bolt_rounded,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          const InfoBanner(
            'Se aceitar, vá imediatamente. A reserva de garantia do cliente já está em custódia.',
            tone: BannerTone.danger,
            title: 'Atendimento imediato',
          ),
          const SizedBox(height: AppSpace.section),
          AppSection(
            title: 'Evidências enviadas pelo cliente',
            child: evidenceCarousel(context, job),
          ),
          const SizedBox(height: AppSpace.section),
          AppSection(
            title: 'Relato',
            child: AppCard(
              variant: AppCardVariant.tonal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClientCardTile(jobId: job.id),
                  const SizedBox(height: AppSpace.s12),
                  StructuredClientBriefView(description: job.description),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          ProviderLocationBuilder(
            jobId: job.id,
            builder: (context, view, loading) =>
                view == null ? ProviderLocationPending(loading: loading) : ProviderLocationPanel(view: view),
          ),
          const SizedBox(height: AppSpace.s12),
          ValueListenableBuilder(
            valueListenable: JobTriageStore.instance,
            builder: (context, _, _) => ProviderTriageBriefCard(
              result: JobTriageStore.instance.resolveForJob(job),
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          AppCard(
            child: AppInfoRow(
              icon: Icons.lock_rounded,
              label: 'Reserva em custódia',
              valueWidget: Text(
                brl(job.agreedPrice),
                style: AppType.figureSm.copyWith(color: tk.successInk),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            'O orçamento final é combinado no local com o cliente.',
            style: AppType.bodySm.copyWith(color: tk.textMuted),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        secondary: AppButton(
          label: 'Recusar',
          variant: AppButtonVariant.tertiary,
          compact: true,
          onPressed: live ? _decline : null,
        ),
        child: AppButton(
          label: 'Aceitar emergência',
          icon: Icons.bolt_rounded,
          loading: _busy,
          onPressed: live ? _accept : null,
        ),
      ),
    );
  }
}

@visibleForTesting
class ProviderWaitingPaymentScreen extends StatelessWidget {
  const ProviderWaitingPaymentScreen({super.key, required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppScaffold(
      appBar: const AppAppBar(title: 'Orçamento aceito!'),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: context.layout.margin, vertical: AppSpace.s24),
        children: [
          const SizedBox(height: AppSpace.s20),
          Center(
            child: CircleAvatar(
              radius: 46,
              backgroundColor: tk.successSoft,
              child: Icon(Icons.handshake_rounded, size: 46, color: tk.successInk),
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          Text(
            'O cliente aceitou!',
            textAlign: TextAlign.center,
            style: AppType.display.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s12),
          Text(
            'Estamos aguardando o pagamento de ${brl(job.agreedPrice)}. Quando for confirmado, o valor fica em custódia e você será avisado para iniciar.',
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: tk.textMuted),
          ),
          const SizedBox(height: AppSpace.s24),
          const AppLoading(message: 'Aguardando confirmação do pagamento...'),
        ],
      ),
    );
  }
}

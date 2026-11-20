import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/fintech_warranty_models.dart';
import '../../../core/models/marketplace_models.dart';
import '../../../core/models/smart_triage_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/state/anti_bypass_fintech_controller.dart';
import '../../../core/state/smart_triage_controller.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../shared/presentation/chat_screen.dart';
import '../../shared/presentation/fintech_warranty_widgets.dart';
import '../../shared/presentation/smart_triage_widgets.dart';
import '../../shared/presentation/support_screens.dart';

/// "Acompanhe seu Pedido" (protótipos 16 e 05): timeline, endereço, PIN de
/// confirmação, evidências enviadas pelo profissional e contato.
class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({
    super.key,
    required this.job,
    @visibleForTesting this.fiscalDocsLoader,
  });

  final Job job;

  /// Carregador opcional de notas fiscais registradas no servidor (`job_fiscal_documents`).
  final Future<List<Map<String, dynamic>>> Function(String jobId)? fiscalDocsLoader;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late final _jobs = JobService();
  ProviderCard? _provider;
  String? _address;
  String? _reference;
  String? _pin;
  List<Map<String, dynamic>> _evidence = const [];
  List<MaterialReimbursementTicket> _serverMaterialTickets = const [];
  Timer? _poll;
  late SmartTriageResult _triage = JobTriageStore.instance.resolveForJob(widget.job);

  @override
  void initState() {
    super.initState();
    JobTriageStore.instance.addListener(_onTriageChanged);
    _loadStatic();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _loadEvidence());
  }

  @override
  void didUpdateWidget(covariant OrderTrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.job.id != widget.job.id ||
        oldWidget.fiscalDocsLoader != widget.fiscalDocsLoader) {
      _loadStatic();
    }
  }

  void _onTriageChanged() {
    if (!mounted) return;
    setState(() => _triage = JobTriageStore.instance.resolveForJob(widget.job));
  }

  void _toggleContainmentStep(int stepNumber) {
    final updated = JobTriageStore.instance.toggleContainmentStepForJob(widget.job, stepNumber);
    maybeProviderContainer(context)?.read(jobTriageRegistryProvider.notifier).saveForJob(widget.job.id, updated);
    if (mounted) setState(() => _triage = updated);
  }

  void _toggleMaterial(String materialId) {
    final updated = JobTriageStore.instance.toggleMaterialForJob(widget.job, materialId);
    maybeProviderContainer(context)?.read(jobTriageRegistryProvider.notifier).saveForJob(widget.job.id, updated);
    if (mounted) setState(() => _triage = updated);
  }

  @override
  void dispose() {
    JobTriageStore.instance.removeListener(_onTriageChanged);
    _poll?.cancel();
    super.dispose();
  }

  Future<List<MaterialReimbursementTicket>> _fetchServerFiscalDocuments(String jobId) async {
    try {
      final List<Map<String, dynamic>> rows;
      if (widget.fiscalDocsLoader != null) {
        rows = await widget.fiscalDocsLoader!(jobId);
      } else {
        final raw = await Supabase.instance.client
            .from('job_fiscal_documents')
            .select('id, fiscal_document_mode, emitter_cnpj, receipt_number, declared_material_amount, clawback_triggered, created_at')
            .eq('job_id', jobId)
            .order('created_at');
        rows = (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      final out = <MaterialReimbursementTicket>[];
      for (final row in rows) {
        if (row['clawback_triggered'] == true) continue;
        final amount = (row['declared_material_amount'] as num?)?.toDouble() ?? 0.0;
        if (amount <= 0) continue;
        final id = (row['id']?.toString() ?? '').trim();
        final mode = (row['fiscal_document_mode'] as String?) ?? 'NFCE_65';
        final modeLabel = mode == 'NFE_55' ? 'NF-e' : 'NFC-e';
        final receiptNum = (row['receipt_number']?.toString() ?? '').trim();
        final cnpj = (row['emitter_cnpj']?.toString() ?? '').trim();
        out.add(
          MaterialReimbursementTicket.validated(
            id: id.isEmpty ? 'srv-${out.length + 1}' : id,
            materialDescription: 'Material registrado (${widget.job.category})',
            storeName: cnpj.isNotEmpty ? 'Emitente CNPJ $cnpj' : 'Fornecedor registrado',
            fiscalReceiptNumber: receiptNum.isNotEmpty ? '$modeLabel $receiptNum' : modeLabel,
            receiptTotalAmount: amount,
            isApprovedByClient: false,
          ),
        );
      }
      return out;
    } catch (_) {
      return const <MaterialReimbursementTicket>[];
    }
  }

  Future<void> _loadStatic() async {
    final job = widget.job;
    final fiscalFuture = _fetchServerFiscalDocuments(job.id);
    try {
      final results = await Future.wait([
        job.providerId == null ? Future.value(null) : ProviderService().byId(job.providerId!),
        _jobs.jobAddress(job.id),
        _jobs.jobPin(job.id),
        _jobs.evidence(job.id),
      ]);
      if (!mounted) return;
      final addr = results[1] as Map<String, dynamic>?;
      var addressLine = (addr?['address_line'] as String?)?.trim();
      var reference = (addr?['reference'] as String?)?.trim();

      if (addressLine == null || addressLine.isEmpty) {
        try {
          final ownerLoc = await _jobs.fetchOwnerExactLocation(job.id);
          if (ownerLoc != null) {
            final full = ownerLoc.fullStreetLine?.trim();
            if (full != null && full.isNotEmpty) {
              addressLine = full;
            }
            if ((reference == null || reference.isEmpty) &&
                ownerLoc.reference != null &&
                ownerLoc.reference!.trim().isNotEmpty) {
              reference = ownerLoc.reference!.trim();
            }
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _provider = results[0] as ProviderCard?;
        _address = addressLine;
        _reference = reference;
        _pin = results[2] as String?;
        _evidence = results[3] as List<Map<String, dynamic>>;
      });
    } catch (_) {}
    final fiscalTickets = await fiscalFuture;
    if (mounted) {
      setState(() => _serverMaterialTickets = fiscalTickets);
    }
  }

  Future<void> _loadEvidence() async {
    try {
      final ev = await _jobs.evidence(widget.job.id);
      if (mounted) setState(() => _evidence = ev);
    } catch (_) {}
    final fiscalTickets = await _fetchServerFiscalDocuments(widget.job.id);
    if (mounted) {
      setState(() => _serverMaterialTickets = fiscalTickets);
    }
  }

  List<_Step> _steps(Job job) {
    final name = _provider == null ? 'O profissional' : firstName(_provider!.fullName);
    final executing = _evidence.isNotEmpty || job.status == JobStatus.awaitingApproval;
    final scheduledFuture = job.scheduledFor != null && job.scheduledFor!.isAfter(DateTime.now());
    return [
      _Step('Reserva confirmada', 'O pagamento de ${brl(job.agreedPrice)} foi aprovado e está em custódia.', _State.done, Icons.verified_rounded),
      if (job.scheduledFor != null)
        _Step('Compromisso agendado', dateLong(job.scheduledFor!), _State.done, Icons.calendar_month_rounded),
      if (job.isEmergency)
        _Step('Profissional a caminho', '$name aceitou e está se deslocando até você.', executing ? _State.done : _State.current, Icons.directions_car_rounded)
      else
        _Step(
          scheduledFuture ? 'Aguardando o dia do serviço' : 'Profissional a caminho / no local',
          '$name iniciará o atendimento na data e hora marcadas.',
          executing ? _State.done : _State.current,
          Icons.schedule_rounded,
        ),
      _Step('Serviço em execução', 'Acompanhe as fotos enviadas pelo profissional.', executing ? _State.current : _State.pending, Icons.handyman_rounded),
      _Step('Concluído', 'Você informa o código e o pagamento é liberado.', _State.pending, Icons.flag_rounded),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    final job = widget.job;
    final disputed = job.status == JobStatus.disputed;
    final steps = _steps(job);
    return AppScaffold(
      backgroundColor: tk.surface,
      appBar: AppAppBar(
        backgroundColor: tk.surface,
        leading: AppIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Voltar',
          onPressed: () => Navigator.maybePop(context),
        ),
        titleWidget: const BrandLogo(),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(layout.margin, AppSpace.s4, layout.margin, AppSpace.s24),
        children: [
          Semantics(
            header: true,
            child: Text(
              'Acompanhe seu Pedido',
              style: AppType.display.copyWith(color: tk.brand),
            ),
          ),
          const SizedBox(height: AppSpace.item),
          if (_triage.hasEmergencyContainment) ...[
            AppStaggerItem(
              index: 0,
              scope: 'order-tracking-${job.id}',
              child: EmergencyContainmentBanner(
                guide: _triage.containmentGuide!,
                onToggleStep: _toggleContainmentStep,
              ),
            ),
            const SizedBox(height: AppSpace.item),
          ],
          if (disputed) ...[
            const InfoBanner(
              'Abrimos um chamado e nossa equipe está analisando. O pagamento permanece retido até a decisão.',
              tone: BannerTone.warning,
              title: 'Em mediação',
              icon: Icons.gavel_rounded,
            ),
            const SizedBox(height: AppSpace.item),
          ],
          AppStaggerItem(
            index: 1,
            scope: 'order-tracking-${job.id}',
            child: AppCard(
              variant: AppCardVariant.elevated,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (job.isEmergency)
                    const AppStatusChip(
                      'EMERGÊNCIA ATIVA',
                      tone: AppTone.danger,
                      icon: Icons.emergency_rounded,
                    )
                  else
                    const AppStatusChip(
                      'AGENDAMENTO CONFIRMADO',
                      tone: AppTone.info,
                      icon: Icons.event_available_rounded,
                    ),
                  const SizedBox(height: AppSpace.s8),
                  AppInfoRow(
                    label: 'Código do pedido',
                    value: job.code,
                    icon: Icons.tag_rounded,
                    strong: true,
                  ),
                  if (job.agreedPrice != null)
                    AppInfoRow(
                      label: 'Valor em custódia',
                      icon: Icons.shield_outlined,
                      valueWidget: AppPrice(
                        value: job.agreedPrice!,
                        size: AppPriceSize.sm,
                        color: tk.text,
                      ),
                    ),
                  const SizedBox(height: AppSpace.s12),
                  for (final s in steps) _TimelineTile(step: s, last: s == steps.last),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.item),
          AppStaggerItem(
            index: 2,
            scope: 'order-tracking-${job.id}',
            child: AppCard(
              key: const ValueKey('client-readonly-address-card'),
              variant: AppCardVariant.outlined,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: tk.accentSoft,
                    child: Icon(Icons.place_rounded, color: tk.accentInk),
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _address ?? job.addressSummary ?? '—',
                          style: AppType.bodyStrong.copyWith(color: tk.text),
                        ),
                        if (_reference != null && _reference!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpace.s4),
                            child: Text(
                              'Ref: $_reference',
                              style: AppType.bodySm.copyWith(color: tk.textMuted),
                            ),
                          ),
                        const SizedBox(height: AppSpace.s4),
                        Text(
                          'Endereço registrado para o atendimento',
                          style: AppType.caption.copyWith(color: tk.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.item),
          AppStaggerItem(
            index: 3,
            scope: 'order-tracking-${job.id}',
            child: SmartTriageCard(
              result: _triage,
              selectedCategory: job.category,
              onToggleMaterial: _toggleMaterial,
            ),
          ),
          const SizedBox(height: AppSpace.item),
          ValueListenableBuilder(
            valueListenable: FintechLedgerStore.instance,
            builder: (context, _, _) {
              final rawDossier = FintechLedgerStore.instance.resolveForJob(
                job,
                addressOverride: _address ?? job.addressSummary,
              );
              final realInSessionTickets = rawDossier.reimbursedMaterials
                  .where(
                    (m) =>
                        m.id != 'mat-1-${job.id}' &&
                        (m.receiptPhoto == null ||
                            m.receiptPhoto!.imagePathOrUrl.startsWith('evidence/')),
                  )
                  .toList();
              final mergedMaterials = <MaterialReimbursementTicket>[
                ..._serverMaterialTickets,
                for (final t in realInSessionTickets)
                  if (!_serverMaterialTickets.any(
                    (s) => s.fiscalReceiptNumber == t.fiscalReceiptNumber,
                  ))
                    t,
              ];
              final dossier = rawDossier.copyWith(
                reimbursedMaterials: mergedMaterials,
              );
              return Column(
                children: [
                  SmartSplitTransparencyCard(
                    dossier: dossier,
                    onToggleMaterialApproval: (ticketId) {
                      if (_serverMaterialTickets.any((m) => m.id == ticketId)) {
                        setState(() {
                          _serverMaterialTickets = _serverMaterialTickets
                              .map(
                                (m) => m.id == ticketId
                                    ? m.copyWith(isApprovedByClient: !m.isApprovedByClient)
                                    : m,
                              )
                              .toList();
                        });
                      }
                      FintechLedgerStore.instance.toggleMaterialReceiptApproval(
                        orderId: job.id,
                        ticketId: ticketId,
                      );
                    },
                  ),
                  const SizedBox(height: AppSpace.item),
                  ForensicCheckInOutCard(
                    dossier: dossier,
                    onOpenThreeLayerWarranty: () =>
                        WarrantyThreeLayerResolutionSheet.show(context, orderId: job.id),
                  ),
                ],
              );
            },
          ),
          if (job.status == JobStatus.inProgress && _pin != null) ...[
            const SizedBox(height: AppSpace.item),
            _PinCard(pin: _pin!),
          ],
          Builder(
            builder: (context) {
              final photos = _evidence.where((e) => e['slot'] != 'video').toList();
              if (photos.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: AppSpace.section),
                child: AppSection(
                  title: 'Fotos do serviço',
                  child: AppCard(
                    variant: AppCardVariant.outlined,
                    child: SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s12),
                        itemBuilder: (_, i) => SignedImage(
                          path: photos[i]['path'] as String,
                          width: 96,
                          height: 96,
                          radius: AppGeometry.fieldRadius,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (_provider != null) ...[
            const SizedBox(height: AppSpace.section),
            AppSection(
              title: 'Profissional',
              child: AppCard(
                variant: AppCardVariant.elevated,
                child: Column(
                  children: [
                    Row(
                      children: [
                        AppHero(
                          tag: 'provider-avatar-${_provider!.id}',
                          child: AppAvatar(
                            url: _provider!.avatarUrl,
                            name: _provider!.fullName,
                            radius: 28,
                            verified: true,
                          ),
                        ),
                        const SizedBox(width: AppSpace.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _provider!.fullName,
                                style: AppType.titleSm.copyWith(color: tk.text),
                              ),
                              Text(
                                _provider!.title,
                                style: AppType.bodySm.copyWith(color: tk.textMuted),
                              ),
                              if (_provider!.ratingCount > 0) ...[
                                const SizedBox(height: AppSpace.s4),
                                AppRating(
                                  value: _provider!.ratingAvg,
                                  count: _provider!.ratingCount,
                                  showValue: true,
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s16),
                    if (layout.isLargeText || layout.isCompact)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppButton(
                            label: 'Abrir chat',
                            icon: Icons.chat_bubble_outline_rounded,
                            variant: AppButtonVariant.secondary,
                            compact: true,
                            onPressed: () => Navigator.of(context).push(
                              AppRoute(
                                builder: (_) => ChatScreen(
                                  job: job,
                                  providerId: _provider!.id,
                                  peerName: _provider!.fullName,
                                  peerAvatar: _provider!.avatarUrl,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpace.s8),
                          AppButton(
                            label: 'Ligar',
                            icon: Icons.phone_rounded,
                            variant: AppButtonVariant.primary,
                            compact: true,
                            onPressed: () => AppSnackbar.show(
                              context,
                              'Chamadas pelo app chegam em breve. Use o chat.',
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Abrir chat',
                              icon: Icons.chat_bubble_outline_rounded,
                              variant: AppButtonVariant.secondary,
                              compact: true,
                              onPressed: () => Navigator.of(context).push(
                                AppRoute(
                                  builder: (_) => ChatScreen(
                                    job: job,
                                    providerId: _provider!.id,
                                    peerName: _provider!.fullName,
                                    peerAvatar: _provider!.avatarUrl,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpace.s12),
                          Expanded(
                            child: AppButton(
                              label: 'Ligar',
                              icon: Icons.phone_rounded,
                              variant: AppButtonVariant.primary,
                              compact: true,
                              onPressed: () => AppSnackbar.show(
                                context,
                                'Chamadas pelo app chegam em breve. Use o chat.',
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.help_outline_rounded, color: tk.textMuted),
                const SizedBox(width: AppSpace.s8),
                Text(
                  'Preciso de ajuda?',
                  style: AppType.bodyStrong.copyWith(color: tk.text),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                AppRoute(
                  builder: (_) => ReportProblemScreen(job: job, asProvider: false),
                ),
              ),
              style: TextButton.styleFrom(
                minimumSize: const Size(AppGeometry.minTarget, AppGeometry.minTarget),
                foregroundColor: tk.dangerInk,
              ),
              child: Text(
                'Relatar problema',
                style: AppType.bodyStrong.copyWith(color: tk.dangerInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _State { done, current, pending }

class _Step {
  const _Step(this.title, this.subtitle, this.state, this.icon);
  final String title;
  final String subtitle;
  final _State state;
  final IconData icon;
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.step, required this.last});

  final _Step step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final color = switch (step.state) {
      _State.done => tk.providerAccentInk,
      _State.current => tk.accentInk,
      _State.pending => tk.border,
    };
    final lineColor = switch (step.state) {
      _State.done => tk.providerAccent,
      _State.current => tk.accent,
      _State.pending => tk.border,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: step.state == _State.pending
                    ? tk.surface
                    : lineColor.withValues(alpha: 0.14),
                child: Icon(
                  step.state == _State.done ? Icons.check_rounded : step.icon,
                  size: 16,
                  color: step.state == _State.pending ? tk.textMuted : color,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    color: lineColor.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: AppType.bodyStrong.copyWith(
                      color: step.state == _State.pending ? tk.textMuted : tk.text,
                    ),
                  ),
                  const SizedBox(height: AppSpace.s2),
                  Text(
                    step.subtitle,
                    style: AppType.bodySm.copyWith(color: tk.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinCard extends StatelessWidget {
  const _PinCard({required this.pin});

  final String pin;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      variant: AppCardVariant.tonal,
      color: tk.securitySoft,
      borderColor: tk.security.withValues(alpha: 0.5),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.lock_rounded, color: tk.security),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  'Código de confirmação',
                  style: AppType.titleSm.copyWith(color: tk.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              for (final d in pin.split(''))
                Container(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 58),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s12,
                    vertical: AppSpace.s8,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tk.card,
                    borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
                    border: Border.all(color: tk.border),
                  ),
                  child: Text(
                    d,
                    style: AppType.tabular(AppType.display).copyWith(color: tk.brand),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Text(
            'Informe este código ao profissional SOMENTE quando o serviço estiver concluído e aprovado por você. Ao digitá-lo, o pagamento é liberado.',
            textAlign: TextAlign.center,
            style: AppType.bodySm.copyWith(color: tk.text),
          ),
        ],
      ),
    );
  }
}

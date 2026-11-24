import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/achievements.dart';
import '../../../core/models/fintech_warranty_models.dart' show ForensicStage;
import '../../../core/models/marketplace_models.dart';
import '../../../core/security/geo_privacy_policy_engine.dart' show ProviderLocationView;
import '../../../core/services/job_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/services/social_service.dart';
import '../../../core/state/anti_bypass_fintech_controller.dart';
import '../../../core/state/provider_portfolio_controller.dart';
import '../../../core/state/smart_triage_controller.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/image_picking.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/structured_voice_brief.dart';
import '../../../services/forensic_photo_service.dart';
import '../../shared/presentation/achievement_widgets.dart';
import '../../shared/presentation/chat_screen.dart';
import '../../shared/presentation/fintech_warranty_widgets.dart';
import '../../shared/presentation/geo_privacy_widgets.dart';
import '../../shared/presentation/review_thanks_view.dart';
import '../../shared/presentation/review_widgets.dart';
import '../../shared/presentation/smart_triage_widgets.dart';
import '../../shared/presentation/support_screens.dart';
import 'material_receipt_capture_screen.dart';

/// Volta até a tela raiz do serviço (ProviderJobScreen) que reage ao stream.
void _backToJob(BuildContext context) {
  Navigator.of(context).popUntil((r) => r.settings.name == 'provider_job' || r.isFirst);
}

// ================================================================ execução (1)

class ServiceExecutionScreen extends StatefulWidget {
  const ServiceExecutionScreen({
    super.key,
    required this.job,
    this.myId,
    this.jobService,
    this.forensicService,
  });

  final Job job;

  /// Ganchos opcionais para testes (padrão `null`, zero impacto em produção).
  final String? myId;
  final JobService? jobService;
  final ForensicPhotoService? forensicService;

  @override
  State<ServiceExecutionScreen> createState() => _ServiceExecutionScreenState();
}

class _ServiceExecutionScreenState extends State<ServiceExecutionScreen> {
  JobService? _jobsOrNull;
  JobService get _jobs => _jobsOrNull ??= widget.jobService ?? JobService();
  ForensicPhotoService? _forensicOrNull;
  ForensicPhotoService get _forensic => _forensicOrNull ??= widget.forensicService ?? ForensicPhotoService();
  Map<String, dynamic>? _client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await _jobs.clientCard(widget.job.id);
      if (!mounted) return;
      setState(() => _client = c);
    } catch (_) {}
  }

  bool _forensicBusy = false;

  /// Nota fiscal REAL dos materiais: o dossiê só recebe o que o servidor confirmou.
  Future<void> _addMaterialReceipt() async {
    final job = widget.job;
    final r = await Navigator.of(context).push<MaterialReceiptResult>(
      AppRoute(builder: (_) => MaterialReceiptCaptureScreen(jobId: job.id)),
    );
    if (r == null || !mounted) return;
    FintechLedgerStore.instance.addMaterialReceipt(
      orderId: job.id,
      materialDescription: 'Materiais do serviço (${job.category})',
      storeName: 'CNPJ ${r.info.formattedCnpj}',
      fiscalReceiptNumber: r.info.label,
      receiptTotalAmount: r.amount,
      approvedByClient: false,
      receiptStoragePath: r.outcome.photoPath,
      realCapture: (lat: null, lng: null, gpsVerified: false),
    );
    AppSnackbar.show(context, r.outcome.message, kind: AppSnackKind.success);
  }

  /// Foto REAL de check-in/check-out (câmera ao vivo, no local, EXIF removido, cofre privado).
  Future<void> _captureForensic(ForensicStage stage, ProviderLocationView? view) async {
    if (_forensicBusy) return;
    setState(() => _forensicBusy = true);
    try {
      final o = await _forensic.captureAndRegister(jobId: widget.job.id, stage: stage, view: view);
      if (!mounted) return;
      if (o.stored) {
        final isIn = stage == ForensicStage.beforeCheckIn;
        final note = isIn ? 'Foto Antes (check-in) registrada no local.' : 'Foto Depois (check-out) registrada no local.';
        if (isIn) {
          FintechLedgerStore.instance.addCheckInPhoto(
            orderId: widget.job.id,
            imagePathOrUrl: o.storagePath!,
            captionOrTechnicalNote: note,
            latitude: o.latitude,
            longitude: o.longitude,
            isGpsVerifiedAtAddress: true,
          );
        } else {
          FintechLedgerStore.instance.addCheckOutPhoto(
            orderId: widget.job.id,
            imagePathOrUrl: o.storagePath!,
            captionOrTechnicalNote: note,
            latitude: o.latitude,
            longitude: o.longitude,
            isGpsVerifiedAtAddress: true,
          );
        }
      }
      if (o.state != ForensicCaptureState.cancelled) {
        AppSnackbar.show(context, o.message, kind: o.stored ? AppSnackKind.success : AppSnackKind.error);
      }
    } finally {
      if (mounted) setState(() => _forensicBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    final job = widget.job;
    final price = job.agreedPrice ?? 0;
    final net = price - price * 0.15;
    final clientName = (_client?['full_name'] as String?) ?? 'Cliente';
    final me = widget.myId ?? Supabase.instance.client.auth.currentUser?.id ?? '';
    return AppScaffold(
      appBar: AppAppBar(
        leading: AppIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Voltar',
          size: 20,
          onPressed: () => Navigator.maybePop(context),
        ),
        titleWidget: const BrandLogo(),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s24),
        children: [
          AppCard(
            variant: AppCardVariant.tonal,
            color: tk.successSoft,
            borderColor: tk.success,
            child: Row(
              children: [
                Icon(Icons.lock_rounded, color: tk.successInk),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pagamento retido e garantido: ${brl(price)}',
                        style: AppType.tabular(AppType.bodyStrong).copyWith(color: tk.successInk),
                      ),
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        'Você recebe ${brl(net)} após a confirmação.',
                        style: AppType.tabular(AppType.bodySm).copyWith(color: tk.successInk),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s24),
          Center(child: _ElapsedClock(since: job.startedAt ?? job.paidAt)),
          const SizedBox(height: AppSpace.s8),
          const Center(
            child: AppStatusChip(
              'Serviço em execução...',
              tone: AppTone.accent,
              icon: Icons.radio_button_checked_rounded,
            ),
          ),
          const SizedBox(height: AppSpace.s20),
          AppCard(
            variant: AppCardVariant.elevated,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppAvatar(url: _client?['avatar_url'] as String?, name: clientName, radius: 24),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cliente: $clientName', style: AppType.titleSm.copyWith(color: tk.text)),
                          Text(job.title, style: AppType.bodySm.copyWith(color: tk.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (StructuredVoiceBrief.tryParseStructuredText(job.description) != null) ...[
                  const SizedBox(height: AppSpace.s12),
                  StructuredClientBriefView(description: job.description),
                ],
                const SizedBox(height: AppSpace.s12),
                ProviderLocationBuilder(
                  jobId: job.id,
                  builder: (context, view, loading) =>
                      view == null ? ProviderLocationPending(loading: loading) : ProviderLocationPanel(view: view),
                ),
                if (job.scheduledFor != null) ...[
                  const SizedBox(height: AppSpace.s12),
                  Text('Agendado: ${dateLong(job.scheduledFor!)}', style: AppType.bodySm.copyWith(color: tk.textMuted)),
                ],
                const SizedBox(height: AppSpace.s12),
                AppButton(
                  label: 'Chat com o cliente',
                  variant: AppButtonVariant.secondary,
                  compact: true,
                  expand: false,
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed: () => Navigator.of(context).push(
                    AppRoute(
                      builder: (_) => ChatScreen(
                        job: job,
                        providerId: me,
                        peerName: clientName,
                        peerAvatar: _client?['avatar_url'] as String?,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          ValueListenableBuilder(
            valueListenable: JobTriageStore.instance,
            builder: (context, _, _) => ProviderTriageBriefCard(
              result: JobTriageStore.instance.resolveForJob(job),
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          ProviderLocationBuilder(
            jobId: job.id,
            builder: (context, locView, _) => ValueListenableBuilder(
              valueListenable: FintechLedgerStore.instance,
              builder: (context, _, _) {
                // Nunca usa `job.addressSummary` (pode conter rua): só o endereço liberado pelo
                // servidor ou, antes disso, Bairro • Cidade-UF.
                final dossier = FintechLedgerStore.instance.resolveForJob(
                  job,
                  addressOverride: locView != null && locView.exactUnlocked
                      ? exactAddressLineOf(locView)
                      : protectedAreaTitle(locView),
                );
                return Column(
                  children: [
                    SmartSplitTransparencyCard(
                      dossier: dossier,
                      isProviderView: true,
                      onAddMaterialReceipt: _addMaterialReceipt,
                    ),
                    const SizedBox(height: AppSpace.s12),
                    ForensicCheckInOutCard(
                      dossier: dossier,
                      isProviderView: true,
                      onAddCheckInPhoto: _forensicBusy ? null : () => _captureForensic(ForensicStage.beforeCheckIn, locView),
                      onAddCheckOutPhoto: _forensicBusy ? null : () => _captureForensic(ForensicStage.afterCheckOut, locView),
                      onOpenThreeLayerWarranty: () =>
                          WarrantyThreeLayerResolutionSheet.show(context, orderId: job.id),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        child: AppButton(
          label: 'Finalizar serviço',
          trailingArrow: true,
          onPressed: () => Navigator.of(context).push(AppRoute(builder: (_) => WarrantyIntroScreen(job: job))),
        ),
      ),
    );
  }
}

// ===================================================== garantia e portfólio (2)

/// Cronômetro do serviço em execução. É DERIVADO do `started_at` gravado pelo servidor (não de
/// um Stopwatch local): sobrevive a fechar o app. Tem o próprio temporizador de 1 s e fica numa
/// camada de pintura separada, para a tela inteira (cards financeiros etc.) não reconstruir todo segundo.
class _ElapsedClock extends StatefulWidget {
  const _ElapsedClock({required this.since});

  final DateTime? since;

  @override
  State<_ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<_ElapsedClock> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Duration get _elapsed {
    final since = widget.since;
    if (since == null) return Duration.zero;
    final d = DateTime.now().difference(since);
    return d.isNegative ? Duration.zero : d;
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return RepaintBoundary(
      child: Semantics(
        label: 'Tempo de serviço',
        child: Text(
          clockHms(_elapsed),
          key: const ValueKey('service-elapsed-clock'),
          textAlign: TextAlign.center,
          style: AppType.figureXl.copyWith(color: tk.accentInk),
        ),
      ),
    );
  }
}

class WarrantyIntroScreen extends StatelessWidget {
  const WarrantyIntroScreen({super.key, required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppScaffold(
      appBar: const AppAppBar(title: 'Garantia e Portfólio'),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: context.layout.margin, vertical: AppSpace.s24),
        children: [
          const SizedBox(height: AppSpace.s8),
          Center(
            child: CircleAvatar(
              radius: 70,
              backgroundColor: tk.providerSoft,
              child: Icon(Icons.emoji_events_rounded, size: 72, color: tk.star),
            ),
          ),
          const SizedBox(height: AppSpace.s24),
          Text(
            'Mostre o seu talento para o mundo!',
            textAlign: TextAlign.center,
            style: AppType.display.copyWith(color: tk.accentInk),
          ),
          const SizedBox(height: AppSpace.s16),
          Text(
            'As próximas 4 fotos garantem a finalização do serviço e ficam salvas como prova para o cliente e para a sua proteção. Mostre o seu trabalho e feche ainda mais clientes!',
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s20),
          const InfoBanner(
            'Acenda as luzes, limpe a lente e mostre o antes/depois.',
            tone: BannerTone.info,
            icon: Icons.lightbulb_outline_rounded,
            title: 'Dica',
          ),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        child: AppButton(
          label: 'Tirar fotos',
          icon: Icons.photo_camera_rounded,
          trailingArrow: true,
          onPressed: () => Navigator.of(context).push(AppRoute(builder: (_) => EvidenceChecklistScreen(job: job))),
        ),
      ),
    );
  }
}

// ====================================================== evidências (3, 4 e 5)

class EvidenceChecklistScreen extends StatefulWidget {
  const EvidenceChecklistScreen({super.key, required this.job});

  final Job job;

  @override
  State<EvidenceChecklistScreen> createState() => _EvidenceChecklistScreenState();
}

class _EvidenceChecklistScreenState extends State<EvidenceChecklistScreen> {
  final _jobs = JobService();
  Map<String, Map<String, dynamic>> _items = {};
  String? _busySlot;
  bool _loading = true;

  // Extras opcionais que alimentam o Case de Sucesso (vitrine pública).
  final _report = TextEditingController();
  String _savedReport = '';
  bool _videoBusy = false;
  bool _reportLoaded = false;

  @override
  void dispose() {
    _report.dispose();
    super.dispose();
  }

  static const _slots = [
    ('overview', 'Visão Geral', 'Mostre todo o ambiente de trabalho.'),
    ('detail', 'Detalhes da Peça', 'Aproxime e mostre o que foi feito ou trocado.'),
    ('angle', 'Outro Ângulo', 'Registre por outro ângulo.'),
    ('clean', 'Ambiente Limpo', 'Mostre o local limpo e organizado.'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ev = await _jobs.evidence(widget.job.id);
      final saved = _reportLoaded ? null : await _jobs.jobReport(widget.job.id);
      if (!mounted) return;
      setState(() {
        _items = {for (final e in ev) e['slot'] as String: e};
        if (!_reportLoaded) {
          _reportLoaded = true;
          _savedReport = saved ?? '';
          _report.text = _savedReport;
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _capture(String slot, String label, String hint) async {
    final img = await pickImage(context);
    if (img == null || !mounted) return;
    setState(() => _busySlot = slot);
    try {
      await _jobs.addEvidence(jobId: widget.job.id, slot: slot, bytes: img.bytes, ext: img.ext);
      await _load();
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _busySlot = null);
    }
  }

  /// Vídeo curto do serviço (opcional, até 30 s / 25 MB): aparece no Case de Sucesso.
  Future<void> _pickVideo() async {
    final source = await AppSheet.show<ImageSource>(
      context,
      title: 'Adicionar vídeo do serviço',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppListTile(
            leadingIcon: Icons.videocam_rounded,
            title: 'Gravar agora (até 30 s)',
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          AppListTile(
            leadingIcon: Icons.video_library_rounded,
            title: 'Escolher da galeria',
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _videoBusy = true);
    try {
      final x = await ImagePicker().pickVideo(source: source, maxDuration: const Duration(seconds: 30));
      if (x == null) return;
      if (await x.length() > 25 * 1024 * 1024) {
        if (mounted) {
          AppSnackbar.show(context, 'O vídeo passa de 25 MB. Grave um trecho mais curto.', kind: AppSnackKind.error);
        }
        return;
      }
      final name = x.name.toLowerCase();
      final ext = name.endsWith('.mov') ? 'mov' : 'mp4';
      await _jobs.addEvidence(jobId: widget.job.id, slot: 'video', bytes: await x.readAsBytes(), ext: ext);
      await _load();
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _videoBusy = false);
    }
  }

  /// Salva o relatório técnico (se mudou) e segue para liberar o pagamento.
  Future<void> _continue() async {
    final text = _report.text.trim();
    if (text != _savedReport.trim()) {
      try {
        await ProviderService().setJobReport(widget.job.id, text);
        _savedReport = text;
      } catch (e) {
        if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
        return;
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(AppRoute(builder: (_) => ReleasePaymentScreen(job: widget.job)));
  }

  Future<void> _remove(String slot) async {
    final id = _items[slot]?['id'] as String?;
    if (id == null) return;
    try {
      await _jobs.removeEvidence(id);
      await _load();
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    final count = _slots.where((s) => _items.containsKey(s.$1)).length;
    final done = count == 4;
    return AppScaffold(
      appBar: const AppAppBar(title: 'Evidências do serviço'),
      body: AppSkeletonSwitcher(
        loading: _loading,
        skeleton: const AppSkeletonList(count: 4),
        child: ListView(
          padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s24),
          children: [
            Text('Capture as 4 fotos obrigatórias', style: AppType.headline.copyWith(color: tk.accentInk)),
            const SizedBox(height: AppSpace.s8),
            Row(
              children: [
                if (done) ...[
                  Icon(Icons.check_circle_rounded, size: 18, color: tk.successInk),
                  const SizedBox(width: AppSpace.s8),
                ],
                Flexible(
                  child: Text(
                    'Fotos obrigatórias ($count/4)',
                    style: AppType.tabular(AppType.bodyStrong).copyWith(color: done ? tk.successInk : tk.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: context.layout.isLargeText ? 0.78 : 1.0,
              mainAxisSpacing: AppSpace.s12,
              crossAxisSpacing: AppSpace.s12,
              children: [
                for (final (slot, label, hint) in _slots)
                  _SlotCard(
                    label: label,
                    path: _items[slot]?['path'] as String?,
                    busy: _busySlot == slot,
                    onTap: () => _capture(slot, label, hint),
                    onDelete: _items.containsKey(slot) ? () => _remove(slot) : null,
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s16),
            const InfoBanner(
              'As fotos ficam salvas no pedido: protegem você e o cliente em caso de qualquer dúvida.',
              tone: BannerTone.security,
            ),
            const SizedBox(height: AppSpace.section),
            AppSection(
              title: 'Vídeo do serviço (opcional)',
              child: AppCard(
                onTap: _videoBusy ? null : _pickVideo,
                child: Row(
                  children: [
                    Icon(
                      _items.containsKey('video') ? Icons.check_circle_rounded : Icons.videocam_outlined,
                      color: _items.containsKey('video') ? tk.successInk : tk.accentInk,
                    ),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(
                      child: Text(
                        _items.containsKey('video')
                            ? 'Vídeo anexado. Toque para trocar.'
                            : 'Grave um vídeo curto do serviço pronto (até 30 s). Ele aparece no seu Case de Sucesso.',
                        style: AppType.bodySm.copyWith(color: tk.text),
                      ),
                    ),
                    if (_videoBusy)
                      const SizedBox(width: 28, height: 28, child: AppLoading())
                    else if (_items.containsKey('video'))
                      AppIconButton(
                        tooltip: 'Remover vídeo',
                        icon: Icons.delete_outline_rounded,
                        color: tk.dangerInk,
                        onPressed: () => _remove('video'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.section),
            AppSection(
              title: 'Relatório técnico (opcional)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    controller: _report,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    hint: 'O que você encontrou, o que fez e o que foi trocado. Ex.: Troquei o disjuntor de 20A por um DR de 25A e reapertei o quadro.',
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    'Aparece para os clientes no seu Case de Sucesso e ajuda a fechar mais serviços.',
                    style: AppType.caption.copyWith(color: tk.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomBar(
        child: AppButton(
          label: 'Continuar para liberar pagamento',
          trailingArrow: true,
          onPressed: done ? _continue : null,
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.label, required this.path, required this.busy, required this.onTap, this.onDelete});

  final String label;
  final String? path;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    if (path == null) {
      return AppPressable(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(AppGeometry.cardRadius),
        child: Container(
          decoration: BoxDecoration(
            color: tk.surface,
            borderRadius: BorderRadius.circular(AppGeometry.cardRadius),
            border: Border.all(color: tk.border, width: 1.5),
          ),
          child: Center(
            child: busy
                ? const AppLoading()
                : Padding(
                    padding: const EdgeInsets.all(AppSpace.s12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_camera_outlined, size: 32, color: tk.textMuted),
                        const SizedBox(height: AppSpace.s8),
                        Text(label, textAlign: TextAlign.center, style: AppType.bodyStrong.copyWith(color: tk.text)),
                        const SizedBox(height: AppSpace.s4),
                        Icon(Icons.add_rounded, size: 22, color: tk.accentInk),
                      ],
                    ),
                  ),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        SignedImage(path: path!, radius: AppGeometry.cardRadius),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(AppSpace.s8),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppGeometry.cardRadius)),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.72), Colors.transparent],
              ),
            ),
            child: Text(label, style: AppType.bodyStrong.copyWith(color: Colors.white)),
          ),
        ),
        Positioned(
          left: AppSpace.s8,
          top: AppSpace.s8,
          child: CircleAvatar(
            radius: 13,
            backgroundColor: tk.success,
            child: Icon(Icons.check_rounded, size: 16, color: AppTokens.onColor(tk.success)),
          ),
        ),
        if (onDelete != null)
          Positioned(
            right: AppSpace.s4,
            top: AppSpace.s4,
            child: Material(
              color: tk.card.withValues(alpha: 0.92),
              shape: const CircleBorder(),
              child: AppIconButton(
                tooltip: 'Remover foto',
                icon: Icons.delete_outline_rounded,
                size: 18,
                color: tk.dangerInk,
                onPressed: onDelete,
              ),
            ),
          ),
      ],
    );
  }
}

// ==================================================== liberar pagamento (PIN, 7)

class ReleasePaymentScreen extends StatefulWidget {
  const ReleasePaymentScreen({super.key, required this.job});

  final Job job;

  @override
  State<ReleasePaymentScreen> createState() => _ReleasePaymentScreenState();
}

class _ReleasePaymentScreenState extends State<ReleasePaymentScreen> {
  final _jobs = JobService();
  String _pin = '';
  bool _busy = false;
  String? _error;
  String _clientName = 'o cliente';

  @override
  void initState() {
    super.initState();
    _jobs.clientCard(widget.job.id).then((c) {
      final n = c?['full_name'] as String?;
      if (mounted && n != null) setState(() => _clientName = firstName(n));
    }).catchError((_) {});
  }

  Future<void> _press(String d) async {
    if (_busy || _pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) await _submit();
  }

  void _back() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await _jobs.completeWithPin(widget.job.id, _pin);
      // Registra imediatamente a conclusão via PIN do cliente no Meu Portfólio (#1)
      // e no Histórico Permanente de Serviços Prestados.
      ProviderPortfolioStore.instance.completeJobWithPin(
        job: widget.job,
        validatedClientPin: _pin,
        clientDisplayName: _clientName,
      );
      if (mounted) _backToJob(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _pin = '';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppScaffold(
      appBar: const AppAppBar(title: 'Liberar pagamento'),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(context.layout.margin, AppSpace.s8, context.layout.margin, AppSpace.s8),
              children: [
                Text(
                  'Insira o código de liberação',
                  textAlign: TextAlign.center,
                  style: AppType.display.copyWith(color: tk.accentInk),
                ),
                const SizedBox(height: AppSpace.s8),
                Text(
                  'Peça a $_clientName o PIN de 4 dígitos para validar a transação.',
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: tk.textMuted),
                ),
                const SizedBox(height: AppSpace.s24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 4; i++)
                      Container(
                        width: 56,
                        height: 64,
                        margin: const EdgeInsets.symmetric(horizontal: AppSpace.s4 + 2),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tk.surfaceInset,
                          borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
                          border: Border.all(
                            color: _error != null
                                ? tk.dangerInk
                                : (i == _pin.length ? tk.accentInk : tk.border),
                            width: i == _pin.length ? 2 : 1.2,
                          ),
                        ),
                        child: Text(
                          i < _pin.length ? '•' : '',
                          style: AppType.displayL.copyWith(color: tk.text),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.s12),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Center(
                    child: _busy
                        ? const AppLoading()
                        : Text(
                            _error ?? '',
                            textAlign: TextAlign.center,
                            style: AppType.bodyStrong.copyWith(color: tk.dangerInk),
                          ),
                  ),
                ),
                Center(
                  child: AppPressScale(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        AppRoute(builder: (_) => SafetyScreen(job: widget.job)),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: tk.dangerInk,
                        minimumSize: const Size(
                          AppGeometry.minTarget,
                          AppGeometry.minTarget,
                        ),
                      ),
                      child: Text(
                        'Tive um problema / o cliente não tem o código',
                        textAlign: TextAlign.center,
                        style: AppType.bodyStrong.copyWith(
                          decoration: TextDecoration.underline,
                          color: tk.dangerInk,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: tk.surface,
            padding: const EdgeInsets.fromLTRB(AppSpace.s24, AppSpace.s12, AppSpace.s24, AppSpace.s20),
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Builder(
                    builder: (context) {
                      const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'back', '0', ''];
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: keys.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisExtent: AppGeometry.minTarget + 4,
                          mainAxisSpacing: AppSpace.s12,
                          crossAxisSpacing: AppSpace.s12,
                        ),
                        itemBuilder: (context, index) {
                          final k = keys[index];
                          if (k.isEmpty) return const SizedBox.shrink();
                          return Material(
                            color: tk.card,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppGeometry.buttonRadius),
                              side: BorderSide(color: tk.border),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppGeometry.buttonRadius),
                              onTap: () => k == 'back' ? _back() : _press(k),
                              child: Center(
                                child: k == 'back'
                                    ? Semantics(
                                        label: 'Apagar dígito',
                                        child: Icon(Icons.backspace_outlined, size: 22, color: tk.accentInk),
                                      )
                                    : Text(k, style: AppType.headline.copyWith(color: tk.accentInk)),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================== segurança e mediação (11/12)

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key, required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppScaffold(
      appBar: const AppAppBar(title: 'Garantia e segurança'),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: context.layout.margin, vertical: AppSpace.s24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 56,
              backgroundColor: tk.providerSoft,
              child: Icon(Icons.shield_rounded, size: 60, color: tk.accentInk),
            ),
          ),
          const SizedBox(height: AppSpace.s20),
          Text(
            'O seu dinheiro está 100% protegido.',
            textAlign: TextAlign.center,
            style: AppType.display.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s12),
          Text(
            'Fique tranquilo: o valor de ${brl(job.agreedPrice)} está bloqueado em nosso sistema para garantir que você não saia no prejuízo. Abra um chamado e a nossa equipe de mediação assume o caso.',
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s16),
          const InfoBanner(
            'Recomendamos que você saia do local em segurança. Não há necessidade de discussão.',
            tone: BannerTone.warning,
            icon: Icons.shield_outlined,
          ),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        child: AppButton(
          label: 'Falar com a mediação',
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: () => Navigator.of(context).push(
            AppRoute(builder: (_) => ReportProblemScreen(job: job, asProvider: true, initialReason: 'O cliente não tem o código')),
          ),
        ),
      ),
    );
  }
}

class MediationScreen extends StatelessWidget {
  const MediationScreen({super.key, required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppScaffold(
      appBar: const AppAppBar(title: 'Mediação em andamento', automaticallyImplyLeading: true),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: SocialService().myTickets(),
        builder: (context, snap) {
          final t = (snap.data ?? const []).where((x) => x['job_id'] == job.id).firstOrNull;
          final protocol = t == null ? '' : protocolOf(t['id'] as String);
          return ListView(
            padding: EdgeInsets.symmetric(horizontal: context.layout.margin, vertical: AppSpace.s24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: tk.providerSoft,
                  child: Icon(Icons.gavel_rounded, size: 54, color: tk.accentInk),
                ),
              ),
              const SizedBox(height: AppSpace.s16),
              Text(
                'Pagamento retido para análise.',
                textAlign: TextAlign.center,
                style: AppType.headline.copyWith(color: tk.text),
              ),
              const SizedBox(height: AppSpace.s12),
              if (protocol.isNotEmpty)
                Center(
                  child: ActionChip(
                    avatar: const Icon(Icons.copy_rounded, size: 16),
                    label: Text('Protocolo: $protocol', style: AppType.bodyStrong.copyWith(color: tk.text)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: protocol));
                      AppSnackbar.show(context, 'Protocolo copiado.', kind: AppSnackKind.success);
                    },
                  ),
                ),
              const SizedBox(height: AppSpace.s12),
              Text(
                'O valor de ${brl(job.agreedPrice)} fica bloqueado com a Desperrengue. Suas fotos e o histórico do serviço já estão salvos no chamado.',
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: tk.text),
              ),
              const SizedBox(height: AppSpace.s16),
              const InfoBanner(
                'A equipe da Desperrengue assumiu este caso e responde em até 24 horas.',
                tone: BannerTone.warning,
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: AppBottomBar(
        child: AppButton(
          label: 'Acompanhar caso',
          trailingArrow: true,
          onPressed: () => Navigator.of(context).push(AppRoute(builder: (_) => const SupportCenterScreen())),
        ),
      ),
    );
  }
}

// ======================================================== pago, avaliar, obrigado

class PaidSuccessScreen extends StatefulWidget {
  const PaidSuccessScreen({super.key, required this.job});

  final Job job;

  @override
  State<PaidSuccessScreen> createState() => _PaidSuccessScreenState();
}

class _PaidSuccessScreenState extends State<PaidSuccessScreen> {
  double _balance = 0;
  double _credited = 0;
  String _reviewStatus = 'none';
  bool _hide = false;
  List<Achievement> _newAchievements = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final payments = await ProviderService().myPayments();
      final status = await SocialService().reviewStatus(widget.job.id);
      // Conquistas desbloqueadas agora há pouco (ao concluir este serviço).
      final recent = await ProviderService().achievements(ProviderService().uid);
      final since = DateTime.now().subtract(const Duration(minutes: 15));
      final fresh = [
        for (final r in recent)
          if (r.unlockedAt.isAfter(since)) ?achievementFromCode(r.code),
      ];
      if (!mounted) return;
      setState(() {
        _balance = ProviderService.summarize(payments).available;
        _credited = payments.where((p) => p.jobId == widget.job.id).fold(0.0, (a, p) => a + p.netAmount);
        _reviewStatus = status;
        _newAchievements = fresh;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    // Blindagem de layout: SafeArea + rolagem + SliverFillRemaining(hasScrollBody: false)
    // mantêm os botões 100% visíveis em telas baixas e com barra de botões/gestos.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return AppScaffold(
      appBar: const AppAppBar(automaticallyImplyLeading: false, titleWidget: BrandLogo()),
      body: SafeArea(
        top: true,
        bottom: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 620;
            final gap = compact ? AppSpace.s12 : AppSpace.s20;
            return CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(context.layout.margin, compact ? AppSpace.s8 : AppSpace.s16, context.layout.margin, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: SuccessHeroHalo(size: compact ? 96 : 128)),
                        SizedBox(height: gap),
                        Text(
                          'Serviço finalizado e pago!',
                          textAlign: TextAlign.center,
                          style: AppType.display.copyWith(color: tk.accentInk),
                        ),
                        const SizedBox(height: AppSpace.s12),
                        Text(
                          'O código foi validado e suas fotos ficaram registradas. ${brl(_credited)} foram adicionados com segurança à sua carteira!',
                          textAlign: TextAlign.center,
                          style: AppType.body.copyWith(color: tk.textMuted),
                        ),
                        SizedBox(height: gap),
                        AppCard(
                          variant: AppCardVariant.tonal,
                          color: tk.successSoft,
                          borderColor: tk.success,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Seu novo saldo é de', style: AppType.bodySm.copyWith(color: tk.successInk)),
                                    if (_hide)
                                      Text('R\$ •••••', style: AppType.figure.copyWith(color: tk.successInk))
                                    else
                                      AppCountText(
                                        value: _balance,
                                        format: brl,
                                        style: AppType.figure.copyWith(color: tk.successInk),
                                      ),
                                  ],
                                ),
                              ),
                              AppIconButton(
                                tooltip: _hide ? 'Mostrar saldo' : 'Ocultar saldo',
                                onPressed: () => setState(() => _hide = !_hide),
                                icon: _hide ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: tk.successInk,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: gap),
                        NewAchievementsBanner(achievements: _newAchievements),
                        const Expanded(child: SizedBox(height: AppSpace.s12)),
                        Padding(
                          padding: EdgeInsets.only(bottom: bottomInset + AppSpace.s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_reviewStatus == 'none')
                                AppButton(
                                  label: 'Avaliar atendimento do cliente',
                                  trailingArrow: true,
                                  onPressed: () async {
                                    await Navigator.of(context).push(AppRoute(builder: (_) => RateClientScreen(job: widget.job)));
                                    _load();
                                  },
                                )
                              else if (_reviewStatus == 'waiting')
                                const InfoBanner(
                                  'Ela será revelada quando o cliente também avaliar, ou em até 48 horas.',
                                  tone: BannerTone.security,
                                  icon: Icons.hourglass_top_rounded,
                                  title: 'Avaliação enviada (cega)',
                                )
                              else
                                const InfoBanner('Avaliação enviada. Obrigado!', tone: BannerTone.success),
                              const SizedBox(height: AppSpace.s12),
                              AppButton(
                                label: 'Ir para o painel',
                                variant: AppButtonVariant.secondary,
                                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class RateClientScreen extends StatefulWidget {
  const RateClientScreen({super.key, required this.job});

  final Job job;

  @override
  State<RateClientScreen> createState() => _RateClientScreenState();
}

/// Profissional avalia o cliente (avaliação cega): estrelas -> pílulas de
/// segurança/respeito -> comentário. Só é revelada quando as duas partes avaliam.
class _RateClientScreenState extends State<RateClientScreen> {
  final _comment = TextEditingController();
  int _rating = 0;
  Set<String> _tags = <String>{};
  bool _busy = false;
  String _name = 'Cliente';
  String? _avatar;
  ({double avg, int count})? _reputation;

  @override
  void initState() {
    super.initState();
    JobService().clientCard(widget.job.id).then((c) {
      if (mounted && c != null) {
        setState(() {
          _name = (c['full_name'] as String?) ?? 'Cliente';
          _avatar = c['avatar_url'] as String?;
        });
      }
    }).catchError((_) {});
    ProviderService().clientReputation(widget.job.clientId).then((r) {
      if (mounted) setState(() => _reputation = r);
    });
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      AppSnackbar.show(context, 'Toque nas estrelas para dar uma nota.', kind: AppSnackKind.error);
      return;
    }
    setState(() => _busy = true);
    try {
      await SocialService().submitReview(jobId: widget.job.id, rating: _rating, comment: _comment.text, tags: _tags.toList());
      final status = await SocialService().reviewStatus(widget.job.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(AppRoute(builder: (_) => ThanksScreen(revealed: status == 'revealed')));
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final negative = ReviewTags.isNegative(_rating);
    final rep = _reputation;
    return AppScaffold(
      appBar: const AppAppBar(title: 'Avaliar cliente'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(context.layout.margin, AppSpace.s8, context.layout.margin, AppSpace.s24),
        children: [
          Center(child: AppAvatar(url: _avatar, name: _name, radius: 40)),
          const SizedBox(height: AppSpace.s8),
          Center(child: Text('$_name (Cliente)', style: AppType.title.copyWith(color: tk.text))),
          if (rep != null && rep.count > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpace.s4),
                child: Text(
                  'Nota atual do cliente: ${rep.avg.toStringAsFixed(1).replaceAll('.', ',')} (${rep.count} avaliações)',
                  style: AppType.tabular(AppType.caption).copyWith(color: tk.textMuted),
                ),
              ),
            ),
          const SizedBox(height: AppSpace.s16),
          Text(
            'Como foi sua experiência com ${firstName(_name)}?',
            textAlign: TextAlign.center,
            style: AppType.headline.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s16),
          Center(
            child: AppRating(
              value: _rating.toDouble(),
              size: 40,
              onChanged: (v) => setState(() {
                _rating = v;
                _tags = ReviewTags.keepValid(_tags, v, byClient: false);
              }),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.d(context, const Duration(milliseconds: 250)),
            alignment: Alignment.topCenter,
            child: _rating == 0
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s12),
                    child: Text(
                      'Toque numa estrela para começar',
                      textAlign: TextAlign.center,
                      style: AppType.bodySm.copyWith(color: tk.textMuted),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpace.s24),
                      Text(ReviewTags.title(_rating), style: AppType.title.copyWith(color: tk.text)),
                      const SizedBox(height: AppSpace.s4),
                      Text('Escolha quantas quiser (opcional).', style: AppType.caption.copyWith(color: tk.textMuted)),
                      const SizedBox(height: AppSpace.s12),
                      ReviewTagPills(
                        options: ReviewTags.options(_rating, byClient: false),
                        selected: _tags,
                        negative: negative,
                        onToggle: (t, on) => setState(() => on ? _tags.add(t) : _tags.remove(t)),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpace.s24),
          Text('Deixe um comentário (opcional)', style: AppType.titleSm.copyWith(color: tk.text)),
          const SizedBox(height: AppSpace.s8),
          AppTextField(
            controller: _comment,
            maxLines: 3,
            maxLength: 1000,
            hint: 'Descreva como foi o atendimento e a postura do cliente...',
          ),
          const SizedBox(height: AppSpace.s12),
          const BlindReviewBanner(who: 'o cliente'),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        child: AppButton(label: 'Enviar avaliação', loading: _busy, onPressed: _submit),
      ),
    );
  }
}

class ThanksScreen extends StatelessWidget {
  const ThanksScreen({super.key, this.revealed = false});

  final bool revealed;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const AppAppBar(automaticallyImplyLeading: false, titleWidget: BrandLogo()),
      body: ReviewThanksView(
        isProvider: true,
        revealed: revealed,
        onBack: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
    );
  }
}

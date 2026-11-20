import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/marketplace_models.dart' show PublicReview;
import '../../../core/models/provider_dossier_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/media_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/state/privacy_mode.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../shared/presentation/chat_screen.dart';
import '../../shared/presentation/geo_privacy_widgets.dart';
import '../../shared/presentation/review_widgets.dart';

/// Carrega o dossiê de um serviço (padrão: RPC `provider_job_dossier`).
typedef DossierLoader = Future<ProviderJobDossier?> Function(String jobId);

/// Abre o chat arquivado (somente leitura) do serviço.
typedef DossierChatOpener = Future<void> Function(BuildContext context, ProviderJobDossier dossier);

/// Desenha uma imagem do bucket privado (padrão: [SignedImage]).
typedef DossierImageBuilder = Widget Function(BuildContext context, String path, {double? width, double? height, BoxFit fit, double radius});

Widget _defaultImage(BuildContext context, String path, {double? width, double? height, BoxFit fit = BoxFit.cover, double radius = 12}) =>
    SignedImage(path: path, width: width, height: height, fit: fit, radius: radius);

/// Rótulo da taxa da plataforma. O percentual vem do servidor (`fee_pct`), aceito como
/// 12 ou 0,12; sem percentual válido o rótulo fica genérico (nada é calculado aqui).
@visibleForTesting
String dossierFeeLabel(double pct) {
  const base = 'Taxa de proteção da plataforma';
  if (pct <= 0) return base;
  final p = pct < 1 ? pct * 100 : pct;
  final txt = p == p.roundToDouble() ? p.round().toString() : p.toStringAsFixed(1).replaceAll('.', ',');
  return '$base ($txt%)';
}

/// Dossiê completo de um serviço, visão INTERNA do profissional contratado: linha do
/// tempo, financeiro (bruto, taxa, líquido), escopo, evidências, avaliação do cliente e
/// o chat arquivado. O cliente nunca chega aqui: o servidor só entrega ao contratado.
class DossieServicoProfissionalScreen extends StatefulWidget {
  const DossieServicoProfissionalScreen({
    super.key,
    required this.jobId,
    this.loader,
    this.openChat,
    this.imageBuilder,
    this.locationLoader,
  });

  final String jobId;

  /// Os três abaixo existem para injetar fakes nos testes; em produção ficam null.
  final DossierLoader? loader;
  final DossierChatOpener? openChat;
  final DossierImageBuilder? imageBuilder;

  /// Fake da localização protegida nos testes (padrão: servidor).
  final ProviderLocationLoader? locationLoader;

  @override
  State<DossieServicoProfissionalScreen> createState() => _DossieServicoProfissionalScreenState();
}

class _DossieServicoProfissionalScreenState extends State<DossieServicoProfissionalScreen> {
  late Future<ProviderJobDossier?> _future = _load();
  bool _openingChat = false;

  bool get _hidden => PrivacyMode.instance.hidden.value;
  DossierImageBuilder get _image => widget.imageBuilder ?? _defaultImage;

  Future<ProviderJobDossier?> _load() {
    final loader = widget.loader;
    return loader != null ? loader(widget.jobId) : ProviderService().jobDossier(widget.jobId);
  }

  void _reload() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  void _onPrivacy() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    PrivacyMode.instance.ensureLoaded();
    PrivacyMode.instance.hidden.addListener(_onPrivacy);
  }

  @override
  void dispose() {
    PrivacyMode.instance.hidden.removeListener(_onPrivacy);
    super.dispose();
  }

  Future<void> _openChat(ProviderJobDossier d) async {
    final custom = widget.openChat;
    if (custom != null) return custom(context, d);
    if (_openingChat) return;
    setState(() => _openingChat = true);
    try {
      final job = await JobService().fetchJob(d.jobId);
      if (!mounted) return;
      if (job == null) {
        AppSnackbar.show(context, 'Não foi possível abrir a conversa deste serviço.', kind: AppSnackKind.error);
        return;
      }
      // Arquivo somente leitura: o serviço já acabou, não se envia mensagem nova.
      await Navigator.of(context).push(AppRoute<void>(
        builder: (_) => ChatScreen(
          job: job,
          providerId: ProviderService().uid,
          peerName: d.client.name,
          peerAvatar: d.client.avatarUrl,
          readOnly: true,
        ),
      ));
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  void _zoom(List<String> paths, int index) {
    Navigator.of(context).push(AppRoute<void>(
      fullscreenModal: true,
      builder: (_) => _ZoomGallery(paths: paths, initial: index, imageBuilder: _image),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppScaffold(
      appBar: AppAppBar(
        title: 'Dossiê do serviço',
        actions: [
          AppIconButton(
            tooltip: _hidden ? 'Mostrar valores' : 'Ocultar valores',
            onPressed: PrivacyMode.instance.toggle,
            icon: _hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: tk.textMuted,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false, // o respiro inferior é somado manualmente ao conteúdo rolável
        child: FutureBuilder<ProviderJobDossier?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const AppLoading(message: 'Carregando dossiê...');
            if (snap.hasError) {
              return AppErrorState(
                message: 'Não foi possível carregar o dossiê do serviço.',
                retryLabel: 'Tentar novamente',
                onRetry: _reload,
              );
            }
            final d = snap.data;
            if (d == null) {
              return const AppEmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Dossiê indisponível',
                message: 'Este serviço não existe ou você não é o profissional contratado.',
              );
            }
            return _content(context, d);
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ProviderJobDossier d) {
    final tk = context.tk;
    final margin = context.layout.margin;
    final photos = d.evidencePhotos;
    final video = d.evidenceVideo;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, MediaQuery.viewPaddingOf(context).bottom + AppSpace.s24),
      children: [
        _header(context, d),
        const SizedBox(height: AppSpace.section),
        AppSection(title: 'Financeiro', child: _financial(context, d)),
        const SizedBox(height: AppSpace.section),
        AppSection(title: 'Escopo e relatório', child: _scope(context, d)),
        const SizedBox(height: AppSpace.section),
        AppSection(
          title: 'Evidências',
          child: (photos.isEmpty && video == null)
              ? Text('Nenhuma evidência registrada para este serviço.', style: AppType.bodySm.copyWith(color: tk.textMuted))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (photos.isNotEmpty) _evidenceGrid(context, photos),
                    if (video != null) ...[
                      const SizedBox(height: AppSpace.s12),
                      _EvidenceVideo(path: video.path),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: AppSpace.section),
        AppSection(title: 'Avaliação do cliente', child: _review(context, d)),
        const SizedBox(height: AppSpace.s20),
        AppButton(
          label: 'Ver histórico de conversa com o cliente',
          variant: AppButtonVariant.secondary,
          icon: Icons.forum_rounded,
          loading: _openingChat,
          onPressed: _openingChat ? null : () => _openChat(d),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- cabeçalho

  Widget _header(BuildContext context, ProviderJobDossier d) {
    final tk = context.tk;
    final tone = switch (d.status) {
      DossierStatus.completed => AppTone.success,
      DossierStatus.disputed => AppTone.warning,
      DossierStatus.canceled => AppTone.danger,
      _ => AppTone.info,
    };
    return AppCard(
      variant: AppCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(d.code, style: AppType.overline.copyWith(color: tk.textMuted)),
              AppStatusChip(
                d.status.label,
                tone: tone,
                icon: d.isCompleted ? Icons.check_circle_rounded : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          Text(d.title, style: AppType.headline.copyWith(color: tk.text)),
          if (d.category != null) ...[
            const SizedBox(height: AppSpace.s4),
            Text(d.category!, style: AppType.bodySm.copyWith(color: tk.textMuted)),
          ],
          const SizedBox(height: AppSpace.s16),
          _TimelineRow(icon: Icons.event_rounded, label: 'Agendado', value: d.scheduledFor == null ? '—' : dateLong(d.scheduledFor!)),
          _TimelineRow(
            icon: Icons.play_circle_outline_rounded,
            label: 'Início real',
            value: d.startedAt == null ? 'Não iniciado' : dateLong(d.startedAt!),
            note: d.startedAt != null && d.startedSimulated ? '(início de teste, sem efeito real)' : null,
          ),
          _TimelineRow(icon: Icons.flag_rounded, label: 'Conclusão', value: d.finishedAt == null ? '—' : dateLong(d.finishedAt!), last: true),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- financeiro

  Widget _financial(BuildContext context, ProviderJobDossier d) {
    final tk = context.tk;
    final hidden = _hidden;
    // Com a privacidade ligada TODOS os valores viram a máscara (sem sinal), como na carteira.
    final gross = PrivacyMode.money(brl(d.gross), hidden: hidden);
    final fee = hidden ? PrivacyMode.mask : '− ${brl(d.fee)}';
    final net = hidden ? PrivacyMode.mask : '+ ${brl(d.net)}';
    return AppCard(
      child: Column(
        children: [
          _MoneyRow(label: 'Valor bruto do orçamento', value: gross),
          const SizedBox(height: AppSpace.s12),
          _MoneyRow(label: dossierFeeLabel(d.feePct), value: fee, valueColor: tk.dangerInk),
          const Padding(padding: EdgeInsets.symmetric(vertical: AppSpace.s12), child: Divider(height: 1)),
          AppCard(
            variant: AppCardVariant.tonal,
            color: tk.successSoft,
            radius: AppGeometry.fieldRadius,
            padding: const EdgeInsets.all(AppSpace.s16),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.isCompleted ? 'Valor líquido recebido' : 'Valor líquido a receber',
                    style: AppType.bodyStrong.copyWith(color: tk.successInk),
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(net, style: AppType.figure.copyWith(color: tk.successInk)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------- escopo

  Widget _scope(BuildContext context, ProviderJobDossier d) {
    final tk = context.tk;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(url: d.client.avatarUrl, name: d.client.name, radius: 20),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cliente', style: AppType.caption.copyWith(color: tk.textMuted)),
                    Text(d.client.name, style: AppType.titleSm.copyWith(color: tk.text)),
                  ],
                ),
              ),
            ],
          ),
          // Endereço: SEMPRE pela trava de privacidade do servidor. Serviço encerrado/cancelado/em
          // mediação ⇒ só Bairro • Cidade-UF; rua/número/mapa exato só se o servidor liberar.
          ProviderLocationBuilder(
            jobId: d.jobId,
            loader: widget.locationLoader,
            builder: (context, view, loading) {
              if (view == null) return const SizedBox.shrink();
              final unlocked = view.exactUnlocked;
              return Padding(
                padding: const EdgeInsets.only(top: AppSpace.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabeledText(
                      icon: Icons.place_rounded,
                      label: unlocked ? 'Endereço atendido' : 'Região do atendimento',
                      text: unlocked ? exactAddressLineOf(view) : protectedAreaTitle(view),
                      onTap: unlocked ? () => openProviderLocation(context, view) : null,
                    ),
                    if (!unlocked) ...[
                      const SizedBox(height: AppSpace.s8),
                      GeoLockNotice(view: view),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpace.s16),
          _LabeledText(icon: Icons.description_rounded, label: 'Descrição original do pedido', text: d.description ?? 'Sem descrição.'),
          if (d.photoPaths.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s16),
            Text('Fotos do pedido', style: AppType.caption.copyWith(color: tk.textMuted, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpace.s8),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: d.photoPaths.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s8),
                itemBuilder: (_, i) => AppPressable(
                  borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
                  onTap: () => _zoom(d.photoPaths, i),
                  child: _image(context, d.photoPaths[i], width: 96, height: 96, radius: AppGeometry.fieldRadius),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.s16),
          _LabeledText(
            icon: Icons.assignment_turned_in_rounded,
            label: 'Relatório técnico',
            text: d.report ?? 'Nenhum relatório técnico foi enviado.',
            muted: d.report == null,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- evidências

  Widget _evidenceGrid(BuildContext context, List<DossierEvidence> photos) {
    final tk = context.tk;
    final paths = [for (final e in photos) e.path];
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: AppSpace.s12,
      crossAxisSpacing: AppSpace.s12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < photos.length; i++)
          AppPressable(
            borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
            onTap: () => _zoom(paths, i),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _image(context, photos[i].path, radius: AppGeometry.fieldRadius),
                Positioned(
                  left: AppSpace.s8,
                  bottom: AppSpace.s8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8, vertical: AppSpace.s4),
                    decoration: BoxDecoration(
                      color: tk.scrim,
                      borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
                    ),
                    child: Text(
                      photos[i].slot.label,
                      style: AppType.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ----------------------------------------------------------------- avaliação

  Widget _review(BuildContext context, ProviderJobDossier d) {
    final tk = context.tk;
    final r = d.review;
    if (r == null) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.hourglass_empty_rounded, color: tk.textMuted),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Text(
                'O cliente ainda não avaliou este serviço.',
                style: AppType.bodySm.copyWith(color: tk.textMuted),
              ),
            ),
          ],
        ),
      );
    }
    if (!r.isRevealed) {
      return const InfoBanner(
        'Avaliação recebida, oculta pela regra cega. Ela aparece quando você avaliar o cliente ou 48 h depois da primeira avaliação.',
        tone: BannerTone.security,
        icon: Icons.visibility_off_rounded,
        title: 'Avaliação recebida',
      );
    }
    // Reaproveita o visual do ReviewCard (sem toque nem dica: aqui já estamos no dossiê).
    return ReviewCard(
      review: PublicReview(
        id: d.jobId,
        rating: r.rating ?? 0,
        reviewerName: d.client.name,
        createdAt: r.createdAt ?? DateTime.now(),
        comment: r.comment,
        tags: r.tags,
        photoPaths: r.photoPaths,
        reply: r.reply,
      ),
    );
  }
}

// ============================================================ blocos de layout

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.icon, required this.label, required this.value, this.note, this.last = false});

  final IconData icon;
  final String label;
  final String value;
  final String? note;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tk.accentInk),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppType.caption.copyWith(color: tk.textMuted)),
                Text(value, style: AppType.bodyStrong.copyWith(color: tk.text)),
                if (note != null)
                  Text(
                    note!,
                    style: AppType.caption.copyWith(color: tk.textMuted, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppInfoRow(
      label: label,
      valueWidget: Text(
        value,
        textAlign: context.layout.isLargeText ? TextAlign.start : TextAlign.end,
        style: AppType.tabular(AppType.titleSm).copyWith(color: valueColor ?? tk.text),
      ),
    );
  }
}

class _LabeledText extends StatelessWidget {
  const _LabeledText({required this.icon, required this.label, required this.text, this.muted = false, this.onTap});

  final IconData icon;
  final String label;
  final String text;
  final bool muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: tk.accentInk),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppType.caption.copyWith(color: tk.textMuted, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpace.s2),
              Text(text, style: AppType.body.copyWith(color: muted ? tk.textMuted : tk.text)),
              if (onTap != null) ...[
                const SizedBox(height: AppSpace.s4),
                Row(
                  children: [
                    Icon(Icons.map_outlined, size: 15, color: tk.accentInk),
                    const SizedBox(width: AppSpace.s4),
                    Flexible(
                      child: Text(
                        'Toque para ver no mapa',
                        style: AppType.caption.copyWith(fontWeight: FontWeight.w700, color: tk.accentInk),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (onTap != null) Icon(Icons.chevron_right_rounded, color: tk.textMuted),
      ],
    );
    if (onTap == null) return row;
    return AppPressable(
      borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
        child: row,
      ),
    );
  }
}

/// Galeria em tela cheia: arraste para trocar, pinça para dar zoom.
class _ZoomGallery extends StatelessWidget {
  const _ZoomGallery({required this.paths, required this.initial, required this.imageBuilder});

  final List<String> paths;
  final int initial;
  final DossierImageBuilder imageBuilder;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Evidência')),
      body: PageView.builder(
        controller: PageController(initialPage: initial),
        itemCount: paths.length,
        itemBuilder: (context, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(child: imageBuilder(context, paths[i], fit: BoxFit.contain, radius: 0)),
        ),
      ),
    );
  }
}

/// Player do vídeo opcional. Só baixa quando o usuário toca em reproduzir (economiza dados).
class _EvidenceVideo extends StatefulWidget {
  const _EvidenceVideo({required this.path});

  final String path;

  @override
  State<_EvidenceVideo> createState() => _EvidenceVideoState();
}

class _EvidenceVideoState extends State<_EvidenceVideo> {
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
                color: tk.surface,
                child: InkWell(
                  onTap: _loading ? null : _start,
                  child: Center(
                    child: _loading
                        ? const AppLoading(message: 'Carregando vídeo...')
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.play_circle_fill_rounded, size: 64, color: tk.accentInk),
                            const SizedBox(height: AppSpace.s8),
                            Text(
                              _error ?? 'Toque para assistir ao vídeo do serviço',
                              style: AppType.bodySm.copyWith(color: tk.textMuted),
                            ),
                          ]),
                  ),
                ),
              )
            : Stack(alignment: Alignment.bottomCenter, children: [
                VideoPlayer(c),
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: c,
                  builder: (context, v, _) => Container(
                    color: tk.scrim,
                    child: Row(children: [
                      AppIconButton(
                        tooltip: v.isPlaying ? 'Pausar vídeo' : 'Reproduzir vídeo',
                        icon: v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        onPressed: () => v.isPlaying ? c.pause() : c.play(),
                      ),
                      Expanded(
                        child: VideoProgressIndicator(
                          c,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(playedColor: Colors.white, bufferedColor: Colors.white30, backgroundColor: Colors.white12),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s12),
                    ]),
                  ),
                ),
              ]),
      ),
    );
  }
}

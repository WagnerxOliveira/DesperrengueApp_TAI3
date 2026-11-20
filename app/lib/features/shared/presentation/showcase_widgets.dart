import 'package:desperrengue_app/core/ui/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/showcase_models.dart';
import '../../../core/services/media_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';

// =============================================================================
// Vitrine de cases (portfólio automático LIFO) + Case de Sucesso
// =============================================================================

/// Faixa horizontal com os últimos serviços (máx. 4) do profissional.
///
/// LIFO: quando o cliente valida o PIN e avalia, o serviço entra na posição [0] e
/// empurra os antigos; o 5º cai para o histórico geral. Serviços FIXADOS pelo
/// profissional mantêm a vaga. Toda a regra roda no banco (`provider_showcase`).
///
/// [isOwner] mostra o atalho "Gerenciar" (curadoria) e uma dica quando está vazia;
/// na visão do cliente a seção some se não houver cases.
class ShowcaseStrip extends StatefulWidget {
  const ShowcaseStrip({super.key, required this.providerId, this.isOwner = false});

  final String providerId;
  final bool isOwner;

  @override
  State<ShowcaseStrip> createState() => _ShowcaseStripState();
}

class _ShowcaseStripState extends State<ShowcaseStrip> {
  final _providers = ProviderService();
  late Future<List<ShowcaseCase>> _future = _providers.showcase(widget.providerId);

  void _reload() => setState(() => _future = _providers.showcase(widget.providerId));

  Future<void> _manage() async {
    await Navigator.of(context).push(AppRoute(builder: (_) => const CaseCurationScreen()));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5);
    final stripHeight = 264.0 + ((textScale - 1.0) * 112.0).clamp(0.0, 64.0);
    return FutureBuilder<List<ShowcaseCase>>(
      future: _future,
      builder: (context, snap) {
        final cases = snap.data ?? const <ShowcaseCase>[];
        if (snap.connectionState != ConnectionState.done) {
          return const AppSkeletonCard(height: 112);
        }
        if (cases.isEmpty && !widget.isOwner) return const SizedBox.shrink();
        return AppSection(
          title: 'Vitrine de cases',
          action: widget.isOwner
              ? AppButton(
                  label: 'Gerenciar',
                  icon: Icons.push_pin_outlined,
                  variant: AppButtonVariant.tertiary,
                  expand: false,
                  compact: true,
                  onPressed: _manage,
                )
              : null,
          child: cases.isEmpty
              ? const InfoBanner(
                  'Sua vitrine é montada sozinha: cada serviço concluído e avaliado com 4 estrelas ou mais entra aqui, '
                  'do mais recente para o mais antigo. Capriche nas fotos e no relatório técnico!',
                  tone: BannerTone.info,
                  icon: Icons.auto_awesome_rounded,
                )
              : SizedBox(
                  height: stripHeight,
                  // ListView.builder: só desenha os cartões visíveis (no máx. 4).
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: cases.length,
                    itemExtent: 248,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(right: AppSpace.s12),
                      child: _ShowcaseCard(
                        item: cases[i],
                        onTap: () => Navigator.of(context).push(
                          AppRoute(builder: (_) => CaseDetailScreen(jobId: cases[i].jobId, preview: cases[i])),
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _ShowcaseCard extends StatelessWidget {
  const _ShowcaseCard({required this.item, required this.onTap});

  final ShowcaseCase item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      variant: AppCardVariant.elevated,
      padding: EdgeInsets.zero,
      semanticLabel: 'Case: ${item.title}, ${item.rating} estrelas',
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppGeometry.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 108,
                  width: double.infinity,
                  child: item.coverPath == null
                      ? Container(color: tk.surface, child: Icon(Icons.image_outlined, color: tk.textMuted, size: 36))
                      : SignedImage(path: item.coverPath!, radius: 0, height: 108, width: double.infinity),
                ),
                Positioned(
                  left: AppSpace.s8,
                  right: AppSpace.s8,
                  top: AppSpace.s8,
                  child: Wrap(
                    spacing: AppSpace.s4,
                    runSpacing: AppSpace.s4,
                    alignment: item.pinned ? WrapAlignment.spaceBetween : WrapAlignment.end,
                    children: [
                      if (item.pinned)
                        const AppStatusChip('Fixado', tone: AppTone.warning, icon: Icons.push_pin_rounded),
                      const AppStatusChip('Verificado', tone: AppTone.success, icon: Icons.verified_rounded),
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.fade,
                      style: AppType.bodyStrong.copyWith(color: tk.text),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    AppRating(value: item.rating.toDouble(), size: 15),
                    const SizedBox(height: AppSpace.s4),
                    Expanded(
                      child: Text(
                        item.comment?.trim().isNotEmpty == true ? '“${item.comment!.trim()}”' : 'Cliente satisfeito.',
                        maxLines: 2,
                        overflow: TextOverflow.fade,
                        style: AppType.caption.copyWith(color: tk.textMuted),
                      ),
                    ),
                    Text(
                      '— ${item.clientName}',
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: AppType.caption.copyWith(fontWeight: FontWeight.w700, color: tk.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Case de Sucesso (dossiê técnico)
// =============================================================================

class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({super.key, required this.jobId, this.preview});

  final String jobId;

  /// Dados do cartão, mostrados no título enquanto o dossiê carrega.
  final ShowcaseCase? preview;

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  late final Future<CaseDetail?> _future = ProviderService().caseDetail(widget.jobId);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const AppAppBar(title: 'Case de sucesso'),
      body: FutureBuilder<CaseDetail?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const AppSkeletonList(count: 3);
          if (snap.hasError) {
            return AppErrorState(message: 'Não foi possível abrir este case.', onRetry: () => setState(() {}));
          }
          final d = snap.data;
          if (d == null) {
            return const AppEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Case indisponível',
              message: 'Este serviço não está mais disponível na vitrine.',
            );
          }
          return _CaseBody(detail: d);
        },
      ),
    );
  }
}

class _CaseBody extends StatefulWidget {
  const _CaseBody({required this.detail});

  final CaseDetail detail;

  @override
  State<_CaseBody> createState() => _CaseBodyState();
}

class _CaseBodyState extends State<_CaseBody> {
  int _photoIndex = 0;
  late final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    final d = widget.detail;
    final photoBadgeBg = tk.scrim;
    final photoBadgeFg = AppTokens.onColor(photoBadgeBg);
    return ListView(
      padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s32),
      children: [
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            const AppStatusChip('Serviço verificado pelo Desperrengue', tone: AppTone.success, icon: Icons.verified_rounded),
            if (d.pinned) const AppStatusChip('Fixado', tone: AppTone.warning, icon: Icons.push_pin_rounded),
          ],
        ),
        const SizedBox(height: AppSpace.s12),
        Text(d.title, style: AppType.headline.copyWith(color: tk.text)),
        const SizedBox(height: AppSpace.s4),
        Text(
          [if (d.category.isNotEmpty) d.category, if (d.finishedAt != null) 'Concluído em ${dateShort(d.finishedAt!.toLocal())}'].join(' · '),
          style: AppType.bodySm.copyWith(color: tk.textMuted),
        ),
        if (d.video != null) ...[
          const SizedBox(height: AppSpace.section),
          AppSection(title: 'Vídeo do serviço', child: _CaseVideo(path: d.video!)),
        ],
        if (d.photos.isNotEmpty) ...[
          const SizedBox(height: AppSpace.section),
          AppSection(
            title: 'Galeria (${_photoIndex + 1} de ${d.photos.length})',
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Arraste para o lado',
                  style: AppType.caption.copyWith(fontWeight: FontWeight.w700, color: tk.accentInk),
                ),
                const SizedBox(width: AppSpace.s4),
                Icon(Icons.arrow_forward_rounded, size: 16, color: tk.accentInk),
              ],
            ),
            child: SizedBox(
              height: 224,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PageView.builder(
                    key: const ValueKey('case-detail-photo-pageview'),
                    controller: _pageController,
                    itemCount: d.photos.length,
                    onPageChanged: (idx) => setState(() => _photoIndex = idx),
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
                      child: GestureDetector(
                        onTap: () => _zoom(context, d.photos, i),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            SignedImage(path: d.photos[i], radius: AppGeometry.fieldRadius, height: 224, width: double.infinity),
                            Positioned(
                              top: AppSpace.s12,
                              left: AppSpace.s12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s4),
                                decoration: BoxDecoration(
                                  color: photoBadgeBg,
                                  borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                                ),
                                child: Text(
                                  'Foto ${i + 1} de ${d.photos.length}',
                                  style: AppType.tabular(AppType.caption).copyWith(fontWeight: FontWeight.w700, color: photoBadgeFg),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (d.photos.length > 1 && _photoIndex > 0)
                    Positioned(
                      left: AppSpace.s8,
                      child: AppIconButton(
                        tooltip: 'Foto anterior',
                        filled: true,
                        onPressed: () => _pageController.previousPage(
                          duration: AppMotion.d(context, AppMotion.page),
                          curve: AppMotion.pageCurve,
                        ),
                        icon: Icons.chevron_left_rounded,
                      ),
                    ),
                  if (d.photos.length > 1 && _photoIndex < d.photos.length - 1)
                    Positioned(
                      right: AppSpace.s8,
                      child: AppIconButton(
                        tooltip: 'Próxima foto',
                        filled: true,
                        onPressed: () => _pageController.nextPage(
                          duration: AppMotion.d(context, AppMotion.page),
                          curve: AppMotion.pageCurve,
                        ),
                        icon: Icons.chevron_right_rounded,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (d.hasClientRequestDescription) ...[
          const SizedBox(height: AppSpace.section),
          AppSection(
            title: 'O que foi solicitado pelo cliente',
            child: AppCard(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.assignment_outlined, color: tk.info),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Text(d.clientRequestDescription!.trim(), style: AppType.body.copyWith(color: tk.text)),
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.section),
        AppSection(
          title: 'Relatório técnico',
          child: AppCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.description_outlined, color: tk.accentInk),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Text(
                  d.hasReport ? d.report!.trim() : 'O profissional não registrou um relatório técnico para este serviço.',
                  style: AppType.body.copyWith(color: d.hasReport ? tk.text : tk.textMuted),
                ),
              ),
            ]),
          ),
        ),
        if (d.hasComplementaryNotes) ...[
          const SizedBox(height: AppSpace.section),
          AppSection(
            title: 'Notas Técnicas Complementares',
            child: AppCard(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.engineering_rounded, color: tk.accentInk),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Text(d.complementaryNotes!.trim(), style: AppType.body.copyWith(color: tk.text)),
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.section),
        AppSection(
          title: 'Avaliação do cliente',
          child: AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppRating(value: d.rating.toDouble(), size: 22),
                      const SizedBox(width: AppSpace.s8),
                      Text(
                        '${d.rating}.0',
                        style: AppType.tabular(AppType.titleSm).copyWith(color: tk.text),
                      ),
                    ],
                  ),
                  Text(d.clientName, style: AppType.bodyStrong.copyWith(color: tk.textMuted)),
                ],
              ),
              if (d.tags.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s12),
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: [for (final t in d.tags) AppStatusChip(t, tone: AppTone.success)],
                ),
              ],
              if (d.comment?.trim().isNotEmpty == true) ...[
                const SizedBox(height: AppSpace.s12),
                Text(
                  '“${d.comment!.trim()}”',
                  style: AppType.body.copyWith(fontStyle: FontStyle.italic, color: tk.text),
                ),
              ],
              if (d.reply?.trim().isNotEmpty == true) ...[
                const Divider(height: AppSpace.s24),
                Text('Resposta do profissional', style: AppType.caption.copyWith(fontWeight: FontWeight.w700, color: tk.textMuted)),
                const SizedBox(height: AppSpace.s4),
                Text(d.reply!.trim(), style: AppType.body.copyWith(color: tk.text)),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  void _zoom(BuildContext context, List<String> photos, int start) {
    Navigator.of(context).push<void>(
      AppRoute<void>(
        fullscreenModal: true,
        builder: (_) => _ShowcasePhotoZoomScreen(photos: photos, start: start),
      ),
    );
  }
}

class _ShowcasePhotoZoomScreen extends StatelessWidget {
  const _ShowcasePhotoZoomScreen({required this.photos, required this.start});

  final List<String> photos;
  final int start;

  @override
  Widget build(BuildContext context) {
    final darkTk = AppTokens.dark;
    return Scaffold(
      backgroundColor: darkTk.surfaceInset,
      body: Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: start),
            itemCount: photos.length,
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(child: SignedImage(path: photos[i], radius: 0, fit: BoxFit.contain)),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s8),
                child: AppIconButton(
                  tooltip: 'Fechar',
                  icon: Icons.close_rounded,
                  color: darkTk.text,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Player do vídeo do serviço. Só baixa o vídeo quando o usuário toca em reproduzir
/// (economiza dados e memória; nada é carregado ao abrir a tela).
class _CaseVideo extends StatefulWidget {
  const _CaseVideo({required this.path});

  final String path;

  @override
  State<_CaseVideo> createState() => _CaseVideoState();
}

class _CaseVideoState extends State<_CaseVideo> {
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
      await c.setLooping(false);
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
    final darkTk = AppTokens.dark;
    final c = _c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
      child: AspectRatio(
        aspectRatio: c?.value.aspectRatio ?? 16 / 9,
        child: c == null
            ? Material(
                color: darkTk.surface,
                child: InkWell(
                  onTap: _loading ? null : _start,
                  child: Center(
                    child: _loading
                        ? const AppLoading()
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.play_circle_fill_rounded, size: 64, color: darkTk.text),
                            const SizedBox(height: AppSpace.s8),
                            Text(_error ?? 'Toque para assistir', style: AppType.bodySm.copyWith(color: darkTk.textMuted)),
                          ]),
                  ),
                ),
              )
            : Stack(alignment: Alignment.bottomCenter, children: [
                VideoPlayer(c),
                _Controls(controller: c),
              ]),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final darkTk = AppTokens.dark;
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, v, _) => Container(
        color: darkTk.scrim,
        child: Row(children: [
          AppIconButton(
            tooltip: v.isPlaying ? 'Pausar vídeo' : 'Reproduzir vídeo',
            icon: v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: darkTk.text,
            onPressed: () => v.isPlaying ? controller.pause() : controller.play(),
          ),
          Expanded(
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: darkTk.text,
                bufferedColor: darkTk.textMuted.withValues(alpha: 0.45),
                backgroundColor: darkTk.border.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s12),
        ]),
      ),
    );
  }
}

// =============================================================================
// Curadoria: histórico geral + "Fixar"
// =============================================================================

class CaseCurationScreen extends StatefulWidget {
  const CaseCurationScreen({super.key});

  @override
  State<CaseCurationScreen> createState() => _CaseCurationScreenState();
}

class _CaseCurationScreenState extends State<CaseCurationScreen> {
  final _providers = ProviderService();
  late Future<List<CaseHistoryItem>> _future = _providers.caseHistory();
  String? _busy;

  void _reload() => setState(() => _future = _providers.caseHistory());

  Future<void> _toggle(CaseHistoryItem it) async {
    setState(() => _busy = it.jobId);
    try {
      if (it.pinned) {
        await _providers.unpinCase(it.jobId);
      } else {
        await _providers.pinCase(it.jobId);
      }
      _reload();
    } catch (e) {
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    return AppScaffold(
      appBar: const AppAppBar(title: 'Gerenciar vitrine'),
      body: FutureBuilder<List<CaseHistoryItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const AppSkeletonList(count: 4);
          if (snap.hasError) {
            return AppErrorState(message: 'Não foi possível carregar o histórico.', onRetry: _reload);
          }
          final items = snap.data ?? const <CaseHistoryItem>[];
          final pinned = items.where((i) => i.pinned).length;
          if (items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.push_pin_outlined,
              title: 'Nada para fixar ainda',
              message: 'Seus serviços concluídos e avaliados aparecem aqui.',
            );
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s24),
            children: [
              InfoBanner(
                'A vitrine mostra $kShowcaseSlots serviços: os mais recentes (4 estrelas ou mais) entram sozinhos. '
                'Fixe até $kMaxPinnedCases serviços com 5 estrelas para mantê-los lá para sempre. Fixados: $pinned/$kMaxPinnedCases.',
                tone: BannerTone.info,
                icon: Icons.push_pin_rounded,
              ),
              const SizedBox(height: AppSpace.s12),
              for (final it in items)
                AppCard(
                  margin: const EdgeInsets.only(bottom: AppSpace.s12),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(it.title, maxLines: 2, style: AppType.bodyStrong.copyWith(color: tk.text)),
                        const SizedBox(height: AppSpace.s4),
                        Wrap(
                          spacing: AppSpace.s8,
                          runSpacing: AppSpace.s4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            AppRating(value: it.rating.toDouble(), size: 15),
                            if (it.inShowcase)
                              const AppStatusChip('Na vitrine', tone: AppTone.success),
                          ],
                        ),
                        if (!it.canPin)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpace.s4),
                            child: Text(
                              'Só serviços com 5 estrelas podem ser fixados.',
                              style: AppType.caption.copyWith(color: tk.textMuted),
                            ),
                          ),
                      ]),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    _busy == it.jobId
                        ? const SizedBox(
                            width: AppGeometry.minTarget,
                            height: AppGeometry.minTarget,
                            child: AppLoading(),
                          )
                        : AppIconButton(
                            tooltip: it.pinned ? 'Soltar' : 'Fixar',
                            filled: it.pinned,
                            onPressed: (it.pinned || (it.canPin && pinned < kMaxPinnedCases)) ? () => _toggle(it) : null,
                            icon: it.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                          ),
                  ]),
                ),
            ],
          );
        },
      ),
    );
  }
}

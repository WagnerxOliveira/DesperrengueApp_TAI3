import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/client_dossier_models.dart';
import '../../../core/models/marketplace_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/media_service.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/names.dart';
import '../../shared/presentation/chat_screen.dart';

/// Carrega o dossiê do serviço (produção: RPC `client_job_dossier`).
typedef DossierLoader = Future<ClientDossier?> Function(String jobId);

/// Carrega o [Job] (necessário para abrir o chat arquivado).
typedef JobLoader = Future<Job?> Function(String jobId);

/// Desenha uma imagem privada do serviço (produção: [SignedImage]).
typedef EvidenceImageBuilder = Widget Function(BuildContext context, String path, BoxFit fit);

/// Abre o detalhe de um serviço já encerrado (concluído/cancelado).
void openClientServiceDetail(BuildContext context, String jobId) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetalheServicoClienteScreen(jobId: jobId)));
}

/// Dossiê do serviço para o cliente: o que foi pedido, o que foi entregue
/// (fotos/vídeo), quanto foi pago, relatório, sua avaliação e a conversa arquivada.
class DetalheServicoClienteScreen extends StatefulWidget {
  const DetalheServicoClienteScreen({
    super.key,
    required this.jobId,
    @visibleForTesting this.dossierLoader,
    @visibleForTesting this.jobLoader,
    @visibleForTesting this.imageBuilder,
  });

  final String jobId;
  final DossierLoader? dossierLoader;
  final JobLoader? jobLoader;
  final EvidenceImageBuilder? imageBuilder;

  @override
  State<DetalheServicoClienteScreen> createState() => _DetalheServicoClienteScreenState();
}

class _DetalheServicoClienteScreenState extends State<DetalheServicoClienteScreen> {
  late Future<ClientDossier?> _future = _load();
  bool _openingChat = false;

  Future<ClientDossier?> _load() =>
      widget.dossierLoader != null ? widget.dossierLoader!(widget.jobId) : JobService().clientJobDossier(widget.jobId);

  void _reload() => setState(() => _future = _load());

  Widget _image(BuildContext context, String path, BoxFit fit) =>
      widget.imageBuilder != null ? widget.imageBuilder!(context, path, fit) : SignedImage(path: path, fit: fit, radius: 0);

  /// Toque na foto: tela cheia com zoom/pan (pinça).
  void _zoom(String path, String label) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(child: _image(ctx, path, BoxFit.contain)),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Fechar',
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
    return Scaffold(
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

  Widget _content(BuildContext context, ClientDossier d) {
    final tk = context.tk;
    final photos = d.requiredPhotos;
    final video = d.videoPath;
    final provider = d.provider;
    final endLabel = d.isCanceled ? 'Cancelado' : 'Concluído em';
    final endDate = d.finishedAt;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(d.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 8),
                  d.isCanceled
                      ? StatusChip('Cancelado', color: tk.danger, icon: Icons.cancel_outlined)
                      : StatusChip('Concluído', color: tk.success, icon: Icons.check_circle_outline),
                ],
              ),
              const SizedBox(height: 12),
              _InfoRow(icon: Icons.tag_rounded, label: 'ID do serviço', value: d.code),
              if (d.category.isNotEmpty) _InfoRow(icon: Icons.handyman_outlined, label: 'Categoria', value: d.category),
              if (endDate != null)
                _InfoRow(
                  icon: d.isCanceled ? Icons.event_busy_outlined : Icons.event_available_outlined,
                  label: endLabel,
                  value: dateLong(endDate),
                ),
              if (d.scheduledFor != null)
                _InfoRow(icon: Icons.schedule_rounded, label: 'Agendado para', value: dateLong(d.scheduledFor!)),
              if ((d.addressSummary ?? '').isNotEmpty)
                _InfoRow(icon: Icons.place_outlined, label: 'Local', value: d.addressSummary!),
            ],
          ),
        ),
        if (d.description.isNotEmpty) ...[
          const SectionTitle('O que você pediu'),
          AppCard(child: Text(d.description, style: const TextStyle(height: 1.4))),
        ],
        if (d.photoPaths.isNotEmpty) ...[
          const SectionTitle('Fotos do seu pedido'),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: d.photoPaths.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _Thumb(
                size: 92,
                onTap: () => _zoom(d.photoPaths[i], 'Foto do pedido'),
                child: _image(context, d.photoPaths[i], BoxFit.cover),
              ),
            ),
          ),
        ],
        if (photos.isNotEmpty || video != null) ...[
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
                for (final e in photos)
                  _Thumb(
                    label: e.label,
                    onTap: () => _zoom(e.path, e.label),
                    child: _image(context, e.path, BoxFit.cover),
                  ),
              ],
            ),
          if (video != null) ...[
            const SizedBox(height: 12),
            _ServiceVideo(path: video),
          ],
        ],
        const SectionTitle('Pagamento'),
        AppCard(
          child: Column(
            children: [
              _InfoRow(icon: Icons.payments_outlined, label: 'Valor pago', value: brl(d.amount), strong: true),
              _InfoRow(icon: Icons.verified_outlined, label: 'Situação', value: _paymentLabel(d.paymentStatus)),
            ],
          ),
        ),
        if (d.report != null) ...[
          const SectionTitle('Relatório do profissional'),
          AppCard(child: Text(d.report!, style: const TextStyle(height: 1.4))),
        ],
        if (d.myReview != null) ...[
          const SectionTitle('Sua avaliação'),
          _ReviewCard(review: d.myReview!),
        ],
        if (provider != null) ...[
          const SectionTitle('Profissional'),
          AppCard(
            child: Row(
              children: [
                UserAvatar(url: provider.avatarUrl, name: friendlyName(provider.name, fallback: 'Profissional'), radius: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friendlyName(provider.name, fallback: 'Profissional'),
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
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: '💬 Ver conversa do serviço',
            onPressed: _openingChat ? null : () => _openChat(d),
          ),
        ],
      ],
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.strong = false});

  final IconData icon;
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.tk.textMuted),
          const SizedBox(width: 10),
          Text('$label: ', style: TextStyle(color: context.tk.textMuted)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700, fontSize: strong ? 16 : 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Miniatura tocável (zoom) com rótulo opcional.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.child, required this.onTap, this.label, this.size});

  final Widget child;
  final VoidCallback onTap;
  final String? label;
  final double? size;

  @override
  Widget build(BuildContext context) {
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
              ColoredBox(color: context.tk.card, child: child),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/chat_models.dart';
import '../../../core/models/marketplace_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/social_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/widgets.dart' show friendlyError;
import '../../../core/utils/format.dart';
import '../../../core/utils/ids.dart';

/// Fonte de dados do chat. A tela só conhece esta interface; em produção é o
/// [SupabaseChatBackend] e nos testes entra um fake (sem rede).
abstract class ChatBackend {
  /// `auth.uid()` de quem usa o app.
  String get currentUserId;

  /// Mensagens da conversa (Realtime), já em ordem cronológica.
  Stream<List<ChatMessage>> messages(String jobId, String providerId);

  /// Estado do serviço, para a conversa virar somente leitura ao encerrar.
  Stream<Job?> job(String jobId);

  Future<ChatCounterpart?> counterpart(String jobId, String providerId);

  Future<void> send({
    required String jobId,
    required String providerId,
    required String body,
    required String clientMessageId,
    String kind = 'text',
    Map<String, dynamic>? meta,
  });
}

/// Implementação de produção (Supabase).
class SupabaseChatBackend implements ChatBackend {
  SupabaseChatBackend() : _social = SocialService(), _jobs = JobService();

  final SocialService _social;
  final JobService _jobs;

  @override
  String get currentUserId => Supabase.instance.client.auth.currentUser!.id;

  @override
  Stream<List<ChatMessage>> messages(String jobId, String providerId) =>
      _social.streamMessages(jobId, providerId);

  @override
  Stream<Job?> job(String jobId) => _jobs.streamJob(jobId);

  @override
  Future<ChatCounterpart?> counterpart(String jobId, String providerId) =>
      _social.chatCounterpart(jobId, providerId);

  @override
  Future<void> send({
    required String jobId,
    required String providerId,
    required String body,
    required String clientMessageId,
    String kind = 'text',
    Map<String, dynamic>? meta,
  }) =>
      _social.sendMessage(
        jobId: jobId,
        providerId: providerId,
        body: body,
        kind: kind,
        meta: meta,
        clientMessageId: clientMessageId,
      );
}

/// Chat seguro por demanda entre cliente e profissional.
/// [providerId] identifica a conversa (cada profissional que orçou tem a sua).
///
/// Fica SOMENTE LEITURA ([readOnly] ou serviço `completed`/`canceled`): o banco
/// também recusa novas mensagens (`CHAT_ARCHIVED`), a UI só evita o erro.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.job,
    required this.providerId,
    this.peerName,
    this.peerAvatar,
    this.readOnly = false,
    @visibleForTesting this.backend,
  });

  final Job job;
  final String providerId;

  /// Nome provisório do interlocutor (até a RPC `chat_counterpart` responder).
  final String? peerName;
  final String? peerAvatar;
  final bool readOnly;

  /// Só para testes: substitui o acesso ao Supabase.
  final ChatBackend? backend;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatBackend _backend = widget.backend ?? SupabaseChatBackend();
  late final ChatThread _thread = ChatThread(me: _backend.currentUserId);
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  StreamSubscription<List<ChatMessage>>? _msgSub;
  StreamSubscription<Job?>? _jobSub;

  late Job _job = widget.job;
  ChatCounterpart? _peer;
  bool _loaded = false;
  bool _loadFailed = false;

  /// Lock de envio (botão E teclado): impede duplo toque/Enter durante o await.
  bool _isSending = false;
  bool _locating = false;

  /// O banco recusou por `CHAT_ARCHIVED` antes de o stream do job avisar.
  bool _archivedByServer = false;

  @override
  void initState() {
    super.initState();
    _msgSub = _backend.messages(widget.job.id, widget.providerId).listen(
      _onMessages,
      onError: (Object _) {
        if (mounted) setState(() => _loadFailed = true);
      },
    );
    if (!widget.readOnly) {
      _jobSub = _backend.job(widget.job.id).listen(
        (j) {
          if (j != null && mounted) setState(() => _job = j);
        },
        onError: (Object _) {}, // sem o stream do job a conversa continua utilizável
      );
    }
    _loadPeer();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _jobSub?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _readOnly =>
      widget.readOnly ||
      _archivedByServer ||
      _job.status == JobStatus.completed ||
      _job.status == JobStatus.canceled;

  Future<void> _loadPeer() async {
    try {
      final p = await _backend.counterpart(widget.job.id, widget.providerId);
      if (mounted && p != null) setState(() => _peer = p);
    } catch (_) {
      // Mantém peerName/peerAvatar recebidos; o cabeçalho nunca fica sem nome.
    }
  }

  // ----------------------------------------------------------------- scroll

  /// Perto do fim = o usuário está acompanhando a conversa (não lendo histórico).
  bool get _nearBottom =>
      !_scroll.hasClients ||
      _scroll.position.maxScrollExtent - _scroll.position.pixels < 120;

  void _scrollToEnd({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      final dur = AppMotion.d(context, const Duration(milliseconds: 250));
      if (animate && dur > Duration.zero) {
        _scroll.animateTo(end, duration: dur, curve: AppMotion.fadeCurve);
      } else {
        _scroll.jumpTo(end);
      }
    });
  }

  void _onMessages(List<ChatMessage> msgs) {
    if (!mounted) return;
    final first = !_loaded;
    final wasNear = _nearBottom;
    final before = _thread.items.length;
    setState(() {
      _thread.merge(msgs);
      _loaded = true;
      _loadFailed = false;
    });
    final items = _thread.items;
    if (first) {
      _scrollToEnd(animate: false);
    } else if (items.length > before && (wasNear || items.last.mine)) {
      // Só auto-rola se o usuário já estava no fim ou a mensagem é dele.
      _scrollToEnd();
    }
  }

  // ------------------------------------------------------------------ envio

  Future<void> _send({
    String? text,
    String kind = 'text',
    Map<String, dynamic>? meta,
  }) async {
    final body = (text ?? _controller.text).trim();
    if (body.isEmpty || _isSending || _readOnly) return;
    // O id nasce AQUI (uma vez por mensagem) e acompanha qualquer reenvio.
    final pending = _thread.addPending(
      clientMessageId: uuidV4(),
      jobId: widget.job.id,
      providerId: widget.providerId,
      body: body,
      kind: kind,
      meta: meta,
    );
    if (text == null) _controller.clear();
    setState(() {});
    _scrollToEnd();
    await _dispatch(pending);
  }

  Future<void> _retry(ChatItem item) async {
    final cid = item.message.clientMessageId;
    if (cid == null || _isSending) return;
    final msg = _thread.retry(cid);
    if (msg == null) return;
    setState(() {});
    await _dispatch(msg);
  }

  Future<void> _dispatch(ChatMessage m) async {
    final cid = m.clientMessageId!;
    setState(() => _isSending = true);
    try {
      await _backend.send(
        jobId: m.jobId,
        providerId: m.providerId,
        body: m.body,
        kind: m.kind,
        meta: m.meta,
        clientMessageId: cid,
      );
      // Se o eco do Realtime já chegou, a otimista já foi trocada e isto é no-op.
      if (mounted) setState(() => _thread.markSent(cid));
    } on ChatArchivedException {
      if (mounted) {
        setState(() {
          _thread.discard(cid); // reenviar não adianta: o chat está arquivado
          _archivedByServer = true;
        });
        AppSnackbar.show(
          context,
          ChatArchivedException.userMessage,
          kind: AppSnackKind.error,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _thread.markFailed(cid));
        AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _shareLocation() async {
    if (_locating || _isSending) return;
    _locating = true;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          AppSnackbar.show(
            context,
            'Permissão de localização negada.',
            kind: AppSnackKind.error,
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      await _send(
        text: 'Localização compartilhada',
        kind: 'location',
        meta: {'lat': pos.latitude, 'lng': pos.longitude},
      );
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          'Não foi possível obter a localização.',
          kind: AppSnackKind.error,
        );
      }
    } finally {
      _locating = false;
    }
  }

  // ------------------------------------------------------------------- build

  Widget _title() {
    final tk = context.tk;
    final peerIsProvider = _backend.currentUserId == _job.clientId;
    final name = pickDisplayName(
      [_peer?.name, widget.peerName],
      fallback: peerIsProvider ? 'Profissional' : 'Cliente',
    );
    final avatar = _peer?.avatarUrl ?? widget.peerAvatar;
    final subtitle =
        _peer != null && _peer!.isProvider ? _peer!.subtitle?.trim() : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppAvatar(url: avatar, name: name, radius: 18),
        const SizedBox(width: AppSpace.s12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 2,
                style: AppType.bodyStrong.copyWith(color: tk.text),
              ),
              if (subtitle != null && subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  style: AppType.caption.copyWith(color: tk.textMuted),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _messages() {
    final items = _thread.items;
    if (_loadFailed && items.isEmpty) {
      return const AppErrorState(
        message: 'Não foi possível carregar a conversa.',
      );
    }
    final readOnly = _readOnly;
    // [nota de segurança] + (vazio ? convite : balões). Lista NÃO reversa:
    // antiga no topo, nova na base.
    final extra = items.isEmpty ? 2 : 1;
    final list = ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.symmetric(
        horizontal: context.layout.margin,
        vertical: AppSpace.s16,
      ),
      itemCount: items.length + extra,
      itemBuilder: (context, i) {
        if (i == 0) {
          return const _SystemNote(
            'Conversa segura da Desperrengue. Combine os detalhes aqui; o pagamento permanece protegido no app.',
          );
        }
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSpace.s24),
            child: AppEmptyState(
              icon: readOnly
                  ? Icons.chat_bubble_outline_rounded
                  : Icons.waving_hand_rounded,
              title: readOnly ? 'Nenhuma mensagem nesta conversa.' : 'Diga olá',
              message: readOnly
                  ? null
                  : 'Envie uma mensagem para alinhar os detalhes do serviço.',
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s16,
                vertical: AppSpace.s24,
              ),
            ),
          );
        }
        final item = items[i - 1];
        return _MessageEntrance(
          key: ValueKey(item.key),
          child: _Bubble(
            item: item,
            onRetry:
                item.status == ChatItemStatus.failed ? () => _retry(item) : null,
          ),
        );
      },
    );
    return AppSkeletonSwitcher(
      loading: !_loaded,
      skeleton: const AppSkeletonList(count: 5),
      child: list,
    );
  }

  Widget _composer() {
    final tk = context.tk;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tk.surfaceAt(1),
        border: Border(top: BorderSide(color: tk.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s8,
            vertical: AppSpace.s8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppIconButton(
                icon: Icons.location_on_outlined,
                tooltip: 'Compartilhar localização',
                color: tk.accentInk,
                onPressed: _shareLocation,
              ),
              const SizedBox(width: AppSpace.s4),
              Expanded(
                child: AppTextField(
                  controller: _controller,
                  hint: 'Digitar mensagem...',
                  semanticLabel: 'Digitar mensagem',
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [LengthLimitingTextInputFormatter(2000)],
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              AppIconButton(
                tooltip: 'Enviar',
                icon: Icons.send_rounded,
                size: 20,
                filled: true,
                onPressed: _isSending ? null : _send,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final readOnly = _readOnly;
    return AppScaffold(
      backgroundColor: tk.surface,
      appBar: AppAppBar(
        centerTitle: false,
        titleWidget: _title(),
        actions: [
          if (!readOnly)
            AppIconButton(
              tooltip: 'Chamada pelo app',
              icon: Icons.phone_in_talk_rounded,
              color: tk.accentInk,
              onPressed: () => AppSnackbar.show(
                context,
                'Chamadas pelo app chegam em breve. Use o chat por enquanto.',
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: tk.card,
              border: Border(bottom: BorderSide(color: tk.border)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.layout.margin,
                vertical: AppSpace.s12,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.home_repair_service_rounded,
                    size: 18,
                    color: tk.accentInk,
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Serviço: ',
                            style: AppType.bodySm.copyWith(color: tk.textMuted),
                          ),
                          TextSpan(
                            text: _job.title,
                            style: AppType.bodySm.copyWith(
                              fontWeight: FontWeight.w700,
                              color: tk.text,
                            ),
                          ),
                          if (_job.scheduledFor != null)
                            TextSpan(
                              text: '  |  ${dateShort(_job.scheduledFor!)}',
                              style: AppType.tabular(AppType.bodySm)
                                  .copyWith(color: tk.textMuted),
                            ),
                        ],
                      ),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _messages()),
          if (readOnly) _ArchivedBanner(job: _job) else _composer(),
        ],
      ),
    );
  }
}

/// Entrada suave de mensagem: slide de 8 px + fade em 140 ms ([AppMotion.message]).
/// Respeita `MediaQuery.disableAnimations` via [AppMotion.reduced].
class _MessageEntrance extends StatefulWidget {
  const _MessageEntrance({super.key, required this.child});

  final Widget child;

  @override
  State<_MessageEntrance> createState() => _MessageEntranceState();
}

class _MessageEntranceState extends State<_MessageEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _curve;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    if (AppMotion.reduced(context)) return;
    final c = AnimationController(vsync: this, duration: AppMotion.message);
    _controller = c;
    _curve = CurvedAnimation(parent: c, curve: AppMotion.fadeCurve);
    c.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = _curve;
    if (curve == null) return widget.child;
    return AnimatedBuilder(
      animation: curve,
      child: widget.child,
      builder: (context, child) => FadeTransition(
        opacity: curve,
        child: Transform.translate(
          offset: Offset(0, (1 - curve.value) * AppSpace.s8),
          child: child,
        ),
      ),
    );
  }
}

/// Faixa no lugar da barra de digitação quando a conversa está arquivada.
class _ArchivedBanner extends StatelessWidget {
  const _ArchivedBanner({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final canceled = job.status == JobStatus.canceled;
    final when = job.approvedAt ?? job.finishedAt ?? job.createdAt;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s12,
          AppSpace.s8,
          AppSpace.s12,
          AppSpace.s12,
        ),
        child: AppCard(
          variant: AppCardVariant.tonal,
          color: tk.securitySoft,
          borderColor: tk.security.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s16,
            vertical: AppSpace.s12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s2),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: tk.security,
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  '${canceled ? 'Serviço cancelado' : 'Serviço finalizado'} em ${dateLong(when)}. '
                  'Este histórico de conversa está arquivado para sua segurança.',
                  style: AppType.bodySm.copyWith(
                    color: tk.text,
                    fontWeight: FontWeight.w600,
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

class _SystemNote extends StatelessWidget {
  const _SystemNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s12),
      child: AppCard(
        variant: AppCardVariant.outlined,
        padding: const EdgeInsets.all(AppSpace.s12),
        radius: AppGeometry.itemRadius,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s2),
              child: Icon(
                Icons.shield_outlined,
                size: 18,
                color: tk.security,
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: Text(
                text,
                style: AppType.caption.copyWith(color: tk.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.item, this.onRetry});

  final ChatItem item;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final message = item.message;
    final mine = item.mine;
    final failed = item.status == ChatItemStatus.failed;
    final isLocation = message.kind == 'location';
    final bg = failed ? tk.dangerSoft : (mine ? tk.accent : tk.card);
    final fg = failed ? tk.dangerInk : (mine ? tk.onAccent : tk.text);
    final meta = failed
        ? tk.dangerInk
        : (mine ? tk.onAccent.withValues(alpha: 0.78) : tk.textMuted);

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpace.s4),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: AppSpace.s12,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: borderRadius,
        border: mine || failed ? null : Border.all(color: tk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isLocation)
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s2),
                  child: Icon(Icons.location_on_rounded, size: 18, color: fg),
                ),
                const SizedBox(width: AppSpace.s4),
                Flexible(
                  child: Text(
                    message.body,
                    style: AppType.body.copyWith(color: fg),
                  ),
                ),
              ],
            )
          else
            Text(message.body, style: AppType.body.copyWith(color: fg)),
          const SizedBox(height: AppSpace.s4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (failed) ...[
                Icon(Icons.error_outline_rounded, size: 14, color: meta),
                const SizedBox(width: AppSpace.s4),
                Text(
                  'Toque para reenviar',
                  style: AppType.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: meta,
                  ),
                ),
              ] else ...[
                Text(
                  hhmm(message.createdAt.toLocal()),
                  style: AppType.tabular(AppType.caption).copyWith(color: meta),
                ),
                // Tique só nas MINHAS: relógio enviando -> dois tiques confirmada.
                if (mine) ...[
                  const SizedBox(width: AppSpace.s4),
                  Icon(
                    item.status == ChatItemStatus.sending
                        ? Icons.schedule
                        : Icons.done_all,
                    size: 14,
                    color: meta,
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: onRetry == null
          ? bubble
          : AppPressable(
              onTap: onRetry,
              borderRadius: borderRadius,
              semanticLabel: 'Reenviar mensagem',
              child: bubble,
            ),
    );
  }
}

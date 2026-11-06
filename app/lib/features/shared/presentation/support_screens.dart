import '../../../core/ui/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/marketplace_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/job_service.dart';
import '../../client/presentation/detalhe_servico_cliente_screen.dart';
import '../../provider/presentation/provider_job_screen.dart';

import '../../../core/services/media_service.dart';
import '../../../core/services/social_service.dart';
import '../../../core/ui/image_picking.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/ui/app_tokens.dart';

String protocolOf(String ticketId) => '#DSP-${ticketId.replaceAll('-', '').substring(0, 4).toUpperCase()}';

/// "Relatar problema / disputa" (protótipo 09 do cliente; 11 e 12 do profissional).
/// Ao abrir o chamado de um serviço em andamento, o pagamento fica retido.
class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key, this.job, required this.asProvider, this.initialReason});

  final Job? job;
  final bool asProvider;
  final String? initialReason;

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _desc = TextEditingController();
  final _images = <PickedImage>[];
  late String _reason;
  bool _busy = false;

  List<String> get _reasons {
    if (widget.job == null) {
      return ['Dúvida sobre pagamento', 'Problema com a conta', 'Sugestão ou elogio', 'Outros'];
    }
    return widget.asProvider
        ? ['O cliente não tem o código', 'Cliente ausente no local', 'Endereço incorreto ou inseguro', 'Outros']
        : ['O profissional não compareceu', 'O serviço não foi finalizado', 'Danos à propriedade', 'Outros'];
  }

  @override
  void initState() {
    super.initState();
    _reason = widget.initialReason ?? _reasons.first;
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_desc.text.trim().length < 10) {
      showSnack(context, 'Descreva o ocorrido (mín. 10 caracteres).', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final media = MediaService();
      final paths = <String>[];
      for (final img in _images) {
        paths.add(await media.uploadPrivate(img.bytes, img.ext, prefix: 'ticket'));
      }
      final id = await SocialService().createTicket(
        jobId: widget.job?.id,
        reason: _reason,
        description: _desc.text.trim(),
        evidencePaths: paths,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TicketCreatedScreen(ticketId: id, hasJob: widget.job != null, asProvider: widget.asProvider)),
      );
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: Text(widget.job == null ? 'Novo chamado' : 'Relatar problema')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(widget.job == null ? 'Como podemos ajudar?' : 'O que aconteceu com o seu serviço?',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          if (widget.job != null) ...[
            const SizedBox(height: 10),
            const InfoBanner(
              'Ao abrir o chamado, o pagamento do serviço permanece retido até a decisão da nossa equipe de mediação.',
              tone: BannerTone.security,
            ),
          ],
          const SizedBox(height: 14),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v ?? _reason),
            child: Column(
              children: [
                for (final r in _reasons)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: r,
                    title: Text(r, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text('Enviar fotos (recomendado)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          MediaPickerRow(images: _images, onAdd: () async {
            final img = await pickImage(context);
            if (img != null && mounted) setState(() => _images.add(img));
          }, onRemove: (i) => setState(() => _images.removeAt(i))),
          const SizedBox(height: 16),
          Text.rich(TextSpan(children: [
            TextSpan(text: 'Descreva o ocorrido ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            TextSpan(text: '*', style: TextStyle(color: context.tk.danger, fontWeight: FontWeight.w900)),
          ])),
          const SizedBox(height: 8),
          TextField(
            controller: _desc,
            maxLines: 5,
            maxLength: 2000,
            decoration: const InputDecoration(hintText: 'Conte o que houve em detalhes para que possamos ajudar você...'),
          ),
        ],
      ),
      bottomNavigationBar: BottomBar(child: PrimaryButton(label: 'Abrir chamado de suporte', loading: _busy, onPressed: _submit)),
    );
  }
}

/// Confirmação com protocolo e SLA de 24 h (protótipos 6/05 e profissional 12).
class TicketCreatedScreen extends StatelessWidget {
  const TicketCreatedScreen({super.key, required this.ticketId, required this.hasJob, required this.asProvider});

  final String ticketId;
  final bool hasJob;
  final bool asProvider;

  @override
  Widget build(BuildContext context) {
    final protocol = protocolOf(ticketId);
    return AppScaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Chamado aberto')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 12),
          Center(child: CircleAvatar(radius: 44, backgroundColor: context.tk.successSoft, child: Icon(Icons.shield_rounded, size: 46, color: context.tk.success))),
          const SizedBox(height: 16),
          const Text('Recebemos o seu chamado', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Center(
            child: ActionChip(
              avatar: const Icon(Icons.copy_rounded, size: 16),
              label: Text('Protocolo: $protocol', style: const TextStyle(fontWeight: FontWeight.w800)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: protocol));
                showSnack(context, 'Protocolo copiado.');
              },
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hasJob
                ? 'O pagamento fica retido com a Desperrengue enquanto analisamos. Suas fotos e informações do serviço já estão salvas no chamado.'
                : 'Nossa equipe responderá pelo app.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.45, color: context.tk.textMuted),
          ),
          const SizedBox(height: 14),
          const InfoBanner('Prazo de resposta (SLA): até 24 horas.', tone: BannerTone.warning, icon: Icons.schedule_rounded),
          if (hasJob) ...[
            const SizedBox(height: 10),
            InfoBanner(
              asProvider
                  ? 'Recomendamos que você saia do local em segurança. Deixe que nós resolvemos tudo por você.'
                  : 'Você pode continuar usando o app normalmente enquanto cuidamos do caso.',
              tone: BannerTone.warning,
              icon: Icons.warning_amber_rounded,
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomBar(
        child: PrimaryButton(label: 'Entendi', onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
      ),
    );
  }
}

/// Central de ajuda: mediações em andamento (só quando existem), chamados e novo chamado.
class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({
    super.key,
    this.asProvider = false,
    @visibleForTesting this.ticketsLoader,
    @visibleForTesting this.disputesLoader,
    @visibleForTesting this.onOpenMediation,
  });

  /// Usado para abrir o caso na visão certa (cliente ou profissional).
  final bool asProvider;
  final Future<List<Map<String, dynamic>>> Function()? ticketsLoader;
  final Future<List<Job>> Function()? disputesLoader;
  final void Function(BuildContext context, Job job)? onOpenMediation;

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> {
  late Future<({List<Map<String, dynamic>> tickets, List<Job> disputes})> _future = _load();

  Future<({List<Map<String, dynamic>> tickets, List<Job> disputes})> _load() async {
    final tickets = await (widget.ticketsLoader ?? SocialService().myTickets)();
    List<Job> disputes;
    try {
      disputes = await (widget.disputesLoader ?? JobService().fetchMyDisputes)();
    } catch (_) {
      disputes = const []; // a lista de mediações é um extra: nunca derruba a Central
    }
    return (tickets: tickets, disputes: disputes);
  }

  void _reload() => setState(() {
        _future = _load();
      });

  void _openCase(Job job) {
    if (widget.onOpenMediation != null) {
      widget.onOpenMediation!(context, job);
      return;
    }
    // Cliente: dossiê completo da mediação. Profissional: tela de mediação do serviço.
    final me = Supabase.instance.client.auth.currentUser?.id;
    final asClient = job.clientId == me && !widget.asProvider;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => asClient ? DetalheServicoClienteScreen(jobId: job.id) : ProviderJobScreen(jobId: job.id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('Ajuda e suporte')),
      body: FutureBuilder<({List<Map<String, dynamic>> tickets, List<Job> disputes})>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(message: 'Não foi possível carregar seus chamados.', onRetry: _reload);
          final items = snap.data!.tickets;
          final disputes = snap.data!.disputes;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const InfoBanner(
                'Respondemos em até 24 horas. Para problemas com um serviço específico, abra o chamado dentro do pedido: assim o pagamento fica protegido.',
                tone: BannerTone.info,
                title: 'Central Desperrengue',
              ),
              if (disputes.isNotEmpty) ...[
                const SectionTitle('Mediações em andamento'),
                for (final j in disputes) _MediationCard(job: j, asProvider: widget.asProvider, onTap: () => _openCase(j)),
              ],
              const SizedBox(height: 14),
              SecondaryButton(
                label: 'Abrir novo chamado',
                icon: Icons.add_comment_outlined,
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportProblemScreen(asProvider: widget.asProvider)));
                  _reload();
                },
              ),
              const SectionTitle('Meus chamados'),
              if (items.isEmpty)
                Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Nenhum chamado aberto.', style: TextStyle(color: context.tk.textMuted))))
              else
                for (final t in items)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(protocolOf(t['id'] as String), style: const TextStyle(fontWeight: FontWeight.w900)),
                            const Spacer(),
                            StatusChip(
                              switch (t['status']) { 'resolved' => 'Resolvido', 'in_review' => 'Em análise', _ => 'Aberto' },
                              color: t['status'] == 'resolved' ? context.tk.success : context.tk.warningInk,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(t['reason'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(relativeTime(DateTime.parse(t['created_at'] as String)), style: TextStyle(color: context.tk.textMuted, fontSize: 12.5)),
                        if (t['resolution'] != null) ...[
                          const SizedBox(height: 6),
                          Text('Resolução: ${t['resolution']}', style: const TextStyle(height: 1.35)),
                        ],
                      ],
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

/// Cartão de uma mediação em andamento (cliente ou profissional).
class _MediationCard extends StatelessWidget {
  const _MediationCard({required this.job, required this.asProvider, required this.onTap});

  final Job job;
  final bool asProvider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      key: ValueKey('mediation:${job.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      color: tk.dangerSoft,
      borderColor: tk.danger.withValues(alpha: 0.4),
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(radius: 22, backgroundColor: tk.danger.withValues(alpha: 0.18), child: Icon(Icons.gavel_rounded, color: tk.danger)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
                const SizedBox(height: 2),
                Text('${job.code} • ${asProvider ? 'Você é o profissional' : 'Você é o cliente'}', style: TextStyle(color: tk.textMuted, fontSize: 12.5)),
                const SizedBox(height: 6),
                const StatusChip('Em mediação', icon: Icons.gavel_rounded),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: tk.textMuted),
        ],
      ),
    );
  }
}

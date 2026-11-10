import '../../../core/ui/app_scaffold.dart';
import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/job_labels.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import 'detalhe_servico_cliente_screen.dart';

/// Carrega os serviços encerrados/em proteção/em mediação do cliente (produção: query em `jobs`).
typedef FinishedJobsLoader = Future<List<Job>> Function();

/// Histórico de serviços do cliente: concluídos, sob proteção pós-serviço, em mediação e cancelados.
/// Isolado estritamente para a visão de quem contratou (o cliente jamais vê o Histórico do Profissional).
class HistoricoServicosClienteScreen extends StatefulWidget {
  const HistoricoServicosClienteScreen({super.key, @visibleForTesting this.loader});

  final FinishedJobsLoader? loader;

  @override
  State<HistoricoServicosClienteScreen> createState() => _HistoricoServicosClienteScreenState();
}

class _HistoricoServicosClienteScreenState extends State<HistoricoServicosClienteScreen> {
  late Future<List<Job>> _future = _load();
  String _filter = 'all';

  Future<List<Job>> _load() => widget.loader != null ? widget.loader!() : JobService().fetchMyFinishedJobs();

  Future<void> _reload() async {
    final f = _load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {
      // O erro já é exibido pelo FutureBuilder.
    }
  }

  static bool _isUnderProtection(Job j) =>
      j.status == JobStatus.completed && j.paymentStatus == 'escrow';

  static bool _isSettledCompleted(Job j) =>
      j.status == JobStatus.completed && j.paymentStatus != 'escrow';

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppScaffold(
      backgroundColor: tk.surface,
      appBar: AppBar(title: const Text('Histórico de serviços')),
      body: FutureBuilder<List<Job>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) {
            return ErrorView(message: 'Não foi possível carregar seu histórico.', onRetry: _reload);
          }
          final jobs = snap.data ?? const <Job>[];
          if (jobs.isEmpty) {
            return const EmptyView(
              icon: Icons.history_rounded,
              title: 'Nenhum serviço encerrado ainda',
              subtitle: 'Quando um serviço for concluído ou cancelado, ele aparece aqui para você rever.',
            );
          }

          final settledCount = jobs.where(_isSettledCompleted).length;
          final protectionCount = jobs.where(_isUnderProtection).length;
          final disputedCount = jobs.where((j) => j.status == JobStatus.disputed).length;
          final canceledCount = jobs.where((j) => j.status == JobStatus.canceled).length;

          final filtered = switch (_filter) {
            'settled' => jobs.where(_isSettledCompleted).toList(),
            'protection' => jobs.where(_isUnderProtection).toList(),
            'mediation' => jobs.where((j) => j.status == JobStatus.disputed).toList(),
            'canceled' => jobs.where((j) => j.status == JobStatus.canceled).toList(),
            _ => jobs,
          };

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('Todos (${jobs.length})'),
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                    ChoiceChip(
                      label: Text('Concluídos ($settledCount)'),
                      selected: _filter == 'settled',
                      onSelected: (_) => setState(() => _filter = 'settled'),
                    ),
                    ChoiceChip(
                      label: Text('Sob Proteção Pós-Serviço ($protectionCount)'),
                      selected: _filter == 'protection',
                      onSelected: (_) => setState(() => _filter = 'protection'),
                    ),
                    ChoiceChip(
                      label: Text('Em Mediação ($disputedCount)'),
                      selected: _filter == 'mediation',
                      onSelected: (_) => setState(() => _filter = 'mediation'),
                    ),
                    ChoiceChip(
                      label: Text('Cancelados ($canceledCount)'),
                      selected: _filter == 'canceled',
                      onSelected: (_) => setState(() => _filter = 'canceled'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (filtered.isEmpty)
                  const EmptyView(
                    icon: Icons.filter_list_rounded,
                    title: 'Nenhum serviço nesta categoria',
                    subtitle: 'Selecione outro filtro acima para ver seus demais pedidos.',
                  )
                else
                  for (var i = 0; i < filtered.length; i++) ...[
                    _HistoryItem(job: filtered[i]),
                    if (i < filtered.length - 1) const SizedBox(height: 12),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final when = job.approvedAt ?? job.finishedAt ?? job.createdAt;
    final canceled = job.status == JobStatus.canceled;
    final underProtection = job.status == JobStatus.completed && job.paymentStatus == 'escrow';
    return AppCard(
      onTap: () => openClientServiceDetail(context, job.id),
      child: Row(
        children: [
          CategoryBrandEmblem(
            categoryName: job.category,
            size: 50,
            showCornerBadge: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '${job.code} • ${dateShort(when)}',
                  style: TextStyle(color: tk.textMuted, fontSize: 12.5),
                ),
                const SizedBox(height: 6),
                if (underProtection)
                  StatusChip(
                    'Sob Proteção Pós-Serviço',
                    color: tk.info,
                    icon: Icons.shield_moon_rounded,
                  )
                else
                  JobStatusChip(job),
              ],
            ),
          ),
          if (!canceled && job.agreedPrice != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(brl(job.agreedPrice), style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(
                    underProtection ? 'sob proteção' : 'pago',
                    style: TextStyle(color: tk.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          Icon(Icons.chevron_right_rounded, color: tk.textMuted),
        ],
      ),
    );
  }
}

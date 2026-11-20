import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/job_labels.dart';
import '../../../core/ui/media_widgets.dart';
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

  Future<List<Job>> _load() =>
      widget.loader != null ? widget.loader!() : JobService().fetchMyFinishedJobs();

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
    final margin = context.layout.margin;
    return AppScaffold(
      backgroundColor: tk.surface,
      appBar: const AppAppBar(title: 'Histórico de serviços'),
      body: FutureBuilder<List<Job>>(
        future: _future,
        builder: (context, snap) {
          final loading = snap.connectionState != ConnectionState.done;
          return AppSkeletonSwitcher(
            loading: loading,
            skeleton: AppSkeletonList(
              count: 4,
              padding: EdgeInsets.all(margin),
            ),
            child: _buildBody(context, snap, margin),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, AsyncSnapshot<List<Job>> snap, double margin) {
    if (snap.hasError) {
      return AppErrorState(
        message: 'Não foi possível carregar seu histórico.',
        retryLabel: 'Tentar novamente',
        onRetry: _reload,
      );
    }
    final jobs = snap.data ?? const <Job>[];
    if (jobs.isEmpty) {
      return const AppEmptyState(
        icon: Icons.history_rounded,
        title: 'Nenhum serviço encerrado ainda',
        message: 'Quando um serviço for concluído ou cancelado, ele aparece aqui para você rever.',
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
        padding: EdgeInsets.all(margin),
        children: [
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              ChoiceChip(
                label: Text(
                  'Todos (${jobs.length})',
                  style: AppType.tabular(AppType.bodySm),
                ),
                selected: _filter == 'all',
                onSelected: (_) => setState(() => _filter = 'all'),
              ),
              ChoiceChip(
                label: Text(
                  'Concluídos ($settledCount)',
                  style: AppType.tabular(AppType.bodySm),
                ),
                selected: _filter == 'settled',
                onSelected: (_) => setState(() => _filter = 'settled'),
              ),
              ChoiceChip(
                label: Text(
                  'Sob Proteção Pós-Serviço ($protectionCount)',
                  style: AppType.tabular(AppType.bodySm),
                ),
                selected: _filter == 'protection',
                onSelected: (_) => setState(() => _filter = 'protection'),
              ),
              ChoiceChip(
                label: Text(
                  'Em Mediação ($disputedCount)',
                  style: AppType.tabular(AppType.bodySm),
                ),
                selected: _filter == 'mediation',
                onSelected: (_) => setState(() => _filter = 'mediation'),
              ),
              ChoiceChip(
                label: Text(
                  'Cancelados ($canceledCount)',
                  style: AppType.tabular(AppType.bodySm),
                ),
                selected: _filter == 'canceled',
                onSelected: (_) => setState(() => _filter = 'canceled'),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s16),
          if (filtered.isEmpty)
            const AppEmptyState(
              icon: Icons.filter_list_rounded,
              title: 'Nenhum serviço nesta categoria',
              message: 'Selecione outro filtro acima para ver seus demais pedidos.',
            )
          else
            for (var i = 0; i < filtered.length; i++) ...[
              AppStaggerItem(
                index: i,
                scope: 'client-history',
                child: _HistoryItem(job: filtered[i]),
              ),
              if (i < filtered.length - 1) const SizedBox(height: AppSpace.item),
            ],
        ],
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
    final stack = context.layout.isLargeText;
    final priceBlock = (!canceled && job.agreedPrice != null)
        ? Column(
            crossAxisAlignment: stack ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Text(
                brl(job.agreedPrice),
                style: AppType.tabular(AppType.bodyStrong).copyWith(
                  fontWeight: FontWeight.w700,
                  color: tk.text,
                ),
              ),
              Text(
                underProtection ? 'sob proteção' : 'pago',
                style: AppType.caption.copyWith(color: tk.textMuted),
              ),
            ],
          )
        : null;

    return AppCard(
      variant: AppCardVariant.elevated,
      onTap: () => openClientServiceDetail(context, job.id),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppHero(
            tag: 'order-card-${job.id}',
            child: CategoryBrandEmblem(
              categoryName: job.category,
              size: 50,
              showCornerBadge: false,
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.title,
                  style: AppType.titleSm.copyWith(color: tk.text),
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  '${job.code} • ${dateShort(when)}',
                  style: AppType.tabular(AppType.caption).copyWith(color: tk.textMuted),
                ),
                const SizedBox(height: AppSpace.s8),
                if (underProtection)
                  const AppStatusChip(
                    'Sob Proteção Pós-Serviço',
                    tone: AppTone.success,
                    icon: Icons.verified_user_rounded,
                  )
                else
                  JobStatusChip(job),
                if (stack && priceBlock != null) ...[
                  const SizedBox(height: AppSpace.s8),
                  priceBlock,
                ],
              ],
            ),
          ),
          if (!stack && priceBlock != null) ...[
            const SizedBox(width: AppSpace.s8),
            priceBlock,
          ],
          const SizedBox(width: AppSpace.s4),
          Icon(Icons.chevron_right_rounded, color: tk.textMuted),
        ],
      ),
    );
  }
}

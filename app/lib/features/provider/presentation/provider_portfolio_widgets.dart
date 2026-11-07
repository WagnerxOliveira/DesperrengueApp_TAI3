import 'package:flutter/material.dart';

import '../../../core/models/provider_portfolio_models.dart';
import '../../../core/state/provider_portfolio_controller.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';

/// Seção completa do **"Meu Portfólio" Inteligente + "Histórico de Serviços Prestados"**
/// governada por validação de PIN do Cliente.
class ProviderSmartPortfolioSection extends StatelessWidget {
  const ProviderSmartPortfolioSection({
    super.key,
    this.isOwner = true,
    this.showSimulationControls = true,
  });

  final bool isOwner;
  final bool showSimulationControls;

  @override
  Widget build(BuildContext context) {
    final store = ProviderPortfolioStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final state = store.state;
        final tk = context.tk;
        final topThree = state.automaticTopThree;
        final curated = state.curatedPortfolioServices;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Banner Explicativo no Topo
            Container(
              key: const ValueKey('portfolio-explanatory-banner'),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tk.providerSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: tk.providerAccent.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    color: tk.providerAccent,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Seu Portfólio exibe automaticamente os 3 últimos serviços validados pelo código PIN do cliente. '
                      'A partir do seu 4º serviço concluído, os serviços anteriores ficam salvos para sempre no seu '
                      'Histórico de Serviços Prestados, e você pode escolher até 3 deles (1 por vez) para destacar aqui.',
                      style: TextStyle(
                        fontSize: 12.8,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: tk.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Acesso rápido ao "Histórico de Serviços Prestados" + Controles de Simulação PIN
            AppCard(
              key: const ValueKey('open-full-history-card'),
              onTap: () => ProviderFullHistoryScreen.open(context),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: tk.infoSoft,
                    child: Icon(Icons.history_edu_rounded, color: tk.info),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Histórico de Serviços Prestados',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${state.totalCompletedCount} serviços validados via PIN • Registro permanente imutável',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: tk.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    'Ver todos (${state.totalCompletedCount})',
                    color: tk.info,
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: tk.textMuted),
                ],
              ),
            ),

            if (isOwner && showSimulationControls) ...[
              const SizedBox(height: 10),
              _PinSimulationToolbar(state: state),
            ],

            const SizedBox(height: 18),

            // 3. Seção 1 — "Últimos 3 Serviços Realizados (Atualização Automática via PIN)"
            Row(
              children: [
                Icon(Icons.workspace_premium_rounded, size: 20, color: tk.providerAccent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Últimos 3 Serviços Realizados (Atualização Automática via PIN)',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Sempre que um serviço é finalizado com o PIN do cliente, ele entra automaticamente em #1.',
              style: TextStyle(fontSize: 12.5, color: tk.textMuted),
            ),
            const SizedBox(height: 10),

            if (topThree.isEmpty)
              AppCard(
                key: const ValueKey('portfolio-top3-empty'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nenhum serviço validado por PIN ainda',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assim que você concluir seu 1º atendimento inserindo o código PIN do cliente, ele aparecerá automaticamente aqui.',
                      style: TextStyle(color: tk.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              for (var i = 0; i < topThree.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CompletedServicePortfolioCard(
                    key: ValueKey('portfolio-top3-card-$i-${topThree[i].id}'),
                    service: topThree[i],
                    positionBadge: i == 0 ? '#1 Mais Recente' : '#${i + 1}',
                    isAutomaticTopThree: true,
                    onTap: () => PortfolioServiceDetailSheet.show(
                      context,
                      serviceId: topThree[i].id,
                    ),
                  ),
                ),

            const SizedBox(height: 18),

            // 4. Seção 2 — "Destaques Escolhidos do Meu Histórico (Até 3 serviços)"
            Row(
              children: [
                Icon(Icons.push_pin_rounded, size: 20, color: tk.providerAccent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Destaques Escolhidos do Meu Histórico (Até 3 serviços)',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                StatusChip(
                  '${curated.length}/3',
                  color: tk.providerAccent,
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (!state.isAddFromHistoryUnlocked)
              // REGRA ESTRITA: Quando totalCompletedCount <= 3, NÃO renderizar o botão de adicionar!
              Container(
                key: const ValueKey('portfolio-curated-locked-card'),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tk.warningSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: tk.warningInk.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_clock_rounded, color: tk.warningInk, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Conclua seu 4º serviço (atualmente ${state.totalCompletedCount}/3 nos últimos serviços) '
                        'para desbloquear a escolha de até 3 serviços adicionais do seu Histórico.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.38,
                          fontWeight: FontWeight.w700,
                          color: tk.warningInk,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              if (curated.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Você já desbloqueou o Histórico! Escolha até 3 serviços anteriores (1 por vez) para destacar na sua vitrine.',
                    style: TextStyle(fontSize: 13, color: tk.textMuted),
                  ),
                ),
              for (var i = 0; i < curated.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CompletedServicePortfolioCard(
                    key: ValueKey('portfolio-curated-card-$i-${curated[i].id}'),
                    service: curated[i],
                    positionBadge: 'Destaque Escolhido ${i + 1}/3',
                    isAutomaticTopThree: false,
                    onTap: () => PortfolioServiceDetailSheet.show(
                      context,
                      serviceId: curated[i].id,
                    ),
                    onRemoveFromPortfolio: isOwner
                        ? () {
                            store.removeCuratedServiceFromPortfolio(
                              curated[i].id,
                            );
                            showSnack(
                              context,
                              'Serviço removido dos destaques (continua salvo no seu Histórico).',
                            );
                          }
                        : null,
                    onSwapFromHistory: (isOwner && state.availableToCurate.isNotEmpty)
                        ? () => _openHistoryPickerSheet(
                              context,
                              swapOldServiceId: curated[i].id,
                            )
                        : null,
                  ),
                ),
              if (isOwner && state.canAddMoreCuratedServices)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('btn-add-from-history-one-by-one'),
                    onPressed: () => _openHistoryPickerSheet(context),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: Text(
                      'Adicionar serviço do Histórico (+1 por vez • ${curated.length}/3)',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _openHistoryPickerSheet(
    BuildContext context, {
    String? swapOldServiceId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        final store = ProviderPortfolioStore.instance;
        return ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final state = store.state;
            final available = state.availableToCurate;
            final tk = context.tk;
            return FractionallySizedBox(
              heightFactor: 0.78,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      swapOldServiceId != null
                          ? 'Trocar por outro serviço do Histórico'
                          : 'Escolher 1 serviço do Histórico (${state.curatedPortfolioServices.length}/3)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Apenas serviços concluídos que já saíram dos 3 mais recentes aparecem aqui. Selecione 1 por vez:',
                      style: TextStyle(fontSize: 13, color: tk.textMuted),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: available.isEmpty
                          ? const EmptyView(
                              icon: Icons.inventory_2_outlined,
                              title: 'Nenhum outro serviço elegível disponível',
                              subtitle:
                                  'Conclua novos serviços com o PIN do cliente para ampliar seu Histórico.',
                            )
                          : ListView.separated(
                              itemCount: available.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final s = available[i];
                                return AppCard(
                                  key: ValueKey('picker-eligible-item-${s.id}'),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          StatusChip(
                                            s.categoryName,
                                            color: tk.providerAccent,
                                          ),
                                          StatusChip(
                                            'PIN ${s.validatedClientPin} Validado',
                                            color: tk.success,
                                            icon: Icons.verified_rounded,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        s.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        s.detailedExecutionReport,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: tk.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          key: ValueKey(
                                            'confirm-pick-service-${s.id}',
                                          ),
                                          onPressed: () {
                                            final ok = swapOldServiceId != null
                                                ? store
                                                    .swapCuratedServiceInPortfolio(
                                                      oldServiceId:
                                                          swapOldServiceId,
                                                      newServiceId: s.id,
                                                    )
                                                : store
                                                    .addServiceFromHistoryToPortfolio(
                                                      s.id,
                                                    );
                                            Navigator.of(ctx).pop();
                                            if (ok && context.mounted) {
                                              showSnack(
                                                context,
                                                swapOldServiceId != null
                                                    ? 'Destaque substituído com sucesso no Meu Portfólio!'
                                                    : 'Serviço adicionado com sucesso ao Meu Portfólio (+1)!',
                                              );
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.add_task_rounded,
                                            size: 18,
                                          ),
                                          label: Text(
                                            swapOldServiceId != null
                                                ? 'Substituir por este serviço'
                                                : 'Destacar este serviço (+1)',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Barra de simulação interativa para testar em tempo real a conclusão via PIN
/// (1º, 2º, 3º, 4º, 5º+ serviço) e a trava antes do 4º serviço.
class _PinSimulationToolbar extends StatelessWidget {
  const _PinSimulationToolbar({required this.state});

  final ProviderPortfolioState state;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final store = ProviderPortfolioStore.instance;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tk.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pin_rounded, size: 18, color: tk.providerAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Simulador de Gatilho por PIN do Cliente (${state.totalCompletedCount} concluídos)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('btn-simulate-next-pin-service'),
                onPressed: () {
                  final added = store.simulateNextPinCompletedService();
                  showSnack(
                    context,
                    'Novo serviço validado com PIN ${added.validatedClientPin}! Entrou em #1 no Meu Portfólio.',
                  );
                },
                icon: const Icon(Icons.verified_rounded, size: 17),
                label: Text(
                  'Concluir ${state.totalCompletedCount + 1}º Serviço com PIN',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('btn-simulate-3-services-locked'),
                onPressed: () {
                  store.resetToCount(3);
                  showSnack(
                    context,
                    'Estado ajustado para 3 serviços concluídos (escolha do Histórico bloqueada até o 4º).',
                  );
                },
                icon: const Icon(Icons.looks_3_outlined, size: 17),
                label: const Text(
                  'Testar com 3 serviços',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('btn-simulate-5-services-unlocked'),
                onPressed: () {
                  store.resetToCount(5);
                  showSnack(
                    context,
                    'Estado ajustado para 5 serviços concluídos (Top 3 + 2 elegíveis no Histórico).',
                  );
                },
                icon: const Icon(Icons.looks_5_outlined, size: 17),
                label: const Text(
                  'Testar com 5 serviços',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card rico de um serviço concluído e validado via PIN (usado no Portfólio e no Histórico).
class CompletedServicePortfolioCard extends StatelessWidget {
  const CompletedServicePortfolioCard({
    super.key,
    required this.service,
    required this.positionBadge,
    required this.isAutomaticTopThree,
    required this.onTap,
    this.onRemoveFromPortfolio,
    this.onSwapFromHistory,
  });

  final CompletedServiceRecord service;
  final String positionBadge;
  final bool isAutomaticTopThree;
  final VoidCallback onTap;
  final VoidCallback? onRemoveFromPortfolio;
  final VoidCallback? onSwapFromHistory;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(
                positionBadge,
                color: isAutomaticTopThree ? tk.providerAccent : tk.info,
                icon: isAutomaticTopThree
                    ? Icons.auto_awesome_rounded
                    : Icons.push_pin_rounded,
              ),
              StatusChip(
                'PIN Validado (${service.validatedClientPin})',
                color: tk.success,
                icon: Icons.verified_rounded,
              ),
              StatusChip(
                service.categoryName,
                color: tk.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            service.title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15.5,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            service.detailedExecutionReport,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: tk.textMuted,
              height: 1.38,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_available_rounded, size: 15, color: tk.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    dateShort(service.completedAt),
                    style: TextStyle(fontSize: 12, color: tk.textMuted, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.place_outlined, size: 15, color: tk.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    service.cityAndState,
                    style: TextStyle(fontSize: 12, color: tk.textMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.payments_outlined, size: 15, color: tk.success),
                  const SizedBox(width: 4),
                  Text(
                    brl(service.serviceValue),
                    style: TextStyle(fontSize: 12, color: tk.successInk, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Bloco resumido de Avaliação do Cliente (Sincronização Reativa)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: service.isReviewedByClient ? tk.successSoft : tk.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: service.isReviewedByClient
                    ? tk.success.withValues(alpha: 0.35)
                    : tk.border,
              ),
            ),
            child: service.isReviewedByClient
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star_rounded, size: 17, color: tk.warningInk),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Avaliação do cliente: ${(service.clientRating ?? 5.0).toStringAsFixed(1).replaceAll('.', ',')} ★',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                                color: tk.successInk,
                              ),
                            ),
                          ),
                          if (service.clientDisplayName != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              service.clientDisplayName!,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: tk.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if ((service.clientReviewComment ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '"${service.clientReviewComment}"',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.2,
                            fontStyle: FontStyle.italic,
                            color: tk.text,
                          ),
                        ),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      Icon(Icons.hourglass_top_rounded, size: 16, color: tk.warningInk),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '⏳ Aguardando avaliação do cliente (sincroniza automaticamente quando enviada)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: tk.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Toque para ver relatório técnico completo e fotos',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: tk.providerAccent,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.open_in_new_rounded, size: 15, color: tk.providerAccent),
            ],
          ),

          if (onRemoveFromPortfolio != null || onSwapFromHistory != null) ...[
            const Divider(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (onSwapFromHistory != null)
                  TextButton.icon(
                    key: ValueKey('btn-swap-curated-${service.id}'),
                    onPressed: onSwapFromHistory,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text(
                      'Trocar por outro do Histórico',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                if (onRemoveFromPortfolio != null)
                  TextButton.icon(
                    key: ValueKey('btn-remove-curated-${service.id}'),
                    onPressed: onRemoveFromPortfolio,
                    icon: Icon(Icons.bookmark_remove_outlined, size: 16, color: tk.danger),
                    label: Text(
                      'Remover do Portfólio (mantém no Histórico)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tk.danger,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Modal detalhado ao clicar em qualquer serviço do Portfólio ou do Histórico de Serviços Prestados.
/// Exibe todas as informações do serviço realizado + avaliação do cliente (ou simulador de avaliação futura).
class PortfolioServiceDetailSheet extends StatelessWidget {
  const PortfolioServiceDetailSheet({
    super.key,
    required this.serviceId,
  });

  final String serviceId;

  static Future<void> show(
    BuildContext context, {
    required String serviceId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.90,
        child: PortfolioServiceDetailSheet(serviceId: serviceId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ProviderPortfolioStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final tk = context.tk;
        final state = store.state;
        final service = state.fullHistory
            .where((s) => s.id == serviceId)
            .firstOrNull;
        if (service == null) {
          return const Center(child: Text('Serviço não encontrado.'));
        }
        final inTop3 = state.isInAutomaticTopThree(service.id);
        final inCurated = state.isInCuratedPortfolio(service.id);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      StatusChip(
                        service.categoryName,
                        color: tk.providerAccent,
                      ),
                      if (inTop3)
                        StatusChip(
                          'Top 3 Automático',
                          color: tk.providerAccent,
                          icon: Icons.auto_awesome_rounded,
                        ),
                      if (inCurated)
                        StatusChip(
                          'Destaque Escolhido',
                          color: tk.info,
                          icon: Icons.push_pin_rounded,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              service.title,
              key: const ValueKey('detail-sheet-service-title'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 12),

            // Selo de Segurança de Conclusão via PIN
            Container(
              key: const ValueKey('detail-sheet-pin-seal'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tk.successSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tk.success.withValues(alpha: 0.45)),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: tk.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Serviço concluído e validado com PIN do cliente (${service.validatedClientPin})',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.2,
                            color: tk.successInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Certificado de Garantia: ${service.warrantyCertificateCode} • Pedido ${service.orderId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: tk.successInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailMetaRow(
                    icon: Icons.event_available_rounded,
                    label: 'Concluído em',
                    value: dateLong(service.completedAt),
                  ),
                  _DetailMetaRow(
                    icon: Icons.place_outlined,
                    label: 'Cidade / UF',
                    value: service.cityAndState,
                  ),
                  _DetailMetaRow(
                    icon: Icons.timer_outlined,
                    label: 'Duração da execução',
                    value: service.executionDurationText,
                  ),
                  _DetailMetaRow(
                    icon: Icons.payments_outlined,
                    label: 'Valor do serviço',
                    value: brl(service.serviceValue),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            const Text(
              'Relatório Técnico do Serviço Realizado',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 6),
            AppCard(
              child: Text(
                service.detailedExecutionReport,
                key: const ValueKey('detail-sheet-execution-report'),
                style: const TextStyle(height: 1.45, fontSize: 14),
              ),
            ),

            if (service.toolsAndMaterialsUsed.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Ferramentas e Materiais Utilizados',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 6),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in service.toolsAndMaterialsUsed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.build_circle_outlined, size: 17, color: tk.providerAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],

            if (service.beforeAfterPhotoCaptionsOrUrls.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Evidências Fotográficas (Antes e Depois)',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 6),
              for (final caption in service.beforeAfterPhotoCaptionsOrUrls)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    color: tk.surface,
                    child: Row(
                      children: [
                        Icon(Icons.camera_alt_rounded, color: tk.providerAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            caption,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 14),
            const Text(
              'Avaliação do Cliente sobre este Serviço',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 6),
            if (service.isReviewedByClient)
              AppCard(
                key: const ValueKey('detail-sheet-client-review-card'),
                color: tk.successSoft,
                borderColor: tk.success.withValues(alpha: 0.4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        RatingStars(value: service.clientRating ?? 5.0, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${(service.clientRating ?? 5.0).toStringAsFixed(1).replaceAll('.', ',')} / 5,0',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: tk.successInk,
                          ),
                        ),
                        const Spacer(),
                        if (service.clientReviewedAt != null)
                          Text(
                            dateShort(service.clientReviewedAt!),
                            style: TextStyle(fontSize: 12, color: tk.textMuted),
                          ),
                      ],
                    ),
                    if ((service.clientReviewComment ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '"${service.clientReviewComment}"',
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (service.clientPraiseTags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in service.clientPraiseTags)
                            StatusChip(
                              tag,
                              color: tk.successInk,
                              icon: Icons.thumb_up_alt_rounded,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              )
            else
              AppCard(
                key: const ValueKey('detail-sheet-pending-review-card'),
                color: tk.warningSoft,
                borderColor: tk.warningInk.withValues(alpha: 0.35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.hourglass_bottom_rounded, color: tk.warningInk),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Aguardando avaliação do cliente — assim que o cliente avaliar, '
                            'a nota e o comentário aparecerão automaticamente aqui e no Histórico.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: tk.warningInk,
                              height: 1.38,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('btn-simulate-client-review-now'),
                        onPressed: () {
                          store.simulateFutureClientReviewForService(service.id);
                          showSnack(
                            context,
                            'Avaliação 5,0 ★ sincronizada no Meu Portfólio e no Histórico!',
                          );
                        },
                        icon: const Icon(Icons.stars_rounded, size: 18),
                        label: const Text(
                          'Simular Avaliação do Cliente Agora (5,0 ★)',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DetailMetaRow extends StatelessWidget {
  const _DetailMetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 17, color: tk.textMuted),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: tk.textMuted, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tela dedicada do **"Histórico de Serviços Prestados"** (permanente e imutável).
/// Exibe todos os serviços já realizados e validados pelo PIN do cliente,
/// com contadores, filtros e ação direta para destacar no Meu Portfólio.
class ProviderFullHistoryScreen extends StatefulWidget {
  const ProviderFullHistoryScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProviderFullHistoryScreen()),
    );
  }

  @override
  State<ProviderFullHistoryScreen> createState() =>
      _ProviderFullHistoryScreenState();
}

class _ProviderFullHistoryScreenState extends State<ProviderFullHistoryScreen> {
  String _filter = 'all'; // 'all' | 'top3' | 'eligible' | 'reviewed'

  @override
  Widget build(BuildContext context) {
    final store = ProviderPortfolioStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final state = store.state;
        final tk = context.tk;
        final all = state.fullHistory;
        final filtered = switch (_filter) {
          'top3' => state.automaticTopThree,
          'eligible' => state.eligibleHistoryPool,
          'reviewed' => all.where((s) => s.isReviewedByClient).toList(),
          _ => all,
        };

        return AppScaffold(
          appBar: AppBar(
            title: const Text('Histórico de Serviços Prestados'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tk.infoSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tk.info.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_rounded, color: tk.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Registro Permanente Auditado (${state.totalCompletedCount} serviços)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Todos os serviços concluídos com validação do PIN do cliente ficam salvos permanentemente aqui. '
                      'Nenhum serviço realizado é apagado quando sai dos 3 mais recentes do Portfólio.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.38,
                        color: tk.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _PinSimulationToolbar(state: state),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('Todos (${all.length})'),
                    selected: _filter == 'all',
                    onSelected: (_) => setState(() => _filter = 'all'),
                  ),
                  ChoiceChip(
                    label: Text('Top 3 Recentes (${state.automaticTopThree.length})'),
                    selected: _filter == 'top3',
                    onSelected: (_) => setState(() => _filter = 'top3'),
                  ),
                  ChoiceChip(
                    label: Text('Elegíveis p/ Destaque (${state.eligibleHistoryPool.length})'),
                    selected: _filter == 'eligible',
                    onSelected: (_) => setState(() => _filter = 'eligible'),
                  ),
                  ChoiceChip(
                    label: Text(
                      'Com Avaliação (${all.where((s) => s.isReviewedByClient).length})',
                    ),
                    selected: _filter == 'reviewed',
                    onSelected: (_) => setState(() => _filter = 'reviewed'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                const EmptyView(
                  icon: Icons.history_rounded,
                  title: 'Nenhum serviço neste filtro',
                  subtitle: 'Use os controles acima para visualizar todos os serviços concluídos.',
                )
              else
                for (var i = 0; i < filtered.length; i++) ...[
                  Builder(
                    builder: (context) {
                      final s = filtered[i];
                      final inTop3 = state.isInAutomaticTopThree(s.id);
                      final inCurated = state.isInCuratedPortfolio(s.id);
                      final canPick = state.canAddMoreCuratedServices &&
                          !inTop3 &&
                          !inCurated;
                      final rankIndex = all.indexWhere((e) => e.id == s.id);
                      final badge = inTop3
                          ? '#${rankIndex + 1} (No Top 3 Automático)'
                          : (inCurated
                              ? 'Destaque Escolhido no Portfólio'
                              : 'Salvo no Histórico (#${rankIndex + 1})');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            CompletedServicePortfolioCard(
                              key: ValueKey('history-service-card-${s.id}'),
                              service: s,
                              positionBadge: badge,
                              isAutomaticTopThree: inTop3,
                              onTap: () => PortfolioServiceDetailSheet.show(
                                context,
                                serviceId: s.id,
                              ),
                              onRemoveFromPortfolio: inCurated
                                  ? () {
                                      store.removeCuratedServiceFromPortfolio(s.id);
                                      showSnack(
                                        context,
                                        'Removido dos destaques do Portfólio (mantido no Histórico).',
                                      );
                                    }
                                  : null,
                            ),
                            if (canPick)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    key: ValueKey('history-add-to-portfolio-${s.id}'),
                                    onPressed: () {
                                      final ok = store
                                          .addServiceFromHistoryToPortfolio(s.id);
                                      if (ok) {
                                        showSnack(
                                          context,
                                          'Serviço destacado no Meu Portfólio (+1)!',
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.push_pin_outlined, size: 17),
                                    label: Text(
                                      'Destacar no Meu Portfólio (+1 • ${state.curatedPortfolioServices.length}/3)',
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/models/provider_portfolio_models.dart';
import '../../../core/state/provider_portfolio_controller.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';

/// Seção completa **"Meu Portfólio"** conectada ao **"Histórico de Serviços Prestados"**.
///
/// Regras de Negócio e Arquitetura:
/// - **Zero Fake Data**: Exibe exclusivamente serviços reais que já cumpriram o período de
///   proteção pós-serviço e tiveram 100% do pagamento líquido recebido pelo profissional.
/// - **Seção A — Pilha LIFO Automática (`Top 3`)**: Os 3 serviços elegíveis mais recentes entram
///   sozinhos em `#1`, `#2` e `#3`. Quando um novo serviço finaliza a proteção pós-serviço,
///   assume `#1`, deslocando `#1 -> #2`, `#2 -> #3` e enviando o antigo `#3` para o pool do Histórico.
/// - **Seção B — Destaques Escolhidos pelo Profissional (`Até 5 serviços`)**: A partir do 4º
///   serviço elegível no Histórico, o profissional pode escolher até 5 serviços adicionais.
/// - **Isolamento Cliente vs. Profissional (`isOwner`)**:
///   - Quando `isOwner == false` (Usuário Cliente visitando o perfil do profissional), nenhum
///     valor monetário (`R$`) é exibido (sem avisos de ocultação), nenhum botão de edição aparece
///     e o botão do "Histórico de Serviços Prestados" jamais é renderizado.
class ProviderSmartPortfolioSection extends StatefulWidget {
  const ProviderSmartPortfolioSection({
    super.key,
    this.isOwner = true,
    this.syncOnMount = true,
  });

  final bool isOwner;
  final bool syncOnMount;

  @override
  State<ProviderSmartPortfolioSection> createState() =>
      _ProviderSmartPortfolioSectionState();
}

class _ProviderSmartPortfolioSectionState
    extends State<ProviderSmartPortfolioSection> {
  @override
  void initState() {
    super.initState();
    if (widget.syncOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ProviderPortfolioStore.instance.syncFromSupabase();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ProviderPortfolioStore.instance;
    final tk = context.tk;
    final isOwner = widget.isOwner;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final state = store.state;
        final topThree = state.automaticTopThree;
        final curated = state.curatedPortfolioServices;
        final totalCount = state.totalCompletedCount;
        final unlocked = state.isAddFromHistoryUnlocked;

        // Se for visão pública do Cliente e o profissional ainda não tiver nenhum
        // serviço 100% liquidado pós-proteção, exibe estado informativo enxuto.
        if (!isOwner && topThree.isEmpty && curated.isEmpty) {
          return Container(
            key: const ValueKey('client-public-portfolio-empty'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tk.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tk.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: tk.providerAccent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Profissional com identidade e biometria verificadas. '
                    'Os próximos serviços concluídos aparecerão neste portfólio.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.38,
                      color: tk.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =================================================================
            // CABEÇALHO DO PORTFÓLIO + ACESSO AO HISTÓRICO (APENAS PROFISSIONAL)
            // =================================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    tk.providerSoft,
                    tk.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: tk.providerAccent.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: tk.providerAccent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOwner
                                  ? 'Meu Portfólio'
                                  : 'Portfólio de Serviços Verificados',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                color: tk.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isOwner
                                  ? '$totalCount serviço(s) concluído(s) • 3 recentes + até $kMaxCuratedPortfolioServices destaques'
                                  : '${topThree.length + curated.length} serviço(s) verificado(s) e concluído(s) na plataforma',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: tk.providerAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOwner)
                        OutlinedButton.icon(
                          key: const ValueKey('btn-open-full-history'),
                          onPressed: () =>
                              ProviderFullHistoryScreen.open(context),
                          icon: const Icon(Icons.history_edu_rounded, size: 17),
                          label: Text(
                            'Histórico (${state.totalHistoryRecordsCount})',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isOwner
                        ? 'Seus 3 últimos serviços concluídos entram aqui automaticamente. A partir do 4º serviço, você pode escolher até $kMaxCuratedPortfolioServices destaques do seu Histórico.'
                        : 'Toque em qualquer serviço abaixo para ver o que foi solicitado, a solução aplicada pelo profissional e as fotos.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: tk.textMuted,
                    ),
                  ),
                  if (isOwner && state.underProtectionServices.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => ProviderFullHistoryScreen.open(
                        context,
                        initialFilter: 'protection',
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: tk.infoSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: tk.info.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shield_moon_rounded,
                              size: 17,
                              color: tk.info,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${state.underProtectionServices.length} serviço(s) Sob Proteção Pós-Serviço — entrarão no Portfólio após a liberação final.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: tk.text,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: tk.info,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),

            // =================================================================
            // SEÇÃO 1: ÚLTIMOS 3 SERVIÇOS REALIZADOS (AUTOMÁTICO)
            // =================================================================
            Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  color: tk.providerAccent,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isOwner
                        ? 'Últimos 3 Serviços Realizados'
                        : 'Serviços Recentes Verificados',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                      color: tk.text,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tk.providerSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${topThree.length}/$kAutomaticPortfolioTopCount',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: tk.providerAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (topThree.isEmpty)
              Container(
                key: const ValueKey('portfolio-empty-top3-card'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tk.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tk.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      color: tk.providerAccent,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Nenhum serviço concluído ainda. Assim que você finalizar seu 1º atendimento, ele aparecerá automaticamente aqui.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: tk.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (var i = 0; i < topThree.length; i++) ...[
                CompletedServicePortfolioCard(
                  key: ValueKey('portfolio-top3-card-$i-${topThree[i].id}'),
                  service: topThree[i],
                  positionBadge: isOwner
                      ? '#${i + 1} Mais Recente'
                      : 'Serviço Verificado #${i + 1}',
                  isAutomaticTopThree: true,
                  showPrice: isOwner,
                  onTap: () => PortfolioServiceDetailSheet.show(
                    context,
                    serviceId: topThree[i].id,
                    isOwner: isOwner,
                  ),
                ),
                const SizedBox(height: 10),
              ],

            const SizedBox(height: 10),

            // =================================================================
            // SEÇÃO 2: ATÉ 5 DESTAQUES ESCOLHIDOS PELO PROFISSIONAL (A PARTIR DO 4º)
            // =================================================================
            if (isOwner || curated.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.stars_rounded,
                    color: tk.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isOwner
                          ? 'Destaques do Meu Histórico (Até $kMaxCuratedPortfolioServices)'
                          : 'Destaques Selecionados pelo Especialista',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                        color: tk.text,
                      ),
                    ),
                  ),
                  if (isOwner)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: unlocked ? tk.successSoft : tk.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: unlocked
                              ? tk.success.withValues(alpha: 0.4)
                              : tk.border,
                        ),
                      ),
                      child: Text(
                        unlocked
                            ? '${curated.length}/$kMaxCuratedPortfolioServices escolhidos'
                            : 'Libera no 4º serviço',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: unlocked ? tk.success : tk.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (!unlocked && isOwner)
                Container(
                  key: const ValueKey('portfolio-curated-locked-card'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tk.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tk.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_clock_rounded,
                        color: tk.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Disponível a partir do 4º serviço concluído (faltam ${(4 - totalCount).clamp(0, 4)}). Você poderá fixar até $kMaxCuratedPortfolioServices serviços do seu Histórico aqui.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.38,
                            color: tk.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                if (isOwner)
                  Text(
                    'Escolha até $kMaxCuratedPortfolioServices serviços concluídos e 100% pagos que já saíram dos 3 últimos para manter fixados na sua vitrine pública.',
                    style: TextStyle(fontSize: 12.5, color: tk.textMuted),
                  ),
                const SizedBox(height: 10),
                if (curated.isEmpty && isOwner)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tk.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tk.border),
                    ),
                    child: Text(
                      'Nenhum serviço extra destacado no momento. Use o botão abaixo para escolher até $kMaxCuratedPortfolioServices serviços do seu Histórico de Serviços Prestados.',
                      style: TextStyle(fontSize: 12.5, color: tk.textMuted),
                    ),
                  )
                else
                  for (var i = 0; i < curated.length; i++) ...[
                    CompletedServicePortfolioCard(
                      key: ValueKey('portfolio-curated-card-$i-${curated[i].id}'),
                      service: curated[i],
                      positionBadge: isOwner
                          ? 'Destaque Escolhido ${i + 1}/$kMaxCuratedPortfolioServices'
                          : 'Destaque do Especialista',
                      isAutomaticTopThree: false,
                      showPrice: isOwner,
                      onTap: () => PortfolioServiceDetailSheet.show(
                        context,
                        serviceId: curated[i].id,
                        isOwner: isOwner,
                      ),
                      onSwapFromHistory:
                          isOwner && state.availableToCurate.isNotEmpty
                              ? () => _showHistoryPickerSheet(
                                    context,
                                    replaceServiceId: curated[i].id,
                                  )
                              : null,
                      onRemoveFromPortfolio: isOwner
                          ? () {
                              store.removeCuratedServiceFromPortfolio(
                                curated[i].id,
                              );
                              showSnack(
                                context,
                                'Serviço removido dos destaques (continua salvo no seu Histórico Permanente).',
                              );
                            }
                          : null,
                    ),
                    const SizedBox(height: 10),
                  ],
                if (isOwner && state.canAddMoreCuratedServices)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('btn-add-from-history-one-by-one'),
                      onPressed: () => _showHistoryPickerSheet(context),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: Text(
                        'Escolher +1 Serviço do Histórico (${curated.length}/$kMaxCuratedPortfolioServices)',
                      ),
                    ),
                  ),
              ],
            ],
          ],
        );
      },
    );
  }

  Future<void> _showHistoryPickerSheet(
    BuildContext context, {
    String? replaceServiceId,
  }) async {
    final store = ProviderPortfolioStore.instance;
    final available = store.state.availableToCurate;
    if (available.isEmpty) {
      showSnack(
        context,
        'Todos os serviços elegíveis do Histórico já estão exibidos no Portfólio.',
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        final tk = sheetCtx.tk;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  replaceServiceId == null
                      ? 'Escolher Serviço do Histórico (1 por vez • até $kMaxCuratedPortfolioServices)'
                      : 'Substituir Destaque por Outro do Histórico',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: tk.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Apenas serviços Concluídos & 100% Liquidados (pós-proteção) que já saíram dos 3 últimos podem ser escolhidos.',
                  style: TextStyle(fontSize: 12.5, color: tk.textMuted),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: available.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, idx) {
                      final item = available[idx];
                      return CompletedServicePortfolioCard(
                        key: ValueKey('history-picker-item-${item.id}'),
                        service: item,
                        positionBadge: 'Elegível no Histórico',
                        isAutomaticTopThree: false,
                        showPrice: true,
                        onTap: () {
                          final bool ok;
                          if (replaceServiceId != null) {
                            ok = store.swapCuratedServiceInPortfolio(
                              oldServiceId: replaceServiceId,
                              newServiceId: item.id,
                            );
                          } else {
                            ok = store.addServiceFromHistoryToPortfolio(
                              item.id,
                            );
                          }
                          Navigator.of(sheetCtx).pop();
                          if (ok) {
                            showSnack(
                              context,
                              replaceServiceId != null
                                  ? 'Destaque substituído com sucesso no Meu Portfólio!'
                                  : 'Serviço adicionado com sucesso ao Meu Portfólio!',
                            );
                          }
                        },
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
  }
}

/// Card de serviço exibido no Meu Portfólio e no Histórico de Serviços Prestados.
///
/// Regra de Sigilo para o Usuário Cliente (`showPrice == false`):
/// - Quando `showPrice == false`, nenhum valor monetário (`R$`) é renderizado e
///   nenhum aviso de ocultação é exibido.
class CompletedServicePortfolioCard extends StatelessWidget {
  const CompletedServicePortfolioCard({
    super.key,
    required this.service,
    required this.positionBadge,
    required this.isAutomaticTopThree,
    required this.onTap,
    this.showPrice = true,
    this.onSwapFromHistory,
    this.onRemoveFromPortfolio,
  });

  final CompletedServiceRecord service;
  final String positionBadge;
  final bool isAutomaticTopThree;
  final bool showPrice;
  final VoidCallback onTap;
  final VoidCallback? onSwapFromHistory;
  final VoidCallback? onRemoveFromPortfolio;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final stage = service.lifecycleStage;

    final (Color stageBg, Color stageFg, IconData stageIcon) = switch (stage) {
      ServiceHistoryLifecycleStage.settledAndPaid => (
          isAutomaticTopThree ? tk.providerSoft : tk.successSoft,
          isAutomaticTopThree ? tk.providerAccent : tk.success,
          isAutomaticTopThree ? Icons.bolt_rounded : Icons.verified_rounded,
        ),
      ServiceHistoryLifecycleStage.underPostServiceProtection => (
          tk.infoSoft,
          tk.info,
          Icons.shield_moon_rounded,
        ),
      ServiceHistoryLifecycleStage.inMediation => (
          tk.warningSoft,
          tk.warning,
          Icons.gavel_rounded,
        ),
      ServiceHistoryLifecycleStage.canceled => (
          tk.dangerSoft,
          tk.danger,
          Icons.cancel_outlined,
        ),
    };

    return Material(
      color: tk.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isAutomaticTopThree
                  ? tk.providerAccent.withValues(alpha: 0.4)
                  : tk.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: stageBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(stageIcon, size: 13, color: stageFg),
                        const SizedBox(width: 4),
                        Text(
                          positionBadge,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: stageFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tk.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: tk.border),
                    ),
                    child: Text(
                      service.categoryName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: tk.text,
                      ),
                    ),
                  ),
                  if (stage != ServiceHistoryLifecycleStage.canceled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tk.successSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            size: 13,
                            color: tk.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            showPrice
                                ? 'PIN ${service.validatedClientPin} Validado'
                                : 'Conclusão Verificada',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: tk.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                service.title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: tk.text,
                ),
              ),
              if (service.hasClientRequestedDescription) ...[
                const SizedBox(height: 4),
                Text(
                  'Solicitado: ${service.clientRequestedDescription}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tk.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                service.detailedExecutionReport,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: tk.textMuted,
                ),
              ),
              if (service.hasComplementaryTechnicalNotes) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.note_alt_outlined,
                      size: 14,
                      color: tk.providerAccent,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Notas Técnicas Complementares: ${service.complementaryTechnicalNotes}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: tk.providerAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),

              // ===============================================================
              // BLOCO DE AVALIAÇÃO DO CLIENTE OU STATUS DO HISTÓRICO
              // ===============================================================
              if (stage == ServiceHistoryLifecycleStage.canceled)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tk.dangerSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Cancelado (${service.canceledByRole == 'client' ? 'pelo Cliente' : (service.canceledByRole == 'provider' ? 'pelo Profissional' : 'Sistema')}): '
                    '${service.cancelReason ?? 'Cancelamento registrado no histórico.'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tk.danger,
                    ),
                  ),
                )
              else if (stage == ServiceHistoryLifecycleStage.inMediation)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tk.warningSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Em Mediação Técnica: ${service.mediationReason ?? 'Análise de evidências em andamento na plataforma.'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tk.warning,
                    ),
                  ),
                )
              else if (stage ==
                  ServiceHistoryLifecycleStage.underPostServiceProtection)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tk.infoSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_moon_rounded, size: 16, color: tk.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sob Proteção Pós-Serviço (Em Cobertura Técnica & Maturação) • '
                          '${service.protectionEndsAt != null ? 'Liberação 100% em ${dateShort(service.protectionEndsAt!)}' : 'Aguardando conclusão da janela de proteção para entrar no Portfólio'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: tk.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (service.isReviewedByClient)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tk.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tk.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: tk.warning,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${(service.clientRating ?? 5.0).toStringAsFixed(1)} ★ • Avaliação de ${service.clientDisplayName ?? 'Cliente Verificado'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: tk.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if ((service.clientReviewComment ?? '')
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '"${service.clientReviewComment}"',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: tk.text,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: tk.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tk.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: tk.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Concluído e validado (${service.clientDisplayName ?? 'Cliente'}) • Aguardando avaliação',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: tk.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 14, color: tk.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${service.cityAndState} • ${dateShort(service.completedAt)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: tk.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (service.beforeAfterPhotoCaptionsOrUrls.isNotEmpty) ...[
                    Icon(
                      Icons.photo_library_outlined,
                      size: 14,
                      color: tk.providerAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${service.beforeAfterPhotoCaptionsOrUrls.length} foto(s)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: tk.providerAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  // Omissão silenciosa de valores para o Usuário Cliente (`showPrice == false`)
                  if (showPrice) ...[
                    Text(
                      brl(service.serviceValue),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: tk.text,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    'Ver detalhes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: tk.providerAccent,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: tk.providerAccent,
                  ),
                ],
              ),

              if (onSwapFromHistory != null ||
                  onRemoveFromPortfolio != null) ...[
                const Divider(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onSwapFromHistory != null)
                      TextButton.icon(
                        onPressed: onSwapFromHistory,
                        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                        label: const Text('Trocar por outro do Histórico'),
                      ),
                    if (onRemoveFromPortfolio != null)
                      TextButton.icon(
                        onPressed: onRemoveFromPortfolio,
                        icon: Icon(
                          Icons.remove_circle_outline_rounded,
                          size: 16,
                          color: tk.danger,
                        ),
                        label: Text(
                          'Tirar da Vitrine',
                          style: TextStyle(color: tk.danger),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal detalhado de um serviço do Portfólio ou do Histórico:
/// 1. O que foi solicitado pelo cliente (`clientRequestedDescription` — imutável);
/// 2. A solução técnica aplicada pelo profissional na conclusão (`detailedExecutionReport` — imutável);
/// 3. Galeria de fotos deslizável da 1ª à última foto (`PageView.builder` + `InteractiveViewer` — imutável);
/// 4. "Notas Técnicas Complementares" (`complementaryTechnicalNotes` — editável apenas pelo profissional dono).
///
/// Quando `isOwner == false` (visão do Cliente):
/// - Oculta silenciosamente 100% dos valores monetários (sem exibir mensagem de ocultação);
/// - Exibe tudo em modo somente leitura limpo (sem botões de edição e sem avisos de restrição).
class PortfolioServiceDetailSheet extends StatefulWidget {
  const PortfolioServiceDetailSheet({
    super.key,
    required this.serviceId,
    this.isOwner = true,
  });

  final String serviceId;
  final bool isOwner;

  static Future<void> show(
    BuildContext context, {
    required String serviceId,
    bool isOwner = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.90,
        child: PortfolioServiceDetailSheet(
          serviceId: serviceId,
          isOwner: isOwner,
        ),
      ),
    );
  }

  @override
  State<PortfolioServiceDetailSheet> createState() =>
      _PortfolioServiceDetailSheetState();
}

class _PortfolioServiceDetailSheetState
    extends State<PortfolioServiceDetailSheet> {
  int _currentPhotoIndex = 0;
  late final PageController _pageController = PageController();
  bool _editingComplementaryNotes = false;
  final TextEditingController _notesController = TextEditingController();
  bool _savingNotes = false;

  @override
  void dispose() {
    _pageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveComplementaryNotes(CompletedServiceRecord service) async {
    setState(() => _savingNotes = true);
    try {
      await ProviderPortfolioStore.instance.updateComplementaryTechnicalNotes(
        serviceId: service.id,
        notes: _notesController.text,
      );
      if (mounted) {
        setState(() => _editingComplementaryNotes = false);
        showSnack(
          context,
          'Notas Técnicas Complementares atualizadas no seu Portfólio!',
        );
      }
    } finally {
      if (mounted) setState(() => _savingNotes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ProviderPortfolioStore.instance;
    final tk = context.tk;
    final isOwner = widget.isOwner;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final service = store.state.findById(widget.serviceId);
        if (service == null) {
          return const Center(child: Text('Serviço não encontrado.'));
        }

        final photos = service.beforeAfterPhotoCaptionsOrUrls;

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              // Selos de cabeçalho
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    key: const ValueKey('detail-sheet-pin-seal'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: tk.successSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 15,
                          color: tk.success,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            isOwner
                                ? 'Validado com PIN do Cliente (${service.validatedClientPin})'
                                : 'Serviço Auditado & Verificado na Plataforma',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: tk.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: tk.providerSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      service.categoryName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: tk.providerAccent,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: tk.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: tk.border),
                    ),
                    child: Text(
                      service.lifecycleStage.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: tk.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                service.title,
                key: const ValueKey('detail-sheet-service-title'),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: tk.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${service.cityAndState} • Concluído em ${dateShort(service.completedAt)} • Certificado ${service.warrantyCertificateCode}',
                style: TextStyle(fontSize: 12.5, color: tk.textMuted),
              ),
              const SizedBox(height: 16),

              // ===============================================================
              // METADADOS OPERACIONAIS (VALORES VISÍVEIS APENAS PARA O PROFISSIONAL)
              // ===============================================================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tk.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tk.border),
                ),
                child: Row(
                  children: [
                    if (isOwner) ...[
                      Expanded(
                        child: _MetricTile(
                          label: 'Líquido (100% Pago)',
                          value: brl(service.serviceValue),
                        ),
                      ),
                      if (service.materialsAmount > 0)
                        Expanded(
                          child: _MetricTile(
                            label: 'Peças (Taxa 0%)',
                            value: brl(service.materialsAmount),
                          ),
                        ),
                    ],
                    Expanded(
                      child: _MetricTile(
                        label: 'Tempo de Execução',
                        value: service.executionDurationText,
                      ),
                    ),
                    Expanded(
                      child: _MetricTile(
                        label: 'Cliente',
                        value: service.clientDisplayName ?? 'Verificado',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ===============================================================
              // 1. O QUE FOI SOLICITADO PELO CLIENTE (IMUTÁVEL)
              // ===============================================================
              Text(
                'O que foi solicitado pelo Cliente',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: tk.text,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                key: const ValueKey('detail-sheet-client-request'),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tk.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tk.border),
                ),
                child: Text(
                  service.hasClientRequestedDescription
                      ? service.clientRequestedDescription
                      : 'Solicitação de atendimento técnico em ${service.categoryName}: ${service.title}.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: tk.text,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ===============================================================
              // 2. SOLUÇÃO TÉCNICA APLICADA NA CONCLUSÃO (IMUTÁVEL 🔒)
              // ===============================================================
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Solução Técnica Aplicada na Conclusão',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: tk.text,
                      ),
                    ),
                  ),
                  if (isOwner)
                    Container(
                      key: const ValueKey('detail-sheet-immutable-lock-badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tk.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: tk.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 12,
                            color: tk.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Registro Original Imutável',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: tk.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                key: const ValueKey('detail-sheet-execution-report'),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tk.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tk.border),
                ),
                child: Text(
                  service.detailedExecutionReport,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: tk.text,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ===============================================================
              // 3. NOTAS TÉCNICAS COMPLEMENTARES (EDITÁVEL APENAS PELO PROFISSIONAL)
              // ===============================================================
              if (isOwner || service.hasComplementaryTechnicalNotes) ...[
                Container(
                  key: const ValueKey('detail-sheet-complementary-notes-section'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tk.providerSoft.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tk.providerAccent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.engineering_rounded,
                            size: 18,
                            color: tk.providerAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Notas Técnicas Complementares',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14.5,
                                    color: tk.text,
                                  ),
                                ),
                                if (isOwner)
                                  Text(
                                    'Adicione detalhes técnicos complementares pós-obra para destacar sua execução no Portfólio.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: tk.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isOwner && !_editingComplementaryNotes)
                            TextButton.icon(
                              key: const ValueKey('btn-edit-complementary-notes'),
                              onPressed: () {
                                _notesController.text =
                                    service.complementaryTechnicalNotes ?? '';
                                setState(
                                  () => _editingComplementaryNotes = true,
                                );
                              },
                              icon: const Icon(Icons.edit_note_rounded, size: 18),
                              label: Text(
                                service.hasComplementaryTechnicalNotes
                                    ? 'Editar'
                                    : 'Adicionar',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (isOwner && _editingComplementaryNotes) ...[
                        TextField(
                          key: const ValueKey('input-complementary-notes'),
                          controller: _notesController,
                          maxLines: 4,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            hintText:
                                'Ex.: Especificação das peças aplicadas, normas técnicas ABNT atendidas e recomendações de manutenção preventiva...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: _savingNotes
                                  ? null
                                  : () => setState(
                                        () =>
                                            _editingComplementaryNotes = false,
                                      ),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton.icon(
                              key: const ValueKey('btn-save-complementary-notes'),
                              style: FilledButton.styleFrom(
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                              onPressed: _savingNotes
                                  ? null
                                  : () => _saveComplementaryNotes(service),
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text('Salvar Notas Complementares'),
                            ),
                          ],
                        ),
                      ] else if (service.hasComplementaryTechnicalNotes)
                        Text(
                          service.complementaryTechnicalNotes!,
                          key: const ValueKey('text-complementary-notes-value'),
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: tk.text,
                          ),
                        )
                      else if (isOwner)
                        Text(
                          'Nenhuma nota complementar adicionada ainda. Toque em "Adicionar" para detalhar materiais, normas ou diferenciais deste serviço.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: tk.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // ===============================================================
              // 4. GALERIA DE FOTOS DESLIZÁVEL (DA 1ª À ÚLTIMA FOTO — IMUTÁVEL)
              // ===============================================================
              if (photos.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Fotos do Serviço (${_currentPhotoIndex + 1} de ${photos.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: tk.text,
                        ),
                      ),
                    ),
                    Text(
                      'Arraste para o lado ➔',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tk.providerAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 230,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PageView.builder(
                        key: const ValueKey('detail-sheet-photo-pageview'),
                        controller: _pageController,
                        itemCount: photos.length,
                        onPageChanged: (idx) =>
                            setState(() => _currentPhotoIndex = idx),
                        itemBuilder: (context, idx) {
                          final item = photos[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: GestureDetector(
                              key: ValueKey('portfolio-photo-slide-$idx'),
                              onTap: () => PortfolioFullScreenPhotoViewer.open(
                                context,
                                photos: photos,
                                initialIndex: idx,
                                serviceTitle: service.title,
                              ),
                              child: _PortfolioPhotoSlideCard(
                                photoOrCaption: item,
                                index: idx,
                                total: photos.length,
                              ),
                            ),
                          );
                        },
                      ),
                      if (photos.length > 1 && _currentPhotoIndex > 0)
                        Positioned(
                          left: 8,
                          child: IconButton.filledTonal(
                            key: const ValueKey('btn-photo-prev'),
                            onPressed: () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                            ),
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                        ),
                      if (photos.length > 1 &&
                          _currentPhotoIndex < photos.length - 1)
                        Positioned(
                          right: 8,
                          child: IconButton.filledTonal(
                            key: const ValueKey('btn-photo-next'),
                            onPressed: () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                            ),
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ),
                    ],
                  ),
                ),
                if (photos.length > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < photos.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _currentPhotoIndex ? 20 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _currentPhotoIndex
                                ? tk.providerAccent
                                : tk.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
              ],

              if (service.toolsAndMaterialsUsed.isNotEmpty) ...[
                Text(
                  'Ferramental e Insumos Aplicados',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: tk.text,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tool in service.toolsAndMaterialsUsed)
                      Chip(
                        label: Text(
                          tool,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
              ],

              // ===============================================================
              // 5. AVALIAÇÃO REATIVA DO CLIENTE
              // ===============================================================
              Text(
                'Avaliação do Cliente',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: tk.text,
                ),
              ),
              const SizedBox(height: 8),
              if (service.isReviewedByClient)
                Container(
                  key: const ValueKey('detail-sheet-client-review-box'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tk.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tk.warning.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          for (var s = 0; s < 5; s++)
                            Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: s < (service.clientRating ?? 5).round()
                                  ? tk.warning
                                  : tk.border,
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${(service.clientRating ?? 5.0).toStringAsFixed(1)} • ${service.clientDisplayName ?? 'Cliente Verificado'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                color: tk.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if ((service.clientReviewComment ?? '')
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '"${service.clientReviewComment}"',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                            color: tk.text,
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: tk.successSoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: tk.success,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tk.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tk.border),
                  ),
                  child: Text(
                    'Este serviço já foi concluído e auditado. Assim que o cliente registrar sua avaliação, a nota e o comentário aparecerão automaticamente aqui.',
                    style: TextStyle(fontSize: 12.5, color: tk.textMuted),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PortfolioPhotoSlideCard extends StatelessWidget {
  const _PortfolioPhotoSlideCard({
    required this.photoOrCaption,
    required this.index,
    required this.total,
  });

  final String photoOrCaption;
  final int index;
  final int total;

  bool get _isStoragePathOrUrl {
    final p = photoOrCaption.trim();
    return p.startsWith('http://') ||
        p.startsWith('https://') ||
        (p.contains('/') && !p.contains(' '));
  }

  bool get _isPublicPath {
    final p = photoOrCaption.trim();
    return p.startsWith('http://') ||
        p.startsWith('https://') ||
        p.contains('/portfolio_') ||
        p.startsWith('portfolio/') ||
        p.contains('/avatar_') ||
        p.startsWith('avatar/');
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isStoragePathOrUrl)
            _isPublicPath
                ? PublicImage(
                    path: photoOrCaption,
                    height: 230,
                    width: double.infinity,
                    radius: 16,
                  )
                : SignedImage(
                    path: photoOrCaption,
                    height: 230,
                    width: double.infinity,
                    radius: 16,
                  )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    tk.surface,
                    tk.providerSoft,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: tk.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_enhance_rounded,
                    size: 40,
                    color: tk.providerAccent,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    photoOrCaption,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      height: 1.38,
                      color: tk.text,
                    ),
                  ),
                ],
              ),
            ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Foto ${index + 1} de $total',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_out_map_rounded, size: 13, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Toque para ampliar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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

/// Visualizador em tela cheia deslizável (`PageView.builder` + `InteractiveViewer`)
/// permitindo navegar da 1ª até a última foto do serviço com pinça de zoom.
class PortfolioFullScreenPhotoViewer extends StatefulWidget {
  const PortfolioFullScreenPhotoViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.serviceTitle,
    this.usePublicBucket = false,
  });

  final List<String> photos;
  final int initialIndex;
  final String serviceTitle;
  final bool usePublicBucket;

  static Future<void> open(
    BuildContext context, {
    required List<String> photos,
    required int initialIndex,
    required String serviceTitle,
    bool usePublicBucket = false,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PortfolioFullScreenPhotoViewer(
          photos: photos,
          initialIndex: initialIndex,
          serviceTitle: serviceTitle,
          usePublicBucket: usePublicBucket,
        ),
      ),
    );
  }

  @override
  State<PortfolioFullScreenPhotoViewer> createState() =>
      _PortfolioFullScreenPhotoViewerState();
}

class _PortfolioFullScreenPhotoViewerState
    extends State<PortfolioFullScreenPhotoViewer> {
  late int _index = widget.initialIndex;
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isPublicPath(String raw) {
    final p = raw.trim();
    return widget.usePublicBucket ||
        p.startsWith('http://') ||
        p.startsWith('https://') ||
        p.contains('/portfolio_') ||
        p.startsWith('portfolio/') ||
        p.contains('/avatar_') ||
        p.startsWith('avatar/');
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photos.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Foto ${_index + 1} de $total • ${widget.serviceTitle}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          PageView.builder(
            key: const ValueKey('fullscreen-photo-pageview'),
            controller: _controller,
            itemCount: total,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, idx) {
              final item = widget.photos[idx];
              final isPath = item.trim().startsWith('http://') ||
                  item.trim().startsWith('https://') ||
                  (item.contains('/') && !item.contains(' '));
              final usePublic = _isPublicPath(item);
              return InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: isPath
                        ? (usePublic
                            ? PublicImage(
                                path: item,
                                height: 480,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                radius: 16,
                              )
                            : SignedImage(
                                path: item,
                                height: 480,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                radius: 16,
                              ))
                        : Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141923),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.camera_enhance_rounded,
                                  size: 56,
                                  color: Colors.orangeAccent,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  item,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Deslize para o lado para ver todas as fotos (${_index + 1}/$total)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: tk.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            color: tk.text,
          ),
        ),
      ],
    );
  }
}

/// Tela completa do **"Histórico de Serviços Prestados"** exclusiva do Usuário Profissional.
///
/// Exibe os 4 estados reais do ciclo de vida pós-contratação:
/// 1. **Concluídos & 100% Liquidados** (`settledAndPaid` — únicos elegíveis para o Meu Portfólio)
/// 2. **Sob Proteção Pós-Serviço** (`underPostServiceProtection` — *Em Cobertura Técnica & Maturação*)
/// 3. **Em Mediação** (`inMediation`)
/// 4. **Cancelados** (`canceled`)
class ProviderFullHistoryScreen extends StatefulWidget {
  const ProviderFullHistoryScreen({
    super.key,
    this.initialFilter = 'all',
    this.syncOnMount = true,
  });

  final String initialFilter;
  final bool syncOnMount;

  static Future<void> open(
    BuildContext context, {
    String initialFilter = 'all',
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderFullHistoryScreen(
          initialFilter: initialFilter,
        ),
      ),
    );
  }

  @override
  State<ProviderFullHistoryScreen> createState() =>
      _ProviderFullHistoryScreenState();
}

class _ProviderFullHistoryScreenState extends State<ProviderFullHistoryScreen> {
  late String _filter = widget.initialFilter;

  @override
  void initState() {
    super.initState();
    if (widget.syncOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ProviderPortfolioStore.instance.syncFromSupabase();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ProviderPortfolioStore.instance;
    final tk = context.tk;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final state = store.state;
        final all = state.fullHistory;
        final filtered = switch (_filter) {
          'settled' => state.settledEligibleHistory,
          'protection' => state.underProtectionServices,
          'mediation' => state.inMediationServices,
          'canceled' => state.canceledServices,
          'top3' => state.automaticTopThree,
          'eligible' => state.eligibleHistoryPool,
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
                            'Seus atendimentos (${state.totalHistoryRecordsCount} registros)',
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
                      'Consulte todos os seus serviços por etapa. Após concluir a proteção pós-serviço e liberar o pagamento, você pode destacá-los no seu Portfólio.',
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
              SizedBox(
                height: 44,
                child: SingleChildScrollView(
                  key: const ValueKey('history-filter-strip'),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        key: const ValueKey('history-chip-all'),
                        showCheckmark: false,
                        label: Text('Todos (${all.length})'),
                        selected: _filter == 'all',
                        onSelected: (_) => setState(() => _filter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        key: const ValueKey('history-chip-settled'),
                        showCheckmark: false,
                        label: Text(
                          'Concluídos 100% Pagos (${state.settledEligibleHistory.length})',
                        ),
                        selected: _filter == 'settled',
                        onSelected: (_) => setState(() => _filter = 'settled'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        key: const ValueKey('history-chip-protection'),
                        showCheckmark: false,
                        label: Text(
                          'Sob Proteção Pós-Serviço (${state.underProtectionServices.length})',
                        ),
                        selected: _filter == 'protection',
                        onSelected: (_) => setState(() => _filter = 'protection'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        key: const ValueKey('history-chip-mediation'),
                        showCheckmark: false,
                        label: Text(
                          'Em Mediação (${state.inMediationServices.length})',
                        ),
                        selected: _filter == 'mediation',
                        onSelected: (_) => setState(() => _filter = 'mediation'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        key: const ValueKey('history-chip-canceled'),
                        showCheckmark: false,
                        label: Text(
                          'Cancelados (${state.canceledServices.length})',
                        ),
                        selected: _filter == 'canceled',
                        onSelected: (_) => setState(() => _filter = 'canceled'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                const EmptyView(
                  icon: Icons.history_rounded,
                  title: 'Nenhum serviço registrado neste filtro',
                  subtitle:
                      'Seus atendimentos reais entre você e os clientes aparecerão automaticamente aqui conforme avançarem de etapa.',
                )
              else
                for (var i = 0; i < filtered.length; i++) ...[
                  Builder(
                    builder: (context) {
                      final s = filtered[i];
                      final inTop3 = state.isInAutomaticTopThree(s.id);
                      final inCurated = state.isInCuratedPortfolio(s.id);
                      final canPick = s.isEligibleForPortfolio &&
                          state.canAddMoreCuratedServices &&
                          !inTop3 &&
                          !inCurated;
                      final rankIndex = state.settledRankOf(s.id);
                      final String badge;
                      if (!s.isEligibleForPortfolio) {
                        badge = s.lifecycleStage.label;
                      } else if (inTop3) {
                        badge = '#${rankIndex + 1} (No Top 3 Automático)';
                      } else if (inCurated) {
                        badge = 'Destaque Escolhido no Portfólio';
                      } else {
                        badge =
                            'Concluído & 100% Liquidado (#${rankIndex + 1})';
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            CompletedServicePortfolioCard(
                              key: ValueKey('history-service-card-${s.id}'),
                              service: s,
                              positionBadge: badge,
                              isAutomaticTopThree: inTop3,
                              showPrice: true,
                              onTap: () => PortfolioServiceDetailSheet.show(
                                context,
                                serviceId: s.id,
                                isOwner: true,
                              ),
                              onRemoveFromPortfolio: inCurated
                                  ? () {
                                      store.removeCuratedServiceFromPortfolio(
                                        s.id,
                                      );
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
                                    key: ValueKey(
                                      'history-add-to-portfolio-${s.id}',
                                    ),
                                    onPressed: () {
                                      final ok = store
                                          .addServiceFromHistoryToPortfolio(
                                        s.id,
                                      );
                                      if (ok) {
                                        showSnack(
                                          context,
                                          'Serviço destacado no Meu Portfólio (+1)!',
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.push_pin_outlined,
                                      size: 17,
                                    ),
                                    label: Text(
                                      'Destacar no Meu Portfólio (+1 • ${state.curatedPortfolioServices.length}/$kMaxCuratedPortfolioServices)',
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

import 'package:flutter/material.dart';

import '../../../core/models/provider_portfolio_models.dart';
import '../../../core/state/provider_portfolio_controller.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/media_widgets.dart';
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
          return AppCard(
            key: const ValueKey('client-public-portfolio-empty'),
            variant: AppCardVariant.tonal,
            borderColor: tk.border,
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: tk.accentInk,
                  size: 24,
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Text(
                    'Profissional com identidade e biometria verificadas. '
                    'Os próximos serviços concluídos aparecerão neste portfólio.',
                    style: AppType.bodySm.copyWith(color: tk.textMuted),
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
            AppCard(
              variant: AppCardVariant.tonal,
              color: tk.providerSoft,
              borderColor: tk.accentInk.withValues(alpha: 0.25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpace.s12),
                        decoration: BoxDecoration(
                          color: tk.accent,
                          borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
                        ),
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          color: tk.onAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOwner
                                  ? 'Meu Portfólio'
                                  : 'Portfólio de Serviços Verificados',
                              style: AppType.title.copyWith(color: tk.text),
                            ),
                            const SizedBox(height: AppSpace.s2),
                            Text(
                              isOwner
                                  ? '$totalCount serviço(s) concluído(s) • 3 recentes + até $kMaxCuratedPortfolioServices destaques'
                                  : '${topThree.length + curated.length} serviço(s) verificado(s) e concluído(s) na plataforma',
                              style: AppType.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: tk.accentInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isOwner) ...[
                    const SizedBox(height: AppSpace.s12),
                    AppButton(
                      key: const ValueKey('btn-open-full-history'),
                      variant: AppButtonVariant.secondary,
                      compact: true,
                      expand: false,
                      onPressed: () => ProviderFullHistoryScreen.open(context),
                      icon: Icons.history_edu_rounded,
                      label: 'Histórico (${state.totalHistoryRecordsCount})',
                    ),
                  ],
                  const SizedBox(height: AppSpace.s12),
                  Text(
                    isOwner
                        ? 'Seus 3 últimos serviços concluídos entram aqui automaticamente. A partir do 4º serviço, você pode escolher até $kMaxCuratedPortfolioServices destaques do seu Histórico.'
                        : 'Toque em qualquer serviço abaixo para ver o que foi solicitado, a solução aplicada pelo profissional e as fotos.',
                    style: AppType.bodySm.copyWith(color: tk.textMuted),
                  ),
                  if (isOwner && state.underProtectionServices.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s12),
                    AppCard(
                      variant: AppCardVariant.tonal,
                      color: tk.infoSoft,
                      borderColor: tk.info.withValues(alpha: 0.35),
                      radius: AppGeometry.fieldRadius,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s12,
                        vertical: AppSpace.s12,
                      ),
                      onTap: () => ProviderFullHistoryScreen.open(
                        context,
                        initialFilter: 'protection',
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shield_moon_rounded,
                            size: 18,
                            color: tk.accentInk,
                          ),
                          const SizedBox(width: AppSpace.s8),
                          Expanded(
                            child: Text(
                              '${state.underProtectionServices.length} serviço(s) Sob Proteção Pós-Serviço — entrarão no Portfólio após a liberação final.',
                              style: AppType.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: tk.text,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: tk.accentInk,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpace.section),

            // =================================================================
            // SEÇÃO 1: ÚLTIMOS 3 SERVIÇOS REALIZADOS (AUTOMÁTICO)
            // =================================================================
            AppSection(
              title: isOwner
                  ? 'Últimos 3 Serviços Realizados'
                  : 'Serviços Recentes Verificados',
              action: AppStatusChip(
                '${topThree.length}/$kAutomaticPortfolioTopCount',
                tone: AppTone.accent,
              ),
              child: topThree.isEmpty
                  ? AppCard(
                      key: const ValueKey('portfolio-empty-top3-card'),
                      variant: AppCardVariant.tonal,
                      borderColor: tk.border,
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            color: tk.accentInk,
                            size: 22,
                          ),
                          const SizedBox(width: AppSpace.s12),
                          Expanded(
                            child: Text(
                              'Nenhum serviço concluído ainda. Assim que você finalizar seu 1º atendimento, ele aparecerá automaticamente aqui.',
                              style: AppType.bodySm.copyWith(color: tk.textMuted),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
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
                          if (i < topThree.length - 1) const SizedBox(height: AppSpace.s12),
                        ],
                      ],
                    ),
            ),

            // =================================================================
            // SEÇÃO 2: ATÉ 5 DESTAQUES ESCOLHIDOS PELO PROFISSIONAL (A PARTIR DO 4º)
            // =================================================================
            if (isOwner || curated.isNotEmpty) ...[
              const SizedBox(height: AppSpace.section),
              AppSection(
                title: isOwner
                    ? 'Destaques do Meu Histórico (Até $kMaxCuratedPortfolioServices)'
                    : 'Destaques Selecionados pelo Especialista',
                action: isOwner
                    ? AppStatusChip(
                        unlocked
                            ? '${curated.length}/$kMaxCuratedPortfolioServices escolhidos'
                            : 'Libera no 4º serviço',
                        tone: unlocked ? AppTone.success : AppTone.neutral,
                      )
                    : null,
                subtitle: isOwner && unlocked
                    ? 'Escolha até $kMaxCuratedPortfolioServices serviços concluídos e 100% pagos que já saíram dos 3 últimos para manter fixados na sua vitrine pública.'
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!unlocked && isOwner)
                      AppCard(
                        key: const ValueKey('portfolio-curated-locked-card'),
                        variant: AppCardVariant.tonal,
                        borderColor: tk.border,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_clock_rounded,
                              color: tk.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpace.s12),
                            Expanded(
                              child: Text(
                                'Disponível a partir do 4º serviço concluído (faltam ${(4 - totalCount).clamp(0, 4)}). Você poderá fixar até $kMaxCuratedPortfolioServices serviços do seu Histórico aqui.',
                                style: AppType.bodySm.copyWith(color: tk.textMuted),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      if (curated.isEmpty && isOwner)
                        AppCard(
                          variant: AppCardVariant.tonal,
                          borderColor: tk.border,
                          child: Text(
                            'Nenhum serviço extra destacado no momento. Use o botão abaixo para escolher até $kMaxCuratedPortfolioServices serviços do seu Histórico de Serviços Prestados.',
                            style: AppType.bodySm.copyWith(color: tk.textMuted),
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
                                    AppSnackbar.show(
                                      context,
                                      'Serviço removido dos destaques (continua salvo no seu Histórico Permanente).',
                                    );
                                  }
                                : null,
                          ),
                          const SizedBox(height: AppSpace.s12),
                        ],
                      if (isOwner && state.canAddMoreCuratedServices) ...[
                        if (curated.isEmpty) const SizedBox(height: AppSpace.s12),
                        AppButton(
                          key: const ValueKey('btn-add-from-history-one-by-one'),
                          variant: AppButtonVariant.secondary,
                          compact: true,
                          onPressed: () => _showHistoryPickerSheet(context),
                          icon: Icons.add_circle_outline_rounded,
                          label: 'Escolher +1 Serviço do Histórico (${curated.length}/$kMaxCuratedPortfolioServices)',
                        ),
                      ],
                    ],
                  ],
                ),
              ),
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
      AppSnackbar.show(
        context,
        'Todos os serviços elegíveis do Histórico já estão exibidos no Portfólio.',
      );
      return;
    }

    await AppSheet.show<void>(
      context,
      title: replaceServiceId == null
          ? 'Escolher Serviço do Histórico (1 por vez • até $kMaxCuratedPortfolioServices)'
          : 'Substituir Destaque por Outro do Histórico',
      subtitle: 'Apenas serviços Concluídos & 100% Liquidados (pós-proteção) que já saíram dos 3 últimos podem ser escolhidos.',
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var idx = 0; idx < available.length; idx++) ...[
            if (idx > 0) const SizedBox(height: AppSpace.s12),
            CompletedServicePortfolioCard(
              key: ValueKey('history-picker-item-${available[idx].id}'),
              service: available[idx],
              positionBadge: 'Elegível no Histórico',
              isAutomaticTopThree: false,
              showPrice: true,
              onTap: () {
                final item = available[idx];
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
                  AppSnackbar.show(
                    context,
                    replaceServiceId != null
                        ? 'Destaque substituído com sucesso no Meu Portfólio!'
                        : 'Serviço adicionado com sucesso ao Meu Portfólio!',
                    kind: AppSnackKind.success,
                  );
                }
              },
            ),
          ],
        ],
      ),
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

    final (AppTone stageTone, IconData stageIcon) = switch (stage) {
      ServiceHistoryLifecycleStage.settledAndPaid => (
          isAutomaticTopThree ? AppTone.accent : AppTone.success,
          isAutomaticTopThree ? Icons.bolt_rounded : Icons.verified_rounded,
        ),
      ServiceHistoryLifecycleStage.underPostServiceProtection => (
          AppTone.info,
          Icons.shield_moon_rounded,
        ),
      ServiceHistoryLifecycleStage.inMediation => (
          AppTone.warning,
          Icons.gavel_rounded,
        ),
      ServiceHistoryLifecycleStage.canceled => (
          AppTone.danger,
          Icons.cancel_outlined,
        ),
    };

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppStatusChip(positionBadge, tone: stageTone, icon: stageIcon),
              AppStatusChip(service.categoryName, tone: AppTone.neutral),
              if (stage != ServiceHistoryLifecycleStage.canceled)
                AppStatusChip(
                  showPrice
                      ? 'PIN ${service.validatedClientPin} Validado'
                      : 'Conclusão Verificada',
                  tone: AppTone.success,
                  icon: Icons.verified_user_rounded,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            service.title,
            maxLines: 2,
            style: AppType.titleSm.copyWith(color: tk.text),
          ),
          if (service.hasClientRequestedDescription) ...[
            const SizedBox(height: AppSpace.s4),
            Text(
              'Solicitado: ${service.clientRequestedDescription}',
              maxLines: 1,
              style: AppType.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: tk.textMuted,
              ),
            ),
          ],
          const SizedBox(height: AppSpace.s4),
          Text(
            service.detailedExecutionReport,
            maxLines: 2,
            style: AppType.bodySm.copyWith(color: tk.textMuted),
          ),
          if (service.hasComplementaryTechnicalNotes) ...[
            const SizedBox(height: AppSpace.s8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s2),
                  child: Icon(
                    Icons.note_alt_outlined,
                    size: 15,
                    color: tk.accentInk,
                  ),
                ),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: Text(
                    'Notas Técnicas Complementares: ${service.complementaryTechnicalNotes}',
                    maxLines: 2,
                    style: AppType.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tk.accentInk,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpace.s12),

          // ===============================================================
          // BLOCO DE AVALIAÇÃO DO CLIENTE OU STATUS DO HISTÓRICO
          // ===============================================================
          if (stage == ServiceHistoryLifecycleStage.canceled)
            AppCard(
              variant: AppCardVariant.tonal,
              color: tk.dangerSoft,
              radius: AppGeometry.fieldRadius,
              padding: const EdgeInsets.all(AppSpace.s12),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  'Cancelado (${service.canceledByRole == 'client' ? 'pelo Cliente' : (service.canceledByRole == 'provider' ? 'pelo Profissional' : 'Sistema')}): '
                  '${service.cancelReason ?? 'Cancelamento registrado no histórico.'}',
                  style: AppType.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tk.dangerInk,
                  ),
                ),
              ),
            )
          else if (stage == ServiceHistoryLifecycleStage.inMediation)
            AppCard(
              variant: AppCardVariant.tonal,
              color: tk.warningSoft,
              radius: AppGeometry.fieldRadius,
              padding: const EdgeInsets.all(AppSpace.s12),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  'Em Mediação Técnica: ${service.mediationReason ?? 'Análise de evidências em andamento na plataforma.'}',
                  style: AppType.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tk.warningInk,
                  ),
                ),
              ),
            )
          else if (stage == ServiceHistoryLifecycleStage.underPostServiceProtection)
            AppCard(
              variant: AppCardVariant.tonal,
              color: tk.infoSoft,
              radius: AppGeometry.fieldRadius,
              padding: const EdgeInsets.all(AppSpace.s12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_moon_rounded, size: 17, color: tk.accentInk),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Text(
                      'Sob Proteção Pós-Serviço (Em Cobertura Técnica & Maturação) • '
                      '${service.protectionEndsAt != null ? 'Liberação 100% em ${dateShort(service.protectionEndsAt!)}' : 'Aguardando conclusão da janela de proteção para entrar no Portfólio'}',
                      style: AppType.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tk.text,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (service.isReviewedByClient)
            AppCard(
              variant: AppCardVariant.outlined,
              color: tk.card,
              radius: AppGeometry.fieldRadius,
              padding: const EdgeInsets.all(AppSpace.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: tk.star,
                        size: 17,
                      ),
                      const SizedBox(width: AppSpace.s4),
                      Expanded(
                        child: Text(
                          '${(service.clientRating ?? 5.0).toStringAsFixed(1)} • Avaliação de ${service.clientDisplayName ?? 'Cliente Verificado'}',
                          maxLines: 2,
                          style: AppType.tabular(AppType.caption).copyWith(
                            fontWeight: FontWeight.w700,
                            color: tk.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if ((service.clientReviewComment ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s4),
                    Text(
                      '"${service.clientReviewComment}"',
                      maxLines: 2,
                      style: AppType.bodySm.copyWith(
                        fontStyle: FontStyle.italic,
                        color: tk.text,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            AppCard(
              variant: AppCardVariant.outlined,
              color: tk.card,
              radius: AppGeometry.fieldRadius,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s12,
                vertical: AppSpace.s8,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: tk.textMuted,
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Text(
                      'Concluído e validado (${service.clientDisplayName ?? 'Cliente'}) • Aguardando avaliação',
                      style: AppType.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tk.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppSpace.s12),
          // Linha 1 de rodapé: local + data (nunca estoura à direita em 320-390 px)
          Row(
            children: [
              Icon(Icons.place_outlined, size: 15, color: tk.textMuted),
              const SizedBox(width: AppSpace.s4),
              Expanded(
                child: Text(
                  '${service.cityAndState} • ${dateShort(service.completedAt)}',
                  style: AppType.caption.copyWith(
                    color: tk.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          // Linha 2 de rodapé: fotos, valor (só para dono) e "Ver detalhes" em Wrap seguro
          Wrap(
            spacing: AppSpace.s12,
            runSpacing: AppSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (service.beforeAfterPhotoCaptionsOrUrls.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 15,
                      color: tk.accentInk,
                    ),
                    const SizedBox(width: AppSpace.s4),
                    Text(
                      '${service.beforeAfterPhotoCaptionsOrUrls.length} foto(s)',
                      style: AppType.tabular(AppType.caption).copyWith(
                        fontWeight: FontWeight.w700,
                        color: tk.accentInk,
                      ),
                    ),
                  ],
                ),
              // Omissão silenciosa de valores para o Usuário Cliente (`showPrice == false`)
              if (showPrice)
                Text(
                  brl(service.serviceValue),
                  style: AppType.tabular(AppType.bodyStrong).copyWith(color: tk.text),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ver detalhes',
                    style: AppType.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tk.accentInk,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: tk.accentInk,
                  ),
                ],
              ),
            ],
          ),

          if (onSwapFromHistory != null || onRemoveFromPortfolio != null) ...[
            const Divider(height: AppSpace.s20),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                children: [
                  if (onSwapFromHistory != null)
                    AppButton(
                      label: 'Trocar por outro do Histórico',
                      icon: Icons.swap_horiz_rounded,
                      variant: AppButtonVariant.tertiary,
                      expand: false,
                      compact: true,
                      onPressed: onSwapFromHistory,
                    ),
                  if (onRemoveFromPortfolio != null)
                    TextButton.icon(
                      onPressed: onRemoveFromPortfolio,
                      icon: Icon(
                        Icons.remove_circle_outline_rounded,
                        size: 18,
                        color: tk.dangerInk,
                      ),
                      label: Text(
                        'Tirar da Vitrine',
                        style: AppType.bodySm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tk.dangerInk,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
      ],
    );

    return AppCard(
      variant: AppCardVariant.outlined,
      onTap: onTap,
      color: tk.surface,
      borderColor: isAutomaticTopThree
          ? tk.accentInk.withValues(alpha: 0.35)
          : tk.border,
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxHeight.isFinite
            ? SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: content,
              )
            : content,
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
    this.embeddedInSheet = false,
  });

  final String serviceId;
  final bool isOwner;
  final bool embeddedInSheet;

  static Future<void> show(
    BuildContext context, {
    required String serviceId,
    bool isOwner = true,
  }) {
    return AppSheet.show<void>(
      context,
      maxHeightFactor: 0.90,
      builder: (_) => PortfolioServiceDetailSheet(
        serviceId: serviceId,
        isOwner: isOwner,
        embeddedInSheet: true,
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
        AppSnackbar.show(
          context,
          'Notas Técnicas Complementares atualizadas no seu Portfólio!',
          kind: AppSnackKind.success,
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s24),
              child: Text('Serviço não encontrado.', style: AppType.body.copyWith(color: tk.textMuted)),
            ),
          );
        }

        final photos = service.beforeAfterPhotoCaptionsOrUrls;
        final children = <Widget>[
          // Selos de cabeçalho
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              KeyedSubtree(
                key: const ValueKey('detail-sheet-pin-seal'),
                child: AppStatusChip(
                  isOwner
                      ? 'Validado com PIN do Cliente (${service.validatedClientPin})'
                      : 'Serviço Auditado & Verificado na Plataforma',
                  tone: AppTone.success,
                  icon: Icons.verified_user_rounded,
                ),
              ),
              AppStatusChip(service.categoryName, tone: AppTone.accent),
              AppStatusChip(service.lifecycleStage.label, tone: AppTone.neutral),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Text(
            service.title,
            key: const ValueKey('detail-sheet-service-title'),
            style: AppType.headline.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            '${service.cityAndState} • Concluído em ${dateShort(service.completedAt)} • Certificado ${service.warrantyCertificateCode}',
            style: AppType.caption.copyWith(color: tk.textMuted),
          ),
          const SizedBox(height: AppSpace.s16),

          // ===============================================================
          // METADADOS OPERACIONAIS (VALORES VISÍVEIS APENAS PARA O PROFISSIONAL)
          // ===============================================================
          AppCard(
            variant: AppCardVariant.tonal,
            borderColor: tk.border,
            padding: const EdgeInsets.all(AppSpace.s12),
            child: Wrap(
              spacing: AppSpace.s16,
              runSpacing: AppSpace.s8,
              children: [
                if (isOwner) ...[
                  _PortfolioMetaChip(
                    label: 'Líquido (100% Pago)',
                    value: brl(service.serviceValue),
                  ),
                  if (service.materialsAmount > 0)
                    _PortfolioMetaChip(
                      label: 'Peças (Taxa 0%)',
                      value: brl(service.materialsAmount),
                    ),
                ],
                _PortfolioMetaChip(
                  label: 'Tempo de Execução',
                  value: service.executionDurationText,
                ),
                _PortfolioMetaChip(
                  label: 'Cliente',
                  value: service.clientDisplayName ?? 'Verificado',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s16),

          // ===============================================================
          // 1. O QUE FOI SOLICITADO PELO CLIENTE (IMUTÁVEL)
          // ===============================================================
          Text(
            'O que foi solicitado pelo Cliente',
            style: AppType.titleSm.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s8),
          AppCard(
            key: const ValueKey('detail-sheet-client-request'),
            variant: AppCardVariant.tonal,
            borderColor: tk.border,
            radius: AppGeometry.fieldRadius,
            padding: const EdgeInsets.all(AppSpace.s12),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                service.hasClientRequestedDescription
                    ? service.clientRequestedDescription
                    : 'Solicitação de atendimento técnico em ${service.categoryName}: ${service.title}.',
                style: AppType.bodySm.copyWith(color: tk.text),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s16),

          // ===============================================================
          // 2. SOLUÇÃO TÉCNICA APLICADA NA CONCLUSÃO (IMUTÁVEL)
          // ===============================================================
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Solução Técnica Aplicada na Conclusão',
                style: AppType.titleSm.copyWith(color: tk.text),
              ),
              if (isOwner)
                const KeyedSubtree(
                  key: ValueKey('detail-sheet-immutable-lock-badge'),
                  child: AppStatusChip(
                    'Registro Original Imutável',
                    tone: AppTone.neutral,
                    icon: Icons.lock_outline_rounded,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          AppCard(
            key: const ValueKey('detail-sheet-execution-report'),
            variant: AppCardVariant.tonal,
            borderColor: tk.border,
            radius: AppGeometry.fieldRadius,
            padding: const EdgeInsets.all(AppSpace.s12),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                service.detailedExecutionReport,
                style: AppType.bodySm.copyWith(color: tk.text),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s16),

          // ===============================================================
          // 3. NOTAS TÉCNICAS COMPLEMENTARES (EDITÁVEL APENAS PELO PROFISSIONAL)
          // ===============================================================
          if (isOwner || service.hasComplementaryTechnicalNotes) ...[
            AppCard(
              key: const ValueKey('detail-sheet-complementary-notes-section'),
              variant: AppCardVariant.tonal,
              color: tk.providerSoft.withValues(alpha: 0.45),
              borderColor: tk.accentInk.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(AppSpace.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.engineering_rounded,
                        size: 20,
                        color: tk.accentInk,
                      ),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notas Técnicas Complementares',
                              style: AppType.titleSm.copyWith(color: tk.text),
                            ),
                            if (isOwner) ...[
                              const SizedBox(height: AppSpace.s2),
                              Text(
                                'Adicione detalhes técnicos complementares pós-obra para destacar sua execução no Portfólio.',
                                style: AppType.caption.copyWith(color: tk.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isOwner && !_editingComplementaryNotes && !context.layout.isLargeText)
                        AppButton(
                          key: const ValueKey('btn-edit-complementary-notes'),
                          variant: AppButtonVariant.tertiary,
                          compact: true,
                          expand: false,
                          onPressed: () {
                            _notesController.text =
                                service.complementaryTechnicalNotes ?? '';
                            setState(
                              () => _editingComplementaryNotes = true,
                            );
                          },
                          icon: Icons.edit_note_rounded,
                          label: service.hasComplementaryTechnicalNotes
                              ? 'Editar'
                              : 'Adicionar',
                        ),
                    ],
                  ),
                  if (isOwner && !_editingComplementaryNotes && context.layout.isLargeText) ...[
                    const SizedBox(height: AppSpace.s8),
                    AppButton(
                      key: const ValueKey('btn-edit-complementary-notes'),
                      variant: AppButtonVariant.tertiary,
                      compact: true,
                      expand: false,
                      onPressed: () {
                        _notesController.text =
                            service.complementaryTechnicalNotes ?? '';
                        setState(
                          () => _editingComplementaryNotes = true,
                        );
                      },
                      icon: Icons.edit_note_rounded,
                      label: service.hasComplementaryTechnicalNotes
                          ? 'Editar'
                          : 'Adicionar',
                    ),
                  ],
                  const SizedBox(height: AppSpace.s8),
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
                    const SizedBox(height: AppSpace.s8),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: AppSpace.s8,
                      runSpacing: AppSpace.s8,
                      children: [
                        AppButton(
                          label: 'Cancelar',
                          variant: AppButtonVariant.tertiary,
                          expand: false,
                          compact: true,
                          onPressed: _savingNotes
                              ? null
                              : () => setState(
                                    () => _editingComplementaryNotes = false,
                                  ),
                        ),
                        AppButton(
                          key: const ValueKey('btn-save-complementary-notes'),
                          label: 'Salvar Notas Complementares',
                          icon: Icons.check_rounded,
                          expand: false,
                          compact: true,
                          loading: _savingNotes,
                          onPressed: _savingNotes
                              ? null
                              : () => _saveComplementaryNotes(service),
                        ),
                      ],
                    ),
                  ] else if (service.hasComplementaryTechnicalNotes)
                    Text(
                      service.complementaryTechnicalNotes!,
                      key: const ValueKey('text-complementary-notes-value'),
                      style: AppType.bodySm.copyWith(color: tk.text),
                    )
                  else if (isOwner)
                    Text(
                      'Nenhuma nota complementar adicionada ainda. Toque em "Adicionar" para detalhar materiais, normas ou diferenciais deste serviço.',
                      style: AppType.caption.copyWith(color: tk.textMuted),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s20),
          ],

          // ===============================================================
          // 4. GALERIA DE FOTOS DESLIZÁVEL (DA 1ª À ÚLTIMA FOTO — IMUTÁVEL)
          // ===============================================================
          if (photos.isNotEmpty) ...[
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  'Fotos do Serviço (${_currentPhotoIndex + 1} de ${photos.length})',
                  style: AppType.tabular(AppType.titleSm).copyWith(color: tk.text),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Arraste para o lado',
                      style: AppType.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tk.accentInk,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s4),
                    Icon(Icons.arrow_forward_rounded, size: 15, color: tk.accentInk),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s8),
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
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
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
                      left: AppSpace.s8,
                      child: AppIconButton(
                        key: const ValueKey('btn-photo-prev'),
                        tooltip: 'Foto anterior',
                        filled: true,
                        onPressed: () => _pageController.previousPage(
                          duration: AppMotion.d(context, AppMotion.sheet),
                          curve: Curves.easeOutCubic,
                        ),
                        icon: Icons.chevron_left_rounded,
                      ),
                    ),
                  if (photos.length > 1 && _currentPhotoIndex < photos.length - 1)
                    Positioned(
                      right: AppSpace.s8,
                      child: AppIconButton(
                        key: const ValueKey('btn-photo-next'),
                        tooltip: 'Próxima foto',
                        filled: true,
                        onPressed: () => _pageController.nextPage(
                          duration: AppMotion.d(context, AppMotion.sheet),
                          curve: Curves.easeOutCubic,
                        ),
                        icon: Icons.chevron_right_rounded,
                      ),
                    ),
                ],
              ),
            ),
            if (photos.length > 1) ...[
              const SizedBox(height: AppSpace.s8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < photos.length; i++)
                    AnimatedContainer(
                      duration: AppMotion.d(context, const Duration(milliseconds: 180)),
                      margin: const EdgeInsets.symmetric(horizontal: AppSpace.s2 + 1),
                      width: i == _currentPhotoIndex ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _currentPhotoIndex
                            ? tk.accent
                            : tk.border,
                        borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpace.s20),
          ],

          if (service.toolsAndMaterialsUsed.isNotEmpty) ...[
            Text(
              'Ferramental e Insumos Aplicados',
              style: AppType.titleSm.copyWith(color: tk.text),
            ),
            const SizedBox(height: AppSpace.s8),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final tool in service.toolsAndMaterialsUsed)
                  AppStatusChip(tool, tone: AppTone.neutral),
              ],
            ),
            const SizedBox(height: AppSpace.s20),
          ],

          // ===============================================================
          // 5. AVALIAÇÃO REATIVA DO CLIENTE
          // ===============================================================
          Text(
            'Avaliação do Cliente',
            style: AppType.titleSm.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s8),
          if (service.isReviewedByClient)
            AppCard(
              key: const ValueKey('detail-sheet-client-review-box'),
              variant: AppCardVariant.tonal,
              borderColor: tk.warning.withValues(alpha: 0.45),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpace.s8,
                    runSpacing: AppSpace.s4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AppRating(value: service.clientRating ?? 5.0, size: 18),
                      Text(
                        '${(service.clientRating ?? 5.0).toStringAsFixed(1)} • ${service.clientDisplayName ?? 'Cliente Verificado'}',
                        style: AppType.tabular(AppType.bodyStrong).copyWith(color: tk.text),
                      ),
                    ],
                  ),
                  if ((service.clientReviewComment ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s8),
                    Text(
                      '"${service.clientReviewComment}"',
                      style: AppType.bodySm.copyWith(
                        fontStyle: FontStyle.italic,
                        color: tk.text,
                      ),
                    ),
                  ],
                  if (service.clientPraiseTags.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s12),
                    Wrap(
                      spacing: AppSpace.s8,
                      runSpacing: AppSpace.s8,
                      children: [
                        for (final tag in service.clientPraiseTags)
                          AppStatusChip(tag, tone: AppTone.success),
                      ],
                    ),
                  ],
                ],
              ),
            )
          else
            AppCard(
              variant: AppCardVariant.tonal,
              borderColor: tk.border,
              child: Text(
                'Este serviço já foi concluído e auditado. Assim que o cliente registrar sua avaliação, a nota e o comentário aparecerão automaticamente aqui.',
                style: AppType.bodySm.copyWith(color: tk.textMuted),
              ),
            ),
        ];

        if (widget.embeddedInSheet) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );
        }

        return SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.layout.margin,
              AppSpace.s8,
              context.layout.margin,
              AppSpace.s24,
            ),
            children: children,
          ),
        );
      },
    );
  }
}

class _PortfolioMetaChip extends StatelessWidget {
  const _PortfolioMetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppType.caption.copyWith(color: tk.textMuted),
        ),
        const SizedBox(height: AppSpace.s2),
        Text(
          value,
          style: AppType.tabular(AppType.bodyStrong).copyWith(color: tk.text),
        ),
      ],
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
      borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isStoragePathOrUrl)
            _isPublicPath
                ? PublicImage(
                    path: photoOrCaption,
                    height: 230,
                    width: double.infinity,
                    radius: AppGeometry.itemRadius,
                  )
                : SignedImage(
                    path: photoOrCaption,
                    height: 230,
                    width: double.infinity,
                    radius: AppGeometry.itemRadius,
                  )
          else
            Container(
              padding: const EdgeInsets.all(AppSpace.s20),
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
                borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_enhance_rounded,
                    size: 40,
                    color: tk.accentInk,
                  ),
                  const SizedBox(height: AppSpace.s12),
                  Text(
                    photoOrCaption,
                    textAlign: TextAlign.center,
                    style: AppType.bodyStrong.copyWith(color: tk.text),
                  ),
                ],
              ),
            ),
          Positioned(
            top: AppSpace.s12,
            left: AppSpace.s12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s4),
              decoration: BoxDecoration(
                color: tk.scrim,
                borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
              ),
              child: Text(
                'Foto ${index + 1} de $total',
                style: AppType.tabular(AppType.caption).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: AppSpace.s12,
            right: AppSpace.s12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s4),
              decoration: BoxDecoration(
                color: tk.scrim,
                borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.zoom_out_map_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: AppSpace.s4),
                  Text(
                    'Toque para ampliar',
                    style: AppType.caption.copyWith(
                      color: Colors.white,
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
      AppRoute(
        fullscreenModal: true,
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
    final darkTk = AppTokens.dark;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Foto ${_index + 1} de $total • ${widget.serviceTitle}',
          maxLines: 2,
          style: AppType.titleSm.copyWith(color: Colors.white),
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
                    padding: const EdgeInsets.all(AppSpace.s20),
                    child: isPath
                        ? (usePublic
                            ? PublicImage(
                                path: item,
                                height: 480,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                radius: AppGeometry.itemRadius,
                              )
                            : SignedImage(
                                path: item,
                                height: 480,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                radius: AppGeometry.itemRadius,
                              ))
                        : Container(
                            padding: const EdgeInsets.all(AppSpace.s24),
                            decoration: BoxDecoration(
                              color: darkTk.card,
                              borderRadius: BorderRadius.circular(AppGeometry.cardRadius),
                              border: Border.all(color: darkTk.border),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.camera_enhance_rounded,
                                  size: 56,
                                  color: darkTk.star,
                                ),
                                const SizedBox(height: AppSpace.s16),
                                Text(
                                  item,
                                  textAlign: TextAlign.center,
                                  style: AppType.titleSm.copyWith(color: Colors.white),
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
            bottom: AppSpace.s24,
            left: AppSpace.s16,
            right: AppSpace.s16,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s8),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
                ),
                child: Text(
                  'Deslize para o lado para ver todas as fotos (${_index + 1}/$total)',
                  textAlign: TextAlign.center,
                  style: AppType.tabular(AppType.caption).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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
      AppRoute(
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
    final margin = context.layout.margin;

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
          appBar: const AppAppBar(title: 'Histórico de Serviços Prestados'),
          body: ListView(
            padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s24),
            children: [
              AppCard(
                variant: AppCardVariant.tonal,
                color: tk.infoSoft,
                borderColor: tk.info.withValues(alpha: 0.35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_rounded, color: tk.accentInk),
                        const SizedBox(width: AppSpace.s8),
                        Expanded(
                          child: Text(
                            'Seus atendimentos (${state.totalHistoryRecordsCount} registros)',
                            style: AppType.tabular(AppType.titleSm).copyWith(color: tk.text),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s8),
                    Text(
                      'Consulte todos os seus serviços por etapa. Após concluir a proteção pós-serviço e liberar o pagamento, você pode destacá-los no seu Portfólio.',
                      style: AppType.bodySm.copyWith(color: tk.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s12),
              SingleChildScrollView(
                key: const ValueKey('history-filter-strip'),
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      key: const ValueKey('history-chip-all'),
                      showCheckmark: false,
                      label: Text('Todos (${all.length})', style: AppType.bodySm),
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    ChoiceChip(
                      key: const ValueKey('history-chip-settled'),
                      showCheckmark: false,
                      label: Text(
                        'Concluídos 100% Pagos (${state.settledEligibleHistory.length})',
                        style: AppType.bodySm,
                      ),
                      selected: _filter == 'settled',
                      onSelected: (_) => setState(() => _filter = 'settled'),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    ChoiceChip(
                      key: const ValueKey('history-chip-protection'),
                      showCheckmark: false,
                      label: Text(
                        'Sob Proteção Pós-Serviço (${state.underProtectionServices.length})',
                        style: AppType.bodySm,
                      ),
                      selected: _filter == 'protection',
                      onSelected: (_) => setState(() => _filter = 'protection'),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    ChoiceChip(
                      key: const ValueKey('history-chip-mediation'),
                      showCheckmark: false,
                      label: Text(
                        'Em Mediação (${state.inMediationServices.length})',
                        style: AppType.bodySm,
                      ),
                      selected: _filter == 'mediation',
                      onSelected: (_) => setState(() => _filter = 'mediation'),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    ChoiceChip(
                      key: const ValueKey('history-chip-canceled'),
                      showCheckmark: false,
                      label: Text(
                        'Cancelados (${state.canceledServices.length})',
                        style: AppType.bodySm,
                      ),
                      selected: _filter == 'canceled',
                      onSelected: (_) => setState(() => _filter = 'canceled'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s16),
              if (filtered.isEmpty)
                const AppEmptyState(
                  icon: Icons.history_rounded,
                  title: 'Nenhum serviço registrado neste filtro',
                  message:
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
                        badge = 'Concluído & 100% Liquidado (#${rankIndex + 1})';
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                      AppSnackbar.show(
                                        context,
                                        'Removido dos destaques do Portfólio (mantido no Histórico).',
                                      );
                                    }
                                  : null,
                            ),
                            if (canPick)
                              Padding(
                                padding: const EdgeInsets.only(top: AppSpace.s8),
                                child: AppButton(
                                  key: ValueKey('history-add-to-portfolio-${s.id}'),
                                  variant: AppButtonVariant.secondary,
                                  compact: true,
                                  onPressed: () {
                                    final ok = store
                                        .addServiceFromHistoryToPortfolio(
                                      s.id,
                                    );
                                    if (ok) {
                                      AppSnackbar.show(
                                        context,
                                        'Serviço destacado no Meu Portfólio (+1)!',
                                        kind: AppSnackKind.success,
                                      );
                                    }
                                  },
                                  icon: Icons.push_pin_outlined,
                                  label:
                                      'Destacar no Meu Portfólio (+1 • ${state.curatedPortfolioServices.length}/$kMaxCuratedPortfolioServices)',
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

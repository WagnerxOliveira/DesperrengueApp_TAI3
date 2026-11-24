import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/smart_triage_models.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/utils/structured_voice_brief.dart';

/// Cartão de leitura rápida para o profissional (e revisão do cliente) quando a
/// descrição foi estruturada em briefing (`RESUMO`, `LOCAL E EQUIPAMENTO`,
/// `SINTOMAS`, `HISTÓRICO`, `OBSERVAÇÕES`, `URGÊNCIA / HORÁRIO`).
///
/// Para textos livres legados sem cabeçalhos, exibe `Text(description)` comum.
class StructuredClientBriefView extends StatelessWidget {
  const StructuredClientBriefView({
    super.key,
    required this.description,
    this.compactMode = false,
  });

  final String description;
  final bool compactMode;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final brief = StructuredVoiceBrief.tryParseStructuredText(description);
    if (brief == null) {
      return Text(description, style: AppType.body.copyWith(color: tk.text));
    }

    final hasCritical = brief.safetyRisk == 'critical';
    final hasAttention = brief.safetyRisk == 'attention';

    return Column(
      key: const ValueKey('structured-client-brief-view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 17,
                  color: compactMode ? tk.accentInk : tk.providerAccentInk,
                ),
                const SizedBox(width: AppSpace.s4 + 2),
                Text(
                  'Relato estruturado',
                  style: AppType.bodySm.copyWith(
                    color: compactMode ? tk.accentInk : tk.providerAccentInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (hasCritical)
              const AppStatusChip(
                'Risco crítico',
                tone: AppTone.danger,
                icon: Icons.warning_amber_rounded,
              )
            else if (hasAttention)
              const AppStatusChip(
                'Requer atenção técnica',
                tone: AppTone.warning,
                icon: Icons.bolt_rounded,
              ),
          ],
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          brief.problemSummary,
          style: AppType.bodyStrong.copyWith(color: tk.text),
        ),
        if (brief.locationAndEquipment != null) ...[
          const SizedBox(height: AppSpace.s8),
          _BriefRow(
            icon: Icons.home_repair_service_outlined,
            label: 'Local e equipamento',
            value: brief.locationAndEquipment!,
          ),
        ],
        if (brief.observedSymptoms.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s8),
          _BriefRow(
            icon: Icons.fact_check_outlined,
            label: 'Sintomas relatados',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final sym in brief.observedSymptoms)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: AppType.bodySm.copyWith(
                            color: tk.accentInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            sym,
                            style: AppType.bodySm.copyWith(color: tk.text),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (brief.timelineAndContext != null) ...[
          const SizedBox(height: AppSpace.s8),
          _BriefRow(
            icon: Icons.history_rounded,
            label: 'Quando começou / gatilho',
            value: brief.timelineAndContext!,
          ),
        ],
        if (brief.clientActionsOrNotes != null) ...[
          const SizedBox(height: AppSpace.s8),
          _BriefRow(
            icon: Icons.build_circle_outlined,
            label: 'Já feito / observações',
            value: brief.clientActionsOrNotes!,
          ),
        ],
        if (brief.urgencyAndAvailability != null) ...[
          const SizedBox(height: AppSpace.s8),
          _BriefRow(
            icon: Icons.schedule_rounded,
            label: 'Urgência / disponibilidade',
            value: brief.urgencyAndAvailability!,
          ),
        ],
        if (!compactMode && brief.photoNotes.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s8),
          _BriefRow(
            icon: Icons.photo_camera_outlined,
            label: 'Observações nas fotos',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final note in brief.photoNotes)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s2),
                    child: Text(
                      note,
                      style: AppType.bodySm.copyWith(color: tk.text),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BriefRow extends StatelessWidget {
  const _BriefRow({
    required this.icon,
    required this.label,
    this.value,
    this.child,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s8,
      ),
      decoration: BoxDecoration(
        color: tk.card,
        borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
        border: Border.all(color: tk.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: tk.textMuted),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppType.bodySm.copyWith(
                    color: tk.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpace.s2),
                if (child != null)
                  child!
                else if (value != null)
                  Text(
                    value!,
                    style: AppType.bodySm.copyWith(color: tk.text),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

AppTone _urgencyTone(UrgencyLevel level) => switch (level) {
      UrgencyLevel.criticalEmergency => AppTone.danger,
      UrgencyLevel.high => AppTone.warning,
      UrgencyLevel.medium => AppTone.info,
      UrgencyLevel.low => AppTone.success,
    };

/// Gatilho visual "Diagnosticar e Listar Peças com IA" na abertura do chamado.
class SmartTriageTriggerBar extends StatelessWidget {
  const SmartTriageTriggerBar({
    super.key,
    required this.hasResult,
    required this.analyzing,
    required this.onTrigger,
  });

  final bool hasResult;
  final bool analyzing;
  final VoidCallback onTrigger;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      key: const ValueKey('smart-triage-trigger-container'),
      variant: AppCardVariant.tonal,
      borderColor: tk.accent.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppGeometry.iconTileSize,
                height: AppGeometry.iconTileSize,
                decoration: BoxDecoration(
                  color: tk.accentSoft,
                  borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: tk.accentInk, size: 22),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Triagem Inteligente Multimodal',
                      style: AppType.titleSm.copyWith(color: tk.text),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    Text(
                      'Gera diagnóstico técnico, checklist de peças e primeiros socorros do imóvel em 60s.',
                      style: AppType.bodySm.copyWith(color: tk.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Builder(
            builder: (context) {
              final reduced = AppMotion.reduced(context);
              final showSpinner = analyzing && !reduced;
              final label = analyzing
                  ? 'Analisando diagnóstico com IA...'
                  : (hasResult
                      ? 'Atualizar Diagnóstico e Lista de Peças com IA'
                      : 'Diagnosticar e Listar Peças com IA');
              return AppButton(
                key: const ValueKey('btn-smart-triage'),
                label: label,
                icon: analyzing && reduced ? Icons.hourglass_top_rounded : Icons.auto_awesome_rounded,
                loading: showSpinner,
                onPressed: analyzing ? null : onTrigger,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Frente 1 — Card de Diagnóstico Técnico + Checklist Interativo de Peças + Ferramental.
class SmartTriageCard extends StatelessWidget {
  const SmartTriageCard({
    super.key,
    required this.result,
    required this.onToggleMaterial,
    this.selectedCategory,
    this.onApplyCategory,
  });

  final SmartTriageResult result;
  final ValueChanged<String> onToggleMaterial;
  final String? selectedCategory;
  final ValueChanged<String>? onApplyCategory;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final confidencePct = (result.confidenceScore * 100).round().clamp(1, 99);
    final showApplyCategory = onApplyCategory != null &&
        selectedCategory != result.suggestedCategoryName;

    return AppCard(
      key: const ValueKey('smart-triage-card'),
      variant: AppCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Cabeçalho Inteligente
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppStatusChip(
                'Sugerida: ${result.suggestedCategoryName}',
                tone: AppTone.accent,
                icon: categoryIcon(result.suggestedCategoryName),
              ),
              if (showApplyCategory)
                ActionChip(
                  key: const ValueKey('triage-apply-category'),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  visualDensity: VisualDensity.standard,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s12),
                  avatar: Icon(Icons.check_circle_outline_rounded, size: 16, color: tk.accentInk),
                  label: Text(
                    'Aplicar categoria',
                    style: AppType.caption.copyWith(fontWeight: FontWeight.w700, color: tk.accentInk),
                  ),
                  onPressed: () => onApplyCategory?.call(result.suggestedCategoryName),
                ),
              AppStatusChip(
                '${result.urgencyLevel.label} • ${result.urgencyLevel.slaTargetText}',
                tone: _urgencyTone(result.urgencyLevel),
                icon: result.urgencyLevel.icon,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              _MetaPill(
                icon: Icons.verified_outlined,
                label: '$confidencePct% de precisão',
              ),
              _MetaPill(
                icon: Icons.timer_outlined,
                label: 'Tempo estimado: ${result.estimatedDurationRange}',
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s16),

          // ---- Resumo Técnico & Causa Provável
          AppCard(
            variant: AppCardVariant.tonal,
            padding: const EdgeInsets.all(AppSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 18, color: tk.accentInk),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text(
                        'Diagnóstico Preliminar & Causa Provável',
                        style: AppType.bodyStrong.copyWith(color: tk.text),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s8),
                Text(
                  result.diagnosticSummary,
                  style: AppType.body.copyWith(fontWeight: FontWeight.w600, color: tk.text),
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  'Hipótese técnica: ${result.probableRootCause}',
                  style: AppType.bodySm.copyWith(color: tk.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s16),

          // ---- Lista Provável de Peças (Evita Visita Perdida)
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 18, color: tk.accentInk),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  'Lista Provável de Peças (Evita Visita Perdida)',
                  style: AppType.titleSm.copyWith(color: tk.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            'Marque as peças que você já tem em casa para o profissional saber exatamente o que precisa levar.',
            style: AppType.bodySm.copyWith(color: tk.textMuted),
          ),
          const SizedBox(height: AppSpace.s12),
          for (final item in result.probableMaterials)
            _MaterialCheckTile(
              item: item,
              onToggle: () => onToggleMaterial(item.id),
            ),

          if (result.recommendedProviderTools.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s12),
            Row(
              children: [
                Icon(Icons.construction_rounded, size: 18, color: tk.textMuted),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: Text(
                    'Ferramental Recomendado ao Profissional',
                    style: AppType.bodyStrong.copyWith(color: tk.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s8),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final tool in result.recommendedProviderTools)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s12,
                      vertical: AppSpace.s8 - 2,
                    ),
                    decoration: BoxDecoration(
                      color: tk.surface,
                      borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
                      border: Border.all(color: tk.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.build_circle_outlined, size: 16, color: tk.textMuted),
                        const SizedBox(width: AppSpace.s4 + 2),
                        Flexible(
                          child: Text(
                            tool,
                            style: AppType.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: tk.text,
                            ),
                          ),
                        ),
                      ],
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

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s4 + 1),
      decoration: BoxDecoration(
        color: tk.surface,
        borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
        border: Border.all(color: tk.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tk.textMuted),
          const SizedBox(width: AppSpace.s4 + 1),
          Flexible(
            child: Text(
              label,
              style: AppType.tabular(AppType.caption).copyWith(
                fontWeight: FontWeight.w600,
                color: tk.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialCheckTile extends StatelessWidget {
  const _MaterialCheckTile({required this.item, required this.onToggle});

  final ProbableMaterialItem item;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final hasIt = item.clientAlreadyHasIt;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: AppPressable(
        key: ValueKey('triage-material-${item.id}'),
        onTap: onToggle,
        borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
        scale: 0.985,
        child: AnimatedContainer(
          duration: AppMotion.d(context, AppMotion.fadeShort),
          curve: AppMotion.fadeCurve,
          padding: const EdgeInsets.all(AppSpace.s12),
          decoration: BoxDecoration(
            color: hasIt ? tk.successSoft.withValues(alpha: tk.isDark ? 0.45 : 0.65) : tk.surface,
            borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
            border: Border.all(
              color: hasIt ? tk.success.withValues(alpha: 0.65) : tk.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: hasIt,
                      onChanged: (_) => onToggle(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: AppType.bodyStrong.copyWith(color: tk.text),
                        ),
                        const SizedBox(height: AppSpace.s2),
                        Text(
                          item.technicalSpec,
                          style: AppType.bodySm.copyWith(color: tk.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s8),
              Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8 - 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s8,
                      vertical: AppSpace.s4,
                    ),
                    decoration: BoxDecoration(
                      color: tk.card,
                      borderRadius: BorderRadius.circular(AppSpace.s8),
                      border: Border.all(color: tk.border),
                    ),
                    child: Text(
                      'Qtd: ${item.estimatedQuantity}${item.isOptional ? ' (se necessário)' : ''}',
                      style: AppType.tabular(AppType.caption).copyWith(
                        fontWeight: FontWeight.w600,
                        color: tk.text,
                      ),
                    ),
                  ),
                  AppStatusChip(
                    hasIt ? 'Já tenho esta peça • Cliente fornece' : 'Prestador deve trazer',
                    tone: hasIt ? AppTone.success : AppTone.warning,
                    icon: hasIt ? Icons.check_rounded : Icons.handyman_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frente 1 (Visão do Prestador) — Resumo da Triagem Inteligente nos Detalhes do Chamado.
class ProviderTriageBriefCard extends StatelessWidget {
  const ProviderTriageBriefCard({super.key, required this.result});

  final SmartTriageResult result;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final mustBring = result.materialsProviderMustBring;
    final clientHas = result.materialsClientProvides;
    final guide = result.containmentGuide;

    return AppCard(
      key: const ValueKey('provider-triage-brief-card'),
      variant: AppCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8 - 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 18, color: tk.providerAccentInk),
                  const SizedBox(width: AppSpace.s8 - 2),
                  Flexible(
                    child: Text(
                      'Dossiê de Triagem Técnica (IA)',
                      style: AppType.titleSm.copyWith(color: tk.text),
                    ),
                  ),
                ],
              ),
              AppStatusChip(
                result.urgencyLevel.label,
                tone: _urgencyTone(result.urgencyLevel),
              ),
              _MetaPill(
                icon: Icons.timer_outlined,
                label: result.estimatedDurationRange,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Text(
            result.diagnosticSummary,
            style: AppType.body.copyWith(fontWeight: FontWeight.w600, color: tk.text),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            'Causa provável: ${result.probableRootCause}',
            style: AppType.bodySm.copyWith(color: tk.textMuted),
          ),
          if (guide != null) ...[
            const SizedBox(height: AppSpace.s12),
            AppCard(
              variant: AppCardVariant.tonal,
              color: guide.isFullyContained ? tk.successSoft : tk.infoSoft,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12, vertical: AppSpace.s8),
              child: Row(
                children: [
                  Icon(
                    guide.isFullyContained
                        ? Icons.verified_user_rounded
                        : Icons.health_and_safety_outlined,
                    size: 18,
                    color: guide.isFullyContained ? tk.successInk : tk.providerAccentInk,
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Text(
                      'Contenção de emergência pelo cliente: ${guide.completedStepsCount}/${guide.steps.length} passos concluídos',
                      style: AppType.tabular(AppType.bodySm).copyWith(
                        fontWeight: FontWeight.w700,
                        color: guide.isFullyContained ? tk.successInk : tk.providerAccentInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpace.s12),
          Text(
            'Peças que você deve levar (${mustBring.length}):',
            style: AppType.tabular(AppType.bodyStrong).copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s8 - 2),
          if (mustBring.isEmpty)
            Text(
              'O cliente informou que já possui todas as peças listadas no local.',
              style: AppType.bodySm.copyWith(
                fontWeight: FontWeight.w600,
                color: tk.successInk,
              ),
            )
          else
            for (final m in mustBring)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_right_rounded, size: 18, color: tk.providerAccentInk),
                    Expanded(
                      child: Text(
                        '${m.name} (${m.estimatedQuantity}) — ${m.technicalSpec}',
                        style: AppType.bodySm.copyWith(color: tk.text),
                      ),
                    ),
                  ],
                ),
              ),
          if (clientHas.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s8),
            Text(
              'Peças que o cliente já tem no local (${clientHas.length}):',
              style: AppType.tabular(AppType.bodyStrong).copyWith(color: tk.successInk),
            ),
            const SizedBox(height: AppSpace.s4),
            for (final m in clientHas)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: tk.successInk),
                    const SizedBox(width: AppSpace.s8 - 2),
                    Expanded(
                      child: Text(
                        '${m.name} (${m.estimatedQuantity})',
                        style: AppType.bodySm.copyWith(color: tk.text),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (result.recommendedProviderTools.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s12),
            Text(
              'Ferramentas recomendadas para a maleta:',
              style: AppType.bodyStrong.copyWith(color: tk.text),
            ),
            const SizedBox(height: AppSpace.s8),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8 - 2,
              children: [
                for (final t in result.recommendedProviderTools)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s12,
                      vertical: AppSpace.s4,
                    ),
                    decoration: BoxDecoration(
                      color: tk.surface,
                      borderRadius: BorderRadius.circular(AppSpace.s8),
                      border: Border.all(color: tk.border),
                    ),
                    child: Text(
                      t,
                      style: AppType.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tk.text,
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

/// Frente 2 — Card interativo "Primeiros Socorros do Imóvel (Ação em 60s)".
class EmergencyContainmentBanner extends StatelessWidget {
  const EmergencyContainmentBanner({
    super.key,
    required this.guide,
    required this.onToggleStep,
  });

  final EmergencyContainmentGuide guide;
  final ValueChanged<int> onToggleStep;

  Future<void> _callEmergency(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        AppSnackbar.show(context, 'Ligue imediatamente para $phone.', kind: AppSnackKind.warning);
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.show(context, 'Ligue imediatamente para $phone.', kind: AppSnackKind.warning);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final done = guide.isFullyContained;
    final accentFill = done ? tk.success : tk.danger;
    final accentInk = done ? tk.successInk : tk.dangerInk;
    final containerBg = done
        ? tk.successSoft.withValues(alpha: tk.isDark ? 0.45 : 0.65)
        : tk.dangerSoft.withValues(alpha: tk.isDark ? 0.45 : 0.6);

    return AppCard(
      key: const ValueKey('emergency-containment-banner'),
      variant: AppCardVariant.tonal,
      color: containerBg,
      borderColor: accentFill.withValues(alpha: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Cabeçalho de Alerta Controlado
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppGeometry.iconTileSize,
                height: AppGeometry.iconTileSize,
                decoration: BoxDecoration(
                  color: accentFill.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
                ),
                child: Icon(
                  done ? Icons.health_and_safety_rounded : Icons.warning_amber_rounded,
                  color: accentInk,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Primeiros Socorros do Imóvel (Ação em ${guide.targetActionSeconds}s)',
                      style: AppType.titleSm.copyWith(color: tk.text),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    Text(
                      guide.emergencyTypeTitle,
                      style: AppType.bodySm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accentInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            'Enquanto o profissional está a caminho, execute os passos abaixo para estancar o dano material e garantir sua segurança.',
            style: AppType.bodySm.copyWith(color: tk.text),
          ),

          // ---- Alertas de Proibição Crítica
          if (guide.criticalProhibitions.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s12),
            AppCard(
              variant: AppCardVariant.tonal,
              color: tk.dangerSoft,
              borderColor: tk.danger.withValues(alpha: 0.55),
              padding: const EdgeInsets.all(AppSpace.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.do_not_disturb_on_rounded, size: 16, color: tk.dangerInk),
                      const SizedBox(width: AppSpace.s8 - 2),
                      Expanded(
                        child: Text(
                          'PROIBIÇÕES CRÍTICAS DE SEGURANÇA',
                          style: AppType.overline.copyWith(color: tk.dangerInk),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s8),
                  for (final p in guide.criticalProhibitions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: AppType.bodySm.copyWith(fontWeight: FontWeight.w700, color: tk.dangerInk),
                          ),
                          Expanded(
                            child: Text(
                              p,
                              style: AppType.bodySm.copyWith(
                                fontWeight: FontWeight.w600,
                                color: tk.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          // ---- Barra de Progresso de Contenção
          const SizedBox(height: AppSpace.s12),
          Row(
            children: [
              Expanded(
                child: Text(
                  done
                      ? 'Contenção inicial concluída! Imóvel estabilizado aguardando o profissional.'
                      : '${guide.completedStepsCount} de ${guide.steps.length} medidas concluídas',
                  style: AppType.tabular(AppType.bodySm).copyWith(
                    fontWeight: FontWeight.w700,
                    color: done ? tk.successInk : tk.text,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              Text(
                '${(guide.completionProgress * 100).round()}%',
                style: AppType.tabular(AppType.bodyStrong).copyWith(color: accentInk),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s8 - 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: guide.completionProgress),
              duration: AppMotion.d(context, AppMotion.progress),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: AppSpace.s8,
                backgroundColor: tk.card.withValues(alpha: 0.75),
                valueColor: AlwaysStoppedAnimation<Color>(accentFill),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s12),

          // ---- Lista de Passos Clicáveis
          for (final step in guide.steps)
            _ContainmentStepTile(
              step: step,
              onTap: () => onToggleStep(step.stepNumber),
            ),

          // ---- Botão de Emergência Pública (193 / 199)
          if (guide.emergencyPublicPhone != null) ...[
            const SizedBox(height: AppSpace.s8),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppGeometry.buttonHeight),
              child: AppButton(
                key: const ValueKey('emergency-public-call'),
                variant: AppButtonVariant.destructive,
                icon: Icons.phone_in_talk_rounded,
                label: guide.emergencyPublicLabel ??
                    'Emergência Pública (${guide.emergencyPublicPhone})',
                onPressed: () => _callEmergency(context, guide.emergencyPublicPhone!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContainmentStepTile extends StatelessWidget {
  const _ContainmentStepTile({required this.step, required this.onTap});

  final ContainmentStep step;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final completed = step.isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: AppPressable(
        key: ValueKey('containment-step-${step.stepNumber}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
        scale: 0.985,
        child: AnimatedContainer(
          duration: AppMotion.d(context, AppMotion.fadeShort),
          curve: AppMotion.fadeCurve,
          padding: const EdgeInsets.all(AppSpace.s12),
          decoration: BoxDecoration(
            color: tk.card,
            borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
            border: Border.all(
              color: completed
                  ? tk.success.withValues(alpha: 0.7)
                  : (step.isCriticalSafetyWarning
                      ? tk.danger.withValues(alpha: 0.55)
                      : tk.border),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completed ? tk.success : tk.accentSoft,
                ),
                child: completed
                    ? Icon(Icons.check_rounded, size: 18, color: AppTokens.onColor(tk.success))
                    : Icon(step.iconData, size: 18, color: tk.accentInk),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (step.isCriticalSafetyWarning &&
                        step.safetyWarningBadgeText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s4),
                        child: AppStatusChip(
                          step.safetyWarningBadgeText!,
                          tone: AppTone.danger,
                        ),
                      ),
                    Text(
                      '${step.stepNumber}. ${step.title}',
                      style: AppType.bodyStrong.copyWith(
                        decoration: completed ? TextDecoration.lineThrough : null,
                        color: completed ? tk.textMuted : tk.text,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    Text(
                      step.description,
                      style: AppType.bodySm.copyWith(color: tk.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              Icon(
                completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: completed ? tk.successInk : tk.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

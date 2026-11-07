import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/smart_triage_models.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final tk = context.tk;
    return Container(
      key: const ValueKey('smart-triage-trigger-container'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: tk.isDark ? 0.55 : 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tk.clientAccent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tk.clientSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.auto_awesome, color: tk.clientAccent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Triagem Inteligente Multimodal',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gera diagnóstico técnico, checklist de peças e primeiros socorros do imóvel em 60s.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: tk.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              key: const ValueKey('btn-smart-triage'),
              onPressed: analyzing ? null : onTrigger,
              icon: analyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                hasResult
                    ? 'Atualizar Diagnóstico e Lista de Peças com IA'
                    : 'Diagnosticar e Listar Peças com IA',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: tk.clientAccent,
                foregroundColor: AppTokens.onColor(tk.clientAccent),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
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
    final scheme = Theme.of(context).colorScheme;
    final tk = context.tk;
    final urgencyColor = result.urgencyLevel.resolveColor(scheme);
    final urgencyBg = result.urgencyLevel.resolveContainerColor(scheme);
    final confidencePct = (result.confidenceScore * 100).round().clamp(1, 99);
    final showApplyCategory = onApplyCategory != null &&
        selectedCategory != result.suggestedCategoryName;

    return Container(
      key: const ValueKey('smart-triage-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tk.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Cabeçalho Inteligente
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      categoryIcon(result.suggestedCategoryName),
                      size: 15,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Sugerida: ${result.suggestedCategoryName}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (showApplyCategory)
                ActionChip(
                  key: const ValueKey('triage-apply-category'),
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(Icons.check_circle_outline_rounded,
                      size: 16, color: tk.clientAccent),
                  label: const Text(
                    'Aplicar categoria',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () =>
                      onApplyCategory?.call(result.suggestedCategoryName),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: urgencyBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: urgencyColor.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(result.urgencyLevel.icon, size: 15, color: urgencyColor),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${result.urgencyLevel.label} • ${result.urgencyLevel.slaTargetText}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: urgencyColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MetaPill(
                icon: Icons.verified_outlined,
                label: '$confidencePct% de precisão',
              ),
              _MetaPill(
                icon: Icons.timer_outlined,
                label: '⏱ Tempo estimado: ${result.estimatedDurationRange}',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ---- Resumo Técnico & Causa Provável
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(
                alpha: tk.isDark ? 0.45 : 0.6,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: tk.clientAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Diagnóstico Preliminar & Causa Provável',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  result.diagnosticSummary,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    height: 1.35,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hipótese técnica: ${result.probableRootCause}',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: tk.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- Lista Provável de Peças (Evita Visita Perdida)
          Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 18, color: tk.clientAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lista Provável de Peças (Evita Visita Perdida)',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Marque as peças que você já tem em casa para o profissional saber exatamente o que precisa levar.',
            style: TextStyle(fontSize: 12, color: tk.textMuted, height: 1.3),
          ),
          const SizedBox(height: 10),
          for (final item in result.probableMaterials)
            _MaterialCheckTile(
              item: item,
              onToggle: () => onToggleMaterial(item.id),
            ),

          if (result.recommendedProviderTools.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.construction_rounded,
                    size: 17, color: tk.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ferramental Recomendado ao Profissional',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tool in result.recommendedProviderTools)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: tk.isDark ? 0.5 : 0.75,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tk.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.build_circle_outlined,
                            size: 14, color: tk.textMuted),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            tool,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
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
    final scheme = Theme.of(context).colorScheme;
    final tk = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(
          alpha: tk.isDark ? 0.5 : 0.7,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tk.textMuted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
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
    final scheme = Theme.of(context).colorScheme;
    final tk = context.tk;
    final hasIt = item.clientAlreadyHasIt;
    final tagColor = hasIt ? tk.successInk : tk.warningInk;
    final tagBg = hasIt ? tk.successSoft : tk.warningSoft;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: ValueKey('triage-material-${item.id}'),
        onTap: onToggle,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasIt
                ? tk.successSoft.withValues(alpha: tk.isDark ? 0.35 : 0.55)
                : scheme.surfaceContainerHighest.withValues(
                    alpha: tk.isDark ? 0.35 : 0.45,
                  ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasIt
                  ? tk.success.withValues(alpha: 0.6)
                  : tk.border,
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.technicalSpec,
                          style: TextStyle(
                            fontSize: 12,
                            color: tk.textMuted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tk.border),
                    ),
                    child: Text(
                      'Qtd: ${item.estimatedQuantity}${item.isOptional ? ' (se necessário)' : ''}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tagBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hasIt
                          ? '✓ Já tenho esta peça • Cliente fornece'
                          : 'Prestador deve trazer',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: tagColor,
                      ),
                    ),
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
    final scheme = Theme.of(context).colorScheme;
    final tk = context.tk;
    final mustBring = result.materialsProviderMustBring;
    final clientHas = result.materialsClientProvides;
    final guide = result.containmentGuide;
    final urgencyColor = result.urgencyLevel.resolveColor(scheme);
    final urgencyBg = result.urgencyLevel.resolveContainerColor(scheme);

    return Container(
      key: const ValueKey('provider-triage-brief-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tk.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: tk.providerAccent),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Dossiê de Triagem Técnica (IA)',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: urgencyBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  result.urgencyLevel.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: urgencyColor,
                  ),
                ),
              ),
              _MetaPill(
                icon: Icons.timer_outlined,
                label: '⏱ ${result.estimatedDurationRange}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            result.diagnosticSummary,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              height: 1.35,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Causa provável: ${result.probableRootCause}',
            style: TextStyle(fontSize: 12.5, color: tk.textMuted, height: 1.35),
          ),
          if (guide != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: guide.isFullyContained ? tk.successSoft : tk.infoSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    guide.isFullyContained
                        ? Icons.verified_user_rounded
                        : Icons.health_and_safety_outlined,
                    size: 18,
                    color: guide.isFullyContained ? tk.successInk : tk.info,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Contenção de emergência pelo cliente: ${guide.completedStepsCount}/${guide.steps.length} passos concluídos',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: guide.isFullyContained ? tk.successInk : tk.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Peças que você deve levar (${mustBring.length}):',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          if (mustBring.isEmpty)
            Text(
              'O cliente informou que já possui todas as peças listadas no local.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: tk.successInk,
              ),
            )
          else
            for (final m in mustBring)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_right_rounded,
                        size: 18, color: tk.providerAccent),
                    Expanded(
                      child: Text(
                        '${m.name} (${m.estimatedQuantity}) — ${m.technicalSpec}',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          if (clientHas.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Peças que o cliente já tem no local (${clientHas.length}):',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: tk.successInk,
              ),
            ),
            const SizedBox(height: 4),
            for (final m in clientHas)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 15, color: tk.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${m.name} (${m.estimatedQuantity})',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (result.recommendedProviderTools.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Ferramentas recomendadas para a maleta:',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in result.recommendedProviderTools)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: tk.isDark ? 0.5 : 0.75,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
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
        showSnack(context, 'Ligue imediatamente para $phone.');
      }
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'Ligue imediatamente para $phone.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tk = context.tk;
    final done = guide.isFullyContained;
    final accentColor = done ? tk.success : tk.danger;
    final containerBg = done
        ? tk.successSoft.withValues(alpha: tk.isDark ? 0.45 : 0.65)
        : scheme.errorContainer.withValues(alpha: tk.isDark ? 0.35 : 0.45);

    return Container(
      key: const ValueKey('emergency-containment-banner'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.65),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Cabeçalho de Alerta Controlado
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  done
                      ? Icons.health_and_safety_rounded
                      : Icons.warning_amber_rounded,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Primeiros Socorros do Imóvel (Ação em ${guide.targetActionSeconds}s)',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      guide.emergencyTypeTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enquanto o profissional está a caminho, execute os passos abaixo para estancar o dano material e garantir sua segurança.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: scheme.onSurface.withValues(alpha: 0.88),
            ),
          ),

          // ---- Alertas de Proibição Crítica
          if (guide.criticalProhibitions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tk.dangerSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tk.danger.withValues(alpha: 0.55)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.do_not_disturb_on_rounded,
                          size: 16, color: tk.danger),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'PROIBIÇÕES CRÍTICAS DE SEGURANÇA',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: tk.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final p in guide.criticalProhibitions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: tk.danger,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              p,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                                color: scheme.onSurface,
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  done
                      ? 'Contenção inicial concluída! Imóvel estabilizado aguardando o profissional.'
                      : '${guide.completedStepsCount} de ${guide.steps.length} medidas concluídas',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: done ? tk.successInk : scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(guide.completionProgress * 100).round()}%',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: guide.completionProgress),
              duration: const Duration(milliseconds: 280),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: scheme.surface.withValues(alpha: 0.7),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ---- Lista de Passos Clicáveis
          for (final step in guide.steps)
            _ContainmentStepTile(
              step: step,
              onTap: () => onToggleStep(step.stepNumber),
            ),

          // ---- Botão de Emergência Pública (193 / 199)
          if (guide.emergencyPublicPhone != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('emergency-public-call'),
                onPressed: () =>
                    _callEmergency(context, guide.emergencyPublicPhone!),
                icon: Icon(Icons.phone_in_talk_rounded,
                    size: 18, color: tk.danger),
                label: Text(
                  guide.emergencyPublicLabel ??
                      'Emergência Pública (${guide.emergencyPublicPhone})',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: tk.danger,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: scheme.surface,
                  side: BorderSide(color: tk.danger, width: 1.4),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
    final scheme = Theme.of(context).colorScheme;
    final tk = context.tk;
    final completed = step.isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: ValueKey('containment-step-${step.stepNumber}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
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
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completed ? tk.success : tk.clientSoft,
                ),
                child: completed
                    ? const Icon(Icons.check_rounded,
                        size: 18, color: Colors.white)
                    : Icon(step.iconData, size: 17, color: tk.clientAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (step.isCriticalSafetyWarning &&
                        step.safetyWarningBadgeText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tk.dangerSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            step.safetyWarningBadgeText!,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: tk.danger,
                            ),
                          ),
                        ),
                      ),
                    Text(
                      '${step.stepNumber}. ${step.title}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        decoration:
                            completed ? TextDecoration.lineThrough : null,
                        color: completed ? tk.textMuted : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      step.description,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: tk.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                completed
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: completed ? tk.success : tk.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

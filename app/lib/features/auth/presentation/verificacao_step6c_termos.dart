import 'package:flutter/material.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/legal_mandate_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';

/// Tela oficial de Termos de Uso, Política de Privacidade e Cláusula-Mandato
/// Mercantil Expressa (Art. 653 do Código Civil — Split 85% / 13,5% / 1,5% + 0% Peças NF-e),
/// com seletor segmentado **Termos do Cliente** | **Termos do Profissional** para consulta
/// pública ou autenticada a qualquer momento.
class VerificacaoStep6cTermosScreen extends StatefulWidget {
  const VerificacaoStep6cTermosScreen({super.key, this.initialMode});

  final UserMode? initialMode;

  @override
  State<VerificacaoStep6cTermosScreen> createState() =>
      _VerificacaoStep6cTermosScreenState();
}

class _VerificacaoStep6cTermosScreenState
    extends State<VerificacaoStep6cTermosScreen> {
  late UserMode _selectedMode = widget.initialMode ?? UserMode.provider;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    final canonicalHex = LegalMandateService.currentDocumentSha256Hex;
    final modeHex = LegalMandateService.sha256ForMode(_selectedMode);
    final modeVersion = LegalMandateService.versionForMode(_selectedMode);
    final clauses = LegalMandateService.clausesForMode(_selectedMode);
    final isClient = _selectedMode == UserMode.client;

    return AppScaffold(
      backgroundColor: tk.background,
      appBar: AppAppBar(
        title: 'Termos e Mandato Legal',
        leading: AppIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Voltar',
          size: 20,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            layout.margin,
            AppSpace.s16,
            layout.margin,
            AppSpace.s32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppStatusChip(
                'DOCUMENTO OFICIAL · MANDATO ART. 653 CC',
                tone: AppTone.accent,
                icon: Icons.gavel_rounded,
              ),
              const SizedBox(height: AppSpace.s16),
              _buildRoleSegmentSelector(context),
              const SizedBox(height: AppSpace.s20),
              Text(
                isClient
                    ? 'Termos de Uso e Proteção do Cliente Desperrengue'
                    : 'Termos de Uso, Custódia e Cláusula-Mandato',
                style: AppType.headline.copyWith(color: tk.text),
              ),
              const SizedBox(height: AppSpace.s8),
              Text(
                'Versão vigente: $modeVersion · Código Civil, CDC, Marco Civil e LGPD · Validação de Segurança a cada 90 dias',
                style: AppType.caption.copyWith(color: tk.textMuted),
              ),
              const SizedBox(height: AppSpace.s16),
              Divider(color: tk.border, height: 1),
              const SizedBox(height: AppSpace.s20),
              for (final clause in clauses)
                _buildClause(
                  context,
                  title: clause.title,
                  content: clause.body,
                ),
              AppCard(
                variant: AppCardVariant.tonal,
                borderColor: tk.border,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selo Digital de Integridade Contratual (SHA-256)',
                      style: AppType.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tk.accentInk,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    Text(
                      canonicalHex,
                      style: AppType.tabular(AppType.caption).copyWith(
                        color: tk.textMuted,
                      ),
                    ),
                    if (modeHex != canonicalHex) ...[
                      const SizedBox(height: AppSpace.s8),
                      Text(
                        'Selo Específico (${isClient ? "Cliente" : "Profissional"}): $modeHex',
                        style: AppType.tabular(AppType.caption).copyWith(
                          color: tk.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSegmentSelector(BuildContext context) {
    final tk = context.tk;
    final isClient = _selectedMode == UserMode.client;
    final reduced = AppMotion.reduced(context);
    final duration = reduced ? Duration.zero : AppMotion.fade;

    Widget buildTab({
      required Key key,
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return AppPressScale(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
            onTap: onTap,
            child: AnimatedContainer(
              duration: duration,
              curve: AppMotion.fadeCurve,
              constraints: const BoxConstraints(
                minHeight: AppGeometry.minTarget,
              ),
              padding: const EdgeInsets.symmetric(
                vertical: AppSpace.s12,
                horizontal: AppSpace.s12,
              ),
              decoration: BoxDecoration(
                color: selected ? tk.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppType.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? tk.onAccent : tk.text,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpace.s4),
      decoration: BoxDecoration(
        color: tk.isDark ? tk.surface : tk.surfaceInset,
        borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
        border: Border.all(color: tk.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final clientTab = buildTab(
            key: const ValueKey('segment-terms-client'),
            label: 'Termos do Cliente',
            selected: isClient,
            onTap: () => setState(() => _selectedMode = UserMode.client),
          );
          final providerTab = buildTab(
            key: const ValueKey('segment-terms-provider'),
            label: 'Termos do Profissional',
            selected: !isClient,
            onTap: () => setState(() => _selectedMode = UserMode.provider),
          );

          if (constraints.maxWidth < 300 || context.layout.isLargeText) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                clientTab,
                const SizedBox(height: AppSpace.s4),
                providerTab,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: clientTab),
              const SizedBox(width: AppSpace.s4),
              Expanded(child: providerTab),
            ],
          );
        },
      ),
    );
  }

  Widget _buildClause(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppType.titleSm.copyWith(color: tk.text)),
          const SizedBox(height: AppSpace.s8),
          Text(content, style: AppType.bodySm.copyWith(color: tk.textMuted)),
        ],
      ),
    );
  }
}

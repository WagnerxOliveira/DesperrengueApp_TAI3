import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:desperrengue_app/core/ui/design_system/design_system.dart';

import '../../../core/services/document_ocr_and_liveness_service.dart';
import '../../../core/ui/kyc_human_feedback_translator.dart';
import 'widgets/kyc_onboarding_chrome.dart';

/// Etapa dedicada de conferência dos dados transcritos automaticamente do documento (OCR),
/// exibida como a próxima tela logo após capturar e validar Frente e Verso.
///
/// Projetada no padrão Quiet Luxury (Design System v2.28.0):
/// - Cabeçalho limpo com chip verde `"Leitura Confirmada"`;
/// - Strip com miniaturas nítidas da Frente e do Verso + botão `"Refazer fotos"`;
/// - Cartão principal (`ValueKey('ocr-transcribed-card')`) com `AppInfoRow` responsivo,
///   CPF mascarado LGPD por padrão e botão de revelar/ocultar 48×48 (`ValueKey('toggle-cpf-reveal')`);
/// - Selos de segurança em português 100% humano (zero jargão técnico).
class DocumentOcrReviewStep extends StatefulWidget {
  const DocumentOcrReviewStep({
    super.key,
    required this.ocrResult,
    this.typedName = '',
    this.frontImageBytes,
    this.backImageBytes,
    this.onRetakePhotos,
    this.onConfirm,
    this.confirmLabel,
    this.isSubmitting = false,
  });

  final AuditedDocumentOcrResult ocrResult;
  final String typedName;
  final Uint8List? frontImageBytes;
  final Uint8List? backImageBytes;
  final VoidCallback? onRetakePhotos;
  final VoidCallback? onConfirm;
  final String? confirmLabel;
  final bool isSubmitting;

  @override
  State<DocumentOcrReviewStep> createState() => _DocumentOcrReviewStepState();
}

class _DocumentOcrReviewStepState extends State<DocumentOcrReviewStep> {
  bool _revealCpf = false;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final ocr = widget.ocrResult;
    final bool isLargeText = context.layout.isLargeText;
    final double facePct =
        (ocr.faceMatchCosineSimilarity * 100.0).clamp(0.0, 100.0);
    final double namePct =
        (ocr.nameCrossCheckSimilarity * 100.0).clamp(0.0, 100.0);
    final String maskedCpf = KycHumanFeedbackTranslator.formatCpfQuietLuxury(
      ocr.extractedCpfDigits,
      masked: true,
    );
    final String displayedCpf =
        _revealCpf ? ocr.extractedCpfFormatted : maskedCpf;
    final String safeIssuer =
        KycHumanFeedbackTranslator.sanitizeForHumanDisplay(
      ocr.extractedIssuingAuthority,
    );
    final String safeSeal = KycHumanFeedbackTranslator.sanitizeForHumanDisplay(
      ocr.forensicVerificationSeal,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppGeometry.maxColumnWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Cabeçalho editorial + micro-selo e chips de confirmação
            const KycStepHeroHeader(
              icon: Icons.fact_check_rounded,
              title: 'Confira os dados do seu documento',
              subtitle:
                  'Lemos automaticamente a frente e o verso do seu documento. Verifique se está tudo certo antes de continuar.',
              trustBadgeText: 'Leitura confirmada com sucesso',
              trustBadgeIcon: Icons.verified_rounded,
            ),
            const SizedBox(height: AppSpace.s12),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const AppStatusChip(
                  'Leitura Confirmada',
                  key: ValueKey('ocr-review-confirmed-chip'),
                  tone: AppTone.success,
                  icon: Icons.verified_rounded,
                ),
                AppStatusChip(
                  ocr.documentType.label,
                  tone: AppTone.neutral,
                  icon: Icons.badge_outlined,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s20),

            // 2. Strip elegante de miniaturas da Frente e Verso + botão "Refazer fotos"
            _CapturedDocumentsStrip(
              frontImageBytes: widget.frontImageBytes,
              backImageBytes: widget.backImageBytes,
              onRetakePhotos: widget.onRetakePhotos,
            ),
            const SizedBox(height: AppSpace.s16),

            // 3. Cartão editorial principal com dados do documento
            KeyedSubtree(
              key: const ValueKey('ocr-transcribed-card'),
              child: KycPorcelainSectionCard(
                title: 'Dados do documento',
                subtitle:
                    'Autenticidade física e facial confirmada. Confira se tudo corresponde ao seu documento.',
                icon: Icons.fact_check_rounded,
                statusChipLabel: 'Conferido',
                statusTone: AppTone.success,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppInfoRow(
                      label: 'Nome civil confirmado',
                      value: ocr.extractedFullName,
                      strong: true,
                      stacked: true,
                    ),
                    if (widget.typedName.trim().isNotEmpty)
                      AppInfoRow(
                        label: 'Nome no cadastro',
                        stacked: true,
                        valueWidget: Text(
                          '${widget.typedName.trim()} (${namePct.toStringAsFixed(0)}% compatível)',
                          style: AppType.tabular(AppType.bodyStrong)
                              .copyWith(color: tk.text),
                        ),
                      ),
                    AppInfoRow(
                      label: 'CPF do titular',
                      stacked: true,
                      valueWidget: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              '$displayedCpf · Confirmado',
                              style: AppType.tabular(AppType.bodyStrong)
                                  .copyWith(color: tk.text),
                            ),
                          ),
                          AppIconButton(
                            key: const ValueKey('toggle-cpf-reveal'),
                            tooltip:
                                _revealCpf ? 'Ocultar CPF' : 'Mostrar CPF',
                            icon: _revealCpf
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: tk.accentInk,
                            onPressed: () =>
                                setState(() => _revealCpf = !_revealCpf),
                          ),
                        ],
                      ),
                    ),
                    AppInfoRow(
                      label: 'Documento',
                      stacked: isLargeText,
                      valueWidget: Text(
                        '${ocr.documentType.code} · Nº ${ocr.extractedDocumentNumber}',
                        textAlign:
                            isLargeText ? TextAlign.start : TextAlign.end,
                        style: AppType.tabular(AppType.bodyStrong)
                            .copyWith(color: tk.text),
                      ),
                    ),
                    AppInfoRow(
                      label: 'Data de nascimento',
                      stacked: isLargeText,
                      valueWidget: Text(
                        ocr.extractedBirthDateFormatted,
                        textAlign:
                            isLargeText ? TextAlign.start : TextAlign.end,
                        style: AppType.tabular(AppType.bodyStrong)
                            .copyWith(color: tk.text),
                      ),
                    ),
                    AppInfoRow(
                      label: 'Órgão emissor',
                      value: safeIssuer,
                      strong: true,
                      stacked: isLargeText,
                    ),
                    Divider(height: AppSpace.s24, color: tk.border),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                          color: tk.successInk,
                        ),
                        const SizedBox(width: AppSpace.s8),
                        Expanded(
                          child: Text(
                            'Foto nítida · Frente e verso · Identidade protegida (${facePct.toStringAsFixed(0)}%)',
                            style: AppType.bodySm.copyWith(
                              color: tk.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s8),
                    Text(
                      'Registro de verificação: $safeSeal',
                      style: AppType.tabular(AppType.bodySm)
                          .copyWith(color: tk.textMuted),
                    ),
                  ],
                ),
              ),
            ),

            if (widget.onConfirm != null) ...[
              const SizedBox(height: AppSpace.s20),
              AppButton(
                key: const ValueKey('btn-ocr-review-confirm'),
                label: widget.confirmLabel ?? 'Confirmar dados e continuar',
                trailingArrow: true,
                loading: widget.isSubmitting,
                onPressed: widget.isSubmitting ? null : widget.onConfirm,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CapturedDocumentsStrip extends StatelessWidget {
  const _CapturedDocumentsStrip({
    required this.frontImageBytes,
    required this.backImageBytes,
    required this.onRetakePhotos,
  });

  final Uint8List? frontImageBytes;
  final Uint8List? backImageBytes;
  final VoidCallback? onRetakePhotos;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      key: const ValueKey('ocr-thumbnails-strip'),
      variant: AppCardVariant.tonal,
      padding: const EdgeInsets.all(AppSpace.s12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compactStack =
              constraints.maxWidth < 330 || context.layout.isLargeText;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compactStack) ...[
                Text(
                  'Fotos capturadas',
                  style: AppType.bodyStrong.copyWith(color: tk.text),
                ),
                if (onRetakePhotos != null) ...[
                  const SizedBox(height: AppSpace.s8),
                  AppButton(
                    key: const ValueKey('btn-ocr-retake-photos'),
                    variant: AppButtonVariant.secondary,
                    compact: true,
                    icon: Icons.refresh_rounded,
                    label: 'Refazer fotos',
                    onPressed: onRetakePhotos,
                  ),
                ],
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Fotos capturadas',
                        style: AppType.bodyStrong.copyWith(color: tk.text),
                      ),
                    ),
                    if (onRetakePhotos != null)
                      AppButton(
                        key: const ValueKey('btn-ocr-retake-photos'),
                        variant: AppButtonVariant.secondary,
                        compact: true,
                        expand: false,
                        icon: Icons.refresh_rounded,
                        label: 'Refazer fotos',
                        onPressed: onRetakePhotos,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpace.s12),
              Row(
                children: [
                  Expanded(
                    child: _DocumentThumbnailTile(
                      label: 'Frente',
                      bytes: frontImageBytes,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: _DocumentThumbnailTile(
                      label: 'Verso',
                      bytes: backImageBytes,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DocumentThumbnailTile extends StatelessWidget {
  const _DocumentThumbnailTile({
    required this.label,
    required this.bytes,
  });

  final String label;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final bool hasBytes = bytes != null && bytes!.isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tk.card,
        borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
        border: Border.all(color: tk.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
              child: AspectRatio(
                aspectRatio: 1.586,
                child: hasBytes
                    ? Image.memory(
                        bytes!,
                        fit: BoxFit.cover,
                        semanticLabel: 'Miniatura da foto $label do documento',
                      )
                    : ColoredBox(
                        color: tk.surfaceInset,
                        child: Center(
                          child: Icon(
                            Icons.credit_card_outlined,
                            size: 26,
                            color: tk.textMuted,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpace.s8),
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: tk.successInk,
                ),
                const SizedBox(width: AppSpace.s4),
                Expanded(
                  child: Text(
                    label,
                    style: AppType.caption.copyWith(
                      color: tk.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

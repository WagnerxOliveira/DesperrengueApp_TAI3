import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:desperrengue_app/core/ui/design_system/design_system.dart';

import '../../../core/services/document_ocr_and_liveness_service.dart';
import '../../../core/ui/kyc_human_feedback_translator.dart';

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
            // 1. Cabeçalho limpo + chip verde "Leitura Confirmada"
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
            const SizedBox(height: AppSpace.s12),
            Text(
              'Confira os dados do seu documento',
              style: AppType.headline.copyWith(color: tk.text),
            ),
            const SizedBox(height: AppSpace.s4),
            Text(
              'Lemos automaticamente a frente e o verso do seu documento. Verifique se está tudo certo antes de continuar.',
              style: AppType.bodySm.copyWith(color: tk.textMuted),
            ),
            const SizedBox(height: AppSpace.s16),

            // 2. Strip de miniaturas da Frente e Verso + botão "Refazer fotos"
            _CapturedDocumentsStrip(
              frontImageBytes: widget.frontImageBytes,
              backImageBytes: widget.backImageBytes,
              onRetakePhotos: widget.onRetakePhotos,
            ),
            const SizedBox(height: AppSpace.s16),

            // 3. Cartão principal com dados transcritos (OCR)
            AppCard(
              key: const ValueKey('ocr-transcribed-card'),
              variant: AppCardVariant.elevated,
              borderColor: tk.success,
              padding: const EdgeInsets.all(AppSpace.cardLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: AppGeometry.iconTileSize,
                        height: AppGeometry.iconTileSize,
                        decoration: BoxDecoration(
                          color: tk.successSoft,
                          borderRadius: BorderRadius.circular(
                            AppGeometry.iconTileRadius,
                          ),
                        ),
                        child: Icon(
                          Icons.fact_check_rounded,
                          size: 22,
                          color: tk.successInk,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dados Transcritos Automaticamente do Documento (OCR)',
                              style: AppType.titleSm.copyWith(color: tk.text),
                            ),
                            const SizedBox(height: AppSpace.s4),
                            Text(
                              'Autenticidade física e facial confirmada. Pronto para seguir.',
                              style: AppType.bodySm.copyWith(
                                color: tk.successInk,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: AppSpace.s24),
                  AppInfoRow(
                    label: 'Nome Civil Confirmado',
                    value: ocr.extractedFullName,
                    strong: true,
                  ),
                  if (widget.typedName.trim().isNotEmpty)
                    AppInfoRow(
                      label: 'Nome no cadastro',
                      valueWidget: Text(
                        '${widget.typedName.trim()} (${namePct.toStringAsFixed(0)}% compatível)',
                        textAlign:
                            isLargeText ? TextAlign.start : TextAlign.end,
                        style: AppType.tabular(AppType.bodyStrong)
                            .copyWith(color: tk.text),
                      ),
                    ),
                  AppInfoRow(
                    label: 'CPF do Titular',
                    valueWidget: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: isLargeText
                          ? WrapAlignment.start
                          : WrapAlignment.end,
                      spacing: AppSpace.s4,
                      children: [
                        Text(
                          '$displayedCpf (Confirmado)',
                          style: AppType.tabular(AppType.bodyStrong)
                              .copyWith(color: tk.text),
                        ),
                        AppIconButton(
                          key: const ValueKey('toggle-cpf-reveal'),
                          tooltip: _revealCpf ? 'Ocultar CPF' : 'Mostrar CPF',
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
                    label: 'Tipo e Nº do Documento',
                    valueWidget: Text(
                      '${ocr.documentType.code} · Nº ${ocr.extractedDocumentNumber}',
                      textAlign: isLargeText ? TextAlign.start : TextAlign.end,
                      style: AppType.tabular(AppType.bodyStrong)
                          .copyWith(color: tk.text),
                    ),
                  ),
                  AppInfoRow(
                    label: 'Data de Nascimento',
                    valueWidget: Text(
                      ocr.extractedBirthDateFormatted,
                      textAlign: isLargeText ? TextAlign.start : TextAlign.end,
                      style: AppType.tabular(AppType.bodyStrong)
                          .copyWith(color: tk.text),
                    ),
                  ),
                  AppInfoRow(
                    label: 'Órgão Emissor',
                    value: safeIssuer,
                    strong: true,
                  ),
                  const Divider(height: AppSpace.s24),
                  Wrap(
                    spacing: AppSpace.s8,
                    runSpacing: AppSpace.s8,
                    children: [
                      AppStatusChip(
                        'Identidade Protegida (${facePct.toStringAsFixed(0)}%)',
                        tone: AppTone.success,
                        icon: Icons.verified_user_outlined,
                      ),
                      const AppStatusChip(
                        'Foto Nítida',
                        tone: AppTone.success,
                        icon: Icons.high_quality_outlined,
                      ),
                      const AppStatusChip(
                        'Frente e Verso',
                        tone: AppTone.success,
                        icon: Icons.credit_card_outlined,
                      ),
                      AppStatusChip(
                        'Titularidade Conferida (${namePct.toStringAsFixed(0)}%)',
                        tone: AppTone.success,
                        icon: Icons.shield_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s12),
                  Text(
                    'Protocolo de segurança: $safeSeal',
                    style: AppType.tabular(AppType.bodySm)
                        .copyWith(color: tk.textMuted),
                  ),
                ],
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

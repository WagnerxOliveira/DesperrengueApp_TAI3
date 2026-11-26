import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/criminal_background_service.dart';
import '../../../core/services/criminal_certificate_picker_and_extractor.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/kyc_human_feedback_translator.dart';
import '../../client/presentation/widgets/kyc_onboarding_chrome.dart';

/// Assinatura injetável para seleção de arquivo/foto da certidão em testes de widget.
typedef CriminalCertificateFilePicker =
    Future<({Uint8List bytes, String fileName})?> Function();

/// Assinatura injetável para extração de texto/QR/campos da certidão em testes de widget.
typedef CriminalCertificateExtractorOverride =
    Future<CriminalCertificateExtractionResult> Function({
      required Uint8List bytes,
      required String fileName,
    });

enum _CertificateUploadSource { downloads, gallery, camera }

/// Etapa unificada e ultra-responsiva de validação 100% automática da Certidão
/// Negativa de Antecedentes Criminais da Polícia Federal (ePol / SINIC — gov.br).
///
/// Sem campos manuais para o usuário digitar: protocolo, data de emissão, código
/// de autenticidade, CPF, nome do titular e situação "Nada Consta" são extraídos
/// e validados internamente direto do PDF ou foto da certidão, respeitando o
/// prazo oficial de **90 dias** da Polícia Federal e enviando avisos prévios
/// automáticos por e-mail antes do vencimento.
class CriminalBackgroundCheckStep extends StatefulWidget {
  const CriminalBackgroundCheckStep({
    super.key,
    required this.expectedFullName,
    required this.expectedCpfRaw,
    required this.onValidated,
    this.initialResult,
    this.isSixMonthRenewal = false,
    @visibleForTesting this.customCertificatePicker,
    @visibleForTesting this.customDownloadsPicker,
    @visibleForTesting this.customGalleryPicker,
    @visibleForTesting this.customCameraPicker,
    @visibleForTesting this.customCertificateExtractor,
    @visibleForTesting this.customUrlLauncher,
    @visibleForTesting this.rawExtractedTextOverride,
    @visibleForTesting this.referenceNow,
  });

  final String expectedFullName;
  final String expectedCpfRaw;
  final ValueChanged<AuditedCriminalRecordResult?> onValidated;
  final AuditedCriminalRecordResult? initialResult;
  final bool isSixMonthRenewal;
  final CriminalCertificateFilePicker? customCertificatePicker;
  final CriminalCertificateFilePicker? customDownloadsPicker;
  final CriminalCertificateFilePicker? customGalleryPicker;
  final CriminalCertificateFilePicker? customCameraPicker;
  final CriminalCertificateExtractorOverride? customCertificateExtractor;
  final Future<void> Function(String url)? customUrlLauncher;
  final String? rawExtractedTextOverride;
  final DateTime? referenceNow;

  @override
  State<CriminalBackgroundCheckStep> createState() =>
      _CriminalBackgroundCheckStepState();
}

class _CriminalBackgroundCheckStepState
    extends State<CriminalBackgroundCheckStep> {
  Uint8List? _fileBytes;
  String? _fileName;
  String? _lastExtractedText;
  String? _lastQrPayload;
  bool _analyzing = false;
  AuditedCriminalRecordResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
    if (_result != null) {
      _fileBytes = _result!.fileBytes;
      _fileName = 'certidao_pf.${_result!.fileExtension}';
    }
  }

  @override
  void didUpdateWidget(covariant CriminalBackgroundCheckStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialResult != oldWidget.initialResult &&
        widget.initialResult != null) {
      _result = widget.initialResult;
      _fileBytes = _result!.fileBytes;
      _fileName = 'certidao_pf.${_result!.fileExtension}';
    }
  }

  static String _formatFileSize(int byteLength) {
    if (byteLength < 1024) return '$byteLength B';
    if (byteLength < 1024 * 1024) {
      final kb = (byteLength / 1024).round();
      return '$kb KB';
    }
    final mb = (byteLength / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',');
    return '$mb MB';
  }

  Future<void> _openPoliciaFederalPortal() async {
    const url = CriminalBackgroundService.officialPoliciaFederalUrl;
    if (widget.customUrlLauncher != null) {
      await widget.customUrlLauncher!(url);
      return;
    }
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          'Acesse servicos.pf.gov.br/epol-sinic-publico no navegador para emitir gratuitamente.',
          kind: AppSnackKind.info,
        );
      }
    }
  }

  Future<void> _handleSelectCertificateTap() async {
    if (_analyzing) return;
    setState(() => _errorMessage = null);

    try {
      // Compatibilidade total com testes legados que injetam picker direto
      if (widget.customCertificatePicker != null) {
        final picked = await widget.customCertificatePicker!();
        if (!mounted || picked == null) return;
        await _processPickedCertificate(
          bytes: picked.bytes,
          fileName: picked.fileName,
        );
        return;
      }

      final source = await _showCertificateSourceSheet();
      if (!mounted || source == null) return;

      final ({Uint8List bytes, String fileName})? picked = switch (source) {
        _CertificateUploadSource.downloads =>
          widget.customDownloadsPicker != null
              ? await widget.customDownloadsPicker!()
              : await CriminalCertificatePickerAndExtractor
                  .pickFromDownloadsOrFiles(),
        _CertificateUploadSource.gallery =>
          widget.customGalleryPicker != null
              ? await widget.customGalleryPicker!()
              : await CriminalCertificatePickerAndExtractor.pickFromGallery(),
        _CertificateUploadSource.camera =>
          widget.customCameraPicker != null
              ? await widget.customCameraPicker!()
              : await CriminalCertificatePickerAndExtractor.captureWithCamera(),
      };

      if (!mounted || picked == null || picked.bytes.isEmpty) return;
      await _processPickedCertificate(
        bytes: picked.bytes,
        fileName: picked.fileName,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _errorMessage = KycHumanFeedbackTranslator.translateError(e);
      });
    }
  }

  Future<_CertificateUploadSource?> _showCertificateSourceSheet() {
    return AppSheet.show<_CertificateUploadSource>(
      context,
      title: 'Como deseja enviar a Certidão PF?',
      subtitle: 'PDF baixado do gov.br ou foto nítida.',
      builder: (sheetCtx) {
        final tk = sheetCtx.tk;
        final isCompactSheet =
            MediaQuery.sizeOf(sheetCtx).width < 380 ||
            sheetCtx.layout.isLargeText;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              variant: AppCardVariant.outlined,
              color: tk.card,
              borderColor: tk.accentInk.withValues(alpha: tk.isDark ? 0.35 : 0.28),
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCompactSheet)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpace.s12,
                        AppSpace.s12,
                        AppSpace.s12,
                        0,
                      ),
                      child: AppStatusChip(
                        'Recomendado',
                        tone: AppTone.success,
                        icon: Icons.verified_rounded,
                      ),
                    ),
                  AppListTile(
                    key: const ValueKey('sheet-pick-criminal-downloads'),
                    leadingIcon: Icons.folder_open_rounded,
                    title: 'Escolher PDF ou arquivo do celular',
                    subtitle: isCompactSheet
                        ? 'Abre em Downloads; navegue por qualquer pasta.'
                        : 'Abre em Downloads, mas você pode navegar por qualquer pasta do aparelho.',
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpace.s12,
                      vertical: isCompactSheet ? AppSpace.s4 : AppSpace.s8,
                    ),
                    trailing: isCompactSheet
                        ? null
                        : const AppStatusChip(
                            'Recomendado',
                            tone: AppTone.success,
                          ),
                    showChevron: isCompactSheet,
                    onTap: () => Navigator.of(
                      sheetCtx,
                    ).pop(_CertificateUploadSource.downloads),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            AppListTile(
              key: const ValueKey('sheet-pick-criminal-gallery'),
              leadingIcon: Icons.photo_library_outlined,
              title: 'Escolher foto da galeria',
              subtitle: 'Imagem salva no seu aparelho.',
              padding: EdgeInsets.symmetric(
                horizontal: AppSpace.s12,
                vertical: isCompactSheet ? AppSpace.s4 : AppSpace.s8,
              ),
              showChevron: true,
              onTap: () => Navigator.of(
                sheetCtx,
              ).pop(_CertificateUploadSource.gallery),
            ),
            AppListTile(
              key: const ValueKey('sheet-pick-criminal-camera'),
              leadingIcon: Icons.photo_camera_outlined,
              title: 'Fotografar certidão com a câmera',
              subtitle: 'Foto de página inteira bem iluminada.',
              padding: EdgeInsets.symmetric(
                horizontal: AppSpace.s12,
                vertical: isCompactSheet ? AppSpace.s4 : AppSpace.s8,
              ),
              showChevron: true,
              onTap: () => Navigator.of(
                sheetCtx,
              ).pop(_CertificateUploadSource.camera),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processPickedCertificate({
    required Uint8List bytes,
    required String fileName,
  }) async {
    setState(() {
      _fileBytes = bytes;
      _fileName = fileName;
      _analyzing = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final CriminalCertificateExtractionResult extraction;
      if (widget.customCertificateExtractor != null) {
        extraction = await widget.customCertificateExtractor!(
          bytes: bytes,
          fileName: fileName,
        );
      } else if (widget.rawExtractedTextOverride != null &&
          widget.rawExtractedTextOverride!.trim().isNotEmpty) {
        final rawText = widget.rawExtractedTextOverride!.trim();
        extraction = CriminalCertificateExtractionResult(
          extractedText: rawText,
          fields: CriminalBackgroundService.extractCertificateFieldsFromText(
            rawText,
          ),
          source: 'override',
        );
      } else {
        extraction = await CriminalCertificatePickerAndExtractor
            .extractTextAndQrFromCertificateBytes(
          bytes: bytes,
          fileName: fileName,
          expectedFullName: widget.expectedFullName,
          expectedCpfRaw: widget.expectedCpfRaw,
        );
      }

      if (!mounted) return;
      setState(() {
        _lastExtractedText = extraction.extractedText;
        _lastQrPayload = extraction.qrPayload;
      });

      await _runValidation(
        extractedTextOverride: extraction.extractedText.trim().isNotEmpty
            ? extraction.extractedText
            : null,
        qrPayloadOverride: extraction.qrPayload,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _result = null;
        _errorMessage = KycHumanFeedbackTranslator.translateError(e);
      });
      widget.onValidated(null);
    }
  }

  void _removeAttachedCertificate() {
    if (_analyzing) return;
    setState(() {
      _fileBytes = null;
      _fileName = null;
      _result = null;
      _errorMessage = null;
      _lastExtractedText = null;
      _lastQrPayload = null;
    });
    widget.onValidated(null);
    AppSnackbar.show(
      context,
      'Certidão removida. Você pode enviar outro arquivo quando desejar.',
      kind: AppSnackKind.info,
    );
  }

  Future<void> _runValidation({
    String? extractedTextOverride,
    String? qrPayloadOverride,
  }) async {
    setState(() {
      _analyzing = true;
      _errorMessage = null;
    });

    try {
      final Uint8List effectiveBytes = _fileBytes ?? Uint8List(0);
      final String effectiveFileName = _fileName ?? 'certidao_pf.pdf';

      if (effectiveBytes.isEmpty) {
        setState(() {
          _analyzing = false;
          _errorMessage =
              'Envie o arquivo PDF original baixado no site da Polícia Federal (gov.br) ou uma foto nítida de página inteira.';
        });
        widget.onValidated(null);
        return;
      }

      final effectiveTextOverride =
          extractedTextOverride ??
          widget.rawExtractedTextOverride ??
          ((_lastExtractedText != null && _lastExtractedText!.trim().isNotEmpty)
              ? _lastExtractedText
              : null);
      final effectiveQr = qrPayloadOverride ?? _lastQrPayload;

      // Validação 100% interna e automática: protocolo, data de emissão (<= 90 dias)
      // e código de autenticidade são extraídos diretamente do documento.
      final result =
          await CriminalBackgroundService.analyzeAndValidateCertificate(
            fileBytes: effectiveBytes,
            fileName: effectiveFileName,
            expectedFullName: widget.expectedFullName,
            expectedCpfRaw: widget.expectedCpfRaw,
            rawExtractedTextOverride: effectiveTextOverride,
            qrPayload: effectiveQr,
            referenceNow: widget.referenceNow,
          );

      if (!mounted) return;
      setState(() {
        _result = result;
        _analyzing = false;
        if (!result.passed) {
          _errorMessage = KycHumanFeedbackTranslator.sanitizeForHumanDisplay(
            result.humanFeedbackMessage,
          );
        } else {
          _errorMessage = null;
        }
      });

      widget.onValidated(result.passed ? result : null);
    } catch (e) {
      if (!mounted) return;
      final cleanMsg = KycHumanFeedbackTranslator.translateError(e);
      setState(() {
        _analyzing = false;
        _result = null;
        _errorMessage = cleanMsg;
      });
      widget.onValidated(null);
    }
  }

  Widget _buildEmptyUploadSurface(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      key: const ValueKey('btn-upload-criminal-certificate'),
      variant: AppCardVariant.tonal,
      color: tk.surface,
      borderColor: tk.accentInk.withValues(alpha: 0.45),
      onTap: _analyzing ? null : _handleSelectCertificateTap,
      semanticLabel: 'Enviar PDF ou Foto da Certidão da Polícia Federal',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tk.accentSoft,
              borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
            ),
            child: Icon(
              Icons.upload_file_rounded,
              color: tk.accentInk,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enviar PDF ou foto da certidão',
                  style: AppType.titleSm.copyWith(color: tk.text),
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  'Anexe o PDF baixado do gov.br, foto da galeria ou câmera — a validação ocorre automaticamente na hora.',
                  style: AppType.bodySm.copyWith(color: tk.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Icon(
            Icons.chevron_right_rounded,
            color: tk.accentInk,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildAttachedFileCard(BuildContext context, {required bool approved}) {
    final tk = context.tk;
    final bytes = _fileBytes!;
    final fileName = (_fileName ?? 'certidao_pf.pdf').trim();
    final ext = CriminalBackgroundService.detectCanonicalExtension(
      bytes,
      fileName,
    );
    final isPdf = ext == 'pdf';
    final metaLabel = '${ext.toUpperCase()} · ${_formatFileSize(bytes.length)}';

    final String statusLabel;
    final AppTone statusTone;
    final IconData statusIcon;
    if (_analyzing) {
      statusLabel = 'Lendo certidão...';
      statusTone = AppTone.info;
      statusIcon = Icons.hourglass_top_rounded;
    } else if (approved) {
      statusLabel = 'Validada';
      statusTone = AppTone.success;
      statusIcon = Icons.verified_rounded;
    } else if (_errorMessage != null) {
      statusLabel = 'Revisão necessária';
      statusTone = AppTone.warning;
      statusIcon = Icons.info_outline_rounded;
    } else {
      statusLabel = 'Arquivo anexado';
      statusTone = AppTone.info;
      statusIcon = Icons.attach_file_rounded;
    }

    final Widget preview = isPdf
        ? Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: tk.dangerSoft,
              borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
              border: Border.all(color: tk.danger.withValues(alpha: 0.3)),
            ),
            child: Icon(
              Icons.picture_as_pdf_rounded,
              color: tk.dangerInk,
              size: 28,
            ),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
            child: Container(
              width: 56,
              height: 56,
              color: tk.surfaceInset,
              child: Image.memory(
                bytes,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.image_outlined,
                  color: tk.accentInk,
                  size: 26,
                ),
              ),
            ),
          );

    return AppCard(
      key: const ValueKey('criminal-attached-file-card'),
      variant: AppCardVariant.tonal,
      color: approved ? tk.successSoft.withValues(alpha: 0.5) : tk.surface,
      borderColor: approved
          ? tk.success.withValues(alpha: 0.6)
          : tk.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              preview,
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: AppType.bodyStrong.copyWith(color: tk.text),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    Text(
                      metaLabel,
                      style: AppType.tabular(AppType.bodySm)
                          .copyWith(color: tk.textMuted),
                    ),
                    const SizedBox(height: AppSpace.s8),
                    AppStatusChip(
                      statusLabel,
                      tone: statusTone,
                      icon: statusIcon,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackButtons =
                  constraints.maxWidth < 300 || context.layout.isLargeText;
              final replaceBtn = KeyedSubtree(
                key: const ValueKey('btn-upload-criminal-certificate'),
                child: AppButton(
                  key: const ValueKey('btn-replace-criminal-certificate'),
                  label: 'Trocar arquivo',
                  icon: Icons.swap_horiz_rounded,
                  variant: AppButtonVariant.secondary,
                  compact: true,
                  onPressed: _analyzing ? null : _handleSelectCertificateTap,
                ),
              );
              final removeBtn = AppButton(
                key: const ValueKey('btn-remove-criminal-certificate'),
                label: 'Remover',
                icon: Icons.delete_outline_rounded,
                variant: AppButtonVariant.tertiary,
                compact: true,
                onPressed: _analyzing ? null : _removeAttachedCertificate,
              );

              if (stackButtons) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    replaceBtn,
                    const SizedBox(height: AppSpace.s8),
                    removeBtn,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: replaceBtn),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(child: removeBtn),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final approved = _result != null && _result!.passed;
    final hasFile = _fileBytes != null && _fileBytes!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho Editorial de Confiança
        KycStepHeroHeader(
          icon: Icons.gpp_good_rounded,
          title: widget.isSixMonthRenewal
              ? 'Renovação de Antecedentes Criminais (90 dias)'
              : 'Certidão de Antecedentes Criminais (Polícia Federal)',
          subtitle:
              'Emita grátis no gov.br e envie o PDF ou foto. Nossa auditoria lê e valida tudo automaticamente, seguindo o prazo oficial de 90 dias da Polícia Federal.',
        ),
        const SizedBox(height: AppSpace.s12),
        const Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppStatusChip(
              'Validade 90 dias',
              tone: AppTone.info,
              icon: Icons.verified_user_rounded,
            ),
            AppStatusChip(
              'Leitura automática',
              tone: AppTone.success,
              icon: Icons.auto_awesome_rounded,
            ),
            AppStatusChip(
              'Cliente e Profissional',
              tone: AppTone.neutral,
              icon: Icons.sync_alt_rounded,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s16),

        // PASSO 1 GUIADO — EMISSÃO OFICIAL GRATUITA EM 1 MINUTO
        KycPorcelainSectionCard(
          title: '1. Emitir grátis no gov.br',
          subtitle: 'Emissão gratuita em menos de 1 minuto no portal da Polícia Federal.',
          icon: Icons.account_balance_rounded,
          statusChipLabel: 'Grátis',
          statusTone: AppTone.info,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const KycNumberedStepRow(
                stepNumber: '1',
                description:
                    'Abra o portal oficial da Polícia Federal (gov.br) pelo botão abaixo.',
                showConnector: true,
              ),
              const KycNumberedStepRow(
                stepNumber: '2',
                description:
                    'Preencha seu nome civil e CPF para gerar a certidão "Nada Consta".',
                showConnector: true,
              ),
              const KycNumberedStepRow(
                stepNumber: '3',
                description:
                    'Salve o PDF no celular (ou fotografe nítido) e anexe logo abaixo — sem digitar nada.',
              ),
              const SizedBox(height: AppSpace.s16),
              AppButton(
                key: const ValueKey('btn-open-pf-portal'),
                label: 'Emitir certidão no gov.br',
                icon: Icons.open_in_new_rounded,
                variant: AppButtonVariant.secondary,
                compact: true,
                onPressed: _openPoliciaFederalPortal,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s16),

        // PASSO 2 — ENVIO UNIFICADO COM VALIDAÇÃO INTERNA AUTOMÁTICA (ZERO CAMPOS MANUAIS)
        KycPorcelainSectionCard(
          title: '2. Enviar certidão',
          subtitle:
              'Anexe o PDF ou foto nítida emitida nos últimos 90 dias em nome de ${widget.expectedFullName.isEmpty ? "seu CPF" : widget.expectedFullName}.',
          icon: Icons.upload_file_rounded,
          statusChipLabel: _analyzing
              ? 'Validando...'
              : (approved
                    ? 'Validada'
                    : (hasFile ? 'Anexada' : 'Aguardando')),
          statusTone: _analyzing
              ? AppTone.info
              : (approved
                    ? AppTone.success
                    : (hasFile ? AppTone.info : AppTone.neutral)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasFile)
                _buildAttachedFileCard(context, approved: approved)
              else
                _buildEmptyUploadSurface(context),
              const SizedBox(height: AppSpace.s12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 18,
                    color: tk.accentInk,
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Text(
                      'Conferimos nome, CPF, resultado Nada Consta e a validade de 90 dias diretamente no arquivo — você não precisa digitar protocolo nem código.',
                      style: AppType.bodySm.copyWith(color: tk.textMuted),
                    ),
                  ),
                ],
              ),
              if (hasFile && !approved) ...[
                const SizedBox(height: AppSpace.s12),
                AppButton(
                  key: const ValueKey('btn-validate-criminal-certificate'),
                  label: _analyzing
                      ? 'Validando Certidão da Polícia Federal...'
                      : 'Tentar validar novamente',
                  icon: Icons.policy_rounded,
                  variant: AppButtonVariant.secondary,
                  compact: true,
                  loading: _analyzing,
                  onPressed: _analyzing ? null : _runValidation,
                ),
              ],
            ],
          ),
        ),

        // PASSO 3 — RESULTADO DA VALIDAÇÃO INTERNA
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpace.s16),
          AppCard(
            key: const ValueKey('criminal-check-rejected-card'),
            variant: AppCardVariant.tonal,
            color: tk.dangerSoft,
            borderColor: tk.danger.withValues(alpha: 0.4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.gpp_maybe_rounded, color: tk.dangerInk, size: 22),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Atenção na validação da certidão',
                        style: AppType.bodyStrong.copyWith(color: tk.dangerInk),
                      ),
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        _errorMessage!,
                        style: AppType.bodySm.copyWith(color: tk.dangerInk),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (approved && _result != null) ...[
          const SizedBox(height: AppSpace.s16),
          _ApprovedCriminalRecordCard(
            result: _result!,
            holderName: widget.expectedFullName,
          ),
        ],
      ],
    );
  }
}

class _ApprovedCriminalRecordCard extends StatelessWidget {
  const _ApprovedCriminalRecordCard({
    required this.result,
    required this.holderName,
  });

  final AuditedCriminalRecordResult result;
  final String holderName;

  static String _formatDateBr(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final expiresAt = result.expiresAt;

    return AppCard(
      key: const ValueKey('criminal-check-approved-card'),
      variant: AppCardVariant.elevated,
      color: tk.card,
      borderColor: tk.success.withValues(alpha: tk.isDark ? 0.45 : 0.35),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tk.successSoft,
                    borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
                    border: Border.all(
                      color: tk.success.withValues(alpha: tk.isDark ? 0.35 : 0.22),
                    ),
                  ),
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: tk.successInk,
                    size: 20,
                  ),
                ),
                const AppStatusChip(
                  'Nada Consta',
                  tone: AppTone.success,
                  icon: Icons.verified_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          Text(
            'Certidão validada por 90 dias',
            style: AppType.title.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            'Situação confirmada automaticamente junto à Polícia Federal. Válida até ${_formatDateBr(expiresAt)} — enviaremos lembretes por e-mail antes do vencimento.',
            style: AppType.tabular(AppType.bodySm).copyWith(
              color: tk.textMuted,
            ),
          ),
          Divider(height: AppSpace.s24, color: tk.border),
          AppInfoRow(
            label: 'Titular conferido',
            value: holderName.isEmpty ? 'Titular Verificado' : holderName,
            strong: true,
            stacked: true,
          ),
          AppInfoRow(
            label: 'Registro interno PF',
            value: result.protocolMasked.isNotEmpty
                ? result.protocolMasked
                : 'Validado automaticamente',
            strong: true,
            stacked: true,
          ),
          AppInfoRow(
            label: 'Emissão e validade (90 dias)',
            value:
                'Emitida em ${_formatDateBr(result.issuedDate)} · Válida até ${_formatDateBr(expiresAt)}',
            strong: true,
            stacked: true,
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            'Comprovante digital: ${result.fileSha256Hex.length >= 16 ? '${result.fileSha256Hex.substring(0, 16)}...' : result.fileSha256Hex}',
            style: AppType.tabular(AppType.bodySm).copyWith(
              color: tk.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tela de consulta rápida do status da Certidão de Antecedentes Criminais e da
/// Validade Oficial de 90 Dias da verificação de segurança.
class CriminalBackgroundStatusScreen extends StatelessWidget {
  const CriminalBackgroundStatusScreen({
    super.key,
    required this.profile,
    this.onRequestRenewal,
  });

  final UserProfile profile;
  final VoidCallback? onRequestRenewal;

  static String _formatDateBr(DateTime? dt) {
    if (dt == null) return 'Não informado';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    final expiresAt = profile.effectiveKycExpiresAt;
    final expired = profile.isKycExpiredAt();
    final daysRemaining = profile.daysUntilKycExpiration();
    final valid = profile.criminalRecordVerified && !expired;

    return AppScaffold(
      backgroundColor: tk.background,
      appBar: const AppAppBar(title: 'Validação e Antecedentes (90 Dias)'),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          layout.margin,
          AppSpace.s12,
          layout.margin,
          AppSpace.s32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              variant: AppCardVariant.tonal,
              color: valid ? tk.successSoft : tk.warningSoft,
              borderColor: (valid ? tk.success : tk.warning).withValues(
                alpha: 0.45,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    valid
                        ? Icons.verified_user_rounded
                        : Icons.event_repeat_rounded,
                    color: valid ? tk.successInk : tk.warningInk,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          valid
                              ? 'Ciclo de Segurança Ativo (90 dias)'
                              : 'Renovação de Segurança Necessária',
                          style: AppType.bodyStrong.copyWith(
                            color: valid ? tk.successInk : tk.warningInk,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s2),
                        Text(
                          valid
                              ? 'Sua identidade biométrica e sua Certidão Negativa da Polícia Federal estão válidas para Cliente e Profissional. Avisaremos por e-mail antes do vencimento de 90 dias.'
                              : 'A certidão da Polícia Federal tem validade oficial de 90 dias. Atualize seus documentos para manter a proteção ativa em toda a comunidade.',
                          style: AppType.bodySm.copyWith(
                            color: valid ? tk.successInk : tk.warningInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumo do Ciclo de Validação (90 Dias)',
                    style: AppType.titleSm.copyWith(color: tk.text),
                  ),
                  Divider(height: AppSpace.s24, color: tk.border),
                  AppInfoRow(
                    label: 'Titular Homologado',
                    value: profile.officialCivilName,
                    strong: true,
                  ),
                  AppInfoRow(
                    label: 'Antecedentes PF',
                    value: valid
                        ? 'Nada Consta Verificado'
                        : (expired ? 'Ciclo Expirado (90 dias)' : 'Pendente'),
                    strong: true,
                  ),
                  AppInfoRow(
                    label: 'Registro PF',
                    value:
                        profile.criminalCertificateNumberMasked ??
                        'Conferido eletronicamente',
                    strong: true,
                  ),
                  AppInfoRow(
                    label: 'Válido até',
                    value: _formatDateBr(expiresAt),
                    strong: true,
                  ),
                  if (daysRemaining != null)
                    AppInfoRow(
                      label: 'Prazo Restante',
                      value: daysRemaining > 0
                          ? '$daysRemaining dias restantes'
                          : 'Renovação imediata necessária',
                      strong: true,
                    ),
                ],
              ),
            ),
            if (onRequestRenewal != null) ...[
              const SizedBox(height: AppSpace.s20),
              AppButton(
                key: const ValueKey('btn-trigger-six-month-renewal'),
                label: 'Renovar Certidão PF e Identidade (+90 Dias)',
                icon: Icons.refresh_rounded,
                onPressed: onRequestRenewal,
              ),
            ],
            const SizedBox(height: AppSpace.s16),
            Text(
              'Proteção LGPD: seus documentos são armazenados em cofre privado criptografado e '
              'reaproveitados automaticamente quando você alterna entre Cliente e Profissional. '
              'Lembretes automáticos são enviados por e-mail 15 dias e 5 dias antes do vencimento.',
              style: AppType.caption.copyWith(color: tk.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

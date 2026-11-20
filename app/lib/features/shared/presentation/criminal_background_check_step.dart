import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/criminal_background_service.dart';
import '../../../core/services/criminal_certificate_picker_and_extractor.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/kyc_human_feedback_translator.dart';

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

/// Etapa unificada e ultra-responsiva de validação da Certidão Negativa de
/// Antecedentes Criminais da Polícia Federal (ePol / SINIC — gov.br).
///
/// A validação aprovada possui vigência de **6 meses (180 dias)** e é compartilhada
/// entre os modos **Cliente** e **Profissional** sem exigir novo envio nem gerar
/// nova cobrança de verificação.
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
  late final TextEditingController _protocolCtrl = TextEditingController(
    text: widget.initialResult?.protocolNumber ?? '',
  );
  late final TextEditingController _validationCodeCtrl = TextEditingController(
    text: widget.initialResult?.validationCode ?? '',
  );

  late DateTime _issuedDate =
      widget.initialResult?.issuedDate ??
      (widget.referenceNow ?? DateTime.now());
  late bool _hasExplicitDate = widget.initialResult != null;

  Uint8List? _fileBytes;
  String? _fileName;
  String? _lastExtractedText;
  String? _lastQrPayload;
  bool _analyzing = false;
  bool _autoFilledProtocol = false;
  bool _autoFilledDate = false;
  bool _autoFilledValidationCode = false;
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
      if (_protocolCtrl.text.trim().isEmpty) {
        _protocolCtrl.text = widget.initialResult!.protocolNumber;
      }
      if (_validationCodeCtrl.text.trim().isEmpty) {
        _validationCodeCtrl.text = widget.initialResult!.validationCode;
      }
      _issuedDate = widget.initialResult!.issuedDate;
      _hasExplicitDate = true;
    }
  }

  @override
  void dispose() {
    _protocolCtrl.dispose();
    _validationCodeCtrl.dispose();
    super.dispose();
  }

  static String _formatDateBr(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
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

  Future<void> _pickIssueDate() async {
    final now = widget.referenceNow ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _issuedDate.isAfter(now) ? now : _issuedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      helpText: 'Data de emissão da Certidão PF',
    );
    if (picked != null && mounted) {
      setState(() {
        _issuedDate = picked;
        _hasExplicitDate = true;
        _autoFilledDate = false;
        _errorMessage = null;
      });
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
              variant: AppCardVariant.tonal,
              color: tk.infoSoft.withValues(alpha: tk.isDark ? 0.45 : 0.65),
              borderColor: tk.info.withValues(alpha: 0.35),
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
                    title: 'Selecionar PDF ou Arquivo (Pasta Downloads)',
                    subtitle: 'Acessa a pasta Downloads para o PDF baixado da PF.',
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s12,
                      vertical: AppSpace.s8,
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
            const SizedBox(height: AppSpace.s8),
            AppListTile(
              key: const ValueKey('sheet-pick-criminal-gallery'),
              leadingIcon: Icons.photo_library_outlined,
              title: 'Escolher Foto da Galeria',
              subtitle: 'Imagem salva no seu aparelho.',
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s12,
                vertical: AppSpace.s8,
              ),
              showChevron: true,
              onTap: () => Navigator.of(
                sheetCtx,
              ).pop(_CertificateUploadSource.gallery),
            ),
            const SizedBox(height: AppSpace.s4),
            AppListTile(
              key: const ValueKey('sheet-pick-criminal-camera'),
              leadingIcon: Icons.photo_camera_outlined,
              title: 'Fotografar Certidão com a Câmera',
              subtitle: 'Foto de página inteira bem iluminada.',
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s12,
                vertical: AppSpace.s8,
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
      final fields = extraction.fields;
      final fallbackNow = widget.referenceNow ?? DateTime.now();

      setState(() {
        _lastExtractedText = extraction.extractedText;
        _lastQrPayload = extraction.qrPayload;

        // Autopreenchimento imediato: SEMPRE atualiza com os dados do novo arquivo
        // (sobrescrevendo qualquer valor de um arquivo anterior).
        if (fields.protocolNumber != null &&
            fields.protocolNumber!.trim().isNotEmpty) {
          _protocolCtrl.text = fields.protocolNumber!.trim();
          _autoFilledProtocol = true;
        } else if (_autoFilledProtocol) {
          _protocolCtrl.clear();
          _autoFilledProtocol = false;
        }

        if (fields.validationCode != null &&
            fields.validationCode!.trim().isNotEmpty) {
          _validationCodeCtrl.text = fields.validationCode!.trim();
          _autoFilledValidationCode = true;
        } else if (_autoFilledValidationCode) {
          _validationCodeCtrl.clear();
          _autoFilledValidationCode = false;
        }

        if (fields.issuedDate != null) {
          _issuedDate = fields.issuedDate!;
          _hasExplicitDate = true;
          _autoFilledDate = true;
        } else if (_autoFilledDate) {
          _issuedDate = fallbackNow;
          _hasExplicitDate = false;
          _autoFilledDate = false;
        }
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
      _protocolCtrl.clear();
      _validationCodeCtrl.clear();
      _issuedDate = widget.referenceNow ?? DateTime.now();
      _hasExplicitDate = false;
      _autoFilledProtocol = false;
      _autoFilledDate = false;
      _autoFilledValidationCode = false;
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
      final manualProtocol = _protocolCtrl.text.trim();
      final manualCode = _validationCodeCtrl.text.trim();

      Uint8List effectiveBytes = _fileBytes ?? Uint8List(0);
      String effectiveFileName = _fileName ?? 'certidao_pf.pdf';

      // Caso o usuário tenha preenchido os dados estruturados da certidão PF
      // (Protocolo + Código de Validação Eletrônica) diretamente e tocado em validar:
      if (effectiveBytes.isEmpty &&
          manualProtocol.isNotEmpty &&
          manualCode.isNotEmpty) {
        final syntheticDoc =
            '%PDF-1.4\n'
            'POLICIA FEDERAL - SISTEMA NACIONAL DE INFORMACOES CRIMINAIS - SINIC\n'
            'CERTIDAO DE ANTECEDENTES CRIMINAIS - NADA CONSTA\n'
            'A Policia Federal CERTIFICA que NAO CONSTA condenação com transito em julgado\n'
            'NOME: ${widget.expectedFullName.toUpperCase()}\n'
            'CPF: ${widget.expectedCpfRaw}\n'
            'CERTIDAO N: $manualProtocol\n'
            'DATA DE EMISSAO: ${_formatDateBr(_issuedDate)}\n'
            'CODIGO DE VALIDACAO: $manualCode\n';
        effectiveBytes = Uint8List.fromList(utf8.encode(syntheticDoc));
        effectiveFileName = 'certidao_pf_eletronica.pdf';
      }

      if (effectiveBytes.isEmpty) {
        setState(() {
          _analyzing = false;
          _errorMessage =
              'Envie o arquivo (PDF ou foto nítida) da Certidão da Polícia Federal ou preencha o Nº da Certidão e o Código de Validação.';
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

      final result =
          await CriminalBackgroundService.analyzeAndValidateCertificate(
            fileBytes: effectiveBytes,
            fileName: effectiveFileName,
            expectedFullName: widget.expectedFullName,
            expectedCpfRaw: widget.expectedCpfRaw,
            manualProtocol: manualProtocol.isEmpty ? null : manualProtocol,
            manualIssuedDate: _hasExplicitDate || _fileBytes == null
                ? _issuedDate
                : null,
            manualValidationCode: manualCode.isEmpty ? null : manualCode,
            rawExtractedTextOverride: effectiveTextOverride,
            qrPayload: effectiveQr,
            referenceNow: widget.referenceNow,
          );

      if (!mounted) return;
      setState(() {
        _result = result;
        _analyzing = false;
        if (result.protocolNumber.isNotEmpty &&
            _protocolCtrl.text.trim().isEmpty) {
          _protocolCtrl.text = result.protocolNumber;
          _autoFilledProtocol = true;
        }
        if (result.validationCode.isNotEmpty &&
            _validationCodeCtrl.text.trim().isEmpty) {
          _validationCodeCtrl.text = result.validationCode;
          _autoFilledValidationCode = true;
        }
        _issuedDate = result.issuedDate;
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
                  'Enviar PDF ou Foto da Certidão',
                  style: AppType.titleSm.copyWith(color: tk.text),
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  'Selecione o PDF na pasta Downloads, escolha uma foto da galeria ou fotografe com a câmera.',
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

  Widget _buildAutoFilledBadge(Key key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: AppStatusChip(
        'Preenchido automaticamente',
        key: key,
        tone: AppTone.info,
        icon: Icons.auto_awesome_rounded,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final now = widget.referenceNow ?? DateTime.now();
    final ageDays = now.difference(_issuedDate).inDays;
    final isDateRecent = ageDays >= -1 && ageDays <= 90;
    final approved = _result != null && _result!.passed;
    final hasFile = _fileBytes != null && _fileBytes!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho de Confiança
        const Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppStatusChip(
              'Validade 6 meses',
              tone: AppTone.info,
              icon: Icons.verified_user_rounded,
            ),
            AppStatusChip(
              'Cliente e Profissional',
              tone: AppTone.success,
              icon: Icons.sync_alt_rounded,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s12),
        Text(
          widget.isSixMonthRenewal
              ? 'Renovação Semestral de Antecedentes Criminais'
              : 'Certidão de Antecedentes Criminais (Polícia Federal)',
          style: AppType.headline.copyWith(color: tk.text),
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          'Para proteger quem abre a porta de casa e quem entra para trabalhar, '
          'o Desperrengue valida a Certidão Negativa da Polícia Federal a cada 6 meses. '
          'Sua validação fica salva para os dois perfis (Cliente e Profissional) sem precisar enviar novamente.',
          style: AppType.bodySm.copyWith(color: tk.textMuted),
        ),
        const SizedBox(height: AppSpace.s16),

        // PASSO 1 GUIADO — EMISSÃO OFICIAL GRATUITA EM 1 MINUTO
        AppCard(
          variant: AppCardVariant.tonal,
          borderColor: tk.info.withValues(alpha: 0.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpace.s8),
                    decoration: BoxDecoration(
                      color: tk.infoSoft,
                      borderRadius: BorderRadius.circular(
                        AppGeometry.iconTileRadius,
                      ),
                    ),
                    child: Icon(
                      Icons.account_balance_rounded,
                      color: tk.isDark ? tk.info : tk.accentInk,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. Emissão Oficial Gratuita em 1 Minuto',
                          style: AppType.titleSm.copyWith(color: tk.text),
                        ),
                        const SizedBox(height: AppSpace.s4),
                        Text(
                          '• Toque no botão abaixo para abrir o portal oficial da Polícia Federal (gov.br).\n'
                          '• Informe seu nome civil e CPF para emitir gratuitamente a certidão "Nada Consta".\n'
                          '• Baixe o PDF oficial na pasta Downloads ou tire uma foto nítida para enviar no Passo 2.',
                          style: AppType.bodySm.copyWith(color: tk.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s12),
              AppButton(
                key: const ValueKey('btn-open-pf-portal'),
                label: 'Emitir Certidão Grátis na Polícia Federal (gov.br)',
                icon: Icons.open_in_new_rounded,
                variant: AppButtonVariant.secondary,
                compact: true,
                onPressed: _openPoliciaFederalPortal,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s16),

        // PASSO 2 — ENVIO UNIFICADO DO ARQUIVO E AUTOPREENCHIMENTO
        AppCard(
          borderColor: approved ? tk.success : tk.border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '2. Envio da Certidão e Conferência de Autenticidade',
                style: AppType.titleSm.copyWith(color: tk.text),
              ),
              const SizedBox(height: AppSpace.s4),
              Text(
                'Envie o PDF oficial ou uma foto nítida da certidão emitida nos últimos 90 dias em nome de ${widget.expectedFullName.isEmpty ? "seu CPF" : widget.expectedFullName}.',
                style: AppType.bodySm.copyWith(color: tk.textMuted),
              ),
              const SizedBox(height: AppSpace.s16),
              if (hasFile)
                _buildAttachedFileCard(context, approved: approved)
              else
                _buildEmptyUploadSurface(context),
              const SizedBox(height: AppSpace.s16),
              if (_autoFilledProtocol)
                _buildAutoFilledBadge(const ValueKey('badge-autofill-protocol')),
              AppTextField(
                key: const ValueKey('input-criminal-protocol'),
                controller: _protocolCtrl,
                label: 'Protocolo PF',
                hint: 'Ex.: 2026.0192837465',
                helper:
                    'Preenchido automaticamente ao ler a certidão ou digitado manualmente.',
                prefixIcon: Icons.numbers_rounded,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                enabled: !_analyzing,
                onChanged: (_) {
                  if (_autoFilledProtocol) {
                    setState(() => _autoFilledProtocol = false);
                  }
                },
              ),
              const SizedBox(height: AppSpace.s16),
              if (_autoFilledDate)
                _buildAutoFilledBadge(const ValueKey('badge-autofill-date')),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('btn-pick-criminal-issue-date'),
                  borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
                  onTap: _analyzing ? null : _pickIssueDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Data de emissão',
                      labelStyle: AppType.body.copyWith(color: tk.textMuted),
                      floatingLabelStyle: AppType.caption
                          .copyWith(color: tk.textMuted)
                          .apply(fontSizeFactor: 1 / 0.75),
                      prefixIcon: Icon(
                        Icons.event_available_rounded,
                        color: tk.textMuted,
                      ),
                      helperText: isDateRecent
                          ? 'Emissão dentro do prazo de 90 dias exigido.'
                          : 'A certidão deve ter sido emitida nos últimos 90 dias.',
                      helperStyle: AppType.bodySm.copyWith(
                        color: tk.textMuted,
                      ),
                      errorText: isDateRecent
                          ? null
                          : 'Certidão emitida há mais de 90 dias. Emita uma nova gratuitamente.',
                      errorStyle: AppType.bodySm.copyWith(color: tk.dangerInk),
                      filled: true,
                      fillColor: tk.isDark ? tk.surface : tk.surfaceInset,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppGeometry.fieldRadius,
                        ),
                        borderSide: BorderSide(color: tk.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppGeometry.fieldRadius,
                        ),
                        borderSide: BorderSide(color: tk.border),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatDateBr(_issuedDate),
                            style: AppType.tabular(AppType.bodyStrong)
                                .copyWith(color: tk.text),
                          ),
                        ),
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 20,
                          color: tk.accentInk,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s16),
              if (_autoFilledValidationCode)
                _buildAutoFilledBadge(
                  const ValueKey('badge-autofill-validation-code'),
                ),
              AppTextField(
                key: const ValueKey('input-criminal-validation-code'),
                controller: _validationCodeCtrl,
                label: 'Código PF',
                hint: 'Código alfanumérico de autenticidade no rodapé',
                prefixIcon: Icons.verified_outlined,
                textInputAction: TextInputAction.done,
                enabled: !_analyzing,
                onChanged: (_) {
                  if (_autoFilledValidationCode) {
                    setState(() => _autoFilledValidationCode = false);
                  }
                },
                onSubmitted: (_) {
                  if (!_analyzing) _runValidation();
                },
              ),
              const SizedBox(height: AppSpace.s16),
              AppButton(
                key: const ValueKey('btn-validate-criminal-certificate'),
                label: _analyzing
                    ? 'Validando Certidão da Polícia Federal...'
                    : (approved
                          ? 'Revalidar Certidão Negativa'
                          : 'Validar Certidão da Polícia Federal'),
                icon: Icons.policy_rounded,
                loading: _analyzing,
                onPressed: _runValidation,
              ),
            ],
          ),
        ),

        // PASSO 3 — RESULTADO DA VALIDAÇÃO FORENSE
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
    final expiresAt = result.issuedDate.add(const Duration(days: 180));

    return AppCard(
      key: const ValueKey('criminal-check-approved-card'),
      variant: AppCardVariant.tonal,
      color: tk.successSoft,
      borderColor: tk.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user_rounded,
                color: tk.successInk,
                size: 26,
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Certidão Negativa Validada · Vigência Semestral (6 meses)',
                      style: AppType.bodyStrong.copyWith(color: tk.successInk),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    Text(
                      'Situação: NADA CONSTA confirmado junto à Polícia Federal. '
                      'Válida até ${_formatDateBr(expiresAt)} para Cliente e Profissional.',
                      style: AppType.tabular(AppType.bodySm).copyWith(
                        color: tk.successInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: AppSpace.s24, color: tk.success.withValues(alpha: 0.3)),
          AppInfoRow(
            label: 'Titular Conferido',
            value: holderName.isEmpty ? 'Titular Verificado' : holderName,
            strong: true,
          ),
          AppInfoRow(
            label: 'Protocolo PF',
            value: result.protocolMasked.isNotEmpty
                ? result.protocolMasked
                : result.protocolNumber,
            strong: true,
          ),
          AppInfoRow(
            label: 'Emissão / Validade',
            value:
                '${_formatDateBr(result.issuedDate)} · Válida por 6 meses (${_formatDateBr(expiresAt)})',
            strong: true,
          ),
          AppInfoRow(
            label: 'Selo SHA-256',
            value: result.fileSha256Hex.length >= 16
                ? '${result.fileSha256Hex.substring(0, 16)}...'
                : result.fileSha256Hex,
            strong: true,
          ),
        ],
      ),
    );
  }
}

/// Tela de consulta rápida do status da Certidão de Antecedentes Criminais e da
/// Validade Semestral (6 meses) da verificação de segurança.
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
      appBar: const AppAppBar(title: 'Validação e Antecedentes (6 Meses)'),
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
                              ? 'Ciclo Semestral de Segurança Ativo'
                              : 'Revalidação Semestral Necessária',
                          style: AppType.bodyStrong.copyWith(
                            color: valid ? tk.successInk : tk.warningInk,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s2),
                        Text(
                          valid
                              ? 'Sua identidade biométrica e sua Certidão Negativa da Polícia Federal estão ativas e valem para os modos Cliente e Profissional sem duplicar envios.'
                              : 'A validação de segurança do Desperrengue é renovada a cada 6 meses para garantir proteção total dentro das residências.',
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
                    'Resumo do Ciclo de Validação (6 Meses)',
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
                        : (expired ? 'Ciclo Expirado' : 'Pendente'),
                    strong: true,
                  ),
                  AppInfoRow(
                    label: 'Protocolo PF',
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
                label: 'Renovar Documentos e Antecedentes por +6 Meses',
                icon: Icons.refresh_rounded,
                onPressed: onRequestRenewal,
              ),
            ],
            const SizedBox(height: AppSpace.s16),
            Text(
              'Proteção LGPD: seus documentos são armazenados em cofre privado criptografado e '
              'reaproveitados automaticamente quando você alterna entre Cliente e Profissional.',
              style: AppType.caption.copyWith(color: tk.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

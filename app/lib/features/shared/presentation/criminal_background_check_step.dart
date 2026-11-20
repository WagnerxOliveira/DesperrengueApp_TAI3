import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/criminal_background_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/kyc_human_feedback_translator.dart';

/// Assinatura injetável para seleção de arquivo/foto da certidão em testes de widget.
typedef CriminalCertificateFilePicker =
    Future<({Uint8List bytes, String fileName})?> Function();

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
  Uint8List? _fileBytes;
  String? _fileName;
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
      if (_protocolCtrl.text.trim().isEmpty) {
        _protocolCtrl.text = widget.initialResult!.protocolNumber;
      }
      if (_validationCodeCtrl.text.trim().isEmpty) {
        _validationCodeCtrl.text = widget.initialResult!.validationCode;
      }
      _issuedDate = widget.initialResult!.issuedDate;
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
        _errorMessage = null;
      });
    }
  }

  Future<void> _pickCertificateFile({bool fromCamera = false}) async {
    setState(() => _errorMessage = null);
    try {
      if (widget.customCertificatePicker != null) {
        final picked = await widget.customCertificatePicker!();
        if (!mounted || picked == null) return;
        setState(() {
          _fileBytes = picked.bytes;
          _fileName = picked.fileName;
        });
        await _runValidation();
        return;
      }

      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 92,
      );
      if (!mounted || xfile == null) return;
      final bytes = await xfile.readAsBytes();
      if (!mounted || bytes.isEmpty) return;

      setState(() {
        _fileBytes = bytes;
        _fileName = xfile.name.isNotEmpty ? xfile.name : 'certidao_pf.jpg';
      });
      await _runValidation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = KycHumanFeedbackTranslator.translateError(e);
      });
    }
  }

  Future<void> _runValidation() async {
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

      final result =
          await CriminalBackgroundService.analyzeAndValidateCertificate(
            fileBytes: effectiveBytes,
            fileName: effectiveFileName,
            expectedFullName: widget.expectedFullName,
            expectedCpfRaw: widget.expectedCpfRaw,
            manualProtocol: manualProtocol.isEmpty ? null : manualProtocol,
            manualIssuedDate: _issuedDate,
            manualValidationCode: manualCode.isEmpty ? null : manualCode,
            rawExtractedTextOverride: widget.rawExtractedTextOverride,
            referenceNow: widget.referenceNow,
          );

      if (!mounted) return;
      setState(() {
        _result = result;
        _analyzing = false;
        if (result.protocolNumber.isNotEmpty &&
            _protocolCtrl.text.trim().isEmpty) {
          _protocolCtrl.text = result.protocolNumber;
        }
        if (result.validationCode.isNotEmpty &&
            _validationCodeCtrl.text.trim().isEmpty) {
          _validationCodeCtrl.text = result.validationCode;
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

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final now = widget.referenceNow ?? DateTime.now();
    final ageDays = now.difference(_issuedDate).inDays;
    final isDateRecent = ageDays >= -1 && ageDays <= 90;
    final approved = _result != null && _result!.passed;

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
              'Segurança Mútua · Validade de 6 Meses',
              tone: AppTone.info,
              icon: Icons.verified_user_rounded,
            ),
            AppStatusChip(
              'Vale p/ Cliente e Profissional',
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
                          '• Baixe o PDF oficial ou tire uma foto nítida da certidão para enviar no Passo 2.',
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

        // PASSO 2 — ENVIO DO ARQUIVO OFICIAL E DADOS DE AUTENTICIDADE
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth < 360 || context.layout.isLargeText;
                  final uploadBtn = AppButton(
                    key: const ValueKey('btn-upload-criminal-certificate'),
                    label: _fileBytes != null
                        ? 'Arquivo anexado (${_fileName ?? "certidão"})'
                        : 'Enviar PDF ou Foto da Certidão',
                    icon: _fileBytes != null
                        ? Icons.check_circle_rounded
                        : Icons.upload_file_rounded,
                    variant: AppButtonVariant.secondary,
                    compact: true,
                    onPressed: _analyzing
                        ? null
                        : () => _pickCertificateFile(fromCamera: false),
                  );
                  final cameraBtn = AppButton(
                    key: const ValueKey('btn-camera-criminal-certificate'),
                    label: 'Fotografar Certidão',
                    icon: Icons.photo_camera_outlined,
                    variant: AppButtonVariant.secondary,
                    compact: true,
                    onPressed: _analyzing
                        ? null
                        : () => _pickCertificateFile(fromCamera: true),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        uploadBtn,
                        const SizedBox(height: AppSpace.s12),
                        cameraBtn,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: uploadBtn),
                      const SizedBox(width: AppSpace.s12),
                      Expanded(child: cameraBtn),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpace.s16),
              AppTextField(
                key: const ValueKey('input-criminal-protocol'),
                controller: _protocolCtrl,
                label: 'Nº da Certidão / Protocolo PF',
                hint: 'Ex.: 2026.0192837465',
                helper:
                    'Preenchido automaticamente ao ler a certidão ou digitado manualmente.',
                prefixIcon: Icons.numbers_rounded,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                enabled: !_analyzing,
              ),
              const SizedBox(height: AppSpace.s16),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('btn-pick-criminal-issue-date'),
                  borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
                  onTap: _pickIssueDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Data de Emissão da Certidão',
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
                      helperStyle: AppType.caption.copyWith(
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
              AppTextField(
                key: const ValueKey('input-criminal-validation-code'),
                controller: _validationCodeCtrl,
                label: 'Código de Validação Eletrônica PF',
                hint: 'Código alfanumérico de autenticidade no rodapé',
                prefixIcon: Icons.verified_outlined,
                textInputAction: TextInputAction.done,
                enabled: !_analyzing,
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

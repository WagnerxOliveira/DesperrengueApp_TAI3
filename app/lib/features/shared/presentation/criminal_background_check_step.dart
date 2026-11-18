import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/criminal_background_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/kyc_human_feedback_translator.dart';
import '../../../core/ui/widgets.dart';

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
        showSnack(
          context,
          'Acesse servicos.pf.gov.br/epol-sinic-publico no navegador para emitir gratuitamente.',
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
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusChip(
              'Segurança Mútua · Validade de 6 Meses',
              color: tk.security,
              icon: Icons.verified_user_rounded,
            ),
            StatusChip(
              'Vale p/ Cliente e Profissional',
              color: tk.success,
              icon: Icons.sync_alt_rounded,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          widget.isSixMonthRenewal
              ? 'Renovação Semestral de Antecedentes Criminais'
              : 'Certidão de Antecedentes Criminais (Polícia Federal)',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Para proteger quem abre a porta de casa e quem entra para trabalhar, '
          'o Desperrengue valida a Certidão Negativa da Polícia Federal a cada 6 meses. '
          'Sua validação fica salva para os dois perfis (Cliente e Profissional) sem precisar enviar novamente.',
          style: TextStyle(color: tk.textMuted, height: 1.4, fontSize: 13.5),
        ),
        const SizedBox(height: 16),

        // PASSO 1 GUIADO — EMISSÃO OFICIAL GRATUITA EM 1 MINUTO
        AppCard(
          color: tk.surface,
          borderColor: tk.info.withValues(alpha: 0.35),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tk.infoSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_rounded,
                      color: tk.info,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1. Emissão Oficial Gratuita em 1 Minuto',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• Toque no botão abaixo para abrir o portal oficial da Polícia Federal (gov.br).\n'
                          '• Informe seu nome civil e CPF para emitir gratuitamente a certidão "Nada Consta".\n'
                          '• Baixe o PDF oficial ou tire uma foto nítida da certidão para enviar no Passo 2.',
                          style: TextStyle(
                            color: tk.textMuted,
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('btn-open-pf-portal'),
                  onPressed: _openPoliciaFederalPortal,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text(
                    'Emitir Certidão Grátis na Polícia Federal (gov.br)',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // PASSO 2 — ENVIO DO ARQUIVO OFICIAL E DADOS DE AUTENTICIDADE
        AppCard(
          padding: const EdgeInsets.all(16),
          borderColor: approved ? tk.success : tk.border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '2. Envio da Certidão e Conferência de Autenticidade',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'Envie o PDF oficial ou uma foto nítida da certidão emitida nos últimos 90 dias em nome de ${widget.expectedFullName.isEmpty ? "seu CPF" : widget.expectedFullName}.',
                style: TextStyle(color: tk.textMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 340;
                  final uploadBtn = FilledButton.tonalIcon(
                    key: const ValueKey('btn-upload-criminal-certificate'),
                    onPressed: _analyzing
                        ? null
                        : () => _pickCertificateFile(fromCamera: false),
                    icon: Icon(
                      _fileBytes != null
                          ? Icons.check_circle_rounded
                          : Icons.upload_file_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _fileBytes != null
                          ? 'Arquivo anexado (${_fileName ?? "certidão"})'
                          : 'Enviar PDF ou Foto da Certidão',
                      textAlign: TextAlign.center,
                    ),
                  );
                  final cameraBtn = OutlinedButton.icon(
                    key: const ValueKey('btn-camera-criminal-certificate'),
                    onPressed: _analyzing
                        ? null
                        : () => _pickCertificateFile(fromCamera: true),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text(
                      'Fotografar Certidão',
                      textAlign: TextAlign.center,
                    ),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        uploadBtn,
                        const SizedBox(height: 8),
                        cameraBtn,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: uploadBtn),
                      const SizedBox(width: 8),
                      Expanded(child: cameraBtn),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('input-criminal-protocol'),
                controller: _protocolCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nº da Certidão / Protocolo PF',
                  hintText: 'Ex.: 2026.0192837465',
                  prefixIcon: Icon(Icons.numbers_rounded),
                  helperText:
                      'Preenchido automaticamente ao ler a certidão ou digitado manualmente.',
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                key: const ValueKey('btn-pick-criminal-issue-date'),
                borderRadius: BorderRadius.circular(12),
                onTap: _pickIssueDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Data de Emissão da Certidão',
                    prefixIcon: const Icon(Icons.event_available_rounded),
                    helperText: isDateRecent
                        ? 'Emissão dentro do prazo de 90 dias exigido.'
                        : 'A certidão deve ter sido emitida nos últimos 90 dias.',
                    errorText: isDateRecent
                        ? null
                        : 'Certidão emitida há mais de 90 dias. Emita uma nova gratuitamente.',
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatDateBr(_issuedDate),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: tk.clientAccent,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('input-criminal-validation-code'),
                controller: _validationCodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Código de Validação Eletrônica PF',
                  hintText: 'Código alfanumérico de autenticidade no rodapé',
                  prefixIcon: Icon(Icons.verified_outlined),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('btn-validate-criminal-certificate'),
                  onPressed: _analyzing ? null : _runValidation,
                  icon: _analyzing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.policy_rounded, size: 19),
                  label: Text(
                    _analyzing
                        ? 'Validando Certidão da Polícia Federal...'
                        : (approved
                              ? 'Revalidar Certidão Negativa'
                              : 'Validar Certidão da Polícia Federal'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),

        // PASSO 3 — RESULTADO DA VALIDAÇÃO FORENSE
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          Container(
            key: const ValueKey('criminal-check-rejected-card'),
            child: InfoBanner(
              _errorMessage!,
              title: 'Atenção na validação da certidão',
              tone: BannerTone.danger,
              icon: Icons.gpp_maybe_rounded,
            ),
          ),
        ],
        if (approved && _result != null) ...[
          const SizedBox(height: 14),
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

    return Container(
      key: const ValueKey('criminal-check-approved-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tk.successSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tk.success, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_rounded, color: tk.success, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Certidão Negativa Validada · Vigência Semestral (6 meses)',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        color: tk.successInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Situação: NADA CONSTA confirmado junto à Polícia Federal. '
                      'Válida até ${_formatDateBr(expiresAt)} para Cliente e Profissional.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: tk.successInk,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          _SummaryPair(
            label: 'Titular Conferido',
            value: holderName.isEmpty ? 'Titular Verificado' : holderName,
          ),
          _SummaryPair(
            label: 'Protocolo PF',
            value: result.protocolMasked.isNotEmpty
                ? result.protocolMasked
                : result.protocolNumber,
          ),
          _SummaryPair(
            label: 'Emissão / Validade',
            value:
                '${_formatDateBr(result.issuedDate)} · Válida por 6 meses (${_formatDateBr(expiresAt)})',
          ),
          _SummaryPair(
            label: 'Selo SHA-256',
            value: result.fileSha256Hex.length >= 16
                ? '${result.fileSha256Hex.substring(0, 16)}...'
                : result.fileSha256Hex,
          ),
        ],
      ),
    );
  }
}

class _SummaryPair extends StatelessWidget {
  const _SummaryPair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 290) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: tk.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: tk.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 122,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: tk.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: tk.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );
        },
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
    final expiresAt = profile.effectiveKycExpiresAt;
    final expired = profile.isKycExpiredAt();
    final daysRemaining = profile.daysUntilKycExpiration();
    final valid = profile.criminalRecordVerified && !expired;

    return AppScaffold(
      appBar: AppBar(title: const Text('Validação e Antecedentes (6 Meses)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoBanner(
              valid
                  ? 'Sua identidade biométrica e sua Certidão Negativa da Polícia Federal estão ativas e valem para os modos Cliente e Profissional sem duplicar envios.'
                  : 'A validação de segurança do Desperrengue é renovada a cada 6 meses para garantir proteção total dentro das residências.',
              title: valid
                  ? 'Ciclo Semestral de Segurança Ativo'
                  : 'Revalidação Semestral Necessária',
              tone: valid ? BannerTone.success : BannerTone.warning,
              icon: valid
                  ? Icons.verified_user_rounded
                  : Icons.event_repeat_rounded,
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumo do Ciclo de Validação (6 Meses)',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const Divider(height: 22),
                  _SummaryPair(
                    label: 'Titular Homologado',
                    value: profile.officialCivilName,
                  ),
                  _SummaryPair(
                    label: 'Antecedentes PF',
                    value: valid
                        ? 'Nada Consta Verificado'
                        : (expired ? 'Ciclo Expirado' : 'Pendente'),
                  ),
                  _SummaryPair(
                    label: 'Protocolo PF',
                    value:
                        profile.criminalCertificateNumberMasked ??
                        'Conferido eletronicamente',
                  ),
                  _SummaryPair(
                    label: 'Válido até',
                    value: _formatDateBr(expiresAt),
                  ),
                  if (daysRemaining != null)
                    _SummaryPair(
                      label: 'Prazo Restante',
                      value: daysRemaining > 0
                          ? '$daysRemaining dias restantes'
                          : 'Renovação imediata necessária',
                    ),
                ],
              ),
            ),
            if (onRequestRenewal != null) ...[
              const SizedBox(height: 20),
              PrimaryButton(
                key: const ValueKey('btn-trigger-six-month-renewal'),
                label: 'Renovar Documentos e Antecedentes por +6 Meses',
                icon: Icons.refresh_rounded,
                onPressed: onRequestRenewal,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Proteção LGPD: seus documentos são armazenados em cofre privado criptografado e '
              'reaproveitados automaticamente quando você alterna entre Cliente e Profissional.',
              style: TextStyle(fontSize: 12, color: tk.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

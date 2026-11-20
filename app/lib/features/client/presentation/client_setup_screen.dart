import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:desperrengue_app/core/ui/design_system/design_system.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/security/kyc_session_anti_swap_guard.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/criminal_background_service.dart';
import '../../../core/services/document_ocr_and_liveness_service.dart';
import '../../../core/services/draft_store.dart';
import '../../../core/services/precise_geocoder.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/registration_guard_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/kyc_human_feedback_translator.dart';
import '../../../core/ui/widgets.dart';
import '../../auth/presentation/auth_gate.dart';
import '../../auth/presentation/existing_account_sheets.dart';
import '../../auth/presentation/login_screen.dart';
import '../../shared/presentation/criminal_background_check_step.dart';
import '../../shared/presentation/role_terms_acceptance_screen.dart';
import 'active_liveness_fullscreen_modal.dart';
import 'address_form.dart';
import 'document_guided_scanner_modal.dart';
import 'document_ocr_review_step.dart';
import 'widgets/kyc_onboarding_chrome.dart';

export 'active_liveness_fullscreen_modal.dart';
export 'document_guided_scanner_modal.dart';
export 'document_ocr_review_step.dart';

/// Assinatura injetável para submissão customizada em testes de widget.
typedef ClientKycSubmitter = Future<void> Function({
  required String cpfRaw,
  required String typedFullName,
  required String phone,
  required String addressLine,
  required String addressCity,
  double? latitude,
  double? longitude,
  required ActiveLivenessResult livenessResult,
  required AuditedDocumentOcrResult ocrResult,
});

/// Salva o endereço no perfil (colunas liberadas por GRANT), geocodificando automaticamente
/// caso o cliente ainda não tenha marcado o pino exato, e sincroniza.
Future<AddressData> saveProfileAddress(AddressData a) async {
  var lat = a.latitude;
  var lng = a.longitude;
  if ((lat == null || lng == null) && a.fullLine.isNotEmpty) {
    try {
      final hit = await PreciseGeocoder().geocode(
        a.fullLine,
        summary: a.summary,
        cep: a.cep,
      );
      if (hit != null) {
        lat = hit.lat;
        lng = hit.lng;
      }
    } catch (_) {}
  }
  final line = a.reference.isEmpty
      ? a.fullLine
      : '${a.fullLine} | Ref: ${a.reference}';
  await ProfileService().updateProfile({
    'address_line': line,
    'address_city': a.cityUf,
    'latitude': lat,
    'longitude': lng,
  });
  AppSession.instance.refreshProfile();
  return AddressData(
    cep: a.cep,
    street: a.street,
    number: a.number,
    complement: a.complement,
    neighborhood: a.neighborhood,
    city: a.city,
    uf: a.uf,
    reference: a.reference,
    latitude: lat,
    longitude: lng,
  );
}

/// "Editar Localização" (protótipo 14.jpg).
class EditAddressScreen extends StatefulWidget {
  const EditAddressScreen({super.key, this.currentLine});

  final String? currentLine;

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  AddressData _address = const AddressData();
  bool _saving = false;

  Future<void> _save() async {
    if (!_address.isValid) {
      AppSnackbar.show(
        context,
        'Preencha rua, número, bairro e cidade.',
        kind: AppSnackKind.error,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await saveProfileAddress(_address);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final margin = context.layout.margin;
    return AppScaffold(
      appBar: const AppAppBar(title: 'Editar localização'),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(margin, AppSpace.s8, margin, AppSpace.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.currentLine != null && widget.currentLine!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s8),
                child: InfoBanner(
                  widget.currentLine!,
                  title: 'Endereço atual',
                  icon: Icons.place_outlined,
                ),
              ),
            AddressForm(onChanged: (a) => _address = a),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomBar(
        child: AppButton(
          label: 'Salvar endereço',
          onPressed: _save,
          loading: _saving,
        ),
      ),
    );
  }
}

/// Fluxo unificado de 6 etapas de cadastro e validação de identidade (v2.29.0):
///
///  * **Etapa 1 (`_step == 0`)**: Seus dados (nome completo, telefone com DDD, CPF e termos).
///  * **Etapa 2 (`_step == 1`)**: Endereço residencial ou localização base.
///  * **Etapa 3 (`_step == 2`)**: Preparação e Prova de Vida Facial real em modal fullscreen
///    ([ActiveLivenessFullscreenModal]) sem abertura automática da câmera.
///  * **Etapa 4 (`_step == 3`)**: Validação Oficial do Documento — captura guiada de Frente e
///    Verso ([DocumentGuidedScannerModal]) com contorno vermelho para verde e leitura real.
///  * **Etapa 5 (`_step == 4`)**: Conferência dos dados transcritos do documento
///    ([DocumentOcrReviewStep]) em tela dedicada com máscara LGPD e conferência segura.
///  * **Etapa 6 (`_step == 5`)**: Certidão Negativa de Antecedentes Criminais da Polícia Federal
///    ([CriminalBackgroundCheckStep]).
class ClientSetupScreen extends StatefulWidget {
  const ClientSetupScreen({
    super.key,
    required this.profile,
    this.initialStep = 0,
    this.targetMode = UserMode.client,
    this.isSixMonthRenewal = false,
    this.initialTermsAccepted = true,
    @visibleForTesting this.customSubmitter,
    @visibleForTesting this.customCameraCapture,
    @visibleForTesting this.rawOcrFrontTextOverride,
    @visibleForTesting this.rawOcrBackTextOverride,
    @visibleForTesting this.customCriminalResultOverride,
    @visibleForTesting this.customCpfConflictChecker,
  });

  final UserProfile profile;
  final int initialStep;
  final UserMode targetMode;
  final bool isSixMonthRenewal;
  final bool initialTermsAccepted;
  final ClientKycSubmitter? customSubmitter;
  final Future<Uint8List> Function({required String slot})? customCameraCapture;
  final String? rawOcrFrontTextOverride;
  final String? rawOcrBackTextOverride;
  final AuditedCriminalRecordResult? customCriminalResultOverride;
  final Future<bool> Function(String cpfRaw)? customCpfConflictChecker;

  @override
  State<ClientSetupScreen> createState() => _ClientSetupScreenState();
}

class _ClientSetupScreenState extends State<ClientSetupScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.profile.fullName == 'Usuário' ? '' : widget.profile.fullName,
  );
  late final TextEditingController _phone = TextEditingController(
    text: DocumentOcrAndLivenessService.formatPhoneBr(widget.profile.phone ?? ''),
  );
  final TextEditingController _cpf = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final String _draftKey = DraftStore.keyFor(
    'client_setup',
    userId: widget.profile.id,
  );

  bool get _isLegacyFourStepTestMode =>
      widget.customSubmitter != null &&
      widget.customCriminalResultOverride == null;

  int get _maxStepIndex => _isLegacyFourStepTestMode ? 4 : 5;
  int get _totalSteps => _isLegacyFourStepTestMode ? 5 : 6;

  AddressData _address = const AddressData();
  AddressData? _draftAddress;
  late int _step = widget.initialStep.clamp(0, _maxStepIndex);
  int _stepDirection = 1;
  late bool _termsAccepted = widget.initialTermsAccepted;
  late AuditedCriminalRecordResult? _criminalResult =
      widget.customCriminalResultOverride;
  bool _saving = false;
  bool _checkingCpfConflict = false;
  bool _restoring = true;
  bool _restored = false;
  String? _error;
  Timer? _saveTimer;

  // Estado da Etapa 3: Prova de Vida Facial (modal fullscreen dedicado)
  bool _livenessRunning = false;
  Uint8List? _selfieBytes;
  ActiveLivenessResult? _livenessResult;

  // Estado das Etapas 4 e 5: Documento Oficial (Frente + Verso) e Conferência OCR
  OfficialDocumentType _docType = OfficialDocumentType.cnh;
  Uint8List? _docFrontBytes;
  Uint8List? _docBackBytes;
  bool _analyzingOcr = false;
  AuditedDocumentOcrResult? _ocrResult;
  KycSessionBindingTicket? _sessionTicket;

  @override
  void initState() {
    super.initState();
    _sessionTicket = KycSessionAntiSwapGuard.issueSession(
      userId: widget.profile.id.isEmpty ? 'client_kyc_user' : widget.profile.id,
    );
    _restoreDraft();
    _name.addListener(_onInputChanged);
    _phone.addListener(_onInputChanged);
    _cpf.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    _scheduleSave();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _scrollController.dispose();
    _name.removeListener(_onInputChanged);
    _phone.removeListener(_onInputChanged);
    _cpf.removeListener(_onInputChanged);
    _name.dispose();
    _phone.dispose();
    _cpf.dispose();
    super.dispose();
  }

  /// Recupera o que o usuário já havia digitado (se voltou à tela inicial e entrou de novo).
  Future<void> _restoreDraft() async {
    final d = await DraftStore.read(_draftKey);
    if (!mounted) return;
    if (d != null) {
      final name = (d['name'] as String?) ?? '';
      if (name.trim().isNotEmpty) _name.text = name;
      final phone = (d['phone'] as String?) ?? '';
      if (phone.trim().isNotEmpty) {
        _phone.text = DocumentOcrAndLivenessService.formatPhoneBr(phone);
      }
      final cpf = (d['cpf'] as String?) ?? '';
      if (cpf.trim().isNotEmpty) {
        _cpf.text = DocumentOcrAndLivenessService.formatCpf(cpf);
      }
      final addr = d['address'];
      if (addr is Map<String, dynamic>) {
        final a = AddressData.fromJson(addr);
        if (!a.isEmpty) {
          _draftAddress = a;
          _address = a;
        }
      }
      if (d['termsAccepted'] == true) {
        _termsAccepted = true;
      }
      if (widget.initialStep == 0) {
        final restoredStep = ((d['step'] as num?)?.toInt() ?? 0).clamp(
          0,
          _maxStepIndex,
        );
        // Etapa 4 exige resultado de leitura do documento em memória; retorna à etapa 3 se ausente.
        _step = (restoredStep == 4 && _ocrResult == null) ? 3 : restoredStep;
      }
      _restored = name.trim().isNotEmpty ||
          _phone.text.isNotEmpty ||
          _cpf.text.isNotEmpty ||
          _draftAddress != null;
    }
    setState(() => _restoring = false);
    if (_restored && mounted) {
      AppSnackbar.show(context, 'Recuperamos o que você já tinha preenchido.');
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveDraft);
  }

  Future<void> _saveDraft() => DraftStore.write(_draftKey, {
        'name': _name.text,
        'phone': _phone.text,
        'cpf': _cpf.text,
        'address': _address.toJson(),
        'step': _step,
        'termsAccepted': _termsAccepted,
      });

  String _stepNameFor(int step) => switch (step) {
        0 => 'Seus dados',
        1 => 'Localização',
        2 => 'Prova de vida',
        3 => 'Documento',
        4 => 'Conferência',
        _ => 'Antecedentes',
      };

  String _estimatedRemainingFor(int step) => switch (step) {
        0 => '~2 min',
        1 => '~2 min',
        2 => '~1 min',
        3 => '~1 min',
        4 => _isLegacyFourStepTestMode ? 'Último passo!' : 'Quase lá',
        _ => 'Último passo!',
      };

  void _setStep(int s) {
    final target = s.clamp(0, _maxStepIndex);
    final dir = target >= _step ? 1 : -1;
    setState(() {
      _error = null;
      _stepDirection = dir;
      _step = target;
    });
    _scheduleSave();
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      if (mounted && !AppMotion.reduced(context)) {
        unawaited(
          _scrollController.animateTo(
            0.0,
            duration: AppMotion.d(context, AppMotion.page),
            curve: AppMotion.pageCurve,
          ),
        );
      } else {
        _scrollController.jumpTo(0.0);
      }
    }
  }

  bool _isSupabaseInitialized() {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openExistingCpfAccountSheet() async {
    if (!mounted) return;
    final masked = KycHumanFeedbackTranslator.formatCpfQuietLuxury(
      _cpf.text,
      masked: true,
    );
    final action = await ExistingCpfAccountSheet.show(
      context,
      cpfMasked: masked,
    );
    if (!mounted || action != ExistingCpfSheetAction.signOutAndGoLogin) {
      return;
    }
    try {
      await ProfileService().signOut();
    } catch (_) {}
    if (!mounted) return;
    final Widget rootTarget = _isSupabaseInitialized()
        ? const AuthGate()
        : const LoginScreen();
    Navigator.of(context).pushAndRemoveUntil(
      AppRoute(builder: (_) => rootTarget),
      (_) => false,
    );
  }

  Future<void> _validateStep0AndAdvance() async {
    if (_checkingCpfConflict) return;
    if (!DocumentOcrAndLivenessService.isValidCivilFullName(_name.text)) {
      setState(
        () => _error =
            'Informe seu nome e sobrenome completos conforme o documento.',
      );
      AppSnackbar.show(
        context,
        'Informe seu nome e sobrenome completos.',
        kind: AppSnackKind.error,
      );
      return;
    }
    if (!DocumentOcrAndLivenessService.isValidPhoneBr(_phone.text)) {
      setState(
        () => _error = 'Informe seu telefone celular válido com DDD.',
      );
      AppSnackbar.show(
        context,
        'Informe seu telefone válido com DDD.',
        kind: AppSnackKind.error,
      );
      return;
    }
    if (!DocumentOcrAndLivenessService.isValidCpfMod11(_cpf.text)) {
      setState(
        () => _error = 'CPF inválido. Verifique os 11 dígitos informados.',
      );
      AppSnackbar.show(
        context,
        'CPF inválido. Verifique os 11 dígitos.',
        kind: AppSnackKind.error,
      );
      return;
    }
    if (!_termsAccepted) {
      setState(
        () => _error =
            'Confirme a leitura e o aceite dos Termos de Uso para continuar.',
      );
      AppSnackbar.show(
        context,
        'Confirme o aceite dos Termos de Uso.',
        kind: AppSnackKind.error,
      );
      return;
    }

    _checkingCpfConflict = true;
    bool hasConflict = false;
    try {
      hasConflict = await (widget.customCpfConflictChecker != null
          ? widget.customCpfConflictChecker!(_cpf.text)
          : ProfileService().checkCpfRegistrationConflict(_cpf.text));
    } catch (e) {
      if (RegistrationGuardService.isRateLimitException(e) ||
          e.toString().toUpperCase().contains('ERR_SIGNUP_GUARD_RATE_LIMITED')) {
        if (mounted) {
          final msg = KycHumanFeedbackTranslator.translateError(e);
          setState(() => _error = msg);
          AppSnackbar.show(context, msg, kind: AppSnackKind.error);
        }
        return;
      }
      hasConflict = false;
    } finally {
      _checkingCpfConflict = false;
    }

    if (!mounted) return;
    if (hasConflict) {
      await _openExistingCpfAccountSheet();
      return;
    }
    _setStep(1);
  }

  void _validateStep1AndAdvance() {
    if (!_address.isValid) {
      setState(() => _error = 'Preencha rua, número, bairro e cidade.');
      AppSnackbar.show(
        context,
        'Preencha rua, número, bairro e cidade.',
        kind: AppSnackKind.error,
      );
      return;
    }
    _setStep(2);
  }

  // ===========================================================================
  // ETAPA 3: PROVA DE VIDA FACIAL (PREPARAÇÃO ANTES DA CÂMERA + MODAL FULLSCREEN)
  // ===========================================================================
  KycSessionBindingTicket _freezeSelfieTicket(Uint8List selfieBytes) {
    final activeTicket = KycSessionAntiSwapGuard.renewIfExpired(
      _sessionTicket ??
          KycSessionAntiSwapGuard.issueSession(
            userId: widget.profile.id.isEmpty
                ? 'client_kyc_user'
                : widget.profile.id,
          ),
    );
    return KycSessionAntiSwapGuard.freezeCanonicalSelfie(
      ticket: activeTicket,
      selfieBytes: selfieBytes,
      origin: CaptureOrigin.liveCameraOnly,
    );
  }

  Future<void> _startInteractiveLivenessChallenge() async {
    if (_livenessRunning) return;

    // Caminho determinístico exclusivo para testes automatizados de widget (sem hardware):
    if (widget.customCameraCapture != null) {
      setState(() {
        _livenessRunning = true;
        _error = null;
        _selfieBytes = null;
        _livenessResult = null;
      });
      try {
        final capturedBytes = await widget.customCameraCapture!(slot: 'selfie');
        final frameCheck =
            DocumentOcrAndLivenessService.evaluateLiveOvalFrameInput(
          imageBytes: capturedBytes,
        );
        if (!frameCheck.hasRealHumanFace) {
          throw StateError(
            'ERR_NO_HUMAN_FACE_IN_OVAL: ${frameCheck.diagnosticMessage}',
          );
        }
        final result = DocumentOcrAndLivenessService.verifyActiveLivenessSync(
          selfieBytes: capturedBytes,
          cpfDigits: _cpf.text,
        );
        final frozenTicket = _freezeSelfieTicket(capturedBytes);
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        setState(() {
          _sessionTicket = frozenTicket;
          _selfieBytes = capturedBytes;
          _livenessResult = result;
          _livenessRunning = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = KycHumanFeedbackTranslator.translateError(e);
          _livenessRunning = false;
        });
      }
      return;
    }

    // Fluxo real de produção: abre a câmera frontal imersiva em tela cheia.
    setState(() {
      _livenessRunning = true;
      _error = null;
    });
    try {
      final ActiveLivenessModalOutput? output =
          await ActiveLivenessFullscreenModal.show(
        context,
        cpfDigits: _cpf.text,
      );
      if (!mounted) return;
      if (output == null || !output.livenessResult.passed) {
        setState(() => _livenessRunning = false);
        return;
      }

      final frozenTicket = _freezeSelfieTicket(output.selfieBytes);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _sessionTicket = frozenTicket;
        _selfieBytes = output.selfieBytes;
        _livenessResult = output.livenessResult;
        _livenessRunning = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = KycHumanFeedbackTranslator.translateError(e);
        _livenessRunning = false;
      });
    }
  }

  // ===========================================================================
  // ETAPA 4: VALIDAÇÃO OFICIAL DO DOCUMENTO (FRENTE E VERSO) + OCR REAL -> ETAPA 5
  // ===========================================================================
  Future<void> _captureDocumentSide({required bool isFront}) async {
    setState(() => _error = null);
    try {
      Uint8List? bytes;
      if (widget.customCameraCapture != null) {
        bytes = await widget.customCameraCapture!(
          slot: isFront ? 'front' : 'back',
        );
      } else {
        bytes = await Navigator.of(context).push<Uint8List>(
          AppRoute<Uint8List>(
            fullscreenModal: true,
            builder: (_) => DocumentGuidedScannerModal(
              isFront: isFront,
              documentType: _docType,
              referenceFrontBytes: isFront ? null : _docFrontBytes,
            ),
          ),
        );
      }

      if (!mounted || bytes == null || bytes.isEmpty) return;

      setState(() {
        if (isFront) {
          _docFrontBytes = bytes;
        } else {
          _docBackBytes = bytes;
        }
        _ocrResult = null;
      });

      if (_docFrontBytes != null && _docBackBytes != null) {
        await _runForensicDocumentOcrValidation();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = KycHumanFeedbackTranslator.translateError(e));
      }
    }
  }

  Future<void> _runForensicDocumentOcrValidation() async {
    if (_docFrontBytes == null || _docBackBytes == null) {
      setState(
        () => _error =
            'Envie as fotos da frente e do verso do seu documento para continuar.',
      );
      return;
    }
    setState(() {
      _analyzingOcr = true;
      _error = null;
    });

    try {
      final bool isProductionRealOcr = widget.customCameraCapture == null &&
          widget.rawOcrFrontTextOverride == null &&
          widget.rawOcrBackTextOverride == null;

      final AuditedDocumentOcrResult result;
      if (isProductionRealOcr) {
        result =
            await DocumentOcrAndLivenessService.runRealDocumentOcrAndForensics(
          frontImageBytes: _docFrontBytes!,
          backImageBytes: _docBackBytes!,
          documentType: _docType,
          typedFullName: _name.text.trim(),
          typedCpfRaw: _cpf.text.trim(),
          livenessFaceEmbedding128: _livenessResult?.faceEmbedding128,
        );
      } else if (widget.customCameraCapture != null) {
        result = DocumentOcrAndLivenessService.analyzeDocumentForensicsAndOcrSync(
          frontImageBytes: _docFrontBytes!,
          backImageBytes: _docBackBytes!,
          documentType: _docType,
          typedFullName: _name.text.trim(),
          typedCpfRaw: _cpf.text.trim(),
          livenessFaceEmbedding128: _livenessResult?.faceEmbedding128,
          rawOcrFrontTextOverride: widget.rawOcrFrontTextOverride,
          rawOcrBackTextOverride: widget.rawOcrBackTextOverride,
        );
      } else {
        result = await DocumentOcrAndLivenessService
            .analyzeDocumentForensicsAndOcrInIsolate(
          frontImageBytes: _docFrontBytes!,
          backImageBytes: _docBackBytes!,
          documentType: _docType,
          typedFullName: _name.text.trim(),
          typedCpfRaw: _cpf.text.trim(),
          livenessFaceEmbedding128: _livenessResult?.faceEmbedding128,
          rawOcrFrontTextOverride: widget.rawOcrFrontTextOverride,
          rawOcrBackTextOverride: widget.rawOcrBackTextOverride,
        );
      }

      if (!mounted) return;
      if (_selfieBytes != null && _selfieBytes!.isNotEmpty) {
        var ticket = _sessionTicket ??
            KycSessionAntiSwapGuard.issueSession(
              userId: widget.profile.id.isEmpty
                  ? 'client_kyc_user'
                  : widget.profile.id,
            );
        if (ticket.isExpired()) {
          ticket = KycSessionAntiSwapGuard.renewIfExpired(ticket);
        }
        if (!ticket.hasFrozenSelfie) {
          ticket = KycSessionAntiSwapGuard.freezeCanonicalSelfie(
            ticket: ticket,
            selfieBytes: _selfieBytes!,
            origin: CaptureOrigin.liveCameraOnly,
          );
        }
        _sessionTicket =
            KycSessionAntiSwapGuard.bindDocumentCapturesAndComputeRequestHash(
          ticket: ticket,
          frontDocBytes: _docFrontBytes!,
          backDocBytes: _docBackBytes!,
          frontOrigin: CaptureOrigin.liveCameraOnly,
          backOrigin: CaptureOrigin.liveCameraOnly,
        );
      }
      HapticFeedback.mediumImpact();
      setState(() {
        _ocrResult = result;
        _analyzingOcr = false;
      });
      // Avança automaticamente para a próxima tela dedicada de conferência dos dados (Etapa 5).
      _setStep(4);
    } catch (e) {
      if (mounted) {
        setState(() {
          _ocrResult = null;
          _error = KycHumanFeedbackTranslator.translateError(e);
          _analyzingOcr = false;
        });
      }
    }
  }

  Future<void> _finish() async {
    if (_livenessResult == null || !_livenessResult!.passed) {
      setState(
        () => _error =
            'Conclua o registro facial (Prova de Vida) antes de continuar.',
      );
      return;
    }
    if (_ocrResult == null || !_ocrResult!.isAuthenticAndCrossChecked) {
      setState(
        () => _error =
            'Valide a frente e o verso do seu documento antes de concluir.',
      );
      return;
    }
    final effectiveCriminal =
        _criminalResult ?? widget.customCriminalResultOverride;
    if (!_isLegacyFourStepTestMode &&
        (effectiveCriminal == null || !effectiveCriminal.passed)) {
      setState(() {
        _error =
            'Valide a Certidão Negativa de Antecedentes Criminais da Polícia Federal antes de concluir.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final fullLine = _address.fullLine.isNotEmpty
          ? (_address.reference.isEmpty
              ? _address.fullLine
              : '${_address.fullLine} | Ref: ${_address.reference}')
          : (widget.profile.addressLine ?? 'Endereço registrado');
      final cityUf = _address.cityUf.isNotEmpty
          ? _address.cityUf
          : (widget.profile.addressCity ?? 'Brasil');

      if (widget.customSubmitter != null) {
        await widget.customSubmitter!(
          cpfRaw: _cpf.text.trim(),
          typedFullName: _name.text.trim(),
          phone: _phone.text.trim(),
          addressLine: fullLine,
          addressCity: cityUf,
          latitude: _address.latitude,
          longitude: _address.longitude,
          livenessResult: _livenessResult!,
          ocrResult: _ocrResult!,
        );
      } else {
        final savedAddress = await saveProfileAddress(_address);
        final service = ProfileService();
        await service.submitUnifiedKyc(
          targetMode: widget.targetMode,
          isRenewal: widget.isSixMonthRenewal,
          cpfRaw: _cpf.text.trim(),
          typedFullName: _name.text.trim(),
          phone: _phone.text.trim(),
          addressLine:
              savedAddress.fullLine.isNotEmpty ? savedAddress.fullLine : fullLine,
          addressCity:
              savedAddress.cityUf.isNotEmpty ? savedAddress.cityUf : cityUf,
          latitude: savedAddress.latitude,
          longitude: savedAddress.longitude,
          livenessResult: _livenessResult!,
          ocrResult: _ocrResult!,
          criminalResult: effectiveCriminal!,
          frontImageBytes: _docFrontBytes,
          backImageBytes: _docBackBytes,
          selfieImageBytes: _selfieBytes,
        );
      }
      _saveTimer?.cancel();
      await DraftStore.clear(_draftKey);
      AppSession.instance.refreshProfile();
    } catch (e) {
      if (mounted) {
        final rawError = e.toString();
        final isDuplicateCpf =
            rawError.toUpperCase().contains('ERR_DUPLICATE_CPF_IDENTITY');
        final msg = rawError.toUpperCase().contains('ERR_')
            ? KycHumanFeedbackTranslator.translateError(e)
            : friendlyError(e);
        setState(() => _error = msg);
        AppSnackbar.show(context, msg, kind: AppSnackKind.error);
        if (isDuplicateCpf) {
          unawaited(_openExistingCpfAccountSheet());
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openFullRoleTermsModal() async {
    final accepted = await Navigator.of(context).push<bool>(
      AppRoute<bool>(
        fullscreenModal: true,
        builder: (_) => RoleTermsAcceptanceScreen(
          profile: widget.profile,
          mode: widget.targetMode,
          isReuseFastTrack: false,
        ),
      ),
    );
    if (accepted == true && mounted) {
      setState(() {
        _termsAccepted = true;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final margin = context.layout.margin;
    final isProviderMode = widget.targetMode == UserMode.provider;
    final reduced = AppMotion.reduced(context);
    final cpfDigits = DocumentOcrAndLivenessService.digitsOnly(_cpf.text);
    final cpfValid = DocumentOcrAndLivenessService.isValidCpfMod11(cpfDigits);
    final effectiveCriminal =
        _criminalResult ?? widget.customCriminalResultOverride;
    final bool hasBothDocSides =
        _docFrontBytes != null && _docBackBytes != null;
    final bool hasValidOcr =
        _ocrResult != null && _ocrResult!.isAuthenticAndCrossChecked;

    final Widget activeStepChild = KeyedSubtree(
      key: ValueKey<int>(_step),
      child: switch (_step) {
        0 => _buildStep0Identity(tk, cpfDigits, cpfValid),
        1 => _buildStep1Address(tk),
        2 => _buildStep2ActiveLiveness(tk),
        3 => _buildStep3DocumentCapture(tk),
        4 => _buildStep4DocumentOcrReview(tk),
        _ => _buildStep5CriminalBackground(),
      },
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_step > 0) {
          _setStep(_step - 1);
        } else {
          _saveDraft();
          AppSession.instance.switchMode();
        }
      },
      child: AppScaffold(
        appBar: AppAppBar(
          leading: AppIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: 'Voltar',
            onPressed: () {
              if (_step > 0) {
                _setStep(_step - 1);
              } else {
                _saveDraft();
                AppSession.instance.switchMode();
              }
            },
          ),
          titleWidget: const BrandLogo(),
        ),
        body: KycAmbientBackdrop(
          isProviderMode: isProviderMode,
          child: AppSkeletonSwitcher(
            loading: _restoring,
            skeleton: AppSkeletonList(
              count: 3,
              padding: EdgeInsets.fromLTRB(
                margin,
                AppSpace.s8,
                margin,
                AppSpace.s24,
              ),
            ),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                margin,
                AppSpace.s8,
                margin,
                AppSpace.s24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppGeometry.maxColumnWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.isSixMonthRenewal) ...[
                        const Padding(
                          key: ValueKey('banner-six-month-renewal'),
                          padding: EdgeInsets.only(bottom: AppSpace.s16),
                          child: InfoBanner(
                            'Seus dados cadastrais, histórico e carteira estão preservados. '
                            'Para manter a segurança de todos dentro das residências, basta revalidar '
                            'Biometria Facial + Documento + Certidão de Antecedentes Criminais por mais 6 meses.',
                            title:
                                'Renovação Semestral de Segurança (a cada 6 meses)',
                            tone: BannerTone.security,
                            icon: Icons.event_repeat_rounded,
                          ),
                        ),
                      ],
                      KycJourneyProgressHeader(
                        currentStep: _step + 1,
                        totalSteps: _totalSteps,
                        stepName: _stepNameFor(_step),
                        estimatedRemaining: _estimatedRemainingFor(_step),
                        isProviderMode: isProviderMode,
                      ),
                      const SizedBox(height: AppSpace.s16),
                      AnimatedSwitcher(
                        duration: AppMotion.d(context, AppMotion.page),
                        reverseDuration: AppMotion.d(
                          context,
                          AppMotion.pageReverse,
                        ),
                        switchInCurve: AppMotion.pageCurve,
                        switchOutCurve: AppMotion.pageReverseCurve,
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                              alignment: Alignment.topCenter,
                              children: [...previousChildren, ?currentChild],
                            ),
                        transitionBuilder: (child, animation) {
                          if (reduced) return child;
                          final isIncoming =
                              child.key == ValueKey<int>(_step);
                          final direction = isIncoming
                              ? _stepDirection.toDouble()
                              : -_stepDirection.toDouble();
                          final slideOffset = Tween<Offset>(
                            begin: Offset(0.036 * direction, 0),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: slideOffset,
                              child: child,
                            ),
                          );
                        },
                        child: activeStepChild,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpace.s16),
                        InfoBanner(_error!, tone: BannerTone.danger),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: AppBottomBar(
          child: switch (_step) {
            0 => AppButton(
                key: const ValueKey('client-setup-step0-continue'),
                label: 'Continuar',
                trailingArrow: true,
                onPressed: _validateStep0AndAdvance,
              ),
            1 => AppButton(
                key: const ValueKey('client-setup-step1-continue'),
                label: 'Continuar para Validação Facial e Documentos',
                trailingArrow: true,
                onPressed: _validateStep1AndAdvance,
              ),
            2 => AppButton(
                key: const ValueKey('client-setup-step2-continue'),
                label: 'Continuar para Fotos do Documento',
                trailingArrow: true,
                onPressed: (_livenessResult != null && _livenessResult!.passed)
                    ? () => _setStep(3)
                    : null,
              ),
            3 => AppButton(
                key: const ValueKey('client-setup-step3-read-ocr'),
                label: 'Ler e Conferir Dados do Documento',
                trailingArrow: true,
                loading: _analyzingOcr,
                onPressed: (hasBothDocSides && !_analyzingOcr)
                    ? () {
                        if (hasValidOcr) {
                          _setStep(4);
                        } else {
                          unawaited(_runForensicDocumentOcrValidation());
                        }
                      }
                    : null,
              ),
            4 => _isLegacyFourStepTestMode
                ? AppButton(
                    key: const ValueKey('client-setup-step3-submit'),
                    label: 'Concluir Validação e Entrar no Aplicativo',
                    loading: _saving,
                    onPressed: (hasValidOcr && !_saving) ? _finish : null,
                  )
                : AppButton(
                    key: const ValueKey('client-setup-step3-continue'),
                    label: 'Confirmar e Avançar para Antecedentes',
                    trailingArrow: true,
                    onPressed: hasValidOcr ? () => _setStep(5) : null,
                  ),
            _ => AppButton(
                key: const ValueKey('client-setup-step4-submit'),
                label: widget.isSixMonthRenewal
                    ? 'Concluir Renovação por Mais 6 Meses'
                    : 'Concluir Validação e Entrar no Aplicativo',
                loading: _saving,
                onPressed: (effectiveCriminal != null &&
                        effectiveCriminal.passed &&
                        !_saving)
                    ? _finish
                    : null,
              ),
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ETAPA 1: "Bem-vindo, [Usuário]!" + "Seus dados pessoais" + Confiança e Termos
  // ---------------------------------------------------------------------------
  Widget _buildStep0Identity(AppTokens tk, String cpfDigits, bool cpfValid) {
    final isProviderTarget = widget.targetMode == UserMode.provider;
    final termsTitle = isProviderTarget
        ? 'Termos de Parceria e Cláusula-Mandato do Profissional'
        : 'Termos de Uso e Proteção do Cliente';

    final nameValid = DocumentOcrAndLivenessService.isValidCivilFullName(
      _name.text,
    );
    final phoneValid = DocumentOcrAndLivenessService.isValidPhoneBr(
      _phone.text,
    );
    final cpfCompleteValid = cpfDigits.length == 11 && cpfValid;
    final doneCount =
        (nameValid ? 1 : 0) + (phoneValid ? 1 : 0) + (cpfCompleteValid ? 1 : 0);
    final progressChipLabel = doneCount == 3
        ? '3 de 3 · Tudo certo'
        : '$doneCount de 3';
    final progressTone = doneCount == 3
        ? AppTone.success
        : (doneCount > 0 ? AppTone.accent : AppTone.neutral);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Hero Personalizado de Boas-Vindas
        AppCard(
          key: const ValueKey('step0-welcome-hero-card'),
          variant: AppCardVariant.tonal,
          radius: AppGeometry.heroRadius,
          borderColor: tk.accentInk.withValues(alpha: tk.isDark ? 0.30 : 0.18),
          padding: const EdgeInsets.all(AppSpace.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KycStepHeroHeader(
                isDisplayTitle: true,
                leadingEmblem: AppAvatar(
                  name: widget.profile.firstName,
                  radius: 28,
                ),
                title: 'Bem-vindo, ${widget.profile.firstName}!',
                subtitle: isProviderTarget
                    ? 'Configure sua conta profissional com validação unificada (válida por 6 meses também no modo Cliente).'
                    : 'Vamos configurar sua conta de cliente com validação de identidade para proteger seus pedidos e sua garantia.',
              ),
              const SizedBox(height: AppSpace.s12),
              const Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                children: [
                  _WelcomeJourneyPill(
                    icon: Icons.badge_outlined,
                    label: '1. Dados e endereço',
                  ),
                  _WelcomeJourneyPill(
                    icon: Icons.face_retouching_natural_rounded,
                    label: '2. Rosto e documento',
                  ),
                  _WelcomeJourneyPill(
                    icon: Icons.verified_user_outlined,
                    label: '3. Selo de segurança',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s16),

        // 2. Cartão Porcelain "Seus dados pessoais" com contador vivo
        KycPorcelainSectionCard(
          key: const ValueKey('step0-personal-data-card'),
          title: 'Seus dados pessoais',
          subtitle: 'Preencha exatamente como consta no seu documento oficial.',
          icon: Icons.person_outline_rounded,
          statusChipLabel: progressChipLabel,
          statusTone: progressTone,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Como podemos te chamar?',
                style: AppType.bodyStrong.copyWith(color: tk.text),
              ),
              const SizedBox(height: AppSpace.s8),
              AppTextField(
                key: const ValueKey('client-setup-name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                hint: 'Nome e sobrenome completos',
                semanticLabel: 'Como podemos te chamar?',
                prefixIcon: Icons.person_outline,
                success: nameValid,
              ),
              const SizedBox(height: AppSpace.s12),
              AppTextField(
                key: const ValueKey('client-setup-phone'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: const [BrPhoneInputFormatter()],
                label: 'Telefone com DDD',
                hint: '(35) 99999-9999',
                prefixIcon: Icons.phone_outlined,
                helper:
                    'Obrigatório para avisos de chegada e segurança do pedido.',
                success: phoneValid,
              ),
              const SizedBox(height: AppSpace.s12),
              AppTextField(
                key: const ValueKey('client-setup-cpf'),
                controller: _cpf,
                keyboardType: TextInputType.number,
                inputFormatters: const [CpfInputFormatter()],
                label: 'CPF do Titular',
                hint: 'Digite seu CPF',
                prefixIcon: Icons.badge_outlined,
                success: cpfCompleteValid,
                errorText: cpfDigits.length == 11 && !cpfValid
                    ? 'Dígito verificador do CPF inválido'
                    : null,
                helper: cpfCompleteValid
                    ? 'CPF válido e verificado com sucesso'
                    : 'Utilizado para cruzar com seu documento oficial e proteger seu PIX.',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s16),

        // 3. Cartão Refinado de Confiança e Termos
        AppCard(
          key: const ValueKey('card-initial-role-terms'),
          variant: AppCardVariant.outlined,
          padding: const EdgeInsets.all(AppSpace.card),
          borderColor:
              _termsAccepted ? tk.success.withValues(alpha: 0.65) : tk.border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeSemantics(
                        child: Container(
                          width: AppGeometry.iconTileSize,
                          height: AppGeometry.iconTileSize,
                          decoration: BoxDecoration(
                            color: _termsAccepted
                                ? tk.successSoft
                                : tk.accentSoft,
                            borderRadius: BorderRadius.circular(
                              AppGeometry.iconTileRadius,
                            ),
                          ),
                          child: Icon(
                            Icons.verified_user_outlined,
                            size: 20,
                            color: _termsAccepted
                                ? tk.successInk
                                : tk.accentInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s12),
                      Flexible(
                        child: Text(
                          'Confiança e Termos',
                          style: AppType.titleSm.copyWith(color: tk.text),
                        ),
                      ),
                    ],
                  ),
                  const AppStatusChip(
                    'Validade 6 meses',
                    tone: AppTone.info,
                    icon: Icons.event_repeat_rounded,
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    key: const ValueKey('checkbox-accept-initial-terms'),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    value: _termsAccepted,
                    onChanged: (v) {
                      final next = v ?? false;
                      if (next) {
                        ScaffoldMessenger.maybeOf(
                          context,
                        )?.hideCurrentSnackBar();
                      }
                      setState(() {
                        _termsAccepted = next;
                        if (next) _error = null;
                      });
                    },
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final next = !_termsAccepted;
                        if (next) {
                          ScaffoldMessenger.maybeOf(
                            context,
                          )?.hideCurrentSnackBar();
                        }
                        setState(() {
                          _termsAccepted = next;
                          if (next) _error = null;
                        });
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: AppGeometry.minTarget,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpace.s8,
                            ),
                            child: Text(
                              'Aceito os $termsTitle e a validação semestral de segurança (a cada 6 meses).',
                              style: AppType.bodySm.copyWith(
                                fontWeight: FontWeight.w600,
                                color: tk.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s4),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  key: const ValueKey('btn-read-full-terms'),
                  variant: AppButtonVariant.tertiary,
                  expand: false,
                  compact: true,
                  icon: Icons.description_outlined,
                  label: 'Ler termos completos',
                  onPressed: _openFullRoleTermsModal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ETAPA 2: Endereço Residencial (Cliente) ou Localização Base (Profissional)
  // ---------------------------------------------------------------------------
  Widget _buildStep1Address(AppTokens tk) {
    final isProviderTarget = widget.targetMode == UserMode.provider;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KycStepHeroHeader(
          icon: Icons.location_on_rounded,
          title: isProviderTarget
              ? 'Qual é sua localização base de atendimento?'
              : 'Onde você precisa do serviço?',
          subtitle: isProviderTarget
              ? 'Usamos sua cidade e endereço base para conectar você aos chamados próximos na sua região com total segurança.'
              : 'O endereço completo só é compartilhado com o profissional contratado.',
          trustBadgeText: isProviderTarget
              ? 'Sua localização exata nunca fica pública no mapa'
              : 'Endereço oculto até você aprovar o orçamento',
          trustBadgeIcon: Icons.lock_outline_rounded,
        ),
        const SizedBox(height: AppSpace.s40),
        AddressForm(
          initial: _address.isEmpty ? null : _address,
          onChanged: (a) {
            final changed =
                a.toJson().toString() != _address.toJson().toString();
            _address = a;
            if (changed) _scheduleSave();
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ETAPA 3: PREPARAÇÃO PARA PROVA DE VIDA FACIAL (ANTES DE ABRIR A CÂMERA)
  // ---------------------------------------------------------------------------
  Widget _buildStep2ActiveLiveness(AppTokens tk) {
    final bool done = _livenessResult != null && _livenessResult!.passed;

    if (done) {
      return _buildStep2LivenessApproved(tk);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KycStepHeroHeader(
          icon: Icons.face_retouching_natural_rounded,
          title: 'Prova de Vida Facial',
          subtitle:
              'Antes de abrir a câmera, confira as orientações abaixo para confirmar sua identidade com tranquilidade em poucos segundos.',
          trustBadgeText: 'Protegido pela LGPD · Válido por 6 meses',
          trustBadgeIcon: Icons.verified_user_outlined,
        ),
        const SizedBox(height: AppSpace.s20),
        KeyedSubtree(
          key: const ValueKey('liveness-prep-card'),
          child: KycPorcelainSectionCard(
            title: 'Prepare-se para a câmera ao vivo',
            subtitle:
                'A câmera só será aberta quando você tocar no botão abaixo.',
            statusChipLabel: '3 passos simples',
            statusTone: AppTone.accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: KycFaceIdIllustration(size: 108)),
                const SizedBox(height: AppSpace.s20),
                const _LivenessPrepTipRow(
                  icon: Icons.wb_sunny_outlined,
                  title: 'Iluminação de frente para o rosto',
                  description:
                      'Escolha um local bem iluminado e evite ficar contra a luz de janelas ou lâmpadas.',
                ),
                const SizedBox(height: AppSpace.s12),
                const _LivenessPrepTipRow(
                  icon: Icons.visibility_outlined,
                  title: 'Sem óculos escuros ou acessórios',
                  description:
                      'Mantenha o rosto descoberto e certifique-se de que apenas você apareça na câmera.',
                ),
                const SizedBox(height: AppSpace.s12),
                const _LivenessPrepTipRow(
                  icon: Icons.motion_photos_on_outlined,
                  title: '3 movimentos simples ao vivo',
                  description:
                      'Enquadre o rosto na moldura, pisque os olhos e faça um leve movimento com a cabeça.',
                ),
                const SizedBox(height: AppSpace.s20),
                AppButton(
                  key: const ValueKey('btn-start-liveness'),
                  loading: _livenessRunning,
                  icon: Icons.videocam_rounded,
                  label: 'Iniciar Prova de Vida',
                  onPressed: _livenessRunning
                      ? null
                      : _startInteractiveLivenessChallenge,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2LivenessApproved(AppTokens tk) {
    final bool reduced = AppMotion.reduced(context);
    final double score = _livenessResult!.livenessScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KycStepHeroHeader(
          icon: Icons.verified_user_rounded,
          title: 'Prova de Vida Facial',
          subtitle:
              'Sua verificação facial ao vivo foi concluída. Continue para fotografar seu documento oficial.',
          trustBadgeText: 'Protegido pela LGPD · Válido por 6 meses',
          trustBadgeIcon: Icons.verified_rounded,
        ),
        const SizedBox(height: AppSpace.s20),
        AppCard(
          key: const ValueKey('liveness-approved-card'),
          variant: AppCardVariant.elevated,
          radius: AppGeometry.heroRadius,
          borderColor: tk.success,
          padding: const EdgeInsets.all(AppSpace.cardLarge),
          child: Column(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: tk.success, width: 3),
                        color: tk.successSoft,
                      ),
                      child: ClipOval(
                        child: _selfieBytes != null && _selfieBytes!.isNotEmpty
                            ? Image.memory(
                                _selfieBytes!,
                                fit: BoxFit.cover,
                              )
                            : Icon(
                                Icons.face_rounded,
                                size: 44,
                                color: tk.successInk,
                              ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _LivenessApprovedBadge(reduced: reduced),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s16),
              Text(
                'Prova de Vida Homologada!',
                textAlign: TextAlign.center,
                style: AppType.title.copyWith(color: tk.text),
              ),
              const SizedBox(height: AppSpace.s8),
              AppStatusChip(
                'Identidade confirmada (${score.toStringAsFixed(1)}%)',
                tone: AppTone.success,
                icon: Icons.verified_rounded,
              ),
              const SizedBox(height: AppSpace.s12),
              Text(
                'Seu rosto foi validado ao vivo com segurança. Agora toque em continuar para enviar as fotos do documento.',
                textAlign: TextAlign.center,
                style: AppType.bodySm.copyWith(color: tk.textMuted),
              ),
              const SizedBox(height: AppSpace.s20),
              AppButton(
                key: const ValueKey('btn-start-liveness'),
                variant: AppButtonVariant.secondary,
                loading: _livenessRunning,
                icon: Icons.refresh_rounded,
                label: 'Refazer Prova de Vida',
                onPressed: _livenessRunning
                    ? null
                    : _startInteractiveLivenessChallenge,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ETAPA 4: VALIDAÇÃO OFICIAL DO DOCUMENTO (SOMENTE CAPTURA FRENTE E VERSO)
  // ---------------------------------------------------------------------------
  Widget _buildStep3DocumentCapture(AppTokens tk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KycStepHeroHeader(
          icon: Icons.badge_outlined,
          title: 'Validação Oficial do Documento',
          subtitle: 'Fotografe a frente e o verso com boa iluminação.',
          trustBadgeText: 'Leitura automática segura',
          trustBadgeIcon: Icons.shield_outlined,
        ),
        const SizedBox(height: AppSpace.s12),
        KycPorcelainSectionCard(
          key: const ValueKey('doc-type-selector-card'),
          title: 'Qual documento você vai usar?',
          child: Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s4,
            children: [
              for (final t in OfficialDocumentType.values)
                ChoiceChip(
                  key: ValueKey('doc-type-${t.code}'),
                  tooltip: t.label,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
                  labelPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s4,
                  ),
                  label: Text(t.code),
                  selected: _docType == t,
                  onSelected: (_) {
                    setState(() {
                      _docType = t;
                      _ocrResult = null;
                    });
                    if (_docFrontBytes != null && _docBackBytes != null) {
                      unawaited(_runForensicDocumentOcrValidation());
                    }
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool stackCards =
                constraints.maxWidth < 360 || context.layout.isLargeText;
            final frontCard = _DocumentCaptureCard(
              key: const ValueKey('capture-doc-front'),
              isFront: true,
              title: '1. Frente do documento',
              subtitle: 'Foto e nome (${_docType.code})',
              validatedBadgeLabel: 'Frente validada',
              imageBytes: _docFrontBytes,
              onTap: () => _captureDocumentSide(isFront: true),
            );
            final backCard = _DocumentCaptureCard(
              key: const ValueKey('capture-doc-back'),
              isFront: false,
              title: '2. Verso do documento',
              subtitle: 'CPF e código',
              validatedBadgeLabel: 'Verso validado',
              imageBytes: _docBackBytes,
              onTap: () => _captureDocumentSide(isFront: false),
            );

            if (stackCards) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  frontCard,
                  const SizedBox(height: AppSpace.s12),
                  backCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: frontCard),
                const SizedBox(width: AppSpace.s12),
                Expanded(child: backCard),
              ],
            );
          },
        ),
        if (_analyzingOcr) ...[
          const SizedBox(height: AppSpace.s16),
          const AppCard(
            variant: AppCardVariant.tonal,
            padding: EdgeInsets.all(AppSpace.s16),
            child: AppLoading(
              message: 'Lendo e conferindo os dados do seu documento...',
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ETAPA 5: CONFERÊNCIA DEDICADA DOS DADOS TRANSCRITOS DO DOCUMENTO (OCR)
  // ---------------------------------------------------------------------------
  Widget _buildStep4DocumentOcrReview(AppTokens tk) {
    final ocr = _ocrResult;
    if (ocr == null) {
      return _buildStep3DocumentCapture(tk);
    }
    return DocumentOcrReviewStep(
      ocrResult: ocr,
      typedName: _name.text.trim(),
      frontImageBytes: _docFrontBytes,
      backImageBytes: _docBackBytes,
      onRetakePhotos: () => _setStep(3),
    );
  }

  // ---------------------------------------------------------------------------
  // ETAPA 6: CERTIDÃO NEGATIVA DE ANTECEDENTES CRIMINAIS DA POLÍCIA FEDERAL
  // ---------------------------------------------------------------------------
  Widget _buildStep5CriminalBackground() {
    return CriminalBackgroundCheckStep(
      expectedFullName: _ocrResult?.extractedFullName.isNotEmpty == true
          ? _ocrResult!.extractedFullName
          : _name.text.trim(),
      expectedCpfRaw: _cpf.text.trim(),
      initialResult: _criminalResult,
      isSixMonthRenewal: widget.isSixMonthRenewal,
      onValidated: (res) {
        if (!mounted) return;
        setState(() {
          _criminalResult = res;
          _error = null;
        });
      },
    );
  }
}

class _WelcomeJourneyPill extends StatelessWidget {
  const _WelcomeJourneyPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tk.surfaceAt(1),
        borderRadius: BorderRadius.circular(AppGeometry.pillRadius),
        border: Border.all(color: tk.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12,
          vertical: AppSpace.s4 + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: tk.accentInk),
            const SizedBox(width: AppSpace.s4 + 2),
            Flexible(
              child: Text(
                label,
                style: AppType.bodySm.copyWith(
                  color: tk.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LivenessPrepTipRow extends StatelessWidget {
  const _LivenessPrepTipRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: AppGeometry.iconTileSize,
          height: AppGeometry.iconTileSize,
          decoration: BoxDecoration(
            color: tk.surface,
            borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
            border: Border.all(color: tk.border),
          ),
          child: Icon(icon, size: 20, color: tk.accentInk),
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppType.bodyStrong.copyWith(color: tk.text),
              ),
              const SizedBox(height: AppSpace.s2),
              Text(
                description,
                style: AppType.bodySm.copyWith(color: tk.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LivenessApprovedBadge extends StatelessWidget {
  const _LivenessApprovedBadge({required this.reduced});

  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final staticBadge = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tk.success,
        border: Border.all(color: tk.surface, width: 2.5),
      ),
      child: Icon(
        Icons.check_rounded,
        size: 20,
        color: AppTokens.onColor(tk.success),
      ),
    );
    if (reduced) {
      return Semantics(
        label: 'Verificação facial aprovada',
        child: staticBadge,
      );
    }
    return Semantics(
      label: 'Verificação facial aprovada',
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tk.surface,
          border: Border.all(color: tk.success, width: 1.5),
        ),
        child: Lottie.asset(
          'assets/lottie/check_burst.json',
          width: 40,
          height: 40,
          repeat: false,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Center(child: staticBadge),
        ),
      ),
    );
  }
}

class _DocumentCaptureCard extends StatelessWidget {
  const _DocumentCaptureCard({
    super.key,
    required this.isFront,
    required this.title,
    required this.subtitle,
    required this.validatedBadgeLabel,
    required this.imageBytes,
    required this.onTap,
  });

  final bool isFront;
  final String title;
  final String subtitle;
  final String validatedBadgeLabel;
  final Uint8List? imageBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final bool hasPhoto = imageBytes != null && imageBytes!.isNotEmpty;

    return AppCard(
      onTap: onTap,
      variant: hasPhoto ? AppCardVariant.tonal : AppCardVariant.elevated,
      color: hasPhoto ? tk.successSoft : null,
      borderColor: hasPhoto ? tk.success : tk.border,
      radius: AppGeometry.cardRadius,
      padding: const EdgeInsets.all(AppSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasPhoto)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
              child: AspectRatio(
                aspectRatio: 1.586,
                child: Image.memory(
                  imageBytes!,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s8,
                vertical: AppSpace.s8,
              ),
              decoration: BoxDecoration(
                color: tk.surfaceInset,
                borderRadius: BorderRadius.circular(AppGeometry.fieldRadius),
                border: Border.all(color: tk.border),
              ),
              child: Center(
                child: KycDocumentCardWireframe(
                  isFront: isFront,
                  height: 68,
                ),
              ),
            ),
          const SizedBox(height: AppSpace.s8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppType.bodyStrong.copyWith(color: tk.text),
          ),
          const SizedBox(height: AppSpace.s4),
          if (hasPhoto) ...[
            Center(
              child: AppStatusChip(
                validatedBadgeLabel,
                tone: AppTone.success,
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
            const SizedBox(height: AppSpace.s8),
            Text(
              'Toque para refazer',
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(
                color: tk.successInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppType.bodySm.copyWith(color: tk.textMuted),
            ),
            const SizedBox(height: AppSpace.s8),
            const Center(
              child: AppStatusChip(
                'Abrir câmera',
                tone: AppTone.accent,
                icon: Icons.camera_alt_outlined,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

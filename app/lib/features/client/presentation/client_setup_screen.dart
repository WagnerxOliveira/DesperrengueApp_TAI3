import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/security/kyc_session_anti_swap_guard.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/document_ocr_and_liveness_service.dart';
import '../../../core/services/draft_store.dart';
import '../../../core/services/live_camera_frame_bridge.dart';
import '../../../core/services/precise_geocoder.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/kyc_human_feedback_translator.dart';
import '../../../core/ui/widgets.dart';
import 'address_form.dart';

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
      final hit = await PreciseGeocoder().geocode(a.fullLine, summary: a.summary, cep: a.cep);
      if (hit != null) {
        lat = hit.lat;
        lng = hit.lng;
      }
    } catch (_) {}
  }
  final line = a.reference.isEmpty ? a.fullLine : '${a.fullLine} | Ref: ${a.reference}';
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
      showSnack(context, 'Preencha rua, número, bairro e cidade.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await saveProfileAddress(_address);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('Editar localização')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.currentLine != null && widget.currentLine!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InfoBanner(widget.currentLine!, title: 'Endereço atual', icon: Icons.place_outlined),
              ),
            AddressForm(onChanged: (a) => _address = a),
          ],
        ),
      ),
      bottomNavigationBar: BottomBar(
        child: PrimaryButton(label: 'Salvar endereço', onPressed: _save, loading: _saving),
      ),
    );
  }
}

/// Onboarding de 4 Passos do CLIENTE com Validação Biométrica Facial Real Ao Vivo (Active Liveness
/// na Câmera Frontal embutida no Oval), Scanner Guiado ISO ID-1 na Câmera Traseira com Recorte ROI,
/// Face Match Multi-Ângulo (0°, 90°, 180°, 270°) e Transcrição Automática Visível via OCR:
///
///  * **Passo 1 (`_step == 0`)**: "Como podemos te chamar?", "Telefone com DDD" (obrigatório)
///    e "CPF do Titular" (validação matemática Mod-11 em tempo real).
///  * **Passo 2 (`_step == 1`)**: "Onde você precisa do serviço?" (`AddressForm` com GPS/CEP e mapa).
///  * **Passo 3 (`_step == 2`)**: Registro Facial de Segurança ao vivo dentro do `ClipOval`
///    usando a câmera frontal (`CameraLensDirection.front` / `facingMode: 'user'`), validando
///    presença real de rosto humano ($YCbCr$ + filtro anti-monitor) e desafios biomecânicos reais
///    (centralizar rosto, piscar os dois olhos, virar a cabeça e retornar ao centro para captura automática).
///  * **Passo 4 (`_step == 3`)**: Scanner Guiado de Documento (`DocumentGuidedScannerModal`) com
///    moldura retangular vazada ISO/IEC 7810 ID-1 (`Horizontal` ou `Vertical`), recorte estrito de ROI,
///    distinção `dHash` + `MAD` sem falso positivo de mesa, Face Match 1:1 invariante à rotação e
///    exibição imediata do card **"Dados Transcritos Automaticamente do Documento (OCR)"**.
class ClientSetupScreen extends StatefulWidget {
  const ClientSetupScreen({
    super.key,
    required this.profile,
    this.initialStep = 0,
    @visibleForTesting this.customSubmitter,
    @visibleForTesting this.customCameraCapture,
    @visibleForTesting this.rawOcrFrontTextOverride,
    @visibleForTesting this.rawOcrBackTextOverride,
  });

  final UserProfile profile;
  final int initialStep;
  final ClientKycSubmitter? customSubmitter;
  final Future<Uint8List> Function({required String slot})? customCameraCapture;
  final String? rawOcrFrontTextOverride;
  final String? rawOcrBackTextOverride;

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
  late final String _draftKey = DraftStore.keyFor('client_setup', userId: widget.profile.id);

  AddressData _address = const AddressData();
  AddressData? _draftAddress;
  late int _step = widget.initialStep.clamp(0, 3);
  bool _saving = false;
  bool _restoring = true;
  bool _restored = false;
  String? _error;
  Timer? _saveTimer;

  // Estado do Passo 3: Biometria Facial Ao Vivo na Câmera Frontal Embutida no Oval
  ActiveLivenessStep _livenessStep = ActiveLivenessStep.centerFaceInOval;
  bool _livenessRunning = false;
  Uint8List? _selfieBytes;
  ActiveLivenessResult? _livenessResult;
  LiveOvalFrameAnalysis? _latestOvalAnalysis;
  String _liveDiagnosticMessage =
      'Toque em "Iniciar Câmera Frontal no Oval" e posicione seu rosto dentro da moldura.';

  CameraController? _frontCameraController;
  List<CameraDescription> _availableCameras = const <CameraDescription>[];
  int _selectedFrontCameraIndex = 0;
  bool _cameraInitializing = false;
  bool _processingFrame = false;
  CameraImage? _latestStreamImage;
  Timer? _frameSamplingTimer;

  // Acumuladores biomecânicos reais para os 3 desafios da Prova de Vida
  int _consecutiveCenteredFaceFrames = 0;
  int _blinkPhaseFrames = 0;
  double? _baselineEyeRatio;
  double _minEyeRatioInBlink = 1.0;
  double _maxEyeRatioInBlink = 0.0;
  double? _baselineCentroidX;
  double? _previousCentroidX;
  bool _headTurnObserved = false;

  // Estado do Passo 4: Documento Oficial (Frente + Verso) + OCR Automático Visível
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
    _stopFrontOvalCamera();
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
      if (widget.initialStep == 0) {
        _step = ((d['step'] as num?)?.toInt() ?? 0).clamp(0, 3);
      }
      _restored = name.trim().isNotEmpty ||
          _phone.text.isNotEmpty ||
          _cpf.text.isNotEmpty ||
          _draftAddress != null;
    }
    setState(() => _restoring = false);
    if (_restored && mounted) {
      showSnack(context, 'Recuperamos o que você já tinha preenchido.');
    }
    if (_step == 2 && widget.customCameraCapture == null) {
      unawaited(_startInteractiveLivenessChallenge());
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
      });

  void _setStep(int s) {
    final target = s.clamp(0, 3);
    if (target != 2) {
      _stopFrontOvalCamera();
    }
    setState(() {
      _error = null;
      _step = target;
    });
    _scheduleSave();
    if (target == 2 &&
        (_livenessResult == null || !_livenessResult!.passed) &&
        widget.customCameraCapture == null) {
      unawaited(_startInteractiveLivenessChallenge());
    }
  }

  void _validateStep0AndAdvance() {
    if (!DocumentOcrAndLivenessService.isValidCivilFullName(_name.text)) {
      setState(() => _error = 'Informe seu nome e sobrenome completos conforme o documento.');
      showSnack(context, 'Informe seu nome e sobrenome completos.', error: true);
      return;
    }
    if (!DocumentOcrAndLivenessService.isValidPhoneBr(_phone.text)) {
      setState(() => _error = 'Informe seu telefone celular válido com DDD.');
      showSnack(context, 'Informe seu telefone válido com DDD.', error: true);
      return;
    }
    if (!DocumentOcrAndLivenessService.isValidCpfMod11(_cpf.text)) {
      setState(() => _error = 'CPF inválido. Verifique os 11 dígitos informados.');
      showSnack(context, 'CPF inválido. Verifique os 11 dígitos.', error: true);
      return;
    }
    _setStep(1);
  }

  void _validateStep1AndAdvance() {
    if (!_address.isValid) {
      setState(() => _error = 'Preencha rua, número, bairro e cidade.');
      showSnack(context, 'Preencha rua, número, bairro e cidade.', error: true);
      return;
    }
    _setStep(2);
  }

  // ===========================================================================
  // PASSO 3: CÂMERA FRONTAL AO VIVO DENTRO DO OVAL + PROVA DE VIDA REAL
  // ===========================================================================
  void _stopFrontOvalCamera() {
    _frameSamplingTimer?.cancel();
    _frameSamplingTimer = null;
    _latestStreamImage = null;
    final ctrl = _frontCameraController;
    _frontCameraController = null;
    if (ctrl != null) {
      unawaited(() async {
        try {
          if (!kIsWeb && ctrl.value.isStreamingImages) {
            await ctrl.stopImageStream();
          }
        } catch (_) {}
        try {
          await ctrl.dispose();
        } catch (_) {}
      }());
    }
  }

  void _resetBiomechanicalChallengeState() {
    _consecutiveCenteredFaceFrames = 0;
    _blinkPhaseFrames = 0;
    _baselineEyeRatio = null;
    _minEyeRatioInBlink = 1.0;
    _maxEyeRatioInBlink = 0.0;
    _baselineCentroidX = null;
    _previousCentroidX = null;
    _headTurnObserved = false;
  }

  Future<void> _startInteractiveLivenessChallenge({bool switchCameraLens = false}) async {
    if (_cameraInitializing) return;

    // Caminho determinístico exclusivamente para testes automatizados de widget (sem hardware):
    if (widget.customCameraCapture != null) {
      setState(() {
        _livenessRunning = true;
        _error = null;
        _selfieBytes = null;
        _livenessResult = null;
        _livenessStep = ActiveLivenessStep.centerFaceInOval;
      });
      try {
        final capturedBytes = await widget.customCameraCapture!(slot: 'selfie');
        final frameCheck = DocumentOcrAndLivenessService.evaluateLiveOvalFrameInput(
          imageBytes: capturedBytes,
        );
        if (!frameCheck.hasRealHumanFace) {
          throw StateError('ERR_NO_HUMAN_FACE_IN_OVAL: ${frameCheck.diagnosticMessage}');
        }
        final result = DocumentOcrAndLivenessService.verifyActiveLivenessSync(
          selfieBytes: capturedBytes,
          cpfDigits: _cpf.text,
        );
        final activeTicket = KycSessionAntiSwapGuard.renewIfExpired(
          _sessionTicket ??
              KycSessionAntiSwapGuard.issueSession(
                userId: widget.profile.id.isEmpty
                    ? 'client_kyc_user'
                    : widget.profile.id,
              ),
        );
        final frozenTicket = KycSessionAntiSwapGuard.freezeCanonicalSelfie(
          ticket: activeTicket,
          selfieBytes: capturedBytes,
          origin: CaptureOrigin.liveCameraOnly,
        );
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        setState(() {
          _sessionTicket = frozenTicket;
          _selfieBytes = capturedBytes;
          _livenessResult = result;
          _latestOvalAnalysis = frameCheck;
          _livenessStep = ActiveLivenessStep.completed;
          _liveDiagnosticMessage =
              KycHumanFeedbackTranslator.sanitizeForHumanDisplay(
            frameCheck.diagnosticMessage,
          );
          _livenessRunning = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = KycHumanFeedbackTranslator.translateError(e);
          _livenessStep = ActiveLivenessStep.centerFaceInOval;
          _livenessRunning = false;
        });
      }
      return;
    }

    _stopFrontOvalCamera();
    _resetBiomechanicalChallengeState();

    setState(() {
      _cameraInitializing = true;
      _livenessRunning = true;
      _error = null;
      _selfieBytes = null;
      _livenessResult = null;
      _latestOvalAnalysis = null;
      _livenessStep = ActiveLivenessStep.centerFaceInOval;
      _liveDiagnosticMessage = 'Inicializando câmera frontal ao vivo dentro da moldura oval...';
    });

    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        throw StateError(
          'Nenhuma câmera detectada no dispositivo. Verifique as permissões de câmera do navegador/sistema.',
        );
      }
      _availableCameras = cams;

      if (switchCameraLens && cams.length > 1) {
        _selectedFrontCameraIndex = (_selectedFrontCameraIndex + 1) % cams.length;
      } else {
        // Prioriza estritamente a câmera FRONTAL (selfie)
        final frontIdx = cams.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        if (frontIdx >= 0) {
          _selectedFrontCameraIndex = frontIdx;
        } else {
          final nameFrontIdx = cams.indexWhere(
            (c) =>
                c.name.toLowerCase().contains('front') ||
                c.name.toLowerCase().contains('user') ||
                c.name.toLowerCase().contains('selfie'),
          );
          _selectedFrontCameraIndex = nameFrontIdx >= 0 ? nameFrontIdx : 0;
        }
      }

      final chosenCamera = cams[_selectedFrontCameraIndex];
      final controller = CameraController(
        chosenCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      if (kIsWeb) {
        // Força facingMode: 'user' na tag <video> WebRTC do navegador mobile
        final wantFront = chosenCamera.lensDirection != CameraLensDirection.back ||
            cams.length == 1;
        await ensureWebVideoFacingMode(frontCamera: wantFront);
      } else {
        try {
          await controller.startImageStream((CameraImage image) {
            _latestStreamImage = image;
          });
        } catch (_) {}
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _frontCameraController = controller;
        _cameraInitializing = false;
        _liveDiagnosticMessage =
            'Posicione seu rosto real dentro da moldura oval para iniciar a leitura.';
      });

      // Inicia o loop real de visão computacional (140ms por quadro)
      _frameSamplingTimer = Timer.periodic(
        const Duration(milliseconds: 140),
        (_) => _evaluateNextLiveOvalFrame(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraInitializing = false;
        _livenessRunning = false;
        _error =
            'Não foi possível acessar a câmera frontal ao vivo. Conceda permissão à câmera e tente novamente.';
        _liveDiagnosticMessage = 'Permissão de câmera necessária para a Prova de Vida.';
      });
    }
  }

  Future<void> _evaluateNextLiveOvalFrame() async {
    if (!mounted ||
        !_livenessRunning ||
        _processingFrame ||
        _frontCameraController == null ||
        !_frontCameraController!.value.isInitialized) {
      return;
    }
    _processingFrame = true;
    try {
      LiveOvalFrameAnalysis? analysis;
      if (kIsWeb) {
        final pngBytes = await grabWebVideoFramePngBytes(
          maxWidth: 240,
          maxHeight: 240,
          mirrorHorizontal: true,
        );
        if (pngBytes == null || pngBytes.isEmpty) return;
        analysis = DocumentOcrAndLivenessService.evaluateLiveOvalFrameInput(
          imageBytes: pngBytes,
          previousCentroidX: _previousCentroidX,
          baselineEyeRatio: _baselineEyeRatio,
        );
      } else {
        final streamImg = _latestStreamImage;
        if (streamImg != null) {
          final desc = _frontCameraController!.description;
          final rgbImg = convertCameraImageToUprightRgbNamed(
            image: streamImg,
            sensorOrientation: desc.sensorOrientation,
            isFrontCamera: desc.lensDirection == CameraLensDirection.front,
            targetMaxDimension: 240,
          );
          if (rgbImg != null) {
            analysis = DocumentOcrAndLivenessService.evaluateLiveOvalFrameInput(
              decodedImage: rgbImg,
              previousCentroidX: _previousCentroidX,
              baselineEyeRatio: _baselineEyeRatio,
            );
          }
        }
      }

      if (analysis == null || !mounted) return;
      _previousCentroidX = analysis.faceCentroidX;

      // GATE CONTÍNUO DE PRESENÇA HUMANA REAL:
      // Se não há rosto humano real (ex.: monitor com VS Code, mesa ou parede),
      // NÃO avança nenhuma etapa e exibe o alerta em tempo real.
      if (!analysis.hasRealHumanFace) {
        _consecutiveCenteredFaceFrames = math.max(0, _consecutiveCenteredFaceFrames - 1);
        setState(() {
          _latestOvalAnalysis = analysis;
          _liveDiagnosticMessage = analysis!.diagnosticMessage;
        });
        return;
      }

      // Máquina de estados guiada exclusivamente pelos movimentos físicos reais no vídeo:
      switch (_livenessStep) {
        case ActiveLivenessStep.centerFaceInOval:
          if (analysis.isFaceCentered && analysis.laplacianSharpness >= 36.0) {
            _consecutiveCenteredFaceFrames++;
            if (_consecutiveCenteredFaceFrames >= 5) {
              _baselineEyeRatio = analysis.estimatedEar;
              _baselineCentroidX = analysis.faceCentroidX;
              _minEyeRatioInBlink = analysis.estimatedEar;
              _maxEyeRatioInBlink = analysis.estimatedEar;
              HapticFeedback.lightImpact();
              setState(() {
                _latestOvalAnalysis = analysis;
                _livenessStep = ActiveLivenessStep.blinkBothEyesSlowly;
                _liveDiagnosticMessage =
                    'Rosto centralizado! Agora pisque os dois olhos lentamente.';
              });
              return;
            }
          } else {
            _consecutiveCenteredFaceFrames = math.max(0, _consecutiveCenteredFaceFrames - 1);
          }
          setState(() {
            _latestOvalAnalysis = analysis;
            _liveDiagnosticMessage = analysis!.isFaceCentered
                ? 'Mantenha o rosto firme no centro (${(_consecutiveCenteredFaceFrames * 20).clamp(0, 100)}%)...'
                : 'Centralize seu rosto no meio da moldura oval.';
          });
          break;

        case ActiveLivenessStep.blinkBothEyesSlowly:
          _blinkPhaseFrames++;
          _minEyeRatioInBlink = math.min(_minEyeRatioInBlink, analysis.estimatedEar);
          _maxEyeRatioInBlink = math.max(_maxEyeRatioInBlink, analysis.estimatedEar);
          final earRange = _maxEyeRatioInBlink - _minEyeRatioInBlink;
          final blinked = analysis.blinkDetected ||
              (earRange >= 0.013 && _blinkPhaseFrames >= 4) ||
              (_blinkPhaseFrames >= 10 && analysis.isFaceCentered && earRange >= 0.006);

          if (blinked) {
            HapticFeedback.mediumImpact();
            _baselineCentroidX = analysis.faceCentroidX;
            setState(() {
              _latestOvalAnalysis = analysis;
              _livenessStep = ActiveLivenessStep.turnHeadRight;
              _liveDiagnosticMessage =
                  'Piscada validada! Agora vire levemente o rosto para o lado e volte ao centro.';
            });
            return;
          }
          setState(() {
            _latestOvalAnalysis = analysis;
            _liveDiagnosticMessage =
                'Pisque os dois olhos lentamente olhando para a câmera frontal.';
          });
          break;

        case ActiveLivenessStep.turnHeadRight:
          final refX = _baselineCentroidX ?? 0.5;
          final lateralShift = (analysis.faceCentroidX - refX).abs();
          final turned = analysis.headTurnDetected ||
              lateralShift >= 0.055 ||
              analysis.estimatedYawDegrees.abs() >= 13.0;
          if (turned) {
            _headTurnObserved = true;
            HapticFeedback.lightImpact();
            setState(() {
              _latestOvalAnalysis = analysis;
              _livenessStep = ActiveLivenessStep.returnHeadToCenterAndCapture;
              _liveDiagnosticMessage =
                  'Rotação 3D detectada! Olhe novamente para o centro para capturar a selfie.';
            });
            return;
          }
          setState(() {
            _latestOvalAnalysis = analysis;
            _liveDiagnosticMessage =
                'Vire levemente o rosto para a direita (ou esquerda) para validar a profundidade 3D.';
          });
          break;

        case ActiveLivenessStep.returnHeadToCenterAndCapture:
          if (_headTurnObserved && analysis.isFaceCentered) {
            await _captureHighResSelfieFromLiveOval(analysis);
          } else {
            setState(() {
              _latestOvalAnalysis = analysis;
              _liveDiagnosticMessage =
                  'Alinhe o rosto de volta ao centro do oval para captura automática...';
            });
          }
          break;

        case ActiveLivenessStep.completed:
          break;
      }
    } finally {
      _processingFrame = false;
    }
  }

  Future<void> _captureHighResSelfieFromLiveOval(LiveOvalFrameAnalysis lastAnalysis) async {
    _frameSamplingTimer?.cancel();
    _frameSamplingTimer = null;

    setState(() {
      _liveDiagnosticMessage = 'Capturando selfie biométrica de alta nitidez...';
    });

    try {
      Uint8List? capturedBytes;
      final ctrl = _frontCameraController;

      if (kIsWeb) {
        capturedBytes = await grabWebVideoFramePngBytes(
          maxWidth: 640,
          maxHeight: 640,
          mirrorHorizontal: true,
        );
      }

      if ((capturedBytes == null || capturedBytes.isEmpty) && ctrl != null) {
        if (!kIsWeb && ctrl.value.isStreamingImages) {
          try {
            await ctrl.stopImageStream();
          } catch (_) {}
        }
        final xfile = await ctrl.takePicture();
        capturedBytes = await xfile.readAsBytes();
      }

      if (capturedBytes == null || capturedBytes.isEmpty) {
        throw StateError('Falha ao capturar quadro da câmera frontal.');
      }

      final result = await DocumentOcrAndLivenessService.verifyActiveLivenessInIsolate(
        selfieBytes: capturedBytes,
        cpfDigits: _cpf.text,
      );
      final activeTicket = KycSessionAntiSwapGuard.renewIfExpired(
        _sessionTicket ??
            KycSessionAntiSwapGuard.issueSession(
              userId: widget.profile.id.isEmpty
                  ? 'client_kyc_user'
                  : widget.profile.id,
            ),
      );
      final frozenTicket = KycSessionAntiSwapGuard.freezeCanonicalSelfie(
        ticket: activeTicket,
        selfieBytes: capturedBytes,
        origin: CaptureOrigin.liveCameraOnly,
        detectedCameraLabels:
            _availableCameras.map((c) => c.name).toList(growable: false),
      );

      _stopFrontOvalCamera();
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _sessionTicket = frozenTicket;
        _selfieBytes = capturedBytes;
        _livenessResult = result;
        _latestOvalAnalysis = lastAnalysis;
        _livenessStep = ActiveLivenessStep.completed;
        _livenessRunning = false;
        _liveDiagnosticMessage =
            'Prova de Vida Homologada! Rosto humano real autenticado com sucesso.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = KycHumanFeedbackTranslator.translateError(e);
        _livenessRunning = false;
        _livenessStep = ActiveLivenessStep.centerFaceInOval;
      });
      _stopFrontOvalCamera();
    }
  }

  // ===========================================================================
  // PASSO 4: SCANNER GUIADO DE DOCUMENTO (ISO ID-1) + OCR AUTOMÁTICO VISÍVEL
  // ===========================================================================
  Future<void> _captureDocumentSide({required bool isFront}) async {
    setState(() => _error = null);
    try {
      Uint8List? bytes;
      if (widget.customCameraCapture != null) {
        bytes = await widget.customCameraCapture!(slot: isFront ? 'front' : 'back');
      } else {
        bytes = await Navigator.of(context).push<Uint8List>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => DocumentGuidedScannerModal(
              isFront: isFront,
              documentType: _docType,
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
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _runForensicDocumentOcrValidation() async {
    if (_docFrontBytes == null || _docBackBytes == null) {
      setState(() => _error = 'Envie as fotos da FRENTE e do VERSO do seu documento.');
      return;
    }
    setState(() {
      _analyzingOcr = true;
      _error = null;
    });

    try {
      final result = widget.customCameraCapture != null
          ? DocumentOcrAndLivenessService.analyzeDocumentForensicsAndOcrSync(
              frontImageBytes: _docFrontBytes!,
              backImageBytes: _docBackBytes!,
              documentType: _docType,
              typedFullName: _name.text.trim(),
              typedCpfRaw: _cpf.text.trim(),
              livenessFaceEmbedding128: _livenessResult?.faceEmbedding128,
              rawOcrFrontTextOverride: widget.rawOcrFrontTextOverride,
              rawOcrBackTextOverride: widget.rawOcrBackTextOverride,
            )
          : await DocumentOcrAndLivenessService.analyzeDocumentForensicsAndOcrInIsolate(
              frontImageBytes: _docFrontBytes!,
              backImageBytes: _docBackBytes!,
              documentType: _docType,
              typedFullName: _name.text.trim(),
              typedCpfRaw: _cpf.text.trim(),
              livenessFaceEmbedding128: _livenessResult?.faceEmbedding128,
              rawOcrFrontTextOverride: widget.rawOcrFrontTextOverride,
              rawOcrBackTextOverride: widget.rawOcrBackTextOverride,
            );

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
          detectedCameraLabels:
              _availableCameras.map((c) => c.name).toList(growable: false),
        );
      }
      HapticFeedback.mediumImpact();
      setState(() {
        _ocrResult = result;
      });

      // Rola automaticamente para que o card de dados transcritos (OCR) e o botão de conclusão fiquem imediatamente visíveis
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _ocrResult = null;
          _error = KycHumanFeedbackTranslator.translateError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _analyzingOcr = false);
    }
  }

  Future<void> _finish() async {
    if (_livenessResult == null || !_livenessResult!.passed) {
      setState(() => _error = 'Conclua o registro facial (Prova de Vida) antes de continuar.');
      return;
    }
    if (_ocrResult == null || !_ocrResult!.isAuthenticAndCrossChecked) {
      setState(() => _error = 'Valide a frente e o verso do seu documento antes de concluir.');
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
        await service.submitClientKyc(
          cpfRaw: _cpf.text.trim(),
          typedFullName: _name.text.trim(),
          phone: _phone.text.trim(),
          addressLine: savedAddress.fullLine.isNotEmpty ? savedAddress.fullLine : fullLine,
          addressCity: savedAddress.cityUf.isNotEmpty ? savedAddress.cityUf : cityUf,
          latitude: savedAddress.latitude,
          longitude: savedAddress.longitude,
          livenessResult: _livenessResult!,
          ocrResult: _ocrResult!,
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
        final msg = friendlyError(e);
        setState(() => _error = msg);
        showSnack(context, msg, error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final cpfDigits = DocumentOcrAndLivenessService.digitsOnly(_cpf.text);
    final cpfValid = DocumentOcrAndLivenessService.isValidCpfMod11(cpfDigits);

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
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              if (_step > 0) {
                _setStep(_step - 1);
              } else {
                _saveDraft();
                AppSession.instance.switchMode();
              }
            },
          ),
          title: const BrandLogo(),
        ),
        body: _restoring
            ? const LoadingView()
            : SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StepperBar(total: 4, current: _step + 1),
                    const SizedBox(height: 18),
                    if (_step == 0) _buildStep0Identity(tk, cpfDigits, cpfValid),
                    if (_step == 1) _buildStep1Address(),
                    if (_step == 2) _buildStep2ActiveLiveness(tk),
                    if (_step == 3) _buildStep3DocumentForensicsAndOcr(tk),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      InfoBanner(_error!, tone: BannerTone.danger),
                    ],
                  ],
                ),
              ),
        bottomNavigationBar: BottomBar(
          child: switch (_step) {
            0 => PrimaryButton(
                key: const ValueKey('client-setup-step0-continue'),
                label: 'Continuar',
                trailingArrow: true,
                onPressed: _validateStep0AndAdvance,
              ),
            1 => PrimaryButton(
                key: const ValueKey('client-setup-step1-continue'),
                label: 'Continuar para Validação Facial e Documentos',
                trailingArrow: true,
                onPressed: _validateStep1AndAdvance,
              ),
            2 => PrimaryButton(
                key: const ValueKey('client-setup-step2-continue'),
                label: 'Continuar para Fotos do Documento',
                trailingArrow: true,
                onPressed: (_livenessResult != null && _livenessResult!.passed)
                    ? () => _setStep(3)
                    : null,
              ),
            _ => PrimaryButton(
                key: const ValueKey('client-setup-step3-submit'),
                label: 'Concluir Validação e Entrar no Aplicativo',
                loading: _saving,
                onPressed: (_ocrResult != null &&
                        _ocrResult!.isAuthenticAndCrossChecked &&
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
  // PASSO 1: "Como podemos te chamar?" + "Telefone com DDD" + "CPF do Titular"
  // ---------------------------------------------------------------------------
  Widget _buildStep0Identity(AppTokens tk, String cpfDigits, bool cpfValid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bem-vindo, ${widget.profile.firstName}!',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Vamos configurar sua conta de cliente com validação de identidade para proteger seus pedidos e sua garantia.',
          style: TextStyle(color: tk.textMuted, height: 1.4),
        ),
        const SizedBox(height: 24),
        TextField(
          key: const ValueKey('client-setup-name'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Como podemos te chamar?',
            hintText: 'Nome e sobrenome completos',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey('client-setup-phone'),
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: const [BrPhoneInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'Telefone com DDD',
            hintText: '(35) 99999-9999',
            prefixIcon: Icon(Icons.phone_outlined),
            helperText: 'Obrigatório para avisos de chegada e segurança do pedido.',
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey('client-setup-cpf'),
          controller: _cpf,
          keyboardType: TextInputType.number,
          inputFormatters: const [CpfInputFormatter()],
          decoration: InputDecoration(
            labelText: 'CPF do Titular',
            hintText: '000.000.000-00',
            prefixIcon: const Icon(Icons.badge_outlined),
            suffixIcon: cpfDigits.length == 11
                ? Icon(
                    cpfValid ? Icons.verified_rounded : Icons.error_outline_rounded,
                    color: cpfValid ? tk.success : tk.danger,
                  )
                : null,
            helperText: cpfDigits.length == 11
                ? (cpfValid
                    ? 'CPF válido e verificado com sucesso'
                    : 'Dígito verificador do CPF inválido')
                : 'Utilizado para cruzar com seu documento oficial e proteger seu PIX.',
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PASSO 2: "Onde você precisa do serviço?" (AddressForm mantido integralmente)
  // ---------------------------------------------------------------------------
  Widget _buildStep1Address() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Onde você precisa do serviço?',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'O endereço completo só é compartilhado com o profissional contratado.',
          style: TextStyle(color: context.tk.textMuted, height: 1.4),
        ),
        const SizedBox(height: 8),
        AddressForm(
          initial: _address.isEmpty ? null : _address,
          onChanged: (a) {
            final changed = a.toJson().toString() != _address.toJson().toString();
            _address = a;
            if (changed) _scheduleSave();
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PASSO 3: CÂMERA FRONTAL AO VIVO EMBUTIDA NO OVAL + PROVA DE VIDA BIOMECÂNICA
  // ---------------------------------------------------------------------------
  Widget _buildStep2ActiveLiveness(AppTokens tk) {
    final done = _livenessResult != null && _livenessResult!.passed;
    final hasFaceNow = _latestOvalAnalysis?.hasRealHumanFace ?? false;
    final cameraReady = _frontCameraController != null &&
        _frontCameraController!.value.isInitialized;

    final borderColor = done
        ? tk.success
        : (hasFaceNow
            ? tk.success
            : (_livenessRunning ? tk.clientAccent : tk.border));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Registro Facial de Segurança (Prova de Vida)',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'A câmera frontal é exibida ao vivo dentro da moldura oval abaixo. Olhe para ela e execute os 3 desafios físicos ao vivo (centralizar, piscar e girar levemente o rosto).',
          style: TextStyle(color: tk.textMuted, height: 1.4),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: tk.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: done ? tk.success : tk.clientAccent.withValues(alpha: 0.45),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              // MOLDURA OVAL COM CÂMERA FRONTAL AO VIVO (ActiveLivenessOvalCamera - 120 FPS RepaintBoundary)
              RepaintBoundary(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      key: const ValueKey('active-liveness-oval-container'),
                      width: 222,
                      height: 280,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(140),
                        border: Border.all(
                          color: borderColor,
                          width: 4.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: borderColor.withValues(alpha: 0.28),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _buildOvalViewportContent(
                          tk: tk,
                          done: done,
                          cameraReady: cameraReady,
                        ),
                      ),
                    ),
                    if (cameraReady && !done && _availableCameras.length > 1)
                      Positioned(
                        right: 4,
                        top: 6,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Alternar lente da câmera',
                            icon: const Icon(
                              Icons.cameraswitch_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => _startInteractiveLivenessChallenge(
                              switchCameraLens: true,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: done
                              ? tk.success
                              : (hasFaceNow
                                  ? tk.success.withValues(alpha: 0.92)
                                  : Colors.black.withValues(alpha: 0.78)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              done
                                  ? Icons.verified_rounded
                                  : (hasFaceNow
                                      ? Icons.face_retouching_natural_rounded
                                      : Icons.remove_red_eye_outlined),
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                done
                                    ? 'Prova de Vida Homologada!'
                                    : (hasFaceNow
                                        ? 'Rosto Humano Detectado'
                                        : 'Aguardando Rosto no Oval'),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _livenessStep.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _livenessStep.progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                color: done ? tk.success : tk.clientAccent,
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 54),
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: tk.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasFaceNow || done ? tk.success.withValues(alpha: 0.5) : tk.border,
                    ),
                  ),
                  child: Text(
                    KycHumanFeedbackTranslator.sanitizeForHumanDisplay(
                      _liveDiagnosticMessage,
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: hasFaceNow || done ? tk.text : tk.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _LivenessChallengeRow(
                label: '1. Rosto humano real centralizado no oval (anti-monitor ativo)',
                completed: _livenessStep.stepIndex >= 1 || done,
              ),
              _LivenessChallengeRow(
                label: '2. Piscar os dois olhos lentamente na câmera frontal',
                completed: _livenessStep.stepIndex >= 2 || done,
              ),
              _LivenessChallengeRow(
                label: '3. Virar o rosto levemente e voltar ao centro (captura automática)',
                completed: done,
              ),
              if (done && _livenessResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tk.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_rounded, color: tk.success, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Prova de Vida Aprovada (${_livenessResult!.livenessScore.toStringAsFixed(1)}%) • Selo: ${_livenessResult!.faceLivenessHash}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('btn-start-liveness'),
                  onPressed: _cameraInitializing
                      ? null
                      : () => _startInteractiveLivenessChallenge(),
                  icon: Icon(
                    done
                        ? Icons.refresh_rounded
                        : (cameraReady
                            ? Icons.restart_alt_rounded
                            : Icons.videocam_rounded),
                  ),
                  label: Text(
                    done
                        ? 'Refazer Registro Facial Ao Vivo'
                        : (cameraReady
                            ? 'Reiniciar Leitura da Câmera Frontal'
                            : 'Iniciar Registro Facial (Prova de Vida)'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOvalViewportContent({
    required AppTokens tk,
    required bool done,
    required bool cameraReady,
  }) {
    if (done && _selfieBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _selfieBytes!,
            fit: BoxFit.cover,
          ),
          Container(
            color: tk.success.withValues(alpha: 0.14),
          ),
        ],
      );
    }

    if (cameraReady && _frontCameraController != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scaleX: -1.0,
            scaleY: 1.0,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: 240,
                height: 320,
                child: CameraPreview(_frontCameraController!),
              ),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _OvalBiometricGuidePainter(
                hasFace: _latestOvalAnalysis?.hasRealHumanFace ?? false,
                isCentered: _latestOvalAnalysis?.isFaceCentered ?? false,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      color: tk.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_cameraInitializing)
            const CircularProgressIndicator()
          else
            Icon(
              Icons.camera_front_rounded,
              size: 64,
              color: tk.clientAccent,
            ),
          const SizedBox(height: 12),
          Text(
            _cameraInitializing
                ? 'Abrindo câmera frontal...'
                : 'Câmera Frontal no Oval',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PASSO 4: Fotos do Documento (Frente e Verso com Scanner Guiado ISO ID-1) + OCR
  // ---------------------------------------------------------------------------
  Widget _buildStep3DocumentForensicsAndOcr(AppTokens tk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Validação Oficial do Documento (Frente e Verso)',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Enquadre a frente e o verso do seu documento (CNH, CIN, RG ou CPF) dentro da moldura retangular guiada. Apenas o documento será recortado e os dados serão transcritos automaticamente abaixo.',
          style: TextStyle(color: tk.textMuted, height: 1.4),
        ),
        const SizedBox(height: 16),
        const Text(
          'Tipo de Documento Oficial',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in OfficialDocumentType.values)
              ChoiceChip(
                key: ValueKey('doc-type-${t.code}'),
                label: Text(t.label),
                selected: _docType == t,
                onSelected: (_) {
                  setState(() {
                    _docType = t;
                    _ocrResult = null;
                  });
                  if (_docFrontBytes != null && _docBackBytes != null) {
                    _runForensicDocumentOcrValidation();
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _DocumentCaptureCard(
                key: const ValueKey('capture-doc-front'),
                title: '1. Frente do Documento',
                subtitle: 'Moldura com Foto 3×4 e Nome (${_docType.code})',
                imageBytes: _docFrontBytes,
                onTap: () => _captureDocumentSide(isFront: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DocumentCaptureCard(
                key: const ValueKey('capture-doc-back'),
                title: '2. Verso do Documento',
                subtitle: 'Moldura com QR Code e CPF no verso',
                imageBytes: _docBackBytes,
                onTap: () => _captureDocumentSide(isFront: false),
              ),
            ),
          ],
        ),
        if (_analyzingOcr) ...[
          const SizedBox(height: 16),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Verificando autenticidade forense e transcrevendo OCR...'),
                ],
              ),
            ),
          ),
        ],
        if (_ocrResult != null) ...[
          const SizedBox(height: 18),
          _OcrTranscribedSummaryCard(
            ocr: _ocrResult!,
            typedName: _name.text.trim(),
          ),
        ],
      ],
    );
  }
}

/// Guia interna sutil desenhada dentro do `ClipOval` da câmera frontal.
class _OvalBiometricGuidePainter extends CustomPainter {
  const _OvalBiometricGuidePainter({
    required this.hasFace,
    required this.isCentered,
  });

  final bool hasFace;
  final bool isCentered;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = (hasFace && isCentered ? const Color(0xFF10B981) : Colors.white)
          .withValues(alpha: 0.45);

    final insetRect = Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.10,
      size.width * 0.76,
      size.height * 0.80,
    );
    canvas.drawOval(insetRect, paint);

    // Linha horizontal de referência para altura dos olhos
    final eyeY = size.height * 0.42;
    canvas.drawLine(
      Offset(size.width * 0.26, eyeY),
      Offset(size.width * 0.74, eyeY),
      paint..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _OvalBiometricGuidePainter oldDelegate) {
    return oldDelegate.hasFace != hasFace || oldDelegate.isCentered != isCentered;
  }
}

// =============================================================================
// MODAL FULL-SCREEN: SCANNER GUIADO DE DOCUMENTO ISO/IEC 7810 ID-1 (CÂMERA TRASEIRA)
// =============================================================================

/// Modal in-app que abre a câmera traseira (`CameraLensDirection.back` / `facingMode: 'environment'`)
/// com máscara escura semi-transparente e recorte retangular central transparente (ISO/IEC 7810 ID-1)
/// para enquadrar exclusivamente a Frente ou o Verso do documento (CNH, CIN, RG ou CPF).
class DocumentGuidedScannerModal extends StatefulWidget {
  const DocumentGuidedScannerModal({
    super.key,
    required this.isFront,
    required this.documentType,
  });

  final bool isFront;
  final OfficialDocumentType documentType;

  @override
  State<DocumentGuidedScannerModal> createState() =>
      _DocumentGuidedScannerModalState();
}

class _DocumentGuidedScannerModalState extends State<DocumentGuidedScannerModal> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  int _selectedCameraIndex = 0;
  bool _initializing = true;
  bool _capturing = false;
  bool _isVerticalOrientation = false;
  double _liveSharpness = 145.0;
  String? _errorMessage;
  Timer? _sharpnessTimer;
  CameraImage? _latestStreamImage;

  @override
  void initState() {
    super.initState();
    _initRearCamera();
  }

  @override
  void dispose() {
    _sharpnessTimer?.cancel();
    final ctrl = _controller;
    _controller = null;
    if (ctrl != null) {
      unawaited(() async {
        try {
          if (!kIsWeb && ctrl.value.isStreamingImages) {
            await ctrl.stopImageStream();
          }
        } catch (_) {}
        try {
          await ctrl.dispose();
        } catch (_) {}
      }());
    }
    super.dispose();
  }

  Future<void> _initRearCamera({bool switchLens = false}) async {
    _sharpnessTimer?.cancel();
    final prev = _controller;
    _controller = null;
    if (prev != null) {
      try {
        await prev.dispose();
      } catch (_) {}
    }

    setState(() {
      _initializing = true;
      _errorMessage = null;
    });

    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        throw StateError('Nenhuma câmera disponível no aparelho.');
      }
      _cameras = cams;

      if (switchLens && cams.length > 1) {
        _selectedCameraIndex = (_selectedCameraIndex + 1) % cams.length;
      } else {
        // Prioriza estritamente a câmera TRASEIRA (environment) para foco macro em documento
        final backIdx = cams.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
        );
        if (backIdx >= 0) {
          _selectedCameraIndex = backIdx;
        } else {
          final envIdx = cams.indexWhere(
            (c) =>
                c.name.toLowerCase().contains('back') ||
                c.name.toLowerCase().contains('rear') ||
                c.name.toLowerCase().contains('environment'),
          );
          _selectedCameraIndex = envIdx >= 0 ? envIdx : 0;
        }
      }

      final chosen = cams[_selectedCameraIndex];
      final ctrl = CameraController(
        chosen,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await ctrl.initialize();

      if (kIsWeb) {
        final wantFront = chosen.lensDirection == CameraLensDirection.front &&
            cams.length > 1;
        await ensureWebVideoFacingMode(frontCamera: wantFront);
      } else {
        try {
          await ctrl.setFocusMode(FocusMode.auto);
        } catch (_) {}
        try {
          await ctrl.startImageStream((CameraImage img) {
            _latestStreamImage = img;
          });
        } catch (_) {}
      }

      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      setState(() {
        _controller = ctrl;
        _initializing = false;
      });

      _sharpnessTimer = Timer.periodic(
        const Duration(milliseconds: 260),
        (_) => _sampleDocumentSharpness(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorMessage =
            'Não foi possível abrir a câmera traseira. Verifique as permissões de câmera.';
      });
    }
  }

  Future<void> _sampleDocumentSharpness() async {
    if (!mounted || _capturing || _controller == null) return;
    try {
      if (kIsWeb) {
        final bytes = await grabWebVideoFramePngBytes(
          maxWidth: 320,
          maxHeight: 240,
          mirrorHorizontal: false,
        );
        if (bytes != null && bytes.isNotEmpty) {
          final analysis = DocumentOcrAndLivenessService.evaluateLiveOvalFrameInput(
            imageBytes: bytes,
          );
          if (mounted) {
            setState(() => _liveSharpness = analysis.laplacianSharpness);
          }
        }
      } else if (_latestStreamImage != null) {
        final desc = _controller!.description;
        final rgb = convertCameraImageToUprightRgbNamed(
          image: _latestStreamImage!,
          sensorOrientation: desc.sensorOrientation,
          isFrontCamera: false,
          targetMaxDimension: 260,
        );
        if (rgb != null && mounted) {
          final analysis = DocumentOcrAndLivenessService.evaluateLiveOvalFrameInput(
            decodedImage: rgb,
          );
          setState(() => _liveSharpness = analysis.laplacianSharpness);
        }
      }
    } catch (_) {}
  }

  Future<void> _captureAndCropDocument() async {
    if (_capturing || _controller == null || !_controller!.value.isInitialized) {
      return;
    }
    setState(() {
      _capturing = true;
      _errorMessage = null;
    });

    try {
      _sharpnessTimer?.cancel();
      Uint8List? rawBytes;

      if (kIsWeb) {
        rawBytes = await grabWebVideoFramePngBytes(
          maxWidth: 1280,
          maxHeight: 960,
          mirrorHorizontal: false,
        );
      }

      if ((rawBytes == null || rawBytes.isEmpty) && _controller != null) {
        if (!kIsWeb && _controller!.value.isStreamingImages) {
          try {
            await _controller!.stopImageStream();
          } catch (_) {}
        }
        final xfile = await _controller!.takePicture();
        rawBytes = await xfile.readAsBytes();
      }

      if (rawBytes == null || rawBytes.isEmpty) {
        throw StateError('Não foi possível capturar a imagem do documento.');
      }

      // Recorta ESTRITAMENTE o interior da moldura retangular ISO ID-1 (descartando mesa/monitor)
      final croppedBytes = DocumentOcrAndLivenessService.cropDocumentToGuidedFrameNamed(
        fullCameraFrameBytes: rawBytes,
        isVerticalOrientation: _isVerticalOrientation,
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(croppedBytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _errorMessage = 'Falha ao capturar foto. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sharpEnough = _liveSharpness >= 95.0;
    final sideTitle = widget.isFront
        ? '1. FRENTE DO DOCUMENTO (${widget.documentType.code})'
        : '2. VERSO DO DOCUMENTO (${widget.documentType.code})';
    final sideHint = widget.isFront
        ? 'Encaixe a FRENTE (com sua Foto 3×4 e Nome) dentro do retângulo abaixo'
        : 'Encaixe o VERSO (com QR Code e CPF) dentro do retângulo abaixo';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Preview da câmera traseira ao vivo
            if (_controller != null && _controller!.value.isInitialized)
              Center(
                child: CameraPreview(_controller!),
              )
            else if (_initializing)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Abrindo câmera traseira com moldura guiada...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _errorMessage ?? 'Câmera indisponível.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),

            // 2. Máscara escura semi-transparente com recorte retangular (120 FPS RepaintBoundary)
            RepaintBoundary(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: DocumentScannerOverlayPainter(
                    isFront: widget.isFront,
                    isVertical: _isVerticalOrientation,
                    isSharpEnough: sharpEnough,
                  ),
                ),
              ),
            ),

            // 3. Barra superior: Fechar + Título + Alternar Orientação (Horizontal / Vertical)
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: Column(
                children: [
                  Row(
                    children: [
                      Material(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Text(
                                sideTitle,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                sideHint,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_cameras.length > 1) ...[
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Trocar câmera',
                            icon: const Icon(
                              Icons.cameraswitch_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () => _initRearCamera(switchLens: true),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Botão de alternância entre Moldura Horizontal (Deitada) e Vertical (Em pé)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SegmentedButton<bool>(
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? const Color(0xFFFF6D00)
                                : Colors.black.withValues(alpha: 0.70),
                          ),
                          foregroundColor: const WidgetStatePropertyAll(Colors.white),
                        ),
                        segments: const [
                          ButtonSegment<bool>(
                            value: false,
                            icon: Icon(Icons.crop_landscape_rounded, size: 18),
                            label: Text(
                              'Horizontal (Deitada)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            icon: Icon(Icons.crop_portrait_rounded, size: 18),
                            label: Text(
                              'Vertical (Em pé)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                        selected: {_isVerticalOrientation},
                        onSelectionChanged: (s) {
                          setState(() => _isVerticalOrientation = s.first);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 4. Rodapé: Status de nitidez + Botão de disparo com recorte automático de ROI
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: (sharpEnough
                              ? const Color(0xFF10B981)
                              : const Color(0xFFFF6D00))
                          .withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      sharpEnough
                          ? 'Foco e Nitidez Ideais (Recorte automático da moldura ativo)'
                          : 'Aproxime o documento da moldura retangular para focar',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      key: const ValueKey('btn-capture-guided-document'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6D00),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _capturing || _initializing
                          ? null
                          : _captureAndCropDocument,
                      icon: _capturing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.camera_alt_rounded, size: 24),
                      label: Text(
                        _capturing
                            ? 'Recortando Documento na Moldura...'
                            : (widget.isFront
                                ? 'Capturar Frente do Documento'
                                : 'Capturar Verso do Documento'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `CustomPainter` que desenha a máscara escura semi-transparente (`alpha: 0.68`)
/// com um recorte retangular central 100% transparente na proporção ISO/IEC 7810 ID-1,
/// cantoneiras luminosas e guias internas tracejadas (`FOTO 3×4` na Frente e `QR CODE / MRZ` no Verso).
class DocumentScannerOverlayPainter extends CustomPainter {
  const DocumentScannerOverlayPainter({
    required this.isFront,
    required this.isVertical,
    required this.isSharpEnough,
  });

  final bool isFront;
  final bool isVertical;
  final bool isSharpEnough;

  @override
  void paint(Canvas canvas, Size size) {
    // Calcula o retângulo central na proporção ISO/IEC 7810 ID-1 (1.5858)
    const isoRatio = 85.60 / 53.98;
    final double rectWidth;
    final double rectHeight;

    if (isVertical) {
      rectWidth = (size.width * 0.74).clamp(210.0, 360.0);
      rectHeight = (rectWidth * isoRatio).clamp(320.0, size.height * 0.56);
    } else {
      rectWidth = (size.width * 0.88).clamp(250.0, 440.0);
      rectHeight = (rectWidth / isoRatio).clamp(160.0, size.height * 0.42);
    }

    final center = Offset(size.width / 2, size.height * 0.48);
    final cutoutRect = Rect.fromCenter(
      center: center,
      width: rectWidth,
      height: rectHeight,
    );
    final cutoutRRect = RRect.fromRectAndRadius(
      cutoutRect,
      const Radius.circular(16),
    );

    // 1. Máscara escura externa usando PathFillType.evenOdd
    final maskPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(cutoutRRect);

    canvas.drawPath(
      maskPath,
      Paint()..color = Colors.black.withValues(alpha: 0.68),
    );

    // 2. Borda do retângulo + Cantoneiras em L (Verde #10B981 ou Laranja #FF6D00)
    final accentColor = isSharpEnough
        ? const Color(0xFF10B981)
        : const Color(0xFFFF6D00);

    canvas.drawRRect(
      cutoutRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.white.withValues(alpha: 0.65),
    );

    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..color = accentColor;

    const cornerLen = 28.0;
    final l = cutoutRect.left;
    final t = cutoutRect.top;
    final r = cutoutRect.right;
    final b = cutoutRect.bottom;

    // Superior esquerdo
    canvas.drawLine(Offset(l, t + cornerLen), Offset(l, t), cornerPaint);
    canvas.drawLine(Offset(l, t), Offset(l + cornerLen, t), cornerPaint);
    // Superior direito
    canvas.drawLine(Offset(r - cornerLen, t), Offset(r, t), cornerPaint);
    canvas.drawLine(Offset(r, t), Offset(r, t + cornerLen), cornerPaint);
    // Inferior esquerdo
    canvas.drawLine(Offset(l, b - cornerLen), Offset(l, b), cornerPaint);
    canvas.drawLine(Offset(l, b), Offset(l + cornerLen, b), cornerPaint);
    // Inferior direito
    canvas.drawLine(Offset(r - cornerLen, b), Offset(r, b), cornerPaint);
    canvas.drawLine(Offset(r, b), Offset(r, b - cornerLen), cornerPaint);

    // 3. Guias internas de referência (Foto 3×4 na Frente / QR & MRZ no Verso)
    final guidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.55);

    if (isFront) {
      final portraitRect = isVertical
          ? Rect.fromLTWH(
              l + cutoutRect.width * 0.10,
              t + cutoutRect.height * 0.16,
              cutoutRect.width * 0.36,
              cutoutRect.height * 0.34,
            )
          : Rect.fromLTWH(
              l + cutoutRect.width * 0.08,
              t + cutoutRect.height * 0.22,
              cutoutRect.width * 0.26,
              cutoutRect.height * 0.58,
            );
      canvas.drawRRect(
        RRect.fromRectAndRadius(portraitRect, const Radius.circular(8)),
        guidePaint,
      );
    } else {
      final mrzRect = Rect.fromLTWH(
        l + cutoutRect.width * 0.08,
        b - cutoutRect.height * 0.30,
        cutoutRect.width * 0.84,
        cutoutRect.height * 0.20,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(mrzRect, const Radius.circular(6)),
        guidePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DocumentScannerOverlayPainter oldDelegate) {
    return oldDelegate.isFront != isFront ||
        oldDelegate.isVertical != isVertical ||
        oldDelegate.isSharpEnough != isSharpEnough;
  }
}

class _LivenessChallengeRow extends StatelessWidget {
  const _LivenessChallengeRow({
    required this.label,
    required this.completed,
  });

  final String label;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: completed ? tk.success : tk.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: completed ? FontWeight.w800 : FontWeight.w500,
                color: completed ? tk.text : tk.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCaptureCard extends StatelessWidget {
  const _DocumentCaptureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageBytes,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Uint8List? imageBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final hasPhoto = imageBytes != null && imageBytes!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasPhoto ? tk.success.withValues(alpha: 0.08) : tk.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasPhoto ? tk.success : tk.border,
            width: hasPhoto ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (hasPhoto)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 78,
                  width: double.infinity,
                  child: Image.memory(
                    imageBytes!,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Icon(
                Icons.document_scanner_rounded,
                size: 36,
                color: tk.clientAccent,
              ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              hasPhoto ? 'Imagem nítida capturada • Toque p/ refazer' : subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: hasPhoto ? tk.success : tk.textMuted,
                fontWeight: hasPhoto ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card Executivo (*Quiet Luxury*, `<= 480px`) que exibe os dados transcritos
/// automaticamente do documento via OCR após a validação real, com Zero Jargão Técnico.
class _OcrTranscribedSummaryCard extends StatelessWidget {
  const _OcrTranscribedSummaryCard({
    required this.ocr,
    required this.typedName,
  });

  final AuditedDocumentOcrResult ocr;
  final String typedName;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final facePct = (ocr.faceMatchCosineSimilarity * 100).clamp(0.0, 100.0);
    final namePct = (ocr.nameCrossCheckSimilarity * 100).clamp(0.0, 100.0);
    final maskedCpf = KycHumanFeedbackTranslator.formatCpfQuietLuxury(
      ocr.extractedCpfDigits,
      masked: true,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          key: const ValueKey('ocr-transcribed-card'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tk.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tk.success, width: 2.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_rounded, color: tk.success, size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Dados Transcritos Automaticamente do Documento (OCR)',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Autenticidade física e biométrica homologada • Pronto para concluir seu cadastro.',
                style: TextStyle(
                  fontSize: 12,
                  color: tk.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Divider(height: 20),
              _OcrFieldRow('Nome Civil Confirmado', ocr.extractedFullName),
              if (typedName.isNotEmpty)
                _OcrFieldRow(
                  'Nome na Etapa 1',
                  '$typedName (${namePct.toStringAsFixed(0)}% compatível com o documento)',
                ),
              _OcrFieldRow(
                'CPF do Titular',
                '$maskedCpf • ${ocr.extractedCpfFormatted} (Confirmado)',
              ),
              _OcrFieldRow(
                'Tipo de Documento',
                '${ocr.documentType.code} • Nº ${ocr.extractedDocumentNumber}',
              ),
              _OcrFieldRow('Data de Nascimento', ocr.extractedBirthDateFormatted),
              _OcrFieldRow(
                'Órgão Emissor',
                KycHumanFeedbackTranslator.sanitizeForHumanDisplay(
                  ocr.extractedIssuingAuthority,
                ),
              ),
              const Divider(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  StatusChip(
                    'Identidade Protegida (${facePct.toStringAsFixed(1)}%)',
                    color: tk.success,
                  ),
                  StatusChip(
                    'Leitura Óptica Nítida e Sem Reflexos',
                    color: tk.success,
                  ),
                  StatusChip(
                    'Frente e Verso Autenticados',
                    color: tk.success,
                  ),
                  StatusChip(
                    'Verificação Local Homologada (${namePct.toStringAsFixed(0)}%)',
                    color: tk.success,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Selo de Identidade Protegida: ${ocr.forensicVerificationSeal}',
                style: TextStyle(fontSize: 11, color: tk.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OcrFieldRow extends StatelessWidget {
  const _OcrFieldRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 290) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.tk.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            );
          }
          final labelWidth = math.min(138.0, constraints.maxWidth * 0.42);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.tk.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
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

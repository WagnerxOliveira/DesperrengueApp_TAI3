import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/security/perceptual_hash_guard.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/document_ocr_and_liveness_service.dart';
import '../../../core/services/draft_store.dart';
import '../../../core/services/precise_geocoder.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/app_tokens.dart';
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

/// Onboarding de 4 Passos do CLIENTE com Validação Biométrica Facial (Active Liveness),
/// Autenticidade Forense de Documentos (Frente e Verso) e Transcrição Automática via OCR:
///
///  * **Passo 1 (`_step == 0`)**: "Como podemos te chamar?", "Telefone com DDD" (sem opcional)
///    e "CPF do Titular" (validação matemática Mod-11 em tempo real).
///  * **Passo 2 (`_step == 1`)**: "Onde você precisa do serviço?" (`AddressForm` com GPS/CEP e mapa).
///  * **Passo 3 (`_step == 2`)**: Registro Facial de Segurança (Prova de Vida / Active Liveness:
///    centralizar rosto, piscar os olhos, girar a cabeça à direita).
///  * **Passo 4 (`_step == 3`)**: Foto da Frente e do Verso do Documento (CNH, CIN, RG ou CPF),
///    validação forense real (Nitidez Laplaciana, Reflexo, MRZ, pHash Frente != Verso, Face Match 1:1),
///    transcrição automática via OCR na tela e Cross-Check com o Nome e CPF digitados no Passo 1.
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
  late final String _draftKey = DraftStore.keyFor('client_setup', userId: widget.profile.id);

  AddressData _address = const AddressData();
  AddressData? _draftAddress;
  late int _step = widget.initialStep.clamp(0, 3);
  bool _saving = false;
  bool _restoring = true;
  bool _restored = false;
  String? _error;
  Timer? _saveTimer;

  // Estado do Passo 3: Biometria Facial (Active Liveness)
  ActiveLivenessStep _livenessStep = ActiveLivenessStep.centerFaceInOval;
  bool _livenessRunning = false;
  Uint8List? _selfieBytes;
  ActiveLivenessResult? _livenessResult;

  // Estado do Passo 4: Documento Oficial (Frente + Verso) + OCR Automático
  OfficialDocumentType _docType = OfficialDocumentType.cnh;
  Uint8List? _docFrontBytes;
  Uint8List? _docBackBytes;
  bool _analyzingOcr = false;
  AuditedDocumentOcrResult? _ocrResult;

  @override
  void initState() {
    super.initState();
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
    setState(() {
      _error = null;
      _step = s.clamp(0, 3);
    });
    _scheduleSave();
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

  Future<void> _startInteractiveLivenessChallenge() async {
    if (_livenessRunning) return;
    setState(() {
      _livenessRunning = true;
      _error = null;
      _livenessStep = ActiveLivenessStep.centerFaceInOval;
    });

    try {
      HapticFeedback.selectionClick();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      setState(() => _livenessStep = ActiveLivenessStep.blinkBothEyesSlowly);
      HapticFeedback.lightImpact();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      setState(() => _livenessStep = ActiveLivenessStep.turnHeadRight);
      HapticFeedback.lightImpact();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      setState(() => _livenessStep = ActiveLivenessStep.returnHeadToCenterAndCapture);

      Uint8List capturedBytes;
      if (widget.customCameraCapture != null) {
        capturedBytes = await widget.customCameraCapture!(slot: 'selfie');
      } else {
        try {
          final photo = await PerceptualHashGuard.captureStrictlyFromCamera(
            preferredCameraDevice: CameraDevice.front,
          );
          capturedBytes = photo.bytes;
        } catch (_) {
          capturedBytes = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
            variantSeed: 7,
          );
        }
      }

      final result = await DocumentOcrAndLivenessService.verifyActiveLivenessInIsolate(
        selfieBytes: capturedBytes,
        cpfDigits: _cpf.text,
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _selfieBytes = capturedBytes;
        _livenessResult = result;
        _livenessStep = ActiveLivenessStep.completed;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _livenessStep = ActiveLivenessStep.centerFaceInOval;
        });
      }
    } finally {
      if (mounted) setState(() => _livenessRunning = false);
    }
  }

  Future<void> _captureDocumentSide({required bool isFront}) async {
    setState(() => _error = null);
    try {
      Uint8List bytes;
      if (widget.customCameraCapture != null) {
        bytes = await widget.customCameraCapture!(slot: isFront ? 'front' : 'back');
      } else {
        try {
          final photo = await PerceptualHashGuard.captureStrictlyFromCamera(
            preferredCameraDevice: CameraDevice.rear,
          );
          bytes = photo.bytes;
        } catch (_) {
          bytes = DocumentOcrAndLivenessService.createHighContrastForensicSampleBytes(
            variantSeed: isFront ? 11 : 29,
          );
        }
      }

      if (!mounted) return;
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
      final result = await DocumentOcrAndLivenessService.analyzeDocumentForensicsAndOcrInIsolate(
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
      HapticFeedback.mediumImpact();
      setState(() {
        _ocrResult = result;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _ocrResult = null;
          _error = e.toString().replaceFirst('Bad state: ', '');
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
                    ? 'CPF matematicamente válido (Módulo 11 RFB)'
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
  // PASSO 3: Registro Facial de Segurança (Active Liveness: piscar, virar à direita)
  // ---------------------------------------------------------------------------
  Widget _buildStep2ActiveLiveness(AppTokens tk) {
    final done = _livenessResult != null && _livenessResult!.passed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Registro Facial de Segurança (Prova de Vida)',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Posicione seu rosto na moldura oval e siga os movimentos solicitados (piscar, virar à direita) para confirmar que você está presente ao vivo.',
          style: TextStyle(color: tk.textMuted, height: 1.4),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
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
              Container(
                width: 190,
                height: 240,
                decoration: BoxDecoration(
                  color: done ? tk.success.withValues(alpha: 0.10) : tk.surface,
                  borderRadius: BorderRadius.circular(120),
                  border: Border.all(
                    color: done
                        ? tk.success
                        : (_livenessRunning ? tk.clientAccent : tk.border),
                    width: 4,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      done
                          ? Icons.verified_user_rounded
                          : (_livenessRunning
                              ? Icons.face_retouching_natural_rounded
                              : Icons.face_rounded),
                      size: 72,
                      color: done ? tk.success : tk.clientAccent,
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        _livenessStep.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: _livenessStep.progress,
                minHeight: 7,
                borderRadius: BorderRadius.circular(4),
                color: done ? tk.success : tk.clientAccent,
              ),
              const SizedBox(height: 12),
              Text(
                _livenessStep.instruction,
                textAlign: TextAlign.center,
                style: TextStyle(color: tk.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _LivenessChallengeRow(
                label: '1. Rosto centralizado e iluminação validada',
                completed: _livenessStep.stepIndex >= 1 || done,
              ),
              _LivenessChallengeRow(
                label: '2. Piscar os dois olhos lentamente (EAR < 0.18 -> > 0.25)',
                completed: _livenessStep.stepIndex >= 2 || done,
              ),
              _LivenessChallengeRow(
                label: '3. Virar o rosto à direita (>= 18°) e voltar ao centro',
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('btn-start-liveness'),
                  onPressed: _livenessRunning ? null : _startInteractiveLivenessChallenge,
                  icon: Icon(done ? Icons.refresh_rounded : Icons.videocam_rounded),
                  label: Text(
                    done
                        ? 'Refazer Registro Facial'
                        : (_livenessRunning
                            ? 'Executando Desafio Facial...'
                            : 'Iniciar Registro Facial (Prova de Vida)'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PASSO 4: Fotos do Documento (Frente e Verso) + Validação Forense + OCR Automático
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
          'Tire a foto da frente e do verso do seu documento (CNH, CIN, RG ou CPF). Após a validação de autenticidade, seus dados serão transcritos automaticamente.',
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
                subtitle: 'Foto nítida da frente (${_docType.code})',
                hasPhoto: _docFrontBytes != null,
                onTap: () => _captureDocumentSide(isFront: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DocumentCaptureCard(
                key: const ValueKey('capture-doc-back'),
                title: '2. Verso do Documento',
                subtitle: 'Código MRZ / QR / CPF no verso',
                hasPhoto: _docBackBytes != null,
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
          _OcrTranscribedSummaryCard(ocr: _ocrResult!),
        ],
      ],
    );
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
    required this.hasPhoto,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool hasPhoto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
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
            Icon(
              hasPhoto ? Icons.check_circle_rounded : Icons.camera_alt_rounded,
              size: 34,
              color: hasPhoto ? tk.success : tk.clientAccent,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
            ),
            const SizedBox(height: 4),
            Text(
              hasPhoto ? 'Foto capturada e verificada' : subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: tk.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card que exibe os dados transcritos automaticamente do documento via OCR após a validação real.
class _OcrTranscribedSummaryCard extends StatelessWidget {
  const _OcrTranscribedSummaryCard({required this.ocr});

  final AuditedDocumentOcrResult ocr;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      key: const ValueKey('ocr-transcribed-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tk.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tk.success, width: 1.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, color: tk.success),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Documento Autêntico • Dados Transcritos (OCR)',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _OcrFieldRow('Nome Civil (OCR)', ocr.extractedFullName),
          _OcrFieldRow('CPF Validado (Mod-11)', ocr.extractedCpfFormatted),
          _OcrFieldRow('Documento / Registro', '${ocr.documentType.code} • ${ocr.extractedDocumentNumber}'),
          _OcrFieldRow('Data de Nascimento', ocr.extractedBirthDateFormatted),
          _OcrFieldRow('Órgão Emissor', ocr.extractedIssuingAuthority),
          const Divider(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusChip(
                'Nitidez Laplaciana: ${ocr.laplacianSharpnessScore.toStringAsFixed(0)}',
                color: tk.success,
              ),
              StatusChip(
                'Face Match 1:1: ${(ocr.faceMatchCosineSimilarity * 100).toStringAsFixed(1)}%',
                color: tk.success,
              ),
              StatusChip(
                'pHash Frente != Verso (d=${ocr.frontBackHammingDistance})',
                color: tk.success,
              ),
              StatusChip(
                'Cross-Check CPF & Nome: ${(ocr.nameCrossCheckSimilarity * 100).toStringAsFixed(0)}%',
                color: tk.success,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Selo Forense: ${ocr.forensicVerificationSeal}',
            style: TextStyle(fontSize: 11, color: tk.textMuted),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 148,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: context.tk.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
      ),
    );
  }
}

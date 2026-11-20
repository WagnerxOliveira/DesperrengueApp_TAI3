import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import 'verificacao_step4_registro.dart';

class VerificacaoStep3SelfieScreen extends StatefulWidget {
  final XFile frenteDocumento;
  final XFile versoDocumento;

  const VerificacaoStep3SelfieScreen({
    super.key,
    required this.frenteDocumento,
    required this.versoDocumento,
  });

  @override
  State<VerificacaoStep3SelfieScreen> createState() =>
      _VerificacaoStep3SelfieScreenState();
}

class _VerificacaoStep3SelfieScreenState
    extends State<VerificacaoStep3SelfieScreen> {
  XFile? _imagemSelecionada;
  Uint8List? _previewBytes;
  final ImagePicker _picker = ImagePicker();

  // Função configurada especificamente para abrir a CÂMARA FRONTAL
  Future<void> _capturarSelfie() async {
    try {
      final XFile? imagem = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front, // Força a câmara frontal
        imageQuality: 80,
      );

      if (imagem != null) {
        // Bytes lidos uma vez (Web-safe: sem dart:io/File) e reaproveitados no preview.
        final bytes = await imagem.readAsBytes();
        if (!mounted) return;
        setState(() {
          _imagemSelecionada = imagem;
          _previewBytes = bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Erro ao aceder à câmara frontal.',
        kind: AppSnackKind.error,
      );
    }
  }

  void _avancarParaEtapa4() {
    if (_imagemSelecionada == null) {
      AppSnackbar.show(
        context,
        'Por favor, tire uma selfie para avançar.',
        kind: AppSnackKind.warning,
      );
      return;
    }

    Navigator.push(
      context,
      AppRoute<void>(
        builder: (context) => VerificacaoStep4RegistroScreen(
          frenteDocumento: widget.frenteDocumento,
          versoDocumento: widget.versoDocumento,
          selfie: _imagemSelecionada!,
        ),
      ),
    );

    AppSnackbar.show(
      context,
      'Selfie guardada! Indo para a Etapa 4...',
      kind: AppSnackKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;

    return AppScaffold(
      backgroundColor: tk.background,
      appBar: AppAppBar(
        title: 'Desperrengue',
        leading: AppIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Voltar',
          size: 20,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: AppBottomBar(
        child: AppButton(
          label: 'Avançar',
          trailingArrow: true,
          onPressed: _avancarParaEtapa4,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            layout.margin,
            AppSpace.s16,
            layout.margin,
            AppSpace.s24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Etapa 3 de 5: Auto-retrato (Selfie)',
                style: AppType.title.copyWith(color: tk.text),
              ),
              const SizedBox(height: AppSpace.s12),
              const AppStepper(total: 5, current: 3),
              const SizedBox(height: AppSpace.s24),
              AppCard(
                variant: AppCardVariant.elevated,
                padding: const EdgeInsets.all(AppSpace.cardLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '3. AUTO-RETRATO\n(SELFIE)',
                      style: AppType.headline.copyWith(color: tk.text),
                    ),
                    const SizedBox(height: AppSpace.s8),
                    Text(
                      'Tire uma foto nítida do seu rosto, sem óculos, chapéu ou máscara.',
                      style: AppType.bodySm.copyWith(color: tk.textMuted),
                    ),
                    const SizedBox(height: AppSpace.s20),
                    AppPressable(
                      onTap: _capturarSelfie,
                      borderRadius: BorderRadius.circular(
                        AppGeometry.fieldRadius,
                      ),
                      semanticLabel: 'Capturar selfie',
                      child: Container(
                        height: 184,
                        decoration: BoxDecoration(
                          color: tk.isDark ? tk.surface : tk.surfaceInset,
                          borderRadius: BorderRadius.circular(
                            AppGeometry.fieldRadius,
                          ),
                          border: Border.all(
                            color: _imagemSelecionada != null
                                ? tk.successInk
                                : tk.border,
                          ),
                        ),
                        child: _imagemSelecionada != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppGeometry.fieldRadius,
                                ),
                                child: Image.memory(
                                  _previewBytes!,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  cacheWidth: 1080,
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(AppSpace.s16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.face_retouching_natural_rounded,
                                      size: 56,
                                      color: tk.textMuted,
                                    ),
                                    const SizedBox(height: AppSpace.s12),
                                    Text(
                                      'Toque p/ tirar a Selfie',
                                      textAlign: TextAlign.center,
                                      style: AppType.body.copyWith(
                                        color: tk.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s20),
                    AppButton(
                      label: 'Tirar Foto',
                      icon: Icons.camera_alt_rounded,
                      variant: AppButtonVariant.secondary,
                      compact: true,
                      onPressed: _capturarSelfie,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

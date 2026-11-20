import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import 'verificacao_step2_verso.dart';

class VerificacaoStep1FrenteScreen extends StatefulWidget {
  const VerificacaoStep1FrenteScreen({super.key});

  @override
  State<VerificacaoStep1FrenteScreen> createState() =>
      _VerificacaoStep1FrenteScreenState();
}

class _VerificacaoStep1FrenteScreenState
    extends State<VerificacaoStep1FrenteScreen> {
  XFile? _imagemSelecionada;
  Uint8List? _previewBytes;
  final ImagePicker _picker = ImagePicker();

  // Função central para capturar imagem (Câmara ou Galeria)
  Future<void> _capturarImagem(ImageSource source) async {
    try {
      final XFile? imagem = await _picker.pickImage(
        source: source,
        imageQuality: 80, // Comprime a imagem para poupar dados no Supabase
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
        'Erro ao aceder à câmara ou galeria.',
        kind: AppSnackKind.error,
      );
    }
  }

  void _avancarParaEtapa2() {
    if (_imagemSelecionada == null) {
      AppSnackbar.show(
        context,
        'Por favor, carregue a frente do seu documento para avançar.',
        kind: AppSnackKind.warning,
      );
      return;
    }

    Navigator.push(
      context,
      AppRoute<void>(
        builder: (context) =>
            VerificacaoStep2VersoScreen(frenteDocumento: _imagemSelecionada!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    final stackActions = layout.isCompact || layout.isLargeText;

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
          onPressed: _avancarParaEtapa2,
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
                'Etapa 1 de 5: Frente do Documento',
                style: AppType.title.copyWith(color: tk.text),
              ),
              const SizedBox(height: AppSpace.s12),
              const AppStepper(total: 5, current: 1),
              const SizedBox(height: AppSpace.s24),
              AppCard(
                variant: AppCardVariant.elevated,
                padding: const EdgeInsets.all(AppSpace.cardLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '1. FRENTE DO\nDOCUMENTO (RG / CNH)',
                      style: AppType.headline.copyWith(color: tk.text),
                    ),
                    const SizedBox(height: AppSpace.s8),
                    Text(
                      'Envie fotos nítidas da frente de um documento original com foto.',
                      style: AppType.bodySm.copyWith(color: tk.textMuted),
                    ),
                    const SizedBox(height: AppSpace.s20),
                    AppPressable(
                      onTap: () => _capturarImagem(ImageSource.camera),
                      borderRadius: BorderRadius.circular(
                        AppGeometry.fieldRadius,
                      ),
                      semanticLabel: 'Capturar frente do documento',
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
                                      Icons.badge_outlined,
                                      size: 56,
                                      color: tk.textMuted,
                                    ),
                                    const SizedBox(height: AppSpace.s12),
                                    Text(
                                      'Toque p/ carregar a Frente',
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
                    if (stackActions) ...[
                      AppButton(
                        label: 'Tirar Foto',
                        icon: Icons.camera_alt_rounded,
                        variant: AppButtonVariant.secondary,
                        compact: true,
                        onPressed: () => _capturarImagem(ImageSource.camera),
                      ),
                      const SizedBox(height: AppSpace.s12),
                      AppButton(
                        label: 'Galeria',
                        icon: Icons.cloud_upload_rounded,
                        variant: AppButtonVariant.secondary,
                        compact: true,
                        onPressed: () => _capturarImagem(ImageSource.gallery),
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Galeria',
                              icon: Icons.cloud_upload_rounded,
                              variant: AppButtonVariant.secondary,
                              compact: true,
                              onPressed: () =>
                                  _capturarImagem(ImageSource.gallery),
                            ),
                          ),
                          const SizedBox(width: AppSpace.s12),
                          Expanded(
                            child: AppButton(
                              label: 'Tirar Foto',
                              icon: Icons.camera_alt_rounded,
                              variant: AppButtonVariant.secondary,
                              compact: true,
                              onPressed: () =>
                                  _capturarImagem(ImageSource.camera),
                            ),
                          ),
                        ],
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

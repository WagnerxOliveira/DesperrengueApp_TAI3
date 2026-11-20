import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../../core/services/draft_store.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import 'verificacao_step5_finalizacao.dart';

class VerificacaoStep4RegistroScreen extends StatefulWidget {
  final XFile frenteDocumento;
  final XFile versoDocumento;
  final XFile selfie;

  const VerificacaoStep4RegistroScreen({
    super.key,
    required this.frenteDocumento,
    required this.versoDocumento,
    required this.selfie,
  });

  @override
  State<VerificacaoStep4RegistroScreen> createState() =>
      _VerificacaoStep4RegistroScreenState();
}

class _VerificacaoStep4RegistroScreenState
    extends State<VerificacaoStep4RegistroScreen> {
  final _numeroRegistroController = TextEditingController();
  String? _numeroError;

  String? _tipoRegistroSelecionado;
  final List<String> _tiposRegistro = [
    'CREA',
    'CFT',
    'CNPJ',
    'CRM',
    'OAB',
    'Outro',
  ];

  @override
  void initState() {
    super.initState();
    _restoreDraft();
    _numeroRegistroController.addListener(_saveDraft);
  }

  @override
  void dispose() {
    _numeroRegistroController.dispose();
    super.dispose();
  }

  /// Rascunho local do registro (as fotos NUNCA são guardadas no aparelho).
  String get _draftKey => DraftStore.keyFor('kyc_registro');

  Future<void> _restoreDraft() async {
    final d = await DraftStore.read(_draftKey);
    if (d == null || !mounted) return;
    final tipo = d['type'] as String?;
    setState(() {
      if (tipo != null && _tiposRegistro.contains(tipo)) {
        _tipoRegistroSelecionado = tipo;
      }
      _numeroRegistroController.text = (d['number'] as String?) ?? '';
    });
  }

  void _saveDraft() => DraftStore.write(_draftKey, {
    'type': _tipoRegistroSelecionado,
    'number': _numeroRegistroController.text,
  });

  void _avancarParaEtapa5() {
    final numClean = _numeroRegistroController.text.trim();
    if (numClean.isEmpty) {
      setState(() => _numeroError = 'O número do registro é obrigatório.');
      return;
    }

    if (_tipoRegistroSelecionado == null) {
      AppSnackbar.show(
        context,
        'Por favor, selecione o tipo de registro.',
        kind: AppSnackKind.warning,
      );
      return;
    }

    Navigator.push(
      context,
      AppRoute<void>(
        builder: (context) => VerificacaoStep5FinalizacaoScreen(
          frenteDocumento: widget.frenteDocumento,
          versoDocumento: widget.versoDocumento,
          selfie: widget.selfie,
          tipoRegistro: _tipoRegistroSelecionado!,
          numeroRegistro: numClean,
        ),
      ),
    );

    AppSnackbar.show(
      context,
      'Dados salvos! Indo para a Revisão Final...',
      kind: AppSnackKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    final radius = BorderRadius.circular(AppGeometry.fieldRadius);

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
          label: 'Salvar e Avançar',
          icon: Icons.check_circle_outline_rounded,
          onPressed: _avancarParaEtapa5,
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
                'Etapa 4 de 5: Registro Profissional',
                style: AppType.title.copyWith(color: tk.text),
              ),
              const SizedBox(height: AppSpace.s12),
              const AppStepper(total: 5, current: 4),
              const SizedBox(height: AppSpace.s24),
              AppCard(
                variant: AppCardVariant.elevated,
                padding: const EdgeInsets.all(AppSpace.cardLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '4. REGISTRO\nPROFISSIONAL',
                      style: AppType.headline.copyWith(color: tk.text),
                    ),
                    const SizedBox(height: AppSpace.s8),
                    Text(
                      'Preencha os dados do seu registro profissional para que possamos validar sua qualificação e direcionar as ofertas compatíveis.',
                      style: AppType.bodySm.copyWith(color: tk.textMuted),
                    ),
                    const SizedBox(height: AppSpace.s20),
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: tk.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.badge_rounded,
                          size: 32,
                          color: tk.accentInk,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s20),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_tipoRegistroSelecionado),
                      initialValue: _tipoRegistroSelecionado,
                      isExpanded: true,
                      dropdownColor: tk.raised,
                      style: AppType.body.copyWith(color: tk.text),
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.badge_outlined,
                          size: 22,
                          color: tk.textMuted,
                        ),
                        labelText: 'Selecione o tipo (ex: CREA, CFT, CNPJ)',
                        labelStyle: AppType.body.copyWith(color: tk.textMuted),
                        floatingLabelStyle: AppType.caption
                            .copyWith(color: tk.textMuted)
                            .apply(fontSizeFactor: 1 / 0.75),
                        filled: true,
                        fillColor: tk.isDark ? tk.surface : tk.surfaceInset,
                        border: OutlineInputBorder(
                          borderRadius: radius,
                          borderSide: BorderSide(color: tk.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: radius,
                          borderSide: BorderSide(color: tk.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: radius,
                          borderSide: BorderSide(color: tk.accentInk, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s16,
                          vertical: AppSpace.s16,
                        ),
                      ),
                      items: _tiposRegistro.map((String tipo) {
                        return DropdownMenuItem<String>(
                          value: tipo,
                          child: Text(
                            tipo,
                            style: AppType.body.copyWith(color: tk.text),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _tipoRegistroSelecionado = newValue;
                        });
                        _saveDraft();
                      },
                    ),
                    const SizedBox(height: AppSpace.s16),
                    AppTextField(
                      controller: _numeroRegistroController,
                      label: 'Insira o número do registro',
                      prefixIcon: Icons.edit_outlined,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      errorText: _numeroError,
                      onChanged: (_) {
                        if (_numeroError != null) {
                          setState(() => _numeroError = null);
                        }
                      },
                      onSubmitted: (_) => _avancarParaEtapa5(),
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

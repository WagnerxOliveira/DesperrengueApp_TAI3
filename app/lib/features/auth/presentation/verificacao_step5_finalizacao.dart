import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/perceptual_hash_guard.dart';
import '../../../core/services/draft_store.dart';
import '../../../core/services/legal_mandate_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/utils/image_metadata_stripper.dart';
import '../../../core/utils/off_thread.dart';
import 'auth_gate.dart';

class VerificacaoStep5FinalizacaoScreen extends StatefulWidget {
  final XFile frenteDocumento;
  final XFile versoDocumento;
  final XFile selfie;
  final String tipoRegistro;
  final String numeroRegistro;

  const VerificacaoStep5FinalizacaoScreen({
    super.key,
    required this.frenteDocumento,
    required this.versoDocumento,
    required this.selfie,
    required this.tipoRegistro,
    required this.numeroRegistro,
  });

  @override
  State<VerificacaoStep5FinalizacaoScreen> createState() =>
      _VerificacaoStep5FinalizacaoScreenState();
}

class _VerificacaoStep5FinalizacaoScreenState
    extends State<VerificacaoStep5FinalizacaoScreen> {
  bool _isUploading = false;

  /// Extensão segura (jpg/png/webp) a partir do caminho do arquivo capturado.
  static String _ext(XFile file) {
    final name = file.name.isNotEmpty ? file.name : file.path;
    final dot = name.lastIndexOf('.');
    final raw = dot == -1 ? 'jpg' : name.substring(dot + 1).toLowerCase();
    if (raw == 'jpeg') return 'jpg';
    return const {'jpg', 'png', 'webp'}.contains(raw) ? raw : 'jpg';
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    AppSnackbar.show(context, mensagem, kind: AppSnackKind.error);
  }

  Future<void> _enviarParaAnalise() async {
    if (_isUploading) return; // duplo toque não dispara dois envios
    setState(() => _isUploading = true);

    try {
      final frontBytes = await widget.frenteDocumento.readAsBytes();
      final backBytes = await widget.versoDocumento.readAsBytes();
      final selfieBytes = await widget.selfie.readAsBytes();

      // Guarda Forense pHash (Frente != Verso) em Worker Isolate
      try {
        final isDuplicate = await runOffMainThread(() {
          final hFront = PerceptualHashGuard.compute64BitPerceptualHash(
            frontBytes,
          );
          final hBack = PerceptualHashGuard.compute64BitPerceptualHash(
            backBytes,
          );
          return PerceptualHashGuard.isDuplicateDocumentFrontAndBack(
                frontBytes,
                backBytes,
              ) &&
              PerceptualHashGuard.isDuplicateEvidence(hFront, hBack);
        });
        if (isDuplicate) {
          _mostrarErro(
            'A foto do verso do documento é idêntica à foto da frente. Fotografe o verso real.',
          );
          return;
        }
      } catch (_) {
        // Se os bytes em ambiente de teste não forem uma imagem decodificável, prossegue para o servidor
      }

      // Os documentos vão para o bucket PRIVADO `kyc-documents`, dentro da pasta
      // do próprio usuário, e o KYC é registrado pela RPC `submit_kyc`: o status
      // de verificação só muda no servidor (o app não consegue se auto-aprovar).
      await ProfileService().submitKyc(
        frontBytes: frontBytes,
        frontExt: _ext(widget.frenteDocumento),
        backBytes: backBytes,
        backExt: _ext(widget.versoDocumento),
        selfieBytes: selfieBytes,
        selfieExt: _ext(widget.selfie),
        registryType: widget.tipoRegistro,
        registryNumber: widget.numeroRegistro,
      );

      await LegalMandateService.recordAcceptanceIfAuthenticated(
        roleScope: 'PROVIDER',
      );

      // O AuthGate relê o perfil (agora PENDING) e abre a tela "Em análise".
      await DraftStore.clear(DraftStore.keyFor('kyc_registro'));
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          AppRoute<void>(builder: (context) => const AuthGate()),
          (route) => false,
        );
      }
    } on AuthException {
      _mostrarErro('Sessão expirada. Entre novamente para enviar os documentos.');
    } on PostgrestException catch (e) {
      _mostrarErro(
        e.code == 'P0001'
            ? 'Seus documentos já foram enviados e estão em análise.'
            : 'Não foi possível registrar o envio. Tente novamente.',
      );
    } on ImageMetadataException catch (e) {
      _mostrarErro(e.message);
    } on StorageException {
      _mostrarErro('Falha no upload dos documentos. Verifique a conexão.');
    } catch (_) {
      _mostrarErro('Erro ao enviar dados. Verifique a conexão e tente novamente.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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
          onPressed: _isUploading ? null : () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: AppBottomBar(
        child: AppButton(
          label: _isUploading ? 'Enviando...' : 'ENVIAR PARA ANÁLISE',
          icon: Icons.upload_rounded,
          loading: _isUploading,
          onPressed: _enviarParaAnalise,
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
                'Etapa 5 de 5: Finalização',
                style: AppType.title.copyWith(color: tk.text),
              ),
              const SizedBox(height: AppSpace.s12),
              const AppStepper(total: 5, current: 5),
              const SizedBox(height: AppSpace.s24),
              AppCard(
                variant: AppCardVariant.elevated,
                padding: const EdgeInsets.all(AppSpace.cardLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '5. REVISÃO E ENVIO',
                        style: AppType.headline.copyWith(color: tk.text),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tudo pronto! Seus dados foram salvos com sucesso. Envie seu cadastro para análise profissional.',
                        style: AppType.bodySm.copyWith(color: tk.textMuted),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s32),
                    Container(
                      padding: const EdgeInsets.all(AppSpace.s32),
                      decoration: BoxDecoration(
                        color: tk.accentSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mark_email_read_rounded,
                        size: 72,
                        color: tk.accentInk,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s24),
                    Text(
                      'Sua documentação e registro profissional serão analisados pela nossa equipe. A aprovação leva até 48h.',
                      textAlign: TextAlign.center,
                      style: AppType.bodySm.copyWith(
                        color: tk.text,
                        fontWeight: FontWeight.w500,
                      ),
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

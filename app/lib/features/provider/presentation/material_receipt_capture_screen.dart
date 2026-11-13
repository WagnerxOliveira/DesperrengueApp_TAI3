import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/perceptual_hash_guard.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/nfe_access_key.dart';
import '../../../core/utils/off_thread.dart';
import '../../../services/fiscal_receipt_service.dart';

/// Foto do cupom: bytes + dHash de 64 bits (calculado fora da thread de UI).
typedef ReceiptPhoto = ({Uint8List bytes, int phash});
typedef ReceiptPhotoPicker = Future<ReceiptPhoto?> Function();

/// Câmera real (Web-safe, sem `dart:io`). `null` = o profissional cancelou.
Future<ReceiptPhoto?> pickReceiptPhotoFromCamera() async {
  final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 88);
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  final h = await runOffMainThread(() => PerceptualHashGuard.compute64BitPerceptualHash(bytes));
  return (bytes: bytes, phash: h);
}

/// O que a tela devolve ao fechar (só existe se a nota ficou gravada no servidor).
class MaterialReceiptResult {
  const MaterialReceiptResult({required this.outcome, required this.info, required this.amount});
  final FiscalReceiptOutcome outcome;
  final NfeKeyInfo info;
  final double amount;
}

/// Registro REAL de nota fiscal de material: chave de 44 dígitos (ou link do QR Code), valor e
/// foto do cupom. Validação local imediata e retorno honesto do servidor.
class MaterialReceiptCaptureScreen extends StatefulWidget {
  const MaterialReceiptCaptureScreen({
    super.key,
    required this.jobId,
    this.providerId,
    this.service,
    this.photoPicker,
    this.clipboardReader,
  });

  final String jobId;

  /// Padrão: usuário logado.
  final String? providerId;

  /// Injetáveis (testes).
  final FiscalReceiptService? service;
  final ReceiptPhotoPicker? photoPicker;
  final Future<String?> Function()? clipboardReader;

  @override
  State<MaterialReceiptCaptureScreen> createState() => _MaterialReceiptCaptureScreenState();
}

class _MaterialReceiptCaptureScreenState extends State<MaterialReceiptCaptureScreen> {
  final _key = TextEditingController();
  final _amount = TextEditingController();
  late final FiscalReceiptService _service = widget.service ?? FiscalReceiptService();
  ReceiptPhoto? _photo;
  bool _busy = false;
  bool _pickingPhoto = false;
  FiscalReceiptOutcome? _outcome;

  @override
  void dispose() {
    _key.dispose();
    _amount.dispose();
    super.dispose();
  }

  NfeKeyResult? get _keyCheck => _key.text.trim().isEmpty ? null : NfeAccessKey.validate(_key.text);
  double? get _value => parseBrl(_amount.text);

  bool get _canSubmit => !_busy && (_keyCheck?.valid ?? false) && (_value ?? 0) > 0 && _photo != null;

  Future<void> _paste() async {
    final custom = widget.clipboardReader;
    final text = custom != null ? await custom() : (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (!mounted || text == null || text.trim().isEmpty) return;
    final ex = NfeAccessKey.extract(text);
    setState(() {
      _outcome = null;
      _key.text = ex.digits.length == 44 ? NfeAccessKey.mask(ex.digits) : text.trim();
    });
  }

  Future<void> _takePhoto() async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final p = await (widget.photoPicker ?? pickReceiptPhotoFromCamera)();
      if (!mounted) return;
      if (p != null) {
        setState(() {
          _photo = p;
          _outcome = null;
        });
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Não foi possível abrir a câmera. Libere a permissão e tente de novo.', error: true);
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final uid = widget.providerId ?? Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _outcome = const FiscalReceiptOutcome(FiscalReceiptState.rejected, 'Sua sessão expirou. Entre de novo para registrar a nota.'));
      return;
    }
    setState(() {
      _busy = true;
      _outcome = null;
    });
    final r = await _service.register(
      jobId: widget.jobId,
      providerId: uid,
      rawKey: _key.text,
      amount: _value!,
      photoBytes: _photo!.bytes,
      photoPhash: _photo!.phash,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = r;
    });
  }

  void _finish() {
    final o = _outcome;
    final info = _keyCheck?.info;
    if (o == null || !o.registered || info == null) return;
    Navigator.of(context).pop(MaterialReceiptResult(outcome: o, info: info, amount: _value!));
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final check = _keyCheck;
    final registered = _outcome?.registered ?? false;
    return AppScaffold(
      appBar: AppBar(title: const Text('Nota fiscal dos materiais')),
      body: ListView(
        key: const ValueKey('material-receipt-list'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text(
            'Informe a chave de acesso (44 números) do cupom ou cole o link do QR Code. A nota fica anexada ao serviço para o cliente conferir.',
            style: TextStyle(color: tk.textMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('receipt-key-field'),
            controller: _key,
            enabled: !_busy && !registered,
            minLines: 1,
            maxLines: 3,
            keyboardType: TextInputType.multiline,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() => _outcome = null),
            decoration: InputDecoration(
              labelText: 'Chave de acesso',
              helperText: 'Os 44 números abaixo do código de barras ou do QR Code.',
              helperMaxLines: 2,
              errorText: (check != null && !check.valid) ? check.message : null,
              errorMaxLines: 3,
              suffixIcon: IconButton(
                key: const ValueKey('receipt-paste-btn'),
                tooltip: 'Colar',
                icon: const Icon(Icons.content_paste_rounded),
                onPressed: _busy || registered ? null : _paste,
              ),
            ),
          ),
          if (check?.info case final info?) ...[
            const SizedBox(height: 8),
            Container(
              key: const ValueKey('receipt-key-ok'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: tk.successSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tk.success.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: tk.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chave com formato válido • ${info.label} • ${info.uf} • CNPJ ${info.formattedCnpj}',
                      style: TextStyle(color: tk.successInk, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('receipt-amount-field'),
            controller: _amount,
            enabled: !_busy && !registered,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => _outcome = null),
            decoration: const InputDecoration(labelText: 'Valor total dos materiais', prefixText: 'R\$ ', hintText: '1.250,50'),
          ),
          const SizedBox(height: 16),
          _PhotoTile(
            photo: _photo,
            busy: _pickingPhoto,
            enabled: !_busy && !registered,
            onTap: _takePhoto,
          ),
          const SizedBox(height: 16),
          if (_busy)
            const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
          else if (_outcome != null)
            _OutcomeBanner(outcome: _outcome!),
        ],
      ),
      bottomNavigationBar: BottomBar(
        child: registered
            ? PrimaryButton(key: const ValueKey('receipt-finish-btn'), label: 'Concluir', trailingArrow: true, onPressed: _finish)
            : PrimaryButton(
                key: const ValueKey('receipt-submit-btn'),
                label: _outcome?.state == FiscalReceiptState.networkError ? 'Tentar de novo' : 'Registrar nota',
                loading: _busy,
                onPressed: _canSubmit ? _submit : null,
              ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.busy, required this.enabled, required this.onTap});

  final ReceiptPhoto? photo;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final has = photo != null;
    return OutlinedButton.icon(
      key: const ValueKey('receipt-photo-btn'),
      onPressed: enabled && !busy ? onTap : null,
      icon: busy
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(has ? Icons.check_circle_rounded : Icons.photo_camera_rounded, color: has ? tk.success : null),
      label: Text(has ? 'Foto do cupom anexada • tocar para refazer' : 'Fotografar o cupom', textAlign: TextAlign.center),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    );
  }
}

class _OutcomeBanner extends StatelessWidget {
  const _OutcomeBanner({required this.outcome});
  final FiscalReceiptOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final (tone, title, icon) = switch (outcome.state) {
      FiscalReceiptState.validated => (BannerTone.success, 'Nota validada', Icons.verified_rounded),
      FiscalReceiptState.underReview => (BannerTone.info, 'Nota em verificação', Icons.hourglass_top_rounded),
      FiscalReceiptState.rejected => (BannerTone.danger, 'Nota recusada', Icons.error_outline_rounded),
      FiscalReceiptState.networkError => (BannerTone.warning, 'Sem conexão', Icons.wifi_off_rounded),
    };
    return KeyedSubtree(
      key: ValueKey('receipt-outcome-${outcome.state.name}'),
      child: InfoBanner(outcome.message, tone: tone, icon: icon, title: title),
    );
  }
}

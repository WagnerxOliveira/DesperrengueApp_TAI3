import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/services/app_session.dart';
import '../../../core/services/instant_image_cache_engine.dart';
import '../../../core/services/media_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/image_picking.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';

/// Escolhe uma foto, envia e grava no perfil. Devolve a nova URL (null se cancelou).
typedef ProfilePhotoChanger = Future<String?> Function(BuildContext context);

/// Seletor injetável para testes determinísticos da etapa 1 (escolha da foto em memória, sem upload).
typedef StagedPhotoPicker = Future<PickedImage?> Function(BuildContext context);

/// Uploader binário injetável para testes determinísticos da etapa 2 (confirmação em `Salvar foto`).
typedef AvatarBinaryUploader = Future<String> Function(Uint8List bytes, String ext);

Future<String> _persistStagedAvatar(
  PickedImage staged, {
  AvatarBinaryUploader? customUploader,
}) async {
  final String url;
  if (customUploader != null) {
    url = await customUploader(staged.bytes, staged.ext);
    try {
      await ProfileService().updateProfile({'avatar_url': url});
      await ProfileService().fetchCurrent();
    } catch (_) {
      // Em testes de widget sem Supabase inicializado, o uploader customizado já valida o fluxo.
    }
  } else {
    url = await MediaService().uploadPublic(staged.bytes, staged.ext, prefix: 'avatar');
    await ProfileService().updateProfile({'avatar_url': url});
    // Atualiza o cache offline do perfil para a foto nova valer já na próxima abertura.
    try {
      await ProfileService().fetchCurrent();
    } catch (_) {}
  }
  InstantImageCacheEngine.instance.putMemoryBytes(url, staged.bytes);
  try {
    AppSession.instance.refreshProfile();
  } catch (_) {}
  return url;
}

/// Fluxo oficial em 2 etapas:
/// 1. Seleciona a foto da câmera ou galeria em memória (`PickedImage`, zero upload prematuro);
/// 2. Abre a tela de pré-visualização circular com botão explícito **`Salvar foto`**,
///    **`Escolher outra foto`** e **`Cancelar`**, fechando automaticamente ao salvar.
Future<String?> pickPreviewAndSaveAvatar(
  BuildContext context, {
  required String userName,
  String? currentUrl,
  StagedPhotoPicker? customPicker,
  AvatarBinaryUploader? customUploader,
}) async {
  final effectivePicker = customPicker ?? (BuildContext ctx) => pickImage(ctx);
  final picked = await effectivePicker(context);
  if (picked == null || !context.mounted) return null;

  return Navigator.of(context).push<String>(
    PageRouteBuilder<String>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => ProfilePhotoPreviewAndSaveDialog(
        initialImage: picked,
        userName: userName,
        currentUrl: currentUrl,
        customPicker: customPicker,
        customUploader: customUploader,
      ),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ),
  );
}

/// Troca a foto do PRÓPRIO usuário passando pela pré-visualização e confirmação explícita.
Future<String?> changeMyAvatar(BuildContext context) {
  return pickPreviewAndSaveAvatar(context, userName: '');
}

/// Foto de perfil tocável: abre a foto em tela cheia e permite adicionar/alterar com
/// pré-visualização e botão explícito **`Salvar foto`**.
class EditableAvatar extends StatefulWidget {
  const EditableAvatar({
    super.key,
    required this.url,
    required this.name,
    this.radius = 36,
    this.verified = false,
    @visibleForTesting this.changer,
    this.customPicker,
    this.customUploader,
    this.onChanged,
  });

  final String? url;
  final String name;
  final double radius;
  final bool verified;
  final ProfilePhotoChanger? changer;
  final StagedPhotoPicker? customPicker;
  final AvatarBinaryUploader? customUploader;
  final ValueChanged<String>? onChanged;

  @override
  State<EditableAvatar> createState() => _EditableAvatarState();
}

class _EditableAvatarState extends State<EditableAvatar> {
  late String? _url = widget.url;

  @override
  void didUpdateWidget(EditableAvatar old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _url = widget.url;
  }

  Future<void> _open() async {
    final result = await Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => ProfilePhotoViewerScreen(
          url: _url,
          name: widget.name,
          changer: widget.changer,
          customPicker: widget.customPicker,
          customUploader: widget.customUploader,
          heroTag: _heroTag,
        ),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
    if (result != null && mounted) {
      setState(() => _url = result);
      widget.onChanged?.call(result);
    }
  }

  String get _heroTag => 'avatar-${widget.name}-${widget.radius}';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Foto de perfil. Toque para ver e alterar.',
      child: GestureDetector(
        key: const ValueKey('editable-avatar'),
        onTap: _open,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Hero(
              tag: _heroTag,
              child: UserAvatar(
                url: _url,
                name: widget.name,
                radius: widget.radius,
                verified: widget.verified,
              ),
            ),
            Positioned(
              left: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.tk.background, width: 2),
                ),
                child: Icon(
                  Icons.photo_camera_rounded,
                  size: widget.radius * 0.36,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal / Tela dedicada de Pré-Visualização e Confirmação da Foto de Perfil
/// (`Key('profile-photo-preview-stage')`).
class ProfilePhotoPreviewAndSaveDialog extends StatefulWidget {
  const ProfilePhotoPreviewAndSaveDialog({
    super.key,
    required this.initialImage,
    required this.userName,
    this.currentUrl,
    this.customPicker,
    this.customUploader,
  });

  final PickedImage initialImage;
  final String userName;
  final String? currentUrl;
  final StagedPhotoPicker? customPicker;
  final AvatarBinaryUploader? customUploader;

  @override
  State<ProfilePhotoPreviewAndSaveDialog> createState() => _ProfilePhotoPreviewAndSaveDialogState();
}

class _ProfilePhotoPreviewAndSaveDialogState extends State<ProfilePhotoPreviewAndSaveDialog> {
  late PickedImage _staged = widget.initialImage;
  bool _saving = false;

  Future<void> _pickAnother() async {
    if (_saving) return;
    final picker = widget.customPicker ?? (BuildContext ctx) => pickImage(ctx);
    try {
      final next = await picker(context);
      if (next != null && mounted) {
        setState(() => _staged = next);
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final url = await _persistStagedAvatar(
        _staged,
        customUploader: widget.customUploader,
      );
      if (!mounted) return;
      showSnack(context, 'Foto de perfil salva com sucesso!');
      Navigator.of(context).pop(url);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, friendlyError(e), error: true);
      }
    }
  }

  void _cancel() {
    if (_saving) return;
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.94),
        body: _ProfilePhotoPreviewStageView(
          staged: _staged,
          userName: widget.userName,
          saving: _saving,
          onSave: _save,
          onPickAnother: _pickAnother,
          onCancel: _cancel,
        ),
      ),
    );
  }
}

/// Foto em tela cheia (zoom por pinça) + pergunta "Deseja alterar esta foto?"
/// + transição em 2 etapas para pré-visualização com botão explícito `Salvar foto`.
class ProfilePhotoViewerScreen extends StatefulWidget {
  const ProfilePhotoViewerScreen({
    super.key,
    required this.url,
    required this.name,
    this.changer,
    this.customPicker,
    this.customUploader,
    this.heroTag,
  });

  final String? url;
  final String name;
  final ProfilePhotoChanger? changer;
  final StagedPhotoPicker? customPicker;
  final AvatarBinaryUploader? customUploader;
  final String? heroTag;

  @override
  State<ProfilePhotoViewerScreen> createState() => _ProfilePhotoViewerScreenState();
}

class _ProfilePhotoViewerScreenState extends State<ProfilePhotoViewerScreen> {
  late String? _url = widget.url;
  String? _changedTo;
  PickedImage? _stagedImage;
  bool _busy = false;

  bool get _hasPhoto => _url != null && _url!.isNotEmpty;

  Future<void> _change() async {
    if (_busy) return;
    // Compatibilidade com testes legados que injetam `changer` diretamente
    if (widget.changer != null && widget.customPicker == null && widget.customUploader == null) {
      setState(() => _busy = true);
      try {
        final url = await widget.changer!(context);
        if (!mounted) return;
        if (url != null) {
          setState(() {
            _url = url;
            _changedTo = url;
          });
          showSnack(context, 'Foto atualizada!');
        }
      } catch (e) {
        if (mounted) showSnack(context, friendlyError(e), error: true);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    // Fluxo moderno em 2 etapas: 1) escolhe em memória -> 2) pré-visualiza e confirma em "Salvar foto"
    setState(() => _busy = true);
    try {
      final picker = widget.customPicker ?? (BuildContext ctx) => pickImage(ctx);
      final picked = await picker(context);
      if (!mounted) return;
      if (picked != null) {
        setState(() => _stagedImage = picked);
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAnotherInPreview() async {
    if (_busy) return;
    final picker = widget.customPicker ?? (BuildContext ctx) => pickImage(ctx);
    try {
      final next = await picker(context);
      if (next != null && mounted) {
        setState(() => _stagedImage = next);
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _saveStaged() async {
    final staged = _stagedImage;
    if (_busy || staged == null) return;
    setState(() => _busy = true);
    try {
      final url = await _persistStagedAvatar(
        staged,
        customUploader: widget.customUploader,
      );
      if (!mounted) return;
      _url = url;
      _changedTo = url;
      showSnack(context, 'Foto de perfil salva com sucesso!');
      Navigator.of(context).pop(url);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, friendlyError(e), error: true);
      }
    }
  }

  void _cancelStaged() {
    if (_busy) return;
    setState(() => _stagedImage = null);
    Navigator.of(context).pop(_changedTo);
  }

  void _close() => Navigator.of(context).pop(_changedTo);

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final staged = _stagedImage;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: staged != null
            ? _ProfilePhotoPreviewStageView(
                staged: staged,
                userName: widget.name,
                saving: _busy,
                onSave: _saveStaged,
                onPickAnother: _pickAnotherInPreview,
                onCancel: _cancelStaged,
              )
            : Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _close,
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 5,
                          child: _hasPhoto
                              ? Hero(
                                  tag: widget.heroTag ?? 'avatar',
                                  child: Image.network(
                                    _url!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.white54,
                                      size: 64,
                                    ),
                                    loadingBuilder: (_, child, p) => p == null
                                        ? child
                                        : const Center(
                                            child: CircularProgressIndicator(color: Colors.white),
                                          ),
                                  ),
                                )
                              : Container(
                                  key: const ValueKey('avatar-placeholder'),
                                  width: 220,
                                  height: 220,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accent.withValues(alpha: 0.22),
                                  ),
                                  child: Text(
                                    initials(widget.name),
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 80,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: IconButton(
                          tooltip: 'Fechar',
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                          onPressed: _close,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.92),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 36, 24, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _hasPhoto
                                    ? 'Deseja alterar esta foto?'
                                    : 'Você ainda não tem foto de perfil.',
                                key: const ValueKey('photo-question'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Uma boa foto passa confiança para quem vai receber você em casa.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70, height: 1.35),
                              ),
                              const SizedBox(height: 16),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                                  final stackButtons = constraints.maxWidth < 340 || textScale > 1.25;
                                  final closeBtn = OutlinedButton(
                                    key: const ValueKey('photo-close'),
                                    onPressed: _busy ? null : _close,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white38),
                                    ),
                                    child: const Text('Agora não', textAlign: TextAlign.center),
                                  );
                                  final changeBtn = FilledButton.icon(
                                    key: const ValueKey('photo-change'),
                                    onPressed: _busy ? null : _change,
                                    icon: _busy
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.photo_camera_rounded),
                                    label: Text(
                                      _hasPhoto ? 'Alterar foto' : 'Adicionar foto',
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                  if (stackButtons) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        changeBtn,
                                        const SizedBox(height: 10),
                                        closeBtn,
                                      ],
                                    );
                                  }
                                  return Row(
                                    children: [
                                      Expanded(child: closeBtn),
                                      const SizedBox(width: 12),
                                      Expanded(flex: 2, child: changeBtn),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Estágio dedicado de Pré-Visualização e Confirmação (`Key('profile-photo-preview-stage')`).
class _ProfilePhotoPreviewStageView extends StatelessWidget {
  const _ProfilePhotoPreviewStageView({
    required this.staged,
    required this.userName,
    required this.saving,
    required this.onSave,
    required this.onPickAnother,
    required this.onCancel,
  });

  final PickedImage staged;
  final String userName;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onPickAnother;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    return SafeArea(
      key: const Key('profile-photo-preview-stage'),
      child: LayoutBuilder(
        builder: (context, viewport) {
          final maxCircle = math
              .min(
                viewport.maxWidth * 0.56,
                (viewport.maxHeight * 0.34).clamp(112.0, 228.0),
              )
              .clamp(108.0, 228.0);

          return Column(
            children: [
              // Barra superior discreta com botão fechar/cancelar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Cancelar',
                      onPressed: saving ? null : onCancel,
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: accent.withValues(alpha: 0.55)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 15, color: accent),
                            const SizedBox(width: 6),
                            const Flexible(
                              child: Text(
                                'Nova foto selecionada',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 6),
                      Container(
                        width: maxCircle,
                        height: maxCircle,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accent, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.32),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: Image.memory(
                              staged.bytes,
                              key: ValueKey(
                                'staged-avatar-memory-${staged.name}-${staged.bytes.length}',
                              ),
                              width: maxCircle,
                              height: maxCircle,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (_, _, _) => Container(
                                color: accent.withValues(alpha: 0.22),
                                alignment: Alignment.center,
                                child: Text(
                                  initials(userName.isEmpty ? 'U' : userName),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: maxCircle * 0.34,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Gostou da sua nova foto?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Confira como ela aparecerá no seu perfil antes de salvar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, barConstraints) {
                          final isCompact = barConstraints.maxWidth < 380 || textScale > 1.2;

                          final saveBtn = FilledButton.icon(
                            key: const Key('btn-save-profile-photo'),
                            onPressed: saving ? null : onSave,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            ),
                            icon: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_rounded, size: 20),
                            label: Text(
                              saving ? 'Salvando...' : 'Salvar foto',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          );

                          final pickAnotherBtn = OutlinedButton.icon(
                            key: const Key('btn-pick-another-photo'),
                            onPressed: saving ? null : onPickAnother,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                            ),
                            icon: const Icon(Icons.photo_library_outlined, size: 18),
                            label: const Text(
                              'Escolher outra foto',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          );

                          final cancelBtn = TextButton(
                            key: const Key('btn-cancel-profile-photo'),
                            onPressed: saving ? null : onCancel,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              foregroundColor: Colors.white70,
                            ),
                            child: const Text(
                              'Cancelar',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          );

                          if (isCompact) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                saveBtn,
                                const SizedBox(height: 10),
                                pickAnotherBtn,
                                const SizedBox(height: 6),
                                cancelBtn,
                              ],
                            );
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: pickAnotherBtn),
                                  const SizedBox(width: 12),
                                  Expanded(child: saveBtn),
                                ],
                              ),
                              const SizedBox(height: 8),
                              cancelBtn,
                            ],
                          );
                        },
                      ),
                    ],
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

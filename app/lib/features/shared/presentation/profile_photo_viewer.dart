import 'dart:math' as math;
import 'dart:typed_data';

import 'package:desperrengue_app/core/ui/design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../core/services/app_session.dart';
import '../../../core/services/instant_image_cache_engine.dart';
import '../../../core/services/media_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/ui/image_picking.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';

/// Escolhe uma foto, envia e grava no perfil. Devolve a nova URL (null se cancelou).
typedef ProfilePhotoChanger = Future<String?> Function(BuildContext context);

/// Seletor injetável para testes determinísticos da etapa 1 (escolha da foto em memória, sem upload).
typedef StagedPhotoPicker = Future<PickedImage?> Function(BuildContext context);

/// Uploader binário injetável para testes determinísticos da etapa 2 (confirmação em `Salvar foto`).
typedef AvatarBinaryUploader = Future<String> Function(Uint8List bytes, String ext);

/// Monta tokens escuros preservando o acento do modo ativo (cliente/profissional/marca)
/// para superfícies escuras de visualização de foto (lightbox) mesmo no tema claro.
AppTokens _viewerDarkTokens(BuildContext context) {
  final current = context.tk;
  if (current.accent == current.clientAccent) {
    return AppTokens.dark.forAccent(
      accent: AppTokens.dark.clientAccent,
      accentInk: AppTokens.dark.clientAccentInk,
      accentSoft: AppTokens.dark.clientSoft,
    );
  }
  if (current.accent == current.providerAccent) {
    return AppTokens.dark.forAccent(
      accent: AppTokens.dark.providerAccent,
      accentInk: AppTokens.dark.providerAccentInk,
      accentSoft: AppTokens.dark.providerSoft,
    );
  }
  return AppTokens.dark;
}

ThemeData _viewerDarkTheme(BuildContext context, AppTokens darkTk) {
  final base = Theme.of(context);
  return base.copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkTk.surfaceInset,
    colorScheme: base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: darkTk.accent,
      onPrimary: darkTk.onAccent,
      surface: darkTk.background,
      onSurface: darkTk.text,
    ),
    extensions: [darkTk],
  );
}

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
    AppRoute<String>(
      opaque: false,
      fullscreenModal: true,
      barrierColor: AppTokens.dark.surfaceInset.withValues(alpha: 0.92),
      builder: (_) => ProfilePhotoPreviewAndSaveDialog(
        initialImage: picked,
        userName: userName,
        currentUrl: currentUrl,
        customPicker: customPicker,
        customUploader: customUploader,
      ),
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
      AppRoute<String>(
        opaque: false,
        fullscreenModal: true,
        barrierColor: AppTokens.dark.surfaceInset,
        builder: (_) => ProfilePhotoViewerScreen(
          url: _url,
          name: widget.name,
          changer: widget.changer,
          customPicker: widget.customPicker,
          customUploader: widget.customUploader,
          heroTag: _heroTag,
        ),
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
    final tk = context.tk;
    return Semantics(
      button: true,
      label: 'Foto de perfil. Toque para ver e alterar.',
      child: GestureDetector(
        key: const ValueKey('editable-avatar'),
        onTap: _open,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AppHero(
              tag: _heroTag,
              child: AppAvatar(
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
                padding: const EdgeInsets.all(AppSpace.s4),
                decoration: BoxDecoration(
                  color: tk.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: tk.background, width: 2),
                ),
                child: Icon(
                  Icons.photo_camera_rounded,
                  size: widget.radius * 0.36,
                  color: tk.onAccent,
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
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
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
      AppSnackbar.show(context, 'Foto de perfil salva com sucesso!', kind: AppSnackKind.success);
      Navigator.of(context).pop(url);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
      }
    }
  }

  void _cancel() {
    if (_saving) return;
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final darkTk = _viewerDarkTokens(context);
    return Theme(
      data: _viewerDarkTheme(context, darkTk),
      child: PopScope(
        canPop: !_saving,
        child: Scaffold(
          backgroundColor: darkTk.surfaceInset.withValues(alpha: 0.96),
          body: _ProfilePhotoPreviewStageView(
            staged: _staged,
            userName: widget.userName,
            saving: _saving,
            onSave: _save,
            onPickAnother: _pickAnother,
            onCancel: _cancel,
          ),
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
          AppSnackbar.show(context, 'Foto atualizada!', kind: AppSnackKind.success);
        }
      } catch (e) {
        if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
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
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
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
      if (mounted) AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
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
      AppSnackbar.show(context, 'Foto de perfil salva com sucesso!', kind: AppSnackKind.success);
      Navigator.of(context).pop(url);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        AppSnackbar.show(context, friendlyError(e), kind: AppSnackKind.error);
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
    final darkTk = _viewerDarkTokens(context);
    final staged = _stagedImage;

    return Theme(
      data: _viewerDarkTheme(context, darkTk),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !_busy) _close();
        },
        child: Scaffold(
          backgroundColor: darkTk.surfaceInset,
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
                                ? AppHero(
                                    tag: widget.heroTag ?? 'avatar',
                                    child: Image.network(
                                      _url!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => Icon(
                                        Icons.broken_image_outlined,
                                        color: darkTk.textMuted,
                                        size: 64,
                                      ),
                                      loadingBuilder: (_, child, p) => p == null ? child : const AppLoading(),
                                    ),
                                  )
                                : Container(
                                    key: const ValueKey('avatar-placeholder'),
                                    width: 220,
                                    height: 220,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: darkTk.accentSoft,
                                    ),
                                    child: Text(
                                      initials(widget.name),
                                      style: AppType.displayL.apply(fontSizeFactor: 2.0).copyWith(color: darkTk.accentInk),
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
                          padding: const EdgeInsets.all(AppSpace.s8),
                          child: AppIconButton(
                            tooltip: 'Fechar',
                            icon: Icons.close_rounded,
                            size: 28,
                            color: darkTk.text,
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
                              darkTk.surfaceInset.withValues(alpha: 0.94),
                              darkTk.surfaceInset.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpace.s24, AppSpace.s32, AppSpace.s24, AppSpace.s20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _hasPhoto
                                      ? 'Deseja alterar esta foto?'
                                      : 'Você ainda não tem foto de perfil.',
                                  key: const ValueKey('photo-question'),
                                  textAlign: TextAlign.center,
                                  style: AppType.title.copyWith(color: darkTk.text),
                                ),
                                const SizedBox(height: AppSpace.s4),
                                Text(
                                  'Uma boa foto passa confiança para quem vai receber você em casa.',
                                  textAlign: TextAlign.center,
                                  style: AppType.bodySm.copyWith(color: darkTk.textMuted),
                                ),
                                const SizedBox(height: AppSpace.s16),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                                    final stackButtons = constraints.maxWidth < 340 || textScale > 1.25;
                                    final closeBtn = AppButton(
                                      key: const ValueKey('photo-close'),
                                      label: 'Agora não',
                                      variant: AppButtonVariant.secondary,
                                      compact: true,
                                      onPressed: _busy ? null : _close,
                                    );
                                    final changeBtn = AppButton(
                                      key: const ValueKey('photo-change'),
                                      label: _hasPhoto ? 'Alterar foto' : 'Adicionar foto',
                                      icon: Icons.photo_camera_rounded,
                                      loading: _busy,
                                      compact: true,
                                      onPressed: _busy ? null : _change,
                                    );
                                    if (stackButtons) {
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          changeBtn,
                                          const SizedBox(height: AppSpace.s12),
                                          closeBtn,
                                        ],
                                      );
                                    }
                                    return Row(
                                      children: [
                                        Expanded(child: closeBtn),
                                        const SizedBox(width: AppSpace.s12),
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
    final tk = context.tk;
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
                padding: const EdgeInsets.fromLTRB(AppSpace.s12, AppSpace.s8, AppSpace.s12, AppSpace.s4),
                child: Row(
                  children: [
                    AppIconButton(
                      tooltip: 'Cancelar',
                      onPressed: saving ? null : onCancel,
                      icon: Icons.close_rounded,
                      size: 26,
                      color: tk.text,
                    ),
                    const SizedBox(width: AppSpace.s8),
                    const Expanded(
                      child: Center(
                        child: AppStatusChip(
                          'Nova foto selecionada',
                          tone: AppTone.accent,
                          icon: Icons.auto_awesome_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppGeometry.minTarget),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s20, vertical: AppSpace.s8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: AppSpace.s8),
                      Container(
                        width: maxCircle,
                        height: maxCircle,
                        padding: const EdgeInsets.all(AppSpace.s4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: tk.accent, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: tk.accent.withValues(alpha: 0.32),
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
                                color: tk.accentSoft,
                                alignment: Alignment.center,
                                child: Text(
                                  initials(userName.isEmpty ? 'U' : userName),
                                  style: AppType.displayL.copyWith(color: tk.accentInk),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.s20),
                      Text(
                        'Gostou da sua nova foto?',
                        textAlign: TextAlign.center,
                        style: AppType.headline.copyWith(color: tk.text),
                      ),
                      const SizedBox(height: AppSpace.s8),
                      Text(
                        'Confira como ela aparecerá no seu perfil antes de salvar.',
                        textAlign: TextAlign.center,
                        style: AppType.bodySm.copyWith(color: tk.textMuted),
                      ),
                      const SizedBox(height: AppSpace.s20),
                      LayoutBuilder(
                        builder: (context, barConstraints) {
                          final isCompact = barConstraints.maxWidth < 380 || textScale > 1.2;

                          final saveBtn = AppButton(
                            key: const Key('btn-save-profile-photo'),
                            label: saving ? 'Salvando...' : 'Salvar foto',
                            icon: Icons.check_circle_rounded,
                            loading: saving,
                            compact: true,
                            onPressed: saving ? null : onSave,
                          );

                          final pickAnotherBtn = AppButton(
                            key: const Key('btn-pick-another-photo'),
                            label: 'Escolher outra foto',
                            icon: Icons.photo_library_outlined,
                            variant: AppButtonVariant.secondary,
                            compact: true,
                            onPressed: saving ? null : onPickAnother,
                          );

                          final cancelBtn = AppButton(
                            key: const Key('btn-cancel-profile-photo'),
                            label: 'Cancelar',
                            variant: AppButtonVariant.tertiary,
                            compact: true,
                            onPressed: saving ? null : onCancel,
                          );

                          if (isCompact) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                saveBtn,
                                const SizedBox(height: AppSpace.s12),
                                pickAnotherBtn,
                                const SizedBox(height: AppSpace.s8),
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
                                  const SizedBox(width: AppSpace.s12),
                                  Expanded(child: saveBtn),
                                ],
                              ),
                              const SizedBox(height: AppSpace.s8),
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

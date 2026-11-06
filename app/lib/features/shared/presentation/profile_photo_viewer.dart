import 'package:flutter/material.dart';

import '../../../core/services/media_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/image_picking.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';

/// Escolhe uma foto, envia e grava no perfil. Devolve a nova URL (null se cancelou).
typedef ProfilePhotoChanger = Future<String?> Function(BuildContext context);

/// Troca a foto do PRÓPRIO usuário: câmera/galeria → `public-media` → `profiles.avatar_url`.
Future<String?> changeMyAvatar(BuildContext context) async {
  final img = await pickImage(context);
  if (img == null) return null;
  final url = await MediaService().uploadPublic(img.bytes, img.ext, prefix: 'avatar');
  await ProfileService().updateProfile({'avatar_url': url});
  // Atualiza o cache offline do perfil para a foto nova valer já na próxima abertura.
  try {
    await ProfileService().fetchCurrent();
  } catch (_) {}
  return url;
}

/// Foto de perfil tocável: abre a foto em tela cheia e PERGUNTA se o usuário quer trocá-la.
class EditableAvatar extends StatefulWidget {
  const EditableAvatar({
    super.key,
    required this.url,
    required this.name,
    this.radius = 36,
    this.verified = false,
    @visibleForTesting this.changer,
    this.onChanged,
  });

  final String? url;
  final String name;
  final double radius;
  final bool verified;
  final ProfilePhotoChanger? changer;
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
        pageBuilder: (_, _, _) => ProfilePhotoViewerScreen(url: _url, name: widget.name, changer: widget.changer ?? changeMyAvatar, heroTag: _heroTag),
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
            Hero(tag: _heroTag, child: UserAvatar(url: _url, name: widget.name, radius: widget.radius, verified: widget.verified)),
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
                child: Icon(Icons.photo_camera_rounded, size: widget.radius * 0.36, color: Theme.of(context).colorScheme.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Foto em tela cheia (zoom por pinça) + pergunta "Deseja alterar esta foto?".
class ProfilePhotoViewerScreen extends StatefulWidget {
  const ProfilePhotoViewerScreen({super.key, required this.url, required this.name, required this.changer, this.heroTag});

  final String? url;
  final String name;
  final ProfilePhotoChanger changer;
  final String? heroTag;

  @override
  State<ProfilePhotoViewerScreen> createState() => _ProfilePhotoViewerScreenState();
}

class _ProfilePhotoViewerScreenState extends State<ProfilePhotoViewerScreen> {
  late String? _url = widget.url;
  String? _changedTo;
  bool _busy = false;

  bool get _hasPhoto => _url != null && _url!.isNotEmpty;

  Future<void> _change() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final url = await widget.changer(context);
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
  }

  void _close() => Navigator.of(context).pop(_changedTo);

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
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
                              errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
                              loadingBuilder: (_, child, p) => p == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
                            ),
                          )
                        : Container(
                            key: const ValueKey('avatar-placeholder'),
                            width: 220,
                            height: 220,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.22)),
                            child: Text(initials(widget.name), style: TextStyle(color: accent, fontSize: 80, fontWeight: FontWeight.w800)),
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
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withValues(alpha: 0.92), Colors.transparent]),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _hasPhoto ? 'Deseja alterar esta foto?' : 'Você ainda não tem foto de perfil.',
                          key: const ValueKey('photo-question'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Uma boa foto passa confiança para quem vai receber você em casa.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, height: 1.35),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                key: const ValueKey('photo-close'),
                                onPressed: _busy ? null : _close,
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
                                child: const Text('Agora não'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                key: const ValueKey('photo-change'),
                                onPressed: _busy ? null : _change,
                                icon: _busy
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.photo_camera_rounded),
                                label: Text(_hasPhoto ? 'Alterar foto' : 'Adicionar foto'),
                              ),
                            ),
                          ],
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

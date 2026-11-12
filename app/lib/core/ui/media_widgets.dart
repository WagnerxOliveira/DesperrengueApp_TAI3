import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/marketplace_models.dart';
import '../services/instant_image_cache_engine.dart';
import '../services/media_service.dart';
import '../utils/format.dart';
import './app_tokens.dart';
import 'app_theme.dart';
import 'category_brand_emblem.dart';

export 'category_brand_emblem.dart';
export 'duotone_service_icons.dart';

bool _isFlutterTestEnvironment() {
  final bindingName = WidgetsBinding.instance.runtimeType.toString();
  return bindingName.contains('Test') || bindingName.contains('AutomatedTest');
}

IconData categoryIcon(String name) {
  switch (name) {
    case 'Elétrica':
      return Icons.bolt_rounded;
    case 'Encanador':
      return Icons.plumbing_rounded;
    case 'Limpeza':
      return Icons.cleaning_services_rounded;
    case 'Montagem':
      return Icons.chair_alt_rounded;
    case 'Pintura':
      return Icons.format_paint_rounded;
    case 'Chaveiro':
      return Icons.vpn_key_rounded;
    case 'Pedreiro':
      return Icons.construction_rounded;
    case 'Gesso':
      return Icons.light_rounded;
    case 'Marcenaria':
      return Icons.carpenter_rounded;
    case 'Ar-condicionado':
      return Icons.air_rounded;
    case 'Pequenos Reparos':
      return Icons.home_repair_service_rounded;
    case 'Jardinagem':
      return Icons.yard_rounded;
    case 'Dedetização':
      return Icons.pest_control_rounded;
    case 'Vidraceiro':
      return Icons.sensor_window_rounded;
    case 'Serralheria':
      return Icons.fence_rounded;
    case 'Telhados e Calhas':
      return Icons.roofing_rounded;
    case 'Impermeabilização':
      return Icons.shield_rounded;
    case 'Desentupidora':
      return Icons.water_drop_rounded;
    case 'Piscina':
      return Icons.pool_rounded;
    case 'Eletrodomésticos':
      return Icons.local_laundry_service_rounded;
    case 'TV e Antenas':
      return Icons.connected_tv_rounded;
    case 'Câmeras e Alarmes':
      return Icons.security_rounded;
    case 'Portões e Interfones':
      return Icons.settings_remote_rounded;
    case 'Energia Solar':
      return Icons.solar_power_rounded;
    case 'Gás e Aquecedores':
      return Icons.local_fire_department_rounded;
    case 'Pisos e Revestimentos':
      return Icons.layers_rounded;
    case 'Cortinas e Persianas':
      return Icons.curtains_rounded;
    case 'Estofados e Tapetes':
      return Icons.weekend_rounded;
    case 'Mudanças e Fretes':
      return Icons.local_shipping_rounded;
    case 'Informática e Redes':
      return Icons.wifi_tethering_rounded;
    case 'Cuidador de Idosos':
      return Icons.elderly_rounded;
    case 'Babá':
      return Icons.child_care_rounded;
    case 'Pet Care':
      return Icons.pets_rounded;
    default:
      return Icons.handyman_rounded;
  }
}

Color categoryColor(String name) {
  final spec = resolveCategoryBrandSpec(name);
  for (final c in kCategories) {
    if (c.name == name) return spec.primaryColor.withValues(alpha: 0.20);
  }
  return AppColors.surface;
}

/// Componente universal de imagem de latência zero (`0 ms`).
///
/// Consulta sincronamente o cache L1 em RAM (`InstantImageCacheEngine.instance.peekMemoryBytes`)
/// durante o `build()`. Se os bytes já estiverem em memória, renderiza `MemoryImage`
/// (com `ResizeImage` opcional e `gaplessPlayback: true`) no exato primeiro frame (`0 ms`),
/// sem piscada, sem placeholder e sem spinner.
class InstantCachedImage extends StatefulWidget {
  const InstantCachedImage({
    super.key,
    this.url,
    this.storagePath,
    this.path,
    this.isPrivateStorage = false,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 12,
    this.borderRadius,
    this.cacheWidth,
    this.cacheHeight,
    this.placeholder,
    this.errorWidget,
    this.semanticLabel,
  });

  /// URL pública (ou caminho público no bucket).
  final String? url;

  /// Caminho em bucket privado do Supabase Storage (`job-photos`, etc.).
  final String? storagePath;

  /// Atalho compatível que aceita tanto URL pública quanto caminho de storage.
  final String? path;

  /// Quando `true`, interpreta [path] como caminho privado do Supabase Storage.
  final bool isPrivateStorage;

  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;
  final BorderRadius? borderRadius;
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget? placeholder;
  final Widget? errorWidget;
  final String? semanticLabel;

  @override
  State<InstantCachedImage> createState() => _InstantCachedImageState();
}

class _InstantCachedImageState extends State<InstantCachedImage> {
  Uint8List? _asyncBytes;
  String? _fallbackNetworkUrl;
  bool _loading = false;
  bool _failed = false;

  bool get _treatAsPrivateStorage {
    if (widget.storagePath != null && widget.storagePath!.trim().isNotEmpty) {
      return true;
    }
    return widget.isPrivateStorage;
  }

  String _rawSource() {
    if (widget.storagePath != null && widget.storagePath!.trim().isNotEmpty) {
      return widget.storagePath!.trim();
    }
    if (widget.url != null && widget.url!.trim().isNotEmpty) {
      return widget.url!.trim();
    }
    if (widget.path != null && widget.path!.trim().isNotEmpty) {
      return widget.path!.trim();
    }
    return '';
  }

  String? _resolvedPublicUrl(String raw) {
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (_treatAsPrivateStorage) return null;
    try {
      return MediaService().publicUrl(raw);
    } catch (_) {
      return raw;
    }
  }

  Uint8List? _peekSynchronousBytes(String raw) {
    if (raw.isEmpty) return null;
    final engine = InstantImageCacheEngine.instance;
    final direct = engine.peekMemoryBytes(raw);
    if (direct != null) return direct;
    if (_treatAsPrivateStorage) {
      final byStorage = engine.peekMemoryBytes(
        InstantImageCacheEngine.storageCacheKey(raw),
      );
      if (byStorage != null) return byStorage;
    } else {
      final resolved = _resolvedPublicUrl(raw);
      if (resolved != null) {
        final byResolved = engine.peekMemoryBytes(resolved);
        if (byResolved != null) return byResolved;
      }
    }
    return _asyncBytes;
  }

  @override
  void initState() {
    super.initState();
    _ensureLoaded();
  }

  @override
  void didUpdateWidget(covariant InstantCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.storagePath != widget.storagePath ||
        oldWidget.path != widget.path ||
        oldWidget.isPrivateStorage != widget.isPrivateStorage) {
      _asyncBytes = null;
      _fallbackNetworkUrl = null;
      _failed = false;
      _ensureLoaded();
    }
  }

  Future<void> _ensureLoaded() async {
    final raw = _rawSource();
    if (raw.isEmpty) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }

    final syncHit = _peekSynchronousBytes(raw);
    if (syncHit != null) {
      _asyncBytes = syncHit;
      _loading = false;
      _failed = false;
      return;
    }

    setState(() {
      _loading = true;
      _failed = false;
    });

    final engine = InstantImageCacheEngine.instance;
    try {
      if (_treatAsPrivateStorage &&
          !raw.startsWith('http://') &&
          !raw.startsWith('https://')) {
        final bytes = await engine.getOrFetchSignedStorageBytes(raw);
        if (!mounted) return;
        if (bytes != null && bytes.isNotEmpty) {
          setState(() {
            _asyncBytes = bytes;
            _loading = false;
          });
          return;
        }
        // Fallback para URL assinada direta caso CORS bloqueie leitura de bytes na Web.
        final signed = await MediaService().signedUrl(raw);
        if (!mounted) return;
        setState(() {
          _fallbackNetworkUrl = signed;
          _loading = false;
          _failed = signed == null || signed.isEmpty;
        });
      } else {
        final resolved = _resolvedPublicUrl(raw) ?? raw;
        final bytes = await engine.getOrFetchUrlBytes(resolved);
        if (!mounted) return;
        if (bytes != null && bytes.isNotEmpty) {
          setState(() {
            _asyncBytes = bytes;
            _loading = false;
          });
          return;
        }
        setState(() {
          _fallbackNetworkUrl = resolved;
          _loading = false;
          _failed = resolved.isEmpty;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  int? _effectiveCacheWidth(BuildContext context) {
    if (widget.cacheWidth != null) return widget.cacheWidth;
    final w = widget.width;
    if (w != null && w.isFinite && w > 0) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      return (w * dpr).round().clamp(64, 1920);
    }
    return null;
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (widget.placeholder != null) return widget.placeholder!;
    final isDark = context.tk.isDark;
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  context.tk.surface,
                  context.tk.raised.withValues(alpha: 0.85),
                ]
              : [
                  context.tk.raised,
                  context.tk.surface,
                ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.photo_outlined,
          size: 20,
          color: context.tk.textMuted.withValues(alpha: 0.38),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    if (widget.errorWidget != null) return widget.errorWidget!;
    return Container(
      width: widget.width,
      height: widget.height,
      color: context.tk.surface,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: context.tk.textMuted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final raw = _rawSource();
    final effectiveRadius =
        widget.borderRadius ?? BorderRadius.circular(widget.radius);

    // Caminho crítico 0 ms: se os bytes já estão no cache L1 em RAM, retorna
    // imediatamente no primeiro frame sem qualquer assincronismo.
    final memoryBytes = _peekSynchronousBytes(raw);
    Widget content;
    if (memoryBytes != null && memoryBytes.isNotEmpty) {
      final provider = InstantImageCacheEngine.instance.buildMemoryProvider(
        memoryBytes,
        cacheWidth: _effectiveCacheWidth(context),
        cacheHeight: widget.cacheHeight,
      );
      content = Image(
        image: provider,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        semanticLabel: widget.semanticLabel,
        errorBuilder: (_, _, _) => _buildError(context),
      );
    } else if (_loading) {
      content = _buildPlaceholder(context);
    } else if (_fallbackNetworkUrl != null &&
        _fallbackNetworkUrl!.isNotEmpty &&
        !_isFlutterTestEnvironment()) {
      content = Image.network(
        _fallbackNetworkUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        semanticLabel: widget.semanticLabel,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return _buildPlaceholder(ctx);
        },
        errorBuilder: (_, _, _) => _buildError(context),
      );
    } else if (_failed || raw.isEmpty) {
      content = _buildError(context);
    } else {
      content = _buildPlaceholder(context);
    }

    final sized = SizedBox(
      width: widget.width,
      height: widget.height,
      child: content,
    );

    if (effectiveRadius == BorderRadius.zero) {
      return sized;
    }
    return ClipRRect(
      borderRadius: effectiveRadius,
      child: sized,
    );
  }
}

/// Avatar circular/squircle premium com renderização instantânea em `0 ms`
/// via `InstantImageCacheEngine.instance.peekMemoryBytes`, `ResizeImage`
/// calibrado pelo `radius * devicePixelRatio`, `gaplessPlayback: true` e
/// iniciais estilizadas sem jamais exibir buraco preto ou pop-in tardio.
class InstantUserAvatar extends StatefulWidget {
  const InstantUserAvatar({
    super.key,
    this.url,
    required this.name,
    this.radius = 24,
    this.verified = false,
    this.isSquircle = false,
    this.accentColor,
  });

  final String? url;
  final String name;
  final double radius;
  final bool verified;
  final bool isSquircle;
  final Color? accentColor;

  @override
  State<InstantUserAvatar> createState() => _InstantUserAvatarState();
}

class _InstantUserAvatarState extends State<InstantUserAvatar> {
  Uint8List? _asyncBytes;
  bool _fetchAttempted = false;

  String? _resolvedUrl() {
    final raw = widget.url?.trim() ?? '';
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    try {
      return MediaService().publicUrl(raw);
    } catch (_) {
      return raw;
    }
  }

  Uint8List? _peekSyncBytes() {
    final raw = widget.url?.trim() ?? '';
    if (raw.isEmpty) return null;
    final engine = InstantImageCacheEngine.instance;
    final direct = engine.peekMemoryBytes(raw);
    if (direct != null) return direct;
    final resolved = _resolvedUrl();
    if (resolved != null) {
      final byResolved = engine.peekMemoryBytes(resolved);
      if (byResolved != null) return byResolved;
    }
    return _asyncBytes;
  }

  @override
  void initState() {
    super.initState();
    _ensureAvatarCached();
  }

  @override
  void didUpdateWidget(covariant InstantUserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _asyncBytes = null;
      _fetchAttempted = false;
      _ensureAvatarCached();
    }
  }

  Future<void> _ensureAvatarCached() async {
    final resolved = _resolvedUrl();
    if (resolved == null || resolved.isEmpty) return;
    final syncBytes = _peekSyncBytes();
    if (syncBytes != null) {
      _asyncBytes = syncBytes;
      return;
    }
    try {
      final bytes =
          await InstantImageCacheEngine.instance.getOrFetchUrlBytes(resolved);
      if (!mounted) return;
      setState(() {
        _asyncBytes = bytes;
        _fetchAttempted = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _fetchAttempted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? Theme.of(context).colorScheme.primary;
    final diameter = widget.radius * 2;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final targetPx = (diameter * dpr).round().clamp(48, 512);

    final initialsWidget = Center(
      child: Text(
        initials(widget.name),
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w800,
          fontSize: widget.radius * 0.7,
        ),
      ),
    );

    final resolved = _resolvedUrl();
    final memoryBytes = _peekSyncBytes();

    Widget? imageChild;
    if (memoryBytes != null && memoryBytes.isNotEmpty) {
      final provider = InstantImageCacheEngine.instance.buildMemoryProvider(
        memoryBytes,
        cacheWidth: targetPx,
      );
      imageChild = Image(
        image: provider,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => initialsWidget,
      );
    } else if (resolved != null &&
        resolved.isNotEmpty &&
        _fetchAttempted &&
        !_isFlutterTestEnvironment()) {
      imageChild = Image.network(
        resolved,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => initialsWidget,
      );
    }

    final Widget avatarCore;
    if (widget.isSquircle) {
      final sqRadius = BorderRadius.circular(widget.radius * 0.68);
      avatarCore = Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: sqRadius,
          border: Border.all(
            color: accent.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: sqRadius,
          child: imageChild ?? initialsWidget,
        ),
      );
    } else {
      avatarCore = CircleAvatar(
        radius: widget.radius,
        backgroundColor: accent.withValues(alpha: 0.14),
        child: imageChild != null
            ? ClipOval(
                child: SizedBox(
                  width: diameter,
                  height: diameter,
                  child: imageChild,
                ),
              )
            : initialsWidget,
      );
    }

    if (!widget.verified) return avatarCore;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatarCore,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: context.tk.card,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_rounded,
              color: context.tk.info,
              size: widget.radius * 0.6,
            ),
          ),
        ),
      ],
    );
  }
}

/// Imagem de bucket PRIVADO (URL assinada, com cache L1/L2 em 0 ms).
class SignedImage extends StatelessWidget {
  const SignedImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 12,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return InstantCachedImage(
      storagePath: path,
      isPrivateStorage: true,
      width: width,
      height: height,
      fit: fit,
      radius: radius,
    );
  }
}

/// Imagem de bucket PÚBLICO (portfólio/avatar) a partir do caminho salvo (com cache L1 em 0 ms).
class PublicImage extends StatelessWidget {
  const PublicImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 12,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return InstantCachedImage(
      path: path,
      isPrivateStorage: false,
      width: width,
      height: height,
      fit: fit,
      radius: radius,
    );
  }
}

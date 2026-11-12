import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/image_metadata_stripper.dart';

/// Upload e URLs de mídia.
///  * `public-media`: avatar e portfólio (URL pública, qualquer logado vê).
///  * `job-media`: fotos do pedido, evidências e provas de suporte (privado;
///    acesso por URL assinada, liberado por policy a quem participa do pedido).
///
/// LGPD (contrato B.3): TODA imagem passa por [sanitizeForUpload] antes de sair
/// do aparelho, removendo EXIF/GPS/XMP/IPTC. Sem isso, a foto de um problema
/// na casa do cliente entregaria a coordenada exata ao profissional antes do
/// desbloqueio do endereço.
class MediaService {
  MediaService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const publicBucket = 'public-media';
  static const privateBucket = 'job-media';

  /// Validade pedida ao Storage para URLs assinadas.
  static const int signedUrlTtlSeconds = 3600;

  /// Reaproveitamos a URL só enquanto faltar folga suficiente para o aparelho
  /// terminar de baixar (antes ficava em cache para sempre → 403 após 1 h).
  static const Duration _signedCacheLifetime = Duration(minutes: 50);
  static const int _signedCacheMaxEntries = 300;

  static final Map<String, _SignedEntry> _signedCache = <String, _SignedEntry>{};

  /// Limpa URLs assinadas (chamar no logout).
  static void clearSignedCache() => _signedCache.clear();

  /// Acima deste tamanho a higienização roda em isolate (Web: inline).
  @visibleForTesting
  static const int isolateThresholdBytes = 1536 * 1024;

  String get _uid {
    final u = _client.auth.currentUser;
    if (u == null) throw const AuthException('Sessão expirada.');
    return u.id;
  }

  static String mime(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      default:
        return 'image/jpeg';
    }
  }

  static String extOf(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return 'jpg';
    final e = name.substring(i + 1).toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp'}.contains(e) ? (e == 'jpeg' ? 'jpg' : e) : 'jpg';
  }

  static bool _isVideoExt(String ext) {
    final e = ext.toLowerCase();
    return e == 'mp4' || e == 'mov';
  }

  /// Extensão segura para compor o caminho no Storage (nada de `../`).
  static String _safeExt(String ext) {
    final e = ext.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (e.isEmpty || e.length > 5) return 'jpg';
    return e == 'jpeg' ? 'jpg' : e;
  }

  /// Remove EXIF/GPS (e demais metadados) de [bytes] e devolve extensão e MIME
  /// coerentes com o conteúdo REAL (magic bytes), não com o nome do arquivo.
  ///
  /// * Vídeo (`mp4`/`mov`) passa direto (não é foto do pedido).
  /// * Imagens grandes são processadas em isolate (`compute`) para não travar
  ///   a UI; na Web roda inline.
  /// * Formato desconhecido/corrompido lança [ImageMetadataException] (falha
  ///   fechada: não enviamos o que não conseguimos higienizar).
  static Future<SanitizedMedia> sanitizeForUpload(Uint8List bytes, String ext) async {
    final safe = _safeExt(ext);
    if (_isVideoExt(safe)) {
      return SanitizedMedia(bytes, safe, mime(safe));
    }
    final Uint8List? clean = bytes.lengthInBytes >= isolateThresholdBytes
        ? await compute(_stripInIsolate, bytes)
        : _stripInIsolate(bytes);
    if (clean == null) {
      throw const ImageMetadataException(
        'Não foi possível preparar a foto com segurança. Tente outra imagem (JPG, PNG ou WebP).',
      );
    }
    final String realExt;
    final String realMime;
    switch (ImageMetadataStripper.sniff(clean)) {
      case ImageContainer.png:
        realExt = 'png';
        realMime = 'image/png';
      case ImageContainer.webp:
        realExt = 'webp';
        realMime = 'image/webp';
      case ImageContainer.jpeg:
      case ImageContainer.unknown:
        realExt = 'jpg';
        realMime = 'image/jpeg';
    }
    return SanitizedMedia(clean, realExt, realMime);
  }

  /// Top-level-like (estática) para poder ir ao isolate. `null` = falhou.
  static Uint8List? _stripInIsolate(Uint8List bytes) {
    try {
      return ImageMetadataStripper.strip(bytes);
    } catch (_) {
      return null;
    }
  }

  static final math.Random _rng = math.Random();

  /// `<uid>/<prefix>_<µs>_<rand>.<ext>`: único mesmo em duplo-toque no mesmo
  /// milissegundo (upsert:false derrubava o segundo envio com 409).
  String _newPath(String prefix, String ext) {
    final safePrefix = prefix.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final salt = _rng.nextInt(0x7fffffff).toRadixString(36);
    return '$_uid/${safePrefix.isEmpty ? 'img' : safePrefix}_${DateTime.now().microsecondsSinceEpoch}_$salt.$ext';
  }

  /// Envia para `public-media/<uid>/<prefix>_<ts>.<ext>` e devolve a URL pública.
  Future<String> uploadPublic(Uint8List bytes, String ext, {String prefix = 'img'}) async {
    final path = await _upload(publicBucket, bytes, ext, prefix);
    return _client.storage.from(publicBucket).getPublicUrl(path);
  }

  /// Caminho de armazenamento (para guardar no banco) de um upload público.
  Future<String> uploadPublicPath(Uint8List bytes, String ext, {String prefix = 'img'}) =>
      _upload(publicBucket, bytes, ext, prefix);

  String publicUrl(String path) => _client.storage.from(publicBucket).getPublicUrl(path);

  /// Envia para `job-media/<uid>/<prefix>_<ts>.<ext>` e devolve o caminho.
  Future<String> uploadPrivate(Uint8List bytes, String ext, {String prefix = 'img'}) =>
      _upload(privateBucket, bytes, ext, prefix);

  Future<String> _upload(String bucket, Uint8List bytes, String ext, String prefix) async {
    final media = await sanitizeForUpload(bytes, ext);
    final path = _newPath(prefix, media.ext);
    await _client.storage.from(bucket).uploadBinary(
          path,
          media.bytes,
          fileOptions: FileOptions(contentType: media.mime, upsert: false),
        );
    return path;
  }

  Future<String?> signedUrl(String path) async {
    final now = DateTime.now();
    final cached = _signedCache[path];
    if (cached != null) {
      if (now.isBefore(cached.expiresAt)) return cached.url;
      _signedCache.remove(path);
    }
    try {
      final url = await _client.storage.from(privateBucket).createSignedUrl(path, signedUrlTtlSeconds);
      if (_signedCache.length >= _signedCacheMaxEntries) {
        _signedCache.remove(_signedCache.keys.first); // FIFO simples
      }
      _signedCache[path] = _SignedEntry(url, now.add(_signedCacheLifetime));
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<void> removePrivate(String path) async {
    await _client.storage.from(privateBucket).remove([path]);
    _signedCache.remove(path);
  }
}

/// Mídia pronta para upload (metadados removidos).
@immutable
class SanitizedMedia {
  const SanitizedMedia(this.bytes, this.ext, this.mime);
  final Uint8List bytes;
  final String ext;
  final String mime;
}

class _SignedEntry {
  const _SignedEntry(this.url, this.expiresAt);
  final String url;
  final DateTime expiresAt;
}

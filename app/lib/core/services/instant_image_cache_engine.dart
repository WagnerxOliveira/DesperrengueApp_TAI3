import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/marketplace_models.dart';
import 'media_service.dart';
import 'provider_service.dart';

class _SignedUrlMemo {
  const _SignedUrlMemo({
    required this.url,
    required this.expiresAt,
  });

  final String url;
  final DateTime expiresAt;

  bool isValidAt(DateTime now) => now.isBefore(expiresAt);
}

/// Motor multiplataforma (Web/PWA, Android e iOS — ZERO `dart:io`) de cache de imagens
/// de latência zero (`0 ms`), combinando:
/// - **L1 Síncrona em RAM (`LinkedHashMap<String, Uint8List>` LRU, teto 96 MB)** para
///   renderização no primeiro frame sem `FutureBuilder` piscando;
/// - **Deduplicação `_inFlight`** para requisições simultâneas na mesma chave;
/// - **Memoização de URLs assinadas por 45 min** indexadas pela chave estável `'storage:$path'`;
/// - **L2 Persistente leve (`SharedPreferences`)** para avatares compactos entre sessões.
class InstantImageCacheEngine {
  InstantImageCacheEngine({
    this.maxMemoryBytes = 96 << 20, // 96 MB L1 RAM
    this.maxPersistedItemBytes = 96 * 1024, // Avatares/ícones <= 96 KB na L2
    this.maxPersistedEntries = 48,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static final InstantImageCacheEngine instance = InstantImageCacheEngine();

  final int maxMemoryBytes;
  final int maxPersistedItemBytes;
  final int maxPersistedEntries;
  final DateTime Function() _clock;

  static const Duration kSignedUrlTtl = Duration(minutes: 45);
  static const Duration kNetworkTimeout = Duration(seconds: 8);
  static const String _kPersistentL2Key = 'carbon_instant_img_l2_v1';

  final LinkedHashMap<String, Uint8List> _l1Memory =
      LinkedHashMap<String, Uint8List>();
  int _currentMemoryBytes = 0;

  final Map<String, Future<Uint8List?>> _inFlight =
      <String, Future<Uint8List?>>{};
  final Map<String, _SignedUrlMemo> _signedUrlMemo =
      <String, _SignedUrlMemo>{};

  final LinkedHashMap<String, String> _l2Base64 =
      LinkedHashMap<String, String>();
  bool _l2Hydrated = false;
  Future<void>? _l2HydratingFuture;

  final http.Client _sharedClient = http.Client();

  /// Quantidade atual de entradas residentes na camada L1 em RAM.
  int get memoryEntryCount => _l1Memory.length;

  /// Total atual de bytes alocados na camada L1 em RAM.
  int get currentMemoryBytes => _currentMemoryBytes;

  /// Chave canônica estável para objetos privados do Supabase Storage.
  static String storageCacheKey(String storagePath) =>
      'storage:${storagePath.trim()}';

  /// Chave canônica para URLs públicas.
  static String urlCacheKey(String url) => url.trim();

  static bool _isFlutterTestBinding() {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  /// Ajusta o `ImageCache` global do Flutter (`500` imagens / `250 MB`) com segurança total
  /// (no-op seguro caso o `PaintingBinding` ainda não esteja inicializado).
  void configureGlobalImageCache() {
    try {
      final cache = PaintingBinding.instance.imageCache;
      cache.maximumSize = 500;
      // 128 MB de pixels decodificados: dá folga p/ listas com avatares/fotos sem
      // estourar RAM de aparelhos de entrada (Android Go/3 GB), onde 250 MB causava
      // kills em segundo plano. L1 (bytes comprimidos) tem teto próprio de 96 MB.
      cache.maximumSizeBytes = 128 << 20;
    } catch (_) {
      // No-op seguro se o binding ainda não estiver pronto.
    }
  }

  Uint8List? _touchL1(String key) {
    final existing = _l1Memory.remove(key);
    if (existing != null) {
      _l1Memory[key] = existing;
    }
    return existing;
  }

  /// Lookup **100% síncrono (`0 ms`)** na camada L1 em RAM.
  ///
  /// Quando presente, permite que `Image(image: buildMemoryProvider(bytes), gaplessPlayback: true)`
  /// desenhe a imagem imediatamente no primeiro frame sem qualquer placeholder ou piscada.
  Uint8List? peekMemoryBytes(String cacheKey) {
    final clean = cacheKey.trim();
    if (clean.isEmpty) return null;
    final direct = _touchL1(clean);
    if (direct != null) return direct;
    if (!clean.startsWith('storage:') &&
        !clean.startsWith('http://') &&
        !clean.startsWith('https://')) {
      return _touchL1('storage:$clean');
    }
    return null;
  }

  /// Insere ou atualiza [bytes] na camada L1 em RAM respeitando o teto LRU ([maxMemoryBytes]).
  void putMemoryBytes(String cacheKey, Uint8List bytes) {
    final clean = cacheKey.trim();
    if (clean.isEmpty || bytes.isEmpty) return;
    if (bytes.lengthInBytes > maxMemoryBytes) return;

    final previous = _l1Memory.remove(clean);
    if (previous != null) {
      _currentMemoryBytes -= previous.lengthInBytes;
    }

    _l1Memory[clean] = bytes;
    _currentMemoryBytes += bytes.lengthInBytes;

    while (_currentMemoryBytes > maxMemoryBytes && _l1Memory.isNotEmpty) {
      final oldestKey = _l1Memory.keys.first;
      if (oldestKey == clean && _l1Memory.length == 1) break;
      final removed = _l1Memory.remove(oldestKey);
      if (removed != null) {
        _currentMemoryBytes -= removed.lengthInBytes;
      }
    }
  }

  /// Hidrata avatares/imagens compactas persistidas na camada L2 (`SharedPreferences`) para a L1.
  Future<void> ensurePersistentCacheLoaded() {
    if (_l2Hydrated) return Future<void>.value();
    return _l2HydratingFuture ??= _doHydrateL2();
  }

  Future<void> _doHydrateL2() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPersistentL2Key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final k = '${entry.key}'.trim();
            final b64 = entry.value;
            if (k.isNotEmpty && b64 is String && b64.isNotEmpty) {
              try {
                final bytes = base64Decode(b64);
                if (bytes.isNotEmpty) {
                  _l2Base64[k] = b64;
                  if (!_l1Memory.containsKey(k)) {
                    putMemoryBytes(k, bytes);
                  }
                }
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {
      // Melhor esforço em I/O multiplataforma.
    } finally {
      _l2Hydrated = true;
      _l2HydratingFuture = null;
    }
  }

  Future<void> _persistToL2IfCompact(String key, Uint8List bytes) async {
    if (bytes.isEmpty || bytes.lengthInBytes > maxPersistedItemBytes) return;
    // LGPD: mídia PRIVADA (`storage:<path>` = fotos do pedido/evidências) fica só em
    // RAM (L1). A L2 é texto puro no SharedPreferences e sobrevive ao logout; ela
    // guarda apenas imagens públicas (avatares/portfólio).
    if (key.startsWith('storage:')) return;
    try {
      await ensurePersistentCacheLoaded();
      _l2Base64.remove(key);
      _l2Base64[key] = base64Encode(bytes);
      while (_l2Base64.length > maxPersistedEntries) {
        _l2Base64.remove(_l2Base64.keys.first);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPersistentL2Key, jsonEncode(_l2Base64));
    } catch (_) {}
  }

  /// Verifica L1 (`0 ms`) -> deduplica downloads simultâneos em `_inFlight` -> verifica L2 ->
  /// baixa os bytes via HTTP -> armazena em L1 (e L2 para avatares compactos).
  Future<Uint8List?> getOrFetchUrlBytes(
    String url, {
    String? cacheKey,
    http.Client? client,
  }) {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return Future<Uint8List?>.value(null);
    final key = (cacheKey != null && cacheKey.trim().isNotEmpty)
        ? cacheKey.trim()
        : cleanUrl;

    final l1Hit = peekMemoryBytes(key);
    if (l1Hit != null) return Future<Uint8List?>.value(l1Hit);

    final active = _inFlight[key];
    if (active != null) return active;

    final future = _fetchUrlInternal(
      cleanUrl,
      key: key,
      client: client,
    );
    _inFlight[key] = future;
    future.whenComplete(() => _inFlight.remove(key));
    return future;
  }

  Future<Uint8List?> _fetchUrlInternal(
    String url, {
    required String key,
    http.Client? client,
  }) async {
    await ensurePersistentCacheLoaded();
    final afterHydration = peekMemoryBytes(key);
    if (afterHydration != null) return afterHydration;

    // Sob `flutter test` sem client injetado, evita tentar abrir socket HTTP real.
    if (client == null && _isFlutterTestBinding()) {
      return null;
    }

    try {
      final uri = Uri.tryParse(url);
      if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
        return null;
      }
      final res = await (client ?? _sharedClient)
          .get(uri)
          .timeout(kNetworkTimeout);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      final bytes = Uint8List.fromList(res.bodyBytes);
      putMemoryBytes(key, bytes);
      unawaited(_persistToL2IfCompact(key, bytes));
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Baixa e indexa objetos privados do Supabase Storage na camada L1 pela chave estável
  /// `'storage:$storagePath'` (independente do token temporário da URL assinada), além de
  /// memoizar a URL assinada por 45 minutos.
  Future<Uint8List?> getOrFetchSignedStorageBytes(
    String storagePath, {
    Future<String?> Function(String)? urlResolver,
    http.Client? client,
  }) {
    final cleanPath = storagePath.trim();
    if (cleanPath.isEmpty) return Future<Uint8List?>.value(null);

    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      return getOrFetchUrlBytes(cleanPath, client: client);
    }

    final key = storageCacheKey(cleanPath);
    final l1Hit = peekMemoryBytes(key);
    if (l1Hit != null) return Future<Uint8List?>.value(l1Hit);

    final active = _inFlight[key];
    if (active != null) return active;

    final future = _fetchSignedStorageInternal(
      cleanPath,
      key: key,
      urlResolver: urlResolver,
      client: client,
    );
    _inFlight[key] = future;
    future.whenComplete(() => _inFlight.remove(key));
    return future;
  }

  Future<Uint8List?> _fetchSignedStorageInternal(
    String cleanPath, {
    required String key,
    Future<String?> Function(String)? urlResolver,
    http.Client? client,
  }) async {
    await ensurePersistentCacheLoaded();
    final hydrated = peekMemoryBytes(key);
    if (hydrated != null) return hydrated;

    final now = _clock();
    var signedUrl = _signedUrlMemo[cleanPath]?.isValidAt(now) == true
        ? _signedUrlMemo[cleanPath]!.url
        : null;

    if (signedUrl == null) {
      try {
        signedUrl = urlResolver != null
            ? await urlResolver(cleanPath)
            : await _defaultSignedUrlResolver(cleanPath);
      } catch (_) {
        signedUrl = null;
      }
      if (signedUrl != null && signedUrl.trim().isNotEmpty) {
        _signedUrlMemo[cleanPath] = _SignedUrlMemo(
          url: signedUrl.trim(),
          expiresAt: now.add(kSignedUrlTtl),
        );
      }
    }

    if (signedUrl == null || signedUrl.trim().isEmpty) return null;

    if (client == null && _isFlutterTestBinding() && urlResolver == null) {
      return null;
    }

    try {
      final uri = Uri.tryParse(signedUrl);
      if (uri == null) return null;
      final res = await (client ?? _sharedClient)
          .get(uri)
          .timeout(kNetworkTimeout);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      final bytes = Uint8List.fromList(res.bodyBytes);
      putMemoryBytes(key, bytes);
      unawaited(_persistToL2IfCompact(key, bytes));
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _defaultSignedUrlResolver(String path) async {
    try {
      return await MediaService().signedUrl(path);
    } catch (_) {
      return null;
    }
  }

  /// Constrói um [ImageProvider] otimizado em memória com decodificação dimensionada via
  /// [ResizeImage.resizeIfNeeded] para economia de VRAM e 120 FPS constantes.
  ImageProvider<Object> buildMemoryProvider(
    Uint8List bytes, {
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return ResizeImage.resizeIfNeeded(
      cacheWidth,
      cacheHeight,
      MemoryImage(bytes),
    );
  }

  /// Verifica se os bytes correspondem a um cabeçalho de imagem válido (PNG/JPEG/GIF/WebP)
  /// antes de acionar decodificação antecipada de GPU.
  static bool looksLikeValidEncodedImage(Uint8List bytes) {
    if (bytes.lengthInBytes < 12) return false;
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true;
    }
    // GIF: 47 49 46 38
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return true;
    }
    // RIFF....WEBP
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    return false;
  }

  /// Logout / exclusão de conta: apaga L1, URLs assinadas memorizadas, L2 persistida
  /// e o `ImageCache` global (imagens decodificadas), para que nada do usuário
  /// anterior apareça — nem fique em disco — para o próximo.
  Future<void> purgeAllUserImages() async {
    clearForTesting(clearGlobalImageCache: true);
    _l2Hydrated = true; // nada a hidratar: acabamos de limpar
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPersistentL2Key);
    } catch (_) {}
  }

  @visibleForTesting
  void clearForTesting({bool clearGlobalImageCache = false}) {
    _l1Memory.clear();
    _currentMemoryBytes = 0;
    _inFlight.clear();
    _signedUrlMemo.clear();
    _l2Base64.clear();
    _l2Hydrated = false;
    _l2HydratingFuture = null;
    EagerImagePrefetcher._warmedProviderIds.clear();
    if (clearGlobalImageCache) {
      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (_) {}
    }
  }
}

/// Pré-aquecedor assíncrono não-bloqueante para aquecer avatares e fotos de pedidos em RAM
/// antes da abertura das telas de detalhes, perfil ou chat.
class EagerImagePrefetcher {
  const EagerImagePrefetcher._();

  static final Set<String> _warmedProviderIds = <String>{};

  /// Máximo de downloads de pré-carga simultâneos. Sem limite, abrir Meus Pedidos com
  /// 50 pedidos disparava 50+ requisições de uma vez (rede/CPU/jank).
  static const int maxConcurrentPrefetch = 4;

  static int _generation = 0;
  static int _active = 0;
  static final Queue<Future<void> Function()> _queue = Queue<Future<void> Function()>();

  /// Cancela o que ainda NÃO começou (chamar ao sair da tela). Downloads já
  /// em andamento terminam e ficam no cache; nada novo é iniciado para a tela morta.
  static void cancelPending() {
    _generation++;
    _queue.clear();
  }

  @visibleForTesting
  static int get debugQueuedPrefetches => _queue.length;

  static void _enqueue(Future<void> Function() job) {
    final gen = _generation;
    _queue.add(() async {
      if (gen != _generation) return;
      await job();
    });
    _pump();
  }

  static void _pump() {
    while (_active < maxConcurrentPrefetch && _queue.isNotEmpty) {
      final next = _queue.removeFirst();
      _active++;
      unawaited(next().catchError((_) {}).whenComplete(() {
        _active--;
        _pump();
      }));
    }
  }

  @visibleForTesting
  static Set<String> get debugWarmedProviderIds =>
      Set<String>.unmodifiable(_warmedProviderIds);

  /// Pré-carrega URLs públicas (avatares, portfólios) em background sem bloquear a UI.
  static void prefetchUrls(
    Iterable<String?> urls, {
    BuildContext? context,
    http.Client? client,
  }) {
    final engine = InstantImageCacheEngine.instance..configureGlobalImageCache();
    final seen = <String>{};
    for (final raw in urls) {
      final url = raw?.trim() ?? '';
      if (url.isEmpty || !seen.add(url)) continue;
      _enqueue(() => _warmUrl(engine, url, context: context, client: client));
    }
  }

  /// Pré-carrega caminhos do bucket público (`public-media`, como portfólio e fotos de avaliações)
  /// convertendo-os em URL pública sem bloquear a UI.
  static void prefetchPublicPaths(
    Iterable<String?> paths, {
    BuildContext? context,
    String Function(String)? publicUrlResolver,
    http.Client? client,
  }) {
    final resolvedUrls = <String>[];
    for (final raw in paths) {
      final clean = raw?.trim() ?? '';
      if (clean.isEmpty) continue;
      final lower = clean.toLowerCase();
      if (lower.endsWith('.mp4') || lower.endsWith('.mov')) continue;
      if (clean.startsWith('http://') || clean.startsWith('https://')) {
        resolvedUrls.add(clean);
      } else {
        try {
          final url = publicUrlResolver != null
              ? publicUrlResolver(clean)
              : MediaService().publicUrl(clean);
          if (url.trim().isNotEmpty) resolvedUrls.add(url.trim());
        } catch (_) {}
      }
    }
    if (resolvedUrls.isNotEmpty) {
      prefetchUrls(resolvedUrls, context: context, client: client);
    }
  }

  /// Pré-carrega caminhos privados do Supabase Storage em background sem bloquear a UI.
  static void prefetchStoragePaths(
    Iterable<String?> paths, {
    BuildContext? context,
    Future<String?> Function(String)? urlResolver,
    http.Client? client,
  }) {
    final engine = InstantImageCacheEngine.instance..configureGlobalImageCache();
    final seen = <String>{};
    for (final raw in paths) {
      final path = raw?.trim() ?? '';
      if (path.isEmpty || !seen.add(path)) continue;
      _enqueue(
        () => _warmStoragePath(
          engine,
          path,
          context: context,
          urlResolver: urlResolver,
          client: client,
        ),
      );
    }
  }

  /// Pré-carrega fotos (`job.photoPaths`) e avatares dos profissionais (`job.providerId`)
  /// de uma coleção de [Job]s silenciosamente em background, deduplicando `providerId`s
  /// na sessão para nunca reconsultar e ignorando falhas quando offline ou em testes.
  static void prefetchJobs(
    Iterable<Job> jobs, {
    BuildContext? context,
    Future<String?> Function(String)? urlResolver,
    Future<Map<String, ProviderCard>> Function(Iterable<String>)?
        providerResolver,
    http.Client? client,
  }) {
    final urls = <String>[];
    final storagePaths = <String>[];
    final newProviderIds = <String>[];

    for (final job in jobs) {
      final pid = job.providerId?.trim() ?? '';
      if (pid.isNotEmpty && _warmedProviderIds.add(pid)) {
        newProviderIds.add(pid);
      }
      for (final p in job.photoPaths) {
        final clean = p.trim();
        if (clean.isEmpty) continue;
        // Ignora vídeos (.mp4/.mov) no pré-aquecimento de imagens estáticas.
        final lower = clean.toLowerCase();
        if (lower.endsWith('.mp4') || lower.endsWith('.mov')) continue;
        if (clean.startsWith('http://') || clean.startsWith('https://')) {
          urls.add(clean);
        } else {
          storagePaths.add(clean);
        }
      }
    }

    if (urls.isNotEmpty) {
      prefetchUrls(urls, context: context, client: client);
    }
    if (storagePaths.isNotEmpty) {
      prefetchStoragePaths(
        storagePaths,
        context: context,
        urlResolver: urlResolver,
        client: client,
      );
    }
    if (newProviderIds.isNotEmpty) {
      if (providerResolver != null ||
          !InstantImageCacheEngine._isFlutterTestBinding()) {
        unawaited(
          _warmProviders(
            newProviderIds,
            context: context,
            providerResolver: providerResolver,
            client: client,
          ),
        );
      }
    }
  }

  static Future<void> _warmProviders(
    List<String> providerIds, {
    BuildContext? context,
    Future<Map<String, ProviderCard>> Function(Iterable<String>)?
        providerResolver,
    http.Client? client,
  }) async {
    try {
      final cards = await (providerResolver != null
          ? providerResolver(providerIds)
          : ProviderService().byIds(providerIds));
      final urls = cards.values.map((c) => c.avatarUrl);
      if (context != null && context.mounted) {
        prefetchUrls(urls, context: context, client: client);
      } else {
        prefetchUrls(urls, client: client);
      }
    } catch (_) {
      _warmedProviderIds.removeAll(providerIds);
    }
  }

  static Future<void> _warmUrl(
    InstantImageCacheEngine engine,
    String url, {
    BuildContext? context,
    http.Client? client,
  }) async {
    try {
      final bytes = await engine.getOrFetchUrlBytes(url, client: client);
      if (bytes != null &&
          context != null &&
          context.mounted &&
          InstantImageCacheEngine.looksLikeValidEncodedImage(bytes)) {
        await precacheImage(
          engine.buildMemoryProvider(bytes),
          context,
          onError: (_, _) {},
        );
      }
    } catch (_) {}
  }

  static Future<void> _warmStoragePath(
    InstantImageCacheEngine engine,
    String path, {
    BuildContext? context,
    Future<String?> Function(String)? urlResolver,
    http.Client? client,
  }) async {
    try {
      final bytes = await engine.getOrFetchSignedStorageBytes(
        path,
        urlResolver: urlResolver,
        client: client,
      );
      if (bytes != null &&
          context != null &&
          context.mounted &&
          InstantImageCacheEngine.looksLikeValidEncodedImage(bytes)) {
        await precacheImage(
          engine.buildMemoryProvider(bytes),
          context,
          onError: (_, _) {},
        );
      }
    } catch (_) {}
  }
}

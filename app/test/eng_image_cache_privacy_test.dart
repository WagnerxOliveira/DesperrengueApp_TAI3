import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:desperrengue_app/core/services/instant_image_cache_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PNG 1x1 válido.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InstantImageCacheEngine.instance.clearForTesting(clearGlobalImageCache: true);
    EagerImagePrefetcher.cancelPending();
  });

  test('mídia PRIVADA (storage:) nunca vai para a L2 em texto puro; pública vai', () async {
    final engine = InstantImageCacheEngine.instance;
    final client = MockClient((_) async => http.Response.bytes(_png, 200));

    await engine.getOrFetchSignedStorageBytes(
      'uid/job_123.png',
      urlResolver: (p) async => 'https://cdn.example.com/signed/$p?token=abc',
      client: client,
    );
    await engine.getOrFetchUrlBytes('https://cdn.example.com/avatar.png', client: client);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('carbon_instant_img_l2_v1') ?? '{}';
    final l2 = jsonDecode(raw) as Map<String, dynamic>;
    expect(l2.keys.where((k) => k.startsWith('storage:')), isEmpty,
        reason: 'foto privada não pode ficar em SharedPreferences');
    expect(l2.keys, contains('https://cdn.example.com/avatar.png'));
  });

  test('purgeAllUserImages limpa L1, L2 e o ImageCache (logout)', () async {
    final engine = InstantImageCacheEngine.instance;
    final client = MockClient((_) async => http.Response.bytes(_png, 200));
    await engine.getOrFetchUrlBytes('https://cdn.example.com/a.png', client: client);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(engine.memoryEntryCount, greaterThan(0));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('carbon_instant_img_l2_v1'), isNotNull);

    await engine.purgeAllUserImages();

    expect(engine.memoryEntryCount, 0);
    expect(engine.currentMemoryBytes, 0);
    expect((await SharedPreferences.getInstance()).getString('carbon_instant_img_l2_v1'), isNull);
  });

  test('ImageCache global com teto sensato (128 MB / 500 itens)', () {
    InstantImageCacheEngine.instance.configureGlobalImageCache();
    final c = PaintingBinding.instance.imageCache;
    expect(c.maximumSizeBytes, 128 << 20);
    expect(c.maximumSize, 500);
  });

  test('pré-carga limita a 4 downloads simultâneos e cancelPending descarta a fila', () async {
    var active = 0;
    var peak = 0;
    final gates = <Completer<void>>[];
    final client = MockClient((_) async {
      active++;
      if (active > peak) peak = active;
      final g = Completer<void>();
      gates.add(g);
      await g.future;
      active--;
      return http.Response.bytes(_png, 200);
    });

    EagerImagePrefetcher.prefetchUrls(
      [for (var i = 0; i < 12; i++) 'https://cdn.example.com/p$i.png'],
      client: client,
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(peak, EagerImagePrefetcher.maxConcurrentPrefetch);
    expect(EagerImagePrefetcher.debugQueuedPrefetches, 12 - EagerImagePrefetcher.maxConcurrentPrefetch);

    // Usuário saiu da tela: o que ainda não começou é descartado.
    EagerImagePrefetcher.cancelPending();
    expect(EagerImagePrefetcher.debugQueuedPrefetches, 0);

    for (final g in List<Completer<void>>.of(gates)) {
      g.complete();
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(gates.length, EagerImagePrefetcher.maxConcurrentPrefetch, reason: 'nenhum download novo após cancelar');
  });
}

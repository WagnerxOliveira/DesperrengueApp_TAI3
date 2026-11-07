import 'dart:js_interop';

@JS('eval')
external JSPromise<JSBoolean> _evalAsyncPromise(JSString script);

/// Na Web/PWA:
/// 1. Busca `version.json` e `manifest.json` com query param anti-cache (`?t=...`);
/// 2. Desregistra/atualiza todos os `ServiceWorkerRegistration` ativos;
/// 3. Limpa todos os `CacheStorage` (`window.caches.keys()` -> `caches.delete()`);
/// 4. Recarrega a página forçando busca na rede (`window.location.reload()`).
Future<bool> purgeWebCachesAndReload({bool reloadWindow = true}) async {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final shouldReload = reloadWindow ? 'true' : 'false';
  final jsCode = '''
    (async function() {
      try {
        try {
          await fetch('version.json?t=$ts', { cache: 'no-store' });
        } catch (_) {}
        try {
          await fetch('manifest.json?t=$ts', { cache: 'no-store' });
        } catch (_) {}
        if ('serviceWorker' in navigator && navigator.serviceWorker.getRegistrations) {
          const regs = await navigator.serviceWorker.getRegistrations();
          for (const reg of regs) {
            try { await reg.update(); } catch (_) {}
            try { await reg.unregister(); } catch (_) {}
          }
        }
        if ('caches' in window && window.caches && window.caches.keys) {
          const keys = await window.caches.keys();
          for (const key of keys) {
            try { await window.caches.delete(key); } catch (_) {}
          }
        }
        if ($shouldReload && window.location && window.location.reload) {
          window.location.reload();
        }
        return true;
      } catch (e) {
        if ($shouldReload && window.location && window.location.reload) {
          window.location.reload();
        }
        return false;
      }
    })()
  ''';

  try {
    final res = await _evalAsyncPromise(jsCode.toJS).toDart;
    return res.toDart;
  } catch (_) {
    return false;
  }
}

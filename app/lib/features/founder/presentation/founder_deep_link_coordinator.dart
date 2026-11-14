/// Coordenador de Deep-Links Soberanos do `Desperrengue CEO` (`AppLinks` + Zero-Trust).
///
/// Escuta tanto `getInitialLink` (cold-start quando Wagner toca no botão do 2º e-mail
/// com o app fechado) quanto `uriLinkStream` (warm-resume com o app em segundo plano)
/// e publica concessões validadas por [FounderDeepLinkPolicy] em [pendingResetGrant].
library;

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../domain/founder_deep_link_policy.dart';

class FounderDeepLinkCoordinator {
  FounderDeepLinkCoordinator({
    FounderDeepLinkPolicy? policy,
    this.getInitialLinkOverride,
    this.uriStreamOverride,
  }) : _policy = policy ?? FounderDeepLinkPolicy();

  final FounderDeepLinkPolicy _policy;
  final Future<Uri?> Function()? getInitialLinkOverride;
  final Stream<Uri>? uriStreamOverride;

  final ValueNotifier<FounderResetLinkGrant?> pendingResetGrant =
      ValueNotifier<FounderResetLinkGrant?>(null);

  StreamSubscription<Uri>? _sub;
  bool _started = false;
  bool _disposed = false;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;

    try {
      final Future<Uri?> initialFuture;
      if (getInitialLinkOverride != null) {
        initialFuture = getInitialLinkOverride!();
      } else if (kIsWeb) {
        initialFuture = Future<Uri?>.value(null);
      } else {
        initialFuture = AppLinks().getInitialLink();
      }
      final initialUri = await initialFuture;
      if (_disposed) return;
      _handleIncomingUri(initialUri);
    } catch (_) {
      // Nunca logar URL de segurança em console/crashlytics
    }

    if (_disposed) return;
    try {
      final stream = uriStreamOverride ??
          (kIsWeb ? const Stream<Uri>.empty() : AppLinks().uriLinkStream);
      _sub = stream.listen(_handleIncomingUri, onError: (_) {});
    } catch (_) {}
  }

  /// Permite injetar programaticamente um URI em testes determinísticos.
  bool handleUriForTesting(Uri uri) => _handleIncomingUri(uri);

  bool _handleIncomingUri(Uri? uri) {
    if (_disposed || uri == null) return false;
    final grant = _policy.parseAndValidate(uri);
    if (grant == null) return false;
    pendingResetGrant.value = grant;
    return true;
  }

  void clearPendingGrant({bool allowReopenWithinTtl = false}) {
    final current = pendingResetGrant.value;
    if (current != null && allowReopenWithinTtl) {
      _policy.releaseUnconsumedLinkId(current.linkId);
    }
    pendingResetGrant.value = null;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _sub?.cancel();
    _sub = null;
    pendingResetGrant.dispose();
  }
}

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/draft_store.dart';
import '../../../core/services/media_service.dart';
import 'deep_link_policy.dart';
import 'login_screen.dart';
import 'post_auth_router.dart';

/// Raiz de navegação do app.
///
/// - Sem sessão  -> [LoginScreen].
/// - Com sessão  -> [PostAuthRouter] (decide a tela pelo estado do servidor).
///
/// Reage a login/logout (inclusive OAuth Google, que retorna por deep link) e
/// ao deep link `desperrengue://onboarding/...` do e-mail de aprovação. O link
/// NÃO carrega credencial: ele só faz o app reconsultar o status no servidor.
/// Links são validados por [DeepLinkPolicy] (esquema/host/caminho/query) e
/// limitados por throttle.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final SupabaseClient _client = Supabase.instance.client;

  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<Uri>? _linkSub;

  /// `true` após o dispose: o `await` de [_initDeepLinks] pode terminar depois
  /// da tela morrer, e a assinatura criada tarde nunca seria cancelada (leak).
  bool _disposed = false;
  DateTime? _lastLinkRefresh;

  String? _userId;
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    _userId = _client.auth.currentUser?.id;

    _authSub = _client.auth.onAuthStateChange.listen((state) {
      final newId = state.session?.user.id;
      if (!mounted || newId == _userId) return; // ignora refresh de token
      final previous = _userId;
      if (newId == null && previous != null) _wipeLocalUserData(previous);
      setState(() {
        _userId = newId;
        _refreshTick++;
      });
    });

    _initDeepLinks();
  }

  /// LGPD: ao sair da conta, rascunhos (CPF/endereço/telefone digitados) e URLs
  /// assinadas de mídia privada não ficam no aparelho para o próximo usuário.
  void _wipeLocalUserData(String userId) {
    MediaService.clearSignedCache();
    unawaited(DraftStore.clearAllForUser(userId));
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();
    try {
      final initial = await appLinks.getInitialLink();
      if (_disposed) return;
      if (initial != null) _onLink(initial);
    } catch (_) {
      // Sem log do erro/URL: pode conter token ou dado pessoal.
    }
    if (_disposed) return;
    _linkSub = appLinks.uriLinkStream.listen(_onLink, onError: (_) {});
  }

  void _onLink(Uri uri) {
    if (!mounted || !DeepLinkPolicy.isTrustedOnboardingLink(uri)) return;
    final now = DateTime.now();
    if (!DeepLinkPolicy.shouldRefresh(lastRefresh: _lastLinkRefresh, now: now)) return;
    _lastLinkRefresh = now;
    setState(() => _refreshTick++);
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub?.cancel();
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) return const LoginScreen();
    return PostAuthRouter(key: ValueKey('$_userId-$_refreshTick'));
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/boot/app_initialization_service.dart';
import '../../core/services/instant_image_cache_engine.dart';
import '../../core/state/theme_controller.dart';
import '../../core/state/unread_orders_badge_controller.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/design_system/design_system.dart';
import '../../core/ui/desperrengue_brand_logo.dart';
import '../auth/presentation/auth_gate.dart';
import 'animated_splash_screen.dart';

/// Porta de entrada do app: splash animada + inicialização em paralelo; ao
/// terminar, FadeOut direto para o [AuthGate] (que decide Login / Seleção de
/// perfil / Painel). Se o armazenamento local estiver corrompido, o serviço já
/// o limpou e o AuthGate cai no Login — nunca um crash.
class BootGate extends ConsumerStatefulWidget {
  const BootGate({super.key});

  @override
  ConsumerState<BootGate> createState() => _BootGateState();
}

class _BootGateState extends ConsumerState<BootGate> {
  Future<BootResult>? _init;
  int _attempt = 0;
  bool _failed = false;

  /// Warm-up do engine durante a splash: decodifica o símbolo no cache de imagens,
  /// configura o ImageCache global e hidrata em paralelo avatares L2 e badges lidos
  /// em RAM antes do 1º frame do app.
  Future<void> _warmUp() async {
    InstantImageCacheEngine.instance.configureGlobalImageCache();
    await Future.wait<void>([
      precacheImage(const AssetImage('assets/splash/logo.png'), context),
      () async {
        try {
          await InstantImageCacheEngine.instance.ensurePersistentCacheLoaded();
        } catch (_) {}
      }(),
      () async {
        try {
          await UnreadOrdersBadgeController.instance.ensureLoaded();
        } catch (_) {}
      }(),
    ]);
  }

  void _start() {
    _init = AppInitializationService(warmUp: _warmUp).run();
    _failed = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init == null) _start();
  }

  void _onFinished(BootResult r) {
    ref.read(themeModeProvider.notifier).hydrate(r.theme);
    if (!r.backendReady) {
      setState(() => _failed = true);
      return;
    }
    Navigator.of(context).pushReplacement(fadeRoute(const AuthGate()));
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      const onNavy = DesperrengueBrandLogoPainter.pureWhite;
      return AppScaffold(
        backgroundColor: AnimatedSplashScreen.navy,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.s32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color: onNavy.withValues(alpha: 0.75),
                      size: 56,
                    ),
                    const SizedBox(height: AppSpace.s16),
                    Text(
                      'Não foi possível iniciar o aplicativo.',
                      textAlign: TextAlign.center,
                      style: AppType.title.copyWith(color: onNavy),
                    ),
                    const SizedBox(height: AppSpace.s8),
                    Text(
                      'Verifique sua conexão e tente novamente.',
                      textAlign: TextAlign.center,
                      style: AppType.body.copyWith(
                        color: onNavy.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s24),
                    AppPressScale(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: onNavy,
                          foregroundColor: AnimatedSplashScreen.navy,
                          minimumSize: const Size(0, AppGeometry.buttonHeightCompact),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppGeometry.buttonRadius),
                          ),
                          textStyle: AppType.button,
                        ),
                        onPressed: () => setState(() {
                          _attempt++;
                          _start();
                        }),
                        child: const Text('Tentar novamente'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return AnimatedSplashScreen(key: ValueKey(_attempt), init: _init!, onFinished: _onFinished);
  }
}

/// Transição de saída da splash: FadeOut/FadeIn suave (sem slide).
Route<T> fadeRoute<T>(Widget page, {Duration duration = const Duration(milliseconds: 380)}) => PageRouteBuilder<T>(
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (context, animation, _, child) {
        if (AppMotion.reduced(context)) return child;
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );

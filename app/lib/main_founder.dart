import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/boot/app_initialization_service.dart';
import 'core/constants/env.dart';
import 'core/services/instant_image_cache_engine.dart';
import 'core/storage/secure_session_storage.dart';
import 'features/founder/presentation/founder_animated_splash_screen.dart';
import 'features/founder/presentation/founder_animations_and_shaders.dart';
import 'features/founder/presentation/founder_cockpit_screen.dart';
import 'features/founder/presentation/founder_deep_link_coordinator.dart';
import 'features/founder/presentation/founder_update_gate.dart';

/// Entrypoint exclusivo do binário Soberano do Fundador/CEO (`desperrengue-founder-ceo.apk`
/// / `br.com.desperrengue.app.founder`).
///
/// Isolado fisicamente do entrypoint público (`lib/main.dart`):
/// - Zero código ou rota do Founder Cockpit embarcado no APK público;
/// - `detectSessionInUri: false` para que o GoTrue jamais intercepte os deep-links
///   exclusivos `desperrengue-founder://vault/reset-password` do Cofre Soberano;
/// - Cold-start 120 FPS sem flash branco (`#07090D` nativo -> `FounderAnimatedSplashScreen`);
/// - Auto-updater direto no aparelho (`FounderUpdateGate` em `MaterialApp.builder`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: DesperrengueFounderApp()));
}

class DesperrengueFounderApp extends StatefulWidget {
  const DesperrengueFounderApp({
    super.key,
    this.bootService,
    this.updateService,
    this.otaInstaller,
    this.deepLinkCoordinator,
    this.splashDuration = const Duration(milliseconds: 1750),
  });

  final AppInitializationService? bootService;
  final FounderUpdateService? updateService;
  final FounderNativeOtaInstaller? otaInstaller;
  final FounderDeepLinkCoordinator? deepLinkCoordinator;
  final Duration splashDuration;

  @override
  State<DesperrengueFounderApp> createState() => _DesperrengueFounderAppState();
}

class _DesperrengueFounderAppState extends State<DesperrengueFounderApp> {
  late final AppInitializationService _service = widget.bootService ??
      AppInitializationService(
        warmUp: _warmUpFounder,
        initBackend: _initFounderSovereignBackend,
      );

  static Future<void> _initFounderSovereignBackend() => Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabasePublishableKey,
        authOptions: FlutterAuthClientOptions(
          detectSessionInUri: false,
          localStorage: SecureSessionStorage(
            persistSessionKey:
                '${SecureSessionStorage.keyFor(Env.supabaseUrl)}_ceo_sovereign',
          ),
        ),
      );

  static Future<void> _warmUpFounder() async {
    InstantImageCacheEngine.instance.configureGlobalImageCache();
    try {
      await InstantImageCacheEngine.instance.ensurePersistentCacheLoaded();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final sovereignTheme = FounderSovereignTokens.buildTheme();
    return MaterialApp(
      title: 'Desperrengue CEO',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const <Locale>[Locale('pt', 'BR')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: sovereignTheme,
      darkTheme: sovereignTheme,
      themeMode: ThemeMode.dark,
      builder: (context, child) => FounderUpdateGate(
        service: widget.updateService,
        installer: widget.otaInstaller,
        child: child ?? const SizedBox.shrink(),
      ),
      home: FounderBootGate(
        service: _service,
        splashDuration: widget.splashDuration,
        readyChild: FounderCockpitScreen(
          deepLinkCoordinator: widget.deepLinkCoordinator,
        ),
      ),
    );
  }
}

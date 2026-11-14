import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/env.dart';
import 'core/services/instant_image_cache_engine.dart';
import 'core/storage/secure_session_storage.dart';
import 'features/founder/presentation/founder_animations_and_shaders.dart';
import 'features/founder/presentation/founder_cockpit_screen.dart';

/// Entrypoint exclusivo do binário Soberano do Fundador/CEO (`desperrengue-founder-ceo.apk`
/// / `flutter build web --target=lib/main_founder.dart`).
///
/// Isolado fisicamente do entrypoint público (`lib/main.dart`):
/// - Zero código ou rota do Founder Cockpit embarcado no APK público;
/// - Sem trava de `480px` em telas largas, habilitando o Command Center Panorâmico
///   de 3 colunas em `1440px+` (Desktop/Web) e o modo Pocket de 6 abas no celular.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  InstantImageCacheEngine.instance.configureGlobalImageCache();

  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSessionStorage(
          persistSessionKey: SecureSessionStorage.keyFor(Env.supabaseUrl),
        ),
      ),
    );
  } catch (_) {
    // Segue em modo determinístico/offline caso já inicializado ou sem rede.
  }

  runApp(const ProviderScope(child: DesperrengueFounderApp()));
}

class DesperrengueFounderApp extends StatelessWidget {
  const DesperrengueFounderApp({super.key});

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
      home: const FounderCockpitScreen(),
    );
  }
}

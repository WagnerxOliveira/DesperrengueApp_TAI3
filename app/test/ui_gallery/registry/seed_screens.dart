import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/features/auth/presentation/login_screen.dart';
import 'package:desperrengue_app/features/client/presentation/carteira_cliente_screen.dart';
import 'package:desperrengue_app/features/client/presentation/category_picker.dart';
import 'package:desperrengue_app/features/client/presentation/insufficient_funds_sheet.dart';
import 'package:flutter/material.dart';

import '../../support/screen_gallery/screen_gallery.dart';

/// Telas-semente (as mais simples de montar). As demais ondas ficam em
/// arquivos próprios desta pasta (`registry/*.dart`), todos agregados por
/// `gallery_registry.dart`.
List<GalleryScreen> seedScreens() => <GalleryScreen>[
      GalleryScreen(
        id: 'auth/login',
        title: 'Login',
        source: 'features/auth/presentation/login_screen.dart',
        wave: 1,
        owner: 'auth_ui',
        modes: const <UserMode?>{null},
        builder: (_, __) => const LoginScreen(),
      ),
      GalleryScreen(
        id: 'client/carteira',
        title: 'Carteira do cliente',
        source: 'features/client/presentation/carteira_cliente_screen.dart',
        wave: 3,
        owner: 'client_core_ui',
        modes: const <UserMode?>{UserMode.client},
        overrides: (_) => walletOverrides(),
        builder: (_, __) => const CarteiraClienteScreen(),
      ),
      GalleryScreen(
        id: 'client/category_grid',
        title: 'Grade de categorias',
        source: 'features/client/presentation/category_picker.dart',
        wave: 2,
        owner: 'client_core_ui',
        kind: GalleryKind.widget,
        modes: const <UserMode?>{UserMode.client},
        builder: (_, __) => CategoryGrid(onPick: (_) {}),
      ),
      GalleryScreen(
        id: 'client/insufficient_funds_sheet',
        title: 'Sheet de saldo insuficiente',
        source: 'features/client/presentation/insufficient_funds_sheet.dart',
        wave: 3,
        owner: 'client_core_ui',
        kind: GalleryKind.sheet,
        modes: const <UserMode?>{UserMode.client},
        builder: (_, __) => const InsufficientFundsBottomSheet(requiredCents: 22000, availableCents: 15000),
      ),
    ];

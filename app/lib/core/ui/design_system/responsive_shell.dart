import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../desperrengue_brand_logo.dart';
import 'tokens/app_breakpoints.dart';
import 'tokens/app_space.dart';
import 'tokens/app_type.dart';

/// Fundo de marca atrás da coluna do app em telas largas (Web/desktop/tablet).
abstract final class AppShellColors {
  static const Color brandBackdrop = Color(0xFF0F172A);
  static const Color brandSurface = Color(0xFF172236);
  static const Color brandBorder = Color(0xFF26354E);
  static const Color onBrand = Color(0xFFF8FAFC);
  static const Color onBrandMuted = Color(0xFFCBD5E1);
  static const Color benefitTrust = Color(0xFF3CCB8C);
  static const Color benefitAccent = Color(0xFFFF8F52);
  static const Color benefitInfo = Color(0xFF74A7FF);
}

/// Comportamento de rolagem global: habilita arraste com mouse/trackpad na Web
/// e exibe `Scrollbar` visível em Web/desktop sem interferir no mobile.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    final platform = getPlatform(context);
    final isDesktopOrWeb = kIsWeb ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.macOS;
    if (!isDesktopOrWeb) return child;
    if (details.direction == AxisDirection.left || details.direction == AxisDirection.right) {
      return child;
    }
    final controller = details.controller;
    if (controller == null) return child;
    return Scrollbar(controller: controller, child: child);
  }
}

/// Moldura responsiva do app (§2.6 — substitui o hack `MediaQuery.copyWith(size: 480)`).
///
/// * `<= 600 px`: tela cheia;
/// * `600–899 px`: coluna centralizada de **560**;
/// * `900–1039 px`: coluna do app (**520**) centralizada sobre fundo de marca;
/// * `>= 1040 px`: coluna do app (**520**) acompanhada por painel lateral
///   discreto da marca (logo + 3 garantias reais do app) — os cartões do app
///   NUNCA esticam em desktop.
///
/// O `MediaQuery.size` repassado ao app é o da COLUNA, então `context.layout`
/// e `LayoutBuilder` das telas enxergam a largura real disponível.
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({
    super.key,
    required this.child,
    this.showSidePanel = true,
  });

  final Widget child;

  /// Exibe o painel lateral de marca em telas desktop (`>= 1040 px`).
  final bool showSidePanel;

  /// Largura mínima de janela para compor o painel lateral junto à coluna.
  static const double sidePanelBreakpoint = 1040;

  /// Largura da coluna do app para uma janela de [windowWidth] px (ou `null` =
  /// tela cheia).
  static double? columnWidthFor(double windowWidth) {
    if (windowWidth <= AppBreakpoints.medium) return null;
    if (windowWidth < AppBreakpoints.expanded) return AppGeometry.maxColumnWidth;
    return 520;
  }

  /// `true` quando a janela comporta o painel lateral de marca + coluna do app.
  static bool showsSidePanelFor(double windowWidth) => windowWidth >= sidePanelBreakpoint;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final colW = columnWidthFor(mq.size.width);
    if (colW == null) return child;
    final wide = mq.size.width >= AppBreakpoints.expanded;
    final hasSidePanel = showSidePanel && showsSidePanelFor(mq.size.width);
    final tk = context.tk;

    final appColumn = SizedBox(
      width: colW,
      height: mq.size.height,
      child: MediaQuery(
        data: mq.copyWith(size: Size(colW, mq.size.height)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tk.background,
            border: wide
                ? const Border.symmetric(
                    vertical: BorderSide(color: AppShellColors.brandBorder),
                  )
                : null,
            boxShadow: wide
                ? const [BoxShadow(color: Color(0x66000000), blurRadius: 48, offset: Offset(0, 16))]
                : null,
          ),
          child: ClipRect(child: child),
        ),
      ),
    );

    if (!hasSidePanel) {
      return ColoredBox(
        color: AppShellColors.brandBackdrop,
        child: Center(child: appColumn),
      );
    }

    final gap = mq.size.width >= 1200 ? AppSpace.s48 : AppSpace.s32;
    return ColoredBox(
      color: AppShellColors.brandBackdrop,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RepaintBoundary(child: _DesktopBrandSidePanel()),
            SizedBox(width: gap),
            appColumn,
          ],
        ),
      ),
    );
  }
}

class _DesktopBrandSidePanel extends StatelessWidget {
  const _DesktopBrandSidePanel();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('responsive_shell_side_panel'),
      width: 340,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s20, vertical: AppSpace.s32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const DesperrengueBrandLogo(
                    size: 52,
                    variant: DesperrengueLogoVariant.highRecallOrange,
                    showShadow: false,
                  ),
                  const SizedBox(width: AppSpace.s16),
                  Expanded(
                    child: Text(
                      'Desperrengue',
                      style: AppType.headline.copyWith(color: AppShellColors.onBrand),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s16),
              Text(
                'Serviços residenciais com clareza, proteção e controle do começo ao fim.',
                style: AppType.body.copyWith(color: AppShellColors.onBrandMuted),
              ),
              const SizedBox(height: AppSpace.s24),
              const _BenefitTile(
                icon: Icons.verified_user_rounded,
                iconColor: AppShellColors.benefitTrust,
                title: 'Pagamento protegido',
                subtitle: 'O valor fica guardado e só é liberado quando você confirma o serviço.',
              ),
              const SizedBox(height: AppSpace.s12),
              const _BenefitTile(
                icon: Icons.badge_rounded,
                iconColor: AppShellColors.benefitAccent,
                title: 'Profissionais verificados',
                subtitle: 'Cadastro conferido, portfólio real e avaliações de quem já contratou.',
              ),
              const SizedBox(height: AppSpace.s12),
              const _BenefitTile(
                icon: Icons.location_on_rounded,
                iconColor: AppShellColors.benefitInfo,
                title: 'Endereço preservado',
                subtitle: 'Seu endereço exato é compartilhado somente no dia do atendimento.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppShellColors.brandSurface,
        borderRadius: BorderRadius.circular(AppGeometry.itemRadius),
        border: Border.all(color: AppShellColors.brandBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: AppGeometry.iconTileSize,
              height: AppGeometry.iconTileSize,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppGeometry.iconTileRadius),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.bodyStrong.copyWith(color: AppShellColors.onBrand)),
                  const SizedBox(height: AppSpace.s4),
                  Text(subtitle, style: AppType.bodySm.copyWith(color: AppShellColors.onBrandMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// `Scaffold` com tratamento correto das áreas do sistema (barra de navegação do Android com
/// 3 botões/gestos e "home indicator" do iOS).
///
/// Problema que resolve: no Android 15+ o app desenha "de ponta a ponta" (edge-to-edge) e o
/// conteúdo vai para BAIXO da barra de navegação do sistema. Uma lista com `padding` fixo de
/// 24 px termina sob essa barra (≈ 48 px): o último botão/cartão aparece cortado e **não dá
/// para rolar mais**.
///
/// Regra:
///  * sem `bottomNavigationBar`: o corpo ganha `SafeArea` embaixo — o que sobra pinta com a
///    cor do próprio fundo do Scaffold (sem emenda visual);
///  * com `bottomNavigationBar` (BottomBar/NavigationBar): eles já tratam a área do sistema,
///    então o corpo não é alterado (evita espaço duplo).
/// Teclado: com o teclado aberto o `padding.bottom` do sistema é 0, então nada é somado.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.appBar,
    this.body,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.resizeToAvoidBottomInset,
    this.extendBodyBehindAppBar = false,
    this.extendBody = false,
    this.drawer,
  });

  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool? resizeToAvoidBottomInset;
  final bool extendBodyBehindAppBar;
  final bool extendBody;
  final Widget? drawer;

  @override
  Widget build(BuildContext context) {
    final needsSafeBottom = bottomNavigationBar == null && !extendBody && body != null;
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      extendBody: extendBody,
      drawer: drawer,
      body: needsSafeBottom ? SafeArea(top: false, left: false, right: false, child: body!) : body,
    );
  }
}

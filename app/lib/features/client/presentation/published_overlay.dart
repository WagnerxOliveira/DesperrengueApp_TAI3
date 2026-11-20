import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/media_widgets.dart';

/// Mostra, SOBRE o Painel do Cliente, o overlay circular "Pedido publicado!".
///
///  * fundo escurecido (`Colors.black.withValues(alpha: 0.65)`) com o painel visível atrás;
///  * círculo central com micro-celebração breve (Lottie `check_burst.json` + onda única,
///    sem loop infinito) e próximo passo útil;
///  * fecha ao tocar em qualquer parte escura (`barrierDismissible: true`) OU no botão
///    "Fechar" logo abaixo do círculo.
///
/// Use o `context` do Navigator (ex.: `navigator.context`), pois a tela do wizard já foi fechada.
Future<void> showPublishedOrderOverlay(
  BuildContext context, {
  required String categoryName,
  bool direct = false,
  String? providerName,
}) {
  final reduced = AppMotion.reduced(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar',
    barrierColor: Colors.black.withValues(alpha: 0.65),
    transitionDuration: reduced ? Duration.zero : AppMotion.sheet,
    transitionBuilder: (context, anim, _, child) {
      if (AppMotion.reduced(context)) return child;
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: AppMotion.fadeCurve),
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      );
    },
    pageBuilder: (context, _, _) => PublishedOrderOverlay(
      categoryName: categoryName,
      direct: direct,
      providerName: providerName,
    ),
  );
}

/// Conteúdo do overlay (público para os testes).
class PublishedOrderOverlay extends StatefulWidget {
  const PublishedOrderOverlay({
    super.key,
    required this.categoryName,
    this.direct = false,
    this.providerName,
  });

  final String categoryName;
  final bool direct;
  final String? providerName;

  @override
  State<PublishedOrderOverlay> createState() => _PublishedOrderOverlayState();
}

class _PublishedOrderOverlayState extends State<PublishedOrderOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _celebrate = AnimationController(
    vsync: this,
    duration: AppMotion.success,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _celebrate.value = 1.0;
    } else {
      _celebrate.forward();
    }
  }

  @override
  void dispose() {
    _celebrate.dispose();
    super.dispose();
  }

  String get _body {
    if (widget.direct) {
      final n = widget.providerName;
      return n == null
          ? 'O profissional está sendo notificado e responderá em breve.'
          : '$n está sendo notificado e responderá em breve.';
    }
    return 'Os profissionais de ${widget.categoryName} da sua região estão sendo notificados agora.';
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final layout = context.layout;
    final outerSize = math.min(layout.width - AppSpace.s16, 332.0);
    final circleSize = math.max(264.0, outerSize - AppSpace.s32);

    // O Material cobre só o conteúdo (não a tela inteira): o resto da tela continua sendo a
    // barreira escura, que fecha o overlay ao toque.
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8, vertical: AppSpace.s16),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toques no círculo não fecham: só a área escura (barreira) e o botão Fechar.
                RepaintBoundary(
                  child: SizedBox(
                    key: const ValueKey('published-circle'),
                    width: outerSize,
                    height: outerSize,
                    child: AnimatedBuilder(
                      animation: _celebrate,
                      builder: (context, child) => CustomPaint(
                        painter: _CelebrationRingPainter(
                          color: tk.accent,
                          t: _celebrate.value,
                        ),
                        child: child,
                      ),
                      child: Center(
                        child: Container(
                          width: circleSize,
                          height: circleSize,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s24,
                            vertical: AppSpace.s20,
                          ),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tk.surfaceAt(4),
                            border: Border.all(
                              color: tk.accent.withValues(alpha: 0.55),
                              width: 2.5,
                            ),
                            boxShadow: tk.elevation(2),
                          ),
                          child: ClipOval(
                            child: Center(
                              child: SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const _BriefCheckCelebration(),
                                      const SizedBox(height: AppSpace.s8),
                                      Text(
                                        widget.direct
                                            ? 'Pedido enviado!'
                                            : 'Pedido publicado!',
                                        textAlign: TextAlign.center,
                                        style: AppType.title.copyWith(color: tk.text),
                                      ),
                                      const SizedBox(height: AppSpace.s4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            categoryIcon(widget.categoryName),
                                            size: 16,
                                            color: tk.accentInk,
                                          ),
                                          const SizedBox(width: AppSpace.s4),
                                          Flexible(
                                            child: Text(
                                              widget.categoryName,
                                              textAlign: TextAlign.center,
                                              style: AppType.caption.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: tk.accentInk,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpace.s4),
                                      Text(
                                        _body,
                                        textAlign: TextAlign.center,
                                        style: AppType.bodySm.copyWith(color: tk.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s12),
                Text(
                  'Acompanhe o andamento em Meus Pedidos',
                  textAlign: TextAlign.center,
                  style: AppType.bodySm.copyWith(color: AppTokens.onColor(tk.scrim)),
                ),
                const SizedBox(height: AppSpace.s12),
                AppButton(
                  key: const ValueKey('published-close'),
                  label: 'Fechar',
                  icon: Icons.close_rounded,
                  expand: false,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Onda breve de celebração única (t: 0→1) sem loop infinito.
class _CelebrationRingPainter extends CustomPainter {
  _CelebrationRingPainter({required this.color, required this.t});

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = size.center(Offset.zero);
    final inner = (size.width - AppSpace.s32) / 2;
    final maxR = size.width / 2;
    final eased = Curves.easeOutCubic.transform(t);
    final r = inner + (maxR - inner) * eased;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color.withValues(alpha: (1 - eased) * 0.55),
    );
  }

  @override
  bool shouldRepaint(_CelebrationRingPainter old) => old.t != t || old.color != color;
}

/// Micro-celebração breve (Lottie `check_burst.json` não-loop ou selo estático em reduced-motion).
class _BriefCheckCelebration extends StatefulWidget {
  const _BriefCheckCelebration();

  @override
  State<_BriefCheckCelebration> createState() => _BriefCheckCelebrationState();
}

class _BriefCheckCelebrationState extends State<_BriefCheckCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lottie = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _lottie.value = 1.0;
    } else {
      _lottie.forward();
    }
  }

  @override
  void dispose() {
    _lottie.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final reduce = AppMotion.reduced(context);
    final badge = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tk.success,
      ),
      child: Icon(Icons.check_rounded, color: AppTokens.onColor(tk.success), size: 32),
    );
    if (reduce) return badge;
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1.0),
            duration: AppMotion.success,
            curve: Curves.easeOutBack,
            builder: (context, v, child) => Transform.scale(scale: math.max(0.0, v), child: child),
            child: badge,
          ),
          IgnorePointer(
            child: Lottie.asset(
              'assets/lottie/check_burst.json',
              controller: _lottie,
              repeat: false,
              width: 64,
              height: 64,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

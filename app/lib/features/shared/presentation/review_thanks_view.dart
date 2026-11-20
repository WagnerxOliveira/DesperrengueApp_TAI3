import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/ui/design_system/design_system.dart';

/// "Obrigado pela sua avaliação!" (cliente e profissional): medalhão com
/// celebração breve em Lottie (`check_burst.json`, `repeat: false`) e pulso
/// calmo, card de transparência (Avaliação Cega) com mini linha do tempo de 2
/// passos, microcopy e rodapé fixo com "Voltar ao painel" protegido pela área
/// segura.
///
/// Use como `body` de um `Scaffold`. [onBack] padrão: volta à raiz (painel).
/// [revealed] = as duas avaliações já foram reveladas (o passo 2 aparece concluído).
class ReviewThanksView extends StatelessWidget {
  const ReviewThanksView({
    super.key,
    required this.isProvider,
    this.onBack,
    this.revealed = false,
  });

  final bool isProvider;
  final VoidCallback? onBack;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final other = isProvider ? 'o cliente' : 'o profissional';
    final accent = isProvider ? tk.providerAccentInk : tk.clientAccentInk;
    final accentSoft = isProvider ? tk.providerSoft : tk.clientSoft;
    final margin = context.layout.margin;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: margin,
                vertical: AppSpace.s16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - AppSpace.s32)
                      .clamp(0.0, double.infinity),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _GlassShieldIcon(accent: accent, soft: accentSoft),
                      const SizedBox(height: AppSpace.s24),
                      Text(
                        'Obrigado pela sua avaliação!',
                        textAlign: TextAlign.center,
                        style: AppType.display.copyWith(color: tk.text),
                      ),
                      const SizedBox(height: AppSpace.s8),
                      Text(
                        revealed
                            ? 'As duas avaliações já foram reveladas. Seu feedback ajuda a manter a comunidade da Desperrengue segura, transparente e justa.'
                            : 'Assim que $other avaliar, as duas notas serão reveladas ao mesmo tempo.',
                        textAlign: TextAlign.center,
                        style: AppType.body.copyWith(color: tk.textMuted),
                      ),
                      const SizedBox(height: AppSpace.s24),
                      _TransparencyCard(accent: accent, revealed: revealed),
                      const SizedBox(height: AppSpace.s16),
                      Text(
                        'No Desperrengue, utilizamos o sistema de Avaliação Cega para garantir 100% de justiça e sinceridade: nenhuma das partes vê a nota antes de enviar a sua.',
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
        AppBottomBar(
          child: AppButton(
            label: 'Voltar ao painel',
            trailingArrow: true,
            onPressed: onBack ??
                () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ),
      ],
    );
  }
}

/// Medalhão de vidro com escudo, estrela, ampulheta e celebração breve em
/// Lottie (`assets/lottie/check_burst.json`, `repeat: false`).
/// Tudo respeita `AppMotion.reduced(context)` (estado estático, zero tickers).
class _GlassShieldIcon extends StatefulWidget {
  const _GlassShieldIcon({required this.accent, required this.soft});

  final Color accent;
  final Color soft;

  @override
  State<_GlassShieldIcon> createState() => _GlassShieldIconState();
}

class _GlassShieldIconState extends State<_GlassShieldIcon>
    with TickerProviderStateMixin {
  static const String _burstAsset = 'assets/lottie/check_burst.json';

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppMotion.success,
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool _pulsePlayed = false;
  bool _burstPlayed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _pulse.stop();
      _pulse.value = 0;
      _burst.stop();
      _burst.value = 1;
    } else if (!_pulsePlayed) {
      _pulsePlayed = true;
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final accent = widget.accent;
    final reduced = AppMotion.reduced(context);
    final onAccent = AppTokens.onColor(accent);
    final borderColor = (tk.isDark ? tk.border : accent)
        .withValues(alpha: tk.isDark ? 0.55 : 0.35);

    final glass = Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: tk.isDark ? 0.24 : 0.14),
            widget.soft.withValues(alpha: 0.55),
          ],
        ),
        border: Border.all(color: borderColor, width: 1.4),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shield_rounded, size: 68, color: accent),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
              ),
              child: Icon(Icons.star_rounded, size: 22, color: onAccent),
            ),
          ),
          Positioned(
            right: 6,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tk.card,
                border: Border.all(color: accent.withValues(alpha: 0.5)),
              ),
              child: Icon(
                Icons.hourglass_top_rounded,
                size: 17,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );

    return ExcludeSemantics(
      child: SizedBox(
        width: 148,
        height: 148,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = math.sin(_pulse.value * math.pi).clamp(0.0, 1.0);
                return Container(
                  width: 112 + 32 * t,
                  height: 112 + 32 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.18 * t),
                  ),
                );
              },
            ),
            RepaintBoundary(child: glass),
            if (!reduced)
              IgnorePointer(
                child: SizedBox(
                  width: 148,
                  height: 148,
                  child: Lottie.asset(
                    _burstAsset,
                    controller: _burst,
                    repeat: false,
                    fit: BoxFit.contain,
                    onLoaded: (composition) {
                      if (!mounted || _burstPlayed) return;
                      _burstPlayed = true;
                      _burst.duration = composition.duration;
                      if (!AppMotion.reduced(context)) {
                        _burst.forward(from: 0);
                      }
                    },
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Card "Avaliação Cega" com a mini linha do tempo de 2 passos.
class _TransparencyCard extends StatelessWidget {
  const _TransparencyCard({required this.accent, required this.revealed});

  final Color accent;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      variant: AppCardVariant.tonal,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s16,
        AppSpace.s16,
        AppSpace.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_off_rounded, size: 18, color: tk.security),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  'AVALIAÇÃO CEGA',
                  style: AppType.overline.copyWith(color: tk.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s16),
          _TimelineStep(
            icon: Icons.check_rounded,
            color: tk.successInk,
            filled: true,
            text: 'Passo 1: Sua avaliação foi registrada e criptografada.',
            isLast: false,
          ),
          _TimelineStep(
            icon: revealed ? Icons.check_rounded : Icons.hourglass_top_rounded,
            color: revealed ? tk.successInk : accent,
            filled: revealed,
            text: revealed
                ? 'Passo 2: As duas avaliações já foram reveladas.'
                : 'Passo 2: Aguardando a outra parte avaliar (ou liberação automática em 48h).',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.icon,
    required this.color,
    required this.filled,
    required this.text,
    required this.isLast,
  });

  final IconData icon;
  final Color color;
  final bool filled;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? color : color.withValues(alpha: 0.14),
                    border: Border.all(color: color, width: 1.6),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: filled ? AppTokens.onColor(color) : color,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: tk.success.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: AppSpace.s4,
                bottom: isLast ? 0 : AppSpace.s16,
              ),
              child: Text(
                text,
                style: AppType.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: tk.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

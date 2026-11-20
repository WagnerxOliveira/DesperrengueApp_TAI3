import 'package:flutter/material.dart';

import 'tokens/app_motion.dart';
import 'tokens/app_space.dart';
import 'tokens/app_type.dart';

/// Tween que garante o valor final EXATO em `t == 1` (evita `0,1 + 0,2 != 0,3`).
class _ExactTween extends Tween<double> {
  _ExactTween({super.end});

  @override
  double lerp(double t) => t >= 1 ? end! : super.lerp(t);
}

/// Texto numérico que anima do valor antigo para o novo (`AppMotion.count`,
/// 250 ms, `easeOutCubic`) — saldo, preço, nota, percentual (§3.1).
///
/// * a **primeira exibição** mostra o valor final, sem animar;
/// * `disableAnimations` ⇒ troca instantânea;
/// * algarismos **tabulares** (os dígitos não "dançam" de largura);
/// * ao fim o texto é exatamente `format(value)`; leitores de tela ouvem só o
///   valor final (nunca os intermediários).
///
/// ```dart
/// AppCountText(
///   value: saldo,
///   format: (v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}',
///   style: AppType.figure,
/// )
/// ```
class AppCountText extends StatelessWidget {
  const AppCountText({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.textAlign,
    this.duration,
  });

  final double value;
  final String Function(double) format;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// Sobrescreve [AppMotion.count].
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final effective = AppType.tabular(base);
    return Semantics(
      label: format(value),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: _ExactTween(end: value),
        duration: AppMotion.d(context, duration ?? AppMotion.count),
        curve: AppMotion.countCurve,
        builder: (context, v, _) => Text(format(v), style: effective, textAlign: textAlign),
      ),
    );
  }
}

/// Item de entrada escalonada: **fade + slide de 8 px em 160 ms**, atraso de
/// 24 ms × `min(index, 5)`; só os **6 primeiros** itens e **só na 1ª exibição**
/// (§3.1) — nunca ao rolar ou reconstruir.
///
/// A memória de "já animou" é um `Set` estático por [scope] (padrão: a rota
/// atual). Itens recriados pelo scroll/rebuild aparecem direto. Sem animação
/// com `disableAnimations`.
///
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, i) => AppStaggerItem(
///     index: i,
///     scope: 'pedidos',
///     child: PedidoTile(pedidos[i]),
///   ),
/// )
/// ```
class AppStaggerItem extends StatefulWidget {
  const AppStaggerItem({super.key, required this.index, required this.child, this.scope});

  /// Posição do item na lista (0-based). `index >= 6` nunca anima.
  final int index;
  final Widget child;

  /// Chave da "lista". `null` ⇒ a rota atual (`ModalRoute`) — cada tela anima
  /// uma única vez enquanto sua rota existir.
  final Object? scope;

  static const Object _global = Object();
  static const int _maxScopes = 64;
  static final Map<Object, Set<int>> _played = <Object, Set<int>>{};

  /// Esquece o que já animou (um [scope] ou tudo). Útil em testes e após
  /// "recarregar" uma tela de propósito.
  static void reset([Object? scope]) {
    if (scope == null) {
      _played.clear();
    } else {
      _played.remove(scope);
    }
  }

  static Set<int> _setFor(Object scope) {
    if (!_played.containsKey(scope) && _played.length >= _maxScopes) {
      _played.remove(_played.keys.first); // descarta o escopo mais antigo
    }
    return _played.putIfAbsent(scope, () => <int>{});
  }

  @override
  State<AppStaggerItem> createState() => _AppStaggerItemState();
}

class _AppStaggerItemState extends State<AppStaggerItem> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late final Animation<double> _t;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final scope = widget.scope ?? ModalRoute.of(context) ?? AppStaggerItem._global;
    final played = AppStaggerItem._setFor(scope);
    final eligible = widget.index >= 0 && widget.index < AppMotion.staggerMax;
    final animate = eligible && !AppMotion.reduced(context) && !played.contains(widget.index);
    if (eligible) played.add(widget.index);
    if (!animate) return;

    final delay = AppMotion.staggerDelay * widget.index;
    final total = delay + AppMotion.stagger;
    final c = AnimationController(vsync: this, duration: total);
    _controller = c;
    _t = CurvedAnimation(
      parent: c,
      curve: Interval(delay.inMicroseconds / total.inMicroseconds, 1, curve: AppMotion.staggerCurve),
    );
    c.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    // A estrutura é decidida uma única vez (não remonta o filho ao terminar).
    if (c == null) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => FadeTransition(
        opacity: _t,
        child: Transform.translate(
          offset: Offset(0, (1 - _t.value) * AppSpace.s8),
          child: child,
        ),
      ),
    );
  }
}

/// Coluna com entrada escalonada: cada filho vira um [AppStaggerItem]
/// (só os 6 primeiros animam, só na 1ª exibição), separados por [spacing].
///
/// ```dart
/// AppStagger(
///   children: [ResumoCard(), ProximoPedidoCard(), AtalhosCard()],
/// )
/// ```
class AppStagger extends StatelessWidget {
  const AppStagger({
    super.key,
    required this.children,
    this.spacing = AppSpace.item,
    this.scope,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final double spacing;

  /// Veja [AppStaggerItem.scope].
  final Object? scope;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          AppStaggerItem(index: i, scope: scope, child: children[i]),
        ],
      ],
    );
  }
}

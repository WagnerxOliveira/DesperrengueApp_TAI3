import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Contraste WCAG 2.x real (razão por `Text`/`Icon` sobre o fundo efetivo).

/// Razão de contraste WCAG entre duas cores OPACAS (1–21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Composição de [fg] (com alpha) sobre [bg] opaco.
Color composite(Color fg, Color bg) => Color.alphaBlend(fg, bg);

/// Texto "grande" (WCAG 1.4.3): ≥ 24 px, ou ≥ 18,66 px em negrito (w700+).
bool isLargeText(double fontSizePx, int weight) => fontSizePx >= 24 || (fontSizePx >= 18.66 && weight >= 700);

/// Fundos candidatos sob [e], do mais distante ao mais próximo, compostos.
///
/// Devolve uma LISTA porque gradientes geram uma cor por parada (pior caso =
/// menor razão). Camadas translúcidas são compostas sobre as de baixo; a busca
/// termina na primeira camada opaca. Fallback: `scaffoldBackgroundColor`.
List<Color> effectiveBackgrounds(Element e) {
  final layers = <List<Color>>[]; // do mais próximo ao mais distante
  var sawImage = false;
  var done = false;
  e.visitAncestorElements((a) {
    final w = a.widget;
    List<Color>? colors;
    if (w is ColoredBox) {
      colors = <Color>[w.color];
    } else if (w is DecoratedBox) {
      final d = w.decoration;
      if (w.position == DecorationPosition.background && d is BoxDecoration) {
        if (d.gradient != null) {
          colors = d.gradient!.colors.toList();
        } else if (d.color != null) {
          colors = <Color>[d.color!];
        }
        if (d.image != null) sawImage = true;
      }
    } else if (w is Material) {
      if (w.type != MaterialType.transparency) {
        final theme = Theme.of(a);
        final c = w.color ??
            switch (w.type) {
              MaterialType.canvas => theme.canvasColor,
              MaterialType.card => theme.cardColor,
              _ => null,
            };
        if (c != null) colors = <Color>[c];
      }
    } else if (w is PhysicalModel) {
      colors = <Color>[w.color];
    } else if (w is PhysicalShape) {
      colors = <Color>[w.color];
    } else if (w is Scaffold) {
      colors = <Color>[w.backgroundColor ?? Theme.of(a).scaffoldBackgroundColor];
    } else if (w is Ink) {
      final d = w.decoration;
      if (d is BoxDecoration) {
        if (d.gradient != null) {
          colors = d.gradient!.colors.toList();
        } else if (d.color != null) {
          colors = <Color>[d.color!];
        }
      }
    }
    if (colors != null) {
      layers.add(colors);
      if (colors.every((c) => c.a >= 0.999)) {
        done = true;
        return false;
      }
    }
    return true;
  });
  if (sawImage) {
    // Imagem de fundo: contraste indeterminável por widgets; usa o que houver.
  }
  var bases = <Color>[Theme.of(e).scaffoldBackgroundColor];
  if (!done && layers.isEmpty) return bases;
  for (final layer in layers.reversed) {
    final next = <Color>[];
    for (final base in bases) {
      for (final c in layer) {
        next.add(Color.alphaBlend(c, base));
      }
    }
    bases = _dedupe(next);
  }
  return bases;
}

List<Color> _dedupe(List<Color> colors) {
  final seen = <int>{};
  final out = <Color>[];
  for (final c in colors) {
    if (seen.add(c.toARGB32())) out.add(c);
    if (out.length >= 12) break;
  }
  return out;
}

/// Menor razão de contraste de [fg] sobre os fundos efetivos de [e].
({double ratio, Color fg, Color bg}) worstContrast(Element e, Color fg) {
  final bgs = effectiveBackgrounds(e);
  var worst = double.infinity;
  Color worstBg = bgs.first;
  Color worstFg = fg;
  for (final bg in bgs) {
    final f = fg.a < 1 ? composite(fg, bg) : fg;
    final r = contrastRatio(f, bg);
    if (r < worst) {
      worst = r;
      worstBg = bg;
      worstFg = f;
    }
  }
  return (ratio: worst, fg: worstFg, bg: worstBg);
}

/// Opacidade efetiva acumulada (Opacity/FadeTransition/AnimatedOpacity).
double ancestorOpacity(Element e) {
  var o = 1.0;
  e.visitAncestorElements((a) {
    final w = a.widget;
    if (w is Opacity) o *= w.opacity;
    if (w is FadeTransition) o *= w.opacity.value;
    if (w is AnimatedOpacity) o *= w.opacity;
    return true;
  });
  return o;
}

/// `true` se [e] está num controle desabilitado ou dentro de `IgnorePointer`
/// absoluto (WCAG isenta componentes inativos).
bool inDisabledControl(Element e) {
  var disabled = false;
  e.visitAncestorElements((a) {
    final w = a.widget;
    if (w is ButtonStyleButton && !w.enabled) {
      disabled = true;
      return false;
    }
    if (w is IconButton && w.onPressed == null) {
      disabled = true;
      return false;
    }
    if (w is IgnorePointer && w.ignoring) {
      // IgnorePointer também é usado em overlays decorativos; só conta se for
      // o ancestral imediato de um botão inativo — conservador: não isenta.
      return true;
    }
    return true;
  });
  return disabled;
}

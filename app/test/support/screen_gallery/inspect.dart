import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fonts.dart';

/// Coletores da galeria: `Text`/`Icon` renderizados (estilo efetivo, retângulo,
/// contraste), alvos de toque e utilidades de localização (arquivo:linha).

/// Um trecho de texto (ou ícone) renderizado, com o estilo EFETIVO resolvido.
class TextProbe {
  TextProbe({
    required this.text,
    required this.style,
    required this.rect,
    required this.element,
    required this.scaler,
    required this.isIcon,
    required this.truncated,
    required this.maxLines,
    this.transformScale = 1.0,
  });

  final String text;
  final TextStyle style;

  /// Retângulo global do parágrafo inteiro.
  final Rect rect;
  final Element element;
  final TextScaler scaler;
  final bool isIcon;

  /// `true` se o parágrafo foi truncado (`…`/clip por maxLines).
  final bool truncated;
  final int? maxLines;

  /// Escala acumulada por `Transform`/`FittedBox` ancestrais (1.0 = nenhuma).
  final double transformScale;

  /// `fontSize` declarado (antes do `TextScaler`); padrão do Flutter = 14.
  double get fontSize => style.fontSize ?? 14.0;
  double get renderedFontSize => scaler.scale(fontSize);

  /// Tamanho EFETIVO na tela: escala do sistema × encolhimento por `FittedBox`/`Transform`.
  double get effectiveSize => renderedFontSize * transformScale;
  String? get family => style.fontFamily;
  int get weight => style.fontWeight?.value ?? 400;

  bool get isTabular =>
      (style.fontFeatures ?? const <ui.FontFeature>[]).any((f) => f.feature == 'tnum' && f.value == 1);

  bool get hasDigits => RegExp(r'\d').hasMatch(text);

  /// Texto "numérico": R$, %, horas, contagens (dígitos e quase nada além disso).
  bool get isNumeric =>
      hasDigits && RegExp(r'^[\sR$%.,:+\-–/\d×x°h]+$', caseSensitive: false).hasMatch(text.replaceAll(r'R$', 'R'));

  String get shortText => text.length <= 40 ? text : '${text.substring(0, 37)}…';

  @override
  String toString() => '"$shortText" (${family ?? 'sem família'} ${fontSize.toStringAsFixed(1)}sp w$weight)';
}

/// Todos os `RichText` visíveis (inclui `Text`, `Icon` e `Text.rich`).
///
/// [within] restringe a uma subárvore; por padrão varre o app inteiro.
List<TextProbe> collectProbes(WidgetTester tester, {Finder? within}) {
  final out = <TextProbe>[];
  final finder = within == null ? find.byType(RichText) : find.descendant(of: within, matching: find.byType(RichText));
  for (final e in finder.evaluate()) {
    final ro = e.renderObject;
    if (ro is! RenderParagraph || !ro.attached || !ro.hasSize) continue;
    final widget = e.widget as RichText;
    final topLeft = ro.localToGlobal(Offset.zero);
    final rect = topLeft & ro.size;
    final scaler = widget.textScaler;
    final truncated = ro.didExceedMaxLines;
    final tscale = ro.getTransformTo(null).getMaxScaleOnAxis();
    _walkSpan(widget.text, const TextStyle(), (text, style) {
      if (text.trim().isEmpty) return;
      final family = style.fontFamily;
      final isIcon =
          (family != null && kIconFontFamilies.contains(family)) ||
          (text.runes.length == 1 && _isPrivateUse(text.runes.first));
      out.add(
        TextProbe(
          text: text,
          style: style,
          rect: rect,
          element: e,
          scaler: scaler,
          isIcon: isIcon,
          truncated: truncated,
          maxLines: widget.maxLines,
          transformScale: tscale,
        ),
      );
    });
  }
  return out;
}

bool _isPrivateUse(int cp) => (cp >= 0xE000 && cp <= 0xF8FF) || cp >= 0xF0000;

void _walkSpan(InlineSpan span, TextStyle inherited, void Function(String, TextStyle) emit) {
  if (span is! TextSpan) return;
  final style = inherited.merge(span.style);
  final t = span.text;
  if (t != null && t.isNotEmpty) emit(t, style);
  for (final c in span.children ?? const <InlineSpan>[]) {
    _walkSpan(c, style, emit);
  }
}

/// Texto (sem ícones) apenas.
List<TextProbe> textOnly(Iterable<TextProbe> probes) => probes.where((p) => !p.isIcon).toList();

List<TextProbe> iconsOnly(Iterable<TextProbe> probes) => probes.where((p) => p.isIcon).toList();

/// `true` se [e] está dentro de um scroll horizontal (texto "cortado" ali é
/// intencional: carrossel/chips).
bool insideHorizontalScroll(Element e) {
  var found = false;
  e.visitAncestorElements((a) {
    final w = a.widget;
    if (w is Scrollable) {
      final axis = axisDirectionToAxis(w.axisDirection);
      if (axis == Axis.horizontal) {
        found = true;
        return false;
      }
    }
    return true;
  });
  return found;
}

/// Alvo de toque (nó de semântica com ação `tap`).
class TapTarget {
  TapTarget(this.label, this.rect, this.enabled, this.isTextField);

  final String label;
  final Rect rect;
  final bool enabled;
  final bool isTextField;

  double get minSide => rect.width < rect.height ? rect.width : rect.height;

  @override
  String toString() =>
      '"${label.length > 36 ? '${label.substring(0, 33)}…' : label}" ${rect.width.toStringAsFixed(0)}x${rect.height.toStringAsFixed(0)}';
}

/// Coleta os alvos de toque a partir da árvore de semântica (exige
/// `tester.ensureSemantics()`, feito por `withGalleryRun`).
List<TapTarget> collectTapTargets(WidgetTester tester) {
  final owner = tester.binding.pipelineOwner.semanticsOwner;
  final root = owner?.rootSemanticsNode;
  final out = <TapTarget>[];
  if (root == null) return out;

  void visit(SemanticsNode node, Matrix4 parent) {
    final transform = node.transform == null ? parent : (parent.clone()..multiply(node.transform!));
    final data = node.getSemanticsData();
    final hidden = node.isInvisible || data.flagsCollection.isHidden;
    if (!hidden && data.hasAction(SemanticsAction.tap) && !node.isMergedIntoParent) {
      final rect = MatrixUtils.transformRect(transform, node.rect);
      final label = data.label.isNotEmpty ? data.label : (data.tooltip.isNotEmpty ? data.tooltip : data.value);
      out.add(
        TapTarget(label, rect, data.flagsCollection.isEnabled != ui.Tristate.isFalse, data.flagsCollection.isTextField),
      );
    }
    node.visitChildren((c) {
      visit(c, transform);
      return true;
    });
  }

  visit(root, Matrix4.identity());
  return out;
}

/// Escala global (acumulada) aplicada ao elemento por `Transform`s ancestrais.
double globalScaleOf(Element e) {
  final ro = e.renderObject;
  if (ro is! RenderBox) return 1.0;
  final m = ro.getTransformTo(null);
  return m.getMaxScaleOnAxis();
}

/// Localização (arquivo:linha) do widget que CRIOU [e]: sobe os ancestrais até
/// achar um widget criado dentro de `lib/features/` (ou `lib/core/ui/`), que é o
/// que o dono da tela precisa corrigir.
String? creatorLocation(Element e) {
  String? first;
  String? owner;
  void consider(Element el) {
    final loc = _location(el.widget);
    if (loc == null) return;
    first ??= loc;
    if (owner == null && (loc.contains('/features/') || loc.contains('/main.dart'))) owner = loc;
  }

  consider(e);
  if (owner == null) {
    e.visitAncestorElements((a) {
      consider(a);
      return owner == null;
    });
  }
  return owner ?? first;
}

String? _location(Widget w) {
  try {
    final node = w.toDiagnosticsNode();
    final json = node.toJsonMap(
      InspectorSerializationDelegate(service: WidgetInspectorService.instance, subtreeDepth: 0),
    );
    final loc = json['creationLocation'];
    if (loc is Map && loc['file'] != null) {
      final file = (loc['file'] as String).replaceAll(r'\', '/');
      final i = file.indexOf('/lib/');
      final shown = i >= 0 ? file.substring(i + 1) : file;
      return '$shown:${loc['line']}';
    }
  } catch (_) {
    /* sem localização */
  }
  return null;
}

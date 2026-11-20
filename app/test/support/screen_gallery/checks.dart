import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'contrast.dart';
import 'fonts.dart';
import 'glyphs.dart';
import 'inspect.dart';
import 'pump.dart';
import 'viewports.dart';

/// Regras da galeria (identificadores estáveis: chave do ratchet).
abstract final class GalleryRules {
  static const overflow = 'overflow';
  static const renderError = 'render_error';
  static const clipped = 'clipped';
  static const truncated = 'truncated';
  static const minFont = 'min_font';
  static const bodyFont = 'body_font';
  static const family = 'font_family';
  static const weight = 'font_weight';
  static const tabular = 'tabular';
  static const symbols = 'symbols_in_text';
  static const glyphs = 'glyph_missing';
  static const tapTarget = 'tap_target';
  static const contrast = 'contrast';
  static const scaleMonotonic = 'scale_monotonic';
  static const motion = 'motion';
  static const timers = 'timers';
  static const keyboard = 'keyboard';

  /// Regras de layout (rodam na matriz `layout`).
  static const layoutRules = <String>[overflow, renderError, clipped];

  /// Regras de estilo (rodam na matriz `style`).
  static const styleRules = <String>[minFont, bodyFont, family, weight, tabular, symbols, glyphs, tapTarget, contrast];

  static const all = <String>[
    overflow,
    renderError,
    clipped,
    minFont,
    bodyFont,
    family,
    weight,
    tabular,
    symbols,
    glyphs,
    tapTarget,
    contrast,
    scaleMonotonic,
    motion,
    timers,
  ];
}

/// Uma violação. [signature] NÃO inclui a variante (dedupe entre variantes);
/// [variants] lista onde ocorreu.
class Violation {
  Violation(this.rule, this.signature, {this.where});

  final String rule;
  final String signature;

  /// `arquivo:linha` do widget (quando resolvido).
  final String? where;
  final Set<String> variants = <String>{};

  @override
  String toString() =>
      '[$rule] $signature${where == null ? '' : ' @ $where'} {${variants.take(3).join(' | ')}${variants.length > 3 ? ' +${variants.length - 3}' : ''}}';
}

/// Acumulador de violações de UMA tela (deduplica por regra+assinatura).
class ViolationLog {
  /// Normaliza relógios/contadores (`00:44`, `12:34`, `45s`) na chave de
  /// deduplicação para evitar flutuação entre variantes por virada de segundo.
  static final RegExp _clockTick = RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\b|\b\d+s\b');

  final Map<String, Violation> _byKey = <String, Violation>{};

  void add(String rule, String signature, GalleryVariant v, {String? where}) {
    final k = '$rule|${signature.replaceAll(_clockTick, '<T>')}';
    final viol = _byKey.putIfAbsent(k, () => Violation(rule, signature, where: where));
    viol.variants.add(v.label);
  }

  List<Violation> get all => _byKey.values.toList();

  List<Violation> byRule(String rule) => all.where((v) => v.rule == rule).toList();

  Map<String, int> countsByRule() {
    final m = <String, int>{};
    for (final v in _byKey.values) {
      m[v.rule] = (m[v.rule] ?? 0) + 1;
    }
    return m;
  }

  bool get isEmpty => _byKey.isEmpty;
}

// ---------------------------------------------------------------- layout

/// Overflow, erros de render e texto cortado lateralmente.
void checkLayout(GalleryRun run, ViolationLog log, {bool reportTruncation = false}) {
  final v = run.variant;
  for (final s in run.errors.overflowSummaries()) {
    log.add(GalleryRules.overflow, s, v);
  }
  for (final d in run.errors.others) {
    final first = d.exceptionAsString().split('\n').first;
    log.add(GalleryRules.renderError, first.length > 140 ? '${first.substring(0, 137)}…' : first, v);
  }
  final width = v.viewport.width;
  for (final p in textOnly(collectProbes(run.tester))) {
    if (insideHorizontalScroll(p.element)) continue;
    if (p.rect.left < -0.5 || p.rect.right > width + 0.5) {
      log.add(
        GalleryRules.clipped,
        'texto fora da tela: ${p.shortText} (${p.rect.left.toStringAsFixed(0)}..${p.rect.right.toStringAsFixed(0)} de ${width.toStringAsFixed(0)})',
        v,
        where: creatorLocation(p.element),
      );
    }
    if (reportTruncation && p.truncated) {
      log.add(GalleryRules.truncated, 'texto truncado (…): ${p.shortText}', v, where: creatorLocation(p.element));
    }
  }
}

// ------------------------------------------------------------ tipografia

const double kMinFontSize = 12.5;
const double kBodyFontSize = 14.0;

final RegExp _symbolRegex = RegExp(
  '[\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{1F000}-\u{1FAFF}\u{FE0F}\u{200D}\u{2190}-\u{21FF}]',
  unicode: true,
);

bool _isBodyText(TextProbe p) => p.text.trim().split(RegExp(r'\s+')).length >= 4 || p.text.trim().length > 32;

Set<int>? _embeddedCoverage;

Set<int> embeddedCodepoints() => _embeddedCoverage ??= <int>{
  for (final fam in embeddedFontFiles().values)
    for (final file in fam.values) ...readCmapCodepoints(readFontFileSync(file)),
};

/// Tipografia: mínimo, corpo, família, pesos, tabular, símbolos e glifos.
void checkTypography(GalleryRun run, ViolationLog log) {
  final v = run.variant;
  final cover = embeddedCodepoints();
  for (final p in textOnly(collectProbes(run.tester))) {
    final where = creatorLocation(p.element);
    final size = p.fontSize * p.transformScale; // FittedBox que encolhe conta como fonte menor
    if (size < kMinFontSize - 0.001) {
      log.add(GalleryRules.minFont, '${p.shortText} com ${size.toStringAsFixed(1)}sp < 12.5', v, where: where);
    } else if (_isBodyText(p) && size < kBodyFontSize - 0.001 && !p.isNumeric) {
      log.add(GalleryRules.bodyFont, 'corpo ${p.shortText} com ${size.toStringAsFixed(1)}sp < 14', v, where: where);
    }
    final fam = p.family;
    if (fam == null || !kAllowedFontFamilies.contains(fam)) {
      log.add(
        GalleryRules.family,
        'família ${fam ?? '(padrão do sistema)'} ≠ PlusJakartaSans/Inter: ${p.shortText}',
        v,
        where: where,
      );
    }
    // Pesos: família efetiva (padrão do tema passa a ser Inter).
    final eff = (fam != null && embeddedFontFiles().containsKey(fam)) ? fam : 'Inter';
    final weights = (embeddedFontFiles()[eff] ?? const <int, String>{}).keys;
    if (!weights.contains(p.weight)) {
      log.add(
        GalleryRules.weight,
        'peso w${p.weight} inexistente em $eff (síntese de negrito): ${p.shortText}',
        v,
        where: where,
      );
    }
    if (p.isNumeric && !p.isTabular) {
      log.add(GalleryRules.tabular, 'número sem tabularFigures: ${p.shortText}', v, where: where);
    }
    if (_symbolRegex.hasMatch(p.text)) {
      log.add(GalleryRules.symbols, 'emoji/símbolo em Text: ${p.shortText}', v, where: where);
    }
    final missing = <int>{
      for (final cp in p.text.runes)
        if (cp > 0x7E && cp != 0xA0 && !cover.contains(cp) && !_symbolRegex.hasMatch(String.fromCharCode(cp))) cp,
    };
    if (missing.isNotEmpty) {
      log.add(
        GalleryRules.glyphs,
        'glifo(s) fora das fontes embarcadas: ${missing.map(describeCodepoint).join(' ')} em ${p.shortText}',
        v,
        where: where,
      );
    }
  }
}

// -------------------------------------------------------------- alvos

const double kMinTapTarget = 48.0;

void checkTapTargets(GalleryRun run, ViolationLog log) {
  final v = run.variant;
  final size = v.viewport.size;
  for (final t in collectTapTargets(run.tester)) {
    if (!t.enabled) continue;
    // fora da tela (rolagem) ou invisível
    if (t.rect.right < 0 || t.rect.bottom < 0 || t.rect.left > size.width || t.rect.top > size.height * 4) continue;
    if (t.rect.isEmpty) continue;
    // Recorte parcial nas bordas de rolagem (ex.: botão de 56px aparecendo só
    // os 2px superiores no fim da tela não é um botão de 2px).
    final clippedVert = t.rect.height < kMinTapTarget - 0.5 &&
        (t.rect.bottom >= size.height - 1.0 || t.rect.top <= 1.0);
    final clippedHoriz = t.rect.width < kMinTapTarget - 0.5 &&
        (t.rect.right >= size.width - 1.0 || t.rect.left <= 1.0);
    if (clippedVert || clippedHoriz) continue;
    if (t.minSide < kMinTapTarget - 0.5) {
      log.add(GalleryRules.tapTarget, 'alvo de toque ${t.toString()} < 48x48', v);
    }
  }
}

// ------------------------------------------------------------ contraste

void checkContrast(GalleryRun run, ViolationLog log) {
  final v = run.variant;
  for (final p in collectProbes(run.tester)) {
    final base = p.style.color ?? const Color(0xFF000000);
    if (base.a < 0.05) continue;
    final opacity = ancestorOpacity(p.element);
    if (opacity < 0.5) continue;
    if (inDisabledControl(p.element)) continue;
    final w = worstContrast(p.element, base.withValues(alpha: base.a * opacity));
    final large = p.isIcon || isLargeText(p.fontSize, p.weight);
    final min = large ? 3.0 : 4.5;
    if (w.ratio < min - 0.001) {
      log.add(
        GalleryRules.contrast,
        '${p.isIcon ? 'ícone' : 'texto'} ${p.isIcon ? '' : '${p.shortText} '}${w.ratio.toStringAsFixed(2)}:1 < ${min.toStringAsFixed(1)}:1 '
        '(${_hex(w.fg)} sobre ${_hex(w.bg)})',
        v,
        where: creatorLocation(p.element),
      );
    }
  }
}

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

// ---------------------------------------------------------- escala

/// Tamanhos renderizados por texto (chave = texto + índice de ocorrência).
Map<String, double> renderedSizes(GalleryRun run) {
  final counts = <String, int>{};
  final out = <String, double>{};
  for (final p in textOnly(collectProbes(run.tester))) {
    final n = counts[p.text] = (counts[p.text] ?? 0) + 1;
    out['${p.text}#$n'] = p.effectiveSize;
  }
  return out;
}

/// Compara duas execuções da MESMA tela (escala menor × maior): o texto
/// renderizado nunca pode ser menor com a escala maior.
void checkScaleMonotonic(
  Map<String, double> small,
  Map<String, double> large,
  GalleryVariant largeVariant,
  ViolationLog log,
) {
  for (final e in small.entries) {
    final l = large[e.key];
    if (l == null) continue;
    if (l < e.value - 0.01) {
      log.add(
        GalleryRules.scaleMonotonic,
        'fonte encolheu com escala maior: ${e.key.split('#').first} ${e.value.toStringAsFixed(1)} → ${l.toStringAsFixed(1)}',
        largeVariant,
      );
    }
  }
}

/// Soma/maior relatório útil para mensagens.
String summarize(List<Violation> list, {int max = 8}) {
  final b = StringBuffer();
  for (final v in list.take(max)) {
    b.writeln('  - $v');
  }
  if (list.length > max) b.writeln('  … +${list.length - max}');
  return b.toString();
}

double maxOf(Iterable<double> xs) => xs.fold(0.0, math.max);

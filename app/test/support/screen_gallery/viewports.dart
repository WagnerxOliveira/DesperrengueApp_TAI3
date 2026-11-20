import 'dart:io';

import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:flutter/material.dart';

/// Viewports, escalas de fonte, temas e modos da "Galeria de Telas" (v2.28.0).
///
/// Um [GalleryVariant] é UMA combinação (viewport × escala × brilho × modo)
/// em que uma tela é montada. As matrizes ([GalleryMatrix]) agrupam as
/// combinações usadas por cada família de testes, para o custo ficar previsível.

/// Faixa de largura do layout (espelha `AppBreakpoints` do spec §2.2).
enum GalleryBreakpoint { compact, regular, medium, expanded }

@immutable
class GalleryViewport {
  const GalleryViewport(this.name, this.size, {this.dpr = 1.0});

  final String name;

  /// Tamanho em pixels LÓGICOS.
  final Size size;
  final double dpr;

  double get width => size.width;
  double get height => size.height;

  GalleryBreakpoint get breakpoint => width < 360
      ? GalleryBreakpoint.compact
      : width < 600
      ? GalleryBreakpoint.regular
      : width < 900
      ? GalleryBreakpoint.medium
      : GalleryBreakpoint.expanded;

  bool get isWeb => width >= 900;

  @override
  String toString() => name;
}

const GalleryViewport vp320 = GalleryViewport('320x640', Size(320, 640));
const GalleryViewport vp360 = GalleryViewport('360x780', Size(360, 780));
const GalleryViewport vp390 = GalleryViewport('390x844', Size(390, 844));
const GalleryViewport vp412 = GalleryViewport('412x915', Size(412, 915));
const GalleryViewport vp600 = GalleryViewport('600x960', Size(600, 960));
const GalleryViewport vp1280 = GalleryViewport('web1280x800', Size(1280, 800));
const GalleryViewport vp1920 = GalleryViewport('web1920x1080', Size(1920, 1080));

/// Os 7 viewports do contrato (§6.1).
const List<GalleryViewport> kGalleryViewports = <GalleryViewport>[vp320, vp360, vp390, vp412, vp600, vp1280, vp1920];

/// Escalas de fonte do sistema do contrato (o app limita em 1.5 no `builder`).
const List<double> kGalleryScales = <double>[1.0, 1.35, 1.5];

@immutable
class GalleryVariant {
  const GalleryVariant({
    required this.viewport,
    this.scale = 1.0,
    this.brightness = Brightness.light,
    this.mode,
    this.disableAnimations = false,
  });

  final GalleryViewport viewport;
  final double scale;
  final Brightness brightness;

  /// `null` = tema da marca (login/KYC); `client` = laranja; `provider` = azul.
  final UserMode? mode;
  final bool disableAnimations;

  bool get isDark => brightness == Brightness.dark;

  String get modeLabel => switch (mode) {
    UserMode.client => 'cliente',
    UserMode.provider => 'profissional',
    null => 'marca',
  };

  GalleryVariant copyWith({
    GalleryViewport? viewport,
    double? scale,
    Brightness? brightness,
    Object? mode = _keep,
    bool? disableAnimations,
  }) => GalleryVariant(
    viewport: viewport ?? this.viewport,
    scale: scale ?? this.scale,
    brightness: brightness ?? this.brightness,
    mode: identical(mode, _keep) ? this.mode : mode as UserMode?,
    disableAnimations: disableAnimations ?? this.disableAnimations,
  );

  /// Rótulo curto e estável (entra nas mensagens e no relatório).
  String get label => '${viewport.name} @${scale.toStringAsFixed(2)} ${isDark ? 'escuro' : 'claro'} $modeLabel';

  @override
  String toString() => label;

  @override
  bool operator ==(Object other) =>
      other is GalleryVariant &&
      other.viewport.name == viewport.name &&
      other.scale == scale &&
      other.brightness == brightness &&
      other.mode == mode &&
      other.disableAnimations == disableAnimations;

  @override
  int get hashCode => Object.hash(viewport.name, scale, brightness, mode, disableAnimations);
}

const Object _keep = Object();

/// Matrizes pré-definidas (cada família de testes escolhe a sua).
abstract final class GalleryMatrix {
  /// Matriz completa do contrato: 7 viewports × 3 escalas × 2 temas × 2 modos
  /// (= 84 combinações/tela). Só para execuções pontuais (`GALLERY_FULL=1`).
  static List<GalleryVariant> full() => <GalleryVariant>[
    for (final vp in kGalleryViewports)
      for (final s in kGalleryScales)
        for (final b in Brightness.values)
          for (final m in const <UserMode>[UserMode.client, UserMode.provider])
            GalleryVariant(viewport: vp, scale: s, brightness: b, mode: m),
  ];

  /// Matriz AMPLIADA de layout (11 combinações) — GALLERY_FULL=1.
  static List<GalleryVariant> layoutFull(UserMode? mode) => <GalleryVariant>[
    GalleryVariant(viewport: vp320, scale: 1.0, mode: mode),
    GalleryVariant(viewport: vp320, scale: 1.35, mode: mode),
    GalleryVariant(viewport: vp320, scale: 1.5, mode: mode),
    GalleryVariant(viewport: vp360, scale: 1.0, mode: mode),
    GalleryVariant(viewport: vp390, scale: 1.0, mode: mode),
    GalleryVariant(viewport: vp412, scale: 1.35, mode: mode),
    GalleryVariant(viewport: vp600, scale: 1.0, mode: mode),
    GalleryVariant(viewport: vp1280, scale: 1.0, mode: mode),
    GalleryVariant(viewport: vp1920, scale: 1.0, mode: mode),
    GalleryVariant(viewport: vp320, scale: 1.5, brightness: Brightness.dark, mode: mode),
    GalleryVariant(viewport: vp390, scale: 1.0, brightness: Brightness.dark, mode: mode),
  ];

  /// Matriz PADRÃO de layout (6 combinações): extremos de largura/escala, claro e escuro.
  static List<GalleryVariant> layout(UserMode? mode) => <GalleryVariant>[
    GalleryVariant(viewport: vp320, scale: 1.0, mode: mode),
    GalleryVariant(viewport: vp320, scale: 1.5, mode: mode),
    GalleryVariant(viewport: vp360, scale: 1.0, brightness: Brightness.dark, mode: mode),
    GalleryVariant(viewport: vp412, scale: 1.35, mode: mode),
    GalleryVariant(viewport: vp600, scale: 1.0, mode: mode),
    GalleryVariant(viewport: vp1280, scale: 1.0, mode: mode),
  ];

  /// Tipografia/alvos/contraste: 2 viewports × claro/escuro (escala 1.0).
  static List<GalleryVariant> style(UserMode? mode) => <GalleryVariant>[
    GalleryVariant(viewport: vp360, mode: mode),
    GalleryVariant(viewport: vp360, brightness: Brightness.dark, mode: mode),
    GalleryVariant(viewport: vp1280, mode: mode),
    GalleryVariant(viewport: vp1280, brightness: Brightness.dark, mode: mode),
  ];

  /// Tipografia/alvos: 360 (celular) e 1280 (Web), claro, escala 1.0.
  static List<GalleryVariant> typography(UserMode? mode) => <GalleryVariant>[
    GalleryVariant(viewport: vp360, mode: mode),
    GalleryVariant(viewport: vp1280, mode: mode),
  ];

  /// Contraste: claro e escuro no celular.
  static List<GalleryVariant> contrast(UserMode? mode) => <GalleryVariant>[
    GalleryVariant(viewport: vp360, mode: mode),
    GalleryVariant(viewport: vp360, brightness: Brightness.dark, mode: mode),
  ];

  /// Escala de fonte monotônica (mesma tela, 3 escalas, viewport médio).
  static List<GalleryVariant> scales(UserMode? mode) => <GalleryVariant>[
    for (final s in kGalleryScales) GalleryVariant(viewport: vp390, scale: s, mode: mode),
  ];

  /// Os dois acentos (cliente laranja / profissional azul) × claro/escuro.
  static List<GalleryVariant> accents() => <GalleryVariant>[
    for (final m in const <UserMode>[UserMode.client, UserMode.provider])
      for (final b in Brightness.values) GalleryVariant(viewport: vp390, brightness: b, mode: m),
  ];

  /// Movimento: `disableAnimations` ligado, 1 viewport.
  static List<GalleryVariant> reducedMotion(UserMode? mode) => <GalleryVariant>[
    GalleryVariant(viewport: vp390, mode: mode, disableAnimations: true),
  ];
}

/// 	rue com GALLERY_FULL=1 (matriz ampliada).
bool get galleryFull => Platform.environment['GALLERY_FULL'] == '1';

/// Variantes de layout conforme o ambiente (padrão enxuto; GALLERY_FULL=1 amplia).
List<GalleryVariant> galleryLayoutVariants(UserMode? mode) =>
    galleryFull ? GalleryMatrix.layoutFull(mode) : GalleryMatrix.layout(mode);

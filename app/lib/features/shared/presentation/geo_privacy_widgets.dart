import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../core/models/scheduling_models.dart';
import '../../../core/security/geo_privacy_policy_engine.dart';
import '../../../core/services/job_service.dart';
import '../../../core/ui/app_tokens.dart';
import 'live_location_map.dart';
import 'service_map_widgets.dart' show MapAttribution;

// =============================================================================
// Trava de privacidade do endereço — widgets do MODO PROFISSIONAL.
//
// Regra: enquanto `ProviderLocationView.exactUnlocked == false` o profissional só vê
// Bairro • Cidade-UF e um CÍRCULO aproximado (raio 500–800 m, centro deslocado pelo
// servidor). Nunca há pino exato, rota, rua, número, complemento, referência ou CEP.
// A fonte da verdade é o servidor (`fetchLocationForViewer`); esta camada é a 2ª defesa.
// =============================================================================

/// Carrega a visão de localização do profissional para um serviço.
typedef ProviderLocationLoader = Future<ProviderLocationView?> Function(String jobId);

/// Ponto único de acesso à visão de localização (cache curto + falha FECHADA).
class ProviderLocationSource {
  ProviderLocationSource._();

  /// Somente testes: substitui a chamada ao servidor.
  @visibleForTesting
  static ProviderLocationLoader? debugLoader;

  static final Map<String, ({DateTime at, ProviderLocationView view})> _cache = {};
  static const Duration _ttl = Duration(seconds: 40);

  @visibleForTesting
  static void debugReset() {
    debugLoader = null;
    _cache.clear();
  }

  /// Devolve `null` quando não foi possível confirmar a fase no servidor — e a UI então
  /// mostra o estado protegido genérico (nunca endereço).
  static Future<ProviderLocationView?> load(String jobId, {bool force = false}) async {
    final custom = debugLoader;
    if (custom != null) {
      try {
        return await custom(jobId);
      } catch (_) {
        return null;
      }
    }
    final hit = _cache[jobId];
    if (!force && hit != null && DateTime.now().difference(hit.at) < _ttl) return hit.view;
    try {
      final view = await JobService().fetchLocationForViewer(jobId);
      if (view != null) _cache[jobId] = (at: DateTime.now(), view: view);
      return view;
    } catch (_) {
      return null;
    }
  }
}

/// Resolve a localização de um serviço e reconstrói quando o desbloqueio (00h00) chega.
class ProviderLocationBuilder extends StatefulWidget {
  const ProviderLocationBuilder({super.key, required this.jobId, required this.builder, this.loader});

  final String jobId;

  /// `view == null` com `loading == false` ⇒ não foi possível confirmar (mostre o estado protegido).
  final Widget Function(BuildContext context, ProviderLocationView? view, bool loading) builder;
  final ProviderLocationLoader? loader;

  @override
  State<ProviderLocationBuilder> createState() => _ProviderLocationBuilderState();
}

class _ProviderLocationBuilderState extends State<ProviderLocationBuilder> {
  ProviderLocationView? _view;
  bool _loading = true;
  Timer? _unlockTimer;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProviderLocationBuilder old) {
    super.didUpdateWidget(old);
    if (old.jobId != widget.jobId) {
      _view = null;
      _loading = true;
      _load();
    }
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    final gen = ++_gen;
    final loader = widget.loader;
    final view = loader != null
        ? await (() async {
            try {
              return await loader(widget.jobId);
            } catch (_) {
              return null;
            }
          })()
        : await ProviderLocationSource.load(widget.jobId, force: force);
    if (!mounted || gen != _gen) return;
    setState(() {
      _view = view;
      _loading = false;
    });
    _armUnlockTimer(view);
  }

  /// Quando falta pouco para o desbloqueio, rebusca no instante exato (sem polling).
  void _armUnlockTimer(ProviderLocationView? view) {
    _unlockTimer?.cancel();
    final at = view?.unlockAt;
    if (view == null || view.exactUnlocked || at == null) return;
    final wait = at.difference(DateTime.now());
    if (wait.isNegative || wait > const Duration(hours: 24)) return;
    _unlockTimer = Timer(wait + const Duration(seconds: 2), () {
      if (mounted) _load(force: true);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _view, _loading);
}

// -----------------------------------------------------------------------------
// Utilitários

String _two(int v) => v.toString().padLeft(2, '0');

/// `DD/MM/AAAA` do dia agendado (já em America/Sao_Paulo; não converte fuso).
String formatGeoDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

/// Texto de uma linha com a região (nunca rua): `Country Club • Poços de Caldas - MG`.
String protectedAreaTitle(ProviderLocationView? view) {
  final t = view?.areaTitle.trim() ?? '';
  return t.isEmpty ? 'Região protegida' : t;
}

/// `true` somente se o servidor liberou o endereço exato.
bool isExactLocationUnlocked(ProviderLocationView? view) => view != null && view.exactUnlocked;

/// Linha completa (rua, nº - complemento, bairro, cidade-UF) — vazia enquanto bloqueado.
String exactAddressLineOf(ProviderLocationView view) {
  if (!view.exactUnlocked) return '';
  final street = (view.fullStreetLine ?? '').trim();
  final hood = view.neighborhood.trim();
  final city = view.city.trim();
  final uf = view.uf.trim();
  final parts = <String>[
    if (street.isNotEmpty) street,
    if (hood.isNotEmpty) hood,
    if (city.isNotEmpty) uf.isEmpty ? city : '$city - $uf',
  ];
  return parts.join(', ');
}

/// ÚNICO caminho para abrir mapa a partir do profissional.
/// Bloqueado ⇒ mostra só a área aproximada; liberado ⇒ mapa exato em tela cheia com rota.
Future<void> openProviderLocation(
  BuildContext context,
  ProviderLocationView view, {
  Widget? tileLayerOverride,
}) {
  if (!view.exactUnlocked) {
    return ProtectedAreaMapSheet.show(context, view: view, tileLayerOverride: tileLayerOverride);
  }
  final line = exactAddressLineOf(view);
  return LiveLocationMapSheet.show(
    context,
    addressLine: line.isEmpty ? protectedAreaTitle(view) : line,
    summary: view.areaTitle,
    latitude: view.lat,
    longitude: view.lng,
    precision: view.lat != null && view.lng != null ? DestinationPrecision.exact : null,
  );
}

// -----------------------------------------------------------------------------
// Visual "Quiet Luxury" dark glass

const Color _kGlassBase = Color(0xFF0B1120);
const Color _kSeal = Color(0xFF38BDF8);

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _kGlassBase.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _kSeal.withValues(alpha: 0.42)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Selo "🔒 Segurança Residencial".
class ResidentialSecuritySeal extends StatelessWidget {
  const ResidentialSecuritySeal({super.key});

  @override
  Widget build(BuildContext context) {
    return const _GlassPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔒', style: TextStyle(fontSize: 12)),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Segurança Residencial',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cadeado compacto para cards estreitos.
class ResidentialSecuritySealCompact extends StatelessWidget {
  const ResidentialSecuritySealCompact({super.key});

  @override
  Widget build(BuildContext context) {
    return const Tooltip(
      message: 'Segurança Residencial',
      child: _GlassPill(
        padding: EdgeInsets.all(7),
        child: Text('🔒', style: TextStyle(fontSize: 12)),
      ),
    );
  }
}

/// Zoom em que o círculo ocupa ~62% do menor lado do mapa.
double _zoomForCircle({required double radiusM, required double latitude, required double minSidePx}) {
  final cosLat = math.cos(latitude * math.pi / 180).abs().clamp(0.2, 1.0);
  final targetMetersAcross = (2 * radiusM) / 0.62;
  final mPerPx = targetMetersAcross / math.max(minSidePx, 120);
  final z = math.log(156543.03392 * cosLat / mPerPx) / math.ln2;
  return z.clamp(11.0, 17.0);
}

/// Mapa do CÍRCULO de área aproximada (sem pino exato, sem rota, sem "Ajustar pino").
class ProtectedAreaMapCard extends StatelessWidget {
  const ProtectedAreaMapCard({
    super.key,
    required this.view,
    this.tileLayerOverride,
    this.height = 190,
    this.interactive = false,
    this.onTap,
  });

  final ProviderLocationView view;
  final Widget? tileLayerOverride;
  final double height;

  /// Permite arrastar/ampliar (limitado). O padrão é estático.
  final bool interactive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lat = view.lat;
    final lng = view.lng;
    final radius = (view.radiusM <= 0 ? 650 : view.radiusM).toDouble();
    final title = protectedAreaTitle(view);
    final date = view.phase == GeoPrivacyPhase.closed ? null : view.scheduledDate;
    final radiusLabel = 'Mapa da região aproximada do serviço em $title';

    final Widget body;
    if (lat == null || lng == null) {
      body = const _MapUnavailableBackdrop();
    } else {
      final center = LatLng(lat, lng);
      body = RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, c) {
            final minSide = math.min(c.maxWidth.isFinite ? c.maxWidth : 320.0, c.maxHeight.isFinite ? c.maxHeight : height);
            final zoom = _zoomForCircle(radiusM: radius, latitude: lat, minSidePx: minSide);
            return FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: zoom,
                minZoom: interactive ? math.max(10, zoom - 2) : zoom,
                maxZoom: interactive ? math.min(17, zoom + 1.5) : zoom,
                backgroundColor: const Color(0xFF0C1424),
                interactionOptions: InteractionOptions(
                  flags: interactive ? InteractiveFlag.drag | InteractiveFlag.pinchZoom : InteractiveFlag.none,
                ),
              ),
              children: [
                buildSafeMapTileLayer(context, tileLayerOverride: tileLayerOverride),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: center,
                      radius: radius,
                      useRadiusInMeter: true,
                      color: _kSeal.withValues(alpha: 0.16),
                      borderColor: _kSeal.withValues(alpha: 0.9),
                      borderStrokeWidth: 2.2,
                    ),
                  ],
                ),
                const MapAttribution(),
              ],
            );
          },
        ),
      );
    }

    return Semantics(
      container: true,
      label: radiusLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: const Color(0xFF0C1424),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              key: const ValueKey('protected-area-map-card'),
              height: height,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ExcludeSemantics(child: body),
                  // véu para legibilidade do rodapé
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0x00000000), Color(0xCC0B1120)],
                          stops: [0, 0.45, 1],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(left: 10, top: 10, right: 10, child: Align(alignment: Alignment.topLeft, child: ResidentialSecuritySeal())),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          key: const ValueKey('protected-area-title'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, height: 1.2),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          date != null ? 'Endereço liberado em ${formatGeoDate(date)}, às 00h00' : 'Região aproximada do atendimento',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600, height: 1.25),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapUnavailableBackdrop extends StatelessWidget {
  const _MapUnavailableBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0C1424), Color(0xFF14233B)]),
      ),
      child: Center(child: Icon(Icons.shield_moon_outlined, size: 44, color: Color(0x6638BDF8))),
    );
  }
}

/// Aviso de endereço protegido, ajustado à fase.
class GeoLockNotice extends StatelessWidget {
  const GeoLockNotice({super.key, required this.view});

  final ProviderLocationView view;

  /// Texto único do motor ([ProviderLocationView.lockMessage]); fallback pt-BR para liberado.
  static String messageFor(ProviderLocationView view) {
    if (view.exactUnlocked) return 'Endereço liberado para o atendimento de hoje.';
    final m = view.lockMessage;
    if (m != null && m.trim().isNotEmpty) return m;
    return '🔒 Endereço Protegido por Segurança: a rua, o número e a rota só são liberados no dia do serviço.';
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final unlocked = view.exactUnlocked;
    final accent = unlocked ? tk.success : tk.info;
    return Container(
      key: const ValueKey('geo-lock-notice'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: tk.isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.38)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(unlocked ? Icons.lock_open_rounded : Icons.lock_rounded, size: 18, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              messageFor(view),
              style: TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w600, color: tk.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Folha com a área aproximada (círculo). Nunca mostra pino exato nem rota.
class ProtectedAreaMapSheet extends StatelessWidget {
  const ProtectedAreaMapSheet({super.key, required this.view, this.tileLayerOverride});

  final ProviderLocationView view;
  final Widget? tileLayerOverride;

  static Future<void> show(
    BuildContext context, {
    required ProviderLocationView view,
    Widget? tileLayerOverride,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.tk.background,
      builder: (_) => ProtectedAreaMapSheet(view: view, tileLayerOverride: tileLayerOverride),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final screenH = MediaQuery.sizeOf(context).height;
    final mapH = (screenH * 0.40).clamp(200.0, 360.0);
    return SingleChildScrollView(
      key: const ValueKey('protected-area-map-sheet'),
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Região do serviço', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: tk.text)),
          const SizedBox(height: 4),
          Text(
            'O círculo mostra só a região aproximada. O ponto exato fica protegido.',
            style: TextStyle(fontSize: 13, color: tk.textMuted, height: 1.35),
          ),
          const SizedBox(height: 12),
          ProtectedAreaMapCard(view: view, tileLayerOverride: tileLayerOverride, height: mapH, interactive: true),
          const SizedBox(height: 12),
          GeoLockNotice(view: view),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Fechar')),
        ],
      ),
    );
  }
}

/// Bloco de endereço do profissional: travado ⇒ círculo + aviso; liberado ⇒ endereço completo
/// e botão para o mapa exato com rota.
class ProviderLocationPanel extends StatelessWidget {
  const ProviderLocationPanel({
    super.key,
    required this.view,
    this.tileLayerOverride,
    this.mapHeight = 170,
    this.onOpenExactMap,
  });

  final ProviderLocationView view;
  final Widget? tileLayerOverride;
  final double mapHeight;

  /// Abre o mapa exato (liberado). Padrão: [openProviderLocation].
  final VoidCallback? onOpenExactMap;

  @override
  Widget build(BuildContext context) {
    if (!view.exactUnlocked) {
      return Column(
        key: const ValueKey('provider-location-panel-locked'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (view.canShowApproximateArea)
            ProtectedAreaMapCard(
              view: view,
              tileLayerOverride: tileLayerOverride,
              height: mapHeight,
              onTap: () => ProtectedAreaMapSheet.show(context, view: view, tileLayerOverride: tileLayerOverride),
            )
          else
            _AreaOnlyCard(view: view),
          const SizedBox(height: 10),
          GeoLockNotice(view: view),
        ],
      );
    }
    final tk = context.tk;
    final street = (view.fullStreetLine ?? '').trim();
    final comp = (view.complement ?? '').trim();
    final ref = (view.reference ?? '').trim();
    final cep = (view.cep ?? '').trim();
    final open = onOpenExactMap ?? () => openProviderLocation(context, view, tileLayerOverride: tileLayerOverride);
    return Material(
      key: const ValueKey('provider-location-panel-unlocked'),
      color: tk.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: open,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tk.providerAccent.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.place_rounded, color: tk.providerAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          street.isNotEmpty ? street : protectedAreaTitle(view),
                          style: const TextStyle(fontWeight: FontWeight.w800, height: 1.3),
                        ),
                        if (comp.isNotEmpty && street.isEmpty)
                          Padding(padding: const EdgeInsets.only(top: 3), child: Text(comp, style: TextStyle(color: tk.text, fontSize: 13.5))),
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(protectedAreaTitle(view), style: TextStyle(color: tk.textMuted, fontSize: 12.5)),
                        ),
                        if (ref.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text('Ref: $ref', style: TextStyle(color: tk.textMuted, fontSize: 12.5))),
                        if (cep.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text('CEP $cep', style: TextStyle(color: tk.textMuted, fontSize: 12.5))),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: tk.providerAccent),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                key: const ValueKey('provider-open-precise-route-btn'),
                children: [
                  Icon(Icons.route_rounded, size: 16, color: tk.providerAccent),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Ver mapa e rota até o cliente',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: tk.providerAccent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GeoLockNotice(view: view),
            ],
          ),
        ),
      ),
    );
  }
}

/// Só Bairro • Cidade-UF (fase encerrada: sem círculo, sem coordenadas).
class _AreaOnlyCard extends StatelessWidget {
  const _AreaOnlyCard({required this.view});
  final ProviderLocationView view;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      key: const ValueKey('provider-area-only-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tk.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tk.border),
      ),
      child: Row(
        children: [
          Icon(Icons.location_city_rounded, size: 20, color: tk.providerAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              protectedAreaTitle(view),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, height: 1.3, color: tk.text),
            ),
          ),
          const ResidentialSecuritySealCompact(),
        ],
      ),
    );
  }
}

/// Estado enquanto a fase ainda não foi confirmada pelo servidor (ou falhou): protegido, sem endereço.
class ProviderLocationPending extends StatelessWidget {
  const ProviderLocationPending({super.key, required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      key: const ValueKey('provider-location-pending'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tk.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tk.border),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, size: 18, color: tk.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loading
                  ? 'Verificando a liberação do endereço…'
                  : 'Endereço Protegido por Segurança. Ele aparece aqui assim que for liberado.',
              style: TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w600, color: tk.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini-selo de região para listas/cards (Oportunidades etc.): Bairro • Cidade-UF.
class ProviderAreaLine extends StatelessWidget {
  const ProviderAreaLine({super.key, required this.jobId, this.loader});

  final String jobId;
  final ProviderLocationLoader? loader;

  @override
  Widget build(BuildContext context) {
    return ProviderLocationBuilder(
      jobId: jobId,
      loader: loader,
      builder: (context, view, loading) {
        final tk = context.tk;
        final label = view == null ? 'Região protegida' : protectedAreaTitle(view);
        return Row(
          key: const ValueKey('provider-area-line'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radar_rounded, size: 15, color: tk.warningInk),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tk.textMuted, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }
}


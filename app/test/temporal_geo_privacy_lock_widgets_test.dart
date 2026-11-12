import 'dart:async';

import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/models/provider_dossier_models.dart';
import 'package:desperrengue_app/core/models/scheduling_models.dart';
import 'package:desperrengue_app/core/security/geo_privacy_policy_engine.dart';
import 'package:desperrengue_app/core/services/scheduling_service.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/features/provider/presentation/dossie_servico_profissional_screen.dart';
import 'package:desperrengue_app/features/shared/presentation/geo_privacy_widgets.dart';
import 'package:desperrengue_app/features/shared/presentation/live_location_map.dart';
import 'package:desperrengue_app/features/shared/presentation/scheduled_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =============================================================================
// SUÍTE ADVERSARIAL DE WIDGETS E INTEGRAÇÃO — TEMPORAL & SPATIAL GEO-PRIVACY LOCK
// (ADR-0022 — Fases: ownerFull, openQuoting, confirmedFuture, serviceDay, closed)
// =============================================================================

const Widget _kOfflineTileOverride = SizedBox(
  key: ValueKey('adversarial-test-tile-override'),
);

const List<Size> _kRequiredViewports = <Size>[
  Size(360, 780),
  Size(412, 915),
  Size(320, 640),
];

const String _kExactStreet = 'Avenida Padre Cletus Francis Cox';
const String _kExactNumber = '1661';
const String _kExactApt = 'Apto 402 Bloco B';
const String _kExactRef = 'Em frente ao portão principal da PUC';
const String _kExactCep = '37701-355';
const String _kNeighborhood = 'Country Club';
const String _kCity = 'Poços de Caldas';
const String _kUf = 'MG';
const double _kExactLat = -21.786912;
const double _kExactLng = -46.561423;
const double _kFuzzyLat = -21.789150;
const double _kFuzzyLng = -46.563810;

const List<String> _kForbiddenPiiTokensWhenLocked = <String>[
  _kExactStreet,
  'Padre Cletus',
  _kExactNumber,
  _kExactApt,
  '402',
  'Bloco B',
  _kExactRef,
  _kExactCep,
  '37701',
  'Rua Secreta do Payload',
  '9999',
  'Cobertura Duplex',
];

ProviderLocationView _buildRpcDrivenProviderView({
  required GeoPrivacyPhase phase,
  required bool exactUnlocked,
  DateTime? scheduledDate,
  DateTime? unlockAt,
  int radiusM = 680,
}) {
  return ProviderLocationView.fromRpc(<String, dynamic>{
    'viewer_role': phase == GeoPrivacyPhase.ownerFull ? 'owner' : 'provider',
    'phase': switch (phase) {
      GeoPrivacyPhase.ownerFull => 'owner_full',
      GeoPrivacyPhase.openQuoting => 'open_quoting',
      GeoPrivacyPhase.confirmedFuture => 'confirmed_future',
      GeoPrivacyPhase.serviceDay => 'service_day',
      GeoPrivacyPhase.closed => 'closed',
    },
    'exact_unlocked': exactUnlocked,
    'city': _kCity,
    'uf': _kUf,
    'neighborhood': _kNeighborhood,
    'street': exactUnlocked ? _kExactStreet : null,
    'number': exactUnlocked ? _kExactNumber : null,
    'complement': exactUnlocked ? _kExactApt : null,
    'reference': exactUnlocked ? _kExactRef : null,
    'cep': exactUnlocked ? _kExactCep : null,
    'lat': phase == GeoPrivacyPhase.closed
        ? null
        : (exactUnlocked ? _kExactLat : _kFuzzyLat),
    'lng': phase == GeoPrivacyPhase.closed
        ? null
        : (exactUnlocked ? _kExactLng : _kFuzzyLng),
    'radius_m': exactUnlocked ? 100 : radiusM,
    'scheduled_date': scheduledDate != null
        ? '${scheduledDate.year.toString().padLeft(4, '0')}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}'
        : null,
    'unlock_at': unlockAt?.toUtc().toIso8601String(),
  });
}

void _configureViewport(
  WidgetTester tester,
  Size size, {
  double textScale = 1.0,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

Widget _wrapWithApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.resolve(null, Brightness.dark),
    home: Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ),
    ),
  );
}

void _assertZeroPiiLeakInWidgetTree() {
  for (final token in _kForbiddenPiiTokensWhenLocked) {
    expect(
      find.textContaining(token),
      findsNothing,
      reason: 'Vazamento de PII detectado na árvore visual: "$token"',
    );
  }
}

class _FakeSchedulingBackend implements SchedulingBackend {
  _FakeSchedulingBackend({this.dest});
  final JobDestination? dest;
  int destinationRequests = 0;

  @override
  Future<DateTime> serverTime() async => DateTime.utc(2026, 11, 15, 12);

  @override
  Future<JobDestination?> destination(String jobId) async {
    destinationRequests++;
    return dest;
  }

  @override
  Future<StartResult> startJob(
    String jobId, {
    GeoFix? position,
    bool simulate = false,
  }) async =>
      StartResult(startedAt: DateTime.now(), simulated: simulate);

  @override
  Future<JobDestination?> setLocation(
    String jobId,
    double lat,
    double lng, {
    String source = 'client_pin',
    String precision = 'house',
  }) async =>
      dest;
}

Job _sampleJob({
  required JobStatus status,
  DateTime? scheduledFor,
  String urgency = 'scheduled',
}) {
  return Job(
    id: 'aaaa1111-bbbb-2222-cccc-333333333333',
    clientId: 'client-owner-1',
    providerId: 'provider-assigned-1',
    title: 'Manutenção de Quadro Elétrico Trifásico',
    description: 'Revisão de disjuntores e barramento.',
    category: 'Elétrica',
    status: status,
    paymentStatus: status == JobStatus.awaitingPayment ? 'pending' : 'escrow',
    urgency: urgency,
    visibility: 'public',
    createdAt: DateTime.utc(2026, 11, 10, 14),
    agreedPrice: 320.0,
    scheduledFor: scheduledFor,
    publicLat: status == JobStatus.completed || status == JobStatus.canceled
        ? null
        : _kFuzzyLat,
    publicLng: status == JobStatus.completed || status == JobStatus.canceled
        ? null
        : _kFuzzyLng,
    fuzzyRadiusM: 680,
    // Simula um resumo sujo legado para provar que a UI do profissional o ignora:
    addressSummary:
        'Rua Secreta do Payload, 9999, Cobertura Duplex - Country Club, Poços de Caldas - MG',
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    try {
      await Supabase.initialize(
        url: 'http://localhost:54321',
        anonKey: 'anon-test-key',
      );
    } catch (_) {}
  });

  tearDown(ProviderLocationSource.debugReset);

  // ===========================================================================
  // (a) CLIENTE VÊ ENDEREÇO COMPLETO + MAPA EXATO EM QUALQUER FASE
  // ===========================================================================
  group('(a) Visão do Cliente (ownerFull) em todas as fases e viewports', () {
    for (final viewport in _kRequiredViewports) {
      testWidgets(
        'Cliente vê Rua, Número, Apto, CEP e DestinationMapPin exato em qualquer status (${viewport.width.toInt()}×${viewport.height.toInt()})',
        (tester) async {
          _configureViewport(tester, viewport);

          for (final status in <JobStatus>[
            JobStatus.open,
            JobStatus.awaitingPayment,
            JobStatus.scheduled,
            JobStatus.inProgress,
            JobStatus.completed,
            JobStatus.canceled,
          ]) {
            final decision = GeoPrivacyPolicyEngine.evaluate(
              role: GeoViewerRole.owner,
              status: status,
              scheduledFor: DateTime.utc(2026, 11, 25, 15),
              now: DateTime.utc(2026, 11, 12, 15),
            );
            expect(decision.phase, GeoPrivacyPhase.ownerFull);
            expect(decision.exactUnlocked, isTrue);

            await tester.pumpWidget(
              _wrapWithApp(
                InteractiveLocationPreviewCard(
                  key: ValueKey('client-preview-${status.name}'),
                  addressLine:
                      '$_kExactStreet, $_kExactNumber - $_kExactApt, $_kNeighborhood, $_kCity - $_kUf',
                  summary: '$_kNeighborhood, $_kCity - $_kUf',
                  cep: _kExactCep,
                  referencePoint: _kExactRef,
                  latitude: _kExactLat,
                  longitude: _kExactLng,
                  precision: DestinationPrecision.exact,
                  pinConfirmed: true,
                  orderStatus: status.wire,
                  tileLayerOverride: _kOfflineTileOverride,
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 60));

            expect(find.textContaining(_kExactStreet), findsWidgets);
            expect(find.textContaining(_kExactNumber), findsWidgets);
            expect(find.byType(DestinationMapPin), findsOneWidget);
            expect(find.byType(ProtectedAreaMapCard), findsNothing);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }

    testWidgets(
      'Cliente em OrderLiveMapModalScreen full-screen vê pino exato (DestinationMapPin) e endereço completo',
      (tester) async {
        _configureViewport(tester, const Size(360, 780));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.resolve(null, Brightness.dark),
            home: const OrderLiveMapModalScreen(
              addressLine:
                  '$_kExactStreet, $_kExactNumber - $_kExactApt, $_kNeighborhood, $_kCity - $_kUf',
              summary: '$_kNeighborhood, $_kCity - $_kUf',
              cep: _kExactCep,
              referencePoint: _kExactRef,
              latitude: _kExactLat,
              longitude: _kExactLng,
              precision: DestinationPrecision.exact,
              pinConfirmed: true,
              orderStatus: 'scheduled',
              tileLayerOverride: _kOfflineTileOverride,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        expect(find.byType(DestinationMapPin), findsOneWidget);
        expect(find.textContaining(_kExactStreet), findsWidgets);
        expect(find.textContaining(_kExactNumber), findsWidgets);
        expect(find.byKey(const ValueKey('adversarial-test-tile-override')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ===========================================================================
  // (b) PROFISSIONAL EM JOB ABERTO E AGENDADO PARA AMANHÃ / PRÓXIMA SEMANA
  // ===========================================================================
  group(
    '(b) Profissional em openQuoting e confirmedFuture (amanhã / próxima semana)',
    () {
      final nowSp = DateTime.parse('2026-11-12T14:00:00-03:00');
      final tomorrowSp = DateTime.parse('2026-11-13T09:00:00-03:00');
      final nextWeekSp = DateTime.parse('2026-11-19T14:00:00-03:00');

      for (final viewport in _kRequiredViewports) {
        testWidgets(
          'openQuoting + amanhã + próxima semana (${viewport.width.toInt()}×${viewport.height.toInt()}): só Cidade, Bairro e raio; ZERO rua/nº/apto e ZERO DestinationMapPin',
          (tester) async {
            _configureViewport(tester, viewport);

            final scenarios = <({String label, ProviderLocationView view})>[
              (
                label: 'openQuoting',
                view: _buildRpcDrivenProviderView(
                  phase: GeoPrivacyPhase.openQuoting,
                  exactUnlocked: false,
                ),
              ),
              (
                label: 'confirmedFuture-tomorrow',
                view: _buildRpcDrivenProviderView(
                  phase: GeoPrivacyPhase.confirmedFuture,
                  exactUnlocked: false,
                  scheduledDate: GeoPrivacyPolicyEngine.saoPauloDay(tomorrowSp),
                  unlockAt: GeoPrivacyPolicyEngine.unlockInstantFor(tomorrowSp),
                ),
              ),
              (
                label: 'confirmedFuture-nextWeek',
                view: _buildRpcDrivenProviderView(
                  phase: GeoPrivacyPhase.confirmedFuture,
                  exactUnlocked: false,
                  scheduledDate: GeoPrivacyPolicyEngine.saoPauloDay(nextWeekSp),
                  unlockAt: GeoPrivacyPolicyEngine.unlockInstantFor(nextWeekSp),
                ),
              ),
            ];

            expect(
              GeoPrivacyPolicyEngine.evaluate(
                role: GeoViewerRole.provider,
                status: JobStatus.scheduled,
                isAssignedProvider: true,
                scheduledFor: tomorrowSp,
                now: nowSp,
              ).phase,
              GeoPrivacyPhase.confirmedFuture,
            );
            expect(
              GeoPrivacyPolicyEngine.evaluate(
                role: GeoViewerRole.provider,
                status: JobStatus.scheduled,
                isAssignedProvider: true,
                scheduledFor: nextWeekSp,
                now: nowSp,
              ).phase,
              GeoPrivacyPhase.confirmedFuture,
            );

            for (final sc in scenarios) {
              await tester.pumpWidget(
                _wrapWithApp(
                  ProviderLocationPanel(
                    key: ValueKey('panel-${sc.label}'),
                    view: sc.view,
                    tileLayerOverride: _kOfflineTileOverride,
                  ),
                ),
              );
              await tester.pump();

              // Deve exibir Cidade, Bairro e raio aproximado (CircleLayer / ProtectedAreaMapCard):
              expect(find.byType(ProtectedAreaMapCard), findsOneWidget);
              expect(find.byType(CircleLayer), findsOneWidget);
              final circleLayer = tester.widget<CircleLayer>(
                find.byType(CircleLayer),
              );
              expect(circleLayer.circles, isNotEmpty);
              expect(circleLayer.circles.first.radius, 680);
              expect(circleLayer.circles.first.useRadiusInMeter, isTrue);
              expect(find.byType(GeoLockNotice), findsOneWidget);
              expect(
                find.text('$_kNeighborhood • $_kCity - $_kUf'),
                findsOneWidget,
              );

              // PROIBIDO pino exato (DestinationMapPin / MarkerLayer) e polilinha:
              expect(find.byType(DestinationMapPin), findsNothing);
              expect(find.byType(MarkerLayer), findsNothing);
              expect(find.byType(PolylineLayer), findsNothing);

              // PROIBIDO conter Rua, Número, Apto, Referência ou CEP:
              _assertZeroPiiLeakInWidgetTree();
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    },
  );

  // ===========================================================================
  // (c) PROFISSIONAL NO DIA AGENDADO (serviceDay) VÊ RUA, NÚMERO, APTO E MAPA EXATO COM ROTA
  // ===========================================================================
  group('(c) Profissional no dia agendado (serviceDay)', () {
    final serviceDayView = _buildRpcDrivenProviderView(
      phase: GeoPrivacyPhase.serviceDay,
      exactUnlocked: true,
      scheduledDate: DateTime.utc(2026, 11, 15),
    );

    for (final viewport in _kRequiredViewports) {
      testWidgets(
        'serviceDay (${viewport.width.toInt()}×${viewport.height.toInt()}): exibe Rua, Número, Apto, Referência, CEP e botão de rota exata',
        (tester) async {
          _configureViewport(tester, viewport);
          await tester.pumpWidget(
            _wrapWithApp(
              ProviderLocationPanel(
                view: serviceDayView,
                tileLayerOverride: _kOfflineTileOverride,
              ),
            ),
          );
          await tester.pump();

          expect(
            find.byKey(const ValueKey('provider-location-panel-unlocked')),
            findsOneWidget,
          );
          expect(
            find.textContaining('$_kExactStreet, $_kExactNumber'),
            findsOneWidget,
          );
          expect(find.textContaining(_kExactApt), findsOneWidget);
          expect(find.textContaining('Ref: $_kExactRef'), findsOneWidget);
          expect(find.textContaining('CEP $_kExactCep'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('provider-open-precise-route-btn')),
            findsOneWidget,
          );
          expect(find.byType(ProtectedAreaMapCard), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'No serviceDay, mapa exato exibe DestinationMapPin e PolylineLayer de rota até o imóvel',
      (tester) async {
        _configureViewport(tester, const Size(360, 780));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.resolve(null, Brightness.dark),
            home: OrderLiveMapModalScreen(
              addressLine: exactAddressLineOf(serviceDayView),
              summary: serviceDayView.areaTitle,
              cep: serviceDayView.cep,
              referencePoint: serviceDayView.reference,
              latitude: serviceDayView.lat,
              longitude: serviceDayView.lng,
              precision: DestinationPrecision.exact,
              pinConfirmed: true,
              providerOrigin: const LatLng(-21.7810, -46.5680),
              orderStatus: 'in_progress',
              tileLayerOverride: _kOfflineTileOverride,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        expect(find.byType(DestinationMapPin), findsOneWidget);
        expect(find.byType(PolylineLayer), findsWidgets);
        expect(find.textContaining(_kExactStreet), findsWidgets);
        expect(find.textContaining(_kExactNumber), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ===========================================================================
  // (d) APÓS COMPLETED / CANCELED VOLTAM A FICAR OCULTOS (LGPD RE-LOCK)
  // ===========================================================================
  group('(d) Re-bloqueio permanente pós-serviço (completed / canceled / disputed)', () {
    final closedView = _buildRpcDrivenProviderView(
      phase: GeoPrivacyPhase.closed,
      exactUnlocked: false,
    );

    for (final viewport in _kRequiredViewports) {
      testWidgets(
        'Após completed/canceled (${viewport.width.toInt()}×${viewport.height.toInt()}): Rua, Número, Apto, pino e rota voltam a ficar ocultos',
        (tester) async {
          _configureViewport(tester, viewport);

          for (final closedStatus in <JobStatus>[
            JobStatus.completed,
            JobStatus.canceled,
            JobStatus.disputed,
          ]) {
            final decision = GeoPrivacyPolicyEngine.evaluate(
              role: GeoViewerRole.provider,
              status: closedStatus,
              isAssignedProvider: true,
              scheduledFor: DateTime.parse('2026-11-12T10:00:00-03:00'),
              now: DateTime.parse('2026-11-12T18:00:00-03:00'),
            );
            expect(decision.phase, GeoPrivacyPhase.closed);
            expect(decision.exactUnlocked, isFalse);
          }

          await tester.pumpWidget(
            _wrapWithApp(
              ProviderLocationPanel(
                view: closedView,
                tileLayerOverride: _kOfflineTileOverride,
              ),
            ),
          );
          await tester.pump();

          expect(
            find.byKey(const ValueKey('provider-area-only-card')),
            findsOneWidget,
          );
          expect(
            find.text('$_kNeighborhood • $_kCity - $_kUf'),
            findsOneWidget,
          );
          expect(find.byType(DestinationMapPin), findsNothing);
          expect(find.byType(MarkerLayer), findsNothing);
          expect(find.byType(PolylineLayer), findsNothing);
          expect(find.byType(FlutterMap), findsNothing);
          _assertZeroPiiLeakInWidgetTree();
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'Dossiê do profissional em serviço completed ignora address_line legado e oculta rua/nº/apto',
      (tester) async {
        _configureViewport(tester, const Size(360, 2000));
        final legacyDossier = ProviderJobDossier.fromMap(<String, dynamic>{
          'job_id': 'job-closed-1',
          'code': '#DSP-77123',
          'title': 'Manutenção Elétrica Concluída',
          'status': 'completed',
          'address_line': '$_kExactStreet, $_kExactNumber',
          'complement': _kExactApt,
          'reference': _kExactRef,
          'address_summary': '$_kExactStreet, $_kExactNumber - $_kNeighborhood',
          'client': <String, dynamic>{'name': 'Cliente Teste'},
          'gross': 320.0,
          'fee': 48.0,
          'fee_pct': 15.0,
          'net': 272.0,
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.resolve(null, Brightness.dark),
            home: DossieServicoProfissionalScreen(
              jobId: 'job-closed-1',
              loader: (_) async => legacyDossier,
              locationLoader: (_) async => closedView,
              imageBuilder:
                  (context, path, {width, height, fit = BoxFit.cover, radius = 12}) =>
                      const SizedBox.shrink(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Região do atendimento'), findsOneWidget);
        expect(find.text('$_kNeighborhood • $_kCity - $_kUf'), findsOneWidget);
        _assertZeroPiiLeakInWidgetTree();
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ===========================================================================
  // (e) FRONTEIRA EXATA 23:59:59 vs 00:00:00 (America/Sao_Paulo UTC-3)
  // ===========================================================================
  group('(e) Fronteira 23:59:59 vs 00:00:00 em America/Sao_Paulo (UTC-3)', () {
    for (final viewport in _kRequiredViewports) {
      testWidgets(
        'Transição 23:59:59 SP (travado) -> 00:00:00 SP (destravado) (${viewport.width.toInt()}×${viewport.height.toInt()})',
        (tester) async {
          _configureViewport(tester, viewport);

          // Agendado para 20/11/2026 às 14:30 SP (17:30Z)
          final scheduledFor = DateTime.parse('2026-11-20T14:30:00-03:00');
          // 19/11/2026 às 23:59:59 SP = 20/11/2026 às 02:59:59Z (em UTC já é dia 20, mas em SP ainda é dia 19!)
          final at235959Sp = DateTime.parse('2026-11-19T23:59:59-03:00');
          // 20/11/2026 às 00:00:00 SP = 20/11/2026 às 03:00:00Z
          final at000000Sp = DateTime.parse('2026-11-20T00:00:00-03:00');

          final decision2359 = GeoPrivacyPolicyEngine.evaluate(
            role: GeoViewerRole.provider,
            status: JobStatus.scheduled,
            isAssignedProvider: true,
            scheduledFor: scheduledFor,
            now: at235959Sp,
          );
          expect(decision2359.phase, GeoPrivacyPhase.confirmedFuture);
          expect(decision2359.exactUnlocked, isFalse);

          final decision0000 = GeoPrivacyPolicyEngine.evaluate(
            role: GeoViewerRole.provider,
            status: JobStatus.scheduled,
            isAssignedProvider: true,
            scheduledFor: scheduledFor,
            now: at000000Sp,
          );
          expect(decision0000.phase, GeoPrivacyPhase.serviceDay);
          expect(decision0000.exactUnlocked, isTrue);

          final viewAt2359 = _buildRpcDrivenProviderView(
            phase: decision2359.phase,
            exactUnlocked: decision2359.exactUnlocked,
            scheduledDate: decision2359.scheduledDay,
            unlockAt: decision2359.unlockAt,
          );

          final viewAt0000 = _buildRpcDrivenProviderView(
            phase: decision0000.phase,
            exactUnlocked: decision0000.exactUnlocked,
            scheduledDate: decision0000.scheduledDay,
            unlockAt: decision0000.unlockAt,
          );

          // 1) Às 23:59:59 SP: TRAVADO
          await tester.pumpWidget(
            _wrapWithApp(
              ProviderLocationPanel(
                key: const ValueKey('boundary-2359'),
                view: viewAt2359,
                tileLayerOverride: _kOfflineTileOverride,
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(ProtectedAreaMapCard), findsOneWidget);
          expect(find.byType(CircleLayer), findsOneWidget);
          expect(find.byType(DestinationMapPin), findsNothing);
          expect(find.textContaining('20/11/2026'), findsWidgets);
          _assertZeroPiiLeakInWidgetTree();

          // 2) Às 00:00:00 SP: DESTRAVADO
          await tester.pumpWidget(
            _wrapWithApp(
              ProviderLocationPanel(
                key: const ValueKey('boundary-0000'),
                view: viewAt0000,
                tileLayerOverride: _kOfflineTileOverride,
              ),
            ),
          );
          await tester.pump();

          expect(
            find.byKey(const ValueKey('provider-location-panel-unlocked')),
            findsOneWidget,
          );
          expect(
            find.textContaining('$_kExactStreet, $_kExactNumber'),
            findsOneWidget,
          );
          expect(find.textContaining(_kExactApt), findsOneWidget);
          expect(
            find.byKey(const ValueKey('provider-open-precise-route-btn')),
            findsOneWidget,
          );
          expect(find.byType(ProtectedAreaMapCard), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'ScheduledServiceScreen no lado profissional mantém trava às 23:59:59 SP e libera endereço + destino às 00:00:00 SP',
      (tester) async {
        _configureViewport(tester, const Size(360, 2600));
        final scheduledFor = DateTime.parse('2026-11-20T14:30:00-03:00');
        final backend = _FakeSchedulingBackend(
          dest: const JobDestination(
            lat: _kExactLat,
            lng: _kExactLng,
            precision: DestinationPrecision.exact,
            radiusM: 100,
            source: 'client_pin',
          ),
        );

        var isPastMidnightSp = false;
        Future<ProviderLocationView?> dynamicLoader(String _) async {
          if (!isPastMidnightSp) {
            return _buildRpcDrivenProviderView(
              phase: GeoPrivacyPhase.confirmedFuture,
              exactUnlocked: false,
              scheduledDate: DateTime.utc(2026, 11, 20),
              unlockAt: DateTime.now().subtract(const Duration(seconds: 1)),
            );
          }
          return _buildRpcDrivenProviderView(
            phase: GeoPrivacyPhase.serviceDay,
            exactUnlocked: true,
            scheduledDate: DateTime.utc(2026, 11, 20),
          );
        }

        final deps = SchedulingDeps(
          backend: backend,
          requestLocation: () async => LocationAccess.granted,
          positions: () => const Stream<GeoFix>.empty(),
          address: (_) async => <String, dynamic>{
            'address_line': 'Rua Secreta do Payload, 9999',
            'reference': _kExactRef,
          },
          clientCard: (_) async => <String, dynamic>{'full_name': 'Cliente SP'},
          peer: (_) async => (name: 'Profissional SP', avatar: null),
          geocode: (_, _) async => null,
          location: dynamicLoader,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.resolve(null, Brightness.dark),
            home: ScheduledServiceScreen(
              job: _sampleJob(
                status: JobStatus.scheduled,
                scheduledFor: scheduledFor,
              ),
              asProvider: true,
              deps: deps,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        // Antes da virada: zero requisição ao destino exato e zero PII na tela
        expect(backend.destinationRequests, 0);
        expect(
          find.byKey(const ValueKey('provider-location-panel-locked')),
          findsOneWidget,
        );
        _assertZeroPiiLeakInWidgetTree();

        // Virada 00:00:00 SP:
        isPastMidnightSp = true;
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.byKey(const ValueKey('provider-location-panel-unlocked')),
          findsOneWidget,
        );
        expect(
          find.textContaining('$_kExactStreet, $_kExactNumber'),
          findsOneWidget,
        );
        expect(backend.destinationRequests, greaterThan(0));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}

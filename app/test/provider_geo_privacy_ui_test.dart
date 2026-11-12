import 'dart:async';

import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/models/provider_dossier_models.dart';
import 'package:desperrengue_app/core/models/scheduling_models.dart';
import 'package:desperrengue_app/core/security/geo_privacy_policy_engine.dart';
import 'package:desperrengue_app/core/services/scheduling_service.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/features/provider/presentation/dossie_servico_profissional_screen.dart';
import 'package:desperrengue_app/features/shared/presentation/geo_privacy_widgets.dart';
import 'package:desperrengue_app/features/shared/presentation/scheduled_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Visões do servidor para cada fase (o app do profissional NUNCA recebe rua/número
// antes do desbloqueio; os campos `street` etc. só vêm preenchidos em serviceDay).
// ---------------------------------------------------------------------------

final _day = DateTime.utc(2030, 1, 15);

final openView = ProviderLocationView(
  phase: GeoPrivacyPhase.openQuoting,
  exactUnlocked: false,
  city: 'Poços de Caldas',
  uf: 'MG',
  neighborhood: 'Country Club',
  lat: -21.7871,
  lng: -46.5612,
  radiusM: 650,
);

final futureView = ProviderLocationView(
  phase: GeoPrivacyPhase.confirmedFuture,
  exactUnlocked: false,
  city: 'Poços de Caldas',
  uf: 'MG',
  neighborhood: 'Country Club',
  lat: -21.7871,
  lng: -46.5612,
  radiusM: 650,
  scheduledDate: _day,
  unlockAt: _day.add(const Duration(hours: 3)),
);

const serviceDayView = ProviderLocationView(
  phase: GeoPrivacyPhase.serviceDay,
  exactUnlocked: true,
  city: 'Poços de Caldas',
  uf: 'MG',
  neighborhood: 'Country Club',
  street: 'Avenida Padre Cletus',
  number: '1661',
  complement: 'Apto 12',
  reference: 'Portão azul',
  cep: '37701-000',
  lat: -21.7869,
  lng: -46.5614,
  radiusM: 100,
);

const closedView = ProviderLocationView(
  phase: GeoPrivacyPhase.closed,
  exactUnlocked: false,
  city: 'Poços de Caldas',
  uf: 'MG',
  neighborhood: 'Country Club',
);

/// Visão adulterada: servidor "esqueceu" de zerar a rua mesmo travado (defesa em profundidade).
const leakyLockedView = ProviderLocationView(
  phase: GeoPrivacyPhase.confirmedFuture,
  exactUnlocked: false,
  city: 'Poços de Caldas',
  uf: 'MG',
  neighborhood: 'Country Club',
  street: 'Rua Vazada',
  number: '99',
  complement: 'Casa dos fundos',
  reference: 'Ao lado do mercado',
  cep: '37701-999',
  lat: -21.7871,
  lng: -46.5612,
  radiusM: 650,
);

const _forbiddenWhenLocked = [
  'Avenida Padre Cletus',
  '1661',
  'Apto 12',
  'Portão azul',
  '37701',
  'Rua Vazada',
  'Casa dos fundos',
  'Ao lado do mercado',
  'Ver mapa e rota',
  'Ajustar',
  'Waze',
  'Copiar',
];

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.resolve(null, Brightness.dark),
      home: Scaffold(body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child))),
    );

void _size(WidgetTester t, double w, double h, {double scale = 1.0}) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1.0;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    t.view.reset();
    t.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

void _expectNoLeak(List<String> forbidden) {
  for (final s in forbidden) {
    expect(find.textContaining(s), findsNothing, reason: 'vazou "$s"');
  }
}

class _Backend implements SchedulingBackend {
  _Backend({this.dest});
  JobDestination? dest;
  int destinationCalls = 0;
  @override
  Future<DateTime> serverTime() async => DateTime.now();
  @override
  Future<JobDestination?> destination(String jobId) async {
    destinationCalls++;
    return dest;
  }

  @override
  Future<StartResult> startJob(String jobId, {GeoFix? position, bool simulate = false}) async =>
      StartResult(startedAt: DateTime.now(), simulated: simulate);

  @override
  Future<JobDestination?> setLocation(String jobId, double lat, double lng,
          {String source = 'client_pin', String precision = 'house'}) async =>
      dest;
}

Job _job({JobStatus status = JobStatus.scheduled, DateTime? at}) => Job(
      id: '11111111-2222-3333-4444-555555555555',
      clientId: 'c',
      title: 'Instalar chuveiro',
      description: 'Trocar o chuveiro da suíte.',
      category: 'Elétrica',
      status: status,
      paymentStatus: 'escrow',
      urgency: 'scheduled',
      visibility: 'direct',
      createdAt: DateTime(2026, 10, 29),
      providerId: 'p',
      agreedPrice: 150,
      scheduledFor: at ?? DateTime.now(),
      // Mesmo que o modelo traga um resumo com rua, a tela do profissional não pode usá-lo.
      addressSummary: 'Rua Do Resumo Vazado, 77 - Country Club, Poços de Caldas - MG',
    );

SchedulingDeps _deps(_Backend b, Future<ProviderLocationView?> Function(String) loc) => SchedulingDeps(
      backend: b,
      requestLocation: () async => LocationAccess.granted,
      positions: () => const Stream<GeoFix>.empty(),
      address: (_) async => {'address_line': 'Rua Do Job Address Vazado, 5', 'reference': 'Vazou'},
      clientCard: (_) async => {'full_name': 'Carla Souza'},
      peer: (_) async => (name: 'Paulo', avatar: null),
      geocode: (_, _) async => null,
      location: loc,
    );

Future<void> _pumpLoaded(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(url: 'http://localhost', anonKey: 'anon');
    } catch (_) {}
  });
  tearDown(ProviderLocationSource.debugReset);

  // ------------------------------------------------------------------ widgets
  for (final size in const [Size(320, 640), Size(360, 780), Size(412, 915), Size(480, 900)]) {
    group('ProviderLocationPanel ${size.width.toInt()}×${size.height.toInt()}', () {
      testWidgets('openQuoting: círculo aproximado, sem pino, rota nem endereço', (t) async {
        _size(t, size.width, size.height, scale: 1.3);
        await t.pumpWidget(_host(ProviderLocationPanel(view: openView)));
        await t.pump();
        expect(find.byKey(const ValueKey('provider-location-panel-locked')), findsOneWidget);
        expect(find.byType(ProtectedAreaMapCard), findsOneWidget);
        expect(find.byType(CircleLayer), findsOneWidget);
        expect(find.byType(MarkerLayer), findsNothing, reason: 'pino exato proibido');
        expect(find.byType(PolylineLayer), findsNothing, reason: 'rota proibida');
        expect(find.text('Country Club • Poços de Caldas - MG'), findsOneWidget);
        expect(find.textContaining('Segurança Residencial'), findsOneWidget);
        expect(find.byKey(const ValueKey('geo-lock-notice')), findsOneWidget);
        expect(find.textContaining('Endereço Protegido por Segurança'), findsOneWidget);
        _expectNoLeak(_forbiddenWhenLocked);
        expect(t.takeException(), isNull);
      });

      testWidgets('confirmedFuture: data de liberação DD/MM/AAAA e nada de endereço', (t) async {
        _size(t, size.width, size.height, scale: 1.3);
        await t.pumpWidget(_host(ProviderLocationPanel(view: futureView)));
        await t.pump();
        expect(find.byType(CircleLayer), findsOneWidget);
        expect(find.byType(MarkerLayer), findsNothing);
        expect(find.textContaining('15/01/2030'), findsWidgets);
        expect(find.textContaining('00h00'), findsWidgets);
        _expectNoLeak(_forbiddenWhenLocked);
        expect(t.takeException(), isNull);
      });

      testWidgets('serviceDay: libera rua, número, complemento, referência e CEP', (t) async {
        _size(t, size.width, size.height, scale: 1.3);
        await t.pumpWidget(_host(ProviderLocationPanel(view: serviceDayView)));
        await t.pump();
        expect(find.byKey(const ValueKey('provider-location-panel-unlocked')), findsOneWidget);
        expect(find.textContaining('Avenida Padre Cletus, 1661'), findsOneWidget);
        expect(find.textContaining('Apto 12'), findsOneWidget);
        expect(find.textContaining('Ref: Portão azul'), findsOneWidget);
        expect(find.textContaining('CEP 37701-000'), findsOneWidget);
        expect(find.byKey(const ValueKey('provider-open-precise-route-btn')), findsOneWidget);
        expect(find.byType(ProtectedAreaMapCard), findsNothing);
        expect(find.byType(CircleLayer), findsNothing);
        expect(t.takeException(), isNull);
      });

      testWidgets('closed: volta a só Bairro • Cidade-UF (sem mapa nem círculo)', (t) async {
        _size(t, size.width, size.height, scale: 1.3);
        await t.pumpWidget(_host(ProviderLocationPanel(view: closedView)));
        await t.pump();
        expect(find.byKey(const ValueKey('provider-area-only-card')), findsOneWidget);
        expect(find.text('Country Club • Poços de Caldas - MG'), findsOneWidget);
        expect(find.byType(CircleLayer), findsNothing);
        expect(find.byType(FlutterMap), findsNothing);
        expect(find.textContaining('Atendimento encerrado'), findsOneWidget);
        _expectNoLeak(_forbiddenWhenLocked);
        expect(t.takeException(), isNull);
      });
    });
  }

  testWidgets('defesa em profundidade: visão travada com campos vazados NUNCA exibe rua/número/CEP', (t) async {
    _size(t, 360, 780);
    await t.pumpWidget(_host(ProviderLocationPanel(view: leakyLockedView)));
    await t.pump();
    _expectNoLeak(_forbiddenWhenLocked);
    expect(find.byType(CircleLayer), findsOneWidget);
    expect(find.byType(MarkerLayer), findsNothing);
    // o único ponto de abertura de mapa recusa expor o exato quando travado
    expect(leakyLockedView.fullStreetLine, isNull);
    expect(exactAddressLineOf(leakyLockedView), isEmpty);
  });

  testWidgets('ProtectedAreaMapCard sem coordenadas (negado): não quebra e continua protegido', (t) async {
    _size(t, 320, 640);
    await t.pumpWidget(_host(const ProtectedAreaMapCard(view: closedView)));
    await t.pump();
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Country Club • Poços de Caldas - MG'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('tileLayerOverride é respeitado (offline-safe em teste)', (t) async {
    _size(t, 360, 780);
    await t.pumpWidget(_host(ProtectedAreaMapCard(view: openView, tileLayerOverride: const SizedBox(key: ValueKey('tile-fake')))));
    await t.pump();
    expect(find.byKey(const ValueKey('tile-fake')), findsOneWidget);
  });

  testWidgets('ProtectedAreaMapSheet abre com círculo, sem pino/rota/ajuste, e fecha', (t) async {
    _size(t, 360, 780);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.resolve(null, Brightness.dark),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => ProtectedAreaMapSheet.show(context, view: futureView),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('protected-area-map-sheet')), findsOneWidget);
    expect(find.byType(CircleLayer), findsOneWidget);
    expect(find.byType(MarkerLayer), findsNothing);
    expect(find.byType(PolylineLayer), findsNothing);
    expect(find.textContaining('Ajustar'), findsNothing);
    expect(find.textContaining('15/01/2030'), findsWidgets);
    await t.ensureVisible(find.text('Fechar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Fechar'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('protected-area-map-sheet')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('openProviderLocation: travado abre só a área aproximada (nunca o mapa exato)', (t) async {
    _size(t, 360, 780);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.resolve(null, Brightness.dark),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(child: TextButton(onPressed: () => openProviderLocation(context, leakyLockedView), child: const Text('abrir'))),
        ),
      ),
    ));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('protected-area-map-sheet')), findsOneWidget);
    _expectNoLeak(_forbiddenWhenLocked);
  });

  // ------------------------------------------------------------ fonte da verdade
  testWidgets('ProviderAreaLine (Oportunidades): só Bairro • Cidade-UF; falha de rede ⇒ "Região protegida"', (t) async {
    _size(t, 320, 640);
    await t.pumpWidget(_host(ProviderAreaLine(jobId: 'a', loader: (_) async => openView)));
    await t.pump();
    await t.pump();
    expect(find.text('Country Club • Poços de Caldas - MG'), findsOneWidget);

    await t.pumpWidget(_host(ProviderAreaLine(jobId: 'b', loader: (_) async => throw StateError('offline'))));
    await t.pump();
    await t.pump();
    expect(find.text('Região protegida'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('ProviderLocationBuilder rebusca no instante do desbloqueio (00h00) sem polling', (t) async {
    _size(t, 360, 780);
    var calls = 0;
    final soon = ProviderLocationView(
      phase: GeoPrivacyPhase.confirmedFuture,
      exactUnlocked: false,
      city: 'Poços de Caldas',
      uf: 'MG',
      neighborhood: 'Country Club',
      lat: -21.7871,
      lng: -46.5612,
      radiusM: 650,
      unlockAt: DateTime.now().add(const Duration(seconds: 10)),
    );
    await t.pumpWidget(_host(ProviderLocationBuilder(
      jobId: 'j',
      loader: (_) async => ++calls == 1 ? soon : serviceDayView,
      builder: (context, view, loading) => view == null ? const Text('...') : ProviderLocationPanel(view: view),
    )));
    await t.pump();
    await t.pump();
    expect(calls, 1);
    expect(find.byKey(const ValueKey('provider-location-panel-locked')), findsOneWidget);
    await t.pump(const Duration(seconds: 14));
    await t.pump();
    expect(calls, 2);
    expect(find.byKey(const ValueKey('provider-location-panel-unlocked')), findsOneWidget);
    expect(find.textContaining('Avenida Padre Cletus, 1661'), findsOneWidget);
    // Ao sair da tela o temporizador é cancelado (sem timers pendentes).
    await t.pumpWidget(const SizedBox());
  });

  // -------------------------------------------------------------- dossiê (4 fases)
  group('Dossiê do profissional respeita a trava', () {
    ProviderJobDossier dossier() => ProviderJobDossier.fromMap({
          'job_id': 'j1',
          'code': '#DSP-1A2B3',
          'title': 'Instalar chuveiro',
          'status': 'completed',
          'address_line': 'Rua Vazada Dossie, 100',
          'complement': 'Apto 12',
          'reference': 'Perto da padaria',
          'address_summary': 'Rua Vazada Dossie, 100 - Centro',
          'client': {'name': 'Maria Souza'},
          'gross': 150.0,
          'fee': 18.0,
          'fee_pct': 12.0,
          'net': 132.0,
        });

    Future<void> open(WidgetTester t, ProviderLocationView? v) async {
      _size(t, 360, 2400);
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.resolve(null, Brightness.dark),
        home: DossieServicoProfissionalScreen(
          jobId: 'j1',
          loader: (_) async => dossier(),
          locationLoader: (_) async => v,
          imageBuilder: (context, path, {width, height, fit = BoxFit.cover, radius = 12}) => const SizedBox(),
        ),
      ));
      await t.pump();
      await t.pump();
      await t.pump();
    }

    for (final entry in {
      'openQuoting': openView,
      'confirmedFuture': futureView,
      'closed': closedView,
    }.entries) {
      testWidgets('${entry.key}: só a região; nenhum endereço do payload do dossiê aparece', (t) async {
        await open(t, entry.value);
        expect(find.text('Região do atendimento'), findsOneWidget);
        expect(find.text('Country Club • Poços de Caldas - MG'), findsOneWidget);
        expect(find.byKey(const ValueKey('geo-lock-notice')), findsOneWidget);
        expect(find.textContaining('Rua Vazada Dossie'), findsNothing);
        expect(find.textContaining('Perto da padaria'), findsNothing);
        expect(find.textContaining('Apto 12'), findsNothing);
        expect(find.textContaining('Toque para ver no mapa'), findsNothing);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('serviceDay: mostra a linha completa liberada pelo servidor e o atalho do mapa', (t) async {
      await open(t, serviceDayView);
      expect(find.text('Endereço atendido'), findsOneWidget);
      expect(find.textContaining('Avenida Padre Cletus, 1661 - Apto 12'), findsOneWidget);
      expect(find.textContaining('Toque para ver no mapa'), findsOneWidget);
      expect(find.textContaining('Rua Vazada Dossie'), findsNothing, reason: 'sempre a visão do servidor, não o payload do dossiê');
      expect(t.takeException(), isNull);
    });

    testWidgets('falha ao confirmar a fase: nada de endereço (falha fechada)', (t) async {
      await open(t, null);
      expect(find.textContaining('Rua Vazada Dossie'), findsNothing);
      expect(find.text('Endereço atendido'), findsNothing);
    });
  });

  // ------------------------------------------------ agenda / pré-serviço (4 fases)
  group('ScheduledServiceScreen (profissional)', () {
    Future<void> open(WidgetTester t, _Backend b, Future<ProviderLocationView?> Function(String) loc, {JobStatus status = JobStatus.scheduled}) async {
      _size(t, 360, 3000);
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.resolve(null, Brightness.dark),
        home: ScheduledServiceScreen(job: _job(status: status), asProvider: true, deps: _deps(b, loc)),
      ));
      await _pumpLoaded(t);
    }

    for (final entry in {'openQuoting': openView, 'confirmedFuture': futureView, 'closed': closedView}.entries) {
      testWidgets('${entry.key}: não busca destino exato, não usa job_addresses nem resumo do pedido', (t) async {
        final backend = _Backend(dest: const JobDestination(lat: -21.7869, lng: -46.5614, precision: DestinationPrecision.exact, radiusM: 100, source: 'client_pin'));
        await open(t, backend, (_) async => entry.value);
        expect(backend.destinationCalls, 0, reason: 'coordenada exata não pode nem ser requisitada antes do dia');
        _expectNoLeak(['Rua Do Resumo Vazado', 'Rua Do Job Address Vazado', 'Vazou', ..._forbiddenWhenLocked]);
        expect(find.byType(MarkerLayer), findsNothing);
        expect(find.textContaining('distância atual'), findsNothing);
        expect(find.textContaining('liberados às 00h00'), findsWidgets);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('serviceDay: endereço completo liberado e destino exato carregado', (t) async {
      final backend = _Backend(dest: const JobDestination(lat: -21.7869, lng: -46.5614, precision: DestinationPrecision.exact, radiusM: 100, source: 'client_pin'));
      await open(t, backend, (_) async => serviceDayView);
      expect(backend.destinationCalls, greaterThan(0));
      expect(find.byKey(const ValueKey('provider-location-panel-unlocked')), findsOneWidget);
      expect(find.textContaining('Avenida Padre Cletus, 1661'), findsOneWidget);
      expect(find.textContaining('Rua Do Resumo Vazado'), findsNothing);
      expect(find.textContaining('Rua Do Job Address Vazado'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('falha ao confirmar a fase: continua protegido e sem endereço', (t) async {
      final backend = _Backend();
      await open(t, backend, (_) async => null);
      expect(find.byKey(const ValueKey('provider-location-pending')), findsOneWidget);
      expect(backend.destinationCalls, 0);
      _expectNoLeak(['Rua Do Resumo Vazado', 'Rua Do Job Address Vazado', ..._forbiddenWhenLocked]);
    });

    testWidgets('virada do dia (relógio do servidor passa do unlockAt): endereço e destino aparecem sem reabrir a tela', (t) async {
      var calls = 0;
      final justPassed = ProviderLocationView(
        phase: GeoPrivacyPhase.confirmedFuture,
        exactUnlocked: false,
        city: 'Poços de Caldas',
        uf: 'MG',
        neighborhood: 'Country Club',
        lat: -21.7871,
        lng: -46.5612,
        radiusM: 650,
        scheduledDate: _day,
        unlockAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      final backend = _Backend(dest: const JobDestination(lat: -21.7869, lng: -46.5614, precision: DestinationPrecision.exact, radiusM: 100, source: 'client_pin'));
      await open(t, backend, (_) async => ++calls == 1 ? justPassed : serviceDayView);
      expect(find.byKey(const ValueKey('provider-location-panel-locked')), findsOneWidget);
      expect(backend.destinationCalls, 0);
      await t.pump(const Duration(seconds: 2));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('provider-location-panel-unlocked')), findsOneWidget);
      expect(find.textContaining('Avenida Padre Cletus, 1661'), findsOneWidget);
      expect(backend.destinationCalls, greaterThan(0));
      await t.pumpWidget(const SizedBox());
    });
  });
}

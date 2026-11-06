import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:desperrengue_app/core/models/geocode_models.dart';
import 'package:desperrengue_app/core/models/scheduling_models.dart';
import 'package:desperrengue_app/core/services/address_lookup.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/features/client/presentation/address_form.dart';
import 'package:desperrengue_app/features/shared/presentation/live_location_map.dart';
import 'package:desperrengue_app/features/shared/presentation/service_map_widgets.dart';

/// Localização exata: o pino é fixo no centro e o cliente arrasta o mapa; o ponto só vale para o
/// endereço em que foi marcado; coordenadas de CEP (imprecisas) nunca viram o pino do serviço.
Widget host(Widget child) => MaterialApp(theme: AppTheme.resolve(null, Brightness.light), home: child);

void tall(WidgetTester t, {double h = 6000}) {
  t.view.physicalSize = Size(1080, h);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
}

class _Geo implements AddressGeocoder {
  _Geo(this.hit);
  final GeocodeHit? hit;
  final lines = <String>[];
  @override
  Future<GeocodeHit?> geocode(String addressLine, {String? summary, String? cep}) async {
    lines.add(addressLine);
    return hit;
  }
}

const _tiles = SizedBox.shrink(); // sem rede nos testes

void main() {
  // ---------------------------------------------------------------- LocationPickerSheet
  group('LocationPickerSheet (pino fixo no centro; arraste o mapa)', () {
    const initial = JobDestination(lat: -21.8027, lng: -46.6028, precision: DestinationPrecision.street, radiusM: 250, source: 'client_geocode');

    Future<List<(double, double)>> open(WidgetTester t, {JobDestination? start = initial, Future<void> Function(double, double)? onConfirm}) async {
      tall(t, h: 3000);
      final confirmed = <(double, double)>[];
      await t.pumpWidget(host(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(
                builder: (_) => Scaffold(
                  body: LocationPickerSheet(
                    initial: start,
                    addressLine: 'Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG',
                    tileLayer: _tiles,
                    onConfirm: onConfirm ?? (la, ln) async => confirmed.add((la, ln)),
                  ),
                ),
              )),
              child: const Text('abrir'),
            ),
          ),
        ),
      )));
      await t.tap(find.text('abrir'));
      await t.pumpAndSettle();
      return confirmed;
    }

    testWidgets('mostra o endereço do cliente, o pino central e a explicação dos 100 m', (t) async {
      await open(t);
      expect(find.byKey(const ValueKey('pin-map')), findsOneWidget);
      expect(find.byKey(const ValueKey('center-pin')), findsOneWidget);
      expect(find.textContaining('Rua Padre José Geraldi, 203'), findsOneWidget);
      expect(find.textContaining('menos de 100 m'), findsOneWidget);
      expect(find.text('Confirmar este local'), findsOneWidget);
    });

    testWidgets('confirmar sem mexer devolve o ponto inicial e fecha', (t) async {
      final c = await open(t);
      await t.tap(find.text('Confirmar este local'));
      await t.pumpAndSettle();
      expect(c, hasLength(1));
      expect(c.single.$1, closeTo(-21.8027, 1e-6));
      expect(c.single.$2, closeTo(-46.6028, 1e-6));
      expect(find.byKey(const ValueKey('pin-map')), findsNothing, reason: 'a tela fecha');
    });

    testWidgets('arrastar o mapa move o pino (as coordenadas confirmadas mudam)', (t) async {
      final c = await open(t);
      await t.drag(find.byKey(const ValueKey('pin-map')), const Offset(-160, 90));
      await t.pump();
      await t.tap(find.text('Confirmar este local'));
      await t.pumpAndSettle();
      expect(c, hasLength(1));
      expect((c.single.$1 - (-21.8027)).abs() + (c.single.$2 - (-46.6028)).abs(), greaterThan(1e-6), reason: 'o centro do mapa andou');
    });

    testWidgets('sem ponto inicial abre numa região padrão e ainda assim é confirmável', (t) async {
      final c = await open(t, start: null);
      await t.tap(find.text('Confirmar este local'));
      await t.pumpAndSettle();
      expect(c, hasLength(1));
    });

    testWidgets('falha ao salvar mostra o erro e mantém a tela aberta para tentar de novo', (t) async {
      await open(t, onConfirm: (_, _) async => throw Exception('sem rede'));
      await t.tap(find.text('Confirmar este local'));
      await t.pump();
      await t.pump();
      expect(find.byKey(const ValueKey('pin-map')), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------- AddressForm
  group('AddressForm: "Confirmar o ponto exato no mapa"', () {
    Future<({List<AddressData> emitted, List<JobDestination?> opened, _Geo geo, Future<void> Function(double, double)? Function() confirmer})> open(
      WidgetTester t, {
      GeocodeHit? hit = const GeocodeHit(lat: -21.8027, lng: -46.6028, precision: DestinationPrecision.street),
      AddressLookup? lookup,
      AddressData? initial,
      bool autoConfirm = true,
      double confirmLat = -21.80285,
      double confirmLng = -46.60301,
    }) async {
      tall(t);
      final emitted = <AddressData>[];
      final opened = <JobDestination?>[];
      final geo = _Geo(hit);
      Future<void> Function(double, double)? pending;
      await t.pumpWidget(host(Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: AddressForm(
            initial: initial,
            onChanged: emitted.add,
            lookup: lookup,
            geocoder: geo,
            pinPicker: (context, {required initial, required onConfirm, addressLine}) async {
              opened.add(initial);
              pending = onConfirm;
              if (autoConfirm) await onConfirm(confirmLat, confirmLng);
              return true;
            },
          ),
        ),
      )));
      await t.pump();
      return (emitted: emitted, opened: opened, geo: geo, confirmer: () => pending);
    }

    Future<void> fill(WidgetTester t, {String street = 'Rua Padre José Geraldi', String number = '203', String city = 'Poços de Caldas'}) async {
      await t.enterText(find.widgetWithText(TextField, 'Rua / Avenida *'), street);
      await t.enterText(find.widgetWithText(TextField, 'Número *'), number);
      await t.enterText(find.widgetWithText(TextField, 'Cidade *'), city);
      await t.enterText(find.widgetWithText(TextField, 'UF'), 'MG');
      await t.pump();
    }

    testWidgets('o botão só aparece com rua, número e cidade preenchidos', (t) async {
      await open(t);
      expect(find.byKey(const Key('pin-confirm')), findsNothing);
      await t.enterText(find.widgetWithText(TextField, 'Rua / Avenida *'), 'Rua Padre José Geraldi');
      await t.pump();
      expect(find.byKey(const Key('pin-confirm')), findsNothing);
      await fill(t);
      expect(find.byKey(const Key('pin-confirm')), findsOneWidget);
      expect(find.text('Confirmar o ponto exato no mapa'), findsOneWidget);
    });

    testWidgets('abre o mapa já no ponto sugerido pela geocodificação e grava o ponto confirmado', (t) async {
      final r = await open(t);
      await fill(t);
      await t.tap(find.byKey(const Key('pin-confirm')));
      await t.pump();
      await t.pump();
      expect(r.geo.lines.single, contains('Rua Padre José Geraldi, 203'));
      expect(r.geo.lines.single, contains('Poços de Caldas'));
      expect(r.opened.single!.lat, closeTo(-21.8027, 1e-9), reason: 'mapa abre no ponto da rua, não no centro da cidade');
      expect(r.emitted.last.latitude, closeTo(-21.80285, 1e-9));
      expect(r.emitted.last.longitude, closeTo(-46.60301, 1e-9));
      expect(find.text('Ponto exato confirmado no mapa.'), findsOneWidget);
      expect(find.byKey(const Key('pin-adjust')), findsOneWidget);
    });

    testWidgets('sem internet/geocodificação: o mapa abre assim mesmo e o cliente arrasta', (t) async {
      final r = await open(t, hit: null);
      await fill(t);
      await t.tap(find.byKey(const Key('pin-confirm')));
      await t.pump();
      await t.pump();
      expect(r.opened.single, isNull);
      expect(r.emitted.last.latitude, isNotNull);
    });

    testWidgets('mudar a rua/cidade DESCARTA o ponto (ele só vale para o endereço marcado)', (t) async {
      final r = await open(t);
      await fill(t);
      await t.tap(find.byKey(const Key('pin-confirm')));
      await t.pump();
      await t.pump();
      expect(r.emitted.last.latitude, isNotNull);
      await t.enterText(find.widgetWithText(TextField, 'Rua / Avenida *'), 'Rua das Flores');
      await t.pump();
      expect(r.emitted.last.latitude, isNull);
      expect(r.emitted.last.longitude, isNull);
      expect(find.text('Ponto exato confirmado no mapa.'), findsNothing);
      expect(find.byKey(const Key('pin-confirm')), findsOneWidget, reason: 'volta a pedir a confirmação');
    });

    testWidgets('mudar o número também descarta o ponto', (t) async {
      final r = await open(t);
      await fill(t);
      await t.tap(find.byKey(const Key('pin-confirm')));
      await t.pump();
      await t.pump();
      await t.enterText(find.widgetWithText(TextField, 'Número *'), '500');
      await t.pump();
      expect(r.emitted.last.latitude, isNull);
    });

    testWidgets('"Ajustar" reabre o mapa a partir do ponto já confirmado (sem geocodificar de novo)', (t) async {
      final r = await open(t);
      await fill(t);
      await t.tap(find.byKey(const Key('pin-confirm')));
      await t.pump();
      await t.pump();
      await t.tap(find.byKey(const Key('pin-adjust')));
      await t.pump();
      await t.pump();
      expect(r.geo.lines, hasLength(1));
      expect(r.opened, hasLength(2));
      expect(r.opened.last!.lat, closeTo(-21.80285, 1e-9));
    });

    testWidgets('CEP: preenche os campos mas as coordenadas do CEP NÃO viram o pino do serviço', (t) async {
      // BrasilAPI devolve coordenadas do CEP (chegam a km do endereço real).
      final client = MockClient((req) async {
        if (req.url.host == 'viacep.com.br') return http.Response('boom', 503);
        return http.Response(
          '{"street":"Rua Padre José Geraldi","neighborhood":"Maria Imaculada","city":"Poços de Caldas","state":"MG","location":{"coordinates":{"latitude":"-21.7500","longitude":"-46.5000"}}}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final r = await open(t, lookup: AddressLookup(client));
      await t.enterText(find.widgetWithText(TextField, 'CEP'), '37701377');
      await t.pump();
      await t.pump();
      await t.pump();
      expect(find.widgetWithText(TextField, 'Rua Padre José Geraldi'), findsOneWidget);
      expect(r.emitted.last.street, 'Rua Padre José Geraldi');
      expect(r.emitted.last.latitude, isNull, reason: 'coordenada de CEP é imprecisa: o ponto vem da confirmação no mapa');
      expect(r.emitted.last.longitude, isNull);
    });

    testWidgets('endereço inicial com coordenadas (rascunho) as mantém até o cliente editar o endereço', (t) async {
      final r = await open(
        t,
        initial: const AddressData(cep: '37701377', street: 'Rua A', number: '1', neighborhood: 'Centro', city: 'Poços de Caldas', uf: 'MG', latitude: -21.8, longitude: -46.6),
      );
      expect(r.emitted.last.latitude, -21.8);
      await t.enterText(find.widgetWithText(TextField, 'Rua / Avenida *'), 'Rua B');
      await t.pump();
      expect(r.emitted.last.latitude, isNull);
    });
  });

  // ---------------------------------------------------------------- LiveLocationMapSheet: ajustar o pino
  group('LiveLocationMapSheet: ponto aproximado e "Ajustar o ponto exato"', () {
    Future<List<(double, double)>> open(WidgetTester t, {DestinationPrecision? precision, bool pinConfirmed = false, bool withAdjust = true}) async {
      tall(t, h: 3000);
      final adjusted = <(double, double)>[];
      final gps = StreamController<GeoFix>();
      addTearDown(gps.close);
      await t.pumpWidget(host(Scaffold(
        body: LiveLocationMapSheet(
          addressLine: 'Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG',
          latitude: -21.79,
          longitude: -46.56,
          precision: precision,
          pinConfirmed: pinConfirmed,
          onAdjustPin: withAdjust ? (la, ln) async => adjusted.add((la, ln)) : null,
          positionStream: () => gps.stream,
          resolver: (_, _) async => null,
          tileLayer: _tiles,
        ),
      )));
      await t.pump();
      await t.pump();
      return adjusted;
    }

    testWidgets('ponto de cidade (locality) avisa que é aproximado e oferece ajustar', (t) async {
      await open(t, precision: DestinationPrecision.locality);
      expect(find.byKey(const ValueKey('adjust-pin')), findsOneWidget);
      expect(find.textContaining('aproximad', findRichText: true), findsWidgets);
    });

    testWidgets('quem não é dono do pedido (sem onAdjustPin) não vê o botão de ajustar', (t) async {
      await open(t, precision: DestinationPrecision.locality, withAdjust: false);
      expect(find.byKey(const ValueKey('adjust-pin')), findsNothing);
    });

    testWidgets('pino já confirmado não mostra o aviso de aproximado', (t) async {
      await open(t, precision: DestinationPrecision.exact, pinConfirmed: true);
      expect(find.textContaining('aproximad', findRichText: true), findsNothing);
    });
  });
}

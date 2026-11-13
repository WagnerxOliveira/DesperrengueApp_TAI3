import 'dart:io';
import 'dart:typed_data';

import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/features/provider/presentation/material_receipt_capture_screen.dart';
import 'package:desperrengue_app/services/fiscal_receipt_service.dart';
import 'package:desperrengue_app/services/forensic_photo_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'nfe_access_key_test.dart' show buildKey;

class _Storage implements ForensicStoragePort {
  @override
  Future<String> uploadSanitized({required String path, required Uint8List bytes}) async => 'https://signed/$path';
}

class _Backend implements FiscalReceiptBackend {
  _Backend(this.respond);
  final Future<Map<String, dynamic>> Function() respond;
  int calls = 0;
  @override
  Future<Map<String, dynamic>> register(Map<String, dynamic> params) {
    calls++;
    return respond();
  }
}

void _size(WidgetTester t, double w, double h, {double scale = 1.0}) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1.0;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    t.view.reset();
    t.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

Future<MaterialReceiptResult?> _open(WidgetTester t, _Backend backend, {Size size = const Size(360, 780), double scale = 1.0, String? clip}) async {
  _size(t, size.width, size.height, scale: scale);
  MaterialReceiptResult? result;
  await t.pumpWidget(MaterialApp(
    theme: AppTheme.resolve(null, Brightness.dark),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<MaterialReceiptResult>(MaterialPageRoute(
                builder: (_) => MaterialReceiptCaptureScreen(
                  jobId: 'job-1',
                  providerId: 'prov-1',
                  service: FiscalReceiptService(backend: backend, storage: _Storage()),
                  photoPicker: () async => (bytes: Uint8List.fromList([1, 2, 3]), phash: 4242),
                  clipboardReader: () async => clip,
                ),
              ));
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  ));
  await t.tap(find.text('abrir'));
  await t.pumpAndSettle();
  return result;
}

Future<void> _show(WidgetTester t, Finder f) async {
  if (f.evaluate().isNotEmpty) {
    await t.ensureVisible(f);
  } else {
    await t.scrollUntilVisible(f, 120, scrollable: find.descendant(of: find.byKey(const ValueKey('material-receipt-list')), matching: find.byType(Scrollable)).first);
  }
  await t.pump();
}

Future<void> _fill(WidgetTester t, {String? key, String amount = '1.250,50', bool photo = true}) async {
  final keyF = find.byKey(const ValueKey('receipt-key-field'));
  await _show(t, keyF);
  await t.enterText(keyF, key ?? buildKey());
  final amountF = find.byKey(const ValueKey('receipt-amount-field'));
  await _show(t, amountF);
  await t.enterText(amountF, amount);
  if (photo) {
    final photoF = find.byKey(const ValueKey('receipt-photo-btn'));
    await _show(t, photoF);
    await t.tap(photoF);
  }
  await t.pump();
  await t.pump();
}

FilledButton _submitBtn(WidgetTester t) => t.widget<FilledButton>(find.descendant(of: find.byKey(const ValueKey('receipt-submit-btn')), matching: find.byType(FilledButton)).first);

void main() {
  group('MaterialReceiptCaptureScreen', () {
    testWidgets('botão só habilita com chave válida + valor + foto; chave inválida mostra o motivo', (t) async {
      final b = _Backend(() async => {'verified': true});
      await _open(t, b);
      expect(_submitBtn(t).onPressed, isNull);

      await t.enterText(find.byKey(const ValueKey('receipt-key-field')), '1234');
      await t.pump();
      expect(find.textContaining('44 números'), findsWidgets);

      final wrongDv = buildKey().substring(0, 43) + ((int.parse(buildKey()[43]) + 1) % 10).toString();
      await _fill(t, key: wrongDv);
      expect(find.textContaining('último número'), findsOneWidget);
      expect(_submitBtn(t).onPressed, isNull);

      await _fill(t);
      expect(find.byKey(const ValueKey('receipt-key-ok')), findsOneWidget);
      expect(find.textContaining('CNPJ 11.222.333/0001-81'), findsOneWidget);
      expect(_submitBtn(t).onPressed, isNotNull);
      expect(b.calls, 0);
    });

    testWidgets('sem foto o botão fica desabilitado (o servidor exige o hash do cupom)', (t) async {
      await _open(t, _Backend(() async => {'verified': true}));
      await _fill(t, photo: false);
      expect(_submitBtn(t).onPressed, isNull);
    });

    testWidgets('em verificação: mensagem honesta, nunca "validada"; devolve o resultado ao concluir', (t) async {
      final b = _Backend(() async => {'verified': true, 'document_id': 'doc-1'});
      MaterialReceiptResult? result;
      _size(t, 360, 780);
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.resolve(null, Brightness.dark),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await Navigator.of(context).push<MaterialReceiptResult>(MaterialPageRoute(
                builder: (_) => MaterialReceiptCaptureScreen(
                  jobId: 'job-1',
                  providerId: 'prov-1',
                  service: FiscalReceiptService(backend: b, storage: _Storage()),
                  photoPicker: () async => (bytes: Uint8List.fromList([1]), phash: 1),
                ),
              )),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('abrir'));
      await t.pumpAndSettle();
      await _fill(t);
      await t.tap(find.byKey(const ValueKey('receipt-submit-btn')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('receipt-outcome-underReview')), findsOneWidget);
      expect(find.text('Nota em verificação'), findsOneWidget);
      expect(find.textContaining('Nota validada'), findsNothing);
      await t.tap(find.byKey(const ValueKey('receipt-finish-btn')));
      await t.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.amount, 1250.5);
      expect(result!.info.number, 1234);
      expect(result!.outcome.state, FiscalReceiptState.underReview);
    });

    testWidgets('validada quando o servidor confirma a SEFAZ', (t) async {
      await _open(t, _Backend(() async => {'verified': true, 'sefaz_confirmed': true}));
      await _fill(t);
      await t.tap(find.byKey(const ValueKey('receipt-submit-btn')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('receipt-outcome-validated')), findsOneWidget);
    });

    testWidgets('recusada: mostra o motivo em pt-BR e não oferece "Concluir"', (t) async {
      await _open(t, _Backend(() async => throw const PostgrestException(message: 'duplicate key', code: '23505')));
      await _fill(t);
      await t.tap(find.byKey(const ValueKey('receipt-submit-btn')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('receipt-outcome-rejected')), findsOneWidget);
      expect(find.textContaining('já foi registrada'), findsOneWidget);
      expect(find.byKey(const ValueKey('receipt-finish-btn')), findsNothing);
    });

    testWidgets('erro de rede: mensagem clara e "Tentar de novo" funciona', (t) async {
      var fail = true;
      final b = _Backend(() async {
        if (fail) throw StateError('offline');
        return {'verified': true};
      });
      await _open(t, b);
      await _fill(t);
      await t.tap(find.byKey(const ValueKey('receipt-submit-btn')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('receipt-outcome-networkError')), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
      fail = false;
      await t.tap(find.byKey(const ValueKey('receipt-submit-btn')));
      await t.pumpAndSettle();
      expect(b.calls, 2);
      expect(find.byKey(const ValueKey('receipt-outcome-underReview')), findsOneWidget);
    });

    testWidgets('colar o link do QR Code extrai e formata a chave', (t) async {
      final k = buildKey();
      await _open(t, _Backend(() async => {'verified': true}), clip: 'https://sefaz.example/nfce?p=$k|2|1|1|HASH');
      await t.tap(find.byKey(const ValueKey('receipt-paste-btn')));
      await t.pump();
      await t.pump();
      final text = t.widget<TextField>(find.byKey(const ValueKey('receipt-key-field'))).controller!.text;
      expect(text.replaceAll(' ', ''), k);
      expect(find.byKey(const ValueKey('receipt-key-ok')), findsOneWidget);
    });

    for (final size in const [Size(320, 640), Size(360, 780), Size(412, 915)]) {
      testWidgets('${size.width.toInt()} px, fonte 1.3: sem overflow', (t) async {
        // Largura real do aparelho; altura grande só para a lista inteira ficar montada (o risco é overflow horizontal).
        await _open(t, _Backend(() async => throw const PostgrestException(message: 'SEFAZ_NOT_AUTHORIZED', code: 'P0001')), size: Size(size.width, 3000), scale: 1.3);
        await _fill(t, key: '1234');
        await t.pump();
        expect(t.takeException(), isNull);
        await _fill(t);
        await t.tap(find.byKey(const ValueKey('receipt-submit-btn')));
        await t.pumpAndSettle();
        await _show(t, find.byKey(const ValueKey('receipt-outcome-rejected')));
        expect(find.byKey(const ValueKey('receipt-outcome-rejected')), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  });

  group('Sem dados de demonstração nas telas do profissional', () {
    String read(String p) => File(p).readAsStringSync();

    test('provider_execution_screens.dart não tem NFC-e/valor/fotos fictícios', () {
      final src = read('lib/features/provider/presentation/provider_execution_screens.dart');
      expect(src.contains('forensic://'), isFalse);
      expect(src.contains('65.00'), isFalse);
      expect(src.contains('NFC-e #001'), isFalse);
      expect(src.contains('Distribuidora Técnica Autorizada'), isFalse);
      expect(src.contains('Peça de Reposição Técnica'), isFalse);
    });

    test('nenhuma tela do profissional sintetiza evidência (forensic://)', () {
      final dir = Directory('lib/features/provider');
      for (final f in dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        expect(f.readAsStringSync().contains('forensic://'), isFalse, reason: f.path);
      }
    });

    test('serviços novos não usam dart:io', () {
      for (final p in [
        'lib/services/fiscal_receipt_service.dart',
        'lib/services/forensic_photo_service.dart',
        'lib/core/utils/nfe_access_key.dart',
        'lib/features/provider/presentation/material_receipt_capture_screen.dart',
      ]) {
        expect(read(p).contains("import 'dart:io'"), isFalse, reason: p);
      }
    });
  });
}

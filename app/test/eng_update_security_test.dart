import 'dart:convert';

import 'package:desperrengue_app/core/services/update_service.dart';
import 'package:desperrengue_app/features/boot/update_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _release(String url) => jsonEncode({
      'body': 'build: 99\nversion: 1.0.0\n## Novidades\nok\n---\n',
      'assets': [
        {'name': 'app.apk', 'browser_download_url': url, 'size': 10},
      ],
    });

void main() {
  group('UpdateService: só baixa APK do GitHub por HTTPS', () {
    test('aceita github.com e *.githubusercontent.com', () {
      expect(UpdateService.isTrustedDownloadUrl('https://github.com/x/y/releases/download/t/a.apk'), isTrue);
      expect(UpdateService.isTrustedDownloadUrl('https://objects.githubusercontent.com/abc/a.apk'), isTrue);
    });

    test('rejeita http, domínio arbitrário, host disfarçado, userinfo e porta', () {
      for (final u in [
        'http://github.com/x/y/a.apk',
        'https://evil.example.com/a.apk',
        'https://github.com.evil.io/a.apk',
        'https://githubusercontent.com.evil.io/a.apk',
        'https://user:pw@github.com/a.apk',
        'https://github.com:8443/a.apk',
        'ftp://github.com/a.apk',
        'not a url',
        '',
      ]) {
        expect(UpdateService.isTrustedDownloadUrl(u), isFalse, reason: u);
      }
    });

    test('parse descarta release cujo APK aponta para domínio não confiável', () {
      expect(UpdateService.parse(_release('https://evil.example.com/a.apk')), isNull);
      expect(UpdateService.parse(_release('https://github.com/x/y/releases/download/t/a.apk')), isNotNull);
    });
  });

  testWidgets('UpdateGate: check que lança não vira erro não tratado e a checagem não se sobrepõe', (t) async {
    var calls = 0;
    await t.pumpWidget(MaterialApp(
      home: UpdateGate(
        check: () async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          throw StateError('rede caiu');
        },
        initialDelay: const Duration(milliseconds: 5),
        interval: const Duration(milliseconds: 10),
        child: const Scaffold(body: Text('conteúdo')),
      ),
    ));
    await t.pump(const Duration(milliseconds: 200));
    expect(t.takeException(), isNull);
    expect(find.text('conteúdo'), findsOneWidget);
    // 200 ms / 30 ms por checagem => nunca mais de ~7 execuções; sem guarda seriam ~20 simultâneas.
    expect(calls, lessThan(10));
    // Desmonta: timers cancelados (o teste falharia com "Timer still pending").
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 100)); // drena o Future.delayed do check falso
  });
}

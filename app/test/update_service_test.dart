import 'dart:convert';

import 'package:desperrengue_app/core/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _dualReleaseJson({
  int build = 29800123,
  String version = '2.12.0',
  String notes = 'isolamento dual-apk publico vs ceo',
  required List<Map<String, Object>> assets,
}) =>
    jsonEncode({
      'tag_name': 'beta-latest',
      'body': 'build: $build\nversion: $version\n## Novidades\n$notes\n\n---\nRelease rolante dual-APK.',
      'assets': assets,
    });

void main() {
  group('UpdateService Dual-APK Public OTA Isolation', () {
    test('invariante ASCII: desperrengue-founder-ceo.apk ordena antes de desperrengue.apk e parse escolhe estritamente desperrengue.apk', () {
      // Prova algébrica da armadilha ASCII: '-' (45) < '.' (46)
      expect('-'.codeUnitAt(0), 45);
      expect('.'.codeUnitAt(0), 46);
      final sortedNames = ['desperrengue.apk', 'desperrengue-founder-ceo.apk']..sort();
      expect(sortedNames.first, 'desperrengue-founder-ceo.apk');

      final body = _dualReleaseJson(
        assets: [
          {
            'name': 'desperrengue-founder-ceo.apk',
            'browser_download_url':
                'https://github.com/WagnerxOliveira/DesperrengueApp_TAI3/releases/download/beta-latest/desperrengue-founder-ceo.apk',
            'size': 41943040,
          },
          {
            'name': 'desperrengue.apk',
            'browser_download_url':
                'https://github.com/WagnerxOliveira/DesperrengueApp_TAI3/releases/download/beta-latest/desperrengue.apk',
            'size': 62914560,
          },
        ],
      );

      final info = UpdateService.parse(body);
      expect(info, isNotNull);
      expect(
        info!.apkUrl,
        'https://github.com/WagnerxOliveira/DesperrengueApp_TAI3/releases/download/beta-latest/desperrengue.apk',
      );
      expect(info.apkUrl.contains('founder'), isFalse);
      expect(info.sizeBytes, 62914560);
      expect(info.sizeLabel, '60 MB');
      expect(info.build, 29800123);
      expect(info.version, '2.12.0');
    });

    test('prefere desperrengue.apk mesmo quando outro .apk genérico vem antes na lista de assets', () {
      final body = _dualReleaseJson(
        assets: [
          {
            'name': 'aux-tool.apk',
            'browser_download_url': 'https://github.com/x/y/releases/download/beta-latest/aux-tool.apk',
            'size': 10485760,
          },
          {
            'name': 'desperrengue-founder-ceo.apk',
            'browser_download_url': 'https://github.com/x/y/releases/download/beta-latest/desperrengue-founder-ceo.apk',
            'size': 41943040,
          },
          {
            'name': 'desperrengue.apk',
            'browser_download_url': 'https://github.com/x/y/releases/download/beta-latest/desperrengue.apk',
            'size': 52428800,
          },
        ],
      );

      final info = UpdateService.parse(body);
      expect(info, isNotNull);
      expect(info!.apkUrl, 'https://github.com/x/y/releases/download/beta-latest/desperrengue.apk');
      expect(info.sizeBytes, 52428800);
    });

    test('fallback compatível com fixtures legadas (app.apk) ignorando desperrengue-founder-ceo.apk', () {
      final body = _dualReleaseJson(
        assets: [
          {
            'name': 'desperrengue-founder-ceo.apk',
            'browser_download_url': 'https://github.com/x/y/releases/download/beta-latest/desperrengue-founder-ceo.apk',
            'size': 41943040,
          },
          {
            'name': 'app.apk',
            'browser_download_url': 'https://github.com/x/y/releases/download/beta-latest/app.apk',
            'size': 31457280,
          },
        ],
      );

      final info = UpdateService.parse(body);
      expect(info, isNotNull);
      expect(info!.apkUrl, 'https://github.com/x/y/releases/download/beta-latest/app.apk');
      expect(info.sizeBytes, 31457280);
    });

    test('JAMAIS seleciona desperrengue-founder-ceo.apk quando é o único APK presente (janela parcial de upload)', () {
      for (final founderName in [
        'desperrengue-founder-ceo.apk',
        'Desperrengue-Founder-CEO.APK',
        'founder-release.apk',
      ]) {
        final body = _dualReleaseJson(
          assets: [
            {
              'name': founderName,
              'browser_download_url': 'https://github.com/x/y/releases/download/beta-latest/$founderName',
              'size': 41943040,
            },
          ],
        );
        expect(UpdateService.parse(body), isNull, reason: 'não pode entregar $founderName via OTA público');
      }
    });

    test('bloqueia metadado adulterado onde name=desperrengue.apk aponta para URL founder', () {
      final body = _dualReleaseJson(
        assets: [
          {
            'name': 'desperrengue.apk',
            'browser_download_url':
                'https://github.com/x/y/releases/download/beta-latest/desperrengue-founder-ceo.apk',
            'size': 41943040,
          },
        ],
      );
      expect(UpdateService.parse(body), isNull);
    });

    test('UpdateService.check entrega estritamente desperrengue.apk em release dual-APK via HTTP 200', () async {
      final dualBody = _dualReleaseJson(
        build: 500,
        assets: [
          {
            'name': 'desperrengue-founder-ceo.apk',
            'browser_download_url': 'https://github.com/x/y/releases/download/beta-latest/desperrengue-founder-ceo.apk',
            'size': 40000000,
          },
          {
            'name': 'desperrengue.apk',
            'browser_download_url': 'https://github.com/x/y/releases/download/beta-latest/desperrengue.apk',
            'size': 60000000,
          },
        ],
      );

      final service = UpdateService(
        client: MockClient((_) async => http.Response(dualBody, 200, headers: {'etag': 'W/"dual-500"'})),
        installedBuild: () async => 499,
        repo: 'x/y',
        enabled: true,
      );

      final update = await service.check();
      expect(update, isNotNull);
      expect(update!.build, 500);
      expect(update.apkUrl, 'https://github.com/x/y/releases/download/beta-latest/desperrengue.apk');
    });
  });
}

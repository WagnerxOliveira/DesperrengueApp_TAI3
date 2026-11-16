import 'dart:convert';

import 'package:desperrengue_app/core/services/public_ota_installer.dart';
import 'package:desperrengue_app/core/services/update_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    test('extrai SHA-256 exclusivamente de desperrengue.apk mesmo com FOUNDER_SHA256 no mesmo release e faz fallback para digest do asset', () {
      const publicSha = 'a1b2c3d4e5f60718293a4b5c6d7e8f90112233445566778899aabbccddeeff00';
      const founderSha = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

      final dualNotesBody = jsonEncode({
        'tag_name': 'beta-latest',
        'body': 'build: 777\nversion: 2.15.0\n## Novidades\nOTA direto sem navegador\n\n---\n'
            '- SHA-256 (`desperrengue-founder-ceo.apk`): `$founderSha`\n'
            '- SHA-256 (`desperrengue.apk`): `$publicSha`\n',
        'assets': [
          {
            'name': 'desperrengue-founder-ceo.apk',
            'browser_download_url': 'https://github.com/x/y/releases/download/beta-latest/desperrengue-founder-ceo.apk',
            'size': 42000000,
            'digest': 'sha256:$founderSha',
          },
          {
            'name': 'desperrengue.apk',
            'browser_download_url': 'https://github.com/x/y/releases/download/beta-latest/desperrengue.apk',
            'size': 63000000,
          },
        ],
      });

      final parsed = UpdateService.parse(dualNotesBody);
      expect(parsed, isNotNull);
      expect(parsed!.sha256, publicSha);
      expect(parsed.sha256, isNot(founderSha));

      // Fallback para o campo oficial `digest: sha256:...` do asset no GitHub API
      final digestOnlyBody = jsonEncode({
        'tag_name': 'beta-latest',
        'body': 'build: 778\nversion: 2.15.1\n## Novidades\nDigest via API\n---\n',
        'assets': [
          {
            'name': 'desperrengue.apk',
            'browser_download_url': 'https://github.com/x/y/releases/download/beta-latest/desperrengue.apk',
            'size': 63000000,
            'digest': 'sha256:${publicSha.toUpperCase()}',
          },
        ],
      });
      final fromDigest = UpdateService.parse(digestOnlyBody);
      expect(fromDigest, isNotNull);
      expect(fromDigest!.sha256, publicSha);
    });

    test('persiste ETag + payload em SharedPreferences para 304 Not Modified após cold start', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const publicSha = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final payload = jsonEncode({
        'tag_name': 'beta-latest',
        'body': 'build: 900\nversion: 2.16.0\n## Novidades\nCold ETag\n---\n- SHA-256 (`desperrengue.apk`): `$publicSha`',
        'assets': [
          {
            'name': 'desperrengue.apk',
            'browser_download_url': 'https://github.com/x/y/releases/download/beta-latest/desperrengue.apk',
            'size': 60000000,
          },
        ],
      });

      final firstInstance = UpdateService(
        client: MockClient((_) async => http.Response(payload, 200, headers: {'etag': 'W/"etag-900"'})),
        installedBuild: () async => 899,
        repo: 'x/y',
        enabled: true,
      );
      final firstResult = await firstInstance.check();
      expect(firstResult?.build, 900);
      expect(firstResult?.sha256, publicSha);

      String? sentIfNoneMatch;
      final coldSecondInstance = UpdateService(
        client: MockClient((req) async {
          sentIfNoneMatch = req.headers['If-None-Match'];
          return http.Response('', 304);
        }),
        installedBuild: () async => 899,
        repo: 'x/y',
        enabled: true,
      );
      final secondResult = await coldSecondInstance.check();
      expect(sentIfNoneMatch, 'W/"etag-900"');
      expect(secondResult?.build, 900);
      expect(secondResult?.sha256, publicSha);
    });
  });

  group('PublicNativeOtaInstaller: canal nativo, verificação de assinatura e isolamento', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('br.com.desperrengue.app/ota');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('rejeita URLs fora do GitHub HTTPS ou com artefato founder sem chamar o canal nativo', () async {
      var nativeCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
        nativeCalls++;
        return <String, Object?>{'status': 'installer_launched'};
      });

      final installer = PublicNativeOtaInstaller(
        channel: channel,
        isAndroidOverride: true,
      );
      addTearDown(installer.dispose);

      for (final badUrl in <String>[
        'http://github.com/x/y/releases/download/beta-latest/desperrengue.apk',
        'https://evil.example.com/desperrengue.apk',
        'https://github.com/x/y/releases/download/beta-latest/desperrengue-founder-ceo.apk',
      ]) {
        await installer.downloadAndInstall(
          UpdateInfo(build: 10, version: '1.0.0', apkUrl: badUrl),
        );
        expect(installer.progressNotifier.value.phase, PublicOtaInstallPhase.error);
      }
      expect(nativeCalls, 0);
    });

    test('executa downloadAndInstallApk no canal nativo e propaga installerLaunched e permission_required', () async {
      Map<Object?, Object?>? capturedArgs;
      var returnPermissionRequired = true;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'downloadAndInstallApk') {
          capturedArgs = call.arguments as Map<Object?, Object?>?;
          if (returnPermissionRequired) {
            return <String, Object?>{
              'status': 'permission_required',
              'bytes': 62914560,
              'sha256': 'aabbcc',
            };
          }
          return <String, Object?>{
            'status': 'installer_launched',
            'bytes': 62914560,
            'sha256': 'aabbcc',
          };
        }
        if (call.method == 'triggerPendingInstall') {
          return <String, Object?>{'status': 'installer_launched'};
        }
        return null;
      });

      final installer = PublicNativeOtaInstaller(
        channel: channel,
        isAndroidOverride: true,
      );
      addTearDown(installer.dispose);

      const info = UpdateInfo(
        build: 901,
        version: '2.16.0',
        apkUrl: 'https://github.com/x/y/releases/download/beta-latest/desperrengue.apk',
        sizeBytes: 62914560,
        sha256: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );

      await installer.downloadAndInstall(info);
      expect(capturedArgs?['apkUrl'], info.apkUrl);
      expect(capturedArgs?['expectedSha256'], info.sha256);
      expect(
        installer.progressNotifier.value.phase,
        PublicOtaInstallPhase.awaitingPermission,
      );

      await installer.triggerPendingInstall();
      expect(
        installer.progressNotifier.value.phase,
        PublicOtaInstallPhase.installerLaunched,
      );

      returnPermissionRequired = false;
      await installer.downloadAndInstall(info);
      expect(
        installer.progressNotifier.value.phase,
        PublicOtaInstallPhase.installerLaunched,
      );
    });

    test('traduz ERR_OTA_SIGNATURE_MISMATCH e ERR_OTA_SHA256_MISMATCH em mensagem clara de bloqueio de segurança', () async {
      for (final errCode in <String>[
        'ERR_OTA_SHA256_MISMATCH',
        'ERR_OTA_SIGNATURE_MISMATCH',
        'ERR_OTA_PACKAGE_MISMATCH',
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: errCode, message: 'Assinatura divergente');
        });

        final installer = PublicNativeOtaInstaller(
          channel: channel,
          isAndroidOverride: true,
        );

        await installer.downloadAndInstall(
          const UpdateInfo(
            build: 902,
            version: '2.16.0',
            apkUrl: 'https://github.com/x/y/releases/download/beta-latest/desperrengue.apk',
          ),
        );
        expect(installer.progressNotifier.value.phase, PublicOtaInstallPhase.error);
        expect(
          installer.progressNotifier.value.errorMessage,
          contains('Assinatura de segurança inválida'),
        );
        installer.dispose();
      }
    });
  });
}
